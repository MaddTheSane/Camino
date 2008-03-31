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

#import "BookmarkManager.h"
#import "BookmarkMenu.h"
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

- (void)setupBookmarkMenu;
- (void)menuWillBeDisplayed;
- (void)appendBookmarkItem:(BookmarkItem *)inItem buildingSubmenus:(BOOL)buildSubmenus;
- (void)addLastItems;

@end

#pragma mark -

@implementation BookmarkMenu

- (id)initWithTitle:(NSString *)inTitle bookmarkFolder:(BookmarkFolder*)inFolder
{
  if ((self = [super initWithTitle:inTitle])) {
    mFolder = [inFolder retain];
    mDirty  = YES;
    mAppendTabsItem = YES;
    [self setupBookmarkMenu];
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
  [self setupBookmarkMenu];
}

- (void)setupBookmarkMenu
{
  [self setAutoenablesItems:NO];

  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc addObserver:self selector:@selector(bookmarkAdded:)   name:BookmarkFolderAdditionNotification object:nil];
  [nc addObserver:self selector:@selector(bookmarkRemoved:) name:BookmarkFolderDeletionNotification object:nil];
  [nc addObserver:self selector:@selector(bookmarkChanged:) name:BookmarkItemChangedNotification object:nil];

  // register for menu display
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(menuWillDisplay:)
                                               name:NSMenuWillDisplayNotification
                                             object:nil];
}


- (void)setBookmarkFolder:(BookmarkFolder*)inFolder
{
  [mFolder autorelease];
  mFolder = [inFolder retain];
  mDirty = YES;
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

- (void)menuWillDisplay:(NSNotification*)inNotification
{
  if ([self isTargetOfMenuDisplayNotification:[inNotification object]]) {
    [self menuWillBeDisplayed];
  }
}

- (void)menuWillBeDisplayed
{
  [self rebuildMenuIncludingSubmenus:NO];
}

- (void)rebuildMenuIncludingSubmenus:(BOOL)includeSubmenus
{
  if (mDirty) {
    // remove everything after the "before" item
    [self removeItemsAfterItem:mItemBeforeCustomItems];

    NSEnumerator* childEnum = [[mFolder childArray] objectEnumerator];
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

- (void)appendBookmarkItem:(BookmarkItem *)inItem buildingSubmenus:(BOOL)buildSubmenus
{
  NSString *title = [[inItem title] stringByTruncatingTo:MENU_TRUNCATION_CHARS at:kTruncateAtMiddle];
  NSMenuItem *menuItem;

  if ([(Bookmark *)inItem isSeparator])
    menuItem = [[NSMenuItem separatorItem] retain];
  else
    menuItem = [[NSMenuItem alloc] initWithTitle:title action:NULL keyEquivalent:@""];

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

      BookmarkMenu* subMenu = [[BookmarkMenu alloc] initWithTitle:title bookmarkFolder:curFolder];
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

- (void)bookmarkAdded:(NSNotification *)inNotification
{
  BookmarkFolder* parentFolder = [inNotification object];
  if (parentFolder == mFolder)
    mDirty = YES;
}

- (void)bookmarkRemoved:(NSNotification *)inNotification
{
  BookmarkFolder* parentFolder = [inNotification object];
  if (parentFolder == mFolder)
    mDirty = YES;
}

- (void)bookmarkChanged:(NSNotification *)inNotification
{
  BookmarkItem* changedItem = [inNotification object];

  NSNumber* noteChangeFlags = [[inNotification userInfo] objectForKey:BookmarkItemChangedFlagsKey];
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
}

@end

