/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Foundation/Foundation.h>

@class BookmarkItem;
@class BookmarkFolder;

// Reads Opera bookmark files, converting them to Camino bookmark structures.
@interface OperaBookmarkConverter : NSObject {
}

+ (id)operaBookmarkConverter;

// Reads the bookmarks from |filePath| and returns the root bookmark folder
// from the import (or nil if importing fails).
- (BookmarkFolder*)bookmarksFromFile:(NSString*)filePath;

@end
