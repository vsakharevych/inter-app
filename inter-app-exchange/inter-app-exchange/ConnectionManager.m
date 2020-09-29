//
//  ConnectionManager.m
//
//
//  Created by Volodymyr Sakharevych on 24.09.2020.
//  Copyright © 2020 Volodymyr Sakharevych. All rights reserved.
//

#import "ConnectionManager.h"

#include <sys/socket.h>
#include <netinet/in.h>
#include <sys/types.h>
#include <netdb.h>

NSString * const kDataReceivedNotification = @"kDataReceivedNotification";
NSString * const kDataKey = @"kDataKey";

static NSString * const kLocalHostAddress = @"127.0.0.1";

@interface ConnectionManager ()

@property (nonatomic, strong) dispatch_source_t listeningSource;
@property (nonatomic, strong) dispatch_io_t writeChannel;
@property (nonatomic, strong) dispatch_io_t readChannel;

@end

@implementation ConnectionManager

+ (nonnull instancetype)sharedInstance
{
    NSLog(@"%s %@", __FUNCTION__, [NSThread currentThread]);
    static id instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[ConnectionManager alloc] init];
    });
    
    return instance;
}

- (void)dealloc
{
    NSLog(@"%s %@", __FUNCTION__, [NSThread currentThread]);
    self.pendingData = nil;
    [self invalidateCommunicationChannels];
}

- (void)invalidateCommunicationChannels
{
    NSLog(@"%s %@", __FUNCTION__, [NSThread currentThread]);
    if (self.listeningSource)
    {
        dispatch_source_cancel(self.listeningSource);
        self.listeningSource = nil;
    }
    if (self.writeChannel)
    {
        dispatch_io_close(self.writeChannel, DISPATCH_IO_STOP);
        self.writeChannel = nil;
    }
    if (self.readChannel)
    {
        dispatch_io_close(self.readChannel, DISPATCH_IO_STOP);
        self.readChannel = nil;
    }
}

#pragma mark - Async sending of data

- (void)sendDataIfAnyUsingPort:(uint16_t)portNumber withinTimeInterval:(NSTimeInterval)timeInterval
{
    NSLog(@"%s %@", __FUNCTION__, [NSThread currentThread]);
    if (self.pendingData && self.pendingData.length)
    {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self connectToServerUsingPort:portNumber withinTimeInterval:timeInterval andSendData:self.pendingData];
        });
    }
}

- (void)dispatchAsyncSend:(int)clientSocket
{
    NSLog(@"%s %@", __FUNCTION__, [NSThread currentThread]);
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    dispatch_io_t channel = dispatch_io_create(DISPATCH_IO_STREAM, clientSocket, queue, ^ (__unused int error) {});
    
    if (channel)
    {
        self.writeChannel = channel;
        dispatch_io_set_low_water(channel, 1);
        dispatch_io_set_high_water(channel, SIZE_MAX);
        
        NSData *messageData = self.pendingData;
        
        dispatch_data_t messageDispatchData = dispatch_data_create([messageData bytes],
                                                            [messageData length],
                                                            queue,
                                                            DISPATCH_DATA_DESTRUCTOR_DEFAULT);
        
        dispatch_io_write(channel,
                          0,
                          messageDispatchData,
                          queue,
                          ^ (bool done, __unused dispatch_data_t data, int write_error)
                          {
            if (done)
            {
                close(clientSocket);
                dispatch_io_close(self.writeChannel, DISPATCH_IO_STOP);
                self.writeChannel = nil;
                NSLog(@"dispatch_io_write finished");
            }
        });
    }
    else
    {
        close(clientSocket);
    }
}

- (int)connectToServerUsingPort:(uint16_t)portNumber withinTimeInterval:(NSTimeInterval)timeInterval andSendData:(NSData *)data
{
    NSLog(@"%s %@", __FUNCTION__, [NSThread currentThread]);
    struct hostent *hostEnt;
    struct sockaddr_in serverAddress;
    hostEnt = gethostbyname(kLocalHostAddress.UTF8String);
    
    if (!hostEnt)
    {
        NSLog(@"gethostbyname() failed: %s", strerror(errno));
        return 1;
    }
    
    int clientSocket = -1;
    NSDate *timeStamp = [NSDate dateWithTimeInterval:timeInterval sinceDate:[NSDate date]];
    
    while (1)
    {
        NSLog(@"Creating client socket");
        clientSocket = socket(AF_INET, SOCK_STREAM, 0);
        if (clientSocket < 0)
        {
            NSLog(@"socket() failed: %s", strerror(errno));
            return 1;
        }

        serverAddress.sin_family = AF_INET;
        serverAddress.sin_port = htons(portNumber);
        serverAddress.sin_addr = *((struct in_addr *)hostEnt->h_addr);
        bzero(&(serverAddress.sin_zero), 8);
        
        NSLog(@"Connecting to server");

        if (connect(clientSocket, (struct sockaddr *)&serverAddress, sizeof(struct sockaddr)))
        {
            if ((errno != ECONNREFUSED)
                // if timeout expired
                || ([timeStamp compare:[NSDate date]] == NSOrderedAscending))
            {
                NSLog(@"connect() failed. Exit function");
                close(clientSocket);
                return 1;
            }
            NSLog(@"connect() failed: %s %d", strerror(errno), errno);
            close(clientSocket);
            [NSThread sleepForTimeInterval:0.05];
        }
        else
        {
            break;
        }
    }

    NSLog(@"dispatchAsyncSend");
    [self dispatchAsyncSend:clientSocket];
    
    return 0;
}

