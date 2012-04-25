/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>
#import "FindBarController.h"

#import "BrowserWrapper.h"
#import "FindNotifications.h"
#import "RolloverImageButton.h"
#import "NSWorkspace+Utils.h"

@interface FindBarController(Private)
- (void)lazyLoad;
- (void)doFindForwards:(BOOL)inNext;
- (void)setupCloseBox:(RolloverImageButton*)button;
- (void)putStringOnFindPasteboard:(NSString*)inStr;
- (NSString*)findPasteboardString;
- (void)updateStatusTextWithSuccess:(BOOL)success;
@end


@implementation FindBarController

// TODO
// - turn bar red when there are no matches
// - hookup status text for wraparound (need to use FastFind?)
// - find all (requires converting Ff's custom JS to C++, there's no API)

- (id)initWithContent:(BrowserWrapper*)inContentView finder:(id<Find>)inFinder
{
  if ((self = [super init])) {
    mContentView = inContentView;
    mFinder = inFinder;
    // lazily load the nibs
  }
  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];

  // Balance the implicit retain from being a top-level nib object.
  [mFindBar release];

  [super dealloc];
}

//
// -lazyLoad
//
// We don't want to load a separate nib every time the user opens a browser 
// window, since we assume that most windows won't want the find bar. Load the
// nibs lazily and set them up when needed.
//
- (void)lazyLoad
{
  NSString* nibName;
  BOOL isLeopardOrHigher = [NSWorkspace isLeopardOrHigher];
  if (isLeopardOrHigher)
    nibName = @"FindBarTextured";
  else
    nibName = @"FindBar";
  BOOL success = [NSBundle loadNibNamed:nibName owner:self];
  if (!success) {
    NSLog(@"Error, couldn't load find bar. Find won't work");
    return;
  }
  
  [self setupCloseBox:mCloseBox];
  [mStatusText setStringValue:@""];
  if (isLeopardOrHigher) {
    // The textured buttons at regular size use a larger font size than the
    // status text that's right next to it, which looks bad. To work around it,
    // we use a smaller control in the nib (so that localizers are sizing the
    // button width based on the font size that will actually be used), then we
    // fix up the controlSize and height of the button as we load it.
    [[mMatchCase cell] setControlSize:NSRegularControlSize];
    NSSize buttonSize = [mMatchCase frame].size;
    buttonSize.height = [[mMatchCase cell] cellSize].height;
    [mMatchCase setFrameSize:buttonSize];
  }

  [mFindBar setLastKeySubview:mMatchCase];

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(updateFindStatusText:)
                                               name:kFindStatusNotification
                                             object:nil];
}

//
// -showFindBar
//
// Makes the find bar visible and makes the search field take focus and sets
// its value to the contents of the find pasteboard.
//
- (void)showFindBar {
  if (!mFindBar)
    [self lazyLoad];

  [mStatusText setStringValue:@""];
  [mSearchField setStringValue:[self findPasteboardString]];

  [mContentView showTransientBar:mFindBar atPosition:eTransientBarPositionBottom];
  [[mFindBar window] makeFirstResponder:mSearchField];
}

//
// -hideFindBar:
//
// Makes the find bar go away.
//
- (IBAction)hideFindBar:(id)sender {
  [mContentView removeTransientBar:mFindBar display:YES];
}

//
// -findNext:
// -findPrevious:
//
// Actions for the search field and the UI buttons.
//
- (IBAction)findNext:(id)sender
{
  [self doFindForwards:YES];
  // Return/enter ends editing and unfocuses the search field, which we don't
  // want. Rather than setting up a custom field editor, just force focus back
  // if it's not focused.
  if (![mSearchField currentEditor] ||
      [[mSearchField window] firstResponder] != [mSearchField currentEditor])
  {
    [[mSearchField window] makeFirstResponder:mSearchField];
  }
}

- (IBAction)findPrevious:(id)sender
{
  [self doFindForwards:NO];
}

