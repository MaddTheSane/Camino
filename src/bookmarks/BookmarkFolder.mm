/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
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
 * The Original Code is mozilla.org code.
 *
 * The Initial Developer of the Original Code is
 * Netscape Communications Corporation.
 * Portions created by the Initial Developer are Copyright (C) 2002
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *   David Haas <haasd@cae.wisc.edu>
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

#import "NSString+Utils.h"
#import "NSArray+Utils.h"

#import "BookmarkManager.h"
#import "BookmarkFolder.h"
#import "Bookmark.h"

// Notification definitions
NSString* const BookmarkFolderAdditionNotification      = @"bf_add";
NSString* const BookmarkFolderDeletionNotification      = @"bf_del";
NSString* const BookmarkFolderChildKey                  = @"bf_ck";
NSString* const BookmarkFolderChildIndexKey             = @"bf_ik";
NSString* const BookmarkFolderDockMenuChangeNotificaton = @"bf_dmc";


struct BookmarkSortData
{
  SEL       mSortSelector;
  NSNumber* mReverseSort;

  SEL       mSecondarySortSelector;
  NSNumber* mSecondaryReverseSort;
};


static int BookmarkItemSort(id firstItem, id secondItem, void* context)
{
  BookmarkSortData* sortData = (BookmarkSortData*)context;
  int comp = (int)[firstItem performSelector:sortData->mSortSelector withObject:secondItem withObject:sortData->mReverseSort];

  if (comp == 0 && sortData->mSecondarySortSelector)
    comp = (int)[firstItem performSelector:sortData->mSecondarySortSelector withObject:secondItem withObject:sortData->mSecondaryReverseSort];

  return comp;
}


@interface BookmarksEnumerator : NSEnumerator
{
  BookmarkFolder*   mRootFolder;

  BookmarkFolder*   mCurFolder;
  int               mCurChildIndex;   // -1 means "self"
}

- (id)initWithRootFolder:(BookmarkFolder*)rootFolder;

- (id)nextObject;
- (NSArray *)allObjects;

@end;

#pragma mark -


@interface BookmarkFolder (Private)

// status stuff
- (unsigned)specialFlag;
- (void)setSpecialFlag:(unsigned)aNumber;

// ways to add a new bookmark
- (BOOL)addBookmarkFromNativeDict:(NSDictionary *)aDict;
- (BOOL)addBookmarkFromSafariDict:(NSDictionary *)aDict;

// ways to add a new bookmark folder
- (BOOL)addBookmarkFolderFromNativeDict:(NSDictionary *)aDict; //read in - adds sequentially
- (BOOL)addBookmarkFolderFromSafariDict:(NSDictionary *)aDict;

// deletes the bookmark or bookmark array
- (BOOL)deleteBookmark:(Bookmark *)childBookmark;
- (BOOL)deleteBookmarkFolder:(BookmarkFolder *)childArray;

// notification methods
- (void)itemAddedNote:(BookmarkItem *)theItem atIndex:(unsigned)anIndex;
- (void)itemRemovedNote:(BookmarkItem *)theItem;
- (void)itemChangedNote:(BookmarkItem *)theItem;
- (void)dockMenuChanged:(NSNotification *)note;

// aids in searching
- (NSString*)expandURL:(NSString*)url withString:(NSString*)searchString;
- (NSArray *)folderItemsWithClass:(Class)theClass;

// used for undo
- (void)arrangeChildrenWithOrder:(NSArray*)inChildArray;

@end

#pragma mark -

@implementation BookmarksEnumerator

- (id)initWithRootFolder:(BookmarkFolder*)rootFolder
{
  if ((self = [super init])) {
    mRootFolder = [rootFolder retain];
    mCurFolder = mRootFolder;
    mCurChildIndex = -1;
  }
  return self;
}

- (void)dealloc
{
  [mRootFolder release];
  [super dealloc];
}

- (void)setupNextForItem:(BookmarkItem*)inItem
{
  if ([inItem isKindOfClass:[BookmarkFolder class]]) {
    mCurFolder = (BookmarkFolder*)inItem;
    mCurChildIndex = 0;   // start on its children next time
  }
  else
    ++mCurChildIndex;
}

- (id)nextObject
{
  if (!mCurFolder) return nil;    // if we're done, keep it that way

  if (mCurChildIndex == -1) {
    [self setupNextForItem:mCurFolder];
    return mCurFolder;
  }

  NSArray* curFolderChildren = [mCurFolder children];
  BookmarkItem* curChild = [curFolderChildren safeObjectAtIndex:mCurChildIndex];
  if (curChild) {
    [self setupNextForItem:curChild];
    return curChild;
  }

  // we're at the end of this folder.
  while (1) {
    if (mCurFolder == mRootFolder) {  // we're done
      mCurFolder = nil;
      break;
    }

    // back up to parent folder, next index
    BookmarkFolder* newCurFolder = [mCurFolder parent];
    mCurChildIndex = [newCurFolder indexOfObject:mCurFolder] + 1;
    mCurFolder = newCurFolder;
    if (mCurChildIndex < (int)[newCurFolder count]) {
      BookmarkItem* nextItem = [mCurFolder objectAtIndex:mCurChildIndex];
      [self setupNextForItem:nextItem];
      return nextItem;
    }
  }

  return nil;
}

- (NSArray*)allObjects
{
  NSMutableArray* allObjectsArray = [NSMutableArray array];

  BookmarksEnumerator* bmEnum = [[[BookmarksEnumerator alloc] initWithRootFolder:mRootFolder] autorelease];
  id curItem;
  while ((curItem = [bmEnum nextObject]))
    [allObjectsArray addObject:curItem];

  return allObjectsArray;
}

