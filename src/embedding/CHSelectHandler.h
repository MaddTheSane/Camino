/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#ifndef CHSelectHandler_h_
#define CHSelectHandler_h_

#include <Cocoa/Cocoa.h>

#include "nsIDOMMouseListener.h"
#include "nsIDOMKeyListener.h"

// This class is a hack.  It listens to user mouse and key events so we know
// when to build and show our native menus for <select> items
class CHSelectHandler :  public nsIDOMMouseListener,
                         public nsIDOMKeyListener
{
public:
  CHSelectHandler();
  virtual ~CHSelectHandler();

  NS_DECL_ISUPPORTS

  // DOM event listener interface.
  NS_IMETHOD HandleEvent(nsIDOMEvent* aEvent) { return NS_OK; };

  // DOM mouse listener interface
  NS_IMETHOD MouseDown(nsIDOMEvent* aMouseEvent);
  NS_IMETHOD MouseUp(nsIDOMEvent* aMouseEvent) { return NS_OK; };
  NS_IMETHOD MouseClick(nsIDOMEvent* aMouseEvent) { return NS_OK; };
  NS_IMETHOD MouseDblClick(nsIDOMEvent* aMouseEvent) { return NS_OK; };
  NS_IMETHOD MouseOver(nsIDOMEvent* aMouseEvent) { return NS_OK; };
  NS_IMETHOD MouseOut(nsIDOMEvent* aMouseEvent) { return NS_OK; };

  // DOM key listener interface
  NS_IMETHOD KeyDown(nsIDOMEvent* aKeyEvent);
  NS_IMETHOD KeyUp(nsIDOMEvent* aKeyEvent) { return NS_OK; };
  NS_IMETHOD KeyPress(nsIDOMEvent* aKeyEvent) { return NS_OK; };
};


#endif
