/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*-
*
* The contents of this file are subject to the Mozilla Public
* License Version 1.1 (the "License"); you may not use this file
* except in compliance with the License. You may obtain a copy of
* the License at http://www.mozilla.org/MPL/
*
* Software distributed under the License is distributed on an "AS
* IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
* implied. See the License for the specific language governing
* rights and limitations under the License.
*
* The Original Code is the Mozilla browser.
*
* The Initial Developer of the Original Code is Netscape
* Communications Corporation. Portions created by Netscape are
* Copyright (C) 2002 Netscape Communications Corporation. All
* Rights Reserved.
*
* Contributor(s):
*   Joe Hewitt <hewitt@netscape.com> (Original Author)
*   David Haas <haasd@cae.wisc.edu> 
*/

#import "CHAutoCompleteTextField.h"
#import "BrowserWindowController.h"
#import "CHPageProxyIcon.h"
#include "nsIServiceManager.h"
#include "nsMemory.h"
#include "nsString.h"
#include "CHUserDefaults.h"

static const int kMaxRows = 6;
static const int kFrameMargin = 1;

@interface AutoCompleteWindow : NSWindow
- (BOOL)isKeyWindow;
@end

@implementation AutoCompleteWindow
- (BOOL)isKeyWindow
{
  return YES;
}
@end

class AutoCompleteListener : public nsIAutoCompleteListener
{  
public:
  AutoCompleteListener(CHAutoCompleteTextField* aTextField)
  {
    NS_INIT_REFCNT();
    mTextField = aTextField;
  }
  
  NS_DECL_ISUPPORTS

  NS_IMETHODIMP OnStatus(const PRUnichar* aText) { return NS_OK; }
  NS_IMETHODIMP SetParam(nsISupports *aParam) { return NS_OK; }
  NS_IMETHODIMP GetParam(nsISupports **aParam) { return NS_OK; }

  NS_IMETHODIMP OnAutoComplete(nsIAutoCompleteResults *aResults, AutoCompleteStatus aStatus)
  {
    [mTextField dataReady:aResults status:aStatus];
    return NS_OK;
  }

private:
  CHAutoCompleteTextField *mTextField;
};

NS_IMPL_ISUPPORTS1(AutoCompleteListener, nsIAutoCompleteListener)

////////////////////////////////////////////////////////////////////////

@implementation CHAutoCompleteTextField

- (void) awakeFromNib
{
  NSTableColumn *column;
  NSScrollView *scrollView;
  NSCell *dataCell;
  
  mSearchString = nil;
  mBackspaced = NO;
  mCompleteResult = NO;
  mOpenTimer = nil;
  
  mSession = nsnull;
  mResults = nsnull;
  mListener = (nsIAutoCompleteListener *)new AutoCompleteListener(self);
  NS_IF_ADDREF(mListener);

  [self setDelegate: self]; 

  // XXX the owner of the textfield should set this
  [self setSession:@"history"];
  
  // construct and configure the popup window
  mPopupWin = [[AutoCompleteWindow alloc] initWithContentRect:NSMakeRect(0,0,0,0)
                      styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO];
  [mPopupWin setReleasedWhenClosed:NO];
  [mPopupWin setLevel:NSFloatingWindowLevel];
  [mPopupWin setHasShadow:YES];
  [mPopupWin setAlphaValue:0.9];

  // construct and configure the view
  mTableView = [[[NSTableView alloc] initWithFrame:NSMakeRect(0,0,0,0)] autorelease];
  [mTableView setIntercellSpacing:NSMakeSize(1, 2)];
  [mTableView setTarget:self];
  [mTableView setAction:@selector(onRowClicked:)];
  
  // Create the icon column if we have a proxy icon
  if (mProxyIcon) {
    column = [[[NSTableColumn alloc] initWithIdentifier:@"icon"] autorelease];
    [column setWidth:[mProxyIcon frame].origin.x + [mProxyIcon frame].size.width];
    dataCell = [[[NSImageCell alloc] initImageCell:nil] autorelease];
    [column setDataCell:dataCell];
    [mTableView addTableColumn: column];
  }
  
  // create the text columns
  column = [[[NSTableColumn alloc] initWithIdentifier:@"col1"] autorelease];
  [mTableView addTableColumn: column];
  column = [[[NSTableColumn alloc] initWithIdentifier:@"col2"] autorelease];
  [[column dataCell] setTextColor:[NSColor darkGrayColor]];
  [mTableView addTableColumn: column];

  // hide the table header
  [mTableView setHeaderView:nil];
  
  // construct the scroll view that contains the table view
  scrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(0,0,0,0)] autorelease];
  [scrollView setHasVerticalScroller:YES];
  [[scrollView verticalScroller] setControlSize:NSSmallControlSize];
  [scrollView setDocumentView: mTableView];

  // construct the datasource
  mDataSource = [[CHAutoCompleteDataSource alloc] init];
  [mTableView setDataSource: mDataSource];

  [mPopupWin setContentView:scrollView];

  // listen for when window resigns from key handling
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onBlur:)
                                        name:NSWindowDidResignKeyNotification object:nil];

  // listen for when window is about to be moved or resized
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onBlur:)
                                        name:NSWindowWillMoveNotification object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onResize:)
                                        name:NSWindowDidResizeNotification object:nil];

  // read the user default on if we should auto-complete the text field as the user
  // types or make them pick something from a list (a-la mozilla).
	mCompleteWhileTyping = [[NSUserDefaults standardUserDefaults] boolForKey:USER_DEFAULTS_AUTOCOMPLETE_WHILE_TYPING];
}

