//
//  LocationViewController.m
//  Leela Maps
//
//  Created by Gregory Hazel on 11/5/17.
//  Copyright © 2017 Leela Maps. All rights reserved.
//

#import "LocationViewController.h"
#import "AppDelegate.h"
#import "NSAttributedString+Twitterify.h"
#import "LocationEditViewController.h"
#import "MapViewController.h"
#import "SearchTable.h"

@import CoreLocation;
@import MessageUI;


@interface LocationViewController () <UICloudSharingControllerDelegate, UIPopoverPresentationControllerDelegate, UITextViewDelegate, MFMailComposeViewControllerDelegate>
@property (weak, nonatomic) IBOutlet UITextView *address;
@property (weak, nonatomic) IBOutlet UITextView *desc;
@property (weak, nonatomic) IBOutlet UIButton *owner;
@property (weak, nonatomic) IBOutlet UILabel *memberList;
@property (weak, nonatomic) IBOutlet UILabel *instructions;
@property (nonatomic) BOOL selectingTag;
@end

@implementation LocationViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = nil;
    _address.text = nil;
    _desc.text = nil;
    [_owner setTitle:nil forState:UIControlStateNormal];
    _memberList.text = nil;
    _instructions.text = nil;
    self.location = _location;
    self.share = _share;
}

-(void)willMoveToParentViewController:(UIViewController *)parent {
    [super willMoveToParentViewController:parent];
    if (!parent && !_selectingTag) {
        AppDelegate *a = (AppDelegate*)UIApplication.sharedApplication.delegate;
        MapViewController *m = a.mapViewController;
        [m showAllAnnotations];
    }
}

- (void)updateBarButton
{
    if (!_location) {
        self.navigationItem.rightBarButtonItem = nil;
        return;
    }
    self.navigationItem.rightBarButtonItems = @[[UIBarButtonItem.alloc initWithImage:[UIImage imageNamed:@"ellipsis.circle"]
                                                                               style:UIBarButtonItemStylePlain
                                                                              target:self
                                                                              action:@selector(more:)],
                                                [UIBarButtonItem.alloc initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                                                                            target:self
                                                                                            action:@selector(share:)]
                                                ];
}

- (void)setLocation:(CKRecord*)location
{
    _location = location;
    self.title = _location[@"name"];
    _address.text = _location[@"address"];
    _desc.text = _location[@"desc"];
    _desc.attributedText = [_desc.attributedText twitterify:_desc.tintColor];
    if (!location) {
        [_owner setTitle:nil forState:UIControlStateNormal];
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
                NSString *name = [NSPersonNameComponentsFormatter
                                  localizedStringFromPersonNameComponents:userInfo.nameComponents
                                  style:NSPersonNameComponentsFormatterStyleDefault
                                  options:0];
                [self.owner setTitle:name forState:UIControlStateNormal];
            });
        }];
    }
    _instructions.text = _location[@"instructions"];
    [self updateBarButton];
}

- (void)setShare:(CKShare *)share
{
    _share = share;
    NSMutableArray *a = NSMutableArray.array;
    for (CKShareParticipant *p in _share.participants) {
        if (p.role == CKShareParticipantRoleOwner) {
            continue;
        }
        [a addObject:[NSPersonNameComponentsFormatter localizedStringFromPersonNameComponents:p.userIdentity.nameComponents
                                                                                        style:NSPersonNameComponentsFormatterStyleDefault
                                                                                      options:0]];
    }
    _memberList.text = [a componentsJoinedByString:@"\n"];
    [self updateBarButton];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)textView:(UITextView *)textView shouldInteractWithURL:(NSURL *)URL inRange:(NSRange)characterRange interaction:(UITextItemInteraction)interaction
{
    NSLog(@"%@", URL);
    if ([URL.absoluteString hasPrefix:@"#"]) {
        AppDelegate *a = (AppDelegate*)UIApplication.sharedApplication.delegate;
        MapViewController *m = a.mapViewController;
        _selectingTag = YES;
        [m selectTag:URL.absoluteString];
        _selectingTag = NO;
        return NO;
    }
    return YES;
}

- (void)cloudSharingControllerDidSaveShare:(UICloudSharingController *)csc
{
    NSLog(@"cloudSharingControllerDidSaveShare:%@", csc);
    [csc dismissViewControllerAnimated:YES completion:nil];
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
    return _location[@"name"];
}

- (nullable NSData *)itemThumbnailDataForCloudSharingController:(UICloudSharingController *)csc
{
    return [NSDataAsset.alloc initWithName:@"Thumbnail"].data;
}

- (nullable NSString *)itemTypeForCloudSharingController:(UICloudSharingController *)csc
{
    return @"com.leelamaps.location";
}

