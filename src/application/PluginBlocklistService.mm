/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#include "PluginBlocklistService.h"

#import <Foundation/Foundation.h>

#import "PreferenceManager.h"

#include "nsIPluginTag.h"
#include "nsString.h"

static NSString* const kPluginNameAdobePDFNPAPI = @"Adobe Acrobat NPAPI Plug-in";
static NSString* const kPluginNameFlash = @"Shockwave Flash";
static NSString* const kPluginNameFlip4Mac = @"Flip4Mac";

struct VersionStruct {
  int major;
  int minor;
  int bugfix;
  int build;
};

// Minimum versions of plugins allowed unless the dangerous plugin pref is set.
#if defined(__ppc__)
// This version is known to have vulnerabilities, but is the last available for
// PPC so we have to allow it.
static const VersionStruct minFlashVersion = { 10, 1, 102, 64 };
#else
static const VersionStruct minFlashVersion = { 10, 3, 183, 19 };
#endif
// Flash 11 doesn't officially support Gecko 1.9.2, but users on 10.6 and 10.7
// may still have it installed instead of Flash 10.3.
static const VersionStruct minUnsupportedFlashVersion = { 11, 2, 202, 235 };

// Given a version string, parses it according to the common major.minor.bugfix
// format. Any component not present (or not parsable) will be set to 0.
static void ParseVersion(NSString* version, VersionStruct* components)
{
  NSArray* versionComponents = [version componentsSeparatedByString:@"."];
  int count = [versionComponents count];
  components->major = count > 0 ?
      [[versionComponents objectAtIndex:0] intValue] : 0;
  components->minor = count > 1 ?
      [[versionComponents objectAtIndex:1] intValue] : 0;
  components->bugfix = count > 2 ?
      [[versionComponents objectAtIndex:2] intValue] : 0;
  components->build = count > 3 ?
      [[versionComponents objectAtIndex:3] intValue] : 0;
}

// Returns YES if |version| is older than |target|
static BOOL IsOlder(const VersionStruct& version, const VersionStruct& target)
{
  return (version.major < target.major ||
          (version.major == target.major && version.minor < target.minor) ||
          (version.major == target.major && version.minor == target.minor &&
           version.bugfix < target.bugfix) ||
          (version.major == target.major && version.minor == target.minor &&
           version.bugfix == target.bugfix && version.build < target.build));
}

NS_IMPL_ISUPPORTS1(PluginBlocklistService, nsIBlocklistService)

NS_IMETHODIMP PluginBlocklistService::IsAddonBlocklisted(const nsAString & id,
                                                         const nsAString & version,
                                                         const nsAString & appVersion,
                                                         const nsAString & toolkitVersion,
                                                         PRBool *_retval NS_OUTPARAM)
{
  return NS_ERROR_NOT_IMPLEMENTED;
}

NS_IMETHODIMP PluginBlocklistService::GetAddonBlocklistState(const nsAString & id,
                                                             const nsAString & version,
                                                             const nsAString & appVersion,
                                                             const nsAString & toolkitVersion,
                                                             PRUint32 *_retval NS_OUTPARAM)
{
  return NS_ERROR_NOT_IMPLEMENTED;
}

NS_IMETHODIMP PluginBlocklistService::GetPluginBlocklistState(nsIPluginTag *plugin,
                                                              const nsAString & appVersion,
                                                              const nsAString & toolkitVersion,
                                                              PRUint32 *_retval NS_OUTPARAM)
{
  *_retval = nsIBlocklistService::STATE_NOT_BLOCKED;

  nsCAutoString nameAutoString;
  plugin->GetName(nameAutoString);
  NSString* name = [NSString stringWithUTF8String:nameAutoString.get()];
  nsCAutoString versionAutoString;
  plugin->GetVersion(versionAutoString);
  NSString* versionString =
      [NSString stringWithUTF8String:versionAutoString.get()];
  VersionStruct version;
  ParseVersion(versionString, &version);

  BOOL blocked = NO;
  if ([name hasPrefix:kPluginNameFlash]) {
    // Unless the user allows dangerous plugins, disable versions of Flash with
    // known security vulnerabilities.
    BOOL prefLoaded = NO;
    BOOL allowDangerousPlugins = [[PreferenceManager sharedInstanceDontCreate]
        getBooleanPref:kGeckoPrefAllowDangerousPlugins withSuccess:&prefLoaded];
    if (prefLoaded && !allowDangerousPlugins) {
      blocked = IsOlder(version, minFlashVersion);
      if (!blocked && version.major > minFlashVersion.major)
        blocked = IsOlder(version, minUnsupportedFlashVersion);
    }

    // Flash 9 leaks file handles on every instantiation.
    if (version.major == 9)
      blocked = YES;
  }
  else if ([name hasPrefix:kPluginNameFlip4Mac]) {
    // 2.3.0 - 2.3.5 load content synchronously, causing long hangs.
    if (version.major == 2 && version.minor == 3 && version.bugfix <= 5)
      blocked = YES;
    else {
      // Pre-2.2.1 moves the graphics origin, corrupting all Gecko drawing.
      VersionStruct minAllowed = { 2, 2, 1, 0 };
      blocked = IsOlder(version, minAllowed);
    }
  }
  else if ([name hasPrefix:kPluginNameAdobePDFNPAPI]) {
    // Newer Acrobat Reader versions automatically install an incompatible PDF
    // plug-in.
    blocked = YES;
  }

  if (blocked) {
    *_retval = nsIBlocklistService::STATE_BLOCKED;
    return NS_OK;
  }

  // We are (ab)using blocklist service to work around the fact that we
  // sometimes nuke pluginreg.dat, which stores enable/disable data. When
  // plugin info is rebuilt each plugin's block state is checked, so we use
  // that opportunity to re-disable plugins the user has disabled (by returing
  // SOFTBLOCKED, which the plugin system handles by disabling).
  if ([[PreferenceManager sharedInstanceDontCreate]
          pluginShouldBeDisabled:nameAutoString.get()])
  {
    *_retval = nsIBlocklistService::STATE_SOFTBLOCKED;
  }

  return NS_OK;
}

