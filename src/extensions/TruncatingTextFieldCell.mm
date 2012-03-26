/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */


#import "NSString+Utils.h"

#import "TruncatingTextFieldCell.h"

@interface TruncatingTextFieldCell(Private)

- (NSString*)truncatedStringForRect:(NSRect)inRect;
- (NSDictionary*)fontAttributes;
- (NSRect)textBoundsForFrame:(NSRect)inFrameRect;

@end

@implementation TruncatingTextFieldCell

// designated initializer
- (id)initTextCell:(NSString*)inTextValue
{
  if ((self = [super initTextCell:inTextValue]))
  {
    mTruncationPosition = kTruncateAtEnd;
  }
  return self;
}

- (id)initTextCell:(NSString*)inTextValue truncation:(ETruncationType)truncType
{
  if ((self = [self initTextCell:inTextValue]))
  {
    mTruncationPosition = truncType;
  }
  return self;
}

- (void)setTruncationPosition:(ETruncationType)truncType
{
  mTruncationPosition = truncType;
  // redo truncation?
}

- (ETruncationType)truncationPosition
{
  return mTruncationPosition;
}

- (void)setStringValue:(NSString*)inValue
{
  NSString* oldValue = mOriginalStringValue;
  mOriginalStringValue = [inValue retain];
  [oldValue release];
  [super setStringValue:inValue];
}

- (NSString*)stringValue
{
  return mOriginalStringValue;
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
  [super setStringValue:[self truncatedStringForRect:cellFrame]];
  [super drawInteriorWithFrame:cellFrame inView:controlView];
}

- (NSString*)truncatedStringForRect:(NSRect)inRect
{
  NSRect textRect = [self textBoundsForFrame:inRect];
  return [mOriginalStringValue stringByTruncatingToWidth:NSWidth(textRect)
                                                      at:mTruncationPosition
                                          withAttributes:[self fontAttributes]];
}

- (NSDictionary*)fontAttributes
{
  return [NSDictionary dictionaryWithObject:[self font] forKey:NSFontAttributeName];
}

- (NSRect)textBoundsForFrame:(NSRect)inFrameRect
{
  // values derived empirically
  return NSInsetRect(inFrameRect, 2.0f, 0.0f);
}

@end

