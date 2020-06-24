//
//  SearchTable.m
//  Leela Maps
//
//  Created by Gregory Hazel on 10/25/17.
//  Copyright © 2017 Leela Maps. All rights reserved.
//

#import "SearchTable.h"
#import "NSMapTable+Subscripting.h"
#import "PullUpViewController.h"

@import CloudKit;


@interface NSArray (Map)
- (NSArray*)map:(id (^)(id obj))block;
- (NSArray*)mapKey:(NSString*)key;
@end

@implementation NSArray (Map)
- (NSArray*)map:(id (^)(id obj))block {
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:self.count];
    for (id obj in self) {
        [result addObject:block(obj)];
    }
    return result;
}

- (NSArray*)mapKey:(NSString*)key {
    return [self map:^id(id obj) {
        return obj[key];
    }];
}
@end

@interface SearchTable ()
@property (nonatomic) NSArray<CKRecord*> *results;
@end

@implementation SearchTable

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)queueChanges:(NSArray<CKRecord*>*)oldData newData:(NSArray<CKRecord*>*)newData
{
    // map of new positions
    NSMapTable<NSString*, NSNumber*> *newMap = NSMapTable.strongToStrongObjectsMapTable;
    for (NSUInteger i = 0; i < newData.count; i++) {
        newMap[newData[i].recordChangeTag] = @(i);
    }

    // compute moves and deletes
    NSMutableArray *deleteIndexPaths = NSMutableArray.array;
    for (NSInteger i = oldData.count - 1; i >= 0; i--) {
        NSString *k = oldData[i].recordChangeTag;
        NSNumber *newIndex = newMap[k];
        if (newIndex) {
            [self.tableView moveRowAtIndexPath:[NSIndexPath indexPathForItem:i inSection:0]
                                   toIndexPath:[NSIndexPath indexPathForItem:newIndex.integerValue inSection:0]];
            newMap[k] = nil;
        } else {
            [deleteIndexPaths addObject:[NSIndexPath indexPathForItem:i inSection:0]];
        }
    }
    [self.tableView deleteRowsAtIndexPaths:deleteIndexPaths withRowAnimation:UITableViewRowAnimationAutomatic];

    // compute inserts
    NSMutableArray *insertIndexPaths = NSMutableArray.array;
    for (NSInteger i = newData.count - 1; i >= 0; i--) {
        if (newMap[newData[i].recordChangeTag]) {
            [insertIndexPaths addObject:[NSIndexPath indexPathForItem:i inSection:0]];
        }
    }
    [self.tableView insertRowsAtIndexPaths:insertIndexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (CLLocationDegrees)wrap:(CLLocationDegrees)value minimumValue:(CLLocationDegrees)minimumValue maximumValue:(CLLocationDegrees)maximumValue
{
    CLLocationDegrees d = maximumValue - minimumValue;
    return fmod((fmod((value - minimumValue), d) + d), d) + minimumValue;
}

- (NSPredicate*)nearbyPredicate
{
    CLLocationDegrees lat1 = [self wrap:_mapView.mapView.region.center.latitude + _mapView.mapView.region.span.latitudeDelta
                           minimumValue:-90
                           maximumValue:90];
    CLLocationDegrees lng1 = _mapView.mapView.region.center.longitude;
    CLLocationDegrees lat2 = _mapView.mapView.region.center.latitude;
    CLLocationDegrees lng2 = [self wrap:_mapView.mapView.region.center.longitude + _mapView.mapView.region.span.longitudeDelta
                           minimumValue:-180
                           maximumValue:180];

    CLLocation *loc1 = [CLLocation.alloc initWithLatitude:lat1 longitude:lng1];
    CLLocation *loc2 = [CLLocation.alloc initWithLatitude:lat2 longitude:lng2];
    CLLocationDistance distance1 = [_mapView.center distanceFromLocation:loc1];
    CLLocationDistance distance2 = [_mapView.center distanceFromLocation:loc2];
    CLLocationDistance radius = MIN(distance1, distance2) / 3;
    radius = MAX(radius, 1 * 1000);

    return [NSPredicate predicateWithFormat:@"distanceToLocation:fromLocation:(location, %@) < %f", _mapView.center, radius];
}

- (void)showRecords:(NSArray<CKRecord*>*)records
{
    NSSet *blockUsers = [NSSet setWithArray:[NSUserDefaults.standardUserDefaults arrayForKey:@"blockedUsers"]];
    records = [records filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(CKRecord *object, NSDictionary *bindings) {
        return ![blockUsers containsObject:object.creatorUserRecordID.recordName];
    }]];
    [self.tableView performBatchUpdates:^{
        NSArray<CKRecord*> *oldResults = self.results;
        self.results = records;
        [self queueChanges:oldResults newData:self.results];
    } completion:^(BOOL finished) {
        if (!self.mapView.searchController.searchBar.searchTextField.editing) {
            [self.mapView showRecords:self.results];
        }
    }];
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController
{
    NSLog(@"updateSearchResultsForSearchController");
    // to limit network activity, reload half a second after last key press.
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(reload:) object:searchController];
    [self performSelector:@selector(reload:) withObject:searchController afterDelay:0.3];
}

- (void)reload:(UISearchController *)searchController
{
    NSLog(@"reload");

    dispatch_group_t group = dispatch_group_create();
    NSMutableArray<CKRecord*> *records = NSMutableArray.array;

    NSString *q = searchController.searchBar.text;

    if (!q.length && !searchController.searchBar.searchTextField.tokens.count) {
        // default search of all places
        [self search:self.nearbyPredicate includePublic:YES records:records group:group];
        dispatch_group_notify(group, dispatch_get_main_queue(), ^{
            [self showRecords:[self uniqueRecords:records]];
        });
        return;
    }

    NSLog(@"q:%@ tags:%@", q, [searchController.searchBar.searchTextField.tokens map:^id(UISearchToken *obj) {
        return obj.representedObject;
    }]);
    q = [q stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"#"]];
    CKDatabase *publicDatabase = CKContainer.defaultContainer.publicCloudDatabase;

    NSMutableArray<NSPredicate*> *predicates = NSMutableArray.array;
    for (UISearchToken *t in searchController.searchBar.searchTextField.tokens) {
        NSString *tag = t.representedObject;
        [predicates addObject:[NSPredicate predicateWithFormat:@"self CONTAINS %@", tag]];
    }
    if (predicates.count) {
        [self search:[NSCompoundPredicate andPredicateWithSubpredicates:predicates] includePublic:YES records:records group:group];
    }

    NSMutableArray<CKRecord*> *tagRecords = NSMutableArray.array;
    if (q.length) {
        {
            NSPredicate *tagPredicate = [NSPredicate predicateWithFormat:@"name BEGINSWITH %@", [NSString stringWithFormat:@"#%@", q]];
            CKQuery *query = [CKQuery.alloc initWithRecordType:@"Tag" predicate:tagPredicate];
            query.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]];
            NSLog(@"query:%@", query);
            dispatch_group_enter(group);
            [publicDatabase performQuery:query inZoneWithID:nil completionHandler:^(NSArray *results, NSError *error) {
                NSLog(@"tag results: %@ error: %@", [results mapKey:@"name"], error);
                [tagRecords addObjectsFromArray:results];
                dispatch_group_leave(group);
            }];
        }

        {
            NSPredicate *tagPredicate = [NSPredicate predicateWithFormat:@"self contains %@", [NSString stringWithFormat:@"#%@", q]];
            CKQuery *query = [CKQuery.alloc initWithRecordType:@"Tag" predicate:tagPredicate];
            query.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]];
            NSLog(@"query:%@", query);
            dispatch_group_enter(group);
            [publicDatabase performQuery:query inZoneWithID:nil completionHandler:^(NSArray *results, NSError *error) {
                NSLog(@"tag results: %@ error: %@", [results mapKey:@"name"], error);
                [tagRecords addObjectsFromArray:results];
                dispatch_group_leave(group);
            }];
        }

        [self search:[NSPredicate predicateWithFormat:@"name BEGINSWITH %@", q] includePublic:YES records:records group:group];
        [self search:[NSPredicate predicateWithFormat:@"self CONTAINS %@", q] includePublic:YES records:records group:group];
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSArray *u = [self uniqueRecords:records];
        u = [u sortedArrayUsingDescriptors:@[[CKLocationSortDescriptor.alloc
                                              initWithKey:@"location"
                                              relativeLocation:self.mapView.center]]];
        [tagRecords addObjectsFromArray:u];
        [self showRecords:[self uniqueRecords:tagRecords]];
    });
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _results.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    CKRecord *r = _results[indexPath.row];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:r.recordType forIndexPath:indexPath];
    cell.textLabel.text = r[@"name"];
    return cell;
}

