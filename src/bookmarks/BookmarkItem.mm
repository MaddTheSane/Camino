/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "NSString+Utils.h"

#import "BookmarkManager.h"
#import "BookmarkNotifications.h"
#import "BookmarkItem.h"

// Notifications
NSString* const kBookmarkItemChangedNotification = @"bookmark_changed";
NSString* const kBookmarkItemChangedFlagsKey = @"change_flags";

// Camino plist keys
NSString* const kBMTitleKey = @"Title";
NSString* const kBMChildrenKey = @"Children";
NSString* const kBMFolderDescKey = @"FolderDescription";
NSString* const kBMFolderTypeKey = @"FolderType";
NSString* const kBMFolderShortcutKey = @"FolderKeyword";
NSString* const kBMDescKey = @"Description";
NSString* const kBMStatusKey = @"Status";
NSString* const kBMURLKey = @"URL";
NSString* const kBMUUIDKey = @"UUID";
NSString* const kBMShortcutKey = @"Keyword";
NSString* const kBMLastVisitKey = @"LastVisitedDate";
NSString* const kBMVisitCountKey = @"VisitCount";
NSString* const kBMLinkedFaviconURLKey = @"LinkedFaviconURL";

@implementation BookmarkShortcutFormatter

- (NSString *)stringForObjectValue:(id)anObject
{
  return anObject;
}

- (BOOL)getObjectValue:(id *)anObject forString:(NSString *)string errorDescription:(NSString **)error
{
  *anObject = string;
  return YES;
}

- (BOOL)isPartialStringValid:(NSString *)partialString newEditingString:(NSString **)newString errorDescription:(NSString **)error
{
  if ([partialString rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet]].location != NSNotFound) {
    *newString = [partialString stringByRemovingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    return NO;
  }
  return YES;
}

@end

#pragma mark -

@implementation BookmarkItem

+ (BOOL)bookmarkChangedNotificationUserInfo:(NSDictionary*)inUserInfo containsFlags:(unsigned int)inFlags
{
  unsigned int changeFlags = kBookmarkItemEverythingChangedMask;  // assume everything changed
  NSNumber* noteChangeFlags = [inUserInfo objectForKey:kBookmarkItemChangedFlagsKey];
  if (noteChangeFlags)
    changeFlags = [noteChangeFlags unsignedIntValue];

  return ((changeFlags & inFlags) != 0);
}


//Initialization
- (id)init
{
  if ((self = [super init])) {
    mParent       = nil;
    mTitle        = [[NSString alloc] init]; //retain count +1
    mShortcut     = [mTitle retain]; //retain count +2
    mDescription  = [mTitle retain]; //retain count +3! and just 1 allocation.
    mUUID         = nil;
    mIcon         = nil;
  }
  return self;
}

- (id)copyWithZone:(NSZone *)zone
{
  //descend from NSObject - so don't call super
  id bmItemCopy = [[[self class] allocWithZone:zone] init];
  [bmItemCopy setTitle:[self title]];
  [bmItemCopy setItemDescription:[self itemDescription]];
  [bmItemCopy setShortcut:[self shortcut]];
  [bmItemCopy setParent:[self parent]];
  [bmItemCopy setIcon:[self icon]];
  // do NOT copy the UUID.  It wouldn't be "U" then, would it?
  return bmItemCopy;
}

- (void)dealloc
{
  [mTitle release];
  [mDescription release];
  [mShortcut release];
  [mIcon release];
  [mUUID release];

  [super dealloc];
}

// Basic properties
- (id)parent
{
  return mParent;
}

- (NSString *)title
{
  return mTitle;
}

- (NSString *)itemDescription
{
  return mDescription;
}

- (NSString *)shortcut
{
  return mShortcut;
}

// if we ask for a UUID, it means we need
// one.  So generate it if it doesn't exist.
- (NSString *)UUID
{
  if (!mUUID)
    mUUID = [[NSString stringWithUUID] retain];

  NSAssert([mUUID length] > 0, @"Empty UUID");
  return mUUID;
}