- (UICloudSharingController*)newShareController
{
    __block UICloudSharingController *s = [UICloudSharingController.alloc initWithPreparationHandler:^(UICloudSharingController * _Nonnull controller, void (^ _Nonnull preparationCompletionHandler)(CKShare * _Nullable, CKContainer * _Nullable, NSError * _Nullable)) {
        CKShare *share = [CKShare.alloc initWithRootRecord:self.location];
        share[CKShareTitleKey] = [self itemTitleForCloudSharingController:s];
        share[CKShareThumbnailImageDataKey] = [self itemThumbnailDataForCloudSharingController:s];
        share[CKShareTypeKey] = [self itemTypeForCloudSharingController:s];
        CKModifyRecordsOperation *modifyOp = [CKModifyRecordsOperation.alloc initWithRecordsToSave:@[self.location, share]
                                                                                 recordIDsToDelete:nil];
        modifyOp.modifyRecordsCompletionBlock = ^(NSArray<CKRecord *> * _Nullable savedRecords, NSArray<CKRecordID *> * _Nullable deletedRecordIDs, NSError * _Nullable operationError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSLog(@"modifyOp error:%@ savedRecords:%@", operationError, savedRecords);
                preparationCompletionHandler(share, CKContainer.defaultContainer, operationError);
                NSLog(@"publicPermissions:%d", (int)share.publicPermission);
                NSLog(@"url:%@", share.URL);
                self.share = share;
            });
        };
        [CKContainer.defaultContainer.privateCloudDatabase addOperation:modifyOp];
    }];
    return s;
}

- (UICloudSharingController*)updateShareController
{
    return [UICloudSharingController.alloc initWithShare:_share container:CKContainer.defaultContainer];
}

- (IBAction)edit:(id)sender
{
    UINavigationController *v = [self.storyboard instantiateViewControllerWithIdentifier:@"LocationEditNav"];
    LocationEditViewController *l = v.viewControllers.firstObject;
    l.location = _location;
    l.share = _share;
    [self presentViewController:v animated:YES completion:nil];
}

- (IBAction)share:(id)sender
{
    UICloudSharingController *s;
    if (_share) {
        s = [self updateShareController];
    } else {
        s = [self newShareController];
    }
    s.delegate = self;
    s.popoverPresentationController.barButtonItem = sender;
    [self presentViewController:s animated:YES completion:nil];
}

- (IBAction)more:(id)sender
{
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:self.title
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    alert.popoverPresentationController.barButtonItem = sender;

    UIAlertAction* reportAction = [UIAlertAction actionWithTitle:@"Report"
                                                            style:UIAlertActionStyleDestructive
                                                          handler:^(UIAlertAction * action) {

        MFMailComposeViewController* composeVC = MFMailComposeViewController.new;
        composeVC.mailComposeDelegate = self;
        [composeVC setToRecipients:@[@"moderation@leelamaps.com"]];
        [composeVC setSubject:[NSString stringWithFormat:@"Report for '%@'", self.title]];
        [composeVC setMessageBody:[NSString stringWithFormat:@"Hi Leela Maps Team,<br><br><br><br><br><br><small style='color :#d3d3d3'>recordName %@<br>zoneID %@:%@</small>",
                                   self.location.recordID.recordName,
                                   self.location.recordID.zoneID.zoneName,
                                   self.location.recordID.zoneID.ownerName] isHTML:YES];
        [self presentViewController:composeVC animated:YES completion:nil];
    }];
    [alert addAction:reportAction];
    if (_share.currentUserParticipant.permission == CKShareParticipantPermissionReadWrite ||
        (!_share && [_location.creatorUserRecordID.recordName isEqualToString:CKCurrentUserDefaultName])) {
        [alert addAction:[UIAlertAction actionWithTitle:@"Edit" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
            [self edit:nil];
        }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
    UINavigationController *v = [self.storyboard instantiateViewControllerWithIdentifier:@"LocationEditNav"];
    LocationEditViewController *l = v.viewControllers.firstObject;
    l.location = _location;
    l.share = _share;
    [self presentViewController:v animated:YES completion:nil];
}

- (void)mailComposeController:(MFMailComposeViewController *)controller
         didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error {
    // Check the result or perform other tasks.

    // Dismiss the mail compose view controller.
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)ownerTapped:(id)sender {
    UIButton *owner = sender;
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:owner.currentTitle
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    alert.popoverPresentationController.sourceView = sender;

    UIAlertAction* blockAction = [UIAlertAction actionWithTitle:@"Block"
                                                            style:UIAlertActionStyleDestructive
                                                          handler:^(UIAlertAction * action) {
        UIAlertController* confirm = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"Block %@", owner.currentTitle]
                                                                         message:[NSString stringWithFormat:@"Are you sure you want to block %@?", owner.currentTitle]
                                                                  preferredStyle:UIAlertControllerStyleAlert];
        confirm.popoverPresentationController.sourceView = sender;
        [confirm addAction:[UIAlertAction actionWithTitle:@"Block"
                                                  style:UIAlertActionStyleDestructive
                                                handler:^(UIAlertAction * action) {

            // XXX: should use NSUbiquitousKeyValueStore.defaultStore instead of NSUserDefaults.standardUserDefaults,
            // but then we'd need a way to unblock a user
            NSArray *blockedUsers = [NSUserDefaults.standardUserDefaults arrayForKey:@"blockedUsers"];
            if (!blockedUsers) {
                blockedUsers = @[self->_location.creatorUserRecordID.recordName];
            } else {
                NSMutableSet *set = [NSMutableSet setWithArray:blockedUsers];
                [set addObject:self->_location.creatorUserRecordID.recordName];
                blockedUsers = set.allObjects;
            }
            [NSUserDefaults.standardUserDefaults setObject:blockedUsers forKey:@"blockedUsers"];
            AppDelegate *a = (AppDelegate*)UIApplication.sharedApplication.delegate;
            MapViewController *m = a.mapViewController;
            [m returnToMap];
         }]];
         [confirm addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
         [self presentViewController:confirm animated:YES completion:nil];
    }];
    [alert addAction:blockAction];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}


@end
