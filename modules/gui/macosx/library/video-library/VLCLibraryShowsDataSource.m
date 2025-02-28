/*****************************************************************************
 * VLCLibraryShowsDataSource.m: MacOS X interface module
 *****************************************************************************
 * Copyright (C) 2024 VLC authors and VideoLAN
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

#import "VLCLibraryShowsDataSource.h"

#import "extensions/NSPasteboardItem+VLCAdditions.h"

#import "library/VLCLibraryCollectionViewItem.h"
#import "library/VLCLibraryCollectionViewFlowLayout.h"
#import "library/VLCLibraryCollectionViewMediaItemSupplementaryDetailView.h"
#import "library/VLCLibraryCollectionViewSupplementaryElementView.h"
#import "library/VLCLibraryModel.h"
#import "library/VLCLibraryRepresentedItem.h"

@interface VLCLibraryShowsDataSource ()

@property (readwrite, atomic) NSArray<VLCMediaLibraryShow *> *showsArray;

@end

@implementation VLCLibraryShowsDataSource

- (instancetype)init
{
    self = [super init];
    if(self) {
        [self connect];
    }
    return self;
}

- (void)connect
{
    NSNotificationCenter * const notificationCenter = NSNotificationCenter.defaultCenter;

    [notificationCenter addObserver:self
                           selector:@selector(libraryModelShowsListReset:)
                               name:VLCLibraryModelListOfShowsReset
                             object:nil];

    [self reloadData];
}

- (void)disconnect
{
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)libraryModelShowsListReset:(NSNotification *)notification
{
    [self reloadData];
}

- (void)reloadData
{
    [(VLCLibraryCollectionViewFlowLayout *)self.collectionView.collectionViewLayout resetLayout];

    self.showsArray = self.libraryModel.listOfShows;

    [self.showsTableView reloadData];
    [self.selectedShowTableView reloadData];
    [self.collectionView reloadData];
}

- (NSUInteger)indexOfMediaItem:(const NSUInteger)libraryId inArray:(NSArray const *)array
{
    return [array indexOfObjectPassingTest:^BOOL(const id<VLCMediaLibraryItemProtocol> findItem, 
                                                 const NSUInteger idx,
                                                 BOOL * const stop) {
        NSAssert(findItem != nil, @"Collection should not contain nil items");
        return findItem.libraryID == libraryId;
    }];
}

#pragma mark - table view data source and delegation

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    if (tableView == self.showsTableView) {
        return self.showsArray.count;
    } 

    const NSInteger selectedShowRow = self.showsTableView.selectedRow;
    if (tableView == self.selectedShowTableView && selectedShowRow > -1) {
        VLCMediaLibraryShow * const show = self.showsArray[selectedShowRow];
        return show.episodeCount;
    }

    return 0;
}

- (id<NSPasteboardWriting>)tableView:(NSTableView *)tableView pasteboardWriterForRow:(NSInteger)row
{
    const id<VLCMediaLibraryItemProtocol> libraryItem = [self libraryItemAtRow:row 
                                                                  forTableView:tableView];
    return [NSPasteboardItem pasteboardItemWithLibraryItem:libraryItem];
}

- (id<VLCMediaLibraryItemProtocol>)libraryItemAtRow:(NSInteger)row
                                       forTableView:(NSTableView *)tableView
{
    if (tableView == self.showsTableView) {
        return self.showsArray[row];
    }

    const NSInteger selectedShowRow = self.showsTableView.selectedRow;
    if (tableView == self.selectedShowTableView && selectedShowRow > -1) {
        VLCMediaLibraryShow * const show = self.showsArray[selectedShowRow];
        return show.episodes[row];
    }

    return nil;
}

- (NSInteger)rowForLibraryItem:(id<VLCMediaLibraryItemProtocol>)libraryItem
{
    if (libraryItem == nil) {
        return NSNotFound;
    }
    return [self indexOfMediaItem:libraryItem.libraryID inArray:self.showsArray];
}

- (VLCMediaLibraryParentGroupType)currentParentType
{
    return VLCMediaLibraryParentGroupTypeShow;
}

# pragma mark - collection view data source and delegation

- (id<VLCMediaLibraryItemProtocol>)libraryItemAtIndexPath:(NSIndexPath *)indexPath
                                        forCollectionView:(NSCollectionView *)collectionView
{
    VLCMediaLibraryShow * const show = self.showsArray[indexPath.section];
    return show.episodes[indexPath.item];
}

- (NSIndexPath *)indexPathForLibraryItem:(id<VLCMediaLibraryItemProtocol>)libraryItem
{
    __block NSInteger showEpisodeIndex = NSNotFound;
    const NSInteger showIndex = 
        [self.showsArray indexOfObjectPassingTest:^BOOL(VLCMediaLibraryShow * const show,
                                                        const NSUInteger idx,
                                                        BOOL * const stop) {
            showEpisodeIndex = 
                [show.episodes indexOfObjectPassingTest:^BOOL(VLCMediaLibraryMediaItem * const item,
                                                              const NSUInteger idx,
                                                              BOOL * const stop) {
                    return item.libraryID == libraryItem.libraryID;
                }];
            return showEpisodeIndex != NSNotFound;
        }];
    return showIndex != NSNotFound
        ? [NSIndexPath indexPathForItem:showEpisodeIndex inSection:showIndex]
        : nil;
}

- (NSArray<VLCLibraryRepresentedItem *> *)representedItemsAtIndexPaths:(NSSet<NSIndexPath *> *const)indexPaths
                                                     forCollectionView:(NSCollectionView *)collectionView
{
    NSMutableArray<VLCLibraryRepresentedItem *> * const representedItems =
        [NSMutableArray arrayWithCapacity:indexPaths.count];

    for (NSIndexPath * const indexPath in indexPaths) {
        const id<VLCMediaLibraryItemProtocol> libraryItem =
            [self libraryItemAtIndexPath:indexPath forCollectionView:collectionView];
        VLCLibraryRepresentedItem * const representedItem =
            [[VLCLibraryRepresentedItem alloc] initWithItem:libraryItem
                                                 parentType:self.currentParentType];
        [representedItems addObject:representedItem];
    }

    return representedItems;
}

- (NSInteger)numberOfSectionsInCollectionView:(NSCollectionView *)collectionView
{
    return self.showsArray.count;
}

- (NSInteger)collectionView:(NSCollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section
{
    return self.showsArray[section].episodeCount;
}

- (NSCollectionViewItem *)collectionView:(NSCollectionView *)collectionView
     itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath
{
    VLCLibraryCollectionViewItem * const viewItem = 
        [collectionView makeItemWithIdentifier:VLCLibraryCellIdentifier forIndexPath:indexPath];
    const id<VLCMediaLibraryItemProtocol> item = 
        [self libraryItemAtIndexPath:indexPath forCollectionView:collectionView];
    VLCLibraryRepresentedItem * const representedItem =
        [[VLCLibraryRepresentedItem alloc] initWithItem:item parentType:self.currentParentType];
    viewItem.representedItem = representedItem;
    return viewItem;
}

- (NSView *)collectionView:(NSCollectionView *)collectionView
viewForSupplementaryElementOfKind:(NSCollectionViewSupplementaryElementKind)kind
               atIndexPath:(NSIndexPath *)indexPath
{
    if([kind isEqualToString:NSCollectionElementKindSectionHeader]) {
        VLCLibraryCollectionViewSupplementaryElementView * const sectionHeadingView = 
            [collectionView makeSupplementaryViewOfKind:kind
                                         withIdentifier:VLCLibrarySupplementaryElementViewIdentifier
                                           forIndexPath:indexPath];
        VLCMediaLibraryShow * const show = self.showsArray[indexPath.section];
        sectionHeadingView.stringValue = show.displayString;
        return sectionHeadingView;

    } else if ([kind isEqualToString:VLCLibraryCollectionViewMediaItemSupplementaryDetailViewKind]) {
        NSString * const viewIdentifier =
            VLCLibraryCollectionViewMediaItemSupplementaryDetailViewIdentifier;
        VLCLibraryCollectionViewMediaItemSupplementaryDetailView * const mediaItemDetailView =
            [collectionView makeSupplementaryViewOfKind:kind
                                         withIdentifier:viewIdentifier
                                           forIndexPath:indexPath];
        const id<VLCMediaLibraryItemProtocol> item = [self libraryItemAtIndexPath:indexPath
                                                                forCollectionView:collectionView];
        VLCLibraryRepresentedItem * const representedItem =
            [[VLCLibraryRepresentedItem alloc] initWithItem:item parentType:self.currentParentType];

        mediaItemDetailView.representedItem = representedItem;
        mediaItemDetailView.selectedItem = [collectionView itemAtIndexPath:indexPath];
        return mediaItemDetailView;
    }

    return nil;
}

@end
