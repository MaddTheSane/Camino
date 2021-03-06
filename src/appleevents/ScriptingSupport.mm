/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*-
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "MainController.h"
#import "BrowserWindow.h"
#import "BrowserWrapper.h"
#import "BookmarkManager.h"
#import "BookmarkFolder.h"
#import "Bookmark.h"
#import "AutoCompleteTextField.h"
#import "BrowserWindowController.h"
#import "BrowserTabViewItem.h"
#import "NSString+Utils.h"
#import "MAAttachedWindow.h"


// This file adds scripting support to various classes.
// 
// Scripting classes and the Obj-C classes that implement them:
// 
//  application................NSApplication w/ MainController (delegate)
//  browser window.............BrowserWindow
//  tab........................BrowserWrapper
//  bookmark item..............BookmarkItem
//  bookmark folder............BookmarkFolder
//  bookmark...................Bookmark


@interface MainController (ScriptingSupport)
- (BOOL)application:(NSApplication *)sender delegateHandlesKey:(NSString *)key;
- (NSArray *)orderedWindows;
- (NSArray *)allBrowserWindows;
- (BOOL)isOnline;
- (void)setIsOnline:(BOOL)newState;
- (NSArray *)bookmarkCollections;
- (void)insertInBookmarkCollections:(BookmarkFolder *)aItem atIndex:(unsigned)aIndex;
- (void)insertInBookmarkCollections:(BookmarkFolder *)aItem;
- (void)removeFromBookmarkCollectionsAtIndex:(unsigned)aIndex;
- (void)replaceInBookmarkCollections:(BookmarkFolder *)aItem atIndex:(unsigned)aIndex;
@end

@interface BrowserWindow (ScriptingSupport)
- (NSScriptObjectSpecifier *)objectSpecifier;
- (NSArray *)tabs;
- (BrowserWrapper *)currentTab;
- (void)setCurrentTab:(BrowserWrapper *)newTabItemView;
- (void)handleReloadScriptCommand:(NSScriptCommand *)command;
- (void)handleReloadForObject:(id)objectToReload ignoringCache:(BOOL)ignoreCache;
@end

@interface BrowserWrapper (ScriptingSupport)
- (NSScriptObjectSpecifier *)objectSpecifier;
- (void)setCurrentURI:(NSString *)newURI;
- (void)handleReloadScriptCommand:(NSScriptCommand *)command;
- (void)handleReloadForObject:(id)objectToReload ignoringCache:(BOOL)ignoreCache;
- (void)scriptableReload:(BOOL)ignoreCache;
@end

@interface BookmarkItem (ScriptingSupport)
- (void)setScriptingProperties:(NSDictionary *)properties;
- (NSString *)uniqueID;
@end

@interface BookmarkFolder (ScriptingSupport)
- (NSScriptObjectSpecifier *)objectSpecifier;
- (NSArray *)folderItemsWithClass:(Class)theClass;
- (NSArray *)childBookmarks;
- (NSArray *)childFolders;
- (void)insertInChildren:(BookmarkItem *)aItem atIndex:(unsigned)aIndex;
- (void)insertInChildFolders:(BookmarkFolder *)aItem atIndex:(unsigned)aIndex;
- (void)insertInChildBookmarks:(Bookmark *)aItem atIndex:(unsigned)aIndex;
- (void)insertInChildren:(BookmarkItem *)aItem;
- (void)insertInChildFolders:(BookmarkFolder *)aItem;
- (void)insertInChildBookmarks:(Bookmark *)aItem;
- (void)removeFromChildrenAtIndex:(unsigned)aIndex;
- (void)removeFromChildFoldersAtIndex:(unsigned)aIndex;
- (void)removeFromChildBookmarksAtIndex:(unsigned)aIndex;
- (void)replaceInChildren:(BookmarkItem *)aItem atIndex:(unsigned)aIndex;
- (void)replaceInChildFolders:(BookmarkFolder *)aItem atIndex:(unsigned)aIndex;
- (void)replaceInChildBookmarks:(Bookmark *)aItem atIndex:(unsigned)aIndex;
- (NSArray *)indicesOfObjectsByEvaluatingObjectSpecifier:(NSScriptObjectSpecifier *)specifier;
- (NSArray *)indicesOfObjectsByEvaluatingRelativeSpecifier:(NSRelativeSpecifier *)relSpec;
- (NSArray *)indicesOfObjectsByEvaluatingRangeSpecifier:(NSRangeSpecifier *)rangeSpec;
@end

@interface Bookmark (ScriptingSupport)
- (NSScriptObjectSpecifier *)objectSpecifier;
@end


#pragma mark -
#pragma mark Scripting class: application

@implementation MainController (ScriptingSupport)

