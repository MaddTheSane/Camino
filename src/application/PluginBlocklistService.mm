/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* ***** BEGIN LICENSE BLOCK *****
 * Version: MPL 1.1/GPL 2.0/LGPL 2.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Original Code is Camino code.
 *
 * The Initial Developer of the Original Code is
 * Stuart Morgan.
 * Portions created by the Initial Developer are Copyright (C) 2011
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *   Stuart Morgan <stuart.morgan@alumni.case.edu>
 *
 * Alternatively, the contents of this file may be used under the terms of
 * either the GNU General Public License Version 2 or later (the "GPL"), or
 * the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
 * in which case the provisions of the GPL or the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of either the GPL or the LGPL, and not to allow others to
 * use your version of this file under the terms of the MPL, indicate your
 * decision by deleting the provisions above and replace them with the notice
 * and other provisions required by the GPL or the LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the MPL, the GPL or the LGPL.
 *
 * ***** END LICENSE BLOCK ***** */

#include "PluginBlocklistService.h"

#import <Foundation/Foundation.h>

#import "PreferenceManager.h"

#include "nsIPluginTag.h"
#include "nsString.h"

static NSString* const kPluginNameFlash = @"Shockwave Flash";
static NSString* const kPluginNameFlip4Mac = @"Flip4Mac";

struct VersionStruct {
  int major;
  int minor;
  int bugfix;
};

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
}

// Returns YES if |version| is older than |target|
static BOOL IsOlder(const VersionStruct& version, const VersionStruct& target)
{
  return (version.major < target.major ||
          (version.major == target.major && version.minor < target.minor) ||
          (version.major == target.major && version.minor == target.minor &&
           version.bugfix < target.bugfix));
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
      VersionStruct minAllowed = { 2, 2, 1 };
      blocked = IsOlder(version, minAllowed);
    }
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

