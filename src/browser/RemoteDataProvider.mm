/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "ChimeraUtils.h"
#import "NSString+Gecko.h"

#import "RemoteDataProvider.h"

#include "nsISupports.h"
#include "nsHashtable.h"
#include "nsNetUtil.h"
#include "nsICacheSession.h"
#include "nsICacheService.h"
#include "nsICacheEntryDescriptor.h"
#include "nsICachingChannel.h"

NSString* const kRemoteDataLoadRequestNotification = @"remoteload_notification";
NSString* const kRemoteDataLoadRequestURIKey       = @"remoteload_uri_key";
NSString* const kRemoteDataLoadRequestDataKey      = @"remoteload_data_key";
NSString* const kRemoteDataLoadRequestUserDataKey  = @"remoteload_user_data_key";
NSString* const kRemoteDataLoadRequestResultKey    = @"remoteload_result_key";


// this has to retain the load listener, to ensure that the listener lives long
// enough to receive notifications. We have to be careful to avoid ref cycles.
class StreamLoaderContext : public nsISupports
{
public:
  StreamLoaderContext(id<RemoteLoadListener> inLoadListener, id inUserData, id inTarget, const nsAString& inURI, PRBool inUsingNetwork)
  : mLoadListener(inLoadListener)
  , mTarget(inTarget)
  , mUserData(inUserData)
  , mURI(inURI)
  , mUsingNetwork(inUsingNetwork)
  {
    [mLoadListener retain];
    [mTarget retain];
    [mUserData retain];
  }
  
  virtual ~StreamLoaderContext()
  {
    [mLoadListener release];
    [mTarget release];
    [mUserData release];
  }
  
  NS_DECL_ISUPPORTS

  void                    LoadComplete(nsresult inLoadStatus, const void* inData, unsigned int inDataLength);  
  const nsAString&        GetURI() { return mURI; }
  PRBool                  IsNetworkLoad() const { return mUsingNetwork; }

protected:

  // we have to retain all of these so that by the time the necko request completes, the target
  // to which we send the notification (|mTarget|) and its "parameters" (|mUserData|) are still around.
  id<RemoteLoadListener>	mLoadListener; // retained
  id                      mTarget;       // retained
  id                      mUserData;     // retained
  nsString                mURI;
  PRBool                  mUsingNetwork;
  
};


NS_IMPL_THREADSAFE_ISUPPORTS1(StreamLoaderContext, nsISupports)

void StreamLoaderContext::LoadComplete(nsresult inLoadStatus, const void* inData, unsigned int inDataLength)
{
  StAutoreleasePool pool;

  if (mLoadListener)
  {
    NSData* loadData = nil;
    if (NS_SUCCEEDED(inLoadStatus))
      loadData = [NSData dataWithBytes:inData length:inDataLength];

    [mLoadListener doneRemoteLoad:[NSString stringWith_nsAString:mURI] forTarget:mTarget
                                                                    withUserData:mUserData
                                                                            data:loadData
                                                                          status:inLoadStatus
                                                                    usingNetwork:mUsingNetwork];
  }
}

#pragma mark -

class RemoteURILoadManager : public nsIStreamLoaderObserver
{
public:

                        RemoteURILoadManager();
  virtual               ~RemoteURILoadManager();

  NS_DECL_ISUPPORTS
  NS_DECL_NSISTREAMLOADEROBSERVER

  nsresult              Init();
  nsresult              RequestURILoad(const nsAString& inURI, id<RemoteLoadListener> loadListener, id userData, id target, PRBool allowNetworking);
  nsresult              CancelAllRequests();
  
protected:

  nsSupportsHashtable		mStreamLoaderHash;		// hash of active stream loads, keyed on URI
  nsCOMPtr<nsICacheSession> mCacheSession;
  nsCOMPtr<nsILoadGroup>    mLoadGroup;

};

RemoteURILoadManager::RemoteURILoadManager()
{
}

RemoteURILoadManager::~RemoteURILoadManager()
{
}

NS_IMPL_ISUPPORTS1(RemoteURILoadManager, nsIStreamLoaderObserver)

NS_IMETHODIMP RemoteURILoadManager::OnStreamComplete(nsIStreamLoader *loader, nsISupports *ctxt, nsresult status, PRUint32 resultLength, const PRUint8 *result)
{
  StreamLoaderContext* loaderContext = static_cast<StreamLoaderContext*>(ctxt);
  if (loaderContext)
  {
    loaderContext->LoadComplete(status, (const void*)result, resultLength);

    // remove the stream loader from the hash table
    nsStringKey	uriKey(loaderContext->GetURI());
    mStreamLoaderHash.Remove(&uriKey);
  }
  
  return NS_OK;
}

static NS_DEFINE_CID(kCacheServiceCID, NS_CACHESERVICE_CID);

nsresult RemoteURILoadManager::Init()
{
  nsresult rv;
  nsCOMPtr<nsICacheService> cacheService = do_GetService(kCacheServiceCID, &rv);
  if (NS_FAILED(rv))
    return rv;
  
  rv = cacheService->CreateSession("HTTP", nsICache::STORE_ANYWHERE,
                                           nsICache::STREAM_BASED, getter_AddRefs(mCacheSession));

  return rv;
}

