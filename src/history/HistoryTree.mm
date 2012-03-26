/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "HistoryTree.h"

#import "NSPasteboard+Utils.h"
#import "NSString+Utils.h"

#import "BookmarkViewController.h"    // only for +greyStringWithItemCount
#import "HistoryDataSource.h"
#import "HistoryItem.h"
#import "PreferenceManager.h"

NSString* const kHistoryTreeChangedNotification = @"history_tree_changed";
NSString* const kHistoryTreeChangeRootKey       = @"history_tree_change_root";
NSString* const kHistoryTreeChangedChildrenKey  = @"history_tree_changed_children";

NSString* const kHistoryViewByDate    = @"date";
NSString* const kHistoryViewBySite    = @"site";
NSString* const kHistoryViewFlat      = @"flat";

struct SortData
{
  SEL       mSortSelector;
  NSNumber* mReverseSort;
};

static int HistoryItemSort(id firstItem, id secondItem, void* context)
{
  SortData* sortData = (SortData*)context;
  int comp = (int)[firstItem performSelector:sortData->mSortSelector withObject:secondItem withObject:sortData->mReverseSort];
  return comp;
}

#pragma mark -

// base class for a 'builder' object. This one just builds a flat list
@interface HistoryTreeBuilder : NSObject
{
  HistoryDataSource*    mDataSource;    // not retained (it owns us)
  HistoryCategoryItem*  mRootItem;      // retained
  SEL                   mSortSelector;
  BOOL                  mSortDescending;
}

// sets up the tree and sorts it
- (id)initWithDataSource:(HistoryDataSource*)inDataSource sortSelector:(SEL)sortSelector descending:(BOOL)descending;
- (void)buildTree;

- (HistoryItem*)rootItem;
- (HistoryItem*)addItem:(HistorySiteItem*)item;
- (HistoryItem*)removeItem:(HistorySiteItem*)item;

- (void)resortWithSelector:(SEL)sortSelector descending:(BOOL)descending;

// for internal use
- (void)buildTreeWithItems:(NSArray*)items;
- (void)resortFromItem:(HistoryItem*)item;

@end

@interface HistoryBySiteTreeBuilder : HistoryTreeBuilder
{
  NSMutableDictionary*    mSiteDictionary;
}

- (HistoryCategoryItem*)ensureHostCategoryForItem:(HistorySiteItem*)inItem;
- (void)removeSiteCategory:(HistoryCategoryItem*)item forHostname:(NSString*)hostname;

@end

@interface HistoryByDateTreeBuilder : HistoryTreeBuilder
{
  NSMutableArray*         mDateCategories;        // retained. array of HistoryCategoryItems ordered recent -> old
}

- (void)setUpDateCategories;
- (HistoryCategoryItem*)categoryItemForDate:(NSDate*)date;

@end

#pragma mark -
#pragma mark History Tree

@interface HistoryTree (Private)

- (HistoryItem*)addItem:(HistorySiteItem*)item;
- (HistoryItem*)removeItem:(HistorySiteItem*)item;

- (void)historyItemChanged:(NSNotification*)notification;
- (void)historyRebuilt:(NSNotification*)notification;

- (void)sortSearchResults;
- (void)rebuildSearchResults;

- (SEL)selectorForSortColumn;

- (void)sendChangeNotificationWithRoot:(HistoryItem*)root
                     includingChildren:(BOOL)childrenChanged;

// Timer callback from HistoryTimerProxy.
- (void)checkForNewDay;

@end

#pragma mark -

// This little object exists simply to avoid a ref cycle between the refresh
// timer and the history tree.
@interface HistoryTimerProxy : NSObject
{
  HistoryTree*    mHistoryTree;  // NOT owned
}

- (id)initWithHistoryTree:(HistoryTree*)historyTree;
- (void)refreshTimerFired:(NSTimer*)timer;

@end

@implementation HistoryTimerProxy

