/* This Source Code Form is subject to the terms of the Mozilla Public
* License, v. 2.0. If a copy of the MPL was not distributed with this
* file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Foundation/Foundation.h>
#import "nscore.h"

class nsAString;
class nsACString;

// A category to add Gecko string translation to NSString
@interface NSString (ChimeraGeckoStringUtils)

+ (id)stringWithPRUnichars:(const PRUnichar*)inString;
+ (id)stringWith_nsAString:(const nsAString&)inString;
+ (id)stringWith_nsACString:(const nsACString&)inString;    // assumes nsACString is UTF-8
- (void)assignTo_nsAString:(nsAString&)ioString;

- (id)initWith_nsAString:(const nsAString&)inString;
- (id)initWith_nsACString:(const nsACString&)inString;    // assumes nsACString is UTF-8
- (id)initWithPRUnichars:(const PRUnichar*)inString;

- (NSString *)stringByRemovingWindowsShortcutAmpersand;

// allocate a new unicode buffer with the contents of the current string. Caller
// is responsible for freeing the buffer.
- (PRUnichar*)createNewUnicodeBuffer;

@end
