/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "SafeBrowsingBar.h"
#import "CHGradient.h"
#import "RolloverImageButton.h"

@implementation SafeBrowsingBar

- (void)awakeFromNib
{
  [mCloseButton setImage:[NSImage imageNamed:@"popup_close"]];
  [mCloseButton setAlternateImage:[NSImage imageNamed:@"popup_close_pressed"]];
  [mCloseButton setHoverImage:[NSImage imageNamed:@"popup_close_hover"]];
  
  // The warning label's text color is set to black in the nib so it's visible
  // when editing. Revert it to the actual white color we display it in on the bar.
  [mWarningLabelTextField setTextColor:[NSColor whiteColor]];

  [self setLastKeySubview:mCloseButton];
}

- (void)drawRect:(NSRect)rect
{
  NSColor* startColor = [NSColor colorWithCalibratedRed:0.654902f green:0.101961f blue:0.094118f 
                                                  alpha:1.0f];
  NSColor* endColor = [NSColor colorWithCalibratedRed:0.349020f green:0.015686f blue:0.015686f 
                                                alpha:1.0f];

  CHGradient* backgroundGradient =
    [[[CHGradient alloc] initWithStartingColor:startColor
                                   endingColor:endColor] autorelease];
  
  [backgroundGradient drawInRect:[self bounds] angle:270.0];

  [[NSColor colorWithCalibratedWhite:0.70 alpha:1.0] set];
  [NSBezierPath strokeLineFromPoint:NSMakePoint(0, 0) toPoint:NSMakePoint(NSMaxX([self bounds]), 0)];
}

- (BOOL)isReplaceable
{
  return NO;
}

@end
