/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Foundation/Foundation.h>

typedef enum
{
  kTruncateAtStart,
  kTruncateAtMiddle,
  kTruncateAtEnd
} ETruncationType;


// a category to extend NSString
@interface NSString (ChimeraStringUtils)

+ (id)ellipsisString;
+ (NSString*)stringWithUUID;

- (BOOL)isEqualToStringIgnoringCase:(NSString*)inString;
- (BOOL)hasCaseInsensitivePrefix:(NSString*)inString;

// Some URIs can contain spaces and still work, even though they aren't strictly valid
// per RFC2396. This method allows us to account for those URIs.
- (BOOL)isLooselyValidatedURI;

// Utility method to identify URIs that can be run in the context of the current page.
// These URIs could be used as attack vectors via AppleScript, for example.
- (BOOL)isPotentiallyDangerousURI;

// URIs containing "%s" are bookmark shortcuts; this method allows us to treat
// them as real URLs when checking for URL data.
- (BOOL)isBookmarkShortcutURI;

// Utility method to ensure validity of URI strings. NSURL is used to validate
// most of them, but the NSURL test may fail for |javascript:| and |data:| URIs
// because they often contain invalid (per RFC2396) characters such as spaces.
- (BOOL)isValidURI;

- (NSString *)stringByRemovingCharactersInSet:(NSCharacterSet*)characterSet;
- (NSString *)stringByReplacingCharactersInSet:(NSCharacterSet*)characterSet withString:(NSString*)string;
- (NSString *)stringByTruncatingTo:(unsigned int)maxCharacters at:(ETruncationType)truncationType;
- (NSString *)stringByTruncatingToWidth:(float)inWidth at:(ETruncationType)truncationType withAttributes:(NSDictionary *)attributes;
- (NSString *)stringByTrimmingWhitespace;
- (NSString *)stringByRemovingAmpEscapes;
- (NSString *)stringByAddingAmpEscapes;

// Returns a version of the string with all regex special characters escaped.
- (NSString*)stringbyEscapingForRegex;

// Returns the conceptual character starting at |index|, correctly handling
// composed characters.
- (NSString*)composedCharacterAtIndex:(unsigned int)index;

// Returns the first |count| conceptual characters of the string. If the string
// has fewer than |count| characters, returns the original string.
- (NSString*)prefixWithCharacterCount:(unsigned int)count;

@end

@interface NSMutableString (ChimeraMutableStringUtils)

- (void)truncateTo:(unsigned)maxCharacters at:(ETruncationType)truncationType;
- (void)truncateToWidth:(float)maxWidth at:(ETruncationType)truncationType withAttributes:(NSDictionary *)attributes;

@end

@interface NSString (ChimeraFilePathStringUtils)

- (NSString*)volumeNamePathComponent;
- (NSString*)displayNameOfLastPathComponent;

@end

@interface NSString (CaminoURLStringUtils)

// Returns true if the string represents a "blank" URL ("" or "about:blank")
- (BOOL)isBlankURL;
// Returns a URI that looks good in a location field
- (NSString *)unescapedURI;

@end
