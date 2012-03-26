/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <AppKit/AppKit.h>

@class BookmarkItem;

@interface BookmarkInfoController : NSWindowController
{
  IBOutlet NSView*      mBookmarkView;
  IBOutlet NSView*      mFolderView;

  IBOutlet NSTabView*   mTabView;
  IBOutlet NSTextField* mBookmarkNameField;
  IBOutlet NSTextField* mBookmarkLocationField;
  IBOutlet NSTextField* mBookmarkShortcutField;
  IBOutlet NSTextField* mBookmarkDescField;
  IBOutlet NSTextField* mFolderNameField;
  IBOutlet NSTextField* mFolderShortcutField;
  IBOutlet NSTextField* mFolderDescField;
  IBOutlet NSTextField* mLastVisitField;
  IBOutlet NSTextField* mNumberVisitsField;

  IBOutlet NSButton*    mTabgroupCheckbox;
  IBOutlet NSButton*    mDockMenuCheckbox;
  IBOutlet NSButton*    mClearNumberVisitsButton;

  NSTabViewItem *mBookmarkInfoTabView;
  NSTabViewItem *mBookmarkUpdateTabView;
  NSTabViewItem *mFolderInfoTabView;
  BookmarkItem  *mBookmarkItem;
  NSTextView    *mFieldEditor;
}

+ (id)sharedBookmarkInfoController;
+ (id)existingSharedBookmarkInfoController;
+ (void)closeBookmarkInfoController;

- (void)setBookmark:(BookmarkItem*)aBookmark;
- (BookmarkItem*)bookmark;

- (IBAction)tabGroupCheckboxClicked:(id)sender;
- (IBAction)dockMenuCheckboxClicked:(id)sender;
- (IBAction)clearVisitCount:(id)sender;

@end
