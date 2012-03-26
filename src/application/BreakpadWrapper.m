/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

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
