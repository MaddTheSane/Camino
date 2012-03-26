/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */


#import <AppKit/AppKit.h>

#import "CHDownloadProgressDisplay.h"
#import "CHStackView.h"

/*
  How ProgressViewController and ProgressDlgController work. 
  
  ProgressDlgController manages the window the the downloads are displayed in.
  It contains a single CHStackView, a custom class that asks its datasource
  for a list of views to display, in a similar fashion to the way NSTableView
  asks its datasource for data to display. There is a single instance of
  ProgressDlgController, returned by +sharedDownloadController. 
  
  The ProgressDlgController is a subclass of CHDownloadController, which
  means that it gets asked to create new objects conforming to the
  CHDownloadProgressDisplay protocol, which are used to display
  the progress of a single download. It does so by returning instances of
  ProgressViewController, which manage an NSView that contains a progress
  indicator and some text fields for status info. 
  
  After a ProgressViewController is requested, the CHStackView is reloaded,
  which causes it to ask the ProgressDlgController (it's datasource) to
  provide it with a list of all the subviews to be diaplyed. It calculates
  it's new frame, and arranges the subviews in a vertical list.
*/

#import "CHDownloadProgressDisplay.h"
#import "FileChangeWatcher.h"
#import "ProgressViewController.h"  // For DownloadSelectionBehavior enum

//
// interface ProgressDlgController
//
// A window controller managing multiple simultaneous downloads. The user
// can cancel, remove, or get information about any of the downloads it
// manages. It maintains one |ProgressViewController| object for each download.
//

@interface ProgressDlgController : NSWindowController<CHDownloadDisplayFactory, CHStackViewDataSource>
{
  IBOutlet CHStackView*  mStackView;
  IBOutlet NSScrollView* mScrollView;
  
  NSSize                mDefaultWindowSize;
  NSTimer*              mDownloadTimer;            // used for updating the status, STRONG ref
  NSMutableArray*       mProgressViewControllers;  // the downloads we manage, STRONG ref
  int                   mNumActiveDownloads;
  int                   mSelectionPivotIndex;
  BOOL                  mShouldCloseWindow;         // true when a download completes when termination modal sheet is up
  BOOL                  mAwaitingTermination;       // true when we are waiting for users termination modal sheet
  
  FileChangeWatcher*    mFileChangeWatcher;         // strong ref.
}

+(ProgressDlgController *)sharedDownloadController;           // creates if necessary
+(ProgressDlgController *)existingSharedDownloadController;   // doesn't create

-(IBAction)cancel:(id)sender;
-(IBAction)remove:(id)sender;
-(IBAction)reveal:(id)sender;
-(IBAction)cleanUpDownloads:(id)sender;
-(IBAction)open:(id)sender;
-(IBAction)pause:(id)sender;
-(IBAction)resume:(id)sender;
-(IBAction)selectAll:(id)sender;

-(ProgressViewController*)downloadWithIdentifier:(unsigned int)identifier;

-(void)updateSelectionOfDownload:(ProgressViewController*)selectedDownload
                    withBehavior:(DownloadSelectionBehavior)behavior;

-(int)numDownloadsInProgress;
-(void)clearAllDownloads;
-(void)didStartDownload:(ProgressViewController*)progressDisplay;
-(void)didEndDownload:(ProgressViewController*)progressDisplay withSuccess:(BOOL)completedOK statusCode:(nsresult)status;
-(void)removeDownload:(ProgressViewController*)progressDisplay suppressRedraw:(BOOL)suppressRedraw;
-(NSApplicationTerminateReply)allowTerminate;
-(void)applicationWillTerminate;

-(void)addFileDelegateToWatchList:(id<WatchedFileDelegate>)aWatchedFileDelegate;
-(void)removeFileDelegateFromWatchList:(id<WatchedFileDelegate>)aWatchedFileDelegate;

@end
