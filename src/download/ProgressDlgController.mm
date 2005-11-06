/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* ***** BEGIN LICENSE BLOCK *****
 * Version: MPL 1.1/GPL 2.0/LGPL 2.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Original Code is mozilla.org code.
 *
 * The Initial Developer of the Original Code is
 * Netscape Communications Corporation.
 * Portions created by the Initial Developer are Copyright (C) 2002
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *   Calum Robinson <calumr@mac.com>
 *   Josh Aas <josha@mac.com>
 *   Nick Kreeger <nick.kreeger@park.edu>
 *
 * Alternatively, the contents of this file may be used under the terms of
 * either the GNU General Public License Version 2 or later (the "GPL"), or
 * the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
 * in which case the provisions of the GPL or the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of either the GPL or the LGPL, and not to allow others to
 * use your version of this file under the terms of the MPL, indicate your
 * decision by deleting the provisions above and replace them with the notice
 * and other provisions required by the GPL or the LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the MPL, the GPL or the LGPL.
 *
 * ***** END LICENSE BLOCK ***** */

#include "nsNetError.h"

#import "NSString+Utils.h"
#import "NSView+Utils.h"

#import "ProgressDlgController.h"

#import "PreferenceManager.h"
#import "ProgressView.h"

static NSString* const kProgressWindowFrameSaveName = @"ProgressWindow";

@interface ProgressDlgController(PrivateProgressDlgController)

-(void)showErrorSheetForDownload:(id <CHDownloadProgressDisplay>)progressDisplay withStatus:(nsresult)inStatus;
-(void)rebuildViews;
-(NSMutableArray*)getSelectedProgressViewControllers;
-(void)deselectDLInstancesInArray:(NSArray*)instances;
-(void)makeDLInstanceVisibleIfItsNotAlready:(ProgressViewController*)controller;
-(void)killDownloadTimer;
-(void)setupDownloadTimer;
-(BOOL)shouldAllowCancelAction;
-(BOOL)shouldAllowRemoveAction;
-(BOOL)shouldAllowOpenAction;

@end

@implementation ProgressDlgController

static id gSharedProgressController = nil;

+(ProgressDlgController *)sharedDownloadController
{
  if (gSharedProgressController == nil) {
    gSharedProgressController = [[ProgressDlgController alloc] init];
  }
  
  return gSharedProgressController;
}

+(ProgressDlgController *)existingSharedDownloadController
{
  return gSharedProgressController;
}

-(id)init
{
  if ((self == [super initWithWindowNibName:@"ProgressDialog"])) {
    mProgressViewControllers = [[NSMutableArray alloc] init];
    mDefaultWindowSize = [[self window] frame].size;
    // it would be nice if we could get the frame from the name, and then
    // mess with it before setting it.
    [[self window] setFrameUsingName:kProgressWindowFrameSaveName];
    
    // We provide the views for the stack view, from mProgressViewControllers
    [mStackView setDataSource:self];
    mSelectionPivotIndex = -1;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(DLInstanceSelected:)
                                                 name:@"DownloadInstanceSelected" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(DLInstanceOpened:)
                                                 name:@"DownloadInstanceOpened" object:nil];
    
  }
  return self;
}

-(void)awakeFromNib
{
  NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier:@"dlmanager1"]; // so pause/resume button will show
  [toolbar setDelegate:self];
  [toolbar setAllowsUserCustomization:YES];
  [toolbar setAutosavesConfiguration:YES];
  [[self window] setToolbar:toolbar];    
  
  // load the saved instances to mProgressViewControllers array
  [self loadProgressViewControllers];
}

-(void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  if (self == gSharedProgressController) {
    gSharedProgressController = nil;
  }
  [mProgressViewControllers release];
  [self killDownloadTimer];
  [super dealloc];
}

// cancel all selected instances
-(IBAction)cancel:(id)sender
{
  NSMutableArray* selected = [self getSelectedProgressViewControllers];
  unsigned int count = [selected count];
  for (unsigned int i = 0; i < count; i++) {
    [[selected objectAtIndex:i] cancel:sender];
  }
}

// reveal all selected instances in the Finder
-(IBAction)reveal:(id)sender
{
  NSMutableArray* selected = [self getSelectedProgressViewControllers];
  unsigned int count = [selected count];
  for (unsigned int i = 0; i < count; i++) {
    [[selected objectAtIndex:i] reveal:sender];
  }
}

// open all selected instances
-(IBAction)open:(id)sender
{
  NSMutableArray* selected = [self getSelectedProgressViewControllers];
  unsigned int count = [selected count];
  for (unsigned int i = 0; i < count; i++) {
    [[selected objectAtIndex:i] open:sender];
  }
}

