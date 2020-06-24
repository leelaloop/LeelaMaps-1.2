//
//  NSAttributedString+Twitterify.m
//  Leela Maps
//
//  Created by Gregory Hazel on 12/20/17.
//  Copyright © 2017 Leela Maps. All rights reserved.
//

#import "NSAttributedString+Twitterify.h"
#import "TwitterText.h"


@implementation NSAttributedString (Twitterify)

- (NSMutableAttributedString*)twitterify:(UIColor*)twitterColor
{
    NSMutableAttributedString *attributedText = self.mutableCopy;
    NSArray *entities = [TwitterText entitiesInText:attributedText.string];
    [entities enumerateObjectsUsingBlock:^(TwitterTextEntity *obj, NSUInteger idx, BOOL *stop) {
        if (obj.type == TwitterTextEntityHashtag) {
            NSString *tag = [attributedText.string substringWithRange:obj.range];
            [attributedText addAttributes:@{NSForegroundColorAttributeName: twitterColor,
                                            NSLinkAttributeName: tag} range:obj.range];
        }
    }];
    return attributedText;
}

@end
