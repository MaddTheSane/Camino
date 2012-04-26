/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <AppKit/AppKit.h>
#import <Carbon/Carbon.h>

// Pull in the constants so all the consumers don't have to do so explicitly.
#import "GeckoPrefConstants.h"

class nsProfileDirServiceProvider;
class nsIPrefBranch;

extern NSString* const kPrefChangedNotification;
// userInfo entries:
extern NSString* const kPrefChangedPrefNameUserInfoKey;   // NSString

@interface PreferenceManager : NSObject
{
@private
  NSUserDefaults*       mDefaults;
  nsProfileDirServiceProvider* mProfileProvider;
  nsIPrefBranch*        mPrefs;

  NSMutableDictionary*  mPrefChangeObservers; // dict of NSMutableArray of PrefChangeObserverOwner, keyed by pref name.

  long                  mLastRunPrefsVersion;
  BOOL                  mIsCustomProfile;
  NSString*             mProfilePath;

  // proxies notification stuff
  CFRunLoopSourceRef    mRunLoopSource;
}

+ (PreferenceManager*)sharedInstance;
+ (PreferenceManager*)sharedInstanceDontCreate;

- (BOOL)initMozillaPrefs;
- (void)syncMozillaPrefs;
- (void)savePrefsFile;

// Load our various style sheets, according to user prefs. Must be called after
// component registration, since it accesses the plug-in list.
- (void)loadUserStylesheets;

- (NSString*)homePageUsingStartPage:(BOOL)checkStartupPagePref;

- (NSURL*)getFilePref:(const char*)prefName withSuccess:(BOOL*)outSuccess;
- (NSString*)getStringPref: (const char*)prefName withSuccess:(BOOL*)outSuccess;
- (NSColor*)getColorPref: (const char*)prefName withSuccess:(BOOL*)outSuccess;
- (BOOL)getBooleanPref: (const char*)prefName withSuccess:(BOOL*)outSuccess;
- (int)getIntPref: (const char*)prefName withSuccess:(BOOL*)outSuccess;

- (void)setPref:(const char*)prefName toFile:(NSURL*)value;
- (void)setPref:(const char*)prefName toString:(NSString*)value;
- (void)setPref:(const char*)prefName toInt:(int)value;
- (void)setPref:(const char*)prefName toBoolean:(BOOL)value;

// Set/Get the directory to download files to.
- (void)setDownloadDirectoryPath:(NSString*)aPath;
- (NSString*)downloadDirectoryPath;

- (void)clearPref:(const char*)prefName;

// Returns YES if the user has disabled the given plugin.
- (BOOL)pluginShouldBeDisabled:(const char*)pluginName;

// Returns YES if Java can be enabled (i.e., if a Java plugin is present).
- (BOOL)javaPluginCanBeEnabled;

// Returns YES if a Flash plugin is present.
- (BOOL)isFlashInstalled;

// the path to the user profile's root folder
- (NSString*)profilePath;
// the path to Camino's cache root folder
- (NSString*)cacheParentDirPath;

// turn notifications on and off when the given pref changes. 
// if not nil, inObject is used at the 'object' of the resulting notification.
- (void)addObserver:(id)inObject forPref:(const char*)inPrefName;
- (void)removeObserver:(id)inObject;    // remove from all prefs that it observes
- (void)removeObserver:(id)inObject forPref:(const char*)inPrefName;

// Returns a Cocoa font name translated from a Gecko font family name (used in 
// preferences). There's occasionally a mismatch when using Gecko family names
// in Cocoa to create an NSFont (usually caused by localization differences).
// Returns nil if no font name matches |geckoName|.
- (NSString*)fontNameForGeckoFontName:(NSString*)geckoName;

@end
