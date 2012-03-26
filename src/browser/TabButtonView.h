/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>

@class BrowserTabViewItem;
@class TruncatingTextAndImageCell;
@class RolloverImageButton;
@class CHSlidingViewAnimation;

typedef enum {
  eSlideAnimationDirectionLeft,
  eSlideAnimationDirectionRight,
  eSlideAnimationDirectionNone
} ESlideAnimationDirection;

extern NSString *const kSlidingTabAnimationFinishedNotification;
// Key in the |kSlidingTabAnimationFinishedNotification| user info dictionary to inform observers
// if the sliding tab animation was aborted before it finished.
extern NSString *const kSlidingTabAnimationFinishedCompletelyKey;

// A view for visible tab buttons; there is a one-to-one correspondence between
// a BrowserTabViewItem and a TabButtonView.
@interface TabButtonView : NSView
{
  BrowserTabViewItem*           mTabViewItem;       // weak ref
  RolloverImageButton*          mCloseButton;       // strong ref
#ifdef USE_PROGRESS_SPINNERS
  NSProgressIndicator*          mLoadingIndicator;  // strong ref
#else
  NSImageView*                  mLoadingIndicator;  // strong ref
#endif
  TruncatingTextAndImageCell*   mLabelCell;         // strong ref
  NSRect                        mLabelRect;
  NSTrackingRectTag             mTrackingTag;
  BOOL                          mMouseWithin;
  BOOL                          mIsDragTarget;
  BOOL                          mSelectTabOnMouseUp;
  BOOL                          mNeedsLeftDivider;
  BOOL                          mNeedsRightDivider;
  ESlideAnimationDirection      mSlideAnimationDirection;
  CHSlidingViewAnimation*       mViewAnimation;     // strong ref
}

- (id)initWithFrame:(NSRect)frameRect andTabItem:(BrowserTabViewItem*)tabViewItem;

// Returns the associated tabViewItem
- (BrowserTabViewItem*)tabViewItem;

// Set the label on the tab. Truncation will be handled automatically.
- (void)setLabel:(NSString*)label;

// Set the icon on the tab, and whether or not the icon is draggable.
- (void)setIcon:(NSImage *)newIcon isDraggable:(BOOL)draggable;

// Enable or disable the close button.
- (void)setCloseButtonEnabled:(BOOL)isEnabled;

- (RolloverImageButton*)closeButton;

// Enable or disable drawing of the dividers.
- (void)setDrawsLeftDivider:(BOOL)drawsLeftDivider;
- (void)setDrawsRightDivider:(BOOL)drawsRightDivider;

// Start and stop the tab loading animation.
- (void)startLoadAnimation;
- (void)stopLoadAnimation;

// Smoothly animates the tab button to a new location.
- (void)slideToLocation:(NSPoint)newLocation;
- (void)stopSliding;

// The current direction the tab is sliding in.
- (ESlideAnimationDirection)slideAnimationDirection;

// TODO: The following three methods should be removed from the public
// interface, and all tracking should be handled internally to the class

// Start tracking mouse movements.
- (void)addTrackingRect;
// Stop tracking mouse movements.
- (void)removeTrackingRect;
// Inform the view that it should re-evaluate the state of its mouse tracking.
- (void)updateHoverState:(BOOL)isHovered;

@end