- (PullUpViewController*)pullUpViewController
{
    return (PullUpViewController*)_mapView.pullUpViewController;
}

- (NSArray*)uniqueRecords:(NSArray*)records
{
    NSMutableSet *s = NSMutableSet.new;
    return [records filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        CKRecord *r = (CKRecord*)evaluatedObject;
        if ([s containsObject:r.recordChangeTag]) {
            return false;
        }
        [s addObject:r.recordChangeTag];
        return true;
    }]];
}

- (void)search:(NSPredicate*)predicate includePublic:(BOOL)includePublic records:(NSMutableArray<CKRecord*>*)records group:(dispatch_group_t)group
{
    NSCompoundPredicate *predicates = [NSCompoundPredicate andPredicateWithSubpredicates:@[predicate, self.nearbyPredicate]];
    CKQuery *query = [CKQuery.alloc initWithRecordType:@"Location" predicate:predicates];
    query.sortDescriptors = @[[CKLocationSortDescriptor.alloc initWithKey:@"location" relativeLocation:_mapView.center]];
    NSLog(@"query:%@", query);

    CKDatabase *privateDatabase = CKContainer.defaultContainer.privateCloudDatabase;
    dispatch_group_enter(group);
    [privateDatabase performQuery:query inZoneWithID:nil completionHandler:^(NSArray *results, NSError *error) {
        NSLog(@"priv loc results: %lu error: %@", results.count, error);
        [records addObjectsFromArray:results];
        dispatch_group_leave(group);
    }];

    if (includePublic) {
        CKDatabase *publicDatabase = CKContainer.defaultContainer.publicCloudDatabase;
        dispatch_group_enter(group);
        [publicDatabase performQuery:query inZoneWithID:nil completionHandler:^(NSArray *results, NSError *error) {
            NSLog(@"pub loc results: %lu error: %@", results.count, error);
            [records addObjectsFromArray:results];
            dispatch_group_leave(group);
        }];
    }

    CKDatabase *sharedDatabase = CKContainer.defaultContainer.sharedCloudDatabase;
    dispatch_group_enter(group);
    [sharedDatabase fetchAllRecordZonesWithCompletionHandler:^(NSArray<CKRecordZone *> * _Nullable zones, NSError * _Nullable error) {
        for (CKRecordZone *zone in zones) {
            dispatch_group_enter(group);
            [sharedDatabase performQuery:query inZoneWithID:zone.zoneID completionHandler:^(NSArray *results, NSError *error) {
                NSLog(@"share loc results: %lu error: %@", results.count, error);
                [records addObjectsFromArray:results];
                dispatch_group_leave(group);
            }];
        }
        dispatch_group_leave(group);
    }];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    CKRecord *r = _results[indexPath.row];
    if ([r.recordType isEqualToString:@"Location"]) {
        [self.pullUpViewController setState:ISHPullUpStateIntermediate animated:YES];
        [_mapView selectRecord:r];
        return;
    }
    [_mapView selectTag:r[@"name"]];
}

@end

