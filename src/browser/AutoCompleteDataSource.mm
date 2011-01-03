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
 *   David Hyatt <hyatt@mozilla.org> (Original Author)
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

#import "NSString+Gecko.h"
#import "NSString+Utils.h"

#import <AppKit/AppKit.h>
#import "AutoCompleteDataSource.h"
#import "AutoCompleteTextField.h"
#import "AutoCompleteResult.h"
#import "Trie.h"
#import "CHBrowserService.h"
#import "SiteIconProvider.h"

#import "Bookmark.h"
#import "BookmarkFolder.h"
#import "BookmarkManager.h"

#import "HistoryItem.h"
#import "HistoryDataSource.h"

static const unsigned int kMaxResultsPerHeading = 5;
static const unsigned int kMaxTrieDepth = 5;

// Amount of time to pause between chunks when building the trie.
static const NSTimeInterval kProcessNextChunkDelay = 0.1;

// Internal change queueing constants.
static NSString *const kSourceItemChangedItemKey = @"SourceItemChangedItem";
static NSString *const kSourceItemChangeTypeKey = @"SourceItemChangeTypeKey";
enum SourceChangeType {
  kSourceItemAdded,
  kSourceItemRemoved,
  kSourceItemChanged
};

// Helper class to process changes to a trie asynchronously. All notifications
// of data source (i.e., history and bookmarks) changes should pass through this
// helper so that notification delivery isn't slow, and batch changes don't
// cause long hangs.
@interface AsynchronousTrieUpdater : NSObject
{
  NSMutableArray* mChangeQueue;       // owned
  Trie*           mTrie;              // weak
  BOOL            mProcessingPaused;
}

// Initializes a new updater for the given trie. The trie is not retained, so
// the caller is responsible for ensuring that it outlives this object.
- (id)initWithTrie:(Trie*)trie;

// Queues the given change for asyncronous processing. Changes are guaranteed
// to be processed in FIFO order.
- (void)queueChange:(NSDictionary*)change;

// Pauses or unpauses processing. While paused, the updater will accumulate
// changes, but not process them.
- (void)setProcessingPaused:(BOOL)paused;

@end

@interface AsynchronousTrieUpdater (Private)

// Processes the next chunk of queued changes.
- (void)processNextChangeChunk;

// Updates the trie based on the given change info.
- (void)updateTrieWithChange:(NSDictionary *)changeInfo;

@end


@implementation AsynchronousTrieUpdater

- (id)initWithTrie:(Trie*)trie
{
  if ((self = [super init])) {
    mTrie = trie;
    mChangeQueue = [[NSMutableArray alloc] init];
  }
  return self;
}

- (void)dealloc
{
  [NSObject cancelPreviousPerformRequestsWithTarget:self];
  [mChangeQueue release];
  [super dealloc];
}

- (void)queueChange:(NSDictionary*)change
{
  if (!mProcessingPaused && [mChangeQueue count] == 0) {
    [self performSelector:@selector(processNextChangeChunk)
               withObject:nil
               afterDelay:kProcessNextChunkDelay];
  }
  [mChangeQueue addObject:change];
}

- (void)setProcessingPaused:(BOOL)paused
{
  if (!paused && mProcessingPaused && [mChangeQueue count] > 0) {
    [self performSelector:@selector(processNextChangeChunk)
               withObject:nil
               afterDelay:kProcessNextChunkDelay];
  }
  mProcessingPaused = paused;
}

- (void)processNextChangeChunk
{
  if ([mChangeQueue count] == 0)
    return;

  NSDate *startTime = [NSDate date];
  NSAutoreleasePool *localPool = [[NSAutoreleasePool alloc] init];
  unsigned int processedCount = 0;
  while (processedCount < [mChangeQueue count]) {
    [self updateTrieWithChange:[mChangeQueue objectAtIndex:processedCount]];
    if (++processedCount % 10 == 0) {
      // Aim for ~50% CPU usage.
      NSTimeInterval elapsedTime = [[NSDate date] timeIntervalSinceDate:startTime];
      if (elapsedTime > kProcessNextChunkDelay)
        break;

      [localPool drain];
      localPool = [[NSAutoreleasePool alloc] init];
    }
  }
  [localPool drain];

  [mChangeQueue removeObjectsInRange:NSMakeRange(0, processedCount)];
  if ([mChangeQueue count] > 0) {
    [self performSelector:@selector(processNextChangeChunk)
               withObject:nil
               afterDelay:kProcessNextChunkDelay];
  }
}

