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

#import "BookmarkItem.h"

// Notifications
NSString* const BookmarkItemChangedNotification = @"bi_cg";
NSString* const BookmarkIconChangedNotification = @"bicon_cg";

// all our saving/loading keys
// Safari & Camino plist keys
NSString* const BMTitleKey = @"Title";
NSString* const BMChildrenKey = @"Children";

// Camino plist keys
NSString* const BMFolderDescKey = @"FolderDescription";
NSString* const BMFolderTypeKey = @"FolderType";
NSString* const BMFolderKeywordKey = @"FolderKeyword";
NSString* const BMDescKey = @"Description";
NSString* const BMStatusKey = @"Status";
NSString* const BMURLKey = @"URL";
NSString* const BMKeywordKey = @"Keyword";
NSString* const BMLastVisitKey = @"LastVisitedDate";
NSString* const BMNumberVisitsKey = @"VisitCount";

// safari keys
NSString* const SafariTypeKey = @"WebBookmarkType";
NSString* const SafariLeaf = @"WebBookmarkTypeLeaf";
NSString* const SafariList = @"WebBookmarkTypeList";
NSString* const SafariAutoTab = @"WebBookmarkAutoTab";
NSString* const SafariUUIDKey = @"WebBookmarkUUID";
NSString* const SafariURIDictKey = @"URIDictionary";
NSString* const SafariBookmarkTitleKey = @"title";
NSString* const SafariURLStringKey = @"URLString";

// camino XML keys
NSString* const CaminoNameKey = @"name";
NSString* const CaminoDescKey = @"description";
NSString* const CaminoTypeKey = @"type";
NSString* const CaminoKeywordKey = @"id";
NSString* const CaminoURLKey = @"href";
NSString* const CaminoToolbarKey = @"toolbar";
NSString* const CaminoDockMenuKey = @"dockmenu";
NSString* const CaminoGroupKey = @"group";
NSString* const CaminoBookmarkKey = @"bookmark";
NSString* const CaminoFolderKey = @"folder";
NSString* const CaminoTrueKey = @"true";


@implementation BookmarkItem

static BOOL gSuppressAllUpdates = NO;

//Initialization
-(id) init
{
  if ((self = [super init]))
  {
    mParent = NULL;
    mTitle = [[NSString alloc] init]; //retain count +1
    mKeyword = [mTitle retain]; //retain count +2
    mDescription = [mTitle retain]; //retain count +3! and just 1 allocation.
    mUUID = nil;
    // if we set the icon here, we will get a memory leak.  so don't.
    // subclass will provide icon.
    mIcon = NULL;
    mAccumulateItemChangeUpdates = NO;
  }
  return self;
}
 
-(id) copyWithZone:(NSZone *)zone
{
  //descend from NSObject - so don't call super
  id doppleganger = [[[self class] allocWithZone:zone] init];
  [doppleganger setTitle:[self title]];
  [doppleganger setDescription:[self description]];
  [doppleganger setKeyword:[self keyword]];
  [doppleganger setParent:[self parent]];
  [doppleganger setIcon:[self icon]];
  // do NOT copy the UUID.  It wouldn't be "U" then, would it?
  return doppleganger;
}

-(void)dealloc
{
  [mTitle release];
  [mDescription release];
  [mKeyword release];
  [mIcon release];
  [mUUID release];
  [super dealloc];
}


// Basic properties
-(id) parent
{
  return mParent;
}

-(NSString *) title
{
  return mTitle;
}

-(NSString *) description
{
  return mDescription;
}

-(NSString *) keyword
{
  return mKeyword;
}

// if we ask for a UUID, it means we need
// one.  So generate it if it doesn't exist. 
-(NSString *) UUID
{
  if (!mUUID) {
    CFUUIDRef aUUID = CFUUIDCreate(kCFAllocatorDefault);
    if (aUUID) {
      mUUID =(NSString *)CFUUIDCreateString(kCFAllocatorDefault, aUUID);
      CFRelease (aUUID);
    }
  }
  return mUUID;
}

-(NSImage *)icon
{
  return mIcon;
}

-(BOOL) isChildOfItem:(BookmarkItem *)anItem
{
  if (![[self parent] isKindOfClass:[BookmarkItem class]])
    return NO;
  if ([self parent] == anItem)
    return YES;
  return [[self parent] isChildOfItem:anItem];
}

