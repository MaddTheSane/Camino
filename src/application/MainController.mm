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

#import "MainController.h"
#import "BrowserWindowController.h"
#include "BookmarksService.h"
#include "nsCOMPtr.h"
#include "nsIServiceManager.h"
#include "nsIIOService.h"
#include "nsCocoaBrowserService.h"
#include "nsIPrefBranch.h"
#include "nsEmbedAPI.h"
#import	"CHAboutBox.h"
#include <Foundation/NSUserDefaults.h>

#ifdef _BUILD_STATIC_BIN
#include "nsStaticComponent.h"
nsresult PR_CALLBACK
app_getModuleInfo(nsStaticModuleInfo **info, PRUint32 *count);
#endif

static const char* ioServiceContractID = "@mozilla.org/network/io-service;1";

@implementation MainController

-(id)init
{
    if ( (self = [super init]) ) {
        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
        if ([defaults boolForKey:@"autoRegister"]) {
            // This option causes us to simply initialize embedding and exit.
            NSString *path = [[[NSBundle mainBundle] executablePath] stringByDeletingLastPathComponent];
            setenv("MOZILLA_FIVE_HOME", [path fileSystemRepresentation], 1);

#ifdef _BUILD_STATIC_BIN
            NSGetStaticModuleInfo = app_getModuleInfo;
#endif

            if (NS_SUCCEEDED(NS_InitEmbedding(nsnull, nsnull)))
              NS_TermEmbedding();

            [NSApp terminate:self];
            return self;
        }
        mSplashScreen = [[CHSplashScreenWindow alloc] splashImage:nil withFade:YES withStatusRect:NSMakeRect(0,0,0,0)];
        mFindDialog = nil;
        mMenuBookmarks = nil;
    }
    return self;
}

-(void)dealloc
{
    [super dealloc];
    [mFindDialog release];
    printf("Main controller died.\n");
}

-(void)awakeFromNib
{
    mPreferenceManager = [[CHPreferenceManager sharedInstance] retain];

    [self newWindow: self];
    
    [mSplashScreen close];

    [mBookmarksMenu setAutoenablesItems: NO];
    mMenuBookmarks = new BookmarksService((BookmarksDataSource*)nil);
    mMenuBookmarks->AddObserver();
    mMenuBookmarks->ConstructBookmarksMenu(mBookmarksMenu, nsnull);
    BookmarksService::gMainController = self;
    
    // Initialize offline mode.
    mOffline = NO;
    nsCOMPtr<nsIIOService> ioService(do_GetService(ioServiceContractID));
    if (!ioService)
        return;
    PRBool offline = PR_FALSE;
    ioService->GetOffline(&offline);
    mOffline = offline;
    
    // Set the menu item's text to "Go Online" if we're currently
    // offline.
    if (mOffline)
        [mOfflineMenuItem setTitle: @"Go Online"];
}

-(IBAction)newWindow:(id)aSender
{
  // If we have a key window, have it autosave its dimensions before
  // we open a new window.  That ensures the size ends up matching.
  NSWindow* mainWindow = [mApplication mainWindow];
  if ( mainWindow && [[mainWindow windowController] respondsToSelector:@selector(autosaveWindowFrame)] )
    [[mainWindow windowController] autosaveWindowFrame];

  // Now open the new window.
  NSString* homePage = [mPreferenceManager homePage:YES];
  BrowserWindowController* controller = [self openBrowserWindowWithURLString:homePage];
  if ([homePage isEqualToString: @"about:blank"])
    [controller focusURLBar];
  else
    [[[controller getBrowserWrapper] getBrowserView] setActive: YES];
}	

-(IBAction)newTab:(id)aSender
{
  [[[mApplication mainWindow] windowController] newTab];
}

-(IBAction)closeTab:(id)aSender
{
  [[[mApplication mainWindow] windowController] closeTab];
}

-(IBAction) previousTab:(id)aSender
{
  [[[mApplication mainWindow] windowController] previousTab];
}