#pragma mark - Async receiving of data

- (void)createAsyncReadChannel:(int)clientSocket queue:(dispatch_queue_t)queue
{
    NSLog(@"%s %@", __FUNCTION__, [NSThread currentThread]);
    NSMutableData *resultData = [NSMutableData data];
    
    dispatch_io_t channel = dispatch_io_create(DISPATCH_IO_STREAM,
                                               clientSocket,
                                               queue,
                                               ^ (int error) {});
    
    if (channel)
    {
        self.readChannel = channel;
        dispatch_io_set_low_water(channel, 1);
        dispatch_io_set_high_water(channel, SIZE_MAX);
        
        dispatch_io_read(channel,
                         0,
                         SIZE_MAX,
                         queue,
                         ^ (bool done, dispatch_data_t data, int error)
                         {
            if (error)
            {
                NSLog(@"dispatch_io_read error: %d", error);
                return;
            }
            if (data && dispatch_data_get_size(data))
            {
                dispatch_data_apply(data, ^bool(dispatch_data_t region,
                                                size_t offset,
                                                const void *buffer,
                                                size_t size)
                                    {
                    NSData *dataChunk = [NSData dataWithBytes:buffer length:size];
                    
                    if (dataChunk && dataChunk.length)
                    {
                        [resultData appendData:dataChunk];
                    }
                    return true;
                });
            }

            if (done)
            {
                if (resultData && resultData.length)
                {
                    NSLog(@"Result data size: %lu", resultData.length);
                    [self postResultData:resultData];
                }
                dispatch_source_cancel(self.listeningSource);
                dispatch_io_close(self.readChannel, DISPATCH_IO_STOP);
                self.readChannel = nil;
                self.listeningSource = nil;
            }
        });
    }
    else
    {
        close(clientSocket);
    }
}

- (void)dispatchAsyncRecv:(int)socketToListen
{
    NSLog(@"%s %@", __FUNCTION__, [NSThread currentThread]);
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    self.listeningSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, (uintptr_t)socketToListen, 0, queue);
    
    if (self.listeningSource)
    {
        dispatch_source_set_event_handler(self.listeningSource, ^ {
            
            NSLog(@"Dispatch source handler called");
            
            struct sockaddr_storage clientAddress;
            socklen_t clientAddressLength = sizeof(clientAddress);
            
            NSLog(@"Accepting connection");
            int clientSocket = accept(socketToListen,
                                      (struct sockaddr*)&clientAddress,
                                      &clientAddressLength);

            if (clientSocket < 0)
            {
                NSLog(@"accept() failed: %s", strerror(errno));
                return;
            }
            
            [self createAsyncReadChannel:clientSocket queue:queue];
        });
        
        dispatch_source_set_cancel_handler(self.listeningSource, ^{
            NSLog(@"Cancel handler called");
            close(socketToListen);
        });
        
        dispatch_resume(self.listeningSource);
    }
    else
    {
        close(socketToListen);
    }
}

- (int)startServerWithPortNumber:(uint16_t)portNumber
{
    NSLog(@"%s %@", __FUNCTION__, [NSThread currentThread]);
    struct addrinfo serverAddressInfo;
    memset(&serverAddressInfo, 0, sizeof(serverAddressInfo));
    serverAddressInfo.ai_family = AF_INET;
    serverAddressInfo.ai_socktype = SOCK_STREAM;
    serverAddressInfo.ai_flags = AI_PASSIVE;
    
    struct addrinfo *serverBindAddress;
    NSString *portNumberString = [NSString stringWithFormat:@"%d", portNumber];
    getaddrinfo(0, portNumberString.UTF8String, &serverAddressInfo, &serverBindAddress);
    
    NSLog(@"Creating socket...");
    int socketToListen = socket(serverBindAddress->ai_family,
                                serverBindAddress->ai_socktype,
                                serverBindAddress->ai_protocol);
    if (socketToListen < 0)
    {
        NSLog(@"socket() failed: %s", strerror(errno));
        return 1;
    }
    
    NSLog(@"Binding socket to local address...");
    if (bind(socketToListen, serverBindAddress->ai_addr, serverBindAddress->ai_addrlen))
    {
        NSLog(@"bind() failed: %s", strerror(errno));
        return 1;
    }
    freeaddrinfo(serverBindAddress);
    
    NSLog(@"Listening...");
    if (listen(socketToListen, 10) < 0)
    {
        NSLog(@"listen() failed: %s", strerror(errno));
        return 1;
    }
    
    [self dispatchAsyncRecv:socketToListen];
    
    return 0;
}

- (void)postResultData:(NSData *)resultData
{
    NSLog(@"%s %@", __FUNCTION__, [NSThread currentThread]);
    NSDictionary *infoDictionary = @{ kDataKey : resultData };
    [NSNotificationCenter.defaultCenter postNotificationName:kDataReceivedNotification
                                                      object:nil
                                                    userInfo:infoDictionary];
}

@end
