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
 * Portions created by the Initial Developer are Copyright (C) 2002
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *   David Hyatt <hyatt@mozilla.org> (Original Author)
 *   Ian Leue <froodian@gmail.com>
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

#import "NSString+Gecko.h"
#import "NSString+Utils.h"
#import "NSArray+Utils.h"
#import "CHBrowserView.h"

#include "nsCOMPtr.h"
#include "nsString.h"
#include "CHSelectHandler.h"
#include "nsIContent.h"
#include "nsIDOMElement.h"
#include "nsIDOMMouseEvent.h"
#include "nsIDOMKeyEvent.h"
#include "nsEmbedAPI.h"
#include "nsIDOMDocument.h"
#include "nsIDOMDocumentEvent.h"
#include "nsIDOMEventTarget.h"
#include "nsIDOMHTMLSelectElement.h"
#include "nsIDOMHTMLOptionElement.h"
#include "nsIDOMHTMLOptionsCollection.h"
#include "nsIDOMHTMLOptGroupElement.h"
#include "nsIDOMWindow.h"
#include "nsIDocument.h"
#include "nsIPresShell.h"
#include "nsIFrame.h"
#include "nsISupportsArray.h"


@interface CHOptionSelector : NSObject
{
  nsIDOMHTMLSelectElement* mSelectElt;
}

- (id)initWithSelect:(nsIDOMHTMLSelectElement*)aSel;
- (IBAction)selectOption:(id)aSender;

@end

@implementation CHOptionSelector

- (id)initWithSelect:(nsIDOMHTMLSelectElement*)aSel
{
  if ((self = [super init])) {
    mSelectElt = aSel;
  }
  return self;
}

- (IBAction)selectOption:(id)aSender
{
  nsIDOMHTMLOptionElement* optionElt = (nsIDOMHTMLOptionElement*)[[aSender representedObject] pointerValue];
  NS_ASSERTION(optionElt, "Missing option element");
  if (!optionElt) return;

  optionElt->SetSelected(PR_TRUE);

  // Fire a DOM event for the title change.
  nsCOMPtr<nsIDOMEvent> event;
  nsCOMPtr<nsIDOMDocument> domDocument;
  mSelectElt->GetOwnerDocument(getter_AddRefs(domDocument));
  nsCOMPtr<nsIDOMDocumentEvent> docEvent(do_QueryInterface(domDocument));

  docEvent->CreateEvent(NS_LITERAL_STRING("Events"), getter_AddRefs(event));
  if (event) {
    event->InitEvent(NS_LITERAL_STRING("change"), PR_TRUE, PR_TRUE);
    PRBool noDefault;
    nsCOMPtr<nsIDOMEventTarget> target(do_QueryInterface(mSelectElt));
    target->DispatchEvent(event, &noDefault);
  }
}

@end

#pragma mark -

@interface CHSelectPopupDisplayer : NSObject
{
  nsIDOMHTMLSelectElement* mSelectElement;
  NSEvent*                 mTriggerEvent;
}

+ (void)showNativePopupMenuAsynchronouslyForSelect:(nsIDOMHTMLSelectElement*)aSelectElement;
- (id)initWithSelect:(nsIDOMHTMLSelectElement*)aSelectElement
               event:(NSEvent*)triggerEvent;
- (void)showNativePopupMenu;

@end

@implementation CHSelectPopupDisplayer

+ (void)showNativePopupMenuAsynchronouslyForSelect:(nsIDOMHTMLSelectElement*)aSelectElement
{
  CHSelectPopupDisplayer* displayer = [[CHSelectPopupDisplayer alloc] initWithSelect:aSelectElement
                                                                               event:[NSApp currentEvent]];
  [displayer performSelector:@selector(showNativePopupMenu)
                  withObject:nil
                  afterDelay:0
                     inModes:[NSArray arrayWithObjects:NSDefaultRunLoopMode, NSEventTrackingRunLoopMode, nil]];
  // The delayed performSelector will retain the object until after it fires,
  // which is as long as we need it, so don't retain ownership.
  [displayer release];
}

- (id)initWithSelect:(nsIDOMHTMLSelectElement*)aSelectElement
               event:(NSEvent*)triggerEvent
{
  if ((self = [super init])) {
    mSelectElement = aSelectElement;
    NS_IF_ADDREF(mSelectElement);
    mTriggerEvent = [triggerEvent retain];
  }
  return self;
}