- (void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];

  if (mSearchString)
    [mSearchString release];
    
  [mPopupWin release];
  [mDataSource release];

  NS_IF_RELEASE(mSession);
  NS_IF_RELEASE(mResults);
  NS_IF_RELEASE(mListener);
  
  [super dealloc];
}

- (void) setSession:(NSString *)aSession
{
  NS_IF_RELEASE(mSession);

  // XXX add aSession to contract id
  nsCOMPtr<nsIAutoCompleteSession> session =
    do_GetService("@mozilla.org/autocompleteSession;1?type=history");
  mSession = session;
  NS_IF_ADDREF(mSession);
}

- (NSString *) session
{
  // XXX return session name
  return @"";
}

- (NSTableView *) tableView
{
  return mTableView;
}

- (int) visibleRows
{
  int minRows = [mDataSource rowCount];
  return minRows < kMaxRows ? minRows : kMaxRows;
}

- (void) setPageProxyIcon:(NSImage *)aImage
{
  [mProxyIcon setImage:aImage];
}

-(id) fieldEditor
{
  return [[self window] fieldEditor:NO forObject:self];
}
// searching ////////////////////////////

- (void) startSearch:(NSString*)aString complete:(BOOL)aComplete
{
  if (mSearchString)
    [mSearchString release];
  mSearchString = [aString retain];

  mCompleteResult = aComplete;

  if ([self isOpen]) {
    [self performSearch];
  } else {
    // delay the search when the popup is not yet opened so that users 
    // don't see a jerky flashing popup when they start typing for the first time
    if (mOpenTimer) {
      [mOpenTimer invalidate];
      [mOpenTimer release];
    }
    
    mOpenTimer = [[NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(searchTimer:)
                          userInfo:nil repeats:NO] retain];
  }
}

- (void) performSearch
{
  PRUnichar* chars = nsMemory::Alloc(([mSearchString length]+1) * sizeof(PRUnichar));
  [mSearchString getCharacters:chars];
  chars[[mSearchString length]] = 0; // I shouldn't have to do this
  nsresult rv = mSession->OnStartLookup(chars, mResults, mListener);
  nsMemory::Free(chars);

  if (NS_FAILED(rv))
    NSLog(@"Unable to perform autocomplete lookup");
}

- (void) dataReady:(nsIAutoCompleteResults*)aResults status:(AutoCompleteStatus)aStatus
{
  NS_IF_RELEASE(mResults);
  mResults = nsnull;
  
  if (aStatus == nsIAutoCompleteStatus::failed) {
    [mDataSource setErrorMessage:@""];
  } else if (aStatus == nsIAutoCompleteStatus::ignored) {
    [mDataSource setErrorMessage:@""];
  } else if (aStatus == nsIAutoCompleteStatus::noMatch) {
    [mDataSource setErrorMessage:@""];
  } else if (aStatus == nsIAutoCompleteStatus::matchFound) {
    mResults = aResults;
    NS_IF_ADDREF(mResults);
    [mDataSource setResults:aResults];
    [self completeDefaultResult];
  }

  if ([mDataSource rowCount] > 0) {
    [mTableView noteNumberOfRowsChanged];
    [self openPopup];
  } else {
    [self closePopup];
  }
}

- (void) searchTimer:(NSTimer *)aTimer
{
  [mOpenTimer release];
  mOpenTimer = nil;

  [self performSearch];
}

- (void) clearResults
{
  // clear out search data
  if (mSearchString)
    [mSearchString release];
  mSearchString = nil;
  NS_IF_RELEASE(mResults);
  mResults = nsnull;

  [mDataSource setResults:nil];

  [self closePopup];
}

// handling the popup /////////////////////////////////

- (void) openPopup
{
  [self resizePopup];

  // show the popup
  if ([mPopupWin isVisible] == NO)
    [mPopupWin orderFront:nil];
}

