/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "NSDate+Utils.h"

#import "CertificateItem.h"
#import "CertificateView.h"
#import "ViewCertificateDialogController.h"
#import "nsAlertController.h"

#include "nsCOMPtr.h"
#include "nsString.h"
#include "nsIMutableArray.h"

#include "nsIX509Cert.h"
#include "nsIX509CertValidity.h"
#include "nsIX509CertDB.h"

#include "nsServiceManagerUtils.h"


@interface ViewCertificateDialogController(Private)

@end

#pragma mark -

@implementation ViewCertificateDialogController

+ (ViewCertificateDialogController*)showCertificateWindowWithCertificateItem:(CertificateItem*)inCertItem certTypeForTrustSettings:(unsigned int)inCertType
{
  // look for existing window with this cert
  NSEnumerator* windowEnum = [[NSApp windows] objectEnumerator];
  NSWindow* thisWindow;
  while ((thisWindow = [windowEnum nextObject]))
  {
    if ([[thisWindow delegate] isKindOfClass:[ViewCertificateDialogController class]])
    {
      ViewCertificateDialogController* dialogController = (ViewCertificateDialogController*)[thisWindow delegate];
      if ([[dialogController certificateItem] isEqualTo:inCertItem])
      {
        [dialogController showWindow:nil];
        return dialogController;
      }
    }
  }

  // init balanced by the autorelease in windowWillClose
  ViewCertificateDialogController* viewCertDialogController = [[ViewCertificateDialogController alloc] initWithWindowNibName:@"ViewCertificateDialog"];
  [viewCertDialogController setCertTypeForTrustSettings:inCertType];
  [viewCertDialogController setCertificateItem:inCertItem];
  [viewCertDialogController showWindow:nil];
  return viewCertDialogController;
}


+ (void)runModalCertificateWindowWithCertificateItem:(CertificateItem*)inCertItem certTypeForTrustSettings:(unsigned int)inCertType
{
  // init balanced by the autorelease in windowWillClose
  ViewCertificateDialogController* viewCertDialogController = [[ViewCertificateDialogController alloc] initWithWindowNibName:@"ViewCertificateDialog"];
  [viewCertDialogController setCertTypeForTrustSettings:inCertType];
  [viewCertDialogController setCertificateItem:inCertItem];
  [viewCertDialogController runModally];
  [viewCertDialogController release];
}

- (void)dealloc
{
  [super dealloc];
}

- (void)awakeFromNib
{
}

- (void)windowDidLoad
{
  [[self window] setFrameAutosaveName:@"ViewCertificateDialog"];
  mAllowTrustSaving = YES;
  [mCertView setDelegate:self];
}

- (void)windowWillClose:(NSNotification *)aNotification
{
  if (mAllowTrustSaving)
    [mCertView saveTrustSettings:nil];
  
  if (!mRunningModally)
    [self autorelease];

  [mCertView setCertificateItem:nil];
}

- (int)runModally
{
  mRunningModally = YES;
  return [nsAlertController safeRunModalForWindow:[self window]];
}

- (void)allowTrustSaving:(BOOL)inAllow
{
  mAllowTrustSaving = inAllow;
}

- (IBAction)defaultButtonHit:(id)sender
{
  if (mRunningModally)
  {
    if (mAllowTrustSaving)
      [mCertView saveTrustSettings:nil];

    [NSApp stopModalWithCode:NSAlertDefaultReturn];
    [[self window] orderOut:nil];
  }
  else
    [self close];
}

- (IBAction)alternateButtonHit:(id)sender
{
  if (mRunningModally)
  {
    [NSApp stopModalWithCode:NSAlertAlternateReturn];
    [[self window] orderOut:nil];
  }
  else
    [self close];
}

// CertificateViewDelegate method
- (void)certificateView:(CertificateView*)certView showIssuerCertificate:(CertificateItem*)issuerCert
{
  // if we are modal, then this must also be modal
  if (mRunningModally)
    [ViewCertificateDialogController runModalCertificateWindowWithCertificateItem:issuerCert
                                                         certTypeForTrustSettings:nsIX509Cert::CA_CERT];
  else
    [ViewCertificateDialogController showCertificateWindowWithCertificateItem:issuerCert
                                                     certTypeForTrustSettings:nsIX509Cert::CA_CERT];
}

- (void)setCertificateItem:(CertificateItem*)inCert
{
  [[self window] setTitle:[inCert displayName]];  // also makes sure that the window is loaded
  [mCertView setCertificateItem:inCert];
}

- (CertificateItem*)certificateItem
{
  return [mCertView certificateItem];
}

- (void)setCertTypeForTrustSettings:(unsigned int)inCertType
{
  [self window];    // make sure view is hooked up
  [mCertView setCertTypeForTrustSettings:inCertType];
}

@end
