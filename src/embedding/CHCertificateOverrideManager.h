/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
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
* The Original Code is Camino code.
*
* The Initial Developer of the Original Code is
* Stuart Morgan
* Portions created by the Initial Developer are Copyright (C) 2009
* the Initial Developer. All Rights Reserved.
*
* Contributor(s):
*   Stuart Morgan <stuart.morgan@alumni.case.edu>
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
