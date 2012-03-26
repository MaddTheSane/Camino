/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
* License, v. 2.0. If a copy of the MPL was not distributed with this
* file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "CHCertificateOverrideManager.h"

#import "NSString+Gecko.h"

#include "nsCOMPtr.h"
#include "nsIX509Cert.h"
#include "nsICertOverrideService.h"
#include "nsICertTree.h"
#include "nsServiceManagerUtils.h"
#include "nsString.h"

// Xcode 2.x's ld dead-strips this symbol.  Xcode 3.0's ld is fine.
asm(".no_dead_strip .objc_class_name_CHCertificateOverrideManager");

const int CHCertificateOverrideFlagUntrusted =
  nsICertOverrideService::ERROR_UNTRUSTED;
const int CHCertificateOverrideFlagDomainMismatch =
  nsICertOverrideService::ERROR_MISMATCH;
const int CHCertificateOverrideFlagInvalidTime =
  nsICertOverrideService::ERROR_TIME;

@implementation CHCertificateOverrideManager

+ (CHCertificateOverrideManager*)certificateOverrideManager
{
  return [[[self alloc] init] autorelease];
}

- (NSArray*)overrideHosts
{
  NSMutableArray* overrides = [NSMutableArray array];
  // There is no way to get a list of all the overrides via the APIs,
  // other than to go via nsICertTree; see bug 467317.
  nsCOMPtr<nsICertTree> certTree =
    do_CreateInstance("@mozilla.org/security/nsCertTree;1");
  if (!certTree)
    return overrides;
  nsresult rv = certTree->LoadCerts(nsIX509Cert::SERVER_CERT);
  if (NS_FAILED(rv))
    return overrides;

  PRInt32 rowCount = 0;
  certTree->GetRowCount(&rowCount);
  for (PRInt32 i = 0; i < rowCount; ++i) {
    PRBool isOverride = PR_FALSE;
    certTree->IsHostPortOverride(i, &isOverride);
    if (!isOverride)
      continue;
    nsCOMPtr<nsICertTreeItem> treeItem;
    certTree->GetTreeItem(i, getter_AddRefs(treeItem));
    if (!treeItem)
      continue;

    nsAutoString hostPort;
    treeItem->GetHostPort(hostPort);
    [overrides addObject:[NSString stringWith_nsAString:hostPort]];
  }
  return overrides;
}

- (BOOL)addOverrideForHost:(NSString*)host
                      port:(int)port
                  withCert:(nsIX509Cert*)cert
           validationFlags:(int)validationFlags
{
  nsCOMPtr<nsICertOverrideService> overrideService =
    do_GetService(NS_CERTOVERRIDE_CONTRACTID);
  if (!overrideService)
    return NO;

  overrideService->RememberValidityOverride(
      nsDependentCString([host UTF8String]), port,
      cert, validationFlags, PR_FALSE);
  return YES;
}

- (BOOL)removeOverrideForHost:(NSString*)host port:(int)port
{
  nsCOMPtr<nsICertOverrideService> overrideService =
    do_GetService(NS_CERTOVERRIDE_CONTRACTID);
  if (!overrideService)
    return NO;

  overrideService->ClearValidityOverride(nsDependentCString([host UTF8String]),
                                         port);
  return YES;
}

@end
