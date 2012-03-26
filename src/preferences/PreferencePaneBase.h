/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <PreferencePanes/PreferencePanes.h>


// optional methods that our prefs panes can implement
@interface NSObject(CaminoPreferencePane)

// the prefs window was activated; pane should update its state
- (void)didActivate;

@end


@interface PreferencePaneBase : NSPreferencePane 
{
  void* dummy; // Placeholder for the old mPrefService variable to prevent
               // third-party preference panes deployed on both 1.x and 2+
               // from breaking due to the fragile base class problem.
}

- (NSString*)getStringPref: (const char*)prefName withSuccess:(BOOL*)outSuccess;
- (NSColor*)getColorPref: (const char*)prefName withSuccess:(BOOL*)outSuccess;
- (BOOL)getBooleanPref: (const char*)prefName withSuccess:(BOOL*)outSuccess;
- (int)getIntPref: (const char*)prefName withSuccess:(BOOL*)outSuccess;

- (void)setPref: (const char*)prefName toString:(NSString*)value;
- (void)setPref: (const char*)prefName toColor:(NSColor*)value;
- (void)setPref: (const char*)prefName toBoolean:(BOOL)value;
- (void)setPref: (const char*)prefName toInt:(int)value;

- (void)clearPref: (const char*)prefName;

- (NSString*)localizedStringForKey:(NSString*)key;

// See PreferenceManager.h for documentation about this method.
- (NSString*)fontNameForGeckoFontName:(NSString*)geckoName;

@end
