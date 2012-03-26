/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "BookmarkItem.h"

//Special flags
enum {
  kBookmarkFolder         = 0,
  kBookmarkFolderGroup    = 1 << 0,
  kBookmarkRootFolder     = 1 << 1,
  kBookmarkToolbarFolder  = 1 << 2,
  kBookmarkSmartFolder    = 1 << 3,
  kBookmarkDockMenuFolder = 1 << 4
};


@class Bookmark;

@interface BookmarkFolder : BookmarkItem
{
  NSMutableArray* mChildArray;
  unsigned int    mSpecialFlag;
  NSString*       mIdentifier;    // only non-nil for "special" collection folders. not saved (yet)
}

+ (id)bookmarkFolderWithTitle:(NSString*)title;
- (id)init;   // designated initializer
- (id)initWithIdentifier:(NSString*)inIdentifier; // will get used for special folders

- (NSArray *)children;
- (NSArray *)childURLs;
- (NSArray *)allChildBookmarks;

// enumerator for this folder and all its children (in depth-first order). not safe under
// tree changes during enumeration
- (NSEnumerator*)objectEnumerator;

- (void)setIdentifier:(NSString*)inIdentifier;
- (NSString*)identifier;

- (BOOL)isSpecial;  // True for special (app-defined) collections. Different meaning than the "special" in "special flag".
- (BOOL)isToolbar;
- (BOOL)isRoot;
- (BOOL)isGroup;
- (BOOL)isSmartFolder;
- (BOOL)isDockMenu;

- (void)setIsGroup:(BOOL)aGroupFlag;
- (void)setIsRoot:(BOOL)aFlag;
- (void)setIsToolbar:(BOOL)aFlag;
- (void)setIsSmartFolder:(BOOL)aFlag;
- (void)setIsDockMenu:(BOOL)aFlag;
- (void)toggleIsDockMenu:(id)sender;

// Things added to make it work sort of like an array
- (unsigned)count;
- (id)objectAtIndex:(unsigned)index;
- (unsigned)indexOfObject:(id)object;
- (unsigned)indexOfObjectIdenticalTo:(id)object;

// methods used for saving to files; are guaranteed never to return nil
- (id)savedSpecialFlag;

// for reading from disk
- (BOOL)readNativeDictionary:(NSDictionary *)aDict;

// ways to add a new bookmark array
- (BookmarkFolder *)addBookmarkFolder; //adds to end
- (BookmarkFolder *)addBookmarkFolder:(NSString *)aTitle inPosition:(unsigned)aIndex isGroup:(BOOL)aFlag;

// finding items by uuid
- (BookmarkItem *)itemWithUUID:(NSString*)uuid;

// Moving & Copying & inserting bookmarks/bookmark arrays
- (void)appendChild:(BookmarkItem *)aChild;
- (void)insertChild:(BookmarkItem *)aChild atIndex:(unsigned)aIndex isMove:(BOOL)aBool;
- (void)moveChild:(BookmarkItem *)aChild toBookmarkFolder:(BookmarkFolder *)aNewParent atIndex:(unsigned)aIndex;
// returns the new child
- (BookmarkItem*)copyChild:(BookmarkItem *)aChild toBookmarkFolder:(BookmarkFolder *)aNewParent atIndex:(unsigned)aIndex;

// Used for deleting bookmarks/bookmark arrays
- (BOOL)deleteChild:(BookmarkItem *)aChild;

// used for batch notifying about changes to this folder's children (and descendants)
- (void)notifyChildrenChanged;

// Smart Folder only methods
- (void)insertIntoSmartFolderChild:(BookmarkItem *)aItem;
- (void)insertIntoSmartFolderChild:(BookmarkItem *)aItem atIndex:(unsigned)inIndex;
- (void)deleteFromSmartFolderChildAtIndex:(unsigned)index;

// sorting
// Arrange the given items (which must be children of this folder) next to eachother and in
// the order determined by the selector. Undoable.
- (void)arrangeChildItems:(NSArray*)inChildItems usingSelector:(SEL)inSelector reverseSort:(BOOL)inReverse;
// Sort the children of this folder, optionally sorting deep. Optionally undoable.
- (void)sortChildrenUsingSelector:(SEL)inSelector reverseSort:(BOOL)inReverse sortDeep:(BOOL)inDeep undoable:(BOOL)inUndoable;
// Sort the children of this folder by descriptors, optionally deep and undoable.
- (void)sortChildrenUsingDescriptors:(NSArray*)descriptors deep:(BOOL)deep undoable:(BOOL)undoable;

// generation menus
- (void)buildFlatFolderList:(NSMenu *)menu depth:(unsigned)pad;

// searching
- (NSArray*)resolveShortcut:(NSString *)shortcut withArgs:(NSString *)args;
- (NSArray*)bookmarksWithString:(NSString*)searchString inFieldWithTag:(int)tag;
- (BOOL)containsChildItem:(BookmarkItem*)inItem;

@end
