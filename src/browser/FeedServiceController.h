/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>

/*
This is a simple controller class that handles notifications to the user when
dealing with opening feeds from within Camino. 

If the user attempts to open a feed detected in Camino, this class checks for
available applications that are registered for "feed://". If there are no
applications found, display a sheet that warns the user and allows them to 
select a application. If there are feed applications found, run a sheet that 
allows the user to choose a new default feed viewer, and open or cancel the 
opening action.
*/

@interface FeedServiceController : NSObject 
{
  IBOutlet NSWindow*      mNotifyOpenExternalFeedApp;  // shown when there are RSS viewing apps
  IBOutlet NSWindow*      mNotifyNoFeedAppFound;       // shown when there is not a RSS viewing app registered
  
  IBOutlet NSPopUpButton* mFeedAppsPopUp;              // pop-up that contains the registered RSS viewer apps
  IBOutlet NSButton*      mSelectAppButton;            // button that allows user to select a RSS viewer app
  IBOutlet NSButton*      mDoNotShowDialogCheckbox;    // checkbox to not show the no feed apps found dialog
  
  NSString*               mFeedURI;                    // holds the URL of the feed when the dialog is run
}

+(FeedServiceController*)sharedFeedServiceController;

-(IBAction)cancelOpenFeed:(id)sender;  
-(IBAction)openFeed:(id)sender;          
-(IBAction)closeSheetAndContinue:(id)sender;    
-(IBAction)selectFeedAppFromMenuItem:(id)sender;
-(IBAction)selectFeedAppFromButton:(id)sender;

-(void)showFeedWillOpenDialog:(NSWindow*)parent feedURI:(NSString*)inFeedURI;  
-(BOOL)feedAppsExist;

@end
