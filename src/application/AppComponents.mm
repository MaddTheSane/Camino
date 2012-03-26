/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>

#import "CertErrorAboutModule.h"
#import "CHStringBundleOverride.h"
#import "PluginBlocklistService.h"
#import "CocoaPromptService.h"
#import "ContentDispatchChooser.h"
#import "KeychainService.h"
#import "nsAboutBookmarks.h"
#import "nsDownloadListener.h"
#import "ProgressDlgController.h"
#import "SafeBrowsingAboutModule.h"
#import "SecurityDialogs.h"


#include "nsIGenericFactory.h"

// {0ffd3880-7a1a-11d6-a384-975d1d5f86fc}
#define NS_SECURITYDIALOGS_CID \
  {0x0ffd3880, 0x7a1a, 0x11d6,{0xa3, 0x84, 0x97, 0x5d, 0x1d, 0x5f, 0x86, 0xfc}}

#define NS_PROMPTSERVICE_CID \
  {0xa2112d6a, 0x0e28, 0x421f, {0xb4, 0x6a, 0x25, 0xc0, 0xb3, 0x8, 0xcb, 0xd0}}

#define NS_KEYCHAINPROMPT_CID                    \
    { 0x64997e60, 0x17fe, 0x11d4, {0x8c, 0xee, 0x00, 0x60, 0xb0, 0xfc, 0x14, 0xa3}}

// {CE002B28-92B7-4701-8621-CC925866FB87}
#define NS_COOKIEPROMPTSERVICE_CID \
    {0xCE002B28, 0x92B7, 0x4701, {0x86, 0x21, 0xCC, 0x92, 0x58, 0x66, 0xFB, 0x87}}

// {6316C6CE-12D3-479e-8F53-E289351412B8}
#define NS_STRINGBUNDLETEXTOVERRIDE_CID \
    { 0x6316c6ce, 0x12d3, 0x479e, { 0x8f, 0x53, 0xe2, 0x89, 0x35, 0x14, 0x12, 0xb8 }}

#define NS_STRINGBUNDLETEXTOVERRIDE_CONTRACTID \
    "@mozilla.org/intl/stringbundle/text-override;1"

// {B3C61CFF-9FBC-4153-86FF-BE05D247DD1E}
#define NS_CONTENTDISPATCHCHOOSER_CID \
    {0xB3C61CFF, 0x9FBC, 0x4153, {0x86, 0xFF, 0xBE, 0x05, 0xD2, 0x47, 0xDD, 0x1E}}

#define NS_CONTENTDISPATCHCHOOSER_CONTRACTID \
    "@mozilla.org/content-dispatch-chooser;1"


NS_GENERIC_FACTORY_CONSTRUCTOR(CHStringBundleOverride)
NS_GENERIC_FACTORY_CONSTRUCTOR(CocoaPromptService)
NS_GENERIC_FACTORY_CONSTRUCTOR(ContentDispatchChooser)
NS_GENERIC_FACTORY_CONSTRUCTOR(KeychainPrompt)
NS_GENERIC_FACTORY_CONSTRUCTOR(PluginBlocklistService)
NS_GENERIC_FACTORY_CONSTRUCTOR(SecurityDialogs)

static nsresult
nsDownloadListenerConstructor(nsISupports *aOuter, REFNSIID aIID, void **aResult)
{
  *aResult = NULL;
  if (aOuter)
      return NS_ERROR_NO_AGGREGATION;

  nsDownloadListener* inst;
  NS_NEWXPCOM(inst, nsDownloadListener);
  if (!inst)
      return NS_ERROR_OUT_OF_MEMORY;

  NS_ADDREF(inst);
  inst->SetDisplayFactory([ProgressDlgController sharedDownloadController]);
  nsresult rv = inst->QueryInterface(aIID, aResult);
  NS_RELEASE(inst);
  return rv;
}

// used by MainController to register the components in which we want to override
// with the Gecko embed layer.

