/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#ifndef __GeckoUtils_h__
#define __GeckoUtils_h__

#include "nsServiceManagerUtils.h"
#include "nsString.h"
#include "jsapi.h"
#include "nsIJSContextStack.h"
#include "nsRect.h"

class nsIDOMWindow;
class nsIDOMNode;
class nsIDOMElement;
class nsIDOMDocument;
class nsIURI;
class nsIEditor;


class GeckoUtils
{
  public:

    static void GatherTextUnder(nsIDOMNode* aNode, nsString& aResult);
    static void GetEnclosingLinkElementAndHref(nsIDOMNode* aNode, nsIDOMElement** aLinkContent, nsString& aHref);

    // Gets the URI for the given document, returning PR_TRUE if the location
    // was found.
    static PRBool GetURIForDocument(nsIDOMDocument* aDocument, nsString& aURI);

    // Returns whether or not the given protocol ('http', 'file', 'mailto', etc.)
    // is handled internally. Returns PR_TRUE in error cases.
    static PRBool isProtocolInternal(const char* aProtocol);
    
    // Find out if a URI is safe to load given the referrer URI.
    // An unsafe URI could be a 'file://' or 'chrome://' from a referrer of a different URI scheme.
    // For more info, see http://developer.mozilla.org/en/docs/Safely_loading_URIs
    static PRBool IsSafeToOpenURIFromReferrer(const char* aTargetUri, const char* aReferrerUri);
  
    // Finds the anchor node for the selection in the given editor
    static void GetAnchorNodeFromSelection(nsIEditor* inEditor, nsIDOMNode** outAnchorNode, PRInt32* outAnchorOffset);
    
    /* Finds the preferred size (ie the minimum size where scrollbars are not needed) of the content window. */
    static void GetIntrinsicSize(nsIDOMWindow* aWindow, PRInt32* outWidth, PRInt32* outHeight);

    // Finds the screen location (nsIntRect) in screen coordinates of a DOM Element.
    // Returns PR_FALSE if the function fails.
    static PRBool GetFrameInScreenCoordinates(nsIDOMElement* aElement, nsIntRect* aRect);

    // Given a DOM Element, scroll the view so that the element is shown
    static void ScrollElementIntoView(nsIDOMElement* aElement);

    // Returns whether or not a string contains the specified word. True if the string
    // starts with "word ", ends with " word", contains " word ", or consists entirely of "word".
    static PRBool StringContainsWord(nsAString& aString, const char* aWord, PRBool caseInsensitive);
};

/* Stack-based utility that will push a null JSContext onto the JS stack during the
   length of its lifetime.

   For example, this is needed when some unprivileged JS code executes from a webpage. 
   If we try to call into Gecko then, the current JSContext will be the webpage, and so 
   Gecko might deny *us* the right to do something. For this reason we push a null JSContext, 
   to make sure that whatever we want to do will be allowed. 
*/
class StNullJSContextScope {
public:
  StNullJSContextScope(nsresult *rv) {
    mStack = do_GetService("@mozilla.org/js/xpc/ContextStack;1", rv);
    if (NS_SUCCEEDED(*rv) && mStack)
      *rv = mStack->Push(nsnull);
  }
  
  ~StNullJSContextScope() {
    if (mStack) {
      JSContext *ctx;
      mStack->Pop(&ctx);
      NS_ASSERTION(!ctx, "Popped JSContext not null!");
    }
  }
  
private:
  nsCOMPtr<nsIJSContextStack> mStack;
};
    
#endif