- (void)updateTrieWithChange:(NSDictionary *)changeInfo
{
  SourceChangeType changeType = (SourceChangeType)[[changeInfo
      objectForKey:kSourceItemChangeTypeKey] intValue];
  id item = [changeInfo objectForKey:kSourceItemChangedItemKey];
  switch (changeType) {
    case kSourceItemAdded:
      [mTrie addItem:item];
      break;
    case kSourceItemRemoved:
      [mTrie removeItem:item];
      break;
    case kSourceItemChanged:
      // TODO: Add finer grained modification information, and optimize the
      // update (so that just changing a visit count/date won't require
      // re-processing all the search terms).
      [mTrie removeItem:item];
      [mTrie addItem:item];
      break;
    default:
      break;
  }
}

@end

#pragma mark -

@interface AutoCompleteDataSource (Private)
// Clears any internal state from a previous search.
- (void)resetSearch;

// Starts the process of asynchronously building a trie of history data.
- (void)startBuildingHistoryTrie;

// Processes the next chunk of initial history data into the trie.
- (void)processNextHistoryChunk;

// Called when the initial history data has all been processed into the trie.
- (void)doneBuildingHistoryTrie;

// Starts the process of asynchronously building a trie of bookmark data.
- (void)startBuildingBookmarkTrie;

// Processes the next chunk of initial bookmark data into the trie.
- (void)processNextBookmarkChunk;

// Called when the initial history data has all been processed into the trie.
- (void)doneBuildingBookmarkTrie;

// Helper method for asyncronous loading; inserts a chunk of |items| into
// |trie|, removing them from |items|.
- (void)processNextChunkOfItems:(NSMutableArray *)items intoTrie:(Trie *)trie;

// Creates and returns an AutoCompleteResult object for the given item.
// The AutoCompleteResult class is used by the AutoCompleteCell to store
// all of the data relevant to drawing a cell.
- (AutoCompleteResult *)autoCompleteResultForItem:(id)item;

// Adds headers to results arrays and consolidates into mResults array,
// then calls searchResultsAvailable on the delegate.
- (void)reportResults;

// Adds the header to the specified results array.
- (void)addHeader:(NSString *)header toResults:(NSMutableArray *)results;

// Called whenever history changes.
- (void)historyChanged:(NSNotification *)notification;

// Called if the history backend is completely rebuilt.
- (void)historyRebuilt:(NSNotification *)notification;

// Called whenever a bookmark changes.
- (void)bookmarkChanged:(NSNotification *)notification;

// Called whenever bookmark are created or deleted.
- (void)bookmarksAddedOrRemoved:(NSNotification *)notification;

// Helper for bookmark notification handling; queues a change for every bookmark
// under the given root.
- (void)queueBookmarkChangesOfType:(SourceChangeType)type
                            atRoot:(BookmarkItem *)root;

// Generates the trie keywords for the given URL.
- (NSArray *)keyArrayForURL:(NSString *)url;

// Returns a URL string with the scheme (and '://' or ':') replaced with a
// unicode character placeholder. See keyArrayForURL for full details.
// Returns nil if the URL has no scheme (or, if restrictScheme is true, if
// it doesn't have a scheme that has been seen before).
- (NSString *)urlStringWithSchemePlaceholder:(NSString *)url
                    restrictedToKnownSchemes:(BOOL)restrictScheme;

// Returns the unicode placeholder for the given scheme.
// If scheme doesn't have a placeholder assigned yet, one will be created if
// |create| is true, or the method will return nil if not.
- (NSString *)unicodeCharacterForScheme:(NSString*)scheme
                      createIfNecessary:(BOOL)create;

