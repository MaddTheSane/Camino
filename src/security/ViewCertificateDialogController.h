/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <AppKit/AppKit.h>

@class CertificateItem;
@class CertificateView;

@interface ViewCertificateDialogController : NSWindowController
{
  IBOutlet CertificateView*         mCertView;
  IBOutlet NSButton*                mOKButton;
  
  // runtime data
  BOOL                              mRunningModally;
  BOOL                              mAllowTrustSaving;    // whether to save the trust settings on window close
}


// if a window exists showing this cert, this will raise it and return its controller
+ (ViewCertificateDialogController*)showCertificateWindowWithCertificateItem:(CertificateItem*)inCertItem certTypeForTrustSettings:(unsigned int)inCertType;
// this will always run a new modal dialog
+ (void)runModalCertificateWindowWithCertificateItem:(CertificateItem*)inCertItem certTypeForTrustSettings:(unsigned int)inCertType;

// XXX we'll want to be able to custmize the buttons etc.

- (IBAction)defaultButtonHit:(id)sender;
- (IBAction)alternateButtonHit:(id)sender;

- (void)setCertificateItem:(CertificateItem*)inCert;
- (CertificateItem*)certificateItem;

- (void)setCertTypeForTrustSettings:(unsigned int)inCertType;  // one of the types in nsIX509Cert

- (int)runModally;
// default is YES
- (void)allowTrustSaving:(BOOL)inAllow;

@end

