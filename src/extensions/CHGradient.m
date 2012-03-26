/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "CHGradient.h"

// Callback function for CGShadingCreateAxial. Takes the start and end colors
// as an 8-element array in |inInfo| (start RGBA, end RGBA), and the fraction
// of the way through the gradient ([0.0 - 1.0]) as the one entry in |inData|,
// and returns the color for that location as a 4-element array (RGBA) through
// |outData|
static void GradientComputation(void* inInfo, float const* inData, float* outData)
{
  float* startColor = (float*)inInfo;
  float* endColor = startColor + 4;
  float interval = inData[0];
  for (int i = 0; i < 4; ++i)
    outData[i] = (1.0 - interval)*startColor[i] + interval*endColor[i];
}

@implementation CHGradient

- (id)initWithStartingColor:(NSColor*)startingColor
                endingColor:(NSColor*)endingColor
{
  if ((self = [super init])) {
    mStartingColor = [[startingColor colorUsingColorSpaceName:NSDeviceRGBColorSpace] retain];
    mEndingColor = [[endingColor colorUsingColorSpaceName:NSDeviceRGBColorSpace] retain];
  }
  return self;
}

- (void)dealloc
{
  [mStartingColor release];
  [mEndingColor release];
  [super dealloc];
}

- (void)drawInRect:(NSRect)rect angle:(float)angle
{
  float colors[8];
  [mStartingColor getRed:&colors[0] green:&colors[1] blue:&colors[2] alpha:&colors[3]];
  [mEndingColor getRed:&colors[4] green:&colors[5] blue:&colors[6] alpha:&colors[7]];

  CGPoint startPoint, endPoint;
  if (angle < 1.0) {
    startPoint = CGPointMake(NSMinX(rect), NSMinY(rect));
    endPoint = CGPointMake(NSMaxX(rect), NSMinY(rect));
  }
  else if (angle < 91.0) {
    startPoint = CGPointMake(NSMinX(rect), NSMinY(rect));
    endPoint = CGPointMake(NSMinX(rect), NSMaxY(rect));
  }
  else if (angle < 181.0) {
    startPoint = CGPointMake(NSMaxX(rect), NSMinY(rect));
    endPoint = CGPointMake(NSMinX(rect), NSMinY(rect));
  }
  else {
    startPoint = CGPointMake(NSMinX(rect), NSMaxY(rect));
    endPoint = CGPointMake(NSMinX(rect), NSMinY(rect));
  }

  struct CGFunctionCallbacks callbacks = {0, GradientComputation, NULL};
  CGFunctionRef function = CGFunctionCreate(colors, 1, NULL, 4, NULL,
                                            &callbacks);
  
  // We require a device dependent RGB profile, to keep same set colors when a display profile
  // is NOT using the standard Apple Gamma (1.8)
  // In the documentation it says that this function in Mac OS X v10.4 and later is
  // replaced by the Generic RGB colorspace (kCGColorSpaceGenericRGB) but in practice
  // this appears NOT to be the case.
  CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
  CGShadingRef shading = CGShadingCreateAxial(colorspace,
                                              startPoint,
                                              endPoint,
                                              function, false, false);
  CGContextRef context = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];

  CGContextSaveGState(context);
  CGContextClipToRect(context, CGRectMake(rect.origin.x, rect.origin.y,
                                          rect.size.width, rect.size.height));
  CGContextDrawShading(context, shading);
  CGContextRestoreGState(context);

  CGShadingRelease(shading);
  CGColorSpaceRelease(colorspace);
  CGFunctionRelease(function);
}

@end