@end

@implementation AutoCompleteDataSource

+ (AutoCompleteDataSource *)sharedDataSource
{
  static AutoCompleteDataSource *sharedDataSource = nil;
  if (sharedDataSource == nil) {
    sharedDataSource = [[self alloc] init];
  }
  return sharedDataSource;
}

-(id)init
{
  if ((self = [super init])) {
    mBookmarkResults = [[NSMutableArray alloc] init];
    mHistoryResults = [[NSMutableArray alloc] init];
    mResults = [[NSMutableArray alloc] init];
    mGenericSiteIcon = [[NSImage imageNamed:@"globe_ico"] retain];
    mGenericFileIcon = [[NSImage imageNamed:@"smallDocument"] retain];
    mSchemeToPlaceholderMap = [[NSMutableDictionary alloc] init];

    NSSortDescriptor *bookmarkSortOrder =
        [[[NSSortDescriptor alloc] initWithKey:@"numberOfVisits"
                                     ascending:NO] autorelease];
    mBookmarkTrie = [[Trie alloc] initWithKeywordDelegate:self
                                                sortOrder:bookmarkSortOrder
                                                 maxDepth:kMaxTrieDepth];

    NSSortDescriptor *historySortOrder =
        [[[NSSortDescriptor alloc] initWithKey:@"visitCount"
                                     ascending:NO] autorelease];
    mHistoryTrie = [[Trie alloc] initWithKeywordDelegate:self
                                               sortOrder:historySortOrder
                                                maxDepth:kMaxTrieDepth];

    NSNotificationCenter *notificationCenter =
        [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self
                           selector:@selector(historyChanged:)
                               name:kNotificationNameHistoryDataSourceItemChanged
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(historyRebuilt:)
                               name:kNotificationNameHistoryDataSourceRebuilt
                             object:nil];

    // Start the process of building the tries. To prevent resource contention,
    // only the bookmark trie is started here, and once that's complete it will
    // kick off the history loading.
    [self startBuildingBookmarkTrie];
  }
  return self;
}

-(void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [NSObject cancelPreviousPerformRequestsWithTarget:self];

  [mBookmarkTrieUpdater release];
  [mHistoryTrieUpdater release];
  [mBookmarkTrie release];
  [mHistoryTrie release];

  [mBookmarkResults release];
  [mHistoryResults release];
  [mResults release];
  [mHistoryItemsToLoad release];
  [mBookmarksToLoad release];
  [mGenericSiteIcon release];
  [mGenericFileIcon release];
  [mSchemeToPlaceholderMap release];
  [super dealloc];
}

#pragma mark -

- (void)historyLoadingComplete
{
  [self startBuildingHistoryTrie];
}

- (void)startBuildingHistoryTrie
{
  mHistoryItemsToLoad = [[NSMutableArray arrayWithArray:
      [[HistoryDataSource sharedHistoryDataSource] historyItems]] retain];
  [self performSelector:@selector(processNextHistoryChunk)
             withObject:nil
             afterDelay:kProcessNextChunkDelay];

  // Start paying attention to changes, but hold off on processing them until
  // the initial load is complete to preserve order.
  mHistoryTrieUpdater =
      [[AsynchronousTrieUpdater alloc] initWithTrie:mHistoryTrie];
  [mHistoryTrieUpdater setProcessingPaused:YES];
}

- (void)processNextHistoryChunk
{
  [self processNextChunkOfItems:mHistoryItemsToLoad intoTrie:mHistoryTrie];

  if ([mHistoryItemsToLoad count] == 0) {
    [self doneBuildingHistoryTrie];
  }
  else {
    [self performSelector:@selector(processNextHistoryChunk)
               withObject:nil
               afterDelay:kProcessNextChunkDelay];
  }
}

- (void)doneBuildingHistoryTrie
{
  [mHistoryItemsToLoad release];
  mHistoryItemsToLoad = nil;
  // Start processing queued notifications now that the initial load is done.
  [mHistoryTrieUpdater setProcessingPaused:NO];
}