@end

#pragma mark -

@implementation BookmarkFolder

+ (id)bookmarkFolderWithTitle:(NSString*)title
{
  BookmarkFolder* folder = [[[self alloc] init] autorelease];
  [folder setTitle:title];
  return folder;
}

- (id)init
{
  if ((self = [super init])) {
    mChildArray   = [[NSMutableArray alloc] init];
    mSpecialFlag  = kBookmarkFolder;
    mIcon         = nil;    // load lazily
  }
  return self;
}

- (id)initWithIdentifier:(NSString*)inIdentifier
{
  if ([self init]) {
    mIdentifier = [inIdentifier retain];
  }
  return self;
}

- (id)copyWithZone:(NSZone *)zone
{
  if ([self isSmartFolder])
    return nil;

  id folderCopy = [super copyWithZone:zone];
  unsigned folderFlags = ([self specialFlag] & ~kBookmarkDockMenuFolder);   // don't copy dock menu flag
  [folderCopy setSpecialFlag:folderFlags];
  // don't copy the identifier, since it should be unique

  NSEnumerator *enumerator = [[self children] objectEnumerator];
  id anItem, aCopiedItem;
  // head fake the undomanager
  NSUndoManager *undoManager = [[BookmarkManager sharedBookmarkManager] undoManager];
  [undoManager disableUndoRegistration];
  while ((anItem = [enumerator nextObject])) {
    aCopiedItem = [anItem copyWithZone:[anItem zone]];
    [folderCopy appendChild:aCopiedItem];
    [aCopiedItem release];
  }
  [undoManager enableUndoRegistration];

  return folderCopy;
}

- (void)dealloc
{
  // NOTE: we're no longer clearning the undo stack here because its pointless and is a potential crasher
  if (mSpecialFlag & kBookmarkDockMenuFolder)
    [[NSNotificationCenter defaultCenter] removeObserver:self];

  // set our all children to have a null parent.
  // important if they've got timers running.
  NSEnumerator *enumerator = [mChildArray objectEnumerator];
  id kid;
  while ((kid = [enumerator nextObject]))
    [kid setParent:nil];

  [mChildArray release];
  [mIdentifier release];

  [super dealloc];
}

- (NSString*)description
{
  return [NSString stringWithFormat:@"BookmarkFolder %08p, title %@", self, mTitle];
}

- (NSImage *)icon
{
  if (!mIcon)
    mIcon = [[NSImage imageNamed:@"folder"] retain];

  return mIcon;
}

//
// get/set properties
//

- (NSArray *)children
{
  return mChildArray;
}

// only return bookmark URL's - if we've got folders, we ignore them.
- (NSArray *)childURLs
{
  NSMutableArray *urlArray = [NSMutableArray arrayWithCapacity:[self count]];
  NSEnumerator *enumerator = [[self children] objectEnumerator];
  id anItem;
  while ((anItem = [enumerator nextObject])) {
    if ([anItem isKindOfClass:[Bookmark class]] && ![(Bookmark *)anItem isSeparator])
      [urlArray addObject:[(Bookmark *)anItem url]];
  }
  return urlArray;
}

- (NSArray *)allChildBookmarks
{
  NSMutableArray *anArray = [NSMutableArray array];
  [anArray addObjectsFromArray:[self folderItemsWithClass:[Bookmark class]]];
  NSEnumerator *enumerator = [[self folderItemsWithClass:[BookmarkFolder class]] objectEnumerator];
  BookmarkFolder *kid;
  while ((kid = [enumerator nextObject])) {
    NSArray *kidsBookmarks = [kid allChildBookmarks];
    [anArray addObjectsFromArray:kidsBookmarks];
  }
  return anArray;
}

- (NSEnumerator*)objectEnumerator
{
  return [[[BookmarksEnumerator alloc] initWithRootFolder:self] autorelease];
}

- (void)setIdentifier:(NSString*)inIdentifier
{
  [mIdentifier autorelease];
  mIdentifier = [inIdentifier retain];
}

- (NSString*)identifier
{
  return mIdentifier;
}

- (BOOL)isSpecial
{
  return ([self identifier] != nil);
}

- (BOOL)isToolbar
{
  return ((mSpecialFlag & kBookmarkToolbarFolder) != 0);
}

- (BOOL)isRoot
{
  return ((mSpecialFlag & kBookmarkRootFolder) != 0);
}

- (BOOL)isGroup
{
  return ((mSpecialFlag & kBookmarkFolderGroup) != 0);
}

- (BOOL)isSmartFolder
{
  return ((mSpecialFlag & kBookmarkSmartFolder) != 0);
}

- (BOOL)isDockMenu
{
  return ((mSpecialFlag & kBookmarkDockMenuFolder) != 0);
}

- (unsigned)specialFlag
{
  return mSpecialFlag;
}

- (void)setIsGroup:(BOOL)aBool
{
  unsigned curVal = [self specialFlag];
  if (aBool)
    curVal |= kBookmarkFolderGroup;
  else
    curVal &= ~kBookmarkFolderGroup;
  [self setSpecialFlag:curVal];
}

