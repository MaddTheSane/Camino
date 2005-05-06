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
 *   Josh Aas <josha@mac.com>
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

#include "nsString.h"
#include "nsIContent.h"
#include "nsIFile.h"
#include "nsAppDirectoryServiceDefs.h"
#import "NSString+Utils.h"
#import "PreferenceManager.h"
#import "RunLoopMessenger.h"
#import "BookmarkManager.h"
#import "Bookmark.h"
#import "BookmarkFolder.h"
#import "BookmarkToolbar.h"
#import "BookmarkImportDlgController.h"
#import "BookmarkOutlineView.h"
#import "BookmarkViewController.h"
#import "KindaSmartFolderManager.h"
#import "BrowserWindowController.h"
#import "MainController.h" 

@interface BookmarkManager (Private)
- (void)setPathToBookmarkFile:(NSString *)aString;
- (void)setupSmartCollections;
- (void)delayedStartupItems;
- (void)writeBookmarks:(NSNotification *)note;
- (BookmarkFolder *)findDockMenuFolderInFolder:(BookmarkFolder *)aFolder;
- (void)writeBookmarksMetadataForSpotlight;
@end

@implementation BookmarkManager

static NSString *WriteBookmarkNotification = @"write_bms";
static BookmarkManager* gBookmarksManager = nil;
static NSLock *startupLock = nil;
static unsigned gFirstUserCollection = 0;


//
// Class Methods - we only need RunLoopMessenger for 10.1 Compat. On 10.2+, there
// are built-in methods for running something on the main thread.
//
+ (void)startBookmarksManager:(RunLoopMessenger *)mainThreadRunLoopMessenger
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  if (!gBookmarksManager && !startupLock)
  {
    startupLock = [[NSLock alloc] init];
    NSLock *avoidRaceLock;
    BookmarkManager *aManager = [[BookmarkManager alloc] init];
    [startupLock lock];
    gBookmarksManager = aManager;
    avoidRaceLock = startupLock;
    startupLock = nil;
    [avoidRaceLock unlock];
    [avoidRaceLock release];
    [mainThreadRunLoopMessenger target:gBookmarksManager performSelector:@selector(delayedStartupItems)];
  }
  [pool release];
}

+ (BookmarkManager*)sharedBookmarkManager
{
  BookmarkManager *theManager;
  [startupLock lock];
  theManager = gBookmarksManager;
  [startupLock unlock];
  return theManager;
}

+ (NSString*)managerStartedNotification
{
  return @"BookmarkManagerStartedNotification";
}

// serialize to an array of UUIDs
+ (NSArray*)serializableArrayWithBookmarkItems:(NSArray*)bmArray
{
  NSMutableArray* dataArray = [NSMutableArray arrayWithCapacity:[bmArray count]];
  NSEnumerator* bmEnum = [bmArray objectEnumerator];
  id bmItem;
  while ((bmItem = [bmEnum nextObject]))
  {
    [dataArray addObject:[bmItem UUID]];
  }
  
  return dataArray;
}

+ (NSArray*)bookmarkItemsFromSerializableArray:(NSArray*)dataArray
{
  NSMutableArray* itemsArray = [NSMutableArray arrayWithCapacity:[dataArray count]];
  NSEnumerator* dataEnum = [dataArray objectEnumerator];
  BookmarkManager* bmManager = [BookmarkManager sharedBookmarkManager];
  id itemUUID;
  while ((itemUUID = [dataEnum nextObject]))
  {
    BookmarkItem* foundItem = [bmManager itemWithUUID:itemUUID];
    if (foundItem)
      [itemsArray addObject:foundItem];
    else
      NSLog(@"Failed to find bm item with uuid %@", itemUUID);
  }
  
  return itemsArray;
}

#pragma mark -

//
// Init, dealloc - better get inited on background thread.
//
- (id)init
{
  if ((self = [super init])) {
    BookmarkFolder* root = [[BookmarkFolder alloc] init];
    [root setParent:self];    // XXX why?
    [root setIsRoot:YES];
    [root setTitle:NSLocalizedString(@"BookmarksRootName", @"")];
    [self setRootBookmarks:root];
    [root release];
    // Turn off the posting of update notifications while reading in bookmarks.
    // All interested parties haven't been init'd yet, and/or will recieve the
    // managerStartedNotification when setup is actually complete.
    [BookmarkItem setSuppressAllUpdateNotifications:YES];
    if (![self readBookmarks]) {
      // one of two things happened. we are importing off an old xml file
      // for startup, OR we totally muffed reading the bookmarks.  we'll hope
      // it was the former.
      if ([root count] > 0) {
        // find the xml toolbar menu.  it'll be in top level of bookmark menu folder
        NSMutableArray *childArray = [[self bookmarkMenuFolder] childArray];
        unsigned i, j=[childArray count];
        id anObject;
        for (i=0;i < j; i++) {
          anObject = [childArray objectAtIndex:i];
          if ([anObject isKindOfClass:[BookmarkFolder class]]) {
            if ([(BookmarkFolder *)anObject isToolbar]) { //triumph!
              [[self bookmarkMenuFolder] moveChild:anObject toBookmarkFolder:root atIndex:kToolbarContainerIndex];
              break;
            }
          }
        }
      } else {  //we are so totally screwed
        BookmarkFolder *aFolder = [root addBookmarkFolder];
        if ([root count] == 1) {
          [aFolder setTitle:NSLocalizedString(@"Bookmark Menu",@"Bookmark Menu")];
          aFolder = [root addBookmarkFolder];
        }
        [aFolder setTitle:NSLocalizedString(@"Bookmark Toolbar",@"Bookmark Toolbar")];
      }
    }
    [BookmarkItem setSuppressAllUpdateNotifications:NO];
    // setup special folders
    [self setupSmartCollections];
    mSmartFolderManager = [[KindaSmartFolderManager alloc] initWithBookmarkManager:self];
    // at some point, f'd up setting the bookmark toolbar folder special flag.
    // this'll handle that little boo-boo for the time being
    [[self toolbarFolder] setIsToolbar:YES];
    [[self toolbarFolder] setTitle:NSLocalizedString(@"Bookmark Bar",@"Bookmark Bar")];
    [[self bookmarkMenuFolder] setTitle:NSLocalizedString(@"Bookmark Menu","Bookmark Menu")]; 
    // don't do this until after we've read in the bookmarks
    mUndoManager = [[NSUndoManager alloc] init];
    // Generic notifications for Bookmark Client
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(bookmarkAdded:) name:BookmarkFolderAdditionNotification object:nil];
    [nc addObserver:self selector:@selector(bookmarkRemoved:) name:BookmarkFolderDeletionNotification object:nil];
    [nc addObserver:self selector:@selector(bookmarkChanged:) name:BookmarkItemChangedNotification object:nil];
    [nc addObserver:self selector:@selector(writeBookmarks:) name:WriteBookmarkNotification object:nil];

    // pitch everything in the cache and start over. Changes made from here will be incremental. It's
    // easier this way in case someone changed the plist directly, we know at startup we always have
    // the most up-to-date cache.
    [self writeBookmarksMetadataForSpotlight];
  }
  
  return self;
}

