/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "AppListMenuFactory.h"
#import "NSWorkspace+Utils.h"

// Xcode 2.x's ld dead-strips this symbol.  Xcode 3.0's ld is fine.
asm(".no_dead_strip .objc_class_name_AppListMenuFactory");

__attribute__((used)) NSString* const kUserChosenBrowserUserDefaultsKey = @"UserChosenBrowsers";
__attribute__((used)) NSString* const kUserChosenFeedViewerUserDefaultsKey = @"UserChosenFeedViewer";
__attribute__((used)) NSString* const kDefaultFeedViewerChanged = @"DefaultFeedViewerChanged";

@interface AppListMenuFactory(Private)

-(NSArray*)webBrowsersList;
-(NSArray*)feedAppsList;
-(NSMenuItem*)menuItemForAppURL:(NSURL*)inURL 
                   withBundleID:(NSString*)inBundleID 
                      andAction:(SEL)inAction
                      andTarget:(id)inTarget;

@end

//
// CompareBundleIDAppDisplayNames()
//
// This is for sorting the web browser bundle ID list by display name.
//
static int CompareBundleIDAppDisplayNames(id a, id b, void *context)
{
  NSURL* appURLa = nil;
  NSURL* appURLb = nil;
  
  if ((LSFindApplicationForInfo(kLSUnknownCreator, (CFStringRef)a, NULL, NULL, (CFURLRef*)&appURLa) == noErr) &&
      (LSFindApplicationForInfo(kLSUnknownCreator, (CFStringRef)b, NULL, NULL, (CFURLRef*)&appURLb) == noErr))
  {
    NSString *aName = [[NSWorkspace sharedWorkspace] displayNameForFile:appURLa];
    NSString *bName = [[NSWorkspace sharedWorkspace] displayNameForFile:appURLb];
    
    [appURLa release];
    [appURLb release];
    
    if (aName && bName)
      return [aName compare:bName];
  }
  
  // this shouldn't ever happen, and if it does we handle it correctly when building the menu.
  // there is no way to flag an error condition here and the sort fuctions return void
  return NSOrderedSame;
}

@implementation AppListMenuFactory

static AppListMenuFactory* sAppListMenuFactoryInstance = nil;

//
// +sharedFeedMenuFactory:
//
// Return the shared static instance of AppListMenuFactory.
//
+(AppListMenuFactory*)sharedAppListMenuFactory
{
  return sAppListMenuFactoryInstance ? sAppListMenuFactoryInstance : sAppListMenuFactoryInstance = [[self alloc] init];
}

//
// -buildFeedAppsMenuForPopup: withAction: withSelectAction: withTarget:
//
// Build a NSMenu for the available feed viewing applications, set the menu of 
// the passed in NSPopUpButton and select the default application in the menu.
//
-(void)buildFeedAppsMenuForPopup:(NSPopUpButton*)inPopupButton 
                       andAction:(SEL)inAction 
                 andSelectAction:(SEL)inSelectAction
                       andTarget:(id)inTarget
{
  NSArray* feedApps = [self feedAppsList];
  NSMenu* menu = [[[NSMenu alloc] initWithTitle:@"FeedApps"] autorelease];
  NSString* defaultFeedViewerID = [[NSWorkspace sharedWorkspace] defaultFeedViewerIdentifier];

  [menu addItem:[NSMenuItem separatorItem]];
  
  BOOL insertedDefaultApp = NO;
  BOOL shouldInsertSeparatorAtEnd = NO;
  NSEnumerator* feedAppsEnum = [feedApps objectEnumerator];
  NSString* curBundleID = nil;
  while ((curBundleID = [feedAppsEnum nextObject])) {
    NSURL* appURL = [[NSWorkspace sharedWorkspace] urlOfApplicationWithIdentifier:curBundleID];
    if (!appURL)
      continue;
    
    NSMenuItem* menuItem = [self menuItemForAppURL:appURL
                                      withBundleID:curBundleID 
                                         andAction:inAction 
                                         andTarget:inTarget];
    
    // If this is the default feed app insert it in the first list
    if (defaultFeedViewerID && [curBundleID isEqualToString:defaultFeedViewerID]) {
      [menu insertItem:menuItem atIndex:0];
      insertedDefaultApp = YES;
    }
    else {
      [menu addItem:menuItem];
      shouldInsertSeparatorAtEnd = YES;
    }
  }
  
  // The user selected an application that is not registered for "feed://"
  // or has no application selected
  if (!insertedDefaultApp) {
    NSURL* defaultFeedAppURL = nil;
    if (defaultFeedViewerID)
      defaultFeedAppURL = [[NSWorkspace sharedWorkspace] urlOfApplicationWithIdentifier:defaultFeedViewerID];
    if (defaultFeedAppURL) {
      NSMenuItem* menuItem = [self menuItemForAppURL:defaultFeedAppURL
                                        withBundleID:defaultFeedViewerID
                                           andAction:nil 
                                           andTarget:inTarget];
      [menu insertItem:menuItem atIndex:0];
    }
    // Since we couldn't find a default application, add a "no default reader" menu item.
    else {
      NSMenuItem* noReaderSelectedItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"NoDefaultReader", nil)
                                                                    action:NULL 
                                                             keyEquivalent:@""];
      [menu insertItem:noReaderSelectedItem atIndex:0];
      [noReaderSelectedItem release];
    }
  }
  
  // allow the user to select a feed application
  if (shouldInsertSeparatorAtEnd)
    [menu addItem:[NSMenuItem separatorItem]];
  NSMenuItem* selectItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Select...", nil)
                                                      action:inSelectAction 
                                               keyEquivalent:@""];
  [selectItem setTarget:inTarget];
  [menu addItem:selectItem];
  [selectItem release];
  
  [inPopupButton setMenu:menu];
  [inPopupButton selectItemAtIndex:0];
}

