/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "TransientBar.h"

@implementation TransientBar

- (void)dealloc
{
  [self setLastKeySubview:nil];
  [super dealloc];
}

#pragma mark -

- (void)setFrame:(NSRect)aNewFrame
{
  // Subclasses can modify their height during this method, to accomodate
  // the given width.
  [super setFrame:aNewFrame];
}

- (NSView *)lastKeySubview
{
  return [[mLastKeySubview retain] autorelease]; 
}

- (void)setLastKeySubview:(NSView *)aLastKeySubview
{
  if (mLastKeySubview != aLastKeySubview) {
    [mLastKeySubview release];
    mLastKeySubview = [aLastKeySubview retain];
  }
}

- (BOOL)isReplaceable
{
  return YES;
}

@end