-(void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];

  [mTop10Container release];
  [mRendezvousContainer release];
  [mAddressBookContainer release];
  [mLastUsedFolder release];
  
  [mUndoManager release];
  [mRootBookmarks release];
  [mPathToBookmarkFile release];
  [mMetadataPath release];
  [mSmartFolderManager release];

  if (mImportDlgController)
    [mImportDlgController release];

  if (self == gBookmarksManager)
    gBookmarksManager = nil;

  [super dealloc];
}

// Perform additional setup items on the main thread.
- (void)delayedStartupItems
{
  [[NSApp delegate] setupBookmarkMenus:gBookmarksManager];
  
  [mSmartFolderManager postStartupInitialization:self];
  [[self toolbarFolder] refreshIcon];

  // load favicons (w/out hitting the network, cache only). Spread it out so that we only get
  // ten every three seconds to avoid locking up the UI with large bookmark lists.
  if ([[PreferenceManager sharedInstance] getBooleanPref:"browser.chrome.favicons" withSuccess:NULL]) {
    NSArray *allBookmarks = [[self rootBookmarks] allChildBookmarks];
    float delay = 3.0; //default value
    int count = [allBookmarks count];
    for (int i = 0; i < count; ++i) {
      if (i % 10 == 0)
        delay += 3.0;
      [[allBookmarks objectAtIndex:i] performSelector:@selector(refreshIcon) withObject:nil afterDelay:delay];
    }
  }

  // broadcast to everyone interested that we're loaded and ready for public consumption
  [[NSNotificationCenter defaultCenter] postNotificationName:[BookmarkManager managerStartedNotification] object:nil];
}

- (void)shutdown
{
  [self writeBookmarks:nil];
}


//
// smart collections, as of now, are Rendezvous, Address Book, Top 10 List.
// We also have history, but that just points to the real history stuff.
- (void)setupSmartCollections
{
  int collectionIndex = 2;  //skip 0 and 1, the menu and toolbar folders
  
  // add history
  BookmarkFolder *temp = [[BookmarkFolder alloc] init];
  [temp setTitle:NSLocalizedString(@"History",@"History")];
  [temp setIsSmartFolder:YES];
  [mRootBookmarks insertChild:temp atIndex:(collectionIndex++) isMove:NO];
  [temp release];
  
  // note: don't release the smart folders until dealloc, so they persist even if turned off and on
  
  // add top 10 list
  mTop10Container = [[BookmarkFolder alloc] init];
  [mTop10Container setTitle:NSLocalizedString(@"Top Ten List",@"Top Ten List")];
  [mTop10Container setIsSmartFolder:YES];
  [mRootBookmarks insertChild:mTop10Container atIndex:(collectionIndex++) isMove:NO];
  
  mRendezvousContainer = [[BookmarkFolder alloc] init];
  [mRendezvousContainer setTitle:NSLocalizedString(@"Rendezvous",@"Rendezvous")];
  [mRendezvousContainer setIsSmartFolder:YES];
  [mRootBookmarks insertChild:mRendezvousContainer atIndex:(collectionIndex++) isMove:NO];
    
  mAddressBookContainer = [[BookmarkFolder alloc] init];
  [mAddressBookContainer setTitle:NSLocalizedString(@"Address Book",@"Address Book")];
  [mAddressBookContainer setIsSmartFolder:YES];
  [mRootBookmarks insertChild:mAddressBookContainer atIndex:(collectionIndex++) isMove:NO];
      
  gFirstUserCollection = collectionIndex;
  
  // set pretty icons
  
  [[self historyFolder] setIcon:[NSImage imageNamed:@"historyicon"]];
  [[self top10Folder] setIcon:[NSImage imageNamed:@"top10_icon"]];
  [[self bookmarkMenuFolder] setIcon:[NSImage imageNamed:@"bookmarkmenu_icon"]];
  [[self toolbarFolder] setIcon:[NSImage imageNamed:@"bookmarktoolbar_icon"]];
  [[self rendezvousFolder] setIcon:[NSImage imageNamed:@"rendezvous_icon"]];
  [[self addressBookFolder] setIcon:[NSImage imageNamed:@"addressbook_icon"]];
}

//
// Getter/Setter methods
//

-(BookmarkFolder *) rootBookmarks
{
  return mRootBookmarks;
}

-(BookmarkFolder *) dockMenuFolder
{
  BookmarkFolder *folder = [self findDockMenuFolderInFolder:[self rootBookmarks]];
  if (folder)
    return folder;
  else
    return [self top10Folder];
}

- (BookmarkFolder *)findDockMenuFolderInFolder:(BookmarkFolder *)aFolder
{
  NSEnumerator *enumerator = [[aFolder childArray] objectEnumerator];
  id aKid;
  BookmarkFolder *foundFolder = nil;
  while ((!foundFolder) && (aKid = [enumerator nextObject])) {
    if ([aKid isKindOfClass:[BookmarkFolder class]]) {
      if ([(BookmarkFolder *)aKid isDockMenu])
        return aKid;
      else
        foundFolder = [self findDockMenuFolderInFolder:aKid];
    }
  }
  return foundFolder;
}

