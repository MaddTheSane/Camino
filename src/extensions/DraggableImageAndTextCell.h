/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <AppKit/AppKit.h>

@interface DraggableImageAndTextCell : NSButtonCell
{
  NSPoint             mTrackingStart;
  float               mClickHoldTimeoutSeconds;
  BOOL                mIsDraggable;
  BOOL                mLastClickHoldTimedOut;
  BOOL                mHasShadow;

  SEL                 mClickHoldAction;
  SEL                 mMiddleClickAction;
}

- (id)initTextCell:(NSString*)aString;

- (BOOL)isDraggable;
- (void)setDraggable:(BOOL)inDraggable;

- (void)setClickHoldTimeout:(float)timeoutSeconds;
- (BOOL)lastClickHoldTimedOut;

- (void)setClickHoldAction:(SEL)inAltAction;
- (void)setMiddleClickAction:(SEL)inAction;

- (BOOL)trackOtherMouse:(NSEvent*)event
                 inRect:(NSRect)cellFrame
                 ofView:(NSView*)controlView
           untilMouseUp:(BOOL)untilMouseUp;

@end

