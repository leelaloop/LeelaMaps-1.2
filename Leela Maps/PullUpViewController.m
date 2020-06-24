//
//  PullUpViewController.m
//  Leela Maps
//
//  Created by Gregory Hazel on 11/25/17.
//  Copyright © 2017 Leela Maps. All rights reserved.
//

#import "PullUpViewController.h"

@interface PullUpViewController () <ISHPullUpContentDelegate>

@end

@implementation PullUpViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.bottomViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"bottom"];
    self.contentViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"MapViewController"];
    self.contentDelegate = self;
}

- (void)pullUpViewController:(ISHPullUpViewController *)pullUpViewController updateEdgeInsets:(UIEdgeInsets)edgeInsets forContentViewController:(UIViewController *)contentVC
{
    self.contentViewController.view.layoutMargins = edgeInsets;
}

@end
