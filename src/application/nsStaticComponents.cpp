/* -*- Mode: C++; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#define XPCOM_TRANSLATE_NSGM_ENTRY_POINT 1

#include "nsIGenericFactory.h"
#include "nsXPCOM.h"
#include "nsStaticComponents.h"
#include "nsMemory.h"

/**
 * Construct a unique NSGetModule entry point for a generic module.
 */
#define NSGETMODULE(_name) _name##_NSGetModule

#ifdef _BUILD_STATIC_BIN
#define MODULES \
    MODULE(CmXULAppInfoModule) \
    MODULE(CHSafeBrowsingModule) \
    MODULE(nsI18nModule) \
    MODULE(nsChardetModule) \
    MODULE(nsUConvModule) \
    MODULE(nsJarModule) \
    MODULE(xpconnect) \
    MODULE(necko) \
    MODULE(nsPrefModule) \
    MODULE(nsCJVMManagerModule) \
    MODULE(nsSecurityManagerModule) \
    MODULE(nsChromeModule) \
    MODULE(nsRDFModule) \
    MODULE(nsParserModule) \
    MODULE(nsGfxModule) \
    MODULE(nsIconDecoderModule) \
    MODULE(nsImageLib2Module) \
    MODULE(nsPluginModule) \
    MODULE(nsWidgetMacModule) \
    MODULE(nsLayoutModule) \
    MODULE(nsPlacesModule) \
    MODULE(docshell_provider) \
    MODULE(embedcomponents) \
    MODULE(Browser_Embedding_Module) \
    MODULE(nsTransactionManagerModule) \
    MODULE(application) \
    MODULE(nsCookieModule) \
    MODULE(nsUniversalCharDetModule) \
    MODULE(nsTypeAheadFind) \
    MODULE(nsPermissionsModule) \
    MODULE(nsComposerModule) \
    MODULE(mozSpellCheckerModule) \
    MODULE(mozStorageModule) \
    MODULE(nsAuthModule) \
    MODULE(BOOT) \
    MODULE(NSS) \
    /* end of list */
#else  // _BUILD_STATIC_BIN
#define MODULES \
    MODULE(CmXULAppInfoModule) \
    /* end of list */
#endif  // _BUILD_STATIC_BIN

/**
 * Declare the NSGetModule() routine for each module
 */
#define MODULE(_name) \
NSGETMODULE_ENTRY_POINT(_name) (nsIComponentManager*, nsIFile*, nsIModule**);

MODULES

#undef MODULE

#define MODULE(_name) { #_name, NSGETMODULE(_name) },

/**
 * The nsStaticModuleInfo
 */
static nsStaticModuleInfo const gStaticModuleInfo[] = {
    MODULES
};

nsStaticModuleInfo const *const kPStaticModules = gStaticModuleInfo;
PRUint32 const kStaticModuleCount = NS_ARRAY_LENGTH(gStaticModuleInfo);
