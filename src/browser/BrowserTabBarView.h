/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>

@class BrowserTabView;
@class BrowserTabViewItem;
@class TabButtonView;

@interface BrowserTabBarView : NSView 
{
@private
  // this tab view should be tabless and borderless
  IBOutlet BrowserTabView*  mTabView;
  
  NSButton*         mOverflowRightButton; // button to slide tabs to the left
  NSButton*         mOverflowLeftButton;  // button to slide tabs to the right
  NSButton*         mOverflowMenuButton;  // button to popup the tab menu
  
  // drag tracking
  BOOL              mDragOverBar;

  NSTimeInterval    mLastClickTime;
  
  BOOL              mOverflowTabs;        // track whether there are more tabs than we can fit onscreen
  NSMutableArray*   mTrackingCells;       // cells which currently have tracking rects in this view
  
  NSImage*          mBackgroundImage;
  NSImage*          mButtonDividerImage;
  
  int               mLeftMostVisibleTabIndex;    // Index of tab view item left-most in the tab bar
  int               mNumberOfVisibleTabs;        // Number of tab view items drawn in the tab bar

  NSView*           mNextExternalKeyView; // The next key view after the tab bar, as set from within Interface Builder.

  BOOL              mTabIsCurrentlyDragging;
  int               mEmptyTabPlaceholderIndex;   // The empty spot where the dragged tab will be inserted at.
  TabButtonView*    mDraggingTab;           // strong
  NSWindow*         mDraggingTabWindow;     // strong
  float             mHorizontalGrabOffset;  // To know when to start dragging when the mouse moves away from the tab.
  NSMutableArray*   mSavedTabFrames;        // strong
  int               mDraggingTabOriginalIndex;
  BOOL              mIsReorganizingTabViewItems;
  NSMutableArray*   mCurrentlySlidingTabs;  // strong
  NSMutableArray*   mCachedTabViewItems;    // strong; Used to reorder tab items locally during a drag session.
}

// Should be called when the number, order, or visible range of tabs is changed.
- (void)tabStructureChanged;
// Should be called when only the selected tab has changed.
- (void)tabSelectionChanged;

// return the height the tab bar should be
-(float)tabBarHeight;
-(BrowserTabViewItem*)tabViewItemAtPoint:(NSPoint)location;
-(BOOL)isVisible;
// show or hide tabs- should be called if this view will be hidden, to give it a chance to register or
// unregister tracking rects as appropriate
-(void)setVisible:(BOOL)show;
-(void)scrollTabIndexToVisible:(int)index;
- (void)updateKeyViewLoop;
-(BOOL)tabIsCurrentlyDragging;
-(void)tabViewClosedTabViewItem:(BrowserTabViewItem*)closedTabViewItem atIndex:(int)indexOfClosedItem;
-(void)tabViewAddedTabViewItem:(BrowserTabViewItem*)addedTabViewItem;

@end
