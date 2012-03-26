/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "CHSlidingViewAnimation.h"

static const NSTimeInterval kDefaultAnimationDuration = 0.5;

@interface CHSlidingViewAnimation (Private)

- (void)setNewPosition:(NSValue*)newPoint;

@end

@implementation CHSlidingViewAnimation

- (id)initWithAnimationTarget:(id)targetObject
{
  if ((self = [super initWithDuration:kDefaultAnimationDuration animationCurve:NSAnimationEaseInOut]))
    [self setAnimationTarget:targetObject];

  return self;
}

- (void)dealloc
{
  [mAnimationTarget release];
  [super dealloc];
}

- (void)setCurrentProgress:(NSAnimationProgress)progress
{
  // We need to call super to update the progress value.
  [super setCurrentProgress:progress];

  // Calculate a new position based on the current progress.
  NSPoint newPosition = 
    NSMakePoint(floor(mStartLocation.x + ((mEndLocation.x - mStartLocation.x) * progress)),
                floor(mStartLocation.y + ((mEndLocation.y - mStartLocation.y) * progress)));

  // If the animation in running on a secondary thread, we should update the UI from the main thread.
  if ([self animationBlockingMode] == NSAnimationNonblockingThreaded) {
    [self performSelectorOnMainThread:@selector(setNewPosition:) 
                           withObject:[NSValue valueWithPoint:newPosition] 
                        waitUntilDone:NO];
  }
  else {
    [self setNewPosition:[NSValue valueWithPoint:newPosition]];
  }
}

- (void)setNewPosition:(NSValue*)newPoint
{
  // If the animation target is a NSView subclass, setFrameOrigin does not automatically mark
  // the view or its superview as needing display.
  if ([mAnimationTarget isKindOfClass:[NSView class]]) {
    [[mAnimationTarget superview] setNeedsDisplayInRect:[mAnimationTarget frame]];
    [mAnimationTarget setFrameOrigin:[newPoint pointValue]];
    [mAnimationTarget setNeedsDisplay:YES];
  }
  else {
    [mAnimationTarget setFrameOrigin:[newPoint pointValue]];
  }
}

- (void)stopAnimation
{
  if ([self isAnimating])
    [super stopAnimation];

  // NSAnimation does not reset progress when the animation is stopped.
  [super setCurrentProgress:0.0];
}

#pragma mark -

- (id)animationTarget
{
  return [[mAnimationTarget retain] autorelease]; 
}

- (void)setAnimationTarget:(id)newTargetObject
{
  if (mAnimationTarget == newTargetObject)
    return;

  if (![newTargetObject respondsToSelector:@selector(setFrameOrigin:)]) {
    [NSException raise:@"CHSlidingViewAnimationInvalidAnimationTarget" 
                format:@"The animation target must be either an NSWindow or NSView object"];
    mAnimationTarget = nil;
    return;
  }

  [mAnimationTarget release];
  mAnimationTarget = [newTargetObject retain];
}

- (NSPoint)startLocation
{
  return mStartLocation;
}

- (void)setStartLocation:(NSPoint)newStartLocation
{
  mStartLocation = newStartLocation;
}

- (NSPoint)endLocation
{
  return mEndLocation;
}

- (void)setEndLocation:(NSPoint)newEndLocation
{
  mEndLocation = newEndLocation;
}

@end
