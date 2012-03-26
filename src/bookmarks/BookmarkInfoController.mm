/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*-
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "NSString+Utils.h"
#import "BookmarkInfoController.h"
#import "Bookmark.h"
#import "BookmarkFolder.h"
#import "BookmarkNotifications.h"

// determined through weeks of trial and error
#define kMaxLengthOfWindowTitle 49


enum EBookmarkInfoViewType {
  eFolderInfoView,
  eBookmarkInfoView
};

@interface BookmarkInfoController(Private)

- (void)commitChanges:(id)sender;
- (void)configureWindowForView:(EBookmarkInfoViewType)inViewType;
- (void)updateUI;
- (void)updateLastVisitField;
- (void)dockMenuChanged:(NSNotification *)aNote;

@end

@implementation BookmarkInfoController

/* BookmarkInfoController singelton */
static BookmarkInfoController* gSharedBookmarkInfoController = nil;

+ (id)sharedBookmarkInfoController
{
  if (!gSharedBookmarkInfoController) {
    gSharedBookmarkInfoController = [[BookmarkInfoController alloc] initWithWindowNibName:@"BookmarkInfoPanel"];
  }
  return gSharedBookmarkInfoController;
}

+ (id)existingSharedBookmarkInfoController
{
  return gSharedBookmarkInfoController;
}

+ (void)closeBookmarkInfoController
{
  if (gSharedBookmarkInfoController)
    [gSharedBookmarkInfoController close];
}

- (id)initWithWindowNibName:(NSString *)windowNibName
{
  if ((self = [super initWithWindowNibName:@"BookmarkInfoPanel"])) {
    //custom field editor lets us undo our changes
    mFieldEditor = [[NSTextView alloc] init];
    [mFieldEditor setAllowsUndo:YES];
    [mFieldEditor setFieldEditor:YES];
  }
  return self;
}

- (void)awakeFromNib
{
  [self setShouldCascadeWindows:NO];
  [[self window] setFrameAutosaveName:@"BookmarkInfoWindow"];
  [mBookmarkShortcutField setFormatter:[[[BookmarkShortcutFormatter alloc] init] autorelease]];
  [mFolderShortcutField setFormatter:[[[BookmarkShortcutFormatter alloc] init] autorelease]];
}

- (void)windowDidLoad
{
  // find the TabViewItems
  mBookmarkInfoTabView = [mTabView tabViewItemAtIndex:[mTabView indexOfTabViewItemWithIdentifier:@"bminfo"]];
  mBookmarkUpdateTabView = [mTabView tabViewItemAtIndex:[mTabView indexOfTabViewItemWithIdentifier:@"bmupdate"]];
  // Generic notifications for Bookmark Client - only care if there's a deletion
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc addObserver:self selector:@selector(bookmarkRemoved:) name:kBookmarkFolderDeletionNotification object:nil];
  // Listen for Dock Menu changes
  [nc addObserver:self selector:@selector(dockMenuChanged:) name:kBookmarkFolderDockMenuChangeNotification object:nil];
}

- (void)dealloc
{
  // this is never called
  if (self == gSharedBookmarkInfoController)
    gSharedBookmarkInfoController = nil;

  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [mBookmarkItem release];
  [mFieldEditor release];

  // balance retains of top-level nib items
  [mBookmarkView release];
  [mFolderView release];
  [super dealloc];
}

// Gets called when the escape key is pressed
- (void)cancel:(id)sender
{
  // revert UI so changes don't get committed
  [self updateUI];
  [[self window] close];
}

// We intercept the tab key in order to let the user tab to/from the bookmark
// description textfield (even though it's a textview)
- (BOOL)textView:(NSTextView *)textView doCommandBySelector:(SEL)command
{
  if (command == @selector(insertTab:)) {
    [[self window] selectNextKeyView:nil];
    return YES;
  }

  if (command == @selector(insertBacktab:)) {
    [[self window] selectPreviousKeyView:nil];
    return YES;
  }

  return NO;
}

// for the NSTextFields
- (void)controlTextDidEndEditing:(NSNotification *)aNotification
{
  [self commitChanges:[aNotification object]];
  [[mFieldEditor undoManager] removeAllActions];
}

// for the NSTextView
- (void)textDidEndEditing:(NSNotification *)aNotification
{
  [self commitChanges:[aNotification object]];
  [[mFieldEditor undoManager] removeAllActions];
}

- (void)windowDidBecomeKey:(NSNotification*)aNotification
{
  if ([[self window] contentView] == mBookmarkView) {
    NSTabViewItem *tabViewItem = [mTabView selectedTabViewItem];
    if (tabViewItem == mBookmarkInfoTabView)
      [[self window] makeFirstResponder:mBookmarkNameField];
    else if (tabViewItem == mBookmarkUpdateTabView)
      [[self window] makeFirstResponder:mClearNumberVisitsButton];
  }
  else {
    [[self window] makeFirstResponder:mFolderNameField];
  }
}