- (void)dealloc
{
  NS_IF_RELEASE(mSelectElement);
  [mTriggerEvent release];
  [super dealloc];
}

- (void)showNativePopupMenu
{
  PRInt32 size = 0;
  mSelectElement->GetSize(&size);
  PRBool multiple = PR_FALSE;
  mSelectElement->GetMultiple(&multiple);
  if (size > 1 || multiple)
    return;

  // If the select has been removed from the document between the time it was
  // clicked and now, it won't have a document anymore, so check that first.
  nsCOMPtr<nsIContent> selContent = do_QueryInterface(mSelectElement);
  if (!selContent)
    return;
  nsCOMPtr<nsIDocument> doc = selContent->GetDocument();
  if (!doc)
    return;

  // the call to popUpContextMenu: is synchronous so we don't need to
  // worry about retaining the menu for later.
  NSMenu* menu = [[[NSMenu alloc] init] autorelease];

  // We'll set the disabled state as the options are created, so disable
  // auto-enabling via NSMenuValidation.
  [menu setAutoenablesItems:NO];

  nsCOMPtr<nsIDOMHTMLOptionsCollection> options;
  mSelectElement->GetOptions(getter_AddRefs(options));
  PRUint32 count;
  options->GetLength(&count);
  PRInt32 selIndex = 0;   // currently unused

  // We need to addref all of the option elements that we set on the menu,
  // then auto release them when we leave this function. see bug: 373482
  nsCOMPtr<nsISupportsArray> option_pool;
  nsresult rv = NS_NewISupportsArray(getter_AddRefs(option_pool));
  if (NS_FAILED(rv))
    return;

  nsCOMPtr<nsIDOMHTMLOptGroupElement> curOptGroup;

  for (PRUint32 i = 0; i < count; i++) {
    nsAutoString itemLabel;

    nsCOMPtr<nsIDOMNode> node;
    options->Item(i, getter_AddRefs(node));

    nsCOMPtr<nsIDOMHTMLOptionElement> option(do_QueryInterface(node));

    nsCOMPtr<nsIDOMNode> parentNode;
    option->GetParentNode(getter_AddRefs(parentNode));
    nsCOMPtr<nsIDOMHTMLOptGroupElement> parentOptGroup = do_QueryInterface(parentNode);
    if (parentOptGroup && (parentOptGroup != curOptGroup)) {
      // insert optgroup item
      parentOptGroup->GetLabel(itemLabel);
      NSString* title = [[NSString stringWith_nsAString:itemLabel] stringByTruncatingTo:75 at:kTruncateAtMiddle];
      NSMenuItem* menuItem = [[[NSMenuItem alloc] initWithTitle:title action:NULL keyEquivalent:@""] autorelease];
      [menu addItem:menuItem];
      [menuItem setEnabled:NO];

      curOptGroup = parentOptGroup;
    }

    option->GetLabel(itemLabel);
    if (itemLabel.IsEmpty())
      option->GetText(itemLabel);

    NSString* title = [[NSString stringWith_nsAString:itemLabel] stringByTruncatingTo:75 at:kTruncateAtMiddle];
    NSMenuItem* menuItem = [[[NSMenuItem alloc] initWithTitle:title action:NULL keyEquivalent:@""] autorelease];
    // indent items in optgroup
    if (parentOptGroup)
      [menuItem setIndentationLevel:1];

    [menu addItem:menuItem];
    option_pool->AppendElement(option);  // refcount the option.
    [menuItem setRepresentedObject:[NSValue valueWithPointer:option.get()]];

    PRBool selected;
    option->GetSelected(&selected);
    if (selected) {
      [menuItem setState:NSOnState];
      selIndex = i;
    }
    PRBool disabled;
    option->GetDisabled(&disabled);
    if (disabled)
      [menuItem setEnabled:NO];
    CHOptionSelector* optSelector = [[[CHOptionSelector alloc] initWithSelect:mSelectElement] autorelease];
    [menuItem setTarget:optSelector];									// retains
    if (!selected)
      [menuItem setAction:@selector(selectOption:)];
  }

  NSWindow* hostWindow = [mTriggerEvent window];
  if (!hostWindow)
    return;

  // get the frame location
  nsIPresShell* presShell = doc->GetPrimaryShell();
  if (!presShell)
    return;

  nsIFrame* selectFrame = presShell->GetPrimaryFrameFor(selContent);
  if (!selectFrame)
    return;

  nsIntRect selectRect = selectFrame->GetScreenRectExternal();
  NSRect selectScreenRect = NSMakeRect(selectRect.x, selectRect.y, selectRect.width, selectRect.height);

  NSScreen* mainScreen = [[NSScreen screens] firstObject];  // NSArray category method
  if (!mainScreen)
    return;

  // y-flip and subtract the control height to convert to cocoa coords
  NSRect mainScreenFrame = [mainScreen frame];
  selectScreenRect.origin.y = NSMaxY(mainScreenFrame) - selectScreenRect.origin.y - selectScreenRect.size.height;

  // convert to window coords
  NSRect selectFrameRect = selectScreenRect;
  selectFrameRect.origin = [hostWindow convertScreenToBase:selectFrameRect.origin];

  // we're gonna make a little view to display things with, so that the popup isn't
  // shown at the top of the window when it's near the bottom of the screen.
  NSView* hostView = [[NSView alloc] initWithFrame:selectFrameRect];
  [[hostWindow contentView] addSubview:hostView];   // takes ownership
  [hostView release];

  const float kMenuWidth = 20.0;               // specify something small so it sizes to fit
  const float kMenuPopupHeight = 20.0;         // height of a popup in aqua

  NSRect bounds = NSMakeRect(0, 0, kMenuWidth, kMenuPopupHeight);

  NSPopUpButtonCell* popupCell = [[NSPopUpButtonCell alloc] initTextCell:@"" pullsDown:NO];
  [popupCell setMenu:menu];
  [popupCell setFont:[NSFont systemFontOfSize:[NSFont systemFontSize]]];
  [popupCell trackMouse:mTriggerEvent inRect:bounds ofView:hostView untilMouseUp:YES];
  [popupCell release];

  [hostView removeFromSuperview];   // this releases it
  return;
}

