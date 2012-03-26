/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*-
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "NSString+Gecko.h"
#import "NSString+Utils.h"

#import <AppKit/AppKit.h>
#import "AutoCompleteDataSource.h"
#import "AutoCompleteKeywordGenerator.h"
#import "AutoCompleteScorer.h"
#import "AutoCompleteResult.h"
#import "Trie.h"
#import "CHBrowserService.h"
#import "PreferenceManager.h"
#import "SiteIconProvider.h"

#import "Bookmark.h"
#import "BookmarkFolder.h"
#import "BookmarkManager.h"

#import "HistoryItem.h"
#import "HistoryDataSource.h"

static const unsigned int kMaxResultsCount = 10;
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

// Convenience class to allow efficient enumerator-like access to Trie search
// results. The search is re-run with a higher limit each time nextResult is
// called, so that the search runs only as far as is necessary.
// This is efficient only if the Trie's search result cache is not invaidated,
// so a TrieSearchEnumerator should not be used across changes to, or other
// queries on, a given Trie.
@interface TrieSearchEnumerator : NSObject
{
  Trie*        mTrie;
  NSArray*     mSearchTerms;
  unsigned int mNextResultIndex;
}

// Convenience method for returning a new autoreleased search enumerator.
+ (id)enumeratorWithTrie:(Trie *)trie searchTerms:(NSArray *)terms;

// Initializes a new enumerator with the given trie and search terms.
- (id)initWithTrie:(Trie *)trie searchTerms:(NSArray *)terms;

// Returns the next search result. Returns |nil| if there are no more results.
- (id)nextResult;

@end

@implementation TrieSearchEnumerator

+ (id)enumeratorWithTrie:(Trie *)trie searchTerms:(NSArray *)terms
{
  return [[[[self class] alloc ] initWithTrie:trie
                                  searchTerms:terms] autorelease];
}

- (id)initWithTrie:(Trie *)trie searchTerms:(NSArray *)terms
{
  if ((self = [super init])) {
    mTrie = [trie retain];
    mSearchTerms = [terms retain];
  }
  return self;
}

- (void)dealloc
{
  [mTrie release];
  [mSearchTerms release];
  [super dealloc];
}

- (id)nextResult
{
  NSArray *results = [mTrie itemsForTerms:mSearchTerms
                                withLimit:(mNextResultIndex + 1)];
  if ([results count] > mNextResultIndex)
    return [[[results objectAtIndex:mNextResultIndex++] retain] autorelease];
  return nil;
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

// Helper method for asyncronous loading; inserts a chunk of |items| into
// |trie|, removing them from |items|.
- (NSArray *)mergedResultsFromBookmarks:(TrieSearchEnumerator *)bookmarkEnumerator
                                history:(TrieSearchEnumerator *)historyEnumerator;

// Creates and returns an AutoCompleteResult object for the given item.
// The AutoCompleteResult class is used by the AutoCompleteCell to store
// all of the data relevant to drawing a cell.
- (AutoCompleteResult *)autoCompleteResultForItem:(id)item;

// Sets mResults to the given results, then calls searchResultsAvailable on
// the delegate.
- (void)reportResults:(NSArray *)results;

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
    mResults = [[NSMutableArray alloc] init];
    mGenericSiteIcon = [[NSImage imageNamed:@"globe_ico"] retain];
    mGenericFileIcon = [[NSImage imageNamed:@"smallDocument"] retain];

    mTrieScorer = [[AutoCompleteScorer alloc] init];
    // As a short-term measure, allow users to disable use of titles as a data
    // source by setting a hidden pref. 
    // TODO: Remove this check and the associated code in
    // AutoCompleteKeywordGenerator once we have implemented learning and
    // improved scoring.
    BOOL gotPref;
    BOOL shouldAutocompleteTitles = [[PreferenceManager sharedInstanceDontCreate]
                                        getBooleanPref:kGeckoPrefLocationBarAutocompleteFromTitles
                                           withSuccess:&gotPref];
    shouldAutocompleteTitles = gotPref ? shouldAutocompleteTitles : YES;
    mKeywordGenerator = [[AutoCompleteKeywordGenerator alloc] init];
    [mKeywordGenerator setGeneratesTitleKeywords:shouldAutocompleteTitles];
    mBookmarkTrie = [[Trie alloc] initWithKeywordGenerator:mKeywordGenerator
                                                    scorer:mTrieScorer
                                                  maxDepth:kMaxTrieDepth];
    mHistoryTrie = [[Trie alloc] initWithKeywordGenerator:mKeywordGenerator
                                                   scorer:mTrieScorer
                                                 maxDepth:kMaxTrieDepth];

    NSNotificationCenter *notificationCenter =
        [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self
                           selector:@selector(historyChanged:)
                               name:kHistoryDataSourceItemChangedNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(historyRebuilt:)
                               name:kHistoryDataSourceRebuiltNotification
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
  [mKeywordGenerator release];
  [mTrieScorer release];

  [mResults release];
  [mHistoryItemsToLoad release];
  [mBookmarksToLoad release];
  [mGenericSiteIcon release];
  [mGenericFileIcon release];
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
      objectForKey:kHistoryDataSourceChangedUserInfoChangeType] intValue];
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

