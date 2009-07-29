/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*-
 *
 * ***** BEGIN LICENSE BLOCK *****
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
 * The Original Code is the Mozilla browser.
 *
 * The Initial Developer of the Original Code is
 * Netscape Communications Corporation.
 * Portions created by the Initial Developer are Copyright (C) 2002
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *   Joe Hewitt <hewitt@netscape.com> (Original Author)
 *   Stuart Morgan <stuart.morgan@alumni.case.edu>
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

#import "HistoryMenu.h"

#import "NSImage+Utils.h"
#import "NSString+Utils.h"
#import "NSMenu+Utils.h"

#import "MainController.h"
#import "BrowserWindowController.h"
#import "BrowserWrapper.h"
#import "CHBrowserService.h"
#import "PreferenceManager.h"

#import "HistoryItem.h"
#import "HistoryDataSource.h"

#include <algorithm>


// the maximum number of history entry menuitems to display
static const int kMaxNumHistoryItems = 50;

// the maximum number of "today" items to show on the main menu
static const unsigned int kMaxTodayItems = 12;

// the maximum number of recently closed pages to show
static const unsigned int kMaxRecentlyClosedItems = 20;

// the maximum number of characters in a menu title before cropping it
static const unsigned int kMaxTitleLength = 50;

// this little class manages the singleton history data source, and takes
// care of shutting it down at XPCOM shutdown time.
@interface HistoryMenuDataSourceOwner : NSObject
{
  HistoryDataSource*    mHistoryDataSource;
}

+ (HistoryMenuDataSourceOwner*)sharedHistoryMenuDataSourceOwner;
+ (HistoryDataSource*)sharedHistoryDataSource;    // just a shortcut

- (HistoryDataSource*)historyDataSource;

@end


@implementation HistoryMenuDataSourceOwner

+ (HistoryMenuDataSourceOwner*)sharedHistoryMenuDataSourceOwner
{
  static HistoryMenuDataSourceOwner* sHistoryOwner = nil;
  if (!sHistoryOwner)
    sHistoryOwner = [[HistoryMenuDataSourceOwner alloc] init];

  return sHistoryOwner;
}

+ (HistoryDataSource*)sharedHistoryDataSource
{
  return [[HistoryMenuDataSourceOwner sharedHistoryMenuDataSourceOwner] historyDataSource];
}

- (id)init
{
  if ((self = [super init])) {
    // register for xpcom shutdown
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(xpcomShutdownNotification:)
                                                 name:XPCOMShutDownNotificationName
                                               object:nil];
  }
  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [mHistoryDataSource release];
  [super dealloc];
}

- (void)xpcomShutdownNotification:(NSNotification*)inNotification
{
  [mHistoryDataSource release];
  mHistoryDataSource = nil;
}

- (HistoryDataSource*)historyDataSource
{
  if (!mHistoryDataSource) {
    mHistoryDataSource = [[HistoryDataSource alloc] init];
    [mHistoryDataSource setHistoryView:kHistoryViewByDate];
    [mHistoryDataSource setSortColumnIdentifier:@"last_visit"]; // always sort by last visit
    [mHistoryDataSource setSortDescending:YES];
  }
  return mHistoryDataSource;
}

@end // HistoryMenuDataSourceOwner


#pragma mark -

@interface HistorySubmenu(Private)

- (NSString*)menuItemTitleForHistoryItem:(HistoryItem*)inItem;

- (void)setupHistoryMenu;
- (void)menuWillBeDisplayed;
- (void)clearHistoryItems;
- (void)rebuildHistoryItems;
- (void)addLastItems;
- (void)historyChanged:(NSNotification*)inNotification;
- (void)menuWillDisplay:(NSNotification*)inNotification;
- (void)openHistoryItem:(id)sender;

@end

#pragma mark -

@implementation HistorySubmenu

- (NSString*)menuItemTitleForHistoryItem:(HistoryItem*)inItem
{
  NSString* itemTitle = [inItem title];
  if ([itemTitle length] == 0)
    itemTitle = [inItem url];

  return [itemTitle stringByTruncatingTo:kMaxTitleLength at:kTruncateAtMiddle];
}

