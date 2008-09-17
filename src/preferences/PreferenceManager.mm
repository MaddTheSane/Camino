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
 * The Original Code is mozilla.org code.
 *
 * The Initial Developer of the Original Code is
 * Netscape Communications Corporation.
 * Portions created by the Initial Developer are Copyright (C) 2002
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *   Bruce Davidson <Bruce.Davidson@ipl.com>
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

#import <SystemConfiguration/SystemConfiguration.h>

#import <Sparkle/Sparkle.h>

#import "NSArray+Utils.h"
#import "NSString+Gecko.h"
#import "NSWorkspace+Utils.h"

#import "PreferenceManager.h"
#import "AppDirServiceProvider.h"
#import "UserDefaults.h"
#import "CHBrowserService.h"
#import "CHISupportsOwner.h"
#import "CmXULAppInfo.h"

#include "nsString.h"
#include "nsCRT.h"
#include "nsWeakReference.h"
#include "nsIServiceManager.h"
#include "nsIObserver.h"
#include "nsProfileDirServiceProvider.h"
#include "nsIPref.h"
#include "nsIPrefService.h"
#include "nsIPrefBranch2.h"
#include "nsEmbedAPI.h"
#include "nsAppDirectoryServiceDefs.h"
#include "nsIStyleSheetService.h"
#include "nsNetUtil.h"
#include "nsStaticComponents.h"
#include "nsILocalFileMac.h"
#include "nsDirectoryServiceDefs.h"
#include "nsINIParser.h"

#define CUSTOM_PROFILE_DIR  "CAMINO_PROFILE_DIR"

NSString* const kPrefChangedNotificationName = @"PrefChangedNotification";
// userInfo entries:
NSString* const kPrefChangedPrefNameUserInfoKey = @"pref_name";


static NSString* const AdBlockingChangedNotificationName = @"AdBlockingChanged";
static NSString* const kFlashBlockChangedNotificationName = @"FlashBlockChanged";

// This is an arbitrary version stamp that gets written to the prefs file.
// It can be used to detect when a new version of Camino is run that needs
// some prefs to be upgraded.
static const PRInt32 kCurrentPrefsVersion = 1;

// CheckCompatibility and WriteVersion are based on the versions in
// toolkit/xre/nsAppRunner.cpp.  This is done to provide forward
// compatibility in anticipation of Camino-on-XULRunner.

#define FILE_COMPATIBILITY_INFO NS_LITERAL_CSTRING("compatibility.ini")

static PRBool
CheckCompatibility(nsIFile* aProfileDir, const nsACString& aVersion,
                   const nsACString& aOSABI, nsIFile* aAppDir)
{
  nsCOMPtr<nsIFile> file;
  aProfileDir->Clone(getter_AddRefs(file));
  if (!file)
    return PR_FALSE;
  file->AppendNative(FILE_COMPATIBILITY_INFO);

  nsINIParser parser;
  nsCOMPtr<nsILocalFile> localFile(do_QueryInterface(file));
  nsresult rv = parser.Init(localFile);
  if (NS_FAILED(rv))
    return PR_FALSE;

  nsCAutoString buf;
  rv = parser.GetString("Compatibility", "LastVersion", buf);
  if (NS_FAILED(rv))
    return PR_FALSE;

  if (!aVersion.Equals(buf))
    return PR_FALSE;

  rv = parser.GetString("Compatibility", "LastOSABI", buf);
  if (NS_FAILED(rv))
    return PR_FALSE;

  if (!aOSABI.Equals(buf))
    return PR_FALSE;

  if (aAppDir) {
    rv = parser.GetString("Compatibility", "LastAppDir", buf);
    if (NS_FAILED(rv))
      return PR_FALSE;

    nsCOMPtr<nsILocalFile> lf;

    rv = NS_NewNativeLocalFile(buf, PR_FALSE,
                               getter_AddRefs(lf));
    if (NS_FAILED(rv))
      return PR_FALSE;

    PRBool eq;
    rv = lf->Equals(aAppDir, &eq);
    if (NS_FAILED(rv) || !eq)
      return PR_FALSE;
  }

  return PR_TRUE;
}

static void
WriteVersion(nsIFile* aProfileDir, const nsACString& aVersion,
             const nsACString& aOSABI, nsIFile* aAppDir)
{
  nsCOMPtr<nsIFile> file;
  aProfileDir->Clone(getter_AddRefs(file));
  if (!file)
    return;
  file->AppendNative(FILE_COMPATIBILITY_INFO);

  nsCOMPtr<nsILocalFile> lf = do_QueryInterface(file);

  nsCAutoString appDir;
  if (aAppDir)
    aAppDir->GetNativePath(appDir);

  PRFileDesc* fd = nsnull;
  lf->OpenNSPRFileDesc(PR_WRONLY | PR_CREATE_FILE | PR_TRUNCATE, 0600, &fd);
  if (!fd) {
    NS_ERROR("could not create output stream");
    return;
  }

  static const char kHeader[] = "[Compatibility]" NS_LINEBREAK
                                "LastVersion=";

  PR_Write(fd, kHeader, sizeof(kHeader) - 1);
  PR_Write(fd, PromiseFlatCString(aVersion).get(), aVersion.Length());

  static const char kOSABIHeader[] = NS_LINEBREAK "LastOSABI=";
  PR_Write(fd, kOSABIHeader, sizeof(kOSABIHeader) - 1);
  PR_Write(fd, PromiseFlatCString(aOSABI).get(), aOSABI.Length());

  static const char kAppDirHeader[] = NS_LINEBREAK "LastAppDir=";
  if (aAppDir) {
    PR_Write(fd, kAppDirHeader, sizeof(kAppDirHeader) - 1);
    PR_Write(fd, appDir.get(), appDir.Length());
  }

  static const char kNL[] = NS_LINEBREAK;
  PR_Write(fd, kNL, sizeof(kNL) - 1);

  PR_Close(fd);
}

@interface PreferenceManager(PreferenceManagerPrivate)

- (void)registerNotificationListener;
- (void)initUpdatePrefs;
- (void)cleanUpObsoletePrefs;

- (void)termEmbedding:(NSNotification*)aNotification;
- (void)xpcomTerminate:(NSNotification*)aNotification;

- (void)showLaunchFailureAndQuitWithErrorTitle:(NSString*)inTitleFormat errorMessage:(NSString*)inMessageFormat;

- (void)setAcceptLanguagesPref;
- (void)setLocalePref;

- (void)configureProxies;
- (BOOL)updateOneProxy:(NSDictionary*)configDict
    protocol:(NSString*)protocol
    proxyEnableKey:(NSString*)enableKey
    proxyURLKey:(NSString*)urlKey
    proxyPortKey:(NSString*)portKey;