// Delegate method: Declares NSApp should let MainController handle certain KVC keys.
// Causes, for instance, [NSApp valueForKey:@"orderedWindows"] to call
// [[NSApp delegate] valueForKey:@"orderedWindows"], but does not affect calls directly
// to [NSApp orderedWindows].
- (BOOL)application:(NSApplication *)sender delegateHandlesKey:(NSString *)key
{
  return [key isEqualToString:@"orderedWindows"] ||
         [key isEqualToString:@"allBrowserWindows"] ||
         [key isEqualToString:@"isOnline"] ||
         [key isEqualToString:@"bookmarkCollections"] ||
         [key isEqualToString:@"bookmarkMenuFolder"] ||
         [key isEqualToString:@"toolbarFolder"] ||
         [key isEqualToString:@"top10Folder"] ||
         [key isEqualToString:@"rendezvousFolder"] ||
         [key isEqualToString:@"addressBookFolder"];
}

// These keys are "forwarded" to the Bookmark Manager.
- (id)valueForKey:(NSString *)key
{
  if ([key isEqualToString:@"bookmarkMenuFolder"] ||
      [key isEqualToString:@"toolbarFolder"] ||
      [key isEqualToString:@"top10Folder"] ||
      [key isEqualToString:@"rendezvousFolder"] ||
      [key isEqualToString:@"addressBookFolder"]) {
    return [[BookmarkManager sharedBookmarkManager] valueForKey:key];
  }
  else {
    return [super valueForKey:key];
  }
}


// Returns "windows that are typically scriptable" as per -[NSApplication orderedWindows]
// documentation.  Includes browser windows, downloads window, and preferences window, but
// ignores invisible windows that NSApplication's implementation doesn't know to ignore.
- (NSArray *)orderedWindows
{
  NSEnumerator* windowEnum = [[NSApp orderedWindows] objectEnumerator];
  NSMutableArray* windowArray = [NSMutableArray array];

  NSWindow* curWindow;
  while ((curWindow = [windowEnum nextObject])) {
    // Three kinds of invisible windows show up in [NSApp orderedWindows]:
    // AutoCompleteWindows, ToolTips (which have the NSBorderlessWindowMask
    // style mask), and NSWindows with uniqueID == -1.  It is unclear what the
    // third set of windows is, but they certainly shouldn't be included.
    // Note: there is no -[NSWindow uniqueID] method; the uniqueID key is only
    // availible via KVC.
    if (![curWindow isKindOfClass:[MAAttachedWindow class]] &&
        [curWindow styleMask] != NSBorderlessWindowMask &&
        [[curWindow valueForKey:@"uniqueID"] intValue] != -1) {
          [windowArray addObject:curWindow];
    }
  }

  return windowArray;
}

// Returns all windows controlled by a BWC. Similar to -browserWindows, but
// returns chrome-less BWs such as view-source:'s and popups as well.
- (NSArray *)allBrowserWindows
{
  NSEnumerator* windowEnum = [[NSApp orderedWindows] objectEnumerator];
  NSMutableArray* windowArray = [NSMutableArray array];

  NSWindow* curWindow;
  while ((curWindow = [windowEnum nextObject])) {
    if ([[curWindow windowController] isKindOfClass:[BrowserWindowController class]])
      [windowArray addObject:curWindow];
  }

  return windowArray;
}

// Returns the online state of the application.
- (BOOL)isOnline
{
  return !mOffline;
}

- (void)setIsOnline:(BOOL)newState
{
  if (newState == [self isOnline])
    return;

  [self toggleOfflineMode:nil];
}


// Returns the user-defined (non-special) top-level BookmarkFolders from the Bookmark Manager's Collections pane.
- (NSArray *)bookmarkCollections
{
  // Get the top-level folders, then filter out special folders.
  NSArray *array = [[BookmarkManager sharedBookmarkManager] valueForKeyPath:@"bookmarkRoot.children"];
  NSMutableArray *collections = [NSMutableArray array];
  NSEnumerator *e = [array objectEnumerator];
  id eachFolder;
  while ((eachFolder = [e nextObject])) {
    if (![eachFolder isSpecial])
      [collections addObject:eachFolder];
  }
  return collections;
}


// NSScriptKeyValueCoding protocol support.
// These methods are called through Scripting-KVC by NSObject's implementation of the
// NSScriptKeyValueCoding informal protocol.  See BookmarkFolder(ScriptingSupport) for more
// information.  These methods pass the buck to the bookmarkRoot folder, which actually
// manages "application's bookmark folders", after making sure we're not touching the
// special collections at the top of the list.

// Offset for bookmarkCollections within bookmarkRoot's childFolders.
- (unsigned)_bookmarkCollectionsOffset
{
  return [[[[BookmarkManager sharedBookmarkManager] bookmarkRoot] children] count] - [[self bookmarkCollections] count];
}

- (void)insertInBookmarkCollections:(BookmarkFolder *)aItem atIndex:(unsigned)aIndex
{
  [[[BookmarkManager sharedBookmarkManager] bookmarkRoot] insertInChildFolders:aItem atIndex:[self _bookmarkCollectionsOffset]+aIndex];
}

