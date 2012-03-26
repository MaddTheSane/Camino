/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Foundation/Foundation.h>

@class NetworkServices;

// protocol implemented by someone who wants to provide UI for network services

@protocol NetworkServicesClient

- (void)availableServicesChanged:(NSNotification *)note;
- (void)serviceResolved:(NSNotification *)note;
- (void)serviceResolutionFailed:(NSNotification *)note;

@end

@interface NetworkServices : NSObject
{
    // browser can only do one search at a time, so we have a browser for
    // each protocol that we care about.
    NSNetServiceBrowser*    mHttpBrowser;
    NSNetServiceBrowser*    mHttpsBrowser;
    NSNetServiceBrowser*    mFtpBrowser;

    int                     mCurServiceID;      // unique ID for each service
    NSMutableDictionary*    mNetworkServices;  // services keyed by ID
    
    NSMutableDictionary*    mClients;           // dictionary of cliend id's for a request    
}

+ (id)sharedNetworkServices;
+ (void)shutdownNetworkServices;
- (void)startServices;
- (void)stopServices;
- (void)attemptResolveService:(int)serviceID forSender:(id)aSender;

- (NSString*)serviceName:(int)serviceID;
- (NSString*)serviceProtocol:(int)serviceID;
- (NSEnumerator*)serviceEnumerator;

// Notifications
extern NSString* const kNetworkServicesAvailableServicesChanged;
extern NSString* const kNetworkServicesResolutionSuccess;
extern NSString* const kNetworkServicesResolutionFailure;
extern NSString* const kNetworkServicesClientKey;
extern NSString* const kNetworkServicesResolvedURLKey;
extern NSString* const kNetworkServicesServiceKey;

@end
