/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */


#import <Foundation/Foundation.h>

@interface NSFileManager(CaminoFileManagerUtils)

- (BOOL)createDirectoriesInPath:(NSString *)path attributes:(NSDictionary *)attributes;

// this will return -1 on error
- (long long)sizeOfFileAtPath:(NSString*)inPath traverseLink:(BOOL)inTraverseLink;

// make a name for a backup file with the given path and suffix
// (e.g. bookmarks.plist will be changed to "bookmarksSUFFIX-1.plist".
- (NSString*)backupFileNameFromPath:(NSString*)inPath withSuffix:(NSString*)inFileSuffix;

// Finds the last modified subdirectory at the specified path. not recursive. 
// Ignores hidden directories and will return nil on failure.
- (NSString *)lastModifiedSubdirectoryAtPath:(NSString *)path;

@end
