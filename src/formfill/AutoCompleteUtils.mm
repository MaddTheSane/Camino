/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "AutoCompleteUtils.h"

@implementation AutoCompleteResults

- (void)dealloc
{
  [mSearchString release];
  [mMatches release];

  [super dealloc];
}

- (NSString*)searchString
{
  return mSearchString;
}

- (void)setSearchString:(NSString*)string
{
  [mSearchString release];

  // The caller might change the string, so keep a copy.
  mSearchString = [string copy];
}

- (NSArray*)matches
{
  return mMatches;
}

- (void)setMatches:(NSArray*)matches
{
  if (mMatches != matches) {
    [mMatches release];
    mMatches = [matches retain];
  }
}

- (int)defaultIndex
{
  return mDefaultIndex;
}

- (void)setDefaultIndex:(int)index
{
  mDefaultIndex = index;
}

@end