-(BookmarkFolder *)top10Folder
{
  return mTop10Container;
}

-(BookmarkFolder *) toolbarFolder
{
  return [[self rootBookmarks] objectAtIndex:kToolbarContainerIndex];
}

-(BookmarkFolder *) bookmarkMenuFolder
{
  return [[self rootBookmarks] objectAtIndex:kBookmarkMenuContainerIndex];
}

-(BookmarkFolder *) historyFolder
{
  return [[self rootBookmarks] objectAtIndex:kHistoryContainerIndex];
}

-(BookmarkFolder *) rendezvousFolder
{
  return mRendezvousContainer;
}

-(BookmarkFolder *) addressBookFolder
{
  return mAddressBookContainer;
}

- (BookmarkFolder*)lastUsedBookmarkFolder
{
  return mLastUsedFolder;
}

- (void)setLastUsedBookmarkFolder:(BookmarkFolder*)inFolder
{
  [mLastUsedFolder autorelease];
  mLastUsedFolder = [inFolder retain];
}

-(BookmarkItem*) itemWithUUID:(NSString*)uuid
{
  return [mRootBookmarks itemWithUUID:uuid];
}

-(NSUndoManager *) undoManager
{
  return mUndoManager;
}

-(unsigned) firstUserCollection
{
  return gFirstUserCollection;
}

- (void)setPathToBookmarkFile:(NSString *)aString
{
  [aString retain];
  [mPathToBookmarkFile release];
  mPathToBookmarkFile = aString;
}

-(void) setRootBookmarks:(BookmarkFolder *)anArray
{
  if (anArray != mRootBookmarks) {
    [anArray retain];
    [mRootBookmarks release];
    mRootBookmarks = anArray;
  }
}

-(NSArray *)resolveBookmarksKeyword:(NSString *)keyword
{
  NSArray *resolvedArray = nil;
  if (![keyword isEqualToString:@""])
    resolvedArray = [[self rootBookmarks] resolveKeyword:keyword];
  if (resolvedArray)
    return resolvedArray;
  return [NSArray arrayWithObject:keyword];
}

// a null container indicates to search all bookmarks
-(NSArray *)searchBookmarksContainer:(BookmarkFolder*)container forString:(NSString *)searchString inFieldWithTag:(int)tag
{
  if ((searchString) && [searchString length] > 0)
  {
    BookmarkFolder* searchContainer = container ? container : [self rootBookmarks];
    NSSet *matchingSet = [searchContainer bookmarksWithString:searchString inFieldWithTag:tag];
    return [matchingSet allObjects];
  }
  return nil;
}

//
// Drag & drop
//

-(BOOL) isDropValid:(NSArray *)items toFolder:(BookmarkFolder *)parent
{
  // Enumerate through items, make sure we're not being dropped into
  // a child OR ourself OR that the a bookmark or group is going into root bookmarks.
  NSEnumerator *enumerator = [items objectEnumerator];
  id aBookmark;
  while ((aBookmark = [enumerator nextObject])) {
    if ([aBookmark isKindOfClass:[BookmarkFolder class]]) {
      if (aBookmark == parent)
        return NO;
      if ((parent == [self rootBookmarks]) && [(BookmarkFolder *)aBookmark isGroup])
        return NO;
    } else if ([aBookmark isKindOfClass:[Bookmark class]]) {
      if (parent == [self rootBookmarks])
        return NO;
    }
    if ([parent isChildOfItem:aBookmark])
      return NO;
  }
  return YES;
}

// unified context menu generator for all kinds of bookmarks
// this can be called from a bookmark outline view
// or from a bookmark button, which should pass a nil outlineView
- (NSMenu *)contextMenuForItem:(id)item fromView:(BookmarkOutlineView *)outlineView target:(id)target
{
  // don't do anything if item == nil
  if (!item)
    return nil;
  
  NSMenu * contextMenu = [[[NSMenu alloc] initWithTitle:@"notitle"] autorelease];
  BOOL isFolder = [item isKindOfClass:[BookmarkFolder class]];
  NSString * menuTitle;
  
  // open in new window
  if (isFolder)
    menuTitle = NSLocalizedString(@"Open Tabs in New Window", @"");
  else
    menuTitle = NSLocalizedString(@"Open in New Window", @"");
  NSMenuItem *menuItem = [[[NSMenuItem alloc] initWithTitle:menuTitle action:@selector(openBookmarkInNewWindow:) keyEquivalent:@""] autorelease];
  [menuItem setTarget:target];
  [contextMenu addItem:menuItem];
  
  // open in new tab
  if (isFolder)
    menuTitle = NSLocalizedString(@"Open in New Tabs", @"");
  else
    menuTitle = NSLocalizedString(@"Open in New Tab", @"");
  menuItem = [[[NSMenuItem alloc] initWithTitle:menuTitle action:@selector(openBookmarkInNewTab:) keyEquivalent:@""] autorelease];
  [menuItem setTarget:target];
  [contextMenu addItem:menuItem];
  
  if (!outlineView || ([outlineView numberOfSelectedRows] == 1)) {
    [contextMenu addItem:[NSMenuItem separatorItem]];
    menuTitle = NSLocalizedString(@"Get Info", @"");
    menuItem = [[[NSMenuItem alloc] initWithTitle:menuTitle action:@selector(showBookmarkInfo:) keyEquivalent:@""] autorelease];
    [menuItem setTarget:target];
    [contextMenu addItem:menuItem];
  }
  
  if ([item isKindOfClass:[BookmarkFolder class]]) {
    menuTitle = NSLocalizedString(@"Use as Dock Menu", @"");
    menuItem = [[[NSMenuItem alloc] initWithTitle:menuTitle action:@selector(makeDockMenu:) keyEquivalent:@""] autorelease];
    [menuItem setTarget:item];
    [contextMenu addItem:menuItem];
  }
  
  BOOL allowNewFolder = NO;
  if ([target isKindOfClass:[BookmarkViewController class]]) {
    if (![[target activeCollection] isSmartFolder])
      allowNewFolder = YES;
  } else
    allowNewFolder = YES;

  if (allowNewFolder) {
    // space
    [contextMenu addItem:[NSMenuItem separatorItem]];
    // create new folder
    menuTitle = NSLocalizedString(@"Create New Folder...", @"");
    menuItem = [[[NSMenuItem alloc] initWithTitle:menuTitle action:@selector(addBookmarkFolder:) keyEquivalent:@""] autorelease];
    [menuItem setTarget:target];
    [contextMenu addItem:menuItem];
  }
  
  // if we're not in a smart collection (other than history)
  if (!outlineView ||
      ![target isKindOfClass:[BookmarkViewController class]] ||
      ![[target activeCollection] isSmartFolder] ||
      ([target activeCollection] == [self historyFolder])) {
    // space
    [contextMenu addItem:[NSMenuItem separatorItem]];
    // delete
    menuTitle = NSLocalizedString(@"Delete", @"");
    menuItem = [[[NSMenuItem alloc] initWithTitle:menuTitle action:@selector(deleteBookmarks:) keyEquivalent:@""] autorelease];
    [menuItem setTarget:target];
    [contextMenu addItem:menuItem];
  }
  return contextMenu;
}

