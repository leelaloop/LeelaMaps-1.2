//
//  LocationEditViewController.m
//  Leela Maps
//
//  Created by Gregory Hazel on 11/6/17.
//  Copyright © 2017 Leela Maps. All rights reserved.
//

@import CoreLocation;
@import MapKit;

#import "LocationEditViewController.h"
#import "TwitterText/TwitterText.h"
#import "NSAttributedString+Twitterify.h"
#import "AppDelegate.h"


@interface LocationEditViewController () <UICloudSharingControllerDelegate, MKMapViewDelegate>
@property (weak, nonatomic) IBOutlet UITextField *name;
@property (weak, nonatomic) IBOutlet UITextField *address;
@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (weak, nonatomic) IBOutlet UITextField *desc;
@property (weak, nonatomic) IBOutlet UILabel *owner;
@property (weak, nonatomic) IBOutlet UITextField *instructions;
@property (nonatomic) NSTimer *addressTimer;
@property (nonatomic) CLLocation *addressLocation;
@end

@implementation LocationEditViewController

- (void)viewDidLoad {
    [super viewDidLoad];
  
    CLLocationManager *locationManager = CLLocationManager.new;
    CLLocation *location = locationManager.location;
    if (location) {
        NSLog(@"existing location:%@", location);
        MKCoordinateSpan span = MKCoordinateSpanMake(0.05, 0.05);
        MKCoordinateRegion region = {.center = location.coordinate, .span = span};
        [_mapView setRegion:region animated:NO];
    }

    [AppDelegate getUserInfo:^(CKUserIdentity *userInfo, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!userInfo) {
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Sign in to iCloud"
                                                                               message:@"On the Home screen, launch Settings, tap iCloud, and enter your Apple ID."
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"Okay"
                                                          style:UIAlertActionStyleCancel
                                                        handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
            } else {
                self.owner.text = [NSPersonNameComponentsFormatter localizedStringFromPersonNameComponents:userInfo.nameComponents
                                                                                                     style:NSPersonNameComponentsFormatterStyleDefault
                                                                                                   options:0];
            }
        });
    }];
    self.location = _location;
}

- (void)setAddressLocation:(CLLocation *)addressLocation
{
    _addressLocation = addressLocation;
    if (!_addressLocation) {
        [_mapView removeAnnotations:_mapView.annotations];
        return;
    }
    MKPointAnnotation *annotation = (MKPointAnnotation *)_mapView.annotations.firstObject;
    if (!annotation) {
        annotation = MKPointAnnotation.new;
        [_mapView addAnnotation:annotation];
    }
    annotation.coordinate = _addressLocation.coordinate;
    annotation.title = _address.text;
    [_mapView showAnnotations:@[annotation] animated:YES];
}

- (void)setLocation:(CKRecord*)location
{
    _location = location;
    _name.text = _location[@"name"];
    _address.text = _location[@"address"];
    self.addressLocation = _location[@"location"];
    _desc.text = _location[@"desc"];
    _desc.attributedText = [_desc.attributedText twitterify:_desc.tintColor];
    if (!location) {
        _owner.text = nil;
    } else {
        [CKContainer.defaultContainer discoverUserIdentityWithUserRecordID:location.creatorUserRecordID completionHandler:^(CKUserIdentity * _Nullable userInfo, NSError * _Nullable error) {
            if (error) {
                NSLog(@"userInfo error: %@", error);
                return;
            }
            if (!userInfo) {
                return;
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                self.owner.text = [NSPersonNameComponentsFormatter localizedStringFromPersonNameComponents:userInfo.nameComponents
                                                                                                     style:NSPersonNameComponentsFormatterStyleDefault
                                                                                                   options:0];
            });
        }];
    }
    _instructions.text = _location[@"instructions"];
}

