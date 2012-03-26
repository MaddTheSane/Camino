/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
* License, v. 2.0. If a copy of the MPL was not distributed with this
* file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <AppKit/AppKit.h>

//
// Any object that needs a file to be polled can implement this protocol and 
// register itself with the watch queue.
//
@protocol WatchedFileDelegate

//
// This method will need to return the full path of the file/folder 
// that is being watched.
//
-(NSString*)representedFilePath;

//
// This method gets called when the watcher recieves news that a file has
// been removed at the watched path.
// Note: This method will be called on a background thread.
//
-(void)fileRemoved;

@end


//
// This class provides a file polling service to any object
// that implements the |WatchedFileDelegate| protocol.
//
@interface FileChangeWatcher : NSObject
{
@private
  NSMutableDictionary* mWatchInfo;           // strong ref
  NSMutableArray*      mWatchedDirectories;  // strong ref
  
  int          mQueueFileDesc;
  BOOL         mShouldRunThread;
  BOOL         mThreadIsRunning;
}

//
// Add an object implementing the |WatchedFileDelegate| to the 
// watch queue. 
// Note: An object will only be added once to the queue.
//
-(void)addWatchedFileDelegate:(id<WatchedFileDelegate>)aWatchedFileDelegate;

//
// Remove an object implementing the |WatchedFileDelegate| from the watch queue.
//
-(void)removeWatchedFileDelegate:(id<WatchedFileDelegate>)aWatchedFileDelegate;

@end
