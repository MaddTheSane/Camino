/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "BookmarkItem.h"

@interface Bookmark : BookmarkItem
{
  NSString*     mURL;
  NSDate*       mLastVisit;
  BOOL          mIsSeparator;
  unsigned int  mVisitCount;
  NSString*     mFaviconURL;  // only used for <link> favicons
}

+ (Bookmark*)separator;
+ (Bookmark*)bookmarkWithTitle:(NSString*)aTitle
                           url:(NSString*)aURL
                     lastVisit:(NSDate*)aLastVisit;
+ (Bookmark*)bookmarkWithNativeDictionary:(NSDictionary*)aDict;

- (NSString *)url;
- (NSDate *)lastVisit;  // nil if not visited
- (unsigned int)visitCount;

// Alternate accessors for persisting to disk; never returns nil.
- (NSString*)savedURL;

- (NSString*)faviconURL;
- (void)setFaviconURL:(NSString*)inURL;

- (void)setUrl:(NSString *)aURL;
- (void)setLastVisit:(NSDate *)aLastVisit;
- (void)setVisitCount:(unsigned)count;
// Clears the last visit date and sets the visit count to 0.
- (void)clearVisitHistory;

- (void)notePageLoadedWithSuccess:(BOOL)inSuccess;

@end


@interface RendezvousBookmark : Bookmark
{
  int       mServiceID;
  BOOL      mResolved;
}

- (id)initWithServiceID:(int)inServiceID;
- (void)setServiceID:(int)inServiceID;
- (int)serviceID;

- (BOOL)resolved;
- (void)setResolved:(BOOL)inResolved;

@end

