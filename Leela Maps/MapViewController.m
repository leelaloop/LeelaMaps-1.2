//
//  MapViewController.m
//  Leela Maps
//
//  Created by Gregory Hazel on 10/25/17.
//  Copyright © 2017 Leela Maps. All rights reserved.
//

#import "MapViewController.h"
#import "AppDelegate.h"
#import "SearchTable.h"
#import "LocationViewController.h"
#import "LocationEditViewController.h"
#import "PullUpViewController.h"
#import "TwitterText/TwitterText.h"

@import CloudKit;
@import MapKit;


@implementation CKPointAnnotation

- (void)loadShare:(void (^)(NSError *error))complete
{
    if (!_location.share || _share) {
        if (complete) {
            complete(nil);
        }
        return;
    }
    // async, but hopefully faster than the user
    [CKContainer.defaultContainer.privateCloudDatabase fetchRecordWithID:_location.share.recordID completionHandler:^(CKRecord *record, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.share = (CKShare *)record;
            if (complete) {
                complete(error);
            }
        });
    }];
}

@end

@interface MapViewController () <CLLocationManagerDelegate, MKMapViewDelegate, UISearchBarDelegate, UITextFieldDelegate, ISHPullUpStateDelegate>
@property (strong, nonatomic) CLLocationManager *locationManager;
@property (weak, nonatomic) IBOutlet ISHHoverBar *hoverbar;
@property (nonatomic) UIBarButtonItem *addButton;
@property (nonatomic) CKPointAnnotation *selectedAnnotation;
@end

@implementation MapViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [AppDelegate getUserInfo:nil];

    _locationManager = CLLocationManager.new;
    _locationManager.delegate = self;
    _locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    [_locationManager requestWhenInUseAuthorization];

    _mapView.delegate = self;
    _mapView.showsCompass = true;

    CLLocation *location = _locationManager.location;
    if (location) {
        NSLog(@"existing location:%@", location);
        MKCoordinateSpan span = MKCoordinateSpanMake(0.05, 0.05);
        MKCoordinateRegion region = {.center = location.coordinate, .span = span};
        [_mapView setRegion:region animated:NO];
    } else {
        [_locationManager requestLocation];
    }

    MKUserTrackingBarButtonItem *mapBarButton = [MKUserTrackingBarButtonItem.alloc initWithMapView:self.mapView];
    UIImage *image = [UIImage systemImageNamed:@"plus"];
    UIBarButtonItem *addBarButton = [UIBarButtonItem.alloc initWithImage:image style:UIBarButtonItemStylePlain target:self action:@selector(addLocation)];
    [_hoverbar setItems:@[mapBarButton, addBarButton]];
}

- (void)didMoveToParentViewController:(UIViewController*)parent
{
    SearchTable *searchTable = (SearchTable*)[self.storyboard instantiateViewControllerWithIdentifier:@"SearchTable"];
    searchTable.mapView = self;
    _searchController = [UISearchController.alloc initWithSearchResultsController:searchTable];
    _searchController.searchResultsUpdater = searchTable;
    _searchController.searchBar.delegate = self;
    _searchController.searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
    [_searchController.searchBar sizeToFit];
    _searchController.searchBar.placeholder = @"Search for tags or a place";
    self.searchView.navigationItem.titleView = _searchController.searchBar;
    _searchController.hidesNavigationBarDuringPresentation = false;
    _searchController.obscuresBackgroundDuringPresentation = true;
    _searchController.automaticallyShowsSearchResultsController = false;
    _searchController.showsSearchResultsController = true;
    self.searchView.definesPresentationContext = true;
    _addButton = self.searchView.navigationItem.rightBarButtonItem;
    if (!self.searchView.location) {
        self.searchView.navigationItem.rightBarButtonItem = nil;
    }
    self.pullUpViewController.stateDelegate = self;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.pullUpViewController setState:ISHPullUpStateIntermediate animated:NO];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    _mapView.layoutMargins = UIEdgeInsetsMake(8 + _hoverbar.frame.size.height + 8, 0, 0, 8);

    if (!_searchController.presentingViewController) {
        [self.searchView presentViewController:_searchController animated:YES completion:nil];
    }
}

