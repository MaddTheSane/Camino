/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*-
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <AppKit/AppKit.h>

@class HistoryItem;

// A class that builds and maintains a menu hierarchy parallel to some portion
// of the history backend.
@interface HistorySubmenu : NSMenu
{
  HistoryItem*          mRootItem;               // root history item for this menu (retained)

  int                   mNumIgnoreItems;         // if > 0, ignore the first N items (for "earlier today")
  BOOL                  mHistoryItemsDirty;      // whether we need to rebuild the items on next update
}

// Sets the root history item that this menu represents.
- (void)setRootHistoryItem:(HistoryItem*)inRootItem;

// Gets the root history item that this menu represents.
- (HistoryItem*)rootItem;

// Sets the menu to skip displaying the first |inIgnoreItems| history items.
- (void)setNumLeadingItemsToIgnore:(int)inIgnoreItems;

// Marks the history menu as needing to be rebuilt.
- (void)setNeedsRebuild:(BOOL)needsRebuild;

@end


// Encapsulates all of the logic of building, displaying, and handling the
// top-level "History" menu.
@interface TopLevelHistoryMenu : HistorySubmenu
{
  IBOutlet NSMenuItem*  mItemBeforeHistoryItems; // the item after which we add history items.
  HistoryItem*          mTodayItem;              // the "Today" history group
  NSMenu*               mRecentlyClosedMenu;     // the folder of recently closed pages

  BOOL                  mAppLaunchDone;          // has app launching completed?
}

// Returns whether there are recently closed pages.
- (BOOL)hasRecentlyClosedPages;

@end
