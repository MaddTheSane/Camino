/* ***** BEGIN LICENSE BLOCK *****
 * Version: MPL 1.1/GPL 2.0/LGPL 2.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Original Code is Chimera code.
 *
 * The Initial Developer of the Original Code is
 * Netscape Communications Corporation.
 * Portions created by the Initial Developer are Copyright (C) 2002
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *   Simon Fraser <smfr@smfr.org>
 *   David Haas   <haasd@cae.wisc.edu>
 *
 * Alternatively, the contents of this file may be used under the terms of
 * either the GNU General Public License Version 2 or later (the "GPL"), or
 * the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
 * in which case the provisions of the GPL or the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of either the GPL or the LGPL, and not to allow others to
 * use your version of this file under the terms of the MPL, indicate your
 * decision by deleting the provisions above and replace them with the notice
 * and other provisions required by the GPL or the LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the MPL, the GPL or the LGPL.
 *
 * ***** END LICENSE BLOCK ***** */

#import "BookmarkMenu.h"

#import "BookmarkManager.h"
#import "BookmarkNotifications.h"
#import "BookmarkFolder.h"
#import "Bookmark.h"

#import "PreferenceManager.h"

#import "NSString+Utils.h"
#import "NSMenu+Utils.h"

// Definitions
#define MENU_TRUNCATION_CHARS 60

// used to determine if we've already added "Open In Tabs" to a menu. This will be on
// the "Open In Tabs" item, not the separator.
const long kOpenInTabsTag = 0xBEEF;

@interface BookmarkMenu(Private)

- (void)setUpBookmarkMenu;
- (void)appendBookmarkItem:(BookmarkItem *)inItem buildingSubmenus:(BOOL)buildSubmenus;
- (void)addLastItems;
- (void)bookmarkListChanged:(NSNotification *)inNotification;

@end

#pragma mark -

@implementation BookmarkMenu

- (id)initWithTitle:(NSString *)inTitle bookmarkFolder:(BookmarkFolder*)inFolder
{
  if ((self = [super initWithTitle:inTitle])) {
    [self setBookmarkFolder:inFolder];
    mAppendTabsItem = YES;
    [self setUpBookmarkMenu];
    // Set us up to receive menuNeedsUpdate: callbacks. We do this here rather
    // than setUpBookmarkMenu because we don't want to change the delegate
    // for the top-level bookmark menu (which comes from the nib)
    [self setDelegate:self];
  }
  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [mFolder release];
  [super dealloc];
}

- (void)awakeFromNib
{
  // the main bookmarks menu, and dock menu are in the nib
  mDirty = YES;
  // default to not appending the tabs item for nib-based menus
  mAppendTabsItem = NO;
  [self setUpBookmarkMenu];
}

- (void)setUpBookmarkMenu
{
  [self setAutoenablesItems:NO];

  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  // TODO: Move this once the boomark notifications are refactored.
  [nc addObserver:self
         selector:@selector(bookmarkChanged:)
             name:kBookmarkItemChangedNotification
           object:nil];
}


- (void)setBookmarkFolder:(BookmarkFolder*)inFolder
{
  [mFolder autorelease];
  mFolder = [inFolder retain];
  mDirty = YES;

  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc removeObserver:self name:kBookmarkFolderAdditionNotification object:nil];
  [nc removeObserver:self name:kBookmarkFolderDeletionNotification object:nil];
  if (mFolder) {
    [nc addObserver:self
           selector:@selector(bookmarkListChanged:)
               name:kBookmarkFolderAdditionNotification
             object:mFolder];
    [nc addObserver:self
           selector:@selector(bookmarkListChanged:)
               name:kBookmarkFolderDeletionNotification
             object:mFolder];
  }
}

- (BookmarkFolder*)bookmarkFolder
{
  return mFolder;
}

- (void)setAppendOpenInTabs:(BOOL)inAppend
{
  mAppendTabsItem = inAppend;
}