- (id)initWithTitle:(NSString *)inTitle
{
  if ((self = [super initWithTitle:inTitle])) {
    mHistoryItemsDirty = YES;
    [self setupHistoryMenu];
  }
  return self;
}

// this should only be called after app launch, when the data source is available
- (void)setupHistoryMenu
{
  // set ourselves up to listen for history changes
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(historyChanged:)
                                               name:kNotificationNameHistoryDataSourceChanged
                                             object:[HistoryMenuDataSourceOwner sharedHistoryDataSource]];

  // Set us up to receive menuNeedsUpdate: callbacks
  [self setDelegate:self];
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [mRootItem release];
  [super dealloc];
}

- (void)setRootHistoryItem:(HistoryItem*)inRootItem
{
  [mRootItem autorelease];
  mRootItem = [inRootItem retain];
}

- (HistoryItem*)rootItem
{
  return mRootItem;
}

- (void)setNumLeadingItemsToIgnore:(int)inIgnoreItems
{
  mNumIgnoreItems = inIgnoreItems;
}

- (void)setNeedsRebuild:(BOOL)needsRebuild
{
  mHistoryItemsDirty = needsRebuild;
}

- (void)historyChanged:(NSNotification*)inNotification
{
  id rootChangedItem = [[inNotification userInfo] objectForKey:kNotificationHistoryDataSourceChangedUserInfoChangedItem];
  // We could optimize by only changing single menu items if itemOnlyChanged is true. Normally this will also be a visit
  // date change, which we can ignore.
  //BOOL itemOnlyChanged = [[[inNotification userInfo] objectForKey:kNotificationHistoryDataSourceChangedUserInfoChangedItemOnly] boolValue];

  // If rootChangedItem is nil, the whole history tree is being rebuilt.
  // We need to clear our root item, because it will become invalid. We'll set it again when we rebuild.
  if (!rootChangedItem) {
    [self setRootHistoryItem:nil];
    [self setNeedsRebuild:YES];
  }
  else if (mRootItem == rootChangedItem ||
           [mRootItem isDescendentOfItem:rootChangedItem] ||
           [rootChangedItem isDescendentOfItem:mRootItem])
  {
    [self setNeedsRebuild:YES];
  }
}

- (void)menuNeedsUpdate:(NSMenu*)menu
{
  // Contrary to what the docs say, this method is also called whenever a key
  // equivalent is triggered anywhere in the application, so we only update
  // the menu if we are actually doing menu tracking.
  if ([NSMenu currentyInMenuTracking])
    [self menuWillBeDisplayed];
}

- (void)clearHistoryItems
{
  [self removeItemsFromIndex:0];
}

- (void)rebuildHistoryItems
{
  // remove everything after the "before" item
  [self clearHistoryItems];

  // now iterate through the history items
  NSEnumerator* childEnum = [[mRootItem children] objectEnumerator];

  // skip the first mNumIgnoreItems items
  for (int i = 0; i < mNumIgnoreItems; ++i)
    [childEnum nextObject];

  int remainingEntriesToShow = kMaxNumHistoryItems;
  HistoryItem* curChild;
  while (((curChild = [childEnum nextObject])) && remainingEntriesToShow > 0) {
    NSMenuItem* newItem = nil;

    if ([curChild isKindOfClass:[HistorySiteItem class]]) {
      newItem = [[[NSMenuItem alloc] initWithTitle:[self menuItemTitleForHistoryItem:curChild]
                                            action:@selector(openHistoryItem:)
                                     keyEquivalent:@""] autorelease];
      [newItem setImage:[curChild iconAllowingLoad:NO]];
      [newItem setTarget:self];
      [newItem setRepresentedObject:curChild];

      [self addItem:newItem];
      [self addCommandKeyAlternatesForMenuItem:newItem];
      remainingEntriesToShow--;
    }
    else if ([curChild isKindOfClass:[HistoryCategoryItem class]] && ([curChild numberOfChildren] > 0)) {
      NSString* itemTitle = [self menuItemTitleForHistoryItem:curChild];
      newItem = [[[NSMenuItem alloc] initWithTitle:itemTitle
                                            action:nil
                                     keyEquivalent:@""] autorelease];
      [newItem setImage:[curChild iconAllowingLoad:NO]];

      HistorySubmenu* newSubmenu = [[HistorySubmenu alloc] initWithTitle:itemTitle];
      [newSubmenu setRootHistoryItem:curChild];
      [newItem setSubmenu:newSubmenu];

      [self addItem:newItem];
      remainingEntriesToShow--;
    }
  }

  [self addLastItems];

  [self setNeedsRebuild:NO];
}

