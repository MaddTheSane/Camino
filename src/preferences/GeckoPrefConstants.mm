/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "GeckoPrefConstants.h"

#import "nsIBrowserDOMWindow.h"

// Xcode 2.x's ld likes to dead-strip symbols that the pref panes need.
asm(".no_dead_strip _kGeckoPrefLinkColor");
asm(".no_dead_strip _kGeckoPrefPageBackgroundColor");
asm(".no_dead_strip _kGeckoPrefPageForegroundColor");
asm(".no_dead_strip _kGeckoPrefUnderlineLinks");
asm(".no_dead_strip _kGeckoPrefUsePageFonts");
asm(".no_dead_strip _kGeckoPrefVisitedLinkColor");
asm(".no_dead_strip _kGeckoPrefCookieLifetimePolicy");
asm(".no_dead_strip _kGeckoPrefDownloadsFolderList");
asm(".no_dead_strip _kGeckoPrefDownloadsDir");
asm(".no_dead_strip _kGeckoPrefDefaultCertificateBehavior");
asm(".no_dead_strip _kGeckoPrefBlockPopups");
asm(".no_dead_strip _kGeckoPrefEnableJava");
asm(".no_dead_strip _kGeckoPrefImageAnimationBehavior");
asm(".no_dead_strip _kGeckoPrefPreventDOMStatusChange");
asm(".no_dead_strip _kGeckoPrefPreventDOMWindowFocus");
asm(".no_dead_strip _kGeckoPrefPreventDOMWindowResize");
asm(".no_dead_strip _kGeckoPrefTabFocusBehavior");
asm(".no_dead_strip _kGeckoPrefUseKeychain");
asm(".no_dead_strip _kStartPageBlank");
asm(".no_dead_strip _kStartPageHome");
asm(".no_dead_strip _kPersonalCertificateAlwaysAsk");
asm(".no_dead_strip _kPersonalCertificateSelectAutomatically");
asm(".no_dead_strip _kExternalLoadOpensNewWindow");
asm(".no_dead_strip _kExternalLoadOpensNewTab");
asm(".no_dead_strip _kExternalLoadReusesWindow");
asm(".no_dead_strip _kSingleWindowModeUseDefault");
asm(".no_dead_strip _kSingleWindowModeUseCurrentTab");
asm(".no_dead_strip _kSingleWindowModeUseNewTab");
asm(".no_dead_strip _kSingleWindowModeUseNewWindow");
asm(".no_dead_strip _kSingleWindowModeApplyAlways");
asm(".no_dead_strip _kSingleWindowModeApplyNever");
asm(".no_dead_strip _kSingleWindowModeApplyOnlyToUnfeatured");
asm(".no_dead_strip _kImageAnimationLoop");
asm(".no_dead_strip _kImageAnimationOnce");
asm(".no_dead_strip _kImageAnimationNone");
asm(".no_dead_strip _kTabFocusesForms");
asm(".no_dead_strip _kTabFocusesLinks");
asm(".no_dead_strip _kTabFocusesTextFields");
asm(".no_dead_strip _kBackspaceActionBack");
asm(".no_dead_strip _kBackspaceActionNone");
asm(".no_dead_strip _kCookieAcceptAll");
asm(".no_dead_strip _kCookieAcceptFromOriginatingServer");
asm(".no_dead_strip _kCookieAcceptNone");
asm(".no_dead_strip _kCookieLifetimeAsk");
asm(".no_dead_strip _kCookieLifetimeNormal");
asm(".no_dead_strip _kCookieLifetimeSession");
asm(".no_dead_strip _kDownloadsFolderDesktop");
asm(".no_dead_strip _kDownloadsFolderDownloads");
asm(".no_dead_strip _kDownloadsFolderCustom");


#pragma mark Tab Behavior

const char* const kGeckoPrefAlwaysShowTabBar = "camino.tab_bar_always_visible";
const char* const kGeckoPrefExternalLoadBehavior = "browser.link.open_external";
const char* const kGeckoPrefOpenTabsForMiddleClick = "browser.tabs.opentabfor.middleclick";
const char* const kGeckoPrefOpenTabsInBackground = "browser.tabs.loadInBackground";
const char* const kGeckoPrefSingleWindowModeTargetBehavior = "browser.link.open_newwindow";
const char* const kGeckoPrefSingleWindowModeRestriction = "browser.link.open_newwindow.restriction";
const char* const kGeckoPrefSingleWindowModeTabsOpenInBackground = "browser.tabs.loadDivertedInBackground";
const char* const kGeckoPrefEnableTabJumpback = "camino.enable_tabjumpback";
const char* const kGeckoPrefViewSourceInTab = "camino.viewsource_in_tab";

