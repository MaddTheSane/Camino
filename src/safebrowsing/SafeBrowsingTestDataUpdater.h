/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#ifndef CHSafeBrowsingTestDataUpdater_h_
#define CHSafeBrowsingTestDataUpdater_h_

#import <Cocoa/Cocoa.h>

#include <nsISupportsUtils.h>
#include "nsCOMPtr.h"
#include "nsIUrlClassifierDBService.h"

//
// CHSafeBrowsingTestDataUpdater
//
// Manually inserts our own test URLs into the safe browsing blacklist database 
// by simulating a url-classifier update stream.
//
class CHSafeBrowsingTestDataUpdater : public nsIUrlClassifierUpdateObserver
{
 public:
  NS_DECL_ISUPPORTS
  NS_DECL_NSIURLCLASSIFIERUPDATEOBSERVER

  CHSafeBrowsingTestDataUpdater();
  virtual ~CHSafeBrowsingTestDataUpdater();

  NS_IMETHOD InsertTestURLsIntoSafeBrowsingDb();

 private:
  nsresult AppendUpdateStream(const nsACString & inDatabaseTableName, NSArray *inTestURLs, nsACString & outUpdateStream);
};

#endif // CHSafeBrowsingTestDataUpdater_h_