//
// -findPreviousNextClicked:
//
// Action for the segmented previous/next button for 10.5+.
//
- (IBAction)findPreviousNextClicked:(id)sender
{
  if ([sender selectedSegment] == 0)
    [self doFindForwards:NO];
  else
    [self doFindForwards:YES];
}

//
// -toggleCaseSensitivity:
//
// Action for the case sensitivity button.
//
- (IBAction)toggleCaseSensitivity:(id)sender
{
  [self doFindForwards:YES];
}

//
// -doFindForwards:
//
// Tell gecko to find the text in the search field. |inNext| determines the direction,
// YES being forwards NO being backwards, which is actually the opposite of the
// way that Gecko wants it.
//
- (void)doFindForwards:(BOOL)inNext
{
  NSString* searchText = [mSearchField stringValue];
  if (![searchText length])
    return;
  BOOL caseSensitive = [mMatchCase state] == NSOnState;
  [self putStringOnFindPasteboard:searchText];
  BOOL success = [mFinder findInPageWithPattern:searchText caseSensitive:caseSensitive wrap:YES backwards:!inNext];

  [self updateStatusTextWithSuccess:success];
}

- (IBAction)findAll:(id)sender
{
  // alas, there's no API call to do this directly, firefox does it with a bunch of JS. Save
  // for someone with more free time. See
  //  toolkit/components/typeaheadfind/content/findBar.js
}

//
// -setupCloseBox
//
// Do some additional setup that we can't easily do in the nib.
//
- (void)setupCloseBox:(RolloverImageButton*)closebox
{
  [closebox setTitle:NSLocalizedString(@"CloseFindBarTitle", nil)];   // doesn't show, but used for accessibility
  [closebox setBezelStyle:NSShadowlessSquareBezelStyle];
  [closebox setImage:[NSImage imageNamed:@"tab_close"]];
  [closebox setImagePosition:NSImageOnly];
  [closebox setButtonType:NSMomentaryChangeButton];
  [closebox setBordered:NO];
  [closebox setAlternateImage:[NSImage imageNamed:@"tab_close_pressed"]];
  [closebox setHoverImage:[NSImage imageNamed:@"tab_close_hover"]];
}

//
// -control:textView:doCommandBySelector:
// delegate method
// 
// Hook in to handle the user hitting the escape key, which will hide the bar.
//
- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command
{
  if (command == @selector(cancelOperation:) || command == @selector(cancel:)) {
    [self hideFindBar:self];
    return YES;
  }
  return NO;
}

//
// -putStringOnFindPasteboard:
//
// Puts |inStr| on the find pasteboard.
//
- (void)putStringOnFindPasteboard:(NSString*)inStr
{
  NSPasteboard* pasteboard = [NSPasteboard pasteboardWithName:NSFindPboard];
  [pasteboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
  [pasteboard setString:inStr forType:NSStringPboardType];
}

//
// -findPasteboardString
//
// Retrieve the most recent search string.
//
- (NSString*)findPasteboardString
{
  NSString* searchText = @"";

  NSPasteboard* findPboard = [NSPasteboard pasteboardWithName:NSFindPboard];
  if ([[findPboard types] indexOfObject:NSStringPboardType] != NSNotFound)
    searchText = [findPboard stringForType:NSStringPboardType];

  return searchText;
}

//
// -updateFindStatusText:
//
// Updates the Find Bar status string in response to a notification.
//
- (void)updateFindStatusText:(NSNotification *)notification
{
  if ([notification object] != [mContentView browserView])
    return;
  BOOL success = [[[notification userInfo]
      objectForKey:kFindStatusNotificationSuccessKey] boolValue];
  [self updateStatusTextWithSuccess:success];
}

//
// -updateStatusTextWithSuccess:
//
// Updates the Find Bar status string based on results of a find operation.
//
- (void)updateStatusTextWithSuccess:(BOOL)success
{
  [mStatusText setStringValue:(success ? NSLocalizedString(@"", nil) : NSLocalizedString(@"TextNotFound", nil))];
}

@end