- (void)insertInBookmarkCollections:(BookmarkFolder *)aItem
{
  [[[BookmarkManager sharedBookmarkManager] bookmarkRoot] insertInChildFolders:aItem];
}

- (void)removeFromBookmarkCollectionsAtIndex:(unsigned)aIndex
{
  [[[BookmarkManager sharedBookmarkManager] bookmarkRoot] removeFromChildFoldersAtIndex:[self _bookmarkCollectionsOffset]+aIndex];
}

- (void)replaceInBookmarkCollections:(BookmarkFolder *)aItem atIndex:(unsigned)aIndex
{
  [[[BookmarkManager sharedBookmarkManager] bookmarkRoot] replaceInChildFolders:aItem atIndex:[self _bookmarkCollectionsOffset]+aIndex];
}

@end


#pragma mark -
#pragma mark Scripting class: browser window

@implementation BrowserWindow (ScriptingSupport)

- (NSScriptObjectSpecifier *)objectSpecifier
{
  NSArray *browserWindows = [[NSApp delegate] allBrowserWindows];
  unsigned index = [browserWindows indexOfObjectIdenticalTo:self];
  NSScriptClassDescription *containerClassDesc = (NSScriptClassDescription *)[NSScriptClassDescription classDescriptionForClass:[NSApp class]];

  if (index != NSNotFound) {
    return [[[NSIndexSpecifier alloc] initWithContainerClassDescription:containerClassDesc
                                                     containerSpecifier:[NSApp objectSpecifier]
                                                                    key:@"allBrowserWindows"
                                                                  index:index] autorelease];
  }
  else {
    return nil;
  }
}

// Returns the BrowserWrappers (tabs) in this BrowserWindow (browser window).
- (NSArray *)tabs
{
  return [self valueForKeyPath:@"windowController.tabBrowser.tabViewItems.view"];
}

- (BrowserWrapper *)currentTab
{
  return [self valueForKeyPath:@"windowController.tabBrowser.selectedTabViewItem.view"];
}

// Changes the current tab in a given browser window to a tab (BrowserWrapper)
// specified by the user. Make sure that the BrowserWrapper we are given is
// actually in the same browser window and warn the user if it is not.
- (void)setCurrentTab:(BrowserWrapper *)newTabItemView
{
  NSTabViewItem *newTabItem = [newTabItemView tab];
  BrowserTabView *tabView = [[self windowController] tabBrowser];
  if ([tabView indexOfTabViewItem:newTabItem] != NSNotFound) {
    [tabView selectTabViewItem:newTabItem];
  }
  else {
    [[NSScriptCommand currentCommand] setScriptErrorNumber:NSArgumentsWrongScriptError];
    [[NSScriptCommand currentCommand] setScriptErrorString:@"The tab to select must be in the same window."];
  }
}

- (void)handleReloadScriptCommand:(NSScriptCommand *)command
{
  id browserWindowsToReload = [command evaluatedReceivers];
  BOOL ignoreCache = [[[command evaluatedArguments] objectForKey:@"ignoringCache"] boolValue];
  [self handleReloadForObject:browserWindowsToReload ignoringCache:ignoreCache];
}

- (void)handleReloadForObject:(id)objectToReload ignoringCache:(BOOL)ignoreCache
{
  // Scripts can send single browser windows or a simple array of browser
  // windows ("reload every browser window" or "reload browser windows 1
  // through 3").
  if ([objectToReload isKindOfClass:[NSArray class]]) {
    id maybeReloadableObject;
    NSEnumerator *reloadablesEnumerator = [objectToReload objectEnumerator];
    while ((maybeReloadableObject = [reloadablesEnumerator nextObject])) {
      [self handleReloadForObject:maybeReloadableObject ignoringCache:ignoreCache];
    }
  }
  else if ([objectToReload isKindOfClass:[BrowserWindow class]]) {
    BrowserWindow *windowToReload = objectToReload;
    BrowserWrapper *tabToReload = [windowToReload currentTab];
    [tabToReload scriptableReload:ignoreCache];
  }
  else {
    // This shouldn't ever happen, but if it does, we need to hear about it.
    [[NSScriptCommand currentCommand] setScriptErrorNumber:NSArgumentsWrongScriptError];
    NSString *scriptingClassName = [[NSScriptClassDescription classDescriptionForClass:[objectToReload class]] className];
    [[NSScriptCommand currentCommand] setScriptErrorString:[NSString stringWithFormat:@"A %@ can't be reloaded.", scriptingClassName]];
  }
}

@end


#pragma mark -
#pragma mark Scripting class: tab

@implementation BrowserWrapper (ScriptingSupport)

- (NSScriptObjectSpecifier *)objectSpecifier
{
  BrowserWindow *window = (BrowserWindow *)[self nativeWindow];
  NSArray *tabArray = [window valueForKeyPath:@"windowController.tabBrowser.tabViewItems.view"];
  unsigned index = [tabArray indexOfObjectIdenticalTo:self];
  
  if (index != NSNotFound) {
    return [[[NSIndexSpecifier alloc] initWithContainerClassDescription:(NSScriptClassDescription *)[NSScriptClassDescription classDescriptionForClass:[window class]]
                                                     containerSpecifier:[window objectSpecifier]
                                                                    key:@"tabs"
                                                                  index:index] autorelease];
  }
  else {
    return nil;
  }
}

