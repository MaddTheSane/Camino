/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>


@interface NSURL (CaminoExtensions) 

// This takes an NSURL to a local file, and if that file is a file that
// represents a URL, returns the URL it contains. Otherwise, returns the
// passed URL. Supports .url, .webloc, .ftploc, and .caminobookmark files.
+ (NSURL*)decodeLocalFileURL:(NSURL*)url;

// Returns the URL for a plist file containing a URL key, or nil on failure.
+(NSURL*)URLFromPlist:(NSString*)inFile;

+(NSURL*)URLFromInetloc:(NSString*)inFile;
+(NSURL*)URLFromIEURLFile:(NSString*)inFile;

@end
