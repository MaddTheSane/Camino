/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "AutoCompleteResult.h"


@implementation AutoCompleteResult

- (id)init
{
  if ((self = [super init])) {
    mSiteURL = @"";
    mSiteTitle = @"";
  }
  return self;
}

- (void)dealloc
{
  [mSiteIcon release];
  [mSiteURL release];
  [mSiteTitle release];
  [super dealloc];
}

- (id)copyWithZone:(NSZone *)zone
{
  AutoCompleteResult *copy = [[[self class] allocWithZone:zone] init];
  [copy setIcon:mSiteIcon];
  [copy setTitle:mSiteTitle];
  [copy setUrl:mSiteURL];
  [copy setIsHeader:mIsHeader];
  return copy;
}

- (BOOL)isEqual:(id)anObject
{
  return [[anObject url] isEqualToString:mSiteURL];
}

- (void)setIcon:(NSImage *)anImage
{
  [mSiteIcon autorelease];
  mSiteIcon = [anImage retain];
}

- (NSImage *)icon
{
  return mSiteIcon;
}

- (void)setUrl:(NSString *)aURL
{
  [mSiteURL autorelease];
  mSiteURL = [aURL copy];
}

- (NSString *)url
{
  return mSiteURL;
}

- (void)setTitle:(NSString *)aString
{
  [mSiteTitle autorelease];
  mSiteTitle = [aString copy];
}

- (NSString *)title
{
  return mSiteTitle;
}

- (void)setIsHeader:(BOOL)aBOOL
{
  mIsHeader = aBOOL;
}

- (BOOL)isHeader
{
  return mIsHeader;
}

@end
