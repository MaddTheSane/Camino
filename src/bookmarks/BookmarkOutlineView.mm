/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "BookmarkViewController.h"
#import "BookmarkOutlineView.h"
#import "BookmarkFolder.h"
#import "Bookmark.h"
#import "BookmarkManager.h"
#import "NSPasteboard+Utils.h"

@implementation BookmarkOutlineView

- (void)awakeFromNib
{
  [self registerForDraggedTypes:[NSArray arrayWithObjects:kCaminoBookmarkListPBoardType,
                                                          kWebURLsWithTitlesPboardType,
                                                          NSStringPboardType,
                                                          NSURLPboardType,
                                                          nil]];
}

- (NSMenu*)menu
{
  BookmarkManager *bm = [BookmarkManager sharedBookmarkManager];
  BookmarkFolder *activeCollection = [(BookmarkViewController*)[self delegate] activeCollection];
  // only give a default menu if its the bookmark menu or toolbar
  if ((activeCollection == [bm bookmarkMenuFolder]) || (activeCollection == [bm toolbarFolder])) {
    // set up default menu
    NSMenu *menu = [[[NSMenu alloc] init] autorelease];
    NSMenuItem *menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Create New Folder...", nil)
                                                       action:@selector(addBookmarkFolder:)
                                                keyEquivalent:@""] autorelease];
    [menuItem setTarget:[self delegate]];
    [menu addItem:menuItem];
    return menu;
  }
  return nil;
}

- (void)draggedImage:(NSImage *)anImage endedAt:(NSPoint)aPoint operation:(NSDragOperation)operation
{
  if (operation == NSDragOperationDelete) {
    NSPasteboard* pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
    NSArray* bookmarks = [BookmarkManager bookmarkItemsFromSerializableArray:[pboard propertyListForType:kCaminoBookmarkListPBoardType]];
    if (bookmarks) {
      [[BookmarkManager sharedBookmarkManager] bookmarkItemsWillBeRemoved:bookmarks];
      for (unsigned int i = 0; i < [bookmarks count]; ++i) {
        BookmarkItem* item = [bookmarks objectAtIndex:i];
        [[item parent] deleteChild:item];
      }
    }
  }
}

// don't edit URL field of folders or menu separators
- (void)_editItem:(id)dummy
{
  id itemToEdit = [self itemAtRow:mRowToBeEdited];
  if ([itemToEdit isKindOfClass:[BookmarkFolder class]]) {
    if (mColumnToBeEdited == [self columnWithIdentifier:@"url"]) {
      [super _cancelEditItem];
      return;
    }
  }
  else if ([itemToEdit isKindOfClass:[Bookmark class]]) {
    if ([(Bookmark *)itemToEdit isSeparator]) {
      [super _cancelEditItem];
      return;
    }
  }
  [super _editItem:dummy];
}

// This gets called when the user hits the Escape key.
- (void)cancel:(id)sender
{
  if ([[[self window] firstResponder] isKindOfClass:[NSTextView class]] &&
      [[self window] fieldEditor:NO forObject:nil] != nil)
  {
    // Store the active NSTextField so we can restore the firstResponder after aborting the edit.
    NSTextField* activeTextField = [(NSTextView*)[[self window] firstResponder] delegate];
    // We want to cancel any active text-field edits that might be going on.
    [activeTextField abortEditing];
    [[self window] makeFirstResponder:activeTextField];
  }
}

//
// Override implementation in ExtendedOutlineView so we can check whether an
// item is selected or whether appropriate data is available on the clipboard.
//
- (BOOL)validateMenuItem:(id)aMenuItem
{
  SEL action = [aMenuItem action];

  if (action == @selector(delete:))
    return [[self delegate] numberOfSelectedRows] > 0;

  if (action == @selector(copy:))
    return [super validateMenuItem:aMenuItem] && [[self delegate] numberOfSelectedRows] > 0;

  if (action == @selector(paste:))
    return [super validateMenuItem:aMenuItem] && [[self delegate] canPasteFromPasteboard:[NSPasteboard generalPasteboard]];

  if (action == @selector(cut:))
    return NO; // XXX fix me [super validateMenuItem:aMenuItem] && [[self delegate] numberOfSelectedRows] > 0;
  
  return YES;
}

- (IBAction)delete:(id)aSender
{
  [[self delegate] deleteBookmarks:aSender];
}

- (BOOL)shouldCollapseAutoExpandedItemsForDeposited:(BOOL)deposited
{
  return YES;
}


@end