- (void)historyChanged:(NSNotification *)notification
{
  if (!mHistoryTrieUpdater)
    return;

  NSDictionary *notificationInfo = [notification userInfo];
  HistoryChangeType historyChangeType = (HistoryChangeType)[[notificationInfo
      objectForKey:kNotificationHistoryDataSourceChangedUserInfoChangeType] intValue];
  int internalChangeType;
  switch (historyChangeType) {
    case kHistoryChangeItemAdded:
      internalChangeType = kSourceItemAdded;
      break;
    case kHistoryChangeItemRemoved:
      internalChangeType = kSourceItemRemoved;
      break;
    case kHistoryChangeItemModified:
      internalChangeType = kSourceItemChanged;
      break;
    default:
      return;
  }

  NSDictionary *changeInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                            [notification object], kSourceItemChangedItemKey,
      [NSNumber numberWithInt:internalChangeType], kSourceItemChangeTypeKey,
                                                   nil];

  [mHistoryTrieUpdater queueChange:changeInfo];
}

- (void)historyRebuilt:(NSNotification *)notification
{
  [mHistoryTrieUpdater release];
  mHistoryTrieUpdater = nil;
  [mHistoryItemsToLoad release];
  mHistoryItemsToLoad = nil;
  [mHistoryTrie removeAllItems];

  [self startBuildingHistoryTrie];
}

#pragma mark -

- (void)startBuildingBookmarkTrie
{
  BookmarkFolder *bookmarkRoot =
      [[BookmarkManager sharedBookmarkManager] bookmarkRoot];
  NSArray *allBookmarks = [bookmarkRoot allChildBookmarks];

  mBookmarksToLoad =
      [[NSMutableArray alloc] initWithCapacity:[allBookmarks count]];
  NSEnumerator *bookmarkEnumerator = [allBookmarks objectEnumerator];
  Bookmark *bookmark;
  while ((bookmark = [bookmarkEnumerator nextObject])) {
    // Skip search bookmarklets and separators.
    if (![bookmark isSeparator] &&
        [[bookmark url] rangeOfString:@"%s"].location == NSNotFound)
    {
      [mBookmarksToLoad addObject:bookmark];
    }
  }
  [self performSelector:@selector(processNextBookmarkChunk)
             withObject:nil
             afterDelay:kProcessNextChunkDelay];

  // Start listening for changes, but hold off on processing them until the
  // initial load is complete to preserve order.
  mBookmarkTrieUpdater =
      [[AsynchronousTrieUpdater alloc] initWithTrie:mBookmarkTrie];
  [mBookmarkTrieUpdater setProcessingPaused:YES];
  NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
  [notificationCenter addObserver:self
                         selector:@selector(bookmarkChanged:)
                             name:BookmarkItemChangedNotification
                           object:nil];
  [notificationCenter addObserver:self
                         selector:@selector(bookmarksAddedOrRemoved:)
                             name:BookmarkItemsAddedNotification
                           object:nil];
  [notificationCenter addObserver:self
                         selector:@selector(bookmarksAddedOrRemoved:)
                             name:BookmarkItemsRemovedNotification
                           object:nil];
}

- (void)processNextBookmarkChunk
{
  [self processNextChunkOfItems:mBookmarksToLoad intoTrie:mBookmarkTrie];

  if ([mBookmarksToLoad count] == 0) {
    [self doneBuildingBookmarkTrie];
  }
  else {
    [self performSelector:@selector(processNextBookmarkChunk)
               withObject:nil
               afterDelay:kProcessNextChunkDelay];
  }
}

- (void)doneBuildingBookmarkTrie
{
  [mBookmarksToLoad release];
  mBookmarksToLoad = nil;
  // Start processing queued notifications now that the initial load is done.
  [mBookmarkTrieUpdater setProcessingPaused:NO];

  // Now that bookmarks are done, start on history.
  HistoryDataSource *historyDataSource =
      [HistoryDataSource sharedHistoryDataSource];
  if ([historyDataSource isLoaded])
    [self startBuildingHistoryTrie];
  else
    [historyDataSource loadAsynchronouslyWithListener:self];
}

