/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#ifndef __CocoaPromptService_h__
#define __CocoaPromptService_h__

#include "nsIStringBundle.h"
#include "nsIPromptService.h"
#include "nsIPromptFactory.h"
#include "nsICookiePromptService.h"
#include "nsCOMPtr.h"
#import <Cocoa/Cocoa.h>

class CocoaPromptService : public nsIPromptService, public nsICookiePromptService, public nsIPromptFactory
{
public:
  CocoaPromptService();
  virtual ~CocoaPromptService();

  NS_DECL_ISUPPORTS;
  NS_DECL_NSIPROMPTSERVICE;
  NS_DECL_NSICOOKIEPROMPTSERVICE;
  NS_DECL_NSIPROMPTFACTORY;

private:
  NSString *GetCommonDialogLocaleString(const char *s);
  NSString *GetButtonStringFromFlags(PRUint32 btnFlags, PRUint32 btnIDAndShift,
                                     const PRUnichar *btnTitle);

  nsCOMPtr<nsIStringBundle> mCommonDialogStringBundle;
};

#endif
