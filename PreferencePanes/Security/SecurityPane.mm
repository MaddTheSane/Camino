/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "SecurityPane.h"

#import "CHCertificateOverrideManager.h"
#import "ExtendedTableView.h"
#import "GeckoPrefConstants.h"

// prefs for showing security dialogs
#define LEAVE_SITE_PREF      "security.warn_leaving_secure"
#define MIXEDCONTENT_PREF    "security.warn_viewing_mixed"

const unsigned int kSelectAutomaticallyMatrixRowValue = 0;
const unsigned int kAskEveryTimeMatrixRowValue        = 1;

static NSString* const kOverrideHostKey = @"host";
static NSString* const kOverridePortKey = @"port";


@interface OrgMozillaCaminoPreferenceSecurity(Private)
// Loads the list of stored certificate overrides into mOverrides.
- (void)loadOverrides;
@end

@implementation OrgMozillaCaminoPreferenceSecurity

- (void)dealloc
{
  [mOverrides release];

  [super dealloc];
}

- (void)updateButtons
{
  // Set initial value on Security checkboxes
  BOOL phishingCheckingEnabled = [self getBooleanPref:kGeckoPrefSafeBrowsingPhishingCheckingEnabled 
                                          withSuccess:NULL];
  BOOL malwareCheckingEnabled = [self getBooleanPref:kGeckoPrefSafeBrowsingMalwareCheckingEnabled 
                                         withSuccess:NULL];
  if (phishingCheckingEnabled && malwareCheckingEnabled)
    [mSafeBrowsing setState:NSOnState];
  else if (phishingCheckingEnabled || malwareCheckingEnabled)
    [mSafeBrowsing setState:NSMixedState];
  else
    [mSafeBrowsing setState:NSOffState];

  BOOL leaveEncrypted = [self getBooleanPref:LEAVE_SITE_PREF withSuccess:NULL];
  [mLeaveEncrypted setState:(leaveEncrypted ? NSOnState : NSOffState)];

  BOOL viewMixed = [self getBooleanPref:MIXEDCONTENT_PREF withSuccess:NULL];
  [mViewMixed setState:(viewMixed ? NSOnState : NSOffState)];

  BOOL gotPref;
  NSString* certificateBehavior = [self getStringPref:kGeckoPrefDefaultCertificateBehavior
                                          withSuccess:&gotPref];
  if (gotPref) {
    if ([certificateBehavior isEqual:kPersonalCertificateSelectAutomatically])
      [mCertificateBehavior selectCellAtRow:kSelectAutomaticallyMatrixRowValue column:0];
    else if ([certificateBehavior isEqual:kPersonalCertificateAlwaysAsk])
      [mCertificateBehavior selectCellAtRow:kAskEveryTimeMatrixRowValue column:0];
  }
}

- (void)willSelect
{
  [self updateButtons];
}

- (void)didActivate
{
  [self updateButtons];
}

//
// clickEnableViewMixed:
// clickEnableLeaveEncrypted:
//
// Set prefs for warnings/alerts wrt secure sites.
//

- (IBAction)clickEnableViewMixed:(id)sender
{
  [self setPref:MIXEDCONTENT_PREF toBoolean:[sender state] == NSOnState];
}

- (IBAction)clickEnableLeaveEncrypted:(id)sender
{
  [self setPref:LEAVE_SITE_PREF toBoolean:[sender state] == NSOnState];
}

- (IBAction)clickCertificateSelectionBehavior:(id)sender
{
  unsigned int row = [mCertificateBehavior selectedRow];

  if (row == kSelectAutomaticallyMatrixRowValue)
    [self setPref:kGeckoPrefDefaultCertificateBehavior toString:kPersonalCertificateSelectAutomatically];
  else // row == kAskEveryTimeMatrixRowValue
    [self setPref:kGeckoPrefDefaultCertificateBehavior toString:kPersonalCertificateAlwaysAsk];
}

- (IBAction)showCertificates:(id)sender
{
  // We'll just fire off a notification and let the application show the UI.
  NSDictionary* userInfoDict = [NSDictionary dictionaryWithObject:[mLeaveEncrypted window]  // any view's window
                                                           forKey:@"parent_window"];
  [[NSNotificationCenter defaultCenter] postNotificationName:@"ShowCertificatesNotification"
                                                      object:nil
                                                    userInfo:userInfoDict];
}