- (void) resizePopup
{
  NSRect locationFrame, winFrame;
  NSPoint locationOrigin;
  int tableHeight;
  
  if ([self visibleRows] == 0) {
    [self closePopup];
    return;
  }

  // get the origin of the location bar in coordinates of the root view
  locationFrame = [[self superview] frame];
  locationOrigin = [[[self superview] superview] convertPoint:locationFrame.origin
                                                       toView:[[[self window] contentView] superview]];

  // get the height of the table view
  winFrame = [[self window] frame];
  tableHeight = (int)([mTableView rowHeight]+[mTableView intercellSpacing].height)*[self visibleRows];

  // make the columns split the width of the popup
  [[mTableView tableColumnWithIdentifier:@"col1"] setWidth:locationFrame.size.width/2];
  
  // position the popup anchored to bottom/left of location bar (
  [mPopupWin setFrame:NSMakeRect(winFrame.origin.x + locationOrigin.x + kFrameMargin,
                                 ((winFrame.origin.y + locationOrigin.y) - tableHeight) - kFrameMargin,
                                 locationFrame.size.width - (2*kFrameMargin),
                                 tableHeight) display:NO];
}

- (void) closePopup
{
  [mPopupWin close];
}

- (BOOL) isOpen
{
  return [mPopupWin isVisible];
}

// url completion ////////////////////////////

- (void) completeDefaultResult
{
  PRInt32 defaultRow;
  mResults->GetDefaultItemIndex(&defaultRow);
  
  if (mCompleteResult && mCompleteWhileTyping) {
    [self selectRowAt:defaultRow];
    [self completeResult:defaultRow];
  } else {
    [self selectRowAt:-1];
  }
}

- (void) completeSelectedResult
{
  [self completeResult:[mTableView selectedRow]];
}

- (void) completeResult:(int)aRow
{
  if (aRow < 0 && mSearchString) {
    // reset to the original search string with the insertion point at the end. Note
    // we have to make our range before we call setStringUndoably: because it calls
    // clearResults() which destroys |mSearchString|.
    NSRange selectAtEnd = NSMakeRange([mSearchString length],0);
    [self setStringUndoably:mSearchString fromLocation:0];
    [[self fieldEditor] setSelectedRange:selectAtEnd];
  }
  else {
    if ([mDataSource rowCount] <= 0)
      return;

    // Fill in the suggestion from the list, but change only the text 
    // after what is typed and select just that part. This allows the
    // user to see what they have typed and what change the autocomplete
    // makes while allowing them to continue typing w/out having to
    // reset the insertion point. 
    NSString *result = [mDataSource resultString:aRow column:@"col1"];
    NSRange matchRange = [result rangeOfString:mSearchString];
    if (matchRange.length > 0 && matchRange.location != NSNotFound) {
      unsigned int location = matchRange.location + matchRange.length;
      result = [result substringWithRange:NSMakeRange(location, [result length]-location)];
      [self setStringUndoably:result fromLocation:[mSearchString length]];
    }
  }
}

- (void) enterResult:(int)aRow
{
  if (aRow >= 0 && [mDataSource rowCount] > 0) {
    [self setStringUndoably:[mDataSource resultString:[mTableView selectedRow] column:@"col1"] fromLocation:0];
    [self closePopup];
  } else if (mOpenTimer) {
    // if there was a search timer going when we hit enter, cancel it
    [mOpenTimer invalidate];
    [mOpenTimer release];
    mOpenTimer = nil;
  }
}

- (void) revertText
{
  BrowserWindowController *controller = (BrowserWindowController *)[[self window] windowController];
  NSString *url = [[controller getBrowserWrapper] getCurrentURLSpec];
  if (url) {
    [self clearResults];
    NSTextView *fieldEditor = [self fieldEditor];
    [[fieldEditor undoManager] removeAllActions];
    [fieldEditor setString:url];
    [fieldEditor selectAll:self];
  }
}

- (void) setStringUndoably:(NSString *)aString fromLocation:(unsigned int)aLocation
{
  NSTextView *fieldEditor = [self fieldEditor];
  NSRange aRange = NSMakeRange(aLocation,[[fieldEditor string] length] - aLocation);
  if ([fieldEditor shouldChangeTextInRange:aRange replacementString:aString]) {
    [[fieldEditor textStorage] replaceCharactersInRange:aRange withString:aString];
    // Whenever we send [self didChangeText], we trigger the
    // textDidChange method, which will begin a new search with
    // a new search string (which we just inserted) if the selection
    // is at the end of the string.  So, we "select" the first character
    // to prevent that badness from happening.
    [fieldEditor setSelectedRange:NSMakeRange(0,0)];    
    [fieldEditor didChangeText];
  }
  aRange = NSMakeRange(aLocation,[[fieldEditor string] length] - aLocation);
  [fieldEditor setSelectedRange:aRange];
}