- (void)pullUpViewController:(ISHPullUpViewController *)pullUpViewController didChangeToState:(ISHPullUpState)state
{
    switch (state) {
    case ISHPullUpStateExpanded:
    case ISHPullUpStateDragging:
        break;
    case ISHPullUpStateCollapsed:
    case ISHPullUpStateIntermediate:
        [_searchController.searchBar endEditing:YES];
        break;
    }
}

- (PullUpViewController*)pullUpViewController
{
    return (PullUpViewController*)self.parentViewController;
}

- (UINavigationController*)searchNavView
{
    return self.pullUpViewController.bottomViewController.childViewControllers.firstObject;
}

- (LocationViewController*)searchView
{
    return self.searchNavView.childViewControllers.firstObject;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (CLLocation*)center
{
    return [CLLocation.alloc initWithLatitude:_mapView.centerCoordinate.latitude
                                    longitude:_mapView.centerCoordinate.longitude];
}

- (void)addLocation
{
    [self performSegueWithIdentifier:@"add" sender:self];
}

/*
 *  locationManager:didChangeAuthorizationStatus:
 *
 *  Discussion:
 *    Invoked when the authorization status changes for this application.
 */
- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    if (status >= kCLAuthorizationStatusAuthorizedAlways) {
        [manager requestLocation];
    }
}

/*
 *  locationManager:didUpdateLocations:
 *
 *  Discussion:
 *    Invoked when new locations are available.  Required for delivery of
 *    deferred locations.  If implemented, updates will
 *    not be delivered to locationManager:didUpdateToLocation:fromLocation:
 *
 *    locations is an array of CLLocation objects in chronological order.
 */
- (void)locationManager:(CLLocationManager *)manager
     didUpdateLocations:(NSArray<CLLocation *> *)locations
{
    if (_mapView.annotations.count > 1) {
        return;
    }
    // center the map and re-submit the search to get new results
    for (CLLocation *location in locations) {
        NSLog(@"location:%@", location);
        MKCoordinateSpan span = MKCoordinateSpanMake(0.05, 0.05);
        MKCoordinateRegion region = {.center = location.coordinate, .span = span};
        [_mapView setRegion:region animated:NO];
    }
    SearchTable *s = (SearchTable*)_searchController.searchResultsUpdater;
    [s updateSearchResultsForSearchController:_searchController];
}

/*
 *  locationManager:didFailWithError:
 *
 *  Discussion:
 *    Invoked when an error has occurred. Error types are defined in "CLError.h".
 */
- (void)locationManager:(CLLocationManager *)manager
       didFailWithError:(NSError *)error
{
    NSLog(@"locationManager:%@ didFailWithError:%@", manager, error);
}

- (CKPointAnnotation*)locationToAnnotation:(CKRecord*)location
{
    assert([location.recordType isEqualToString:@"Location"]);
    CKPointAnnotation *ca = CKPointAnnotation.new;
    ca.title = location[@"name"];
    ca.location = location;
    //ca = l[@"address"];
    ca.coordinate = ((CLLocation*)location[@"location"]).coordinate;
    [ca loadShare:^(NSError *error) {
    }];
    return ca;
}

- (void)showRecords:(NSArray<CKRecord*>*)records
{
    NSMutableArray<CKPointAnnotation*> *annotations = NSMutableArray.array;
    for (CKRecord *r in records) {
        if ([r.recordType isEqualToString:@"Location"]) {
            [annotations addObject:[self locationToAnnotation:r]];
        }
    }
    [self showAnnotations:annotations];
}

- (void)selectRecord:(CKRecord*)record
{
    [_searchController.searchBar endEditing:YES];
    for (id<MKAnnotation> annotation in _mapView.annotations) {
        if ([annotation isKindOfClass:CKPointAnnotation.class]) {
            CKPointAnnotation *ca = (CKPointAnnotation*)annotation;
            if ([ca.location.recordChangeTag isEqualToString:record.recordChangeTag]) {
                [_mapView showAnnotations:@[ca] animated:YES];
                [self selectAnnotation:ca];
                return;
            }
        }
    }
    CKPointAnnotation *ca = [self locationToAnnotation:record];
    [self showAnnotations:@[ca]];
    [self selectAnnotation:ca];
}