- (void)registerForProxyChanges;
- (void)readSystemProxySettings;

- (void)refreshAdBlockingStyleSheet:(BOOL)inLoad;
- (void)refreshFlashBlockStyleSheet:(BOOL)inLoad;
- (void)refreshStyleSheet:(nsIURI *)cssFileURI load:(BOOL)inLoad;
- (BOOL)isFlashBlockAllowed;

- (NSString*)pathForSpecialDirectory:(const char*)specialDirectory;

@end

#pragma mark -

// 
// PrefChangeObserver.
// 
// We create one of these each time someone adds a pref observer
// 
class PrefChangeObserver : public nsIObserver
{
public:
                        PrefChangeObserver(id inObject)  // inObject can be nil
                        : mObject(inObject)
                        {}
                        
  virtual               ~PrefChangeObserver()
                        {}
  
  NS_DECL_ISUPPORTS
  NS_DECL_NSIOBSERVER

  id                    GetObject() const { return mObject; }
  nsresult              RegisterForPref(const char* inPrefName);
  nsresult              UnregisterForPref(const char* inPrefName);

protected:

  id                    mObject;    // not retained
};

NS_IMPL_ISUPPORTS1(PrefChangeObserver, nsIObserver);

nsresult
PrefChangeObserver::RegisterForPref(const char* inPrefName)
{
  nsresult rv;
  nsCOMPtr<nsIPrefBranch2> pbi = do_GetService(NS_PREFSERVICE_CONTRACTID, &rv);
  if (NS_FAILED(rv)) return rv;
  return pbi->AddObserver(inPrefName, this, PR_FALSE);
}

nsresult
PrefChangeObserver::UnregisterForPref(const char* inPrefName)
{
  nsresult rv;
  nsCOMPtr<nsIPrefBranch2> pbi = do_GetService(NS_PREFSERVICE_CONTRACTID, &rv);
  if (NS_FAILED(rv)) return rv;
  return pbi->RemoveObserver(inPrefName, this);
}

NS_IMETHODIMP
PrefChangeObserver::Observe(nsISupports* aSubject, const char* aTopic, const PRUnichar* aSomeData)
{
  if (nsCRT::strcmp(aTopic, "nsPref:changed") != 0)
    return NS_OK;   // not a pref changed notification

  NSDictionary* userInfoDict = [NSDictionary dictionaryWithObject:[NSString stringWithPRUnichars:aSomeData]
                                                           forKey:kPrefChangedPrefNameUserInfoKey];
  
  [[NSNotificationCenter defaultCenter] postNotificationName:kPrefChangedNotificationName
                                                      object:mObject
                                                    userInfo:userInfoDict];
  return NS_OK;
}

// little wrapper for the C++ observer class, which takes care of registering
// and unregistering the observer.
@interface PrefChangeObserverOwner : CHISupportsOwner
{
@private
  NSString*           mPrefName;
}

- (id)initWithPrefName:(NSString*)inPrefName object:(id)inObject;
- (BOOL)hasObject:(id)inObject;

@end

@implementation PrefChangeObserverOwner

- (id)initWithPrefName:(NSString*)inPrefName object:(id)inObject
{
  PrefChangeObserver* changeObserver = new PrefChangeObserver(inObject);
  if ((self = [super initWithValue:(nsISupports*)changeObserver])) {   // retains it
    mPrefName = [inPrefName retain];
    NSLog(@"registering observer %@ on %@", self, mPrefName);
    changeObserver->RegisterForPref([mPrefName UTF8String]);
  }
  return self;
}

- (void)dealloc
{
  NSLog(@"unregistering observer %@ on %@", self, mPrefName);

  PrefChangeObserver* changeObserver = reinterpret_cast<PrefChangeObserver*>([super value]);
  if (changeObserver)
    changeObserver->UnregisterForPref([mPrefName UTF8String]);

  [mPrefName release];
  [super dealloc];
}

- (BOOL)hasObject:(id)inObject
{
  PrefChangeObserver* changeObserver = reinterpret_cast<PrefChangeObserver*>([super value]);
  return (changeObserver && (changeObserver->GetObject() == inObject));
}

@end

#pragma mark -

@implementation PreferenceManager

static PreferenceManager* gSharedInstance = nil;
#if DEBUG
static BOOL gMadePrefManager;
#endif

+ (PreferenceManager*)sharedInstance
{
  if (!gSharedInstance) {
#if DEBUG
    if (gMadePrefManager)
      NSLog(@"Recreating preferences manager on shutdown!");
    gMadePrefManager = YES;
#endif
    gSharedInstance = [[PreferenceManager alloc] init];
  }
    
  return gSharedInstance;
}

+ (PreferenceManager*)sharedInstanceDontCreate
{
  return gSharedInstance;
}

- (id)init
{
  if ((self = [super init])) {
    mRunLoopSource = NULL;
    
    [self registerNotificationListener];

    if ([self initMozillaPrefs] == NO) {
      // we should never get here
      NSLog (@"Failed to initialize mozilla prefs");
    }

    [self initUpdatePrefs];
    [self cleanUpObsoletePrefs];
    
    mDefaults = [NSUserDefaults standardUserDefaults];
  }
  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  if (self == gSharedInstance)
    gSharedInstance = nil;

  [mProfilePath release];
  [super dealloc];
}

- (void)termEmbedding:(NSNotification*)aNotification
{
  NS_IF_RELEASE(mPrefs);
  // remove our runloop observer
  if (mRunLoopSource) {
    CFRunLoopRemoveSource(CFRunLoopGetCurrent(), mRunLoopSource, kCFRunLoopCommonModes);
    CFRelease(mRunLoopSource);
    mRunLoopSource = NULL;
  }
}

- (void)xpcomTerminate:(NSNotification*)aNotification
{
  [mPrefChangeObservers release];
  mPrefChangeObservers = nil;

  // this will notify observers that the profile is about to go away.
  if (mProfileProvider) {
      mProfileProvider->Shutdown();
      // directory service holds a strong ref to this as well.
      NS_RELEASE(mProfileProvider);
  }

  // save prefs now, in case any termination listeners set prefs.
  [self savePrefsFile];

  [gSharedInstance release];
}

- (void)registerNotificationListener
{
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(termEmbedding:)
                                               name:TermEmbeddingNotificationName
                                             object:nil];

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(xpcomTerminate:)
                                               name:XPCOMShutDownNotificationName
                                             object:nil];

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(adBlockingPrefChanged:)
                                               name:AdBlockingChangedNotificationName
                                             object:nil];

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(flashBlockPrefChanged:)
                                               name:kFlashBlockChangedNotificationName
                                             object:nil];
}

