#import "SceneDelegate.h"

#import "CommonConstants.h"
#import "ConnectionManager.h"

@interface SceneDelegate ()

@end

@implementation SceneDelegate


- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
    // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
    // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).

    NSLog(@"%s %@", __FUNCTION__, [NSThread currentThread]);
    NSLog(@"Available URLContexts: %@", connectionOptions.URLContexts);
    if (connectionOptions && connectionOptions.URLContexts)
    {
        [self processURLContexts:connectionOptions.URLContexts];
    }
}


- (void)sceneDidDisconnect:(UIScene *)scene {
    // Called as the scene is being released by the system.
    // This occurs shortly after the scene enters the background, or when its session is discarded.
    // Release any resources associated with this scene that can be re-created the next time the scene connects.
    // The scene may re-connect later, as its session was not neccessarily discarded (see `application:didDiscardSceneSessions` instead).
}


- (void)sceneDidBecomeActive:(UIScene *)scene {
    // Called when the scene has moved from an inactive state to an active state.
    // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
}


- (void)sceneWillResignActive:(UIScene *)scene {
    // Called when the scene will move from an active state to an inactive state.
    // This may occur due to temporary interruptions (ex. an incoming phone call).
    NSLog(@"%s %@", __FUNCTION__, [NSThread currentThread]);
}


- (void)sceneWillEnterForeground:(UIScene *)scene {
    // Called as the scene transitions from the background to the foreground.
    // Use this method to undo the changes made on entering the background.
}


- (void)sceneDidEnterBackground:(UIScene *)scene {
    // Called as the scene transitions from the foreground to the background.
    // Use this method to save data, release shared resources, and store enough scene-specific state information
    // to restore the scene back to its current state.
    NSLog(@"%s %@", __FUNCTION__, [NSThread currentThread]);
}

- (void)scene:(UIScene *)scene openURLContexts:(NSSet<UIOpenURLContext *> *)URLContexts
{
    NSLog(@"%s %@", __FUNCTION__, [NSThread currentThread]);
    NSLog(@"Available URLContexts: %@", URLContexts);
    if (URLContexts)
    {
        [self processURLContexts:URLContexts];
    }
}

- (void)processURLContexts:(NSSet<UIOpenURLContext *> *)contexts
{
    for (UIOpenURLContext *context in contexts)
    {
        if ([context.URL.scheme isEqualToString:kReceiverURLScheme])
        {
            NSString *urlString = context.URL.absoluteString;
            NSString *portNumberString = [urlString componentsSeparatedByString:@":"].lastObject;
            NSScanner *scanner = [NSScanner scannerWithString:portNumberString];
            NSInteger portNumber = -1;

            if ([scanner scanInteger:&portNumber])
            {
                if ([[ConnectionManager sharedInstance] startServerWithPortNumber:portNumber])
                {
                    [NSNotificationCenter.defaultCenter postNotificationName:kFailedToStartServerNotification
                                                                      object:nil];
                }
            }
        }
    }
}

@end
