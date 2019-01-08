/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>

@class BookmarkMenu;
@class BookmarkItem;
@class BookmarkManager;
@class KeychainService;
@class BrowserWindowController;
@class GrowlController;
@class TopLevelHistoryMenu;
@class PreferenceManager;
@class MVPreferencesController;
@class SUUpdater;


typedef NS_ENUM(NSInteger, EBookmarkOpenBehavior)
{
  eBookmarkOpenBehavior_Preferred,     //!< Reuse current window/tab, unless there isn't one, then open a new one
  eBookmarkOpenBehavior_NewPreferred,  //!< Open in new window or tab based on prefs
  eBookmarkOpenBehavior_ForceReuse,
  eBookmarkOpenBehavior_NewWindow,
  eBookmarkOpenBehavior_NewTab
};

typedef NS_ENUM(NSInteger, ETabAndWindowCount)
{
  eNoWindows,                     //!< so we have something to fall back on
  eOneWindowWithoutTabs,
  eMultipleWindowsWithoutTabs,
  eMultipleTabsInOneWindow,
  eMultipleTabsInMultipleWindows
};

@interface MainController : NSObject 
{
    IBOutlet NSApplication*        mApplication;

    // The following item is added to NSSavePanels as an accessory view.
    IBOutlet NSView*               mFilterView;
    IBOutlet NSView*               mExportPanelView;

    IBOutlet NSMenuItem*           mOfflineMenuItem;
    IBOutlet NSMenuItem*           mHideMenuItem;
    IBOutlet NSMenuItem*           mQuitMenuItem;

    IBOutlet NSMenuItem*           mNewWindowMenuItem;
    IBOutlet NSMenuItem*           mNewTabMenuItem;
    IBOutlet NSMenuItem*           mOpenLocationMenuItem;
    IBOutlet NSMenuItem*           mCloseWindowMenuItem;
    IBOutlet NSMenuItem*           mCloseTabMenuItem;

    IBOutlet BookmarkMenu*         mBookmarksMenu;
    IBOutlet BookmarkMenu*         mDockMenu;
    IBOutlet NSMenu*               mServersSubmenu;

    IBOutlet NSMenu*               mViewMenu;
    IBOutlet NSMenuItem*           mTextZoomOnlyMenuItem;

    IBOutlet NSMenu*               mTextEncodingsMenu;

    // The top-level history menu, used in menu validation.
    IBOutlet TopLevelHistoryMenu*  mTopLevelHistoryMenu;

    // Not shown; used to get enable state.
    IBOutlet NSMenu*               mBookmarksHelperMenu;

    IBOutlet NSMenuItem*           mAddBookmarkMenuItem;
    IBOutlet NSMenuItem*           mAddBookmarkWithoutPromptMenuItem;
    IBOutlet NSMenuItem*           mAddTabGroupMenuItem;
    IBOutlet NSMenuItem*           mAddTabGroupWithoutPromptMenuItem;
    IBOutlet NSMenuItem*           mCreateBookmarksFolderMenuItem;
    // mCreateBookmarksSeparatorMenuItem is unused.
    IBOutlet NSMenuItem*           mCreateBookmarksSeparatorMenuItem;
    IBOutlet NSMenuItem*           mShowAllBookmarksMenuItem;

    IBOutlet NSMenuItem*           mMinimizeMenuItem;
    IBOutlet NSMenuItem*           mPreviousTabMenuItem;
    IBOutlet NSMenuItem*           mNextTabMenuItem;

    IBOutlet SUUpdater*            mAutoUpdater;

    BOOL                           mInitialized;
    BOOL                           mOffline;
    BOOL                           mGeckoInitted;
    BOOL                           mFileMenuUpdatePending;
    BOOL                           mPageInfoUpdatePending;

    BookmarkMenu*                  mMenuBookmarks;
    BookmarkMenu*                  mDockBookmarks;

    KeychainService*               mKeychainService;

    NSString*                      mStartURL;

    GrowlController*               mGrowlController;

    NSMutableDictionary*           mCharsets;
}

- (BOOL)isInitialized;

// Application menu actions
- (IBAction)aboutWindow:(id)sender;
- (IBAction)feedbackLink:(id)aSender;
- (IBAction)checkForUpdates:(id)sender;
- (IBAction)displayPreferencesWindow:(id)sender;
- (IBAction)resetBrowser:(id)sender;
- (IBAction)emptyCache:(id)sender;
- (IBAction)toggleOfflineMode:(id)aSender;

