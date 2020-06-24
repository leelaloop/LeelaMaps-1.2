//
//  LocationEditViewController.h
//  Leela Maps
//
//  Created by Gregory Hazel on 11/6/17.
//  Copyright © 2017 Leela Maps. All rights reserved.
//

@import UIKit;

@import CloudKit;

@interface LocationEditViewController : UITableViewController
@property (nonatomic) CKRecord *location;
@property (nonatomic) CKShare *share;
@end
