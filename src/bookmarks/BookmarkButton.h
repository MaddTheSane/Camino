/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <AppKit/AppKit.h>

@class BookmarkItem;

@interface BookmarkButton : NSButton
{
  BookmarkItem*   mItem;                // strong
  NSEvent*        mLastMouseDownEvent;  // strong
  BOOL            mLastEventWasMenu;
}

- (id)initWithFrame:(NSRect)frame item:(BookmarkItem*)item;

- (void)setBookmarkItem:(BookmarkItem*)anItem;
- (BookmarkItem*)bookmarkItem;

- (void)bookmarkChanged:(BOOL*)outNeedsReflow;

- (IBAction)openBookmark:(id)aSender;
- (IBAction)openBookmarkInNewTab:(id)aSender;
- (IBAction)openBookmarkInNewWindow:(id)aSender;
- (IBAction)showBookmarkInfo:(id)aSender;
- (IBAction)revealBookmark:(id)aSender;
- (IBAction)deleteBookmarks:(id)aSender;
- (IBAction)addFolder:(id)aSender;

@end
