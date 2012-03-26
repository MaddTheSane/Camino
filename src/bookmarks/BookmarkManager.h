/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <AppKit/AppKit.h>
#import "BookmarkNotifications.h"

@class BookmarkItem;
@class BookmarkFolder;
@class BookmarkImportDlgController;
@class BookmarkOutlineView;
@class KindaSmartFolderManager;

extern NSString* const kBookmarkManagerStartedNotification;
extern NSString* const kBookmarksToolbarFolderIdentifier;
extern NSString* const kBookmarksMenuFolderIdentifier;

extern NSString* const kBookmarkImportPathIndentifier;
extern NSString* const kBookmarkImportNewFolderNameIdentifier;

extern const int kBookmarksContextMenuArrangeSeparatorTag;


@interface BookmarkManager : NSObject
{
  BookmarkFolder*                 mBookmarkRoot;           // root bookmark object
  KindaSmartFolderManager*        mSmartFolderManager;      // brains behind 4 smart folders
  NSUndoManager*                  mUndoManager;             // handles deletes, adds of bookmarks
  BookmarkImportDlgController*    mImportDlgController;
  NSString*                       mPathToBookmarkFile;
  NSString*                       mMetadataPath;            // where we store spotlight cache (strong)

  NSMutableDictionary*            mBookmarkURLMap;          // map of cleaned bookmark url to bookmark item set
  NSMutableDictionary*            mBookmarkFaviconURLMap;   // map of cleaned bookmark favicon url to bookmark item set

  // smart folders
  BookmarkFolder*                 mTop10Container;
  BookmarkFolder*                 mRendezvousContainer;
  BookmarkFolder*                 mAddressBookContainer;

  BookmarkFolder*                 mLastUsedFolder;

  BOOL                            mBookmarksLoaded;
  BOOL                            mShowSiteIcons;
  BOOL                            mSearchActive;
  BOOL                            mWritingSpotlightMetadata;

  int                             mNotificationsSuppressedCount;
  NSRecursiveLock*                mNotificationsSuppressedLock;    // make mNotificationsSuppressedCount threadsafe
}

// Class Methods & shutdown stuff
+ (BookmarkManager*)sharedBookmarkManager;
+ (BookmarkManager*)sharedBookmarkManagerDontCreate;

- (void)loadBookmarksLoadingSynchronously:(BOOL)loadSync;

- (void)shutdown;

- (BOOL)bookmarksLoaded;

- (BOOL)showSiteIcons;

+ (NSArray*)serializableArrayWithBookmarkItems:(NSArray*)bmArray;
+ (NSArray*)bookmarkItemsFromSerializableArray:(NSArray*)bmArray;
+ (NSArray*)bookmarkURLsFromSerializableArray:(NSArray*)bmArray;

// Getters/Setters
- (BookmarkFolder *)bookmarkRoot;
- (BookmarkFolder *)toolbarFolder;
- (BookmarkFolder *)bookmarkMenuFolder;
- (BookmarkFolder *)dockMenuFolder;
- (BookmarkFolder *)top10Folder;
- (BookmarkFolder *)rendezvousFolder;
- (BookmarkFolder *)addressBookFolder;
- (BookmarkFolder *)historyFolder;

- (BOOL)isUserCollection:(BookmarkFolder *)inFolder;

- (BOOL)searchActive;
- (void)setSearchActive:(BOOL)inSearching;

// Must be called whenever any new not-smart-folder bookmarks are added.
// Should be called at the UI operation level.
- (void)bookmarkItemsAdded:(NSArray*)bookmarks;
// Must be called whenever any bookmarks will be removed.
// Should be called at the UI operation level.
- (void)bookmarkItemsWillBeRemoved:(NSArray*)bookmarks;

// returns NSNotFound if the folder is not a child of the root
- (unsigned)indexOfContainer:(BookmarkFolder*)inFolder;
- (BookmarkFolder*)containerAtIndex:(unsigned)inIndex;
- (BookmarkFolder*)rootBookmarkFolderWithIdentifier:(NSString*)inIdentifier;

- (BOOL)itemsShareCommonParent:(NSArray*)inItems;

// these may be nested, and are threadsafe
- (void)startSuppressingChangeNotifications;
- (void)stopSuppressingChangeNotifications;

- (BOOL)areChangeNotificationsSuppressed;

// get/set folder last used by "Add Bookmarks"
- (BookmarkFolder*)lastUsedBookmarkFolder;
- (void)setLastUsedBookmarkFolder:(BookmarkFolder*)inFolder;

- (BookmarkItem*)itemWithUUID:(NSString*)uuid;
- (NSUndoManager *)undoManager;

// clear visit count on all bookmarks
- (void)clearAllVisits;

// Informational things
- (NSArray *)resolveBookmarksShortcut:(NSString *)shortcut;
- (NSArray *)searchBookmarksContainer:(BookmarkFolder*)container forString:(NSString *)searchString inFieldWithTag:(int)tag;
- (BOOL)isDropValid:(NSArray *)items toFolder:(BookmarkFolder *)parent;
- (NSMenu *)contextMenuForItems:(NSArray*)items fromView:(BookmarkOutlineView *)outlineView target:(id)target;

// Utilities
- (void)copyBookmarksURLs:(NSArray*)bookmarkItems toPasteboard:(NSPasteboard*)aPasteboard;

// Importing bookmarks
- (void)startImportBookmarks;
- (void)importBookmarksThreadEntry:(NSDictionary *)aDict;

// Writing bookmark files
- (void)writeHTMLFile:(NSString *)pathToFile;
- (void)writePropertyListFile:(NSString *)pathToFile;
- (void)writeSafariFile:(NSString *)pathToFile;

@end
