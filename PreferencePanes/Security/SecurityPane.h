/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>
#import <PreferencePanes/NSPreferencePane.h>

#import "PreferencePaneBase.h"

@class ExtendedTableView;

@interface OrgMozillaCaminoPreferenceSecurity : PreferencePaneBase
{
  IBOutlet NSButton* mSafeBrowsing;
  IBOutlet NSButton* mLeaveEncrypted;
  IBOutlet NSButton* mViewMixed;
  IBOutlet NSMatrix* mCertificateBehavior;

  // Certificate override sheet.
  IBOutlet id                 mOverridePanel;
  IBOutlet NSArrayController* mOverridesController;
  IBOutlet ExtendedTableView* mOverridesTable;
  NSMutableArray*             mOverrides;      // strong
}

- (IBAction)clickSafeBrowsing:(id)sender;

- (IBAction)clickEnableLeaveEncrypted:(id)sender;
- (IBAction)clickEnableViewMixed:(id)sender;

- (IBAction)clickCertificateSelectionBehavior:(id)sender;
- (IBAction)showCertificates:(id)sender;

// Brings up the sheet for removing certificate overrides.
- (IBAction)editOverrides:(id)aSender;

// Dismisses the sheet for removing certificate overrides.
- (IBAction)editOverridesDone:(id)aSender;

// Removes the currently selected certificate overrides.
- (IBAction)removeOverrides:(id)aSender;

// Removes all of the certificate overrides, after prompting for confirmation.
- (IBAction)removeAllOverrides:(id)aSender;

@end