//
// -buildBrowserAppsMenuForPopup:withAction:withSelectAction:withTarget:
//
// Build a NSMenu for the available web browser applications, set the menu of 
// the passed in NSPopUpButton and select the default application in the menu.
//
-(void)buildBrowserAppsMenuForPopup:(NSPopUpButton*)inPopupButton
                          andAction:(SEL)inAction
                    andSelectAction:(SEL)inSelectAction
                          andTarget:(id)inTarget
{
  NSArray* browsers = [self webBrowsersList];
  NSMenu* menu = [[[NSMenu alloc] initWithTitle:@"Browsers"] autorelease];
  NSString* caminoBundleID = [[NSBundle mainBundle] bundleIdentifier];
  
  // get current default browser's bundle ID
  NSString* currentDefaultBrowserBundleID = [[NSWorkspace sharedWorkspace] defaultBrowserIdentifier];
  
  // add separator first, current instance of Camino will be inserted before it
  [menu addItem:[NSMenuItem separatorItem]];
  
  // Set up new menu
  NSMenuItem* selectedBrowserMenuItem = nil;
  NSEnumerator* browserEnumerator = [browsers objectEnumerator];
  NSString* bundleID;
  while ((bundleID = [browserEnumerator nextObject])) {
    NSURL* appURL = [[NSWorkspace sharedWorkspace] urlOfApplicationWithIdentifier:bundleID];
    if (!appURL) {
      // see if it was supposed to find Camino and use our own path in that case,
      // otherwise skip this bundle ID
      if ([bundleID isEqualToString:caminoBundleID])
        appURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
      else
        continue;
    }
    
    NSMenuItem* menuItem = [self menuItemForAppURL:appURL
                                      withBundleID:bundleID 
                                         andAction:inAction 
                                         andTarget:inTarget];
    
    // if this item is Camino, insert it first in the list
    if ([bundleID isEqualToString:caminoBundleID])
      [menu insertItem:menuItem atIndex:0];
    else
      [menu addItem:menuItem];
    
    // if this item has the same bundle ID as the current default browser, select it
    if (currentDefaultBrowserBundleID && [bundleID isEqualToString:currentDefaultBrowserBundleID])
      selectedBrowserMenuItem = menuItem;
  }
  
  // allow user to select a browser
  [menu addItem:[NSMenuItem separatorItem]];
  NSMenuItem* selectItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Select...", nil)
                                                      action:inSelectAction 
                                               keyEquivalent:@""];
  [selectItem setTarget:inTarget];
  [menu addItem:selectItem];
  [selectItem release];
  
  [inPopupButton setMenu:menu];
  
  // set the correct selection
  [inPopupButton selectItem:selectedBrowserMenuItem];
}

//
// -createMenuItemForAppURL:withRepresentedObject:withAction:withTarget:
//
// Builds a menu item for the passed in values. The item will be autoreleased.
//
-(NSMenuItem*)menuItemForAppURL:(NSURL*)inURL 
                   withBundleID:(NSString*)inBundleID 
                      andAction:(SEL)inAction
                      andTarget:(id)inTarget
{
  NSMenuItem* menuItem = nil;
  NSString* displayName = [[NSWorkspace sharedWorkspace] displayNameForFile:inURL];
  
  if (displayName) {
    menuItem = [[NSMenuItem alloc] initWithTitle:displayName
                                          action:inAction 
                                   keyEquivalent:@""];
    NSImage* icon = [[NSWorkspace sharedWorkspace] iconForFile:[[inURL path] stringByStandardizingPath]];
    if (icon) {
      [icon setSize:NSMakeSize(16.0, 16.0)];
      [menuItem setImage:icon];
    }
    [menuItem setRepresentedObject:inBundleID];
    [menuItem setTarget:inTarget];
  }
  
  return [menuItem autorelease];
}