- (void)setItemBeforeCustomItems:(NSMenuItem*)inItem
{
  mItemBeforeCustomItems = inItem;
}

- (NSMenuItem*)itemBeforeCustomItems
{
  return mItemBeforeCustomItems;
}

#pragma mark -

- (void)menuNeedsUpdate:(NSMenu*)menu
{
  // Contrary to what the docs say, this method is also called whenever a key
  // equivalent is triggered anywhere in the application, so we only update
  // the menu if we are actually doing menu tracking.
  if ([NSMenu currentyInMenuTracking])
    [self rebuildMenuIncludingSubmenus:NO];
}

- (void)rebuildMenuIncludingSubmenus:(BOOL)includeSubmenus
{
  if (mDirty) {
    // remove everything after the "before" item
    [self removeItemsAfterItem:mItemBeforeCustomItems];

    NSEnumerator* childEnum = [[mFolder children] objectEnumerator];
    BookmarkItem* curItem;
    while ((curItem = [childEnum nextObject])) {
      [self appendBookmarkItem:curItem buildingSubmenus:includeSubmenus];
    }

    [self addLastItems];
    mDirty = NO;
  }
  else if (includeSubmenus) {  // even if we're not dirty, submenus might be
    int firstCustomItemIndex = [self indexOfItem:mItemBeforeCustomItems] + 1;

    for (int i = firstCustomItemIndex; i < [self numberOfItems]; i++) {
      NSMenuItem* curItem = [self itemAtIndex:i];
      if ([curItem hasSubmenu] && [[curItem submenu] isKindOfClass:[BookmarkMenu class]]) {
        [(BookmarkMenu*)[curItem submenu] rebuildMenuIncludingSubmenus:includeSubmenus];
      }
    }
  }
}

static NSString* GetMenuItemTitleForBookmark(BookmarkItem* item)
{
  NSString* title = [item title];
  if ([title length] > 0)
    return [title stringByTruncatingTo:MENU_TRUNCATION_CHARS at:kTruncateAtMiddle];

  if ([item isKindOfClass:[Bookmark class]]) {
    Bookmark* bookmark = (Bookmark*)item;
    NSString* url = [bookmark url];
    if ([url length] > 0)
      return [url stringByTruncatingTo:MENU_TRUNCATION_CHARS at:kTruncateAtEnd];
  }

  // Where did we get a bookmark without a title, description, or URL?
  return @"";
}

- (void)appendBookmarkItem:(BookmarkItem *)inItem buildingSubmenus:(BOOL)buildSubmenus
{
  NSMenuItem *menuItem;

  if ([(Bookmark *)inItem isSeparator]) {
    menuItem = [[NSMenuItem separatorItem] retain];
  } else {
    NSString* menuItemTitle = GetMenuItemTitleForBookmark(inItem);
    menuItem = [[NSMenuItem alloc] initWithTitle:menuItemTitle action:NULL keyEquivalent:@""];
  }

  [menuItem setRepresentedObject:inItem];
  [self addItem:menuItem];

  if ([inItem isKindOfClass:[Bookmark class]] && ![(Bookmark *)inItem isSeparator]) { // normal bookmark
    [menuItem setTarget:[NSApp delegate]];
    [menuItem setAction:@selector(openMenuBookmark:)];
    [menuItem setImage:[inItem icon]];

    [self addCommandKeyAlternatesForMenuItem:menuItem];
  }
  else if ([inItem isKindOfClass:[BookmarkFolder class]]) {
    BookmarkFolder* curFolder = (BookmarkFolder*)inItem;
    if (![curFolder isGroup]) {  // normal folder
      [menuItem setImage:[inItem icon]];

      NSString* menuItemTitle = GetMenuItemTitleForBookmark(inItem);
      BookmarkMenu* subMenu = [[BookmarkMenu alloc] initWithTitle:menuItemTitle bookmarkFolder:curFolder];

      // if building "deep", build submenu; otherwise it will get built lazily on display
      if (buildSubmenus)
        [subMenu rebuildMenuIncludingSubmenus:buildSubmenus];

      [menuItem setSubmenu:subMenu];
      [subMenu release];
    }
    else {  // group
      [menuItem setTarget:[NSApp delegate]];
      [menuItem setAction:@selector(openMenuBookmark:)];
      [menuItem setImage:[inItem icon]];

      [self addCommandKeyAlternatesForMenuItem:menuItem];
    }
  }

  [menuItem release];
}