#pragma mark -
//
// BookmarkClient protocol - so we know when to write out
//
- (void)bookmarkAdded:(NSNotification *)note
{
  BookmarkItem* bmItem = [[note userInfo] objectForKey:BookmarkFolderChildKey];
  if ([MainController supportsSpotlight]) {
    BookmarkFolder* addedTo = [note object];
    if (![addedTo isSmartFolder] && [bmItem isKindOfClass:[Bookmark class]])
      [bmItem writeBookmarksMetadataToPath:mMetadataPath];
  }
  [self bookmarkChanged:nil];
}

- (void)bookmarkRemoved:(NSNotification *)note
{
  [self bookmarkChanged:nil];
  
  BookmarkItem* bmItem = [[note userInfo] objectForKey:BookmarkFolderChildKey];
  if ([MainController supportsSpotlight]) {
    BookmarkFolder* addedTo = [note object];
    if (![addedTo isSmartFolder])
      [bmItem removeBookmarksMetadataFromPath:mMetadataPath];
  }
  if ([bmItem isKindOfClass:[BookmarkFolder class]])
  {
    if ([(BookmarkFolder*)bmItem containsChildItem:mLastUsedFolder])
    {
      [mLastUsedFolder release];
      mLastUsedFolder = nil;
    }
  }
}

- (void)bookmarkChanged:(NSNotification *)aNote
{
  if (aNote) {
    // have this item rewrite its metadata. |aNote| is non-nil when a bookmark has really
    // changed, not when we're using it from other routines to force a write bookmark notification. 
    if ([MainController supportsSpotlight]) {
      id item = [aNote object];
      if ([item isKindOfClass:[Bookmark class]])
        [item writeBookmarksMetadataToPath:mMetadataPath];
    }
  }
  NSNotificationQueue* nq = [NSNotificationQueue defaultQueue];
  NSNotification *note = [NSNotification notificationWithName:WriteBookmarkNotification object:self userInfo:nil];
  [nq enqueueNotification:note postingStyle:NSPostASAP coalesceMask:NSNotificationCoalescingOnName forModes:[NSArray arrayWithObject:NSDefaultRunLoopMode]];   
}

- (void)writeBookmarks:(NSNotification *)note
{
  [self writePropertyListFile:mPathToBookmarkFile];
}

//
// -writeBookmarksMetadataForSpotlight
//
// If we're running on Tiger, write out a flat list of all bookmarks in the caches folder
// so that Spotlight can parse them. We don't need to write our own metadata plugin, we piggyback
// the one that Safari uses which launches the default browser when selected. This blows
// away any previous cache and ensures that everything is up-to-date.
//
- (void)writeBookmarksMetadataForSpotlight
{
  if ([MainController supportsSpotlight]) {
    // build up the path and ensure the folders are present along the way. Removes the
    // previous version entirely.
    NSString* metadataPath = [@"~/Library/Caches/Metadata" stringByExpandingTildeInPath];
    [[NSFileManager defaultManager] createDirectoryAtPath:metadataPath attributes:nil];
    metadataPath = [metadataPath stringByAppendingPathComponent:@"Camino"];
    [[NSFileManager defaultManager] removeFileAtPath:metadataPath handler:nil];
    [[NSFileManager defaultManager] createDirectoryAtPath:metadataPath attributes:nil];
    
    // write all the bookmarks except for smart folders. wBMTP ignores smart folders
    [mRootBookmarks writeBookmarksMetadataToPath:metadataPath];
    
    // save the path for later
    [mMetadataPath autorelease];
    mMetadataPath = [metadataPath retain];
  }
}

