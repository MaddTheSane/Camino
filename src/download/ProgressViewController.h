/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* ***** BEGIN LICENSE BLOCK *****
 * Version: NPL 1.1/GPL 2.0/LGPL 2.1
 *
 * The contents of this file are subject to the Netscape Public License
 * Version 1.1 (the "License"); you may not use this file except in
 * compliance with the License. You may obtain a copy of the License at
 * http://www.mozilla.org/NPL/
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
 *    Calum Robinson <calumr@mac.com>
 *    Simon Fraser <sfraser@netscape.com>
 *    Josh Aas <josha@mac.com>
 *
 * Alternatively, the contents of this file may be used under the terms of
 * either the GNU General Public License Version 2 or later (the "GPL"), or 
 * the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
 * in which case the provisions of the GPL or the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of either the GPL or the LGPL, and not to allow others to
 * use your version of this file under the terms of the NPL, indicate your
 * decision by deleting the provisions above and replace them with the notice
 * and other provisions required by the GPL or the LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the NPL, the GPL or the LGPL.
 *
 * ***** END LICENSE BLOCK ***** */


#import "CHDownloadProgressDisplay.h"

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

//
// interface ProgressViewController
//
// There is a 1-to-1 correspondence between a download in the manager and
// one of these objects. It implements what you can do with the item as 
// well as managing the download. It holds onto two views, one for while
// the item is downloading, the other for after it has completed.
//
@interface ProgressViewController : NSObject<CHDownloadProgressDisplay>
{
  // we share one progress bar between both views. It's in the expanded
  // view by default
  IBOutlet NSProgressIndicator *mProgressBar;

  IBOutlet ProgressView *mProgressView;      // in-progress view, STRONG ref
  IBOutlet ProgressView *mCompletedView;     // completed view, STRONG ref
  
  BOOL            mIsFileSave;
  BOOL            mUserCancelled;
  BOOL            mDownloadingError;
  BOOL            mDownloadDone;
    
  NSTimeInterval  mDownloadTime; // only set when done

  long            mCurrentProgress; // if progress bar is indeterminate, can still calc stats.
  long            mDownloadSize;
  
  NSString        *mSourceURL;
  NSString        *mDestPath;
  NSDate          *mStartTime;
  
  CHDownloader    *mDownloader;             // wraps gecko download, STRONG ref
  
  ProgressDlgController *mProgressWindowController;    // window controller, WEAK ref (owns us)
}

+(NSString *)formatTime:(int)aSeconds;
+(NSString *)formatFuzzyTime:(int)aSeconds;
+(NSString *)formatBytes:(float)aBytes;

-(ProgressView *)view;

-(IBAction)cancel:(id)sender;
-(IBAction)remove:(id)sender;
-(IBAction)reveal:(id)sender;
-(IBAction)open:(id)sender;

-(BOOL)isActive;
-(BOOL)isCanceled;
-(BOOL)isSelected;

-(NSMenu*)contextualMenu;

-(void)setProgressWindowController:(ProgressDlgController*)progressWindowController;

@end
