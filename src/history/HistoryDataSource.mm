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
 *   Simon Woodside <sbwoodside@yahoo.com>
 *   Simon Fraser <smfr@smfr.org>
 *   Christopher Henderson <trendyhendy2000@gmail.com>
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

#import "HistoryDataSource.h"

#import "NSString+Utils.h"
#import "NSString+Gecko.h"
#import "NSDate+Utils.h"

#import "BrowserWindowController.h"
#import "CHBrowserService.h"
#import "CHBrowserView.h"
#import "ExtendedOutlineView.h"
#import "HistoryItem.h"
#import "PreferenceManager.h"
#import "SiteIconProvider.h"

#include "nsComponentManagerUtils.h"
#include "nsCOMPtr.h"
#include "nsIBrowserHistory.h"
#include "nsINavHistoryService.h"
#include "nsIServiceManager.h"
#include "nsNetUtil.h"
#include "nsString.h"


NSString* const kHistoryDataSourceItemChangedNotification    = @"history_item_changed";
NSString* const kHistoryDataSourceChangedUserInfoChangeType  = @"change_type";

NSString* const kHistoryDataSourceClearedNotification = @"history_cleared";
NSString* const kHistoryDataSourceRebuiltNotification = @"history_rebuilt";

// Internal change queueing constants.
static NSString* const kChangeTypeKey = @"change_type";
enum {
  kChangeTypeVisit,
  kChangeTypeRemoval,
  kChangeTypeTitleChange
};
static NSString* const kChangeIdentifierKey = @"identifier";
static NSString* const kChangeNewTitleKey = @"new_title";
static NSString* const kChangeVisitItemKey = @"item";

// Amount of time to pause between chunks when loading history asynchronously.
static const NSTimeInterval kLoadNextChunkDelay = 0.05;
// Number of history items to load in each chunk.
static const unsigned int kNumberOfItemsPerChunk = 500;

#pragma mark -

@interface HistoryDataSource(Private)

// The overall flow for a load in the simple case where no load is already in
// progress is as follows:
// - A client calls either loadSynchronously or loadAsynchronouslyWithListener.
// - startLoading is called.
// - loadNextChunkOfSize: is called either with a chunk size (async) or nil
//   (sync) to start (and in the sync case, finish) the loading.
// - If everything is loaded, allItemsLoaded is called.
//   - If loading is canceled first, cancelLoading will be called.
// - Either way, loadingDone is called.
// - Any loading listeners are called to inform them that loading is done.
// - If loading wasn't canceled, processPendingChanges is called to handle
//   any changes that came in from the Gecko side while loading was in progress.
//
// In the case where an asynchronous load is already in progress, another async
// load call is essentially a no-op. A sync call when a load is in progress
// works as normal, except that startLoading is skipped since the in-progress
// load is used instead of creating a new one.

// Opens a history query in preparation for reading history items.
- (void)startLoading;
// Loads the next chunkSize history items. If |chunkSize| is nil, loads all
// remaining items.
- (void)loadNextChunkOfSize:(NSNumber*)chunkSize;
// Called when all the history items have been loaded.
- (void)allItemsLoaded;
// Returns true if an asynchronous history load is in progress.
- (BOOL)loadingInProgress;
// Cancels any asynchronous that is in progress.
- (void)cancelLoading;
// Called whenever loading stops, no matter what the cause.
- (void)loadingDone;
// Processes any change events that came in during an asyncronous load.
- (void)processPendingChanges;

- (void)batchingStarted;
- (void)batchingFinished;

// Callbacks for use by the Gecko history listener. These differ from
// the itemAdded/Removed/Changed calls in that they correctly handle being
// called during an asynchronous load, by queueing the change to be processed
// later (after loading is complete) so that ordering of operations is preserved
// (e.g., if a history item is removed, that can't be processed on the Cocoa
// side until that item has been loaded).
- (void)visitedItem:(HistorySiteItem*)item withIdentifier:(NSString*)identifier;
- (void)visitedItemWithIdentifier:(NSString*)identifier atDate:(NSDate*)date;
- (void)removedItemWithIdentifier:(NSString*)identifier;
- (void)changedTitleForItemWithIdentifier:(NSString*)identifier
                                       to:(NSString*)newTitle;

- (void)itemAdded:(HistorySiteItem*)item;
- (void)itemRemoved:(HistorySiteItem*)item;
- (void)itemChanged:(HistorySiteItem*)item;

