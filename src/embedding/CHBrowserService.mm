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
 * Portions created by the Initial Developer are Copyright (C) 1998
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *   Stuart Morgan <stuart.morgan@alumni.case.edu>
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

#import "NSString+Utils.h"

#import "CHBrowserService.h"
#import "CHBrowserView.h"

#include "nsIWindowWatcher.h"
#include "nsIWebBrowserChrome.h"
#include "nsCRT.h"
#include "nsString.h"
#include "nsIGenericFactory.h"
#include "nsIComponentRegistrar.h"
#include "nsICategoryManager.h"
#include "nsEmbedAPI.h"
#include "nsIURI.h"
#include "nsIDownload.h"
#include "nsIDirectoryService.h"
#include "nsDirectoryServiceDefs.h"
#include "nsIExternalHelperAppService.h"
#include "nsIMIMEInfo.h"
#include "nsIPref.h"
#include "nsIObserver.h"
#include "nsIObserverService.h"
#include "GeckoUtils.h"

NSString* const InitEmbeddingNotificationName = @"InitEmebedding";    // this is actually broadcast from MainController
NSString* const TermEmbeddingNotificationName = @"TermEmbedding";
NSString* const XPCOMShutDownNotificationName = @"XPCOMShutDown";

nsAlertController* CHBrowserService::sController = nsnull;
CHBrowserService* CHBrowserService::sSingleton = nsnull;
PRUint32 CHBrowserService::sNumBrowsers = 0;
PRBool CHBrowserService::sCanTerminate = PR_FALSE;
const nsModuleComponentInfo* CHBrowserService::sAppComponents = nsnull;
int CHBrowserService::sAppComponentCount = 0;

#pragma mark Autoregistration observer

class XPCOMAutoregistrationObserver : public nsIObserver
{
public:
  XPCOMAutoregistrationObserver() {}
  virtual ~XPCOMAutoregistrationObserver() {}
  
  NS_DECL_ISUPPORTS
  NS_DECL_NSIOBSERVER
};

NS_IMPL_ISUPPORTS1(XPCOMAutoregistrationObserver, nsIObserver);

NS_IMETHODIMP
XPCOMAutoregistrationObserver::Observe(nsISupports* aSubject, const char* aTopic, const PRUnichar* aSomeData)
{
  if (strcmp(aTopic, "end") == 0)
    CHBrowserService::ReRegisterAppComponents();
  return NS_OK;
}

NS_GENERIC_FACTORY_CONSTRUCTOR(XPCOMAutoregistrationObserver)

// {13de2e6a-5745-4b43-9b63-f62a7b7a6a5d}
#define CH_AUTOREGISTRATIONOBSERVER_CID \
        {0x13de2e6a, 0x5745, 0x4b43, {0x9b, 0x63, 0xf6, 0x2a, 0x7b, 0x7a, 0x6a, 0x5d}}
#define CH_AUTOREGISTRATIONOBSERVER_CONTRACTID \
        "@mozilla.org/chbrowser/auto-registration-listener;1"

static const nsModuleComponentInfo sAutoregistrationListenerComponentInfo = {
  "CHBrowser Autoregistration Listener",
  CH_AUTOREGISTRATIONOBSERVER_CID,
  CH_AUTOREGISTRATIONOBSERVER_CONTRACTID,
  XPCOMAutoregistrationObserverConstructor
};

#pragma mark -
#pragma mark CHBrowserService implementation

CHBrowserService::CHBrowserService()
{
}

CHBrowserService::~CHBrowserService()
{
}

NS_IMPL_ISUPPORTS3(CHBrowserService,
                   nsIWindowCreator,
                   nsIFactory, 
                   nsIHelperAppLauncherDialog)

/* static */
nsresult
CHBrowserService::InitEmbedding()
{
  sNumBrowsers++;
  
  if (sSingleton)
    return NS_OK;

  sSingleton = new CHBrowserService();
  if (!sSingleton)
    return NS_ERROR_OUT_OF_MEMORY;
  NS_ADDREF(sSingleton);
  
  nsCOMPtr<nsIComponentRegistrar> cr;
  NS_GetComponentRegistrar(getter_AddRefs(cr));
  if ( !cr )
    return NS_ERROR_FAILURE;

  // Register as the window creator
  nsCOMPtr<nsIWindowWatcher> watcher(do_GetService("@mozilla.org/embedcomp/window-watcher;1"));
  if (!watcher) 
    return NS_ERROR_FAILURE;
  watcher->SetWindowCreator(sSingleton);

  // replace the external helper app dialog with our own
  #define NS_HELPERAPPLAUNCHERDIALOG_CID \
          {0xf68578eb, 0x6ec2, 0x4169, {0xae, 0x19, 0x8c, 0x62, 0x43, 0xf0, 0xab, 0xe1}}
  static NS_DEFINE_CID(kHelperDlgCID, NS_HELPERAPPLAUNCHERDIALOG_CID);
  nsresult rv = cr->RegisterFactory(kHelperDlgCID, NS_IHELPERAPPLAUNCHERDLG_CLASSNAME, NS_IHELPERAPPLAUNCHERDLG_CONTRACTID,
                            sSingleton);
  if (NS_FAILED(rv))
    return rv;

  return NS_OK;
}

