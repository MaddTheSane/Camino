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
 *   Josh Aas <josh@mozilla.com>
 *   Stuart Morgan <stuart.morgan@alumni.case.edu>
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
#import <SystemConfiguration/SystemConfiguration.h>

#import "NSThread+Utils.h"
#import "Bookmark.h"
#import "BookmarkFolder.h"
#import "BookmarkManager.h"
#import "BookmarksClient.h"
#import "NSString+Utils.h"
#import "SiteIconProvider.h"

// Notification of URL load
NSString* const URLLoadNotification   = @"url_load";
NSString* const URLLoadSuccessKey     = @"url_bool";

//Status Flags
#define kBookmarkOKStatus 0
#define kBookmarkSpacerStatus 9

#pragma mark -

@interface Bookmark (Private)

- (void)setIsSeparator:(BOOL)isSeparator;
- (void)clearLastVisit;

// methods used for saving to files; are guaranteed never to return nil
- (id)savedStatus;
- (id)savedNumberOfVisits;
- (id)savedFaviconURL;

@end

#pragma mark -

@implementation Bookmark

+ (Bookmark*)separator
{
  Bookmark* separator = [[[self alloc] init] autorelease];
  [separator setIsSeparator:YES];
  return separator;
}

+ (Bookmark*)bookmarkWithTitle:(NSString*)aTitle
                           url:(NSString*)aURL
                     lastVisit:(NSDate*)aLastVisit
{
  Bookmark* bookmark = [[[self alloc] init] autorelease];
  [bookmark setTitle:aTitle];
  [bookmark setUrl:aURL];
  if (aLastVisit) {
    [bookmark setLastVisit:aLastVisit];
    [bookmark setNumberOfVisits:1];
  }
  return bookmark;
}

+ (Bookmark*)bookmarkWithNativeDictionary:(NSDictionary*)aDict
{
  // There used to be more than two possible status states, but now state just
  // indicates whether or not it's a separator.
  if ([[aDict objectForKey:BMStatusKey] unsignedIntValue] == kBookmarkSpacerStatus)
    return [self separator];

  Bookmark* bookmark = [self bookmarkWithTitle:[aDict objectForKey:BMTitleKey]
                                           url:[aDict objectForKey:BMURLKey]
                                     lastVisit:[aDict objectForKey:BMLastVisitKey]];
  [bookmark setItemDescription:[aDict objectForKey:BMDescKey]];
  [bookmark setShortcut:[aDict objectForKey:BMShortcutKey]];
  [bookmark setUUID:[aDict objectForKey:BMUUIDKey]];
  [bookmark setNumberOfVisits:[[aDict objectForKey:BMNumberVisitsKey] unsignedIntValue]];
  [bookmark setFaviconURL:[aDict objectForKey:BMLinkedFaviconURLKey]];

  return bookmark;
}

- (id)copyWithZone:(NSZone *)zone
{
  id bookmarkCopy = [super copyWithZone:zone];
  [bookmarkCopy setUrl:[self url]];
  [bookmarkCopy setIsSeparator:[self isSeparator]];
  [bookmarkCopy setLastVisit:[self lastVisit]];
  [bookmarkCopy setNumberOfVisits:[self numberOfVisits]];
  return bookmarkCopy;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [mURL release];
  [mLastVisit release];
  [super dealloc];
}

- (NSString*)description
{
  return [NSString stringWithFormat:@"Bookmark %08p, url %@, title %@", self, [self url], [self title]];
}

// set/get properties

- (NSString *)url
{
  return mURL ? mURL : @"";
}

- (NSImage *)icon
{
  if (!mIcon) {
    mIcon = [[NSImage imageNamed:@"smallbookmark"] retain];
    [self refreshIcon];
  }
  return mIcon;
}

- (NSDate *)lastVisit
{
  return mLastVisit;
}

- (unsigned)numberOfVisits
{
  return mNumberOfVisits;
}

- (BOOL)isSeparator
{
  return mIsSeparator;
}

- (NSString*)faviconURL
{
  return mFaviconURL;
}

- (void)setFaviconURL:(NSString*)inURL
{
  [inURL retain];
  [mFaviconURL release];
  mFaviconURL = inURL;
}

- (void)setUrl:(NSString *)aURL
{
  if (!aURL)
    return;

  if (![mURL isEqualToString:aURL]) {
    [mURL release];
    mURL = aURL;
    [mURL retain];

    // clear the icon, so we'll refresh it next time someone asks for it
    [mIcon release];
    mIcon = nil;

    [self itemUpdatedNote:kBookmarkItemURLChangedMask];
  }
}