- (void)savePrefsFile
{
  nsCOMPtr<nsIPrefService> prefsService = do_GetService(NS_PREF_CONTRACTID);
  if (prefsService)
      prefsService->SavePrefFile(nsnull);
}

- (void)showLaunchFailureAndQuitWithErrorTitle:(NSString*)inTitleFormat errorMessage:(NSString*)inMessageFormat
{
  NSString* applicationName = NSLocalizedStringFromTable(@"CFBundleName", @"InfoPlist", nil);
  
  NSString* errorString   = [NSString stringWithFormat:inTitleFormat, applicationName];
  NSString* messageString = [NSString stringWithFormat:inMessageFormat, applicationName];

  NSRunAlertPanel(errorString, messageString, NSLocalizedString(@"QuitButtonText", @""), nil, nil);
  [NSApp terminate:self];
}

- (BOOL)initMozillaPrefs
{
    nsresult rv;

    NSString* path = [[[NSBundle mainBundle] executablePath] stringByDeletingLastPathComponent];
    const char* binDirPath = [path fileSystemRepresentation];
    nsCOMPtr<nsILocalFile> binDir;
    rv = NS_NewNativeLocalFile(nsDependentCString(binDirPath), PR_TRUE, getter_AddRefs(binDir));
    if (NS_FAILED(rv)) {
      [self showLaunchFailureAndQuitWithErrorTitle:NSLocalizedString(@"StartupFailureAlert", @"")
                                      errorMessage:NSLocalizedString(@"StartupFailureBinPathMsg", @"")];
      // not reached
      return NO;
    }

    // This shouldn't be needed since we are initing XPCOM with this
    // directory but causes a (harmless) warning if not defined.
    setenv("MOZILLA_FIVE_HOME", binDirPath, 1);
    
    // Check for a custom profile, first from -profile, then in the environment.
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    const char* customProfilePath = [[defaults stringForKey:USER_DEFAULTS_PROFILE_KEY] fileSystemRepresentation];
    if (!customProfilePath)
      customProfilePath = getenv(CUSTOM_PROFILE_DIR);
    
    // Based on whether a custom path is set, figure out what the
    // profile path should be.
    const char* profileDirectory;
    BOOL isCustomProfile = NO;
    if (!customProfilePath) {
      // If it isn't, we then check the 'mozProfileDirName' key in our Info.plist file
      // and use the regular Application Support/<mozProfileDirName>, and Caches/<mozProfileDirName> 
      // folders.
      NSString* dirString = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"mozProfileDirName"];
      if (dirString)
        profileDirectory = [dirString fileSystemRepresentation];
      else {
        NSLog(@"mozNewProfileDirName key missing from Info.plist file. Using default profile directory");
        profileDirectory = "Camino";
      }
      isCustomProfile = NO;
    }
    else {
      // If we have a custom profile path, let's just use that.
      profileDirectory = customProfilePath;
      isCustomProfile = YES;
    }
    
    // Supply our own directory service provider so we can control where
    // the registry and profiles are located.
    AppDirServiceProvider* provider = new AppDirServiceProvider(profileDirectory, isCustomProfile);
    
    if (!provider) {
      [self showLaunchFailureAndQuitWithErrorTitle:NSLocalizedString(@"StartupFailureAlert", @"")
                                      errorMessage:NSLocalizedString(@"StartupFailureMsg", @"")];
      // not reached
      return NO;
    }

    nsCOMPtr<nsIDirectoryServiceProvider> dirProvider = (nsIDirectoryServiceProvider*)provider;

    const char* executablePath = [[[NSBundle mainBundle] executablePath] fileSystemRepresentation];
    nsCOMPtr<nsILocalFile> executable;
    NS_NewNativeLocalFile(nsDependentCString(executablePath),
                          PR_TRUE, getter_AddRefs(executable));

    nsCOMPtr<nsIFile> profileDir;
    PRBool bogus = PR_FALSE;
    rv = dirProvider->GetFile(NS_APP_USER_PROFILES_ROOT_DIR, &bogus,
                              getter_AddRefs(profileDir));
    if (NS_FAILED(rv)) {
      [self showLaunchFailureAndQuitWithErrorTitle:NSLocalizedString(@"StartupFailureAlert", @"")
                                      errorMessage:NSLocalizedString(@"StartupFailureProfilePathMsg", @"")];
      // not reached
      return NO;
    }

    nsCAutoString version;
    version.Assign([[XULAppInfo version] UTF8String]);
    version.Append('_');
    version.Append([[XULAppInfo appBuildID] UTF8String]);
    version.Append('/');
    version.Append([[XULAppInfo platformVersion] UTF8String]);
    version.Append('_');
    version.Append([[XULAppInfo platformBuildID] UTF8String]);

#ifdef __ppc__
    NS_NAMED_LITERAL_CSTRING(osABI, "Darwin_ppc-gcc3");
#else
#ifdef __i386__
    NS_NAMED_LITERAL_CSTRING(osABI, "Darwin_x86-gcc3");
#else
    NS_NAMED_LITERAL_CSTRING(osABI, "Darwin_UNKNOWN");