- (void)addLastItems
{
  // add the "Open In Tabs" option to open all items in this subfolder
  if (mAppendTabsItem && [[mFolder childURLs] count] > 0) {
    [self addItem:[NSMenuItem separatorItem]];

    NSMenuItem* menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Open in Tabs", nil)
                                                       action:@selector(openMenuBookmark:)
                                                keyEquivalent:@""];
    NSMenuItem* altMenuItem;
    if ([[PreferenceManager sharedInstance] getBooleanPref:kGeckoPrefOpenTabsForMiddleClick withSuccess:NULL])
      altMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Open in New Tabs", nil)
                                               action:@selector(openMenuBookmark:)
                                        keyEquivalent:@""];
    else
      altMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Open in Tabs in New Window", nil)
                                               action:@selector(openMenuBookmark:)
                                        keyEquivalent:@""];

    [menuItem setTarget:[NSApp delegate]];
    [menuItem setTag:kOpenInTabsTag];
    [menuItem setRepresentedObject:mFolder];
    [menuItem setKeyEquivalentModifierMask:0]; //Needed since by default NSMenuItems have NSCommandKeyMask

    [altMenuItem setTarget:[NSApp delegate]];
    [altMenuItem setTag:kOpenInTabsTag];
    [altMenuItem setRepresentedObject:mFolder];
    [altMenuItem setKeyEquivalentModifierMask:NSCommandKeyMask];
    [altMenuItem setAlternate:YES];

    [self addItem:menuItem];
    [menuItem release];
    [self addItem:altMenuItem];
    [altMenuItem release];
  }
}

#pragma mark -

- (void)bookmarkListChanged:(NSNotification *)inNotification
{
  mDirty = YES;
}

- (void)bookmarkChanged:(NSNotification *)inNotification
{
  BookmarkItem* changedItem = [inNotification object];

  NSNumber* noteChangeFlags = [[inNotification userInfo] objectForKey:kBookmarkItemChangedFlagsKey];
  unsigned int changeFlags = kBookmarkItemEverythingChangedMask;
  if (noteChangeFlags)
    changeFlags = [noteChangeFlags unsignedIntValue];

  // first, see if it's a notification that this folder's children have changed
  if ((changedItem == mFolder) && (changeFlags & kBookmarkItemChildrenChangedMask)) {
    mDirty = YES;
    return;
  }

  // any other change is only interesting if it's to one of this folder's children
  if ([changedItem parent] != mFolder)
    return;

  // find the item
  int itemIndex = [self indexOfItemWithRepresentedObject:changedItem];
  if (itemIndex == -1)
    return;

  // if it changed to or from a separator (or everything changed), just do a rebuild later
  if (changeFlags & kBookmarkItemStatusChangedMask) {
    mDirty = YES;
    return;
  }

  NSMenuItem* theMenuItem = [self itemAtIndex:itemIndex];
  if (changeFlags & kBookmarkItemTitleChangedMask) {
    NSString *title = [[changedItem title] stringByTruncatingTo:MENU_TRUNCATION_CHARS at:kTruncateAtMiddle];
    [theMenuItem setTitle:title];
  }

  if (changeFlags & kBookmarkItemIconChangedMask)
    [theMenuItem setImage:[changedItem icon]];

  if ((changeFlags & kBookmarkItemTitleChangedMask) || (changeFlags & kBookmarkItemIconChangedMask))
    [self updateCommandKeyAlternatesForMenuItem:theMenuItem];
}

@end

