/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#ifndef __KeychainDenyList_h__
#define __KeychainDenyList_h__

#import <Cocoa/Cocoa.h>

//
// KeychainDenyList
//
// A singleton object that maintains a list of sites where we should
// not prompt the user for saving in the keychain. This object also
// handles archiving the list in the user's profile dir.
//

@interface KeychainDenyList : NSObject
{
  NSMutableArray* mDenyList;
}

+ (KeychainDenyList*)instance;

- (BOOL)isHostPresent:(NSString*)host;
- (void)addHost:(NSString*)host;
- (void)removeHost:(NSString*)host;
- (void)removeAllHosts;
- (NSArray*)listHosts;

@end

#endif  // __KeychainDenyList_h__