-(IBAction) nextTab:(id)aSender;
{
	[[[mApplication mainWindow] windowController] nextTab];
}

-(IBAction) openFile:(id)aSender
{
    NSOpenPanel* openPanel = [[[NSOpenPanel alloc] init] autorelease];
    [openPanel setCanChooseFiles: YES];
    [openPanel setCanChooseDirectories: NO];
    [openPanel setAllowsMultipleSelection: NO];
    NSArray* array = [NSArray arrayWithObjects: @"htm",@"html",@"shtml",@"xhtml",@"xml",
                                                @"txt",@"text",
                                                @"gif",@"jpg",@"jpeg",@"png",@"bmp",
                                                nil];
    int result = [openPanel runModalForTypes: array];
    if (result == NSOKButton) {
        NSArray* urlArray = [openPanel URLs];
        if ([urlArray count] == 0)
            return;
        NSURL* url = [urlArray objectAtIndex: 0];
        // ----------------------
        [[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:url];
        // ----------------------
        NSWindow* mainWindow = [mApplication mainWindow];
        if (mainWindow) {
          [[mainWindow windowController] loadURL: url];
          [[[[mainWindow windowController] getBrowserWrapper] getBrowserView] setActive: YES];
        }
        else
          [self openBrowserWindowWithURL: url];
    }
}

-(IBAction) openLocation:(id)aSender
{
    NSWindow* mainWindow = [mApplication mainWindow];
    if (!mainWindow) {
      [self openBrowserWindowWithURLString: @"about:blank"];
      mainWindow = [mApplication mainWindow];
    }
    
    [[mainWindow windowController] performAppropriateLocationAction];
}

-(IBAction) savePage:(id)aSender
{
  [[[mApplication mainWindow] windowController] saveDocument: mFilterView filterList: mFilterList];
}

-(IBAction) printPage:(id)aSender
{
  [[[mApplication mainWindow] windowController] printDocument];
}

-(IBAction) printPreview:(id)aSender
{
  [[[mApplication mainWindow] windowController] printPreview];
}

-(IBAction) toggleOfflineMode:(id)aSender
{
    nsCOMPtr<nsIIOService> ioService(do_GetService(ioServiceContractID));
    if (!ioService)
        return;
    PRBool offline = PR_FALSE;
    ioService->GetOffline(&offline);
    ioService->SetOffline(!offline);
    mOffline = !offline;
    
    // Update the menu item text.
    // Set the menu item's text to "Go Online" if we're currently
    // offline.
    if (mOffline)
        [mOfflineMenuItem setTitle: @"Go Online"];
    else
        [mOfflineMenuItem setTitle: @"Work Offline"];
        
    // Indicate that we are working offline.
    [[NSNotificationCenter defaultCenter] postNotificationName:@"offlineModeChanged" object:nil];
}

// Edit menu actions.


//
// -findInPage
//
// Called in response to "Find" in edit menu. Opens the find dialog. We only keep
// one around for the whole app to use, showing/hiding as we see fit.
//
-(IBAction) findInPage:(id)aSender
{
  if ( !mFindDialog )
     mFindDialog = [[FindDlgController alloc] initWithWindowNibName: @"FindDialog"];
  [mFindDialog showWindow:self];
}


//
// -findAgain
//
// Called in response to "Find Again" in edit menu. Tells the find controller
// to find the next occurrance of what's already been found.
//
-(IBAction) findAgain:(id)aSender
{
  if ( mFindDialog )
    [mFindDialog findAgain:aSender];
  else
    NSBeep();
}

-(IBAction) goBack:(id)aSender
{
    [[[mApplication mainWindow] windowController] back: aSender]; 
}

-(IBAction) goForward:(id)aSender
{
    [[[mApplication mainWindow] windowController] forward: aSender]; 
}

-(IBAction) doReload:(id)aSender
{
    [(BrowserWindowController*)([[mApplication mainWindow] windowController]) reload: aSender]; 
}

-(IBAction) doStop:(id)aSender
{
    [(BrowserWindowController*)([[mApplication mainWindow] windowController]) stop: aSender]; 
}

-(IBAction) goHome:(id)aSender
{
    [[[mApplication mainWindow] windowController] home: aSender];
}

-(BrowserWindowController*)openBrowserWindowWithURLString: (NSString*)aURL
{
    return [self openBrowserWindowWithURL: [NSURL URLWithString:aURL]];
}

-(BrowserWindowController*)openBrowserWindowWithURL: (NSURL*)aURL
{
	BrowserWindowController* browser = [[BrowserWindowController alloc] initWithWindowNibName: @"BrowserWindow"];
  [browser loadURL: aURL];
	[browser showWindow: self];
  return browser;
}

-(void)applicationWillTerminate: (NSNotification*)aNotification
{
    printf("Termination notification.\n");

    // Autosave one of the windows.
    [[[mApplication mainWindow] windowController] autosaveWindowFrame];
    
    mMenuBookmarks->RemoveObserver();
    delete mMenuBookmarks;
    mMenuBookmarks = nsnull;
    
    // Release before calling TermEmbedding since we need to access XPCOM
    // to save preferences
    [mPreferenceManager release];
    
    nsCocoaBrowserService::TermEmbedding();
    
    [self autorelease];
}

// Bookmarks menu actions.
-(IBAction) importBookmarks:(id)aSender
{
  // IE favorites: ~/Library/Preferences/Explorer/Favorites.html
  // Omniweb favorites: ~/Library/Application Support/Omniweb/Bookmarks.html
  // For now, open the panel to IE's favorites.
  NSOpenPanel* openPanel = [[[NSOpenPanel alloc] init] autorelease];
  [openPanel setCanChooseFiles: YES];
  [openPanel setCanChooseDirectories: NO];
  [openPanel setAllowsMultipleSelection: NO];
  NSArray* array = [NSArray arrayWithObjects: @"htm",@"html",@"xml", nil];
  int result = [openPanel runModalForDirectory: @"~/Library/Preferences/Explorer/"
                                          file: @"Favorites.html"
                                         types: array];
  if (result == NSOKButton) {
    NSArray* urlArray = [openPanel URLs];
    if ([urlArray count] == 0)
      return;
    NSURL* url = [urlArray objectAtIndex: 0];

    NSWindow* window = [mApplication mainWindow];
    if (!window) {
      [self newWindow: self];
      window = [mApplication mainWindow];
    }
    
    [[window windowController] importBookmarks: url];
  }
}

-(IBAction) addBookmark:(id)aSender
{
  [[[mApplication mainWindow] windowController] addBookmarkExtended: YES isFolder: NO];
}

-(IBAction) addFolder:(id)aSender
{
  [[[mApplication mainWindow] windowController] addBookmarkExtended: YES isFolder: YES];
}

-(IBAction) addSeparator:(id)aSender
{
}

-(IBAction) openMenuBookmark:(id)aSender
{
    NSWindow* mainWind = [mApplication mainWindow];
    if (!mainWind) {
        [self openBrowserWindowWithURLString: @"about:blank"];
        mainWind = [mApplication mainWindow];
    }

    BookmarksService::OpenMenuBookmark([mainWind windowController], aSender);
}

-(IBAction)manageBookmarks: (id)aSender
{
  NSWindow* mainWindow = [mApplication mainWindow];
  if (!mainWindow) {
    [self openBrowserWindowWithURLString: @"about:blank"];
    mainWindow = [mApplication mainWindow];
  }

  [[mainWindow windowController] manageBookmarks: aSender];
}

- (MVPreferencesController *)preferencesController
{
    if (!preferencesController) {
        preferencesController = [[MVPreferencesController sharedInstance] retain];
    }
    return preferencesController;
}

- (void)displayPreferencesWindow:sender
{
    [[self preferencesController] showPreferences:nil] ;
}

- (IBAction)showAboutBox:(id)sender
{
    [[CHAboutBox sharedInstance] showPanel:sender];
}

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename
{
    NSWindow* mainWindow = [mApplication mainWindow];

    if (mainWindow) {
        [[mainWindow windowController] loadURL:[NSURL fileURLWithPath:filename]];
    } else {
        [self openBrowserWindowWithURL:[NSURL fileURLWithPath:filename]];
    }
    
    return YES;
    
}

- (IBAction)biggerTextSize:(id)aSender
{
  [[[mApplication mainWindow] windowController] biggerTextSize];
}

- (IBAction)smallerTextSize:(id)aSender
{
  [[[mApplication mainWindow] windowController] smallerTextSize];
}

-(IBAction) viewSource:(id)aSender
{
  NSWindow* mainWindow = [mApplication mainWindow];
  if (mainWindow && [[mainWindow windowController] respondsToSelector:@selector(viewSource:)] )
    [[mainWindow windowController] viewSource: self];
}


-(BOOL)validateMenuItem: (NSMenuItem*)aMenuItem
{
  // disable items that aren't relevant if there's no main browser window open
  if ([aMenuItem action] == @selector(newTab:) ||
        /* ... many more items go here ... */
        [aMenuItem action] == @selector(savePage:)) {
    if ([[[mApplication mainWindow] windowController] isMemberOfClass:[BrowserWindowController class]])
      return YES;
    return NO;
  }
  
  // only activate if we've got multiple tabs open.
  if (([aMenuItem action] == @selector(closeTab:) ||
       [aMenuItem action] == @selector (nextTab:) ||
       [aMenuItem action] == @selector (previousTab:))) {
    if ([[[[mApplication mainWindow] windowController] getTabBrowser] numberOfTabViewItems] > 1)
      return YES;
    return NO;
  }
  // default return
  return YES;
}

-(IBAction) toggleBookmarksToolbar:(id)aSender
{
  //XXX do nothing for now
}

+ (NSImage*)createImageForDragging:(NSImage*)aIcon title:(NSString*)aTitle
{
  NSImage* image;
  NSSize titleSize, imageSize;
  NSRect imageRect;
  NSDictionary* stringAttrs;
  
  // get the size of the new image we are creating
  titleSize = [aTitle sizeWithAttributes:nil];
  imageSize = NSMakeSize(titleSize.width + [aIcon size].width,
                         titleSize.height > [aIcon size].height ? 
                            titleSize.height : [aIcon size].height);
                        
  // create the image and lock drawing focus on it
  image = [[[NSImage alloc] initWithSize:imageSize] autorelease];
  [image lockFocus];
  
  // draw the image and title in image with translucency
  imageRect = NSMakeRect(0,0, [aIcon size].width, [aIcon size].height);
  [aIcon drawAtPoint: NSMakePoint(0,0) fromRect: imageRect operation:NSCompositeCopy fraction:0.8];
  
  stringAttrs = [NSDictionary dictionaryWithObject: [[NSColor textColor] colorWithAlphaComponent:0.8]
                  forKey: NSForegroundColorAttributeName];
  [aTitle drawAtPoint: NSMakePoint([aIcon size].width, 0) withAttributes: stringAttrs];
  
  [image unlockFocus]; 
  
  return image;
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApp hasVisibleWindows:(BOOL)flag
{
  // If AppKit knows what to do, let it.
  if (flag)
    return YES;
    
  // If window available, wake it up. |mainWindow| should always be null.
  NSWindow* mainWindow = [mApplication mainWindow];
  if (!mainWindow)
    [self newWindow:self];
  else {												// Don't think this will ever happen, but just in case
    if ([[mainWindow windowController]respondsToSelector:@selector(showWindow:)])
      [[mainWindow windowController] showWindow:self];
    else
      [self newWindow:self];
  }

  return NO;
}

@end
