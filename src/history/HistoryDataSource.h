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
 * The Original Code is mozilla.org code.
 *
 * The Initial Developer of the Original Code is
 * Netscape Communications Corporation.
 * Portions created by the Initial Developer are Copyright (C) 2002
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *   Ben Goodger <ben@netscape.com> (Original Author)
 *   Simon Woodside <sbwoodside@yahoo.com>
 *   Simon Fraser <smfr@smfr.org>
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

#import <AppKit/AppKit.h>

#import "HistoryLoadListener.h";

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
