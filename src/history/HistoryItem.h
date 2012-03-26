/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <AppKit/AppKit.h>

@class HistoryDataSource;
class nsINavHistoryResultNode;

// HistoryItem is the base class for every object in the history outliner

@interface HistoryItem : NSObject
{
  HistoryItem*        mParentItem;    // our parent item (not retained)
  HistoryDataSource*  mDataSource;    // the data source that owns us (not retained)
}

- (id)initWithDataSource:(HistoryDataSource*)inDataSource;
- (HistoryDataSource*)dataSource;

- (NSString*)title;
- (BOOL)isSiteItem;
- (NSImage*)icon;
- (NSImage*)iconAllowingLoad:(BOOL)inAllowLoad;

- (NSString*)url;
- (NSDate*)firstVisit;
- (NSDate*)lastVisit;
- (unsigned int)visitCount;
- (NSString*)hostname;
- (NSString*)identifier;

- (void)setParentItem:(HistoryItem*)inParent;
- (HistoryItem*)parentItem;
- (BOOL)isDescendentOfItem:(HistoryItem*)inItem;

- (NSMutableArray*)children;
- (int)numberOfChildren;
- (HistoryItem*)childAtIndex:(int)inIndex;

- (BOOL)isSiteItem;

// we put sort comparators on the base class for convenience
- (NSComparisonResult)compareURL:(HistoryItem *)aItem sortDescending:(NSNumber*)inDescending;
- (NSComparisonResult)compareTitle:(HistoryItem *)aItem sortDescending:(NSNumber*)inDescending;
- (NSComparisonResult)compareFirstVisitDate:(HistoryItem *)aItem sortDescending:(NSNumber*)inDescending;
- (NSComparisonResult)compareLastVisitDate:(HistoryItem *)aItem sortDescending:(NSNumber*)inDescending;
- (NSComparisonResult)compareVisitCount:(HistoryItem *)aItem sortDescending:(NSNumber*)inDescending;
- (NSComparisonResult)compareHostname:(HistoryItem *)aItem sortDescending:(NSNumber*)inDescending;

@end

// a history category item (a folder in the outliner)
@interface HistoryCategoryItem : HistoryItem
{
  NSString*         mUUIDString;  // used to identify folders for outliner state saving
  NSString*         mTitle;
  NSMutableArray*   mChildren;    // array of HistoryItems (may be heterogeneous)
}

- (id)initWithDataSource:(HistoryDataSource*)inDataSource title:(NSString*)title childCapacity:(int)capacity;
- (NSString*)title;
- (NSString*)identifier;    // return UUID for this folder

- (void)addChild:(HistoryItem*)inChild;
- (void)removeChild:(HistoryItem*)inChild;
- (void)addChildren:(NSArray*)inChildren;

@end


// a history site category item (a folder in the outliner)
@interface HistorySiteCategoryItem : HistoryCategoryItem
{
  NSString*         mSite;    // not user-visible; used for state tracking
}

- (id)initWithDataSource:(HistoryDataSource*)inDataSource site:(NSString*)site title:(NSString*)title childCapacity:(int)capacity;
- (NSString*)site;

@end

// a history site category item (a folder in the outliner)
@interface HistoryDateCategoryItem : HistoryCategoryItem
{
  NSDate*           mStartDate;
  int               mAgeInDays;   // -1 is used for "distant past"
}

- (id)initWithDataSource:(HistoryDataSource*)inDataSource startDate:(NSDate*)startDate ageInDays:(int)days title:(NSString*)title childCapacity:(int)capacity;
- (NSDate*)startDate;
- (BOOL)isTodayCategory;

@end

// a specific history entry
@interface HistorySiteItem : HistoryItem
{
  NSString*         mItemIdentifier;
  NSString*         mURL;
  NSString*         mTitle;
  NSString*         mHostname;
  NSDate*           mFirstVisitDate;
  NSDate*           mLastVisitDate;
  unsigned int      mVisitCount;
  
  NSImage*          mSiteIcon;
  BOOL              mAttemptedIconLoad;
}

- (id)initWithDataSource:(HistoryDataSource*)inDataSource resultNode:(nsINavHistoryResultNode*)inNode;

- (BOOL)matchesString:(NSString*)searchString inFieldWithTag:(int)tag;

- (void)setSiteIcon:(NSImage*)inImage;
- (void)setTitle:(NSString*)inTitle;
- (void)setLastVisitDate:(NSDate*)inDate;

@end
