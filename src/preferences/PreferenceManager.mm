/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* ***** BEGIN LICENSE BLOCK *****
 * Version: NPL 1.1/GPL 2.0/LGPL 2.1
 *
 * The contents of this file are subject to the Netscape Public License
 * Version 1.1 (the "License"); you may not use this file except in
 * compliance with the License. You may obtain a copy of the License at
 * http://www.mozilla.org/NPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Original Code is mozilla.org code.
 *
 * The Initial Developer of the Original Code is 
 * Netscape Communications Corporation.
 * Portions created by the Initial Developer are Copyright (C) 2002
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *
 * Alternatively, the contents of this file may be used under the terms of
 * either the GNU General Public License Version 2 or later (the "GPL"), or 
 * the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
 * in which case the provisions of the GPL or the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of either the GPL or the LGPL, and not to allow others to
 * use your version of this file under the terms of the NPL, indicate your
 * decision by deleting the provisions above and replace them with the notice
 * and other provisions required by the GPL or the LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the NPL, the GPL or the LGPL.
 *
 * ***** END LICENSE BLOCK ***** */

#import <Cocoa/Cocoa.h>
#import <Cocoa/Cocoa.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import "CHPreferenceManager.h"
#include "nsIServiceManager.h"
#include "nsIProfile.h"
#include "nsIPref.h"
#include "nsIPrefService.h"
#include "nsString.h"
#include "nsEmbedAPI.h"


#ifdef _BUILD_STATIC_BIN
#include "nsStaticComponent.h"
nsresult PR_CALLBACK
app_getModuleInfo(nsStaticModuleInfo **info, PRUint32 *count);
#endif

@implementation CHPreferenceManager


+ (CHPreferenceManager *) sharedInstance {
  static CHPreferenceManager *sSharedInstance = nil;
	return ( sSharedInstance ? sSharedInstance : (sSharedInstance = [[[CHPreferenceManager alloc] init] autorelease] ));
}


- (id) init
{
    if ((self = [super init])) {
        if ([self initInternetConfig] == NO) {
            // XXXw. throw here
            NSLog (@"Failed to initialize Internet Config.\n");
        }
        if ([self initMozillaPrefs] == NO) {
            // XXXw. throw here too
            NSLog (@"Failed to initialize mozilla prefs.\n");
        }
    }
    return self;
}

- (void) dealloc
{
    nsresult rv;
    ICStop (internetConfig);
    nsCOMPtr<nsIPrefService> pref(do_GetService(NS_PREF_CONTRACTID, &rv));
    if (!NS_FAILED(rv))
        pref->SavePrefFile(nsnull);
    [super dealloc];
}

- (BOOL) initInternetConfig
{
    OSStatus error;
    error = ICStart (&internetConfig, '????');
    if (error != noErr) {
        // XXX throw here?
        NSLog(@"Error initializing IC.\n");
        return NO;
    }
    return YES;
}

- (BOOL) initMozillaPrefs
{
    NSString *path = [[[NSBundle mainBundle] executablePath] stringByDeletingLastPathComponent];
    setenv("MOZILLA_FIVE_HOME", [path fileSystemRepresentation], 1);

    nsresult rv;

#ifdef _BUILD_STATIC_BIN
    // Initialize XPCOM's module info table
    NSGetStaticModuleInfo = app_getModuleInfo;
#endif

    rv = NS_InitEmbedding(nsnull, nsnull);
    if (NS_FAILED(rv)) {
      printf("Embedding init failed.\n");
      return NO;
    }
    
    nsCOMPtr<nsIProfile> profileService(do_GetService(NS_PROFILE_CONTRACTID, &rv));
    if (NS_FAILED(rv))
        return NO;
    
    nsAutoString newProfileName(NS_LITERAL_STRING("Chimera"));
    PRBool profileExists = PR_FALSE;
    rv = profileService->ProfileExists(newProfileName.get(), &profileExists);
    if (NS_FAILED(rv))
        return NO;

    if (!profileExists) {
        rv = profileService->CreateNewProfile(newProfileName.get(), nsnull, nsnull, PR_FALSE);
        if (NS_FAILED(rv))
            return NO;
    }

    rv = profileService->SetCurrentProfile(newProfileName.get());
    if (NS_FAILED(rv)) {
      if (rv == NS_ERROR_FILE_ACCESS_DENIED) {
        //horrible, horrible, bad, fixed strings.  need localization string file.
        NSString *alert = NSLocalizedString(@"AlreadyRunningAlert",@"");
        NSString *message = NSLocalizedString(@"AlreadyRunningMsg",@"");
        NSString *quit = NSLocalizedString(@"AlreadyRunningButton",@"");
        NSRunAlertPanel(alert,message,quit,nil,nil);
        [NSApp terminate:self];
      }
      return NO;
    }

    [self syncMozillaPrefs];
    return YES;
}

