/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*-
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>
#import <PreferencePanes/NSPreferencePane.h>
#import "PreferencePaneBase.h"

@class ExtendedTableView;

@interface OrgMozillaCaminoPreferenceWebFeatures : PreferencePaneBase
{
  IBOutlet NSButton*      mEnableJS;
  IBOutlet NSButton*      mEnableJava;
  IBOutlet NSButton*      mEnablePopupBlocking;
  IBOutlet NSButton*      mEnableAdBlocking;
  IBOutlet NSButton*      mPreventAnimation;
  IBOutlet NSButton*      mEditWhitelist;
  IBOutlet NSButton*      mEditFlashblockWhitelist;
  IBOutlet NSButton*      mEnableFlashblock;
  IBOutlet NSButton*      mEnableAnnoyanceBlocker;
  IBOutlet NSPopUpButton* mTabBehaviorPopup;

  IBOutlet id mWhitelistPanel;
  IBOutlet ExtendedTableView*   mWhitelistTable;
  IBOutlet NSTableColumn*       mPolicyColumn;
  IBOutlet NSTextField*         mAddField;
  IBOutlet NSButton*            mAddButton;

  IBOutlet id                   mFlashblockWhitelistPanel;
  IBOutlet ExtendedTableView*   mFlashblockWhitelistTable;
  IBOutlet NSTextField*         mAddFlashblockField;
  IBOutlet NSButton*            mAddFlashblockButton;
  NSArray*                      mFlashblockSites;        // STRONG

  NSMutableArray* mCachedPermissions;		// cached list for speed, STRONG
}

-(IBAction) clickEnableJS:(id)sender;
-(IBAction) clickEnableJava:(id)sender;

-(IBAction) clickEnablePopupBlocking:(id)sender;
-(IBAction) clickEnableAdBlocking:(id)sender;
-(IBAction) clickPreventAnimation:(id)sender;
-(IBAction) editWhitelist:(id)sender;
-(IBAction) editFlashblockWhitelist:(id)sender;
-(IBAction) clickEnableFlashblock:(id)sender;

-(IBAction) clickEnableAnnoyanceBlocker:(id)sender;
-(void) setAnnoyingWindowPrefsTo:(BOOL)inValue;

-(IBAction) tabFocusBehaviorChanged:(id)sender;

// whitelist sheet methods
-(IBAction) editWhitelistDone:(id)aSender;
-(IBAction) removeWhitelistSite:(id)aSender;
-(IBAction) addWhitelistSite:(id)sender;
-(void) editWhitelistSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void  *)contextInfo;

// Flashblock whitelist sheet methods
-(IBAction) editFlashblockWhitelistDone:(id)aSender;
-(IBAction) removeFlashblockWhitelistSite:(id)aSender;
-(IBAction) addFlashblockWhitelistSite:(id)Sender;
-(void) updateFlashblockWhitelist;

// data source informal protocol (NSTableDataSource)
- (int)numberOfRowsInTableView:(NSTableView *)aTableView;
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex;

@end
