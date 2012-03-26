/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */


#include "nsCOMPtr.h"

#include "nsEmbedAPI.h"
#include "nsString.h"
#include "nsUnicharUtils.h"

#include "nsIDOMElement.h"
#include "nsIDOMMouseEvent.h"
#include "nsIDOMEventTarget.h"

// Common helper routines (also used by the context menu code)
#include "GeckoUtils.h"

#import "NSString+Gecko.h"

#import "ContentClickListener.h"
#import "PreferenceManager.h"
#import "CHBrowserView.h"
#import "BrowserWindowController.h"

NS_IMPL_ISUPPORTS2(ContentClickListener, nsIDOMMouseListener, nsIDOMEventListener)

ContentClickListener::ContentClickListener(id aBrowserController)
:mBrowserController(aBrowserController)
{
}

ContentClickListener::~ContentClickListener()
{

}

NS_IMETHODIMP
ContentClickListener::MouseClick(nsIDOMEvent* aEvent)
{
  nsCOMPtr<nsIDOMEventTarget> target;
  aEvent->GetTarget(getter_AddRefs(target));
  if (!target)
    return NS_OK;
  nsCOMPtr<nsIDOMNode> content(do_QueryInterface(target));

  nsCOMPtr<nsIDOMElement> linkContent;
  nsAutoString href;
  GeckoUtils::GetEnclosingLinkElementAndHref(content, getter_AddRefs(linkContent), href);
  
  // XXXdwh Handle simple XLINKs if we want to be compatible with Mozilla, but who
  // really uses these anyway? :)
  if (!linkContent || href.IsEmpty())
    return NS_OK;
    
  PRUint16 button;
  nsCOMPtr<nsIDOMMouseEvent> mouseEvent(do_QueryInterface(aEvent));
  mouseEvent->GetButton(&button);

  PRBool metaKey, shiftKey, altKey;
  mouseEvent->GetMetaKey(&metaKey);
  mouseEvent->GetShiftKey(&shiftKey);
  mouseEvent->GetAltKey(&altKey);

  NSString* hrefStr = [NSString stringWith_nsAString:href];

  if ((metaKey && button == 0) || button == 1) {
    NSString* referrer = [[[mBrowserController browserWrapper] browserView] focusedURLString];

    NSRange firstColon = [hrefStr rangeOfString:@":"];
    NSString* hrefScheme;
    if (firstColon.location != NSNotFound)
      hrefScheme = [hrefStr substringToIndex:firstColon.location];
    else
      hrefScheme = @"file"; // implicitly file:// if no colon is found

    if (!GeckoUtils::IsSafeToOpenURIFromReferrer([hrefStr UTF8String], [referrer UTF8String]))
      return NS_OK;

    // The Command key is down or we got a middle-click.
    // Open the link in a new window or tab if it's an internally handled, non-Javascript link.
    if (![hrefScheme isEqualToString:@"javascript"] && GeckoUtils::isProtocolInternal([hrefScheme UTF8String])) {
      BOOL useTab           = [[PreferenceManager sharedInstance] getBooleanPref:kGeckoPrefOpenTabsForMiddleClick
                                                                     withSuccess:NULL];
      BOOL loadInBackground = [BrowserWindowController shouldLoadInBackgroundForDestination:(useTab ? eDestinationNewTab
                                                                                                    : eDestinationNewWindow)
                                                                                     sender:nil];

      if (useTab)
        [mBrowserController openNewTabWithURL:hrefStr referrer:referrer loadInBackground:loadInBackground allowPopups:NO setJumpback:YES];
      else
        [mBrowserController openNewWindowWithURL:hrefStr referrer:referrer loadInBackground:loadInBackground allowPopups:NO];
    }
    else { // It's an external protocol or a "javascript:" URL, so just open the link.
      [mBrowserController loadURL:hrefStr referrer:referrer focusContent:YES allowPopups:NO];
    }
  }
  else if (altKey) {
    // The user wants to save this link.
    nsAutoString text;
    GeckoUtils::GatherTextUnder(content, text);

    [mBrowserController saveURL:nil url:hrefStr suggestedFilename:[NSString stringWith_nsAString:text]];
  }

  return NS_OK;
}
