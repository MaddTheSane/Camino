/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
* License, v. 2.0. If a copy of the MPL was not distributed with this
* file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "FileChangeWatcher.h"
#include <sys/types.h>
#include <sys/event.h>
#import "unistd.h"
#import "fcntl.h"

static const int kSecondPollingInterval = 60;

static const unsigned int kMaxWatchedDirectories = 25;

// Watched directory dictionary keys
static NSString* const kDelegatesKey = @"delegates";
static NSString* const kFileDescriptorKey = @"fdes";

@interface FileChangeWatcher(Private)

-(void)startPolling;
-(void)stopPolling;
-(void)pollWatchedDirectories;
-(void)directoryChanged:(NSString*)directory;

@end

@implementation FileChangeWatcher

-(id)init
{
  if ((self = [super init])) {
    mWatchInfo = [[NSMutableDictionary alloc] init];
    mWatchedDirectories = [[NSMutableArray alloc] init];
    mQueueFileDesc = kqueue();
  }
  
  return self;
}

-(void)dealloc
{
  close(mQueueFileDesc);
  [mWatchInfo release];
  [mWatchedDirectories release];
  [super dealloc];
}

-(void)addWatchedFileDelegate:(id<WatchedFileDelegate>)aWatchedFileDelegate
{
  @synchronized(mWatchInfo) {
    NSString* parentDirectory =
      [[aWatchedFileDelegate representedFilePath] stringByDeletingLastPathComponent];
    NSMutableDictionary* directoryInfo = [mWatchInfo objectForKey:parentDirectory];
    if (directoryInfo) {
      NSMutableArray* directoryDelegates = [directoryInfo objectForKey:kDelegatesKey];
      if (![directoryDelegates containsObject:aWatchedFileDelegate])
        [directoryDelegates addObject:aWatchedFileDelegate];
    }
    else {
      // We cap the number of kqueues so we don't end up sucking down all the
      // available file descriptors.
      if ([mWatchInfo count] >= kMaxWatchedDirectories)
        return;

      int fileDesc = open([parentDirectory fileSystemRepresentation], O_EVTONLY, 0);
      if (fileDesc >= 0) {
        struct timespec nullts = { 0, 0 };
        struct kevent ev;
        u_int fflags = NOTE_RENAME | NOTE_WRITE | NOTE_DELETE;

        // mWatchedDirectories needs to own parentDirectory for the lifetime of
        // this kqueue, so that it is safe to use as context data. We need to
        // be sure that we are using the *same* string object when we are
        // tracking multiple downloads in the same folder.
        unsigned int storedIndex = [mWatchedDirectories indexOfObject:parentDirectory];
        if (storedIndex == NSNotFound)
          [mWatchedDirectories addObject:parentDirectory];
        else
          parentDirectory = [mWatchedDirectories objectAtIndex:storedIndex];

        EV_SET(&ev, fileDesc, EVFILT_VNODE, EV_ADD | EV_ENABLE | EV_CLEAR, fflags,
               0, (void*)parentDirectory);

        kevent(mQueueFileDesc, &ev, 1, NULL, 0, &nullts);
        if (!mShouldRunThread)
          [self startPolling];
        
        directoryInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:
          [NSMutableArray arrayWithObject:aWatchedFileDelegate], kDelegatesKey,
                              [NSNumber numberWithInt:fileDesc], kFileDescriptorKey,
                                                                 nil];
        [mWatchInfo setObject:directoryInfo forKey:parentDirectory];
      }
    }
  }
}

-(void)removeWatchedFileDelegate:(id<WatchedFileDelegate>)aWatchedFileDelegate
{
  @synchronized(mWatchInfo) {
    NSString* parentDirectory =
      [[aWatchedFileDelegate representedFilePath] stringByDeletingLastPathComponent];
    NSMutableDictionary* directoryInfo = [mWatchInfo objectForKey:parentDirectory];
    NSMutableArray* directoryDelegates = [directoryInfo objectForKey:kDelegatesKey];
    if (![directoryDelegates containsObject:aWatchedFileDelegate])
      return;

    int fileDesc = [[directoryInfo objectForKey:kFileDescriptorKey] intValue];
    [directoryDelegates removeObject:aWatchedFileDelegate];

    if ([directoryDelegates count] == 0) {
      close(fileDesc);
      [mWatchInfo removeObjectForKey:parentDirectory];
      // mWatchedDirectories is left unchanged; it must be cleaned up in
      // pollWatchedDirectories rather than here.
      if (mShouldRunThread && [mWatchInfo count] == 0)
        [self stopPolling];
    }
  }
}

-(void)startPolling
{
  @synchronized(self) {
    mShouldRunThread = YES;
    if (!mThreadIsRunning) {
      mThreadIsRunning = YES;
      [NSThread detachNewThreadSelector:@selector(pollWatchedDirectories) 
                               toTarget:self 
                             withObject:nil];
    }
  }
}

-(void)stopPolling
{
  @synchronized(self) {
    mShouldRunThread = NO;
  }
}

//
// Portions of this method were originally written by M. Uli Kusterer.
//
-(void)pollWatchedDirectories
{
  const struct timespec timeInterval = { kSecondPollingInterval, 0 };

  while (1) {
    @synchronized(self) {
      if (!mShouldRunThread) {
        mThreadIsRunning = NO;
        break;
      }
    }

    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    // sync mWatchedDirectories back to the current state of the watch requests.
    // Controlling all removal from mWatchedDirectories in this thread
    // guarantees that the kevent data it stores will never vanish out from
    // under a triggering kqueue.
    @synchronized(mWatchInfo) {
      for (int i = [mWatchedDirectories count] - 1; i >= 0; --i) {
        NSString* directory = [mWatchedDirectories objectAtIndex:i];
        if (![mWatchInfo objectForKey:directory]) {
          [mWatchedDirectories removeObjectAtIndex:i];
        }
      }
    }

    @try {
      struct kevent event;
      int n = kevent(mQueueFileDesc, NULL, 0, &event, 1,
                     (const struct timespec*)&timeInterval);
      if (n > 0 && event.filter == EVFILT_VNODE && event.fflags) {
        [self directoryChanged:(NSString*)event.udata];
      }
    }
    @catch (id exception) {
      NSLog(@"Error in watcherThread: %@", exception);
    }
    
    [pool release];
  }
}

-(void)directoryChanged:(NSString*)directory
{
  NSSet* existingFiles =
    [NSSet setWithArray:[[NSFileManager defaultManager] directoryContentsAtPath:directory]];
  
  NSEnumerator* delegateEnumerator;
  @synchronized(mWatchInfo) {
    NSDictionary* directoryInfo = [mWatchInfo objectForKey:directory];
    NSArray* directoryDelegates = [directoryInfo objectForKey:kDelegatesKey];
    // Hold a strong reference to all the delegates that we are going to call
    // until we are done, since they may be removed at any moment.
    delegateEnumerator = [[[directoryDelegates copy] autorelease] objectEnumerator];
  }
  id fileDelegate;
  while ((fileDelegate = [delegateEnumerator nextObject])) {
    NSString* filename = [[fileDelegate representedFilePath] lastPathComponent];
    if (![existingFiles member:filename])
      [fileDelegate fileRemoved];
  }
}

@end
