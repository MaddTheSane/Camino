/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "DraggableImageAndTextCell.h"

@implementation DraggableImageAndTextCell

+ (BOOL)prefersTrackingUntilMouseUp
{
  return YES;
}

- (id)initTextCell:(NSString*)aString
{
  if ((self = [super initTextCell:aString])) {
    mClickHoldTimeoutSeconds = 60.0 * 60.0 * 24.0;
  }
  return self;
}

// Overridden to give the title text a drop shadow when the button is highlighted
- (void)highlight:(BOOL)highlighted withFrame:(NSRect)cellFrame inView:(NSView*)controlView
{
  if ([[self title] length] > 0) {
    if (highlighted && !mHasShadow) {
      NSMutableDictionary* info = [[[self attributedTitle] attributesAtIndex:0 effectiveRange:NULL] mutableCopy];
      NSShadow* shadow = [[NSShadow alloc] init];
      [shadow setShadowBlurRadius:1];
      [shadow setShadowOffset:NSMakeSize(0, -1)];
      [shadow setShadowColor:[NSColor colorWithCalibratedRed:0.0 green:0.0 blue:0.0 alpha:0.6]];
      [info setObject:shadow forKey:NSShadowAttributeName];
      [shadow release];
      NSAttributedString* shadowedTitle = [[NSAttributedString alloc] initWithString:[self title] attributes:info];
      [info release];
      [self setAttributedTitle:shadowedTitle];
      [shadowedTitle release];
      mHasShadow = YES;
    }
    else if (!highlighted && mHasShadow){
      NSMutableDictionary* info = [[[self attributedTitle] attributesAtIndex:0 effectiveRange:NULL] mutableCopy];
      [info removeObjectForKey:NSShadowAttributeName];
      NSAttributedString* unshadowedTitle = [[NSAttributedString alloc] initWithString:[self title] attributes:info];
      [info release];
      [self setAttributedTitle:unshadowedTitle];
      [unshadowedTitle release];
      mHasShadow = NO;
    }
  }
  
  [super highlight:highlighted withFrame:cellFrame inView:controlView];
}

- (void)setClickHoldTimeout:(float)timeoutSeconds
{
  mClickHoldTimeoutSeconds = timeoutSeconds;
}

- (BOOL)lastClickHoldTimedOut
{
  return mLastClickHoldTimedOut;
}

- (void)setClickHoldAction:(SEL)inAltAction
{
  mClickHoldAction = inAltAction;
}

- (void)setMiddleClickAction:(SEL)inAction
{
  mMiddleClickAction = inAction;
}

#pragma mark -

- (BOOL)isDraggable
{
  return mIsDraggable;
}

- (void)setDraggable:(BOOL)inDraggable
{
  mIsDraggable = inDraggable;
}

- (BOOL)startTrackingAt:(NSPoint)startPoint inView:(NSView*)controlView
{
  if (mIsDraggable)
    mTrackingStart = startPoint;

  [super startTrackingAt:startPoint inView:controlView];
  return YES;
}

- (BOOL)continueTracking:(NSPoint)lastPoint at:(NSPoint)currentPoint inView:(NSView*)controlView
{
  if (!mIsDraggable)
    return [super continueTracking:lastPoint at:currentPoint inView:controlView];

  return [DraggableImageAndTextCell prefersTrackingUntilMouseUp];  // XXX fix me?
}

// called when the mouse leaves the cell, or the mouse button was released
- (void)stopTracking:(NSPoint)lastPoint at:(NSPoint)stopPoint inView:(NSView*)controlView mouseIsUp:(BOOL)flag
{
  [super stopTracking:lastPoint at:stopPoint inView:controlView mouseIsUp:flag];
}

#define kDragThreshold 4.0

