/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "StatusBarView.h"

#import "NSWorkspace+Utils.h"

@implementation StatusBarView

//
// -drawRect:
//
// Override to draw the top header of the status bar
//
- (void)drawRect:(NSRect)aRect
{
  [super drawRect:aRect];
  
  if (![NSWorkspace isLeopardOrHigher]) {
    // optimize drawing a bit so we're not *always* redrawing our top header. Only
    // draw if the area we're asked to draw overlaps with the top line.
    NSRect bounds = [self bounds];
    if (NSMaxY(bounds) <= NSMaxY(aRect)) {
      NSPoint leftPoint = NSMakePoint(bounds.origin.x, bounds.origin.y + bounds.size.height);
      NSPoint rightPoint = NSMakePoint(bounds.origin.x + bounds.size.width, bounds.origin.y + bounds.size.height);
      [NSBezierPath strokeLineFromPoint:leftPoint toPoint:rightPoint];
    }
  }
}

@end
