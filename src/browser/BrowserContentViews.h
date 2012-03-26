/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>

@class BookmarkToolbar;
@class BrowserTabView;
@class BrowserTabBarView;
@class TabThumbnailGridView;

@interface BrowserContentView : NSView
{
  IBOutlet BookmarkToolbar  *mBookmarksToolbar;
  IBOutlet NSView           *mBrowserContainerView;   // manages tabs and web content
  IBOutlet NSView           *mStatusBar;
  TabThumbnailGridView      *mTabThumbnailGridView;
  BOOL                       mStatusBarWasHidden;
  BOOL                       mBookmarksToolbarWasHidden;
}

- (void)toggleTabThumbnailGridView;
- (BOOL)tabThumbnailGridViewIsVisible;

@end

@interface BrowserContainerView : NSView
{
  IBOutlet BrowserTabView *mTabView;
  IBOutlet BrowserTabBarView *mTabBarView;
}

@end
