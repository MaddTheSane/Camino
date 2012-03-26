/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "KeychainDenyList.h"
#import "PreferenceManager.h"

// Xcode 2.x's ld dead-strips this symbol.  Xcode 3.0's ld is fine.
asm(".no_dead_strip .objc_class_name_KeychainDenyList");


@interface KeychainDenyList (KeychainDenyListPrivate)
- (void)writeToDisk;
- (NSString*)pathToDenyListFile;
- (NSString*)pathToLegacyDenyListFile;
@end


@implementation KeychainDenyList

static KeychainDenyList *sDenyListInstance = nil;

+ (KeychainDenyList*)instance
{
  return sDenyListInstance ? sDenyListInstance : sDenyListInstance = [[self alloc] init];
}

- (id)init
{
  if ((self = [super init])) {
    mDenyList = [[NSMutableArray alloc] initWithContentsOfFile:[self pathToDenyListFile]];
    // If there's no new deny list file, try the old one
    if (!mDenyList)
      mDenyList = [[NSUnarchiver unarchiveObjectWithFile:[self pathToLegacyDenyListFile]] retain];
    if (!mDenyList)
      mDenyList = [[NSMutableArray alloc] init];
  }
  return self;
}

- (void)dealloc
{
  [mDenyList release];
  [super dealloc];
}

//
// writeToDisk
//
// flushes the deny list to the save file in the user's profile.
//
- (void)writeToDisk
{
  [mDenyList writeToFile:[self pathToDenyListFile] atomically:YES];
}

- (BOOL)isHostPresent:(NSString*)host
{
  return [mDenyList containsObject:host];
}

- (void)addHost:(NSString*)host
{
  if (![self isHostPresent:host]) {
    [mDenyList addObject:host];
    [self writeToDisk];
  }
}

- (void)removeHost:(NSString*)host
{
  if ([self isHostPresent:host]) {
    [mDenyList removeObject:host];
    [self writeToDisk];
  }
}

- (void)removeAllHosts
{
  [mDenyList removeAllObjects];
  [self writeToDisk];
}

- (NSArray*)listHosts
{
  return mDenyList;
}

- (NSString*)pathToDenyListFile
{
  NSString* profilePath = [[PreferenceManager sharedInstance] profilePath];
  return [profilePath stringByAppendingPathComponent:@"KeychainDenyList.plist"];
}

- (NSString*)pathToLegacyDenyListFile
{
  NSString* profilePath = [[PreferenceManager sharedInstance] profilePath];
  return [profilePath stringByAppendingPathComponent:@"Keychain Deny List"];
}

@end