- (void)bookmarkChanged:(NSNotification *)notification
{
  NSDictionary *notificationInfo = [notification userInfo];
  unsigned int changeFlags =
      [[notificationInfo objectForKey:BookmarkItemChangedFlagsKey] unsignedIntValue];
  unsigned int interestingFlagsMask = kBookmarkItemTitleChangedMask |
                                      kBookmarkItemShortcutChangedMask |
                                      kBookmarkItemURLChangedMask |
                                      kBookmarkItemNumVisitsChangedMask;
  if (![[notification object] isKindOfClass:[Bookmark class]] ||
      [[notification object] isSeparator] ||
      !(changeFlags & interestingFlagsMask))
  {
    return;
  }
  NSDictionary *changeInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                            [notification object], kSourceItemChangedItemKey,
      [NSNumber numberWithInt:kSourceItemChanged], kSourceItemChangeTypeKey,
                                                   nil];
  [mBookmarkTrieUpdater queueChange:changeInfo];
}

- (void)bookmarksAddedOrRemoved:(NSNotification *)notification
{
  SourceChangeType changeType =
      [[notification name] isEqualToString:BookmarkItemsAddedNotification] ?
      kSourceItemAdded : kSourceItemRemoved;
  NSEnumerator *bookmarkEnumerator = [[notification object] objectEnumerator];
  BookmarkItem *bookmarkItem;
  while ((bookmarkItem = [bookmarkEnumerator nextObject])) {
    [self queueBookmarkChangesOfType:changeType atRoot:bookmarkItem];
  }
}
- (void)queueBookmarkChangesOfType:(SourceChangeType)type
                            atRoot:(BookmarkItem *)root
{
  if ([root isKindOfClass:[BookmarkFolder class]]) {
    NSEnumerator *bookmarkEnumerator =
        [[(BookmarkFolder*)root allChildBookmarks] objectEnumerator];
    BookmarkItem *bookmarkItem;
    while ((bookmarkItem = [bookmarkEnumerator nextObject])) {
      [self queueBookmarkChangesOfType:type atRoot:bookmarkItem];
    }
  }
  else if (![root isSeparator]) {
    NSDictionary *changeInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                 root, kSourceItemChangedItemKey,
        [NSNumber numberWithInt:type], kSourceItemChangeTypeKey,
                                       nil];
    [mBookmarkTrieUpdater queueChange:changeInfo];
  }
}

#pragma mark -

- (void)processNextChunkOfItems:(NSMutableArray *)items intoTrie:(Trie *)trie
{
  NSDate *startTime = [NSDate date];
  NSAutoreleasePool *localPool = [[NSAutoreleasePool alloc] init];
  unsigned int processedCount = 0;
  while (processedCount < [items count]) {
    [trie addItem:[items objectAtIndex:processedCount]];
    if (++processedCount % 10 == 0) {
      // Aim for ~50% CPU usage.
      NSTimeInterval elapsedTime = [[NSDate date] timeIntervalSinceDate:startTime];
      if (elapsedTime > kProcessNextChunkDelay)
        break;

      [localPool drain];
      localPool = [[NSAutoreleasePool alloc] init];
    }
  }
  [localPool drain];

  [items removeObjectsInRange:NSMakeRange(0, processedCount)];
}

- (NSArray *)keywordsForObject:(id)object
{
  NSMutableArray *keys = [NSMutableArray array];
  [keys addObjectsFromArray:[[[object valueForKey:@"title"] lowercaseString] componentsSeparatedByString:@" "]];
  [keys addObjectsFromArray:[self keyArrayForURL:[object valueForKey:@"url"]]];
  if ([object isKindOfClass:[Bookmark class]] && [[object shortcut] length])
    [keys addObject:[object shortcut]];
  return keys;
}