// remove all selected instances, don't remove anything that is active as a guard against bad things
-(IBAction)remove:(id)sender
{
  // take care of selecting a download instance to replace the selection being removed
  NSMutableArray* selected = [self getSelectedProgressViewControllers];
  unsigned int selectedCount = [selected count];
  unsigned int indexOfLastSelection = [mProgressViewControllers indexOfObject:[selected objectAtIndex:(((int)selectedCount) - 1)]];
  // if dl instance after last selection exists, select it or look for something else to select
  if ((indexOfLastSelection + 1) < [mProgressViewControllers count]) {
    [[((ProgressViewController*)[mProgressViewControllers objectAtIndex:(indexOfLastSelection + 1)]) view] setSelected:YES];
  }
  else { // find the first unselected DL instance before the last one marked for removal and select it
    // use an int in the loop, not unsigned because we might make it negative
    for (int i = ([mProgressViewControllers count] - 1); i >= 0; i--) {
	    if (![((ProgressViewController*)[mProgressViewControllers objectAtIndex:i]) isSelected]) {
          [[((ProgressViewController*)[mProgressViewControllers objectAtIndex:i]) view] setSelected:YES];
          break;
	    }
    }
  }
  mSelectionPivotIndex = -1; // nothing is selected any more so nothing to pivot on
  
  // now remove stuff
  for (unsigned int i = 0; i < selectedCount; i++) {
    if (![[selected objectAtIndex:i] isActive]) {
      [self removeDownload:[selected objectAtIndex:i]];
    }
  }
  
  [self rebuildViews];
  [self saveProgressViewControllers];
}

-(IBAction)pause:(id)sender
{
  NSMutableArray* selected = [self getSelectedProgressViewControllers];
  unsigned int count = [selected count];
  for (unsigned int i = 0; i < count; i++) 
  {
    [[selected objectAtIndex:i] pause:sender];
  }
  
  [self rebuildViews];
}

-(IBAction)resume:(id)sender
{
  NSMutableArray* selected = [self getSelectedProgressViewControllers];
  unsigned int count = [selected count];
  for (unsigned int i = 0; i < count; i++)
  {
    [[selected objectAtIndex:i] resume:sender];
  }
  
  [self rebuildViews];
}

// remove all inactive instances
-(IBAction)cleanUpDownloads:(id)sender
{
  for (unsigned int i = 0; i < [mProgressViewControllers count]; i++) {
    if ((![[mProgressViewControllers objectAtIndex:i] isActive]) || [[mProgressViewControllers objectAtIndex:i] isCanceled]) {
	    [self removeDownload:[mProgressViewControllers objectAtIndex:i]]; // remove the download
	    i--; // leave index at the same position because the dl there got removed
    }
  }
  mSelectionPivotIndex = -1;
  
  [self rebuildViews];
  [self saveProgressViewControllers];
}

// remove all downloads, cancelling if necessary
// this is used for the browser reset function
-(void)clearAllDownloads
{
  for (int i = [mProgressViewControllers count] - 1; i >= 0; i--) {
    // the ProgressViewController method "cancel:" has a sanity check, so its ok to call on anything
    // make sure downloads are not active before removing them
    [[mProgressViewControllers objectAtIndex:i] cancel:self];
    [self removeDownload:[mProgressViewControllers objectAtIndex:i]]; // remove the download
  }
  mSelectionPivotIndex = -1;
  
  [self rebuildViews];
  [self saveProgressViewControllers];
}

//
// -DLInstanceOpened:
// 
// Called when one of the ProgressView's should be opened (dbl clicked, for example). Open all of the
// selected instances with the Finder.
//
-(void)DLInstanceOpened:(NSNotification*)notification
{
  if ([self shouldAllowOpenAction])
    [self open:self];
}