-(void) setParent:(id) aParent
{
  mParent = aParent;	// no reference on the parent, so it better not disappear on us.
}

-(void) setTitle:(NSString *)aTitle
{
  if (!aTitle)
    return;
  [aTitle retain];
  [mTitle release];
  mTitle = aTitle;
  [self itemUpdatedNote];
}

-(void) setDescription:(NSString *)aDescription
{
  if (!aDescription)
    return;
  [aDescription retain];
  [mDescription release];
  mDescription = aDescription;
}

- (void) setKeyword:(NSString *)aKeyword
{
  if (!aKeyword)
    return;
  [aKeyword retain];
  [mKeyword release];
  mKeyword = aKeyword;
}

-(void) setUUID:(NSString *)aUUID
{
  [aUUID retain];
  [mUUID release];
  mUUID = aUUID;
}

-(void) setIcon:(NSImage *)aIcon
{
  if (!aIcon)
    return;
  [aIcon retain];
  [mIcon release];
  mIcon = aIcon;
  
  if (![BookmarkItem allowNotifications]) return;
  NSNotification *note = [NSNotification notificationWithName:BookmarkIconChangedNotification
                                                       object:self userInfo:nil];
  [[NSNotificationCenter defaultCenter] postNotification:note];
}

-(BOOL)matchesString:(NSString*)searchString inFieldWithTag:(int)tag
{
  switch (tag)
  {
    case eBookmarksSearchFieldAll:
      return (([[self title]        rangeOfString:searchString options:NSCaseInsensitiveSearch].location != NSNotFound) ||
              ([[self keyword]      rangeOfString:searchString options:NSCaseInsensitiveSearch].location != NSNotFound) ||
              ([[self description]  rangeOfString:searchString options:NSCaseInsensitiveSearch].location != NSNotFound));
    
    case eBookmarksSearchFieldTitle:
      return ([[self title]        rangeOfString:searchString options:NSCaseInsensitiveSearch].location != NSNotFound);
    
    // case eBookmarksSearchFieldURL: // Bookmark subclass has to check this
    case eBookmarksSearchFieldKeyword:
      return ([[self keyword]      rangeOfString:searchString options:NSCaseInsensitiveSearch].location != NSNotFound);

    case eBookmarksSearchFieldDescription:
      return ([[self description]  rangeOfString:searchString options:NSCaseInsensitiveSearch].location != NSNotFound);
  }

  return NO;
}


// Prevents all NSNotification posting from any BookmarkItem.
// Useful for suppressing all the pointless notifications during load.
+(void) setSuppressAllUpdateNotifications:(BOOL)suppressUpdates
{
  gSuppressAllUpdates = suppressUpdates;
}

+(BOOL) allowNotifications
{
  return !gSuppressAllUpdates;
}

// Helps prevent spamming from itemUpdatedNote:
// calling with YES will prevent itemUpdatedNote from doing anything
// and calling with NO will restore itemUpdatedNote and then call it.
-(void) setAccumulateUpdateNotifications:(BOOL)accumulateUpdates
{
  mAccumulateItemChangeUpdates = accumulateUpdates;
  if (!mAccumulateItemChangeUpdates)
    [self itemUpdatedNote];   //fire an update to cover the updates that weren't sent
}

-(void) itemUpdatedNote
{
  if (gSuppressAllUpdates || mAccumulateItemChangeUpdates) return;
  
  NSNotification *note = [NSNotification notificationWithName:BookmarkItemChangedNotification object:self userInfo:nil];
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc postNotification:note];
}

// stub functions to avoid warning

-(void) refreshIcon
{
}

//Reading/writing to & from disk - all just stubs.

-(BOOL) readNativeDictionary:(NSDictionary *)aDict
{
  return NO;
}

-(BOOL) readSafariDictionary:(NSDictionary *)aDict
{
  return NO;
}

-(BOOL) readCaminoXML:(CFXMLTreeRef)aTreeRef
{
  return NO;
}

-(NSDictionary *)writeNativeDictionary
{
  return [NSDictionary dictionary];
}

-(NSDictionary *)writeSafariDictionary
{
  return [NSDictionary dictionary];
}

-(NSString *)writeHTML:(unsigned)aPad
{
  return [NSString string];
}


@end