- (void)addLastItems
{
  if (([[[self rootItem] children] count] - mNumIgnoreItems) > (unsigned)kMaxNumHistoryItems) {
    [self addItem:[NSMenuItem separatorItem]];
    NSMenuItem* showMoreItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"ShowMoreHistoryMenuItem", @"")
                                                           action:@selector(showHistory:)
                                                    keyEquivalent:@""] autorelease];
    [showMoreItem setRepresentedObject:mRootItem];
    [self addItem:showMoreItem];
  }
}

- (void)menuWillBeDisplayed
{
  if (mHistoryItemsDirty)
    [self rebuildHistoryItems];
}

- (BOOL)validateMenuItem:(NSMenuItem*)aMenuItem
{
  BrowserWindowController* browserController = [(MainController *)[NSApp delegate] mainWindowBrowserController];
  SEL action = [aMenuItem action];

  // disable history if a sheet is up
  if (action == @selector(openHistoryItem:))
    return !([browserController shouldSuppressWindowActions]);

  return YES;
}

- (void)openHistoryItem:(id)sender
{
  id repObject = [sender representedObject];
  NSString* itemURL = nil;
  if ([repObject isKindOfClass:[HistoryItem class]])
    itemURL = [repObject url];
  else if ([repObject isKindOfClass:[NSString class]])
    itemURL = repObject;

  if (itemURL) {
    // XXX share this logic with MainController and HistoryOutlineViewDelegate
    BrowserWindowController* bwc = [(MainController *)[NSApp delegate] mainWindowBrowserController];
    if (bwc) {
      if ([sender keyEquivalentModifierMask] & NSCommandKeyMask) {
        BOOL openInTab = [[PreferenceManager sharedInstance] getBooleanPref:kGeckoPrefOpenTabsForMiddleClick
                                                                withSuccess:NULL];
        BOOL backgroundLoad = [BrowserWindowController shouldLoadInBackgroundForDestination:(openInTab ? eDestinationNewTab
                                                                                                       : eDestinationNewWindow)
                                                                                     sender:sender];
        if (openInTab)
          [bwc openNewTabWithURL:itemURL referrer:nil loadInBackground:backgroundLoad allowPopups:NO setJumpback:NO];
        else
          [bwc openNewWindowWithURL:itemURL referrer:nil loadInBackground:backgroundLoad allowPopups:NO];
      }
      else {
        [bwc loadURL:itemURL];
      }
    }
    else {
      [(MainController *)[NSApp delegate] openBrowserWindowWithURL:itemURL andReferrer:nil behind:nil allowPopups:NO];
    }
  }
}

@end


#pragma mark -

@interface TopLevelHistoryMenu(Private)

- (void)appLaunchFinished:(NSNotification*)inNotification;
- (NSMenuItem*)todayMenuItem;

@end

@implementation TopLevelHistoryMenu

- (NSString*)menuItemTitleForHistoryItem:(HistoryItem*)inItem
{
  // Give the "Today" menu a different title, since part of it is pulled out
  // into the top level.
  if ([inItem respondsToSelector:@selector(isTodayCategory)] &&
      [(HistoryDateCategoryItem*)inItem isTodayCategory])
  {
    return NSLocalizedString(@"TopLevelHistoryMenuEarlierToday", nil);
  }

  return [super menuItemTitleForHistoryItem:inItem];
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [mTodayItem release];
  [mRecentlyClosedMenu release];
  [super dealloc];
}

