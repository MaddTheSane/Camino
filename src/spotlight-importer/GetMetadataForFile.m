/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#include <Foundation/Foundation.h>

#include "SpotlightFileKeys.h"

#if MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_4
static const CFStringRef kMDItemURL = @"kMDItemURL";
#endif

Boolean GetMetadataForFile(void* thisInterface,
                           CFMutableDictionaryRef attributes,
                           CFStringRef contentTypeUTI,
                           CFStringRef pathToFile)
{
  NSMutableDictionary* outDict = (NSMutableDictionary*)attributes;
  NSDictionary* fileInfo =
      [NSDictionary dictionaryWithContentsOfFile:(NSString*)pathToFile];
  if (!fileInfo)
    return FALSE;

  if (!([fileInfo objectForKey:kSpotlightBookmarkTitleKey] &&
        [fileInfo objectForKey:kSpotlightBookmarkURLKey])) {
    return FALSE;
  }

  [outDict setObject:[fileInfo objectForKey:kSpotlightBookmarkTitleKey]
              forKey:(NSString*)kMDItemDisplayName];
  [outDict setObject:[fileInfo objectForKey:kSpotlightBookmarkTitleKey]
              forKey:(NSString*)kMDItemTitle];

  [outDict setObject:[fileInfo objectForKey:kSpotlightBookmarkURLKey]
              forKey:(NSString*)kMDItemURL];

  if ([fileInfo objectForKey:kSpotlightBookmarkDescriptionKey]) {
    [outDict setObject:[fileInfo objectForKey:kSpotlightBookmarkDescriptionKey]
                forKey:(NSString*)kMDItemDescription];
  }

  if ([fileInfo objectForKey:kSpotlightBookmarkShortcutKey]) {
    NSArray* keywords = [NSArray arrayWithObject:
        [fileInfo objectForKey:kSpotlightBookmarkShortcutKey]];
    [outDict setObject:keywords forKey:(NSString*)kMDItemKeywords];
  }

  return TRUE;
}
