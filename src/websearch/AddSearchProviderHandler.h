/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#include "chIAddSearchProviderHandler.h"
#include "nsISupports.h"

// Implements the window.external.AddSearchProvider JavaScript call for
// installing OpenSearch providers.
class AddSearchProviderHandler : public chIAddSearchProviderHandler
{
 public:
  AddSearchProviderHandler();
  ~AddSearchProviderHandler();

  NS_DECL_ISUPPORTS
  NS_DECL_CHIADDSEARCHPROVIDERHANDLER

  // Registers the class as the handler for window.external.
  static void InstallHandler();
};
