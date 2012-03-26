/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#ifndef __nsCocoaBrowserListener_h__
#define __nsCocoaBrowserListener_h__

#include "nsWeakReference.h"
#include "nsIInterfaceRequestor.h"
#include "nsIWebBrowser.h"
#include "nsIWebBrowserChrome.h"
#include "nsIWebProgressListener2.h"
#include "nsIEmbeddingSiteWindow2.h"
#include "nsIWindowCreator.h"
#include "nsIWindowProvider.h"
#include "nsIDOMEventListener.h"
#include "nsIWebBrowserChromeFocus.h"

#include "nsIContextMenuListener.h"
#include "nsITooltipListener.h"

@class CHBrowserView;

typedef enum 
{
  eFeedType,
  eFavIconType,
  eSearchPluginType,
  eOtherType
} ELinkAttributeType;

class CHBrowserListener : public nsSupportsWeakReference,
                               public nsIInterfaceRequestor,
                               public nsIWebBrowserChrome,
                               public nsIWindowCreator,
                               public nsIWindowProvider,
                               public nsIEmbeddingSiteWindow2,
                               public nsIWebProgressListener2,
                               public nsIContextMenuListener,
                               public nsIDOMEventListener,
                               public nsITooltipListener,
                               public nsIWebBrowserChromeFocus
{
public:
  CHBrowserListener(CHBrowserView* aView);
  virtual ~CHBrowserListener();

  NS_DECL_ISUPPORTS
  NS_DECL_NSIINTERFACEREQUESTOR
  NS_DECL_NSIWEBBROWSERCHROME
  NS_DECL_NSIWINDOWCREATOR
  NS_DECL_NSIWINDOWPROVIDER
  NS_DECL_NSIEMBEDDINGSITEWINDOW
  NS_DECL_NSIEMBEDDINGSITEWINDOW2
  NS_DECL_NSIWEBPROGRESSLISTENER
  NS_DECL_NSIWEBPROGRESSLISTENER2
  NS_DECL_NSICONTEXTMENULISTENER
  NS_DECL_NSITOOLTIPLISTENER
  NS_DECL_NSIDOMEVENTLISTENER
  NS_DECL_NSIWEBBROWSERCHROMEFOCUS
    
  void AddListener(id <CHBrowserListener> aListener);
  void RemoveListener(id <CHBrowserListener> aListener);

  void SetContainer(NSView<CHBrowserListener, CHBrowserContainer>* aContainer);

protected:
  nsresult HandleXULPopupEvent(nsIDOMEvent* inEvent);
  nsresult HandleBlockedPopupEvent(nsIDOMEvent* inEvent);
  nsresult HandleLinkAddedEvent(nsIDOMEvent* inEvent);
  nsresult HandleFlashblockCheckEvent(nsIDOMEvent* inEvent);
  nsresult HandleSilverblockCheckEvent(nsIDOMEvent* inEvent);
  void HandleFaviconLink(nsIDOMElement* inElement);
  void HandleFeedLink(nsIDOMElement* inElement);
  void HandleSearchPluginLink(nsIDOMElement* inElement);
  ELinkAttributeType GetLinkAttributeType(nsIDOMElement* inElement); 
  nsresult HandleXULCommandEvent(nsIDOMEvent* inEvent);
  nsresult HandleGestureEvent(nsIDOMEvent* inEvent);

private:
  CHBrowserView*          mView;     // WEAK - it owns us
  NSMutableArray*         mListeners;
  NSView<CHBrowserListener, CHBrowserContainer>* mContainer;
  PRBool                  mIsModal;
  PRUint32                mChromeFlags;
};


#endif // __nsCocoaBrowserListener_h__