#pragma mark Warnings

const char* const kGeckoPrefWarnWhenClosingWindows = "camino.warn_when_closing";
const char* const kGeckoPrefWarnBeforeOpeningFeeds = "camino.warn_before_opening_feed";
const char* const kGeckoPrefLastAddOnWarningVersion = "camino.last_addon_check_version";

#pragma mark Content Control

const char* const kGeckoPrefEnableJavascript = "javascript.enabled";
const char* const kGeckoPrefEnableJava = "camino.enable_java";
const char* const kGeckoPrefEnablePlugins = "camino.enable_plugins";
const char* const kGeckoPrefAllowDangerousPlugins = "camino.allow_dangerous_plugins";
const char* const kGeckoPrefDisabledPluginPrefixes = "camino.disabled_plugin_names";
const char* const kGeckoPrefBlockPopups = "dom.disable_open_during_load";
const char* const kGeckoPrefBlockAds = "camino.enable_ad_blocking";
const char* const kGeckoPrefBlockFlash = "camino.enable_flashblock";
const char* const kGeckoPrefFlashblockWhitelist = "flashblock.whitelist";
const char* const kGeckoPrefBlockSilverlight = "flashblock.silverlight.blocked";
const char* const kGeckoPrefImageAnimationBehavior = "image.animation_mode";
const char* const kGeckoPrefPreventDOMWindowResize = "dom.disable_window_move_resize";
const char* const kGeckoPrefPreventDOMStatusChange = "dom.disable_window_status_change";
const char* const kGeckoPrefPreventDOMWindowFocus = "dom.disable_window_flip";

#pragma mark Home Page

const char* const kGeckoPrefHomepageURL = "browser.startup.homepage";
const char* const kGeckoPrefNewWindowStartPage = "browser.startup.page";
const char* const kGeckoPrefNewTabStartPage = "browser.tabs.startPage";
const char* const kGeckoPrefNewVersionHomepageOverrideVersion = "browser.startup_page_override.version";

#pragma mark Security

const char* const kGeckoPrefDefaultCertificateBehavior = "security.default_personal_cert";
const char* const kGeckoPrefUseKeychain = "chimera.store_passwords_with_keychain";
const char* const kGeckoPrefIgnoreAutocompleteOff = "wallet.crypto.autocompleteoverride";

#pragma mark Miscellaneous UI Controls

const char* const kGeckoPrefLogJSToConsole = "chimera.log_js_to_console";
const char* const kGeckoPrefEnableFavicons = "browser.chrome.favicons";
const char* const kGeckoPrefEnableURLFixup = "keyword.enabled";
const char* const kGeckoPrefDisableBonjour = "camino.disable_bonjour";
const char* const kGeckoPrefCheckDefaultBrowserAtLaunch = "camino.check_default_browser";
const char* const kGeckoPrefInlineLocationBarAutocomplete = "browser.urlbar.autoFill";
const char* const kGeckoPrefLocationBarAutocompleteEnabled = "browser.urlbar.autocomplete.enabled";
const char* const kGeckoPrefLocationBarAutocompleteFromTitles = "camino.autocomplete_from_titles";
const char* const kGeckoPrefFullContentZoom = "browser.zoom.full";

#pragma mark Keyboard Shortcuts

const char* const kGeckoPrefBackspaceAction = "browser.backspace_action";
const char* const kGeckoPrefTabFocusBehavior = "accessibility.tabfocus";

#pragma mark Auto-Update

const char* const kGeckoPrefUpdateURL = "app.update.url";
const char* const kGeckoPrefUpdateURLOverride = "app.update.url.override";
const char* const kGeckoPrefRelaunchingForAutoupdate = "camino.relaunching_for_autoupdate";

#pragma mark i18n

const char* const kGeckoPrefAcceptLanguages = "intl.accept_languages";
const char* const kGeckoPrefAcceptLanguagesOverride = "camino.accept_languages";
const char* const kGeckoPrefCharsetDetector = "intl.charset.detector";

#pragma mark Session Saving

const char* const kGeckoPrefSessionSaveEnabled = "camino.remember_window_state";
const char* const kGeckoPrefSessionSaveRestoreAfterCrash = "browser.sessionstore.resume_from_crash";

