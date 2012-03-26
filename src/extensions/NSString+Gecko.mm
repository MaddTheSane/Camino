/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "NSString+Gecko.h"

#include "nsString.h"
#include "nsPromiseFlatString.h"
#include "nsCRT.h"


@implementation NSString (ChimeraGeckoStringUtils)

+ (id)stringWithPRUnichars:(const PRUnichar*)inString
{
  if (inString)
    return [self stringWithCharacters:inString length:nsCRT::strlen(inString)];
  else
    return [self string];
}

+ (id)stringWith_nsAString:(const nsAString&)inString
{
  nsPromiseFlatString flatString = PromiseFlatString(inString);
  return [self stringWithCharacters:flatString.get() length:flatString.Length()];
}

+ (id)stringWith_nsACString:(const nsACString&)inString
{
  nsPromiseFlatCString flatString = PromiseFlatCString(inString);
  return [self stringWithUTF8String:flatString.get()];
}

- (id)initWith_nsAString:(const nsAString&)inString
{
  nsPromiseFlatString flatString = PromiseFlatString(inString);
  return [self initWithCharacters:flatString.get() length:flatString.Length()];
}

- (id)initWith_nsACString:(const nsACString&)inString
{
  nsPromiseFlatCString flatString = PromiseFlatCString(inString);
  return [self initWithUTF8String:flatString.get()];
}

- (id)initWithPRUnichars:(const PRUnichar*)inString
{
  return [self initWithCharacters:inString length:nsCRT::strlen(inString)];
}

#define ASSIGN_STACK_BUFFER_CHARACTERS  256

- (void)assignTo_nsAString:(nsAString&)ioString
{
  PRUnichar     stackBuffer[ASSIGN_STACK_BUFFER_CHARACTERS];
  PRUnichar*    buffer = stackBuffer;

  // XXX maybe fix this to use SetLength(0), SetLength(len), and a writing iterator.
  unsigned int len = [self length];

  if (len + 1 > ASSIGN_STACK_BUFFER_CHARACTERS) {
    buffer = (PRUnichar *)malloc(sizeof(PRUnichar) * (len + 1));
    if (!buffer)
      return;
  }

  [self getCharacters:buffer];   // does not null terminate
  ioString.Assign(buffer, len);

  if (buffer != stackBuffer)
    free(buffer);
}

- (PRUnichar*)createNewUnicodeBuffer
{
  PRUint32 length = [self length];
  PRUnichar* retStr = (PRUnichar*)nsMemory::Alloc((length + 1) * sizeof(PRUnichar));
  [self getCharacters:retStr];
  retStr[length] = PRUnichar(0);
  return retStr;
}

// Windows buttons have shortcut keys specified by ampersands in the
// title string. This function removes them from such strings.
-(NSString*)stringByRemovingWindowsShortcutAmpersand
{
  NSMutableString* dirtyStringMutant = [NSMutableString stringWithString:self];
  // we loop through removing all single ampersands and reducing double ampersands to singles
  unsigned int searchLocation = 0;
  while (searchLocation < [dirtyStringMutant length]) {
    searchLocation = [dirtyStringMutant rangeOfString:@"&" options:nil
                                                range:NSMakeRange(searchLocation, [dirtyStringMutant length] - searchLocation)].location;
    if (searchLocation == NSNotFound) {
      break;
    }
    else {
      [dirtyStringMutant deleteCharactersInRange:NSMakeRange(searchLocation, 1)];
      // ampersand or not, we leave the next character alone
      searchLocation++;
    }
  }
  return [NSString stringWithString:dirtyStringMutant];
}

@end
