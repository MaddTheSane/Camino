/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*-
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "MoveCommand.h"
#import <AppKit/AppKit.h>

@implementation MoveCommand

// NSMoveCommand interprets "move to <collection>" as "replace <collection>".
// In those cases, substitute the semantic "move to end of <collection>".
// If <collection> is not actually a collection, the user will get an error.
- (id)performDefaultImplementation
{
  NSMutableDictionary *args = [NSMutableDictionary dictionaryWithDictionary:[self arguments]];
  id toLoc = [args objectForKey:@"ToLocation"];
  // If we were planning to replace something...
  if (toLoc && [toLoc isKindOfClass:[NSPositionalSpecifier class]] && [toLoc insertionReplaces]) {
    // ...substitute a similar NSPositionalSpecifier, only inserting at the end of the collection.
    NSPositionalSpecifier *newToLoc = [[[NSPositionalSpecifier alloc] initWithPosition:NSPositionEnd
                                                                       objectSpecifier:[toLoc objectSpecifier]] autorelease];
    [args setValue:newToLoc forKey:@"ToLocation"];
    [self setArguments:args];
  }

  // Let NSMoveCommand do what it does.
  return [super performDefaultImplementation];
}

@end
