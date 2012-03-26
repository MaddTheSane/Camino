/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "NSView+Utils.h"


@implementation NSView(CHViewUtils)

- (NSView*)swapFirstSubview:(NSView*)newSubview
{
  NSView* existingSubview = [self firstSubview];
  if (existingSubview == newSubview)
    return nil;

  [existingSubview retain];
  [existingSubview removeFromSuperview];
  [self addSubview:newSubview];
  [newSubview setFrame:[self bounds]];

  return [existingSubview autorelease];
}

- (NSView*)firstSubview
{
  NSArray* subviews = [self subviews];
  if ([subviews count] > 0)
    return [[self subviews] objectAtIndex:0];
  return 0;
}

- (NSView*)lastSubview
{
  NSArray* subviews = [self subviews];
  unsigned int numSubviews = [subviews count];
  if (numSubviews > 0)
    return [[self subviews] objectAtIndex:numSubviews - 1];
  return 0;
}

- (void)removeAllSubviews
{
  // clone the array to avoid issues with the array changing during the enumeration
  NSArray* subviewsArray = [[self subviews] copy];
  [subviewsArray makeObjectsPerformSelector:@selector(removeFromSuperview)];
  [subviewsArray release];
}

- (BOOL)hasSubview:(NSView*)inView
{
  return [[self subviews] containsObject:inView];
}

- (void)setFrameSizeMaintainingTopLeftOrigin:(NSSize)inNewSize
{
  if ([[self superview] isFlipped])
    [self setFrameSize:inNewSize];
  else
  {
    NSRect newFrame = [self frame];
    newFrame.origin.y -= (inNewSize.height - newFrame.size.height);
    newFrame.size = inNewSize;
    [self setFrame:newFrame];
  }
}

- (NSRect)subviewRectFromTopRelativeRect:(NSRect)inRect
{
  if ([self isFlipped])
    return inRect;

  NSRect theRect = inRect;
  theRect.origin.y = NSHeight([self bounds]) - NSMaxY(inRect);
  return theRect;
}


@end
