/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#ifndef __CHBrowserService_h__
#define __CHBrowserService_h__

#import "nsAlertController.h"
#include "nsCOMPtr.h"
#include "nsIWindowCreator.h"
#include "nsIHelperAppLauncherDialog.h"
#include "nsIFactory.h"

// Two shutdown notifications exist to allow listeners to guarantee ordering of
// notifications, such that they can save state before xpcom-reliant data structures
// are torn down.
extern NSString* const kInitEmbeddingNotification;   // embedding was initted
extern NSString* const kTermEmbeddingNotification;   // someone called TermEmbedding
extern NSString* const kXPCOMShutDownNotification;   // XPCOM is about to shut down

class nsModuleComponentInfo;

class CHBrowserService :  public nsIWindowCreator,
                          public nsIFactory, 
                          public nsIHelperAppLauncherDialog
{
public:
  CHBrowserService();
  virtual ~CHBrowserService();

  NS_DECL_ISUPPORTS
  NS_DECL_NSIWINDOWCREATOR
  NS_DECL_NSIFACTORY
  NS_DECL_NSIHELPERAPPLAUNCHERDIALOG
  
  static nsresult InitEmbedding();
  static void TermEmbedding();
  static void BrowserClosed();

  // Call to override Gecko components with ones implemented by the
  // embedding application. Some examples are security dialogs, password
  // manager, and Necko prompts. This can be called at any time after
  // XPCOM has been initialized.
  // Note that this should be called only once, as ReRegisterAppComponents
  // will not re-register anything registered in subsequent calls.
  static void RegisterAppComponents(const nsModuleComponentInfo* inComponents,
                                    const int inNumComponents);
  // Repeates the registration done in RegisterAppComponents.
  // Called automatically after autoregistration to ensure that overrides
  // remain in effect.
  static void ReRegisterAppComponents();
 
  // Deprecated.  Use +[nsAlertController sharedController] directly.
  static nsAlertController* GetAlertController();

public:
  static PRUint32 sNumBrowsers;

private:
  static void ShutDown();
  static void SetUpAutoregistrationListener();

  static CHBrowserService* sSingleton;
  static PRBool sCanTerminate;
  static const nsModuleComponentInfo* sAppComponents; // weak
  static int sAppComponentCount;
};


#endif // __CHBrowserService_h__

