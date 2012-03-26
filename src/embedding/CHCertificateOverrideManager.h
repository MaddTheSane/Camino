/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
* License, v. 2.0. If a copy of the MPL was not distributed with this
* file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>

class nsIX509Cert;

// Bit flags for various specific certificate validation problems.
extern const int CHCertificateOverrideFlagUntrusted;
extern const int CHCertificateOverrideFlagDomainMismatch;
extern const int CHCertificateOverrideFlagInvalidTime;

// Provides access to and management of certificate exceptions. Wraps the Gecko
// nsICertOverrideService.
@interface CHCertificateOverrideManager : NSObject {
}

// Returns an autoreleased CHCertificateOverrideManager.
+ (CHCertificateOverrideManager*)certificateOverrideManager;

// Returns all cert overrides, as host:port strings.
- (NSArray*)overrideHosts;

// Adds an override for the given host/port pair. The override is only valid
// for the given cert and validation problems.
// Returns YES if the override was successfully added.
- (BOOL)addOverrideForHost:(NSString*)host
                      port:(int)port
                  withCert:(nsIX509Cert*)cert
           validationFlags:(int)validationFlags;

// Removes the override for the given host/port pair.
// Returns YES if the override was successfully removed.
- (BOOL)removeOverrideForHost:(NSString*)host port:(int)port;

@end
