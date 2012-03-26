/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#ifndef __ContentClickListener_h__
#define __ContentClickListener_h__

#include <Carbon/Carbon.h>
#include <Cocoa/Cocoa.h>

#include "nsIDOMMouseListener.h"

@class BrowserWindowController;

class ContentClickListener :  public nsIDOMMouseListener
{
public:
  ContentClickListener(id aBrowserController);
  virtual ~ContentClickListener();

  NS_DECL_ISUPPORTS
  
  // The DOM mouse listener interface.  We only care about clicks.
  NS_IMETHOD HandleEvent(nsIDOMEvent* aEvent) { return NS_OK; };
  NS_IMETHOD MouseDown(nsIDOMEvent* aMouseEvent) { return NS_OK; };
  NS_IMETHOD MouseUp(nsIDOMEvent* aMouseEvent) { return NS_OK; };
  NS_IMETHOD MouseClick(nsIDOMEvent* aMouseEvent);
  NS_IMETHOD MouseDblClick(nsIDOMEvent* aMouseEvent) { return NS_OK; };
  NS_IMETHOD MouseOver(nsIDOMEvent* aMouseEvent) { return NS_OK; };
  NS_IMETHOD MouseOut(nsIDOMEvent* aMouseEvent) { return NS_OK; };

private:
  BrowserWindowController* mBrowserController; // Our browser controller (weakly held)
};


#endif
