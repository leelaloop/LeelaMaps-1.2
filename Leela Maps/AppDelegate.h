//
//  AppDelegate.h
//  Leela Maps
//
//  Created by Gregory Hazel on 10/25/17.
//  Copyright © 2017 Leela Maps. All rights reserved.
//

@import UIKit;
@import CloudKit;

#import "UIBarItem+renderingMode.h"
#import "MapViewController.h"


@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

+ (void)getUserInfo:(void (^)(CKUserIdentity *userInfo, NSError *error))complete;

- (MapViewController*)mapViewController;

@end