#pragma mark History

const char* const kGeckoPrefHistoryLifetimeDays = "browser.history_expire_days";

#pragma mark Cookies

const char* const kGeckoPrefCookieDefaultAcceptPolicy = "network.cookie.cookieBehavior";
const char* const kGeckoPrefCookieLifetimePolicy = "network.cookie.lifetimePolicy";
const char* const kGeckoPrefShouldRememberCookieDecision = "cocoa_prompt.remember_cookie_decision";

#pragma mark Proxies

const char* const kGeckoPrefProxyUsesSystemSettings = "camino.use_system_proxy_settings";
const char* const kGeckoPrefProxyAutoconfigURL = "network.proxy.autoconfig_url";
const char* const kGeckoPrefProxyBypassList = "network.proxy.no_proxies_on";

#pragma mark Downloads

const char* const kGeckoPrefDownloadsFolderList = "browser.download.folderList";
const char* const kGeckoPrefDownloadsDir = "browser.download.dir";
const char* const kGeckoPrefAutoOpenDownloads = "browser.download.manager.openDownloadedFiles";
const char* const kGeckoPrefDownloadCleanupPolicy = "browser.download.manager.retention";
const char* const kGeckoPrefFocusDownloadManagerOnDownload = "browser.download.manager.focusWhenStarting";
const char* const kGeckoPrefOpenDownloadManagerOnDownload = "browser.download.manager.showWhenStarting";
const char* const kGeckoPrefCloseDownloadManagerWhenDone = "browser.download.manager.closeWhenDone";
const char* const kGeckoPrefDownloadToDefaultLocation = "browser.download.useDownloadDir";

#pragma mark Page Appearance

const char* const kGeckoPrefUnderlineLinks = "browser.underline_anchors";
const char* const kGeckoPrefUsePageFonts = "browser.display.use_document_fonts";
const char* const kGeckoPrefPageBackgroundColor = "browser.display.background_color";
const char* const kGeckoPrefPageForegroundColor = "browser.display.foreground_color";
const char* const kGeckoPrefLinkColor = "browser.anchor_color";
const char* const kGeckoPrefVisitedLinkColor = "browser.visited_color";
const char* const kGeckoPrefForceAquaSelects = "camino.use_aqua_selects";

#pragma mark User Agent

const char* const kGeckoPrefUserAgentAppVersion = "general.useragent.vendorSub";
const char* const kGeckoPrefUserAgentLocale = "general.useragent.locale";
const char* const kGeckoPrefUserAgentLocaleOverride = "camino.useragent.locale";
const char* const kGeckoPrefUserAgentMultiLangAddition = "general.useragent.extra.multilang";

#pragma mark Safe Browsing

NSString* const kGeckoPrefSafeBrowsingDataProviderName = @"browser.safebrowsing.provider.%i.name";
NSString* const kGeckoPrefSafeBrowsingDataProviderUpdateURL = @"browser.safebrowsing.provider.%i.updateURL";
NSString* const kGeckoPrefSafeBrowsingDataProviderKeyURL = @"browser.safebrowsing.provider.%i.keyURL";
NSString* const kGeckoPrefSafeBrowsingDataProviderGetHashURL = @"browser.safebrowsing.provider.%i.gethashURL";

NSString* const kGeckoPrefSafeBrowsingDataProviderReportPhishingURL = @"browser.safebrowsing.provider.%i.reportPhishingURL";
NSString* const kGeckoPrefSafeBrowsingDataProviderReportPhishingErrorURL = @"browser.safebrowsing.provider.%i.reportPhishingErrorURL";
NSString* const kGeckoPrefSafeBrowsingDataProviderReportMalwareURL = @"browser.safebrowsing.provider.%i.reportMalwareURL";
NSString* const kGeckoPrefSafeBrowsingDataProviderReportMalwareErrorURL = @"browser.safebrowsing.provider.%i.reportMalwareErrorURL";

const char* const kGeckoPrefSafeBrowsingInformationURL = "browser.safebrowsing.warning.infoURL";
const char* const kGeckoPrefSafeBrowsingPhishingCheckingEnabled = "browser.safebrowsing.enabled";
const char* const kGeckoPrefSafeBrowsingMalwareCheckingEnabled = "browser.safebrowsing.malware.enabled";
const char* const kGeckoPrefSafeBrowsingDataProvider = "browser.safebrowsing.dataProvider";

