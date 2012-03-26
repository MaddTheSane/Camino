/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Foundation/Foundation.h>

// NSArray utilities
@interface NSArray(CaminoNSArrayUtils)

- (id)firstObject;

// just returns nil if out of range, rather than throwing.
- (id)safeObjectAtIndex:(unsigned)inIndex;

// Returns YES if any of the array items match the given prefix. Should only
// be called on arrays of NSStrings.
- (BOOL)containsStringWithPrefix:(NSString*)prefix;

@end
