/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "PreferencesWindow.h"


@implementation PreferencesWindow

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
  // Disable toolbar toggling
  if ([menuItem action] == @selector(toggleToolbarShown:))
    return NO;
  return [super validateMenuItem:menuItem];
}

@end
