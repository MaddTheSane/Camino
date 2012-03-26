/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/*
 * By the way - this is a total hack.  Somebody should really do this in
 * a more intelligent manner.
 */
#import <Foundation/Foundation.h>

@class BookmarkFolder;
@class BookmarkManager;
@class AddressBookManager;

// KindaSmart? How smart? What does it do?
@interface KindaSmartFolderManager : NSObject
{
  BookmarkFolder*       mUpdatedBookmarkFolder;
  BookmarkFolder*       mTop10Folder;
  BookmarkFolder*       mAddressBookFolder;
  BookmarkFolder*       mRendezvousFolder;
  AddressBookManager*   mAddressBookManager;
  NSArray*              mTop10SortDescriptors;
}

- (id)initWithBookmarkManager:(BookmarkManager *)manager;
- (void)postStartupInitialization:(BookmarkManager *)manager;

@end
