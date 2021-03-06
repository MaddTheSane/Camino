/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
* License, v. 2.0. If a copy of the MPL was not distributed with this
* file, You can obtain one at http://mozilla.org/MPL/2.0/. */

// TODO: re-vend PERM_CHANGE_NOTIFICATIONs in a Cocoa-y way.

#import "CHPermissionManager.h"

// For shutdown notification names.
#import "CHBrowserService.h"

#include "nsCOMPtr.h"
#include "nsString.h"
#include "nsServiceManagerUtils.h"
#include "nsIPermission.h"
#include "nsIPermissionManager.h"
#include "nsICookiePermission.h"
#include "nsISimpleEnumerator.h"
#include "nsIURI.h"
#include "nsNetUtil.h"

#pragma mark Policy Definitions

__attribute__((used)) const int CHPermissionUnknown = nsIPermissionManager::UNKNOWN_ACTION;
__attribute__((used)) const int CHPermissionAllow = nsIPermissionManager::ALLOW_ACTION;
__attribute__((used)) const int CHPermissionDeny = nsIPermissionManager::DENY_ACTION;
__attribute__((used)) const int CHPermissionAllowForSession = nsICookiePermission::ACCESS_SESSION;

#pragma mark Permission Type Definitions

__attribute__((used)) NSString* const CHPermissionTypeCookie = @"cookie";
__attribute__((used)) NSString* const CHPermissionTypePopup = @"popup";

#pragma mark -

@interface CHPermission (CHPermissionManagerMethods)
+ (id)permissionWithGeckoPermission:(nsIPermission*)geckoPermission;
- (id)initWithGeckoPermission:(nsIPermission*)geckoPermission;
@end

@implementation CHPermission

// Creates an autoreleased Cocoa-ized version of the given gecko permission
// object. Note that it has its own copy of the data, and doesn't actually
// hold a ref to the gecko permission.
+ (id)permissionWithGeckoPermission:(nsIPermission*)geckoPermission
{
  return [[[self alloc] initWithGeckoPermission:geckoPermission] autorelease];
}

- (id)initWithGeckoPermission:(nsIPermission*)geckoPermission
{
  if ((self = [super init])) {
    if (!geckoPermission) {
      [self release];
      return nil;
    }
    // nsIPermission is just a glorified struct, so there's no reason to keep it
    // around; just convert it into a Cocoa-y data store.
    nsCAutoString host;
    geckoPermission->GetHost(host);
    mHost = [[NSString alloc] initWithCString:host.get()];
    nsCAutoString type;
    geckoPermission->GetType(type);
    mType = [[NSString alloc] initWithCString:type.get()];
    PRUint32 policy;
    geckoPermission->GetCapability(&policy);
    mPolicy = policy;
  }
  return self;
}

- (void)dealloc
{
  [mHost release];
  [mType release];

  [super dealloc];
}

- (NSString*)host
{
  return mHost;
}

- (NSString*)type
{
  return mType;
}

- (int)policy
{
  return mPolicy;
}

// Convenience method allowing Permission objects to act like they are
// mutable and work correctly, even though they aren't hooked up to anything.
- (void)setPolicy:(int)policy
{
  mPolicy = policy;
  [[CHPermissionManager permissionManager] setPolicy:policy forHost:mHost type:mType];
}

- (NSString*)description
{
  return [NSString stringWithFormat:@"<CHPermission %08p, %@ - %@: %d>",
    self, [self host], [self type], [self policy]];
}

@end

#pragma mark -

static CHPermissionManager* sPermissionManager = nil;

@implementation CHPermissionManager

+ (CHPermissionManager*)permissionManager
{
  if (!sPermissionManager)
    sPermissionManager = [[self alloc] init];
  return sPermissionManager;
}

- (id)init
{
  if ((self = [super init])) {
    nsCOMPtr<nsIPermissionManager> pm(do_GetService(NS_PERMISSIONMANAGER_CONTRACTID));
    mManager = pm.get();
    if (!mManager) {
      [self release];
      return nil;
    }
    NS_ADDREF(mManager);

    // Register for xpcom shutdown so that we can release the manager.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(xpcomShutdown:)
                                                 name:kXPCOMShutDownNotification
                                               object:nil];
  }
  return self;
}

- (void)dealloc
{
  sPermissionManager = nil;
  NS_IF_RELEASE(mManager);

  [super dealloc];
}

- (void)xpcomShutdown:(NSNotification*)notification
{
  // This nulls out the pointer
  NS_IF_RELEASE(mManager);
}

- (NSArray*)permissionsOfType:(NSString*)type
{
  if (!mManager)
    return nil;
  const char* typeCString = [type UTF8String];

  nsCOMPtr<nsISimpleEnumerator> permEnumerator;
  mManager->GetEnumerator(getter_AddRefs(permEnumerator));

  if (!permEnumerator)
    return nil;

  NSMutableArray* permissions = [NSMutableArray array];

  // There's no corresponding accessor for nsIPermissionManager, so we have
  // to walk all permissions and check the type of each one.
  PRBool hasMoreElements;
  permEnumerator->HasMoreElements(&hasMoreElements);
  while (hasMoreElements) {
    nsCOMPtr<nsISupports> curr;
    permEnumerator->GetNext(getter_AddRefs(curr));
    nsCOMPtr<nsIPermission> currPerm(do_QueryInterface(curr));
    if (currPerm) {
      nsCAutoString permType;
      currPerm->GetType(permType);
      if (!type || permType.Equals(typeCString)) {
        CHPermission* perm = [CHPermission permissionWithGeckoPermission:currPerm.get()];
        [permissions addObject:perm];
      }
    }
    permEnumerator->HasMoreElements(&hasMoreElements);
  }
  return permissions;
}

- (void)removePermissionForHost:(NSString*)host type:(NSString*)type
{
  if (!mManager)
    return;
  mManager->Remove(nsDependentCString([host UTF8String]), [type UTF8String]);
}

- (void)removeAllPermissions
{
  if (!mManager)
    return;
  mManager->RemoveAll();
}

- (int)policyForHost:(NSString*)host type:(NSString*)type
{
  // Even though the permissons are host-based, the Gecko API requires an
  // nsIURI, so we have to construct a dummy URI and look it up that way.
  return [self policyForURI:[NSString stringWithFormat:@"http://%@", host] type:type];
}

- (int)policyForURI:(NSString*)uri type:(NSString*)type
{
  if (!mManager)
    return CHPermissionUnknown;
  nsCOMPtr<nsIURI> geckoURI;
  NS_NewURI(getter_AddRefs(geckoURI), [uri UTF8String]);
  if (!geckoURI)
    return CHPermissionUnknown;
  PRUint32 policy;
  mManager->TestPermission(geckoURI, [type UTF8String], &policy);
  return policy;
}

- (void)setPolicy:(int)policy forHost:(NSString*)host type:(NSString*)type
{
  // Even though the permissons are host-based, the Gecko API requires an
  // nsIURI, so we have to construct a dummy URI and look it up that way.
  [self setPolicy:policy forURI:[NSString stringWithFormat:@"http://%@", host] type:type];
}

- (void)setPolicy:(int)policy forURI:(NSString*)uri type:(NSString*)type
{
  if (!mManager)
    return;
  nsCOMPtr<nsIURI> geckoURI;
  NS_NewURI(getter_AddRefs(geckoURI), [uri UTF8String]);
  if (!geckoURI)
    return;
  mManager->Add(geckoURI, [type UTF8String], policy);
}

@end
