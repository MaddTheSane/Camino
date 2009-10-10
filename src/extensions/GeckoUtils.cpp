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
 * Portions created by the Initial Developer are Copyright (C) 2006
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s): Håkan Waara (hwaara@gmail.com)
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


#include "GeckoUtils.h"

#include "nsIDOMHTMLAnchorElement.h"
#include "nsIDOMHTMLAreaElement.h"
#include "nsIDOMHTMLLinkElement.h"
#include "nsIDOMHTMLImageElement.h"
#include "nsIDOMCharacterData.h"
#include "nsUnicharUtils.h"

#include "nsIDocShell.h"
#include "nsIWebNavigation.h"
#include "nsIURI.h"
#include "nsISimpleEnumerator.h"
#include "nsString.h"
#include "nsCOMPtr.h"
#include "nsIIOService.h"
#include "nsIProtocolHandler.h"
#include "nsIServiceManager.h"
#include "nsIExternalProtocolHandler.h"
#include "nsIScriptSecurityManager.h"
#include "nsNetUtil.h"

#include "nsIEditor.h"
#include "nsISelection.h"

#include "nsIDocShell.h"
#include "nsIDocShellTreeItem.h"
#include "nsIPresShell.h"
#include "nsIContent.h"
#include "nsIFrame.h"

#include "nsIDocument.h"
#include "nsIDOMDocument.h"
#include "nsIDOMLocation.h"
#include "nsIDOMWindowInternal.h"
#include "nsIDOMNSDocument.h"
#include "nsIDOMNSHTMLElement.h"

/* static */
void GeckoUtils::GatherTextUnder(nsIDOMNode* aNode, nsString& aResult) 
{
  nsAutoString text;
  nsCOMPtr<nsIDOMNode> node;
  aNode->GetFirstChild(getter_AddRefs(node));
  PRUint32 depth = 1;
  while (node && depth) {
    nsCOMPtr<nsIDOMCharacterData> charData(do_QueryInterface(node));
    PRUint16 nodeType;
    node->GetNodeType(&nodeType);
    if (charData && nodeType == nsIDOMNode::TEXT_NODE) {
      // Add this text to our collection.
      text += NS_LITERAL_STRING(" ");
      nsAutoString data;
      charData->GetData(data);
      text += data;
    }
    else {
      nsCOMPtr<nsIDOMHTMLImageElement> img(do_QueryInterface(node));
      if (img) {
        nsAutoString altText;
        img->GetAlt(altText);
        if (!altText.IsEmpty()) {
          text = altText;
          break;
        }
      }
    }
    
    // Find the next node to test.
    PRBool hasChildNodes;
    node->HasChildNodes(&hasChildNodes);
    if (hasChildNodes) {
      nsCOMPtr<nsIDOMNode> temp = node;
      temp->GetFirstChild(getter_AddRefs(node));
      depth++;
    }
    else {
      nsCOMPtr<nsIDOMNode> nextSibling;
      node->GetNextSibling(getter_AddRefs(nextSibling));
      if (nextSibling)
        node = nextSibling;
      else {
        nsCOMPtr<nsIDOMNode> parentNode;
        node->GetParentNode(getter_AddRefs(parentNode));
        if (!parentNode)
          node = nsnull;
        else {
          nsCOMPtr<nsIDOMNode> nextSibling2;
          parentNode->GetNextSibling(getter_AddRefs(nextSibling2));
          node = nextSibling2;
          depth--;
        }
      }
    }
  }
  
  text.CompressWhitespace();
  aResult = text;
}

