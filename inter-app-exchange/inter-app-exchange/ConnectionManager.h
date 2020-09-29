//
//  ConnectionManager.h
//  receiver
//
//  Created by Volodymyr Sakharevych on 24.09.2020.
//  Copyright © 2020 Volodymyr Sakharevych. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * _Nonnull const kDataReceivedNotification;
extern NSString * _Nonnull const kDataKey;


@interface ConnectionManager : NSObject

+ (nonnull instancetype)sharedInstance;

// Async receiving of data
- (int)startServerWithPortNumber:(uint16_t)portNumber;

// Async sending of data
- (void)sendDataIfAnyUsingPort:(uint16_t)portNumber withinTimeInterval:(NSTimeInterval)timeInterval;

- (void)invalidateCommunicationChannels;

@property (atomic, strong) NSData * _Nullable pendingData;

@end