- (void)sendChangeNotification:(HistoryChangeType)type
                       forItem:(HistorySiteItem *)item;
- (void)sendHistoryRebuildNotification;

- (void)removeAllObjects;
- (HistorySiteItem*)itemWithIdentifier:(NSString*)identifier;

- (void)siteIconLoaded:(NSNotification*)inNotification;

@end


#pragma mark -

class nsNavHistoryObserver : public nsINavHistoryObserver
{

public:
  nsNavHistoryObserver(HistoryDataSource* inDataSource)
  : mDataSource(inDataSource)
  {
  }
  
  virtual ~nsNavHistoryObserver()
  {
  }

protected:

  NSString* IdentifierForURI(nsIURI* inURI)
  {
    nsCAutoString url;
    if (inURI && NS_SUCCEEDED(inURI->GetSpec(url))) {
      return [NSString stringWith_nsACString:url];
    }

    return nil;
  }

public:

  NS_DECL_ISUPPORTS

  //
  // OnVisit
  //
  // This is called each time a URI is visited. For the first visit, we need
  // to create a new HistorySiteItem so we can add it to the data source.
  // For all subsequent visits, we just need to find that item and update it
  // with a new last visit date.
  //
  NS_IMETHOD OnVisit(nsIURI *aURI, PRInt64 aVisitID, PRTime aTime, PRInt64 aSessionID,
                     PRInt64 aReferringID, PRUint32 aTransitionType, PRUint32 *aAdded)
  {
    NS_ENSURE_ARG_POINTER(aURI);
    NS_ENSURE_ARG_POINTER(aAdded);

    // Ignore embedded objects, such as images.
    if (aTransitionType == nsINavHistoryService::TRANSITION_EMBED)
      return NS_OK;

    @try { // make sure we don't throw out into gecko
      NSString* identifier = IdentifierForURI(aURI);
      BOOL currentlyLoading = [mDataSource loadingInProgress];

      // If loading is still in progress, we have no way of knowing whether
      // there will be an item when loading is done, so we need to make one and
      // sort it out later.
      HistorySiteItem* item = currentlyLoading ?
          nil : [mDataSource itemWithIdentifier:identifier];

      if (item) {
        NSDate* newDate = [NSDate dateWithPRTime:aTime];
        [mDataSource visitedItemWithIdentifier:identifier atDate:newDate];
      }
      else {
        nsresult rv;
        nsCOMPtr<nsINavHistoryService> histSvc =
          do_GetService("@mozilla.org/browser/nav-history-service;1", &rv);
        NS_ENSURE_SUCCESS(rv, rv);
        NS_ENSURE_TRUE(histSvc, NS_ERROR_UNEXPECTED);

        nsCOMPtr<nsINavHistoryQuery> query;
        rv = histSvc->GetNewQuery(getter_AddRefs(query));
        NS_ENSURE_SUCCESS(rv, rv);
        NS_ENSURE_TRUE(query, NS_ERROR_UNEXPECTED);

        rv = query->SetUri(aURI);
        NS_ENSURE_SUCCESS(rv, rv);

        if (!currentlyLoading) {
          rv = query->SetMinVisits(1);
          NS_ENSURE_SUCCESS(rv, rv);

          rv = query->SetMaxVisits(1);
          NS_ENSURE_SUCCESS(rv, rv);
        }

        nsCOMPtr<nsINavHistoryQueryOptions> options;
        rv = histSvc->GetNewQueryOptions(getter_AddRefs(options));
        NS_ENSURE_SUCCESS(rv, rv);

        if (currentlyLoading) {
          rv = options->SetSortingMode(nsINavHistoryQueryOptions::SORT_BY_DATE_DESCENDING);
          NS_ENSURE_SUCCESS(rv, rv);

          rv = options->SetMaxResults(1);
          NS_ENSURE_SUCCESS(rv, rv);
        }

        nsCOMPtr<nsINavHistoryResult> result;
        rv = histSvc->ExecuteQuery(query, options, getter_AddRefs(result));
        NS_ENSURE_SUCCESS(rv, rv);
        NS_ENSURE_TRUE(result, NS_ERROR_UNEXPECTED);

        nsCOMPtr<nsINavHistoryContainerResultNode> rootNode;
        rv = result->GetRoot(getter_AddRefs(rootNode));
        NS_ENSURE_SUCCESS(rv, rv);
        NS_ENSURE_TRUE(rootNode, NS_ERROR_UNEXPECTED);

        rootNode->SetContainerOpen(PR_TRUE);

        // There should be 1 and only 1 result node returned from our query,
        // since either this is the first visit, or we restricted the search.
        PRUint32 childCount = 0;
        rv = rootNode->GetChildCount(&childCount);
        NS_ENSURE_SUCCESS(rv, rv);
#if DEBUG
        if (childCount != 1) {
          NSLog(@"%d result nodes in OnVisit for '%@' (currentlyLoading = %d)",
                childCount, identifier, currentlyLoading);
        }
#endif
        NS_ENSURE_TRUE(childCount == 1, NS_ERROR_UNEXPECTED);

        nsCOMPtr<nsINavHistoryResultNode> resultNode;
        rv = rootNode->GetChild(0, getter_AddRefs(resultNode));
        NS_ENSURE_SUCCESS(rv, rv);
        NS_ENSURE_TRUE(resultNode, NS_ERROR_UNEXPECTED);

        item = [[HistorySiteItem alloc] initWithDataSource:mDataSource
                                                resultNode:resultNode];
        [mDataSource visitedItem:item withIdentifier:identifier];
        [item release];
      }
    }
    @catch (id exception) {
      NSLog(@"Exception caught in OnVisit: %@", exception);
    }

    return NS_OK;
  }

