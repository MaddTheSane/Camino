/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */


#import <AppKit/AppKit.h>

@class BookmarkViewController;
@class BrowserWindowController;
@class ExtendedOutlineView;


// delegate for the history outliner. we use a different delegate from the bookmarks outliner
// to keep the outline view delegate methods simpler.
@interface HistoryOutlineViewDelegate : NSObject
{
  IBOutlet ExtendedOutlineView*     mHistoryOutlineView;
  
  IBOutlet NSMenu*                  mHistorySortMenu;
  IBOutlet BookmarkViewController*  mBookmarksViewController;

  BrowserWindowController*          mBrowserWindowController;
  BOOL                              mUpdatesDisabled;
  BOOL                              mHistoryLoaded;

  NSMutableDictionary*              mExpandedStates;
}

- (void)setBrowserWindowController:(BrowserWindowController*)bwController;

- (void)historyViewMadeVisible:(BOOL)visible;

- (void)searchFor:(NSString*)searchString inFieldWithTag:(int)tag;
- (void)clearSearchResults;

- (void)copyHistoryURLs:(NSArray*)historyItemsToCopy toPasteboard:(NSPasteboard*)aPasteboard;

- (IBAction)openHistoryItem:(id)sender;
- (IBAction)openHistoryItemInNewWindow:(id)aSender;
- (IBAction)openHistoryItemInNewTab:(id)aSender;
- (IBAction)openHistoryItemsInTabsInNewWindow:(id)aSender;

- (IBAction)deleteHistoryItems:(id)sender;

- (IBAction)copyURLs:(id)sender;

- (IBAction)groupByDate:(id)sender;
- (IBAction)groupBySite:(id)sender;
- (IBAction)setNoGrouping:(id)sender;

- (IBAction)sortBy:(id)sender;

- (IBAction)sortAscending:(id)sender;
- (IBAction)sortDescending:(id)sender;


@end
