/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>

@interface NSSplitView (CaminoExtensions)

// Returns the width (in pixels) of the left panel in the splitter
- (float)leftWidth;

// Sets the width of the left frame to |newWidth| (in pixels) and the right frame
// to the rest of the space. Does nothing if there are less than two panes.
- (void)setLeftWidth:(float)newWidth;

@end
