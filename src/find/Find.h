/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*-
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>

//
// protocol Find
//
// Any window who wants to be able to work with the Find dialog should implement
// this protocol.
//

@protocol Find

// Start a find at the current caret position
- (BOOL)findInPageWithPattern:(NSString*)text caseSensitive:(BOOL)inCaseSensitive
        wrap:(BOOL)inWrap backwards:(BOOL)inBackwards;


// Same as above, but use most recent values for search string,
// case sensitivity, and wrap-around.
- (BOOL)findInPage:(BOOL)inBackwards;

// Get the most recent search string.
- (NSString*)lastFindText;

@end