// calculate what buttons should be enabled/disabled because the user changed the selection state
-(void)DLInstanceSelected:(NSNotification*)notification
{
  // make sure the notification object is the kind we want
  ProgressView* sender = ((ProgressView*)[notification object]);
  if (![sender isKindOfClass:[ProgressView class]])
    return;

  NSMutableArray* selectedArray = [self getSelectedProgressViewControllers];
  int lastMod = [sender lastModifier];

  // check for key modifiers and select more instances if appropriate
  // if its shift key, extend the selection one way or another
  // if its command key, just let the selection happen wherever it is (don't mess with it here)
  // if its not either clear all selections except the one that just happened
  if (lastMod == kNoKey) {
    // deselect everything
    [self deselectDLInstancesInArray:selectedArray];
    [sender setSelected:YES];
    mSelectionPivotIndex = [mProgressViewControllers indexOfObject:[sender getController]];
  }
  else if (lastMod == kCommandKey) {
    if (![sender isSelected]) {
      // if this was at the pivot index set the pivot index to -1
      if ([mProgressViewControllers indexOfObject:[sender getController]] == (unsigned int)mSelectionPivotIndex) {
        mSelectionPivotIndex = -1;
      }
    }
    else {
      if ([selectedArray count] == 1) {
        mSelectionPivotIndex = [mProgressViewControllers indexOfObject:[sender getController]];
      }
    }
  }
  else if (lastMod == kShiftKey) {
    if (mSelectionPivotIndex == -1) {
      mSelectionPivotIndex = [mProgressViewControllers indexOfObject:[sender getController]];
    }
    else { 
      if ([selectedArray count] == 1) {
          mSelectionPivotIndex = [mProgressViewControllers indexOfObject:[sender getController]];
      }
      else {
        int senderLocation = [mProgressViewControllers indexOfObject:[sender getController]];
        // deselect everything
        [self deselectDLInstancesInArray:selectedArray];
        if (senderLocation <= mSelectionPivotIndex) {
          for (int i = senderLocation; i <= mSelectionPivotIndex; i++) {
            [[((ProgressViewController*)[mProgressViewControllers objectAtIndex:i]) view] setSelected:YES];
          }
        }
        else if (senderLocation > mSelectionPivotIndex) {
          for (int i = mSelectionPivotIndex; i <= senderLocation; i++) {
            [[((ProgressViewController*)[mProgressViewControllers objectAtIndex:i]) view] setSelected:YES];
          }
        }
      }
    }
  }
}

-(void)keyDown:(NSEvent *)theEvent
{
  // we don't care about anything if no downloads exist
  if ([mProgressViewControllers count] > 0) {
    int key = [[theEvent characters] characterAtIndex:0];
    int instanceToSelect = -1;
    unsigned int mods = [theEvent modifierFlags];
    if (key == NSUpArrowFunctionKey) { // was it the up arrow key that got pressed?
      // find the first selected item
      int i; // we use this outside the loop so declare it here
      for (i = 0; i < (int)[mProgressViewControllers count]; i++) {
        if ([[mProgressViewControllers objectAtIndex:i] isSelected]) {
          break;
        }
      }      
      // deselect everything if the shift key isn't a modifier
      if (!(mods & NSShiftKeyMask)) {
        [self deselectDLInstancesInArray:[self getSelectedProgressViewControllers]];
      }
      if (i == (int)[mProgressViewControllers count]) { // if nothing was selected select the first item
        instanceToSelect = 0;
      }
      else if (i == 0) { // if selection was already at the top leave it there
        instanceToSelect = 0;
      }
      else { // select the next highest instance
        instanceToSelect = i - 1;
      }
      // select and make sure its visible
      if (instanceToSelect != -1) {
        [[((ProgressViewController*)[mProgressViewControllers objectAtIndex:instanceToSelect]) view] setSelected:YES];
        [self makeDLInstanceVisibleIfItsNotAlready:((ProgressViewController*)[mProgressViewControllers objectAtIndex:instanceToSelect])];
        if (!(mods & NSShiftKeyMask)) {
          mSelectionPivotIndex = instanceToSelect;
        }
      }
    }
    else if (key == NSDownArrowFunctionKey) { // was it the down arrow key that got pressed?
      // find the last selected item
      int i; // we use this outside the coming loop so declare it here
      for (i = [mProgressViewControllers count] - 1; i >= 0 ; i--) {
        if ([[mProgressViewControllers objectAtIndex:i] isSelected]) {
          break;
        }
      }
      // deselect everything if the shift key isn't a modifier
      if (!(mods & NSShiftKeyMask)) {
        [self deselectDLInstancesInArray:[self getSelectedProgressViewControllers]];
      }
      if (i < 0) { // if nothing was selected select the first item
        instanceToSelect = ([mProgressViewControllers count] - 1);
      }
      else if (i == ((int)[mProgressViewControllers count] - 1)) { // if selection was already at the bottom leave it there
        instanceToSelect = ([mProgressViewControllers count] - 1);
      }
      else { // select the next lowest instance
        instanceToSelect = i + 1;
      }
      if (instanceToSelect != -1) {
        [[((ProgressViewController*)[mProgressViewControllers objectAtIndex:instanceToSelect]) view] setSelected:YES];
        [self makeDLInstanceVisibleIfItsNotAlready:((ProgressViewController*)[mProgressViewControllers objectAtIndex:instanceToSelect])];
        if (!(mods & NSShiftKeyMask)) {
          mSelectionPivotIndex = instanceToSelect;
        }
      }
    }
    else if (key == (int)'\177') { // delete key - remove all selected items unless an active one is selected
      NSMutableArray *selected = [self getSelectedProgressViewControllers];
      BOOL activeFound = NO;
      for (unsigned i = 0; i < [selected count]; i++) {
        if ([[selected objectAtIndex:i] isActive]) {
          activeFound = YES;
          break;
        }
      }
      if (activeFound) {
        NSBeep();
      }
      else {
        [self remove:self];
      }
    }
    else if (key == NSPageUpFunctionKey) {
      if ([mProgressViewControllers count] > 0) {
        // make the first instance completely visible
        [self makeDLInstanceVisibleIfItsNotAlready:((ProgressViewController*)[mProgressViewControllers objectAtIndex:0])];
      }
    }
    else if (key == NSPageDownFunctionKey) {
      if ([mProgressViewControllers count] > 0) {
        // make the last instance completely visible
        [self makeDLInstanceVisibleIfItsNotAlready:((ProgressViewController*)[mProgressViewControllers lastObject])];
      }
    }
    else { // ignore any other keys
      NSBeep();
    }
  }
  else {
    NSBeep();
  }
}