/* static */
void
CHBrowserService::BrowserClosed()
{
  sNumBrowsers--;
  if (sCanTerminate && sNumBrowsers == 0) {
    // The app is terminating *and* our count dropped to 0.
    ShutDown();
  }
}

/* static */
void
CHBrowserService::TermEmbedding()
{
  // phase 1 notification (we're trying to terminate)
  [[NSNotificationCenter defaultCenter] postNotificationName:TermEmbeddingNotificationName object:nil];

  sCanTerminate = PR_TRUE;
  if (sNumBrowsers == 0) {
    ShutDown();
  }
  else {
#if DEBUG
  	NSLog(@"Cannot yet shut down embedding.");
#endif
    // Otherwise we cannot yet terminate.  We have to let the death of the browser views
    // induce termination.
  }
}

/* static */
void CHBrowserService::ShutDown()
{
  NS_ASSERTION(sCanTerminate, "Should be able to terminate here!");

  nsCOMPtr<nsIObserverService> observerService = do_GetService("@mozilla.org/observer-service;1");
  if (observerService)
    observerService->NotifyObservers(nsnull, "profile-change-net-teardown", nsnull);
  
  // phase 2 notifcation (we really are about to terminate)
  [[NSNotificationCenter defaultCenter] postNotificationName:XPCOMShutDownNotificationName object:nil];

  NS_IF_RELEASE(sSingleton);
  NS_TermEmbedding();
#if DEBUG
  NSLog(@"Shutting down embedding.");
#endif
}

#define NS_ALERT_NIB_NAME "alert"

nsAlertController* 
CHBrowserService::GetAlertController()
{
  if (!sController) {
    sController = [[nsAlertController alloc] init];
  }
  return sController;
}

void
CHBrowserService::SetAlertController(nsAlertController* aController)
{
  // XXX When should the controller be released?
  sController = aController;
  [sController retain];
}

// nsIFactory implementation
NS_IMETHODIMP 
CHBrowserService::CreateInstance(nsISupports *aOuter, 
                                      const nsIID & aIID, 
                                      void **aResult)
{

  NS_ENSURE_ARG_POINTER(aResult);

  /*
  if (aIID.Equals(NS_GET_IID(nsIHelperAppLauncherDialog)))
  {
  }
  */

  return sSingleton->QueryInterface(aIID, aResult);
}

NS_IMETHODIMP 
CHBrowserService::LockFactory(PRBool lock)
{
  return NS_OK;
}


// Implementation of nsIWindowCreator
/* nsIWebBrowserChrome createChromeWindow (in nsIWebBrowserChrome parent, in PRUint32 chromeFlags); */
NS_IMETHODIMP 
CHBrowserService::CreateChromeWindow(nsIWebBrowserChrome *parent, 
                                          PRUint32 chromeFlags, 
                                          nsIWebBrowserChrome **_retval)
{
  if (!parent) {
#if DEBUG
    NSLog(@"Attempt to create a new browser window with a null parent.  Should not happen in Chimera.");
#endif
    return NS_ERROR_FAILURE;
  }
  
  // Push a null JSContext on the JS stack, before we create the chrome window.
  // Otherwise, a webpage invoking some JS to do window.open() will be last on the JS stack.
  // And once we start fixing up our newly created chrome window (to hide the scrollbar,
  // for example) Gecko will think it's the *webpage*, and webpages are not allowed
  // to do that.  see bug 324907.
  nsresult rv = NS_OK;
  StNullJSContextScope hack(&rv);
  NS_ENSURE_SUCCESS(rv, rv);
  
  nsCOMPtr<nsIWindowCreator> browserChrome(do_QueryInterface(parent));
  return browserChrome->CreateChromeWindow(parent, chromeFlags, _retval);
}


//    void show( in nsIHelperAppLauncher aLauncher, in nsISupports aContext, in unsigned long aReason );
NS_IMETHODIMP
CHBrowserService::Show(nsIHelperAppLauncher* inLauncher, nsISupports* inContext, PRUint32 aReason)
{
  PRBool autoDownload = PR_FALSE;
  
  // See if pref enabled to allow automatic download
  nsCOMPtr<nsIPref> prefService (do_GetService(NS_PREF_CONTRACTID));
  if (prefService)
    prefService->GetBoolPref("browser.download.autoDownload", &autoDownload);
  
  nsCOMPtr<nsIFile> downloadFile;
  if (autoDownload)
  {
    NS_GetSpecialDirectory(NS_MAC_DEFAULT_DOWNLOAD_DIR, getter_AddRefs(downloadFile));
    
    nsAutoString leafName;
    inLauncher->GetSuggestedFileName(leafName);
    if (leafName.IsEmpty())
    {
      nsCOMPtr<nsIURI> sourceURI;
      inLauncher->GetSource(getter_AddRefs(sourceURI));
      if (sourceURI)
      {
        // we know this doesn't have a leaf name, because nsExternalAppHandler::SetUpTempFile would have
        // got it already.
        nsCAutoString hostName;
        sourceURI->GetHost(hostName);
        leafName = NS_ConvertUTF8toUTF16(hostName);
        leafName.Append(NS_LITERAL_STRING(" download"));
      }
      else
      {
        leafName.Assign(NS_LITERAL_STRING("Camino download"));
      }
    }

    downloadFile->Append(leafName);
    // this will make an empty file, that persists until the download is done, "holding"
    // a file system location for the final file. Note that if you change this, be
    // sure to fix nsDownloadListener::DownloadDone not to delete some random file.
    downloadFile->CreateUnique(nsIFile::NORMAL_FILE_TYPE, 0600);
  }  
  
  return inLauncher->SaveToDisk(downloadFile, PR_FALSE);
}