- (NSImage *)icon
{
  return mIcon;
}

- (BOOL)isChildOfItem:(BookmarkItem *)anItem
{
  if (![[self parent] isKindOfClass:[BookmarkItem class]])
    return NO;
  if ([self parent] == anItem)
    return YES;
  return [[self parent] isChildOfItem:anItem];
}

// overridden by Bookmark to return the right thing
// for separators.
- (BOOL)isSeparator
{
  return NO;
}

- (BOOL)hasAncestor:(BookmarkItem*)inItem
{
  if (inItem == self)
    return YES;

  id myParent = [self parent];
  if (myParent && [myParent isKindOfClass:[BookmarkItem class]])
    return [myParent hasAncestor:inItem];

  return NO;
}

- (void)setParent:(id)aParent
{
  mParent = aParent;  // no reference on the parent, so it better not disappear on us.
}

- (void)setTitle:(NSString *)aTitle
{
  if (!aTitle)
    return;

  if (![mTitle isEqualToString:aTitle]) {
    [aTitle retain];
    [mTitle release];
    mTitle = aTitle;
    [self itemUpdatedNote:kBookmarkItemTitleChangedMask];
  }
}

- (void)setItemDescription:(NSString *)aDescription
{
  if (!aDescription)
    return;

  if (![mDescription isEqualToString:aDescription]) {
    [aDescription retain];
    [mDescription release];
    mDescription = aDescription;
    [self itemUpdatedNote:kBookmarkItemDescriptionChangedMask];
  }
}

- (void)setShortcut:(NSString *)aShortcut
{
  if (!aShortcut)
    return;

  if (![mShortcut isEqualToString:aShortcut]) {
    [aShortcut retain];
    [mShortcut release];
    mShortcut = aShortcut;
    [self itemUpdatedNote:kBookmarkItemShortcutChangedMask];
  }
}

- (void)setIcon:(NSImage *)aIcon
{
  if (!aIcon)
    return;   // XXX should be allowed to just remove the icon

  [aIcon retain];
  [mIcon release];
  mIcon = aIcon;

  [self itemUpdatedNote:kBookmarkItemIconChangedMask];
}

- (void)setUUID:(NSString*)aUUID
{
  // ignore nil or empty strings
  if (!aUUID || [aUUID length] == 0)
    return;

  [aUUID retain];
  [mUUID release];
  mUUID = aUUID;
}

- (BOOL)matchesString:(NSString*)searchString inFieldWithTag:(int)tag
{
  switch (tag) {
    case eBookmarksSearchFieldAll:
      return (([[self title]           rangeOfString:searchString options:NSCaseInsensitiveSearch].location != NSNotFound) ||
              ([[self shortcut]        rangeOfString:searchString options:NSCaseInsensitiveSearch].location != NSNotFound) ||
              ([[self itemDescription] rangeOfString:searchString options:NSCaseInsensitiveSearch].location != NSNotFound));

    case eBookmarksSearchFieldTitle:
      return ([[self title]            rangeOfString:searchString options:NSCaseInsensitiveSearch].location != NSNotFound);

    // case eBookmarksSearchFieldURL: // Bookmark subclass has to check this
    case eBookmarksSearchFieldShortcut:
      return ([[self shortcut]         rangeOfString:searchString options:NSCaseInsensitiveSearch].location != NSNotFound);

    case eBookmarksSearchFieldDescription:
      return ([[self itemDescription]  rangeOfString:searchString options:NSCaseInsensitiveSearch].location != NSNotFound);
  }

  return NO;
}