- (id)initWithHistoryTree:(HistoryTree*)historyTree
{
  if ((self = [super init])) {
    mHistoryTree = historyTree;
  }
  return self;
}

- (void)refreshTimerFired:(NSTimer*)timer
{
  [mHistoryTree checkForNewDay];
}

@end

#pragma mark -

@implementation HistoryTree

- (id)initWithDataSource:(HistoryDataSource*)dataSource
{
  if ((self = [super init])) {
    mDataSource = [dataSource retain];

    // TODO: Save last settings in prefs?
    mCurrentViewIdentifier = [kHistoryViewByDate retain];
    mSortColumn = [[NSString stringWithString:@"last_visit"] retain];
    mSortDescending = YES;

    // Set up a timer to fire every 30 secs, to refresh the dates at midnight.
    // It's done this way, rather than setting a timer to fire just after
    // midnight, to be robust against clock adjustments.
    mLastDayOfCommonEra = [[NSCalendarDate calendarDate] dayOfCommonEra];
    HistoryTimerProxy* timerProxy =
        [[[HistoryTimerProxy alloc] initWithHistoryTree:self] autorelease];
    mRefreshTimer = [[NSTimer scheduledTimerWithTimeInterval:30.0
                                                      target:timerProxy
                                                    selector:@selector(refreshTimerFired:)
                                                    userInfo:nil
                                                     repeats:YES] retain];

    NSNotificationCenter* notificationCenter = [NSNotificationCenter defaultCenter];
    // Listen for individual history item changes.
    [notificationCenter addObserver:self
                           selector:@selector(historyItemChanged:)
                               name:kHistoryDataSourceItemChangedNotification
                             object:nil];

    // Listen for history being completely rebuilt.
    [notificationCenter addObserver:self
                           selector:@selector(historyRebuilt:)
                               name:kHistoryDataSourceRebuiltNotification
                             object:nil];
  }
  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [mRefreshTimer invalidate];
  [mRefreshTimer release];
  [mTreeBuilder release];
  [mCurrentViewIdentifier release];
  [mSortColumn release];
  [mSearchString release];
  [mSearchResultsArray release];
  [mDataSource release];

  [super dealloc];
}

- (void)setHistoryView:(NSString*)inView
{
  if (![mCurrentViewIdentifier isEqualToString:inView]) {
    [mCurrentViewIdentifier release];
    mCurrentViewIdentifier = [inView retain];
    [self buildTree];
  }
}

- (NSString*)historyView
{
  return mCurrentViewIdentifier;
}

- (HistoryItem*)rootItem
{
  return [mTreeBuilder rootItem];
}

- (NSString*)sortColumnIdentifier
{
  return [[mSortColumn retain] autorelease];
}

- (void)setSortColumnIdentifier:(NSString*)sortColumnIdentifier
{
  if (![mSortColumn isEqualToString:sortColumnIdentifier]) {
    [mSortColumn release];
    mSortColumn = [sortColumnIdentifier retain];

    [mTreeBuilder resortWithSelector:[self selectorForSortColumn]
                          descending:mSortDescending];
    [self sortSearchResults];
    [self sendChangeNotificationWithRoot:nil includingChildren:YES];
  }
}

- (BOOL)sortDescending
{
  return mSortDescending;
}

- (void)setSortDescending:(BOOL)inDescending
{
  if (mSortDescending != inDescending) {
    mSortDescending = inDescending;

    [mTreeBuilder resortWithSelector:[self selectorForSortColumn]
                          descending:mSortDescending];
    [self sortSearchResults];
    [self sendChangeNotificationWithRoot:nil includingChildren:YES];
  }
}

- (void)checkForNewDay
{
  int dayOfCommonEra = [[NSCalendarDate calendarDate] dayOfCommonEra];
  if (dayOfCommonEra != mLastDayOfCommonEra) {
    [self buildTree];
    mLastDayOfCommonEra = dayOfCommonEra;
  }
}

