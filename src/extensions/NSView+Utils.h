/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <AppKit/AppKit.h>

// category on NSView to add utilities for easy view resizing etc.

@interface NSView(CHViewUtils)

// swap in the given subview as the first subview of the receiver,
// returning the old view. Does nothing if the given view is
// alreay the first subview
- (NSView*)swapFirstSubview:(NSView*)newSubview;

- (NSView*)firstSubview;
- (NSView*)lastSubview;

- (void)removeAllSubviews;

// is 'inView' an immediate subview of the receiver
- (BOOL)hasSubview:(NSView*)inView;

- (void)setFrameSizeMaintainingTopLeftOrigin:(NSSize)inNewSize;

// convert inRect to view coords depending on whether the view is flipped
- (NSRect)subviewRectFromTopRelativeRect:(NSRect)inRect;

@end
