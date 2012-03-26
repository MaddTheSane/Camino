/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>
#import <PreferencePanes/NSPreferencePane.h>

#import "PreferencePaneBase.h"

@class ExtendedTableView;

// for the "Policy" column in the Exceptions List
typedef enum ECookiePolicyPopupIndex
{
  eAllowIndex,
  eSessionOnlyIndex,
  eDenyIndex
} ECookiePolicyPopupIndex;

@interface OrgMozillaCaminoPreferencePrivacy : PreferencePaneBase
{
  // pane
  IBOutlet NSMatrix*          mCookieBehavior;
  IBOutlet NSButton*          mAskAboutCookies;

  IBOutlet NSButton*          mStorePasswords;

  BOOL                        mSortedAscending;   // sort direction for tables in sheets

  // permission sheet
  IBOutlet id                 mPermissionsPanel;
  IBOutlet ExtendedTableView* mPermissionsTable;
  IBOutlet NSTableColumn*     mPermissionColumn;
  IBOutlet NSSearchField*     mPermissionFilterField;
  NSMutableArray*             mPermissions;        // strong

  // cookie sheet
  IBOutlet id                 mCookiesPanel;
  IBOutlet ExtendedTableView* mCookiesTable;
  IBOutlet NSSearchField*     mCookiesFilterField;
  NSMutableArray*             mCookies;            // strong

  // Keychain Exclusions sheet
  IBOutlet id                 mKeychainExclusionsPanel;
  IBOutlet ExtendedTableView* mKeychainExclusionsTable;
  IBOutlet NSSearchField*     mKeychainExclusionsFilterField;
  NSMutableArray*             mKeychainExclusions; // strong
}

// main panel button actions
- (IBAction)clickCookieBehavior:(id)aSender;
- (IBAction)clickAskAboutCookies:(id)sender;
- (IBAction)clickStorePasswords:(id)sender;
- (IBAction)launchKeychainAccess:(id)sender;
- (IBAction)editKeychainExclusions:(id)sender;

// cookie editing functions
- (IBAction)editCookies:(id)aSender;
- (IBAction)editCookiesDone:(id)aSender;
- (IBAction)removeCookies:(id)aSender;
- (IBAction)removeAllCookies:(id)aSender;
- (IBAction)allowCookiesFromSites:(id)aSender;
- (IBAction)blockCookiesFromSites:(id)aSender;
- (IBAction)removeCookiesAndBlockSites:(id)aSender;

// permission editing functions
- (IBAction)editPermissions:(id)aSender;
- (IBAction)editPermissionsDone:(id)aSender;
- (IBAction)expandCookiePermission:(id)aSender;
- (IBAction)removeCookiePermissions:(id)aSender;
- (IBAction)removeAllCookiePermissions:(id)aSender;

// keychain exclusion list editing functions
- (IBAction)editKeychainExclusions:(id)sender;
- (IBAction)editKeychainExclusionsDone:(id)sender;
- (IBAction)removeKeychainExclusions:(id)sender;
- (IBAction)removeAllKeychainExclusions:(id)sender;

// data source informal protocol (NSTableDataSource)
- (int)numberOfRowsInTableView:(NSTableView *)aTableView;
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex;
- (void)tableView:(NSTableView *)aTableView setObjectValue:anObject forTableColumn:(NSTableColumn *)aTableColumn  row:(int)rowIndex;

// NSTableView delegate methods
- (void)tableView:(NSTableView *)aTableView didClickTableColumn:(NSTableColumn *)aTableColumn;

// Filtering delegate
- (IBAction)filterChanged:(id)sender;

@end