- (void)setSpecialFlag:(unsigned)aFlag
{
  unsigned int oldFlag = mSpecialFlag;
  mSpecialFlag = aFlag;

  if ((oldFlag & kBookmarkFolderGroup) != (aFlag & kBookmarkFolderGroup)) {
    // only change the group/folder icon if we're changing that flag
    if ((aFlag & kBookmarkFolderGroup) != 0)
      [self setIcon:[NSImage imageNamed:@"groupbookmark"]];
    else
      [self setIcon:[NSImage imageNamed:@"folder"]];
  }
  if ((aFlag & kBookmarkDockMenuFolder) != 0) {
    // if we're the dock menu folder, tell the previous dock folder that
    // they're no longer it and register for the same notification in
    // case it changes again.
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc postNotificationName:BookmarkFolderDockMenuChangeNotificaton object:self];
    [nc addObserver:self selector:@selector(dockMenuChanged:) name:BookmarkFolderDockMenuChangeNotificaton object:nil];
  }
  else if ((oldFlag & kBookmarkDockMenuFolder) != 0) {
    // when resigning dock menu, notify
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:self name:BookmarkFolderDockMenuChangeNotificaton object:nil];
    [nc postNotificationName:BookmarkFolderDockMenuChangeNotificaton object:self];
  }
}

- (void)setIsToolbar:(BOOL)aBool
{
  unsigned curVal = [self specialFlag];
  if (aBool)
    curVal |= kBookmarkToolbarFolder;
  else
    curVal &= ~kBookmarkToolbarFolder;
  [self setSpecialFlag:curVal];
}

- (void)setIsRoot:(BOOL)aBool
{
  unsigned curVal = [self specialFlag];
  if (aBool) {
    if ([[self parent] isKindOfClass:[BookmarkFolder class]])
      return;
    curVal |= kBookmarkRootFolder;
  }
  else
    curVal &= ~kBookmarkRootFolder;
  [self setSpecialFlag:curVal];
}

- (void)setIsSmartFolder:(BOOL)aBool
{
  unsigned curVal = [self specialFlag];
  if (aBool)
    curVal |= kBookmarkSmartFolder;
  else
    curVal &= ~kBookmarkSmartFolder;
  [self setSpecialFlag:curVal];
}

- (void)toggleIsDockMenu:(id)sender
{
  [self setIsDockMenu:![self isDockMenu]];
}

- (void)setIsDockMenu:(BOOL)aBool
{
  unsigned curVal = [self specialFlag];
  if (aBool)
    curVal |= kBookmarkDockMenuFolder;
  else {
    curVal &= ~kBookmarkDockMenuFolder;
    [[NSNotificationCenter defaultCenter] removeObserver:self name:BookmarkFolderDockMenuChangeNotificaton object:nil];
  }
  [self setSpecialFlag:curVal];
}

//
// Adding children.
//
- (void)appendChild:(BookmarkItem *)aChild
{
  [self insertChild:aChild atIndex:[self count] isMove:NO];
}

- (void)insertChild:(BookmarkItem *)aChild atIndex:(unsigned)aPosition isMove:(BOOL)inIsMove
{
  // Ensure that only folders are added to the root.
  if ([self isRoot] && ![aChild isKindOfClass:[BookmarkFolder class]])
    return;

  [aChild setParent:self];
  unsigned insertPoint = [mChildArray count];
  if (insertPoint > aPosition)
    insertPoint = aPosition;

  [mChildArray insertObject:aChild atIndex:insertPoint];
  if (!inIsMove && ![self isSmartFolder]) {
    NSUndoManager* undoManager = [[BookmarkManager sharedBookmarkManager] undoManager];
    [[undoManager prepareWithInvocationTarget:self] deleteChild:aChild];
    if (![undoManager isUndoing]) {
      if ([aChild isKindOfClass:[BookmarkFolder class]])
        [undoManager setActionName:NSLocalizedString(@"Add Folder", nil)];
      else if ([aChild isKindOfClass:[Bookmark class]]) {
        if (![(Bookmark  *)aChild isSeparator])
          [undoManager setActionName:NSLocalizedString(@"Add Bookmark", nil)];
        else
          [undoManager setActionName:NSLocalizedString(@"Add Separator", nil)];
      }
    }
    else {
      [aChild itemUpdatedNote:kBookmarkItemEverythingChangedMask];   // ??
    }
  }
  [self itemAddedNote:aChild atIndex:insertPoint];
}

//
// Smart folder utilities - we don't set ourself as parent
//
- (void)insertIntoSmartFolderChild:(BookmarkItem *)aItem
{
  if ([self isSmartFolder]) {
    [mChildArray addObject:aItem];
    [self itemAddedNote:aItem atIndex:([self count] - 1)];
  }
}

- (void)insertIntoSmartFolderChild:(BookmarkItem *)aItem atIndex:(unsigned)inIndex
{
  if ([self isSmartFolder]) {
    [mChildArray insertObject:aItem atIndex:inIndex];
    [self itemAddedNote:aItem atIndex:inIndex];
  }
}

- (void)deleteFromSmartFolderChildAtIndex:(unsigned)index
{
  if ([self isSmartFolder]) {
    BookmarkItem *item = [[mChildArray objectAtIndex:index] retain];
    [mChildArray removeObjectAtIndex:index];
    [self itemRemovedNote:[item autorelease]];
  }
}

