/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "NSString+Utils.h"

#import "BookmarkFolder.h"
#import "Bookmark.h"
#import "BookmarkManager.h"

#import "BookmarkViewController.h"
#import "UserDefaults.h"

#import "AddBookmarkDialogController.h"

NSString* const kAddBookmarkItemURLKey        = @"url";
NSString* const kAddBookmarkItemTitleKey      = @"title";
NSString* const kAddBookmarkItemPrimaryTabKey = @"primary";

static NSString* BookmarkUrlForItem(NSDictionary* inItem) {
  return [inItem objectForKey:kAddBookmarkItemURLKey];
}

static NSString* BookmarkTitleForItem(NSDictionary* inItem) {
  NSString* bookmarkTitle = [inItem objectForKey:kAddBookmarkItemTitleKey];
  bookmarkTitle  = [bookmarkTitle stringByReplacingCharactersInSet:[NSCharacterSet controlCharacterSet] withString:@" "];
  if (!bookmarkTitle || ![bookmarkTitle length])
    bookmarkTitle = BookmarkUrlForItem(inItem);
  return bookmarkTitle;
}

static NSDictionary* PrimaryBookmarkItem(NSArray* inItems) {
  NSEnumerator* itemsEnum = [inItems objectEnumerator];
  id curItem;
  while ((curItem = [itemsEnum nextObject])) {
    if ([[curItem objectForKey:kAddBookmarkItemPrimaryTabKey] boolValue])
      return curItem;
  }

  if ([inItems count] > 0)
    return [inItems objectAtIndex:0];

  return nil;
}

#pragma mark -

@interface AddBookmarkDialogController(Private)

- (void)sheetDidEnd:(NSWindow*)sheet
         returnCode:(int)returnCode
        contextInfo:(void*)contextInfo;

- (void)updateTitle:(BOOL)isTabGroup;

- (void)buildBookmarksFolderPopup;
- (void)createBookmarks;

@end

#pragma mark -

@implementation AddBookmarkDialogController

+ (AddBookmarkDialogController*)controller {
  return [[[AddBookmarkDialogController alloc] initWithWindowNibName:@"AddBookmark"] autorelease];
}

- (id)initWithWindowNibName:(NSString*)windowNibName
{
  if ((self = [super initWithWindowNibName:windowNibName])) {
    // Remember the last bookmark folder used in the dialog's popup menu
    NSString* uuid = [[NSUserDefaults standardUserDefaults] objectForKey:USER_DEFAULTS_LAST_SELECTED_BM_FOLDER];
    if (uuid && ![uuid isEqualToString:@""]) {
      BookmarkFolder* foundFolder = (BookmarkFolder*)[[[BookmarkManager sharedBookmarkManager] bookmarkRoot] itemWithUUID:uuid];
      if (foundFolder)
        [self setDefaultParentFolder:foundFolder andIndex:-1];
    }
  }
  return self;
}

- (void)dealloc
{
  [mInitialParentFolder release];
  [mDefaultTitle release];
  [mBookmarkItems release];

  [super dealloc];
}

- (IBAction)confirmAddBookmark:(id)sender
{
  BookmarkItem* selectedItem = [[mParentFolderPopup selectedItem] representedObject];
  [[NSUserDefaults standardUserDefaults] setObject:[selectedItem UUID] forKey:USER_DEFAULTS_LAST_SELECTED_BM_FOLDER];
  [self setDefaultParentFolder:(BookmarkFolder*)selectedItem andIndex:-1];

  [self createBookmarks];

  [[self window] orderOut:self];
  [NSApp endSheet:[self window] returnCode:1];  // releases self
}

- (IBAction)cancelAddBookmark:(id)sender
{
  [[self window] orderOut:self];
  [NSApp endSheet:[self window] returnCode:1];  // releases self
}

- (IBAction)parentFolderChanged:(id)sender
{
  mInitialParentFolderIndex = -1;
}

- (IBAction)toggleTabGroup:(id)sender
{
  BOOL isTabGroup = ([mTabGroupCheckbox state] == NSOnState);
  [self updateTitle:isTabGroup];
}

- (void)makeTabGroup:(BOOL)isTabGroup
{
  [mTabGroupCheckbox setState:(isTabGroup ? NSOnState : NSOffState)];
  [self updateTitle:isTabGroup];
}

- (void)updateTitle:(BOOL)isTabGroup
{
  NSString* defaultGroupTitle = [NSString stringWithFormat:NSLocalizedString(@"defaultTabGroupTitle", @"[%d tabs] %@"),
                                                           [mBookmarkItems count],
                                                           mDefaultTitle];

  // If the title is unedited, update to the default name
  if ([[mTitleField stringValue] isEqualToString:mDefaultTitle] ||
      [[mTitleField stringValue] isEqualToString:defaultGroupTitle])
    [mTitleField setStringValue:(isTabGroup ? defaultGroupTitle : mDefaultTitle)];
}

