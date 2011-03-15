/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* ***** BEGIN LICENSE BLOCK *****
 * Version: MPL 1.1/GPL 2.0/LGPL 2.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Original Code is Camino code.
 *
 * The Initial Developer of the Original Code is
 * Stuart Morgan
 * Portions created by the Initial Developer are Copyright (C) 2010
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *   Stuart Morgan <stuart.morgan@alumni.case.edu>
 *
 * Alternatively, the contents of this file may be used under the terms of
 * either the GNU General Public License Version 2 or later (the "GPL"), or
 * the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
 * in which case the provisions of the GPL or the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of either the GPL or the LGPL, and not to allow others to
 * use your version of this file under the terms of the MPL, indicate your
 * decision by deleting the provisions above and replace them with the notice
 * and other provisions required by the GPL or the LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the MPL, the GPL or the LGPL.
 *
 * ***** END LICENSE BLOCK ***** */

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
