/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */


#import "GrowlController.h"
#import "ProgressDlgController.h"
#import "ProgressViewController.h"

// Names of keys for objects passed in these notifications
static NSString* const kGrowlNotificationNameKey = @"GrowlNotificationNameKey";
static NSString* const kGrowlNotificationObjectKey = @"GrowlNotificationObjectKey";
static NSString* const kGrowlNotificationUserInfoKey = @"GrowlNotificationUserInfoKey";


// Download duration (in seconds) less than which a download is considered 'short'
static NSTimeInterval const kShortDownloadInterval = 15.0;


@interface GrowlController (Private)

- (void)growlForNotification:(NSNotification*)notification;

@end

@implementation GrowlController

- (id)init
{
  if ((self = [super init])) {
    NSNotificationCenter* notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self
                           selector:@selector(growlForNotification:)
                               name:kDownloadStartedNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(growlForNotification:)
                               name:kDownloadFailedNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(growlForNotification:)
                               name:kDownloadCompleteNotification
                             object:nil];
  }
  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  if (mGrowlIsInitialized) {
    // Note this is never acutally called, since Growl retains its delegate.
    [GrowlApplicationBridge setGrowlDelegate:nil];
  }
  [super dealloc];
}

- (NSDictionary*)registrationDictionaryForGrowl
{
  NSArray* allNotifications = [NSArray arrayWithObjects:
                               NSLocalizedString(@"GrowlDownloadStarted", nil),
                               NSLocalizedString(@"GrowlDownloadFailed", nil),
                               NSLocalizedString(@"GrowlShortDownloadComplete", nil),
                               NSLocalizedString(@"GrowlDownloadComplete", nil),
                               nil];

  NSDictionary* notificationDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                          allNotifications, GROWL_NOTIFICATIONS_DEFAULT,
                                          allNotifications, GROWL_NOTIFICATIONS_ALL,
                                          nil];

  return notificationDictionary;
}

- (void)growlForNotification:(NSNotification*)notification
{
  if (!mGrowlIsInitialized) {
    mGrowlIsInitialized = YES;
    [GrowlApplicationBridge setGrowlDelegate:self];
  }
  NSString* notificationName = [notification name];
  ProgressViewController* download = [notification object];
  NSNumber* downloadIdentifier = [NSNumber numberWithUnsignedInt:[download uniqueIdentifier]];
  NSDictionary* userInfo = [notification userInfo];

  NSString* title = nil;
  NSString* name = nil;

  if ([notificationName isEqual:kDownloadStartedNotification]) {
    name = NSLocalizedString(@"GrowlDownloadStarted", nil);
  }
  else if ([notificationName isEqual:kDownloadFailedNotification]) {
    name = NSLocalizedString(@"GrowlDownloadFailed", nil);
  }
  else if ([notificationName isEqual:kDownloadCompleteNotification]) {
    double timeElapsed = [[userInfo objectForKey:kDownloadNotificationTimeElapsedKey] doubleValue];
    if (timeElapsed < kShortDownloadInterval) {
      name = NSLocalizedString(@"GrowlShortDownloadComplete", nil);
      title = NSLocalizedString(@"GrowlDownloadComplete", nil);
    }
    else {
      name = NSLocalizedString(@"GrowlDownloadComplete", nil);
    }
  }
  if (!title)
    title = name;

  NSString* description = [[userInfo objectForKey:kDownloadNotificationFilenameKey] lastPathComponent];
  NSDictionary* context = [NSDictionary dictionaryWithObjectsAndKeys:
                           notificationName, kGrowlNotificationNameKey,
                           downloadIdentifier, kGrowlNotificationObjectKey,
                           userInfo, kGrowlNotificationUserInfoKey,
                           nil];

  [GrowlApplicationBridge notifyWithTitle:title
                              description:description
                         notificationName:name
                                 iconData:nil
                                 priority:0
                                 isSticky:0
                             clickContext:context];
}

- (void)growlNotificationWasClicked:(id)clickContext
{
  NSString* notificationName = [clickContext objectForKey:kGrowlNotificationNameKey];

  if ([notificationName isEqual:kDownloadStartedNotification] ||
      [notificationName isEqual:kDownloadFailedNotification])
  {
    ProgressDlgController* progressWindowController = [ProgressDlgController existingSharedDownloadController];
    if (progressWindowController) {
      [progressWindowController showWindow:self];

      unsigned int downloadIdentifier = [[clickContext objectForKey:kGrowlNotificationObjectKey] unsignedIntValue];
      ProgressViewController* downloadInstance = [progressWindowController downloadWithIdentifier:downloadIdentifier];
      // If downloadInstance is |nil|, this will clear the selection, which is what we want
      [progressWindowController updateSelectionOfDownload:downloadInstance
                                             withBehavior:DownloadSelectExclusively];
    }
  }
  else if ([notificationName isEqual:kDownloadCompleteNotification]) {
    // Reveal the file directly rather than asking the progressViewController to
    // reveal it because users can ask Camino to automatically remove downloads
    // upon completion.
    NSString* filename = [[clickContext objectForKey:kGrowlNotificationUserInfoKey] objectForKey:kDownloadNotificationFilenameKey];
    if (filename && [[NSFileManager defaultManager] fileExistsAtPath:filename]) {
      [[NSWorkspace sharedWorkspace] selectFile:filename
                       inFileViewerRootedAtPath:[filename stringByDeletingLastPathComponent]];
    }
  }
}

@end // GrowlController
