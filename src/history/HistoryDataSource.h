/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <AppKit/AppKit.h>

#import "HistoryLoadListener.h"

@class HistorySiteItem;

class nsNavHistoryObserver;
class nsINavHistoryContainerResultNode;
class nsINavHistoryService;

// Sent when a history item changes. Notification object is the changed item.
extern NSString* const kHistoryDataSourceItemChangedNotification;
// The type of change that occured.
extern NSString* const kHistoryDataSourceChangedUserInfoChangeType;

// Sent when history is cleared. Notification object is the data source.
extern NSString* const kHistoryDataSourceClearedNotification;

// Sent when history is rebuilt from scratch (after initial load). Notification
// object is the data source.
extern NSString* const kHistoryDataSourceRebuiltNotification;

typedef enum {
  kHistoryChangeItemAdded,
  kHistoryChangeItemRemoved,
  kHistoryChangeItemModified,
  kHistoryChangeIconLoaded,
} HistoryChangeType;

@interface HistoryDataSource : NSObject
{
  nsINavHistoryService*   mNavHistoryService;         // owned (would be an nsCOMPtr)
  nsNavHistoryObserver*   mNavHistoryObserver;        // owned
  
  BOOL                    mShowSiteIcons;

  NSMutableArray*         mHistoryItems;              // this array owns all the history items
  NSMutableDictionary*    mHistoryItemsDictionary;    // history items indexed by url (strong)
  BOOL                    mHistoryLoaded;

  // Used only during the history loading process.
  nsINavHistoryContainerResultNode* mRootNode;  // owned
  unsigned int                      mResultCount;
  unsigned int                      mCurrentIndex;
  NSMutableArray*                   mLoadListeners;
  NSMutableArray*                   mPendingChangeQueue;
}

// Returns the single shared history data source.
+ (HistoryDataSource*)sharedHistoryDataSource;

// Synchronously loads history.
// If history has alread been loaded, this reloads it from scratch, so when
// dealing with a shared history source clients will generally want to call this
// only if isLoaded is false.
// If an asynchronous load is already in progress, calling this will cause
// the remaining history to be loaded synchronously, so from the client's
// perspective it's seamless.
- (void)loadSynchronously;
// Asynchronously loads history, calling the HistoryLoadListener callback when
// loading has completed. |listener| is retained until then.
// The listener should not make any calls that modify the history source until
// loading is complete.
// If history is already being loaded asyrchonously, this just adds the new
// listener to the existing asynchronous load.
// As with the synchronous version, calling this once loading is complete will
// reload from scratch.
- (void)loadAsynchronouslyWithListener:(id<HistoryLoadListener>)listener;

// Returns YES if history has already been loaded.
- (BOOL)isLoaded;

// Returns all history items.
- (NSArray*)historyItems;

// Removes the given item from history.
- (void)removeItem:(HistorySiteItem*)item;

// Returns whether or not site icons should be displayed for history items.
- (BOOL)showSiteIcons;

@end
