/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>

class nsIDOMElement;
class nsIDOMNode;

// NSMenuItem subclass for wrapping a XUL <menuitem> element.
// |isHidden| is part of NSMenu on 10.5+, so once Camino is 10.5+ only this
// declaration can be moved into the implementation file.
@interface XULMenuItem : NSMenuItem
{
  nsIDOMElement* mMenuItemElement;   // strong
}

// Returns a XULMenuItem created from a given nsIDOMElement. The element should
// be a XUL <menuitem>.
+ (id)itemWithMenuItem:(nsIDOMElement*)anItem;
// Returns an initialized XULMenuItem object created from a given nsIDOMElement.
// The element should be a XUL <menuitem>.
- (id)initWithMenuItem:(nsIDOMElement*)anItem;
// Returns YES if the item is hidden.
- (BOOL)isHidden;

@end

@interface NSMenu(XULMenu)

// Returns an NSMenu created from a given XUL <popup> element.
+ (NSMenu*)menuFromNode:(nsIDOMNode*)aNode;

@end