- (void)initialBookmarkLoadComplete:(NSNotification *)notification
{
  [[NSNotificationCenter defaultCenter]
      removeObserver:self
                name:kBookmarkManagerStartedNotification
              object:nil];
  [self startBuildingBookmarkTrie];
}

- (void)startBuildingBookmarkTrie
{
  BookmarkManager* bookmarkManager = [BookmarkManager sharedBookmarkManager];
  // If bookmark loading isn't complete yet, wait until it is.
  if (![bookmarkManager bookmarksLoaded]) {
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(initialBookmarkLoadComplete:)
               name:kBookmarkManagerStartedNotification
             object:nil];
    return;
  }

  BookmarkFolder *bookmarkRoot = [bookmarkManager bookmarkRoot];
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
                             name:kBookmarkItemChangedNotification
                           object:nil];
  [notificationCenter addObserver:self
                         selector:@selector(bookmarksAddedOrRemoved:)
                             name:kBookmarkItemsAddedNotification
                           object:nil];
  [notificationCenter addObserver:self
                         selector:@selector(bookmarksAddedOrRemoved:)
                             name:kBookmarkItemsRemovedNotification
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
      [[notificationInfo objectForKey:kBookmarkItemChangedFlagsKey] unsignedIntValue];
  unsigned int interestingFlagsMask = kBookmarkItemTitleChangedMask |
                                      kBookmarkItemShortcutChangedMask |
                                      kBookmarkItemURLChangedMask |
                                      kBookmarkItemVisitCountChangedMask;
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
      [[notification name] isEqualToString:kBookmarkItemsAddedNotification] ?
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
  [mTrieScorer cacheCurrentTime];
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
  [mTrieScorer clearTimeCache];

  [items removeObjectsInRange:NSMakeRange(0, processedCount)];
}

#pragma mark -

- (void)resetSearch
{
  [mResults removeAllObjects];
}

- (void)performSearchWithString:(NSString *)searchString delegate:(id)delegate
{
  mDelegate = delegate;

  NSArray *searchTerms = [mKeywordGenerator searchTermsForString:searchString];

  // TODO: Make the trie searches asynchronous? That would create the
  // possibility of the results being invalidated during iteration though.
  TrieSearchEnumerator *bookmarkEnumerator =
      [TrieSearchEnumerator enumeratorWithTrie:mBookmarkTrie
                                   searchTerms:searchTerms];
  TrieSearchEnumerator *historyEnumerator =
      [TrieSearchEnumerator enumeratorWithTrie:mHistoryTrie
                                   searchTerms:searchTerms];
  [self reportResults:[self mergedResultsFromBookmarks:bookmarkEnumerator
                                               history:historyEnumerator]];
}

- (void)cancelSearch
{
  [self resetSearch];
  // TODO: Once performSearchWithString is once again asynchronous, implement
  // cancel logic.
}

- (NSArray *)mergedResultsFromBookmarks:(TrieSearchEnumerator *)bookmarkEnumerator
                                history:(TrieSearchEnumerator *)historyEnumerator
{
  NSMutableArray *results = [NSMutableArray arrayWithCapacity:kMaxResultsCount];
  [mTrieScorer cacheCurrentTime];
  Bookmark *nextBookmark = [bookmarkEnumerator nextResult];
  HistoryItem *nextHistoryItem = [historyEnumerator nextResult];
  double bookmarkScore =
      nextBookmark ? [mTrieScorer scoreForItem:nextBookmark] : 0;
  double historyScore =
      nextHistoryItem ? [mTrieScorer scoreForItem:nextHistoryItem] : 0;
  // Regardless of the scores, don't take more than 70% of the results from one
  // source (unless the other is out of matches), so that the top results from
  // both sources always show.
  const unsigned int kSourceLimit = 0.7 * kMaxResultsCount;
  unsigned int bookmarksUsed = 0;
  unsigned int historyItemsUsed = 0;

  while ([results count] < kMaxResultsCount &&
         (nextBookmark || nextHistoryItem))
  {
    AutoCompleteResult *result = nil;
    unsigned int *sourceCount = NULL;
    if (nextBookmark && (!nextHistoryItem ||
                         historyItemsUsed >= kSourceLimit ||
                         (bookmarksUsed < kSourceLimit &&
                          bookmarkScore >= historyScore)))
    {
      result = [self autoCompleteResultForItem:nextBookmark];
      nextBookmark = nextBookmark ? [bookmarkEnumerator nextResult] : 0;
      bookmarkScore = [mTrieScorer scoreForItem:nextBookmark];
      sourceCount = &bookmarksUsed;
    }
    else {
      result = [self autoCompleteResultForItem:nextHistoryItem];
      nextHistoryItem = [historyEnumerator nextResult];
      historyScore =
          nextHistoryItem ? [mTrieScorer scoreForItem:nextHistoryItem] : 0;
      sourceCount = &historyItemsUsed;
    }
    if (![results containsObject:result]) {
      [results addObject:result];
      *sourceCount += 1;
    }
  }
  [mTrieScorer clearTimeCache];
  return results;
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

- (void)reportResults:(NSArray *)results
{
  [mResults removeAllObjects];
  [mResults addObjectsFromArray:results];
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
