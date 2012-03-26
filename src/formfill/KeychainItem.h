/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Foundation/Foundation.h>
#import <Security/Security.h>

@interface KeychainItem : NSObject
{
 @private
  SecKeychainItemRef mKeychainItemRef; // strong
  BOOL mDataLoaded;
  BOOL mPasswordLoaded;
  NSString* mUsername;                 // strong
  NSString* mPassword;                 // strong
  NSString* mHost;                     // strong
  NSString* mComment;                  // strong
  NSString* mSecurityDomain;           // strong
  NSString* mLabel;                    // strong
  SecProtocolType mPort;
  SecProtocolType mProtocol;
  SecAuthenticationType mAuthenticationType;
  OSType mCreator;

  OSStatus mLastError;
}

// Returns the first keychain item matching the given criteria.
+ (KeychainItem*)keychainItemForHost:(NSString*)host
                            username:(NSString*)username
                                port:(UInt16)port
                            protocol:(SecProtocolType)protocol
                  authenticationType:(SecAuthenticationType)authType;

// Returns an array of all keychain items matching the given criteria.
// Pass 0/nil (or kAnyPort for port) to ignore a given field.
+ (NSArray*)allKeychainItemsForHost:(NSString*)host
                               port:(UInt16)port
                           protocol:(SecProtocolType)protocol
                 authenticationType:(SecAuthenticationType)authType
                            creator:(OSType)creator;

// Creates and returns a new keychain item
+ (KeychainItem*)addKeychainItemForHost:(NSString*)host
                                   port:(UInt16)port
                               protocol:(SecProtocolType)protocol
                     authenticationType:(SecAuthenticationType)authType
                           withUsername:(NSString*)username
                               password:(NSString*)password;

- (NSString*)username;
- (NSString*)password;
- (void)setUsername:(NSString*)username password:(NSString*)password;
- (NSString*)host;
- (void)setHost:(NSString*)host;
- (UInt16)port;
- (void)setPort:(UInt16)port;
- (SecProtocolType)protocol;
- (void)setProtocol:(SecProtocolType)protocol;
- (SecAuthenticationType)authenticationType;
- (void)setAuthenticationType:(SecAuthenticationType)authType;
- (OSType)creator;
- (void)setCreator:(OSType)creator;
- (NSString*)comment;
- (void)setComment:(NSString*)comment;
- (NSString*)securityDomain;
- (void)setSecurityDomain:(NSString*)securityDomain;
- (NSString*)label;
- (void)setLabel:(NSString*)label;

// Returns YES if this represents a marker from another browser to prevent
// password saving, rather than actual account info (e.g., Safari's
// "Passwords not saved" items).
- (BOOL)isNonEntry;

- (void)removeFromKeychain;

// Returns the error code for the last action performed on this instance.
// This will not report errors from class methods.
- (OSStatus)lastError;

@end
