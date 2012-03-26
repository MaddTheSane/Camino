/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

// superclass for Bookmark & BookmarkFolder.
// Basically here to aid in scripting support.

#import <AppKit/AppKit.h>

enum
{
  kBookmarkItemAccumulateChangesMask    = (1 << 0),

  kBookmarkItemTitleChangedMask         = (1 << 1),
  kBookmarkItemDescriptionChangedMask   = (1 << 2),
  kBookmarkItemShortcutChangedMask      = (1 << 3),
  kBookmarkItemIconChangedMask          = (1 << 4),
  kBookmarkItemURLChangedMask           = (1 << 5),
  kBookmarkItemLastVisitChangedMask     = (1 << 6),
  kBookmarkItemStatusChangedMask        = (1 << 7),   // really "flags", like separator vs. bookmark
  kBookmarkItemVisitCountChangedMask    = (1 << 8),

  // flags for bookmark folder changes
  kBookmarkItemChildrenChangedMask      = (1 << 9),

  // mask of flags that require updating the spotlight metadata file
  kBookmarkItemSpotlightMetadataChangeFlagsMask = kBookmarkItemTitleChangedMask |
                                                  kBookmarkItemDescriptionChangedMask |
                                                  kBookmarkItemShortcutChangedMask |
                                                  kBookmarkItemURLChangedMask,

  // mask of flags that require a save of the bookmarks
  kBookmarkItemSignificantChangeFlagsMask = kBookmarkItemTitleChangedMask |
                                            kBookmarkItemDescriptionChangedMask |
                                            kBookmarkItemShortcutChangedMask |
                                            kBookmarkItemURLChangedMask |
                                            kBookmarkItemLastVisitChangedMask |
                                            kBookmarkItemStatusChangedMask |
                                            kBookmarkItemVisitCountChangedMask,

  kBookmarkItemEverythingChangedMask    = 0xFFFFFFFE
};

// A formatter for shortcut entry fields that prevents whitespace in shortcuts,
// since shortcuts with whitespace don't work.
@interface BookmarkShortcutFormatter : NSFormatter
{
}
@end

@interface BookmarkItem : NSObject <NSCopying>
{
  id              mParent;  //subclasses will use a BookmarkFolder
  NSString*       mTitle;
  NSString*       mDescription;
  NSString*       mShortcut;
  NSString*       mUUID;
  NSImage*        mIcon;
  unsigned int    mPendingChangeFlags;
}

// returns YES if any of the supplied flags are set in the userInfo
+ (BOOL)bookmarkChangedNotificationUserInfo:(NSDictionary*)inUserInfo containsFlags:(unsigned int)inFlags;

// Setters/Getters
- (id)parent;
- (NSString *)title;
- (NSString *)itemDescription;    // don't use "description"
- (NSString *)shortcut;
- (NSImage *)icon;
- (NSString *)UUID;

- (void)setParent:(id)aParent;    // note that the parent of root items is the BookmarksManager, for some reason
- (void)setTitle:(NSString *)aString;
- (void)setItemDescription:(NSString *)aString;
- (void)setShortcut:(NSString *)aShortcut;
- (void)setIcon:(NSImage *)aIcon;
- (void)setUUID:(NSString*)aUUID;

// Status checks
- (BOOL)isChildOfItem:(BookmarkItem *)anItem;
- (BOOL)hasAncestor:(BookmarkItem*)inItem;
- (BOOL)isSeparator;

// Searching

// search field tags, used in search field context menu item tags
enum
{
  eBookmarksSearchFieldAll = 1,
  eBookmarksSearchFieldTitle,
  eBookmarksSearchFieldURL,
  eBookmarksSearchFieldShortcut,
  eBookmarksSearchFieldDescription
};

- (BOOL)matchesString:(NSString*)searchString inFieldWithTag:(int)tag;

// Notification of Change
- (void)setAccumulateUpdateNotifications:(BOOL)suppressUpdates; // does not nest
- (void)itemUpdatedNote:(unsigned int)inChangeMask; // not everything triggers an item update, only certain properties changing

// Methods called on startup for both bookmark & folder
- (void)refreshIcon;

- (void)writeBookmarksMetadataToPath:(NSString*)inPath;
- (void)removeBookmarksMetadataFromPath:(NSString*)inPath;
- (NSDictionary *)writeNativeDictionary;

// methods used for saving to files; are guaranteed never to return nil
- (id)savedTitle;

// sorting

// we put sort comparators on the base class for convenience
- (NSComparisonResult)compareURL:(BookmarkItem *)aItem sortDescending:(NSNumber*)inDescending;
- (NSComparisonResult)compareTitle:(BookmarkItem *)aItem sortDescending:(NSNumber*)inDescending;
- (NSComparisonResult)compareShortcut:(BookmarkItem *)aItem sortDescending:(NSNumber*)inDescending;
- (NSComparisonResult)compareDescription:(BookmarkItem *)aItem sortDescending:(NSNumber*)inDescending;
- (NSComparisonResult)compareType:(BookmarkItem *)aItem sortDescending:(NSNumber*)inDescending;
- (NSComparisonResult)compareVisitCount:(BookmarkItem *)aItem sortDescending:(NSNumber*)inDescending;
- (NSComparisonResult)compareLastVisitDate:(BookmarkItem *)aItem sortDescending:(NSNumber*)inDescending;

@end

// Bunch of Keys for reading/writing dictionaries.

// Camino plist keys
extern NSString* const kBMTitleKey;
extern NSString* const kBMChildrenKey;
extern NSString* const kBMFolderDescKey;
extern NSString* const kBMFolderTypeKey;
extern NSString* const kBMFolderShortcutKey;
extern NSString* const kBMDescKey;
extern NSString* const kBMStatusKey;
extern NSString* const kBMURLKey;
extern NSString* const kBMUUIDKey;
extern NSString* const kBMShortcutKey;
extern NSString* const kBMLastVisitKey;
extern NSString* const kBMVisitCountKey;
extern NSString* const kBMLinkedFaviconURLKey;