-(void)deselectDLInstancesInArray:(NSArray*)instances
{
  unsigned count = [instances count];
  for (unsigned i = 0; i < count; i++) {
    [[((ProgressViewController*)[instances objectAtIndex:i]) view] setSelected:NO];
  }
}

// return a mutable array with instance in order top-down
-(NSMutableArray*)getSelectedProgressViewControllers
{
  NSMutableArray *selectedArray = [[NSMutableArray alloc] init];
  unsigned selectedCount = [mProgressViewControllers count];
  for (unsigned i = 0; i < selectedCount; i++) {
    if ([[mProgressViewControllers objectAtIndex:i] isSelected]) {
	    // insert at zero so they're in order to-down
	    [selectedArray addObject:[mProgressViewControllers objectAtIndex:i]];
    }
  }
  [selectedArray autorelease];
  return selectedArray;
}

-(void)makeDLInstanceVisibleIfItsNotAlready:(ProgressViewController*)controller
{
  NSRect instanceFrame = [[controller view] frame];
  NSRect visibleRect = [[mScrollView contentView] documentVisibleRect];
  // for some reason there is a 1 pixel discrepancy we need to get rid of here
  instanceFrame.size.width -= 1;
  // NSLog([NSString stringWithFormat:@"Instance Frame: %@", NSStringFromRect(instanceFrame)]);
  // NSLog([NSString stringWithFormat:@"Visible Rect: %@", NSStringFromRect(visibleRect)]);
  if (!NSContainsRect(visibleRect, instanceFrame)) { // if instance isn't completely visible
    if (instanceFrame.origin.y < visibleRect.origin.y) { // if the dl instance is at least partly above visible rect
      // just go to the instance's frame origin point
      [[mScrollView contentView] scrollToPoint:instanceFrame.origin];
    }
    else { // if the dl instance is at least partly below visible rect
      // take  instance's frame origin y, subtract content view height, 
      // add instance view height, no parenthesizing
      NSPoint adjustedPoint = NSMakePoint(0,(instanceFrame.origin.y - [[mScrollView contentView] frame].size.height) + instanceFrame.size.height);
      [[mScrollView contentView] scrollToPoint:adjustedPoint];
    }
    [mScrollView reflectScrolledClipView:[mScrollView contentView]];
  }
}

-(void)didStartDownload:(id <CHDownloadProgressDisplay>)progressDisplay
{
  if (![[self window] isVisible]) {
    [self showWindow:nil]; // make sure the window is visible
  }
  
  [self rebuildViews];
  [self setupDownloadTimer];
  
  // downloads should be individually selected when initiated
  [self deselectDLInstancesInArray:[self getSelectedProgressViewControllers]];
  [[((ProgressViewController*)progressDisplay) view] setSelected:YES];
  
  // make sure new download is visible
  [self makeDLInstanceVisibleIfItsNotAlready:progressDisplay];
}

