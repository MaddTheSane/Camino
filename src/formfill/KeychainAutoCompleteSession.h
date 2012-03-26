/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>
#import "AutoCompleteUtils.h"

#include "nsIDOMEventListener.h"
#include "nsCOMPtr.h"

class nsIDOMHTMLInputElement;

//
// KeychainAutoCompleteDOMListener
//
// Listens for password fill requests from the FormFillController when a
// username is entered.
class KeychainAutoCompleteDOMListener : public nsIDOMEventListener
{
public:
  NS_DECL_ISUPPORTS
  NS_DECL_NSIDOMEVENTLISTENER

  void SetElements(nsIDOMHTMLInputElement* usernameElement,
                   nsIDOMHTMLInputElement* passwordElement);

protected:
  // Fills the password with the keychain data from the cached username input
  // element.
  void FillPassword();

  // Pointers to the login input elements so that the form doesn't need to
  // be searched when the same input element is attached again.
  nsCOMPtr<nsIDOMHTMLInputElement>   mUsernameElement;       // strong
  nsCOMPtr<nsIDOMHTMLInputElement>   mPasswordElement;       // strong
};

@interface KeychainAutoCompleteSession : NSObject<AutoCompleteSession>
{
  KeychainAutoCompleteDOMListener* mDOMListener;    // strong
  NSMutableArray* mUsernames;                       // strong
  NSString*       mDefaultUser;                     // strong

  // Cache the username input element so that we don't reread the keychain for
  // the same element.
  nsIDOMHTMLInputElement* mUsernameElement;         // weak
}

- (BOOL)attachToInput:(nsIDOMHTMLInputElement*)usernameElement;

@end
