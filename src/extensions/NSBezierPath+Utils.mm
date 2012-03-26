/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "NSBezierPath+Utils.h"

@implementation NSBezierPath (ChimeraBezierPathUtils)

+ (NSBezierPath*)bezierPathWithRoundCorneredRect:(NSRect)rect cornerRadius:(float)cornerRadius
{
  float maxRadius = cornerRadius;
  if (NSWidth(rect) / 2.0 < maxRadius)
    maxRadius = NSWidth(rect) / 2.0;

  if (NSHeight(rect) / 2.0 < maxRadius)
    maxRadius = NSHeight(rect) / 2.0;

  NSBezierPath*	newPath = [NSBezierPath bezierPath];
  [newPath moveToPoint:NSMakePoint(NSMinX(rect) + maxRadius, NSMinY(rect))];

  [newPath appendBezierPathWithArcWithCenter:NSMakePoint(NSMaxX(rect) - maxRadius, NSMinY(rect) + maxRadius)
      radius:maxRadius startAngle:270.0 endAngle:0.0];

  [newPath appendBezierPathWithArcWithCenter:NSMakePoint(NSMaxX(rect) - maxRadius, NSMaxY(rect) - maxRadius)
      radius:maxRadius startAngle:0.0 endAngle:90.0];

  [newPath appendBezierPathWithArcWithCenter:NSMakePoint(NSMinX(rect) + maxRadius, NSMaxY(rect) - maxRadius)
      radius:maxRadius startAngle:90.0 endAngle:180.0];

  [newPath appendBezierPathWithArcWithCenter:NSMakePoint(NSMinX(rect) + maxRadius, NSMinY(rect) + maxRadius)
      radius:maxRadius startAngle:180.0 endAngle:270.0];
  
  [newPath closePath];
  
  return newPath;
}

@end
