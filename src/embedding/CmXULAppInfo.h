/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#ifndef CmXULAppInfo_h__
#define CmXULAppInfo_h__

#import <Cocoa/Cocoa.h>

#include "nsIXULAppInfo.h"

class CmXULAppInfo : public nsIXULAppInfo {
 public:
  NS_DECL_ISUPPORTS
  NS_DECL_NSIXULAPPINFO
};

@interface XULAppInfo : NSObject

+ (NSString *)vendor;
+ (NSString *)name;
+ (NSString *)ID;
+ (NSString *)version;
+ (NSString *)appBuildID;
+ (NSString *)platformVersion;
+ (NSString *)platformBuildID;

@end

#endif  // CmXULAppInfo_h__
