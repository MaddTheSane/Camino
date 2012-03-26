/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#ifndef CHSafeBrowsingAboutModule_h__
#define CHSafeBrowsingAboutModule_h__

#include "nsIAboutModule.h"

//
// CHSafeBrowsingAboutModule
//
// An nsIAboutModule for the "about:safebrowsingblocked" error page.
//
class CHSafeBrowsingAboutModule : public nsIAboutModule
{
 public:
  NS_DECL_ISUPPORTS
  NS_DECL_NSIABOUTMODULE

  CHSafeBrowsingAboutModule() {}
  virtual ~CHSafeBrowsingAboutModule() {}

  static NS_METHOD CreateSafeBrowsingAboutModule(nsISupports *aOuter, REFNSIID aIID, void **aResult);

 private:
  nsresult GetBlockedPageSource(nsACString &result);
};

/* EDF643A9-8B38-472C-92A0-B6 3B EF B3 07 69 */
#define CH_SAFEBROWSING_ABOUT_MODULE_CID \
{ 0xEDF643A9, 0x8B38, 0x472C, \
{ 0x92, 0xA0, 0xB6, 0x3B, 0xEF, 0xB3, 0x07, 0x69}}

#endif // CHSafeBrowsingAboutModule_h__