- (SEL)selectorForSortColumn
{
  if ([mSortColumn isEqualToString:@"url"])
    return @selector(compareURL:sortDescending:);

  if ([mSortColumn isEqualToString:@"title"])
    return @selector(compareTitle:sortDescending:);

  if ([mSortColumn isEqualToString:@"first_visit"])
    return @selector(compareFirstVisitDate:sortDescending:);

  if ([mSortColumn isEqualToString:@"last_visit"])
    return @selector(compareLastVisitDate:sortDescending:);

  if ([mSortColumn isEqualToString:@"visit_count"])
    return @selector(compareVisitCount:sortDescending:);

  if ([mSortColumn isEqualToString:@"hostname"])
    return @selector(compareHostname:sortDescending:);

  return @selector(compareLastVisitDate:sortDescending:);
}

- (void)buildTree
{
  if (![mDataSource isLoaded])
    [mDataSource loadSynchronously];

  [mTreeBuilder release];
  mTreeBuilder = nil;

  if ([mCurrentViewIdentifier isEqualToString:kHistoryViewFlat]) {
    mTreeBuilder = [[HistoryTreeBuilder alloc] initWithDataSource:mDataSource
                                                     sortSelector:[self selectorForSortColumn]
                                                       descending:mSortDescending];
  }
  else if ([mCurrentViewIdentifier isEqualToString:kHistoryViewBySite]) {
    mTreeBuilder = [[HistoryBySiteTreeBuilder alloc] initWithDataSource:mDataSource
                                                           sortSelector:[self selectorForSortColumn]
                                                             descending:mSortDescending];
  }
  else {  // Default to by grouping by date.
    mTreeBuilder = [[HistoryByDateTreeBuilder alloc] initWithDataSource:mDataSource
                                                           sortSelector:[self selectorForSortColumn]
                                                             descending:mSortDescending];
  }
  [mTreeBuilder buildTree];

  [self sendChangeNotificationWithRoot:nil includingChildren:YES];
}

- (void)searchFor:(NSString*)searchString inFieldWithTag:(int)tag
{
  [mSearchString autorelease];
  mSearchString = [searchString retain];

  mSearchFieldTag = tag;

  if (!mSearchResultsArray)
    mSearchResultsArray = [[NSMutableArray alloc] initWithCapacity:100];

  [self rebuildSearchResults];
}

- (void)clearSearchResults
{
  [mSearchResultsArray release];
  mSearchResultsArray = nil;
  [mSearchString release];
  mSearchString = nil;
}

- (void)rebuildSearchResults
{
  // If mSearchResultsArray is null, we're not showing search results.
  if (!mSearchResultsArray) return;

  [mSearchResultsArray removeAllObjects];

  NSEnumerator* itemsEnumerator = [[mDataSource historyItems] objectEnumerator];
  id obj;
  while ((obj = [itemsEnumerator nextObject])) {
    if ([obj matchesString:mSearchString inFieldWithTag:mSearchFieldTag])
      [mSearchResultsArray addObject:obj];
  }

  [self sortSearchResults];
}

- (void)sortSearchResults
{
  if (!mSearchResultsArray) return;

  SortData sortData;
  sortData.mSortSelector = [self selectorForSortColumn];
  sortData.mReverseSort = [NSNumber numberWithBool:mSortDescending];

  [mSearchResultsArray sortUsingFunction:HistoryItemSort context:&sortData];
}

- (HistoryItem*)addItem:(HistorySiteItem*)item
{
  return [mTreeBuilder addItem:item];
}

- (HistoryItem*)removeItem:(HistorySiteItem*)item
{
  return [mTreeBuilder removeItem:item];
}

- (void)sendChangeNotificationWithRoot:(HistoryItem*)root
                     includingChildren:(BOOL)childrenChanged
{
  // If we are displaying search results, make sure that updates display any
  // new results.
  if (mSearchResultsArray)
    root = nil;

  if (root == [self rootItem])
    root = nil;

  NSDictionary* userInfoDict = nil;
  if (root) {
    userInfoDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                             root, kHistoryTreeChangeRootKey,
        [NSNumber numberWithBool:childrenChanged], kHistoryTreeChangedChildrenKey,
                                                   nil];
  }
  else {
    userInfoDict = [NSDictionary dictionary];
  }

  [[NSNotificationCenter defaultCenter]
      postNotificationName:kHistoryTreeChangedNotification
                    object:self
                  userInfo:userInfoDict];
}

