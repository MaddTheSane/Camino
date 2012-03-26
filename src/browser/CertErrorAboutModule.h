/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#ifndef CHCertErrorAboutModule_h__
#define CHCertErrorAboutModule_h__

#include "nsIAboutModule.h"

//
// CHCertErrorAboutModule
//
// An nsIAboutModule for the "about:certerror" error page.
//
class CHCertErrorAboutModule : public nsIAboutModule
{
 public:
  NS_DECL_ISUPPORTS
  NS_DECL_NSIABOUTMODULE

  CHCertErrorAboutModule() {}
  virtual ~CHCertErrorAboutModule() {}

  static NS_METHOD CreateCertErrorAboutModule(nsISupports *aOuter, REFNSIID aIID, void **aResult);

 private:
  nsresult GetCertErrorPageSource(nsACString &result);
};

/* DC333639-ABF3-43F4-887C-65 17 D8 DF 9A D1 */
#define CH_CERTERROR_ABOUT_MODULE_CID \
{ 0xDC333639, 0xABF3, 0x43F4, \
{ 0x88, 0x7C, 0x65, 0x17, 0xD8, 0xDF, 0x9A, 0xD1}}

#endif // CHCertErrorAboutModule_h__
