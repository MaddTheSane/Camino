/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>

//
// CHGradient
//
// A partial implementation of NSGradient, for use pre-10.5. Once
// Camino is 10.5+, all clients should be able to seamless switch to NSGradient.
//
@interface CHGradient : NSObject {
  NSColor* mStartingColor;  // strong
  NSColor* mEndingColor;    // strong
}

- (id)initWithStartingColor:(NSColor*)startingColor
                endingColor:(NSColor*)endingColor;

// Like the NSGradient method of the same name, except that CHGradient
// currently allows only 0, 90, 180, and 270 degree angles.
- (void)drawInRect:(NSRect)rect angle:(float)angle;

@end
