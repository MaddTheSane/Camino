/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*-
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <PreferencePaneBase.h>

@interface OrgMozillaCaminoPreferenceGeneral : PreferencePaneBase
{
  IBOutlet NSTextField*   textFieldHomePage;

  IBOutlet NSButton*      checkboxNewTabBlank;
  IBOutlet NSButton*      checkboxNewWindowBlank;
  IBOutlet NSPopUpButton* defaultBrowserPopUp;
  IBOutlet NSPopUpButton* defaultFeedViewerPopUp;
  IBOutlet NSButton*      checkboxCheckDefaultBrowserOnLaunch;
  IBOutlet NSButton*      checkboxWarnWhenClosing;
  IBOutlet NSButton*      checkboxRememberWindowState;
  IBOutlet NSButton*      checkboxAutoUpdate;
}

- (IBAction)homePageModified:(id)sender;
- (IBAction)checkboxStartPageClicked:(id)sender;
- (IBAction)defaultBrowserChange:(id)sender;
- (IBAction)defaultFeedViewerChange:(id)sender;
- (IBAction)warningCheckboxClicked:(id)sender;
- (IBAction)rememberWindowStateCheckboxClicked:(id)sender;
- (IBAction)checkDefaultBrowserOnLaunchClicked:(id)sender;
- (IBAction)autoUpdateCheckboxClicked:(id)sender;

// called when the default feed viewer is modified in FeedServiceController
// so we can rebuild the list here as well
- (void)updateDefaultFeedViewerMenu;

- (IBAction)defaultFeedViewerChange:(id)sender;
- (IBAction)runOpenDialogToSelectBrowser:(id)sender;
- (IBAction)runOpenDialogToSelectFeedViewer:(id)sender;

@end
