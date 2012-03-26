/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*-
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>

//
// interface FlashblockWhitelistManager
//
// A singleton class to manage list of sites where Flash is allowed
// when otherwise Flash is blocked
//
@interface FlashblockWhitelistManager : NSObject
{
  NSString*                 mFlashblockWhitelistPref;      // STRONG
  NSMutableArray*           mFlashblockWhitelistSites;     // STRONG
  NSCharacterSet*           mFlashblockSiteCharSet;        // STRONG
}

// Returns the shared FlashblockWhitelistManager instance.
+ (FlashblockWhitelistManager*)sharedInstance;

// Loads whitelisted sites from the preference.
- (void)loadWhitelistSites;

// Sets the Flashblock whitelist Gecko preference to the current whitelist array.
- (void)saveFlashblockWhitelist;

// Adds the site to the Flashblock whitelist, if valid and not already present.
// aSite should be just the host (site.tld, sub.site.tld, or *.site.tld).
// Returns YES if the site was added.
- (BOOL)addFlashblockWhitelistSite:(NSString*)aSite;

// Removes the site from the whitelist, if present, and saves the modified list.
// aSite should be just the host (site.tld, sub.site.tld, or *.site.tld).
- (void)removeFlashblockWhitelistSite:(NSString*)aSite;

// Returns YES if the site or any of its subdomains is in the whitelist.
// aSite should be just the host (site.tld or sub.site.tld).
- (BOOL)isFlashAllowedForSite:(NSString*)aSite;

// Returns YES if the string contains a valid site and is not already in the
// whitelist.
// aSite should be just the host (site.tld, sub.site.tld, or *.site.tld).
- (BOOL)canAddToWhitelist:(NSString*)aSite;

// Returns YES if string contains a valid site.
// aSite should be just the host (site.tld, sub.site.tld, or *.site.tld).
- (BOOL)isValidFlashblockSite:(NSString*)aSite;

// The current array of whitelist sites.
- (NSArray*)whitelistArray;

@end
