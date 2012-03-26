/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <AppKit/AppKit.h>

#import "AddSearchProviderHandler.h"

#import "NSMenu+Utils.h"
#import "NSString+Gecko.h"
#import "SearchEngineManager.h"
#import "XMLSearchPluginParser.h"

#include "nsCOMPtr.h"
#include "nsMemory.h"
#include "nsIClassInfoImpl.h"
#include "nsIComponentRegistrar.h"
#include "nsICategoryManager.h"
#include "nsIGenericFactory.h"
#include "nsIScriptNameSpaceManager.h"
#include "nsIServiceManager.h"

NS_GENERIC_FACTORY_CONSTRUCTOR(AddSearchProviderHandler)

// {5b6f12d6-6b00-4050-bcc2-8f9c76867e7d}
#define ADDSEARCHPROVIDERHANDLER_CID \
{0X5b6f12d6, 0X6b00, 0X4050, {0Xbc, 0Xc2, 0X8f, 0X9c, 0X76, 0X86, 0X7e, 0X7d}}

#define ADDSEARCHPROVIDERHANDLER_CONTRACTID \
"@mozilla.org/camino/addsearchprovider-handler;1"

NS_IMPL_ISUPPORTS1_CI(AddSearchProviderHandler, chIAddSearchProviderHandler)

NS_DECL_CLASSINFO(AddSearchProviderHandler)

static const nsModuleComponentInfo sAddSearchProviderComponentInfo = {
  "AddSearchProviderHandler",
  ADDSEARCHPROVIDERHANDLER_CID,
  ADDSEARCHPROVIDERHANDLER_CONTRACTID,
  AddSearchProviderHandlerConstructor,
  nsnull,
  nsnull,
  nsnull,
  NS_CI_INTERFACE_GETTER_NAME(AddSearchProviderHandler),
  nsnull,
  &NS_CLASSINFO_NAME(AddSearchProviderHandler),
  nsIClassInfo::DOM_OBJECT
};

AddSearchProviderHandler::AddSearchProviderHandler()
{
}

AddSearchProviderHandler::~AddSearchProviderHandler()
{
}