// move the given items together, sorted according to the sort selector.
// inChildItems is assumed to be in the same order as the children
- (void)arrangeChildItems:(NSArray*)inChildItems usingSelector:(SEL)inSelector reverseSort:(BOOL)inReverse
{
  NSMutableArray* orderedItems = [NSMutableArray arrayWithArray:inChildItems];

  BookmarkSortData sortData = { inSelector, [NSNumber numberWithBool:inReverse], NULL, nil };
  [orderedItems sortUsingFunction:BookmarkItemSort context:&sortData];

  // now build a new child array
  NSMutableArray* newChildOrder = [[mChildArray mutableCopy] autorelease];

  // save the index of the first (which won't change, since it's the first)
  int firstChangedIndex = [newChildOrder indexOfObject:[inChildItems firstObject]];
  if (firstChangedIndex == -1) return;    // something went wrong

  [newChildOrder removeObjectsInArray:inChildItems];
  [newChildOrder replaceObjectsInRange:NSMakeRange(firstChangedIndex, 0) withObjectsFromArray:orderedItems];

  // this makes it undoable
  [self arrangeChildrenWithOrder:newChildOrder];
}

// TODO: migrate everything to the descriptor version, and remove this.
- (void)sortChildrenUsingSelector:(SEL)inSelector reverseSort:(BOOL)inReverse sortDeep:(BOOL)inDeep undoable:(BOOL)inUndoable
{
  NSUndoManager* undoManager = [[BookmarkManager sharedBookmarkManager] undoManager];
  if (inUndoable) {
    [undoManager beginUndoGrouping];
    // record undo, back to existing order
    [[undoManager prepareWithInvocationTarget:self] arrangeChildrenWithOrder:[NSArray arrayWithArray:mChildArray]];
  }

  BookmarkSortData sortData = { inSelector, [NSNumber numberWithBool:inReverse], NULL, nil };
  [mChildArray sortUsingFunction:BookmarkItemSort context:&sortData];

  // notify
  [self itemChangedNote:self];

  if (inDeep) {
    NSEnumerator *enumerator = [mChildArray objectEnumerator];
    id childItem;
    while ((childItem = [enumerator nextObject])) {
      if ([childItem isKindOfClass:[BookmarkFolder class]])
        [childItem sortChildrenUsingSelector:inSelector reverseSort:inReverse sortDeep:inDeep undoable:inUndoable];
    }
  }

  if (inUndoable) {
    [undoManager endUndoGrouping];
    [undoManager setActionName:NSLocalizedString(@"Arrange Bookmarks", nil)];
  }
}

- (void)sortChildrenUsingDescriptors:(NSArray*)descriptors deep:(BOOL)deep undoable:(BOOL)undoable
{
  NSUndoManager* undoManager = [[BookmarkManager sharedBookmarkManager] undoManager];
  if (undoable) {
    [undoManager beginUndoGrouping];
    // record undo, back to existing order
    [[undoManager prepareWithInvocationTarget:self] arrangeChildrenWithOrder:[NSArray arrayWithArray:mChildArray]];
  }

  [mChildArray sortUsingDescriptors:descriptors];

  [self itemChangedNote:self];

  if (deep) {
    NSEnumerator *enumerator = [mChildArray objectEnumerator];
    id childItem;
    while ((childItem = [enumerator nextObject])) {
      if ([childItem isKindOfClass:[BookmarkFolder class]])
        [childItem sortChildrenUsingDescriptors:descriptors deep:deep undoable:undoable];
    }
  }

  if (undoable) {
    [undoManager endUndoGrouping];
    [undoManager setActionName:NSLocalizedString(@"Arrange Bookmarks", nil)];
  }
}

// used for undo
- (void)arrangeChildrenWithOrder:(NSArray*)inChildArray
{
  // The undo manager automatically puts redo items in a group, so we don't have to
  // (undoing sorting of nested folders will work OK)
  NSUndoManager* undoManager = [[BookmarkManager sharedBookmarkManager] undoManager];

  // record undo, back to existing order
  [[undoManager prepareWithInvocationTarget:self] arrangeChildrenWithOrder:[NSArray arrayWithArray:mChildArray]];

  if ([mChildArray count] != [inChildArray count]) {
    NSLog(@"arrangeChildrenWithOrder: unmatched child array sizes");
    return;
  }

  // Cheating here. The in array simply contains the items in the order we want,
  // so use it.
  [mChildArray removeAllObjects];
  [mChildArray addObjectsFromArray:inChildArray];

  // notify
  [self itemChangedNote:self];

  [undoManager setActionName:NSLocalizedString(@"Arrange Bookmarks", nil)];
}

//
// Adding bookmarks
//

- (Bookmark *)addBookmark
{
  if ([self isRoot])
    return nil;

  Bookmark* theBookmark = [[[Bookmark alloc] init] autorelease];
  [self appendChild:theBookmark];
  return theBookmark;
}

// adding from native plist
- (BOOL)addBookmarkFromNativeDict:(NSDictionary *)aDict
{
  if ([self isRoot])
    return NO;

  Bookmark* theBookmark = [Bookmark bookmarkWithNativeDictionary:aDict];
  if (!theBookmark)
    return NO;

  [self appendChild:theBookmark];
  return YES;
}

- (BOOL)addBookmarkFromSafariDict:(NSDictionary *)aDict
{
  if ([self isRoot])
    return NO;

  Bookmark* theBookmark = [Bookmark bookmarkWithSafariDictionary:aDict];
  if (!theBookmark)
    return NO;

  [self appendChild:theBookmark];
  return YES;
}

//
// Adding arrays
//
// used primarily for parsing of html bookmark files.
- (BookmarkFolder *)addBookmarkFolder // adds to end
{
  BookmarkFolder *theFolder = [[BookmarkFolder alloc] init];
  [self appendChild:theFolder];
  [theFolder release]; // retained on insert
  return theFolder;
}

// from native plist file
- (BOOL)addBookmarkFolderFromNativeDict:(NSDictionary *)aDict
{
  return [[self addBookmarkFolder] readNativeDictionary:aDict];
}