#pragma mark -
//
// Reading/Importing bookmark files
//
-(BOOL) readBookmarks
{
  NSString *profileDir = [[PreferenceManager sharedInstance] newProfilePath];  

  //
  // figure out where Bookmarks.plist is and store it as mPathToBookmarkFile
  // if there is a Bookmarks.plist, read it
  // if there isn't a Bookmarks.plist, but there is a bookmarks.xml, read it.
  // if there isn't either, move default Bookmarks.plist to profile dir & read it.
  //
  NSFileManager *fM = [NSFileManager defaultManager];
  NSString *bookmarkPath = [profileDir stringByAppendingPathComponent:@"bookmarks.plist"];
  [self setPathToBookmarkFile:bookmarkPath];
  if ([fM isReadableFileAtPath:bookmarkPath]) {
    if ([self readPropertyListFile:bookmarkPath intoFolder:[self rootBookmarks]])
      return YES; // triumph!
  } else if ([fM isReadableFileAtPath:[profileDir stringByAppendingPathComponent:@"bookmarks.xml"]]){
    BookmarkFolder *aFolder = [[self rootBookmarks] addBookmarkFolder];
    [aFolder setTitle:NSLocalizedString(@"Bookmark Menu",@"Bookmark Menu")];
    if ([self readCaminoXMLFile:[profileDir stringByAppendingPathComponent:@"bookmarks.xml"] intoFolder:[self bookmarkMenuFolder]])
      return NO; // triumph! - will do post processing in init
  } else {
    NSString *defaultBookmarks = [[NSBundle mainBundle] pathForResource:@"bookmarks" ofType:@"plist"];
    if ([fM copyPath:defaultBookmarks toPath:bookmarkPath handler:nil]) {
        if ([self readPropertyListFile:bookmarkPath intoFolder:[self rootBookmarks]])
          return YES; //triumph!
    }
  }
  // if we're here, we've had a problem
  NSString *alert     = NSLocalizedString(@"CorruptedBookmarksAlert",@"");
  NSString *message   = NSLocalizedString(@"CorruptedBookmarksMsg",@"");
  NSString *okButton  = NSLocalizedString(@"OKButtonText",@"");
  NSRunAlertPanel(alert, message, okButton, nil, nil);
  return NO;
}

-(void) startImportBookmarks
{
  if (!mImportDlgController)
    mImportDlgController = [[BookmarkImportDlgController alloc] initWithWindowNibName:@"BookmarkImportDlg"];
  [mImportDlgController buildAvailableFileList];
  [mImportDlgController showWindow:nil];
}

-(BOOL) importBookmarks:(NSString *)pathToFile intoFolder:(BookmarkFolder *)aFolder
{
  //I feel dirty doing it this way.  But we'll check file extension
  //to figure out how to handle this.  Damn you, Steve Jobs!!
  NSUndoManager *undoManager = [self undoManager];
  [undoManager beginUndoGrouping];
  BOOL success = NO;
  NSString *extension =[pathToFile pathExtension];
  if ([extension isEqualToString:@""]) // we'll go out on a limb here
    success = [self readOperaFile:pathToFile intoFolder:aFolder];
  else if ([extension isEqualToString:@"html"] || [extension isEqualToString:@"htm"])
    success = [self readHTMLFile:pathToFile intoFolder:aFolder];
  else if ([extension isEqualToString:@"xml"])
    success = [self readCaminoXMLFile:pathToFile intoFolder:aFolder];
  else if ([extension isEqualToString:@"plist"] || !success)
    success = [self readPropertyListFile:pathToFile intoFolder:aFolder];
  // we don't know the extension, or we failed to load.  we'll take another
  // crack at it trying everything we know.
  if (!success) {
    success = [self readOperaFile:pathToFile intoFolder:aFolder];
    if (!success) {
      success = [self readHTMLFile:pathToFile intoFolder:aFolder];
      if (!success) {
        success = [self readCaminoXMLFile:pathToFile intoFolder:aFolder];
      }
    }
  }
  [[undoManager prepareWithInvocationTarget:[self rootBookmarks]] deleteChild:aFolder];
  [undoManager endUndoGrouping];
  [undoManager setActionName:NSLocalizedString(@"Import Bookmarks",@"Import Bookmarks")];
  return success;
}

// spits out text file as NSString with "proper" encoding based on pretty shitty detection
-(NSString *)decodedTextFile:(NSString *)pathToFile
{
  NSData* fileAsData = [[NSData alloc] initWithContentsOfFile:pathToFile];
  if (!fileAsData) {
    NSLog(@"decodedTextFile: file %@ cannot be read.", pathToFile);
    return nil;
  }
  // we're gonna assume for now it's ascii and hope for the best.
  // i'm doing this because I think we can always read it in as ascii,
  // while it might fail if we assume default system encoding.  i don't
  // know this for sure.  but we'll have to do 2 decodings.  big whoop.
  NSString *fileString = [[NSString alloc] initWithData:fileAsData encoding:NSASCIIStringEncoding];
  if (!fileString) {
    NSLog(@"decodedTextFile: file %@ doesn't want to become a string. Exiting.", pathToFile);
    [fileAsData release];
    return nil;
  }

  // Create a dictionary with possible encodings.  As I figure out more possible encodings,
  // I'll add them to the dictionary.
  NSString *utfdash8Key = @"content=\"text/html; charset=utf-8" ;
  NSString *xmacromanKey = @"content=\"text/html; charset=x-mac-roman";
  NSString *xmacsystemKey = @"CONTENT=\"text/html; charset=X-MAC-SYSTEM";
  NSString *shiftJisKey = @"CONTENT=\"text/html; charset=Shift_JIS";
  NSString *operaUTF8Key = @"encoding = utf8";

  NSDictionary *encodingDict = [NSDictionary dictionaryWithObjectsAndKeys:
    [NSNumber numberWithUnsignedInt:NSUTF8StringEncoding],utfdash8Key,
    [NSNumber numberWithUnsignedInt:NSMacOSRomanStringEncoding],xmacromanKey,
    [NSNumber numberWithUnsignedInt:NSShiftJISStringEncoding],shiftJisKey,
    [NSNumber numberWithUnsignedInt:[NSString defaultCStringEncoding]],xmacsystemKey,
    [NSNumber numberWithUnsignedInt:NSUTF8StringEncoding],operaUTF8Key,
    nil];

  NSEnumerator *keyEnumerator = [encodingDict keyEnumerator];
  id key;
  NSRange aRange;
  while ((key = [keyEnumerator nextObject])) {
    aRange = [fileString rangeOfString:key options:NSCaseInsensitiveSearch];
    if (aRange.location != NSNotFound) {
      [fileString release];
      fileString = [[NSString alloc] initWithData:fileAsData encoding:[[encodingDict objectForKey:key] unsignedIntValue]];
      [fileAsData release];
      return [fileString autorelease];
    }
  }
  // if we're here, we don't have a clue as to the encoding.  we'll guess default
  [fileString release];
  if ((fileString = [[NSString alloc] initWithData:fileAsData encoding:[NSString defaultCStringEncoding]])) {
    NSLog(@"decodedTextFile: file %@ encoding unknown. Assume default and proceed.", pathToFile);
    [fileAsData release];
    return [fileString autorelease];
  }
  // we suck.  this is almost certainly wrong, but oh well.
  NSLog(@"decodedTextFile: file %@ encoding unknown, and NOT default. Use ASCII and proceed.", pathToFile);
  fileString = [[NSString alloc] initWithData:fileAsData encoding:NSASCIIStringEncoding];
  [fileAsData release];
  return [fileString autorelease];
}


