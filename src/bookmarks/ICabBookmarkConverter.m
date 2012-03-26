/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "ICabBookmarkConverter.h"

#import "BookmarkItem.h"
#import "Bookmark.h"
#import "BookmarkFolder.h"
#import "BookmarkManager.h"

static NSString* const kEntryTypeKey = @"BookmarkType";
static NSString* const kFolderTypeKey = @"FolderType";
static NSString* const kChildrenKey = @"Children";
static NSString* const kBookmarkTitleKey = @"Title";
static NSString* const kBookmarkFolderTitleKey = @"Title";
static NSString* const kURLKey = @"URL";
static NSString* const kRemarksKey = @"Description";

// Types of bookmarks
static NSString* const kBookmarkTypeBookmark = @"Bookmark";
static NSString* const kBookmarkTypeFolder = @"Folder";
static NSString* const kBookmarkTypeSeparator = @"Separator";

// Types of folders
static NSString* const kFolderTypeTabGroup = @"TabGroup";


@interface ICabBookmarkConverter (Private)
// Returns a the correct bookmark item type for the given iCab dictionary.
// Returns nil if the item is an unknown type.
- (BookmarkItem*)bookmarkItemForDictionary:(NSDictionary*)iCabDict;

// Returns a native bookmark object for the given iCab dictionary.
- (Bookmark*)bookmarkForDictionary:(NSDictionary*)iCabDict;

// Returns a native bookmark folder object for the given iCab dictionary.
- (BookmarkFolder*)bookmarkFolderForDictionary:(NSDictionary*)iCabDict;
@end

@implementation ICabBookmarkConverter

+ (id)iCabBookmarkConverter
{
  return [[[self alloc] init] autorelease];
}

- (BookmarkFolder*)bookmarksFromFile:(NSString*)filePath
{
  NSDictionary* dict = [NSDictionary dictionaryWithContentsOfFile:filePath];
  if (!dict) {
    NSLog(@"Unable to read plist file.");
    return nil;
  }
  if (![dict objectForKey:kEntryTypeKey]) {
    NSLog(@"Plist file is not in iCab format.");
    return nil;
  }
  BookmarkFolder* rootFolder = [self bookmarkFolderForDictionary:dict];
  return rootFolder;
}

- (BookmarkItem*)bookmarkItemForDictionary:(NSDictionary*)iCabDict
{
  if ([[iCabDict objectForKey:kEntryTypeKey] isEqualToString:kBookmarkTypeBookmark])
    return [self bookmarkForDictionary:iCabDict];

  if ([[iCabDict objectForKey:kEntryTypeKey] isEqualToString:kBookmarkTypeSeparator])
    return [Bookmark separator];

  if ([[iCabDict objectForKey:kEntryTypeKey] isEqualToString:kBookmarkTypeFolder])
    return [self bookmarkFolderForDictionary:iCabDict];

  // Ignore anything we don't support or recognize.
  // XXX Once we implement Smart Folders, we'd like to import iCab's, too.
  return nil;
}

- (Bookmark*)bookmarkForDictionary:(NSDictionary*)iCabDict
{
  Bookmark* caminoBookmark = [Bookmark bookmarkWithTitle:[iCabDict objectForKey:kBookmarkTitleKey]
                                                     url:[iCabDict objectForKey:kURLKey]
                                               lastVisit:nil];
  [caminoBookmark setItemDescription:[iCabDict objectForKey:kRemarksKey]];
  return caminoBookmark;
}

- (BookmarkFolder*)bookmarkFolderForDictionary:(NSDictionary*)iCabDict
{
  BookmarkFolder* folder = [BookmarkFolder bookmarkFolderWithTitle:
      [iCabDict objectForKey:kBookmarkFolderTitleKey]];
  if ([[iCabDict objectForKey:kFolderTypeKey] isEqualToString:kFolderTypeTabGroup])
    [folder setIsGroup:YES];

  NSEnumerator* enumerator = [[iCabDict objectForKey:kChildrenKey] objectEnumerator];
  id child;
  while ((child = [enumerator nextObject])) {
    if (![child isKindOfClass:[NSDictionary class]])
      continue;
    BookmarkItem* bookmarkItem = [self bookmarkItemForDictionary:child];
    if (bookmarkItem)
      [folder appendChild:bookmarkItem];
  }

  return folder;
}

@end
