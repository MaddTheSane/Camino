/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#ifndef __SecurityDialogs_h__
#define __SecurityDialogs_h__

#include "nsIClientAuthDialogs.h"
#include "nsITokenPasswordDialogs.h"
#include "nsICertificateDialogs.h"
#include "nsISecurityWarningDialogs.h"
#include "nsITokenDialogs.h"
#include "nsIDOMCryptoDialogs.h"
#include "nsIGenKeypairInfoDlg.h"

#include "nsIStringBundle.h"
#include "nsCOMPtr.h"

class SecurityDialogs : public nsICertificateDialogs,
                        public nsITokenPasswordDialogs,
                        public nsIClientAuthDialogs,
                        public nsISecurityWarningDialogs,
                        public nsITokenDialogs,
                        public nsIDOMCryptoDialogs,
                        public nsIGeneratingKeypairInfoDialogs
{
public:
  SecurityDialogs();
  virtual ~SecurityDialogs();

  NS_DECL_ISUPPORTS;
  NS_DECL_NSICERTIFICATEDIALOGS;
  NS_DECL_NSITOKENPASSWORDDIALOGS;
  NS_DECL_NSICLIENTAUTHDIALOGS;
  NS_DECL_NSISECURITYWARNINGDIALOGS;
  NS_DECL_NSITOKENDIALOGS;
  NS_DECL_NSIDOMCRYPTODIALOGS;
  NS_DECL_NSIGENERATINGKEYPAIRINFODIALOGS;

private:
  nsresult EnsureSecurityStringBundle();

  nsresult AlertDialog(nsIInterfaceRequestor* ctx, const char* prefName,
                       const PRUnichar* messageName,
                       const PRUnichar* showAgainName);

  nsCOMPtr<nsIStringBundle> mSecurityStringBundle;
};

#endif
