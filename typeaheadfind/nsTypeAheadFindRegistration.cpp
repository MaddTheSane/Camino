/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#include "nsIGenericFactory.h"
#include "nsTypeAheadFind.h"
#include "nsIServiceManager.h"
#include "prprf.h"
#include "nsCRT.h"
#include "nsICategoryManager.h"

////////////////////////////////////////////////////////////////////////
// Define a table of CIDs implemented by this module along with other
// information like the function to create an instance, contractid, and
// class name.
//
// The Registration and Unregistration proc are optional in the structure.
//


// This function is called at component registration time
static NS_METHOD
nsTypeAheadFindRegistrationProc(nsIComponentManager *aCompMgr, nsIFile *aPath,
                                const char *registryLocation,
                                const char *componentType,
                                const nsModuleComponentInfo *info)
{
  // This function performs the extra step of installing us as
  // an application component. This makes sure that we're
  // initialized on application startup.

  // Register nsTypeAheadFind to be instantiated on startup.
  // XXX This is needed on linux, but for some reason not needed on win32.
  nsresult rv;
  nsCOMPtr<nsICategoryManager> categoryManager =
    do_GetService(NS_CATEGORYMANAGER_CONTRACTID, &rv);

  if (NS_SUCCEEDED(rv)) {
    rv = categoryManager->AddCategoryEntry(APPSTARTUP_CATEGORY,
                                           "Type Ahead Find", 
                                           "service,"
                                           NS_TYPEAHEADFIND_CONTRACTID,
                                           PR_TRUE, PR_TRUE, nsnull);
  }

  return rv;
}


NS_GENERIC_FACTORY_SINGLETON_CONSTRUCTOR(nsTypeAheadFind,
                                         nsTypeAheadFind::GetInstance)

static void PR_CALLBACK
TypeAheadFindModuleDtor(nsIModule* self)
{
  nsTypeAheadFind::ReleaseInstance();
}

static const nsModuleComponentInfo components[] =
{
  { "TypeAheadFind Component", NS_TYPEAHEADFIND_CID,
    NS_TYPEAHEADFIND_CONTRACTID, nsTypeAheadFindConstructor,
    nsTypeAheadFindRegistrationProc, nsnull  // Unregistration proc
  }
};

NS_IMPL_NSGETMODULE_WITH_DTOR(nsTypeAheadFind, components,
                              TypeAheadFindModuleDtor)
