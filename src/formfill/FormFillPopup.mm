/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "FormFillPopup.h"
#import "FormFillController.h"

@implementation FormFillPopupWindow

- (BOOL)isKeyWindow
{
  return YES;
}

@end

@interface FormFillPopup(Private)

- (void)onRowClicked:(NSNotification *)aNote;

@end

@implementation FormFillPopup

- (id)init
{
  if ((self = [super init])) {
    // Construct and configure the popup window.
    mPopupWin = [[FormFillPopupWindow alloc] initWithContentRect:NSMakeRect(0,0,0,0)
                                                       styleMask:NSNonactivatingPanelMask
                                                         backing:NSBackingStoreBuffered
                                                           defer:NO];

    [mPopupWin setReleasedWhenClosed:NO];
    [mPopupWin setHasShadow:YES];
    [mPopupWin setAlphaValue:0.9];

    // Construct and configure the view.
    mTableView = [[[NSTableView alloc] initWithFrame:NSMakeRect(0,0,0,0)] autorelease];
    [mTableView setIntercellSpacing:NSMakeSize(1, 2)];
    [mTableView setTarget:self];
    [mTableView setAction:@selector(onRowClicked:)];

    // Create the text column (only one).
    NSTableColumn* column = [[[NSTableColumn alloc] initWithIdentifier:@"usernames"] autorelease];
    [column setEditable:NO];
    [mTableView addTableColumn:column];

    // Hide the table header.
    [mTableView setHeaderView:nil];

    [mTableView setDataSource:self];

    NSScrollView *scrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(0,0,0,0)] autorelease];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setAutohidesScrollers:YES];
    [[scrollView verticalScroller] setControlSize:NSSmallControlSize];
    
    [scrollView setDocumentView:mTableView];

    [mPopupWin setContentView:scrollView];
  }

  return self;
}

- (void)dealloc
{
  [mPopupWin release];
  [mItems release];

  [super dealloc];
}

- (void)attachToController:(FormFillController*)controller
{
  mController = controller;
}

- (BOOL)isPopupOpen
{
  return [mPopupWin isVisible];
}

- (void)openPopup:(NSWindow*)browserWindow withOrigin:(NSPoint)origin width:(float)width
{
  // Set the size of the popup window.
  NSRect tableViewFrame = [mTableView frame];
  tableViewFrame.size.width = width;
  [mTableView setFrame:tableViewFrame];

  // Size the panel correctly.
  tableViewFrame.size.height = (int)([mTableView rowHeight] + [mTableView intercellSpacing].height) * [self visibleRows];
  [mPopupWin setContentSize:tableViewFrame.size];
  [mPopupWin setFrameTopLeftPoint:origin];

  // Show the popup.
  if (![mPopupWin isVisible]) {
    [browserWindow addChildWindow:mPopupWin ordered:NSWindowAbove];
    [mPopupWin orderFront:nil];
  }
}

- (void)resizePopup
{
  // Don't resize if popup isn't visible.
  if (![mPopupWin isVisible])
    return;

  if ([self visibleRows] == 0) {
    [self closePopup];
    return;
  }

  NSRect popupWinFrame = [mPopupWin frame];
  int tableHeight = (int)([mTableView rowHeight] + [mTableView intercellSpacing].height) * [self visibleRows];

  popupWinFrame.origin.y += NSHeight(popupWinFrame) - tableHeight;
  popupWinFrame.size.height = tableHeight;

  [mPopupWin setFrame:popupWinFrame display:YES];
}

- (void)closePopup
{
  // We can get -closePopup even if we didn't show it.
  if ([mPopupWin isVisible]) {
    [[mPopupWin parentWindow] removeChildWindow:mPopupWin];
    [mPopupWin orderOut:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
  }
}

- (void)onRowClicked:(NSNotification *)aNote
{
  [mController popupSelected];
  [self closePopup];
}

- (int)visibleRows
{
   int minRows = [self rowCount];
   return (minRows < kFormFillMaxRows) ? minRows : kFormFillMaxRows;
}

- (int)rowCount
{
  if (!mItems)
    return 0;

  return [mItems count];
}

- (void)selectRow:(int)index
{
  if (index == -1)
    [mTableView deselectAll:self];
  else {
    [mTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
    [mTableView scrollRowToVisible:index];
  }
}

- (int)selectedRow
{
  return [mTableView selectedRow];
}

- (NSString*)resultForRow:(int)index
{
  return [mItems objectAtIndex:index];
}

- (void)setItems:(NSArray*)items
{
  if (items != mItems) {
    [mItems release];
    mItems = [items retain];
  }

  // Update the view any time we get new data
  [mTableView noteNumberOfRowsChanged]; 
  [self resizePopup];
}

// methods for table view interaction
-(int)numberOfRowsInTableView:(NSTableView*)aTableView
{
  return [self rowCount];
}

-(id)tableView:(NSTableView*)aTableView objectValueForTableColumn:(NSTableColumn*)aTableColumn row:(int)aRowIndex
{
  return [self resultForRow:aRowIndex];
}

@end