- (void)createLocation:(void (^)(NSError *error))complete
{
    if (_location) {
        complete(nil);
        return;
    }
    CKRecordZone *zone = [CKRecordZone.alloc initWithZoneName:@"FriendZone"];
    CKModifyRecordZonesOperation *op = [CKModifyRecordZonesOperation.alloc initWithRecordZonesToSave:@[zone] recordZoneIDsToDelete:nil];
    op.modifyRecordZonesCompletionBlock = ^(NSArray<CKRecordZone *> * _Nullable savedRecordZones, NSArray<CKRecordZoneID *> * _Nullable deletedRecordZoneIDs, NSError * _Nullable operationError) {
        if (operationError) {
            complete(operationError);
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            self.location = [CKRecord.alloc initWithRecordType:@"Location" zoneID:zone.zoneID];
            complete(nil);
        });
    };
    [CKContainer.defaultContainer.privateCloudDatabase addOperation:op];
}

- (IBAction)save:(id)sender
{
    [self.view endEditing:YES];

    UIView *overlayView = [UIView.alloc initWithFrame:UIScreen.mainScreen.bounds];
    overlayView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.5];
    UIActivityIndicatorView *activityIndicator = [UIActivityIndicatorView.alloc initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    activityIndicator.center = overlayView.center;
    [overlayView addSubview:activityIndicator];
    [self.navigationController.view addSubview:overlayView];

    UIAlertController* alert = [UIAlertController alertControllerWithTitle:nil
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    alert.popoverPresentationController.barButtonItem = sender;
    [alert addAction:[UIAlertAction actionWithTitle:@"Public"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action) {
                                                [activityIndicator startAnimating];
                                                [self publicShare:sender complete:^{
                                                    [overlayView removeFromSuperview];
                                                }];
                                            }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Shared"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action) {
                                                [activityIndicator startAnimating];
                                                [self sharedShare:sender complete:^{
                                                    [overlayView removeFromSuperview];
                                                }];
                                            }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Invite Only"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action) {
                                                [activityIndicator startAnimating];
                                                [self privateShare:sender complete:^{
                                                    [overlayView removeFromSuperview];
                                                }];
                                            }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:^(UIAlertAction * _Nonnull action) {
                                                [overlayView removeFromSuperview];
                                            }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)updateLocation
{
    _location[@"name"] = _name.text;
    _location[@"desc"] = _desc.text;
    _location[@"address"] = _address.text;
    _location[@"location"] = _addressLocation;
    _location[@"instructions"] = _instructions.text;

    NSMutableSet<NSString*> *tags = NSMutableSet.set;
    NSArray *entities = [TwitterText entitiesInText:_desc.text];
    [entities enumerateObjectsUsingBlock:^(TwitterTextEntity *obj, NSUInteger idx, BOOL *stop) {
        if (obj.type == TwitterTextEntityHashtag) {
            [tags addObject:[_desc.text substringWithRange:obj.range]];
        }
    }];
    _location[@"tags"] = tags.allObjects;
    
    NSMutableArray<CKRecord*> *tagRecords = NSMutableArray.array;
    for (NSString *tag in tags) {
        CKRecordID *tagId = [CKRecordID.alloc initWithRecordName:tag];
        CKRecord *tagr = [CKRecord.alloc initWithRecordType:@"Tag" recordID:tagId];
        tagr[@"name"] = tag;
        [tagRecords addObject:tagr];
    }
    CKModifyRecordsOperation *tagOp = [CKModifyRecordsOperation.alloc initWithRecordsToSave:tagRecords
                                                                          recordIDsToDelete:nil];
    tagOp.modifyRecordsCompletionBlock = ^(NSArray<CKRecord *> * _Nullable savedRecords, NSArray<CKRecordID *> * _Nullable deletedRecordIDs, NSError * _Nullable operationError) {
        NSLog(@"tagOp error:%@ savedRecords:%@", operationError, savedRecords);
    };
    [CKContainer.defaultContainer.publicCloudDatabase addOperation:tagOp];
}

