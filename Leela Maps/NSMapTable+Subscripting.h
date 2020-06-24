//
//  NSMapTable+Subscripting.h
//  Leela Maps
//
//  Created by Gregory Hazel on 11/26/17.
//  Copyright © 2017 Leela Maps. All rights reserved.
//

@import Foundation;

@interface NSMapTable<KeyType, ObjectType> (Subscripting)

- (void)setObject:(ObjectType)obj forKeyedSubscript:(KeyType)key;
- (ObjectType)objectForKeyedSubscript:(KeyType)key;

@end
