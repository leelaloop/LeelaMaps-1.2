//
//  LocationViewController.h
//  Leela Maps
//
//  Created by Gregory Hazel on 11/5/17.
//  Copyright © 2017 Leela Maps. All rights reserved.
//

@import UIKit;

@import CloudKit;

@interface LocationViewController : UIViewController
@property (nonatomic) CKRecord *location;
@property (nonatomic) CKShare *share;
@end