- (void)windowDidResignKey:(NSNotification*)aNotification
{
  [[self window] makeFirstResponder:[self window]]; // why?
  if (![[self window] isVisible])
    [self setBookmark:nil];
}

- (void)windowWillClose:(NSNotification *)aNotification
{
  [self commitChanges:nil];
  [self setBookmark:nil];
}

- (void)commitChanges:(id)changedField
{
  NSTabViewItem *tabViewItem = nil;
  if ([[self window] contentView] == mBookmarkView)
    tabViewItem = [mTabView selectedTabViewItem];

  // could this be any more long-winded?
  BOOL isBookmark;
  if ((isBookmark = [mBookmarkItem isKindOfClass:[Bookmark class]])) {
    // why do we check the parent's type?
    if ([(Bookmark *)mBookmarkItem isSeparator] || ![[mBookmarkItem parent] isKindOfClass:[BookmarkItem class]])
      return;
  }

  if (!changedField) {
    if ((tabViewItem == mBookmarkInfoTabView) && isBookmark) {
      [mBookmarkItem setTitle:[mBookmarkNameField stringValue]];
      [mBookmarkItem setItemDescription:[NSString stringWithString:[mBookmarkDescField stringValue]]];
      [mBookmarkItem setShortcut:[mBookmarkShortcutField stringValue]];
      [(Bookmark *)mBookmarkItem setUrl:[mBookmarkLocationField stringValue]];
    }
    else if ([[self window] contentView] == mFolderView && !isBookmark) {
      [mBookmarkItem setTitle:[mFolderNameField stringValue]];
      [mBookmarkItem setItemDescription:[NSString stringWithString:[mFolderDescField stringValue]]];
      if ([(BookmarkFolder *)mBookmarkItem isGroup])
        [mBookmarkItem setShortcut:[mFolderShortcutField stringValue]];
    }
  }
  else if ((changedField == mBookmarkNameField) || (changedField == mFolderNameField))
    [mBookmarkItem setTitle:[changedField stringValue]];
  else if ((changedField == mBookmarkShortcutField) || (changedField == mFolderShortcutField))
    [mBookmarkItem setShortcut:[changedField stringValue]];
  else if ((changedField == mBookmarkDescField) || (changedField == mFolderDescField))
    [mBookmarkItem setItemDescription:[NSString stringWithString:[changedField stringValue]]];
  else if ((changedField == mBookmarkLocationField) && isBookmark)
    [(Bookmark *)mBookmarkItem setUrl:[changedField stringValue]];

  [[mFieldEditor undoManager] removeAllActions];
}

- (IBAction)tabGroupCheckboxClicked:(id)sender
{
  if ([mBookmarkItem isKindOfClass:[BookmarkFolder class]])
    [(BookmarkFolder *)mBookmarkItem setIsGroup:[sender state] == NSOnState];
}

- (IBAction)dockMenuCheckboxClicked:(id)sender
{
  if ([mBookmarkItem isKindOfClass:[BookmarkFolder class]]) {
    [(BookmarkFolder *)mBookmarkItem setIsDockMenu:([sender state] == NSOnState)];
  }
}

- (IBAction)clearVisitCount:(id)sender
{
  if ([mBookmarkItem isKindOfClass:[Bookmark class]])
    [(Bookmark *)mBookmarkItem clearVisitHistory];
  [mNumberVisitsField setIntValue:0];
}

- (void)setBookmark:(BookmarkItem*)aBookmark
{
  // register for changes on the new bookmark
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc removeObserver:self name:kBookmarkItemChangedNotification object:nil];

  [aBookmark retain];
  [mBookmarkItem release];
  mBookmarkItem = aBookmark;

  [self updateUI];
  [nc addObserver:self selector:@selector(bookmarkChanged:) name:kBookmarkItemChangedNotification object:mBookmarkItem];
}

- (void)configureWindowForView:(EBookmarkInfoViewType)inViewType
{
  NSView* newView = nil;

  switch (inViewType) {
    case eFolderInfoView:
      newView = mFolderView;
      break;

    case eBookmarkInfoView:
      newView = mBookmarkView;
      break;
  }

  // Swap view if necessary
  if ([[self window] contentView] != newView)
    [[self window] setContentView:newView];
}