-(void)didEndDownload:(id <CHDownloadProgressDisplay>)progressDisplay withSuccess:(BOOL)completedOK statusCode:(nsresult)status
{
  [self rebuildViews]; // to swap in the completed view
  [[[self window] toolbar] validateVisibleItems]; // force update which doesn't always happen

  // close the window if user has set pref to close when all downloads complete
  if (completedOK)
  {
    BOOL gotPref;
    BOOL keepDownloadsOpen = [[PreferenceManager sharedInstance] getBooleanPref:"browser.download.progressDnldDialog.keepAlive" withSuccess:&gotPref];
    if (!keepDownloadsOpen && ([self numDownloadsInProgress] == 0))
    {
      [self close];   // don't call -performClose: on the window, because we don't want Cocoa to look
                      // for the option key and try to close all windows
    }
  }
  else if (NS_FAILED(status) && status != NS_BINDING_ABORTED)  // if it's an error, and not just canceled, show sheet
  {
    [self showErrorSheetForDownload:progressDisplay withStatus:status];
  }
  
  [self saveProgressViewControllers];
}

-(void)showErrorSheetForDownload:(id <CHDownloadProgressDisplay>)progressDisplay withStatus:(nsresult)inStatus
{
  NSString* errorMsgFmt = NSLocalizedString(@"DownloadErrorMsgFmt", @"");
  NSString* errorExplString = nil;
  
  NSString* destFilePath = [progressDisplay destinationPath];
  NSString* fileName = [destFilePath displayNameOfLastPathComponent];
  
  NSString* errorMsg = [NSString stringWithFormat:errorMsgFmt, fileName];

  switch (inStatus)
  {
    case NS_ERROR_FILE_DISK_FULL:
    case NS_ERROR_FILE_NO_DEVICE_SPACE:
      {
        NSString* fmtString = NSLocalizedString(@"DownloadErrorNoDiskSpaceOnVolumeFmt", @"");
        errorExplString = [NSString stringWithFormat:fmtString, [destFilePath volumeNamePathComponent]];
      }
      break;
      
    case NS_ERROR_FILE_ACCESS_DENIED:
      {
        NSString* fmtString = NSLocalizedString(@"DownloadErrorDestinationWriteProtectedFmt", @"");
        NSString* destDirPath = [destFilePath stringByDeletingLastPathComponent];
        errorExplString = [NSString stringWithFormat:fmtString, [destDirPath displayNameOfLastPathComponent]];
      }
      break;

    case NS_ERROR_FILE_TOO_BIG:
    case NS_ERROR_FILE_READ_ONLY:
    default:
      {
        errorExplString = NSLocalizedString(@"DownloadErrorOther", @"");
        NSLog(@"Download failure code: %X", inStatus);
      }
      break;
  }
  
  NSBeginAlertSheet(errorMsg,
                    nil,    // default button ("OK")
                    nil,    // alt button (none)
                    nil,    // other button (nil)
                    [self window],
                    self,
                    @selector(downloadErrorSheetDidEnd:returnCode:contextInfo:),
                    nil,    // didDismissSelector
                    NULL,   // context info
                    errorExplString);
}

-(void)downloadErrorSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
}

-(void)removeDownload:(id <CHDownloadProgressDisplay>)progressDisplay
{
  [mProgressViewControllers removeObject:progressDisplay];
  
  if ([mProgressViewControllers count] == 0) {
    // Stop doing stuff if there aren't any downloads going on
    [self killDownloadTimer];
  }
}

-(void)rebuildViews
{
  [mStackView reloadSubviews];
}

-(int)numDownloadsInProgress
{
  unsigned numViews = [mProgressViewControllers count];
  int numActive = 0;
  
  for (unsigned int i = 0; i < numViews; i++) {
    if ([[mProgressViewControllers objectAtIndex:i] isActive]) {
      ++numActive;
    }
  }
  return numActive;
}

-(void)autosaveWindowFrame
{
  [[self window] saveFrameUsingName:kProgressWindowFrameSaveName];
}

-(void)windowWillClose:(NSNotification *)notification
{
  [self autosaveWindowFrame];
}

-(void)killDownloadTimer
{
  if (mDownloadTimer) {
    [mDownloadTimer invalidate];
    [mDownloadTimer release];
    mDownloadTimer = nil;
  }
}

// Called by our timer to refresh all the download stats
- (void)setDownloadProgress:(NSTimer *)aTimer
{
  [mProgressViewControllers makeObjectsPerformSelector:@selector(refreshDownloadInfo)];
}

- (void)setupDownloadTimer
{
  [self killDownloadTimer];
  // note that this sets up a retain cycle between |self| and the timer,
  // which has to be broken out of band, before we'll be dealloc'd.
  mDownloadTimer = [[NSTimer scheduledTimerWithTimeInterval:1.0
                                                     target:self
                                                   selector:@selector(setDownloadProgress:)
                                                   userInfo:nil
                                                    repeats:YES] retain];
  // make sure it fires even when the mouse is down
  [[NSRunLoop currentRunLoop] addTimer:mDownloadTimer forMode:NSEventTrackingRunLoopMode];
}

