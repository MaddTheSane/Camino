/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "NSView+Utils.h"
#import "AutoSizingTextField.h"


@interface AutoSizingTextField(Private)

- (NSSize)sizeForFrame:(NSRect)inFrame;
- (void)adjustSize;

@end

#pragma mark -

@implementation AutoSizingTextField

- (void)setStringValue:(NSString*)inString
{
  [super setStringValue:inString];
  [self adjustSize];
}

- (void)setAttributedStringValue:(NSAttributedString *)inString
{
  [super setAttributedStringValue:inString];
  [self adjustSize];
}

- (void)setFrame:(NSRect)frameRect
{
  NSSize origSize = frameRect.size;
  frameRect.size = [self sizeForFrame:frameRect];

  if (![[self superview] isFlipped])
    frameRect.origin.y -= (frameRect.size.height - origSize.height);

  mSettingFrameSize = YES;
  [super setFrame:frameRect];
  mSettingFrameSize = NO;
}

- (void)setFrameSize:(NSSize)newSize
{
  if (mSettingFrameSize)
  {
    [super setFrameSize:newSize];
    return;
  }

  NSRect newFrame = [self frame];
  newFrame.size = newSize;
  [super setFrameSize:[self sizeForFrame:newFrame]];
}

- (NSSize)sizeForFrame:(NSRect)inFrame
{
  inFrame.size.height = 10000.0f;
  NSSize newSize = [[self cell] cellSizeForBounds:inFrame];
  // don't let it get zero height
  if (newSize.height == 0.0f)
  {
    NSFont* cellFont = [[self cell] font];
    float lineHeight = [cellFont ascender] - [cellFont descender];
    newSize.height = lineHeight;
  }
  
  newSize.width = inFrame.size.width;
  return newSize;
}

- (void)adjustSize
{
  // NSLog(@"%@ adjustSize (%@)", self, [self stringValue]);
  [self setFrameSizeMaintainingTopLeftOrigin:[self sizeForFrame:[self frame]]];
  //[self setFrameSize:[self sizeForFrame:[self frame]]];
}

@end
