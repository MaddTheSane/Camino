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
*   David Hyatt <hyatt@netscape.com> (Original Author)
*/

#import "NSString+Utils.h"
#import "NSPasteboard+Utils.h"

#import "BookmarksButton.h"

#include "nsCOMPtr.h"
#include "nsIContent.h"
#include "nsString.h"
#include "nsCRT.h"

#import "DraggableImageAndTextCell.h"

#import "BookmarkInfoController.h"
#import "BookmarksService.h"
#import "BookmarksDataSource.h"
#import "BookmarksMenu.h"

#import "BrowserWindowController.h"
#import "MainController.h"

@implementation BookmarksButton

- (id)initWithFrame:(NSRect)frame
{
  if ( (self = [super initWithFrame:frame]) )
  {
    DraggableImageAndTextCell* newCell = [[[DraggableImageAndTextCell alloc] init] autorelease];
    [newCell setDraggable:YES];
    [self setCell:newCell];

    [self setBezelStyle: NSRegularSquareBezelStyle];
    [self setButtonType: NSMomentaryChangeButton];
    [self setBordered: NO];
    [self setImagePosition: NSImageLeft];
    [self setRefusesFirstResponder: YES];
    [self setFont: [NSFont labelFontOfSize: 11.0]];
  }
  return self;
}

-(id)initWithFrame:(NSRect)frame item:(BookmarkItem*)item
{
  if ( (self = [self initWithFrame:frame]) )
  {
    [self setItem:item];
  }
  return self;
}

-(IBAction)openBookmark:(id)aSender
{
  // Now load the URL in the window.
  BrowserWindowController* brController = [[self window] windowController];

  // See if we're a group.
  if ([mBookmarkItem isGroup])
  {
    NSArray* groupURLs = [[BookmarksManager sharedBookmarksManager] getBookmarkGroupURIs:mBookmarkItem];
    [brController openTabGroup:groupURLs replaceExistingTabs:YES];
    return;
  }

  // if the command key is down, follow the command-click pref
  if (([[NSApp currentEvent] modifierFlags] & NSCommandKeyMask) &&
      [[PreferenceManager sharedInstance] getBooleanPref:"browser.tabs.opentabfor.middleclick" withSuccess:NULL])
  {
    [self openBookmarkInNewTab:aSender];
    return;
  }

  [brController loadURL:[mBookmarkItem url] referrer:nil activate:YES];
}

-(IBAction)openBookmarkInNewTab:(id)aSender
{
  NSString* hrefStr = [mBookmarkItem url];

  BOOL loadInBackground = [[PreferenceManager sharedInstance] getBooleanPref:"browser.tabs.loadInBackground" withSuccess:NULL];

  BrowserWindowController* brController = [[self window] windowController];
  [brController openNewTabWithURL: hrefStr referrer:nil loadInBackground: loadInBackground];
}

-(IBAction)openBookmarkInNewWindow:(id)aSender
{
  BOOL loadInBackground = [[PreferenceManager sharedInstance] getBooleanPref:"browser.tabs.loadInBackground" withSuccess:NULL];

  BrowserWindowController* brController = [[self window] windowController];
  if ([mBookmarkItem isGroup]) 
    [brController openNewWindowWithGroup:[mBookmarkItem contentNode] loadInBackground: loadInBackground];
  else
    [brController openNewWindowWithURL:[mBookmarkItem url] referrer: nil loadInBackground: loadInBackground];
}

-(IBAction)showBookmarkInfo:(id)aSender
{
  BookmarkInfoController *bic = [BookmarkInfoController sharedBookmarkInfoController]; 

  [bic showWindow:bic];
  [bic setBookmark:mBookmarkItem];
}

-(IBAction)deleteBookmarks: (id)aSender
{
	//close the BIC if it was looking at us - if it's already closed, it's not looking at us.
	BookmarkInfoController *bic = [BookmarkInfoController sharedBookmarkInfoController];
	if (([bic bookmark] == mBookmarkItem))
    [bic close];

  [mBookmarkItem remove];
  mBookmarkItem = nil;
}

-(IBAction)addFolder:(id)aSender
{
  BookmarksManager* 		bmManager = [BookmarksManager sharedBookmarksManager];
  BookmarksDataSource* 	bmDataSource = [(BrowserWindowController*)[[self window] delegate] bookmarksDataSource];
  BookmarkItem* 				toolbarRootItem = [bmManager getWrapperForContent:[bmManager getToolbarRoot]];
  [bmDataSource addBookmark:aSender withParent:toolbarRootItem isFolder:YES URL:@"" title:@""]; 
}

-(void)drawRect:(NSRect)aRect
{
  [super drawRect: aRect];
}

-(NSMenu*)menuForEvent:(NSEvent*)aEvent
{
  // Make a copy of the context menu but change it to target us
  // FIXME - this will stop to work as soon as we add items to the context menu
  // that have different targets. In that case, we probably should add code to
  // BookmarksToolbar that manages the context menu for the CHBookmarksButtons.
  
  NSMenu* myMenu = [[[self superview] menu] copy];
  [[myMenu itemArray] makeObjectsPerformSelector:@selector(setTarget:) withObject: self];
  [myMenu update];
  return [myMenu autorelease];
}

