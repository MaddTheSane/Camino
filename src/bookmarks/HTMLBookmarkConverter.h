/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Foundation/Foundation.h>

@class BookmarkItem;
@class BookmarkFolder;

@interface HTMLBookmarkConverter : NSObject {
}

+ (id)htmlBookmarkConverter;

// Reads the bookmarks from |filePath| and returns the root bookmark folder
// from the import (or nil if importing fails). If the file is corrupt, this
// will return as much as it can extract.
- (BookmarkFolder*)bookmarksFromFile:(NSString*)filePath;

// Writes the bookmark hierarchy rooted at |rootBookmarkItem| to a Netscape form
// HTML file at |filePath|.
- (void)writeBookmarks:(BookmarkFolder*)bookmarkRoot toFile:(NSString*)filePath;

@end