- (IBAction)clickSafeBrowsing:(id)sender
{
  // The safe browsing button allows mixed state, since the underlying prefs are 
  // actually independent, but we only want this button to enable or disable
  // safe browsing in its entirety.
  if ([sender state] == NSMixedState)
    [sender setState:NSOnState];

  [self setPref:kGeckoPrefSafeBrowsingPhishingCheckingEnabled
      toBoolean:[sender state] == NSOnState];

  [self setPref:kGeckoPrefSafeBrowsingMalwareCheckingEnabled
      toBoolean:[sender state] == NSOnState];
}

#pragma mark -
#pragma mark Certificate Overrides Sheet

- (IBAction)editOverrides:(id)aSender
{
  [self loadOverrides];

  [mOverridesTable setDeleteAction:@selector(removeOverrides:)];
  [mOverridesTable setTarget:self];

  // bring up sheet
  [NSApp beginSheet:mOverridePanel
     modalForWindow:[aSender window]
      modalDelegate:self
     didEndSelector:NULL
        contextInfo:NULL];
}

- (IBAction)editOverridesDone:(id)aSender
{
  [mOverridePanel orderOut:self];
  [NSApp endSheet:mOverridePanel];

  [mOverrides release];
  mOverrides = nil;
}

- (void)loadOverrides
{
  CHCertificateOverrideManager* overrideManager =
    [CHCertificateOverrideManager certificateOverrideManager];
  NSArray* hostPortOverrides = [overrideManager overrideHosts];

  NSMutableArray* overrides =
    [NSMutableArray arrayWithCapacity:[hostPortOverrides count]];
  NSEnumerator* hostPortEnumerator = [hostPortOverrides objectEnumerator];
  NSString* hostPort;
  while ((hostPort = [hostPortEnumerator nextObject])) {
    // Entries should be "host:port"; split them apart and sanity check.
    NSArray* components = [hostPort componentsSeparatedByString:@":"];
    if ([components count] != 2)
      continue;
    [overrides addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                           [components objectAtIndex:0], kOverrideHostKey,
                           [components objectAtIndex:1], kOverridePortKey,
                           nil]];
  }

  NSSortDescriptor* initialSort =
    [[[NSSortDescriptor alloc] initWithKey:@"host"
                                 ascending:YES] autorelease];
  [self willChangeValueForKey:@"mOverrides"];
  [mOverrides autorelease];
  mOverrides = [overrides retain];
  [mOverrides sortUsingDescriptors:[NSArray arrayWithObject:initialSort]];
  [self didChangeValueForKey:@"mOverrides"];
}

- (IBAction)removeOverrides:(id)aSender
{
  CHCertificateOverrideManager* overrideManager =
    [CHCertificateOverrideManager certificateOverrideManager];

  // Walk the selected rows, removing overrides.
  NSArray* selectedOverrides = [mOverridesController selectedObjects];
  NSEnumerator* overrideEnumerator = [selectedOverrides objectEnumerator];
  NSDictionary* override;
  while ((override = [overrideEnumerator nextObject])) {
    [overrideManager removeOverrideForHost:[override objectForKey:kOverrideHostKey]
                                      port:[[override objectForKey:kOverridePortKey] intValue]];
  }
  [mOverridesController removeObjects:selectedOverrides];
}

- (IBAction)removeAllOverrides:(id)aSender
{
  NSAlert* removeAllAlert = [[[NSAlert alloc] init] autorelease];
  [removeAllAlert setMessageText:[self localizedStringForKey:@"RemoveAllSecurityExceptionsWarningTitle"]];
  [removeAllAlert setInformativeText:[self localizedStringForKey:@"RemoveAllSecurityExceptionsWarning"]];
  [removeAllAlert addButtonWithTitle:[self localizedStringForKey:@"RemoveAllExceptionsButtonText"]];
  NSButton* dontRemoveButton = [removeAllAlert addButtonWithTitle:[self localizedStringForKey:@"DontRemoveButtonText"]];
  [dontRemoveButton setKeyEquivalent:@"\e"]; // escape
  
  [removeAllAlert setAlertStyle:NSCriticalAlertStyle];
  
  if ([removeAllAlert runModal] == NSAlertFirstButtonReturn) {
    NSRange fullRange = NSMakeRange(0, [mOverrides count]);
    NSIndexSet* allIndexes = [NSIndexSet indexSetWithIndexesInRange:fullRange];
    [mOverridesController setSelectionIndexes:allIndexes];
    [self removeOverrides:aSender];
  }
}

@end