#pragma mark -
#pragma mark Data sourc notification listeners

- (void)historyItemChanged:(NSNotification*)notification
{
  // If the tree has not been built yet, ignore changes.
  if (![self rootItem])
    return;

  HistorySiteItem* item = [notification object];
  int changeType = [[[notification userInfo]
      objectForKey:kHistoryDataSourceChangedUserInfoChangeType] intValue];

  switch (changeType) {
    case kHistoryChangeItemAdded: {
      HistoryItem* parentCategory = [self addItem:item];
      [self rebuildSearchResults];
      [self sendChangeNotificationWithRoot:parentCategory
                         includingChildren:YES];
      break;
    }
    case kHistoryChangeItemRemoved: {
      HistoryItem* parentCategory = [self removeItem:item];
      [self rebuildSearchResults];
      [self sendChangeNotificationWithRoot:parentCategory
                         includingChildren:YES];
      break;
    }
    case kHistoryChangeItemModified: {
      //Remove then re-add it since the location may have changed.
      HistoryItem* oldParent = [self removeItem:item];
      HistoryItem* newParent = [self addItem:item];
      [self rebuildSearchResults];

      [self sendChangeNotificationWithRoot:oldParent includingChildren:YES];
      if (oldParent != newParent)
        [self sendChangeNotificationWithRoot:newParent includingChildren:YES];
      break;
    }
    case kHistoryChangeIconLoaded: {
      [self sendChangeNotificationWithRoot:item includingChildren:NO];
      break;
    }
  }
}

- (void)historyRebuilt:(NSNotification*)notification
{
  // If the tree has not been built yet, ignore changes.
  if (![self rootItem])
    return;

  [self buildTree];
}

#pragma mark -
#pragma mark Implementation of NSOutlineViewDataSource protocol

- (id)outlineView:(NSOutlineView*)aOutlineView child:(int)aIndex ofItem:(id)item
{
  if (mSearchResultsArray) {
    if (!item)
      return [mSearchResultsArray objectAtIndex:aIndex];
    return nil;
  }

  if (!item)
    item = [self rootItem];
  return [item childAtIndex:aIndex];
}

- (int)outlineView:(NSOutlineView*)outlineView numberOfChildrenOfItem:(id)item
{
  if (mSearchResultsArray) {
    if (!item)
      return [mSearchResultsArray count];
    return 0;
  }

  if (!item)
    item = [self rootItem];
  return [item numberOfChildren];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
  return [item isKindOfClass:[HistoryCategoryItem class]];
}

// identifiers: title url last_visit first_visit
- (id)outlineView:(NSOutlineView*)outlineView
objectValueForTableColumn:(NSTableColumn*)aTableColumn
           byItem:(id)item
{
  if ([[aTableColumn identifier] isEqualToString:@"title"])
    return [item title];

  if ([item isKindOfClass:[HistorySiteItem class]]) {
    if ([[aTableColumn identifier] isEqualToString:@"url"])
      return [item url];

    if ([[aTableColumn identifier] isEqualToString:@"last_visit"])
      return [item lastVisit];

    if ([[aTableColumn identifier] isEqualToString:@"first_visit"])
      return [item firstVisit];
  }

  if ([item isKindOfClass:[HistoryCategoryItem class]]) {
    if ([[aTableColumn identifier] isEqualToString:@"url"])
      return [BookmarkViewController greyStringWithItemCount:[item numberOfChildren]];
  }

  return nil;

  // TODO: Truncate string.
}

