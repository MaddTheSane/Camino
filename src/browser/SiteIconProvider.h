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
 * The Original Code is Chimera code.
 *
 * The Initial Developer of the Original Code is
 * Netscape Communications Corporation.
 * Portions created by the Initial Developer are Copyright (C) 2002
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *   Simon Fraser <sfraser@netscape.com>
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

#import <Cocoa/Cocoa.h>

#import "RemoteDataProvider.h"

extern NSString* const SiteIconLoadNotificationName;
extern NSString* const SiteIconLoadImageKey;
extern NSString* const SiteIconLoadURIKey;
extern NSString* const SiteIconLoadUserDataKey;

class NeckoCacheHelper;

@interface SiteIconProvider : NSObject<RemoteLoadListener>
{
  NeckoCacheHelper*       mIconsCacheHelper;
  NSMutableDictionary*    mRequestDict;   // dict of favicon url -> request url
  
  NSMutableDictionary*    mIconDictionary;    // map of favorite url -> NSImage
}

+ (SiteIconProvider*)sharedFavoriteIconProvider;

+ (NSString*)faviconLocationStringFromURI:(NSString*)inURI;

// Start a favicon.ico load for the given URI, which can be any URI.
// The caller will get a 'SiteIconLoadNotificationName' notification
// when the load is done, with the image at the 'SiteIconLoadImageKey' key
// in the notifcation userInfo. The caller will have had to register with the
// NSNotifcationCenter in order to receive this notifcation. The notification
// is dispatched with 'sender' as the object.
// This method returns YES if the uri request was dispatched (i.e. if we know
// that we've looked for, and failed to find, this icon before). If it returns
// YES, then the 'SiteIconLoadNotificationName' notification will be sent out.

- (BOOL)loadFavoriteIcon:(id)sender forURI:(NSString *)inURI allowNetwork:(BOOL)inAllowNetwork;

// fetch the icon for the given page.
// inIconURI is the URI of the icon (if specified via a <link> element), or nil for the default
// site icon location.
// when the load is done, a SiteIconLoadNotificationName notification will be sent with
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

@end