- (void)setDefaultTitle:(NSString*)aString
{
  [mDefaultTitle release];
  mDefaultTitle = [aString retain];
}

// -1 index means put at end
- (void)setDefaultParentFolder:(BookmarkFolder*)inFolder andIndex:(int)inIndex
{
  [mInitialParentFolder release];
  mInitialParentFolder = [inFolder retain];
  mInitialParentFolderIndex = inIndex;
}

- (void)setBookmarkViewController:(BookmarkViewController*)inBMViewController
{
  mBookmarkViewController = inBMViewController;
}

- (void)showDialogWithLocationsAndTitles:(NSArray*)inItems isFolder:(BOOL)inIsFolder onWindow:(NSWindow*)inWindow
{
  [self window];  // force nib loading

  if (!inIsFolder && [inItems count] == 0)
    return;

  [mBookmarkItems release];
  mBookmarkItems = [inItems retain];

  if (inIsFolder) {
    [self setDefaultTitle:NSLocalizedString(@"NewBookmarkFolder", nil)];
    [mTabGroupCheckbox removeFromSuperview];
    mTabGroupCheckbox = nil;
  }
  else {
    [self setDefaultTitle:BookmarkTitleForItem(PrimaryBookmarkItem(inItems))];
    if ([inItems count] == 1) {
      [mTabGroupCheckbox setEnabled:NO];
    }
  }

  [mTitleField setStringValue:mDefaultTitle];

  [self buildBookmarksFolderPopup];

  [self retain];  // will release when dismissed in sheetDidEnd:...
  [NSApp beginSheet:[self window]
     modalForWindow:inWindow
      modalDelegate:self
     didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
        contextInfo:nil];
}

- (void)sheetDidEnd:(NSWindow*)sheet
         returnCode:(int)returnCode
        contextInfo:(void*)contextInfo {
  [self release];
}

#pragma mark -

- (void)buildBookmarksFolderPopup
{
  BookmarkManager* bookmarkManager = [BookmarkManager sharedBookmarkManager];
  [mParentFolderPopup removeAllItems];
  [[bookmarkManager bookmarkRoot] buildFlatFolderList:[mParentFolderPopup menu] depth:1];

  BookmarkFolder* initialFolder = mInitialParentFolder;
  if (!initialFolder)
    initialFolder = [bookmarkManager lastUsedBookmarkFolder];

  int initialItemIndex = [[mParentFolderPopup menu] indexOfItemWithRepresentedObject:initialFolder];
  if (initialItemIndex != -1)
    [mParentFolderPopup selectItemAtIndex:initialItemIndex];

  [mParentFolderPopup synchronizeTitleAndSelectedItem];
}

- (void)createBookmarks
{
  BookmarkFolder* parentFolder = [[mParentFolderPopup selectedItem] representedObject];
  NSString*       titleString  = [mTitleField stringValue];

  BookmarkItem* newItem = nil;
  unsigned int  insertPosition = (mInitialParentFolderIndex != -1) ? mInitialParentFolderIndex : [parentFolder count];

  // When creating Bookmark items, set the last-visited time to the time that
  // the bookmark was created.  TODO: use page load time.
  NSDate* now = [NSDate date];

  if (!mTabGroupCheckbox) {
    // No checkbox means to create a folder
    newItem = [parentFolder addBookmarkFolder:titleString inPosition:insertPosition isGroup:NO];
  }
  else if (([mBookmarkItems count] > 1) &&
           ([mTabGroupCheckbox state] == NSOnState)) {
    // bookmark all tabs
    BookmarkFolder* newGroup = [parentFolder addBookmarkFolder:titleString inPosition:insertPosition isGroup:YES];

    unsigned int numItems = [mBookmarkItems count];
    for (unsigned int i = 0; i < numItems; i++) {
      id curItem = [mBookmarkItems objectAtIndex:i];
      NSString* itemURL   = BookmarkUrlForItem(curItem);
      NSString* itemTitle = BookmarkTitleForItem(curItem);

      newItem = [Bookmark bookmarkWithTitle:itemTitle
                                        url:itemURL
                                  lastVisit:now];
      [newGroup insertChild:newItem atIndex:i isMove:NO];
    }
    [[BookmarkManager sharedBookmarkManager] bookmarkItemsAdded:[NSArray arrayWithObject:newGroup]];
  }
  else {
    // Bookmark a single item
    id curItem = PrimaryBookmarkItem(mBookmarkItems);

    NSString* itemURL = BookmarkUrlForItem(curItem);

    newItem = [Bookmark bookmarkWithTitle:titleString
                                      url:itemURL
                                lastVisit:now];
    [parentFolder insertChild:newItem atIndex:insertPosition isMove:NO];
    [[BookmarkManager sharedBookmarkManager] bookmarkItemsAdded:[NSArray arrayWithObject:newItem]];
  }

  [mBookmarkViewController selectAndRevealItem:newItem byExtendingSelection:NO];
  [[BookmarkManager sharedBookmarkManager] setLastUsedBookmarkFolder:parentFolder];
}

@end