-(BOOL)validateMenuItem:(NSMenuItem*)aMenuItem
{
  if (!mBookmarkItem)
    return NO;
  
  BOOL isBookmark = [mBookmarkItem isFolder] == NO;
  BOOL isGroup = [mBookmarkItem isGroup];

  if (([aMenuItem action] == @selector(openBookmarkInNewWindow:))) {
    // Bookmarks and Bookmark Groups can be opened in a new window
    return (isBookmark || isGroup);
  }
  else if (([aMenuItem action] == @selector(openBookmarkInNewTab:))) {
    // Only Bookmarks can be opened in new tabs
    BrowserWindowController* brController = [[self window] windowController];
    return isBookmark && [brController newTabsAllowed];
  }
  return YES;
}

-(void)mouseDown:(NSEvent*)aEvent
{
  // pop up a "context menu" on folders showing their contents. we check
  // for single click to fix issues with dblclicks (bug 162367)
  if (mBookmarkItem && mIsFolder && [aEvent clickCount] == 1)
  {
    NSMenu* popupMenu = [[NSMenu alloc] init];
    // make a temporary BookmarksMenu to build the menu
    BookmarksMenu* bmMenu = [[BookmarksMenu alloc] initWithMenu:popupMenu firstItem:0 rootContent:[mBookmarkItem contentNode] watchedFolder:eBookmarksFolderNormal];
    [NSMenu popUpContextMenu: popupMenu withEvent: aEvent forView: self];
    
    [bmMenu release];
    [popupMenu release];
  }
  else
    [super mouseDown:aEvent];
}

- (void)setItem:(BookmarkItem*)inItem
{
  if (!inItem) return;
  
  mBookmarkItem = inItem;		// we don't hold a ref to this.
  
  NSImage* bookmarkImage = [[BookmarksManager sharedBookmarksManager] createIconForBookmarkItem:mBookmarkItem useSiteIcon:YES];
  if ([mBookmarkItem isGroup])
  {
    mIsFolder = NO;
    [self setImage: bookmarkImage];
    [self setAction: @selector(openBookmark:)];
    [self setTarget: self];
  }
  else if ([mBookmarkItem isFolder])
  {
    [self setImage: bookmarkImage];
    mIsFolder = YES;
  }
  else
  {
    mIsFolder = NO;
    [self setImage: bookmarkImage];
    [self setAction: @selector(openBookmark:)];
    [self setTarget: self];
    [self setToolTip: [mBookmarkItem url]];
  }
  
  [self setTitle: [mBookmarkItem name]];
}

- (BookmarkItem*)getItem
{
  return mBookmarkItem;
}

- (unsigned int)draggingSourceOperationMaskForLocal:(BOOL)localFlag
{
  if (localFlag)
    return (NSDragOperationCopy | NSDragOperationGeneric | NSDragOperationMove);
  
	return (NSDragOperationDelete | NSDragOperationGeneric);
}

- (void) mouseDragged: (NSEvent*) aEvent
{  
  if ([[mBookmarkItem url] length] == 0)
    return;

  NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
  [pboard declareURLPasteboardWithAdditionalTypes:[NSArray arrayWithObjects:@"MozBookmarkType", nil] owner:self];

  NSString     *url 	= [mBookmarkItem url];
  NSString     *title = [mBookmarkItem name];
  NSString     *cleanedTitle = [title stringByReplacingCharactersInSet:[NSCharacterSet controlCharacterSet] withString:@" "];

  // MozBookmarkType
  nsCOMPtr<nsIContent> content = [mBookmarkItem contentNode];
  if (content)
  {
    PRUint32 contentID;
    content->GetContentID(&contentID);  
    NSArray *itemsArray = [NSArray arrayWithObjects:[NSNumber numberWithInt: contentID], nil];
    [pboard setPropertyList: itemsArray forType: @"MozBookmarkType"];  
  }
  
  [pboard setDataForURL:url title:cleanedTitle];

  [self dragImage: [MainController createImageForDragging:[self image] title:title]
                    at: NSMakePoint(0,NSHeight([self bounds])) offset: NSMakeSize(0,0)
                    event: aEvent pasteboard: pboard source: self slideBack: YES];
}


- (void)draggedImage:(NSImage *)anImage endedAt:(NSPoint)aPoint operation:(NSDragOperation)operation
{
  if (operation == NSDragOperationDelete)
  {
    NSArray* contentIds = nil;
    NSPasteboard* pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
    contentIds = [pboard propertyListForType: @"MozBookmarkType"];
    if (contentIds)
    {
      for (unsigned int i = 0; i < [contentIds count]; ++i)
      {
        BookmarkItem* item = BookmarksService::GetWrapperFor([[contentIds objectAtIndex:i] unsignedIntValue]);
        [item remove];
      }
    }
  }

}

@end