- (BOOL)outlineView:(NSOutlineView*)outlineView
         writeItems:(NSArray*)items
       toPasteboard:(NSPasteboard*)pboard
{
  // Need to filter out folders from the list, only allow the urls to be dragged
  NSMutableArray* urlsArray   = [[[NSMutableArray alloc] init] autorelease];
  NSMutableArray* titlesArray = [[[NSMutableArray alloc] init] autorelease];

  NSEnumerator *enumerator = [items objectEnumerator];
  id curItem;
  while ((curItem = [enumerator nextObject])) {
    if ([curItem isSiteItem]) {
      NSString* itemURL = [curItem url];
      NSString* cleanedTitle = [[curItem title]
          stringByReplacingCharactersInSet:[NSCharacterSet controlCharacterSet]
                                withString:@" "];

      [urlsArray addObject:itemURL];
      [titlesArray addObject:cleanedTitle];
    }
  }

  if ([urlsArray count] > 0) {
    [pboard declareURLPasteboardWithAdditionalTypes:[NSArray array] owner:self];
    [pboard setURLs:urlsArray withTitles:titlesArray];
    return YES;
  }

  return NO;
}

@end

#pragma mark -
#pragma mark History Tree Builders

@implementation HistoryTreeBuilder

- (id)initWithDataSource:(HistoryDataSource*)inDataSource sortSelector:(SEL)sortSelector descending:(BOOL)descending
{
  if ((self = [super init])) {
    mDataSource     = inDataSource;    // not retained
    mSortSelector   = sortSelector;
    mSortDescending = descending;
  }
  return self;
}

- (void)dealloc
{
  [mRootItem release];
  [super dealloc];
}

- (void)buildTree
{
  [self buildTreeWithItems:[mDataSource historyItems]];
}

- (HistoryItem*)rootItem
{
  return mRootItem;
}

- (HistoryItem*)addItem:(HistorySiteItem*)item
{
  [mRootItem addChild:item];
  [self resortFromItem:mRootItem];
  return mRootItem;
}

- (HistoryItem*)removeItem:(HistorySiteItem*)item
{
  [mRootItem removeChild:item];
  // no need to resort
  return mRootItem;
}

- (void)buildTreeWithItems:(NSArray*)items
{
  mRootItem = [[HistoryCategoryItem alloc] initWithDataSource:mDataSource title:@"" childCapacity:[items count]];

  [mRootItem addChildren:items];
  [self resortFromItem:mRootItem];
}

- (void)resortWithSelector:(SEL)sortSelector descending:(BOOL)descending
{
  mSortSelector = sortSelector;
  mSortDescending = descending;
  [self resortFromItem:nil];
}

// recursive sort
- (void)resortFromItem:(HistoryItem*)item
{
  SortData sortData;
  sortData.mSortSelector = mSortSelector;
  sortData.mReverseSort = [NSNumber numberWithBool:mSortDescending];

  if (!item)
    item = mRootItem;

  NSMutableArray* itemChildren = [item children];
  [itemChildren sortUsingFunction:HistoryItemSort context:&sortData];

  unsigned int numChildren = [itemChildren count];
  for (unsigned int i = 0; i < numChildren; i ++) {
    HistoryItem* curItem = [itemChildren objectAtIndex:i];
    if ([curItem isKindOfClass:[HistoryCategoryItem class]])
      [self resortFromItem:curItem];
  }
}

@end

#pragma mark -

@implementation HistoryBySiteTreeBuilder

- (id)initWithDataSource:(HistoryDataSource*)inDataSource sortSelector:(SEL)sortSelector descending:(BOOL)descending
{
  if ((self = [super initWithDataSource:inDataSource sortSelector:sortSelector descending:descending])) {
  }
  return self;
}

- (void)dealloc
{
  [mSiteDictionary release];
  [super dealloc];
}

