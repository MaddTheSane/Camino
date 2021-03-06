/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Foundation/Foundation.h>

#pragma GCC visibility push(default)

#pragma mark Tab Behavior

// Controls whether the tab bar is show even when there is only one tab.
extern const char* const kGeckoPrefAlwaysShowTabBar;                   // bool

// Controls the load behavior of URLs loaded from external applications.
extern const char* const kGeckoPrefExternalLoadBehavior;               // int
// Possible values:
extern const int kExternalLoadOpensNewWindow;
extern const int kExternalLoadOpensNewTab;
extern const int kExternalLoadReusesWindow;

// Controls whether middle/command-clicking opens a tab instead of a window
extern const char* const kGeckoPrefOpenTabsForMiddleClick;             // bool

// Controls whether user-opened tabs open in the background (i.e., don't focus)
extern const char* const kGeckoPrefOpenTabsInBackground;               // bool

// Controls where links that would open new windows open.
extern const char* const kGeckoPrefSingleWindowModeTargetBehavior;     // int
// Posible values:
extern const int kSingleWindowModeUseDefault;
extern const int kSingleWindowModeUseCurrentTab;
extern const int kSingleWindowModeUseNewTab;
extern const int kSingleWindowModeUseNewWindow;

// Controls when kGeckoPrefSingleWindowModeTargetBehavior actually applies
extern const char* const kGeckoPrefSingleWindowModeRestriction;        // int
// Possible values:
extern const int kSingleWindowModeApplyAlways;
extern const int kSingleWindowModeApplyNever;
extern const int kSingleWindowModeApplyOnlyToUnfeatured;

// Controls whether tabs diverted by SWM open in the background
extern const char* const kGeckoPrefSingleWindowModeTabsOpenInBackground; // bool

// Controls whether tab jumpback is enabled
extern const char* const kGeckoPrefEnableTabJumpback;                  // bool

// Controls wheter source is opened in a tab rather than a window
extern const char* const kGeckoPrefViewSourceInTab;                    // bool

#pragma mark Warnings

// Controls whether there is a warning before closing multi-tab windows
extern const char* const kGeckoPrefWarnWhenClosingWindows;             // bool

// Controls whether there is a warning before opening a feed: link
extern const char* const kGeckoPrefWarnBeforeOpeningFeeds;             // bool

// The last version for which the user was warned about possible add-on problems
extern const char* const kGeckoPrefLastAddOnWarningVersion;            // string

#pragma mark Content Control

// Controls whether Javascript is enabled
extern const char* const kGeckoPrefEnableJavascript;                   // bool

// Controls whether Java is enabled
extern const char* const kGeckoPrefEnableJava;                         // bool

// Controls whether plugins are enabled
extern const char* const kGeckoPrefEnablePlugins;                      // bool

// Controls whether plugins known to be insecure are allowed to load
extern const char* const kGeckoPrefAllowDangerousPlugins;              // bool

// Controls which plugins are disabled overall
extern const char* const kGeckoPrefDisabledPluginPrefixes;             // bool

// Controls whether the popup blocker is enabled
extern const char* const kGeckoPrefBlockPopups;                        // bool

// Controls whether ads are blocked
extern const char* const kGeckoPrefBlockAds;                           // bool

// Controls whether Flashblock is enabled
extern const char* const kGeckoPrefBlockFlash;                         // bool

// Controls whether Silverlight is blocked
extern const char* const kGeckoPrefBlockSilverlight;                   // bool

// The whitelist of allowed Flash sites
extern const char* const kGeckoPrefFlashblockWhitelist;                // string

// Controls how animated images are allowed to animate
extern const char* const kGeckoPrefImageAnimationBehavior;             // string
// Possible values:
extern NSString* const kImageAnimationNone;
extern NSString* const kImageAnimationOnce;
extern NSString* const kImageAnimationLoop;

// Controls whether JS window resizing is disabled
extern const char* const kGeckoPrefPreventDOMWindowResize;             // bool

// Controls whether JS window status bar updating is disabled
extern const char* const kGeckoPrefPreventDOMStatusChange;             // bool

// Controls whether JS window reordering is disabled
extern const char* const kGeckoPrefPreventDOMWindowFocus;              // bool

#pragma mark Home Page

// The homepage URL
extern const char* const kGeckoPrefHomepageURL;                        // string

// Controls what page is loaded in new windows
extern const char* const kGeckoPrefNewWindowStartPage;                 // int
// Controls what page is loaded in new tabs
extern const char* const kGeckoPrefNewTabStartPage;                    // int
// Possible values:
extern const int kStartPageBlank;
extern const int kStartPageHome;
// other Mozilla/Firefox values are not implemented in Camino

// Records the last version where the homepage override has been applied
extern const char* const kGeckoPrefNewVersionHomepageOverrideVersion;  // string

#pragma mark Security

// Controls how personal certificates are chosen
extern const char* const kGeckoPrefDefaultCertificateBehavior;         // string
// Possible values:
extern NSString* const kPersonalCertificateSelectAutomatically;
extern NSString* const kPersonalCertificateAlwaysAsk;

