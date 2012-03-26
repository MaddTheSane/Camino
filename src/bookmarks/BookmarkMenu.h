/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <AppKit/AppKit.h>

@class BookmarkFolder;

// XXX share some of this code with HistoryMenu
@interface BookmarkMenu : NSMenu
{
  IBOutlet NSMenuItem*  mItemBeforeCustomItems;    // the item after which we add our items. Not retained.

  BookmarkFolder*   mFolder;    // retained
  BOOL              mDirty;
  BOOL              mAppendTabsItem;
}

- (id)initWithTitle:(NSString *)inTitle bookmarkFolder:(BookmarkFolder*)inFolder;
- (void)setBookmarkFolder:(BookmarkFolder*)inFolder;
- (BookmarkFolder*)bookmarkFolder;

// set whether to append "Open in Tabs" item (default is YES)
- (void)setAppendOpenInTabs:(BOOL)inAppend;

// specify the item after which bookmark items will be added
// (they are assumed to go to the end of the menu). If nil,
// the entire menu is full of bookmark items.
- (void)setItemBeforeCustomItems:(NSMenuItem*)inItem;
- (NSMenuItem*)itemBeforeCustomItems;

// do an explicit rebuild
- (void)rebuildMenuIncludingSubmenus:(BOOL)includeSubmenus;

@end
