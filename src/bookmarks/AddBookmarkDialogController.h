/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>

extern NSString* const kAddBookmarkItemURLKey;
extern NSString* const kAddBookmarkItemTitleKey;
extern NSString* const kAddBookmarkItemPrimaryTabKey;   // NSNumber with book, true for frontmost tab

@class BookmarkFolder;
@class BookmarkViewController;

@interface AddBookmarkDialogController : NSWindowController
{
  IBOutlet NSTextField*     mTitleField;
  IBOutlet NSPopUpButton*   mParentFolderPopup;
  IBOutlet NSButton*        mTabGroupCheckbox;  // nil if creating folder

  BookmarkViewController*   mBookmarkViewController;    // not retained

  BookmarkFolder*           mInitialParentFolder;
  int                       mInitialParentFolderIndex;
  NSArray*                  mBookmarkItems;   // array of NSDictionary
  NSString*                 mDefaultTitle;
}

+ (AddBookmarkDialogController*)controller;

- (IBAction)confirmAddBookmark:(id)sender;
- (IBAction)cancelAddBookmark:(id)sender;
- (IBAction)parentFolderChanged:(id)sender;
- (IBAction)toggleTabGroup:(id)sender;

- (void)makeTabGroup:(BOOL)isTabGroup;
- (void)setDefaultParentFolder:(BookmarkFolder*)inFolder andIndex:(int)inIndex;
- (void)setBookmarkViewController:(BookmarkViewController*)inBMViewController;

// inItems is an NSArray of NSDictionary, one per possible item
- (void)showDialogWithLocationsAndTitles:(NSArray*)inItems isFolder:(BOOL)inIsFolder onWindow:(NSWindow*)inWindow;

@end
