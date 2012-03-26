/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
* License, v. 2.0. If a copy of the MPL was not distributed with this
* file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Foundation/Foundation.h>

#import "ContentDispatchChooser.h"

#import "CHBrowserService.h"
#import "CHBrowserView.h"
#import "NSString+Gecko.h"
#include "nsIDOMWindow.h"
#include "nsIHandlerService.h"
#include "nsIInterfaceRequestor.h"
#include "nsIInterfaceRequestorUtils.h"
#include "nsIMIMEInfo.h"
#include "nsIServiceManager.h"
#include "nsIURI.h"
#include "nsString.h"

static const char* handlerServiceContractID = "@mozilla.org/uriloader/handler-service;1";

NS_IMPL_ISUPPORTS1(ContentDispatchChooser, nsIContentDispatchChooser);

ContentDispatchChooser::ContentDispatchChooser()
{
}

ContentDispatchChooser::~ContentDispatchChooser()
{
}

NS_IMETHODIMP ContentDispatchChooser::Ask(nsIHandlerInfo *aHandler,
                                          nsIInterfaceRequestor *aWindowContext,
                                          nsIURI *aURI,
                                          PRUint32 aReason)
{
  // TODO: ideally we'd like a non-modal version of nsAlertController's sheets
  // for this case (we want to use nsAlertController for visual consistency).
  nsAlertController* controller = [[[nsAlertController alloc] init] autorelease];

  NSWindow* parentWindow = nil;
  nsCOMPtr<nsIDOMWindow> domWindow(do_GetInterface(aWindowContext));
  if (domWindow) {
    CHBrowserView* browserView = [CHBrowserView browserViewFromDOMWindow:domWindow];
    parentWindow = [browserView nativeWindow];
  }

  nsCAutoString scheme;
  aURI->GetScheme(scheme);
  NSString* linkType = [NSString stringWith_nsACString:scheme];

  PRBool hasDefault = PR_FALSE;
  aHandler->GetHasDefaultHandler(&hasDefault);
  if (hasDefault) {
    nsAutoString defaultDesc;
    nsresult rv = aHandler->GetDefaultDescription(defaultDesc);
    NSString* handlerName = nil;
    if (NS_SUCCEEDED(rv))
      handlerName = [NSString stringWith_nsAString:defaultDesc];
    else
      handlerName = NSLocalizedString(@"UnknownContentHandler", nil);

    NSString* openButton = [NSString stringWithFormat:NSLocalizedString(@"OpenExternalHandlerOpenButon", nil),
                                                      handlerName];
    NSString* cancelButton = NSLocalizedString(@"OpenExternalHandlerCancelButton", nil);
    NSString* title = [NSString stringWithFormat:NSLocalizedString(@"OpenExternalHandlerTitle", nil),
                                                 handlerName];
    NSString* text = [NSString stringWithFormat:NSLocalizedString(@"OpenExternalHandlerText", nil),
                                                linkType, handlerName];
    NSString* checkboxText = [NSString stringWithFormat:NSLocalizedString(@"OpenExternalHandlerRemember", nil),
                                                        linkType];
    BOOL dontAskAgain = NO;
    int choice = [controller confirmCheckEx:parentWindow
                                      title:title
                                       text:text
                                    button1:openButton
                                    button2:cancelButton
                                    button3:nil
                                   checkMsg:checkboxText
                                 checkValue:&dontAskAgain];

    if (choice == NSAlertDefaultReturn) {
      if (dontAskAgain) {
        aHandler->SetPreferredAction(nsIHandlerInfo::useSystemDefault);
        aHandler->SetAlwaysAskBeforeHandling(PR_FALSE);
        nsCOMPtr<nsIHandlerService> handlerService(do_GetService(handlerServiceContractID));
        if (handlerService)
          handlerService->Store(aHandler);
      }

      aHandler->LaunchWithURI(aURI, aWindowContext);
    }
  }
  else {
    [controller alert:parentWindow
                title:NSLocalizedString(@"NoExternalHandlerTitle", nil)
                 text:[NSString stringWithFormat:NSLocalizedString(@"NoExternalHandlerText", nil),
                                                 linkType]];
  }
  return NS_OK;
}

