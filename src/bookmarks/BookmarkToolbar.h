/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <AppKit/AppKit.h>

@class BookmarkButton;
@class BookmarkItem;

@interface BookmarkToolbar : NSView
{
  NSMutableArray* mButtons;
  BookmarkButton* mDragInsertionButton;
  int             mDragInsertionPosition;
  BOOL            mDrawBorder;
  BOOL            mButtonListDirty;     // do we need a full rebuild of the button list?
  NSView*         mNextExternalKeyView;
}

  // Called to construct & edit the initial set of personal toolbar buttons.
- (void)rebuildButtonList;
- (void)addButton:(BookmarkItem*)aItem atIndex:(int)aIndex;
- (void)updateButton:(BookmarkItem*)aItem;
- (void)removeButton:(BookmarkItem*)aItem;

  // Called to lay out the buttons on the toolbar.
- (void)reflowButtons;
- (void)reflowButtonsStartingAtIndex:(int)aIndex;

  // This is need for correct window zooming
- (float)computeHeight:(float)aWidth startingAtIndex:(int)aIndex;

- (BOOL)isVisible;
- (void)setVisible:(BOOL)aShow;
- (void)setDrawBottomBorder:(BOOL)drawBorder;

- (IBAction)addFolder:(id)aSender;

- (void)momentarilyHighlightButtonAtIndex:(int)aIndex;

@end
