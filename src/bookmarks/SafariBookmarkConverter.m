/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "SafariBookmarkConverter.h"

#import "BookmarkItem.h"
#import "Bookmark.h"
#import "BookmarkFolder.h"
#import "BookmarkManager.h"

static NSString* const kEntryTypeKey = @"WebBookmarkType";
static NSString* const kChildrenKey = @"Children";
static NSString* const kURIDictKey = @"URIDictionary";
static NSString* const kBookmarkTitleKey = @"title";
static NSString* const kBookmarkFolderTitleKey = @"Title";
static NSString* const kTabGroupKey = @"WebBookmarkAutoTab";
static NSString* const kUUIDKey = @"WebBookmarkUUID";
static NSString* const kURLKey = @"URLString";
static NSString* const kProxyKey = @"WebBookmarkIdentifier";

static NSString* const kEntryTypeLeaf = @"WebBookmarkTypeLeaf";
static NSString* const kEntryTypeList = @"WebBookmarkTypeList";
static NSString* const kEntryTypeProxy = @"WebBookmarkTypeProxy";

@interface SafariBookmarkConverter (Private)
// Returns a the correct bookmark item type for the given Safari dictionary.
// Returns nil if the item is an unknown type.
- (BookmarkItem*)bookmarkItemForDictionary:(NSDictionary*)safariDict;

// Returns a native bookmark object for the given Safari dictionary.
- (Bookmark*)bookmarkForDictionary:(NSDictionary*)safariDict;

// Returns a native bookmark folder object for the given Safari dictionary.
- (BookmarkFolder*)bookmarkFolderForDictionary:(NSDictionary*)safariDict;

// Returns a Safari dictionary of the correct type for the given bookmark item.
// Returns nil if Safari doesn't have a corresponding type (e.g., separators).
- (NSDictionary*)safariDictionaryForBookmarkItem:(BookmarkItem*)bookmarkItem;

// Returns a Safari dictionary for the given bookmark.
- (NSDictionary*)safariDictionaryForBookmark:(Bookmark*)bookmark;

// Returns a Safari dictioray for the given bookmark folder.
// Returns nil if the folder is a special folder that Safari doesn't have.
- (NSDictionary*)safariDictionaryForBookmarkFolder:(BookmarkFolder*)bookmarkFolder;

// Returns the Safari proxy entry for the given smart folder, or nil if there
// is no corresponding Safari entry.
- (NSDictionary*)safariDictionaryForSmartFolder:(BookmarkFolder*)smartFolder;
@end

@implementation SafariBookmarkConverter

+ (id)safariBookmarkConverter
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
    NSLog(@"Plist file is not in Safari format.");
    return nil;
  }
  BookmarkFolder* rootFolder = [self bookmarkFolderForDictionary:dict];
  return rootFolder;
}

- (BookmarkItem*)bookmarkItemForDictionary:(NSDictionary*)safariDict
{
  if ([[safariDict objectForKey:kEntryTypeKey] isEqualToString:kEntryTypeLeaf])
    return [self bookmarkForDictionary:safariDict];
  if ([[safariDict objectForKey:kEntryTypeKey] isEqualToString:kEntryTypeList])
    return [self bookmarkFolderForDictionary:safariDict];
  // Could also be WebBookmarkTypeProxy - we'll ignore those.
  return nil;
}

- (Bookmark*)bookmarkForDictionary:(NSDictionary*)safariDict
{
  NSDictionary* uriDict = [safariDict objectForKey:kURIDictKey];
  return [Bookmark bookmarkWithTitle:[uriDict objectForKey:kBookmarkTitleKey]
                                 url:[safariDict objectForKey:kURLKey]
                           lastVisit:nil];
}

