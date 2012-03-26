/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */


#import "CHDownloadProgressDisplay.h"
#import "FileChangeWatcher.h"

class CHDownloader;
@class ProgressDlgController;
@class ProgressView;

// do this because there is no "no" key in the set of key modifiers.
// it is in this header because both classes that need it include this file
// (ProgressDlgController and ProgressView)
enum {
  kNoKey = 0,
  kShiftKey = 1,
  kCommandKey = 2
};
typedef enum {
  DownloadSelectExclusively,
  DownloadSelectByInverting,
  DownloadSelectByExtending
} DownloadSelectionBehavior;

// Names of notifications we will post on download-related events
extern NSString* const kDownloadStartedNotification;
extern NSString* const kDownloadFailedNotification;
extern NSString* const kDownloadCompleteNotification;

// Names of keys for objects passed in these notifications
extern NSString* const kDownloadNotificationFilenameKey;
extern NSString* const kDownloadNotificationTimeElapsedKey;

//
// interface ProgressViewController
//
// There is a 1-to-1 correspondence between a download in the manager and
// one of these objects. It implements what you can do with the item as 
// well as managing the download. It holds onto two views, one for while
// the item is downloading, the other for after it has completed.
//
@interface ProgressViewController : NSObject<CHDownloadProgressDisplay, WatchedFileDelegate>
{
  IBOutlet NSProgressIndicator *mProgressBar;

  IBOutlet ProgressView *mProgressView;      // in-progress view, STRONG ref
  IBOutlet ProgressView *mCompletedView;     // completed view, STRONG ref
  
  unsigned int    mUniqueIdentifier;      // unique identifier for a given session

  BOOL            mIsFileSave;
  BOOL            mUserCancelled;
  BOOL            mDownloadFailed;
  BOOL            mDownloadDone;
  BOOL            mRefreshIcon;
  BOOL            mFileExists;
  BOOL            mFileIsWatched;
  BOOL            mIsBeingRemoved;
  BOOL            mIsSelected;

  NSTimeInterval  mDownloadTime; // only set when done

  long long       mCurrentProgress; // if progress bar is indeterminate, can still calc stats.
  long long       mDownloadSize;
  
  NSString        *mSourceURL;
  NSString        *mDestPath;
  NSDate          *mStartTime;
  
  CHDownloader    *mDownloader;             // wraps gecko download, STRONG ref
  
  ProgressDlgController *mProgressWindowController;    // window controller, WEAK ref (owns us)
}

+(NSString *)formatTime:(int)aSeconds;
+(NSString *)formatFuzzyTime:(int)aSeconds;
+(NSString *)formatBytes:(float)aBytes;

-(id)initWithWindowController:(ProgressDlgController*)aWindowController;
-(id)initWithDictionary:(NSDictionary*)aDict 
    andWindowController:(ProgressDlgController*)aWindowController;

-(ProgressView *)view;

-(IBAction)cancel:(id)sender;
-(IBAction)remove:(id)sender;
-(IBAction)reveal:(id)sender;
-(IBAction)open:(id)sender;
-(IBAction)pause:(id)sender;
-(IBAction)resume:(id)sender;

-(BOOL)deleteFile;

-(BOOL)isActive;
-(BOOL)isCanceled;
-(BOOL)isSelected;
-(BOOL)isPaused;
-(BOOL)fileExists;

-(BOOL)hasSucceeded;

// Directly sets the selection of this item (should not be called by the view).
-(void)setSelected:(BOOL)inSelected;

-(NSDictionary*)downloadInfoDictionary;
-(unsigned int)uniqueIdentifier;

-(NSMenu*)contextualMenu;
-(BOOL)shouldAllowAction:(SEL)action;

// Handlers for actions that are triggered by user action on a view but aren't
// specific to the view.
-(void)updateSelectionWithBehavior:(DownloadSelectionBehavior)behavior;
-(void)openSelectedDownloads;
-(void)cancelSelectedDownloads;

@end
