//
//  CommonConstants.m
//  inter-app
//
//  Created by Volodymyr Sakharevych on 24.09.2020.
//  Copyright © 2020 Volodymyr Sakharevych. All rights reserved.
//

#import "CommonConstants.h"

NSString * const kReceiverURLScheme =                   @"com.interapp.receiver";
NSString * const kLocalHostAddress =                    @"127.0.0.1";
NSString * const kOpenURLReceivedNotification =         @"kOpenURLReceivedNotification";
NSString * const kPortNumberKey =                       @"kPortNumberKey";
NSString * const kDataReceivedNotification =            @"kDataReceivedNotification";
NSString * const kDataKey =                             @"kDataKey";
NSString * const kDataReadyForSendingNotification =     @"kDataReadyForSendingNotification";
NSString * const kSenderAppBundleID =                   @"inter-app.sender";
NSString * const kFailedToStartServerNotification =     @"kFailedToStartServerNotification";

uint16_t kPortNumber =                                  30003;