  NS_IMETHOD OnBeginUpdateBatch()
  {
    [mDataSource batchingStarted];
    return NS_OK;
  }

  NS_IMETHOD OnEndUpdateBatch()
  {
    [mDataSource batchingFinished];
    return NS_OK;
  }

  NS_IMETHOD OnTitleChanged(nsIURI *aURI, const nsAString & aPageTitle)
  {
    NS_ENSURE_ARG_POINTER(aURI);

    @try { // make sure we don't throw out into gecko
      NSString* identifier = IdentifierForURI(aURI);
      if (identifier) {
        NSString* newTitle = [NSString stringWith_nsAString:aPageTitle];
        [mDataSource changedTitleForItemWithIdentifier:identifier
                                                    to:newTitle];
      }
    }
    @catch (id exception) {
      NSLog(@"Exception caught in OnTitleChanged: %@", exception);
    }
    return NS_OK;
  }

  NS_IMETHOD OnBeforeDeleteURI(nsIURI *aURI)
  {
    return NS_OK;
  }

  NS_IMETHOD OnDeleteURI(nsIURI *aURI)
  {
    NS_ENSURE_ARG_POINTER(aURI);

    @try { // make sure we don't throw out into gecko
      NSString* identifier = IdentifierForURI(aURI);
      if (identifier)
        [mDataSource removedItemWithIdentifier:identifier];
    }
    @catch (id exception) {
      NSLog(@"Exception caught in OnDeleteURI: %@", exception);
    }
    return NS_OK;
  }

  NS_IMETHOD OnClearHistory()
  {
    // Rather than calling |itemRemoved| for every item, just remove
    // all the items at once and rebuild.
    [mDataSource removeAllObjects];
    return NS_OK;
  }

  NS_IMETHOD OnPageChanged(nsIURI *aURI, PRUint32 aWhat, const nsAString & aValue)
  {
    return NS_OK;
  }

  NS_IMETHOD OnPageExpired(nsIURI *aURI, PRTime aVisitTime, PRBool aWholeEntry)
  {
    return NS_OK;
  }

protected:

  HistoryDataSource* mDataSource;  // Weak
};

NS_IMPL_ISUPPORTS1(nsNavHistoryObserver, nsINavHistoryObserver);

#pragma mark -

static HistoryDataSource* sSharedDataSource = nil;

@implementation HistoryDataSource