- (NSArray *)keyArrayForURL:(NSString *)url
{
  NSString *lowercaseURL = [url lowercaseString];
  NSMutableArray *urls = [NSMutableArray array];

  // First, convert the url's scheme, if it has one, to a placeholder unicode
  // character. This has essentially the same effect as creating a forest of
  // scheme-specific tries (at the cost of one character of depth in the trie),
  // without all the update and query complexity of actually using a forest.
  // This is done because just inserting the raw URL would
  // a) pollute the search results (e.g., the results for 'h' would be much
  //    noisier than for most letters), and
  // b) make all queries starting with a scheme linear, since the whole depth
  //    of the trie would be used up on the scheme.
  // If there's no scheme (including if NSURL doesn't consider the URL valid)
  // insert the whole string).
  NSString *urlWithSchemePlaceholder =
      [self urlStringWithSchemePlaceholder:lowercaseURL
                  restrictedToKnownSchemes:NO];
  if (urlWithSchemePlaceholder)
    [urls addObject:urlWithSchemePlaceholder];
  else
    [urls addObject:lowercaseURL];

  NSString *host = [[NSURL URLWithString:lowercaseURL] host];
  if (host) {
    // If a host is found, we iterate through each domain fragment and add a
    // copy of the URL beginning with that fragment to the array. This allows
    // matches to any fragment of the domain. The top level domain should be
    // ignored since we don't want to match to it. However, currently
    // we just ignore the final part of the URL after the last dot, so we'll
    // over-match for two-part TLDs such as co.uk.
    NSString *restOfURL = [lowercaseURL substringFromIndex:NSMaxRange([lowercaseURL rangeOfString:host])];
    NSRange nextDot;
    while ((nextDot = [host rangeOfString:@"."]).location != NSNotFound) {
      [urls addObject:[host stringByAppendingString:restOfURL]];
      host = [host substringFromIndex:NSMaxRange(nextDot)];
    }
  }
  return urls;
}

- (NSString *)urlStringWithSchemePlaceholder:(NSString *)url
                    restrictedToKnownSchemes:(BOOL)restrictScheme;
{
  NSURL *nsURL = [NSURL URLWithString:url];
  NSString *scheme = [nsURL scheme];
  if (!scheme)
    return nil;
  NSMutableString *schemelessURL = [url mutableCopy];
  [schemelessURL deleteCharactersInRange:NSMakeRange(0, [scheme length])];
  if ([schemelessURL hasPrefix:@"://"])
    [schemelessURL deleteCharactersInRange:NSMakeRange(0, 3)];
  else if ([schemelessURL hasPrefix:@":"])
    [schemelessURL deleteCharactersInRange:NSMakeRange(0, 1)];
  else
    return nil;

  NSString *placeholder = [self unicodeCharacterForScheme:scheme
                                        createIfNecessary:(!restrictScheme)];
  if (!placeholder)
    return nil;

  return [placeholder stringByAppendingString:schemelessURL];
}

- (NSString *)unicodeCharacterForScheme:(NSString*)scheme
                      createIfNecessary:(BOOL)create
{
  NSString *placeholder = [mSchemeToPlaceholderMap objectForKey:scheme];
  if (!placeholder && create) {
    // Each new scheme encountered is given the next available character from
    // the first Unicode Private Use Area.
    placeholder = [NSString stringWithFormat:@"%C",
                      0xE000 + [mSchemeToPlaceholderMap count]];
    [mSchemeToPlaceholderMap setObject:placeholder forKey:scheme];
  }
  return placeholder;
}

#pragma mark -

- (void)resetSearch
{
  [mBookmarkResults removeAllObjects];
  [mHistoryResults removeAllObjects];
}

