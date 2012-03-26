/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>

#import "RemoteDataProvider.h"

extern NSString* const kSiteIconLoadNotification;
extern NSString* const kSiteIconLoadImageKey;
extern NSString* const kSiteIconLoadURIKey;
extern NSString* const kSiteIconLoadUsedNetworkKey;
extern NSString* const kSiteIconLoadUserDataKey;

class NeckoCacheHelper;

@interface SiteIconProvider : NSObject<RemoteLoadListener>
{
  NeckoCacheHelper*       mIconsCacheHelper;
  // Dict of favicon url -> request url.
  NSMutableDictionary*    mRequestDict;
  // Set of URIs for which we've explicitly registered images to be icons.
  NSMutableSet*           mURIsWithRegisteredIcons;
}

+ (SiteIconProvider*)sharedFavoriteIconProvider;

// get the default location (http://www.foo.bar/favicon.ico) for the given URI
+ (NSString*)defaultFaviconLocationStringFromURI:(NSString*)inURI;

// fetch the icon for the given page.
// inIconURI is the URI of the icon (if specified via a <link> element), or nil for the default
// site icon location.
// when the load is done, a kSiteIconLoadNotification notification will be sent with
// |inClient| as the object.
// returns YES if the load is initiated, and the client can expect a notification.
// 
// there are various reasons why this might fail to load a site icon from the cache,
// when we know we can load it if we hit the network:
// i) it's a https URL, which is never put in the disk cache.
// ii) the url might have moved (301 response), and we don't handle that.
- (BOOL)fetchFavoriteIconForPage:(NSString*)inPageURI
                withIconLocation:(NSString*)inIconURI
                    allowNetwork:(BOOL)inAllowNetwork
                 notifyingClient:(id)inClient;

// image cache method

// get the image for the given page URI. if not available, returns nil.
// if the image was fetched with a specific location (e.g. because of a <link> element)
// then this will take that into account.
- (NSImage*)favoriteIconForPage:(NSString*)inPageURI;

// to register a specific image for a given uri, can all this method. This will
// add an entry to the cache. It's used for "special" uris like "about:bookmarks".
- (void)registerFaviconImage:(NSImage*)inImage forPageURI:(NSString*)inURI;

// get the favicon url from the page url. if we've seen the page before, this
// will attempt to look for any cached <link> image urls.
- (NSString*)favoriteIconURLFromPageURL:(NSString*)inPageURL;

// removes the favicon image associated with the page URL from cache.
- (void)removeImageForPageURL:(NSString*)inURI;

@end