- (BOOL)addBookmarkFolderFromSafariDict:(NSDictionary *)aDict
{
  return [[self addBookmarkFolder] readSafariDictionary:aDict];
}

// normal add while programming running
- (BookmarkFolder *)addBookmarkFolder:(NSString *)aName inPosition:(unsigned)aPosition isGroup:(BOOL)aFlag
{
  BookmarkFolder *theFolder = [[[BookmarkFolder alloc] init] autorelease];
  [theFolder setTitle:aName];
  if (aFlag)
    [theFolder setIsGroup:aFlag];
  [self insertChild:theFolder atIndex:aPosition isMove:NO];
  return theFolder;
}

// if we start spending too much time here, we could build an NSDictionary map
- (BookmarkItem *)itemWithUUID:(NSString*)uuid
{
  // see if we match
  if ([[self UUID] isEqualToString:uuid])
    return self;

  // see if our kids match
  NSEnumerator *enumerator = [[self children] objectEnumerator];
  id childItem;
  while ((childItem = [enumerator nextObject])) {
    if ([childItem isKindOfClass:[Bookmark class]]) {
      if ([[childItem UUID] isEqualToString:uuid])
        return childItem;
    }
    else if ([childItem isKindOfClass:[BookmarkFolder class]]) {
      // recurse
      id foundItem = [childItem itemWithUUID:uuid];
      if (foundItem)
        return foundItem;
    }
  }

  return nil;
}

//
// Moving & Copying children
//

- (void)moveChild:(BookmarkItem *)aChild toBookmarkFolder:(BookmarkFolder *)aNewParent atIndex:(unsigned)aIndex
{
  NSUndoManager* undoManager = [[BookmarkManager sharedBookmarkManager] undoManager];
  unsigned curIndex = [mChildArray indexOfObjectIdenticalTo:aChild];
  if (curIndex == NSNotFound)
    return;

  BOOL isSeparator = NO;
  // A few of sanity checks
  if ([aChild isKindOfClass:[BookmarkFolder class]]) {
    if ([aNewParent isChildOfItem:aChild])
      return;

    if ([(BookmarkFolder *)aChild isToolbar] && ![aNewParent isRoot])
      return;

    if ([(BookmarkFolder *)aChild isSmartFolder] && ![aNewParent isRoot])
      return;
  }
  else if ([aChild isKindOfClass:[Bookmark class]]) {
    if ([aNewParent isRoot])
      return;
    isSeparator = [(Bookmark *)aChild isSeparator];
  }

  [undoManager beginUndoGrouping];

  // What we do depends on if we're moving into a new folder, or just
  // rearranging ourself a bit.
  if (aNewParent != self) {
    [aNewParent insertChild:aChild atIndex:aIndex isMove:YES];
    // DO NOT call deleteChild here.  Just quietly remove it from the array.
    [mChildArray removeObjectAtIndex:curIndex];
    [self itemRemovedNote:aChild];
  }
  else {
    [aChild retain];
    [mChildArray removeObjectAtIndex:curIndex];
    [self itemRemovedNote:aChild];
    if (curIndex < aIndex)
      --aIndex;
    else
      ++curIndex; // so that redo works

    [self insertChild:aChild atIndex:aIndex isMove:YES];
    [aChild release];
  }

  [[undoManager prepareWithInvocationTarget:aNewParent] moveChild:aChild toBookmarkFolder:self atIndex:curIndex];
  [undoManager endUndoGrouping];

  if ([aChild isKindOfClass:[BookmarkFolder class]])
    [undoManager setActionName:NSLocalizedString(@"Move Folder", nil)];
  else if (isSeparator)
    [undoManager setActionName:NSLocalizedString(@"Move Separator", nil)];
  else
    [undoManager setActionName:NSLocalizedString(@"Move Bookmark", nil)];
}

- (BookmarkItem*)copyChild:(BookmarkItem *)aChild toBookmarkFolder:(BookmarkFolder *)aNewParent atIndex:(unsigned)aIndex
{
  if ([aNewParent isRoot] && [aChild isKindOfClass:[Bookmark class]])
    return nil;

  BookmarkItem *copiedChild = [aChild copyWithZone:nil];
  if (!copiedChild)
    return nil;

  [aNewParent insertChild:copiedChild atIndex:aIndex isMove:NO];
  [copiedChild release];

  NSUndoManager* undoManager = [[BookmarkManager sharedBookmarkManager] undoManager];
  if ([aChild isKindOfClass:[BookmarkFolder class]])
    [undoManager setActionName:NSLocalizedString(@"Copy Folder", nil)];
  else
    [undoManager setActionName:NSLocalizedString(@"Copy Bookmark", nil)];

  return copiedChild;
}

//
// Deleting children
//
- (BOOL)deleteChild:(BookmarkItem *)aChild
{
  BOOL itsDead = NO;
  if ([[self children] indexOfObjectIdenticalTo:aChild] != NSNotFound) {
    if ([aChild isKindOfClass:[Bookmark class]])
      itsDead = [self deleteBookmark:(Bookmark *)aChild];
    else if ([aChild isKindOfClass:[BookmarkFolder class]])
      itsDead = [self deleteBookmarkFolder:(BookmarkFolder *)aChild];
  }
  else {
    //with current setup, shouldn't ever hit this code path.
    NSEnumerator *enumerator = [[self children] objectEnumerator];
    id anObject;
    while (!itsDead && (anObject = [enumerator nextObject])) {
      if ([anObject isKindOfClass:[BookmarkFolder class]])
        itsDead = [anObject deleteChild:aChild];
    }
  }
  return itsDead;
}

