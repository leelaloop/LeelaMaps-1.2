//
//  UIBarItem+renderingMode.m
//  Leela Maps
//
//  Created by Gregory Hazel on 11/18/17.
//  Copyright © 2017 Leela Maps. All rights reserved.
//

#import "UIBarItem+renderingMode.h"

@implementation UIBarItem (renderingMode)

- (void)setImageRenderingMode:(UIImageRenderingMode)renderMode
{
    NSAssert(self.image, @"Image must be set before setting rendering mode");
    self.image = [self.image imageWithRenderingMode:renderMode];
}

@end
