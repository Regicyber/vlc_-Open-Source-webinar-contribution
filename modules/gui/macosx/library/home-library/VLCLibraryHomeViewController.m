/*****************************************************************************
 * VLCLibraryHomeViewController.m: MacOS X interface module
 *****************************************************************************
 * Copyright (C) 2023 VLC authors and VideoLAN
 *
 * Authors: Claudio Cambra <developer@claudiocambra.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/

#import "VLCLibraryHomeViewController.h"

#import "extensions/NSString+Helpers.h"

#import "library/VLCLibraryController.h"
#import "library/VLCLibraryModel.h"
#import "library/VLCLibraryTableCellView.h"
#import "library/VLCLibraryUIUnits.h"
#import "library/VLCLibraryWindow.h"
#import "library/VLCLibraryWindowPersistentPreferences.h"

#import "library/audio-library/VLCLibraryAudioViewController.h"

#import "library/home-library/VLCLibraryHomeViewStackViewController.h"
#import "library/home-library/VLCLibraryHomeViewVideoContainerViewDataSource.h"

#import "library/video-library/VLCLibraryVideoDataSource.h"
#import "library/video-library/VLCLibraryVideoTableViewDelegate.h"
#import "library/video-library/VLCLibraryVideoViewController.h"

#import "main/VLCMain.h"

#import "windows/video/VLCMainVideoViewController.h"

@interface VLCLibraryHomeViewController ()
{
    id<VLCMediaLibraryItemProtocol> _awaitingPresentingLibraryItem;
}
@end

@implementation VLCLibraryHomeViewController

- (instancetype)initWithLibraryWindow:(VLCLibraryWindow *)libraryWindow
{
    self = [super init];

    if(self) {
        [self setupPropertiesFromLibraryWindow:libraryWindow];
        [self setupGridViewController];
        [self setupHomePlaceholderView];
        [self setupHomeLibraryViews];

        NSNotificationCenter *notificationCenter = NSNotificationCenter.defaultCenter;
        [notificationCenter addObserver:self
                               selector:@selector(libraryModelUpdated:)
                                   name:VLCLibraryModelVideoMediaListReset
                                 object:nil];
        [notificationCenter addObserver:self
                               selector:@selector(libraryModelUpdated:)
                                   name:VLCLibraryModelVideoMediaItemDeleted
                                 object:nil];
        // TODO: Hook up audio signals
    }

    return self;
}

- (void)setupPropertiesFromLibraryWindow:(VLCLibraryWindow *)libraryWindow
{
    NSParameterAssert(libraryWindow);
    _libraryWindow = libraryWindow;
    _libraryTargetView = libraryWindow.libraryTargetView;
    _homeLibraryView = libraryWindow.homeLibraryView;
    _homeLibraryStackViewScrollView = libraryWindow.homeLibraryStackViewScrollView;
    _homeLibraryStackView = libraryWindow.homeLibraryStackView;

    _segmentedTitleControl = libraryWindow.segmentedTitleControl;
    _placeholderImageView = libraryWindow.placeholderImageView;
    _placeholderLabel = libraryWindow.placeholderLabel;
    _emptyLibraryView = libraryWindow.emptyLibraryView;
}

- (void)setupGridViewController
{
    _stackViewController = [[VLCLibraryHomeViewStackViewController alloc] init];
    self.stackViewController.collectionsStackViewScrollView = _homeLibraryStackViewScrollView;
    self.stackViewController.collectionsStackView = _homeLibraryStackView;
}

- (void)setupHomePlaceholderView
{
    _homePlaceholderImageViewSizeConstraints = @[
        [NSLayoutConstraint constraintWithItem:_placeholderImageView
                                     attribute:NSLayoutAttributeWidth
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:nil
                                     attribute:NSLayoutAttributeNotAnAttribute
                                    multiplier:0.f
                                      constant:182.f],
        [NSLayoutConstraint constraintWithItem:_placeholderImageView
                                     attribute:NSLayoutAttributeHeight
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:nil
                                     attribute:NSLayoutAttributeNotAnAttribute
                                    multiplier:0.f
                                      constant:114.f],
    ];
}

- (void)setupHomeLibraryViews
{
    const NSEdgeInsets defaultInsets = VLCLibraryUIUnits.libraryViewScrollViewContentInsets;
    const NSEdgeInsets scrollerInsets = VLCLibraryUIUnits.libraryViewScrollViewScrollerInsets;

    self.homeLibraryStackViewScrollView.automaticallyAdjustsContentInsets = NO;
    self.homeLibraryStackViewScrollView.contentInsets = defaultInsets;
    self.homeLibraryStackViewScrollView.scrollerInsets = scrollerInsets;
}

#pragma mark - Show the video library view

- (void)updatePresentedView
{
    if (VLCMain.sharedInstance.libraryController.libraryModel.numberOfVideoMedia == 0) { // empty library
        [self presentPlaceholderHomeLibraryView];
    } else {
        [self presentHomeLibraryView];
    }
}

- (void)presentHomeView
{
    self.libraryTargetView.subviews = @[];
    [self updatePresentedView];
}

- (void)presentPlaceholderHomeLibraryView
{
    NSArray<NSLayoutConstraint *> * const audioPlaceholderConstraints = self.libraryWindow.libraryAudioViewController.audioPlaceholderImageViewSizeConstraints;
    for (NSLayoutConstraint * const constraint in audioPlaceholderConstraints) {
        constraint.active = NO;
    }
    NSArray<NSLayoutConstraint *> * const videoPlaceholderConstraints = self.libraryWindow.libraryVideoViewController.videoPlaceholderImageViewSizeConstraints;
    for (NSLayoutConstraint * const constraint in videoPlaceholderConstraints) {
        constraint.active = NO;
    }
    for (NSLayoutConstraint *constraint in self.homePlaceholderImageViewSizeConstraints) {
        constraint.active = YES;
    }

    self.emptyLibraryView.translatesAutoresizingMaskIntoConstraints = NO;
    self.libraryTargetView.subviews = @[self.emptyLibraryView];
    NSDictionary * const dict = NSDictionaryOfVariableBindings(_emptyLibraryView);
    [self.libraryTargetView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_emptyLibraryView(>=572.)]|" options:0 metrics:0 views:dict]];
    [self.libraryTargetView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[_emptyLibraryView(>=444.)]|" options:0 metrics:0 views:dict]];

    self.placeholderImageView.image = [NSImage imageNamed:@"placeholder-video"];
    self.placeholderLabel.stringValue = _NS("Your favorite videos will appear here.\nGo to the Browse section to add videos you love.");
}

- (void)presentHomeLibraryView
{
    self.homeLibraryView.translatesAutoresizingMaskIntoConstraints = NO;
    self.libraryTargetView.subviews = @[self.homeLibraryView];

    NSDictionary * const dict = NSDictionaryOfVariableBindings(_homeLibraryView);
    [self.libraryTargetView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_homeLibraryView(>=572.)]|" options:0 metrics:0 views:dict]];
    [self.libraryTargetView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[_homeLibraryView(>=444.)]|" options:0 metrics:0 views:dict]];

    const VLCLibraryViewModeSegment viewModeSegment = VLCLibraryWindowPersistentPreferences.sharedInstance.homeLibraryViewMode;

    self.homeLibraryStackViewScrollView.hidden = NO;
    [self.stackViewController reloadData];
}

- (void)libraryModelUpdated:(NSNotification *)aNotification
{
    NSParameterAssert(aNotification);
    VLCLibraryModel * const model = VLCMain.sharedInstance.libraryController.libraryModel;
    const NSUInteger videoCount = model.numberOfVideoMedia;

    NSArray<NSView *> * const targetViewSubViews = self.libraryTargetView.subviews;
    if (self.segmentedTitleControl.selectedSegment == VLCLibraryHomeSegment &&
        ((videoCount == 0 && ![targetViewSubViews containsObject:self.emptyLibraryView]) ||
         (videoCount > 0 && ![targetViewSubViews containsObject:self.homeLibraryView])) &&
        _libraryWindow.videoViewController.view.hidden) {

        [self updatePresentedView];
    }
}

@end
