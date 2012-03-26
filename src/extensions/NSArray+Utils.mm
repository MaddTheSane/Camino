/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "NSArray+Utils.h"

@implementation NSArray(CaminoNSArrayUtils)

- (id)firstObject
{
  if ([self count] > 0)
    return [self objectAtIndex:0];

  return nil;
}

- (id)safeObjectAtIndex:(unsigned)inIndex
{
  return (inIndex < [self count]) ? [self objectAtIndex:inIndex] : nil;
}

- (BOOL)containsStringWithPrefix:(NSString*)prefix
{
  NSEnumerator* stringEnumerator = [self objectEnumerator];
  NSString* string;
  while ((string = [stringEnumerator nextObject])) {
    if ([string hasPrefix:prefix])
      return YES;
  }
  return NO;
}

@end
