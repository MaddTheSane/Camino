/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* ***** BEGIN LICENSE BLOCK *****
* Version: NPL 1.1/GPL 2.0/LGPL 2.1
*
* The contents of this file are subject to the Netscape Public License
* Version 1.1 (the "License"); you may not use this file except in
* compliance with the License. You may obtain a copy of the License at
* http://www.mozilla.org/NPL/
*
* Software distributed under the License is distributed on an "AS IS" basis,
* WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
* for the specific language governing rights and limitations under the
* License.
*
* The Original Code is mozilla.org code.
*
* The Initial Developer of the Original Code is
* Netscape Communications Corporation.
* Portions created by the Initial Developer are Copyright (C) 2002
* the Initial Developer. All Rights Reserved.
*
* Contributor(s):
*    Simon Fraser <sfraser@netscape.com>
*
* Alternatively, the contents of this file may be used under the terms of
* either the GNU General Public License Version 2 or later (the "GPL"), or
* the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
* in which case the provisions of the GPL or the LGPL are applicable instead
* of those above. If you wish to allow use of your version of this file only
* under the terms of either the GPL or the LGPL, and not to allow others to
* use your version of this file under the terms of the NPL, indicate your
* decision by deleting the provisions above and replace them with the notice
* and other provisions required by the GPL or the LGPL. If you do not delete
* the provisions above, a recipient may use your version of this file under
* the terms of any one of the NPL, the GPL or the LGPL.
*
* ***** END LICENSE BLOCK ***** */

#import "NSMenu+Utils.h"

#import "HistoryItem.h"
#import "HistoryDataSource.h"

#import "ExtendedOutlineView.h"
#import "PreferenceManager.h"
#import "BrowserWindowController.h"
#import "BookmarkViewController.h"

#import "HistoryOutlineViewDelegate.h"

// sort popup menu items
enum
{
  kGroupingItemsTagMask     = (1 << 16),
  kGroupByDateItemTag       = 1,
  kGroupBySiteItemTag       = 2,
  kNoGroupingItemTag        = 3,
  
  kSortByItemsTagMask       = (1 << 17),
  kSortBySiteItemTag        = 1,
  kSortByURLItemTag         = 2,
  kSortByFirstVisitItemTag  = 3,
  kSortByLastVisitItemTag   = 4,
  
  kSortOrderItemsTagMask    = (1 << 18),
  kSortAscendingItemTag     = 1,
  kSortDescendingItemTag    = 2
};

@interface HistoryOutlineViewDelegate(Private)

- (void)historyChanged:(NSNotification *)notification;
- (HistoryDataSource*)historyDataSource;
- (NSArray*)selectedItems;
- (void)recursiveDeleteItem:(HistoryItem*)item;
- (void)saveViewToPrefs;
- (void)updateSortMenuState;
- (BOOL)anyHistorySiteItemsSelected;

- (int)tagForSortColumnIdentifier:(NSString*)identifier;
- (NSString*)sortColumnIdentifierForTag:(int)tag;

- (int)tagForGrouping:(NSString*)grouping;
- (NSString*)groupingForTag:(int)tag;

- (int)tagForSortOrder:(BOOL)sortDescending;

@end

@implementation HistoryOutlineViewDelegate

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super dealloc];
}

- (void)awakeFromNib
{
  // register for history change notifications. note that we only observe our data
  // source, as there may be more than one.
  [[NSNotificationCenter defaultCenter] addObserver:self
                                        selector:@selector(historyChanged:)
                                        name:kNotificationNameHistoryDataSourceChanged object:[self historyDataSource]];
}

- (void)setBrowserWindowController:(BrowserWindowController*)bwController
{
  mBrowserWindowController = bwController;
}

- (void)historyViewMadeVisible:(BOOL)visible
{
  if (visible)
  {
    if (!mHistoryLoaded)
    {
      NSString* historyView = [[NSUserDefaults standardUserDefaults] stringForKey:@"History View"];
      if (historyView)
        [[self historyDataSource] setHistoryView:historyView];

      [[self historyDataSource] loadLazily];
      
      if (![mHistoryOutlineView sortColumnIdentifier])
      {
        // these forward to the data source
        [mHistoryOutlineView setSortColumnIdentifier:@"last_visit"];
        [mHistoryOutlineView setSortDescending:YES];
      }
            
      mHistoryLoaded = YES;
    }
    
    mUpdatesDisabled = NO;
    [mHistoryOutlineView reloadData];
    [self updateSortMenuState];
  }
  else
  {
    mUpdatesDisabled = YES;
  }
}

