//
//  ReceiverViewController.m
//  receiver
//
//  Created by Volodymyr Sakharevych on 24.09.2020.
//  Copyright © 2020 Volodymyr Sakharevych. All rights reserved.
//

#import "ReceiverViewController.h"

#import "ConnectionManager.h"
#import "CommonConstants.h"


@interface ReceiverViewController ()

@property (weak, nonatomic) IBOutlet UIImageView *imageView;

@end


@implementation ReceiverViewController

- (void)viewDidLoad
{
    NSLog(@"%s %@", __FUNCTION__, [NSThread currentThread]);
    [super viewDidLoad];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(handleReceivedDataNotification:)
                                               name:kDataReceivedNotification
                                             object:nil];
}

- (void)dealloc
{
    NSLog(@"%s %@", __FUNCTION__, [NSThread currentThread]);
    [NSNotificationCenter.defaultCenter removeObserver:self];
    [[ConnectionManager sharedInstance] invalidateCommunicationChannels];
}

#pragma mark - Handle Notifications

- (void)handleReceivedDataNotification:(NSNotification *)notification
{
    NSLog(@"%s %@", __FUNCTION__, [NSThread currentThread]);
    NSDictionary *info = notification.userInfo;
    NSData *resultData = nil;
    if (info)
    {
        resultData = [info valueForKey:kDataKey];
        if (!resultData || !resultData.length)
        {
            return;
        }
    }
    NSError *error = nil;
    UIImage *image = [NSKeyedUnarchiver unarchivedObjectOfClass:[UIImage class]
                                                       fromData:resultData
                                                          error:&error];
    if (image)
    {
        NSLog(@"image %@", image);
        dispatch_async(dispatch_get_main_queue(), ^{
            self.imageView.image = image;
        });
    }
    else
    {
        NSLog(@"Failed to deserialize image: %@", error);
    }
}

@end
