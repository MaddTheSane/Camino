/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#ifndef __KeychainService_h__
#define __KeychainService_h__

#import <Cocoa/Cocoa.h>

#import "CHBrowserView.h"

#include "nsEmbedAPI.h"
#include "nsIFactory.h"
#include "nsIPrompt.h"
#include "nsIAuthPromptWrapper.h"
#include "nsIObserver.h"
#include "nsIFormSubmitObserver.h"
#include "nsIDOMHTMLFormElement.h"
#include "nsIDOMHTMLInputElement.h"

enum KeychainPromptResult { kSave, kDontRemember, kNeverRemember } ;

@class CHBrowserView;
@class KeychainItem;

nsresult FindUsernamePasswordFields(nsIDOMHTMLFormElement* inFormElement,
                                    nsIDOMHTMLInputElement** outUsername,
                                    nsIDOMHTMLInputElement** outPassword,
                                    PRBool inStopWhenFound);

@interface KeychainService : NSObject
{
  IBOutlet id mConfirmFillPasswordPanel;

  BOOL mFormPasswordFillIsEnabled;

  NSMutableDictionary* mAllowedActionHosts;  // strong

  NSMutableDictionary* mCachedKeychainItems; // strong
  NSMutableDictionary* mKeychainCacheTimers; // strong

  nsIObserver* mFormSubmitObserver;
}

+ (KeychainService*)instance;
- (void)shutdown:(id)sender;

- (IBAction)hitButtonOK:(id)sender;
- (IBAction)hitButtonCancel:(id)sender;
- (IBAction)hitButtonOther:(id)sender;

- (void)promptToStoreLogin:(NSDictionary*)loginInfo inWindow:(NSWindow*)window;
- (void)promptToUpdateKeychainItem:(KeychainItem*)keychainItem
                      withUsername:(NSString*)username
                          password:(NSString*)password
                          inWindow:(NSWindow*)window;
- (BOOL)confirmFillPassword:(NSWindow*)parent;

- (KeychainItem*)findWebFormKeychainEntryForUsername:(NSString*)username
                                             forHost:(NSString*)host
                                                port:(UInt16)port
                                              scheme:(NSString*)scheme;
- (KeychainItem*)findDefaultWebFormKeychainEntryForHost:(NSString*)host
                                                   port:(UInt16)port
                                                 scheme:(NSString*)scheme;
- (void)setDefaultWebFormKeychainEntry:(KeychainItem*)keychainItem;

- (NSArray*)allWebFormKeychainItemsForHost:(NSString*)host
                                      port:(UInt16)port
                                    scheme:(NSString*)scheme;
- (KeychainItem*)defaultFromKeychainItems:(NSArray*)items;

- (KeychainItem*)findAuthKeychainEntryForHost:(NSString*)host
                                         port:(UInt16)port
                                       scheme:(NSString*)scheme
                               securityDomain:(NSString*)securityDomain;
- (KeychainItem*)updateAuthKeychainEntry:(KeychainItem*)keychainItem
                            withUsername:(NSString*)username
                                password:(NSString*)password;
- (KeychainItem*)storeUsername:(NSString*)username
                      password:(NSString*)password
                       forHost:(NSString*)host
                securityDomain:(NSString*)securityDomain
                          port:(UInt16)port
                        scheme:(NSString*)scheme
                        isForm:(BOOL)isForm;

- (void)removeAllUsernamesAndPasswords;

- (BOOL)formPasswordFillIsEnabled;

// Methods to interact with the list of hosts we shouldn't ask about.
- (void)addHostToDenyList:(NSString*)host;
- (BOOL)isHostInDenyList:(NSString*)host;

// Methods to interact with the list of approved form action hosts.
- (void)setAllowedActionHosts:(NSArray*)actionHosts forHost:(NSString*)host;
- (NSArray*)allowedActionHostsForHost:(NSString*)host;

// Methods to interact with the temporary keychain item cache.
- (KeychainItem*)cachedKeychainEntryForKey:(NSString*)key;
- (void)cacheKeychainEntry:(KeychainItem*)keychainItem forKey:(NSString*)key;
- (void)expirationTimerFired:(NSTimer*)theTimer;

@end


class KeychainPrompt : public nsIAuthPromptWrapper
{
public:
  KeychainPrompt();
  virtual ~KeychainPrompt();

  NS_DECL_ISUPPORTS
  NS_DECL_NSIAUTHPROMPT
  NS_DECL_NSIAUTHPROMPTWRAPPER
  
protected:
  
  void PreFill(const PRUnichar *, PRUnichar **, PRUnichar **);
  void ProcessPrompt(const PRUnichar *, bool, PRUnichar *, PRUnichar *);
  static void ExtractRealmComponents(NSString* inRealmBlob, NSString** outHost, NSString** outRealm, UInt16* outPort);

  nsCOMPtr<nsIPrompt>   mPrompt;
};

//
// Keychain form submit observer
//
class KeychainFormSubmitObserver : public nsIObserver,
                                   public nsIFormSubmitObserver
{
public:
  KeychainFormSubmitObserver();
  virtual ~KeychainFormSubmitObserver();

  NS_DECL_ISUPPORTS
  NS_DECL_NSIOBSERVER

  // NS_DECL_NSIFORMSUBMITOBSERVER
  NS_IMETHOD Notify(nsIDOMHTMLFormElement* formNode, nsIDOMWindowInternal* window, nsIURI* actionURL, PRBool* cancelSubmit);
};

//
// Keychain browser listener to auto fill username/passwords.
//
@interface KeychainBrowserListener : NSObject<CHBrowserListener>
{
  CHBrowserView* mBrowserView;
}

- (id)initWithBrowser:(CHBrowserView*)aBrowser;

@end

#endif
