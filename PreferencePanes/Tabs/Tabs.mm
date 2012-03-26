/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*-
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "Tabs.h"

#import "GeckoPrefConstants.h"

@implementation OrgMozillaCaminoPreferenceTabs

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
  BOOL gotPref;

  [mCheckboxOpenTabsForCommand setState:([self getBooleanPref:kGeckoPrefOpenTabsForMiddleClick
                                                  withSuccess:&gotPref] ? NSOnState : NSOffState)];

  int externalLinksPref = [self getIntPref:kGeckoPrefExternalLoadBehavior withSuccess:&gotPref];
  if (externalLinksPref == kExternalLoadOpensNewWindow)
    [mCheckboxOpenTabsForExternalLinks setState:NSOffState];
  else if (externalLinksPref == kExternalLoadOpensNewTab)
    [mCheckboxOpenTabsForExternalLinks setState:NSOnState];
  else
    [mCheckboxOpenTabsForExternalLinks setState:NSMixedState];

  int swmBehavior = [self getIntPref:kGeckoPrefSingleWindowModeTargetBehavior withSuccess:&gotPref];
  if (swmBehavior == kSingleWindowModeUseNewWindow)
    [mSingleWindowMode setState:NSOffState];
  else if (swmBehavior == kSingleWindowModeUseNewTab)
    [mSingleWindowMode setState:NSOnState];
  else
    [mSingleWindowMode setState:NSMixedState];

  [mCheckboxLoadTabsInBackground setState:([self getBooleanPref:kGeckoPrefOpenTabsInBackground
                                                    withSuccess:&gotPref] ? NSOnState : NSOffState)];
  [mTabBarVisiblity setState:([self getBooleanPref:kGeckoPrefAlwaysShowTabBar withSuccess:&gotPref] ? NSOnState : NSOffState)];
}

- (IBAction)checkboxClicked:(id)sender
{
  if (sender == mCheckboxOpenTabsForCommand) {
    [self setPref:kGeckoPrefOpenTabsForMiddleClick toBoolean:([sender state] == NSOnState)];
  }
  else if (sender == mCheckboxOpenTabsForExternalLinks) {
    [sender setAllowsMixedState:NO];
    [self setPref:kGeckoPrefExternalLoadBehavior toInt:([sender state] == NSOnState ? kExternalLoadOpensNewTab
                                                                                    : kExternalLoadOpensNewWindow)];
  }
  else if (sender == mSingleWindowMode) {
    [sender setAllowsMixedState:NO];
    int newState = ([sender state] == NSOnState) ? kSingleWindowModeUseNewTab
                                                 : kSingleWindowModeUseNewWindow;
    [self setPref:kGeckoPrefSingleWindowModeTargetBehavior toInt:newState];
  }
  else if (sender == mCheckboxLoadTabsInBackground) {
    [self setPref:kGeckoPrefOpenTabsInBackground toBoolean:([sender state] == NSOnState)];
  }
  else if (sender == mTabBarVisiblity) {
    [self setPref:kGeckoPrefAlwaysShowTabBar toBoolean:([sender state] == NSOnState)];
  }
}

@end