- (BOOL)trackMouse:(NSEvent*)theEvent
            inRect:(NSRect)cellFrame
            ofView:(NSView*)controlView
      untilMouseUp:(BOOL)untilMouseUp
{
  mLastClickHoldTimedOut = NO;

  if (!mIsDraggable)
    return [super trackMouse:theEvent inRect:cellFrame ofView:controlView untilMouseUp:untilMouseUp];

  NSPoint firstWindowLocation = [theEvent locationInWindow];
  NSPoint lastWindowLocation  = firstWindowLocation;
  NSPoint curWindowLocation   = firstWindowLocation;
  NSEventType lastEvent       = (NSEventType)0;
  NSDate* clickHoldBailTime   = [NSDate dateWithTimeIntervalSinceNow:mClickHoldTimeoutSeconds];

  if (![self startTrackingAt:curWindowLocation inView:controlView])
    return NO;

  while(1) {
    NSEvent* event = [NSApp nextEventMatchingMask:(NSLeftMouseDraggedMask | NSLeftMouseUpMask)
                                        untilDate:clickHoldBailTime
                                           inMode:NSEventTrackingRunLoopMode
                                          dequeue:YES];
    if (!event) {
      mLastClickHoldTimedOut = YES;
      break;
    }

    curWindowLocation = [event locationInWindow];
    lastEvent = [event type];

    if (![self continueTracking:lastWindowLocation at:curWindowLocation inView:controlView])
      return NO;

    // Tracking process
    if (([event type] == NSLeftMouseDragged) &&
        (fabs(firstWindowLocation.x - curWindowLocation.x) > kDragThreshold ||
         fabs(firstWindowLocation.y - curWindowLocation.y) > kDragThreshold))
    {
      break;
    }

    if ([event type] == NSLeftMouseUp)
      break;

    lastWindowLocation = curWindowLocation;
  }

  if (mLastClickHoldTimedOut && mClickHoldAction) {
    [self stopTracking:lastWindowLocation at:curWindowLocation inView:controlView mouseIsUp:NO];
    [(NSControl*)controlView sendAction:mClickHoldAction to:[self target]];
    return YES;
  }

  if (lastEvent == NSLeftMouseUp)
    [(NSControl*)controlView sendAction:[self action] to:[self target]];

  [self stopTracking:lastWindowLocation at:curWindowLocation inView:controlView mouseIsUp:(lastEvent == NSLeftMouseUp)];
  return YES;  // XXX fix me
}

- (BOOL)trackOtherMouse:(NSEvent*)theEvent
                 inRect:(NSRect)cellFrame
                 ofView:(NSView*)controlView
           untilMouseUp:(BOOL)untilMouseUp
{
  NSPoint lastWindowLocation  = [theEvent locationInWindow];
  NSPoint curWindowLocation   = lastWindowLocation;
  BOOL mouseInsideCell;
  
  if ([theEvent type] == NSOtherMouseDown)
    [self highlight:YES withFrame:cellFrame inView:controlView];
  
  if (![self startTrackingAt:curWindowLocation inView:controlView])
    return NO;
  
  while(1) {
    NSEvent* event = [NSApp nextEventMatchingMask:(NSOtherMouseDraggedMask | NSOtherMouseUpMask)
                                        untilDate:[NSDate distantFuture]
                                           inMode:NSEventTrackingRunLoopMode
                                          dequeue:YES];
    curWindowLocation = [event locationInWindow];

    mouseInsideCell = NSPointInRect([controlView convertPoint:curWindowLocation fromView:nil], cellFrame);

    if (![self continueTracking:lastWindowLocation at:curWindowLocation inView:controlView])
      return NO;

    if ([event type] == NSOtherMouseDragged) {
      [self highlight:mouseInsideCell withFrame:cellFrame inView:controlView];
    } else if ([event type] == NSOtherMouseUp) {
      [self highlight:NO withFrame:cellFrame inView:controlView];
      break;
    }

    lastWindowLocation = curWindowLocation;
  }

  if (mouseInsideCell)
    [(NSControl*)controlView sendAction:mMiddleClickAction to:[self target]];

  [self stopTracking:lastWindowLocation at:curWindowLocation inView:controlView mouseIsUp:YES];
  return (untilMouseUp || mouseInsideCell);
}
    
@end