const char* const kGeckoPrefSafeBrowsingSendToURLAfterReporting = "browser.safebrowsing.sendToURLAfterReporting";

#pragma mark Obsolete Downloads Prefs

const char* const kOldGeckoPrefAutoOpenDownloads = "browser.download.autoDispatch";
const char* const kOldGeckoPrefDownloadToDefaultLocation = "browser.download.autoDownload";
const char* const kOldGeckoPrefDownloadCleanupPolicy = "browser.download.downloadRemoveAction";
const char* const kOldGeckoPrefFocusDownloadManagerOnDownload = "browser.download.progressDnldDialog.bringToFront";
const char* const kOldGeckoPrefLeaveDownloadManagerOpen = "browser.download.progressDnldDialog.keepAlive";

#pragma mark Obsolete Tab Behavior

const char* const kOldGeckoPrefExternalLoadBehavior = "browser.reuse_window";

#pragma mark -
#pragma mark Values

// kGeckoPrefExternalLoadBehavior values
const int kExternalLoadReusesWindow   = 1;
const int kExternalLoadOpensNewWindow = 2;
const int kExternalLoadOpensNewTab    = 3;

// kGeckoPrefSingleWindowModeTargetBehavior values
const int kSingleWindowModeUseDefault    = nsIBrowserDOMWindow::OPEN_DEFAULTWINDOW;
const int kSingleWindowModeUseCurrentTab = nsIBrowserDOMWindow::OPEN_CURRENTWINDOW;
const int kSingleWindowModeUseNewTab     = nsIBrowserDOMWindow::OPEN_NEWTAB;
const int kSingleWindowModeUseNewWindow  = nsIBrowserDOMWindow::OPEN_NEWWINDOW;

// kGeckoPrefSingleWindowModeRestriction values
const int kSingleWindowModeApplyAlways           = 0;
const int kSingleWindowModeApplyNever            = 1;
const int kSingleWindowModeApplyOnlyToUnfeatured = 2;

// kGeckoPrefImageAnimationBehavior values
NSString* const kImageAnimationNone = @"none";
NSString* const kImageAnimationOnce = @"once";
NSString* const kImageAnimationLoop = @"normal";

// kGeckoPrefNewWindowStartPage and kGeckoPrefNewTabStartPage values
const int kStartPageBlank = 0;
const int kStartPageHome  = 1;

// kGeckoPrefDefaultCertificateBehavior values
NSString* const kPersonalCertificateSelectAutomatically = @"Select Automatically";
NSString* const kPersonalCertificateAlwaysAsk = @"Ask Every Time";

// kGeckoPrefBackspaceAction values
const int kBackspaceActionBack = 0;
const int kBackspaceActionNone = 2;

// kGeckoPrefTabFocusBehavior values
const int kTabFocusesTextFields = (1 << 0);
const int kTabFocusesForms      = (1 << 1);
const int kTabFocusesLinks      = (1 << 2);

// kGeckoPrefCharsetDetector values
NSString* const kCharsetDetectorNone = @"";
NSString* const kCharsetDetectorUniversal = @"universal_charset_detector";

// kGeckoPrefCookieDefaultAcceptPolicy values
const int kCookieAcceptAll = 0;
const int kCookieAcceptFromOriginatingServer = 1;
const int kCookieAcceptNone = 2;

// kGeckoPrefCookieLifetimePolicy values
const int kCookieLifetimeNormal = 0;
const int kCookieLifetimeAsk = 1;
const int kCookieLifetimeSession = 2;

// kGeckoPrefDownloadsFolderList values
const int kDownloadsFolderDesktop = 0;
const int kDownloadsFolderDownloads = 1;
const int kDownloadsFolderCustom = 2;

// kGeckoPrefDownloadCleanupPolicy values
// NB: these are the opposite of what they used to be!
const int kRemoveDownloadsOnSuccess = 0;
const int kRemoveDownloadsOnQuit = 1;
const int kRemoveDownloadsManually = 2;

// kOldGeckoPrefDownloadCleanupPolicy values
// NB: these are the opposite of the new ones!
const int kOldRemoveDownloadsManually = 0;
const int kOldRemoveDownloadsOnQuit = 1;
const int kOldRemoveDownloadsOnSuccess = 2;

// kOldGeckoPrefExternalLoadBehavior values
const int kOldExternalLoadReusesWindow   = 2;
