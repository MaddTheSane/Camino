/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Foundation/Foundation.h>

@class HistoryDataSource;
@class HistoryItem;
@class HistoryTreeBuilder;
@class HistorySiteItem;

// Notification object is the tree.
extern NSString* const kHistoryTreeChangedNotification;
// If present, this is the item at the root of the change. If nil, the whole
// tree is being restructured (e.g., re-sorting).
// When an item is added or removed, the root is its parent, not the item.
extern NSString* const kHistoryTreeChangeRootKey;
// Key for a boolean (as NSNumber) indicating whether this change affects the
// child array for the root (e.g., a child being added/removed) or only the
// item (e.g., rename). Only present if the change root is non-nil.
extern NSString* const kHistoryTreeChangedChildrenKey;

extern NSString* const kHistoryViewByDate;      // grouped by last visit date
extern NSString* const kHistoryViewBySite;      // grouped by site
extern NSString* const kHistoryViewFlat;        // flat

// A class to manage a hiererchically structured view of history data.
// This class can serve as the data source for an outline view.
@interface HistoryTree : NSObject {
  HistoryDataSource*  mDataSource;

  NSString*           mCurrentViewIdentifier;

  NSString*           mSortColumn;
  BOOL                mSortDescending;

  NSString*           mSearchString;
  int                 mSearchFieldTag;
  NSMutableArray*     mSearchResultsArray;

  // Timer to watch for day changes.
  NSTimer*            mRefreshTimer;
  int                 mLastDayOfCommonEra;

  // The tree builder encapsulates the logic to build and update different
  // history views (e.g. by date, by site etc), and supply the root object.
  HistoryTreeBuilder* mTreeBuilder;
}

// Initializes a new HistoryTree with the given data source.
// The tree doesn't actually contain any items until buildTree is called.
- (id)initWithDataSource:(HistoryDataSource*)dataSource;

// Creates the tree from the underlying data source. This will load the data
// source if it isn't already. rootItem will be nil until this is called.
- (void)buildTree;

// Gets/sets the history grouping.
- (void)setHistoryView:(NSString*)inView;
- (NSString*)historyView;

// Returns the root of the tree.
- (HistoryItem*)rootItem;

// Ideally searching and sorting would be on the view, not the data source, but
// this keeps things simpler.
- (NSString*)sortColumnIdentifier;
- (void)setSortColumnIdentifier:(NSString*)sortColumnIdentifier;

- (BOOL)sortDescending;
- (void)setSortDescending:(BOOL)inDescending;

// Quicksearch support.
- (void)searchFor:(NSString*)searchString inFieldWithTag:(int)tag;
- (void)clearSearchResults;

@end