- (BOOL)deleteBookmark:(Bookmark *)aChild
{
  NSUndoManager* undoManager = [[BookmarkManager sharedBookmarkManager] undoManager];
  //record undo
  [[undoManager prepareWithInvocationTarget:self] insertChild:aChild atIndex:[[self children] indexOfObjectIdenticalTo:aChild] isMove:NO];

  [aChild setParent:nil];
  [[aChild retain] autorelease];   // let it live for the notifications (don't rely on undo manager to keep it alive)
  [mChildArray removeObject:aChild];

  if (![undoManager isUndoing] && ![self isSmartFolder]) {
    if ([aChild isSeparator])
      [undoManager setActionName:NSLocalizedString(@"Delete Separator", nil)];
    else
      [undoManager setActionName:NSLocalizedString(@"Delete Bookmark", nil)];
  }

  [self itemRemovedNote:aChild];
  return YES;
}

- (BOOL)deleteBookmarkFolder:(BookmarkFolder *)aChild
{
  NSUndoManager* undoManager = [[BookmarkManager sharedBookmarkManager] undoManager];
  //Make sure it's not a special array - redundant, but oh well.
  if ([aChild isSpecial])
    return NO;

  [undoManager beginUndoGrouping];

  // remove all the children first, so notifications are sent out about their removal
  unsigned int numChildren = [aChild count];
  while (numChildren > 0)
    [aChild deleteChild:[aChild objectAtIndex:--numChildren]];

  // record undo
  [[undoManager prepareWithInvocationTarget:self] insertChild:aChild atIndex:[[self children] indexOfObjectIdenticalTo:aChild] isMove:NO];
  [undoManager endUndoGrouping];

  if([aChild isDockMenu])
    [aChild setIsDockMenu:NO];
  [aChild setParent:nil];
  [[aChild retain] autorelease];   // let it live for the notifications (don't rely on undo manager to keep it alive)
  [mChildArray removeObject:aChild];

  if (![undoManager isUndoing])
    [undoManager setActionName:NSLocalizedString(@"Delete Folder", nil)];

  [self itemRemovedNote:aChild];
  return YES;
}

//
// Make us look like an array methods
//
// figure out # of top level children
- (unsigned)count
{
  return [mChildArray count];
}

- (id)objectAtIndex:(unsigned)index
{
  if ([mChildArray count] > index)
    return [mChildArray objectAtIndex:index];
  return nil;
}

- (unsigned)indexOfObject:(id)object
{
  return [mChildArray indexOfObject:object];
}

- (unsigned)indexOfObjectIdenticalTo:(id)object
{
  return [mChildArray indexOfObjectIdenticalTo:object];
}

- (id)savedSpecialFlag
{
  return [NSNumber numberWithUnsignedInt:mSpecialFlag];
}

//
// build submenu
//
- (void)buildFlatFolderList:(NSMenu *)menu depth:(unsigned)depth
{
  NSEnumerator *children = [mChildArray objectEnumerator];
  id aKid;
  while ((aKid = [children nextObject])) {
    if ([aKid isKindOfClass:[BookmarkFolder class]]) {
      if (![aKid isSmartFolder]) {
        NSString* paddedTitle = [[aKid title] stringByTruncatingTo:80 at:kTruncateAtMiddle];
        NSMenuItem* menuItem = [[NSMenuItem alloc] initWithTitle:paddedTitle action:NULL keyEquivalent:@""];
        [menuItem setRepresentedObject:aKid];

        NSImage *curIcon = [aKid icon];
        NSSize iconSize = [curIcon size];
        NSImage *shiftedIcon = [[NSImage alloc] initWithSize:NSMakeSize(depth*(iconSize.width), iconSize.height)];
        [shiftedIcon lockFocus];
        [curIcon drawInRect:NSMakeRect(([shiftedIcon size].width - iconSize.width), 0, iconSize.width, iconSize.height)
                   fromRect:NSMakeRect(0, 0, iconSize.width, iconSize.height)
                  operation:NSCompositeCopy
                   fraction:1];
        [shiftedIcon unlockFocus];
        [menuItem setImage:shiftedIcon];
        [shiftedIcon release];

        [menu addItem:menuItem];
        [menuItem release];

        [aKid buildFlatFolderList:menu depth:(depth + 1)];
      }
    }
  }
}

//
// searching/shortcut processing
//
- (NSArray*)resolveShortcut:(NSString *)shortcut withArgs:(NSString *)args
{
  if (!shortcut)
    return nil;

  // see if it's us
  if ([[self shortcut] caseInsensitiveCompare:shortcut] == NSOrderedSame) {
    NSMutableArray *urlArray = (NSMutableArray *)[self childURLs];
    int i, j = [urlArray count];
    for (i = 0; i < j; i++) {
      NSString *newURL = [self expandURL:[urlArray objectAtIndex:i] withString:args];
      [urlArray replaceObjectAtIndex:i withObject:newURL];
    }
    return urlArray;
  }
  // see if it's one of our kids
  NSEnumerator* enumerator = [[self children] objectEnumerator];
  id aKid;
  while ((aKid = [enumerator nextObject])) {
    if ([aKid isKindOfClass:[Bookmark class]]) {
      if ([[aKid shortcut] caseInsensitiveCompare:shortcut] == NSOrderedSame)
        return [NSArray arrayWithObject:[self expandURL:[aKid url] withString:args]];
    }
    else if ([aKid isKindOfClass:[BookmarkFolder class]]) {
      // recurse into sub-folders
      NSArray *childArray = [aKid resolveShortcut:shortcut withArgs:args];
      if (childArray)
        return childArray;
    }
  }
  return nil;
}