- (id)init
{
  if ((self = [super init])) {
    // register for xpcom shutdown
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(xpcomShutdownNotification:)
                                                 name:kXPCOMShutDownNotification
                                               object:nil];

    nsCOMPtr<nsINavHistoryService> histSvc = do_GetService("@mozilla.org/browser/nav-history-service;1");
    mNavHistoryService = histSvc;
    if (!mNavHistoryService) {
      NSLog(@"Failed to initialize HistoryDataSource (couldn't get global history)");
      [self autorelease];
      return nil;
    }
    NS_IF_ADDREF(mNavHistoryService);

    mNavHistoryObserver = new nsNavHistoryObserver(self);
    NS_ADDREF(mNavHistoryObserver);
    mNavHistoryService->AddObserver(mNavHistoryObserver, PR_FALSE);

    // register for site icon loads
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(siteIconLoaded:)
                                                 name:kSiteIconLoadNotification
                                               object:nil];

    mShowSiteIcons = [[PreferenceManager sharedInstance] getBooleanPref:kGeckoPrefEnableFavicons
                                                            withSuccess:NULL];

    // register for xpcom shutdown
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(xpcomShutdownNotification:)
                                                 name:kXPCOMShutDownNotification
                                               object:nil];
  }

  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];

  if (mNavHistoryObserver) {
    if (mNavHistoryService)
      mNavHistoryService->RemoveObserver(mNavHistoryObserver);
    NS_RELEASE(mNavHistoryObserver);
  }
  NS_IF_RELEASE(mNavHistoryService);

  [mHistoryItems release];
  [mHistoryItemsDictionary release];

  [super dealloc];
}

+ (HistoryDataSource*)sharedHistoryDataSource
{
  if (!sSharedDataSource)
    sSharedDataSource = [[self alloc] init];
  return sSharedDataSource;
}

- (void)xpcomShutdownNotification:(NSNotification*)inNotification
{
  [sSharedDataSource release];
  sSharedDataSource = nil;
}

#pragma mark -

- (void)batchingStarted
{
}

- (void)batchingFinished
{
  [self loadSynchronously];
  [self sendHistoryRebuildNotification];
}

- (void)visitedItem:(HistorySiteItem*)item withIdentifier:(NSString*)identifier
{
  if ([self loadingInProgress]) {
    [mPendingChangeQueue addObject:[NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithInt:kChangeTypeVisit], kChangeTypeKey,
                                       identifier, kChangeIdentifierKey,
                                             item, kChangeVisitItemKey,
                                                   nil]];
    return;
  }

  [self itemAdded:item];
}

- (void)visitedItemWithIdentifier:(NSString*)identifier atDate:(NSDate*)date
{
  if ([self loadingInProgress]) {
#if DEBUG
    NSLog(@"visitedItemWithIdentifier:atDate: called during asynchronous loading");
#endif
    return;
  }

  HistorySiteItem* item = [self itemWithIdentifier:identifier];
  if (!item)
    return;

  if ([[item lastVisit] isEqual:date])
    return;

  [item setLastVisitDate:date];
  [self itemChanged:item];
}

- (void)removedItemWithIdentifier:(NSString*)identifier
{
  if ([self loadingInProgress]) {
    [mPendingChangeQueue addObject:[NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithInt:kChangeTypeRemoval], kChangeTypeKey,
                                         identifier, kChangeIdentifierKey,
                                                     nil]];
    return;
  }

  HistorySiteItem* item = [self itemWithIdentifier:identifier];
  if (!item)
    return;

  [self itemRemoved:item];
}

- (void)changedTitleForItemWithIdentifier:(NSString*)identifier
                                       to:(NSString*)newTitle
{
  if ([self loadingInProgress]) {
    [mPendingChangeQueue addObject:[NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithInt:kChangeTypeTitleChange], kChangeTypeKey,
                                             identifier, kChangeIdentifierKey,
                                               newTitle, kChangeNewTitleKey,
                                                         nil]];
    return;
  }

  HistorySiteItem* item = [self itemWithIdentifier:identifier];
  if (!item)
    return;

  if ([newTitle isEqualToString:[item title]])
    return;

  [item setTitle:newTitle];
  [self itemChanged:item];
}

#pragma mark -

- (void)itemAdded:(HistorySiteItem*)item
{
  [mHistoryItems addObject:item];
  [mHistoryItemsDictionary setObject:item forKey:[item identifier]];

  [self sendChangeNotification:kHistoryChangeItemAdded forItem:item];
}

- (void)itemRemoved:(HistorySiteItem*)item
{
  [[item retain] autorelease];  // Extend lifetime to construct the notification.
  [mHistoryItems removeObject:item];
  [mHistoryItemsDictionary removeObjectForKey:[item identifier]];

  [self sendChangeNotification:kHistoryChangeItemRemoved forItem:item];
}

- (void)itemChanged:(HistorySiteItem*)item
{
  [self sendChangeNotification:kHistoryChangeItemModified forItem:item];
}

#pragma mark -

