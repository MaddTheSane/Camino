/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#define XPCOM_TRANSLATE_NSGM_ENTRY_POINT 1

#include "CmXULAppInfo.h"

#include "nsIGenericFactory.h"
#include "nsString.h"

//
// CmXULAppInfo module
//

static const CmXULAppInfo kCmXULAppInfo;

static NS_METHOD CmXULAppInfoConstructor(nsISupports *outer,
                                         REFNSIID iid,
                                         void **result) {
  NS_ENSURE_NO_AGGREGATION(outer);
  return const_cast<CmXULAppInfo *>(&kCmXULAppInfo)->QueryInterface(iid,
                                                                    result);
}

// {76849bf1-199d-41a6-aae6-873fcaf123ea}
#define CMXULAPPINFO_CID \
  {0x76849bf1, 0x199d, 0x41a6, {0xaa, 0xe6, 0x87, 0x3f, 0xca, 0xf1, 0x23, 0xea}}

static nsModuleComponentInfo kComponents[] = {
  {
    "CmXULAppInfo",
    CMXULAPPINFO_CID,
    "@mozilla.org/xre/app-info;1",
    CmXULAppInfoConstructor
  }
};

NS_IMPL_NSGETMODULE(CmXULAppInfoModule, kComponents)

//
// CmXULAppInfo class (XPCOM/C++)
//

// This can only exist as a singleton object, instantiated as a static const
// object above.  Deny destruction attempts by avoiding NS_IMPL_ISUPPORTS and
// overriding AddRef and Release.

NS_IMPL_QUERY_INTERFACE1(CmXULAppInfo, nsIXULAppInfo)

NS_IMETHODIMP_(nsrefcnt) CmXULAppInfo::AddRef() {
  return 1;
}

NS_IMETHODIMP_(nsrefcnt) CmXULAppInfo::Release() {
  return 1;
}

// Pass everything through to XULAppInfo.

NS_IMETHODIMP CmXULAppInfo::GetVendor(nsACString &result) {
  result.Assign([[XULAppInfo vendor] UTF8String]);
  return NS_OK;
}

NS_IMETHODIMP CmXULAppInfo::GetName(nsACString &result) {
  result.Assign([[XULAppInfo name] UTF8String]);
  return NS_OK;
}

NS_IMETHODIMP CmXULAppInfo::GetID(nsACString &result) {
  result.Assign([[XULAppInfo ID] UTF8String]);
  return NS_OK;
}

NS_IMETHODIMP CmXULAppInfo::GetVersion(nsACString &result) {
  result.Assign([[XULAppInfo version] UTF8String]);
  return NS_OK;
}

NS_IMETHODIMP CmXULAppInfo::GetAppBuildID(nsACString &result) {
  result.Assign([[XULAppInfo appBuildID] UTF8String]);
  return NS_OK;
}

NS_IMETHODIMP CmXULAppInfo::GetPlatformVersion(nsACString &result) {
  result.Assign([[XULAppInfo platformVersion] UTF8String]);
  return NS_OK;
}

NS_IMETHODIMP CmXULAppInfo::GetPlatformBuildID(nsACString &result) {
  result.Assign([[XULAppInfo platformBuildID] UTF8String]);
  return NS_OK;
}

//
// XULAppInfo class (Objective-C)
//

@implementation XULAppInfo

+ (NSString *)vendor {
  static NSString *kVendor = @"Mozilla";
  return kVendor;
}

+ (NSString *)name {
  return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
}

+ (NSString *)ID {
  static NSString *kID = @"{837e87d2-9e3c-4870-81be-86e6c4560dfd}";
  return kID;
}

+ (NSString *)version {
  return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
}

+ (NSString *)appBuildID {
  return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"MozillaBuildID"];
}

+ (NSString *)platformVersion {
  return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"MozillaGeckoVersion"];
}

+ (NSString *)platformBuildID {
  return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"MozillaBuildID"];
}

@end