- (NSString*)expandURL:(NSString*)url withString:(NSString*)searchString
{
  NSRange matchRange = [url rangeOfString:@"%s"];
  if (matchRange.location != NSNotFound) {
    NSString* escapedString = [(NSString*)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                                                                 (CFStringRef)searchString,
                                                                                 NULL,
                                                                                 // legal URL characters that should be encoded in search terms
                                                                                 CFSTR(";?:@&=+$,"),
                                                                                 kCFStringEncodingUTF8) autorelease];
    NSString* resultString = [NSString stringWithFormat:@"%@%@%@",
      [url substringToIndex:matchRange.location],
      escapedString,
      [url substringFromIndex:(matchRange.location + matchRange.length)]];
    return resultString;
  }
  return url;
}

- (NSArray*)bookmarksWithString:(NSString*)searchString inFieldWithTag:(int)tag
{
  NSMutableArray *matchingBookmarks = [NSMutableArray array];

  // see if our kids match
  NSEnumerator *enumerator = [[self children] objectEnumerator];
  id childItem;
  while ((childItem = [enumerator nextObject])) {
    if ([childItem isKindOfClass:[Bookmark class]]) {
      if ([childItem matchesString:searchString inFieldWithTag:tag])
        [matchingBookmarks addObject:childItem];
    }
    else if ([childItem isKindOfClass:[BookmarkFolder class]]) {
      // recurse, adding found items to the existing matches
      NSArray *matchingDescendents = [childItem bookmarksWithString:searchString inFieldWithTag:tag];
      [matchingBookmarks addObjectsFromArray:matchingDescendents];
    }
  }
  return matchingBookmarks;
}

- (BOOL)containsChildItem:(BookmarkItem*)inItem
{
  if (inItem == self)
    return YES;

  unsigned int numChildren = [mChildArray count];
  for (unsigned int i = 0; i < numChildren; i++) {
    BookmarkItem* curChild = [mChildArray objectAtIndex:i];
    if (curChild == inItem)
      return YES;

    if ([curChild isKindOfClass:[BookmarkFolder class]]) {
      if ([(BookmarkFolder *)curChild containsChildItem:inItem])
        return YES;
    }
  }

  return NO;
}

//
// Notification stuff
//

- (void)itemAddedNote:(BookmarkItem *)theItem atIndex:(unsigned)anIndex
{
  if ([[BookmarkManager sharedBookmarkManager] areChangeNotificationsSuppressed])
    return;

  NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
                                            theItem, BookmarkFolderChildKey,
           [NSNumber numberWithUnsignedInt:anIndex], BookmarkFolderChildIndexKey,
                                                     nil];

  NSNotification *note = [NSNotification notificationWithName:BookmarkFolderAdditionNotification object:self userInfo:dict];
  [[NSNotificationCenter defaultCenter] postNotification:note];
}

- (void)itemRemovedNote:(BookmarkItem *)theItem
{
  if ([[BookmarkManager sharedBookmarkManager] areChangeNotificationsSuppressed])
    return;

  NSDictionary *dict = [NSDictionary dictionaryWithObject:theItem forKey:BookmarkFolderChildKey];
  NSNotification *note = [NSNotification notificationWithName:BookmarkFolderDeletionNotification object:self userInfo:dict];
  [[NSNotificationCenter defaultCenter] postNotification:note];
}

- (void)itemChangedNote:(BookmarkItem *)theItem
{
  [self itemUpdatedNote:kBookmarkItemChildrenChangedMask];
}

- (void)notifyChildrenChanged
{
  [self itemUpdatedNote:kBookmarkItemChildrenChangedMask];
}

- (void)dockMenuChanged:(NSNotification *)note
{
  if (([self isDockMenu]) && ([note object] != self))
    [self setIsDockMenu:NO];
}


#pragma mark -

//
// reading/writing from/to disk
//

- (BOOL)readNativeDictionary:(NSDictionary *)aDict
{
  [self setTitle:[aDict objectForKey:BMTitleKey]];
  [self setItemDescription:[aDict objectForKey:BMFolderDescKey]];
  [self setShortcut:[aDict objectForKey:BMFolderShortcutKey]];
  [self setUUID:[aDict objectForKey:BMUUIDKey]];

  unsigned int flag = [[aDict objectForKey:BMFolderTypeKey] unsignedIntValue];
  // on the off chance we've imported somebody else's bookmarks after startup,
  // we need to clear any super special flags on it.  if we have a shared bookmark manager,
  // we're not in startup, so clear things out.
  if ([[BookmarkManager sharedBookmarkManager] bookmarksLoaded]) {
    if ((flag & kBookmarkRootFolder) != 0)
      flag &= ~kBookmarkRootFolder;
    if ((flag & kBookmarkToolbarFolder) != 0)
      flag &= ~kBookmarkToolbarFolder;
    if ((flag & kBookmarkSmartFolder) != 0)
      flag &= ~kBookmarkSmartFolder;
  }
  [self setSpecialFlag:flag];

  NSEnumerator* enumerator = [[aDict objectForKey:BMChildrenKey] objectEnumerator];
  BOOL success = YES;
  id aKid;
  while ((aKid = [enumerator nextObject]) && success) {
    if ([aKid objectForKey:BMChildrenKey])
      success = [self addBookmarkFolderFromNativeDict:(NSDictionary *)aKid];
    else
      success = [self addBookmarkFromNativeDict:(NSDictionary *)aKid];
  }
  return success;
}

