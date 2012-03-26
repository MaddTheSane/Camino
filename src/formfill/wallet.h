/* -*- Mode: C; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

//
// Portions of this extension have been rewritten from the original version in 
// order to shim in reading from the Apple address book instead of a saved data file. No
// user data is stored in the profile, we only read from the address book.
//
// The majority of the code has been left as-is but commented out so that if additional
// features want to be brought back in (such as saving form values) that should be
// a bit easier.
//

/*
   wallet.h --- prototypes for wallet functions.
*/

#ifndef _WALLET_H
#define _WALLET_H

#include "prtypes.h"
#include "nsIPresShell.h"
#include "nsString.h"
#include "nsIPrompt.h"

class nsIDOMWindowInternal;

PR_BEGIN_EXTERN_C

#define HEADER_VERSION "#2c"

// The only public API we expose from wallet. Prefills the given presShell with values
// from the Apple Address Book's "me" card. This will initialize wallet if nothing else has
// already done so so no additional intialzation routine is necessary.
extern nsresult
Wallet_Prefill(nsIDOMWindowInternal* win);

// Tell wallet to clean itself up.
extern void
Wallet_ReleaseAllLists();

//
// Everything below here is kept as-is for posterity, in case anybody is crazy enough
// to use it....
//

#if UNUSED

#define YES_BUTTON 0
#define NO_BUTTON 1
#define NEVER_BUTTON 2

#define pref_Crypto "wallet.crypto"
#define pref_AutoCompleteOverride "wallet.crypto.autocompleteoverride"

class nsIInputStream;
class nsIOutputStream;
class nsIFile;
class nsIDOMNode;

extern void
WLLT_ChangePassword(PRBool* status);

extern void
WLLT_DeleteAll();

extern void
WLLT_ClearUserData();

extern void
WLLT_DeletePersistentUserData();

extern void
WLLT_PreEdit(nsAString& walletList);

extern void
WLLT_PostEdit(const nsAString& walletList);

extern void
WLLT_PrefillReturn(const nsAString& results);

extern void
WLLT_RequestToCapture(nsIPresShell* shell, nsIDOMWindowInternal * win, PRUint32* status);

extern nsresult
WLLT_PrefillOneElement
  (nsIDOMWindowInternal* win, nsIDOMNode* elementNode, nsAString& compositeValue);

extern void
WLLT_GetNopreviewListForViewer(nsAString& aNopreviewList);

extern void
WLLT_GetNocaptureListForViewer(nsAString& aNocaptureList);

extern void
WLLT_GetPrefillListForViewer(nsAString& aPrefillList);

extern void
WLLT_OnSubmit(nsIDOMHTMLFormElement* formNode, nsIDOMWindowInternal* window);

extern void
WLLT_ExpirePassword(PRBool* status);

extern void
WLLT_ExpirePasswordOnly(PRBool* status);

extern void
WLLT_InitReencryptCallback(nsIDOMWindowInternal* window);

extern nsresult
Wallet_Encrypt(const nsAString& text, nsAString& crypt);

extern nsresult
Wallet_Decrypt(const nsAString& crypt, nsAString& text);

extern nsresult
wallet_GetLine(nsIInputStream* strm, nsACString& line);

/**
 * Writes a line to a stream, including a newline character.
 * parameter should not include '\n'
 */
extern void
wallet_PutLine(nsIOutputStream* strm, const char* line);

/**
 * Gets the current profile directory
 */
extern nsresult Wallet_ProfileDirectory(nsIFile** aFile);

extern PRUnichar * Wallet_Localize(const char * genericString);

extern char* Wallet_RandomName(char* suffix);

extern PRBool Wallet_ConfirmYN(PRUnichar * szMessage, nsIDOMWindowInternal* window);

extern PRInt32 Wallet_3ButtonConfirm(PRUnichar * szMessage, nsIDOMWindowInternal* window);

extern void Wallet_GiveCaveat(nsIDOMWindowInternal* window, nsIPrompt* dialog);

extern void
Wallet_SignonViewerReturn(const nsAString& results);
#endif


PR_END_EXTERN_C

#endif /* !_WALLET_H */