// BrowserWrapper implements a -currentURI but not a -setCurrentURI:.
// This method lets "tab's URL" be a read/write property.
- (void)setCurrentURI:(NSString *)newURI
{
  // Don't allow setting URLs that can run in the context of the existing page.
  if ([newURI isPotentiallyDangerousURI]) {
    NSString *scheme = [[[newURI componentsSeparatedByString:@":"] objectAtIndex:0] lowercaseString];
    [[NSScriptCommand currentCommand] setScriptErrorNumber:NSArgumentsWrongScriptError];
    [[NSScriptCommand currentCommand] setScriptErrorString:[NSString stringWithFormat:@"Can't set URL of tab to a '%@:' URI.", scheme]];
    return;
  }

  [self loadURI:newURI referrer:nil flags:NSLoadFlagsNone focusContent:YES allowPopups:NO];
}

// Allow tabs to respond to "close" command.
- (id)close:(NSCloseCommand *)command
{
  if ([[[self tab] tabView] numberOfTabViewItems] > 1)
    [(BrowserTabViewItem *)[self tab] closeTab:self];
  else
    [[self nativeWindow] performClose:self];
  return nil;
}

- (void)handleReloadScriptCommand:(NSScriptCommand *)command
{
  id tabsToReload = [command evaluatedReceivers];
  BOOL ignoreCache = [[[command evaluatedArguments] objectForKey:@"ignoringCache"] boolValue];
  [self handleReloadForObject:tabsToReload ignoringCache:ignoreCache];
}

- (void)handleReloadForObject:(id)objectToReload ignoringCache:(BOOL)ignoreCache
{
  // Scripts can send single tabs, a simple array of tabs ("reload every tab of
  // browser window 1" or "reload tabs 1 through 2 of browser window 1"), or an
  // array containing arrays of tabs ("reload every tab of every browser 
  // window" or "reload tabs 1 through 2 of browser windows 2 through 3").
  if ([objectToReload isKindOfClass:[NSArray class]]) {
    id maybeReloadableObject;
    NSEnumerator *reloadablesEnumerator = [objectToReload objectEnumerator];
    while ((maybeReloadableObject = [reloadablesEnumerator nextObject])) {
      [self handleReloadForObject:maybeReloadableObject ignoringCache:ignoreCache];
    }
  }
  else if ([objectToReload isKindOfClass:[BrowserWrapper class]]) {
    BrowserWrapper *tabToReload = objectToReload;
    [tabToReload scriptableReload:ignoreCache];
  }
  else {
    // This shouldn't ever happen, but if it does, we need to hear about it.
    [[NSScriptCommand currentCommand] setScriptErrorNumber:NSArgumentsWrongScriptError];
    NSString *scriptingClassName = [[NSScriptClassDescription classDescriptionForClass:[objectToReload class]] className];
    [[NSScriptCommand currentCommand] setScriptErrorString:[NSString stringWithFormat:@"A %@ can't be reloaded.", scriptingClassName]];
  }
}

- (void)scriptableReload:(BOOL)ignoreCache
{
  if (![self canReload])
    return;

  unsigned int reloadFlag = ignoreCache ?
      NSLoadFlagsBypassCacheAndProxy : NSLoadFlagsNone;
  [self reload:reloadFlag];
}

@end


#pragma mark -
#pragma mark Scripting class: bookmark item

@implementation BookmarkItem (ScriptingSupport)

// We need to make sure Cocoa Scripting gives us the right types for our properties.
// NSObject's implementation blithely assigns the value, regardless of type.
- (void)setScriptingProperties:(NSDictionary *)properties
{
  // Note: The current code depends on two facts:
  // 
  //  1. The keys to the dictionary are valid, writable scripting keys according to the dictionary, and
  //  2. All writable properties of BookmarkItem (and its decendents) are strings.
  // 
  // (1) is guaranteed by the documentation for setScriptingProperties:.  (2) is liable to change in the future.
  
  NSEnumerator *e = [properties keyEnumerator];
  id key;
  while ((key = [e nextObject])) {
    id value = [properties valueForKey:key];
    if ([value isKindOfClass:[NSString class]]) {
      [self setValue:value forKey:key];
    }
    // Because the language is weird, given certain syntaxes, AppleScript
    // sends us a property specifier rather than the evaluated object.
    // We try to handle that transparently here.
    else if ([value isKindOfClass:[NSPropertySpecifier class]] && [[value objectsByEvaluatingSpecifier] isKindOfClass:[NSString class]]) {
      [self setValue:[value objectsByEvaluatingSpecifier] forKey:key];
    }
    else {
      [[NSScriptCommand currentCommand] setScriptErrorNumber:NSArgumentsWrongScriptError];
      NSString *scriptingClassName = [(NSScriptClassDescription *)[NSScriptClassDescription classDescriptionForClass:[value class]] className];
      [[NSScriptCommand currentCommand] setScriptErrorString:[NSString stringWithFormat:@"A bookmark item's %@ can't be that type.", scriptingClassName]];
    }
  }
}

