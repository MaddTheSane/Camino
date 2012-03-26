/* -*- Mode: C; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#include "AppDirServiceProvider.h"
#include "nsAppDirectoryServiceDefs.h"
#include "nsDirectoryServiceDefs.h"
#include "nsILocalFileMac.h"
#include "nsIMutableArray.h"
#include "nsIToolkitChromeRegistry.h"

#include <Carbon/Carbon.h>

// Defines
#define APP_REGISTRY_NAME            NS_LITERAL_CSTRING("Application.regs")
#define COMPONENT_REGISTRY_NAME      NS_LITERAL_CSTRING("compreg.dat")
#define XPTI_REGISTRY_NAME           NS_LITERAL_CSTRING("xpti.dat")
#define PROFILE_PLUGIN_DIR_NAME      NS_LITERAL_CSTRING("Internet Plug-Ins")
#define PROFILE_COMPONENTS_DIR_NAME  NS_LITERAL_CSTRING("components")
#define PROFILE_CHROME_MANIFEST_NAME NS_LITERAL_CSTRING("profile.manifest")
#define PROFILE_ADBLOCKING_CSS_NAME  NS_LITERAL_CSTRING("user_ad_blocking.css")


AppDirServiceProvider::AppDirServiceProvider(const char *inName, PRBool isCustomProfile)
{
  mIsCustomProfile = isCustomProfile;
  mName.Assign(inName);
}

AppDirServiceProvider::~AppDirServiceProvider()
{
}

NS_IMPL_ISUPPORTS2(AppDirServiceProvider,
                   nsIDirectoryServiceProvider,
                   nsIDirectoryServiceProvider2)


// nsIDirectoryServiceProvider implementation 

NS_IMETHODIMP
AppDirServiceProvider::GetFile(const char *prop, PRBool *persistent, nsIFile **_retval)
{
  nsCOMPtr<nsILocalFile>  localFile;
  nsresult rv = NS_ERROR_FAILURE;

  *_retval = nsnull;
  *persistent = PR_TRUE;
  
  if (strcmp(prop, NS_APP_APPLICATION_REGISTRY_DIR) == 0 ||
      strcmp(prop, NS_APP_USER_PROFILES_ROOT_DIR)   == 0)
  {
    rv = GetProfileDirectory(getter_AddRefs(localFile));
  }
  else if (strcmp(prop, NS_APP_APPLICATION_REGISTRY_FILE) == 0) {
    rv = GetProfileDirectory(getter_AddRefs(localFile));
    if (NS_SUCCEEDED(rv))
      rv = localFile->AppendNative(APP_REGISTRY_NAME);
  }
  else if (strcmp(prop, NS_XPCOM_COMPONENT_REGISTRY_FILE) == 0) {
    rv = GetProfileDirectory(getter_AddRefs(localFile));
    if (NS_SUCCEEDED(rv))
      rv = localFile->AppendNative(COMPONENT_REGISTRY_NAME);
  }
  else if (strcmp(prop, NS_XPCOM_XPTI_REGISTRY_FILE) == 0) {
    rv = GetProfileDirectory(getter_AddRefs(localFile));
    if (NS_SUCCEEDED(rv))
      rv = localFile->AppendNative(XPTI_REGISTRY_NAME);
  }
  else if (strcmp(prop, NS_APP_CACHE_PARENT_DIR) == 0 ||
           strcmp(prop, NS_APP_USER_PROFILE_LOCAL_50_DIR) == 0)
  {
    rv = GetParentCacheDirectory(getter_AddRefs(localFile));
  }

  if (localFile && NS_SUCCEEDED(rv))
    return localFile->QueryInterface(NS_GET_IID(nsIFile), (void**)_retval);
    
  return rv;
}

NS_IMETHODIMP
AppDirServiceProvider::GetFiles(const char *prop, nsISimpleEnumerator **_retval)
{
  nsresult rv = NS_ERROR_FAILURE;
  *_retval = nsnull;

  nsCOMPtr<nsIMutableArray> files = do_CreateInstance(NS_ARRAY_CONTRACTID);
  NS_ENSURE_TRUE(files, rv);

  if (strcmp(prop, NS_CHROME_MANIFESTS_FILE_LIST) == 0) {
    rv = GetChromeManifestDirectories(files);
  } else if (strcmp(prop, NS_APP_PLUGINS_DIR_LIST) == 0) {
    rv = GetProfilePluginsDirectory(files);
  } else if (strcmp(prop, NS_XPCOM_COMPONENT_DIR_LIST) == 0) {
    rv = GetProfileComponentsDirectory(files);
  }

  if (files && NS_SUCCEEDED(rv))
    files->Enumerate(_retval);

  return rv;
}

// Protected methods

nsresult
AppDirServiceProvider::GetProfileDirectory(nsILocalFile** outFolder)
{
  NS_ENSURE_ARG_POINTER(outFolder);
  *outFolder = nsnull;
  nsresult rv = NS_OK;
  
  // Init and cache the profile directory; we'll get queried for it a lot of times.
  if (!mProfileDir) {
    if (mIsCustomProfile) {
      rv = NS_NewLocalFile(NS_ConvertUTF8toUTF16(mName), PR_FALSE, getter_AddRefs(mProfileDir));
      
      if (NS_FAILED(rv)) {
        NS_WARNING ("Couldn't use the specified custom path!");
        return rv;
      }
    }
    else {
      // if this is not a custom profile path, we have a product name, and we'll use
      // Application Support/<mName> as our profile dir.
      rv = GetSystemDirectory(kApplicationSupportFolderType, getter_AddRefs(mProfileDir));
      NS_ENSURE_SUCCESS(rv, rv);
      
      // if it's not a custom profile, mName is our product name.
      mProfileDir->AppendNative(mName);
    }
    
    rv = EnsureExists(mProfileDir);
    NS_ENSURE_SUCCESS(rv, rv);
  } // end lazy init
  
  nsCOMPtr<nsIFile> profileDir;
  rv = mProfileDir->Clone(getter_AddRefs(profileDir));
  NS_ENSURE_SUCCESS(rv, rv);
  
  return CallQueryInterface(profileDir, outFolder);
}

nsresult
AppDirServiceProvider::GetSystemDirectory(OSType inFolderType, nsILocalFile** outFolder)
{
  FSRef foundRef;
  *outFolder = nsnull;
  
  OSErr err = ::FSFindFolder(kUserDomain, inFolderType, kCreateFolder, &foundRef);
  if (err != noErr)
    return NS_ERROR_FAILURE;
  
  nsCOMPtr<nsILocalFile> localDir;
  NS_NewLocalFile(EmptyString(), PR_TRUE, getter_AddRefs(localDir));
  nsCOMPtr<nsILocalFileMac> localDirMac(do_QueryInterface(localDir));
  NS_ENSURE_STATE(localDirMac);
  
  nsresult rv = localDirMac->InitWithFSRef(&foundRef);
  NS_ENSURE_SUCCESS(rv, rv);
  
  NS_ADDREF(*outFolder = localDirMac);
  return NS_OK;
}

// Gets the parent directory to the Cache folder.
nsresult
AppDirServiceProvider::GetParentCacheDirectory(nsILocalFile** outFolder)
{
  *outFolder = nsnull;
  
  if (mIsCustomProfile)
    return GetProfileDirectory(outFolder);
  
  // we don't have a custom profile path, so use Caches/<product name>
  nsresult rv = GetSystemDirectory(kCachedDataFolderType, outFolder);
  if (NS_FAILED(rv) || !(*outFolder))
    return NS_ERROR_FAILURE;
  
  (*outFolder)->AppendNative(mName);
  rv = EnsureExists(*outFolder);

  return rv;
}

// Gets the "chrome" folder in the user's profile and installs any app-provided
// user profile chrome.
nsresult
AppDirServiceProvider::GetProfileChromeDirectory(nsILocalFile** outFolder)
{
  *outFolder = nsnull;
  
  nsCOMPtr<nsIFile> appUserChromeDir;
  nsresult rv = NS_GetSpecialDirectory(NS_APP_USER_CHROME_DIR,
                                       getter_AddRefs(appUserChromeDir));
  NS_ENSURE_SUCCESS(rv, rv);
  // This folder may not exist yet, so create it in that case.
  nsCOMPtr<nsILocalFile> appUserChromeDirLocalFile(do_QueryInterface(appUserChromeDir));
  NS_ENSURE_TRUE(appUserChromeDirLocalFile, NS_ERROR_FAILURE);
  rv = EnsureExists(appUserChromeDirLocalFile);
  NS_ENSURE_SUCCESS(rv, rv);

  // Add our chrome manifest and CSS file before returning, so that files are
  // in place before registering chrome.
  nsCOMPtr<nsIFile> appUserChromeManifest;
  rv = appUserChromeDir->Clone(getter_AddRefs(appUserChromeManifest));
  if (NS_SUCCEEDED(rv)) {
    rv = appUserChromeManifest->AppendNative(PROFILE_CHROME_MANIFEST_NAME);
    if (NS_SUCCEEDED(rv))
      rv = EnsureProfileFileExists(appUserChromeManifest, appUserChromeDir);
  }
  nsCOMPtr<nsIFile> userAdBlockingSheet;
  rv = appUserChromeDir->Clone(getter_AddRefs(userAdBlockingSheet));
  if (NS_SUCCEEDED(rv)) {
    rv = userAdBlockingSheet->AppendNative(PROFILE_ADBLOCKING_CSS_NAME);
    if (NS_SUCCEEDED(rv))
      rv = EnsureProfileFileExists(userAdBlockingSheet, appUserChromeDir);
  }

  NS_ADDREF(*outFolder = appUserChromeDirLocalFile);
  return NS_OK;
}

nsresult
AppDirServiceProvider::GetChromeManifestDirectories(nsIMutableArray* folderList)
{
  // Get the localized resources directory by finding a resource that is
  // guaranteed to be there, then finding its parent.
  CFURLRef menuNibURL = CFBundleCopyResourceURL(CFBundleGetMainBundle(),
                                                CFSTR("MainMenu"), CFSTR("nib"),
                                                NULL);
  NS_ENSURE_TRUE(menuNibURL, NS_ERROR_FAILURE);
  CFURLRef localizedResourcesURL =
      CFURLCreateCopyDeletingLastPathComponent(kCFAllocatorDefault, menuNibURL);
  CFRelease(menuNibURL);
  NS_ENSURE_TRUE(localizedResourcesURL, NS_ERROR_FAILURE);

  nsCOMPtr<nsILocalFile> localDir;
  NS_NewLocalFile(EmptyString(), PR_TRUE, getter_AddRefs(localDir));
  nsCOMPtr<nsILocalFileMac> localizedResourceDir(do_QueryInterface(localDir));
  NS_ENSURE_TRUE(localizedResourceDir, NS_ERROR_FAILURE);
  nsresult rv = localizedResourceDir->InitWithCFURL(localizedResourcesURL);
  CFRelease(localizedResourcesURL);
  NS_ENSURE_SUCCESS(rv, rv);
  rv = folderList->AppendElement(localizedResourceDir, PR_FALSE);
  NS_ENSURE_SUCCESS(rv, rv);

  nsCOMPtr<nsIFile> appChromeDir;
  rv = NS_GetSpecialDirectory(NS_APP_CHROME_DIR, getter_AddRefs(appChromeDir));
  NS_ENSURE_SUCCESS(rv, rv);
  rv = folderList->AppendElement(appChromeDir, PR_FALSE);
  NS_ENSURE_SUCCESS(rv, rv);

  nsCOMPtr<nsILocalFile> appUserChromeDir;
  rv = GetProfileChromeDirectory(getter_AddRefs(appUserChromeDir));
  NS_ENSURE_SUCCESS(rv, rv);
  rv = folderList->AppendElement(appUserChromeDir, PR_FALSE);
  NS_ENSURE_SUCCESS(rv, rv);

  return rv;
}

nsresult
AppDirServiceProvider::GetProfilePluginsDirectory(nsIMutableArray* folderList)
{
  nsCOMPtr<nsILocalFile> pluginDir;
  nsresult rv = GetProfileDirectory(getter_AddRefs(pluginDir));
  NS_ENSURE_SUCCESS(rv, rv);
  pluginDir->AppendNative(PROFILE_PLUGIN_DIR_NAME);
  rv = EnsureExists(pluginDir);
  NS_ENSURE_SUCCESS(rv, rv);
  rv = folderList->AppendElement(pluginDir, PR_FALSE);
  NS_ENSURE_SUCCESS(rv, rv);

  return NS_SUCCESS_AGGREGATE_RESULT;
}

nsresult
AppDirServiceProvider::GetProfileComponentsDirectory(nsIMutableArray* folderList)
{
  nsCOMPtr<nsILocalFile> componentsDir;
  nsresult rv = GetProfileDirectory(getter_AddRefs(componentsDir));
  NS_ENSURE_SUCCESS(rv, rv);
  componentsDir->AppendNative(PROFILE_COMPONENTS_DIR_NAME);
  rv = EnsureExists(componentsDir);
  NS_ENSURE_SUCCESS(rv, rv);
  rv = folderList->AppendElement(componentsDir, PR_FALSE);
  NS_ENSURE_SUCCESS(rv, rv);

  return NS_SUCCESS_AGGREGATE_RESULT;
}

/* Copied wholesale from nsProfileDirServiceProvider::EnsureProfileFileExists */
nsresult
AppDirServiceProvider::EnsureProfileFileExists(nsIFile *aFile, nsIFile *destDir)
{
  nsresult rv;
  PRBool exists;

  rv = aFile->Exists(&exists);
  if (NS_FAILED(rv))
    return rv;
  if (exists)
    return NS_OK;

  nsCOMPtr<nsIFile> defaultsFile;

  // Attempt first to get the localized subdir of the defaults
  rv = NS_GetSpecialDirectory(NS_APP_PROFILE_DEFAULTS_50_DIR, getter_AddRefs(defaultsFile));
  if (NS_FAILED(rv)) {
    // If that has not been defined, use the top level of the defaults
    rv = NS_GetSpecialDirectory(NS_APP_PROFILE_DEFAULTS_NLOC_50_DIR, getter_AddRefs(defaultsFile));
    if (NS_FAILED(rv))
      return rv;
  }

  nsCAutoString leafName;
  rv = aFile->GetNativeLeafName(leafName);
  if (NS_FAILED(rv))
    return rv;
  rv = defaultsFile->AppendNative(leafName);
  if (NS_FAILED(rv))
    return rv;
  
  return defaultsFile->CopyTo(destDir, EmptyString());
}

/* static */ 
nsresult
AppDirServiceProvider::EnsureExists(nsILocalFile* inFolder)
{
  PRBool exists;
  nsresult rv = inFolder->Exists(&exists);
  if (NS_SUCCEEDED(rv) && !exists)
    rv = inFolder->Create(nsIFile::DIRECTORY_TYPE, 0775);
  return rv;
}