NS_IMETHODIMP AddSearchProviderHandler::AddSearchProvider(const nsAString &aDescriptionURL)
{
  // TODO: find the underlying window to let the dialogs shown by this method be
  // sheets.

  NSString* searchDescriptionURL = [NSString stringWith_nsAString:aDescriptionURL];
  // Make sure we don't throw ObjC exceptions out into Gecko.
  @try {
    SearchEngineManager* searchEngineManager = [SearchEngineManager sharedSearchEngineManager];

    // Make sure the user hasn't already installed this search plugin.
    NSDictionary* existingEngineFromThisPlugin = [searchEngineManager searchEngineFromPluginURL:searchDescriptionURL];
    if (existingEngineFromThisPlugin) {
      NSString* explanatoryText =
        [NSString stringWithFormat:NSLocalizedString(@"SearchPluginAlreadyInstalledMessage", nil),
                                   [existingEngineFromThisPlugin objectForKey:kWebSearchEngineNameKey]];
      NSAlert* alreadyInstalledAlert = [[[NSAlert alloc] init] autorelease];
      [alreadyInstalledAlert addButtonWithTitle:NSLocalizedString(@"OKButtonText", nil)];
      [alreadyInstalledAlert setMessageText:NSLocalizedString(@"SearchPluginAlreadyInstalledTitle", nil)];
      [alreadyInstalledAlert setInformativeText:explanatoryText];
      [alreadyInstalledAlert setAlertStyle:NSWarningAlertStyle];

      [NSMenu cancelAllTracking];
      [alreadyInstalledAlert runModal];
      return NS_OK;
    }

    XMLSearchPluginParser* pluginParser =
      [XMLSearchPluginParser searchPluginParserWithMIMEType:kOpenSearchMIMEType];
    NSError *parsingError;
    if (![pluginParser parseSearchPluginAtURL:[NSURL URLWithString:searchDescriptionURL] error:&parsingError]) {
      NSString* explanatoryText =
        [NSString stringWithFormat:NSLocalizedString(@"SearchPluginInstallationErrorMessage", nil),
                                   NSLocalizedString(@"UnknownSearchPluginName", nil),
                                   [parsingError localizedDescription]];
      NSAlert* parseErrorAlert = [[[NSAlert alloc] init] autorelease];
      [parseErrorAlert addButtonWithTitle:NSLocalizedString(@"OKButtonText", nil)];
      [parseErrorAlert setMessageText:NSLocalizedString(@"SearchPluginInstallationErrorTitle", nil)];
      [parseErrorAlert setInformativeText:explanatoryText];
      [parseErrorAlert setAlertStyle:NSWarningAlertStyle];

      [NSMenu cancelAllTracking];
      [parseErrorAlert runModal];
      return NS_OK;
    }
    NSString* engineName = [pluginParser searchEngineName];
    NSString* engineURL = [pluginParser searchEngineURL];

    // Confirm that the user really wants to add the new engine.
    NSString* explanatoryText =
      [NSString stringWithFormat:NSLocalizedString(@"SearchPluginInstallationConfirmationMessage", nil),
                                 engineName];
    NSAlert* addSearchAlert = [[[NSAlert alloc] init] autorelease];
    [addSearchAlert addButtonWithTitle:NSLocalizedString(@"SearchPluginInstallationConfirmButton", nil)];
    NSButton* cancelButton = [addSearchAlert addButtonWithTitle:NSLocalizedString(@"SearchPluginInstallationCancelButton", nil)];
    [cancelButton setKeyEquivalent:@"\e"];  // Esc
    [addSearchAlert setMessageText:NSLocalizedString(@"SearchPluginInstallationConfirmationTitle", nil)];
    [addSearchAlert setInformativeText:explanatoryText];
    [addSearchAlert setAlertStyle:NSInformationalAlertStyle];

    [NSMenu cancelAllTracking];
    if ([addSearchAlert runModal] != NSAlertFirstButtonReturn)
      return NS_OK;

    // If we got this far, everything checked out, so add the engine.
    [searchEngineManager addSearchEngineWithName:engineName
                                       searchURL:engineURL
                                       pluginURL:searchDescriptionURL];
  }
  @catch (id exception) {
    NSLog(@"Exception caught try to add search engine from '%@': %@",
          searchDescriptionURL, exception);
  }

  return NS_OK;
}

// static
void AddSearchProviderHandler::InstallHandler()
{
  nsCOMPtr<nsIComponentRegistrar> cr;
  nsresult rv = NS_GetComponentRegistrar(getter_AddRefs(cr));
  if (NS_FAILED(rv)) {
    NS_ASSERTION(PR_FALSE, "Unable to get component registrar");
    return;
  }

  // Register with the component manager.
  nsCOMPtr<nsIGenericFactory> componentFactory;
  rv = NS_NewGenericFactory(getter_AddRefs(componentFactory),
                            &sAddSearchProviderComponentInfo);
  if (NS_FAILED(rv)) {
    NS_ASSERTION(PR_FALSE, "Unable to create factory for AddSearchProvider handler");
    return;
  }
  rv = cr->RegisterFactory(sAddSearchProviderComponentInfo.mCID,
                           sAddSearchProviderComponentInfo.mDescription,
                           sAddSearchProviderComponentInfo.mContractID,
                           componentFactory);
  if (NS_FAILED(rv)) {
    NS_ASSERTION(PR_FALSE, "Unable to register factory for AddSearchProvider handler");
    return;
  }

  // Install as the object for JS window.external.
  nsCOMPtr<nsICategoryManager> cm = do_GetService(NS_CATEGORYMANAGER_CONTRACTID);
  if (cm) {
    rv = cm->AddCategoryEntry(JAVASCRIPT_GLOBAL_PROPERTY_CATEGORY,
                              "external",
                              ADDSEARCHPROVIDERHANDLER_CONTRACTID,
                              PR_TRUE, PR_TRUE, NULL);
    NS_ASSERTION(NS_SUCCEEDED(rv), "Unable to register as the window.external handler");
  }
}