- (void)setLastVisit:(NSDate *)aDate
{
  if (aDate && ![mLastVisit isEqual:aDate]) {
    [mLastVisit release];
    mLastVisit = aDate;
    [mLastVisit retain];

    [self itemUpdatedNote:kBookmarkItemLastVisitChangedMask];
  }
}

- (void)clearLastVisit
{
  if (mLastVisit) {
    [mLastVisit release];
    mLastVisit = nil;

    [self itemUpdatedNote:kBookmarkItemLastVisitChangedMask];
  }
}

- (void)setNumberOfVisits:(unsigned)aNumber
{
  if (mNumberOfVisits != aNumber) {
    mNumberOfVisits = aNumber;

    [self itemUpdatedNote:kBookmarkItemNumVisitsChangedMask];

    if (mNumberOfVisits == 0) {
      [self clearLastVisit];
    }
  }
}

- (void)setIsSeparator:(BOOL)isSeparator
{
  if (mIsSeparator != isSeparator) {
    mIsSeparator = isSeparator;
    if (isSeparator)
      [self setTitle:NSLocalizedString(@"<Menu Spacer>", nil)];
    [self itemUpdatedNote:kBookmarkItemStatusChangedMask];
  }
}

- (void)refreshIcon
{
  // don't invoke loads from the non-main thread (e.g. while loading bookmarks on a thread)
  if ([NSThread inMainThread]) {
    NSImage* siteIcon = [[SiteIconProvider sharedFavoriteIconProvider] favoriteIconForPage:[self url]];
    if (siteIcon)
      [self setIcon:siteIcon];
    else if ([[BookmarkManager sharedBookmarkManager] showSiteIcons]) {
      [[SiteIconProvider sharedFavoriteIconProvider] fetchFavoriteIconForPage:[self url]
                                                             withIconLocation:nil
                                                                 allowNetwork:NO
                                                              notifyingClient:self];
    }
  }
}

- (void)notePageLoadedWithSuccess:(BOOL)inSuccess
{
  [self setLastVisit:[NSDate date]];
  if (inSuccess)
    [self setNumberOfVisits:(mNumberOfVisits + 1)];
}

// rather than overriding this, it might be better to have a stub for
// -url in the base class
- (BOOL)matchesString:(NSString*)searchString inFieldWithTag:(int)tag
{
  switch (tag) {
    case eBookmarksSearchFieldAll:
      return (([[self url] rangeOfString:searchString options:NSCaseInsensitiveSearch].location != NSNotFound) ||
              [super matchesString:searchString inFieldWithTag:tag]);

    case eBookmarksSearchFieldURL:
      return ([[self url] rangeOfString:searchString options:NSCaseInsensitiveSearch].location != NSNotFound);
  }

  return [super matchesString:searchString inFieldWithTag:tag];
}

#pragma mark -

- (NSString*)savedURL
{
  return mURL ? mURL : @"";
}

- (id)savedStatus
{
  // There used to be more than two possible status states. Now we regard
  // everything except kBookmarkSpacerStatus as kBookmarkOKStatus.
  return [NSNumber numberWithUnsignedInt:(mIsSeparator ? kBookmarkSpacerStatus
                                                       : kBookmarkOKStatus)];
}

- (id)savedNumberOfVisits
{
  return [NSNumber numberWithUnsignedInt:mNumberOfVisits];
}

- (id)savedFaviconURL
{
  return mFaviconURL ? mFaviconURL : @"";
}

#pragma mark -

//
// for writing to disk
//

//
// -writeBookmarksMetaDatatoPath:
//
// Writes out the meta data for this bookmark to a file with the name of this
// item's UUID in the given path. Using the suffix "webbookmark" allows us to
// piggyback on Safari's bookmark Spotlight importer.
//
- (void)writeBookmarksMetadataToPath:(NSString*)inPath
{
  NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:
                                      [self savedTitle], @"Name",
                                        [self savedURL], @"URL",
                                                         nil];
  NSString* file = [self UUID];
  NSString* path = [NSString stringWithFormat:@"%@/%@.webbookmark", inPath, file];
  [dict writeToFile:path atomically:YES];
}

//
// -removeBookmarksMetadataFromPath:
//
// Delete the meta data for this bookmark from the cache, which consists of a file with
// this item's UUID.
//
- (void)removeBookmarksMetadataFromPath:(NSString*)inPath
{
  NSString* file = [self UUID];
  NSString* path = [NSString stringWithFormat:@"%@/%@.webbookmark", inPath, file];
  [[NSFileManager defaultManager] removeFileAtPath:path handler:nil];
}