- (void)updateUI
{
  [self window]; // make sure the window has loaded

  // setup for bookmarks
  if (mBookmarkItem && [mBookmarkItem isKindOfClass:[Bookmark class]]) {
    [self configureWindowForView:eBookmarkInfoView];
    [mBookmarkNameField setStringValue:[mBookmarkItem title]];
    [mBookmarkDescField setStringValue:[mBookmarkItem itemDescription]];
    [mBookmarkShortcutField setStringValue:[mBookmarkItem shortcut]];
    [mBookmarkLocationField setStringValue:[(Bookmark *)mBookmarkItem url]];
    [mNumberVisitsField setIntValue:[(Bookmark *)mBookmarkItem visitCount]];
    [self updateLastVisitField];

    // if its parent is a smart folder or it's a menu separator,
    // we turn off all the fields.  if it isn't, then we turn them all on
    id parent = [mBookmarkItem parent];
    BOOL canEdit = ([parent isKindOfClass:[BookmarkItem class]]) &&
                   (![parent isSmartFolder]) &&     // bogus check. why don't we ask the bookmark itself?
                   (![(Bookmark *)mBookmarkItem isSeparator]);
    [mBookmarkNameField setEditable:canEdit];
    [mBookmarkDescField setEditable:canEdit];
    [mBookmarkShortcutField setEditable:canEdit];
    [mBookmarkLocationField setEditable:canEdit];
  }
  // Folders
  else if (mBookmarkItem && [mBookmarkItem isKindOfClass:[BookmarkFolder class]]) {
    [self configureWindowForView:eFolderInfoView];

    [mTabgroupCheckbox setState:[(BookmarkFolder *)mBookmarkItem isGroup] ? NSOnState : NSOffState];

    [mFolderNameField setStringValue:[mBookmarkItem title]];
    [mFolderShortcutField setStringValue:[mBookmarkItem shortcut]];
    [mFolderDescField setStringValue:[mBookmarkItem itemDescription]];

    // we can unselect dock menu - we have a fallback default
    if ([(BookmarkFolder *)mBookmarkItem isDockMenu])
      [mDockMenuCheckbox setState:NSOnState];
    else
      [mDockMenuCheckbox setState:NSOffState];
  }
  else {
    [self configureWindowForView:eBookmarkInfoView];
    // clear stuff
    [mBookmarkNameField setStringValue:@""];
    [mBookmarkDescField setStringValue:@""];
    [mBookmarkShortcutField setStringValue:@""];
    [mBookmarkLocationField setStringValue:@""];

    [mBookmarkNameField setEditable:NO];
    [mBookmarkDescField setEditable:NO];
    [mBookmarkShortcutField setEditable:NO];
    [mBookmarkLocationField setEditable:NO];

    [mNumberVisitsField setIntValue:0];
    [mLastVisitField setStringValue:@""];
  }

  // Header
  if (mBookmarkItem) {
    NSMutableString *truncatedTitle = [NSMutableString stringWithString:[mBookmarkItem title]];
    [truncatedTitle truncateTo:kMaxLengthOfWindowTitle at:kTruncateAtEnd];
    NSString* infoForString = [NSString stringWithFormat:NSLocalizedString(@"BookmarkInfoTitle", nil), truncatedTitle];
    [[self window] setTitle:infoForString];
  }
  else {
    [[self window] setTitle:NSLocalizedString(@"BlankBookmarkInfoTitle", nil)];
  }
}

- (void)updateLastVisitField
{
  NSDate* lastVisit = [(Bookmark*)mBookmarkItem lastVisit];
  NSString* lastVisitString;

  if (!lastVisit) {
    lastVisitString = NSLocalizedString(@"BookmarkVisitedNever", nil);
  }
  else {
    NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
    [dateFormatter setDateStyle:NSDateFormatterLongStyle];
    [dateFormatter setTimeStyle:NSDateFormatterLongStyle];
    lastVisitString = [dateFormatter stringFromDate:lastVisit];
    [dateFormatter release];
  }

  [mLastVisitField setStringValue:lastVisitString];
}

- (BookmarkItem *)bookmark
{
  return mBookmarkItem;
}


- (NSText *)windowWillReturnFieldEditor:(NSWindow *)aPanel toObject:(id)aObject
{
  return mFieldEditor;
}

#pragma mark -

- (void)bookmarkAdded:(NSNotification *)aNote
{
}

- (void)bookmarkRemoved:(NSNotification *)aNote
{
  BookmarkItem *item = [[aNote userInfo] objectForKey:kBookmarkFolderChildKey];
  if ((item == [self bookmark]) && ![item parent]) {
    [self setBookmark:nil];
    [[self window] close];
  }
}

// We're only registering for our current bookmark,
// so no need to make checks to see if it's the right one.
- (void)bookmarkChanged:(NSNotification *)aNote
{
  BookmarkItem *item = [aNote object];
  if ([item isKindOfClass:[Bookmark class]]) {
    [mNumberVisitsField setIntValue:[(Bookmark *)item visitCount]];
    [self updateLastVisitField];
  }
}

- (void)dockMenuChanged:(NSNotification *)aNote {
  BookmarkItem *bookmark = [self bookmark];
  if([bookmark isKindOfClass:[BookmarkFolder class]]) {
    [mDockMenuCheckbox setState:([(BookmarkFolder *)bookmark isDockMenu] ? NSOnState : NSOffState)];
  }
}

@end