static const nsModuleComponentInfo gAppComponents[] = {
  {
    "PSM Security Warnings",
    NS_SECURITYDIALOGS_CID,
    NS_SECURITYWARNINGDIALOGS_CONTRACTID,
    SecurityDialogsConstructor
  },
  {
    "Certificate dialogs",
    NS_SECURITYDIALOGS_CID,
    NS_CERTIFICATEDIALOGS_CONTRACTID,
    SecurityDialogsConstructor
  },
  {
    "Token password dialogs",
    NS_SECURITYDIALOGS_CID,
    NS_TOKENPASSWORDSDIALOG_CONTRACTID,
    SecurityDialogsConstructor
  },
  {
    "Client Auth Dialogs",
    NS_SECURITYDIALOGS_CID,
    NS_CLIENTAUTHDIALOGS_CONTRACTID,
    SecurityDialogsConstructor
  },
  {
    "Token Dialogs",
    NS_SECURITYDIALOGS_CID,
    NS_TOKENDIALOGS_CONTRACTID,
    SecurityDialogsConstructor
  },
  {
    "DOM Crypto Dialogs",
    NS_SECURITYDIALOGS_CID,
    NS_DOMCRYPTODIALOGS_CONTRACTID,
    SecurityDialogsConstructor
  },
  {
    "GenKeyPair Dialogs",
    NS_SECURITYDIALOGS_CID,
    NS_GENERATINGKEYPAIRINFODIALOGS_CONTRACTID,
    SecurityDialogsConstructor
  },
  {
    "Prompt Service",
    NS_PROMPTSERVICE_CID,
    "@mozilla.org/embedcomp/prompt-service;1",
    CocoaPromptServiceConstructor
  },
  {
    "Auth prompt factory",
    NS_PROMPTSERVICE_CID,
    "@mozilla.org/passwordmanager/authpromptfactory;1",
    CocoaPromptServiceConstructor
  },
  {
    "Keychain Prompt",
    NS_KEYCHAINPROMPT_CID,
    "@mozilla.org/wallet/single-sign-on-prompt;1",
    KeychainPromptConstructor
  },
  {
    "Download",
    NS_DOWNLOAD_CID,
    NS_TRANSFER_CONTRACTID,
    nsDownloadListenerConstructor
  },
  {
  	"Cookie Service",
  	NS_COOKIEPROMPTSERVICE_CID,
  	NS_COOKIEPROMPTSERVICE_CONTRACTID,
  	CocoaPromptServiceConstructor
  },
  {
    "About Bookmarks Module",
    NS_ABOUT_BOOKMARKS_MODULE_CID,
    NS_ABOUT_MODULE_CONTRACTID_PREFIX "bookmarks",
    nsAboutBookmarks::CreateBookmarks,
  },
  {
    "About Bookmarks Module",
    NS_ABOUT_BOOKMARKS_MODULE_CID,
    NS_ABOUT_MODULE_CONTRACTID_PREFIX "history",
    nsAboutBookmarks::CreateHistory,
  },
  {
    "String Bundle Override Service",
    NS_STRINGBUNDLETEXTOVERRIDE_CID,
    NS_STRINGBUNDLETEXTOVERRIDE_CONTRACTID,
    CHStringBundleOverrideConstructor
  },
  {
    "Content Dispatcher Service",
    NS_CONTENTDISPATCHCHOOSER_CID,
    NS_CONTENTDISPATCHCHOOSER_CONTRACTID,
    ContentDispatchChooserConstructor
  },
  {
    "Safe Browsing Blocked Module",
    CH_SAFEBROWSING_ABOUT_MODULE_CID,
    NS_ABOUT_MODULE_CONTRACTID_PREFIX "safebrowsingblocked",
    CHSafeBrowsingAboutModule::CreateSafeBrowsingAboutModule,
  },
  {
    "Certificate Error Module",
    CH_CERTERROR_ABOUT_MODULE_CID,
    NS_ABOUT_MODULE_CONTRACTID_PREFIX "certerror",
    CHCertErrorAboutModule::CreateCertErrorAboutModule,
  },
  {
    "Plugin Blocklist Module",
    PLUGIN_BLOCKLIST_SERVICE_CID,
    "@mozilla.org/extensions/blocklist;1",
    PluginBlocklistServiceConstructor
  },
};


const nsModuleComponentInfo* GetAppComponents ( unsigned int * outNumComponents )
{
  *outNumComponents = sizeof(gAppComponents) / sizeof(nsModuleComponentInfo);
  return gAppComponents;
}
