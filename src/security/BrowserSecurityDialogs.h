/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <AppKit/AppKit.h>

class nsIX509Cert;

@class DownloadCACertDialogController;
@class InvalidCertOverrideDialogController;
@class CreatePasswordDialogController;
@class GenKeyPairDialogController;
@class ChooseCertDialogController;
@class AutoSizingTextField;

@interface BrowserSecurityUIProvider : NSObject
{
}

+ (BrowserSecurityUIProvider*)sharedBrowserSecurityUIProvider;
+ (NSImage*)lockBadgedApplicationIcon;

// these dialog controllers are autoreleased. You should retain them while running the dialog.
- (DownloadCACertDialogController*)downloadCACertDialogController;
- (InvalidCertOverrideDialogController*)invalidCertOverrideDialogController;
- (CreatePasswordDialogController*)createPasswordDialogController;
- (GenKeyPairDialogController*)genKeyPairDialogController;
- (ChooseCertDialogController*)chooseCertDialogController;

@end


@class CertificateView;

// generic base class for a dialog that contains an icon and a certificate view
@interface CertificateDialogController : NSWindowController
{
  IBOutlet NSImageView*           mIcon;
  IBOutlet CertificateView*       mCertificateView;
}

- (void)setCertificateItem:(CertificateItem*)inCert;

@end


@interface DownloadCACertDialogController : CertificateDialogController
{
  IBOutlet NSTextField*           mMessageField;
}

- (IBAction)onOK:(id)sender;
- (IBAction)onCancel:(id)sender;

// mask of nsIX509CertDB usage flags, from the cert view
- (unsigned int)trustMaskSetting;

@end


// informal protocol implemented by delegates of InvalidCertOverrideDialogController
@interface NSObject(InvalidCertOverrideDelegate)

- (void)certOverride:(InvalidCertOverrideDialogController*)certDialogController
  finishedWithResult:(BOOL)didAddOverride;

@end

@interface InvalidCertOverrideDialogController : CertificateDialogController
{
  IBOutlet NSTextField*         mTitleField;
  IBOutlet AutoSizingTextField* mMessageField;
  NSString*                     mSourceHost;
  int                           mSourcePort;
  int                           mCertFailureFlags;
  id                            mDelegate;      // weak
}

// Shows an override dialog, then calls certOverride:finishedWithResult: on |delegate|
- (void)showWithSourceURL:(NSURL*)url parentWindow:(NSWindow*)parent delegate:(id)delegate;

- (IBAction)onTrust:(id)sender;
- (IBAction)onCancel:(id)sender;


@end


// informal protocol implemented by delegates of CreatePasswordDialogController, used to check
// the old password
@interface NSObject(CreatePasswordDelegate)

- (BOOL)changePasswordDialogController:(CreatePasswordDialogController*)inController oldPasswordValid:(NSString*)oldPassword;

@end

@interface CreatePasswordDialogController : NSWindowController
{
  IBOutlet NSImageView*         mIcon;

  IBOutlet NSButton*            mOKButton;
  IBOutlet NSButton*            mCancelButton;
  
  IBOutlet NSTextField*         mTitleField;
  IBOutlet NSTextField*         mMessageField;

  IBOutlet NSView*              mCurPasswordContainer;
  IBOutlet NSView*              mNewPasswordContainer;

  IBOutlet NSTextField*         mCurPasswordField;

  IBOutlet NSTextField*         mNewPasswordField;
  IBOutlet NSTextField*         mVerifyPasswordField;

  IBOutlet NSTextField*         mNewPasswordNotesField;
  IBOutlet NSTextField*         mVerifyPasswordNotesField;

  // this should really be an NSLevelIndicator
  IBOutlet NSProgressIndicator* mQualityIndicator;
  
  BOOL                          mShowingOldPassword;
  id                            mDelegate;
}

- (void)setDelegate:(id)inDelegate;
- (id)delegate;

- (IBAction)onOK:(id)sender;
- (IBAction)onCancel:(id)sender;

- (void)setTitle:(NSString*)inTitle message:(NSString*)inMessage;
- (void)hideChangePasswordField;

- (NSString*)currentPassword;
- (NSString*)newPassword;

@end


@interface GenKeyPairDialogController : NSWindowController
{
  IBOutlet NSImageView*           mIcon;
  IBOutlet NSProgressIndicator*   mProgressIndicator;
}

- (IBAction)onCancel:(id)sender;
- (void)keyPairGenerationComplete;

@end

@interface ChooseCertDialogController : NSWindowController
{
  IBOutlet NSImageView*           mIcon;

  IBOutlet NSTextField*           mMessageText;
  
  IBOutlet NSPopUpButton*         mCertPopup;
  IBOutlet CertificateView*       mCertificateView;
}

- (IBAction)onOK:(id)sender;
- (IBAction)onCancel:(id)sender;

- (IBAction)onCertPopupChanged:(id)sender;

- (void)setCommonName:(NSString*)inCommonName organization:(NSString*)inOrg issuer:(NSString*)inIssuer;
- (void)setCertificates:(NSArray*)inCertificates;
- (CertificateItem*)selectedCert;

@end

