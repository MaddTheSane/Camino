/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "NSSplitView+Utils.h"

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@implementation NSSplitView (CaminoExtensions)

//
// -leftWidth
//
// Returns the width (in pixels) of the left panel in the splitter
//
- (float)leftWidth
{
  if ([[self subviews] count] < 1)
    return 0.0;

  NSRect leftFrame = [[[self subviews] objectAtIndex:0] frame];
  return leftFrame.size.width;
}

//
// -setLeftWidth:
//
// Sets the width of the left frame to |newWidth| (in pixels) and the right frame
// to the rest of the space. Does nothing if there are less than two panes.
//
- (void)setLeftWidth:(float)newWidth;
{
  if ([[self subviews] count] < 2 || newWidth < 0)
    return;

  // Since we're just setting the widths of the frames (not their origins),
  // we can ignore the thickness of the slider itself.
  NSView* leftView = [[self subviews] objectAtIndex:0];
  NSView* rightView = [[self subviews] objectAtIndex:1];
  NSRect leftFrame = [leftView frame];
  NSRect rightFrame = [rightView frame];
  float totalWidth = leftFrame.size.width + rightFrame.size.width;
  
  leftFrame.size.width = newWidth;
  rightFrame.size.width = totalWidth - newWidth;
  [leftView setFrame:leftFrame];
  [rightView setFrame:rightFrame];
  [self setNeedsDisplay: YES];
}

@end