@end

#pragma mark -

NS_IMPL_ISUPPORTS2(CHSelectHandler,
                   nsIDOMMouseListener,
                   nsIDOMKeyListener)

CHSelectHandler::CHSelectHandler()
{
}

CHSelectHandler::~CHSelectHandler()
{
}

NS_IMETHODIMP
CHSelectHandler::MouseDown(nsIDOMEvent* aEvent)
{
  nsCOMPtr<nsIDOMMouseEvent> mouseEvent(do_QueryInterface(aEvent));
  if (!mouseEvent) return NS_ERROR_FAILURE;

  PRUint16 button;
  mouseEvent->GetButton(&button);
  // only show popup on left button
  if (button != 0)
    return NS_OK;

  nsCOMPtr<nsIDOMEventTarget> target;
  mouseEvent->GetTarget(getter_AddRefs(target));
  if (!target)
    return NS_OK;

  nsCOMPtr<nsIDOMHTMLSelectElement> sel(do_QueryInterface(target));
  if (!sel)
    return NS_OK;

  [CHSelectPopupDisplayer showNativePopupMenuAsynchronouslyForSelect:sel];
  return NS_OK;
}

NS_IMETHODIMP
CHSelectHandler::KeyDown(nsIDOMEvent* aKeyEvent)
{
  nsCOMPtr<nsIDOMKeyEvent> keyEvent(do_QueryInterface(aKeyEvent));
  if (!keyEvent)
    return NS_ERROR_FAILURE;

  PRUint32 keyCode;
  keyEvent->GetKeyCode(&keyCode);
  // We only care about spaces
  if (keyCode != nsIDOMKeyEvent::DOM_VK_SPACE)
    return NS_OK;

  nsCOMPtr<nsIDOMEventTarget> target;
  keyEvent->GetTarget(getter_AddRefs(target));
  if (!target)
    return NS_OK;

  nsCOMPtr<nsIDOMHTMLSelectElement> sel(do_QueryInterface(target));
  if (!sel)
    return NS_OK;

  [CHSelectPopupDisplayer showNativePopupMenuAsynchronouslyForSelect:sel];
  return NS_OK;
}
