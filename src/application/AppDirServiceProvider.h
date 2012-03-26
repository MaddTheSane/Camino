/* -*- Mode: C; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#ifndef __AppDirServiceProvider_h__
#define __AppDirServiceProvider_h__

#include "nsIDirectoryService.h"
#include "nsILocalFile.h"
#include "nsString.h"

#include <Carbon/Carbon.h>

class nsIMutableArray;
class nsIFile;

//*****************************************************************************
// class AppDirServiceProvider
//*****************************************************************************   

class AppDirServiceProvider : public nsIDirectoryServiceProvider2
{
public:
                            // If |isCustomProfile| is true, we use the passed in string as a path to the custom 
                            // profile.   If it is false, the string is the product name, which will be used for the 
                            // Application Support/<name> folder, as well as the Caches/<name> system folder.
                            AppDirServiceProvider(const char *inProductName, PRBool isCustomProfile);

    NS_DECL_ISUPPORTS
    NS_DECL_NSIDIRECTORYSERVICEPROVIDER
    NS_DECL_NSIDIRECTORYSERVICEPROVIDER2

protected:
    virtual                 ~AppDirServiceProvider();

    nsresult                GetProfileDirectory(nsILocalFile** outFolder);
    nsresult                GetParentCacheDirectory(nsILocalFile** outFolder);
    nsresult                GetSystemDirectory(OSType inFolderType, nsILocalFile** outFolder);
    nsresult                GetChromeManifestDirectories(nsIMutableArray* folderList);
    nsresult                GetProfilePluginsDirectory(nsIMutableArray* folderList);
    nsresult                GetProfileComponentsDirectory(nsIMutableArray* folderList);
    nsresult                GetProfileChromeDirectory(nsILocalFile** outFolder);
    nsresult                EnsureProfileFileExists(nsIFile *aFile, nsIFile *destDir);
    static nsresult         EnsureExists(nsILocalFile* inFolder);
  
protected:
    nsCOMPtr<nsILocalFile>  mProfileDir;
    PRBool                  mIsCustomProfile;
    
    // this is either the product name (e.g., "Camino") or a path, depending on mIsCustomPath
    nsCString               mName; 
};

#endif // __AppDirServiceProvider_h__

