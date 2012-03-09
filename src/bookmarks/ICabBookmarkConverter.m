/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* ***** BEGIN LICENSE BLOCK *****
 * Version: MPL 1.1/GPL 2.0/LGPL 2.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Original Code is Camino code.
 *
 * The Initial Developer of the Original Code is
 * Stuart Morgan
 * Portions created by the Initial Developer are Copyright (C) 2008
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *   Stuart Morgan <stuart.morgan@alumni.case.edu>
 *   Chris Lawson
 *
 * Alternatively, the contents of this file may be used under the terms of
 * either the GNU General Public License Version 2 or later (the "GPL"), or
 * the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
 * in which case the provisions of the GPL or the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of either the GPL or the LGPL, and not to allow others to
 * use your version of this file under the terms of the MPL, indicate your
 * decision by deleting the provisions above and replace them with the notice
 * and other provisions required by the GPL or the LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the MPL, the GPL or the LGPL.
 *
 * ***** END LICENSE BLOCK ***** */

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
