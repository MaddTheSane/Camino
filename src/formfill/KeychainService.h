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

- (void)addListenerToView:(CHBrowserView*)view;

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