-(NSApplicationTerminateReply)allowTerminate
{
  if ([self numDownloadsInProgress] > 0) {
    // make sure the window is visible
    [self showWindow:self];
    
    NSString *alert     = NSLocalizedString(@"QuitWithDownloadsMsg", nil);
    NSString *message   = NSLocalizedString(@"QuitWithDownloadsExpl", nil);
    NSString *okButton  = NSLocalizedString(@"QuitWithdownloadsButtonDefault", nil);
    NSString *altButton = NSLocalizedString(@"QuitButtonText", nil);
    
    // while the panel is up, download dialogs won't update (no timers firing) but
    // downloads continue (PLEvents being processed)
    id panel = NSGetAlertPanel(alert, message, okButton, altButton, nil, message);
    
    [NSApp beginSheet:panel
            modalForWindow:[self window]
            modalDelegate:self
            didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
            contextInfo:NULL];
    int sheetResult = [NSApp runModalForWindow: panel];
    [NSApp endSheet: panel];
    [panel orderOut: self];
    NSReleaseAlertPanel(panel);
    
    if (sheetResult == NSAlertDefaultReturn)
      return NSTerminateCancel;
    
    else {
      // need to save here because downloads that were downloading aren't 
      // cancelled just terminated.
      [self saveProgressViewControllers];
      
      return NSTerminateNow;
    }
  }
  
  return NSTerminateNow;
}

-(void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
  [NSApp stopModalWithCode:returnCode];
}

-(void)saveProgressViewControllers
{
  unsigned int arraySize = [mProgressViewControllers count];
  NSMutableArray* downloadArray = [[[NSMutableArray alloc] initWithCapacity:arraySize] autorelease];
  
  NSEnumerator* downloadsEnum = [mProgressViewControllers objectEnumerator];
  ProgressViewController* curController;
  while ((curController = [downloadsEnum nextObject]))
  {
    [downloadArray addObject:[curController downloadInfoDictionary]]; 
  }
  
  // now save
  NSString *profileDir = [[PreferenceManager sharedInstance] newProfilePath];
  [downloadArray writeToFile: [profileDir stringByAppendingPathComponent:@"downloads.plist"] atomically: YES];
}

-(void)loadProgressViewControllers
{
  NSString* downloadsPath = [[[PreferenceManager sharedInstance] newProfilePath] stringByAppendingPathComponent:@"downloads.plist"];
  NSArray*  downloads     = [NSArray arrayWithContentsOfFile:downloadsPath];
  
  if (downloads)
  {
    NSEnumerator* downloadsEnum = [downloads objectEnumerator];
    NSDictionary* downloadsDictionary;
    while((downloadsDictionary = [downloadsEnum nextObject]))
    {
      ProgressViewController* curController = [[ProgressViewController alloc] initWithDictionary:downloadsDictionary];
      [mProgressViewControllers addObject:curController];
    }
    
    [self rebuildViews];
  }
}

-(BOOL)shouldAllowCancelAction
{
  NSMutableArray* selectedArray = [self getSelectedProgressViewControllers];
  unsigned int selectedCount = [selectedArray count];
  // if no selections are inactive or canceled then allow cancel
  for (unsigned int i = 0; i < selectedCount; i++) {
    if ((![[selectedArray objectAtIndex:i] isActive]) || [[selectedArray objectAtIndex:i] isCanceled]) {
      return NO;
    }
  }
  return [[self window] isKeyWindow]; // disable if not key window
}

-(BOOL)shouldAllowRemoveAction
{
  NSMutableArray* selectedArray = [self getSelectedProgressViewControllers];
  unsigned int selectedCount = [selectedArray count];
  // if no selections are active then allow remove
  for (unsigned int i = 0; i < selectedCount; i++) {
    if ([[selectedArray objectAtIndex:i] isActive]) {
      return NO;
    }
  }
  return [[self window] isKeyWindow];
}

-(BOOL)shouldAllowOpenAction
{
  NSMutableArray* selectedArray = [self getSelectedProgressViewControllers];
  unsigned int selectedCount = [selectedArray count];
  // if no selections are are active or canceled then allow open
  for (unsigned int i = 0; i < selectedCount; i++) {
    if ([[selectedArray objectAtIndex:i] isActive] || [[selectedArray objectAtIndex:i] isCanceled]) {
      return NO;
    }
  }
  return YES;
}