- (void) syncMozillaPrefs
{
    CFArrayRef cfArray;
    CFDictionaryRef cfDictionary;
    CFNumberRef cfNumber;
    CFStringRef cfString;
    char strbuf[1024];
    int numbuf;
    NSString *string;

    nsCOMPtr<nsIPref> prefs(do_GetService(NS_PREF_CONTRACTID));
    if (!prefs) {
        // XXXw. throw?
        return;
    }

    // get home page from Internet Config
    string = [self getICStringPref:kICWWWHomePage];
    if (string) {
        prefs->SetCharPref("browser.startup.homepage", [string cString]);
    }

    // get proxies from SystemConfiguration
    prefs->SetIntPref("network.proxy.type", 0); // 0 == no proxies
    prefs->ClearUserPref("network.proxy.http");
    prefs->ClearUserPref("network.proxy.http_port");
    prefs->ClearUserPref("network.proxy.ssl");
    prefs->ClearUserPref("network.proxy.ssl_port");
    prefs->ClearUserPref("network.proxy.ftp");
    prefs->ClearUserPref("network.proxy.ftp_port");
    prefs->ClearUserPref("network.proxy.gopher");
    prefs->ClearUserPref("network.proxy.gopher_port");
    prefs->ClearUserPref("network.proxy.socks");
    prefs->ClearUserPref("network.proxy.socks_port");
    prefs->ClearUserPref("network.proxy.no_proxies_on");

    if ((cfDictionary = SCDynamicStoreCopyProxies (NULL)) != NULL) {
        if (CFDictionaryGetValueIfPresent (cfDictionary, kSCPropNetProxiesHTTPEnable, (const void **)&cfNumber) == TRUE) {
            if (CFNumberGetValue (cfNumber, kCFNumberIntType, &numbuf) == TRUE && numbuf == 1) {
                if (CFDictionaryGetValueIfPresent (cfDictionary, kSCPropNetProxiesHTTPProxy, (const void **)&cfString) == TRUE) {
                    if (CFStringGetCString (cfString, strbuf, sizeof(strbuf)-1, kCFStringEncodingASCII) == TRUE) {
                        prefs->SetCharPref("network.proxy.http", strbuf);
                    }
                    if (CFDictionaryGetValueIfPresent (cfDictionary, kSCPropNetProxiesHTTPPort, (const void **)&cfNumber) == TRUE) {
                        if (CFNumberGetValue (cfNumber, kCFNumberIntType, &numbuf) == TRUE) {
                            prefs->SetIntPref("network.proxy.http_port", numbuf);
                        }
                        prefs->SetIntPref("network.proxy.type", 1);
                    }
                }
            }
        }
        if (CFDictionaryGetValueIfPresent (cfDictionary, kSCPropNetProxiesHTTPSEnable, (const void **)&cfNumber) == TRUE) {
            if (CFNumberGetValue (cfNumber, kCFNumberIntType, &numbuf) == TRUE && numbuf == 1) {
                if (CFDictionaryGetValueIfPresent (cfDictionary, kSCPropNetProxiesHTTPSProxy, (const void **)&cfString) == TRUE) {
                    if (CFStringGetCString (cfString, strbuf, sizeof(strbuf)-1, kCFStringEncodingASCII) == TRUE) {
                        prefs->SetCharPref("network.proxy.ssl", strbuf);
                    }
                    if (CFDictionaryGetValueIfPresent (cfDictionary, kSCPropNetProxiesHTTPSPort, (const void **)&cfNumber) == TRUE) {
                        if (CFNumberGetValue (cfNumber, kCFNumberIntType, &numbuf) == TRUE) {
                            prefs->SetIntPref("network.proxy.ssl_port", numbuf);
                        }
                        prefs->SetIntPref("network.proxy.type", 1);
                    }
                }
            }
        }
        if (CFDictionaryGetValueIfPresent (cfDictionary, kSCPropNetProxiesFTPEnable, (const void **)&cfNumber) == TRUE) {
            if (CFNumberGetValue (cfNumber, kCFNumberIntType, &numbuf) == TRUE && numbuf == 1) {
                if (CFDictionaryGetValueIfPresent (cfDictionary, kSCPropNetProxiesFTPProxy, (const void **)&cfString) == TRUE) {
                    if (CFStringGetCString (cfString, strbuf, sizeof(strbuf)-1, kCFStringEncodingASCII) == TRUE) {
                        prefs->SetCharPref("network.proxy.ftp", strbuf);
                    }
                    if (CFDictionaryGetValueIfPresent (cfDictionary, kSCPropNetProxiesFTPPort, (const void **)&cfNumber) == TRUE) {
                        if (CFNumberGetValue (cfNumber, kCFNumberIntType, &numbuf) == TRUE) {
                            prefs->SetIntPref("network.proxy.ftp_port", numbuf);
                        }
                        prefs->SetIntPref("network.proxy.type", 1);
                    }
                }
            }
        }
        if (CFDictionaryGetValueIfPresent (cfDictionary, kSCPropNetProxiesGopherEnable, (const void **)&cfNumber) == TRUE) {
            if (CFNumberGetValue (cfNumber, kCFNumberIntType, &numbuf) == TRUE && numbuf == 1) {
                if (CFDictionaryGetValueIfPresent (cfDictionary, kSCPropNetProxiesGopherProxy, (const void **)&cfString) == TRUE) {
                    if (CFStringGetCString (cfString, strbuf, sizeof(strbuf)-1, kCFStringEncodingASCII) == TRUE) {
                        prefs->SetCharPref("network.proxy.gopher", strbuf);
                    }
                    if (CFDictionaryGetValueIfPresent (cfDictionary, kSCPropNetProxiesGopherPort, (const void **)&cfNumber) == TRUE) {
                        if (CFNumberGetValue (cfNumber, kCFNumberIntType, &numbuf) == TRUE) {
                            prefs->SetIntPref("network.proxy.gopher_port", numbuf);
                        }
                        prefs->SetIntPref("network.proxy.type", 1);
                    }
                }
            }
        }
        if (CFDictionaryGetValueIfPresent (cfDictionary, kSCPropNetProxiesSOCKSEnable, (const void **)&cfNumber) == TRUE) {
            if (CFNumberGetValue (cfNumber, kCFNumberIntType, &numbuf) == TRUE && numbuf == 1) {
                if (CFDictionaryGetValueIfPresent (cfDictionary, kSCPropNetProxiesSOCKSProxy, (const void **)&cfString) == TRUE) {
                    if (CFStringGetCString (cfString, strbuf, sizeof(strbuf)-1, kCFStringEncodingASCII) == TRUE) {
                        prefs->SetCharPref("network.proxy.socks", strbuf);
                    }
                    if (CFDictionaryGetValueIfPresent (cfDictionary, kSCPropNetProxiesSOCKSPort, (const void **)&cfNumber) == TRUE) {
                        if (CFNumberGetValue (cfNumber, kCFNumberIntType, &numbuf) == TRUE) {
                            prefs->SetIntPref("network.proxy.socks_port", numbuf);
                        }
                        prefs->SetIntPref("network.proxy.type", 1);
                    }
                }
            }
        }
        if (CFDictionaryGetValueIfPresent (cfDictionary, kSCPropNetProxiesExceptionsList, (const void **)&cfArray) == TRUE) {
            cfString = CFStringCreateByCombiningStrings (NULL, cfArray, CFSTR(", "));
            if (CFStringGetLength (cfString) > 0) {
                if (CFStringGetCString (cfString, strbuf, sizeof(strbuf)-1, kCFStringEncodingASCII) == TRUE) {
                    prefs->SetCharPref("network.proxy.no_proxies_on", strbuf);
                }
            }
        }
        CFRelease (cfDictionary);
    }
}

