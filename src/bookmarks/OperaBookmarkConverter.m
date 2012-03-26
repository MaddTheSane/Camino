/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "OperaBookmarkConverter.h"

#import "NSString+Utils.h"

#import "BookmarkItem.h"
#import "Bookmark.h"
#import "BookmarkFolder.h"

// Opera bookmark file markers and property keys.
static NSString* const kFolderStartMarker = @"#FOLDER";
static NSString* const kFolderEndMarker = @"-";
static NSString* const kBookmarkStartMarker = @"#URL";
// note Opera's spelling: SEPERATOR (instead of SEPARATOR)
static NSString* const kSeparatorMarker = @"#SEPERATOR";
static NSString* const kTitleKey = @"NAME";
static NSString* const kURLKey = @"URL";
static NSString* const kDescriptionKey = @"DESCRIPTION";
static NSString* const kShortcutKey = @"SHORT NAME";

// The format for Opera bookmarks is a flat file with a series of
// space-separated blocks:
// 
// MARKER
//   KEY=value
//   KEY=value
//   KEY=value
// 
// MARKER
//   KEY=value
// 
// ...
// 
// Folders work the same way, and everything following is enclosed in that
// folder until a line consisting of:
// -
// ends that folder.

@interface OperaBookmarkConverter (Private)

// Consumes lines from enumerator, constructing the appropriate bookmark items,
// until the end of the current folder is reached.
- (void)readLines:(NSEnumerator*)enumerator intoFolder:(BookmarkFolder*)parent;

// Reads key-value pairs from the enumerator until a non-key-value line is
// reached, returning the pairs as a dictionary.
- (NSDictionary*)readProperties:(NSEnumerator*)lineEnumerator;

@end

@implementation OperaBookmarkConverter

+ (id)operaBookmarkConverter
{
  return [[[self alloc] init] autorelease];
}

- (BookmarkFolder*)bookmarksFromFile:(NSString*)filePath
{
  NSString* fileAsString = [NSString stringWithContentsOfFile:filePath
                                                     encoding:NSUTF8StringEncoding
                                                        error:NULL];
  if (!fileAsString) {
    NSLog(@"Couldn't read Opera bookmark file.");
    return nil;
  }
  NSRange headerRange = [fileAsString rangeOfString:@"Opera Hotlist"
                                            options:NSCaseInsensitiveSearch];
  if (headerRange.location == NSNotFound) {
    NSLog(@"Bookmark file not recognized as Opera Hotlist.");
    return nil;
  }

  BookmarkFolder *rootFolder = [[[BookmarkFolder alloc] init] autorelease];

  NSArray *lines = [fileAsString componentsSeparatedByString:@"\n"];
  [self readLines:[lines objectEnumerator] intoFolder:rootFolder];

  return rootFolder;
}

- (void)readLines:(NSEnumerator*)enumerator intoFolder:(BookmarkFolder*)parent
{
  NSString *line;
  while ((line = [enumerator nextObject])) {
    if ([line hasPrefix:kFolderStartMarker]) {
      NSDictionary* properties = [self readProperties:enumerator];
      BookmarkFolder* folder =
          [BookmarkFolder bookmarkFolderWithTitle:[properties objectForKey:kTitleKey]];
      [parent appendChild:folder];
      [self readLines:enumerator intoFolder:folder];
    }
    else if ([line hasPrefix:kBookmarkStartMarker]) {
      NSDictionary* properties = [self readProperties:enumerator];
      BookmarkItem* bookmark =
          [Bookmark bookmarkWithTitle:[properties objectForKey:kTitleKey]
                                  url:[properties objectForKey:kURLKey]
                            lastVisit:nil];
      if ([properties objectForKey:kDescriptionKey])
        [bookmark setItemDescription:[properties objectForKey:kDescriptionKey]];
      if ([properties objectForKey:kShortcutKey])
        [bookmark setItemDescription:[properties objectForKey:kShortcutKey]];
      [parent appendChild:bookmark];
    }
    else if ([line hasPrefix:kSeparatorMarker]) {
      [parent appendChild:[Bookmark separator]];
    }
    else if ([line hasPrefix:kFolderEndMarker])
      return;
  }
}

- (NSDictionary*)readProperties:(NSEnumerator*)lineEnumerator
{
  NSMutableDictionary* properties = [NSMutableDictionary dictionary];
  NSString *line;
  while ((line = [lineEnumerator nextObject])) {
    NSRange equalsRange = [line rangeOfString:@"="];
    // Each section ends with a blank line, so it's okay that this eats one
    // line past the key-value lines.
    if (equalsRange.location == NSNotFound)
      break;
    [properties setObject:[line substringFromIndex:(equalsRange.location + 1)]
                   forKey:[[line substringToIndex:equalsRange.location]
                              stringByTrimmingWhitespace]];
  }
  return properties;
}

@end