// Controls whether passwords are autofilled from the Keychain.
extern const char* const kGeckoPrefUseKeychain;

// Controls whether autocomplete="off" is ignored for password managment
extern const char* const kGeckoPrefIgnoreAutocompleteOff;              // bool

#pragma mark Miscellaneous UI Controls

// Controls whether JS/CSS errors are logged to the console
extern const char* const kGeckoPrefLogJSToConsole;                     // bool

// Controls whether favicons are used in browser chrome
extern const char* const kGeckoPrefEnableFavicons;                     // bool

// Controls whether URL fixup (e.g., search on DNS failure) is enabled
extern const char* const kGeckoPrefEnableURLFixup;                     // bool

// Controls whether Bonjour has been disabled
extern const char* const kGeckoPrefDisableBonjour;                     // bool

// Controls whether the default browser is checked at each launch
extern const char* const kGeckoPrefCheckDefaultBrowserAtLaunch;        // bool

// Controls whether autocomplete is done in a list or in-line
extern const char* const kGeckoPrefInlineLocationBarAutocomplete;      // bool

// Controls whether autocomplete is enabled
extern const char* const kGeckoPrefLocationBarAutocompleteEnabled;     // bool

// Controls whether autocomplete searches titles or just URLs
extern const char* const kGeckoPrefLocationBarAutocompleteFromTitles;  // bool

// Controls whether full content zoom is used, or text scaling
extern const char* const kGeckoPrefFullContentZoom;                    // bool

#pragma mark Keyboard Shortcuts

// Controls the behavior of the backspace/delete key
extern const char* const kGeckoPrefBackspaceAction;                    // int
// Possible values:
extern const int kBackspaceActionBack;
extern const int kBackspaceActionNone;
// paging is not implemented in Camino

// Controls the behavior of tabbing through page elements.
extern const char* const kGeckoPrefTabFocusBehavior;                   // int
// Possible values (note that these are OR-able, not mutually exclusive):
extern const int kTabFocusesTextFields;
extern const int kTabFocusesForms;
extern const int kTabFocusesLinks;

#pragma mark Auto-Update

// The base URL for software update checks
extern const char* const kGeckoPrefUpdateURL;                          // string

// A user-override for kGeckoPrefUpdateURL
extern const char* const kGeckoPrefUpdateURLOverride;                  // string

// Tracks whether we are doing an auto-update relaunch
extern const char* const kGeckoPrefRelaunchingForAutoupdate;           // bool

#pragma mark i18n

// The ranked languages to send in the Accept-Languages header
extern const char* const kGeckoPrefAcceptLanguages;                    // string

// A user override for the automatically-determined kGeckoPrefAcceptLanguages
extern const char* const kGeckoPrefAcceptLanguagesOverride;            // string

// The automatic character set detector to use for unspecified pages
extern const char* const kGeckoPrefCharsetDetector;                    // string
// Possible values:
extern NSString* const kCharsetDetectorNone;
extern NSString* const kCharsetDetectorUniversal;

#pragma mark Session Saving

// Controls whether session restore is enabled for normal relaunches
extern const char* const kGeckoPrefSessionSaveEnabled;                 // bool

// Controls whether session restore is enabled across crashes (for auto-tests)
extern const char* const kGeckoPrefSessionSaveRestoreAfterCrash;       // bool

#pragma mark History

// Controls how many days history is kept for
extern const char* const kGeckoPrefHistoryLifetimeDays;                // int

#pragma mark Cookies

// Controls how cookies are handled by default
extern const char* const kGeckoPrefCookieDefaultAcceptPolicy;          // int
// Possible values:
extern const int kCookieAcceptAll;
extern const int kCookieAcceptFromOriginatingServer;
extern const int kCookieAcceptNone;

// Controls how long cookies last. Also whether or not the user is prompted
// for each cookie, because mashing orthogonal concepts together is fun!
extern const char* const kGeckoPrefCookieLifetimePolicy;               // int
// Possible values:
extern const int kCookieLifetimeNormal;
extern const int kCookieLifetimeAsk;
extern const int kCookieLifetimeSession;

// Controls the state of the "Remember this decision?" checkbox
extern const char* const kGeckoPrefShouldRememberCookieDecision;       // bool

#pragma mark Proxies

// Controls whether the proxy settings are taken from the OS settings
extern const char* const kGeckoPrefProxyUsesSystemSettings;            // bool

// The url of a PAC file to use for proxy settings
extern const char* const kGeckoPrefProxyAutoconfigURL;                 // string

// A list of sites for which the proxy should not be applied
extern const char* const kGeckoPrefProxyBypassList;                    // string

#pragma mark Downloads

// A list of possible download directories
extern const char* const kGeckoPrefDownloadsFolderList;                // int
// Possible values:
extern const int kDownloadsFolderDesktop;
extern const int kDownloadsFolderDownloads;
extern const int kDownloadsFolderCustom;

