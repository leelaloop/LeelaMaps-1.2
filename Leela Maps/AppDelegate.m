//
//  AppDelegate.m
//  Leela Maps
//
//  Created by Gregory Hazel on 10/25/17.
//  Copyright © 2017 Leela Maps. All rights reserved.
//

#import "AppDelegate.h"
#import "MapViewController.h"
#import "IntroViewController.h"

@import CloudKit;
@import UserNotifications;


@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    if (![NSUserDefaults.standardUserDefaults boolForKey:@"intro"]) {
        self.window.rootViewController = [self.window.rootViewController.storyboard instantiateViewControllerWithIdentifier:@"IntroViewController"];
        [self.window makeKeyAndVisible];
    }

    [UNUserNotificationCenter.currentNotificationCenter requestAuthorizationWithOptions:UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge completionHandler:^(BOOL granted, NSError * _Nullable error) {
        if (error) {
            NSLog(@"notification requestAuthorizationWithOptions:%@", error);
            return;
        }
        if (granted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [application registerForRemoteNotifications];
            });
        }
    }];

    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}


- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    NSLog(@"didRegisterForRemoteNotificationsWithDeviceToken:%@", deviceToken);
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error
{
    NSLog(@"didFailToRegisterForRemoteNotificationsWithError:%@", error);
}

// The method will be called on the delegate only if the application is in the foreground. If the method is not implemented or the handler is not called in a timely manner then the notification will not be presented. The application can choose to have the notification presented as a sound, badge, alert and/or in the notification list. This decision should be based on whether the information in the notification is otherwise visible to the user.
- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler
{
    NSLog(@"willPresentNotification:%@ %@", notification, notification.request.content.userInfo);
    //CKNotification *cloudKitNotification = [CKNotification notificationFromRemoteNotificationDictionary:notification.request.content.userInfo];
    //NSString *alertBody = cloudKitNotification.alertBody;
    completionHandler(UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge);
}

// The method will be called on the delegate when the user responded to the notification by opening the application, dismissing the notification or choosing a UNNotificationAction. The delegate must be set before the application returns from application:didFinishLaunchingWithOptions:.
- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void(^)(void))completionHandler
{
    NSLog(@"didReceiveNotificationResponse:%@", response);
    CKNotification *cloudKitNotification = [CKNotification notificationFromRemoteNotificationDictionary:response.notification.request.content.userInfo];
    if (cloudKitNotification.notificationType == CKNotificationTypeQuery) {
        //CKQueryNotification *qn = (CKQueryNotification*)cloudKitNotification;
        //CKRecordID *recordID = qn.recordID;
    }
    completionHandler();
}

static CKUserIdentity *userInfo;

+ (void)getUserInfo:(void (^)(CKUserIdentity *userInfo, NSError *error))complete
{
    if (userInfo) {
        if (complete) {
            complete(userInfo, nil);
        }
        return;
    }
    [CKContainer.defaultContainer accountStatusWithCompletionHandler:^(CKAccountStatus accountStatus, NSError *error) {
        if (accountStatus == CKAccountStatusNoAccount) {
            if (complete) {
                complete(nil, error);
            }
            return;
        }
        [CKContainer.defaultContainer requestApplicationPermission:CKApplicationPermissionUserDiscoverability completionHandler:^(CKApplicationPermissionStatus applicationPermissionStatus, NSError * _Nullable error) {
            NSLog(@"requestApplicationPermission status:%d error:%@", (int)applicationPermissionStatus, error);
            if (error || applicationPermissionStatus != CKApplicationPermissionStatusGranted) {
                if (complete) {
                    complete(nil, error);
                }
                return;
            }
            [CKContainer.defaultContainer fetchUserRecordIDWithCompletionHandler:^(CKRecordID * _Nullable recordID, NSError * _Nullable error) {
                if (error) {
                    NSLog(@"userRecord error: %@", error);
                    if (complete) {
                        complete(nil, error);
                    }
                    return;
                }
                [CKContainer.defaultContainer discoverUserIdentityWithUserRecordID:recordID completionHandler:^(CKUserIdentity * _Nullable ui, NSError * _Nullable error) {
                    if (error) {
                        NSLog(@"userInfo error: %@", error);
                        if (complete) {
                            complete(nil, error);
                        }
                        return;
                    }
                    userInfo = ui;
                    if (complete) {
                        complete(userInfo, error);
                    }
                }];
            }];
        }];
    }];
}

- (MapViewController*)mapViewController
{
    if (![UIApplication.sharedApplication.keyWindow.rootViewController isKindOfClass:PullUpViewController.class]) {
        return nil;
    }
    PullUpViewController *p = (PullUpViewController*)UIApplication.sharedApplication.keyWindow.rootViewController;
    if (![p.childViewControllers.lastObject isKindOfClass:MapViewController.class]) {
        return nil;
    }
    return (MapViewController *)p.childViewControllers.lastObject;
}

- (void)application:(UIApplication *)application userDidAcceptCloudKitShareWithMetadata:(CKShareMetadata *)cloudKitShareMetadata {
    NSLog(@"userDidAcceptCloudKitShareWithMetadata:%@", cloudKitShareMetadata);
    if (cloudKitShareMetadata.share.owner == cloudKitShareMetadata.share.currentUserParticipant) {
        CKDatabase *privateDatabase = CKContainer.defaultContainer.privateCloudDatabase;
        [privateDatabase fetchRecordWithID:cloudKitShareMetadata.rootRecordID completionHandler:^(CKRecord *location, NSError *error) {
            if (error) {
                NSLog(@"error:%@", error);
                return;
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                MapViewController *m = self.mapViewController;
                CKPointAnnotation *annotation = [m locationToAnnotation:location];
                annotation.share = cloudKitShareMetadata.share;
                [m showAnnotations:@[annotation]];
                [m selectAnnotation:annotation];
            });
        }];
        return;
    }
    CKAcceptSharesOperation *acceptOp = [CKAcceptSharesOperation.alloc initWithShareMetadatas:@[cloudKitShareMetadata]];
    acceptOp.perShareCompletionBlock = ^(CKShareMetadata *shareMetadata, CKShare * _Nullable acceptedShare, NSError * _Nullable error) {
        if (error) {
            NSLog(@"error:%@", error);
            return;
        }
        CKDatabase *sharedDatabase = CKContainer.defaultContainer.sharedCloudDatabase;
        [sharedDatabase fetchRecordWithID:cloudKitShareMetadata.rootRecordID completionHandler:^(CKRecord *location, NSError *error) {
            if (error) {
                NSLog(@"error:%@", error);
                return;
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                MapViewController *m = self.mapViewController;
                CKPointAnnotation *annotation = [m locationToAnnotation:location];
                annotation.share = cloudKitShareMetadata.share;
                [m showAnnotations:@[annotation]];
                [m selectAnnotation:annotation];
            });
        }];
    };
    [[CKContainer containerWithIdentifier:cloudKitShareMetadata.containerIdentifier] addOperation:acceptOp];
}

@end