//
// -webBrowserList:
//
// Retuns an array of web browser application bundle id's that are registered with 
// Launch Services, and those that have been hand picked by the user.
//
-(NSArray*)webBrowsersList
{
  NSArray* installedBrowsers = [[NSWorkspace sharedWorkspace] installedBrowserIdentifiers];
  NSMutableSet* browsersSet = [NSMutableSet setWithArray:installedBrowsers];
  
  // add user chosen browsers to list
  [browsersSet addObjectsFromArray:[[NSUserDefaults standardUserDefaults] objectForKey:kUserChosenBrowserUserDefaultsKey]];
  
  return [[browsersSet allObjects] sortedArrayUsingFunction:&CompareBundleIDAppDisplayNames context:NULL];
}

//
// -feedAppsList:
//
// Retuns an array of feed viewing application bundle id's that are registered with 
// Launch Services for "feed://", and those that have been hand picked by the user.
//
-(NSArray*)feedAppsList
{
  NSArray* installedFeedApps = [[NSWorkspace sharedWorkspace] installedFeedViewerIdentifiers];
  NSMutableSet* feedAppsSet = [NSMutableSet setWithArray:installedFeedApps];
  
  // add user chosen feed apps to the list
  [feedAppsSet addObjectsFromArray:[[NSUserDefaults standardUserDefaults] objectForKey:kUserChosenFeedViewerUserDefaultsKey]];
  
  return [[feedAppsSet allObjects] sortedArrayUsingFunction:&CompareBundleIDAppDisplayNames context:NULL];
}

//
// -attemptDefaultFeedViewerRegistration:
//
// Set the default feed viewing application with Launch Services.
// This is used over the NSWorkspace+Utils method when an application
// was chosen from menu that could possibly contain stale data.
//
-(BOOL)validateAndRegisterDefaultFeedViewer:(NSString*)inBundleID
{
  NSString* defaultAppID = [[NSWorkspace sharedWorkspace] defaultFeedViewerIdentifier];
  BOOL succeeded = NO;
  
  // if the user selected something other than the default application
  if (!(defaultAppID && [inBundleID isEqualToString:defaultAppID])) {
    NSURL* appURL = [[NSWorkspace sharedWorkspace] urlOfApplicationWithIdentifier:inBundleID];
    if (appURL) {
      [[NSWorkspace sharedWorkspace] setDefaultFeedViewerWithIdentifier:inBundleID];
      succeeded = YES;
    }
    // could not find information for the selected app, warn the user
    else {
      NSRunAlertPanel(NSLocalizedString(@"Application does not exist", nil),
                      NSLocalizedString(@"FeedAppDoesNotExistExplanation", nil),
                      NSLocalizedString(@"OKButtonText", nil), nil, nil);
    }
  }
  
  return succeeded;
}  

//
// -attemptDefaultBrowserRegistration:
//
// Set the default web browser with Launch Services.
// This is used over the NSWorkspace+Utils method when an application
// was chosen from menu that could possibly contain stale data.
//
-(BOOL)validateAndRegisterDefaultBrowser:(NSString*)inBundleID
{
  NSString* defaultBrowserID = [[NSWorkspace sharedWorkspace] defaultBrowserIdentifier];
  BOOL succeeded = NO;
  
  // only set a new item if the user selected something other than the default application
  if (!(defaultBrowserID && [inBundleID isEqualToString:defaultBrowserID])) {
    NSURL* appURL = [[NSWorkspace sharedWorkspace] urlOfApplicationWithIdentifier:inBundleID];
    if (appURL) {
      [[NSWorkspace sharedWorkspace] setDefaultBrowserWithIdentifier:inBundleID];
      succeeded = YES;
    }
    // could not find information for the selected app, warn the user
    else {
      NSRunAlertPanel(NSLocalizedString(@"Application does not exist", nil),
                      NSLocalizedString(@"BrowserDoesNotExistExplanation", nil),
                      NSLocalizedString(@"OKButtonText", nil), nil, nil);
    }
  }
  
  return succeeded;
}

@end