-(BOOL)readHTMLFile:(NSString *)pathToFile intoFolder:(BookmarkFolder *)aFolder
{
  // get file as NSString
  NSString* fileAsString = [self decodedTextFile:pathToFile];
  if (!fileAsString) {
    NSLog(@"couldn't read file. bailing out");
    return NO;
  }
  // Set up to scan the bookmark file
  NSScanner *fileScanner = [[NSScanner alloc] initWithString:fileAsString];
  [fileScanner setCharactersToBeSkipped:nil];
  BOOL isNetscape = YES;
  // See if it's a netscape/IE style bookmark file, or omniweb
  NSRange aRange = [fileAsString rangeOfString:@"<!DOCTYPE NETSCAPE-Bookmark-file-1>" options:NSCaseInsensitiveSearch];
  if (aRange.location != NSNotFound) {
    // netscape/IE setup - start after Title attribute
    [fileScanner scanUpToString:@"</TITLE>" intoString:NULL];
    [fileScanner setScanLocation:([fileScanner scanLocation] + 7)];
  } else {
    isNetscape = NO;
    aRange = [fileAsString rangeOfString:@"<bookmarkInfo" options:NSCaseInsensitiveSearch];
    if (aRange.location != NSNotFound)
      // omniweb setup - start at <bookmarkInfo
      [fileScanner scanUpToString:@"<bookmarkInfo" intoString:NULL];
    else {
      NSLog(@"Unrecognized style of Bookmark File. Read fails.");
      [fileScanner release];
      return NO;
    }
  }
  BookmarkFolder *currentArray = aFolder;
  BookmarkItem *currentItem = nil;
  NSScanner *tokenScanner = nil;
  NSString *tokenTag = nil, *tokenString = nil, *tempItem = nil;
  unsigned long scanIndex = 0;
  NSRange tempRange, keyRange;
  BOOL justSetTitle = NO;
  // Scan through file.  As we find a token, do something useful with it.
  while (![fileScanner isAtEnd]) {
    [fileScanner scanUpToString:@"<" intoString:&tokenString];
    scanIndex = [fileScanner scanLocation];
    if ((scanIndex+3) < [fileAsString length]) {
      tokenTag = [[NSString alloc] initWithString:[[fileAsString substringWithRange:NSMakeRange(scanIndex,3)] uppercaseString]];
      // now we pick out if it's something we want to save.
      // check in a "most likely thing first" order
      if ([tokenTag isEqualToString:@"<DT "]) {
        [fileScanner setScanLocation:(scanIndex+1)];
      }
      else if ([tokenTag isEqualToString:@"<P>"]) {
        [fileScanner setScanLocation:(scanIndex+1)];
      }
      else if ([tokenTag isEqualToString:@"<A "]) {
        // adding a new bookmark to end of currentArray.
        [fileScanner scanUpToString:@"</A>" intoString:&tokenString];
        tokenScanner = [[NSScanner alloc] initWithString:tokenString];
        [tokenScanner scanUpToString:@"href=\"" intoString:NULL];
        // might be a menu spacer.  check to make sure.
        if (![tokenScanner isAtEnd]) {
          [tokenScanner setScanLocation:([tokenScanner scanLocation]+6)];
          [tokenScanner scanUpToString:@"\"" intoString:&tempItem];
          if ([tokenScanner isAtEnd]) {
            // we scanned up to the </A> but didn't find a " character ending the HREF. This is probably
            // because we're scanning a bookmarklet that contains an embedded <A></A> so we're in the
            // middle of the string. Just bail and dont import this bookmark. The parser should be able
            // to recover on its own once it gets to the next "<A" token.
            [tokenScanner release];
            [tokenTag release];
            [fileScanner setScanLocation:([fileScanner scanLocation]+1)];
            continue;
          }
          currentItem = [currentArray addBookmark];
          [(Bookmark *)currentItem setUrl:[tempItem stringByRemovingAmpEscapes]];
          [tokenScanner scanUpToString:@">" intoString:&tempItem];
          if (![tokenScanner isAtEnd]) {     // protect against malformed files
            [currentItem setTitle:[[tokenString substringFromIndex:([tokenScanner scanLocation]+1)] stringByRemovingAmpEscapes]];
            justSetTitle = YES;
          }
          // see if we had a keyword
          if (isNetscape) {
            tempRange = [tempItem rangeOfString:@"SHORTCUTURL=\"" options: NSCaseInsensitiveSearch];
            if (tempRange.location != NSNotFound) {
              // throw everything to next " into keyword. A malformed bookmark might not have a closing " which
              // will throw things out of whack slightly, but it's better than crashing.
              keyRange = [tempItem rangeOfString:@"\"" options:0 range:NSMakeRange(tempRange.location+tempRange.length,[tempItem length]-(tempRange.location+tempRange.length))];
              if (keyRange.location != NSNotFound)
                [currentItem setKeyword:[tempItem substringWithRange:NSMakeRange(tempRange.location+tempRange.length,keyRange.location - (tempRange.location+tempRange.length))]];
            }
          }
        }
        [tokenScanner release];
        [fileScanner setScanLocation:([fileScanner scanLocation]+1)];
      }
      else if ([tokenTag isEqualToString:@"<DD"]) {
        // add a description to current item
        [fileScanner scanUpToString:@">" intoString:NULL];
        [fileScanner setScanLocation:([fileScanner scanLocation]+1)];
        [fileScanner scanUpToString:@"<" intoString:&tokenString];
        [currentItem setItemDescription:[tokenString stringByRemovingAmpEscapes]];
        justSetTitle = NO;
      }
      else if ([tokenTag isEqualToString:@"<H3"]) {
        [fileScanner scanUpToString:@"</H3>" intoString:&tokenString];
        currentItem = [currentArray addBookmarkFolder];
        currentArray = (BookmarkFolder *)currentItem;
        tokenScanner = [[NSScanner alloc] initWithString:tokenString];
        if (isNetscape) {
          [tokenScanner scanUpToString:@">" intoString:&tempItem];
          [currentItem setTitle:[[tokenString substringFromIndex:([tokenScanner scanLocation]+1)] stringByRemovingAmpEscapes]];
          // check for group
          tempRange = [tempItem rangeOfString:@"FOLDER_GROUP=\"true\"" options: NSCaseInsensitiveSearch];
          if (tempRange.location != NSNotFound)
            [(BookmarkFolder *)currentItem setIsGroup:YES];          
        } else {
            // have to do this in chunks to handle omniweb 5
          [tokenScanner scanUpToString:@"<a" intoString:NULL];
          [tokenScanner scanUpToString:@">" intoString:NULL];
          [tokenScanner setScanLocation:([tokenScanner scanLocation]+1)];
          [tokenScanner scanUpToString:@"</a>" intoString:&tempItem];
          [currentItem setTitle:[tempItem stringByRemovingAmpEscapes]];
        }
        [tokenScanner release];
        [fileScanner setScanLocation:([fileScanner scanLocation]+1)];
      }
      else if ([tokenTag isEqualToString:@"<DL"]) {
        [fileScanner setScanLocation:(scanIndex+1)];
      }
      else if ([tokenTag isEqualToString:@"</D"]) {
        // note that we only scan for the first two characters of a tag
        // that is why this tag is "</D" and not "</DL"
        currentArray = (BookmarkFolder *)[currentArray parent];
        [fileScanner setScanLocation:(scanIndex+1)];
      }
      else if ([tokenTag isEqualToString:@"<H1"]) {
        [fileScanner scanUpToString:@">" intoString:NULL];
        [fileScanner scanUpToString:@"</H1>" intoString:NULL];
        [fileScanner setScanLocation:([fileScanner scanLocation]+1)];
      }
      else if ([tokenTag isEqualToString:@"<BO"]) {
        //omniweb bookmark marker, no doubt
        [fileScanner scanUpToString:@">" intoString:NULL];
        [fileScanner setScanLocation:([fileScanner scanLocation]+1)];
      }
      else if ([tokenTag isEqualToString:@"</A"]) {
        // some smartass has a description with </A in its title. Probably uses </H's, too.  Dork.
        // It will be just what was added, so append to string of last key.
        // This this can only happen on older Camino html exports.  
        tempItem = [NSString stringWithString:[@"<" stringByAppendingString:[tokenString stringByRemovingAmpEscapes]]];
        if (justSetTitle)
          [currentItem setTitle:[[currentItem title] stringByAppendingString:tempItem]];
        else
          [currentItem setItemDescription:[[currentItem itemDescription] stringByAppendingString:tempItem]];
        [fileScanner setScanLocation:(scanIndex+1)];
      }
      else if ([tokenTag isEqualToString:@"</H"]) {
        // if it's not html, we'll include in previous text string
        tempItem = [[NSString alloc] initWithString:[fileAsString substringWithRange:NSMakeRange(scanIndex,1)]];
        if (([tempItem isEqualToString:@"</HT"]) || ([tempItem isEqualToString:@"</ht"]))
          [fileScanner scanUpToString:@">" intoString:NULL];
        else {
          [tempItem release];
          tempItem = [[NSString alloc] initWithString:[@"<" stringByAppendingString:[tokenString stringByRemovingAmpEscapes]]];
          if (justSetTitle)
            [currentItem setTitle:[[currentItem title] stringByAppendingString:tempItem]];
          else
            [currentItem setItemDescription:[[currentItem itemDescription] stringByAppendingString:tempItem]];
          [fileScanner setScanLocation:([fileScanner scanLocation]+1)];
        }
        [tempItem release];
      }
      // Firefox menu separator
      else if ([tokenTag isEqualToString:@"<HR"]) {
          currentItem = [currentArray addBookmark];
          [(Bookmark *)currentItem setIsSeparator:TRUE];
          [fileScanner setScanLocation:(scanIndex+1)];          
      }
      else { //beats me.  just close the tag out and continue.
        [fileScanner scanUpToString:@">" intoString:NULL];
      }
      [tokenTag release];
    }
  }
  [fileScanner release];
  return YES;
}

