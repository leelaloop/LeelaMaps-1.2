//
//  IntroControllerViewController.m
//  Leela Maps
//
//  Created by Gregory Hazel on 12/16/17.
//  Copyright © 2017 Leela Maps. All rights reserved.
//

#import "IntroViewController.h"

@interface IntroViewController () <UIPageViewControllerDelegate, UIPageViewControllerDataSource>
@property (nonatomic) NSMutableArray<UIViewController*> *pages;
@property (nonatomic, weak) UIViewController *pendingPage;
@property (nonatomic) UIButton *button;
@end

@implementation IntroViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = UIColor.blackColor;
    self.dataSource = self;
    self.delegate = self;

    _pages = NSMutableArray.array;
    for (NSString *n in @[@"page1", @"page2", @"page3", @"page4", @"page5", @"page6", @"page7"]) {
        UIViewController *page = UIViewController.new;
        UIImageView *i = [UIImageView.alloc initWithImage:[UIImage imageNamed:n]];
        i.contentMode = UIViewContentModeScaleAspectFill;
        [i addGestureRecognizer:[UITapGestureRecognizer.alloc initWithTarget:self action:@selector(nextPage)]];
        i.userInteractionEnabled = YES;
        i.translatesAutoresizingMaskIntoConstraints = NO;
        [page.view addSubview:i];
        UILayoutGuide *guide = page.view.safeAreaLayoutGuide;
        [NSLayoutConstraint activateConstraints:@[
            [NSLayoutConstraint
             constraintWithItem:i.superview
             attribute:NSLayoutAttributeCenterX
             relatedBy:NSLayoutRelationEqual
             toItem:i
             attribute:NSLayoutAttributeCenterX
             multiplier:1.0
             constant:0.0],
            [i.topAnchor constraintEqualToSystemSpacingBelowAnchor:guide.topAnchor multiplier:1],
            [guide.bottomAnchor constraintEqualToSystemSpacingBelowAnchor:i.bottomAnchor multiplier:1]
        ]];
        [_pages addObject:page];
    }

    _button = [UIButton buttonWithType:UIButtonTypeCustom];
    _button.translatesAutoresizingMaskIntoConstraints = NO;
    [_button addTarget:self action:@selector(buttonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_button];

    UILayoutGuide *margins = self.view.layoutMarginsGuide;
    [NSLayoutConstraint activateConstraints:@[[_button.trailingAnchor constraintEqualToAnchor:margins.trailingAnchor]]];
    UILayoutGuide *guide = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
                                              [guide.bottomAnchor constraintEqualToSystemSpacingBelowAnchor:_button.bottomAnchor multiplier:1.0]
                                              ]];
    
    UIPageControl.appearance.pageIndicatorTintColor = UIColor.grayColor;
    UIPageControl.appearance.currentPageIndicatorTintColor = UIColor.whiteColor;
    UIPageControl.appearance.backgroundColor = UIColor.clearColor;
    
    self.page = 0;
}

- (void)setPage:(NSInteger)i
{
    __weak typeof(self) weakSelf = self;
    NSArray<UIViewController*> *previous = [self.viewControllers copy];
    [self.delegate pageViewController:self willTransitionToViewControllers:@[_pages[i]]];
    [self setViewControllers:@[_pages[i]]
                   direction:UIPageViewControllerNavigationDirectionForward
                    animated:YES
                  completion:^(BOOL finished) {
                      [weakSelf.delegate pageViewController:weakSelf
                                         didFinishAnimating:finished
                                    previousViewControllers:previous
                                        transitionCompleted:finished];
                  }];

}

- (void)nextPage
{
    NSInteger i = [_pages indexOfObject:self.viewControllers.lastObject];
    if (i >= _pages.count - 1) {
        return;
    }
    self.page = i + 1;
}

- (void)buttonTapped
{
    [NSUserDefaults.standardUserDefaults setBool:YES forKey:@"intro"];
    [UIView transitionWithView:UIApplication.sharedApplication.delegate.window
                      duration:0.5
                       options:UIViewAnimationOptionTransitionFlipFromLeft
                    animations:^{
                        UIApplication.sharedApplication.delegate.window.rootViewController = [self.storyboard instantiateInitialViewController];
                        [UIApplication.sharedApplication.delegate.window makeKeyAndVisible];
                    }
                    completion:nil];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self.view bringSubviewToFront:_button];
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

#pragma mark Page Indicator

- (NSInteger)presentationCountForPageViewController:(UIPageViewController *)pageViewController
{
    return _pages.count;
}

- (NSInteger)presentationIndexForPageViewController:(UIPageViewController *)pageViewController
{
    return [_pages indexOfObject:self.viewControllers.firstObject];
}

#pragma mark Page View Controller Delegate

- (nullable UIViewController *)pageViewController:(nonnull UIPageViewController *)pageViewController viewControllerAfterViewController:(nonnull UIViewController *)viewController {
    NSInteger i = [_pages indexOfObject:viewController] + 1;
    if (i >= _pages.count) {
        return nil;
    }
    return _pages[i];
}

- (nullable UIViewController *)pageViewController:(nonnull UIPageViewController *)pageViewController viewControllerBeforeViewController:(nonnull UIViewController *)viewController {
    NSInteger i = [_pages indexOfObject:viewController] - 1;
    if (i < 0) {
        return nil;
    }
    return _pages[i];
}

- (void)pageViewController:(UIPageViewController *)pageViewController willTransitionToViewControllers:(NSArray<UIViewController *> *)pendingViewControllers
{
    _pendingPage = pendingViewControllers.firstObject;
}

- (void)pageViewController:(UIPageViewController *)pageViewController didFinishAnimating:(BOOL)finished previousViewControllers:(NSArray<UIViewController *> *)previousViewControllers transitionCompleted:(BOOL)completed
{
    if (completed) {
        if (_pendingPage == _pages.lastObject) {
            [_button setTitle:@"Done" forState:UIControlStateNormal];
        } else {
            [_button setTitle:@"Skip" forState:UIControlStateNormal];
        }
    }
}

@end
