/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "NSMenu+Gecko.h"

#import "NSString+Gecko.h"

#include "nsIContent.h"
#include "nsIDocument.h"
#include "nsIDOMAbstractView.h"
#include "nsIDOMDocumentEvent.h"
#include "nsIDOMEventTarget.h"
#include "nsIDOMNodeList.h"
#include "nsIDOMXULCommandEvent.h"
#include "nsPIDOMWindow.h"

@interface XULMenuItem(Private)

// Returns YES if the underlying menu item has a given named attribute.
- (BOOL)hasAttribute:(NSString*)anAttr;
// Returns the value for a given named attribute of the underlying menu item,
// and an empty string if the item does not have that attribute.
- (NSString*)valueForAttribute:(NSString*)anAttr;
// Perform the XUL command of the item; this is typically a call to a
// Javascript function in the document.
- (void)performCommand;

@end

@implementation XULMenuItem

+ (id)itemWithMenuItem:(nsIDOMElement*)anItem
{
  return [[[XULMenuItem alloc] initWithMenuItem:anItem] autorelease];
}

- (id)initWithMenuItem:(nsIDOMElement*)anItem
{
  if ((self = [super init])) {
    if (!anItem) {
      [self autorelease];
      return nil;
    }

    mMenuItemElement = anItem;
    NS_ADDREF(mMenuItemElement);

    [self setTarget:self];

    if ([self hasAttribute:@"label"])
      [self setTitle:[self valueForAttribute:@"label"]];

    BOOL hasCommand = ([self hasAttribute:@"oncommand"] &&
                       ![[self valueForAttribute:@"oncommand"] isEqualToString:@""]);
    BOOL shouldEnableItem = (hasCommand && [self isEnabled]);
    if (shouldEnableItem)
      [self setAction:@selector(performCommand)];
  }
  return self;
}

- (void)dealloc
{
  NS_IF_RELEASE(mMenuItemElement);
  [super dealloc];
}

- (BOOL)hasAttribute:(NSString*)anAttr
{
  nsAutoString attrName;
  [anAttr assignTo_nsAString:attrName];
  PRBool result = PR_FALSE;
  mMenuItemElement->HasAttribute(attrName, &result);
  return result;
}

- (NSString*)valueForAttribute:(NSString*)anAttr
{
  nsAutoString attrName;
  [anAttr assignTo_nsAString:attrName];
  NSString* result = @"";
  nsAutoString attrValue;
  if (NS_SUCCEEDED(mMenuItemElement->GetAttribute(attrName, attrValue)))
    result = [NSString stringWith_nsAString:attrValue];
  return result;
}

- (BOOL)isHidden
{
  return [[self valueForAttribute:@"hidden"] isEqualToString:@"true"];
}

- (BOOL)isEnabled
{
  return ![[self valueForAttribute:@"disabled"] isEqualToString:@"true"];
}

- (void)performCommand
{
  nsCOMPtr<nsIContent> content(do_QueryInterface(mMenuItemElement)); 
  if (!content)
    return;

  nsCOMPtr<nsIDocument> doc = content->GetOwnerDoc();
  if (!doc)
    return;

  nsCOMPtr<nsIDOMDocumentEvent> docEvent = do_QueryInterface(doc);
  if (!docEvent)
    return;

  nsCOMPtr<nsIDOMEvent> event;
  docEvent->CreateEvent(NS_LITERAL_STRING("xulcommandevent"), getter_AddRefs(event));

  nsCOMPtr<nsIDOMXULCommandEvent> xulCommand = do_QueryInterface(event);
  if (!xulCommand)
    return;

  nsCOMPtr<nsIDOMAbstractView> view = do_QueryInterface(doc->GetWindow());
  if (!view)
    return;

  nsresult rv = xulCommand->InitCommandEvent(NS_LITERAL_STRING("command"),
                                             PR_TRUE, PR_TRUE, view, 0,
                                             PR_FALSE, PR_FALSE, PR_FALSE,
                                             PR_FALSE, nsnull);
  if (NS_FAILED(rv))
    return;

  nsCOMPtr<nsIDOMEventTarget> target = do_QueryInterface(mMenuItemElement);
  if(!target)
    return;

  PRBool dummy;
  target->DispatchEvent(xulCommand, &dummy);
}

@end

@implementation NSMenu(XULMenu)

+ (NSMenu*)menuFromNode:(nsIDOMNode*)aNode
{
  PRBool hasChildren;
  nsresult rv = aNode->HasChildNodes(&hasChildren);
  if (NS_FAILED(rv) || !hasChildren)
    return nil;

  nsCOMPtr<nsIDOMNodeList> children;
  rv = aNode->GetChildNodes(getter_AddRefs(children));
  if (NS_FAILED(rv) || !children)
    return nil;

  PRUint32 numChildren;
  rv = children->GetLength(&numChildren);
  if (NS_FAILED(rv))
    return nil;

  nsCOMPtr<nsIDOMElement> contextMenuElement = do_QueryInterface(aNode);
  if (!contextMenuElement)
    return nil;

  nsAutoString popupIDString;
  rv = contextMenuElement->GetAttribute(NS_LITERAL_STRING("id"), popupIDString);
  NSString* menuID = NS_SUCCEEDED(rv) ? [NSString stringWith_nsAString:popupIDString] : @"";
  NSMenu* theMenu = [[[NSMenu alloc] initWithTitle:menuID] autorelease];
  nsCOMPtr<nsIDOMNode> node;
  for (PRUint32 childIndex = 0; childIndex < numChildren; childIndex++) {
    rv = children->Item(childIndex, getter_AddRefs(node));
    if (NS_FAILED(rv))
      continue;

    nsAutoString nodeNameString;
    rv = node->GetNodeName(nodeNameString);
    if (NS_FAILED(rv))
      continue;

    if (nodeNameString.Equals(NS_LITERAL_STRING("menupopup"))) {
      // If the node is a <menupopup>, that means we are at the
      // first child of a <menu>. Instead of an empty parsed <menu>,
      // we should return the parsed <menupopup> (which has proper
      // <menuitem> children).
      // See: https://developer.mozilla.org/en/XUL:menu
      return [NSMenu menuFromNode:node];
    }

    nsCOMPtr<nsIDOMElement> nodeElement = do_QueryInterface(node);
    XULMenuItem* theXULItem = [XULMenuItem itemWithMenuItem:nodeElement];

    if (!theXULItem || [theXULItem isHidden])
      continue;

    [theMenu insertItem:theXULItem atIndex:[theMenu numberOfItems]];

    if (nodeNameString.Equals(NS_LITERAL_STRING("menu"))) {
      NSMenu* subMenu = [NSMenu menuFromNode:node];
      if (subMenu)
        [theMenu setSubmenu:subMenu forItem:theXULItem];
    }
  }
  return theMenu;
}

@end