-(BOOL)readCaminoXMLFile:(NSString *)pathToFile intoFolder:(BookmarkFolder *)aFolder
{
  NSURL* fileURL = [NSURL fileURLWithPath:pathToFile];
  if (!fileURL) {
    NSLog(@"URL creation failed");
    return NO;
  }
  // Thanks, Apple, for example XML parsing code.
  // Create CFXMLTree from file.  This needs to be released later
  CFXMLTreeRef XMLFileTree = CFXMLTreeCreateWithDataFromURL (kCFAllocatorDefault,
                                                             (CFURLRef)fileURL,
                                                             kCFXMLParserSkipWhitespace,
                                                             kCFXMLNodeCurrentVersion);
  if (!XMLFileTree) {
    NSLog(@"XMLTree creation failed");
    return NO;
  }
  // process top level nodes.  I think we'll find DTD
  // before data - so only need to make 1 pass.
  int count, index;
  CFXMLTreeRef subFileTree;
  CFXMLNodeRef bookmarkNode;
  CFXMLDocumentTypeInfo *docTypeInfo;
  CFURLRef dtdURL;
  BOOL aBool;
  count = CFTreeGetChildCount(XMLFileTree);
  for (index=0;index < count;index++) {
    subFileTree = CFTreeGetChildAtIndex(XMLFileTree,index);
    if (subFileTree) {
      bookmarkNode = CFXMLTreeGetNode(subFileTree);
      if (bookmarkNode) {
        switch (CFXMLNodeGetTypeCode(bookmarkNode)) {
          // make sure it's Camino/Chimera DTD
          case (kCFXMLNodeTypeDocumentType):
            docTypeInfo = (CFXMLDocumentTypeInfo *)CFXMLNodeGetInfoPtr(bookmarkNode);
            dtdURL = docTypeInfo->externalID.systemID;
            if (![[(NSURL *)dtdURL absoluteString] isEqualToString:@"http://www.mozilla.org/DTDs/ChimeraBookmarks.dtd"]) {
              NSLog(@"not a ChimeraBookmarks xml file. Bail");
              CFRelease(XMLFileTree);
              return NO;
            }
              break;
          case (kCFXMLNodeTypeElement):
            aBool = [aFolder readCaminoXML:subFileTree];
            CFRelease (XMLFileTree);
            return aBool;
            break;
          default:
            break;
        }
      }
    }
  }
  CFRelease(XMLFileTree);
  NSLog(@"run through the tree and didn't find anything interesting.  Bailed out");
  return NO;
}

