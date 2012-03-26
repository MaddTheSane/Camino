/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
* License, v. 2.0. If a copy of the MPL was not distributed with this
* file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>

class nsIPermission;
class nsIPermissionManager;

// Policy constants.
__attribute__((visibility("default"))) extern const int CHPermissionUnknown;
__attribute__((visibility("default"))) extern const int CHPermissionAllow;
__attribute__((visibility("default"))) extern const int CHPermissionDeny;
// Cookie-only policy constant.
__attribute__((visibility("default"))) extern const int CHPermissionAllowForSession;

// Permission type constants.
__attribute__((visibility("default"))) extern NSString* const CHPermissionTypeCookie;
__attribute__((visibility("default"))) extern NSString* const CHPermissionTypePopup;

// An object encompasing a specific permission entry. Used only for enumerating
// existing permissions; to check or set the permissions for a single host,
// use CHPermissionManager directly.
@interface CHPermission : NSObject {
 @private
  NSString* mHost;   // strong
  NSString* mType;   // strong
  int       mPolicy;
}

// The host the permission applies to.
- (NSString*)host;

// The type of the permission. May be an arbitrary value, but common values
// are defined in the CHPermissionType* constants.
- (NSString*)type;

// The policy for the permission. May be an arbitrary value, but common values
// are defined in the CHPermission* constants.
- (int)policy;
- (void)setPolicy:(int)policy;

@end

#pragma mark -

// The object responsible for querying and setting the permissions (cookies,
// popups, etc.) of specific hosts. Wraps the Gecko nsIPermissionManager. 
@interface CHPermissionManager : NSObject {
 @private
  nsIPermissionManager* mManager; // strong
}

// Returns the shared CHPermissionManager instance.
+ (CHPermissionManager*)permissionManager;

// Gets all permissions of the given type. |type| can be an arbitrary value,
// but common types are defined in the CHPermissionType* constants.
// If |type| is nil, all permissions are returned.
- (NSArray*)permissionsOfType:(NSString*)type;

// Removes a specific permission for host |host|
- (void)removePermissionForHost:(NSString*)host type:(NSString*)type;

// Clears all permissions, of all types, far all hosts. Handle with care.
- (void)removeAllPermissions;

// Getters and setters for individual site policies. Sites can be specified
// either by host (www.foo.com) or full URI. Policy and type may be arbitrary
// values, but common values are defined as constants above.
- (int)policyForHost:(NSString*)host type:(NSString*)type;
- (int)policyForURI:(NSString*)uri type:(NSString*)type;
- (void)setPolicy:(int)policy forHost:(NSString*)host type:(NSString*)type;
- (void)setPolicy:(int)policy forURI:(NSString*)uri type:(NSString*)type;

@end
