/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <AppKit/AppKit.h>

extern NSString* const kCorePasteboardFlavorType_url;
extern NSString* const kCorePasteboardFlavorType_urln;
extern NSString* const kCorePasteboardFlavorType_urld;

extern NSString* const kCaminoBookmarkListPBoardType;
extern NSString* const kWebURLsWithTitlesPboardType;

@interface NSPasteboard(ChimeraPasteboardURLUtils)

- (int) declareURLPasteboardWithAdditionalTypes:(NSArray*)additionalTypes owner:(id)newOwner;
- (void) setDataForURL:(NSString*)url title:(NSString*)title;

- (void) setURLs:(NSArray*)inUrls withTitles:(NSArray*)inTitles;
- (void) getURLs:(NSArray**)outUrls andTitles:(NSArray**)outTitles;
- (BOOL) containsURLData;

@end

