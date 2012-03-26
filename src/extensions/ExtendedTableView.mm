/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "ExtendedTableView.h"
#import "NSWorkspace+Utils.h"

@implementation ExtendedTableView

-(void)setDeleteAction: (SEL)aDeleteAction
{
  mDeleteAction = aDeleteAction;
}

-(SEL)deleteAction
{
  return mDeleteAction;
}

-(void)keyDown:(NSEvent*)aEvent
{
  // check each char in the event array. it should be just 1 char, but
  // just in case we use a loop.
  int len = [[aEvent characters] length];
  BOOL handled = NO;
  
  for (int i = 0; i < len; ++i)
  {
    unichar c = [[aEvent characters] characterAtIndex:i];

    // Check for a certain set of special keys.
    switch (c)
    {
       case NSDeleteCharacter:
       case NSBackspaceCharacter:
       case NSDeleteFunctionKey:
        if (mDeleteAction)
        {
          [NSApp sendAction:mDeleteAction to:[self target] from:self];
          handled = YES;
        }
        break;

      case NSHomeFunctionKey:
        [self scrollRowToVisible:0];
        handled = YES;
        break;

      case NSEndFunctionKey:
        [self scrollRowToVisible:[self numberOfRows] - 1];
        handled = YES;
        break;

      case NSCarriageReturnCharacter:
      case NSEnterCharacter:
        // Start editing the selected row
        NSTableColumn *firstTableColumn = [[self tableColumns] objectAtIndex:0];
        BOOL shouldEdit = [firstTableColumn isEditable] && [self numberOfSelectedRows] == 1;
        // When programmatically editing, this delegate method is not called automatically.
        if (shouldEdit && [[self delegate] respondsToSelector:@selector(tableView:shouldEditTableColumn:row:)]) {
          shouldEdit = [[self delegate] tableView:self 
                            shouldEditTableColumn:firstTableColumn
                                              row:[self selectedRow]];
        }
        if (shouldEdit)
          [self editColumn:0 row:[self selectedRow] withEvent:aEvent select:YES];
        handled = YES;
        break;
    }
  }

  if (!handled)
    [super keyDown:aEvent];
}

-(NSMenu *)menuForEvent:(NSEvent *)theEvent
{
  int rowIndex;
  NSPoint point;
  point = [self convertPoint:[theEvent locationInWindow] fromView:nil];
  rowIndex = [self rowAtPoint:point];
  if (rowIndex >= 0)
  {
    [self abortEditing];
    id delegate = [self delegate];
    if (![self isRowSelected:rowIndex])
    {
      // if we've clicked on an unselected row, ask the table view if
      // it is selectable
      if ([delegate respondsToSelector:@selector(tableView:shouldSelectRow:)])
      {
        if (![delegate tableView:self shouldSelectRow:rowIndex])
          return [self menu];
      }

      // it is selectable, so select it
      [self selectRowIndexes:[NSIndexSet indexSetWithIndex:rowIndex]
        byExtendingSelection:NO];
    }
    
    // now (we're on a selected row) get the contet menu
    if ([delegate respondsToSelector:@selector(tableView:contextMenuForRow:)])
      return [delegate tableView:self contextMenuForRow:rowIndex];
  }
  return [self menu];
}

//
// -textDidEndEditing:
//
// Called when the object we're editing is done. The default behavior is to
// select another editable item, but that's not the behavior we want. We just
// want to keep the selection on what was being editing.
//
- (void)textDidEndEditing:(NSNotification *)aNotification
{
  // This action is not needed on Leopard, as selection behavior was changed.
  if ([NSWorkspace isLeopardOrHigher]) {
    [super textDidEndEditing:aNotification];
    return;
  }

  // Fake our own notification. We pretend that the editing was canceled due to a
  // mouse click. This prevents outlineviw from selecting another cell for editing.
  NSDictionary *userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:NSIllegalTextMovement] forKey:@"NSTextMovement"];
  NSNotification *fakeNotification = [NSNotification notificationWithName:[aNotification name] object:[aNotification object] userInfo:userInfo];
  
  [super textDidEndEditing:fakeNotification];
  
  // Make ourself first responder again
  [[self window] makeFirstResponder:self];
}

@end