- (BOOL)shouldAllowPauseAction
{
  NSMutableArray* selectedArray = [self getSelectedProgressViewControllers];
  unsigned int selectedCount = [selectedArray count];
  // if no selections are paused, allow the pause
  for (unsigned int i = 0; i < selectedCount; i++) {
    if ([[selectedArray objectAtIndex:i] isPaused] || ![[selectedArray objectAtIndex:i] isActive]) {
      return NO;
    }
  }
  
  return YES;
}

-(BOOL)shouldAllowResumeAction
{
  NSMutableArray* selectedArray = [self getSelectedProgressViewControllers];
  unsigned int selectedCount = [selectedArray count];
  // if no selections are paused, allow the pause
  for (unsigned int i = 0; i < selectedCount; i++) {
    if (![[selectedArray objectAtIndex:i] isPaused] || ![[selectedArray objectAtIndex:i] isActive]) {
      return NO;
    }
  }
  
  return YES;
}

-(BOOL)validateMenuItem:(id <NSMenuItem>)menuItem
{
  SEL action = [menuItem action];
  if (action == @selector(cancel:)) {
    return [self shouldAllowCancelAction];
  }
  else if (action == @selector(remove:)) {
    return [self shouldAllowRemoveAction];
  }
  else if (action == @selector(open:)) {
    return [self shouldAllowOpenAction];
  }
  else if (action == @selector(pause:)) {
    return [self shouldAllowPauseAction];
  }
  else if (action == @selector(resume:)) {
    return [self shouldAllowResumeAction];
  }
  return YES;
}


- (BOOL)setPauseResumeToolbarItem:(NSToolbarItem*)theItem
{
  if ([self shouldAllowPauseAction]) {
    [theItem setToolTip:NSLocalizedString(@"dlPauseButtonTooltip", nil)];
    [theItem setLabel:NSLocalizedString(@"dlPauseButtonLabel", nil)];
    [theItem setPaletteLabel:NSLocalizedString(@"dlPauseButtonLabel", nil)];
    [theItem setAction:@selector(pause:)];
    [theItem setImage:[NSImage imageNamed:@"dl_pause.tif"]];
    
    return [[self window] isKeyWindow]; // if not key window, dont enable
  }
  else if ([self shouldAllowResumeAction]) {
    [theItem setToolTip:NSLocalizedString(@"dlResumeButtonTooltip", nil)];
    [theItem setLabel:NSLocalizedString(@"dlResumeButtonLabel", nil)];
    [theItem setPaletteLabel:NSLocalizedString(@"dlResumeButtonLabel", nil)];
    [theItem setAction:@selector(resume:)];
    [theItem setImage:[NSImage imageNamed:@"dl_resume.tif"]];
    
    return [[self window] isKeyWindow]; // if not key window, dont enable
  }
  else {
    return NO;
  }
}

-(BOOL)validateToolbarItem:(NSToolbarItem *)theItem
{
  SEL action = [theItem action];
  
  // return true if the action is validating showWindow:
  // you can always do that from the toolbar
  if (action == @selector(showWindow:))
    return YES;
  
  // validate items not dependent on the current selection
  if (action == @selector(cleanUpDownloads:)) {
    unsigned pcControllersCount = [mProgressViewControllers count];
    for (unsigned i = 0; i < pcControllersCount; i++) {
      if ((![[mProgressViewControllers objectAtIndex:i] isActive]) ||
          [[mProgressViewControllers objectAtIndex:i] isCanceled]) {
        return YES;
      }
    }
    return NO;
  }
  
  // validate items that depend on current selection
  if ([[self getSelectedProgressViewControllers] count] == 0) {
    return NO;
  }
  else if (action == @selector(remove:)) {
	  return [self shouldAllowRemoveAction];
  }
  else if (action == @selector(open:)) {
    return [self shouldAllowOpenAction];
  }
  else if (action == @selector(cancel:)) {
    return [self shouldAllowCancelAction];
  }
  else if (action == @selector(pause:) || action == @selector(resume:)) {
    return [self setPauseResumeToolbarItem:theItem];
  }
  
  return YES;
}