- (void)searchFor:(NSString*)searchString inFieldWithTag:(int)tag
{
  [[self historyDataSource] searchFor:searchString inFieldWithTag:tag];
}

- (void)clearSearchResults
{
  [mBookmarksViewController resetSearchField];
  [[self historyDataSource] clearSearchResults];
}

#pragma mark -

- (IBAction)openHistoryItem:(id)sender
{  
  int index = [mHistoryOutlineView selectedRow];
  if (index == -1) return;

  id item = [mHistoryOutlineView itemAtRow:index];
  if (!item) return;

  if ([mHistoryOutlineView isExpandable:item])
  {
    if ([mHistoryOutlineView isItemExpanded: item])
      [mHistoryOutlineView collapseItem:item];
    else
      [mHistoryOutlineView expandItem:item];
  }
  else
  {
    // The history view obeys the app preference for cmd-click -> open in new window or tab
    if (![item isSiteItem]) return;

    NSString* url = [item url];
    BOOL loadInBackground = [[PreferenceManager sharedInstance] getBooleanPref:"browser.tabs.loadInBackground" withSuccess:NULL];
    if (GetCurrentKeyModifiers() & cmdKey)
    {
      if ([[PreferenceManager sharedInstance] getBooleanPref:"browser.tabs.opentabfor.middleclick" withSuccess:NULL])
        [mBrowserWindowController openNewTabWithURL:url referrer:nil loadInBackground:loadInBackground allowPopups:NO];
      else
        [mBrowserWindowController openNewWindowWithURL:url referrer: nil loadInBackground:loadInBackground allowPopups:NO];
    }
    else
      [[mBrowserWindowController getBrowserWrapper] loadURI:url referrer:nil flags:NSLoadFlagsNone activate:YES allowPopups:NO];
  }
}

- (IBAction)deleteHistoryItems:(id)sender
{
  int index = [mHistoryOutlineView selectedRow];
  if (index == -1)
    return;

  // If just 1 row was selected, keep it so the user can delete again immediately
  BOOL clearSelectionWhenDone = ([mHistoryOutlineView numberOfSelectedRows] > 1);
  
  // make a list of doomed items first so the rows don't change under us
  NSArray* doomedItems = [self selectedItems];

  // to avoid potentially many updates, disabled auto updating
  mUpdatesDisabled = YES;
  
  // catch exceptions to make sure we turn updating back on
  NS_DURING
    NSEnumerator* itemsEnum = [doomedItems objectEnumerator];
    HistoryItem* curItem;
    while ((curItem = [itemsEnum nextObject]))
    {
      [self recursiveDeleteItem:curItem];
    }
  NS_HANDLER
  NS_ENDHANDLER
  
  if (clearSelectionWhenDone)
    [mHistoryOutlineView deselectAll:self];

  mUpdatesDisabled = NO;
  [mHistoryOutlineView reloadData];
}


// called from context menu, assumes represented object has been set
- (IBAction)openHistoryItemInNewWindow:(id)aSender
{
  NSArray* itemsArray = [self selectedItems];

  BOOL backgroundLoad = [[PreferenceManager sharedInstance] getBooleanPref:"browser.tabs.loadInBackground" withSuccess:NULL];

  NSEnumerator* itemsEnum = [itemsArray objectEnumerator];
  HistoryItem* curItem;
  while ((curItem = [itemsEnum nextObject]))
  {
    if ([curItem isKindOfClass:[HistorySiteItem class]])
      [mBrowserWindowController openNewWindowWithURL:[curItem url] referrer:nil loadInBackground:backgroundLoad allowPopups:NO];
  }
}

// called from context menu, assumes represented object has been set
- (IBAction)openHistoryItemInNewTab:(id)aSender
{
  NSArray* itemsArray = [self selectedItems];

  BOOL backgroundLoad = [[PreferenceManager sharedInstance] getBooleanPref:"browser.tabs.loadInBackground" withSuccess:NULL];

  NSEnumerator* itemsEnum = [itemsArray objectEnumerator];
  HistoryItem* curItem;
  while ((curItem = [itemsEnum nextObject]))
  {
    if ([curItem isKindOfClass:[HistorySiteItem class]])
      [mBrowserWindowController openNewTabWithURL:[curItem url] referrer:nil loadInBackground:backgroundLoad allowPopups:NO];
  }
}

