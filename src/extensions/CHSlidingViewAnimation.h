/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>

// A subclass of NSAnimation which smoothly animates an NSView or NSWindow
// to a new location on screen.  Created as an alternative to NSViewAnimation
// since it never seems to produce smooth animations.  Furthermore,
// unlike NSViewAnimation, threaded animation will properly update the UI
// on the main thread.
@interface CHSlidingViewAnimation : NSAnimation {
 @private
  NSView *mAnimationTarget; // strong
  NSPoint mStartLocation;
  NSPoint mEndLocation;
}

// Designated initializer. See -setAnimationTarget: for details about the argument.
- (id)initWithAnimationTarget:(id)targetObject;

// The target to be animated must be either an NSWindow or NSView object.
// -setAnimationTarget raises an exception if the argument is not a supported object.
- (id)animationTarget;
- (void)setAnimationTarget:(id)newAnimationTarget;

// For an NSView, coordinates should be expressed in the local coordinate system of
// its container.  NSWindow targets should supply screen coordinates.
- (NSPoint)startLocation;
- (void)setStartLocation:(NSPoint)newStartLocation;

- (NSPoint)endLocation;
- (void)setEndLocation:(NSPoint)newEndLocation;


@end