-(BOOL)readPropertyListFile:(NSString *)pathToFile intoFolder:aFolder
{
  NSDictionary* dict = [NSDictionary dictionaryWithContentsOfFile:pathToFile];
  // see if it's safari
  if (![dict objectForKey:@"WebBookmarkType"])
    return [aFolder readNativeDictionary:dict];
  else
    return [aFolder readSafariDictionary:dict];
}

-(BOOL)readOperaFile:(NSString *)pathToFile intoFolder:aFolder
{
  // get file as NSString
  NSString* fileAsString = [self decodedTextFile:pathToFile];
  if (!fileAsString) {
    NSLog(@"couldn't read file. bailing out");
    return NO;
  }
  // Easily fooled check to see if it's an Opera Hotlist
  NSRange aRange;
  aRange = [fileAsString rangeOfString:@"Opera Hotlist" options:NSCaseInsensitiveSearch];
  if (aRange.location == NSNotFound) {
    NSLog(@"Bookmark file not recognized as Opera Hotlist.  Read fails.");
    return NO;
  }
  
  // Opera hotlists seem pretty easy to parse. Everything is on a line by itself.  
  // So we'll split the string up into a giant array by newlines, and march through the array.
  BookmarkFolder *currentArray = aFolder;
  BookmarkItem *currentItem = nil;
  
  NSArray *arrayOfFileLines = [fileAsString componentsSeparatedByString:@"\n"];
  NSEnumerator *enumerator = [arrayOfFileLines objectEnumerator];
  NSString *aLine =nil;
  
  while ((aLine = [enumerator nextObject])) {
    // See if we have a new folder.
    if ([aLine hasPrefix:@"#FOLDER"]) {
      currentItem = [currentArray addBookmarkFolder];
      currentArray = (BookmarkFolder *)currentItem;
    }
    // Maybe it's a new URL!
    else if ([aLine hasPrefix:@"#URL"]) {
      currentItem = [currentArray addBookmark];
    }
    // Perhaps a separator? This isn't how I'd spell it, but
    // then again, I'm not Norwagian, so what do I know.
    else if ([aLine hasPrefix:@"#SEPERATOR"]) {
      currentItem = [currentArray addBookmark];
      [(Bookmark *)currentItem setIsSeparator:TRUE];
      currentItem = nil;
    }
    // Or maybe this folder is being closed out.
    else if ([aLine hasPrefix:@"-"] && currentArray != aFolder) {
      currentArray = [currentArray parent];
      currentItem = nil;
    }
    // Well, if we don't have a prefix, we'll look something else
    else {
      // We have to check for Name and Short Name at the same time...
      aRange = [aLine rangeOfString:@"NAME="];
      if (NSNotFound != aRange.location) {
        NSRange sRange = [aLine rangeOfString:@"SHORT NAME="];
        if (NSNotFound != sRange.location) {
          [currentItem setKeyword:[aLine substringFromIndex:(sRange.location + sRange.length)]];
        }
        else {
          [currentItem setTitle:[aLine substringFromIndex:(aRange.location + aRange.length)]];
        }
      }
      // ... then URL ...
      aRange = [aLine rangeOfString:@"URL="];
      if (NSNotFound != aRange.location && [currentItem isKindOfClass:[Bookmark class]]) {
        [(Bookmark *)currentItem setUrl:[aLine substringFromIndex:(aRange.location + aRange.length)]];
      }
      // ... followed by Description
      aRange = [aLine rangeOfString:@"DESCRIPTION="];
      if (NSNotFound != aRange.location) {
        [currentItem setItemDescription:[aLine substringFromIndex:(aRange.location + aRange.length)]];
      }
    }
  }
  // That wasn't so bad
  return YES;
}

//
// Writing bookmark files
//

- (void) writeHTMLFile:(NSString *)pathToFile
{
  NSData *htmlData = [[[self rootBookmarks] writeHTML:0] dataUsingEncoding:NSUTF8StringEncoding];
  if (![htmlData writeToFile:[pathToFile stringByStandardizingPath] atomically:YES])
    NSLog(@"writeHTML: Failed to write file %@",pathToFile);
}

-(void) writeSafariFile:(NSString *)pathToFile
{
  NSDictionary* dict = [[self rootBookmarks] writeSafariDictionary];
  if (![dict writeToFile:[pathToFile stringByStandardizingPath] atomically:YES])
    NSLog(@"writeSafariFile: Failed to write file %@",pathToFile);
}

-(void)writePropertyListFile:(NSString *)pathToFile
{
  NSDictionary* dict = [[self rootBookmarks] writeNativeDictionary];
  if (![dict writeToFile:[pathToFile stringByStandardizingPath] atomically:YES])
    NSLog(@"writePropertyList: Failed to write file %@",pathToFile);
}

@end