// for plist in native format
- (NSDictionary *)writeNativeDictionary
{
  if ([self isSeparator])
    return [NSDictionary dictionaryWithObject:[self savedStatus] forKey:BMStatusKey];

  NSMutableDictionary* itemDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                [self savedTitle], BMTitleKey,
                  [self savedURL], BMURLKey,
                                   nil];

  if (mLastVisit)
    [itemDict setObject:mLastVisit forKey:BMLastVisitKey];

  if (mNumberOfVisits)
    [itemDict setObject:[self savedNumberOfVisits] forKey:BMNumberVisitsKey];

  // The bookmark is guaranteed not to be a separator at this point, so
  // [self savedStatus] will be 0, and there is no reason to write anything
  // for BMStatusKey.

  if ([[self itemDescription] length])
    [itemDict setObject:[self itemDescription] forKey:BMDescKey];

  if ([[self shortcut] length])
    [itemDict setObject:[self shortcut] forKey:BMShortcutKey];

  if ([mUUID length])    // don't call -UUID to avoid generating one
    [itemDict setObject:mUUID forKey:BMUUIDKey];

  if ([[self faviconURL] length])
    [itemDict setObject:[self faviconURL] forKey:BMLinkedFaviconURLKey];

  return itemDict;
}

#pragma mark -

// sorting

- (NSComparisonResult)compareURL:(BookmarkItem *)aItem sortDescending:(NSNumber*)inDescending
{
  NSComparisonResult result;
  // sort folders before sites
  if ([aItem isKindOfClass:[BookmarkFolder class]])
    result = NSOrderedDescending;
  else
    result = [[self url] compare:[(Bookmark*)aItem url] options:NSCaseInsensitiveSearch];

  return [inDescending boolValue] ? (NSComparisonResult)(-1 * (int)result) : result;
}

// base class does the title, shortcut and description compares

- (NSComparisonResult)compareType:(BookmarkItem *)aItem sortDescending:(NSNumber*)inDescending
{
  NSComparisonResult result;
  // sort folders before other stuff, and separators before bookmarks
  if ([aItem isKindOfClass:[BookmarkFolder class]])
    result = NSOrderedDescending;
  else
    result = (NSComparisonResult)((int)[self isSeparator] - (int)[(Bookmark*)aItem isSeparator]);

  return [inDescending boolValue] ? (NSComparisonResult)(-1 * (int)result) : result;
}

- (NSComparisonResult)compareVisitCount:(BookmarkItem *)aItem sortDescending:(NSNumber*)inDescending
{
  NSComparisonResult result;
  // sort folders before other stuff
  if ([aItem isKindOfClass:[BookmarkFolder class]])
    result = NSOrderedDescending;
  else {
    unsigned int otherVisits = [(Bookmark*)aItem numberOfVisits];
    if (mNumberOfVisits == otherVisits)
      result = NSOrderedSame;
    else
      result = (otherVisits > mNumberOfVisits) ? NSOrderedAscending : NSOrderedDescending;
  }

  return [inDescending boolValue] ? (NSComparisonResult)(-1 * (int)result) : result;
}

- (NSComparisonResult)compareLastVisitDate:(BookmarkItem *)aItem sortDescending:(NSNumber*)inDescending
{
  NSComparisonResult result;
  // sort categories before sites
  if ([aItem isKindOfClass:[BookmarkFolder class]]) {
    result = NSOrderedDescending;
  }
  else {
    NSDate* otherLastVisit = [(Bookmark*)aItem lastVisit];
    if (mLastVisit && otherLastVisit)
      result = [mLastVisit compare:otherLastVisit];
    else if (mLastVisit)
      result = NSOrderedDescending;
    else if (otherLastVisit)
      result = NSOrderedAscending;
    else
      result = NSOrderedSame;
  }

  return [inDescending boolValue] ? (NSComparisonResult)(-1 * (int)result) : result;
}

@end

#pragma mark -

@implementation RendezvousBookmark

- (id)initWithServiceID:(int)inServiceID
{
  if ((self = [super init])) {
    mServiceID = inServiceID;
    mResolved = NO;
  }
  return self;
}

- (void)setServiceID:(int)inServiceID
{
  mServiceID = inServiceID;
}

- (int)serviceID
{
  return mServiceID;
}

- (BOOL)resolved
{
  return mResolved;
}

- (void)setResolved:(BOOL)inResolved
{
  mResolved = inResolved;
}

// We don't want to write metadata files for rendezvous bookmarks,
// as they come and go all the time, and we don't correctly clean them up.
- (void)writeBookmarksMetadataToPath:(NSString*)inPath
{
}

- (void)removeBookmarksMetadataFromPath:(NSString*)inPath
{
}

@end