- (void)returnToMap
{
    [_searchController.searchBar endEditing:YES];
    [self.searchNavView popToRootViewControllerAnimated:YES];

    SearchTable *s = (SearchTable*)_searchController.searchResultsUpdater;
    [s updateSearchResultsForSearchController:_searchController];
}

- (void)selectTag:(NSString*)tag
{
    [_searchController.searchBar endEditing:YES];
    [self.searchNavView popToRootViewControllerAnimated:YES];

    UISearchToken *tagToken = [UISearchToken tokenWithIcon:nil text:tag];
    tagToken.representedObject = tag;
    _searchController.searchBar.text = @"";
    [_searchController.searchBar.searchTextField insertToken:tagToken atIndex:_searchController.searchBar.searchTextField.tokens.count];
}

- (void)showAllAnnotations
{
    NSMutableArray<id<MKAnnotation>> *annotations = NSMutableArray.array;
    for (id<MKAnnotation> annotation in _mapView.annotations) {
        if ([annotation isKindOfClass:MKUserLocation.class]) {
            continue;
        }
        [annotations addObject:annotation];
    }
    [_mapView showAnnotations:annotations animated:YES];
}

- (void)showAnnotations:(NSArray<CKPointAnnotation*>*)annotations
{
    [_mapView removeAnnotations:_mapView.annotations];
    for (id<MKAnnotation> annotation in _mapView.selectedAnnotations) {
        [_mapView deselectAnnotation:annotation animated:NO];
    }
    for (CKPointAnnotation *annotation in annotations) {
        [_mapView addAnnotation:annotation];
    }
    [self showAllAnnotations];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar
{
    self.searchView.navigationItem.rightBarButtonItem = nil;
    [self.pullUpViewController setState:ISHPullUpStateExpanded animated:YES];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar
{
    [self tagify:searchBar];
    [self.pullUpViewController setState:ISHPullUpStateIntermediate animated:YES];
    SearchTable *s = (SearchTable*)_searchController.searchResultsUpdater;
    [s updateSearchResultsForSearchController:_searchController];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    [_searchController.searchBar endEditing:YES];
    [self.pullUpViewController setState:ISHPullUpStateCollapsed animated:YES];
}

- (void)tagify:(UISearchBar *)searchBar
{
    NSString *text = searchBar.text;
    NSArray *entities = [TwitterText entitiesInText:text];
    __block NSUInteger index = searchBar.searchTextField.tokens.count;
    for (TwitterTextEntity *obj in entities) {
        if (obj.type == TwitterTextEntityHashtag) {
            NSString *tag = [text substringWithRange:obj.range];
            //NSLog(@"%@ %@", NSStringFromRange(obj.range), tag);
            UISearchToken *tagToken = [UISearchToken tokenWithIcon:nil text:tag];
            tagToken.representedObject = tag;

            NSRange range = obj.range;
            id<UITextInput> textView = searchBar.searchTextField;
            UITextPosition *beginning = searchBar.searchTextField.textualRange.start;
            UITextPosition *start = [textView positionFromPosition:beginning offset:range.location];
            UITextPosition *end = [textView positionFromPosition:start offset:range.length];
            UITextRange *textRange = [textView textRangeFromPosition:start toPosition:end];

            // avoid making a tag out of a word being typed
            if (searchBar.searchTextField.editing && range.location + range.length == text.length) {
                return;
            }

            [searchBar.searchTextField replaceTextualPortionOfRange:textRange withToken:tagToken atIndex:index];
            searchBar.text = [searchBar.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            index++;
        }
    }
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    [self tagify:searchBar];
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id <MKAnnotation>)annotation
{
    if (![annotation isKindOfClass:CKPointAnnotation.class]) {
        return nil;
    }
    MKMarkerAnnotationView *mav = (MKMarkerAnnotationView*)[mapView dequeueReusableAnnotationViewWithIdentifier:@"mark"];
    if (!mav) {
        mav = [MKMarkerAnnotationView.alloc initWithAnnotation:annotation reuseIdentifier:@"mark"];
    }
    mav.annotation = annotation;
    CKPointAnnotation *ca = (CKPointAnnotation*)annotation;
    if (!ca.location.share) {
        mav.markerTintColor = UIColor.systemBlueColor;
    } else {
        mav.markerTintColor = UIColor.systemGreenColor;
        [ca loadShare:^(NSError *error) {
            if (ca.share.publicPermission == CKShareParticipantPermissionNone) {
                mav.markerTintColor = UIColor.systemRedColor;
            }
        }];
    }
    mav.displayPriority = _selectedAnnotation == ca ? MKFeatureDisplayPriorityRequired : MKFeatureDisplayPriorityDefaultLow;
    mav.clusteringIdentifier = @"cluster";
    return mav;
}

- (MKClusterAnnotation *)mapView:(MKMapView *)mapView clusterAnnotationForMemberAnnotations:(NSArray<id<MKAnnotation>> *)memberAnnotations
{
    return [MKClusterAnnotation.alloc initWithMemberAnnotations:memberAnnotations];
}

- (void)mapView:(MKMapView *)mapView didSelectAnnotationView:(MKAnnotationView *)view
{
    id<MKAnnotation> a = view.annotation;
    if ([a isKindOfClass:MKClusterAnnotation.class]) {
        MKClusterAnnotation *ca = (MKClusterAnnotation*)a;
        NSLog(@"didSelectAnnotationView %@", ca.memberAnnotations);
        NSMutableArray<CKRecord*> *records = NSMutableArray.array;
        for (id<MKAnnotation> annotation in ca.memberAnnotations) {
            CKPointAnnotation *pa = (CKPointAnnotation*)annotation;
            [records addObject:pa.location];
        }
        [self.pullUpViewController setState:ISHPullUpStateIntermediate animated:YES];
        SearchTable *s = (SearchTable*)_searchController.searchResultsUpdater;
        [s showRecords:records];
        UINavigationController *n = self.searchNavView;
        [n popToRootViewControllerAnimated:NO];
        if (!_searchController.presentingViewController) {
            [self.searchView presentViewController:_searchController animated:YES completion:nil];
        }
    } else if ([a isKindOfClass:CKPointAnnotation.class]) {
        CKPointAnnotation *pa = (CKPointAnnotation*)a;
        NSLog(@"didSelectAnnotationView %@", pa.location);
        [self.pullUpViewController setState:ISHPullUpStateIntermediate animated:YES];
        _selectedAnnotation = pa;
        [pa loadShare:^(NSError *error) {
            LocationViewController *p = [self.storyboard instantiateViewControllerWithIdentifier:@"LocationViewController"];
            p.location = pa.location;
            p.share = pa.share;
            p.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
            p.modalPresentationStyle = UIModalPresentationOverCurrentContext;
            UINavigationController *n = self.searchNavView;

            // a temporary blur background to make the push animation less ugly
            UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleProminent];
            UIVisualEffectView *blurEffectView = [UIVisualEffectView.alloc initWithEffect:blurEffect];
            blurEffectView.frame = p.view.frame;
            [p.view insertSubview:blurEffectView atIndex:0];

            [n popToRootViewControllerAnimated:NO];
            [n pushViewController:p animated:YES];

            [n.transitionCoordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
                [blurEffectView removeFromSuperview];
            }];
        }];
    }
}

- (void)selectAnnotation:(CKPointAnnotation*)ca
{
    NSLog(@"selectAnnotation %@", ca.location);
    [self.pullUpViewController setState:ISHPullUpStateIntermediate animated:YES];
    // re-add for priority change
    [_mapView removeAnnotation:ca];
    _selectedAnnotation = ca;
    [_mapView addAnnotation:ca];
    [_mapView selectAnnotation:ca animated:YES];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    NSLog(@"segue:%@ sender:%@", segue, sender);
    if ([segue.identifier isEqualToString:@"add"]) {
    }
}

@end
