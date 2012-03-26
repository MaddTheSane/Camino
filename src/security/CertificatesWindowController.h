/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */


#import <AppKit/AppKit.h>

@class ExtendedSplitView;
@class ExtendedOutlineView;

@interface CertificatesWindowController : NSWindowController
{
  IBOutlet ExtendedSplitView*   mSplitter;
  
  IBOutlet NSTableView*         mCategoriesTable;
  IBOutlet ExtendedOutlineView* mCertsOutlineView;

  IBOutlet NSTableColumn*       mDetailsColumn;
  
  IBOutlet NSMenu*              mUserCertsContextMenu;
  IBOutlet NSMenu*              mOtherCertsContextMenu;
  
  NSArray*                      mCertificatesData;
  NSString*                     mDetailsColumnKey;
}

+ (CertificatesWindowController*)sharedCertificatesWindowController;

- (IBAction)viewSelectedCertificates:(id)sender;
- (IBAction)deleteSelectedCertificates:(id)sender;

- (IBAction)backupSelectedCertificates:(id)sender;
- (IBAction)backupAllCertificates:(id)sender;

- (IBAction)importCertificates:(id)sender;

@end