- (void)loadSynchronously
{
  // If loading is already in progress, just finish it synchronously.
  if ([self loadingInProgress])
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
  else
    [self startLoading];

  // If there's no node, something went wrong.
  if (!mRootNode)
    return;

  [self loadNextChunkOfSize:nil];
}

- (void)loadAsynchronouslyWithListener:(id<HistoryLoadListener>)listener
{
  if ([self loadingInProgress]) {
    [mLoadListeners addObject:listener];
    return;
  }

  mLoadListeners = [[NSMutableArray arrayWithObject:listener] retain];
  mPendingChangeQueue = [[NSMutableArray alloc] init];

  [self startLoading];

  // If there's no node, something went wrong.
  if (!mRootNode) {
    [listener historyLoadingComplete];
    [mLoadListeners removeAllObjects];
    return;
  }

  [self loadNextChunkOfSize:[NSNumber numberWithUnsignedInt:kNumberOfItemsPerChunk]];
}

- (BOOL)isLoaded
{
  return mHistoryLoaded;
}

- (void)startLoading
{
  [self cancelLoading];

  nsCOMPtr<nsINavHistoryQuery> query;
  nsresult rv;
  rv = mNavHistoryService->GetNewQuery(getter_AddRefs(query));
  NS_ENSURE_SUCCESS(rv, /* void */);

  nsCOMPtr<nsINavHistoryQueryOptions> options;
  rv = mNavHistoryService->GetNewQueryOptions(getter_AddRefs(options));
  NS_ENSURE_SUCCESS(rv, /* void */);

  nsCOMPtr<nsINavHistoryResult> result;
  rv = mNavHistoryService->ExecuteQuery(query, options, getter_AddRefs(result));
  NS_ENSURE_SUCCESS(rv, /* void */);
  NS_ENSURE_TRUE(result, /* void */);

  nsCOMPtr<nsINavHistoryContainerResultNode> rootNode;
  rv = result->GetRoot(getter_AddRefs(rootNode));
  NS_ENSURE_SUCCESS(rv, /* void */);
  NS_ENSURE_TRUE(rootNode, /* void */);

  rv = rootNode->SetContainerOpen(PR_TRUE);
  NS_ENSURE_SUCCESS(rv, /* void */);

  PRUint32 childCount = 0;
  rv = rootNode->GetChildCount(&childCount);
  NS_ENSURE_SUCCESS(rv, /* void */);

  mRootNode = rootNode.get();
  NS_ADDREF(mRootNode);
  mResultCount = childCount;
  mCurrentIndex = 0;

  mHistoryLoaded = NO;
  [mHistoryItems release];
  mHistoryItems = [[NSMutableArray alloc] initWithCapacity:mResultCount];
  [mHistoryItemsDictionary release];
  mHistoryItemsDictionary = [[NSMutableDictionary alloc] initWithCapacity:childCount];
}

- (void)loadNextChunkOfSize:(NSNumber*)chunkSize
{
  unsigned int stopIndex = mResultCount;
  if (chunkSize) {
    unsigned int chunkMax = mCurrentIndex + [chunkSize unsignedIntValue];
    if (chunkMax < mResultCount)
      stopIndex = chunkMax;
  }

  for (; mCurrentIndex < stopIndex; ++mCurrentIndex) {
    nsCOMPtr<nsINavHistoryResultNode> child;
    mRootNode->GetChild(mCurrentIndex, getter_AddRefs(child));
    if (!child)
      continue;
    HistorySiteItem* item = [[HistorySiteItem alloc] initWithDataSource:self
                                                             resultNode:child];
    [mHistoryItems addObject:item];
    [mHistoryItemsDictionary setObject:item forKey:[item identifier]];
    [item release];
  }

  if (mCurrentIndex == mResultCount) {
    [self allItemsLoaded];
    return;
  }

  [self performSelector:@selector(loadNextChunkOfSize:)
             withObject:chunkSize
             afterDelay:kLoadNextChunkDelay];
}

- (BOOL)loadingInProgress
{
  return mRootNode != NULL;
}

- (void)allItemsLoaded
{
  [self loadingDone];
}

- (void)cancelLoading
{
  if ([self loadingInProgress]) {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [self loadingDone];
  }
}

- (void)loadingDone
{
  NS_IF_RELEASE(mRootNode);
  mHistoryLoaded = YES;

  NSEnumerator* listenerEnumerator = [mLoadListeners objectEnumerator];
  id<HistoryLoadListener> listener;
  while ((listener = [listenerEnumerator nextObject])) {
    [listener historyLoadingComplete];
  }
  [mLoadListeners release];
  mLoadListeners = nil;

  [self processPendingChanges];
}