- (HistoryCategoryItem*)ensureHostCategoryForItem:(HistorySiteItem*)inItem
{
  NSString* itemHostname = [inItem hostname];
  HistoryCategoryItem* hostCategory = [mSiteDictionary objectForKey:itemHostname];
  if (!hostCategory) {
    NSString* itemTitle = itemHostname;
    if ([itemHostname isEqualToString:@"local_file"])
      itemTitle = NSLocalizedString(@"LocalFilesCategoryTitle", @"");

    hostCategory = [[HistorySiteCategoryItem alloc] initWithDataSource:mDataSource site:itemHostname title:itemTitle childCapacity:10];
    [mSiteDictionary setObject:hostCategory forKey:itemHostname];
    [mRootItem addChild:hostCategory];
    [hostCategory release];
  }
  return hostCategory;
}

- (void)removeSiteCategory:(HistoryCategoryItem*)item forHostname:(NSString*)hostname
{
  [mSiteDictionary removeObjectForKey:hostname];
  [mRootItem removeChild:item];
}

- (HistoryItem*)addItem:(HistorySiteItem*)item
{
  HistoryCategoryItem* hostCategory = [mSiteDictionary objectForKey:[item hostname]];
  BOOL newHost = (hostCategory == nil);

  if (!hostCategory)
    hostCategory = [self ensureHostCategoryForItem:item];

  [hostCategory addChild:item];

  [self resortFromItem:newHost ? mRootItem : hostCategory];
  return hostCategory;
}

- (HistoryItem*)removeItem:(HistorySiteItem*)item
{
  NSString* itemHostname = [item hostname];
  HistoryCategoryItem* hostCategory = [mSiteDictionary objectForKey:itemHostname];
  [hostCategory removeChild:item];

  // is the category is now empty, remove it
  if ([hostCategory numberOfChildren] == 0) {
    [self removeSiteCategory:hostCategory forHostname:itemHostname];
    return mRootItem;
  }

  return hostCategory;
}

- (void)buildTreeWithItems:(NSArray*)items
{
  if (!mSiteDictionary)
    mSiteDictionary = [[NSMutableDictionary alloc] initWithCapacity:100];
  else
    [mSiteDictionary removeAllObjects];

  [mRootItem release];
  mRootItem = [[HistoryCategoryItem alloc] initWithDataSource:mDataSource title:@"" childCapacity:100];

  NSEnumerator* itemsEnum = [items objectEnumerator];
  HistorySiteItem* item;
  while ((item = [itemsEnum nextObject])) {
    HistoryCategoryItem* hostCategory = [self ensureHostCategoryForItem:item];
    [hostCategory addChild:item];
  }

  [self resortFromItem:mRootItem];
}

@end

#pragma mark -

@implementation HistoryByDateTreeBuilder

- (id)initWithDataSource:(HistoryDataSource*)inDataSource sortSelector:(SEL)sortSelector descending:(BOOL)descending
{
  if ((self = [super initWithDataSource:inDataSource sortSelector:sortSelector descending:descending])) {
    [self setUpDateCategories];
  }
  return self;
}

- (void)dealloc
{
  [mDateCategories release];
  [super dealloc];
}

