//
//  MapViewController.h
//  Leela Maps
//
//  Created by Gregory Hazel on 10/25/17.
//  Copyright © 2017 Leela Maps. All rights reserved.
//

@import UIKit;
#import "ISHPullUp/ISHPullUpViewController.h"
#import "ISHHoverBar/ISHHoverBar.h"
#import "PullUpViewController.h"

@import MapKit;
@import CloudKit;


@interface CKPointAnnotation : MKPointAnnotation <MKAnnotation>
@property (nonatomic) CKRecord *location;
@property (nonatomic) CKShare *share;
@end

@interface MapViewController : UIViewController

@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (nonatomic) NSMutableOrderedSet *tagSet;
@property (strong, nonatomic) UISearchController *searchController;

- (CLLocation*)center;

- (PullUpViewController*)pullUpViewController;

- (void)showRecords:(NSArray<CKRecord*>*)records;
- (void)selectRecord:(CKRecord*)record;

- (CKPointAnnotation*)locationToAnnotation:(CKRecord*)location;

- (void)showAnnotations:(NSArray<CKPointAnnotation*>*)annotations;
- (void)selectAnnotation:(CKPointAnnotation*)annotation;
- (void)showAllAnnotations;

- (void)returnToMap;
- (void)selectTag:(NSString*)tag;

@end
