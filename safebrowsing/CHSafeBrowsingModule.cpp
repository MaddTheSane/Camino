/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#include "nsIGenericFactory.h"

#include "nsUrlClassifierDBService.h"
#include "nsUrlClassifierStreamUpdater.h"
#include "nsUrlClassifierUtils.h"
#include "nsUrlClassifierHashCompleter.h"
#include "nsDocShellCID.h"

NS_GENERIC_FACTORY_CONSTRUCTOR(nsUrlClassifierStreamUpdater)
NS_GENERIC_FACTORY_CONSTRUCTOR_INIT(nsUrlClassifierUtils, Init)
NS_GENERIC_FACTORY_CONSTRUCTOR_INIT(nsUrlClassifierHashCompleter, Init)

static NS_IMETHODIMP
nsUrlClassifierDBServiceConstructor(nsISupports *aOuter, REFNSIID aIID,
                                    void **aResult)
{
  nsresult rv;
  NS_ENSURE_ARG_POINTER(aResult);
  NS_ENSURE_NO_AGGREGATION(aOuter);

  nsUrlClassifierDBService *sharedDBService = nsUrlClassifierDBService::GetInstance(&rv);
  if (NS_FAILED(rv))
      return rv;
  rv = sharedDBService->QueryInterface(aIID, aResult);
  NS_RELEASE(sharedDBService);

  return rv;
}

static const nsModuleComponentInfo components[] =
{
  { "Url Classifier DB Service",
    NS_URLCLASSIFIERDBSERVICE_CID,
    NS_URLCLASSIFIERDBSERVICE_CONTRACTID,
    nsUrlClassifierDBServiceConstructor },
  { "Url Classifier DB Service",
    NS_URLCLASSIFIERDBSERVICE_CID,
    NS_URICLASSIFIERSERVICE_CONTRACTID,
    nsUrlClassifierDBServiceConstructor },
  { "Url Classifier Stream Updater",
    NS_URLCLASSIFIERSTREAMUPDATER_CID,
    NS_URLCLASSIFIERSTREAMUPDATER_CONTRACTID,
    nsUrlClassifierStreamUpdaterConstructor },
  { "Url Classifier Utils",
    NS_URLCLASSIFIERUTILS_CID,
    NS_URLCLASSIFIERUTILS_CONTRACTID,
    nsUrlClassifierUtilsConstructor },
  { "Url Classifier Hash Completer",
    NS_URLCLASSIFIERHASHCOMPLETER_CID,
    NS_URLCLASSIFIERHASHCOMPLETER_CONTRACTID,
    nsUrlClassifierHashCompleterConstructor },
};

NS_IMPL_NSGETMODULE(CHSafeBrowsingModule, components)
