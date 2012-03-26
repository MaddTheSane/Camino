/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
* License, v. 2.0. If a copy of the MPL was not distributed with this
* file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>

class nsICookieManager;

// Provides access to and management of stored cookies. Wraps the Gecko
// nsICookieManager.
@interface CHCookieStorage : NSObject {
 @private
  nsICookieManager* mManager; // strong
}

// Returns the shared CHCookieStorage instance.
+ (CHCookieStorage*)cookieStorage;

// Returns all cookies.
- (NSArray*)cookies;

// Deletes a specific cookie.
- (void)deleteCookie:(NSHTTPCookie*)cookie;

// Deletes all stored cookies.
- (void)deleteAllCookies;

@end