- (void)processPendingChanges
{
  NSEnumerator* changeEnumerator = [mPendingChangeQueue objectEnumerator];
  NSDictionary* changeInfo;
  while ((changeInfo = [changeEnumerator nextObject])) {
    int changeType = [[changeInfo objectForKey:kChangeTypeKey] intValue];
    NSString* identifier = [changeInfo objectForKey:kChangeIdentifierKey];
    switch (changeType) {
      case kChangeTypeVisit: {
        HistorySiteItem* existingItem = [self itemWithIdentifier:identifier];
        HistorySiteItem* newItem = [changeInfo objectForKey:kChangeVisitItemKey];
        if (existingItem) {
          [self visitedItemWithIdentifier:identifier
                                   atDate:[newItem lastVisit]];
        } else {
          [self visitedItem:newItem withIdentifier:identifier];
        }
        break;
      }
      case kChangeTypeRemoval: {
        [self removedItemWithIdentifier:identifier];
        break;
      }
      case kChangeTypeTitleChange: {
        NSString* title = [changeInfo objectForKey:kChangeNewTitleKey];
        [self changedTitleForItemWithIdentifier:identifier
                                             to:title];
        break;
      }
      default:
#if DEBUG
        NSLog(@"Uh-oh, unknown history change type in queue");
#endif
        break;
    }
  }
  [mPendingChangeQueue release];
  mPendingChangeQueue = nil;
}

#pragma mark -

- (void)sendChangeNotification:(HistoryChangeType)type
                       forItem:(HistorySiteItem *)item
{
  NSMutableDictionary* userInfoDict = [NSMutableDictionary
      dictionaryWithObject:[NSNumber numberWithInt:type]
                    forKey:kHistoryDataSourceChangedUserInfoChangeType];

  [[NSNotificationCenter defaultCenter]
      postNotificationName:kHistoryDataSourceItemChangedNotification
                    object:item
                  userInfo:userInfoDict];
}

- (void)sendHistoryRebuildNotification
{
  [[NSNotificationCenter defaultCenter]
      postNotificationName:kHistoryDataSourceRebuiltNotification
                    object:self
                  userInfo:nil];
}

#pragma mark -

- (BOOL)showSiteIcons
{
  return mShowSiteIcons;
}

- (NSArray*)historyItems
{
  return mHistoryItems;
}

- (HistorySiteItem*)itemWithIdentifier:(NSString*)identifier
{
  return [mHistoryItemsDictionary objectForKey:identifier];
}

- (void)siteIconLoaded:(NSNotification*)inNotification
{
  HistoryItem* theItem = [inNotification object];
  // if it's not a site item, or it doesn't belong to this data source, ignore it
  // (we instantiate multiple data sources)
  if (![theItem isKindOfClass:[HistorySiteItem class]] || [theItem dataSource] != self)
    return;

  HistorySiteItem* siteItem = (HistorySiteItem*)theItem;
  NSImage* iconImage = [[inNotification userInfo] objectForKey:kSiteIconLoadImageKey];
  if (iconImage) {
    [siteItem setSiteIcon:iconImage];
    [self sendChangeNotification:kHistoryChangeIconLoaded forItem:siteItem];
  }
}

- (void)removeItem:(HistorySiteItem*)item
{
  nsCOMPtr<nsIURI> doomedURI;
  NS_NewURI(getter_AddRefs(doomedURI), [[item url] UTF8String]);
  if (doomedURI)
  {
    nsCOMPtr<nsIBrowserHistory> hist(do_QueryInterface(mNavHistoryService));
    if (hist)
      hist->RemovePage(doomedURI);
    [self itemRemoved:item];
  }
}

- (void)removeAllObjects
{
  [self cancelLoading];
  [mPendingChangeQueue release];
  mPendingChangeQueue = nil;
  [mHistoryItems removeAllObjects];
  [mHistoryItemsDictionary removeAllObjects];

  [[NSNotificationCenter defaultCenter]
      postNotificationName:kHistoryDataSourceClearedNotification
                    object:self
                  userInfo:nil];

  // Send a rebuild notification as well so that clients that just care about
  // the raw items don't have to listen for both.
  [self sendHistoryRebuildNotification];
}

@end