/* static */
void GeckoUtils::GetEnclosingLinkElementAndHref(nsIDOMNode* aNode, nsIDOMElement** aLinkContent, nsString& aHref)
{
  nsCOMPtr<nsIDOMElement> content(do_QueryInterface(aNode));
  nsAutoString localName;
  if (content)
    content->GetLocalName(localName);
  
  nsCOMPtr<nsIDOMElement> linkContent;
  ToLowerCase(localName);
  nsAutoString href;
  if (localName.Equals(NS_LITERAL_STRING("a")) ||
      localName.Equals(NS_LITERAL_STRING("area")) ||
      localName.Equals(NS_LITERAL_STRING("link"))) {
    PRBool hasAttr;
    content->HasAttribute(NS_LITERAL_STRING("href"), &hasAttr);
    if (hasAttr) {
      linkContent = content;
      nsCOMPtr<nsIDOMHTMLAnchorElement> anchor(do_QueryInterface(linkContent));
      if (anchor)
        anchor->GetHref(href);
      else {
        nsCOMPtr<nsIDOMHTMLAreaElement> area(do_QueryInterface(linkContent));
        if (area)
          area->GetHref(href);
        else {
          nsCOMPtr<nsIDOMHTMLLinkElement> link(do_QueryInterface(linkContent));
          if (link)
            link->GetHref(href);
        }
      }
    }
  }
  else {
    nsCOMPtr<nsIDOMNode> curr = aNode;
    nsCOMPtr<nsIDOMNode> temp = curr;
    temp->GetParentNode(getter_AddRefs(curr));
    while (curr) {
      content = do_QueryInterface(curr);
      if (!content)
        break;
      content->GetLocalName(localName);
      ToLowerCase(localName);
      if (localName.Equals(NS_LITERAL_STRING("a"))) {
        PRBool hasAttr;
        content->HasAttribute(NS_LITERAL_STRING("href"), &hasAttr);
        if (hasAttr) {
          linkContent = content;
          nsCOMPtr<nsIDOMHTMLAnchorElement> anchor(do_QueryInterface(linkContent));
          if (anchor)
            anchor->GetHref(href);
        }
        else
          linkContent = nsnull; // Links can't be nested.
        break;
      }
      
      temp = curr;
      temp->GetParentNode(getter_AddRefs(curr));
    }
  }
  
  *aLinkContent = linkContent;
  NS_IF_ADDREF(*aLinkContent);
  
  aHref = href;
}

PRBool GeckoUtils::GetURIForDocument(nsIDOMDocument* aDocument, nsString& aURI)
{
  if (!aDocument)
    return PR_FALSE;
  nsCOMPtr<nsIDOMNSDocument> nsDoc(do_QueryInterface(aDocument));
  if (!nsDoc)
    return PR_FALSE;
  nsCOMPtr<nsIDOMLocation> location;
  nsDoc->GetLocation(getter_AddRefs(location));
  if (!location)
    return PR_FALSE;
  nsresult rv = location->GetHref(aURI);
  return NS_SUCCEEDED(rv);
}

/*static*/
PRBool GeckoUtils::isProtocolInternal(const char* aProtocol)
{
  nsCOMPtr<nsIIOService> ioService = do_GetService("@mozilla.org/network/io-service;1");
  if (!ioService)
    return PR_TRUE; // something went wrong, so punt

  nsCOMPtr<nsIProtocolHandler> handler;
  // try to get an external handler for the protocol
  nsresult rv = ioService->GetProtocolHandler(aProtocol, getter_AddRefs(handler));
  if (NS_FAILED(rv))
    return PR_TRUE; // something went wrong, so punt

  nsCOMPtr<nsIExternalProtocolHandler> extHandler = do_QueryInterface(handler);
  // a null external handler means it's a protocol we handle internally
  return (extHandler == nsnull);
}

/* static */
PRBool 
GeckoUtils::IsSafeToOpenURIFromReferrer(const char* aTargetUri, const char* aReferrerUri)
{
  PRBool isUnsafeLink = PR_TRUE;
  nsCOMPtr<nsIURI> referrerUri;
  nsCOMPtr<nsIURI> targetUri;
  NS_NewURI(getter_AddRefs(referrerUri), aReferrerUri);
  NS_NewURI(getter_AddRefs(targetUri), aTargetUri);

  nsCOMPtr<nsIScriptSecurityManager> secManager = do_GetService(NS_SCRIPTSECURITYMANAGER_CONTRACTID);
  if (secManager&& referrerUri && targetUri) {
    nsresult rv = secManager->CheckLoadURI(referrerUri, targetUri, 0);
    isUnsafeLink = NS_SUCCEEDED(rv);
  }

  return isUnsafeLink;
}

//
// GetAnchorNodeFromSelection
//
// Finds the anchor node for the selection in the given editor
//
void GeckoUtils::GetAnchorNodeFromSelection(nsIEditor* inEditor, nsIDOMNode** outAnchorNode, PRInt32* outOffset)
{
  if (!inEditor || !outAnchorNode)
    return;
  *outAnchorNode = nsnull;

  nsCOMPtr<nsISelection> selection;
  inEditor->GetSelection(getter_AddRefs(selection));
  if (!selection)
    return;
  selection->GetAnchorOffset(outOffset);
  selection->GetAnchorNode(outAnchorNode);
}