- (void)setUpDateCategories
{
  static const int kOlderThanAWeek = 7;
  static const int kDefaultExpireDays = 9;

  if (!mDateCategories)
    mDateCategories = [[NSMutableArray alloc] initWithCapacity:kDefaultExpireDays];
  else
    [mDateCategories removeAllObjects];

  // Read the history cutoff so that we don't create too many folders
  BOOL gotPref = NO;
  int expireDays = [[PreferenceManager sharedInstance] getIntPref:kGeckoPrefHistoryLifetimeDays
                                                      withSuccess:&gotPref];
  if (!gotPref)
    expireDays = kDefaultExpireDays;
  else if (expireDays == 0) {
    // Return with an empty array, there is no history
    return;
  }

  NSDictionary* curCalendarLocale = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
  NSString* dateFormat = NSLocalizedString(@"HistoryMenuDateFormat", @"");

  NSCalendarDate* nowDate      = [NSCalendarDate calendarDate];
  NSCalendarDate* lastMidnight = [NSCalendarDate dateWithYear:[nowDate yearOfCommonEra]
                                                    month:[nowDate monthOfYear]
                                                      day:[nowDate dayOfMonth]
                                                     hour:0
                                                   minute:0
                                                   second:0
                                                 timeZone:[nowDate timeZone]];

  int dayLimit = (expireDays < kOlderThanAWeek ? expireDays : kOlderThanAWeek);
  for (int ageDays = 0; ageDays <= dayLimit; ++ageDays) {
    NSDate* dayStartDate;
    if (ageDays < kOlderThanAWeek) {
      dayStartDate = [lastMidnight dateByAddingYears:0
                                              months:0
                                                days:(-1)*ageDays
                                               hours:0
                                             minutes:0
                                             seconds:0];
    }
    else {
      dayStartDate = [NSDate distantPast];
    }

    NSString* itemTitle;
    int childCapacity = 10;
    int ageInDays = ageDays;
    if (ageDays == 0)
      itemTitle = NSLocalizedString(@"Today", @"");
    else if (ageDays == 1 )
      itemTitle = NSLocalizedString(@"Yesterday", @"");
    else if (ageDays == kOlderThanAWeek) {
      itemTitle = NSLocalizedString(@"HistoryMoreThanAWeek", @"");
      ageInDays = -1;
      childCapacity = 100;
    }
    else {
      itemTitle = [dayStartDate descriptionWithCalendarFormat:dateFormat
                                                     timeZone:nil
                                                       locale:curCalendarLocale];
    }

    HistoryCategoryItem* newItem = [[HistoryDateCategoryItem alloc] initWithDataSource:mDataSource
                                                                             startDate:dayStartDate
                                                                             ageInDays:ageInDays
                                                                                 title:itemTitle
                                                                         childCapacity:childCapacity];
    [mDateCategories addObject:newItem];
    [newItem release];
  }
}

- (HistoryCategoryItem*)categoryItemForDate:(NSDate*)date
{
  // find the first category whose start date is older
  unsigned int numDateCategories = [mDateCategories count];
  for (unsigned int i = 0; i < numDateCategories; i ++) {
    HistoryDateCategoryItem* curItem = [mDateCategories objectAtIndex:i];
    NSComparisonResult comp = [date compare:[curItem startDate]];
    if (comp == NSOrderedDescending)
      return curItem;
  }

  // Category not found. The category for this date must have already been trimmed!
  return nil;
}

- (HistoryItem*)addItem:(HistorySiteItem*)item
{
  HistoryCategoryItem* dateCategory = [self categoryItemForDate:[item lastVisit]];
  [dateCategory addChild:item];

  [self resortFromItem:dateCategory];
  return dateCategory;
}

- (HistoryItem*)removeItem:(HistorySiteItem*)item
{
  HistoryCategoryItem* dateCategory = [self categoryItemForDate:[item lastVisit]];
  [dateCategory removeChild:item];
  // no need to resort
  return dateCategory;
}

- (void)buildTreeWithItems:(NSArray*)items
{
  // Populate mDateCategories with history items.
  NSEnumerator* itemsEnum = [items objectEnumerator];
  HistorySiteItem* item;
  while ((item = [itemsEnum nextObject])) {
    HistoryCategoryItem* dateCategory = [self categoryItemForDate:[item lastVisit]];
    [dateCategory addChild:item];
  }

  // Trim old empty categories from mDateCategories.
  for (int i = [mDateCategories count] - 1; i > 0; i--) {
    HistoryDateCategoryItem* dateCategory = [mDateCategories objectAtIndex:i];
    if ([dateCategory numberOfChildren] > 0) {
      break;
    }
    [mDateCategories removeLastObject];
  }

  // Display the Today category through the oldest non-empty category.
  mRootItem = [[HistoryCategoryItem alloc] initWithDataSource:mDataSource
                                                        title:@""
                                                childCapacity:[mDateCategories count]];
  [mRootItem addChildren:mDateCategories];
  [self resortFromItem:mRootItem];
}

@end
