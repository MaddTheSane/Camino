/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>
#import "AutoCompleteUtils.h"

#include "nsIDOMEventListener.h"

extern const int kFormFillMaxRows;

@class KeychainAutoCompleteSession;
@class CHBrowserView;
@class FormFillPopup;
@class FormFillController;

class nsIDOMHTMLInputElement;

// FormFillListener
//
// The FormFillListener object listens for DOM events and the corresponding
// methods in the FormFillController are called for handling.
//
class FormFillListener : public nsIDOMEventListener
{ 
public:
  NS_DECL_ISUPPORTS
  NS_DECL_NSIDOMEVENTLISTENER

  FormFillListener(FormFillController* aController);

protected:
  FormFillController*  mController;     // weak
};

// FormFillController
//
// Manages the FormFillPopup windows that contain search results
// as well as sending search requests to the KeychainAutoCompleteSession
// and listening for search results.  This can be extended to send
// search requests to a form history session as well.
@interface FormFillController : NSObject <AutoCompleteListener>
{
  KeychainAutoCompleteSession*  mKeychainSession;     // strong
  AutoCompleteResults*          mResults;             // strong
  FormFillListener*             mListener;            // strong
  FormFillPopup*                mPopupWindow;         // strong

  CHBrowserView*                mBrowserView;         // weak
  nsIDOMHTMLInputElement*       mFocusedInputElement; // weak

  // mCompleteResult determines if the current search should complete the default
  // result when ready. This prevents backspace/delete from autocompleting.
  BOOL mCompleteResult;

  // mUsernameFillEnabled determines whether we send searches to the Keychain
  // Service.  Form fill history value can be added here as well.
  BOOL mUsernameFillEnabled;
}

- (void)attachToBrowser:(CHBrowserView*)browser;

// Callback function for when a row in the focused popup window is clicked.
- (void)popupSelected;

@end
