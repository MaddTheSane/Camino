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
 * The Original Code is Camino code.
 *
 * The Initial Developer of the Original Code is
 * Stuart Morgan
 * Portions created by the Initial Developer are Copyright (C) 2009
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *   Stuart Morgan <stuart.morgan@alumni.case.edu>
 *   Smokey Ardisson <alqahira@ardisson.org>
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

#import "BreakpadWrapper.h"

#import <Breakpad/Breakpad.h>

#import "NSString+Utils.h"

static BreakpadWrapper* sGlobalBreakpadInstance = nil;

@interface BreakpadWrapper(Private)

- (NSString*)versionFirstInstalledTime;
- (NSString*)installTimeFilePath;
- (NSString*)currentEpochTimeAsString;
- (BOOL)isValidSocorroTimeString:(NSString*)timeString;
- (void)writeInstallTime:(NSString*)installTime forBuild:(NSString*)buildID toDictionary:(NSDictionary*)installTimes;
- (void)writeInstallTimesToFile:(NSDictionary*)installData;

@end

@implementation BreakpadWrapper

- (id)init
{
  if ((self = [super init])) {
    if (!sGlobalBreakpadInstance) {
      NSBundle* mainBundle = [NSBundle mainBundle];
      NSDictionary* info = [mainBundle infoDictionary];
      mBreakpadReference = BreakpadCreate(info);
      if (!mBreakpadReference) {
        [self autorelease];
        return nil;
      }
      sGlobalBreakpadInstance = self;

      // Breakpad uses CFBundleVersion, but we want our short version instead.
      BreakpadSetKeyValue(mBreakpadReference, @BREAKPAD_VERSION,
                          [info valueForKey:@"CFBundleShortVersionString"]);
      // Get the localized vendor, which infoDictionary doesn't do.
      BreakpadSetKeyValue(mBreakpadReference, @BREAKPAD_VENDOR,
                          [mainBundle objectForInfoDictionaryKey:@"BreakpadVendor"]);

      NSString* installTime = [self versionFirstInstalledTime];
      BreakpadAddUploadParameter(mBreakpadReference, @"InstallTime", installTime);
    }
    else {
      NSLog(@"WARNING: attempting to create a second BreakpadWrapper");
      [self autorelease];
    }
  }
  return sGlobalBreakpadInstance;
}

- (void)dealloc
{
  if (self == sGlobalBreakpadInstance)
    sGlobalBreakpadInstance = nil;

  if (mBreakpadReference)
    BreakpadRelease(mBreakpadReference);
  [super dealloc];
}

+ (BreakpadWrapper*)sharedInstance
{
  return sGlobalBreakpadInstance;
}

- (void)setReportedURL:(NSString*)url
{
  if (![url isBlankURL])
    BreakpadAddUploadParameter(mBreakpadReference, @"URL", url);
}

- (NSString*)versionFirstInstalledTime
{
  NSString* buildID = [[[NSBundle mainBundle] infoDictionary] valueForKey:@"MozillaBuildID"];
  NSString* installTimesFile = [self installTimeFilePath];
  NSMutableDictionary* installTimes = nil;
  NSString* currentBuildInstallTime = nil;
  if ([[NSFileManager defaultManager] fileExistsAtPath:installTimesFile]) {
    NSData* fileData = [NSData dataWithContentsOfFile:installTimesFile];
    if (fileData) {
      installTimes = [NSPropertyListSerialization propertyListFromData:fileData
                                                      mutabilityOption:NSPropertyListMutableContainers
                                                                format:NULL
                                                      errorDescription:NULL];
    }
  }
  if (installTimes) {
    currentBuildInstallTime = [installTimes valueForKey:buildID];
    if (!currentBuildInstallTime ||
        ![self isValidSocorroTimeString:currentBuildInstallTime])
    {
      currentBuildInstallTime = [self currentEpochTimeAsString];
      [self writeInstallTime:currentBuildInstallTime
                    forBuild:buildID
                toDictionary:installTimes];
    }
  }
  else {
    // Something failed along the way: either there's no file, reading the data
    // from the file failed, or converting the data to a plist failed; in these
    // cases, set up the install time for the current build using the current
    // time and then start a new file.
    currentBuildInstallTime = [self currentEpochTimeAsString];
    [self writeInstallTime:currentBuildInstallTime
                  forBuild:buildID
              toDictionary:[NSMutableDictionary dictionary]];
  }
  return currentBuildInstallTime;
}

- (NSString*)installTimeFilePath
{
  NSString* appName = [[[NSBundle mainBundle] infoDictionary] valueForKey:@"CFBundleName"];
  NSString *libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,
                              NSUserDomainMask, YES) objectAtIndex:0];
  NSString* installTimeFilePath = [[[libraryPath stringByAppendingPathComponent:@"Breakpad"]
                                                 stringByAppendingPathComponent:appName]
                                                 stringByAppendingPathComponent:@"InstallTime.plist"];
  return installTimeFilePath;
}

- (NSString*)currentEpochTimeAsString
{
  NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
  return [NSString stringWithFormat:@"%.f", now];
}

// Socorro only handles 10-digit numbers for time strings; if we ever manage to
// retrive a valid NSString but an invalid UNIX time integer, Socorro barfs on
// the crash report, so perform some very basic validation.
- (BOOL)isValidSocorroTimeString:(NSString*)timeString
{
  NSCharacterSet* nonDigitSet = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
  return (([timeString rangeOfCharacterFromSet:nonDigitSet].location == NSNotFound) &&
          ([timeString length] == 10));  
}

- (void)writeInstallTime:(NSString*)installTime forBuild:(NSString*)buildID toDictionary:(NSDictionary*)installTimes
{
  [installTimes setValue:installTime forKey:buildID];
  [self writeInstallTimesToFile:installTimes];

}

- (void)writeInstallTimesToFile:(NSDictionary*)installData
{
  NSData* dataFromPlist = [NSPropertyListSerialization dataFromPropertyList:installData
                                                                 format:NSPropertyListBinaryFormat_v1_0
                                                       errorDescription:NULL];
  if (dataFromPlist)
    [dataFromPlist writeToFile:[self installTimeFilePath] atomically:YES];
}

@end