#pragma mark -

- (IBAction)groupByDate:(id)sender
{
  [self clearSearchResults];
  [[self historyDataSource] setHistoryView:kHistoryViewByDate];
  [self updateSortMenuState];
  [self saveViewToPrefs];
}

- (IBAction)groupBySite:(id)sender
{
  [self clearSearchResults];
  [[self historyDataSource] setHistoryView:kHistoryViewBySite];
  [self updateSortMenuState];
  [self saveViewToPrefs];
}

- (IBAction)setNoGrouping:(id)sender
{
  [self clearSearchResults];
  [[self historyDataSource] setHistoryView:kHistoryViewFlat];
  [self updateSortMenuState];
  [self saveViewToPrefs];
}

- (IBAction)sortBy:(id)sender
{
  [mHistoryOutlineView setSortColumnIdentifier:[self sortColumnIdentifierForTag:[sender tagRemovingMask:kSortByItemsTagMask]]];
  [self updateSortMenuState];
}

- (IBAction)sortAscending:(id)sender
{
  [mHistoryOutlineView setSortDescending:NO];
  [self updateSortMenuState];
}

- (IBAction)sortDescending:(id)sender
{
  [mHistoryOutlineView setSortDescending:YES];
  [self updateSortMenuState];
}

#pragma mark -

// maybe we can push some of this logic down into the ExtendedOutlineView
- (void)outlineView:(NSOutlineView *)outlineView didClickTableColumn:(NSTableColumn *)tableColumn
{
  if ([[mHistoryOutlineView sortColumnIdentifier] isEqualToString:[tableColumn identifier]])
  {
    [mHistoryOutlineView setSortDescending:![mHistoryOutlineView sortDescending]];
  }
  else
  {
    [mHistoryOutlineView setSortColumnIdentifier:[tableColumn identifier]];
  }

  [self updateSortMenuState];
}

- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(NSCell *)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
  if ([[tableColumn identifier] isEqualToString:@"title"])
    [cell setImage:[item icon]];
}

#if 0
// implementing this makes NSOutlineView updates much slower (because of all the hover region maintenance)
- (NSString *)outlineView:(NSOutlineView *)outlineView tooltipStringForItem:(id)item
{
  return nil;
}
#endif

- (NSMenu *)outlineView:(NSOutlineView *)outlineView contextMenuForItem:(id)item
{
  HistoryItem* historyItem = (HistoryItem*)item;
  if (![historyItem isKindOfClass:[HistorySiteItem class]])
    return nil;

  return mOutlinerContextMenu;
}

#pragma mark -

- (BOOL)validateMenuItem:(id <NSMenuItem>)menuItem
{
  SEL action = [menuItem action];

  if (action == @selector(openHistoryItem:))
    return [self anyHistorySiteItemsSelected];

  if (action == @selector(openHistoryItemInNewWindow:))
    return [self anyHistorySiteItemsSelected];

  if (action == @selector(openHistoryItemInNewTab:))
    return [self anyHistorySiteItemsSelected];

  if (action == @selector(deleteHistoryItems:))
    return [self anyHistorySiteItemsSelected];

  return YES;
}

- (void)historyChanged:(NSNotification *)notification
{
  if (mUpdatesDisabled) return;

  id rootChangedItem   = [[notification userInfo] objectForKey:kNotificationHistoryDataSourceChangedUserInfoChangedItem];
  BOOL itemOnlyChanged = [[[notification userInfo] objectForKey:kNotificationHistoryDataSourceChangedUserInfoChangedItemOnly] boolValue];

  if (rootChangedItem)
    [mHistoryOutlineView reloadItem:rootChangedItem reloadChildren:!itemOnlyChanged];
  else
    [mHistoryOutlineView reloadData];
}

