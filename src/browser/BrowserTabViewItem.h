/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>

// sent when the current tab will changed. The object is the tab that's being
// switched to. NSTabView does have a delegate method when the tab changes,
// but no notification and we don't want to take over the delegate for internal
// implementation.
extern NSString* const kTabWillChangeNotification;

// A subclass of NSTabViewItem that manages the custom Camino tabs.
@class TabButtonView;
@class TruncatingTextAndImageCell;

@interface BrowserTabViewItem : NSTabViewItem
{
  NSImage*                     mTabIcon;           // STRONG ref
  TabButtonView*               mTabButtonView;     // STRONG ref
  NSMenuItem*                  mMenuItem;          // STRONG ref
  BOOL                         mDraggable;
  int                          mTag;
}

- (NSImage *)tabIcon;
- (void)setTabIcon:(NSImage *)newIcon isDraggable:(BOOL)draggable;

- (BOOL)draggable;

- (TabButtonView*)buttonView;
- (int)tag;
// Note that this method may confirm the tab close (e.g., in the case of an
// onunload handler), and thus may not actually result in the tab being closed.
- (void)closeTab:(id)sender;

// call to start and stop the progress animation on this tab
- (void)startLoadAnimation;
- (void)stopLoadAnimation;

// call before removing to clean up close button and progress spinner
- (void)willBeRemoved;

- (NSMenuItem *)menuItem;
- (void) willDeselect;
- (void) willSelect;
- (void) selectTab:(id)sender;

+ (NSImage*)closeIcon;
+ (NSImage*)closeIconPressed;
+ (NSImage*)closeIconHover;

// Returns YES if |sender| is a valid drag for a tab, NO if not.
- (BOOL)shouldAcceptDrag:(id <NSDraggingInfo>)dragInfo;
// Handle drag and drop of one or more URLs; returns YES if the drop was valid.
- (BOOL)handleDrop:(id <NSDraggingInfo>)dragInfo;

@end