- (BookmarkFolder*)bookmarkFolderForDictionary:(NSDictionary*)safariDict
{
  BookmarkFolder* folder = [BookmarkFolder bookmarkFolderWithTitle:
                              [safariDict objectForKey:kBookmarkFolderTitleKey]];
  if ([[safariDict objectForKey:kTabGroupKey] boolValue])
    [folder setIsGroup:YES];

  NSEnumerator* enumerator = [[safariDict objectForKey:kChildrenKey] objectEnumerator];
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

#pragma mark -

- (void)writeBookmarks:(BookmarkFolder*)bookmarkRoot toFile:(NSString*)filePath
{
  NSDictionary* dict = [self safariDictionaryForBookmarkFolder:bookmarkRoot];
  if (![dict writeToFile:[filePath stringByStandardizingPath] atomically:YES])
    NSLog(@"Failed to write Safari bookmarks to '%@'", filePath);
}

- (NSDictionary*)safariDictionaryForBookmarkItem:(BookmarkItem*)bookmarkItem
{
  if ([bookmarkItem isSeparator])
    return nil;
  if ([bookmarkItem isKindOfClass:[BookmarkFolder class]])
    return [self safariDictionaryForBookmarkFolder:(BookmarkFolder*)bookmarkItem];
  return [self safariDictionaryForBookmark:(Bookmark*)bookmarkItem];
}

- (NSDictionary*)safariDictionaryForBookmark:(Bookmark*)bookmark
{
  if ([bookmark isSeparator])
    return nil;

  NSDictionary *uriDict = [NSDictionary dictionaryWithObjectsAndKeys:
                             [bookmark savedTitle], kBookmarkTitleKey,
                               [bookmark savedURL], @"",
                                                    nil];
  return [NSDictionary dictionaryWithObjectsAndKeys:
                        uriDict, kURIDictKey,
            [bookmark savedURL], kURLKey,
                 kEntryTypeLeaf, kEntryTypeKey,
                [bookmark UUID], kUUIDKey,
                                 nil];
}

- (NSDictionary*)safariDictionaryForBookmarkFolder:(BookmarkFolder*)bookmarkFolder
{
  if ([bookmarkFolder isSmartFolder])
    return [self safariDictionaryForSmartFolder:bookmarkFolder];

  NSMutableArray* children = [NSMutableArray array];
  NSEnumerator* enumerator = [[bookmarkFolder children] objectEnumerator];
  BookmarkItem* item;
  while ((item = [enumerator nextObject])) {
    NSDictionary* entryDict = [self safariDictionaryForBookmarkItem:item];
    if (entryDict)
      [children addObject:entryDict];
  }

  NSString *titleString;
  if ([bookmarkFolder isToolbar])
    titleString = @"BookmarksBar";
  else if ([[BookmarkManager sharedBookmarkManager] bookmarkMenuFolder] == bookmarkFolder)
    titleString = @"BookmarksMenu";
  else
    titleString = [bookmarkFolder title];

  NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                           titleString, kBookmarkFolderTitleKey,
                                        kEntryTypeList, kEntryTypeKey,
                                 [bookmarkFolder UUID], kUUIDKey,
                                              children, kChildrenKey,
                                                        nil];
  if ([bookmarkFolder isGroup])
    [dict setObject:[NSNumber numberWithBool:YES] forKey:kTabGroupKey];
  return dict;
}

- (NSDictionary*)safariDictionaryForSmartFolder:(BookmarkFolder*)smartFolder
{
  NSString* title = nil;
  NSString* proxy = nil;
  if (smartFolder == [[BookmarkManager sharedBookmarkManager] rendezvousFolder]) {
    title = @"Bonjour";
    proxy = @"Bonjour Bookmark Proxy Identifier";
  }
  else if (smartFolder == [[BookmarkManager sharedBookmarkManager] addressBookFolder]) {
    title = @"Address Book";
    proxy = @"Address Book Bookmark Proxy Identifier";
  }
  else if (smartFolder == [[BookmarkManager sharedBookmarkManager] historyFolder]) {
    title = @"History";
    proxy = @"History Bookmark Proxy Identifier";
  }

  if (title && proxy) {
    return [NSDictionary dictionaryWithObjectsAndKeys:
                           title, kBookmarkFolderTitleKey,
                           proxy, kProxyKey,
                 kEntryTypeProxy, kEntryTypeKey,
              [smartFolder UUID], kUUIDKey,
                                  nil];
  }
  return nil;
}

@end
