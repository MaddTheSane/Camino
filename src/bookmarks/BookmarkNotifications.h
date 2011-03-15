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
 * The Original Code is mozilla.org code.
 *
 * The Initial Developer of the Original Code is
 * Netscape Communications Corporation.
 * Portions created by the Initial Developer are Copyright (C) 2002
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *   David Haas <haasd@cae.wisc.edu>
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