// Helps prevent spamming from itemUpdatedNote:
// calling with YES will prevent itemUpdatedNote from doing anything
// and calling with NO will restore itemUpdatedNote and then call it.
- (void)setAccumulateUpdateNotifications:(BOOL)accumulateUpdates
{
  if (accumulateUpdates) {
    mPendingChangeFlags |= kBookmarkItemAccumulateChangesMask;
  }
  else {
    mPendingChangeFlags &= ~kBookmarkItemAccumulateChangesMask;
    [self itemUpdatedNote:mPendingChangeFlags];   //fire an update to cover the updates that weren't sent
  }
}

- (void)itemUpdatedNote:(unsigned int)inChangeMask
{
  // If the bookmark hasn't been inserted into the tree yet then it doesn't
  // matter if it changed, so don't bother sending the notification. Because
  // we can't tell if it's the root of the bookmark tree (which always has a
  // nil parent) we always have to let kBookmarkItemChildrenChangedMask
  // notfications through.
  if (![self parent] && !(inChangeMask & kBookmarkItemChildrenChangedMask))
    return;

  if ([[BookmarkManager sharedBookmarkManager] areChangeNotificationsSuppressed])
    return;   // don't even accumulate the flags. caller is expected to update stuff manually

  // don't let 'em change the pending flag
  mPendingChangeFlags |= (inChangeMask & kBookmarkItemEverythingChangedMask);

  // if we're just accumulating, return
  if (mPendingChangeFlags & kBookmarkItemAccumulateChangesMask)
    return;

  NSDictionary* flagsInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedInt:mPendingChangeFlags]
                                                        forKey:kBookmarkItemChangedFlagsKey];
  NSNotification* note = [NSNotification notificationWithName:kBookmarkItemChangedNotification
                                                       object:self
                                                     userInfo:flagsInfo];
  [[NSNotificationCenter defaultCenter] postNotification:note];
  mPendingChangeFlags = 0;
}

// stub functions to avoid warning

- (void)refreshIcon
{
}

#pragma mark -

// Writing to disk - all just stubs.

- (void)writeBookmarksMetadataToPath:(NSString*)inPath
{
  // do nothing, subclasses must override
}

- (void)removeBookmarksMetadataFromPath:(NSString*)inPath
{
  // do nothing, subclasses must override
}

- (NSDictionary *)writeNativeDictionary
{
  return [NSDictionary dictionary];
}

- (id)savedTitle
{
  return mTitle ? mTitle : @"";
}

#pragma mark -

// sorting

- (NSComparisonResult)compareURL:(BookmarkItem *)aItem sortDescending:(NSNumber*)inDescending
{
  return NSOrderedSame;
}

- (NSComparisonResult)compareTitle:(BookmarkItem *)aItem sortDescending:(NSNumber*)inDescending
{
  NSComparisonResult result = [[self title] compare:[aItem title] options:NSCaseInsensitiveSearch];
  return [inDescending boolValue] ? (NSComparisonResult)(-1 * (int)result) : result;
}

- (NSComparisonResult)compareShortcut:(BookmarkItem *)aItem sortDescending:(NSNumber*)inDescending
{
  NSComparisonResult result = [[self shortcut] compare:[aItem shortcut] options:NSCaseInsensitiveSearch];
  return [inDescending boolValue] ? (NSComparisonResult)(-1 * (int)result) : result;
}

- (NSComparisonResult)compareDescription:(BookmarkItem *)aItem sortDescending:(NSNumber*)inDescending
{
  NSComparisonResult result = [[self itemDescription] compare:[aItem itemDescription] options:NSCaseInsensitiveSearch];
  return [inDescending boolValue] ? (NSComparisonResult)(-1 * (int)result) : result;
}

- (NSComparisonResult)compareType:(BookmarkItem *)aItem sortDescending:(NSNumber*)inDescending
{
  return NSOrderedSame;
}

- (NSComparisonResult)compareVisitCount:(BookmarkItem *)aItem sortDescending:(NSNumber*)inDescending
{
  return NSOrderedSame;
}

- (NSComparisonResult)compareLastVisitDate:(BookmarkItem *)aItem sortDescending:(NSNumber*)inDescending
{
  return NSOrderedSame;
}

@end


