/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <AppKit/AppKit.h>

// 
// SiteIconCache
// 
// The class manages an on-disk cache of site icons.
// The cache consists of a serialized plist file, and
// archived images (which are really just saved TIFF
// representations).
// 
// Icons expire after the given time interval, to avoid
// us caching a stale site icon for ever.


@interface SiteIconCache : NSObject
{
  NSMutableDictionary*        mURLToEntryMap;   // saved to disk. entry is a dict
                                                // containing a uuid and expiration date.

  NSMutableDictionary*        mURLToImageMap;   // memory cache of images
  NSString*                   mCacheDirectory;
  BOOL                        mSuppressSaveNotification;
}

+ (SiteIconCache*)sharedSiteIconCache;

- (NSImage*)siteIconForURL:(NSString*)inURL;
- (void)setSiteIcon:(NSImage*)inImage forURL:(NSString*)inURL withExpiration:(NSDate*)inExpirationDate memoryOnly:(BOOL)inMemoryOnly;

// Purge our cached image of the favicon located at inURL
- (void)removeImageForURL:(NSString*)inURL;

@end