// selecting rows /////////////////////////////////////////

- (void) selectRowAt:(int)aRow
{
  if (aRow >= -1 && [mDataSource rowCount] > 0) {
    // show the popup
    if ([mPopupWin isVisible] == NO)
      [mPopupWin orderFront:nil];

    [mTableView selectRow:aRow byExtendingSelection:NO];
    [mTableView scrollRowToVisible: aRow];
  }
}

- (void) selectRowBy:(int)aRows
{
  int row = [mTableView selectedRow];
  
  if (row == -1 && aRows < 0) {
    // if nothing is selected and you scroll up, go to last row
    row = [mTableView numberOfRows]-1;
  } else if (row == [mTableView numberOfRows]-1 && aRows == 1) {
    // if the last row is selected and you scroll down, go to first row
    row = 0;
  } else if (aRows+row < 0) {
    // if you scroll up beyond first row...
    if (row == 0)
      row = -1; // ...and first row is selected, select nothing
    else
      row = 0; // ...else, go to first row
  } else if (aRows+row >= [mTableView numberOfRows]) {
    // if you scroll down beyond the last row...
    if (row == [mTableView numberOfRows]-1)
      row = 0; // and last row is selected, select first row
    else
      row = [mTableView numberOfRows]-1; // else, go to last row
  } else {
    // no special case, just increment current row
    row += aRows;
  }
    
  [self selectRowAt:row];
}

// event handlers ////////////////////////////////////////////

- (void) onRowClicked:(NSNotification *)aNote
{
  [self enterResult:[mTableView clickedRow]];
  [[[self window] windowController] goToLocationFromToolbarURLField:self];
}

- (void) onBlur:(NSNotification *)aNote
{
  [self closePopup];
}

- (void) onResize:(NSNotification *)aNote
{
  [self resizePopup];
}

// NSTextField delegate //////////////////////////////////
- (void)controlTextDidChange:(NSNotification *)aNote
{
  NSTextView *fieldEditor = [[aNote userInfo] objectForKey:@"NSFieldEditor"];
  NSRange range = [fieldEditor selectedRange];
  // make sure we're typing at the end of the string
  if (range.location == [[fieldEditor string] length]) {
    // when we ask for a NSTextView string, Cocoa returns
    // a pointer to the view's backing store.  So, the value
    // of the string continually changes as we edit the text view.
    // Since we'll edit the text view as we add in autocomplete results,
    // we've got to make a copy of the string as it currently stands
    // to know what we were searching for in the first place.
    NSString *searchString = [[fieldEditor string] copyWithZone:nil];
    [self startSearch:searchString complete:!mBackspaced];
    [searchString release];
  }
  else if (([mTableView selectedRow] == -1) || mBackspaced)
    [self clearResults];
  
  mBackspaced = NO;
}

- (void)controlTextDidEndEditing:(NSNotification *)aNote
{
  [self closePopup];
  [[[[aNote userInfo] objectForKey:@"NSFieldEditor"] undoManager] removeAllActions];
}
  
- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command
{
  if (command == @selector(insertNewline:)) {
    [self enterResult:[mTableView selectedRow]];
  } else if (command == @selector(moveUp:)) {
    [self selectRowBy:-1];
    [self completeSelectedResult];
    return YES;
  } else if (command == @selector(moveDown:)) {
    [self selectRowBy:1];
    [self completeSelectedResult];
    return YES;
  } else if (command == @selector(scrollPageUp:)) {
    [self selectRowBy:-kMaxRows];
    [self completeSelectedResult];
  } else if (command == @selector(scrollPageDown:)) {
    [self selectRowBy:kMaxRows];
    [self completeSelectedResult];
  } else if (command == @selector(moveToBeginningOfDocument:)) {
    [self selectRowAt:0];
    [self completeSelectedResult];
  } else if (command == @selector(moveToEndOfDocument:)) {
    [self selectRowAt:[mTableView numberOfRows]-1];
    [self completeSelectedResult];
  } else if (command == @selector(insertTab:)) {
    if ([mPopupWin isVisible]) {
      [self selectRowBy:1];
      [self completeSelectedResult];
      return YES;
    }
  } else if (command == @selector(deleteBackward:) || 
             command == @selector(deleteForward:)) {
    // if the user deletes characters, we need to know so that
    // we can prevent autocompletion later when search results come in
    if ([[textView string] length] > 1)
      mBackspaced = YES;    
  }
  
  return NO;
}

@end
