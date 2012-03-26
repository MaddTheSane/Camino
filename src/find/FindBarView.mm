/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "FindBarView.h"
#import "NSWorkspace+Utils.h"
#import "CHGradient.h"

@implementation FindBarView

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super dealloc];
}

- (void)viewDidMoveToWindow
{
  if ([self window] && [NSWorkspace isLeopardOrHigher]) {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(windowKeyStatusChanged:)
                                                 name:NSWindowDidBecomeKeyNotification
                                               object:[self window]];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(windowKeyStatusChanged:)
                                                 name:NSWindowDidResignKeyNotification
                                               object:[self window]];
  }
}

- (void)windowKeyStatusChanged:(NSNotification *)aNotification
{
  [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)aRect
{
  // Only draw a gradient if the window is main; this isn't the way these bars
  // ususally work, but it is how the OS draws the status bar, and since the
  // find bar lives at the bottom of the window it looks better to match that.
  if ([NSWorkspace isLeopardOrHigher] && [[self window] isMainWindow]) {
    NSColor* startColor = [NSColor colorWithDeviceWhite:(233.0/255.0) alpha:1.0];
    NSColor* endColor = [NSColor colorWithDeviceWhite:(207.0/255.0) alpha:1.0];
    
    NSRect bounds = [self bounds];
    NSRect gradientRect = NSMakeRect(aRect.origin.x, 0,
                                     aRect.size.width, bounds.size.height - 1.0);
    
    CHGradient* backgroundGradient =
    [[[CHGradient alloc] initWithStartingColor:startColor
                                   endingColor:endColor] autorelease];
    [backgroundGradient drawInRect:gradientRect angle:270.0];
  }

  [super drawRect:aRect];

  // optimize drawing a bit so we're not *always* redrawing our top header. Only
  // draw if the area we're asked to draw overlaps with the top line.
  NSRect bounds = [self bounds];
  if (NSMaxY(bounds) <= NSMaxY(aRect)) {
    NSPoint leftPoint = NSMakePoint(bounds.origin.x, bounds.origin.y + bounds.size.height);
    NSPoint rightPoint = NSMakePoint(bounds.origin.x + bounds.size.width, bounds.origin.y + bounds.size.height);
    [NSBezierPath strokeLineFromPoint:leftPoint toPoint:rightPoint];
  }
}

@end
