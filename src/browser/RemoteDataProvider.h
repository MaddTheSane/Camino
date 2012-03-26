/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Foundation/Foundation.h>
#import "nscore.h"

extern NSString* const kRemoteDataLoadRequestNotification;
extern NSString* const kRemoteDataLoadRequestURIKey;
extern NSString* const kRemoteDataLoadRequestDataKey;
extern NSString* const kRemoteDataLoadRequestUserDataKey;
extern NSString* const kRemoteDataLoadRequestResultKey;

// RemoteDataProvider is a class that can be used to do asynchronous loads
// from URIs using necko, and passing back the result of the load to a
// callback in NSData.
//
// Clients can either implement the RemoteLoadListener protocol and call
// loadURI directly, or they can register with the [NSNotification defaultCenter]
// for 'RemoteDataLoadRequestNotification' notifications, and catch all loads
// that happen that way.

@protocol RemoteLoadListener <NSObject>
// called when the load completes, or fails. If the status code is a failure code,
// data may be nil.
- (void)doneRemoteLoad:(NSString*)inURI forTarget:(id)target withUserData:(id)userData data:(NSData*)data status:(nsresult)status usingNetwork:(BOOL)usingNetwork;
@end


class RemoteURILoadManager;

@interface RemoteDataProvider : NSObject<RemoteLoadListener>
{
  RemoteURILoadManager* mLoadManager;
}

+ (RemoteDataProvider*)sharedRemoteDataProvider;

// generic method. You can load any URI asynchronously with this selector,
// and the listener will get the contents of the URI in an NSData.
// If allowNetworking is NO, then this method will just check the cache,
// and not go to the network
// This method will return YES if the request was dispatched, or NO otherwise.
- (BOOL)loadURI:(NSString*)inURI forTarget:(id)target withListener:(id<RemoteLoadListener>)inListener
          withUserData:(id)userData allowNetworking:(BOOL)inNetworkOK;

// specific request to load a remote file. The sender (or any other object), if
// registered with the notification center, will receive a notification when
// the load completes. The 'target' becomes the 'object' of the notification.
// The notification name is given by NSString* kRemoteDataLoadRequestNotification above.
// If allowNetworking is NO, then this method will just check the cache,
// and not go to the network
// This method will return YES if the request was dispatched, or NO otherwise.
- (BOOL)postURILoadRequest:(NSString*)inURI forTarget:(id)target
          withUserData:(id)userData allowNetworking:(BOOL)inNetworkOK;

// cancel all outstanding requests
- (void)cancelOutstandingRequests;

@end