- (NSString *)uniqueID
{
  // Separators don't have UUIDs, but BookmarkItem's UUID will create one if
  // one is not present.  Bookmarks in the Address Book and Bonjour smart
  // collections, as well as all three smart collections themselves, don't have
  // persistent UUIDs, so it's unwise to let a script think that they do.
  if ([self isKindOfClass:[Bookmark class]] && [self isSeparator])
    return nil;

  if ([[self parent] isKindOfClass:[BookmarkFolder class]] && [[self parent] isSmartFolder])
    return nil;

  if ([self isKindOfClass:[BookmarkFolder class]] && [(BookmarkFolder *)self isSmartFolder])
    return nil;

  return [self UUID];
}

@end


#pragma mark -
#pragma mark Scripting class: bookmark folder

@implementation BookmarkFolder (ScriptingSupport)

// BookmarkFolders identify themselves by name.
- (NSScriptObjectSpecifier *)objectSpecifier
{
  BookmarkFolder *parent = [self parent];

  // If our parent has a parent, we're contained by our parent.  If not, we're a collection contained by application.
  if ([parent parent]) {
    return [[[NSNameSpecifier alloc] initWithContainerClassDescription:(NSScriptClassDescription *)[NSScriptClassDescription classDescriptionForClass:[parent class]]
                                                    containerSpecifier:[parent objectSpecifier]
                                                                   key:@"childFolders"
                                                                  name:[self title]] autorelease];
  }
  else {
    // If we're not a special collection, we belong to NSApp's bookmarkCollections collection.
    if (![self isSpecial]) {
      return [[[NSNameSpecifier alloc] initWithContainerClassDescription:(NSScriptClassDescription *)[NSScriptClassDescription classDescriptionForClass:[NSApp class]]
                                                      containerSpecifier:[NSApp objectSpecifier]
                                                                     key:@"bookmarkCollections"
                                                                    name:[self title]] autorelease];
    }
    // If we're a special folder, we're a specific property of NSApp.
    else {
      NSString *key;
      if (self == [[BookmarkManager sharedBookmarkManager] bookmarkMenuFolder])
        key = @"bookmarkMenuFolder";
      else if (self == [[BookmarkManager sharedBookmarkManager] toolbarFolder])
        key = @"toolbarFolder";
      else if (self == [[BookmarkManager sharedBookmarkManager] top10Folder])
        key = @"top10Folder";
      else if (self == [[BookmarkManager sharedBookmarkManager] rendezvousFolder])
        key = @"rendezvousFolder";
      else if (self == [[BookmarkManager sharedBookmarkManager] addressBookFolder])
        key = @"addressBookFolder";
      else
        return nil;   // Error case: if we're special but we're not one of these folders, something's very wrong, so just bail.
      
      return [[[NSPropertySpecifier alloc] initWithContainerClassDescription:(NSScriptClassDescription *)[NSScriptClassDescription classDescriptionForClass:[NSApp class]]
                                                          containerSpecifier:[NSApp objectSpecifier]
                                                                         key:key] autorelease];
    }
  }
}


// Accessors for childBookmarks and childFolders

- (NSArray *)folderItemsWithClass:(Class)theClass
{
  NSEnumerator* childEnum = [[self children] objectEnumerator];
  NSMutableArray *result = [NSMutableArray array];
  id curItem;
  while ((curItem = [childEnum nextObject])) {
    if ([curItem isKindOfClass:theClass]) {
      [result addObject:curItem];
    }
  }

  return result;
}

- (NSArray *)childBookmarks
{
  return [self folderItemsWithClass:[Bookmark class]];
}

- (NSArray *)childFolders
{
  return [self folderItemsWithClass:[BookmarkFolder class]];
}

#pragma mark -