- (IBAction)publicShare:(id)sender complete:(void (^)(void))complete
{
    if (!_location) {
        _location = [CKRecord.alloc initWithRecordType:@"Location"];
    }
    [self updateLocation];
    CKModifyRecordsOperation *modifyOp = [CKModifyRecordsOperation.alloc initWithRecordsToSave:@[_location]
                                                                             recordIDsToDelete:nil];
    modifyOp.modifyRecordsCompletionBlock = ^(NSArray<CKRecord *> * _Nullable savedRecords, NSArray<CKRecordID *> * _Nullable deletedRecordIDs, NSError * _Nullable operationError) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"modifyOp error:%@ savedRecords:%@", operationError, savedRecords);
            if (!operationError) {
                UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Saved"
                                                                               message:[NSString stringWithFormat:@"'%@' will now appear in search.", self.location[@"name"]]
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                                          style:UIAlertActionStyleDefault
                                                        handler:^(UIAlertAction * _Nonnull action) {
                                                            [self dismissViewControllerAnimated:YES completion:nil];
                                                        }]];
                [self presentViewController:alert animated:YES completion:nil];
            } else {
                UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Error"
                                                                               message:[NSString stringWithFormat:@"'%@' could not be saved:\n%@", self.location[@"name"], operationError.localizedDescription]
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                                          style:UIAlertActionStyleDefault
                                                        handler:^(UIAlertAction * _Nonnull action) {
                                                            [self dismissViewControllerAnimated:YES completion:nil];
                                                        }]];
                [self presentViewController:alert animated:YES completion:nil];
            }
            complete();
        });
    };
    [CKContainer.defaultContainer.publicCloudDatabase addOperation:modifyOp];
}

- (IBAction)sharedShare:(id)sender complete:(void (^)(void))complete
{
    [self createLocation:^(NSError *error) {
        [self updateLocation];
        CKShare *share = [CKShare.alloc initWithRootRecord:self.location];
        UICloudSharingController *csc = UICloudSharingController.new;
        share[CKShareTitleKey] = [self itemTitleForCloudSharingController:csc];
        share[CKShareThumbnailImageDataKey] = [self itemThumbnailDataForCloudSharingController:csc];
        share[CKShareTypeKey] = [self itemTypeForCloudSharingController:csc];
        share.publicPermission = CKShareParticipantPermissionReadOnly;
        CKModifyRecordsOperation *modifyOp = [CKModifyRecordsOperation.alloc initWithRecordsToSave:@[self.location, share]
                                                                                 recordIDsToDelete:nil];
        modifyOp.modifyRecordsCompletionBlock = ^(NSArray<CKRecord *> * _Nullable savedRecords, NSArray<CKRecordID *> * _Nullable deletedRecordIDs, NSError * _Nullable operationError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSLog(@"modifyOp error:%@ savedRecords:%@", operationError, savedRecords);
                NSLog(@"publicPermissions:%d", (int)share.publicPermission);
                NSLog(@"url:%@", share.URL);
                UIActivityViewController *a = [UIActivityViewController.alloc initWithActivityItems:@[share.URL] applicationActivities:nil];
                a.completionWithItemsHandler = ^(UIActivityType  _Nullable activityType, BOOL completed, NSArray * _Nullable returnedItems, NSError * _Nullable activityError) {
                    complete();
                    if (completed) {
                        [self dismissViewControllerAnimated:YES completion:nil];
                    }
                };
                [self presentViewController:a animated:YES completion:nil];
            });
        };
        [CKContainer.defaultContainer.privateCloudDatabase addOperation:modifyOp];
    }];
}

