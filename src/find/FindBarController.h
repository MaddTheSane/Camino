/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>
#import "Find.h"

@class BrowserWrapper;
@class RolloverImageButton;


//
// FindBarController
//
// Manages showing and hiding the find bar in the UI, as well as dealing with
// the functionality of the find bar. This class doesn't actually implement
// anything to do with the actual find, but instead makes use of an object that
// implements to the |Find| protocol.
//
// Right now, this class only replaces the find dialog, it leaves the "find
// as you type" functionality embedded within gecko. We may one day want to
// pull it out into a separate find bar ui, like Ff. 
//
// The current search query is read from and written to the find pasteboard.
//

@class TransientBar;

@interface FindBarController : NSObject
{
  IBOutlet TransientBar* mFindBar;
  IBOutlet NSSearchField* mSearchField;
  IBOutlet NSButton* mMatchCase;
  IBOutlet NSTextField* mStatusText;
  IBOutlet RolloverImageButton* mCloseBox;
  
  id<Find>  mFinder;                    // actually performs the find, weak
  BrowserWrapper* mContentView;         // weak
}

- (id)initWithContent:(BrowserWrapper*)inContentView finder:(id<Find>)inFinder;

// show and hide the various find bars. Showing the find bar sets the focus to
// the search field. Hiding the bar posts the |kFindBarDidHideNotification|
// notification.
- (void)showFindBar;
- (IBAction)hideFindBar:(id)sender;
- (IBAction)toggleCaseSensitivity:(id)sender;
// 10.4- version
- (IBAction)findNext:(id)sender;
- (IBAction)findPrevious:(id)sender;
// 10.5+ version
- (IBAction)findPreviousNextClicked:(id)sender;
// Currently unimplemented.
- (IBAction)findAll:(id)sender;

@end
