/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>

// The position of the bar in relation to the browser content.
typedef enum {
  eTransientBarPositionTop,
  eTransientBarPositionBottom
} ETransientBarPosition;

//
// TransientBar
//
// An abstract class for creating an information bar which can be displayed around
// browser content.
//
@interface TransientBar : NSView {
 @private
  NSView *mLastKeySubview;
}

// Bars may adjust their height inside this method to accommodate the supplied width.
// The new frame value will be re-fetched by the browser after the initial call, to
// determine any changes in height.
- (void)setFrame:(NSRect)aNewFrame;

// The last view in the bar's internal key view loop.
- (NSView *)lastKeySubview;
- (void)setLastKeySubview:(NSView *)aLastKeySubview;

// Indicates whether the bar could be replaced, by a subsequent call to insert 
// another one in the same position. Subclasses can override this method to ensure
// important bars (security, for instance) are not replaced by less urgent ones.
- (BOOL)isReplaceable;

@end