#endif
#endif

    PRBool versionOK = CheckCompatibility(profileDir, version, osABI, executable);

    if (!versionOK) {
      // This isn't the same version that previously used the selected
      // profile.  Remove some caches from the profile, allowing them to
      // be regenerated.  NS_InitEmbedding will reregister components,
      // producing compreg.dat and xpti.dat.  Note that this occurs prior
      // to any profile lock check, because it's inconvenient to move the
      // profile lock check up.  However, doing things this way should be
      // harmless.  Note that WriteVersion isn't called until after the
      // profile lock check.
      nsCOMPtr<nsIFile> file;
      profileDir->Clone(getter_AddRefs(file));
      if (file) {
        const char* kVolatileProfileFiles[] = {
          "compatibility.ini",
          "compreg.dat",
          "xpti.dat",
          "XUL.mfasl",
          nsnull
        };

        // dummy name, will be replaced with real filenames from the list above
        file->AppendNative(NS_LITERAL_CSTRING("M"));

        const char** filenames = kVolatileProfileFiles;
        const char* filename;
        while ((filename = *filenames)) {
          file->SetNativeLeafName(nsDependentCString(filename));
          file->Remove(PR_FALSE);
          filenames++;
        }
      }
    }

    rv = NS_InitEmbedding(binDir, dirProvider,
                          kPStaticModules, kStaticModuleCount);
    if (NS_FAILED(rv)) {
      NSLog(@"Embedding init failed.");
      [self showLaunchFailureAndQuitWithErrorTitle:NSLocalizedString(@"StartupFailureAlert", @"")
                                      errorMessage:NSLocalizedString(@"StartupFailureInitEmbeddingMsg", @"")];
      // not reached
      return NO;
    }
    
    NSString* profilePath = [self profilePath];
    if (!profilePath) {
      NSLog(@"Failed to determine profile path!");
      [self showLaunchFailureAndQuitWithErrorTitle:NSLocalizedString(@"StartupFailureAlert", @"")
                                      errorMessage:NSLocalizedString(@"StartupFailureProfilePathMsg", @"")];
      // not reached
      return NO;
    }

    rv = NS_NewProfileDirServiceProvider(PR_TRUE, &mProfileProvider);
    if (NS_FAILED(rv)) {
      [self showLaunchFailureAndQuitWithErrorTitle:NSLocalizedString(@"StartupFailureAlert", @"")
                                      errorMessage:NSLocalizedString(@"StartupFailureMsg", @"")];
      
      // not reached
      return NO;
    }
    mProfileProvider->Register();

    rv = mProfileProvider->SetProfileDir(profileDir);
    if (NS_FAILED(rv)) {
      if (rv == NS_ERROR_FILE_ACCESS_DENIED) {
        [self showLaunchFailureAndQuitWithErrorTitle:NSLocalizedString(@"AlreadyRunningAlert", @"")
                                        errorMessage:NSLocalizedString(@"AlreadyRunningMsg", @"")];
      }
      else {
        [self showLaunchFailureAndQuitWithErrorTitle:NSLocalizedString(@"StartupFailureAlert", @"")
                                        errorMessage:NSLocalizedString(@"StartupFailureProfileSetupMsg", @"")];
      }
      // not reached
      return NO;
    }

    nsCOMPtr<nsIPref> prefs(do_GetService(NS_PREF_CONTRACTID));
    if (!prefs) {
      [self showLaunchFailureAndQuitWithErrorTitle:NSLocalizedString(@"StartupFailureAlert", @"")
                                      errorMessage:NSLocalizedString(@"StartupFailureNoPrefsMsg", @"")];
      // not reached
      return NO;
    }
    
    mPrefs = prefs;
    NS_ADDREF(mPrefs);
    
    [self syncMozillaPrefs];

    if (!versionOK)
      WriteVersion(profileDir, version, osABI, executable);

    // send out initted notification
    [[NSNotificationCenter defaultCenter] postNotificationName:InitEmbeddingNotificationName object:nil];

    return YES;
}