// File menu actions
- (IBAction)newWindow:(id)aSender;
- (IBAction)newTab:(id)aSender;
- (IBAction)openFile:(id)aSender;
- (IBAction)openLocation:(id)aSender;
- (IBAction)doSearch:(id)aSender;
- (IBAction)closeAllWindows:(id)aSender;
- (IBAction)closeCurrentTab:(id)aSender;
- (IBAction)savePage:(id)aSender;
- (IBAction)sendURL:(id)aSender;
- (IBAction)importBookmarks:(id)aSender;
- (IBAction)exportBookmarks:(id)aSender;
- (IBAction)pageSetup:(id)aSender;
- (IBAction)printDocument:(id)aSender;

// Edit menu actions
// (none)

// View menu actions.
- (IBAction)toggleBookmarksToolbar:(id)aSender;
- (IBAction)toggleStatusBar:(id)aSender;
- (IBAction)stop:(id)aSender;
- (IBAction)reload:(id)aSender;
- (IBAction)reloadAllTabs:(id)aSender;
- (IBAction)makeTextBigger:(id)aSender;
- (IBAction)makeTextDefaultSize:(id)aSender;
- (IBAction)makeTextSmaller:(id)aSender;
- (IBAction)makePageBigger:(id)aSender;
- (IBAction)makePageDefaultSize:(id)aSender;
- (IBAction)makePageSmaller:(id)aSender;
- (IBAction)toggleTextZoom:(id)aSender;
- (IBAction)viewPageSource:(id)aSender;
- (IBAction)reloadWithCharset:(id)aSender;
- (IBAction)toggleAutoCharsetDetection:(id)aSender;

// History menu actions
- (IBAction)goHome:(id)aSender;
- (IBAction)goBack:(id)aSender;
- (IBAction)goForward:(id)aSender;
- (IBAction)showHistory:(id)aSender;
- (IBAction)clearHistory:(id)aSender;

// Bookmarks menu actions
- (IBAction)manageBookmarks: (id)aSender;
- (IBAction)openMenuBookmark:(id)aSender;

// Bonjour submenu
- (IBAction)aboutServers:(id)aSender;
- (IBAction)connectToServer:(id)aSender;

// Window menu actions
- (IBAction)zoomAll:(id)aSender;
- (IBAction)previousTab:(id)aSender;
- (IBAction)nextTab:(id)aSender;
- (IBAction)toggleTabThumbnailView:(id)aSender;
- (IBAction)downloadsWindow:(id)aSender;

// Help menu actions
- (IBAction)supportLink:(id)aSender;
- (IBAction)keyboardShortcutsLink:(id)aSender;
- (IBAction)infoLink:(id)aSender;
- (IBAction)reportPhishingPage:(id)aSender;
- (IBAction)aboutPlugins:(id)aSender;

// used by export bookmarks popup to set file extension for the resulting bookmarks file
- (IBAction)setFileExtension:(id)aSender;
// used by page info panel to show certificate information
- (IBAction)showCertificates:(id)aSender;

// if the main/key window is a browser window, return its controller, otherwise nil
- (BrowserWindowController*)mainWindowBrowserController;
- (BrowserWindowController*)keyWindowBrowserController;
- (NSWindow*)frontmostBrowserWindow;
- (NSArray*)browserWindows;

- (BrowserWindowController*)openBrowserWindowWithURL:(NSString*)aURL andReferrer:(NSString*)aReferrer behind:(NSWindow*)window allowPopups:(BOOL)inAllowPopups;
- (BrowserWindowController*)openBrowserWindowWithURLs:(NSArray*)urlArray behind:(NSWindow*)window allowPopups:(BOOL)inAllowPopups;
- (void)showURL:(NSString*)aURL;
- (void)showURL:(NSString*)aURL usingReferrer:(NSString*)aReferrer loadInBackground:(BOOL)aLoadInBG;
- (void)loadBookmark:(BookmarkItem*)item withBWC:(BrowserWindowController*)browserWindowController openBehavior:(EBookmarkOpenBehavior)behavior reverseBgToggle:(BOOL)reverseBackgroundPref;

- (void)adjustCloseWindowMenuItemKeyEquivalent:(BOOL)inHaveTabs;
- (void)adjustCloseTabMenuItemKeyEquivalent:(BOOL)inHaveTabs;
- (void)delayedFixCloseMenuItemKeyEquivalents;
- (void)delayedUpdatePageInfo;

- (NSView*)savePanelView;

// Returns YES if the event is the shortcut for a menu item that web content
// is not allowed to override.
- (BOOL)isEventNonOverridableMenuShortcut:(NSEvent*)event;

@end
