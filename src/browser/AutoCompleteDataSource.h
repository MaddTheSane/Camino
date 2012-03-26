/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*-
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <AppKit/AppKit.h>

#import "HistoryLoadListener.h"

@class AsynchronousTrieUpdater;
@class AutoCompleteKeywordGenerator;
@class AutoCompleteScorer;
@class HistoryItem;
@class Trie;

// Informal protocol for search delegates
@interface NSObject (AutoCompleteSearchDelegate)
// Called when search results are available.
- (void)searchResultsAvailable;
@end

//
// This class is in charge of retrieving/sorting the history and bookmark results
// for the location bar autocomplete, and is also the datasource for the table view
// in the autocomplete popup window.
//
@interface AutoCompleteDataSource: NSObject<HistoryLoadListener>
{
  id                          mDelegate;

  unsigned int                  mSearchStringLength;

  NSMutableArray*               mBookmarkData;            // owned
  Trie*                         mHistoryTrie;             // owned
  Trie*                         mBookmarkTrie;            // owned
  AutoCompleteScorer*           mTrieScorer;              // owned
  AutoCompleteKeywordGenerator* mKeywordGenerator;        // owned
  NSMutableArray*               mResults;                 // owned
  NSMutableArray*               mHistoryItemsToLoad;      // owned
  NSMutableArray*               mBookmarksToLoad;         // owned
  AsynchronousTrieUpdater*      mHistoryTrieUpdater;      // owned
  AsynchronousTrieUpdater*      mBookmarkTrieUpdater;     // owned

  NSImage*                      mGenericSiteIcon;         // owned
  NSImage*                      mGenericFileIcon;         // owned
}

// Returns the single shared autocomplete data source.
+ (AutoCompleteDataSource *)sharedDataSource;

// Starts the search for matching bookmarks/history items using the string passed
// from AutoCompleteTextField. This is an asynchronous method--when the search is
// complete, searchResultsAvailable will be called on the delegate.
- (void)performSearchWithString:(NSString *)searchString delegate:(id)delegate;

// Stops the search, meaning that no further results for the current search
// string will be sent to the delegate.
- (void)cancelSearch;

// Returns the number of rows matching the search string, including headers.
- (int)rowCount;

// Datasource methods.
- (int)numberOfRowsInTableView:(NSTableView*)aTableView;
- (id)resultForRow:(int)aRow columnIdentifier:(NSString *)aColumnIdentifier;

@end