- (void)performSearchWithString:(NSString *)searchString delegate:(id)delegate
{
  [self resetSearch];
  mDelegate = delegate;

  NSArray *searchTerms = [searchString componentsSeparatedByString:@" "];

  // If it is likely a URL with a scheme, use the placeholder version.
  // This uses a conservative heuristic based on whether or not the scheme
  // actually exists in one of the tries, in order to avoid breaking title
  // queries containing a ':'.
  if ([searchTerms count] == 1) {
    NSString *searchStringWithSchemePlaceholder =
        [self urlStringWithSchemePlaceholder:searchString
                    restrictedToKnownSchemes:YES];
    if (searchStringWithSchemePlaceholder)
      searchTerms = [NSArray arrayWithObject:searchStringWithSchemePlaceholder];
  }

  // TODO: Make the trie searches asynchronous.

  // It's possible that there are duplicate bookmarks of the same URL, so we get
  // more than kMaxResultsPerHeading.
  // TODO: If we still don't get to kMaxResultsPerHeading, re-run the search
  // with a higher limit?
  NSArray *items = [mBookmarkTrie itemsForTerms:searchTerms
                                      withLimit:(2 * kMaxResultsPerHeading)];
  for (unsigned int i = 0; [mBookmarkResults count] < kMaxResultsPerHeading && i < [items count]; i++) {
    AutoCompleteResult *result = [self autoCompleteResultForItem:[items objectAtIndex:i]];
    if (![mBookmarkResults containsObject:result])
      [mBookmarkResults addObject:result];
  }
  items = [mHistoryTrie itemsForTerms:searchTerms
                            withLimit:(kMaxResultsPerHeading + [mBookmarkResults count])];
  for (unsigned int i = 0; [mHistoryResults count] < kMaxResultsPerHeading && i < [items count]; i++) {
    AutoCompleteResult *result = [self autoCompleteResultForItem:[items objectAtIndex:i]];
    if (![mBookmarkResults containsObject:result] &&
        ![mHistoryResults containsObject:result])
      [mHistoryResults addObject:result];
  }
  [self reportResults];
}

- (void)cancelSearch
{
  [self resetSearch];
  // TODO: Once performSearchWithString is once again asynchronous, implement
  // cancel logic.
}

- (AutoCompleteResult *)autoCompleteResultForItem:(id)item
{
  AutoCompleteResult *info = [[[AutoCompleteResult alloc] init] autorelease];
  [info setTitle:[item title]];
  [info setUrl:[item url]];
  if ([[info title] isEqualToString:@""]) {
    NSString *host = [[NSURL URLWithString:[info url]] host];
    [info setTitle:(host ? host : [info url])];
  }
  NSImage *cachedFavicon = [[SiteIconProvider sharedFavoriteIconProvider] favoriteIconForPage:[info url]];
  if (cachedFavicon)
    [info setIcon:cachedFavicon];
  else if ([[info url] hasPrefix:@"file://"])
    [info setIcon:mGenericFileIcon];
  else
    [info setIcon:mGenericSiteIcon];
  return info;
}

- (void)reportResults
{
  [self addHeader:NSLocalizedString(@"BookmarksWindowTitle", nil) toResults:mBookmarkResults];
  [self addHeader:NSLocalizedString(@"HistoryWindowTitle", nil) toResults:mHistoryResults];
  [mResults removeAllObjects];
  [mResults addObjectsFromArray:mBookmarkResults];
  [mResults addObjectsFromArray:mHistoryResults];
  [self resetSearch];
  [mDelegate searchResultsAvailable];
}

- (void)addHeader:(NSString *)header toResults:(NSMutableArray *)results
{
  if ([results count] == 0) {
    // Don't add a header to empty results.
    return;
  }
  AutoCompleteResult *info = [[[AutoCompleteResult alloc] init] autorelease];
  [info setIsHeader:YES];
  [info setTitle:header];
  [results insertObject:info atIndex:0];
}

- (int)rowCount {
  return [mResults count];
}

- (id)resultForRow:(int)aRow columnIdentifier:(NSString *)aColumnIdentifier
{
  if (aRow >= 0 && aRow < [self rowCount])
    return [mResults objectAtIndex:aRow];
  return nil;
}

- (int)numberOfRowsInTableView:(NSTableView*)aTableView
{
  return [self rowCount];
}

- (id)tableView:(NSTableView*)aTableView objectValueForTableColumn:(NSTableColumn*)aTableColumn row:(int)aRowIndex
{
  return [self resultForRow:aRowIndex columnIdentifier:[aTableColumn identifier]];
}

@end