- (void)awakeFromNib
{
  mRecentlyClosedMenu = [[NSMenu alloc] initWithTitle:NSLocalizedString(@"RecentlyClosed", nil)];
  [self setNeedsRebuild:YES];

  // listen for app launch completion
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(appLaunchFinished:)
                                               name:NSApplicationDidFinishLaunchingNotification
                                             object:nil];

  // listen for closing pages
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(browserClosed:)
                                               name:kBrowserInstanceClosedNotification
                                             object:nil];
}

- (void)appLaunchFinished:(NSNotification*)inNotification
{
  mAppLaunchDone = YES;
  // setup the history menu after a delay, so that other app launch stuff
  // finishes first
  [self performSelector:@selector(setupHistoryMenu) withObject:nil afterDelay:0];
}

- (void)browserClosed:(NSNotification*)inNotification
{
  BrowserWrapper* browser = [inNotification object];
  NSString* pageURI = [browser currentURI];

  // Ignore empty pages, as well as things like Bookmarks and History.
  if ([pageURI isBlankURL] || [pageURI hasCaseInsensitivePrefix:@"about:"])
    return;

  NSString* itemTitle = [browser pageTitle];
  if ([itemTitle length] == 0)
    itemTitle = pageURI;
  itemTitle = [itemTitle stringByTruncatingTo:kMaxTitleLength at:kTruncateAtMiddle];

  // If this is the first item being added, mark the menu as needing a rebuild
  // so that the folder will be added.
  if ([mRecentlyClosedMenu numberOfItems] == 0)
    [self setNeedsRebuild:YES];

  NSMenuItem* newItem = [[[NSMenuItem alloc] initWithTitle:itemTitle
                                                    action:@selector(openHistoryItem:)
                                             keyEquivalent:@""] autorelease];
  [newItem setImage:[browser siteIcon]];
  [newItem setTarget:self];
  [newItem setRepresentedObject:pageURI];

  // Add the new item and its alternates at the top of the menu, and figure out
  // how many menu items there are per entry so we can enforce the max correctly.
  [mRecentlyClosedMenu insertItem:newItem atIndex:0];
  int itemsPerEntry = 1 + [mRecentlyClosedMenu addCommandKeyAlternatesForMenuItem:newItem];
  int maxItems = kMaxRecentlyClosedItems * itemsPerEntry;

  // Remove any previous entries with the same URL so we don't have duplicates,
  // then enforce the limit.
  for (int i = [mRecentlyClosedMenu numberOfItems] - 1; i >= itemsPerEntry; --i) {
    if ([[[mRecentlyClosedMenu itemAtIndex:i] representedObject] isEqualToString:pageURI])
      [mRecentlyClosedMenu removeItemAtIndex:i];
  }
  while ([mRecentlyClosedMenu numberOfItems] > maxItems) {
    [mRecentlyClosedMenu removeItemAtIndex:maxItems];
  }
}

- (void)menuWillBeDisplayed
{
  if (mAppLaunchDone) {
    // the root item is nil at launch, and if the history gets totally rebuilt
    if (!mRootItem) {
      HistoryDataSource* dataSource = [HistoryMenuDataSourceOwner sharedHistoryDataSource];
      [dataSource loadLazily];

      mRootItem = [[dataSource rootItem] retain];
    }
  }

  [super menuWillBeDisplayed];
}

- (void)clearHistoryItems
{
  [self removeItemsAfterItem:mItemBeforeHistoryItems];
}

