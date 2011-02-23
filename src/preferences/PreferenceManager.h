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

#import <AppKit/AppKit.h>
#import <Carbon/Carbon.h>

// Pull in the constants so all the consumers don't have to do so explicitly.
#import "GeckoPrefConstants.h"

class nsProfileDirServiceProvider;
class nsIPrefBranch;

extern NSString* const kPrefChangedNotificationName;
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