-(NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
  NSToolbarItem *theItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
  [theItem setTarget:self];
  [theItem setEnabled:NO];
  if ([itemIdentifier isEqualToString:@"removebutton"]) {
    [theItem setToolTip:NSLocalizedString(@"dlRemoveButtonTooltip", nil)];
    [theItem setLabel:NSLocalizedString(@"dlRemoveButtonLabel", nil)];
    [theItem setPaletteLabel:NSLocalizedString(@"dlRemoveButtonLabel", nil)];
    [theItem setAction:@selector(remove:)];
    [theItem setImage:[NSImage imageNamed:@"dl_remove.tif"]];
  }
  else if ([itemIdentifier isEqualToString:@"cancelbutton"]) {
    [theItem setToolTip:NSLocalizedString(@"dlCancelButtonTooltip", nil)];
    [theItem setLabel:NSLocalizedString(@"dlCancelButtonLabel", nil)];
    [theItem setPaletteLabel:NSLocalizedString(@"dlCancelButtonLabel", nil)];
    [theItem setAction:@selector(cancel:)];
    [theItem setImage:[NSImage imageNamed:@"dl_cancel.tif"]];
  }
  else if ([itemIdentifier isEqualToString:@"revealbutton"]) {
    [theItem setToolTip:NSLocalizedString(@"dlRevealButtonTooltip", nil)];
    [theItem setLabel:NSLocalizedString(@"dlRevealButtonLabel", nil)];
    [theItem setPaletteLabel:NSLocalizedString(@"dlRevealButtonLabel", nil)];
    [theItem setAction:@selector(reveal:)];
    [theItem setImage:[NSImage imageNamed:@"dl_reveal.tif"]];
  }
  else if ([itemIdentifier isEqualToString:@"openbutton"]) {
    [theItem setToolTip:NSLocalizedString(@"dlOpenButtonTooltip", nil)];
    [theItem setLabel:NSLocalizedString(@"dlOpenButtonLabel", nil)];
    [theItem setPaletteLabel:NSLocalizedString(@"dlOpenButtonLabel", nil)];
    [theItem setAction:@selector(open:)];
    [theItem setImage:[NSImage imageNamed:@"dl_open.tif"]];
  }
  else if ([itemIdentifier isEqualToString:@"cleanupbutton"]) {
    [theItem setToolTip:NSLocalizedString(@"dlCleanUpButtonTooltip", nil)];
    [theItem setLabel:NSLocalizedString(@"dlCleanUpButtonLabel", nil)];
    [theItem setPaletteLabel:NSLocalizedString(@"dlCleanUpButtonLabel", nil)];
    [theItem setAction:@selector(cleanUpDownloads:)];
    [theItem setImage:[NSImage imageNamed:@"dl_clearall.tif"]];
  }
  else if ([itemIdentifier isEqualToString:@"pauseresumebutton"]) {
    [self setPauseResumeToolbarItem:theItem];
  }
  else {
    return nil;
  }
  return theItem;
}

-(NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
  return [NSArray arrayWithObjects:@"removebutton", @"cleanupbutton", @"cancelbutton", @"pauseresumebutton", @"openbutton", @"revealbutton", NSToolbarFlexibleSpaceItemIdentifier, nil];
}

-(NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
  return [NSArray arrayWithObjects:@"cleanupbutton", @"removebutton", @"cancelbutton", @"pauseresumebutton", @"openbutton", NSToolbarFlexibleSpaceItemIdentifier, @"revealbutton", nil];
}

#pragma mark -

// zoom to fit contents, but don't go under minimum size
-(NSRect)windowWillUseStandardFrame:(NSWindow *)sender defaultFrame:(NSRect)defaultFrame
{
  NSRect windowFrame = [[self window] frame];
  NSSize curScrollFrameSize = [mScrollView frame].size;
  NSSize scrollFrameSize = [NSScrollView frameSizeForContentSize:[mStackView bounds].size
                                         hasHorizontalScroller:NO hasVerticalScroller:YES borderType:NSNoBorder];
  float frameDelta = (curScrollFrameSize.height - scrollFrameSize.height);
  
  // don't get vertically smaller than the default window size
  if ((windowFrame.size.height - frameDelta) < mDefaultWindowSize.height) {
    frameDelta = windowFrame.size.height - mDefaultWindowSize.height;
  }
  
  windowFrame.size.height -= frameDelta;
  windowFrame.origin.y    += frameDelta; // maintain top
  windowFrame.size.width  = mDefaultWindowSize.width;
  
  // cocoa will ensure that the window fits onscreen for us
	return windowFrame;
}

#pragma mark -

/*
 CHStackView datasource methods
 */

-(int)subviewsForStackView:(CHStackView *)stackView
{
  return [mProgressViewControllers count];
}

-(NSView *)viewForStackView:(CHStackView *)aResizingView atIndex:(int)index
{
  return [((ProgressViewController*)[mProgressViewControllers objectAtIndex:index]) view];
}

#pragma mark -

/*
 Just create a progress view, but don't display it (otherwise the URL fields etc. 
                                                    are just blank)
 */
-(id <CHDownloadProgressDisplay>)createProgressDisplay
{
  ProgressViewController *newController = [[[ProgressViewController alloc] init] autorelease];
  [newController setProgressWindowController:self];
  [mProgressViewControllers addObject:newController];
  
  return newController;
}

@end