- (void)rebuildHistoryItems
{
  [super rebuildHistoryItems];

  NSMenuItem* todayMenuItem = [self todayMenuItem];
  [mTodayItem autorelease];
  mTodayItem = [[(HistorySubmenu*)[todayMenuItem submenu] rootItem] retain];

  // Promote the kMaxTodayItems most recent items into the top-level menu.
  unsigned int maxItems = std::min(kMaxTodayItems, [[mTodayItem children] count]);
  if (maxItems > 0) {
    NSArray* latestHistoryItems = [[mTodayItem children] subarrayWithRange:NSMakeRange(0, maxItems)];
    int todayMenuIndex = [self indexOfItem:todayMenuItem];

    NSEnumerator* latestItemsEnumerator = [latestHistoryItems objectEnumerator];
    HistoryItem* historyItem;
    while ((historyItem = [latestItemsEnumerator nextObject])) {
      NSMenuItem* menuItem = [[[NSMenuItem alloc] initWithTitle:[self menuItemTitleForHistoryItem:historyItem]
                                                         action:@selector(openHistoryItem:)
                                                  keyEquivalent:@""] autorelease];
      [menuItem setImage:[historyItem iconAllowingLoad:NO]];
      [menuItem setTarget:self];
      [menuItem setRepresentedObject:historyItem];

      [self insertItem:menuItem atIndex:(todayMenuIndex++)];
      todayMenuIndex += [self addCommandKeyAlternatesForMenuItem:menuItem];
    }

    [self insertItem:[NSMenuItem separatorItem] atIndex:todayMenuIndex];

    // Prevent the "Earlier Today" menu from showing the promoted items,
    // and remove it if nothing is left.
    [(HistorySubmenu*)[todayMenuItem submenu] setNumLeadingItemsToIgnore:maxItems];
    if ([[mTodayItem children] count] <= maxItems) {
      int todayMenuIndex = [self indexOfItem:todayMenuItem];
      [self removeItemAtIndex:todayMenuIndex];
      // If that was the only day folder, we have an extra separator now.
      if ([[self itemAtIndex:todayMenuIndex] isSeparatorItem])
        [self removeItemAtIndex:todayMenuIndex];
    }
  }
}

- (NSMenuItem*)todayMenuItem
{
  NSEnumerator* menuEnumerator = [[self itemArray] objectEnumerator];
  NSMenuItem* menuItem;
  while ((menuItem = [menuEnumerator nextObject])) {
    if ([[menuItem submenu] respondsToSelector:@selector(rootItem)]) {
      HistoryItem* historyItem = [(HistorySubmenu*)[menuItem submenu] rootItem];
      if ([historyItem respondsToSelector:@selector(isTodayCategory)] &&
          [(HistoryDateCategoryItem*)historyItem isTodayCategory])
      {
        return menuItem;
      }
    }
  }
  return nil;
}

- (void)addLastItems
{
  if ([[mRootItem children] count] > 0)
    [self addItem:[NSMenuItem separatorItem]];

  // Add the recently closed items menu if there are any.
  if ([mRecentlyClosedMenu numberOfItems] > 0) {
    NSMenuItem* recentlyClosedItem = [self addItemWithTitle:NSLocalizedString(@"RecentlyClosed", nil)
                                                     action:nil
                                              keyEquivalent:@""];
    [recentlyClosedItem setImage:[NSImage osFolderIcon]];
    [self setSubmenu:mRecentlyClosedMenu forItem:recentlyClosedItem];
    [self addItem:[NSMenuItem separatorItem]];
  }

  // at the bottom of the go menu, add a Clear History item
  NSMenuItem* clearHistoryItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"ClearHistoryMenuItem", @"")
                                                             action:@selector(clearHistory:)
                                                      keyEquivalent:@""] autorelease];
  [self addItem:clearHistoryItem];
}

- (void)historyChanged:(NSNotification*)inNotification
{
  id rootChangedItem = [[inNotification userInfo] objectForKey:kNotificationHistoryDataSourceChangedUserInfoChangedItem];

  // If rootChangedItem is nil, the whole history tree is being rebuilt.
  if (!rootChangedItem) {
    [mTodayItem release];
    mTodayItem = nil;
    // We can get here either when the history is being cleared (in which case
    // we will already have an mRootItem) or when we are doing the lazy
    // construction of the root item as the menu is shown (in which case
    // mRootItem is still |nil|). If it's the former, clear the recently closed
    // pages as well.
    if (mRootItem) {
      [mRecentlyClosedMenu release];
      mRecentlyClosedMenu = [[NSMenu alloc] initWithTitle:NSLocalizedString(@"RecentlyClosed", nil)];
    }
  }
  else if (mTodayItem == rootChangedItem ||
           mTodayItem == [rootChangedItem parentItem])
  {
    [self setNeedsRebuild:YES];
  }

  [super historyChanged:inNotification];
}

@end
