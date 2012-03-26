/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/*
 * Lets us have address book code and still run on 10.1.  When/if 10.1
 * support goes away, merge this into SmartBookmarkManger class.
 */
#import <Foundation/Foundation.h>



@interface AddressBookManager : NSObject
{
  //
  // leave this an id for 10.1 support.  when you go to 10.2
  // this whole class should disappear, and the methods should just
  // get merged into KindaSmartFolderManager.
  id mAddressBookFolder;
}

- (id)initWithFolder:(id)folder;
- (void)fillAddressBook:(NSNotification *)note;

@end
