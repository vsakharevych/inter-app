//
//  SenderViewController.m
//  inter-app
//
//  Created by Volodymyr Sakharevych on 24.09.2020.
//  Copyright © 2020 Volodymyr Sakharevych. All rights reserved.
//

#import "SenderViewController.h"

#import "ConnectionManager.h"
#import "CommonConstants.h"
#import "SceneDelegate.h"


@interface SenderViewController ()

@property (weak, nonatomic) IBOutlet UIButton *sendButton;

@end


@implementation SenderViewController

- (void)viewDidLoad
{
    NSLog(@"%s %@", __FUNCTION__, [NSThread currentThread]);
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated
{
    NSLog(@"%s %@", __FUNCTION__, [NSThread currentThread]);
    [super viewWillAppear:animated];
    [self.sendButton setTitle:@"Send image to Receiver App" forState:UIControlStateNormal];
}

- (IBAction)startServerButtonTapped:(id)sender
{
    NSLog(@"%s %@", __FUNCTION__, [NSThread currentThread]);
    [self.sendButton setTitle:@"Preparing data for sending..." forState:UIControlStateNormal];
    self.sendButton.enabled = NO;

    // prepare data for sending
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *data = [self dataToSend];
        [ConnectionManager sharedInstance].pendingData = data;

        // open Receiver app
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *urlString = [kReceiverURLScheme stringByAppendingFormat:@":%d", kPortNumber];
            NSURL *receiverUrl = [NSURL URLWithString:urlString];

            UIApplication *application = UIApplication.sharedApplication;
            if ([application canOpenURL:receiverUrl])
            {
                [application openURL:receiverUrl options:@{} completionHandler:^(BOOL success)
                {
                    NSLog(@"Url %@ has been opened: %d", receiverUrl, success);
                    [[ConnectionManager sharedInstance] sendDataIfAnyUsingPort:kPortNumber withinTimeInterval:5.0];
                }];
            }
        });
    });
}

- (NSData *)dataToSend
{
    NSLog(@"%s %@", __FUNCTION__, [NSThread currentThread]);
    NSString *path = [NSBundle.mainBundle pathForResource:@"largeImage" ofType:@"jpg"];
    NSAssert(path, @"Wrong path to image");
    UIImage *image = [UIImage imageWithContentsOfFile:path];
    NSAssert(image, @"Unable to instantiate image");
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:image
                                         requiringSecureCoding:YES
                                                         error:nil];
    NSAssert(data, @"Failed to serialize image");
    return data;
}

- (void)dealloc
{
    NSLog(@"%s %@", __FUNCTION__, [NSThread currentThread]);
    [[ConnectionManager sharedInstance] invalidateCommunicationChannels];
}

@end