- (IBAction)privateShare:(id)sender complete:(void (^)(void))complete
{
    __block NSTimer *dismissTimer;
    dismissTimer = [NSTimer scheduledTimerWithTimeInterval:2 repeats:NO block:^(NSTimer * _Nonnull timer) {
        complete();
        dismissTimer = nil;
    }];

    if (_share) {
        [self createLocation:^(NSError *error) {
            [self updateLocation];
            CKModifyRecordsOperation *modifyOp = [CKModifyRecordsOperation.alloc initWithRecordsToSave:@[self.location]
                                                                                     recordIDsToDelete:nil];
            modifyOp.modifyRecordsCompletionBlock = ^(NSArray<CKRecord *> * _Nullable savedRecords, NSArray<CKRecordID *> * _Nullable deletedRecordIDs, NSError * _Nullable operationError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSLog(@"modifyOp error:%@ savedRecords:%@", operationError, savedRecords);

                    UICloudSharingController *s = [UICloudSharingController.alloc initWithShare:self.share container:CKContainer.defaultContainer];
                    s.availablePermissions = UICloudSharingPermissionAllowPublic | UICloudSharingPermissionAllowPrivate | UICloudSharingPermissionAllowReadOnly | UICloudSharingPermissionAllowReadWrite;
                    s.delegate = self;
                    s.popoverPresentationController.barButtonItem = sender;
                    [self presentViewController:s animated:YES completion:nil];

                    NSLog(@"publicPermissions:%d", (int)self.share.publicPermission);
                    NSLog(@"url:%@", self.share.URL);
                    if (dismissTimer) {
                        [dismissTimer invalidate];
                        dismissTimer = nil;
                        complete();
                    }
                });
            };
            [CKContainer.defaultContainer.privateCloudDatabase addOperation:modifyOp];
        }];
    } else {
        UICloudSharingController *s = [UICloudSharingController.alloc initWithPreparationHandler:^(UICloudSharingController * _Nonnull controller, void (^ _Nonnull preparationCompletionHandler)(CKShare * _Nullable, CKContainer * _Nullable, NSError * _Nullable)) {
            [self createLocation:^(NSError *error) {
                [self updateLocation];
                CKShare *share = [CKShare.alloc initWithRootRecord:self.location];
                share[CKShareTitleKey] = [self itemTitleForCloudSharingController:controller];
                share[CKShareThumbnailImageDataKey] = [self itemThumbnailDataForCloudSharingController:controller];
                share[CKShareTypeKey] = [self itemTypeForCloudSharingController:controller];
                share.publicPermission = CKShareParticipantPermissionNone;
                CKModifyRecordsOperation *modifyOp = [CKModifyRecordsOperation.alloc initWithRecordsToSave:@[self.location, share]
                                                                                         recordIDsToDelete:nil];
                modifyOp.modifyRecordsCompletionBlock = ^(NSArray<CKRecord *> * _Nullable savedRecords, NSArray<CKRecordID *> * _Nullable deletedRecordIDs, NSError * _Nullable operationError) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        NSLog(@"modifyOp error:%@ savedRecords:%@", operationError, savedRecords);
                        preparationCompletionHandler(share, CKContainer.defaultContainer, operationError);
                        NSLog(@"publicPermissions:%d", (int)share.publicPermission);
                        NSLog(@"url:%@", share.URL);
                        if (dismissTimer) {
                            [dismissTimer invalidate];
                            dismissTimer = nil;
                            complete();
                        }
                    });
                };
                [CKContainer.defaultContainer.privateCloudDatabase addOperation:modifyOp];
            }];
        }];
        s.availablePermissions = UICloudSharingPermissionAllowPublic | UICloudSharingPermissionAllowPrivate | UICloudSharingPermissionAllowReadOnly | UICloudSharingPermissionAllowReadWrite;
        s.delegate = self;
        s.popoverPresentationController.barButtonItem = sender;
        [self presentViewController:s animated:YES completion:nil];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation
{
    if ([annotation isKindOfClass:MKUserLocation.class]) {
        return nil;
    }
    MKMarkerAnnotationView *mav = (MKMarkerAnnotationView*)[mapView dequeueReusableAnnotationViewWithIdentifier:@"mark"];
    if (!mav) {
        mav = [MKMarkerAnnotationView.alloc initWithAnnotation:annotation reuseIdentifier:@"mark"];
        mav.canShowCallout = YES;
        mav.draggable = YES;
    } else {
        mav.annotation = annotation;
    }
    return mav;
}

- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)view didChangeDragState:(MKAnnotationViewDragState)newState
   fromOldState:(MKAnnotationViewDragState)oldState
{
    if (newState == MKAnnotationViewDragStateEnding) {
        _addressLocation = [CLLocation.alloc initWithCoordinate:view.annotation.coordinate
                                                       altitude:_addressLocation.altitude
                                             horizontalAccuracy:_addressLocation.horizontalAccuracy
                                               verticalAccuracy:_addressLocation.verticalAccuracy
                                                         course:_addressLocation.course
                                                          speed:_addressLocation.speed
                                                      timestamp:_addressLocation.timestamp];
        MKPointAnnotation *annotation = (MKPointAnnotation*)view.annotation;
        annotation.title = _address.text;
        annotation.subtitle = nil;
    }
}

- (IBAction)addressChanged:(id)sender
{
    [_addressTimer invalidate];
    _addressTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:NO block:^(NSTimer * _Nonnull timer) {
        MKLocalSearchRequest *request = MKLocalSearchRequest.new;
        request.naturalLanguageQuery = self.address.text;
        request.region = self.mapView.region;
        MKLocalSearch *localSearch = [MKLocalSearch.alloc initWithRequest:request];
        [localSearch startWithCompletionHandler:^(MKLocalSearchResponse *response, NSError *error) {
            if (error) {
                self.addressLocation = nil;
                return;
            }
            if (!response.mapItems.firstObject) {
                self.addressLocation = nil;
                return;
            }
            MKMapItem *item = response.mapItems.firstObject;
            self.addressLocation = item.placemark.location;
        }];
    }];
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    UITextPosition *beginning = textField.beginningOfDocument;
    UITextPosition *cursorLocation = [textField positionFromPosition:beginning offset:(range.location + string.length)];
    textField.text = [textField.text stringByReplacingCharactersInRange:range withString:string];

    textField.attributedText = [NSAttributedString.alloc initWithString:textField.text];
    textField.attributedText = [textField.attributedText twitterify:textField.tintColor];

    // cursorLocation will be (null) if you're inputting text at the end of the string
    // if already at the end, no need to change location as it will default to end anyway
    if (cursorLocation) {
        // set start/end location to same spot so that nothing is highlighted
        textField.selectedTextRange = [textField textRangeFromPosition:cursorLocation toPosition:cursorLocation];
    }
    return NO;
}

- (void)cloudSharingControllerDidSaveShare:(UICloudSharingController *)csc
{
    NSLog(@"cloudSharingControllerDidSaveShare:%@", csc);
    [csc dismissViewControllerAnimated:YES completion:^{
        [self dismissViewControllerAnimated:YES completion:nil];
    }];
}

- (void)cloudSharingControllerDidStopSharing:(UICloudSharingController *)csc
{
    NSLog(@"cloudSharingControllerDidStopSharing:%@", csc);
}

- (void)cloudSharingController:(UICloudSharingController *)csc failedToSaveShareWithError:(NSError *)error
{
    NSLog(@"failedToSaveShareWithError:%@", error);
}

- (nullable NSString *)itemTitleForCloudSharingController:(UICloudSharingController *)csc
{
    return _name.text;
}

- (nullable NSData *)itemThumbnailDataForCloudSharingController:(UICloudSharingController *)csc
{
    return [NSDataAsset.alloc initWithName:@"Thumbnail"].data;
}

- (nullable NSString *)itemTypeForCloudSharingController:(UICloudSharingController *)csc
{
    return @"com.leelamaps.location";
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