// Overrides setValue:forKey to stop scripts from changing smart folders' properties.
- (void)setValue:(id)value forKey:(NSString *)key
{
  // If we're a smart folder, none of our properties may be modified by script commands.
  if ([self isSmartFolder] && [NSScriptCommand currentCommand]) {
    [[NSScriptCommand currentCommand] setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
    [[NSScriptCommand currentCommand] setScriptErrorString:[NSString stringWithFormat:@"Can't modify properties of special folder '%@'.", [self title]]];
    return;
  }
  else
    [super setValue:value forKey:key];
}


// NSScriptKeyValueCoding protocol support.
// These methods are called through Scripting-KVC by NSObject's implementation of the
// NSScriptKeyValueCoding informal protocol.  We handle three keys here:
// - children
// - childFolders
// - childBookmarks
// 
// Note that the childFolders and childBookmarks collections are filtered
// from the children.  They contain all the folders/bookmarks (respectively)
// of |children| in the order they appear there.  Indexes when dealing with these
// collections refer to the filtered collection, not to the original index in
// |children|.

// Returns false and sets a script error if contents shouldn't be modified by scripting.
- (BOOL)shouldModifyContentsByScripting
{
  if ([self isSmartFolder]) {
    [[NSScriptCommand currentCommand] setScriptErrorNumber:NSReceiversCantHandleCommandScriptError];
    [[NSScriptCommand currentCommand] setScriptErrorString:[NSString stringWithFormat:@"Can't modify contents of smart folder '%@'.", [self title]]];
    return NO;
  }
  return YES;
}

// -insertIn<key>:atIndex:
// Used to create children with a location specifier.

- (void)insertInChildren:(BookmarkItem *)aItem atIndex:(unsigned)aIndex
{
  // Bail if we shouldn't be modified.
  if (![self shouldModifyContentsByScripting]) return;
  
  [self insertChild:aItem atIndex:aIndex isMove:NO];
  [[BookmarkManager sharedBookmarkManager]
      bookmarkItemsAdded:[NSArray arrayWithObject:aItem]];
}

// These two methods currently treat the incoming index as an index into the filtered array of
// folders or bookmarks, and find a place to put the new item in the full |children| so they come
// out at the right index of the applicable filtered array.  This may or may not be desired by
// scripters, depending on the reference form used.

- (void)insertInChildFolders:(BookmarkFolder *)aItem atIndex:(unsigned)aIndex
{
  // Bail if we shouldn't be modified.
  if (![self shouldModifyContentsByScripting]) return;
  
  NSArray *folderArray = [self childFolders];
  BookmarkFolder *aFolder;
  unsigned realIndex;
  if (aIndex < [folderArray count]) {
    aFolder = [folderArray objectAtIndex:aIndex];
    realIndex = [[self children] indexOfObject:aFolder];
  }
  else {
    aFolder = [folderArray lastObject];
    realIndex = 1 + [[self children] indexOfObject:aFolder];
  }
  [self insertChild:aItem atIndex:realIndex isMove:NO];
  [[BookmarkManager sharedBookmarkManager]
      bookmarkItemsAdded:[NSArray arrayWithObject:aItem]];
}

- (void)insertInChildBookmarks:(Bookmark *)aItem atIndex:(unsigned)aIndex
{
  // Bail if we shouldn't be modified.
  if (![self shouldModifyContentsByScripting]) return;
  
  NSArray *bookmarkArray = [self childBookmarks];
  Bookmark *aBookmark;
  unsigned realIndex;
  if (aIndex < [bookmarkArray count])  {
    aBookmark = [bookmarkArray objectAtIndex:aIndex];
    realIndex = [[self children] indexOfObject:aBookmark];
  }
  else {
    aBookmark = [bookmarkArray lastObject];
    realIndex = 1 + [[self children] indexOfObject:aBookmark];
  }
  [self insertChild:aItem atIndex:realIndex isMove:NO];
  [[BookmarkManager sharedBookmarkManager]
      bookmarkItemsAdded:[NSArray arrayWithObject:aItem]];
}


// -insertIn<key>:
// Used to create children without a location specifier.
// Adds to end of entire |children| in all cases, since inserting after last bookmark/folder
// isn't particularly useful.

- (void)insertInChildren:(BookmarkItem *)aItem
{
  // Bail if we shouldn't be modified.
  if (![self shouldModifyContentsByScripting]) return;
  
  [self appendChild:aItem];
  [[BookmarkManager sharedBookmarkManager]
      bookmarkItemsAdded:[NSArray arrayWithObject:aItem]];
}

- (void)insertInChildFolders:(BookmarkFolder *)aItem
{
  // Bail if we shouldn't be modified.
  if (![self shouldModifyContentsByScripting]) return;
  
  [self insertInChildren:aItem];
  [[BookmarkManager sharedBookmarkManager]
      bookmarkItemsAdded:[NSArray arrayWithObject:aItem]];
}

- (void)insertInChildBookmarks:(Bookmark *)aItem
{
  // Bail if we shouldn't be modified.
  if (![self shouldModifyContentsByScripting]) return;
  
  [self insertInChildren:aItem];
  [[BookmarkManager sharedBookmarkManager]
      bookmarkItemsAdded:[NSArray arrayWithObject:aItem]];
}


// -removeFrom<Key>AtIndex:
// Removes the object at the specified index from the collection.

- (void)removeFromChildrenAtIndex:(unsigned)aIndex
{
  // Bail if we shouldn't be modified.
  if (![self shouldModifyContentsByScripting]) return;
  
  BookmarkItem* aKid = [[self children] objectAtIndex:aIndex];
  [[BookmarkManager sharedBookmarkManager]
      bookmarkItemsWillBeRemoved:[NSArray arrayWithObject:aKid]];
  [self deleteChild:aKid];
}

- (void)removeFromChildFoldersAtIndex:(unsigned)aIndex
{
  // Bail if we shouldn't be modified.
  if (![self shouldModifyContentsByScripting]) return;
  
  BookmarkFolder* aKid = [[self childFolders] objectAtIndex:aIndex];
  [[BookmarkManager sharedBookmarkManager]
      bookmarkItemsWillBeRemoved:[NSArray arrayWithObject:aKid]];
  [self deleteChild:aKid];
}

- (void)removeFromChildBookmarksAtIndex:(unsigned)aIndex
{
  // Bail if we shouldn't be modified.
  if (![self shouldModifyContentsByScripting]) return;
  
  Bookmark* aKid = [[self childBookmarks] objectAtIndex:aIndex];
  [[BookmarkManager sharedBookmarkManager]
      bookmarkItemsWillBeRemoved:[NSArray arrayWithObject:aKid]];
  [self deleteChild:aKid];
}


// -replaceIn<Key>:atIndex:
// Replaces the object at the specified index in the collection.

- (void)replaceInChildren:(BookmarkItem *)aItem atIndex:(unsigned)aIndex
{
  // Bail if we shouldn't be modified.
  if (![self shouldModifyContentsByScripting]) return;
  
  [self removeFromChildrenAtIndex:aIndex];
  [self insertChild:aItem atIndex:aIndex isMove:NO];
}

- (void)replaceInChildFolders:(BookmarkFolder *)aItem atIndex:(unsigned)aIndex
{
  // Bail if we shouldn't be modified.
  if (![self shouldModifyContentsByScripting]) return;
  
  [self removeFromChildFoldersAtIndex:aIndex];
  [self insertInChildFolders:aItem atIndex:aIndex];
}

- (void)replaceInChildBookmarks:(Bookmark *)aItem atIndex:(unsigned)aIndex
{
  // Bail if we shouldn't be modified.
  if (![self shouldModifyContentsByScripting]) return;
  
  [self removeFromChildBookmarksAtIndex:aIndex];
  [self insertInChildBookmarks:aItem atIndex:aIndex];
}


#pragma mark -

// XXX These three methods were moved directly from BookmarkFolder.m.  They were part of the Great
// Bookmark Rewrite (bug 212630).  indicesOfObjectsByEvaluatingObjectSpecifier: is an optional
// method; it allows a container to override the default specifier evaluation algorithm for
// performance or other reasons (see the NSScriptObjectSpecifiers informal protocol.) Since
// AppleScript support was poorly understood when these were added, and they are templated
// from Apple's Sketch.app, it is unclear whether these methods serve a purpose or were included
// because Apple's code used them.  This should be examined later.  In the interests of maintaining
// the status quo, they are retained below (along with their original comment).

//
// These next 3 methods swiped almost exactly out of sketch.app by apple.
// look there for an explanation if you're confused.
//
- (NSArray *)indicesOfObjectsByEvaluatingObjectSpecifier:(NSScriptObjectSpecifier *)specifier
{
  if ([specifier isKindOfClass:[NSRangeSpecifier class]])
    return [self indicesOfObjectsByEvaluatingRangeSpecifier:(NSRangeSpecifier *)specifier];
  else if ([specifier isKindOfClass:[NSRelativeSpecifier class]])
    return [self indicesOfObjectsByEvaluatingRelativeSpecifier:(NSRelativeSpecifier *)specifier];
  // If we didn't handle it, return nil so that the default object specifier evaluation will do it.
  return nil;
}

- (NSArray *)indicesOfObjectsByEvaluatingRelativeSpecifier:(NSRelativeSpecifier *)relSpec
{
  NSString *key = [relSpec key];
  if ([key isEqualToString:@"childBookmarks"] ||
      [key isEqualToString:@"children"] ||
      [key isEqualToString:@"childFolders"])
  {
    NSScriptObjectSpecifier *baseSpec = [relSpec baseSpecifier];
    NSString *baseKey = [baseSpec key];
    NSArray *children = [self children];
    NSRelativePosition relPos = [relSpec relativePosition];
    if (baseSpec == nil)
      return nil;

    if ([children count] == 0)
      return [NSArray array];

    if ([baseKey isEqualToString:@"childBookmarks"] ||
        [baseKey isEqualToString:@"children"] ||
        [baseKey isEqualToString:@"childFolders"])
    {
      unsigned baseIndex;
      id baseObject = [baseSpec objectsByEvaluatingWithContainers:self];
      if ([baseObject isKindOfClass:[NSArray class]]) {
        int baseCount = [baseObject count];
        if (baseCount == 0)
          baseObject = nil;
        else {
          if (relPos == NSRelativeBefore)
            baseObject = [baseObject objectAtIndex:0];
          else
            baseObject = [baseObject objectAtIndex:(baseCount-1)];
        }
      }

      if (!baseObject)
        // Oops.  We could not find the base object.
        return nil;

      baseIndex = [children indexOfObjectIdenticalTo:baseObject];
      if (baseIndex == NSNotFound)
        // Oops.  We couldn't find the base object in the child array.  This should not happen.
        return nil;

      NSMutableArray *result = [NSMutableArray array];
      BOOL keyIsArray = [key isEqualToString:@"children"];
      NSArray *relKeyObjects = (keyIsArray ? nil : [self valueForKey:key]);
      id curObj;
      unsigned curKeyIndex, childrenCount = [children count];
      if (relPos == NSRelativeBefore)
          baseIndex--;
      else
          baseIndex++;

      while ((baseIndex >= 0) && (baseIndex < childrenCount)) {
        if (keyIsArray) {
          [result addObject:[NSNumber numberWithInt:baseIndex]];
          break;
        }
        else {
          curObj = [children objectAtIndex:baseIndex];
          curKeyIndex = [relKeyObjects indexOfObjectIdenticalTo:curObj];
          if (curKeyIndex != NSNotFound) {
            [result addObject:[NSNumber numberWithInt:curKeyIndex]];
            break;
          }
        }

        if (relPos == NSRelativeBefore)
          baseIndex--;
        else
          baseIndex++;
      }
      return result;
    }
  }
  return nil;
}

- (NSArray *)indicesOfObjectsByEvaluatingRangeSpecifier:(NSRangeSpecifier *)rangeSpec
{
  NSString *key = [rangeSpec key];
  if ([key isEqualToString:@"childBookmarks"] ||
      [key isEqualToString:@"children"] ||
      [key isEqualToString:@"childFolders"])
  {
    NSScriptObjectSpecifier *startSpec = [rangeSpec startSpecifier];
    NSScriptObjectSpecifier *endSpec = [rangeSpec endSpecifier];
    NSString *startKey = [startSpec key];
    NSString *endKey = [endSpec key];
    NSArray *children = [self children];

    if ((startSpec == nil) && (endSpec == nil))
      return nil;
    if ([children count] == 0)
      return [NSArray array];

    if ((!startSpec || [startKey isEqualToString:@"childBookmarks"] ||
         [startKey isEqualToString:@"children"] || [startKey isEqualToString:@"childFolders"]) &&
        (!endSpec || [endKey isEqualToString:@"childBookmarks"] || [endKey isEqualToString:@"children"] ||
         [endKey isEqualToString:@"childFolders"]))
    {
      unsigned startIndex;
      unsigned endIndex;
      if (startSpec) {
        id startObject = [startSpec objectsByEvaluatingSpecifier];
        if ([startObject isKindOfClass:[NSArray class]]) {
          if ([startObject count] == 0)
            startObject = nil;
          else
            startObject = [startObject objectAtIndex:0];
        }
        if (!startObject)
          return nil;
        startIndex = [children indexOfObjectIdenticalTo:startObject];
        if (startIndex == NSNotFound)
          return nil;
      }
      else
        startIndex = 0;

      if (endSpec) {
        id endObject = [endSpec objectsByEvaluatingSpecifier];
        if ([endObject isKindOfClass:[NSArray class]]) {
          unsigned endObjectsCount = [endObject count];
          if (endObjectsCount == 0)
            endObject = nil;
          else
            endObject = [endObject objectAtIndex:(endObjectsCount-1)];
        }
        if (!endObject)
          return nil;
        endIndex = [children indexOfObjectIdenticalTo:endObject];
        if (endIndex == NSNotFound)
          return nil;
      }
      else
        endIndex = [children count] - 1;

      if (endIndex < startIndex) {
        int temp = endIndex;
        endIndex = startIndex;
        startIndex = temp;
      }

      NSMutableArray *result = [NSMutableArray array];
      BOOL keyIsArray = [key isEqual:@"children"];
      NSArray *rangeKeyObjects = (keyIsArray ? nil : [self valueForKey:key]);
      id curObj;
      unsigned curKeyIndex, i;
      for (i = startIndex; i <= endIndex; i++) {
        if (keyIsArray)
          [result addObject:[NSNumber numberWithInt:i]];
        else {
          curObj = [children objectAtIndex:i];
          curKeyIndex = [rangeKeyObjects indexOfObjectIdenticalTo:curObj];
          if (curKeyIndex != NSNotFound)
            [result addObject:[NSNumber numberWithInt:curKeyIndex]];
        }
      }
      return result;
    }
  }
  return nil;
}



@end


#pragma mark -
#pragma mark Scripting class: bookmark

@implementation Bookmark (ScriptingSupport)

// Bookmarks identify themselves by name.
- (NSScriptObjectSpecifier *)objectSpecifier
{
  BookmarkFolder *parent = [self parent];
  return [[[NSNameSpecifier alloc] initWithContainerClassDescription:(NSScriptClassDescription *)[NSScriptClassDescription classDescriptionForClass:[parent class]]
                                                  containerSpecifier:[parent objectSpecifier]
                                                                 key:@"childBookmarks"
                                                                name:[self title]] autorelease];
}

@end
