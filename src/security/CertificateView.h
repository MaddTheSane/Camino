/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <AppKit/AppKit.h>
#import "CHStackView.h"

@class CertificateItem;

// this is a view that builds its contents dynamically from the cert.
@interface CertificateView : CHShrinkWrapView
{
  CHStackView*              mContentView;       // created dynamically, retained
  
  NSView*                   mTrustItemsView;    // weak
  NSView*                   mDetailsItemsView;  // weak
  
  BOOL                      mForceShowTrust;         // even if we can't read the trust settings, allow the user to set them
  BOOL                      mDetailsExpanded;
  BOOL                      mTrustExpanded;

  // these are not retained; only non-null if trust settings visible
  NSButton*                 mTrustForWebSitesCheckbox;
  NSButton*                 mTrustForEmailCheckbox;
  NSButton*                 mTrustForObjSigningCheckbox;
  
  BOOL                      mTrustedForWebSites;
  BOOL                      mTrustedForEmail;
  BOOL                      mTrustedForObjectSigning;
  
  id                        mDelegate;        // not retained
  CertificateItem*          mCertItem;        // retained
  unsigned int              mCertTrustType;
  
  NSMutableDictionary*      mExpandedStatesDictionary;    // dict to hold expanded states of "hex" views
}

- (CertificateItem*)certificateItem;
- (void)setCertificateItem:(CertificateItem*)inCertItem;

- (void)setDelegate:(id)inDelegate;
- (id)delegate;

- (void)setShowTrust:(BOOL)inShowTrust;

// trust settings will be shown for EMAIL_CERT and CA_CERT, not otherwise
- (void)setCertTypeForTrustSettings:(unsigned int)inCertType;

- (void)setDetailsInitiallyExpanded:(BOOL)inExpanded;
- (void)setTrustInitiallyExpanded:(BOOL)inExpanded;


- (IBAction)toggleDetails:(id)sender;
- (IBAction)toggleTrustSettings:(id)sender;

// it's up to users of this view to save settings if they want to
- (IBAction)saveTrustSettings:(id)sender;

// mask of nsIX509CertDB usage flags, as specified via the checkboxes
- (unsigned int)trustMaskSetting;

@end

// informal protocol for CertificateView delegate
@interface NSObject(CertificateViewDelegate)

- (void)certificateView:(CertificateView*)certView showIssuerCertificate:(CertificateItem*)issuerCert;

@end