//- (BOOL) getICBoolPref:(ConstStr255Param) prefKey;
//{
//    ICAttr dummy;
//    OSStatus error;
//    SInt32 size;
//    Boolean buf;

//    error = ICGetPref (internetConfig, prefKey, &dummy, &buf, &size);
//    if (error == noErr && buf)
//        return YES;
//    else
//        return NO;
// }

- (NSString *) getICStringPref:(ConstStr255Param) prefKey;
{
    NSString *string;
    ICAttr dummy;
    OSStatus error;
    SInt32 size = 256;
    char *buf;

    do {
        if ((buf = malloc ((unsigned int)size)) == NULL) {
            NSLog (@"malloc failed in [PreferenceManager getICStringPref].");
            return nil;
        }
        error = ICGetPref (internetConfig, prefKey, &dummy, buf, &size);
        if (error != noErr && error != icTruncatedErr) {
            free (buf);
            NSLog (@"[IC error %d in [PreferenceManager getICStringPref].\n", (int) error);
            return nil;
        }
        size *= 2;
    } while (error == icTruncatedErr);
    if (*buf == 0) {
        NSLog (@"ICGetPref returned empty string.");
        free (buf);
        return nil;
    }
    CopyPascalStringToC ((ConstStr255Param) buf, buf);
    string = [NSString stringWithCString:buf];
    free (buf);
    return string;
}


- (NSString *) homePage:(BOOL)checkStartupPagePref
{
  nsCOMPtr<nsIPref> prefs(do_GetService(NS_PREF_CONTRACTID));
  if (!prefs)
    return @"about:blank";

  NSString *url = nil;
  PRInt32 mode = 1;
  
  // In some cases, we need to check browser.startup.page to see if
  // we want to use the homepage or if the user wants a blank window.
  // mode 0 is blank page, mode 1 is home page. 2 is "last page visited"
  // but we don't care about that. Default to 1 unless |checkStartupPagePref|
  // is true.
  nsresult rv = NS_OK;
  if ( checkStartupPagePref )
    rv = prefs->GetIntPref("browser.startup.page", &mode);
  if (NS_FAILED(rv) || mode == 1) {
      char *buf = nsnull;
      prefs->GetCharPref("browser.startup.homepage", &buf);
      if (buf && *buf)
          url = [NSString stringWithCString:buf];
      else
          url = @"about:blank";
      free (buf);
      return url;
  }
  else
      return @"about:blank";
}

@end

