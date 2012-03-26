/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
* License, v. 2.0. If a copy of the MPL was not distributed with this
* file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "CHStringBundleOverride.h"
#import "NSString+Gecko.h"
#import "NSString+Utils.h"
#import <Foundation/Foundation.h>

NS_IMPL_ISUPPORTS1(CHStringBundleOverride, nsIStringBundleOverride);

CHStringBundleOverride::CHStringBundleOverride()
{
}

CHStringBundleOverride::~CHStringBundleOverride()
{
}

NS_IMETHODIMP CHStringBundleOverride::GetStringFromName(const nsACString& url, const nsACString& key, nsAString& aRetVal)
{
  /**
   * When gecko requests a localized string from a bundle (i.e. a jar file) it requests it 
   * through the |nsIStringBundle| service. Every time a caller asks the service for a string
   * it checks to see if a override service has been registered (i.e. this class) and asks
   * to see if it wants to replace the chrome string. 
   *
   * If we define a string in Localizable.strings, then we will tell the |nsIStringBundle| 
   * service to replace the string. If not, then the |nsIStringBundle| will use the string
   * defined in the bundled chrome resource.
   */
  @try {
    // Create an autorelease pool, since this may be called on a background thread.
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

    NSString* keyStr = [NSString stringWith_nsACString:key];
    NSString* tableName = [NSString stringWith_nsACString:url];
    // Stip off the chrome:// prefix (9 characters) if it's there
    if ([tableName hasPrefix:@"chrome://"])
      tableName = [tableName substringFromIndex:9];
    NSCharacterSet* replacementSet = [NSCharacterSet characterSetWithCharactersInString:@"/."];
    tableName = [tableName stringByReplacingCharactersInSet:replacementSet
                                                 withString:@"_"];
    NSString* overrideStr = NSLocalizedStringFromTable(keyStr, tableName, nil);  
    if (!overrideStr || [overrideStr isEqualToString:keyStr]) {
      [pool release];
      return NS_ERROR_FAILURE;
    }
      
    [overrideStr assignTo_nsAString:aRetVal];

    [pool release];
  }
  @catch (id exception) {
    // Note that we may leak the autorelease pool if this happens on a
    // background thread, but there's not really a safe way to handle that
    // case; see the discussion at:
    // http://lists.apple.com/archives/objc-language//2007/Aug/msg00023.html
    NSLog(@"Exception caught in CHStringBundleOverride::GetStringFromName %@", exception);
    return NS_ERROR_FAILURE;
  }
  return NS_OK;
}

NS_IMETHODIMP CHStringBundleOverride::EnumerateKeysInBundle(const nsACString & url, nsISimpleEnumerator **_retval)
{
  return NS_ERROR_NOT_IMPLEMENTED;
}
