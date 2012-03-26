/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*-
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "Downloads.h"

#import "PreferenceManager.h"

@interface OrgMozillaCaminoPreferenceDownloads(Private)

- (void)setupDownloadMenuWithPath:(NSString*)inDLPath;

@end

@implementation OrgMozillaCaminoPreferenceDownloads

- (id)initWithBundle:(NSBundle*)bundle
{
  self = [super initWithBundle:bundle];
  return self;
}

- (void)dealloc
{
  [super dealloc];
}

- (void)willSelect
{
  // Our behaviour here should match what the browser does when the prefs don't exist.
  [mAutoCloseDLManager setState:([self getBooleanPref:kGeckoPrefCloseDownloadManagerWhenDone withSuccess:NULL]) ? NSOnState : NSOffState];
  [mEnableHelperApps setState:([self getBooleanPref:kGeckoPrefAutoOpenDownloads withSuccess:NULL]) ? NSOnState : NSOffState];
  [mDownloadRemovalPolicy selectItem:[[mDownloadRemovalPolicy menu] itemWithTag:[self getIntPref:kGeckoPrefDownloadCleanupPolicy
                                                                                     withSuccess:NULL]]];

  NSString* downloadFolderDesc = [[PreferenceManager sharedInstance] downloadDirectoryPath];
  if ([downloadFolderDesc length] == 0)
    downloadFolderDesc = [self localizedStringForKey:@"MissingDlFolder"];

  [self setupDownloadMenuWithPath:downloadFolderDesc];
}

- (IBAction)checkboxClicked:(id)sender
{
  if (sender == mAutoCloseDLManager)
    [self setPref:kGeckoPrefCloseDownloadManagerWhenDone toBoolean:[sender state]];

  if (sender == mEnableHelperApps)
    [self setPref:kGeckoPrefAutoOpenDownloads toBoolean:[sender state]];
}

// Given a full path to the d/l dir, display the leaf name and the Finder icon associated
// with that folder in the first item of the download folder popup.
//
- (void)setupDownloadMenuWithPath:(NSString*)inDLPath
{
  NSMenuItem* placeholder = [mDownloadFolder itemAtIndex:0];
  if (!placeholder)
    return;

  // Get the Finder icon and scale it down to 16x16.
  NSImage* icon = [[NSWorkspace sharedWorkspace] iconForFile:inDLPath];
  [icon setScalesWhenResized:YES];
  [icon setSize:NSMakeSize(16.0, 16.0)];

  // Set the title to the leaf name and the icon to what we gathered above.
  [placeholder setTitle:[[NSFileManager defaultManager] displayNameAtPath:inDLPath]];
  [placeholder setImage:icon];

  // Ensure the first item is selected.
  [mDownloadFolder selectItemAtIndex:0];
}

// Display a file picker sheet allowing the user to set their new download folder.
- (IBAction)chooseDownloadFolder:(id)sender
{
  NSString* oldDLFolder = [[PreferenceManager sharedInstance] downloadDirectoryPath];
  NSOpenPanel* panel = [NSOpenPanel openPanel];
  [panel setCanChooseFiles:NO];
  [panel setCanChooseDirectories:YES];
  [panel setAllowsMultipleSelection:NO];
  [panel setCanCreateDirectories:YES];
  [panel setPrompt:NSLocalizedString(@"ChooseDirectoryOKButton", @"")];

  [panel beginSheetForDirectory:oldDLFolder
                           file:nil
                          types:nil
                 modalForWindow:[mDownloadFolder window]
                  modalDelegate:self
                 didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:)
                    contextInfo:nil];
}

//
// Set the download removal policy.
//
- (IBAction)chooseDownloadRemovalPolicy:(id)sender
{
  // The three options in the popup contains tags 0-2; set the pref according to the
  // selected menu item's tag.
  int selectedTagValue = [mDownloadRemovalPolicy selectedTag];
  [self setPref:kGeckoPrefDownloadCleanupPolicy toInt:selectedTagValue];
}

// This is called when the user closes the open panel sheet for selecting a new d/l folder.
// If they clicked ok, change the pref and display the new choice in the
// popup menu.
- (void)openPanelDidEnd:(NSOpenPanel*)sheet returnCode:(int)returnCode contextInfo:(void*)contextInfo
{
  if (returnCode == NSOKButton) {
    // stuff path into pref
    NSString* newPath = [[sheet filenames] objectAtIndex:0];
    [[PreferenceManager sharedInstance] setDownloadDirectoryPath:newPath];

    // update the menu
    [self setupDownloadMenuWithPath:newPath];
  }
  else {
    [mDownloadFolder selectItemAtIndex:0];
  }
}

@end
