/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*-
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>

@class BrowserTabViewItem;
@class BrowserTabBarView;

// notification sent when someone double-clicks on the background of the tab bar.
extern NSString* const kTabBarBackgroundDoubleClickedNotification;

@interface BrowserTabView : NSTabView
{
  BOOL mBarAlwaysVisible;
  BOOL mVisible; // YES if the view is in the hierarchy
  IBOutlet BrowserTabBarView * mTabBar;
  
  // if non-nil, the tab to jump back to when the currently visible tab is
  // closed.
  BrowserTabViewItem* mJumpbackTab;
}

+ (BrowserTabViewItem*)makeNewTabItem;

// get and set whether the tab bar is always visible, even when it gets down to a single tab. The 
// default is hide when displaying only one tab. 
- (BOOL)barAlwaysVisible;
- (void)setBarAlwaysVisible:(BOOL)newSetting;

// Notification that the tab state has changed.
- (void)numberOfTabsChanged;
- (void)selectedTabChanged;

- (void)addTabForURL:(NSString*)aURL referrer:(NSString*)aReferrer inBackground:(BOOL)inBackground;

- (BOOL)tabsVisible;

- (int)numberOfBookmarkableTabViewItems;
- (int)indexOfTabViewItemWithURL:(NSString*)aURL;
- (BrowserTabViewItem*)itemWithTag:(int)tag;
- (BOOL)isVisible;
// inform the view that it will be shown or hidden; e.g. prior to showing or hiding the bookmarks
- (void)setVisible:(BOOL)show;
- (BOOL)windowShouldClose;
- (void)windowClosed;

// Returns YES if |dragInfo| is a valid drag for a tab or the tab bar, NO if not.
- (BOOL)shouldAcceptDrag:(id <NSDraggingInfo>)dragInfo;
// Handle drag and drop of one or more URLs; returns YES if the drop was valid.
// If |targetTab| is nil, then the drop is on the tab bar background.
- (BOOL)handleDrop:(id <NSDraggingInfo>)dragInfo onTab:(NSTabViewItem*)targetTab;

// get and set the "jumpback tab", the tab that is jumped to when the currently
// visible tab is closed. Reset automatically when switching tabs or after
// jumping back. This isn't designed to be a tab history, it only lives for a very
// well-defined period.
- (void)setJumpbackTab:(BrowserTabViewItem*)inTab;
- (BrowserTabViewItem*)jumpbackTab;

- (void)showOrHideTabsAsAppropriate;

@end
