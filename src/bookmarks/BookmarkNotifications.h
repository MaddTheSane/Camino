/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
#import <Foundation/Foundation.h>

// Notification keys
// Defined in Bookmark.mm
extern NSString* const kURLLoadNotification;                      // object is NSString of URL, userinfo has NSNum of success/fail
extern NSString* const kURLLoadSuccessKey;                        // key for bool of load success/fail

// Defined in BookmarkFolder.mm
extern NSString* const kBookmarkFolderAdditionNotification;       // self is obj, userinfo has added item/index
extern NSString* const kBookmarkFolderDeletionNotification;       // self is obj, userinfo dict has removed item
extern NSString* const kBookmarkFolderChildKey;                   // key for added/removed object in userinfo dict
extern NSString* const kBookmarkFolderChildIndexKey;              // key for added object index in userinfo dict
extern NSString* const kBookmarkFolderDockMenuChangeNotification; // self is NEW dock menu OR nil

// Defined in BookmarkItem.mm
extern NSString* const kBookmarkItemChangedNotification;          // self is object, userInfo contains change flags
extern NSString* const kBookmarkItemChangedFlagsKey;

// Defined in BookmarkManager.mm
extern NSString* const kBookmarkItemsAddedNotification;           // object is array of added bookmarks
extern NSString* const kBookmarkItemsRemovedNotification;         // object is array of removed bookmarks