// If kGeckoPrefsDownloadsFolderList is kDownloadsFolderCustom
extern const char* const kGeckoPrefDownloadsDir;                       // nsILocalFile

// Controls whether downloads should be auto-launched
extern const char* const kGeckoPrefAutoOpenDownloads;                  // bool

// Controls when downloads are removed from the manager
extern const char* const kGeckoPrefDownloadCleanupPolicy;              // int
// Possible values:
extern const int kRemoveDownloadsOnSuccess;
extern const int kRemoveDownloadsOnQuit;
extern const int kRemoveDownloadsManually;

// Controls whether the download manager is focused when a download is started
extern const char* const kGeckoPrefFocusDownloadManagerOnDownload;     // bool

// Controls whether the download manager opens when a download is started
extern const char* const kGeckoPrefOpenDownloadManagerOnDownload;      // bool

// Controls whether the download manager stays open after downloads complete
extern const char* const kGeckoPrefCloseDownloadManagerWhenDone;       // bool

// Controls whether downloads are saved to the Downloads directory
// or prompted for a save location every time
extern const char* const kGeckoPrefDownloadToDefaultLocation;          // bool

#pragma mark Page Appearance

// Controls whether links are underlined by default
extern const char* const kGeckoPrefUnderlineLinks;                     // bool

// Controls whether page-specified fonts should be used
extern const char* const kGeckoPrefUsePageFonts;                       // bool

// The default page background color
extern const char* const kGeckoPrefPageBackgroundColor;                // color

// The default page foreground color
extern const char* const kGeckoPrefPageForegroundColor;                // color

// The default link color
extern const char* const kGeckoPrefLinkColor;                          // color

// The default visited link color
extern const char* const kGeckoPrefVisitedLinkColor;                   // color

// Controls whether <select>s are forced to Aqua instead of honoring author styles
extern const char* const kGeckoPrefForceAquaSelects;                   // bool

#pragma mark User Agent

// The application version to use in the user agent
extern const char* const kGeckoPrefUserAgentAppVersion;                // string

// The locale to use in the user agent
extern const char* const kGeckoPrefUserAgentLocale;                    // string

// A user override for the automatically-determined kGeckoPrefUserAgentLocale
extern const char* const kGeckoPrefUserAgentLocaleOverride;            // string

// An extra suffix for the user agent identifying the multilingual build
extern const char* const kGeckoPrefUserAgentMultiLangAddition;         // string

#pragma mark Safe Browsing

extern NSString* const kGeckoPrefSafeBrowsingDataProviderName;          // string
extern NSString* const kGeckoPrefSafeBrowsingDataProviderUpdateURL;     // string
extern NSString* const kGeckoPrefSafeBrowsingDataProviderKeyURL;        // string
extern NSString* const kGeckoPrefSafeBrowsingDataProviderGetHashURL;    // string

extern NSString* const kGeckoPrefSafeBrowsingDataProviderReportPhishingURL;      // string
extern NSString* const kGeckoPrefSafeBrowsingDataProviderReportPhishingErrorURL; // string
extern NSString* const kGeckoPrefSafeBrowsingDataProviderReportMalwareURL;       // string
extern NSString* const kGeckoPrefSafeBrowsingDataProviderReportMalwareErrorURL;  // string

extern const char* const kGeckoPrefSafeBrowsingInformationURL;          // string
extern const char* const kGeckoPrefSafeBrowsingPhishingCheckingEnabled; // bool
extern const char* const kGeckoPrefSafeBrowsingMalwareCheckingEnabled;  // bool
extern const char* const kGeckoPrefSafeBrowsingDataProvider;            // int

extern const char* const kGeckoPrefSafeBrowsingSendToURLAfterReporting; // string

#pragma mark Obsolete Downloads Prefs
// These prefs are all obsolete as of Camino 2.0.

// Formerly controlled when downloads were removed from the manager
extern const char* const kOldGeckoPrefDownloadCleanupPolicy;           // int
// Possible values:
extern const int kOldRemoveDownloadsManually;
extern const int kOldRemoveDownloadsOnQuit;
extern const int kOldRemoveDownloadsOnSuccess;

// Formerly controlled whether the manager would open on download (iff closed)
extern const char* const kOldGeckoPrefFocusDownloadManagerOnDownload;  // bool

// Formerly controlled whether manager stayed open after downloads completed
extern const char* const kOldGeckoPrefLeaveDownloadManagerOpen;        // bool

// Formerly controlled whether to use default downloads directory
extern const char* const kOldGeckoPrefDownloadToDefaultLocation;       // bool

// Formerly controlled whether to process downloads with helper apps
extern const char* const kOldGeckoPrefAutoOpenDownloads;               // bool

#pragma mark Obsolete Tab Behavior

// Controlled the load behavior of URLs loaded from external applications, prior
// to Camino 2.1.
extern const char* const kOldGeckoPrefExternalLoadBehavior;            // int
// Possible values:
extern const int kOldExternalLoadReusesWindow;

#pragma GCC visibility pop
