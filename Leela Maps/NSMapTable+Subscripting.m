//
//  NSMapTable+Subscripting.m
//  Leela Maps
//
//  Created by Gregory Hazel on 11/26/17.
//  Copyright © 2017 Leela Maps. All rights reserved.
//

#import "NSMapTable+Subscripting.h"


@implementation NSMapTable (Subscripting)

- (void)setObject:(id)obj forKeyedSubscript:(id)key {
    if (obj) {
        [self setObject:obj forKey:key];
    } else {
        [self removeObjectForKey:key];
    }
}

- (id)objectForKeyedSubscript:(id)key {
    return [self objectForKey:key];
}

@end
