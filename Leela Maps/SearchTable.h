//
//  SearchTable.h
//  Leela Maps
//
//  Created by Gregory Hazel on 10/25/17.
//  Copyright © 2017 Leela Maps. All rights reserved.
//

@import UIKit;
#import "MapViewController.h"

@interface SearchTable : UITableViewController <UISearchResultsUpdating>
@property (weak, nonatomic) MapViewController *mapView;

- (void)showRecords:(NSArray<CKRecord*>*)records;
- (void)reload:(UISearchController *)searchController;

@end
