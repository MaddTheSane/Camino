/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*-
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <AppKit/AppKit.h>

@class MAAttachedWindow;
@class AutoCompleteDataSource;
@class LocationBarPartitionView;
@class PageProxyIcon;

extern const int kLocationFieldFrameMargin;

@interface AutoCompleteTextField : NSTextField
{
  IBOutlet PageProxyIcon*   mProxyIcon;
  IBOutlet NSMenu*          mLockIconContextMenu;

  MAAttachedWindow*         mPopupWin;
  NSTableView*              mTableView;

  LocationBarPartitionView* mPartitionView;
  NSColor*                  mSecureBackgroundColor;

  AutoCompleteDataSource*   mDataSource;
  NSString*                 mSearchString;
  
  // Remembers if backspace was pressed in complete so we can check this in controlTextDidChange.
  BOOL mBackspaced;
  // Determines if the search currently pending should complete the default result when it is ready.
  BOOL mCompleteResult;
  // Should the autocomplete fill in the default completion into the text field? The default
  // is no, but this can be set with a hidden Gecko pref.
  BOOL mCompleteWhileTyping;
  // Should we autocomplete? The default is yes, but this can be set with a hidden Gecko pref.
  BOOL mShouldAutocomplete;
}

- (void)searchResultsAvailable;

- (PageProxyIcon*)pageProxyIcon;
- (void)setPageProxyIcon:(NSImage *)aImage;
- (void)setURI:(NSString*)aURI;

- (BOOL)userHasTyped;
- (void)cancelSearch;
- (void)clearResults;
- (void)revertText;

- (id)fieldEditor;

// Changes the display of the text field to indicate whether the page
// is secure or not.
- (void)setSecureState:(unsigned char)inState;

// Shows or hides the feed icon.
- (void)displayFeedIcon:(BOOL)inDisplay;

// Sets the menu for the feed icon.
- (void)setFeedIconContextMenu:(NSMenu*)inMenu;

@end