nsresult RemoteURILoadManager::RequestURILoad(const nsAString& inURI, id<RemoteLoadListener> loadListener,
  id userData, id target, PRBool allowNetworking)
{
  nsresult rv;
  
  nsStringKey	uriKey(inURI);

  // first make sure that there isn't another entry in the hash for this
  nsCOMPtr<nsISupports> foundStreamSupports = mStreamLoaderHash.Get(&uriKey);
  if (foundStreamSupports)
  {
    return NS_OK;
  }

  nsCOMPtr<nsIURI> uri;
  rv = NS_NewURI(getter_AddRefs(uri), inURI);
  if (NS_FAILED(rv))
    return rv;
  
  // create a load group, that we can use to cancel all the requests on quit
  if (!mLoadGroup)
    mLoadGroup = do_CreateInstance(NS_LOADGROUP_CONTRACTID);
    
  nsCOMPtr<nsISupports> loaderContext = new StreamLoaderContext(loadListener, userData, target, inURI, allowNetworking);
 
  // Don't show progress or cookie dialogs.  Cast to avoid "enumeral
  // mismatch" - thanks a lot, xpidl.
  nsLoadFlags loadFlags = (nsLoadFlags)nsIRequest::LOAD_BACKGROUND |
    (allowNetworking ? (nsLoadFlags)nsIRequest::LOAD_NORMAL :
                       ((nsLoadFlags)nsIRequest::LOAD_FROM_CACHE |
                        (nsLoadFlags)nsICachingChannel::LOAD_ONLY_FROM_CACHE));

  // we have to make a channel ourselves for the streamloader, so that we can 
  // do the nsICachingChannel stuff.
  nsCOMPtr<nsIChannel> channel;
  rv = NS_NewChannel(getter_AddRefs(channel), uri, nsnull, mLoadGroup,
                     nsnull, loadFlags);
  if (NS_FAILED(rv)) return rv;

  nsCOMPtr<nsIStreamLoader> streamLoader;
  rv = NS_NewStreamLoader(getter_AddRefs(streamLoader), this);

  if (NS_SUCCEEDED(rv))
    rv = channel->AsyncOpen(streamLoader, loaderContext);

  if (NS_FAILED(rv))
  {
#if DEBUG
    NSLog(@"NS_NewStreamLoader for favicon failed");
#endif
    return rv;
  }

  // put the stream loader into the hash table
  nsCOMPtr<nsISupports> streamLoaderAsSupports = do_QueryInterface(streamLoader);
  mStreamLoaderHash.Put(&uriKey, streamLoaderAsSupports);

  return NS_OK;
}

nsresult RemoteURILoadManager::CancelAllRequests()
{
	if (mLoadGroup)
    mLoadGroup->Cancel(NS_BINDING_ABORTED);
  return NS_OK;
}


#pragma mark -


@implementation RemoteDataProvider


+ (RemoteDataProvider*)sharedRemoteDataProvider
{
  static RemoteDataProvider* sIconProvider = nil;
  if (!sIconProvider)
  {
    sIconProvider = [[RemoteDataProvider alloc] init];
    
    // we probably need to register for NSApplicationWillTerminateNotification notifications
    // and delete this then.
  }
  
  return sIconProvider;
}

- (id)init
{
  if ((self = [super init]))
  {
    mLoadManager = new RemoteURILoadManager;
    NS_ADDREF(mLoadManager);
    nsresult rv = mLoadManager->Init();
    if (NS_FAILED(rv))
    {
      NS_RELEASE(mLoadManager);
      mLoadManager = nil;
    }
  }
  
  return self;
}

- (void)dealloc
{
  NS_IF_RELEASE(mLoadManager);
  [super dealloc];
}

- (BOOL)loadURI:(NSString*)inURI forTarget:(id)target withListener:(id<RemoteLoadListener>)inListener
      withUserData:(id)userData allowNetworking:(BOOL)inNetworkOK
{
  if (mLoadManager && [inURI length] > 0)
  {
    nsAutoString uriString;
    [inURI assignTo_nsAString:uriString];
    
    nsresult rv = mLoadManager->RequestURILoad(uriString, inListener, userData, target, (PRBool)inNetworkOK);
    if (NS_FAILED(rv))
      return NO;
  }
  
  return YES;
}

- (BOOL)postURILoadRequest:(NSString*)inURI forTarget:(id)target withUserData:(id)userData allowNetworking:(BOOL)inNetworkOK
{
  return [self loadURI:inURI forTarget:target withListener:self withUserData:userData allowNetworking:inNetworkOK];
}


- (void)cancelOutstandingRequests
{
  if (mLoadManager)
    mLoadManager->CancelAllRequests();
}


// our own load listener callback
- (void)doneRemoteLoad:(NSString*)inURI forTarget:(id)target withUserData:(id)userData data:(NSData*)data status:(nsresult)status usingNetwork:(BOOL)usingNetwork
{
  NSDictionary*	notificationData = [NSDictionary dictionaryWithObjectsAndKeys:
                              inURI, kRemoteDataLoadRequestURIKey,
                               data, kRemoteDataLoadRequestDataKey,
                           userData, kRemoteDataLoadRequestUserDataKey,
    [NSNumber numberWithInt:status], kRemoteDataLoadRequestResultKey,
                                     nil];
  
  [[NSNotificationCenter defaultCenter] postNotificationName:kRemoteDataLoadRequestNotification
      	object:target userInfo:notificationData];
}

@end