void GeckoUtils::GetIntrinsicSize(nsIDOMWindow* aWindow,  PRInt32* outWidth, PRInt32* outHeight)
{
  if (!aWindow)
    return;

  nsCOMPtr<nsIDOMDocument> domDocument;
  aWindow->GetDocument(getter_AddRefs(domDocument));
  if (!domDocument)
    return;

  nsCOMPtr<nsIDOMElement> docElement;
  domDocument->GetDocumentElement(getter_AddRefs(docElement));
  if (!docElement)
    return;

  nsCOMPtr<nsIDOMNSHTMLElement> nsElement = do_QueryInterface(docElement);
  if (!nsElement)
    return;

  // scrollHeight always gets the wanted height but scrollWidth may not if the page contains
  // non-scrollable elements (eg <pre>), therefor we find the slientWidth and adds the max x
  // offset if the window has a horizontal scroller. For more see bug 155956 and
  // http://developer.mozilla.org/en/docs/DOM:element.scrollWidth
  // http://developer.mozilla.org/en/docs/DOM:element.clientWidth
  // http://developer.mozilla.org/en/docs/DOM:window.scrollMaxX
  nsElement->GetClientWidth(outWidth); 
  nsElement->GetScrollHeight(outHeight);

  nsCOMPtr<nsIDOMWindowInternal> domWindow = do_QueryInterface(aWindow);
  if (!domWindow)
    return;

  PRInt32 scrollMaxX = 0;
  domWindow->GetScrollMaxX(&scrollMaxX);
  if (scrollMaxX > 0) 
    *outWidth  += scrollMaxX;

  return;
}

PRBool GeckoUtils::GetFrameInScreenCoordinates(nsIDOMElement* aElement, nsIntRect* aRect)
{
  nsCOMPtr<nsIContent> content = do_QueryInterface(aElement);
  if (!content)
    return PR_FALSE;

  nsCOMPtr<nsIDocument> doc = content->GetDocument();
  if (!doc)
    return PR_FALSE;

  nsCOMPtr<nsIPresShell> presShell = doc->GetPrimaryShell();
  if (!presShell)
    return PR_FALSE;

  nsIFrame* frame = presShell->GetPrimaryFrameFor(content);
  if (!frame)
    return PR_FALSE;

  *aRect = frame->GetScreenRectExternal();

  return PR_TRUE;
}

void GeckoUtils::ScrollElementIntoView(nsIDOMElement* aElement)
{
  nsCOMPtr<nsIContent> content = do_QueryInterface(aElement);
  if (!content)
    return;

  nsCOMPtr<nsIDocument> doc = content->GetDocument();
  if (!doc)
    return;

  nsCOMPtr<nsIPresShell> presShell = doc->GetPrimaryShell();
  if (!presShell)
    return;

  presShell->ScrollContentIntoView(content, NS_PRESSHELL_SCROLL_IF_NOT_VISIBLE,
                                            NS_PRESSHELL_SCROLL_IF_NOT_VISIBLE);
}

PRBool GeckoUtils::StringContainsWord(nsAString& aString, const char* aWord, PRBool caseInsensitive)
{
  const nsStringComparator& comparator = caseInsensitive ? static_cast<const nsStringComparator&>(nsCaseInsensitiveStringComparator())
                                                         : static_cast<const nsStringComparator&>(nsDefaultStringComparator());
  nsAutoString source, word;
  source.Assign(aString);
  word.AssignASCII(aWord);
  if (source.Length() < word.Length())
    return PR_FALSE;

  nsAutoString wordAsPrefix(word);
  wordAsPrefix += ' ';
  nsAutoString wordAsSuffix(word);
  wordAsSuffix.Insert(' ', 0);
  nsAutoString wordAsWord(wordAsSuffix);
  wordAsWord += ' ';

  if (source.Equals(word, comparator) ||
      StringBeginsWith(source, wordAsPrefix, comparator) ||
      StringEndsWith(source, wordAsSuffix, comparator) ||
      (source.Find(NS_ConvertUTF16toUTF8(wordAsWord).get(), caseInsensitive, 0, -1) != kNotFound))
  {
    return PR_TRUE;
  }
  return PR_FALSE;
}