NS_IMETHODIMP
CHBrowserService::PromptForSaveToFile(nsIHelperAppLauncher* aLauncher, nsISupports *aWindowContext, const PRUnichar *aDefaultFile, const PRUnichar *aSuggestedFileExtension, nsILocalFile **_retval)
{
  NSString* filename = [NSString stringWithPRUnichars:aDefaultFile];
  NSSavePanel *thePanel = [NSSavePanel savePanel];
  
  // Note: although the docs for NSSavePanel specifically state "path and filename can be empty strings, but
  // cannot be nil" if you want the last used directory to persist between calls to display the save panel
  // use nil for the path given to runModalForDirectory
  int runResult = [thePanel runModalForDirectory: nil file:filename];
  if (runResult == NSOKButton) {
    // NSLog(@"Saving to %@", [thePanel filename]);
    NSString *theName = [thePanel filename];
    return NS_NewNativeLocalFile(nsDependentCString([theName fileSystemRepresentation]), PR_FALSE, _retval);
  }

  return NS_ERROR_FAILURE;
}


//
// RegisterAppComponents
//
// Register application-provided Gecko components.
//
void
CHBrowserService::RegisterAppComponents(const nsModuleComponentInfo* inComponents, const int inNumComponents)
{
  nsCOMPtr<nsIComponentRegistrar> cr;
  NS_GetComponentRegistrar(getter_AddRefs(cr));
  if ( !cr )
    return;

  for (int i = 0; i < inNumComponents; ++i) {
    nsCOMPtr<nsIGenericFactory> componentFactory;
    nsresult rv = NS_NewGenericFactory(getter_AddRefs(componentFactory), &(inComponents[i]));
    if (NS_FAILED(rv)) {
      NS_ASSERTION(PR_FALSE, "Unable to create factory for component");
      continue;
    }

    rv = cr->RegisterFactory(inComponents[i].mCID,
                             inComponents[i].mDescription,
                             inComponents[i].mContractID,
                             componentFactory);
    NS_ASSERTION(NS_SUCCEEDED(rv), "Unable to register factory for component");
  }
  
  // The first time through, store the arguments and set up a listener that will
  // re-run registration after any later autoregistration (since overrides may
  // be lost during autoregistration).
  if (!sAppComponents) {
    // No need to copy this, since the component info must be valid for the
    // lifetime of the components they describe anyway.
    sAppComponents = inComponents;
    sAppComponentCount = inNumComponents;
    SetUpAutoregistrationListener();
  }
}

void
CHBrowserService::ReRegisterAppComponents() {
  RegisterAppComponents(sAppComponents, sAppComponentCount);
}

void
CHBrowserService::SetUpAutoregistrationListener() {
  nsCOMPtr<nsIComponentRegistrar> cr;
  NS_GetComponentRegistrar(getter_AddRefs(cr));
  if (!cr)
    return;
  
  // Register the component.
  nsCOMPtr<nsIGenericFactory> componentFactory;
  nsresult rv = NS_NewGenericFactory(getter_AddRefs(componentFactory),
                                     &sAutoregistrationListenerComponentInfo);
  if (NS_FAILED(rv)) {
    NS_ASSERTION(PR_FALSE, "Unable to create factory for autoregistration listener");
    return;
  }
  rv = cr->RegisterFactory(sAutoregistrationListenerComponentInfo.mCID,
                           sAutoregistrationListenerComponentInfo.mDescription,
                           sAutoregistrationListenerComponentInfo.mContractID,
                           componentFactory);
  if (NS_FAILED(rv)) {
    NS_ASSERTION(PR_FALSE, "Unable to register factory for autoregistration listener");
    return;
  }
    
  // Set it to listen for XPCOM autoregistration.
  nsCOMPtr<nsICategoryManager> cm = do_GetService(NS_CATEGORYMANAGER_CONTRACTID);
  if (cm) {
    rv = cm->AddCategoryEntry("xpcom-autoregistration",
                              "CHBrowserService Autoregistration Listener",
                              CH_AUTOREGISTRATIONOBSERVER_CONTRACTID,
                              PR_TRUE, PR_TRUE, NULL);
    NS_ASSERTION(NS_SUCCEEDED(rv), "Unable to register factory for notifications");
  }
}