- (NSArray*)selectedItems
{
  NSMutableArray* itemsArray = [NSMutableArray arrayWithCapacity:[mHistoryOutlineView numberOfSelectedRows]];
  
#if 0
  // XXX selectedRowEnumerator seems to have a bug where it is empty if the first item
  // in the table is selected. work around that here
  if ([mHistoryOutlineView selectedRow] == 0)
  {
    HistoryItem * item = [mHistoryOutlineView itemAtRow:0];
    [itemsArray addObject:item];
  }
  else
#endif
  {
    NSEnumerator* rowEnum = [mHistoryOutlineView selectedRowEnumerator];
    int currentRow;
    while ((currentRow = [[rowEnum nextObject] intValue]))
    {
      HistoryItem * item = [mHistoryOutlineView itemAtRow:currentRow];
      [itemsArray addObject:item];
    }
  }
  
  return itemsArray;
}

- (void)recursiveDeleteItem:(HistoryItem*)item
{
  if ([item isKindOfClass:[HistorySiteItem class]])
  {
    [[self historyDataSource] removeItem:(HistorySiteItem*)item];
  }
  else if ([item isKindOfClass:[HistoryCategoryItem class]])
  {
    // clone the child list to avoid it changing under us
    NSArray* itemChildren = [NSArray arrayWithArray:[item children]];
    
    NSEnumerator* childEnum = [itemChildren objectEnumerator];
    HistoryItem* childItem;
    while ((childItem = [childEnum nextObject]))
    {
      [self recursiveDeleteItem:childItem];
    }
  }
}

- (HistoryDataSource*)historyDataSource
{
  return (HistoryDataSource*)[mHistoryOutlineView dataSource];
}

- (void)saveViewToPrefs
{
  NSString* historyView = [[self historyDataSource] historyView];
  [[NSUserDefaults standardUserDefaults] setObject:historyView forKey:@"History View"];
}

- (BOOL)anyHistorySiteItemsSelected
{
  NSEnumerator* rowEnum = [mHistoryOutlineView selectedRowEnumerator];
  int currentRow;
  while ((currentRow = [[rowEnum nextObject] intValue]))
  {
    HistoryItem * item = [mHistoryOutlineView itemAtRow:currentRow];
    if ([item isKindOfClass:[HistorySiteItem class]])
      return YES;
  }
  return NO;
}

- (void)updateSortMenuState
{
  HistoryDataSource* dataSource = [self historyDataSource];
  
  // grouping items
  [mHistorySortMenu checkItemWithTag:[self tagForGrouping:[dataSource historyView]] inGroupWithMask:kGroupingItemsTagMask];

  // sorting items
  [mHistorySortMenu checkItemWithTag:[self tagForSortColumnIdentifier:[dataSource sortColumnIdentifier]] inGroupWithMask:kSortByItemsTagMask];

  // ascending/descending
  [mHistorySortMenu checkItemWithTag:[self tagForSortOrder:[dataSource sortDescending]] inGroupWithMask:kSortOrderItemsTagMask];
}


- (int)tagForSortColumnIdentifier:(NSString*)identifier
{
  if ([identifier isEqualToString:@"last_visit"])
    return kSortByLastVisitItemTag;

  if ([identifier isEqualToString:@"first_visit"])
    return kSortByFirstVisitItemTag;

  if ([identifier isEqualToString:@"title"])
    return kSortBySiteItemTag;

  if ([identifier isEqualToString:@"url"])
    return kSortByURLItemTag;
    
  return 0;
}

// tag should be unmasked
- (NSString*)sortColumnIdentifierForTag:(int)tag
{
  switch (tag)
  {
    case kSortBySiteItemTag:         return @"title";
    case kSortByURLItemTag:          return @"url";
    case kSortByFirstVisitItemTag:   return @"first_visit";
    default:
    case kSortByLastVisitItemTag:    return @"last_visit";
  }
  return @""; // quiet warning
}

- (int)tagForGrouping:(NSString*)grouping
{
  if ([grouping isEqualToString:kHistoryViewByDate])
    return kGroupByDateItemTag;
  else if ([grouping isEqualToString:kHistoryViewBySite])
    return kGroupBySiteItemTag;
  else
    return kNoGroupingItemTag;
}

// tag should be unmasked
- (NSString*)groupingForTag:(int)tag
{
  switch (tag)
  {
    default:
    case kGroupByDateItemTag:   return kHistoryViewByDate;
    case kGroupBySiteItemTag:   return kHistoryViewBySite;
    case kNoGroupingItemTag:    return kHistoryViewFlat;
  }
  return @""; // quiet warning
}

- (int)tagForSortOrder:(BOOL)sortDescending
{
  return (sortDescending) ? kSortDescendingItemTag : kSortAscendingItemTag;
}

@end