- (void)initUpdatePrefs
{
  // If the Camino 1.6-style settings are in place, upgrade to the new method.
  NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
  if ([defaults objectForKey:SUScheduledCheckIntervalKey]) {
    BOOL wasEnabled = [defaults integerForKey:SUScheduledCheckIntervalKey] > 0;
    [defaults removeObjectForKey:SUScheduledCheckIntervalKey];
    if (wasEnabled)
      [defaults removeObjectForKey:SUEnableAutomaticChecksKey];
    else
      [defaults setBool:NO forKey:SUEnableAutomaticChecksKey];
  }

  // If updates are disabled for this build, don't bother setting up the manifest URL.
  NSBundle* mainBundle = [NSBundle mainBundle];
  if (![[mainBundle objectForInfoDictionaryKey:SUEnableAutomaticChecksKey] boolValue])
    return;

  // Get the base auto-update manifest URL
  NSString* baseURL = [self getStringPref:kGeckoPrefUpdateURLOverride
                              withSuccess:NULL];
  if (![baseURL length])
    baseURL = [self getStringPref:kGeckoPrefUpdateURL withSuccess:NULL];

  NSString* manifestURL = @"";
  if ([baseURL length]) {
    // Append the parameters we might be interested in.
    NSString* intlUAString = [self getStringPref:kGeckoPrefUserAgentMultiLangAddition
                                     withSuccess:NULL];
    NSArray* languages = [mainBundle localizations];
    NSString* currentLanguage = [[NSBundle preferredLocalizationsFromArray:languages] firstObject];
    if (currentLanguage)
      currentLanguage = [NSLocale canonicalLocaleIdentifierFromString:currentLanguage];
    else
      currentLanguage = @"en";
    manifestURL = [NSString stringWithFormat:@"%@?os=%@&arch=%@&version=%@&intl=%d&lang=%@",
                   baseURL,
                   [NSWorkspace osVersionString],
#if defined(__ppc__)
                   @"ppc",
#elif defined(__i386__)
                   @"x86",
#else
#error Unknown Architecture
#endif
                   [mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"],
                   ([intlUAString length] ? 1 : 0),
                   currentLanguage];
  }
  [defaults setObject:manifestURL forKey:SUFeedURLKey];
}

- (void)cleanUpObsoletePrefs
{
  NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
  
  // remove old 0.8-era toolbar configuration prefs that are no longer functional
  [defaults removeObjectForKey:@"NSToolbar Configuration preferences.toolbar"];
  
  // Avoid the General Prefs missing-icon problem for users who have migrated to 1.6+
  // from older versions who had changed the toolbar display prefs (with the now-removed widget).
  // When the widget was used to change the toolbar configuration, it saved the bundle IDs
  // of the pref panes. When an ID changed, the stale data in the plist caused missing icons.
  // Turns out we don't need the bundle IDs at all, so just delete them from the plist.
  NSMutableDictionary* prefsToolbarConfiguration = [[[defaults objectForKey:@"NSToolbar Configuration preferences.toolbar.1"] mutableCopy] autorelease];

  [prefsToolbarConfiguration removeObjectForKey:@"TB Item Identifiers"];
  [defaults setObject:prefsToolbarConfiguration forKey:@"NSToolbar Configuration preferences.toolbar.1"];
}

// Convert an Apple locale (or language with the dialect specified) from the form en_GB
// to the en-gb form required for HTTP accept-language headers.
// If the locale isn't in the expected form we return nil. (Systems upgraded
// from 10.1 report human readable locales (e.g. "English")).
+ (NSString*)convertLocaleToHTTPLanguage:(NSString*)inAppleLocale
{
    NSString* r = nil;
    if (inAppleLocale) {
      NSMutableString* language = [NSMutableString string];
      NSArray* localeParts = [inAppleLocale componentsSeparatedByString:@"_"];

      [language appendString:[localeParts objectAtIndex:0]];
      if ([localeParts count] > 1) {
        [language appendString:@"-"];
        [language appendString:[[localeParts objectAtIndex:1] lowercaseString]];
      }

      // We accept standalone primary subtags (e.g. "en") and also
      // a primary subtag with additional subtags of between two and eight characters long
      // We ignore i- and x- primary subtags
      if ([language length] == 2 ||
          ([language length] >= 5 && [language length] <= 13 && [language characterAtIndex:2] == '-'))
        r = [NSString stringWithString:language];
    }
    return r;
}

- (void)syncMozillaPrefs
{
  if (!mPrefs) {
    NSLog(@"Mozilla prefs not set up successfully");
    return;
  }

  PRInt32 lastRunPrefsVersion = 0;
  mPrefs->GetIntPref("camino.prefs_version", &lastRunPrefsVersion);
  mLastRunPrefsVersion = lastRunPrefsVersion;

  // Prior to pref version 1, we had the universal charset detector on, but
  // turned it off since it didn't work well enough.
  if (mLastRunPrefsVersion < 1)
    mPrefs->SetCharPref("intl.charset.detector", "");

  mPrefs->SetIntPref("camino.prefs_version", kCurrentPrefsVersion);

  // fix up the cookie prefs. If 'p3p' or 'accept foreign cookies' are on,
  // remap them to something that chimera can deal with.
  PRInt32 acceptCookies = 0;
  static const char* kCookieBehaviorPref = kGeckoPrefCookieDefaultAcceptPolicy;
  mPrefs->GetIntPref(kCookieBehaviorPref, &acceptCookies);
  if (acceptCookies == 3) {     // p3p, assume all cookies on
    acceptCookies = kCookieAcceptAll;
    mPrefs->SetIntPref(kCookieBehaviorPref, acceptCookies);
  }

  [self configureProxies];

  [self setAcceptLanguagesPref];
  [self setLocalePref];

  // load up the default stylesheet (is this the best place to do this?)
  if ([self getBooleanPref:kGeckoPrefBlockAds withSuccess:NULL])
    [self refreshAdBlockingStyleSheet:YES];

  // Load flashblock if enabled.  Test dependencies to avoid conflicts
  BOOL flashBlockAllowed = [self isFlashBlockAllowed];	
  if (flashBlockAllowed && [self getBooleanPref:kGeckoPrefBlockFlash withSuccess:NULL])
    [self refreshFlashBlockStyleSheet:YES];

  // Make sure the homepage has been set up.
  nsCOMPtr<nsIPrefBranch> prefBranch = do_QueryInterface(mPrefs);
  if (prefBranch) {
    PRInt32 homepagePrefExists;
    if (NS_FAILED(prefBranch->PrefHasUserValue(kGeckoPrefHomepageURL, &homepagePrefExists)) || !homepagePrefExists) {
      NSString* defaultHomepage = NSLocalizedStringFromTable(@"HomePageDefault", @"WebsiteDefaults", nil);
      // Check that we actually got a sane value back before storing it.
      if (![defaultHomepage isEqualToString:@"HomePageDefault"])
        [self setPref:kGeckoPrefHomepageURL toString:defaultHomepage];
    }
  }
}

- (void)setAcceptLanguagesPref
{
  // Determine if the user specified their own language override. If so
  // use it. If not work out the languages from the system preferences.
  BOOL userProvidedLangOverride = NO;
  NSString* userLanguageOverride = [self getStringPref:kGeckoPrefAcceptLanguagesOverride
                                           withSuccess:&userProvidedLangOverride];

  if (userProvidedLangOverride && [userLanguageOverride length] > 0)
    [self setPref:kGeckoPrefAcceptLanguages toString:userLanguageOverride];
  else {
    NSUserDefaults* defs = [NSUserDefaults standardUserDefaults];
    NSArray* languages = [defs objectForKey:@"AppleLanguages"];
    NSMutableArray* acceptableLanguages = [NSMutableArray array];

    // Build the list of languages the user understands (from System Preferences | International).
    BOOL languagesOkaySoFar = YES;
    int indexOfGenericEnglish = -1;
    BOOL englishDialectExists = NO;
    for (unsigned int i = 0; languagesOkaySoFar && i < [languages count]; ++i) {
      NSString* language = [PreferenceManager convertLocaleToHTTPLanguage:[languages objectAtIndex:i]];
      if (language) {
        [acceptableLanguages addObject:language];
        if ((indexOfGenericEnglish == -1) && !englishDialectExists &&
            [language isEqualToString:@"en"])
          indexOfGenericEnglish = i;
        else if (!englishDialectExists && [language hasPrefix:@"en-"])
          englishDialectExists = YES;
      }
      else {
        // If we don't understand a language don't set any, rather than risk
        // leaving the user with their n'th choice (which may be one Apple made
        // and they don't actually read). Mainly occurs on systems upgraded
        // from 10.1, see convertLocaleToHTTPLanguage().
        NSLog(@"Unable to set languages - language '%@' not a valid ISO language identifier",
              [languages objectAtIndex:i]);
        languagesOkaySoFar = NO;
      }
    }

    // Some servers will disregard a generic 'en', causing a fallback to a
    // subsequent language (see bug 300905). So if the user has only a generic
    // 'en', convert it to 'en-US', 'en'.
    if ((indexOfGenericEnglish != -1) && !englishDialectExists)
      [acceptableLanguages insertObject:@"en-US" atIndex:indexOfGenericEnglish];

    // If we understood all the languages in the list set the accept-language
    // header. Note that necko will determine quality factors itself.
    if (languagesOkaySoFar && [acceptableLanguages count] > 0) {
      // Gecko will only assign 10 unique qualilty factors, and duplicate
      // quality factors breaks the user's ordering (which combined with the
      // 'en' issue above and the fact that Apple's default list has well over
      // 10 languages means the wrong thing can happen with a default list).
      if ([acceptableLanguages count] > 10) {
        NSRange dropRange = NSMakeRange(10, [acceptableLanguages count] - 10);
        [acceptableLanguages removeObjectsInRange:dropRange];
      }
      NSString* acceptLangHeader = [acceptableLanguages componentsJoinedByString:@","];
      [self setPref:kGeckoPrefAcceptLanguages toString:acceptLangHeader];
    }
    else {
      // Fall back to the "en-us, en" default from all-camino.js - clear
      // any existing user pref
      [self clearPref:kGeckoPrefAcceptLanguages];
    }
  }
}

- (void)setLocalePref
{
  // Use the user-selected pref for the user agent locale if it exists
  NSString* uaLocale = [self getStringPref:kGeckoPrefUserAgentLocaleOverride
                               withSuccess:NULL];

  if (![uaLocale length]) {
    // Find the active localization nib's name and make sure it's in
    // ab or ab-CD form
    NSArray* localizations = [[NSBundle mainBundle] preferredLocalizations];
    if ([localizations count]) {
      CFStringRef activeLocalization =
        ::CFLocaleCreateCanonicalLocaleIdentifierFromString(
            NULL, (CFStringRef)[localizations objectAtIndex:0]);
      if (activeLocalization) {
        uaLocale = [PreferenceManager
                     convertLocaleToHTTPLanguage:(NSString*)activeLocalization];
        ::CFRelease(activeLocalization);
      }
    }
  }

  if (uaLocale && [uaLocale length]) {
    [self setPref:kGeckoPrefUserAgentLocale toString:uaLocale];
  }
  else {
    NSLog(@"Unable to determine user interface locale\n");
    // Fall back to the "en-US" default from all.js.  Clear any existing
    // user pref.
    [self clearPref:kGeckoPrefUserAgentLocale];
  }
}

#pragma mark -

- (void)configureProxies
{
  [self readSystemProxySettings];
  [self registerForProxyChanges];
}

static void SCProxiesChangedCallback(SCDynamicStoreRef store, CFArrayRef changedKeys, void* /* info */)
{
  PreferenceManager* prefsManager = [PreferenceManager sharedInstanceDontCreate];
  [prefsManager readSystemProxySettings];
#if DEBUG
  NSLog(@"Updating proxies");
#endif
}

- (void)registerForProxyChanges
{
  if (mRunLoopSource)   // don't register twice
    return;

  SCDynamicStoreContext context = {0, NULL, NULL, NULL, NULL};

  SCDynamicStoreRef dynamicStoreRef = SCDynamicStoreCreate(NULL, CFSTR("ChimeraProxiesNotification"), SCProxiesChangedCallback, &context);
  if (dynamicStoreRef) {
    CFStringRef proxyIdentifier = SCDynamicStoreKeyCreateProxies(NULL);
    CFArrayRef  keyList = CFArrayCreate(NULL, (const void**)&proxyIdentifier, 1, &kCFTypeArrayCallBacks);

    Boolean set = SCDynamicStoreSetNotificationKeys(dynamicStoreRef, keyList, NULL);
    if (set) {
      mRunLoopSource = SCDynamicStoreCreateRunLoopSource(NULL, dynamicStoreRef, 0);
      if (mRunLoopSource) {
        CFRunLoopAddSource(CFRunLoopGetCurrent(), mRunLoopSource, kCFRunLoopCommonModes);
        // we keep the ref to the source, so that we can remove it when the prefs manager is cleaned up.
      }
    }
    
    CFRelease(proxyIdentifier);
    CFRelease(keyList);
    CFRelease(dynamicStoreRef);
  }
}

- (BOOL)updateOneProxy:(NSDictionary*)configDict
  protocol:(NSString*)protocol
  proxyEnableKey:(NSString*)enableKey
  proxyURLKey:(NSString*)urlKey
  proxyPortKey:(NSString*)portKey
{
  BOOL gotProxy = NO;

  BOOL enabled = (BOOL)[[configDict objectForKey:enableKey] intValue];
  if (enabled) {
    NSString* protocolProxy = [configDict objectForKey:urlKey];
    int proxyPort = [[configDict objectForKey:portKey] intValue];
    if ([protocolProxy length] > 0 && proxyPort != 0) {
      [self setPref:[[NSString stringWithFormat:@"network.proxy.%@", protocol] UTF8String] toString:protocolProxy];
      [self setPref:[[NSString stringWithFormat:@"network.proxy.%@_port", protocol] UTF8String] toInt:proxyPort];
      gotProxy = YES;
    }
  }
  
  return gotProxy;
}

typedef enum EProxyConfig {
  eProxyConfig_Direct = 0,
  eProxyConfig_Manual,
  eProxyConfig_PAC,
  eProxyConfig_Direct4x,
  eProxyConfig_WPAD,
  eProxyConfig_Last
} EProxyConfig;

- (void)readSystemProxySettings
{
  // if the user has set kGeckoPrefProxyUsesSystemSettings to false, they want
  // to specify their own proxies (or a PAC), so don't read the OS proxy settings
  if (![self getBooleanPref:kGeckoPrefProxyUsesSystemSettings withSuccess:NULL])
    return;
  
  PRInt32 curProxyType, newProxyType;
  mPrefs->GetIntPref("network.proxy.type", &curProxyType);
  newProxyType = curProxyType;

  mPrefs->ClearUserPref("network.proxy.http");
  mPrefs->ClearUserPref("network.proxy.http_port");
  mPrefs->ClearUserPref("network.proxy.ssl");
  mPrefs->ClearUserPref("network.proxy.ssl_port");
  mPrefs->ClearUserPref("network.proxy.ftp");
  mPrefs->ClearUserPref("network.proxy.ftp_port");
  mPrefs->ClearUserPref("network.proxy.gopher");
  mPrefs->ClearUserPref("network.proxy.gopher_port");
  mPrefs->ClearUserPref("network.proxy.socks");
  mPrefs->ClearUserPref("network.proxy.socks_port");
  mPrefs->ClearUserPref(kGeckoPrefProxyBypassList);

  // get proxies from SystemConfiguration
  NSDictionary* proxyConfigDict = (NSDictionary*)SCDynamicStoreCopyProxies(NULL);
  if (proxyConfigDict) {
    // look for PAC
    NSNumber* proxyAutoConfig = (NSNumber*)[proxyConfigDict objectForKey:(NSString*)kSCPropNetProxiesProxyAutoConfigEnable];
    NSString* proxyURLString  = (NSString*)[proxyConfigDict objectForKey:(NSString*)kSCPropNetProxiesProxyAutoConfigURLString];
    if ([proxyAutoConfig intValue] != 0 && [proxyURLString length] > 0) {
      NSLog(@"Using Proxy Auto-Config (PAC) file %@", proxyURLString);
      [self setPref:kGeckoPrefProxyAutoconfigURL toString:proxyURLString];
      newProxyType = eProxyConfig_PAC;
    }
    else {
      BOOL gotAProxy = NO;
      
      gotAProxy |= [self updateOneProxy:proxyConfigDict protocol:@"http"
                              proxyEnableKey:(NSString*)kSCPropNetProxiesHTTPEnable
                                 proxyURLKey:(NSString*)kSCPropNetProxiesHTTPProxy
                                proxyPortKey:(NSString*)kSCPropNetProxiesHTTPPort];

      gotAProxy |= [self updateOneProxy:proxyConfigDict protocol:@"ssl"
                              proxyEnableKey:(NSString*)kSCPropNetProxiesHTTPSEnable
                                 proxyURLKey:(NSString*)kSCPropNetProxiesHTTPSProxy
                                proxyPortKey:(NSString*)kSCPropNetProxiesHTTPSPort];

      gotAProxy |= [self updateOneProxy:proxyConfigDict protocol:@"ftp"
                              proxyEnableKey:(NSString*)kSCPropNetProxiesFTPEnable
                                 proxyURLKey:(NSString*)kSCPropNetProxiesFTPProxy
                                proxyPortKey:(NSString*)kSCPropNetProxiesFTPPort];

      gotAProxy |= [self updateOneProxy:proxyConfigDict protocol:@"gopher"
                              proxyEnableKey:(NSString*)kSCPropNetProxiesGopherEnable
                                 proxyURLKey:(NSString*)kSCPropNetProxiesGopherProxy
                                proxyPortKey:(NSString*)kSCPropNetProxiesGopherPort];
      
      gotAProxy |= [self updateOneProxy:proxyConfigDict protocol:@"socks"
                              proxyEnableKey:(NSString*)kSCPropNetProxiesSOCKSEnable
                                 proxyURLKey:(NSString*)kSCPropNetProxiesSOCKSProxy
                                proxyPortKey:(NSString*)kSCPropNetProxiesSOCKSPort];

      if (gotAProxy) {
        newProxyType = eProxyConfig_Manual;

        NSArray* exceptions = [proxyConfigDict objectForKey:(NSString*)kSCPropNetProxiesExceptionsList];
        if (exceptions) {
          NSString* sitesList = [exceptions componentsJoinedByString:@", "];
          if ([sitesList length] > 0)
            [self setPref:kGeckoPrefProxyBypassList toString:sitesList];
        }
      }
      else {
        // no proxy hosts found; turn them off
        newProxyType = eProxyConfig_Direct;
      }
    }
    
    [proxyConfigDict release];
  }

  if (newProxyType != curProxyType)
    mPrefs->SetIntPref("network.proxy.type", newProxyType);
}

#pragma mark -

- (void)adBlockingPrefChanged:(NSNotification*)inNotification
{
  BOOL adBlockingEnabled = [self getBooleanPref:kGeckoPrefBlockAds withSuccess:NULL];
  [self refreshAdBlockingStyleSheet:adBlockingEnabled];
}

- (void)flashBlockPrefChanged:(NSNotification*)inNotification
{
  BOOL allowed = [self isFlashBlockAllowed];
 
  BOOL flashBlockEnabled = allowed && [self getBooleanPref:kGeckoPrefBlockFlash withSuccess:NULL];
  [self refreshFlashBlockStyleSheet:flashBlockEnabled];
}

// this will reload the sheet if it's already registered, or unload it if the 
// param is NO
- (void)refreshAdBlockingStyleSheet:(BOOL)inLoad
{
  // the the uri of the sheet in our bundle
  NSString* cssFilePath = [[NSBundle mainBundle] pathForResource:@"ad_blocking" ofType:@"css"];
  if (![[NSFileManager defaultManager] isReadableFileAtPath:cssFilePath]) {
    NSLog(@"ad_blocking.css file not found; ad blocking will be disabled");
    return;
  }
  
  nsresult rv;
  nsCOMPtr<nsILocalFile> cssFile;
  rv = NS_NewNativeLocalFile(nsDependentCString([cssFilePath fileSystemRepresentation]), PR_TRUE, getter_AddRefs(cssFile));
  if (NS_FAILED(rv))
    return;
  
  nsCOMPtr<nsIURI> cssFileURI;
  rv = NS_NewFileURI(getter_AddRefs(cssFileURI), cssFile);
  if (NS_FAILED(rv))
    return;
  
  [self refreshStyleSheet:cssFileURI load:inLoad];
}

// this will reload the flashblock sheet if it's already registered, or unload it if the 
// param is NO
- (void)refreshFlashBlockStyleSheet:(BOOL)inLoad
{
  // the the uri of the flashblock sheet in the chrome path
  nsCOMPtr<nsIURI> cssFileURI;
  nsresult rv = NS_NewURI(getter_AddRefs(cssFileURI), "chrome://flashblock/content/flashblock.css");
  if (NS_FAILED(rv))
    return; 

  [self refreshStyleSheet:cssFileURI load:inLoad];
}

- (void)refreshStyleSheet:(nsIURI *)cssFileURI load:(BOOL)inLoad
{
  nsCOMPtr<nsIStyleSheetService> ssService = do_GetService("@mozilla.org/content/style-sheet-service;1");
  if (!ssService)
    return;

  PRBool alreadyRegistered = PR_FALSE;
  ssService->SheetRegistered(cssFileURI, nsIStyleSheetService::USER_SHEET, &alreadyRegistered);
  if (alreadyRegistered)
    ssService->UnregisterSheet(cssFileURI, nsIStyleSheetService::USER_SHEET);
  
  if (inLoad)
    ssService->LoadAndRegisterSheet(cssFileURI, nsIStyleSheetService::USER_SHEET);
}

#pragma mark -

- (NSString*)getStringPref:(const char*)prefName withSuccess:(BOOL*)outSuccess
{
  NSString* prefValue = @"";

  char* buf = nsnull;
  nsresult rv = NS_ERROR_FAILURE;
  if (mPrefs)
    rv = mPrefs->GetCharPref(prefName, &buf);

  if (NS_SUCCEEDED(rv) && buf) {
    // prefs are UTF-8
    prefValue = [NSString stringWithUTF8String:buf];
    free(buf);
    if (outSuccess) *outSuccess = YES;
  } else {
    if (outSuccess) *outSuccess = NO;
  }
  
  return prefValue;
}

- (NSColor*)getColorPref:(const char*)prefName withSuccess:(BOOL*)outSuccess
{
  // colors are stored in HTML-like #FFFFFF strings
  NSString* colorString = [self getStringPref:prefName withSuccess:outSuccess];
  NSColor*  returnColor = [NSColor blackColor];

  if ([colorString hasPrefix:@"#"] && [colorString length] == 7) {
    unsigned int redInt, greenInt, blueInt;
    sscanf([colorString UTF8String], "#%02x%02x%02x", &redInt, &greenInt, &blueInt);
    
    float redFloat    = ((float)redInt / 255.0);
    float greenFloat  = ((float)greenInt / 255.0);
    float blueFloat   = ((float)blueInt / 255.0);
    
    returnColor = [NSColor colorWithCalibratedRed:redFloat green:greenFloat blue:blueFloat alpha:1.0f];
    if (outSuccess) *outSuccess = YES;
  }
  else {
    if (outSuccess) *outSuccess = NO;
  }

  return returnColor;
}

- (BOOL)getBooleanPref:(const char*)prefName withSuccess:(BOOL*)outSuccess
{
  PRBool boolPref = PR_FALSE;
  nsresult rv = NS_ERROR_FAILURE;
  if (mPrefs)
    rv = mPrefs->GetBoolPref(prefName, &boolPref);

  if (outSuccess)
    *outSuccess = NS_SUCCEEDED(rv);

  return boolPref ? YES : NO;
}

- (int)getIntPref:(const char*)prefName withSuccess:(BOOL*)outSuccess
{
  PRInt32 intPref = 0;
  nsresult rv = NS_ERROR_FAILURE;
  if (mPrefs)
    rv = mPrefs->GetIntPref(prefName, &intPref);

  if (outSuccess)
    *outSuccess = NS_SUCCEEDED(rv);

  return intPref;
}

- (void)setPref:(const char*)prefName toString:(NSString*)value
{
  if (mPrefs)
    (void)mPrefs->SetCharPref(prefName, [value UTF8String]);
}

- (void)setPref:(const char*)prefName toInt:(int)value
{
  if (mPrefs)
    (void)mPrefs->SetIntPref(prefName, (PRInt32)value);
}

- (void)setPref:(const char*)prefName toBoolean:(BOOL)value
{
  if (mPrefs)
    (void)mPrefs->SetBoolPref(prefName, value ? PR_TRUE : PR_FALSE);
}

- (void)clearPref:(const char*)prefName
{
  if (mPrefs)
    (void)mPrefs->ClearUserPref(prefName);
}

- (NSString*)homePageUsingStartPage:(BOOL)checkStartupPagePref
{
  if (!mPrefs)
    return @"about:blank";

  // If |checkStartupPagePref|, always return the homepage, otherwise check the
  // user's pref for new windows.
  BOOL success = NO;
  int mode = kStartPageHome;
  if (checkStartupPagePref)
    mode = [self getIntPref:kGeckoPrefNewWindowStartPage withSuccess:&success];

  if (!success || mode == kStartPageHome) {
    NSString* homepagePref = [self getStringPref:kGeckoPrefHomepageURL withSuccess:NULL];
    if (!homepagePref)
      homepagePref = NSLocalizedStringFromTable(@"HomePageDefault", @"WebsiteDefaults", nil);

    if (homepagePref && [homepagePref length] > 0 && ![homepagePref isEqualToString:@"HomePageDefault"])
      return homepagePref;
  }
  
  return @"about:blank";
}

//
// -profilePath
//
// Returns the path for our post 0.8 profiles.
// We no longer have distinct profiles. The profile dir is the same as
// NS_APP_USER_PROFILES_ROOT_DIR - imposed by our own AppDirServiceProvider. Will
// return |nil| if there is a problem.
//
- (NSString*)profilePath
{
  if (!mProfilePath)
    mProfilePath = [[self pathForSpecialDirectory:NS_APP_USER_PROFILES_ROOT_DIR] retain];

  return mProfilePath;
}

- (NSString*)cacheParentDirPath
{
  return [self pathForSpecialDirectory:NS_APP_CACHE_PARENT_DIR];
}

- (NSString*)downloadDirectoryPath
{
  return [self pathForSpecialDirectory:NS_MAC_DEFAULT_DOWNLOAD_DIR];
}

- (NSString*)pathForSpecialDirectory:(const char*)specialDirectory
{
  nsCOMPtr<nsIFile> directoryFile;
  nsresult rv = NS_GetSpecialDirectory(specialDirectory,
                                       getter_AddRefs(directoryFile));
  if (NS_FAILED(rv))
    return nil;
  nsCAutoString nativePath;
  rv = directoryFile->GetNativePath(nativePath);
  if (NS_FAILED(rv))
    return nil;
  return [NSString stringWithUTF8String:nativePath.get()];
}

- (void)addObserver:(id)inObject forPref:(const char*)inPrefName
{
  if (!mPrefChangeObservers)
    mPrefChangeObservers = [[NSMutableDictionary alloc] initWithCapacity:4];

  NSString* prefName = [NSString stringWithUTF8String:inPrefName];

  // get the array of pref observers for this pref
  NSMutableArray* existingObservers = [mPrefChangeObservers objectForKey:prefName];
  if (!existingObservers) {
    existingObservers = [NSMutableArray arrayWithCapacity:1];
    [mPrefChangeObservers setObject:existingObservers forKey:prefName];
  }

  // look for an existing observer with this target object
  NSEnumerator* observersEnum = [existingObservers objectEnumerator];
  PrefChangeObserverOwner* curValue;
  while ((curValue = [observersEnum nextObject])) {
    if ([curValue hasObject:inObject])
      return;   // found it; nothing to do
  }

  // if it doesn't exist, make one
  PrefChangeObserverOwner* observerOwner = [[PrefChangeObserverOwner alloc] initWithPrefName:prefName object:inObject];
  [existingObservers addObject:observerOwner];    // takes ownership
  [observerOwner release];
}

- (void)removeObserver:(id)inObject
{
  NSEnumerator* observerArraysEnum = [mPrefChangeObservers objectEnumerator];
  NSMutableArray* curArray;
  while ((curArray = [observerArraysEnum nextObject])) {
    // look for an existing observer with this target object
    NSEnumerator* observersEnum = [curArray objectEnumerator];
    PrefChangeObserverOwner* prefObserverOwner = nil;
    
    PrefChangeObserverOwner* curValue;
    while ((curValue = [observersEnum nextObject])) {
      if ([curValue hasObject:inObject]) {
        prefObserverOwner = curValue;
        break;
      }
    }
    
    if (prefObserverOwner)
      [curArray removeObjectIdenticalTo:prefObserverOwner];   // this should release it and unregister the observer
  }
}

- (void)removeObserver:(id)inObject forPref:(const char*)inPrefName
{
  NSString* prefName = [NSString stringWithUTF8String:inPrefName];

  NSMutableArray* existingObservers = [mPrefChangeObservers objectForKey:prefName];
  if (!existingObservers)
    return;

  // look for an existing observer with this target object
  NSEnumerator* observersEnum = [existingObservers objectEnumerator];
  PrefChangeObserverOwner* prefObserverOwner = nil;
  
  PrefChangeObserverOwner* curValue;
  while ((curValue = [observersEnum nextObject])) {
    if ([curValue hasObject:inObject]) {
      prefObserverOwner = curValue;
      break;
    }
  }
  
  if (prefObserverOwner)
    [existingObservers removeObjectIdenticalTo:prefObserverOwner];   // this should release it and unregister the observer
}

//
// isFlashBlockAllowed
//
// Checks whether FlashBlock can be enabled
// FlashBlock only allowed if javascript and plug-ins enabled
// NOTE: This code is duplicated in WebFeatures.mm since the FlashBlock checkbox
// settings are done by WebFeatures and stylesheet loading is done by PreferenceManager
//
-(BOOL) isFlashBlockAllowed
{
  BOOL gotPref = NO;
  BOOL jsEnabled = [self getBooleanPref:kGeckoPrefEnableJavascript withSuccess:&gotPref] && gotPref;
  BOOL pluginsEnabled = [self getBooleanPref:kGeckoPrefEnablePlugins withSuccess:&gotPref] || !gotPref;

  return jsEnabled && pluginsEnabled;
}

@end