- (BOOL)readSafariDictionary:(NSDictionary *)aDict
{
  [self setTitle:[aDict objectForKey:BMTitleKey]];

  BOOL success = YES;
  NSEnumerator* enumerator = [[aDict objectForKey:BMChildrenKey] objectEnumerator];
  id aKid;
  while ((aKid = [enumerator nextObject]) && success) {
    if ([[aKid objectForKey:SafariTypeKey] isEqualToString:SafariLeaf])
      success = [self addBookmarkFromSafariDict:(NSDictionary *)aKid];
    else if ([[aKid objectForKey:SafariTypeKey] isEqualToString:SafariList])
      success = [self addBookmarkFolderFromSafariDict:(NSDictionary *)aKid];
    // might also be a WebBookmarkTypeProxy - we'll ignore those
  }

  if ([[aDict objectForKey:SafariAutoTab] boolValue])
    [self setIsGroup:YES];

  return success;
}

//
// -writeBookmarksMetadataToPath:
//
// Recursively tells each of its children to write out its spotlight metadata at the
// given path. Folders themselves aren't written to the metadata store.
//
- (void)writeBookmarksMetadataToPath:(NSString*)inPath
{
  if (![self isSmartFolder]) {
    id item;
    NSEnumerator* enumerator = [mChildArray objectEnumerator];
    // do it for each child
    while ((item = [enumerator nextObject]))
      [item writeBookmarksMetadataToPath:inPath];
  }
}

//
// -removeBookmarksMetadataFromPath
//
// Recursively tell each child to remove its spotlight metadata from the given path. Folders
// themselves have no metadata.
//
- (void)removeBookmarksMetadataFromPath:(NSString*)inPath
{
  if (![self isSmartFolder]) {
    id item;
    NSEnumerator* enumerator = [mChildArray objectEnumerator];
    // do it for each child
    while ((item = [enumerator nextObject]))
      [item removeBookmarksMetadataFromPath:inPath];
  }
}

- (NSDictionary *)writeNativeDictionary
{
  if ([self isSmartFolder])
    return nil;

  id item;
  NSMutableArray* children = [NSMutableArray arrayWithCapacity:[mChildArray count]];
  NSEnumerator* enumerator = [mChildArray objectEnumerator];
  //get chillins first
  while ((item = [enumerator nextObject])) {
    id aDict = [item writeNativeDictionary];
    if (aDict)
      [children addObject:aDict];
  }

  NSMutableDictionary* folderDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                            children, BMChildrenKey,
                   [self savedTitle], BMTitleKey,
                                      nil];

  if (mSpecialFlag)
    [folderDict setObject:[self savedSpecialFlag] forKey:BMFolderTypeKey];

  if ([mUUID length])
    [folderDict setObject:mUUID forKey:BMUUIDKey];

  if ([[self itemDescription] length])
    [folderDict setObject:[self itemDescription] forKey:BMFolderDescKey];

  if ([[self shortcut] length])
    [folderDict setObject:[self shortcut] forKey:BMFolderShortcutKey];

  return folderDict;
}

- (NSDictionary *)writeSafariDictionary
{
  if (![self isSmartFolder]) {
    id item;
    NSMutableArray* children = [NSMutableArray array];
    NSEnumerator* enumerator = [mChildArray objectEnumerator];
    //get chillins first
    while ((item = [enumerator nextObject])) {
      id aDict = [item writeSafariDictionary];
      if (aDict)
        [children addObject:aDict];
    }
    NSString *titleString;
    if ([self isToolbar])
      titleString = @"BookmarksBar";
    else if ([[BookmarkManager sharedBookmarkManager] bookmarkMenuFolder] == self)
      titleString = @"BookmarksMenu";
    else
      titleString = [self title];

    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
      titleString, BMTitleKey,
      SafariList, SafariTypeKey,
      [self UUID], SafariUUIDKey,
      children, BMChildrenKey,
      nil];

    if ([self isGroup])
      [dict setObject:[NSNumber numberWithBool:YES] forKey:SafariAutoTab];
    return dict;
    // now we handle the smart folders
  }
  else {
    NSString *SafariProxyKey = @"WebBookmarkIdentifier";
    NSString *SafariProxyType = @"WebBookmarkTypeProxy";
    if ([[BookmarkManager sharedBookmarkManager] rendezvousFolder] == self) {
      return [NSDictionary dictionaryWithObjectsAndKeys:
        @"Bonjour", BMTitleKey,
        @"Bonjour Bookmark Proxy Identifier", SafariProxyKey,
        SafariProxyType, SafariTypeKey,
        [self UUID], SafariUUIDKey,
        nil];
    }
    else if ([[BookmarkManager sharedBookmarkManager] addressBookFolder] == self) {
      return [NSDictionary dictionaryWithObjectsAndKeys:
        @"Address Book", BMTitleKey,
        @"Address Book Bookmark Proxy Identifier", SafariProxyKey,
        SafariProxyType, SafariTypeKey,
        [self UUID], SafariUUIDKey,
        nil];
    }
    else if ([[BookmarkManager sharedBookmarkManager] historyFolder] == self) {
      return [NSDictionary dictionaryWithObjectsAndKeys:
        @"History", BMTitleKey,
        @"History Bookmark Proxy Identifier", SafariProxyKey,
        SafariProxyType, SafariTypeKey,
        [self UUID], SafariUUIDKey,
        nil];
    }
  }
  return nil;
}

@end
