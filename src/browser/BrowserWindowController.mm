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

#import <AppKit/NSScroller.h>

#import <AddressBook/AddressBook.h>
#import "ABAddressBook+Utils.h"

#import "NSString+Utils.h"
#import "NSString+Gecko.h"
#import "NSSplitView+Utils.h"
#import "NSMenu+Utils.h"
#import "NSPasteboard+Utils.h"
#import "NSWorkspace+Utils.h"

#import "BrowserWindowController.h"
#import "BrowserWindow.h"
#import "SessionManager.h"

#import "BookmarkToolbar.h"
#import "BookmarkViewController.h"
#import "BookmarkManager.h"
#import "BookmarkFolder.h"
#import "Bookmark.h"
#import "AddBookmarkDialogController.h"
#import "ProgressDlgController.h"
#import "PageInfoWindowController.h"
#import "FeedServiceController.h"
#import "FindBarController.h"

#import "BrowserContentViews.h"
#import "BrowserWrapper.h"
#import "PreferenceManager.h"
#import "BrowserTabView.h"
#import "BrowserTabViewItem.h"
#import "TabButtonView.h"
#import "UserDefaults.h"
#import "PageProxyIcon.h"
#import "AutoCompleteTextField.h"
#import "DraggableImageAndTextCell.h"
#import "MVPreferencesController.h"
#import "ViewCertificateDialogController.h"
#import "ExtendedSplitView.h"
#import "WebSearchField.h"
#import "wallet.h"
#import "ToolbarScriptItem.h"
#import "SearchEngineManager.h"
#import "SearchEngineEditor.h"
// For search plugin description keys:
#import "XMLSearchPluginParser.h"

#import "CHPermissionManager.h"
#import "CHBrowserService.h"

#include "GeckoUtils.h"

#include "nsString.h"
#include "nsCRT.h"
#include "nsServiceManagerUtils.h"

#include "nsIWebNavigation.h"
#include "nsISHistory.h"
#include "nsIHistoryEntry.h"
#include "nsIHistoryItems.h"
#include "nsIDOMDocument.h"
#include "nsIDOMNSDocument.h"
#include "nsIDOMNSHTMLDocument.h"
#include "nsIDOMLocation.h"
#include "nsIDOMElement.h"
#include "nsIDOMEvent.h"
#include "nsIContextMenuListener.h"
#include "nsIDOMWindow.h"
#include "nsIDOMPopupBlockedEvent.h"
#include "nsIDOMHTMLImageElement.h"
#include "nsIWebProgressListener.h"
#include "nsIWebBrowserChrome.h"
#include "nsNetUtil.h"
#include "nsIPref.h"
#include "nsIDocShell.h"
#include "nsIDOMNSEditableElement.h"

#include "nsIClipboardCommands.h"
#include "nsICommandManager.h"
#include "nsICommandParams.h"
#include "nsIWebBrowser.h"
#include "nsIInterfaceRequestorUtils.h"
#include "nsIURI.h"
#include "nsIURIFixup.h"
#include "nsIBrowserHistory.h"
#include "nsIWebPageDescriptor.h"
#include "nsPIDOMWindow.h"
#include "nsIDOMHTMLImageElement.h"
#include "nsIFocusController.h"
#include "nsIX509Cert.h"
#include "nsIArray.h"

// for spellchecking
#include "nsIEditor.h"
#include "nsIEditingSession.h"
#include "nsIInlineSpellChecker.h"
#include "nsIEditorSpellCheck.h"
#include "nsISelection.h"
#include "nsIDOMRange.h"

#include "nsAppDirectoryServiceDefs.h"

#if MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_4
@interface NSWindow(LeopardSDKDeclarations)
- (void)setContentBorderThickness:(float)borderThickness forEdge:(NSRectEdge)edge;
@end

@interface NSSpellChecker(LeopardSDKDeclarations)
- (NSArray *)availableLanguages;
@end

@interface NSCell(LeopardSDKDeclarations)
- (void)setBackgroundStyle:(int)backgroundStyle;
@end
static const int NSBackgroundStyleRaised = 2;
#endif

static NSString* const BrowserToolbarIdentifier         = @"Browser Window Toolbar Combined";
static NSString* const BackToolbarItemIdentifier        = @"Back Toolbar Item";
static NSString* const ForwardToolbarItemIdentifier     = @"Forward Toolbar Item";
static NSString* const ReloadToolbarItemIdentifier      = @"Reload Toolbar Item";
static NSString* const StopToolbarItemIdentifier        = @"Stop Toolbar Item";
static NSString* const HomeToolbarItemIdentifier        = @"Home Toolbar Item";
static NSString* const CombinedLocationToolbarItemIdentifier  = @"Combined Location Toolbar Item";
static NSString* const BookmarksToolbarItemIdentifier   = @"Sidebar Toolbar Item";    // note legacy name
static NSString* const PrintToolbarItemIdentifier       = @"Print Toolbar Item";
static NSString* const ThrobberToolbarItemIdentifier    = @"Throbber Toolbar Item";
static NSString* const ViewSourceToolbarItemIdentifier  = @"View Source Toolbar Item";
static NSString* const BookmarkToolbarItemIdentifier    = @"Bookmark Toolbar Item";
static NSString* const TextBiggerToolbarItemIdentifier  = @"Text Bigger Toolbar Item";
static NSString* const TextSmallerToolbarItemIdentifier = @"Text Smaller Toolbar Item";
static NSString* const NewTabToolbarItemIdentifier      = @"New Tab Toolbar Item";
static NSString* const CloseTabToolbarItemIdentifier    = @"Close Tab Toolbar Item";
static NSString* const SendURLToolbarItemIdentifier     = @"Send URL Toolbar Item";
static NSString* const DLManagerToolbarItemIdentifier   = @"Download Manager Toolbar Item";
static NSString* const FormFillToolbarItemIdentifier    = @"Form Fill Toolbar Item";
static NSString* const HistoryToolbarItemIdentifier     = @"History Toolbar Item";

int TabBarVisiblePrefChangedCallback(const char* pref, void* data);
static const char* const gTabBarVisiblePref = "camino.tab_bar_always_visible";

const float kMinimumLocationBarWidth = 250.0;
const float kMinimumURLAndSearchBarWidth = 128.0;
const float kDefaultSearchBarWidth = 192.0;
const float kEpsilon = 0.001; //suitable for "equality"-testing pseudo-integer values up to ~10000

static NSString* const NavigatorWindowFrameSaveName = @"NavigatorWindow";
static NSString* const NavigatorWindowSearchBarWidth = @"SearchBarWidth";
static NSString* const NavigatorWindowSearchBarHidden = @"SearchBarHidden";
static NSString* const kViewSourceProtocolString = @"view-source:";
const unsigned long kNoToolbarsChromeMask = (nsIWebBrowserChrome::CHROME_ALL & ~(nsIWebBrowserChrome::CHROME_TOOLBAR |
                                                                                 nsIWebBrowserChrome::CHROME_PERSONAL_TOOLBAR |
                                                                                 nsIWebBrowserChrome::CHROME_LOCATIONBAR)); 

// context menu items tags
const int kFrameRelatedItemsTag = 100;
const int kFrameInapplicableItemsTag = 101;
const int kSelectionRelatedItemsTag = 102;
const int kSpellingRelatedItemsTag = 103;
const int kItemsNeedingOpenBehaviorAlternatesTag = 104;
const int kItemsNeedingForceAlternateTag = 105;
const int kLinkOpeningItemsTag = 106;

// Cached toolbar defaults read in from a plist. If null, we'll use
// hardcoded defaults.
static NSArray* sToolbarDefaults = nil;

#pragma mark -

// small class that owns C++ objects on behalf of BrowserWindowController.
// this just allows us to use nsCOMPtr rather than doing manual refcounting.
class BWCDataOwner
{
public:

  BWCDataOwner()
  : mContextMenuFlags(0)
  , mGotOnContextMenu(false)
  {
    mGlobalHistory = do_GetService("@mozilla.org/browser/global-history;2");
    mURIFixer      = do_GetService("@mozilla.org/docshell/urifixup;1");
  }
  
  nsCOMPtr<nsIURIFixup>         mURIFixer;
  nsCOMPtr<nsIBrowserHistory>   mGlobalHistory;

  int                           mContextMenuFlags;
  nsCOMPtr<nsIDOMEvent>         mContextMenuEvent;
  nsCOMPtr<nsIDOMNode>          mContextMenuNode;
  bool                          mGotOnContextMenu;
};


#pragma mark -

// This little class exists so that we can clear up the context menu-related
// pointers in the mDataOwner at autorelease time. See the comments in -onShowContextMenu:
@interface ContextMenuDataClearer : NSObject
{
  id              mTarget;    // retained
  SEL             mSelector;
}

- (id)initWithTarget:(id)inTarget selector:(SEL)inSelector;

@end

@implementation ContextMenuDataClearer

- (id)initWithTarget:(id)inTarget selector:(SEL)inSelector
{
  if ((self = [super init]))
  {
    mTarget   = [inTarget retain];
    mSelector = inSelector;
  }
  return self;
}

-(void)dealloc
{
  [mTarget performSelector:mSelector];    // do our work
  [mTarget release];
  [super dealloc];
}

@end // ContextMenuDataClearer

#pragma mark -

//////////////////////////////////////
@interface AutoCompleteTextFieldEditor : NSTextView
{
  NSFont* mDefaultFont; // will be needed if editing empty field
  NSUndoManager *mUndoManager; //we handle our own undo to avoid stomping on bookmark undo
}
- (id)initWithFrame:(NSRect)bounds defaultFont:(NSFont*)defaultFont;
@end

@implementation AutoCompleteTextFieldEditor

// sets the defaultFont so that we don't paste in the wrong one
- (id)initWithFrame:(NSRect)bounds defaultFont:(NSFont*)defaultFont
{
  if ((self = [super initWithFrame:bounds])) {
    mDefaultFont = defaultFont;
    mUndoManager = [[NSUndoManager alloc] init];
  }
  return self;
}

-(void) dealloc
{
  [mUndoManager release];
  [super dealloc];
}

-(void)paste:(id)sender
{
  NSPasteboard *pboard = [NSPasteboard generalPasteboard];
  NSEnumerator *dataTypes = [[pboard types] objectEnumerator];
  NSString *aType;
  while ((aType = [dataTypes nextObject])) {
    if ([aType isEqualToString:NSStringPboardType]) {
      NSString *oldText = [pboard stringForType:NSStringPboardType];
      NSString *newText = [oldText stringByRemovingCharactersInSet:[NSCharacterSet controlCharacterSet]];
      NSRange aRange = [self selectedRange];
      if ([self shouldChangeTextInRange:aRange replacementString:newText]) {
        [[self textStorage] replaceCharactersInRange:aRange withString:newText];
        if (NSMaxRange(aRange) == 0 && mDefaultFont) // will only be true if the field is empty
          [self setFont:mDefaultFont]; // wrong font will be used otherwise
        [self didChangeText];
      }
      // after a paste, the insertion point should be after the pasted text
      unsigned int newInsertionPoint = aRange.location + [newText length];
      [self setSelectedRange:NSMakeRange(newInsertionPoint,0)];
      return;
    }
  }
}

- (NSUndoManager*)undoManager
{
  return mUndoManager;
}

// Opt-return and opt-enter should download the URL in the location bar
- (void)insertNewlineIgnoringFieldEditor:(id)sender
{
  BrowserWindowController* bwc = (BrowserWindowController *)[[self window] delegate];
  [bwc saveURL:nil url:[self string] suggestedFilename:nil];
}

// Drag & Drop Methods to match behavior of the AutoCompleteTextField
- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
  NSDragOperation sourceDragMask = [sender draggingSourceOperationMask];
  NSPasteboard *pboard = [sender draggingPasteboard];
  if ([[pboard types] containsObject:NSURLPboardType] ||
      [[pboard types] containsObject:NSStringPboardType] ||
      [[pboard types] containsObject:kCorePasteboardFlavorType_url]) {
    if (sourceDragMask & NSDragOperationCopy) {
      return NSDragOperationCopy;
    }
  }
  return NSDragOperationNone;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
  NSPasteboard *pboard = [sender draggingPasteboard];
  NSString *dragString = nil;
  if ([[pboard types] containsObject:kCorePasteboardFlavorType_url])
    dragString = [pboard stringForType:kCorePasteboardFlavorType_url];
  else if ([[pboard types] containsObject:NSURLPboardType])
    dragString = [[NSURL URLFromPasteboard:pboard] absoluteString];
  else if ([[pboard types] containsObject:NSStringPboardType]) {
    dragString = [pboard stringForType:NSStringPboardType];
    // Clean the string on the off chance it has line breaks, etc.
    dragString = [dragString stringByRemovingCharactersInSet:[NSCharacterSet controlCharacterSet]];
  }
  [self setString:dragString];
  return YES;
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
  [self selectAll:self];
}

@end
//////////////////////////////////////

#pragma mark -

//
// IconPopUpCell
//
// A popup cell that displays only an icon with no border, yet retains the
// behaviors of a popup menu. It's amazing you can't get this w/out having
// to subclass, but *shrug*.
//
@interface IconPopUpCell : NSPopUpButtonCell
{
@private
  NSImage* fImage;
  NSRect fSrcRect;      // rect cached for drawing, same size as image
}
- (id)initWithImage:(NSImage *)inImage;
@end

@implementation IconPopUpCell

- (id)initWithImage:(NSImage *)inImage
{
  if ((self = [super initTextCell:@"" pullsDown:YES]))
  {
    fImage = [inImage retain];
    fSrcRect = NSMakeRect(0,0,0,0);
    fSrcRect.size = [fImage size];
  }
  return self;
}

- (void)dealloc
{
  [fImage release];
  [super dealloc];
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
  [fImage setFlipped:[controlView isFlipped]];
  cellFrame.size = fSrcRect.size;                  // don't scale
  [fImage drawInRect:cellFrame fromRect:fSrcRect operation:NSCompositeSourceOver fraction:1.0];
}

@end

#pragma mark -

//
// interface ToolbarViewItem
//
// NSToolbarItem, by default, doesn't do validation for view items. Override
// that behavior to call |-validateToolbarItem:| on the item's target.
//
@interface ToolbarViewItem : NSToolbarItem
{
}
@end

@implementation ToolbarViewItem

//
// -validate
//
// Override default behavior (which does nothing at all for a view item) to
// ask the target to handle it. The target must perform all the appropriate
// enabling/disabling within |-validateToolbarItem:| because we can't know
// all the details. The return value is ignored.
//
- (void)validate
{
  id target = [self target];
  if ([target respondsToSelector:@selector(validateToolbarItem:)])
    [target validateToolbarItem:self];
}

//
// -setEnabled:
//
// Make sure that the menu form, which is used for the text-only view,
// is enabled and disabled with the rest of the toolbar item.
//
- (void)setEnabled:(BOOL)enabled
{
  [super setEnabled:enabled];
  [[self menuFormRepresentation] setEnabled:enabled];
}

@end

#pragma mark -

//
// interface ToolbarButton
//
// A subclass of NSButton that responds to |-setControlSize:| which
// comes from the toolbar when it changes sizes. Adjust the size
// of our associated NSToolbarItem when the call comes.
//
// Note that |-setControlSize:| is not part of NSView's api, but the
// toolbar code calls it anyway, without any documentation to that
// effect.
//
@interface ToolbarButton : NSButton
{
  NSToolbarItem* mToolbarItem;
}
-(id)initWithFrame:(NSRect)inFrame item:(NSToolbarItem*)inItem;
@end

@implementation ToolbarButton

-(id)initWithFrame:(NSRect)inFrame item:(NSToolbarItem*)inItem
{
  if ((self = [super initWithFrame:inFrame])) {
    mToolbarItem = inItem;
  }
  return self;
}

//
// -setControlSize:
//
// Called by the toolbar when the toolbar changes icon size. Adjust our
// toolbar item so that it can adjust larger or smaller.
//
- (void)setControlSize:(NSControlSize)size
{
  NSSize s;
  if (size == NSRegularControlSize) {
    s = NSMakeSize(32., 32.);
    [mToolbarItem setMinSize:s];
    [mToolbarItem setMaxSize:s];
  }
  else {
    s = NSMakeSize(24., 24.);
    [mToolbarItem setMinSize:s];
    [mToolbarItem setMaxSize:s];
  }
  [[self image] setSize:s];
}

//
// -controlSize
//
// The toolbar assumes this implemented whenever |-setControlSize:| is implemented,
// though I'm not sure why. 
//
- (NSControlSize)controlSize
{
  return [[self cell] controlSize];
}

@end

#pragma mark -

#if MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_4
// Declare private NSSpellChecker method.
@interface NSSpellChecker (CurrentlyPrivateWordLearning)
- (void)learnWord:(NSString *)word;
@end
#endif

#pragma mark -

@interface BrowserWindowController(Private)
  // open a new window or tab, but doesn't load anything into them. Must be matched
  // with a call to do that.
- (BrowserWindowController*)openNewWindow:(BOOL)aLoadInBG;
- (BrowserTabViewItem*)openNewTab:(BOOL)aLoadInBG;

- (void)setupToolbar;
- (void)setGeckoActive:(BOOL)inActive;
- (BOOL)isResponderGeckoView:(NSResponder*) responder;
- (NSString*)contextMenuNodeDocumentURL;
- (void)loadSourceForFrame:(BOOL)forFrame inBackground:(BOOL)loadInBackground;
- (void)transformFormatString:(NSMutableString*)inFormat domain:(NSString*)inDomain search:(NSString*)inSearch;
- (void)openNewWindowWithDescriptor:(nsISupports*)aDesc displayType:(PRUint32)aDisplayType loadInBackground:(BOOL)aLoadInBG;
- (void)openNewTabWithDescriptor:(nsISupports*)aDesc displayType:(PRUint32)aDisplayType loadInBackground:(BOOL)aLoadInBG;
- (void)performSearch:(WebSearchField*)inSearchField inView:(EOpenDestination)inDest inBackground:(BOOL)inLoadInBG;
- (int)historyIndexOfPageBeforeBookmarkManager;
- (void)goToLocationFromToolbarURLField:(AutoCompleteTextField *)inURLField inView:(EOpenDestination)inDest inBackground:(BOOL)inLoadInBG;

- (BrowserTabViewItem*)tabForBrowser:(BrowserWrapper*)inWrapper;
- (void)closeTab:(NSTabViewItem *)tab;
- (BookmarkViewController*)bookmarkViewControllerForCurrentTab;
- (void)showAddBookmarkDialogForAllTabs:(BOOL)isTabGroup;
- (void)sessionHistoryItemAtRelativeOffset:(int)indexOffset forWrapper:(BrowserWrapper*)inWrapper title:(NSString**)outTitle URL:(NSString**)outURLString;
- (NSString *)locationToolTipWithFormat:(NSString *)format title:(NSString *)backTitle URL:(NSString *)backURL;

- (void)showPopup:(nsIDOMPopupBlockedEvent*)aBlockedPopup;

- (void)clearContextMenuTarget;
- (void)updateLock:(unsigned int)securityState;

// create back/forward session history menus on toolbar button
- (IBAction)backMenu:(id)inSender;
- (IBAction)forwardMenu:(id)inSender;

- (void)reloadBrowserWrapper:(BrowserWrapper *)inWrapper sender:(id)sender;

// run a modal according to the users pref on opening a feed
- (BOOL)shouldWarnBeforeOpeningFeed;
- (void)buildFeedsDetectedListMenu:(NSNotification*)notifer; 
- (IBAction)openFeedInExternalApp:(id)sender;

- (void)insertForceAlternatesIntoMenu:(NSMenu *)inMenu;
- (BOOL)prepareSpellingSuggestionMenu:(NSMenu*)inMenu tag:(int)inTag;
- (void)addSpellingControlsToMenu:(NSMenu*)inMenu;
- (NSMenuItem*)spellingLanguageMenu;

- (void)setZoomState:(NSRect)newFrame defaultFrame:(NSRect)defaultFrame;

- (void)currentEditor:(nsIEditor**)outEditor;
- (void)getMisspelledWordRange:(nsIDOMRange**)outRange inlineSpellChecker:(nsIInlineSpellChecker**)outInlineChecker;

- (void)populateEnginesIntoAllSearchFields;
- (void)populateEnginesIntoSearchField:(WebSearchField*)searchField;
- (NSString*)lastKnownPreferredSearchEngine;
- (void)setLastKnownPreferredSearchEngine:(NSString*)inPreferredEngine;

@end

#pragma mark -

@implementation BrowserWindowController

- (id)initWithWindowNibName:(NSString *)windowNibName
{
  if ( (self = [super initWithWindowNibName:(NSString *)windowNibName]) )
  {
    // we cannot rely on the OS to correctly cascade new windows (RADAR bug 2972893)
    // so we turn off the cascading. We do it at the end of |windowDidLoad|
    [self setShouldCascadeWindows:NO];
    
    mInitialized = NO;
    mMoveReentrant = NO;
    mShouldAutosave = YES;
    mShouldLoadHomePage = YES;
    mChromeMask = 0;
    mThrobberImages = nil;
    mThrobberHandler = nil;
    mURLFieldEditor = nil;
  
    // register for services
    NSArray* sendTypes = [NSArray arrayWithObjects:NSStringPboardType, nil];
    NSArray* returnTypes = [NSArray arrayWithObjects:NSStringPboardType, nil];
    [NSApp registerServicesMenuSendTypes:sendTypes returnTypes:returnTypes];
    
    mDataOwner = new BWCDataOwner();
  }
  return self;
}

- (void)windowDidBecomeKey:(NSNotification *)notification
{
  BOOL windowWithMultipleTabs = ([mTabBrowser numberOfTabViewItems] > 1);
  // When this window gets focus, fix the Close Window modifiers depending
  // on whether we have multiple tabs
  [[NSApp delegate] adjustCloseTabMenuItemKeyEquivalent:windowWithMultipleTabs];
  [[NSApp delegate] adjustCloseWindowMenuItemKeyEquivalent:windowWithMultipleTabs];

  // the widget code (via -viewsWindowDidBecomeKey) takes care
  // of sending focus and activate events to gecko,
  // but we still need to call the embedding activate API
  [self setGeckoActive:YES];
}

- (void)windowDidResignKey:(NSNotification *)notification
{
  // when we are no longer the key window, set the Close shortcut back
  // to Command-W, for other windows.
  [[NSApp delegate] adjustCloseTabMenuItemKeyEquivalent:NO];
  [[NSApp delegate] adjustCloseWindowMenuItemKeyEquivalent:NO];

  // the widget code (via -viewsWindowDidResignKey) takes care
  // of sending focus and activate events to gecko,
  // but we still need to call the embedding activate API
  [self setGeckoActive:NO];
}

- (void)setGeckoActive:(BOOL)inActive
{
  if ([self isResponderGeckoView:[[self window] firstResponder]])
  {
    BrowserWindow* browserWin = (BrowserWindow*)[self window];
    [browserWin setSuppressMakeKeyFront:YES]; // prevent gecko focus bringing the window to the front
    [mBrowserView setBrowserActive:inActive];
    [browserWin setSuppressMakeKeyFront:NO];
  }
}

- (BOOL)isResponderGeckoView:(NSResponder*) responder
{
  return ([responder isKindOfClass:[NSView class]] &&
          [(NSView*)responder isDescendantOf:[mBrowserView browserView]]);
}

- (void)windowDidChangeMain
{
  // On 10.4, the unified title bar and toolbar is used, and the bookmark
  // toolbar's appearance is tweaked to better match the unified look.
  // Its active/inactive state needs to change along with the toolbar's.
  BrowserWindow* browserWin = (BrowserWindow*)[self window];
  if ([browserWin hasUnifiedToolbarAppearance]) {
    BookmarkToolbar* bookmarkToolbar = [self bookmarkToolbar];
    if (bookmarkToolbar)
      [bookmarkToolbar setNeedsDisplay:YES];
  }
}

- (void)windowDidBecomeMain:(NSNotification *)notification
{
  // MainController listens for window layering notifications and updates
  // bookmarks.
  [self windowDidChangeMain];
}

- (void)windowDidResignMain:(NSNotification *)notification
{
  // MainController listens for window layering notifications and updates
  // bookmarks.
  [self windowDidChangeMain];
}

-(void)mouseMoved:(NSEvent*)aEvent
{
  if (mMoveReentrant)
      return;
      
  mMoveReentrant = YES;
  NSView* view = [[[self window] contentView] hitTest: [aEvent locationInWindow]];
  [view mouseMoved: aEvent];
  [super mouseMoved: aEvent];
  mMoveReentrant = NO;
}

-(void)autosaveWindowFrame
{
  if (mShouldAutosave) {
    [[self window] saveFrameUsingName: NavigatorWindowFrameSaveName];
    
    // save the width and visibility of the search bar so it's consistent regardless of the
    // size of the next window we create
    const float searchBarWidth = [mSearchBar frame].size.width;
    [[NSUserDefaults standardUserDefaults] setFloat:searchBarWidth forKey:NavigatorWindowSearchBarWidth];
    BOOL isCollapsed = [mLocationToolbarView isSubviewCollapsed:mSearchBar];
    [[NSUserDefaults standardUserDefaults] setBool:isCollapsed forKey:NavigatorWindowSearchBarHidden];
  }
}

-(void)disableAutosave
{
  mShouldAutosave = NO;
}

-(void)disableLoadPage
{
  mShouldLoadHomePage = NO;
}

- (BOOL)windowShouldClose:(id)sender 
{
  if (mWindowClosesQuietly)
    return YES;

  if ([[PreferenceManager sharedInstance] getBooleanPref:"camino.warn_when_closing" withSuccess:NULL]) {
    unsigned int numberOfTabs = [mTabBrowser numberOfTabViewItems];
    if (numberOfTabs > 1) {
      NSString* closeMultipleTabWarning = NSLocalizedString(@"CloseWindowWithMultipleTabsExplFormat", @"");

      nsAlertController* controller = CHBrowserService::GetAlertController();
      BOOL dontShowAgain = NO;
      int result = NSAlertErrorReturn;

      @try {
        // note that this is a pseudo-sheet (and causes Cocoa to complain about runModalForWindow:relativeToWindow).
        // Ideally, we'd be able to get a panel from nsAlertController and run it as a sheet ourselves.
        result = [controller confirmCheckEx:[self window]
                                      title:NSLocalizedString(@"CloseWindowWithMultipleTabsMsg", @"")
                                       text:[NSString stringWithFormat:closeMultipleTabWarning, numberOfTabs]
                                    button1:NSLocalizedString(@"CloseWindowWithMultipleTabsButton", @"")
                                    button2:NSLocalizedString(@"CancelButtonText", @"")
                                    button3:nil
                                   checkMsg:NSLocalizedString(@"DontShowWarningAgainCheckboxLabel", @"")
                                 checkValue:&dontShowAgain];
      }
      @catch (id exception) {
      }
      
      if (dontShowAgain)
        [[PreferenceManager sharedInstance] setPref:"camino.warn_when_closing" toBoolean:NO];
      
      if (result != NSAlertDefaultReturn)
        return NO;
    }
  }

  // Check that all the tabs are closable
  return [mTabBrowser windowShouldClose];
}

- (void)windowWillClose:(NSNotification *)notification
{
  mClosingWindow = YES;

  [self autosaveWindowFrame];
  
  // ensure that the URL auto-complete popup is closed before the mork
  // database is shut down, or we crash
  [mURLBar clearResults];

  if (mDataOwner)
  {
    nsCOMPtr<nsIHistoryItems> history(do_QueryInterface(mDataOwner->mGlobalHistory));
    if (history)
      history->Flush();
  }

  delete mDataOwner;
  mDataOwner = NULL;

  nsCOMPtr<nsIPref> pref(do_GetService(NS_PREF_CONTRACTID));
  if (pref)
    pref->UnregisterCallback(gTabBarVisiblePref, TabBarVisiblePrefChangedCallback, self);
      
  // Tell the BrowserTabView the window is closed
  [mTabBrowser windowClosed];
  
  [[NSNotificationCenter defaultCenter] removeObserver:self];

  // autorelease just in case we're here because of a window closing
  // initiated from gecko, in which case this BWC would still be on the 
  // stack and may need to stay alive until it unwinds. We've already
  // shut down gecko above, so we can safely go away at a later time.
  [self autorelease];
}

//
// - stopAllPendingLoads
//
// For each tab, stop it from loading
//
- (void)stopAllPendingLoads
{
  int numTabs = [mTabBrowser numberOfTabViewItems];
  for (int i = 0; i < numTabs; i++) {
    NSTabViewItem* item = [mTabBrowser tabViewItemAtIndex: i];
    [[[item view] browserView] stop:NSStopLoadAll];
  }
}

- (void)dealloc
{
#if DEBUG
  NSLog(@"Browser controller died.");
#endif

  // clear the window-level undo manager used by the edit field. Not sure
  // why this isn't automatically done, but we'll leave objects hanging around in
  // the undo/redo if we do not. We also cannot do this in the url bar's dealloc, 
  // it only works if it's here.
  [[[self window] undoManager] removeAllActions];

  // active Gecko connections have already been shut down in |windowWillClose|
  // so we don't need to worry about that here. We only have to be careful
  // not to access anything related to the document, as it's been destroyed. The
  // superclass dealloc takes care of our child NSView's, which include the 
  // BrowserWrappers and their child CHBrowserViews.
  
  [self stopThrobber];
  [mThrobberImages release];
  [mURLFieldEditor release];
  [mLocationToolbarView release];
  [mLastKnownPreferredSearchEngine release];

  delete mDataOwner;    // paranoia; should have been deleted in -windowWillClose

  [super dealloc];
}

//
// windowDidLoad
//
// setup all the things we can't do in the nib. Note that we defer the setup of
// the bookmarks view until the user actually displays it the first time.
//
- (void)windowDidLoad
{
    [super windowDidLoad];

    // we shouldn't have to do this, yet for some reason removing it from
    // the toolbar destroys the view. However, this also helps us by ensuring
    // that we always have a search bar alive to do things with, like redirect
    // context menu searches to.
    [mLocationToolbarView retain];
    // explicitly don't save the splitter position, we want to save it oursevles
    // since we want a different behavior.
    [mLocationToolbarView setAutosaveSplitterPosition:NO];
    
    BOOL mustResizeChrome = NO;
    
    // hide the resize control if specified by the chrome mask
    if ( mChromeMask && !(mChromeMask & nsIWebBrowserChrome::CHROME_WINDOW_RESIZE) )
      [[self window] setShowsResizeIndicator:NO];
    
    if ((mChromeMask && !(mChromeMask & nsIWebBrowserChrome::CHROME_STATUSBAR)) ||
        [[NSUserDefaults standardUserDefaults] boolForKey:USER_DEFAULTS_HIDE_STATUS_BAR_KEY]) {
      // remove the status bar at the bottom
      [mStatusBar setHidden:YES];
      mustResizeChrome = YES;
    }
    if ([NSWorkspace isLeopardOrHigher]) {
      // On 10.5+, give the text an etched look for the textured status bar.
      [[mStatus cell] setBackgroundStyle:NSBackgroundStyleRaised];
      if (![mStatusBar isHidden])
        [[self window] setContentBorderThickness:NSHeight([mStatusBar bounds]) forEdge:NSMinYEdge];
    }
    else {
      // due to a cocoa issue with it updating the bounding box of two rects
      // that both needing updating instead of just the two individual rects
      // (radar 2194819), we need to make the text area opaque.
      [mStatus setBackgroundColor:[NSColor windowBackgroundColor]];
      [mStatus setDrawsBackground:YES];
    }

    // Set up the menus in the search fields
    [self setLastKnownPreferredSearchEngine:[[SearchEngineManager sharedSearchEngineManager] preferredSearchEngine]];
    [self populateEnginesIntoAllSearchFields];
    // Listen for changes to the collection of built-in search engines.
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(installedSearchEnginesDidChange:) 
                                                 name:kInstalledSearchEnginesDidChangeNotification
                                               object:nil];
    
    // Get our saved dimensions.
    NSRect oldFrame = [[self window] frame];
    BOOL haveSavedFrame = [[self window] setFrameUsingName: NavigatorWindowFrameSaveName];
    if (!haveSavedFrame)
    {
      NSRect mainScreenBounds = [[NSScreen mainScreen] visibleFrame];
      NSRect windowBounds = NSInsetRect(mainScreenBounds, 4.0f, 4.0f);
      const float kDefaultWindowWidth = 800.0f;
      if (NSWidth(windowBounds) > kDefaultWindowWidth)
        windowBounds.size.width = kDefaultWindowWidth;
      [[self window] setFrame:windowBounds display:YES];
    }

    if (NSEqualSizes(oldFrame.size, [[self window] frame].size))
      mustResizeChrome = YES;
    
    mInitialized = YES;

    [[self window] setAcceptsMouseMovedEvents:YES];

    [self setupToolbar];

    // Insert alternate menu items for force reload into the context menus that have reload items
    // This is necessary because IB won't accept shift modifiers on menu items that don't have keyEquivalents
    [self insertForceAlternatesIntoMenu:mPageMenu];
    [self insertForceAlternatesIntoMenu:mTabMenu];
    [self insertForceAlternatesIntoMenu:mTabBarMenu];

    // Listen to the context menu events from the URL bar for the feed icon
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(buildFeedsDetectedListMenu:)
                                                 name:kWillShowFeedMenu
                                               object:nil];

    // set the size of the search bar to the width it was last time and hide it
    // programmatically if it wasn't visible
    BOOL searchBarHidden = [[NSUserDefaults standardUserDefaults] boolForKey:NavigatorWindowSearchBarHidden];
    if (searchBarHidden)
      [mLocationToolbarView collapseSubviewAtIndex:1];
    else {
      float searchBarWidth = [[NSUserDefaults standardUserDefaults] floatForKey:NavigatorWindowSearchBarWidth];
      if (searchBarWidth < kEpsilon)
        searchBarWidth = kDefaultSearchBarWidth;
      const float currentWidth = [mLocationToolbarView frame].size.width;
      float newDividerPosition = currentWidth - searchBarWidth - [mLocationToolbarView dividerThickness];
      if (newDividerPosition < kMinimumURLAndSearchBarWidth)
        newDividerPosition = kMinimumURLAndSearchBarWidth;
      [mLocationToolbarView setLeftWidth:newDividerPosition];
      [mLocationToolbarView adjustSubviews];
    }
    
    // set up autohide behavior on tab browser and register for changes on that pref. The
    // default is for it to hide when only 1 tab is visible, so if no pref is found, it will
    // be NO, and that works. However, if any of the JS chrome flags are set, we don't want
    // to let the tab bar show so leave it off and don't register for the pref updates.
    BOOL allowTabBar = YES;
    if (mChromeMask && (!(mChromeMask & nsIWebBrowserChrome::CHROME_STATUSBAR) ||
                        !(mChromeMask & nsIWebBrowserChrome::CHROME_PERSONAL_TOOLBAR)))
      allowTabBar = NO;
    if (allowTabBar) {
      BOOL tabBarAlwaysVisible = [[PreferenceManager sharedInstance] getBooleanPref:gTabBarVisiblePref withSuccess:nil];
      [mTabBrowser setBarAlwaysVisible:tabBarAlwaysVisible];
      nsCOMPtr<nsIPref> pref(do_GetService(NS_PREF_CONTRACTID));
      if (pref)
        pref->RegisterCallback(gTabBarVisiblePref, TabBarVisiblePrefChangedCallback, self);
    }

    // remove the dummy tab view
    [mTabBrowser removeTabViewItem:[mTabBrowser tabViewItemAtIndex:0]];
    
    // create ourselves a new tab and fill it with the appropriate content. If we
    // have a URL pending to be opened here, don't load anything in it, otherwise,
    // load the homepage if that's what the user wants (or about:blank).
    [self createNewTab:(mPendingURL ? eNewTabEmpty : (mShouldLoadHomePage ? eNewTabHomepage : eNewTabAboutBlank))];
    
    // we have a url "pending" from the "open new window with link" command. Deal
    // with it now that everything is loaded.
    if (mPendingURL) {
      if (mShouldLoadHomePage)
        [self loadURL:mPendingURL referrer:mPendingReferrer focusContent:mPendingActivate allowPopups:mPendingAllowPopups];
      [mPendingURL release];
      [mPendingReferrer release];
      mPendingURL = mPendingReferrer = nil;
    }
    
    [mPersonalToolbar rebuildButtonList];

    BOOL chromeHidesToolbar = (mChromeMask != 0) && !(mChromeMask & nsIWebBrowserChrome::CHROME_PERSONAL_TOOLBAR);
    if (chromeHidesToolbar || ![self shouldShowBookmarkToolbar])
      [mPersonalToolbar setVisible:NO];
    
    if (mustResizeChrome)
      [mContentView resizeSubviewsWithOldSize:[mContentView frame].size];
      
    // stagger window from last browser, if there is one. we can't just use autoposition
    // because it doesn't work on multiple monitors (radar bug 2972893). |frontmostBrowserWindow|
    // only gets fully chromed windows, so this will do the right thing for popups (yay!).
    const int kWindowStaggerOffset = 22;
    
    NSWindow* lastBrowser = [[NSApp delegate] frontmostBrowserWindow];
    if ( lastBrowser && lastBrowser != [self window] ) {
      NSRect screenRect = [[lastBrowser screen] visibleFrame];
      NSRect testBrowserFrame = [lastBrowser frame];
      NSPoint previousOrigin = testBrowserFrame.origin;
      testBrowserFrame.origin.x += kWindowStaggerOffset;
      testBrowserFrame.origin.y -= kWindowStaggerOffset;
      
      // check if this new window position would overlap the dock or go off the screen. We test
      // this by ensuring that it is contained by the  visible screen rect (excluding dock). If
      // not, the window juts out somewhere and needs to be repositioned.
      if ( !NSContainsRect(screenRect, testBrowserFrame) ) {
        // if a normal cascade fails, try shifting horizontally and reseting vertically
        testBrowserFrame.origin.y = NSMaxY(screenRect) - testBrowserFrame.size.height;
        if ( !NSContainsRect(screenRect, testBrowserFrame) ) {
          // if shifting right also fails, try shifting vertically and reseting horizontally instead
          testBrowserFrame.origin.x = NSMinX(screenRect);
          testBrowserFrame.origin.y = previousOrigin.y - kWindowStaggerOffset;
          if ( !NSContainsRect(screenRect, testBrowserFrame) ) {
            // if all else fails, give up and reset to the upper left corner
            testBrowserFrame.origin.x = NSMinX(screenRect);
            testBrowserFrame.origin.y = NSMaxY(screenRect) - testBrowserFrame.size.height;
          }
        }
      }
      // actually move the window
      [[self window] setFrameOrigin: testBrowserFrame.origin];
    }
    
    // cache the original window frame, we may need this for correct zooming
    mLastFrameSize = [[self window] frame];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(newTab:)
                                        name:kTabBarBackgroundDoubleClickedNotification object:mTabBrowser];

}

- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)proposedFrameSize
{
  //if ( mChromeMask && !(mChromeMask & nsIWebBrowserChrome::CHROME_WINDOW_RESIZE) )
  //  return [[self window] frame].size;
  return proposedFrameSize;
}

// zoom to fit contents
- (NSRect)windowWillUseStandardFrame:(NSWindow *)sender defaultFrame:(NSRect)defaultFrame
{
  // Maximize to screen
  if (([[NSApp currentEvent] modifierFlags] & NSShiftKeyMask) ||
      [[self browserWrapper] isEmpty] ||
      [self bookmarkManagerIsVisible])
  {
    [self setZoomState:defaultFrame defaultFrame:defaultFrame];
    return defaultFrame;
  }

  // Get the needed content size
  nsCOMPtr<nsIDOMWindow> contentWindow = [[mBrowserView browserView] contentWindow];
  if (!contentWindow) {
    [self setZoomState:defaultFrame defaultFrame:defaultFrame];
    return defaultFrame;
  }

  PRInt32 contentWidth = 0, contentHeight = 0;
  const PRInt32 kMinSaneHeight = 20; // for bug 361049
  GeckoUtils::GetIntrinsicSize(contentWindow, &contentWidth, &contentHeight);
  if (contentWidth <= 0 || contentHeight <= kMinSaneHeight) {
    // Something went wrong, maximize to screen
    [self setZoomState:defaultFrame defaultFrame:defaultFrame];
    return defaultFrame;
  }

  // Get the current content size and calculate the changes.
  NSSize curFrameSize = [[mBrowserView browserView] frame].size;
  float widthChange   = contentWidth  - curFrameSize.width;
  float heightChange  = contentHeight - curFrameSize.height;

  // The values from GeckoUtils::GetIntrinsicSize may be rounded down, add 1 extra pixel but
  // only if the window will be smaller than the screen (see bug 360878)
  NSRect stdFrame     = [[self window] frame];
  if (stdFrame.size.width + widthChange < defaultFrame.size.width)
    widthChange += 1;

  if (stdFrame.size.height + heightChange < defaultFrame.size.height)
    heightChange += 1;

  // Change the window size, but don't let it be to narrow
  stdFrame.size.width = MAX([[self window] minSize].width, stdFrame.size.width + widthChange);

  if ([mPersonalToolbar isVisible])
    // if the personal toolbar is shown we need to adjust for its height change
    heightChange += [mPersonalToolbar computeHeight:stdFrame.size.width startingAtIndex:0]
                    - [mPersonalToolbar frame].size.height;

  stdFrame.size.height += heightChange;
  stdFrame.origin.y    -= heightChange;

  // add space for scrollers if needed
  float scrollerSize = [NSScroller scrollerWidth];

  if (stdFrame.size.height > defaultFrame.size.height)
    stdFrame.size.width += scrollerSize;

  if (stdFrame.size.width > defaultFrame.size.width) {
    stdFrame.size.height += scrollerSize;
    stdFrame.origin.y    -= scrollerSize;
  }

  [self setZoomState:stdFrame defaultFrame:defaultFrame];
  return stdFrame;
} 

- (BOOL)windowShouldZoom:(NSWindow *)sender toFrame:(NSRect)newFrame
{
  return mShouldZoom;
}

// Don't zoom a window that has not been zoomed before and we're not changing its size,
// strange things will happen (see bug 155956 for details)
- (void)setZoomState:(NSRect)newFrame defaultFrame:(NSRect)defaultFrame
{
  const int kMinZoomChange = 10;

  mShouldZoom = (ABS(mLastFrameSize.size.width  - [[self window] frame].size.width)  > kMinZoomChange ||
                 ABS(mLastFrameSize.size.height - [[self window] frame].size.height) > kMinZoomChange ||
                 ABS(MIN(newFrame.size.width,  defaultFrame.size.width)  - [[self window] frame].size.width)  > kMinZoomChange ||
                 ABS(MIN(newFrame.size.height, defaultFrame.size.height) - [[self window] frame].size.height) > kMinZoomChange);
}

- (void)windowDidResize:(NSNotification *)aNotification
{
  [self updateWindowTitle:[mBrowserView pageTitle]];

  // Update the cached windowframe unless we are zooming the window
  if (!mShouldZoom)
    mLastFrameSize = [[self window] frame];
  else
    // reset mShouldZoom so further resizes will be catched
    mShouldZoom = NO;
}

#pragma mark -

// -createToolbarPopupButton:
//
// Create a new instance of one of our special click-hold popup buttons that knows
// how to display a menu on click-hold. Associate it with the toolbar item |inItem|.
- (NSButton*)createToolbarPopupButton:(NSToolbarItem*)inItem
{
  NSRect frame = NSMakeRect(0.,0.,32.,32.);
  NSButton* button = [[[ToolbarButton alloc] initWithFrame:frame item:inItem] autorelease];
  if (button) {
    DraggableImageAndTextCell* newCell = [[[DraggableImageAndTextCell alloc] initTextCell:@""] autorelease];
    [newCell setDraggable:YES];
    [newCell setClickHoldTimeout:0.45];
    [button setCell:newCell];

    [button setBezelStyle:NSRegularSquareBezelStyle];
    [button setButtonType:NSMomentaryChangeButton];
    [button setImagePosition:NSImageOnly];
    [button setBordered:NO];
  }
  return button;
}

- (void)setupToolbar
{
  NSToolbar *toolbar = [[[NSToolbar alloc] initWithIdentifier:BrowserToolbarIdentifier] autorelease];
  
  [toolbar setDisplayMode:NSToolbarDisplayModeIconOnly];
  [toolbar setAllowsUserCustomization:YES];
  [toolbar setAutosavesConfiguration:YES];
  [toolbar setDelegate:self];
  [[self window] setToolbar:toolbar];
  
  // for a chromed window without the toolbar or locationbar flag, hide the toolbar (but allow the user to show it)
  if (mChromeMask && (!(mChromeMask & nsIWebBrowserChrome::CHROME_TOOLBAR) &&
                      !(mChromeMask & nsIWebBrowserChrome::CHROME_LOCATIONBAR)))
  {
    [toolbar setAutosavesConfiguration:NO]; // make sure this hiding doesn't get saved
    [toolbar setVisible:NO];
  }
}

// toolbarWillAddItem: (toolbar delegate method)
//
// Called when a button is about to be added to a toolbar. This is where we should
// cache items we may need later.
// (void)toolbarWillAddItem:(NSNotification *)notification
//{
//  (Nothing needed at the moment.)
//}

//
// toolbarDidRemoveItem: (toolbar delegate method)
//
// Called when a button is about to be removed from a toolbar. This is where we should
// uncache items so we don't access them after they're gone.
//
- (void)toolbarDidRemoveItem:(NSNotification *)notification
{
  NSToolbarItem* item = [[notification userInfo] objectForKey:@"item"];
  if ( [[item itemIdentifier] isEqual:ThrobberToolbarItemIdentifier] )
    [self stopThrobber];
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
  NSArray *predefinedItems = [NSArray arrayWithObjects: BackToolbarItemIdentifier,
                                                        ForwardToolbarItemIdentifier,
                                                        ReloadToolbarItemIdentifier,
                                                        StopToolbarItemIdentifier,
                                                        HomeToolbarItemIdentifier,
                                                        CombinedLocationToolbarItemIdentifier,
                                                        BookmarksToolbarItemIdentifier,
                                                        ThrobberToolbarItemIdentifier,
                                                        PrintToolbarItemIdentifier,
                                                        ViewSourceToolbarItemIdentifier,
                                                        BookmarkToolbarItemIdentifier,
                                                        NewTabToolbarItemIdentifier,
                                                        CloseTabToolbarItemIdentifier,
                                                        TextBiggerToolbarItemIdentifier,
                                                        TextSmallerToolbarItemIdentifier,
                                                        SendURLToolbarItemIdentifier,
                                                        NSToolbarCustomizeToolbarItemIdentifier,
                                                        NSToolbarFlexibleSpaceItemIdentifier,
                                                        NSToolbarSpaceItemIdentifier,
                                                        NSToolbarSeparatorItemIdentifier,
                                                        DLManagerToolbarItemIdentifier,
                                                        FormFillToolbarItemIdentifier,
                                                        HistoryToolbarItemIdentifier,
                                                        nil];
  // Add script items and return.
  return [predefinedItems arrayByAddingObjectsFromArray:[ToolbarScriptItem scriptItemIdentifiers]];
}

// + toolbarDefaults
//
// Parse a plist called "ToolbarDefaults.plist" in our Resources subfolder. This
// allows anyone to easily customize the default set w/out having to recompile. We
// hold onto the list for the duration of the app to avoid reparsing it every
// time.
+ (NSArray*) toolbarDefaults
{
  if ( !sToolbarDefaults ) {
    sToolbarDefaults = [NSArray arrayWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"ToolbarDefaults" ofType:@"plist"]];
    [sToolbarDefaults retain];
  }
  return sToolbarDefaults;
}

+ (BOOL)shouldLoadInBackgroundForDestination:(EOpenDestination)destination
                                      sender:(id)sender;
{
  BOOL loadInBackground = NO;
  if (destination == eDestinationNewTab) {
    loadInBackground =
      [[PreferenceManager sharedInstance] getBooleanPref:"browser.tabs.loadInBackground"
                                             withSuccess:NULL];
  }

  if ([sender respondsToSelector:@selector(keyEquivalentModifierMask)]) {
    if ([sender keyEquivalentModifierMask] & NSShiftKeyMask)
      loadInBackground = !loadInBackground;
  }
  else {
    if ([[NSApp currentEvent] modifierFlags] & NSShiftKeyMask)
      loadInBackground = !loadInBackground;
  }

  return loadInBackground;
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
  // try to get the defaults from the plist, but if not, hardcode something so
  // the user always has a toolbar.
  NSArray* defaults = [BrowserWindowController toolbarDefaults];
  NS_ASSERTION(defaults, "Couldn't load toolbar defaults from plist");
  return ( defaults ? defaults : [NSArray arrayWithObjects:   BackToolbarItemIdentifier,
                                        ForwardToolbarItemIdentifier,
                                        ReloadToolbarItemIdentifier,
                                        StopToolbarItemIdentifier,
                                        CombinedLocationToolbarItemIdentifier,
                                        BookmarksToolbarItemIdentifier,
                                        nil] );
}

// XXX use a dictionary to speed up the following?
// Better to just read it from a plist.
- (NSToolbarItem *) toolbar:(NSToolbar *)toolbar
      itemForItemIdentifier:(NSString *)itemIdent
  willBeInsertedIntoToolbar:(BOOL)willBeInserted
{
  NSToolbarItem *toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdent] autorelease];
  if ( [itemIdent isEqual:BackToolbarItemIdentifier] && willBeInserted ) {
    // create a new toolbar item that knows how to do validation
    toolbarItem = [[[ToolbarViewItem alloc] initWithItemIdentifier:itemIdent] autorelease];
    
    NSButton* button = [self createToolbarPopupButton:toolbarItem];
    [toolbarItem setLabel:NSLocalizedString(@"Back", nil)];
    [toolbarItem setPaletteLabel:NSLocalizedString(@"Go Back", nil)];

    NSSize size = NSMakeSize(32., 32.);
    NSImage* icon = [NSImage imageNamed:@"back"];
    [icon setScalesWhenResized:YES];
    [button setImage:icon];
    
    [toolbarItem setView:button];
    [toolbarItem setMinSize:size];
    [toolbarItem setMaxSize:size];
    
    [button setTarget:self];
    [button setAction:@selector(back:)];
    [toolbarItem setTarget:self];
    [toolbarItem setAction:@selector(back:)];      // so validateToolbarItem: works correctly
    [[button cell] setClickHoldAction:@selector(backMenu:)];

    NSMenuItem *menuFormRep = [[[NSMenuItem alloc] init] autorelease];
    [menuFormRep setTarget:self];
    [menuFormRep setAction:@selector(back:)];
    [menuFormRep setTitle:[toolbarItem label]];

    [toolbarItem setMenuFormRepresentation:menuFormRep];
  }
  else if ([itemIdent isEqual:BackToolbarItemIdentifier]) {
    // not going onto the toolbar, don't need to go through the gynmastics above
    // and create a separate view
    [toolbarItem setLabel:NSLocalizedString(@"Back", nil)];
    [toolbarItem setPaletteLabel:NSLocalizedString(@"Go Back", nil)];
    [toolbarItem setImage:[NSImage imageNamed:@"back"]];
  }
  else if ( [itemIdent isEqual:ForwardToolbarItemIdentifier] && willBeInserted ) {
    // create a new toolbar item that knows how to do validation
    toolbarItem = [[[ToolbarViewItem alloc] initWithItemIdentifier:itemIdent] autorelease];
    
    NSButton* button = [self createToolbarPopupButton:toolbarItem];
    [toolbarItem setLabel:NSLocalizedString(@"Forward", nil)];
    [toolbarItem setPaletteLabel:NSLocalizedString(@"Go Forward", nil)];

    NSSize size = NSMakeSize(32., 32.);
    NSImage* icon = [NSImage imageNamed:@"forward"];
    [icon setScalesWhenResized:YES];
    [button setImage:icon];

    [toolbarItem setView:button];
    [toolbarItem setMinSize:size];
    [toolbarItem setMaxSize:size];
    
    [button setTarget:self];
    [button setAction:@selector(forward:)];
    [toolbarItem setTarget:self];
    [toolbarItem setAction:@selector(forward:)];      // so validateToolbarItem: works correctly
    [[button cell] setClickHoldAction:@selector(forwardMenu:)];

    NSMenuItem *menuFormRep = [[[NSMenuItem alloc] init] autorelease];
    [menuFormRep setTarget:self];
    [menuFormRep setAction:@selector(forward:)];
    [menuFormRep setTitle:[toolbarItem label]];

    [toolbarItem setMenuFormRepresentation:menuFormRep];
  }
  else if ([itemIdent isEqual:ForwardToolbarItemIdentifier]) {
    // not going onto the toolbar, don't need to go through the gynmastics above
    // and create a separate view
    [toolbarItem setLabel:NSLocalizedString(@"Forward", nil)];
    [toolbarItem setPaletteLabel:NSLocalizedString(@"Go Forward", nil)];
    [toolbarItem setImage:[NSImage imageNamed:@"forward"]];
  }
  else if ([itemIdent isEqual:ReloadToolbarItemIdentifier]) {
    [toolbarItem setLabel:NSLocalizedString(@"Reload", @"Reload")];
    [toolbarItem setPaletteLabel:NSLocalizedString(@"Reload Page", nil)];
    [toolbarItem setToolTip:NSLocalizedString(@"ReloadToolTip", nil)];
    [toolbarItem setImage:[NSImage imageNamed:@"reload"]];
    [toolbarItem setTarget:self];
    [toolbarItem setAction:@selector(reload:)];
  }
  else if ([itemIdent isEqual:StopToolbarItemIdentifier]) {
    [toolbarItem setLabel:NSLocalizedString(@"Stop", nil)];
    [toolbarItem setPaletteLabel:NSLocalizedString(@"Stop Loading", nil)];
    [toolbarItem setToolTip:NSLocalizedString(@"StopToolTip", nil)];
    [toolbarItem setImage:[NSImage imageNamed:@"stop"]];
    [toolbarItem setTarget:self];
    [toolbarItem setAction:@selector(stop:)];
  }
  else if ([itemIdent isEqual:HomeToolbarItemIdentifier]) {
    [toolbarItem setLabel:NSLocalizedString(@"Home", nil)];
    [toolbarItem setPaletteLabel:NSLocalizedString(@"Go Home", nil)];
    [toolbarItem setToolTip:NSLocalizedString(@"HomeToolTip", nil)];
    [toolbarItem setImage:[NSImage imageNamed:@"home"]];
    [toolbarItem setTarget:self];
    [toolbarItem setAction:@selector(home:)];
  }
  else if ([itemIdent isEqual:BookmarksToolbarItemIdentifier]) {
    [toolbarItem setLabel:NSLocalizedString(@"Manage Bookmarks", nil)];
    [toolbarItem setPaletteLabel:NSLocalizedString(@"Manage Bookmarks", nil)];
    [toolbarItem setToolTip:NSLocalizedString(@"ShowBookmarkMgrToolTip", nil)];
    [toolbarItem setImage:[NSImage imageNamed:@"manager"]];
    [toolbarItem setTarget:self];
    [toolbarItem setAction:@selector(manageBookmarks:)];
  }
  else if ([itemIdent isEqual:ThrobberToolbarItemIdentifier]) {
    [toolbarItem setLabel:@""];
    [toolbarItem setPaletteLabel:NSLocalizedString(@"Progress", nil)];
    [toolbarItem setToolTip:NSLocalizedStringFromTable(@"ThrobberPage", @"WebsiteDefaults", nil)];
    [toolbarItem setImage:[NSImage imageNamed:@"throbber-01"]];
    [toolbarItem setTarget:self];
    [toolbarItem setTag:'Thrb'];
    [toolbarItem setAction:@selector(clickThrobber:)];
  }
  else if ([itemIdent isEqual:CombinedLocationToolbarItemIdentifier]) {
    NSMenuItem *menuFormRep = [[[NSMenuItem alloc] init] autorelease];

    [toolbarItem setLabel:NSLocalizedString(@"Location", nil)];
    [toolbarItem setPaletteLabel:NSLocalizedString(@"Location", nil)];
    [toolbarItem setView:mLocationToolbarView];
    [toolbarItem setMinSize:NSMakeSize(kMinimumLocationBarWidth, NSHeight([mLocationToolbarView frame]))];
    [toolbarItem setMaxSize:NSMakeSize(FLT_MAX, NSHeight([mLocationToolbarView frame]))];

    [menuFormRep setTarget:self];
    [menuFormRep setAction:@selector(performAppropriateLocationAction)];
    [menuFormRep setTitle:[toolbarItem label]];

    [toolbarItem setMenuFormRepresentation:menuFormRep];
  }
  else if ([itemIdent isEqual:PrintToolbarItemIdentifier]) {
    [toolbarItem setLabel:NSLocalizedString(@"Print", nil)];
    [toolbarItem setPaletteLabel:NSLocalizedString(@"Print", nil)];
    [toolbarItem setToolTip:NSLocalizedString(@"PrintToolTip", nil)];
    [toolbarItem setImage:[NSImage imageNamed:@"print"]];
    [toolbarItem setTarget:self];
    [toolbarItem setAction:@selector(printDocument:)];
  }
  else if ([itemIdent isEqual:ViewSourceToolbarItemIdentifier]) {
    [toolbarItem setLabel:NSLocalizedString(@"View Source", nil)];
    [toolbarItem setPaletteLabel:NSLocalizedString(@"View Page Source", nil)];
    [toolbarItem setToolTip:NSLocalizedString(@"ViewSourceToolTip", nil)];
    [toolbarItem setImage:[NSImage imageNamed:@"showsource"]];
    [toolbarItem setTarget:self];
    [toolbarItem setAction:@selector(viewSource:)];
  }
  else if ([itemIdent isEqual:BookmarkToolbarItemIdentifier]) {
    [toolbarItem setLabel:NSLocalizedString(@"Bookmark", nil)];
    [toolbarItem setPaletteLabel:NSLocalizedString(@"Bookmark Page", nil)];
    [toolbarItem setToolTip:NSLocalizedString(@"BookmarkToolTip", nil)];
    [toolbarItem setImage:[NSImage imageNamed:@"add_to_bookmark"]];
    [toolbarItem setTarget:self];
    [toolbarItem setAction:@selector(addBookmark:)];
  }
  else if ([itemIdent isEqual:TextBiggerToolbarItemIdentifier]) {
    [toolbarItem setLabel:NSLocalizedString(@"BigText", nil)];
    [toolbarItem setPaletteLabel:NSLocalizedString(@"BigText", nil)];
    [toolbarItem setToolTip:NSLocalizedString(@"BigTextToolTip", nil)];
    [toolbarItem setImage:[NSImage imageNamed:@"textBigger"]];
    [toolbarItem setTarget:self];
    [toolbarItem setAction:@selector(makeTextBigger:)];
  }
  else if ([itemIdent isEqual:TextSmallerToolbarItemIdentifier]) {
    [toolbarItem setLabel:NSLocalizedString(@"SmallText", nil)];
    [toolbarItem setPaletteLabel:NSLocalizedString(@"SmallText", nil)];
    [toolbarItem setToolTip:NSLocalizedString(@"SmallTextToolTip", nil)];
    [toolbarItem setImage:[NSImage imageNamed:@"textSmaller"]];
    [toolbarItem setTarget:self];
    [toolbarItem setAction:@selector(makeTextSmaller:)];
  }
  else if ([itemIdent isEqual:NewTabToolbarItemIdentifier]) {
    [toolbarItem setLabel:NSLocalizedString(@"NewTab", nil)];
    [toolbarItem setPaletteLabel:NSLocalizedString(@"NewTab", nil)];
    [toolbarItem setToolTip:NSLocalizedString(@"NewTabToolTip", nil)];
    [toolbarItem setImage:[NSImage imageNamed:@"newTab"]];
    [toolbarItem setTarget:self];
    [toolbarItem setAction:@selector(newTab:)];
  }
  else if ([itemIdent isEqual:CloseTabToolbarItemIdentifier]) {
    [toolbarItem setLabel:NSLocalizedString(@"CloseTab", nil)];
    [toolbarItem setPaletteLabel:NSLocalizedString(@"CloseTab", nil)];
    [toolbarItem setToolTip:NSLocalizedString(@"CloseTabToolTip", nil)];
    [toolbarItem setImage:[NSImage imageNamed:@"closeTab"]];
    [toolbarItem setTarget:self];
    [toolbarItem setAction:@selector(closeCurrentTab:)];
  }
  else if ([itemIdent isEqual:SendURLToolbarItemIdentifier]) {
    [toolbarItem setLabel:NSLocalizedString(@"SendLink", nil)];
    [toolbarItem setPaletteLabel:NSLocalizedString(@"SendLinkPaletteLabel", nil)];
    [toolbarItem setToolTip:NSLocalizedString(@"SendLinkToolTip", nil)];
    [toolbarItem setImage:[NSImage imageNamed:@"sendLink"]];
    [toolbarItem setTarget:self];
    [toolbarItem setAction:@selector(sendURL:)];
  }
  else if ([itemIdent isEqual:DLManagerToolbarItemIdentifier]) {
    [toolbarItem setLabel:NSLocalizedString(@"Downloads", nil)];
    [toolbarItem setPaletteLabel:NSLocalizedString(@"Downloads", nil)];
    [toolbarItem setToolTip:NSLocalizedString(@"DownloadsToolTip", nil)];
    [toolbarItem setImage:[NSImage imageNamed:@"dl_manager"]];
    [toolbarItem setTarget:[ProgressDlgController sharedDownloadController]];
    [toolbarItem setAction:@selector(showWindow:)];
  }
  else if ([itemIdent isEqual:FormFillToolbarItemIdentifier]) {
    [toolbarItem setLabel:NSLocalizedString(@"Fill Form", nil)];
    [toolbarItem setPaletteLabel:NSLocalizedString(@"Fill Form", nil)];
    [toolbarItem setToolTip:NSLocalizedString(@"FillFormToolTip", nil)];
    [toolbarItem setImage:[NSImage imageNamed:@"autofill"]];
    [toolbarItem setTarget:self];
    [toolbarItem setAction:@selector(fillForm:)];
  }
  else if ([itemIdent isEqual:HistoryToolbarItemIdentifier]) {
    [toolbarItem setLabel:NSLocalizedString(@"ShowHistory", nil)];
    [toolbarItem setPaletteLabel:NSLocalizedString(@"ShowHistory", nil)];
    [toolbarItem setToolTip:NSLocalizedString(@"ShowHistoryToolTip", nil)];
    [toolbarItem setImage:[NSImage imageNamed:@"history"]];
    [toolbarItem setTarget:self];
    [toolbarItem setAction:@selector(manageHistory:)];
  }
  else if ([itemIdent hasPrefix:kScriptItemIdentifierPrefix]) {
    toolbarItem = [[[ToolbarScriptItem alloc] initWithItemIdentifier:itemIdent] autorelease];
  }
  else {
    toolbarItem = nil;
  }

  return toolbarItem;
}

// This method handles the enabling/disabling of the toolbar buttons.
- (BOOL)validateToolbarItem:(NSToolbarItem *)theItem
{
  // Check the action and see if it matches.
  SEL action = [theItem action];
  // NSLog(@"Validating toolbar item %@ with selector %s", [theItem label], action);
  if (action == @selector(back:)) {
    // if the bookmark manager is showing, we enable the back button so that
    // they can click back to return to the webpage they were viewing.
    BOOL enable = [[mBrowserView browserView] canGoBack];

    // we have to handle all the enabling/disabling ourselves because this
    // toolbar button is a view item. Note the return value is ignored.
    [theItem setEnabled:enable];

    // set the tooltip to the previous URL and title
    NSString* toolTipString = nil;
    if ([theItem isEnabled]) { // if there is a previous URL
      NSString* backTitle = nil;
      NSString* backURL   = nil;
      [self sessionHistoryItemAtRelativeOffset:-1 forWrapper:[self browserWrapper] title:&backTitle URL:&backURL];
      toolTipString = [self locationToolTipWithFormat:@"BackToolTipFormat" title:backTitle URL:backURL];
    }

    if (toolTipString)
      [theItem setToolTip:toolTipString];
    else  // there's no previous URL or something was nil during the setup, give it a stock tooltip
      [theItem setToolTip:NSLocalizedString(@"BackToolTip", nil)];

    return enable;
  }
  else if (action == @selector(forward:)) {
    // we have to handle all the enabling/disabling ourselves because this
    // toolbar button is a view item. Note the return value is ignored.
    BOOL enable = [[mBrowserView browserView] canGoForward];
    [theItem setEnabled:enable];

    // set the tooltip to the next URL and title
    NSString* toolTipString = nil;
    if ([theItem isEnabled]) { // if there is a previous URL
      NSString* forwardTitle = nil;
      NSString* forwardURL   = nil;
      [self sessionHistoryItemAtRelativeOffset:1 forWrapper:[self browserWrapper] title:&forwardTitle URL:&forwardURL];
      toolTipString = [self locationToolTipWithFormat:@"ForwardToolTipFormat" title:forwardTitle URL:forwardURL];
    }

    if (toolTipString)
      [theItem setToolTip:toolTipString];
    else  // there's no next URL or something was nil during the setup, give it a stock tooltip
      [theItem setToolTip:NSLocalizedString(@"ForwardToolTip", nil)];

    return enable;
  }
  else if (action == @selector(manageBookmarks:)) {
    if ([self bookmarkManagerIsVisible]) {
      [theItem setLabel:NSLocalizedString(@"Hide Bookmarks", nil)];
      [theItem setPaletteLabel:NSLocalizedString(@"Hide Bookmarks", nil)];
      [theItem setToolTip:NSLocalizedString(@"HideBookmarkMgrToolTip", nil)];
      [theItem setImage:[NSImage imageNamed:@"hidemanager"]];
    }
    else {
      [theItem setLabel:NSLocalizedString(@"Manage Bookmarks", nil)];
      [theItem setPaletteLabel:NSLocalizedString(@"Manage Bookmarks", nil)];
      [theItem setToolTip:NSLocalizedString(@"ShowBookmarkMgrToolTip", nil)];
      [theItem setImage:[NSImage imageNamed:@"manager"]];
    }

    return ![self bookmarkManagerIsVisible] || [self canHideBookmarks];
  }

  return [self validateActionBySelector:action];
}

//
// Helper method for setting formatted tooltips with a title and url (like the back/forward tooltips)
//
- (NSString *)locationToolTipWithFormat:(NSString *)format title:(NSString *)backTitle URL:(NSString *)backURL
{
  if (backTitle && backURL) {
    NSString* toolTipString = [NSString stringWithFormat:NSLocalizedString(format, nil), backTitle, backURL];
    // using "\n\n" as a tooltip string causes Cocoa to hang when displaying the tooltip,
    // so be paranoid about not doing that
    if (![toolTipString isEqualToString:@"\n\n"])
      return toolTipString;
  }

  return nil;
}

//
// -splitView:canCollapseSubview:
// NSSplitView delegate
// 
// Allow the user (read: smokey) to collapse the search bar but not the url bar.
//
- (BOOL)splitView:(NSSplitView *)sender canCollapseSubview:(NSView *)subview
{
  if (sender == mLocationToolbarView)
    return (subview == mSearchBar);
  return YES;
}

//
// -splitView:constrainMinCoordiante:ofSubviewAt:
// NSSplitView delegate
//
// Called when the combined url/search splitter is being resized to provide a mininum
// value for the splitter, which in our case is we want to be the min width of the url bar.
//
- (float)splitView:(NSSplitView *)sender constrainMinCoordinate:(float)proposedMin ofSubviewAt:(int)offset
{
  if (sender == mLocationToolbarView)
    return kMinimumURLAndSearchBarWidth;
  return proposedMin;
}

//
// -splitView:constrainMaxCoordinate:ofSubviewAt:
//
// Called when the combined url/search splitter is being resized to provide a max
// value for the splitter. |proposedMax| is the rightmost extent of the
// view to the right of the splitter, which in our case is the search bar. We
// want the splitter to stop at that extent less the minimum search bar width.
//
- (float)splitView:(NSSplitView *)sender constrainMaxCoordinate:(float)proposedMax ofSubviewAt:(int)offset
{
  if (sender == mLocationToolbarView)
    return proposedMax - kMinimumURLAndSearchBarWidth;
  return proposedMax;
}

//
// -splitView:resizeSubviewsWithOldSize:
// NSSplitView delegate
//
// Called when the split view is being resized. We are now in full control over
// how our subviews are repositioned. We want to fix the width of the search bar so
// that no matter how narrow/wide the window gets, the url bar is the one that changes
// size.
//
- (void)splitView:(NSSplitView *)sender resizeSubviewsWithOldSize:(NSSize)oldSize 
{
  NSSize newSize = [sender frame].size;
  NSRect searchFrame = [mSearchBar frame];
  NSView* urlSuperview = [mURLBar superview];
  NSRect urlBarFrame = [urlSuperview frame];
  
  // keep the search field constant size, expanding the url bar to take up the new slack
  float deltaX = newSize.width - oldSize.width;     // positive when window grows
  urlBarFrame.size.width += deltaX;
  searchFrame.origin.x += deltaX;
  // each toolbar resize actually shrinks the splitview to its minwidth, then re-expands
  // it to the new value; enforce min URL width only when not doing the min-size call
  if (fabsf(newSize.width - kMinimumLocationBarWidth) > kEpsilon) {
    if (urlBarFrame.size.width < kMinimumURLAndSearchBarWidth) {
      float widthShortage = kMinimumURLAndSearchBarWidth - urlBarFrame.size.width;
      searchFrame.origin.x += widthShortage;
      searchFrame.size.width -= widthShortage;
      urlBarFrame.size.width = kMinimumURLAndSearchBarWidth;
    }
  }
  [urlSuperview setFrame:urlBarFrame];
  [mSearchBar setFrame:searchFrame];
  [sender setNeedsDisplay:YES];
}

#pragma mark -


- (BOOL)validateMenuItem:(NSMenuItem*)aMenuItem
{
  SEL action = [aMenuItem action];

  // Always allow the search engine menu to work
  if (action == @selector(searchEngineChanged:) ||
      action == @selector(installSearchPlugin:) ||
      action == @selector(manageSearchEngines:) ||
      action == @selector(findSearchEngines:))
  {
    return YES;
  }

  // Disable all window-specific menu items while a sheet is showing.
  // We don't do this in validateActionBySelector: because toolbar items shouldn't
  // suddenly get a disabled look when a sheet appears (they aren't clickable anyway).
  if ([[self window] attachedSheet])
    return NO;

  if (action == @selector(reloadSendersTab:)) {
    BrowserTabViewItem* sendersTab = [[self tabBrowser] itemWithTag:[aMenuItem tag]];
    return [[sendersTab view] canReload];
  }

  if (action == @selector(getInfo:)) {
    if ([self bookmarkManagerIsVisible]) {
      [aMenuItem setTitle:NSLocalizedString(@"Bookmark Info", nil)];
      // let the BookmarkViewController validate based on selection
      return [[self bookmarkViewControllerForCurrentTab] validateMenuItem:aMenuItem];
    }
    else
      [aMenuItem setTitle:NSLocalizedString(@"Page Info", nil)];
  }

  if (action == @selector(findActions:)) {
    // we could add more complex logic to only show this if the find bar has
    // focus, but for now it'll just always be enabled when there's content.
    if ([self bookmarkManagerIsVisible])
      return NO;    
    long tag = [aMenuItem tag];
    if (tag == NSFindPanelActionNext || tag == NSFindPanelActionPrevious)
      return ([[[mBrowserView browserView] lastFindText] length] > 0);
    return YES;
  }

  return [self validateActionBySelector:action];
}

- (BOOL)validateActionBySelector:(SEL)action
{
  if (action == @selector(back:))
    return [[mBrowserView browserView] canGoBack];
  if (action == @selector(forward:))
    return [[mBrowserView browserView] canGoForward];
  if (action == @selector(stop:))
    return [mBrowserView isBusy];
  if (action == @selector(reload:))
    return [[self browserWrapper] canReload];
  if (action == @selector(moveTabToNewWindow:) ||
      action == @selector(closeSendersTab:) ||
      action == @selector(closeOtherTabs:) ||
      action == @selector(nextTab:) ||
      action == @selector(previousTab:))
  {
    return ([mTabBrowser numberOfTabViewItems] > 1);
  }
  if (action == @selector(closeCurrentTab:))
    return ([mTabBrowser numberOfTabViewItems] > 1 && [[self window] isKeyWindow]);
  if (action == @selector(addBookmark:) ||
      action == @selector(addBookmarkWithoutPrompt:))
  {
    return [mBrowserView isBookmarkable];
  }
  if (action == @selector(addTabGroup:) ||
      action == @selector(addTabGroupWithoutPrompt:))
  {
    return ([mTabBrowser numberOfBookmarkableTabViewItems] > 1);
  }
  if (action == @selector(makeTextBigger:))
    return [self canMakeTextBigger];
  if (action == @selector(makeTextSmaller:))
    return [self canMakeTextSmaller];
  if (action == @selector(makeTextDefaultSize:))
    return [self canMakeTextDefaultSize];
  if (action == @selector(find:)) {
    return ([self bookmarkManagerIsVisible] ||
            [[[self browserWrapper] browserView] isTextBasedContent]);
  }
  if (action == @selector(sendURL:))
    return ![[self browserWrapper] isInternalURI];
  if (action == @selector(viewSource:) ||
      action == @selector(viewPageSource:) ||
      action == @selector(fillForm:))
  {
    BrowserWrapper* browser = [self browserWrapper];
    return (![browser isInternalURI] && [[browser browserView] isTextBasedContent]);
  }
  if (action == @selector(printDocument:) ||
      action == @selector(pageSetup:))
  {
    return ![self bookmarkManagerIsVisible];
  }

  return YES;
}

#pragma mark -

// BrowserUIDelegate methods (called from the frontmost tab's BrowserWrapper)


- (void)loadingStarted
{
}

- (void)loadingDone:(BOOL)activateContent
{
  if (activateContent) {
    // if we're the front/key window, focus the content area. If we're not,
    // set gecko as the first responder so that it will be activated when
    // the window is focused. If the user is typing in the urlBar, however,
    // don't mess with the focus at all.
    if ([[self window] isKeyWindow]) {
      if (![self userChangedLocationField])
        [mBrowserView setBrowserActive:YES];
    }
    else
      [[self window] makeFirstResponder:[mBrowserView browserView]];
  }

  if ([[self window] isMainWindow])
    [[PageInfoWindowController visiblePageInfoWindowController] updateFromBrowserView:[self activeBrowserView]];

  [[NSApp delegate] delayedAdjustBookmarksMenuItemsEnabling];
  [[SessionManager sharedInstance] windowStateChanged];
}

- (void)setLoadingActive:(BOOL)active
{
  NSSize statusFieldSize = [mStatus frame].size;

  if (active) {
    [self startThrobber];
    [mProgress setIndeterminate:YES];
    [mProgress setHidden:NO];
    [mProgress startAnimation:self];
    
    const int statusBarPadding = 9;
    statusFieldSize.width = NSMinX([mProgress frame]) - statusBarPadding -
                            NSMinX([mStatus frame]);
  }
  else {
    [self stopThrobber];
    [mProgress stopAnimation:self];
    [mProgress setHidden:YES];
    [mProgress setIndeterminate:YES];
    [[[self window] toolbar] validateVisibleItems];

    statusFieldSize.width = NSMaxX([mProgress frame]) - NSMinX([mStatus frame]);
  }

  [mStatus setFrameSize:statusFieldSize];
  [mStatusBar setNeedsDisplay:YES];
}

- (void)setLoadingProgress:(float)progress
{
  if (progress > 0.0f)
  {
    [mProgress setIndeterminate:NO];
    [mProgress setDoubleValue:progress];
  }
  else
  {
    [mProgress setIndeterminate:YES];
    [mProgress startAnimation:self];
  }
}

// Get the title's maximal width manually and truncate the title ourselves to work around
// 10.3's crappy title truncation.  Also, this way we can middle-truncate, which 10.4 doesn't do
- (void)updateWindowTitle:(NSString*)title
{
  if (!title)
    return;

  NSWindow* window = [self window];

  float leftEdge = NSMaxX([[window standardWindowButton:NSWindowZoomButton] frame]);
  NSButton* toolbarButton = [window standardWindowButton:NSWindowToolbarButton];
  float rightEdge = toolbarButton ? [toolbarButton frame].origin.x : NSMaxX([window frame]);

  // Leave 8 pixels of padding around the title.
  const int kTitlePadding = 8;
  float titleWidth = rightEdge - leftEdge - 2 * kTitlePadding;

  // Sending |titleBarFontOfSize| 0 returns default size
  NSDictionary* attributes = [NSDictionary dictionaryWithObject:[NSFont titleBarFontOfSize:0] forKey:NSFontAttributeName];

  [window setTitle:[title stringByTruncatingToWidth:titleWidth at:kTruncateAtMiddle withAttributes:attributes]];
}

- (void)updateStatus:(NSString*)status
{
  if ([[mStatus stringValue] isEqualToString:status])
    return;

  [mStatus setStringValue:status];
}

- (void)updateLocationFields:(NSString*)url ignoreTyping:(BOOL)ignoreTyping
{
  if (!ignoreTyping && [self userChangedLocationField])
    return;

  if ([url isEqual:@"about:blank"])
    url = @""; // return;

  [mURLBar setURI:url];
  [mLocationSheetURLField setStringValue:url];

  if ([[self window] isMainWindow])
    [[PageInfoWindowController visiblePageInfoWindowController] updateFromBrowserView:[self activeBrowserView]];
}

- (void)updateSiteIcons:(NSImage*)icon ignoreTyping:(BOOL)ignoreTyping
{
  if (!ignoreTyping && [self userChangedLocationField])
    return;

  if (icon == nil)
    icon = [NSImage imageNamed:@"globe_ico"];
  [mProxyIcon setImage:icon];
}

- (void)showPopupBlocked:(BOOL)inBlocked
{
  // do nothing, everything is now handled by the BrowserWindow.
}

//
// -openFeedPrefPane
//
// Opens the preference pane that contains the options for opening feeds
//
- (IBAction)openFeedPrefPane:(id)sender
{
  [[MVPreferencesController sharedInstance] showPreferences:nil];
  [[MVPreferencesController sharedInstance] selectPreferencePaneByIdentifier:@"org.mozilla.camino.preference.navigation"];
}

//
// showBlockedPopups:whitelistingSource:
//
// UI delegate method to show the given blocked popups, optionally whitelisting the source.
//
- (void)showBlockedPopups:(nsIArray*)blockedSites whitelistingSource:(BOOL)shouldWhitelist
{
  // Because of the way our UI is set up, we white/blacklist based on the top-level window URI,
  // rather than the requesting URI (which can be different on framed sites).
  if (shouldWhitelist) {
    [[CHPermissionManager permissionManager] setPolicy:CHPermissionAllow
                                                forURI:[mBrowserView currentURI]
                                                  type:CHPermissionTypePopup];
  }

  nsCOMPtr<nsISimpleEnumerator> enumerator;
  blockedSites->Enumerate(getter_AddRefs(enumerator));
  PRBool hasMore = PR_FALSE;

  // iterate over the array of blocked popup events, and unblock & show
  // them, one by one.
  while (NS_SUCCEEDED(enumerator->HasMoreElements(&hasMore)) && hasMore) {
    nsCOMPtr<nsISupports> curSupports;
    enumerator->GetNext(getter_AddRefs(curSupports));
    if (!curSupports)
      continue;

    nsCOMPtr<nsIDOMPopupBlockedEvent> evt;
    evt = do_QueryInterface(curSupports);
    if (evt)
      [self showPopup:evt];
  }
}

- (void)showPopup:(nsIDOMPopupBlockedEvent*)aPopupBlockedEvent
{ 
  nsCOMPtr<nsIDOMWindow> requestingWindow;
  aPopupBlockedEvent->GetRequestingWindow(getter_AddRefs(requestingWindow));
  // get the URIs for the popup window, and it's parent document
  nsCOMPtr<nsIURI> popupWindowURI;
  aPopupBlockedEvent->GetPopupWindowURI(getter_AddRefs(popupWindowURI));

  nsAutoString windowName, features;
  
  // get the popup window's features
  aPopupBlockedEvent->GetPopupWindowFeatures(features);
  
#ifndef MOZILLA_1_8_BRANCH
  // XXXhakan: nsIDOMPopupBlockedEvent didn't get the popupWindowName property added on branch, so
  // we can't set the popup window's original name for now.
  // see bug 343734
  aPopupBlockedEvent->GetPopupWindowName(windowName);
#endif

  // find the docshell for the blocked popup window, in order to show it
  if (!requestingWindow)
    return;

  nsCOMPtr<nsPIDOMWindow> piDomWin = do_QueryInterface(requestingWindow);
  if (!piDomWin)
    return;

  // needed so the blocking code will know that we're allowed to
  // show this popup.
  nsAutoPopupStatePusher popupStatePusher(piDomWin, openAllowed);
  nsCAutoString uriStr;
  popupWindowURI->GetSpec(uriStr);
  
  // show the blocked popup
  nsCOMPtr<nsIDOMWindow> openedWindow;
  nsresult rv = piDomWin->Open(NS_ConvertUTF8toUTF16(uriStr), windowName, features, getter_AddRefs(openedWindow));
  if (NS_FAILED(rv))
    NSLog(@"Couldn't show the blocked popup window for %@", [NSString stringWith_nsACString:uriStr]);
}

- (void)blacklistPopupsFromURL:(NSString*)inURL
{
  [[CHPermissionManager permissionManager] setPolicy:CHPermissionDeny
                                              forURI:inURL
                                                type:CHPermissionTypePopup];
}

//
// -showFeedDetected:
//
// Called when the browser wrapper decides to show or hide the feed icon. 
// Pass the notice off to the URL bar.
//
- (void)showFeedDetected:(BOOL)inDetected 
{
  [mURLBar displayFeedIcon:inDetected];
}

//
// -buildFeedsDetectedListMenu
//
// Called by the notification center right before the menu will be displayed. This
// allows us the opportunity to populate its contents from the number of feeds that were detected
//
- (void)buildFeedsDetectedListMenu:(NSNotification*)notifier
{
  NSMenu* menu = [[[NSMenu alloc] initWithTitle:@"FeedListMenu"] autorelease];  // retained by the popup button
  NSEnumerator* feedsEnum = [[[self browserWrapper] feedList] objectEnumerator];
  NSString* titleFormat = NSLocalizedString(@"SubscribeTo", nil); // "Subscribe to feedTitle or feedURI"
  NSDictionary* curFeedDict;
  while ((curFeedDict = [feedsEnum nextObject])) {
    NSString* feedTitle = [curFeedDict objectForKey:@"feedtitle"];
    NSString* feedURI = [curFeedDict objectForKey:@"feeduri"];
    NSString* itemTitle;
    
    if (feedTitle && [feedTitle length] > 0)
      itemTitle = [NSString stringWithFormat:titleFormat, feedTitle];
    else
      itemTitle = [NSString stringWithFormat:titleFormat, feedURI];
    
    // Insert the feed item into the menu if one with the same name has not
    // already been inserted into the list.
    if ([menu indexOfItemWithTitle:itemTitle] == -1) {
      NSMenuItem* curFeedMenuItem = [[NSMenuItem alloc] initWithTitle:itemTitle
                                                               action:@selector(openFeedInExternalApp:)
                                                        keyEquivalent:@""];
      
      [curFeedMenuItem setTarget:self];
      [curFeedMenuItem setRepresentedObject:feedURI];
      [menu addItem:curFeedMenuItem];
      [curFeedMenuItem release];
    }
  }
  
  // Offer a shortcut to the feed preferences
  [menu addItem:[NSMenuItem separatorItem]];
  NSMenuItem* feedPrefItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"FeedPreferences", nil)
                                                        action:@selector(openFeedPrefPane:) 
                                                 keyEquivalent:@""];
  [feedPrefItem setTarget:self];
  [feedPrefItem setEnabled:YES];
  [menu addItem:feedPrefItem];
  [feedPrefItem release];
  
  [mURLBar setFeedIconContextMenu:menu];
}

//
// -shouldWarnBeforeOpeningFeed
//
// Returns the state of the users pref to show the warning screen when opening a feed
// 
-(BOOL)shouldWarnBeforeOpeningFeed
{
  return [[PreferenceManager sharedInstance] getBooleanPref:"camino.warn_before_opening_feed" withSuccess:NULL];
}

// -openFeedInExternalApp
//
// Called when the user clicks on one of the feeds found on the page
- (IBAction)openFeedInExternalApp:(id)sender
{
  FeedServiceController* feedServController = [FeedServiceController sharedFeedServiceController];
  
  // Only pose the warning dialog if we need to warn the user before opening
  // or if the user doesn't have any feed applications registered.
  if ([self shouldWarnBeforeOpeningFeed] || ![feedServController feedAppsExist]) 
    [feedServController showFeedWillOpenDialog:[self window]  feedURI:[sender representedObject]];
  else
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[sender representedObject]]];
}

- (void)showSecurityState:(unsigned long)state
{
  [self updateLock:state];
}

- (BOOL)userChangedLocationField
{
  return [mURLBar userHasTyped];
}

- (void)contentViewChangedTo:(NSView*)inView forURL:(NSString*)inURL
{
  // update bookmarks menu
  [[NSApp delegate] delayedAdjustBookmarksMenuItemsEnabling];

  // should we change page info for bookmarks?
}

- (void)updateFromFrontmostTab
{
  [self updateWindowTitle:[mBrowserView pageTitle]];
  [self setLoadingActive:[mBrowserView isBusy]];
  [self setLoadingProgress:[mBrowserView loadingProgress]];
  [self showSecurityState:[mBrowserView securityState]];
  [self updateSiteIcons:[mBrowserView siteIcon] ignoreTyping:NO];
  [self updateStatus:[mBrowserView statusString]];
  [self updateLocationFields:[mBrowserView currentURI] ignoreTyping:NO];
  [self showFeedDetected:[mBrowserView feedsDetected]];
  [self showSearchPluginDetected:[[mBrowserView detectedSearchPlugins] count]];
}

#pragma mark -

- (BrowserTabViewItem*)tabForBrowser:(BrowserWrapper*)inWrapper
{
  NSEnumerator* tabsEnum = [[mTabBrowser tabViewItems] objectEnumerator];
  id curTabItem;
  while ((curTabItem = [tabsEnum nextObject]))
  {
    if ([curTabItem isKindOfClass:[BrowserTabViewItem class]] && ([(BrowserTabViewItem*)curTabItem view] == inWrapper))
      return curTabItem;
  }
  return nil;
}

- (BookmarkViewController*)bookmarkViewControllerForCurrentTab
{
  id viewProvider = [mBrowserView contentViewProviderForURL:@"about:bookmarks"];
  if ([viewProvider isKindOfClass:[BookmarkViewController class]])
    return (BookmarkViewController*)viewProvider;
  return nil;
}

// indexOffset denotes the number of entries forward or back in session history to look
- (void)sessionHistoryItemAtRelativeOffset:(int)indexOffset forWrapper:(BrowserWrapper*)inWrapper title:(NSString**)outTitle URL:(NSString**)outURLString
{
  NSString* curTitle = nil;
  NSString* curURL = nil;

  nsCOMPtr<nsIWebBrowser> webBrowser = dont_AddRef([[inWrapper browserView] webBrowser]);
  if (webBrowser) {
    nsCOMPtr<nsIWebNavigation> webNav(do_QueryInterface(webBrowser));

    nsCOMPtr<nsISHistory> sessionHistory;
    webNav->GetSessionHistory(getter_AddRefs(sessionHistory));
    if (sessionHistory) {
      PRInt32 curEntryIndex;
      sessionHistory->GetIndex(&curEntryIndex);
      PRInt32 count;
      sessionHistory->GetCount(&count);

      PRInt32 targetIndex = (curEntryIndex + indexOffset);
      // if the place we're looking for in session history exists
      if ((targetIndex >= 0) && (targetIndex < count)) {
        nsCOMPtr<nsIHistoryEntry> entry;
        sessionHistory->GetEntryAtIndex(targetIndex, PR_FALSE, getter_AddRefs(entry));

        nsCAutoString uriSpec;
        nsCOMPtr<nsIURI> entryURI;
        entry->GetURI(getter_AddRefs(entryURI));
        if (entryURI)
          entryURI->GetSpec(uriSpec);

        nsAutoString textStr;
        entry->GetTitle(getter_Copies(textStr));

        curTitle = [NSString stringWith_nsAString:textStr];
        curURL = [NSString stringWithUTF8String:uriSpec.get()];
      }
    }
  }

  *outTitle = curTitle;
  *outURLString = curURL;
}

- (void)performAppropriateLocationAction
{
  NSToolbar *toolbar = [[self window] toolbar];
  if ( [toolbar isVisible] )
  {
    if ( ([[[self window] toolbar] displayMode] == NSToolbarDisplayModeIconAndLabel) ||
          ([[[self window] toolbar] displayMode] == NSToolbarDisplayModeIconOnly) )
    {
      NSArray *itemsWeCanSee = [toolbar visibleItems];
      
      for (unsigned int i = 0; i < [itemsWeCanSee count]; i++)
      {
        if ([[[itemsWeCanSee objectAtIndex:i] itemIdentifier] isEqual:CombinedLocationToolbarItemIdentifier])
        {
          [self focusURLBar];
          return;
        }
      }
    }
  }
  
  [self beginLocationSheet];
}

- (void)focusURLBar
{
  [mBrowserView setBrowserActive:NO];
  [mURLBar selectText:self];
}

- (void)beginLocationSheet
{
  [mLocationSheetURLField setStringValue:[mURLBar stringValue]];
  [mLocationSheetURLField selectText:nil];

  [NSApp beginSheet:  mLocationSheetWindow
     modalForWindow:  [self window]
      modalDelegate:  nil
     didEndSelector:  nil
        contextInfo:  nil];
}

- (IBAction)endLocationSheet:(id)sender
{
  [mLocationSheetWindow close];   // assumes it's not released on close
  [NSApp endSheet:mLocationSheetWindow returnCode:1];
  [self goToLocationFromToolbarURLField:mLocationSheetURLField];
}

- (IBAction)cancelLocationSheet:(id)sender
{
  [mLocationSheetWindow close];   // assumes it's not released on close
  [NSApp endSheet:mLocationSheetWindow returnCode:0];
}

//
// -performAppropriateSearchAction
//
// Called when the user executes the "search the web" action. If the combined
// url/search bar is visible, focus the text field. If it's not (text only or
// removed from toolbar), show the search sheet.
//
// Note that with the combined url/search bar, the only way to get this sheet
// is to use the menu item/key combo, as clicking the text-only toolbar item
// will show the location sheet. I'm not really happy about this, but I couldn't
// come up with a good unified sheet that made sense. 
//
- (void)performAppropriateSearchAction
{
  if ([mSearchBar window] && ![mLocationToolbarView isSubviewCollapsed:mSearchBar])
    [self focusSearchBar];
  else 
    [self beginSearchSheet];
}

- (void)focusSearchBar
{
  [mBrowserView setBrowserActive:NO];
  [mSearchBar selectText:self];
}

- (void)beginSearchSheet
{
  [NSApp beginSheet:  mSearchSheetWindow
     modalForWindow:  [self window]
      modalDelegate:  nil
     didEndSelector:  nil
        contextInfo:  nil];
}

- (IBAction)endSearchSheet:(id)sender
{
  [mSearchSheetWindow orderOut:self];
  [NSApp endSheet:mSearchSheetWindow returnCode:1];
  [self performSearch:mSearchSheetTextField inView:eDestinationCurrentView inBackground:NO];
}

- (IBAction)cancelSearchSheet:(id)sender
{
  [mSearchSheetWindow orderOut:self];
  [NSApp endSheet:mSearchSheetWindow returnCode:0];
}

//
// - manageBookmarks:
//
// Load the bookmarks in the frontmost tab or window.
//
-(IBAction)manageBookmarks:(id)aSender
{
  if ([self bookmarkManagerIsVisible]) {
    int previousPage = [self historyIndexOfPageBeforeBookmarkManager];
    if (previousPage != -1)
      [[[self browserWrapper] browserView] goToSessionHistoryIndex:previousPage];
  }
  else {
    [self loadURL:@"about:bookmarks"];
  }
}

//
// -manageHistory:
//
// History is a slightly different beast from bookmarks. Unlike 
// bookmarks, which acts as a toggle, history ensures the manager
// is visible and selects the history collection. If the manager
// is already visible, selects the history collection.
//
// An alternate solution would be to have it select history when
// it wasn't the selected container, and hide when history was
// the selected collection (toggling in that one case). This makes
// me feel dirty as the command does two different things depending
// on the (possibly undiscoverable to the user) context in which it is
// invoked. For that reason, I've chosen to not have history be a 
// toggle and see the fallout.
//
-(IBAction)manageHistory: (id)aSender
{
  [self loadURL:@"about:history"];

  // aSender could be a history menu item with a represented object of
  // an item that we wish to reveal. However, it belongs to a different
  // data source than the one we just created. need a way to find the one
  // to reveal...
}

//
// historyIndexOfPageBeforeBookmarkManager
//
// Returns the index in session history of the last page visited before viewing the bookmarks manager
//
- (int)historyIndexOfPageBeforeBookmarkManager
{
  if (![self bookmarkManagerIsVisible])
    return -1;

  nsIWebNavigation* webNav = [self currentWebNavigation];
  if (!webNav)
    return -1;

  nsCOMPtr<nsISHistory> sessionHistory;
  webNav->GetSessionHistory(getter_AddRefs(sessionHistory));
  if (!sessionHistory)
    return -1;

  PRInt32 curEntryIndex;
  sessionHistory->GetIndex(&curEntryIndex);

  for (int i = curEntryIndex - 1; i >= 0; --i) {
    nsCOMPtr<nsIHistoryEntry> entry;
    sessionHistory->GetEntryAtIndex(i, PR_FALSE, getter_AddRefs(entry));

    nsCAutoString uriSpec;
    nsCOMPtr<nsIURI> entryURI;
    entry->GetURI(getter_AddRefs(entryURI));
    if (entryURI)
      entryURI->GetSpec(uriSpec);

    if (!(uriSpec.EqualsLiteral("about:bookmarks") || uriSpec.EqualsLiteral("about:history")))
      return i;
  }

  return -1;
}

- (IBAction)goToLocationFromToolbarURLField:(id)sender
{
  if ([sender isKindOfClass:[AutoCompleteTextField class]])
    [self goToLocationFromToolbarURLField:(AutoCompleteTextField *)sender
                                    inView:eDestinationCurrentView inBackground:NO];
}

- (void)goToLocationFromToolbarURLField:(AutoCompleteTextField *)inURLField 
                                 inView:(EOpenDestination)inDest inBackground:(BOOL)inLoadInBG
{
  // trim off any whitespace around url
  NSString *theURL = [[inURLField stringValue] stringByTrimmingWhitespace];

  if ([theURL length] == 0)
  {
    // re-focus the url bar if it's visible (might be in sheet?)
    if ([inURLField window] == [self window])
      [[self window] makeFirstResponder:inURLField];

    return;
  }

  // look for bookmarks shortcut match
  NSArray *resolvedURLs = [[BookmarkManager sharedBookmarkManager] resolveBookmarksShortcut:theURL];

  NSString* targetURL = nil;
  if (!resolvedURLs || [resolvedURLs count] == 1) {
    targetURL = resolvedURLs ? [resolvedURLs lastObject] : theURL;
    BOOL allowPopups = resolvedURLs ? YES : NO; //Allow popups if it's a bookmark shortcut
    if (inDest == eDestinationNewTab)
      [self openNewTabWithURL:targetURL referrer:nil loadInBackground:inLoadInBG allowPopups:allowPopups setJumpback:NO];
    else if (inDest == eDestinationNewWindow)
      [self openNewWindowWithURL:targetURL referrer:nil loadInBackground:inLoadInBG allowPopups:allowPopups];
    else // if it's not a new window or a new tab, load into the current view
      [self loadURL:targetURL referrer:nil focusContent:YES allowPopups:allowPopups];
  }
  else {
    if (inDest == eDestinationNewTab || inDest == eDestinationNewWindow)
      [self openURLArray:resolvedURLs tabOpenPolicy:eAppendTabs allowPopups:YES];
    else
      [self openURLArray:resolvedURLs tabOpenPolicy:eReplaceTabs allowPopups:YES];
  }

  // global history needs to know the user typed this url so it can present it
  // in autocomplete. We use the URI fixup service to strip whitespace and remove
  // invalid protocols, etc. Don't save shortcut-expanded urls.
  if (!resolvedURLs &&
      mDataOwner &&
      mDataOwner->mGlobalHistory &&
      mDataOwner->mURIFixer && [theURL length] > 0)
  {
    nsAutoString url;
    [theURL assignTo_nsAString:url];
    NS_ConvertUTF16toUTF8 utf8URL(url);

    nsCOMPtr<nsIURI> fixedURI;
    mDataOwner->mURIFixer->CreateFixupURI(utf8URL, 0, getter_AddRefs(fixedURI));
    if (fixedURI)
      mDataOwner->mGlobalHistory->MarkPageAsTyped(fixedURI);
  }
}
- (void)saveDocument:(BOOL)focusedFrame filterView:(NSView*)aFilterView
{
  [[mBrowserView browserView] saveDocument:focusedFrame filterView:aFilterView];
}

- (void)saveURL:(NSView*)aFilterView url:(NSString*)aURLSpec suggestedFilename:(NSString*)aFilename
{
  [[mBrowserView browserView] saveURL:aFilterView url:aURLSpec suggestedFilename:aFilename];
}

- (void)loadSourceForFrame:(BOOL)forFrame inBackground:(BOOL)loadInBackground
{
  // First, to get a descriptor so we can load the source from cache
  nsCOMPtr<nsISupports> desc = [[mBrowserView browserView] pageDescriptorByFocus:forFrame];
  // If that somehow fails, we'll do it by URL
  NSString* viewSource = nil;
  if (!desc) {
    NSString* urlStr = forFrame ? [[mBrowserView browserView] focusedURLString]
                                : [mBrowserView currentURI];
    viewSource = [kViewSourceProtocolString stringByAppendingString:urlStr];
  }

  if ([[PreferenceManager sharedInstance] getBooleanPref:"camino.viewsource_in_tab" withSuccess:NULL]) {
    if (desc)
      [self openNewTabWithDescriptor:desc displayType:nsIWebPageDescriptor::DISPLAY_AS_SOURCE loadInBackground:loadInBackground];
    else
      [self openNewTabWithURL:viewSource referrer:nil loadInBackground:loadInBackground allowPopups:NO setJumpback:NO];
  }      
  else {
    // open a new window and hide the toolbars for prettyness
    BrowserWindowController* controller = [[BrowserWindowController alloc] initWithWindowNibName:@"BrowserWindow"];
    [controller setChromeMask:kNoToolbarsChromeMask];
    [controller disableAutosave]; // don't save view-source window size/position

    if (loadInBackground)
      [[controller window] orderWindow:NSWindowBelow relativeTo:[[self window] windowNumber]];
    else
      [controller showWindow:nil];

    if (desc)
      [[[controller browserWrapper] browserView] setPageDescriptor:desc displayType:nsIWebPageDescriptor::DISPLAY_AS_SOURCE];
    else
      [controller loadURL:viewSource];
  }
}

// This method is currently unused due to bug 56488, but is completely functional.
- (IBAction)toggleStatusBar:(id)aSender
{
  BOOL shouldHide = ![mStatusBar isHidden];
  [[NSUserDefaults standardUserDefaults] setBool:shouldHide forKey:USER_DEFAULTS_HIDE_STATUS_BAR_KEY];

  [mStatusBar setHidden:shouldHide];
  if ([NSWorkspace isLeopardOrHigher]) {
    if (shouldHide)
      [[self window] setContentBorderThickness:0 forEdge:NSMinYEdge];
    else
      [[self window] setContentBorderThickness:NSHeight([mStatusBar bounds]) forEdge:NSMinYEdge];
  }

  NSSize oldContentSize = [mContentView frame].size;
  NSRect windowRect = [[self window] frame];
  float statusBarHeight = [mStatusBar frame].size.height;
  if (shouldHide) {
    windowRect.origin.y += statusBarHeight;
    windowRect.size.height -= statusBarHeight;
  }
  else {
    // shift and/or shrink the window as necessary to keep it within the screen area
    NSRect screenRect = [[[self window] screen] visibleFrame];
    windowRect.origin.y = MAX(windowRect.origin.y - statusBarHeight,
                              screenRect.origin.y);
    windowRect.size.height = MIN(windowRect.size.height + statusBarHeight,
                                 screenRect.size.height);
  }
  [[self window] setFrame:windowRect display:YES];
  // if the window height didn't change, then the content view may not have been resized,
  // so we need to ensure that it's updated to account for the status bar changing.
  if ([mContentView frame].size.height == oldContentSize.height)
    [mContentView resizeSubviewsWithOldSize:oldContentSize];
}

- (IBAction)viewSource:(id)aSender
{
  BOOL loadInBackground = (([[NSApp currentEvent] modifierFlags] & NSShiftKeyMask) != 0);
  [self loadSourceForFrame:YES inBackground:loadInBackground];
}

- (IBAction)viewPageSource:(id)aSender
{
  // If it's a capital V, shift is down
  BOOL loadInBackground = ([[aSender keyEquivalent] isEqualToString:@"V"]);
  [self loadSourceForFrame:NO inBackground:loadInBackground];
}

- (IBAction)printDocument:(id)aSender
{
  [[mBrowserView browserView] printDocument];
}

- (IBAction)pageSetup:(id)aSender
{
  [[mBrowserView browserView] pageSetup];
}

// -searchFieldTriggered:
//
// This should be used *only* as an action method for a WebSearchField, and
// never invoked programatically.
- (IBAction)searchFieldTriggered:(id)aSender
{
  // WebSearchField sends an action on clearing the search field, which isn't
  // distinguishable from submitting an empty search, so we make sure the
  // trigger was someone hitting return/enter if it's empty.
  BOOL performSearch = NO;
  if ([[aSender stringValue] length] > 0) {
    performSearch = YES;
  }
  else {
    NSEvent* currentEvent = [NSApp currentEvent];
    if (([currentEvent type] == NSKeyDown) && [[currentEvent characters] length] > 0) {
      unichar character = [[currentEvent characters] characterAtIndex:0];
      if ((character == NSCarriageReturnCharacter) || (character == NSEnterCharacter))
        performSearch = YES;
    }
  }

  if (performSearch) {
    // If it came from the search sheet, dismiss the sheet now
    if (aSender == mSearchSheetTextField) {
      [mSearchSheetWindow orderOut:self];
      [NSApp endSheet:mSearchSheetWindow returnCode:1];
    }
    [self performSearch:aSender inView:eDestinationCurrentView inBackground:NO];
  }
}

//
// -searchForSelection:
//
// Get the selection, stick it into the search bar, and do a search with the
// currently selected search engine in the search bar. If there is no search
// bar in the toolbar, that's still ok because we've guaranteed that we always
// have a search bar even if it's not on a toolbar.
//
- (IBAction)searchForSelection:(id)aSender
{
  NSString* selection = [[mBrowserView browserView] selectedText];
  [mSearchBar becomeFirstResponder];
  [mSearchBar setStringValue:selection];
  
  unsigned int modifiers = [[NSApp currentEvent] modifierFlags];

  EOpenDestination destination = eDestinationCurrentView;
  BOOL loadInBackground = NO;
  // do search in a new window/tab if Command is held down
  if (modifiers & NSCommandKeyMask) {
    BOOL loadInTab = [[PreferenceManager sharedInstance] getBooleanPref:"browser.tabs.opentabfor.middleclick" withSuccess:NULL];
    destination = loadInTab ? eDestinationNewTab : eDestinationNewWindow;
    loadInBackground = [BrowserWindowController shouldLoadInBackgroundForDestination:destination
                                                                              sender:nil];
  }

  [self performSearch:mSearchBar inView:destination inBackground:loadInBackground];
}

//
// - performSearch:inView:inBackground
//
// performs a search using searchField and opens either in the current view, a new tab, or a new
// window. If it's a new tab or window, loadInBG determines whether the window/tab is opened in the background
//
-(void)performSearch:(WebSearchField*)inSearchField inView:(EOpenDestination)inDest inBackground:(BOOL)inLoadInBG
{
  NSString *searchString = [inSearchField stringValue];
  NSMutableString *searchURL = [[[inSearchField currentSearchURL] mutableCopy] autorelease];
  
  // If we have an about: type URL, remove " site:%d" from the search string
  // This is a fix to deal with Google's Search this Site feature
  // If other sites use %d to search the site, we'll have to have specific rules
  // for those sites.
  if ([[[self browserWrapper] currentURI] hasPrefix:@"about:"]) {
    NSRange domainStringRange = [searchURL rangeOfString:@" site:%d"
                                                 options:NSBackwardsSearch];
    
    NSRange notFoundRange = NSMakeRange(NSNotFound, 0);
    if (NSEqualRanges(domainStringRange, notFoundRange) == NO)
      [searchURL deleteCharactersInRange:domainStringRange];
  }
  
  // If they didn't type anything in the search field, visit the domain of
  // the search site, i.e. www.google.com for the Google site
  if ([searchString isEqualToString:@""]) {
    const char *urlSpec = [searchURL lossyCString];
    
    nsCOMPtr<nsIURI> searchURI;
    if (NS_NewURI(getter_AddRefs(searchURI), urlSpec) == NS_OK) {
      nsCAutoString spec;
      searchURI->GetHost(spec);
      
      NSString *searchDomain = [NSString stringWithUTF8String:spec.get()];
      
      if (inDest == eDestinationNewTab)
        [self openNewTabWithURL:searchDomain referrer:nil loadInBackground:inLoadInBG allowPopups:NO setJumpback:NO];
      else if (inDest == eDestinationNewWindow)
        [self openNewWindowWithURL:searchDomain referrer:nil loadInBackground:inLoadInBG allowPopups:NO];
      else // if it's not a new window or a new tab, load into the current view
        [self loadURL:searchDomain];
    } 
  } else {
    const char *urlSpec = [[[self browserWrapper] currentURI] UTF8String];
    
    // Get the domain so that we can replace %d in our searchURL
    NSString *currentDomain = @"";
    nsCOMPtr<nsIURI> currentURI;
    if (NS_NewURI(getter_AddRefs(currentURI), urlSpec) == NS_OK) {
      nsCAutoString spec;
      currentURI->GetHost(spec);
      
      currentDomain = [NSString stringWithUTF8String:spec.get()];
    }
    
    // Escape the search string so the user can search for strings with
    // special characters ("&", "+", etc.) List from RFC2396.
    NSString *escapedSearchString = (NSString *) CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)searchString, NULL, CFSTR(";?:@&=+$,"), kCFStringEncodingUTF8);
    
    // replace the conversion specifiers (%d, %s) in the search string
    [self transformFormatString:searchURL domain:currentDomain search:escapedSearchString];
    [escapedSearchString release];
    
    if (inDest == eDestinationNewTab)
      [self openNewTabWithURL:searchURL referrer:nil loadInBackground:inLoadInBG allowPopups:NO setJumpback:NO];
    else if (inDest == eDestinationNewWindow)
      [self openNewWindowWithURL:searchURL referrer:nil loadInBackground:inLoadInBG allowPopups:NO];
    else // if it's not a new window or a new tab, load into the current view
      [self loadURL:searchURL];
  }
}

// - transformFormatString:domain:search
//
// Replaces all occurrences of %d in |inFormat| with |inDomain| and all occurrences of
// %s with |inSearch|.
- (void) transformFormatString:(NSMutableString*)inFormat domain:(NSString*)inDomain search:(NSString*)inSearch
{
  // Replace any occurence of %d with the current domain
  [inFormat replaceOccurrencesOfString:@"%d" withString:inDomain options:NSBackwardsSearch
                                 range:NSMakeRange(0, [inFormat length])];
  
  // Replace any occurence of %s with the contents of the search text field
  [inFormat replaceOccurrencesOfString:@"%s" withString:inSearch options:NSBackwardsSearch
                                 range:NSMakeRange(0, [inFormat length])];
}

- (IBAction)sendURL:(id)aSender
{
  BrowserWrapper* browserWrapper = [self browserWrapper];
  NSString* urlString = [browserWrapper currentURI];
  if (!urlString)
    return;

  // put < > around the URL to minimise problems when e-mailing
  urlString = [NSString stringWithFormat:@"<%@>", urlString];

  NSString* titleString = [browserWrapper pageTitle];
  if (!titleString)
    titleString = @"";

  // we need to encode entities in the title and url strings first. For some reason
  // CFURLCreateStringByAddingPercentEscapes is only happy with UTF-8 strings.
  CFStringRef urlUTF8String   = CFStringCreateWithCString(kCFAllocatorDefault, [urlString   UTF8String], kCFStringEncodingUTF8);
  CFStringRef titleUTF8String = CFStringCreateWithCString(kCFAllocatorDefault, [titleString UTF8String], kCFStringEncodingUTF8);
  
  CFStringRef escapedURL   = CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, urlUTF8String,   NULL, CFSTR("&?="), kCFStringEncodingUTF8);
  CFStringRef escapedTitle = CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, titleUTF8String, NULL, CFSTR("&?="), kCFStringEncodingUTF8);
    
  NSString* mailtoURLString = [NSString stringWithFormat:@"mailto:?subject=%@&body=%@", (NSString*)escapedTitle, (NSString*)escapedURL];

  [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:mailtoURLString]];
  
  CFRelease(urlUTF8String);
  CFRelease(titleUTF8String);
  
  CFRelease(escapedURL);
  CFRelease(escapedTitle);
}

- (IBAction)sendURLFromLink:(id)aSender
{
  if (!mDataOwner->mContextMenuNode)
    return;

  nsCOMPtr<nsIDOMElement> linkContent;
  nsAutoString href;
  GeckoUtils::GetEnclosingLinkElementAndHref(mDataOwner->mContextMenuNode, getter_AddRefs(linkContent), href);
  
  // XXXdwh Handle simple XLINKs if we want to be compatible with Mozilla, but who
  // really uses these anyway? :)
  if (!linkContent || href.IsEmpty())
    return;
  
  // put < > around the URL to minimise problems when e-mailing
  NSString* urlString = [NSString stringWithFormat:@"<%@>", [NSString stringWith_nsAString:href]];
  
  // we need to encode entities in the title and url strings first. For some reason
  // CFURLCreateStringByAddingPercentEscapes is only happy with UTF-8 strings.
  CFStringRef urlUTF8String = CFStringCreateWithCString(kCFAllocatorDefault, [urlString UTF8String], kCFStringEncodingUTF8);
  CFStringRef escapedURL    = CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, urlUTF8String, NULL, CFSTR("&?="), kCFStringEncodingUTF8);
  
  NSString* mailtoURLString = [NSString stringWithFormat:@"mailto:?body=%@", (NSString*)escapedURL];
  
  [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:mailtoURLString]];
  
  CFRelease(urlUTF8String);
  CFRelease(escapedURL);
}

- (NSToolbarItem*)throbberItem
{
    // find our throbber toolbar item.
    NSToolbar* toolbar = [[self window] toolbar];
    NSArray* items = [toolbar visibleItems];
    unsigned count = [items count];
    for (unsigned i = 0; i < count; ++i) {
        NSToolbarItem* item = [items objectAtIndex: i];
        if ([item tag] == 'Thrb') {
            return item;
        }
    }
    return nil;
}

- (NSArray*)throbberImages
{
  // Simply load an array of NSImage objects from the files "throbber-NN.tiff". I used "Quicktime Player" to
  // save all of the frames of the animated gif as individual .tiff files for simplicity of implementation.
  if (mThrobberImages == nil)
  {
    NSImage* images[64];
    int i;
    for (i = 0;; ++i) {
      NSString* imageName = [NSString stringWithFormat: @"throbber-%02d", i + 1];
      images[i] = [NSImage imageNamed: imageName];
      if (images[i] == nil)
        break;
    }
    mThrobberImages = [[NSArray alloc] initWithObjects: images count: i];
  }
  return mThrobberImages;
}


- (void)clickThrobber:(id)aSender
{
  NSString *pageToLoad = NSLocalizedStringFromTable(@"ThrobberPage", @"WebsiteDefaults", nil);
  if (![pageToLoad isEqualToString:@"ThrobberPage"])
    [self loadURL:pageToLoad];
}

- (void)startThrobber
{
  // optimization:  only throb if the throbber toolbar item is visible.
  NSToolbarItem* throbberItem = [self throbberItem];
  if (throbberItem) {
    [self stopThrobber];
    mThrobberHandler = [[ThrobberHandler alloc] initWithToolbarItem:throbberItem 
                          images:[self throbberImages]];
  }
}

// -find:
//
// Called when the user selects Edit > Find for this browser window. Shows the
// find bar if a webpage is visible and focuses the search field if bookmarks
// is visible. 
//
- (void)find:(id)aSender
{
  if ([self bookmarkManagerIsVisible]) {
    [[self bookmarkViewControllerForCurrentTab] focusSearchField];
  }
  else {
    [mBrowserView showFindBar];
  }
}

//
// -findActions:(id)inSender
//
// Tell the find controller to do things like next/previous. We get this if
// the content area doesn't have focus, and we leave it up to the find controller
// to do the right thing. We can't use |-performFindPanelAction:| because it
// gets eaten by things like the search field. 
//
- (IBAction)findActions:(id)inSender
{
  switch ([inSender tag]) {
    case NSFindPanelActionNext:
      [[mBrowserView browserView] findInPage:NO];
      break;
    
    case NSFindPanelActionPrevious:
      [[mBrowserView browserView] findInPage:YES];
      break;
  }
}

- (void)stopThrobber
{
  [mThrobberHandler stopThrobber];
  [mThrobberHandler release];
  mThrobberHandler = nil;
  NSToolbarItem* throbberItem = [self throbberItem];
  if (throbberItem)
    [throbberItem setImage: [NSImage imageNamed:@"throbber-00"]];
}


- (BOOL)bookmarkManagerIsVisible
{
  NSString* currentURL = [[[self browserWrapper] currentURI] lowercaseString];
  return [currentURL isEqualToString:@"about:bookmarks"] || [currentURL isEqualToString:@"about:history"];
}

- (BOOL)canHideBookmarks
{
  return [self historyIndexOfPageBeforeBookmarkManager] != -1;
}

- (BOOL)singleBookmarkIsSelected
{
  if (![self bookmarkManagerIsVisible])
    return NO;

  BookmarkViewController* bookmarksController = [self bookmarkViewControllerForCurrentTab];
  return ([bookmarksController numberOfSelectedRows] == 1);
}

- (IBAction)addBookmark:(id)aSender
{
  [self showAddBookmarkDialogForAllTabs:NO];
}

- (IBAction)addTabGroup:(id)aSender
{
  [self showAddBookmarkDialogForAllTabs:YES];
}

- (void)showAddBookmarkDialogForAllTabs:(BOOL)isTabGroup
{
  int numTabs = [mTabBrowser numberOfTabViewItems];
  NSMutableArray* itemsArray = [NSMutableArray arrayWithCapacity:numTabs];
  for (int i = 0; i < numTabs; i++)
  {
    BrowserWrapper* browserWrapper = (BrowserWrapper*)[[mTabBrowser tabViewItemAtIndex:i] view];
    if (![browserWrapper isBookmarkable])
      continue;

    NSString* curTitleString = [browserWrapper pageTitle];
    NSString* hrefString = [browserWrapper currentURI];

    NSMutableDictionary* itemInfo = [NSMutableDictionary dictionaryWithObject:hrefString forKey:kAddBookmarkItemURLKey];

    // title can be nil (e.g. for text files)
    if (curTitleString)
      [itemInfo setObject:curTitleString forKey:kAddBookmarkItemTitleKey];

    if (browserWrapper == mBrowserView)
      [itemInfo setObject:[NSNumber numberWithBool:YES] forKey:kAddBookmarkItemPrimaryTabKey];

    [itemsArray addObject:itemInfo];
  }

  NS_ASSERTION([itemsArray count], "Displaying the Add Bookmark dialog with no URIs");
  AddBookmarkDialogController* dlgController = [AddBookmarkDialogController controller];
  [dlgController showDialogWithLocationsAndTitles:itemsArray isFolder:NO onWindow:[self window]];

  if (isTabGroup)
    [dlgController makeTabGroup:YES];
}

- (IBAction)addBookmarkWithoutPrompt:(id)aSender
{
  BookmarkManager* bookmarkManager = [BookmarkManager sharedBookmarkManager];
  BookmarkFolder*  parentFolder = [bookmarkManager lastUsedBookmarkFolder];

  BrowserWrapper* browserWrapper = [self browserWrapper];
  NSString* itemTitle = [browserWrapper pageTitle];
  NSString* itemURL = [browserWrapper currentURI];

  NS_ASSERTION([browserWrapper isBookmarkable], "Bookmarking an innappropriate URI");

  // When creating Bookmark items, set the last-visited time to the time that
  // the bookmark was created.  TODO: use page load time.
  [parentFolder appendChild:[Bookmark bookmarkWithTitle:itemTitle
                                                    url:itemURL
                                              lastVisit:[NSDate date]]];
  [bookmarkManager setLastUsedBookmarkFolder:parentFolder];
}

- (IBAction)addTabGroupWithoutPrompt:(id)aSender
{
  BookmarkFolder* newTabGroup = [[[BookmarkFolder alloc] init] autorelease];
  [newTabGroup setIsGroup:YES];

  BrowserWrapper* currentBrowserWrapper = [self browserWrapper];
  int numberOfTabs = [mTabBrowser numberOfTabViewItems];
  NSString *primaryTabTitle = nil;

  // When creating Bookmark items, set the last-visited time to the time that
  // the bookmark was created.  TODO: use page load time.
  NSDate* now = [NSDate date];

  for (int i = 0; i < numberOfTabs; i++) {
    BrowserWrapper* browserWrapper = (BrowserWrapper*)[[mTabBrowser tabViewItemAtIndex:i] view];
    if (![browserWrapper isBookmarkable])
      continue;

    [newTabGroup appendChild:[Bookmark bookmarkWithTitle:[browserWrapper pageTitle]
                                                     url:[browserWrapper currentURI]
                                               lastVisit:now]];

    if (browserWrapper == currentBrowserWrapper)
      primaryTabTitle = [browserWrapper pageTitle];
  }

  if (!primaryTabTitle && [newTabGroup count]) {
    // The active tab was not included in the group.
    primaryTabTitle = [[newTabGroup objectAtIndex:0] title];
  }

  NS_ASSERTION([newTabGroup count], "Adding a tab group with no children");
  [newTabGroup setTitle:[NSString stringWithFormat:NSLocalizedString(@"defaultTabGroupTitle", nil),
                                                   [newTabGroup count], 
                                                   primaryTabTitle]];
  BookmarkFolder* parentFolder = [[BookmarkManager sharedBookmarkManager] lastUsedBookmarkFolder];
  [parentFolder appendChild:newTabGroup];
  [[BookmarkManager sharedBookmarkManager] setLastUsedBookmarkFolder:parentFolder];
}

- (IBAction)addBookmarkForLink:(id)aSender
{
  if (!mDataOwner->mContextMenuNode)
    return;

  nsCOMPtr<nsIDOMElement> linkContent;
  nsAutoString href;
  GeckoUtils::GetEnclosingLinkElementAndHref(mDataOwner->mContextMenuNode, getter_AddRefs(linkContent), href);
  nsAutoString linkText;
  GeckoUtils::GatherTextUnder(linkContent, linkText);
  NSString* urlStr = [NSString stringWith_nsAString:href];
  NSString* titleStr = [NSString stringWith_nsAString:linkText];

  NSDictionary* itemInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                            titleStr, kAddBookmarkItemTitleKey,
                                              urlStr, kAddBookmarkItemURLKey,
                                                      nil];
  NSArray* items = [NSArray arrayWithObject:itemInfo];
  [[AddBookmarkDialogController controller] showDialogWithLocationsAndTitles:items isFolder:NO onWindow:[self window]];
}

- (IBAction)addBookmarkFolder:(id)aSender
{
  if ([self bookmarkManagerIsVisible])
  {
    // if the bookmarks view controller is visible, delegate to it (so that it can use the
    // selection to set the parent folder)
    BookmarkViewController* bookmarksController = [self bookmarkViewControllerForCurrentTab];
    [bookmarksController addBookmarkFolder:aSender];
  }
  else
    [[AddBookmarkDialogController controller] showDialogWithLocationsAndTitles:nil isFolder:YES onWindow:[self window]];
}

- (IBAction)addBookmarkSeparator:(id)aSender
{
  BookmarkViewController* bookmarksController = [self bookmarkViewControllerForCurrentTab];
  [bookmarksController addBookmarkSeparator:aSender];
}

//
// -currentWebNavigation
//
// return a weak reference to the current web navigation object. Callers should
// not hold onto this for longer than the current call unless they addref it.
//
- (nsIWebNavigation*) currentWebNavigation
{
  BrowserWrapper* wrapper = [self browserWrapper];
  if (!wrapper) return nsnull;
  CHBrowserView* view = [wrapper browserView];
  if (!view) return nsnull;
  nsCOMPtr<nsIWebBrowser> webBrowser = dont_AddRef([view webBrowser]);
  if (!webBrowser) return nsnull;
  nsCOMPtr<nsIWebNavigation> webNav(do_QueryInterface(webBrowser));
  return webNav.get();
}

//
// -sessionHistory
//
// Return a weak reference to the current session history object. Callers
// should not hold onto this for longer than the current call unless they addref.
//
- (nsISHistory*) sessionHistory
{
  nsIWebNavigation* webNav = [self currentWebNavigation];
  if (!webNav) return nil;
  nsCOMPtr<nsISHistory> sessionHistory;
  webNav->GetSessionHistory(getter_AddRefs(sessionHistory));
  return sessionHistory.get();
}

- (void)historyItemAction:(id)inSender
{
  // get web navigation for current browser
  nsIWebNavigation* webNav = [self currentWebNavigation];
  if (!webNav) return;
  
  // browse to the history entry for the menuitem that was selected
  PRInt32 historyIndex = [inSender tag];
  webNav->GotoIndex(historyIndex);
}

//
// -populateSessionHistoryMenu:shist:from:to:
//
// Adds to the given popup menu the items of the session history from index |inFrom| to
// |inTo|. Sets the tag on the item to the index in the session history. When an item
// is selected, calls |-historyItemAction:|. Correctly handles iterating in the 
// correct direction based on relative indices of from/to.
//
- (void)populateSessionHistoryMenu:(NSMenu*)inPopup shist:(nsISHistory*)inHistory from:(unsigned long)inFrom to:(unsigned long)inTo
{
  // max number of characters in a menu title before cropping it
  const unsigned int kMaxTitleLength = 80;

  // go forwards if |inFrom| < |inTo| and backwards if |inFrom| > |inTo|
  int direction = -1;
  if (inFrom <= inTo)
    direction = 1;

  // create a menu item for each item in the session history. Instead of simply going
  // from |inFrom| to |inTo|, we use |count| to take the directionality out of the loop
  // control so we can go fwd or backwards with the same loop control.
  const int numIterations = abs(inFrom - inTo) + 1;    
  for (PRInt32 i = inFrom, count = 0; count < numIterations; i += direction, ++count) {
    nsCOMPtr<nsIHistoryEntry> entry;
    inHistory->GetEntryAtIndex(i, PR_FALSE, getter_AddRefs(entry));
    if (entry) {
      nsAutoString textStr;
      entry->GetTitle(getter_Copies(textStr));
      NSString* title = [[NSString stringWith_nsAString: textStr] stringByTruncatingTo:kMaxTitleLength at:kTruncateAtMiddle];    
      NSMenuItem *newItem = [inPopup addItemWithTitle:title action:@selector(historyItemAction:) keyEquivalent:@""];
      [newItem setTarget:self];
      [newItem setTag:i];
    }
  }
}

//
// -forwardMenu:
//
// Create a menu off the fwd button (the sender) that contains the session history
// from the current position forward to the most recent in the session history.
//
- (IBAction)forwardMenu:(id)inSender
{
  NSMenu* popupMenu = [[[NSMenu alloc] init] autorelease];
  [popupMenu addItemWithTitle:@"" action:NULL keyEquivalent:@""];  // dummy first item

  // figure out what indices of the history to build in the menu. Item 0
  // in the shared history is the least recent (beginning of history) page.
  nsISHistory* sessionHistory = [self sessionHistory];
  PRInt32 currentIndex;
  sessionHistory->GetIndex(&currentIndex);
  PRInt32 count;
  sessionHistory->GetCount(&count);

  // builds forwards from the item after the current to the end (|count|)
  [self populateSessionHistoryMenu:popupMenu shist:sessionHistory from:currentIndex+1 to:count-1];

  // use a temporary NSPopUpButtonCell to display the menu.
  NSPopUpButtonCell *popupCell = [[[NSPopUpButtonCell alloc] initTextCell:@"" pullsDown:YES] autorelease];
  [popupCell setMenu: popupMenu];
  [popupCell trackMouse:[NSApp currentEvent] inRect:[inSender bounds] ofView:inSender untilMouseUp:YES];
}

//
// -backMenu:
//
// Create a menu off the back button (the sender) that contains the session history
// from the current position backward to the first item in the session history.
//
- (IBAction)backMenu:(id)inSender
{
  NSMenu* popupMenu = [[[NSMenu alloc] init] autorelease];
  [popupMenu addItemWithTitle:@"" action:NULL keyEquivalent:@""];  // dummy first item

  // figure out what indices of the history to build in the menu. Item 0
  // in the shared history is the least recent (beginning of history) page.
  nsISHistory* sessionHistory = [self sessionHistory];
  PRInt32 currentIndex;
  sessionHistory->GetIndex(&currentIndex);

  // builds backwards from the item before the current item to 0, the first item in the list
  [self populateSessionHistoryMenu:popupMenu shist:sessionHistory from:currentIndex-1 to:0];

  // use a temporary NSPopUpButtonCell to display the menu.
  NSPopUpButtonCell *popupCell = [[[NSPopUpButtonCell alloc] initTextCell:@"" pullsDown:YES] autorelease];
  [popupCell setMenu: popupMenu];
  [popupCell trackMouse:[NSApp currentEvent] inRect:[inSender bounds] ofView:inSender untilMouseUp:YES];
}

- (IBAction)back:(id)aSender
{
  [[mBrowserView browserView] goBack];
}

- (IBAction)forward:(id)aSender
{
  [[mBrowserView browserView] goForward];
}

- (IBAction)reload:(id)aSender
{
  [self reloadBrowserWrapper:mBrowserView sender:aSender];
}

- (IBAction)reloadSendersTab:(id)sender
{
  if ([sender isMemberOfClass:[NSMenuItem class]]) {
    BrowserTabViewItem* tabViewItem = [mTabBrowser itemWithTag:[sender tag]];
    if (tabViewItem)
      [self reloadBrowserWrapper:[tabViewItem view] sender:sender];
  }
}

- (IBAction)reloadAllTabs:(id)sender
{
  NSEnumerator* tabsEnum = [[mTabBrowser tabViewItems] objectEnumerator];
  BrowserTabViewItem* curTabItem;
  while ((curTabItem = [tabsEnum nextObject])) {
    if ([curTabItem isKindOfClass:[BrowserTabViewItem class]])
      [self reloadBrowserWrapper:[curTabItem view] sender:sender];
  }
}

// Reloads the given BrowserWrapper, automatically performing the appropriate
// checks to decide whether to do a force-reload if sender is non-nil.
- (void)reloadBrowserWrapper:(BrowserWrapper *)inWrapper sender:(id)sender
{
  unsigned int reloadFlags = NSLoadFlagsNone;
  // If the sender is nil then the reload was programatically invoked, so we
  // don't want to change behavior based on whether shift happens to be pressed.
  if (sender) {
    if ([sender respondsToSelector:@selector(keyEquivalent)]) {
      // Capital R tests for shift when there's a keyEquivalent, keyEquivalentModifierMask
      // tests when there isn't
      if ([[sender keyEquivalent] isEqualToString:@"R"] ||
          ([sender keyEquivalentModifierMask] & NSShiftKeyMask))
        reloadFlags = NSLoadFlagsBypassCacheAndProxy;
    }
    // It's a toolbar button, so we test for shift using modifierFlags
    else if ([[NSApp currentEvent] modifierFlags] & NSShiftKeyMask)
      reloadFlags = NSLoadFlagsBypassCacheAndProxy;
  }

  [inWrapper reload:reloadFlags];
}

- (IBAction)stop:(id)aSender
{
  [[mBrowserView browserView] stop:NSStopLoadAll];
}

- (IBAction)home:(id)aSender
{
  [mBrowserView loadURI:[[PreferenceManager sharedInstance] homePageUsingStartPage:NO]
               referrer:nil
                  flags:NSLoadFlagsNone
               focusContent:YES
            allowPopups:NO];
}

- (NSString*)contextMenuNodeDocumentURL
{
  if (!mDataOwner->mContextMenuNode) return @"";

  nsCOMPtr<nsIDOMDocument> ownerDoc;
  mDataOwner->mContextMenuNode->GetOwnerDocument(getter_AddRefs(ownerDoc));

  nsCOMPtr<nsIDOMNSDocument> nsDoc = do_QueryInterface(ownerDoc);
  if (!nsDoc) return @"";

  nsCOMPtr<nsIDOMLocation> location;
  nsDoc->GetLocation(getter_AddRefs(location));
  if (!location) return @"";

  nsAutoString urlStr;
  location->GetHref(urlStr);
  return [NSString stringWith_nsAString:urlStr];
}

- (IBAction)frameToNewWindow:(id)sender
{
  // assumes mContextMenuNode has been set
  NSString* frameURL = [self contextMenuNodeDocumentURL];
  if ([frameURL length] > 0)
    [self openNewWindowWithURL:frameURL referrer:nil loadInBackground:NO allowPopups:NO];     // follow the pref?
}

- (IBAction)frameToNewTab:(id)sender
{
  // assumes mContextMenuNode has been set
  NSString* frameURL = [self contextMenuNodeDocumentURL];
  if ([frameURL length] > 0)
    [self openNewTabWithURL:frameURL referrer:nil loadInBackground:NO allowPopups:NO setJumpback:NO];  // follow the pref?
}

- (IBAction)frameToThisWindow:(id)sender
{
  // assumes mContextMenuNode has been set
  NSString* frameURL = [self contextMenuNodeDocumentURL];
  if ([frameURL length] > 0)
    [self loadURL:frameURL];
}

// map command-left arrow to 'back'
- (void)moveToBeginningOfLine:(id)sender
{
  [self back:sender];
}

// map command-right arrow to 'forward'
- (void)moveToEndOfLine:(id)sender
{
  [self forward:sender];
}

//
// -currentEditor:
//
// Returns the nsIEditor of the currently focused text area, input, or midas editor
//
- (void)currentEditor:(nsIEditor**)outEditor
{
  if (!outEditor)
    return;
  *outEditor = nsnull;

  nsCOMPtr<nsIDOMElement> focusedElement =
    dont_AddRef([[[self browserWrapper] browserView] focusedDOMElement]);
  nsCOMPtr<nsIDOMNSEditableElement> editElement = do_QueryInterface(focusedElement);
  if (editElement) {
    editElement->GetEditor(outEditor);
  }
  // if there's no element focused, we're probably in a Midas editor
  else {
    #define ENSURE_TRUE(x) if (!x) return;
    nsCOMPtr<nsIFocusController> controller =
      dont_AddRef([[[self browserWrapper] browserView] focusController]);
    ENSURE_TRUE(controller);
    nsCOMPtr<nsIDOMWindowInternal> winInternal;
    controller->GetFocusedWindow(getter_AddRefs(winInternal));
    nsCOMPtr<nsIDOMWindow> focusedWindow(do_QueryInterface(winInternal));
    ENSURE_TRUE(focusedWindow);
    nsCOMPtr<nsIDOMDocument> domDoc;
    focusedWindow->GetDocument(getter_AddRefs(domDoc));
    nsCOMPtr<nsIDOMNSHTMLDocument> htmlDoc(do_QueryInterface(domDoc));
    ENSURE_TRUE(htmlDoc);
    nsAutoString designMode;
    htmlDoc->GetDesignMode(designMode);
    if (designMode.EqualsLiteral("on")) {
      // we are in a Midas editor, so find its editor
      nsCOMPtr<nsPIDOMWindow> privateWindow = do_QueryInterface(focusedWindow);
      ENSURE_TRUE(privateWindow);
      nsIDocShell *docshell = privateWindow->GetDocShell();
      nsCOMPtr<nsIEditingSession> editSession = do_GetInterface(docshell);
      ENSURE_TRUE(editSession)
      editSession->GetEditorForWindow(focusedWindow, outEditor);
    }
    #undef ENSURE_TRUE
  }
}

-(void)loadURL:(NSString*)aURLSpec referrer:(NSString*)aReferrer focusContent:(BOOL)focusContent allowPopups:(BOOL)inAllowPopups
{
  if (mInitialized) {
    [mBrowserView loadURI:aURLSpec referrer:aReferrer flags:NSLoadFlagsNone focusContent:focusContent allowPopups:inAllowPopups];
  }
  else {
    // we haven't yet initialized all the browser machinery, stash the url and referrer
    // until we're ready in windowDidLoad:
    mPendingURL = aURLSpec;
    [mPendingURL retain];
    mPendingReferrer = aReferrer;
    [mPendingReferrer retain];
    mPendingActivate = focusContent;
    mPendingAllowPopups = inAllowPopups;
  }
}

//Simplified loadURL which calls default values
- (void)loadURL:(NSString*)aURLSpec
{
  [self loadURL:aURLSpec referrer:nil focusContent:YES allowPopups:NO];
}

//
// closeBrowserWindow:
//
// Some gecko view in this window wants to close the window. If we have
// a bunch of tabs, only close the relevant tab, otherwise close the
// window as a whole.
//
- (void)closeBrowserWindow:(BrowserWrapper*)inBrowser
{
  if ([mTabBrowser numberOfTabViewItems] > 1) {
    [self closeTab:[inBrowser tab]];
  }
  // if a window unload handler calls window.close(), we
  // can get here while the window is already being closed,
  // so we don't want to close it again (and recurse).
  else if (!mClosingWindow) {
    [[self window] close];
    [[NSApp delegate] delayedAdjustBookmarksMenuItemsEnabling];
  }

  [[SessionManager sharedInstance] windowStateChanged];
}

- (void)willShowPromptForBrowser:(BrowserWrapper*)inBrowser
{
  // Remember where the user was, so we can come back.
  mLastBrowserView = mBrowserView;
  // bring the tab to the front (for security reasons)
  BrowserTabViewItem* tabItem = [self tabForBrowser:inBrowser];
  [mTabBrowser selectTabViewItem:tabItem];
  // force a display, so that the tab view redraws before the sheet is shown
  [mTabBrowser display];
}

- (void)didDismissPromptForBrowser:(BrowserWrapper*)inBrowser
{
  // Return the user to the tab they were looking at.
  if (mLastBrowserView) {
    BrowserTabViewItem* lastTab = [self tabForBrowser:mLastBrowserView];
    [mTabBrowser selectTabViewItem:lastTab];
  }
  mLastBrowserView = nil;
}

- (void)createNewTab:(ENewTabContents)contents
{
    BrowserTabViewItem* newTab  = [self createNewTabItem];
    BrowserWrapper*     newView = [newTab view];
    
    BOOL loadHomepage = NO;
    if (contents == eNewTabHomepage)
    {
      // 0 = about:blank, 1 = home page, 2 = last page visited
      int newTabPage = [[PreferenceManager sharedInstance] getIntPref:"browser.tabs.startPage" withSuccess:NULL];
      loadHomepage = (newTabPage == 1);
    }

    [newTab setLabel: (loadHomepage ? NSLocalizedString(@"TabLoading", @"") : NSLocalizedString(@"UntitledPageTitle", @""))];
    [mTabBrowser addTabViewItem: newTab];
    
    BOOL focusURLBar = NO;
    if (contents != eNewTabEmpty)
    {
      // Focus the URL bar if we're opening a blank tab and the URL bar is visible.
      NSToolbar* toolbar = [[self window] toolbar];
      BOOL locationBarVisible = [toolbar isVisible] &&
                                ([toolbar displayMode] == NSToolbarDisplayModeIconAndLabel ||
                                 [toolbar displayMode] == NSToolbarDisplayModeIconOnly);
                                
      NSString* urlToLoad = @"about:blank";
      if (loadHomepage)
        urlToLoad = [[PreferenceManager sharedInstance] homePageUsingStartPage:NO];

      focusURLBar = locationBarVisible && (!urlToLoad || [urlToLoad isBlankURL]);

      [newView loadURI:urlToLoad referrer:nil flags:NSLoadFlagsNone focusContent:!focusURLBar allowPopups:NO];
    }

    [mTabBrowser selectLastTabViewItem:self];

    if (focusURLBar)
      [self focusURLBar];
}

- (IBAction)newTab:(id)sender
{
  [self createNewTab:eNewTabHomepage];  // we'll look at the pref to decide whether to load the home page
}

-(IBAction)closeCurrentTab:(id)sender
{
  if ([mTabBrowser numberOfTabViewItems] > 1)
    [self closeTab:[mTabBrowser selectedTabViewItem]];
}

- (IBAction)previousTab:(id)sender
{
  // pass |nil| because it's way too complicated to compute the previous tab.
  [[NSNotificationCenter defaultCenter] postNotificationName:kTabWillChangeNotifcation object:nil];
  if ([mTabBrowser indexOfTabViewItem:[mTabBrowser selectedTabViewItem]] == 0)
    [mTabBrowser selectLastTabViewItem:sender];
  else
    [mTabBrowser selectPreviousTabViewItem:sender];

  [[NSApp delegate] delayedAdjustBookmarksMenuItemsEnabling];
}

- (IBAction)nextTab:(id)sender
{
  // pass |nil| because it's way too complicated to compute the next tab.
  [[NSNotificationCenter defaultCenter] postNotificationName:kTabWillChangeNotifcation object:nil];
  if ([mTabBrowser indexOfTabViewItem:[mTabBrowser selectedTabViewItem]] == [mTabBrowser numberOfTabViewItems] - 1)
    [mTabBrowser selectFirstTabViewItem:sender];
  else
    [mTabBrowser selectNextTabViewItem:sender];

  [[NSApp delegate] delayedAdjustBookmarksMenuItemsEnabling];
}

- (IBAction)closeSendersTab:(id)sender
{
  if ([sender isMemberOfClass:[NSMenuItem class]]) {
    BrowserTabViewItem* tabViewItem = [mTabBrowser itemWithTag:[sender tag]];
    if (tabViewItem)
      [self closeTab:tabViewItem];
  }
}

- (IBAction)closeOtherTabs:(id)sender
{
  if ([sender isMemberOfClass:[NSMenuItem class]]) {
    BrowserTabViewItem* savedTab = [mTabBrowser itemWithTag:[sender tag]];
    if (savedTab) {
      int tabCount = [mTabBrowser numberOfTabViewItems];
      // Any tab may refuse to close, so we walk the tabs in reverse so that any
      // that are left open don't throw off the count.
      for (int i = (tabCount - 1); i >= 0; --i) {
        BrowserTabViewItem* doomedTab = (BrowserTabViewItem*)[mTabBrowser tabViewItemAtIndex:i];
        if (doomedTab != savedTab)
          [doomedTab closeTab:self];
      }
    }
  }
  [[NSApp delegate] delayedAdjustBookmarksMenuItemsEnabling];
}

- (void)closeTab:(NSTabViewItem *)tab
{
  [(BrowserTabViewItem*)tab closeTab:self];
  [[NSApp delegate] delayedAdjustBookmarksMenuItemsEnabling];
}

- (IBAction)moveTabToNewWindow:(id)sender
{
  if ([sender isMemberOfClass:[NSMenuItem class]]) {
    BrowserTabViewItem* tabViewItem = [mTabBrowser itemWithTag:[sender tag]];
    if (tabViewItem) {
      NSString* url = [[tabViewItem view] currentURI];
      BOOL backgroundLoad = [BrowserWindowController shouldLoadInBackgroundForDestination:eDestinationNewWindow
                                                                                   sender:nil];

      [self openNewWindowWithURL:url referrer:nil loadInBackground:backgroundLoad allowPopups:NO];

      [self closeTab:tabViewItem];
    }
  }
}

- (void)tabView:(NSTabView *)aTabView didSelectTabViewItem:(NSTabViewItem *)aTabViewItem
{
  // we'll get called for the sidebar tabs as well. ignore any calls coming from
  // there, we're only interested in the browser tabs.
  if (aTabView != mTabBrowser)
    return;

  // Disconnect the old view, if one has been designated.
  // If the window has just been opened, none has been.
  if (mBrowserView)
  {
    [mBrowserView willResignActiveBrowser];
    [mBrowserView setDelegate:nil];
  }

  // Connect up the new view
  mBrowserView = [aTabViewItem view];
  [mTabBrowser refreshTabBar:YES];
      
  // Make the new view the primary content area.
  [mBrowserView setDelegate:self];
  [mBrowserView didBecomeActiveBrowser];
  [self updateFromFrontmostTab];

  if (![self userChangedLocationField] && [[self window] isKeyWindow])
    [mBrowserView setBrowserActive:YES];

  [[NSApp delegate] delayedAdjustBookmarksMenuItemsEnabling];
}

- (void)tabView:(NSTabView *)aTabView willSelectTabViewItem:(NSTabViewItem *)aTabViewItem
{
  // we'll get called for the sidebar tabs as well. ignore any calls coming from
  // there, we're only interested in the browser tabs.
  if (aTabView != mTabBrowser)
    return;
  if ([aTabView isKindOfClass:[BrowserTabView class]] && [aTabViewItem isKindOfClass:[BrowserTabViewItem class]]) {
    [(BrowserTabViewItem *)[aTabView selectedTabViewItem] willDeselect];
    [(BrowserTabViewItem *)aTabViewItem willSelect];
  }
}

- (void)tabViewDidChangeNumberOfTabViewItems:(NSTabView *)aTabView
{
  [[NSApp delegate] delayedFixCloseMenuItemKeyEquivalents];
  [mTabBrowser refreshTabBar:YES];
  // paranoia, to avoid stale mBrowserView pointer (since we don't own it)
  if ([aTabView numberOfTabViewItems] == 0)
    mBrowserView = nil;
}

-(BrowserTabView*)tabBrowser
{
  return mTabBrowser;
}

-(BrowserWrapper*)browserWrapper
{
  return mBrowserView;
}

// this should really be a class method
-(BrowserWindowController*)openNewWindowWithURL:(NSString*)aURLSpec referrer:(NSString*)aReferrer loadInBackground:(BOOL)aLoadInBG allowPopups:(BOOL)inAllowPopups
{
  BOOL focusURLBar = !aURLSpec || [aURLSpec isBlankURL];
  BrowserWindowController* browser = [self openNewWindow:aLoadInBG];
  [browser loadURL:aURLSpec referrer:aReferrer focusContent:!focusURLBar allowPopups:inAllowPopups];
  return browser;
}

//
// -openNewWindow:
//
// open a new window, but doesn't load anything into it. Must be matched
// with a call to do that.
// 
// this should really be a class method
//
- (BrowserWindowController*)openNewWindow:(BOOL)aLoadInBG
{
  // Autosave our dimensions before we open a new window.  That ensures the size ends up matching.
  [self autosaveWindowFrame];

  BrowserWindowController* browser = [[BrowserWindowController alloc] initWithWindowNibName: @"BrowserWindow"];
  if (aLoadInBG)
  {
    BrowserWindow* browserWin = (BrowserWindow*)[browser window];
    [browserWin setSuppressMakeKeyFront:YES]; // prevent gecko focus bringing the window to the front
    [browserWin orderWindow: NSWindowBelow relativeTo: [[self window] windowNumber]];
    [browserWin setSuppressMakeKeyFront:NO];
  }
  else
    [browser showWindow:nil];

  return browser;
}

-(void)openNewTabWithURL:(NSString*)aURLSpec referrer:(NSString*)aReferrer loadInBackground:(BOOL)aLoadInBG 
        allowPopups:(BOOL)inAllowPopups setJumpback:(BOOL)inSetJumpback
{
  BrowserTabViewItem* previouslySelected = (BrowserTabViewItem*)[mTabBrowser selectedTabViewItem];
  BrowserTabViewItem* newTab             = [self openNewTab:aLoadInBG];
  BOOL focusURLBar                       = !aURLSpec || [aURLSpec isBlankURL];

  // if instructed, tell the tab browser to remember the currently selected tab to
  // jump back to if this new one is closed w/out switching to any other tabs.
  // This must come after the call to |openNewTab:| which clears the jumpback
  // tab and changes the selected tab to the new tab.
  if (inSetJumpback && !aLoadInBG)
    [mTabBrowser setJumpbackTab:previouslySelected];

  [[newTab view] loadURI:aURLSpec referrer:aReferrer flags:NSLoadFlagsNone focusContent:!focusURLBar allowPopups:inAllowPopups];
}

//
// -createNewTabBrowser:
// BrowserUICreationDelegate
//
// create a new tab in the window associated with this wrapper and get its
// browser view without loading anything into it.
//
- (CHBrowserView*)createNewTabBrowser:(BOOL)inLoadInBG
{
  BrowserTabViewItem* previouslySelected = (BrowserTabViewItem*)[mTabBrowser selectedTabViewItem];
  BrowserTabViewItem* newTab = [self openNewTab:inLoadInBG];
 
  // tell the tab browser to remember the currently selected tab to
  // jump back to if this new one is closed w/out switching to any other tabs.
  // This must come after the call to |openNewTab:| which clears the jumpback
  // tab and changes the selected tab to the new tab.
  if (!inLoadInBG)
    [mTabBrowser setJumpbackTab:previouslySelected];

  return [[newTab view] browserView];
}

//
// -openNewTab:
//
// open a new tab, but doesn't load anything into it. Must be matched
// with a call to do that.
//
- (BrowserTabViewItem*)openNewTab:(BOOL)aLoadInBG
{
  BrowserTabViewItem* newTab  = [self createNewTabItem];

  
  // hyatt originally made new tabs open on the far right and tabs opened from a content
  // link open to the right of the current tab. The idea was to keep the new tab
  // close to the tab that spawned it, since they are related. Users, however, got confused
  // as to why tabs appeared in different places, so now all tabs go on the far right.
#ifdef OPEN_TAB_TO_RIGHT_OF_SELECTED    
  NSTabViewItem* selectedTab = [mTabBrowser selectedTabViewItem];
  int index = [mTabBrowser indexOfTabViewItem: selectedTab];
  [mTabBrowser insertTabViewItem: newTab atIndex: index+1];
#else
  [mTabBrowser addTabViewItem: newTab];
#endif

  [newTab setLabel: NSLocalizedString(@"TabLoading", @"")];

  // unless we're told to load this tab in the bg, select the tab
  // before we load so that it's the primary and will push the url into
  // the url bar immediately rather than waiting for the server.
  if (!aLoadInBG)
    [mTabBrowser selectTabViewItem: newTab];

  return newTab;
}

-(void)openNewWindowWithDescriptor:(nsISupports*)aDesc displayType:(PRUint32)aDisplayType loadInBackground:(BOOL)aLoadInBG
{
  BrowserWindowController* browser = [self openNewWindow:aLoadInBG];
  [[[browser browserWrapper] browserView] setPageDescriptor:aDesc displayType:aDisplayType];
}

-(void)openNewTabWithDescriptor:(nsISupports*)aDesc displayType:(PRUint32)aDisplayType loadInBackground:(BOOL)aLoadInBG
{
  BrowserTabViewItem* newTab = [self openNewTab:aLoadInBG];
  [[[newTab view] browserView] setPageDescriptor:aDesc displayType:aDisplayType];
}

- (void)openURLArray:(NSArray*)urlArray tabOpenPolicy:(ETabOpenPolicy)tabPolicy allowPopups:(BOOL)inAllowPopups
{
  int curNumTabs = [mTabBrowser numberOfTabViewItems];
  int numItems   = (int)[urlArray count];
  int selectedTabIndex = [[mTabBrowser tabViewItems] indexOfObject:[mTabBrowser selectedTabViewItem]];
  BrowserTabViewItem* tabViewToSelect = nil;
  
  for (int i = 0; i < numItems; i++)
  {
    NSString* thisURL = [urlArray objectAtIndex:i];
    BrowserTabViewItem* tabViewItem = nil;
    
    if (tabPolicy == eReplaceTabs && i < curNumTabs)
      tabViewItem = (BrowserTabViewItem*)[mTabBrowser tabViewItemAtIndex:i];
    else if (tabPolicy == eReplaceFromCurrentTab && selectedTabIndex < curNumTabs)
      tabViewItem = (BrowserTabViewItem*)[mTabBrowser tabViewItemAtIndex:selectedTabIndex++];
    else
    {
      tabViewItem = [self createNewTabItem];
      [tabViewItem setLabel:NSLocalizedString(@"UntitledPageTitle", @"")];
      [mTabBrowser addTabViewItem:tabViewItem];
    }
    
    if (!tabViewToSelect)
      tabViewToSelect = tabViewItem;

    [[tabViewItem view] loadURI:thisURL referrer:nil
                          flags:NSLoadFlagsNone focusContent:(i == 0) allowPopups:inAllowPopups];
  }
  
  // if we replace all tabs (because we opened a tab group), or we open additional tabs
  // with the "focus new tab"-pref on, focus the first new tab.
  BOOL loadInBackground = [BrowserWindowController shouldLoadInBackgroundForDestination:eDestinationNewTab
                                                                                 sender:nil];
  if (!((tabPolicy == eAppendTabs) && loadInBackground))
    [mTabBrowser selectTabViewItem:tabViewToSelect];
    
}

-(void) openURLArrayReplacingTabs:(NSArray*)urlArray closeExtraTabs:(BOOL)closeExtra allowPopups:(BOOL)inAllowPopups
{
  // if there are no urls to load (say, an empty tab group), just bail outright. otherwise we'd be
  // left with no tabs at all and hell to pay when it came time to do menu/toolbar item validation.
  if (![urlArray count])
    return;

  [self openURLArray:urlArray tabOpenPolicy:eReplaceTabs allowPopups:inAllowPopups];
  if (closeExtra) {
    int closeIndex = [urlArray count];
    int closeCount = [mTabBrowser numberOfTabViewItems] - closeIndex;
    for (int i = 0; i < closeCount; i++) {
      [(BrowserTabViewItem*)[mTabBrowser tabViewItemAtIndex:closeIndex] closeTab:nil];
    }
  }
}

-(BrowserTabViewItem*)createNewTabItem
{
  BrowserTabViewItem* newTab = [BrowserTabView makeNewTabItem];
  BrowserWrapper* newView = [[BrowserWrapper alloc] initWithTab:newTab inWindow:[self window]];
  [newView setUICreationDelegate:self];

  // register the bookmarks as a custom view
  BookmarkViewController* bmController = [[[BookmarkViewController alloc] initWithBrowserWindowController:self] autorelease];
  [newView registerContentViewProvider:bmController forURL:@"about:bookmarks"];
  [newView registerContentViewProvider:bmController forURL:@"about:history"];
  
  // size the new browser view properly up-front, so that if the
  // page is scrolled to a relative anchor, we don't mess with the
  // scroll position by resizing it later
  [newView setFrame:[mTabBrowser contentRect] resizingBrowserViewIfHidden:YES];

  [newTab setView: newView];  // takes ownership
  [newView release];
  
  // we have to copy the context menu for each tag, because
  // the menu gets the tab view item's tag.
  NSMenu* contextMenu = [mTabMenu copy];
  [[newTab buttonView] setMenu:contextMenu];
  [contextMenu release];

  return newTab;
}

-(void)setChromeMask:(unsigned int)aMask
{
  mChromeMask = aMask;
}

-(unsigned int)chromeMask
{
  return mChromeMask;
}

-(BOOL)hasFullBrowserChrome
{
  return (mChromeMask == 0 || 
            (mChromeMask & nsIWebBrowserChrome::CHROME_TOOLBAR &&
             mChromeMask & nsIWebBrowserChrome::CHROME_STATUSBAR &&
             mChromeMask & nsIWebBrowserChrome::CHROME_WINDOW_RESIZE));
}

- (BOOL)canMakeTextBigger
{
  BrowserWrapper* wrapper = [self browserWrapper];
  return (![wrapper isEmpty] &&
          ![self bookmarkManagerIsVisible] &&
          [[wrapper browserView] isTextBasedContent] &&
          [[wrapper browserView] canMakeTextBigger]);
}

- (BOOL)canMakeTextSmaller
{
  BrowserWrapper* wrapper = [self browserWrapper];
  return (![wrapper isEmpty] &&
          ![self bookmarkManagerIsVisible] &&
          [[wrapper browserView] isTextBasedContent] &&
          [[wrapper browserView] canMakeTextSmaller]);
}

- (BOOL)canMakeTextDefaultSize
{
  BrowserWrapper* wrapper = [self browserWrapper];
  return (![wrapper isEmpty] &&
          ![self bookmarkManagerIsVisible] &&
          [[wrapper browserView] isTextBasedContent] &&
          ![[wrapper browserView] isTextDefaultSize]);
}

- (IBAction)makeTextBigger:(id)aSender
{
  [[mBrowserView browserView] makeTextBigger];
}

- (IBAction)makeTextSmaller:(id)aSender
{
  [[mBrowserView browserView] makeTextSmaller];
}

- (IBAction)makeTextDefaultSize:(id)aSender
{
  [[mBrowserView browserView] makeTextDefaultSize];
}

- (IBAction)getInfo:(id)sender
{
  if ([self bookmarkManagerIsVisible])
    [self showBookmarksInfo:sender];
  else
    [self showPageInfo:sender];
}

- (BOOL)shouldShowBookmarkToolbar
{
  NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
  if ([defaults integerForKey:USER_DEFAULTS_HIDE_PERS_TOOLBAR_KEY] == 1)
     return NO;

  return YES;
}

// Called when a context menu should be shown.
- (void)onShowContextMenu:(int)flags domEvent:(nsIDOMEvent*)aEvent domNode:(nsIDOMNode*)aNode
{
  if (mDataOwner)
  {
    mDataOwner->mContextMenuFlags = flags;
    mDataOwner->mContextMenuNode  = aNode;
    mDataOwner->mContextMenuEvent = aEvent;
    mDataOwner->mGotOnContextMenu = true;
  }
  
  // There is no simple way of getting a callback when the context menu handling
  // has finished, so we don't have a good place to clear mContextMenuNode etc.
  // Cocoa doesn't provide any methods that can be overridden on the menu, view
  // or window.
  // The menu closes before the actions are dispatched, so that's too early.
  // And we can't just use -performSelector:afterDelay:0 because that will fire
  // while the menu is still up.
  // So the best solution I've been able to come up with is relying on the
  // autorelease of an object, which will happen when we get back to the
  // main loop.
  [[[ContextMenuDataClearer alloc] initWithTarget:self selector:@selector(clearContextMenuTarget)] autorelease];
}

- (void)clearContextMenuTarget
{
  if (mDataOwner)
  {
    mDataOwner->mContextMenuFlags = 0;
    mDataOwner->mContextMenuNode  = nsnull;
    mDataOwner->mContextMenuEvent = nsnull;
    mDataOwner->mGotOnContextMenu = false;
  }
}

// Returns the text of the href attribute for the link the context menu is
// currently on. Returns an empty string if the context menu is not on a
// link or we couldn't work out the href for some other reason.
- (NSString*)contextMenuNodeHrefText
{
  if (!mDataOwner->mContextMenuNode)
    return @"";

  nsCOMPtr<nsIDOMElement> linkContent;
  nsAutoString href;
  GeckoUtils::GetEnclosingLinkElementAndHref(mDataOwner->mContextMenuNode, getter_AddRefs(linkContent), href);

  // XXXdwh Handle simple XLINKs if we want to be compatible with Mozilla, but who
  // really uses these anyway? :)
  if (linkContent && !href.IsEmpty())
    return [NSString stringWith_nsAString:href];

  return @"";
}

//
// Determine if the node the context menu has been invoked for is an <a> node
// indicating a mailto: link. If so return an array containing the e-mail addresses
// in the link. Otherwise return nil.
//
- (NSArray*)mailAddressesInContextMenuLinkNode
{
  NSString* hrefStr = [self contextMenuNodeHrefText];
  
  if ([hrefStr hasPrefix:@"mailto:"]) {
    NSString* linkTargetText = [hrefStr substringFromIndex:7];
    
    // mailto: links can contain arguments (after '?')
    NSRange separatorRange = [linkTargetText rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"?"]];
    
    if (separatorRange.length != 0)
      linkTargetText = [linkTargetText substringToIndex:separatorRange.location];
      
    return [linkTargetText componentsSeparatedByString:@","];
  }

  return nil;
}

// Add the e-mail address from the mailto: link of the context menu node
// to the user's address book. If the address already exists we just
// open the address book at the record containing it.
- (IBAction)addToAddressBook:(id)aSender
{
  NSString* emailAddress = [aSender representedObject];
  if (emailAddress) {
    ABAddressBook* abook = [ABAddressBook sharedAddressBook];
    if ([abook emailAddressExistsInAddressBook:emailAddress] )
      [abook openAddressBookForRecordWithEmail:emailAddress];
    else
      [abook addNewPersonFromEmail:emailAddress];
  }
}

// Copy the e-mail address(es) from the mailto: link of the context menu node
// onto the clipboard.
- (IBAction)copyAddressToClipboard:(id)aSender
{
  NSString* emailAddress = [[self mailAddressesInContextMenuLinkNode] componentsJoinedByString:@","];
  
  if (emailAddress) {
    NSPasteboard* clipboard = [NSPasteboard generalPasteboard];
    
    NSArray* types = [NSArray arrayWithObject:NSStringPboardType];
    
    [clipboard declareTypes:types owner:nil];
    [clipboard setString:emailAddress forType:NSStringPboardType];
  }
}

//
// Create a menu item to add/open the specified e-mail address to Address Book
//
- (NSMenuItem*)prepareAddToAddressBookMenuItem:(NSString*)emailAddress
{
  NSMenuItem* addToAddressBookItem = nil;

  if ([emailAddress length] > 0) {
    addToAddressBookItem = [[NSMenuItem alloc] init];

    if ([[ABAddressBook sharedAddressBook] emailAddressExistsInAddressBook:emailAddress]) {
      NSString* realName = [[ABAddressBook sharedAddressBook] realNameForEmailAddress:emailAddress];
      [addToAddressBookItem setTitle:[NSString stringWithFormat:NSLocalizedString(@"Open %@ in Address Book", @""), realName != nil ? realName : @""]];
    } else {
      [addToAddressBookItem setTitle:[NSString stringWithFormat:NSLocalizedString(@"Add %@ to Address Book", @""), emailAddress]];
    }

    [addToAddressBookItem setEnabled:YES];
    [addToAddressBookItem setRepresentedObject:emailAddress];
    [addToAddressBookItem setAction:@selector(addToAddressBook:)];
    [addToAddressBookItem autorelease];
  }
  
  return addToAddressBookItem;
}

- (NSMenu*)contextMenu
{
  if (!mDataOwner->mGotOnContextMenu)
    return nil;

  BOOL showFrameItems = NO;
  BOOL isTextField = NO;
  BOOL needsAlternates = NO;
  BOOL isUnsafeLink = NO;

  NSArray* emailAddresses = nil;
  unsigned numEmailAddresses = 0;

  BOOL hasSelection = [[mBrowserView browserView] canCopy];
  BOOL isMidas = NO;

  if (mDataOwner->mContextMenuNode) {
    nsCOMPtr<nsIDOMDocument> ownerDoc;
    mDataOwner->mContextMenuNode->GetOwnerDocument(getter_AddRefs(ownerDoc));

    // Check to see if it's a Midas frame
    nsCOMPtr<nsIDOMNSHTMLDocument> htmlDoc(do_QueryInterface(ownerDoc));
    if (htmlDoc) {
      nsAutoString designMode;
      htmlDoc->GetDesignMode(designMode);
      isMidas = designMode.EqualsLiteral("on");
    }

    // If it's not a Midas frame, check to see if it's a subframe
    if (!isMidas) {
      nsCOMPtr<nsIDOMWindow> contentWindow = [[mBrowserView browserView] contentWindow];

      nsCOMPtr<nsIDOMDocument> contentDoc;
      if (contentWindow)
        contentWindow->GetDocument(getter_AddRefs(contentDoc));

      showFrameItems = (contentDoc != ownerDoc);
    }
  }

  NSMenu* menuPrototype = nil;
  int contextMenuFlags = mDataOwner->mContextMenuFlags;

  if ((contextMenuFlags & nsIContextMenuListener::CONTEXT_LINK) != 0) {
    emailAddresses = [self mailAddressesInContextMenuLinkNode];
    if (emailAddresses != nil)
      numEmailAddresses = [emailAddresses count];

    // Verify that it is safe to open this link.
    NSString* referrerURL = [[mBrowserView browserView] focusedURLString];
    nsCOMPtr<nsIDOMElement> linkElement;
    nsAutoString hrefURL;
    GeckoUtils::GetEnclosingLinkElementAndHref(mDataOwner->mContextMenuNode,
                                               getter_AddRefs(linkElement),
                                               hrefURL);
    if (!GeckoUtils::IsSafeToOpenURIFromReferrer(NS_ConvertUTF16toUTF8(hrefURL).get(), [referrerURL UTF8String]))
      isUnsafeLink = YES;

    if ((contextMenuFlags & nsIContextMenuListener::CONTEXT_IMAGE) != 0) {
      if (numEmailAddresses > 0)
        menuPrototype = mImageMailToLinkMenu;
      else
        menuPrototype = mImageLinkMenu;

      needsAlternates = YES;
    }
    else {
      if (numEmailAddresses > 0)
        menuPrototype = mMailToLinkMenu;
      else
        menuPrototype = mLinkMenu;
    }
  }
  else if ((contextMenuFlags & nsIContextMenuListener::CONTEXT_INPUT) != 0 ||
           (contextMenuFlags & nsIContextMenuListener::CONTEXT_TEXT) != 0 ||
           isMidas)
  {
    // The following is a hack to work around bug 365183: If there is a no selection in the
    // editor, we simulate a double click to select the word as native text fields do
    // for context clicks, which allows spell check to operate on the word under the mouse.
    // The behavior is not quite right since a right click outside of an existing selection should
    // change the selection, but this gets us most of the way there until bug 365183 is fixed.
    if (!hasSelection) {
      NSEvent* realClick = [NSApp currentEvent];
      NSEvent* fakeDoubleClickDown = [NSEvent mouseEventWithType:NSLeftMouseDown
                                                        location:[realClick locationInWindow]
                                                   modifierFlags:0
                                                       timestamp:[realClick timestamp]
                                                    windowNumber:[realClick windowNumber]
                                                         context:[realClick context]
                                                     eventNumber:[realClick eventNumber]
                                                      clickCount:2
                                                        pressure:[realClick pressure]];
      NSEvent* fakeDoubleClickUp = [NSEvent mouseEventWithType:NSLeftMouseUp
                                                      location:[realClick locationInWindow]
                                                 modifierFlags:0
                                                     timestamp:[realClick timestamp]
                                                  windowNumber:[realClick windowNumber]
                                                       context:[realClick context]
                                                   eventNumber:[realClick eventNumber]
                                                    clickCount:2
                                                      pressure:[realClick pressure]];
      NSView* textFieldView = [mContentView hitTest:[[mContentView superview] convertPoint:[realClick locationInWindow] fromView:nil]];
      [textFieldView mouseDown:fakeDoubleClickDown];
      [textFieldView mouseUp:fakeDoubleClickUp];
    }
    
    menuPrototype = mInputMenu;
    isTextField = YES;
  }
  else if ((contextMenuFlags & nsIContextMenuListener::CONTEXT_IMAGE) != 0) {
    menuPrototype = mImageMenu;
    needsAlternates = YES;
  }
  else if (!contextMenuFlags || (contextMenuFlags & nsIContextMenuListener::CONTEXT_DOCUMENT) != 0) {
    // if there aren't any flags or we're in the background of a page,
    // show the document menu. This prevents us from failing to find a case
    // and not showing the context menu.
    menuPrototype = mPageMenu;
    [mBackItem    setEnabled: [[mBrowserView browserView] canGoBack]];
    [mForwardItem setEnabled: [[mBrowserView browserView] canGoForward]];
    [mCopyItem    setEnabled:hasSelection];
  }

  // we have to clone the menu and return that, so that we don't change
  // our only copy of the menu
  NSMenu* result = [[menuPrototype copy] autorelease];

  if (isUnsafeLink) {
    NSMenuItem* frameItem;
    while ((frameItem = [result itemWithTag:kLinkOpeningItemsTag]) != nil)
      [result removeItem:frameItem];
  }

  // validate View Page/Frame Source
  BrowserWrapper* browser = [self browserWrapper];
  if ([browser isInternalURI] || ![[browser browserView] isTextBasedContent]) {
    [[result itemWithTarget:self andAction:@selector(viewPageSource:)] setEnabled:NO];
    [[result itemWithTarget:self andAction:@selector(viewSource:)] setEnabled:NO];
  }

  // validate 'Bookmark This Page'
  [[result itemWithTarget:self andAction:@selector(addBookmark:)] setEnabled:[[self browserWrapper] isBookmarkable]];

  BOOL showMisspelledWordItems = NO;
  if (isTextField)
    showMisspelledWordItems = [self prepareSpellingSuggestionMenu:result tag:kSpellingRelatedItemsTag];

  if (!showMisspelledWordItems) {
    // word spelled correctly or not applicable, remove all traces of spelling items
    NSMenuItem* selectionItem;
    while ((selectionItem = [result itemWithTag:kSpellingRelatedItemsTag]) != nil)
      [result removeItem:selectionItem];
  }

  // Add the persistent spelling items
  if (isTextField)
    [self addSpellingControlsToMenu:result];

  // if there's no selection or no search bar in the toolbar, hide the search item.
  // We need a search item to know what the user's preferred search is.
  if (!hasSelection) {
    NSMenuItem* selectionItem;
    while ((selectionItem = [result itemWithTag:kSelectionRelatedItemsTag]) != nil)
      [result removeItem:selectionItem];
  }

  if (showFrameItems) {
    NSMenuItem* frameItem;
    while ((frameItem = [result itemWithTag:kFrameInapplicableItemsTag]) != nil)
      [result removeItem:frameItem];
  }
  else {
    NSMenuItem* frameItem;
    while ((frameItem = [result itemWithTag:kFrameRelatedItemsTag]) != nil)
      [result removeItem:frameItem];
  }

  // Add items to add/open each e-mail address in a mailto: link and
  // change "address" to the plural form if necessary
  if (numEmailAddresses > 0) {
    for (signed i = (signed) numEmailAddresses - 1; i >= 0 ; --i) {
      NSMenuItem* item = [self prepareAddToAddressBookMenuItem:[emailAddresses objectAtIndex:i]];
      if (item)
        [result insertItem:item atIndex:1];
    }
    if (numEmailAddresses > 1)
      [[result itemWithTarget:self andAction:@selector(copyAddressToClipboard:)] setTitle:NSLocalizedString(@"Copy Addresses", @"")];
  }

  // Create command and command-shift alternates for applicable menu items
  if (needsAlternates) {
    NSArray* menuArray = [result itemArray];
    BOOL inNewTab = [[PreferenceManager sharedInstance] getBooleanPref:"browser.tabs.opentabfor.middleclick" withSuccess:NULL];

    for (int i = [menuArray count] - 1; i >= 0; i--) {
      NSMenuItem* menuItem = [menuArray objectAtIndex:i];

      // Only create alternates for the items that need them
      if ([menuItem tag] == kItemsNeedingOpenBehaviorAlternatesTag) {
        NSString* altMenuItemTitle;
        if (inNewTab)
          altMenuItemTitle = [NSString stringWithFormat:NSLocalizedString(@"Action in New Tab", nil), [menuItem title]];
        else
          altMenuItemTitle = [NSString stringWithFormat:NSLocalizedString(@"Action in New Window", nil), [menuItem title]];

        SEL action = [menuItem action];
        id target = [menuItem target];

        // Create the alternates and insert them into the two places after the menu item
        NSMenuItem* cmdMenuItem = [NSMenuItem alternateMenuItemWithTitle:altMenuItemTitle
                                                                  action:action
                                                                  target:target
                                                               modifiers:NSCommandKeyMask];
        [result insertItem:cmdMenuItem atIndex:(i + 1)];
        NSMenuItem* cmdShiftMenuItem = [NSMenuItem alternateMenuItemWithTitle:altMenuItemTitle
                                                                       action:action
                                                                       target:target
                                                                    modifiers:(NSCommandKeyMask | NSShiftKeyMask)];
        [result insertItem:cmdShiftMenuItem atIndex:(i + 2)];
      }
    }
  }

  // Disable context menu items if the window is currently showing a sheet.
  if ([[self window] attachedSheet]) {
    NSArray* menuArray = [result itemArray];
    for (unsigned i = 0; i < [menuArray count]; i++) {
      [[menuArray objectAtIndex:i] setEnabled:NO];
    }
  }

  return result;
}

- (void)insertForceAlternatesIntoMenu:(NSMenu *)inMenu
{
  NSArray* menuArray = [inMenu itemArray];

  for (unsigned int i = 0; i < [menuArray count]; i++) {
    NSMenuItem* menuItem = [menuArray objectAtIndex:i];

    if ([menuItem tag] == kItemsNeedingForceAlternateTag) {
      // @"Force Format" = @"Force %@", so this gives the menu's title prepended with "Force"
      NSString* title = [NSString stringWithFormat:NSLocalizedString(@"Force Format", nil), [menuItem title]];

      NSMenuItem* forceReloadItem = [NSMenuItem alternateMenuItemWithTitle:title
                                                                    action:[menuItem action]
                                                                    target:[menuItem target]
                                                                 modifiers:([menuItem keyEquivalentModifierMask] | NSShiftKeyMask)];

      [inMenu insertItem:forceReloadItem atIndex:(i + 1)];
    }
  }
}

//
// -getMisspelledRange:inlineSpellChecker:
//
// Upon return, |outRange| contains the range of the currently misspelled word and 
// |outInlineChecker| contains the inline spell checker to allow for further action.
// This method AddRef's both out parameters.
//
- (void)getMisspelledWordRange:(nsIDOMRange**)outRange inlineSpellChecker:(nsIInlineSpellChecker**)outInlineChecker
{
  #define ENSURE_TRUE(x) if (!x) return;

  if (!(outRange && outInlineChecker))
    return;
  *outRange = nsnull;
  *outInlineChecker = nsnull;

  nsCOMPtr<nsIEditor> editor;
  [self currentEditor:getter_AddRefs(editor)];
  ENSURE_TRUE(editor);

  editor->GetInlineSpellChecker(PR_TRUE, outInlineChecker);
  ENSURE_TRUE(*outInlineChecker);

  PRBool checkingIsEnabled = NO;
  (*outInlineChecker)->GetEnableRealTimeSpell(&checkingIsEnabled);
  ENSURE_TRUE(checkingIsEnabled);

  nsCOMPtr<nsISelection> selection;
  editor->GetSelection(getter_AddRefs(selection));
  ENSURE_TRUE(selection);

  nsCOMPtr<nsIDOMNode> selectionEndNode;
  PRInt32 selectionEndOffset = 0;
  selection->GetFocusNode(getter_AddRefs(selectionEndNode));
  selection->GetFocusOffset(&selectionEndOffset);

  (*outInlineChecker)->GetMispelledWord(selectionEndNode, (long)selectionEndOffset, outRange);

  #undef ENSURE_TRUE
}

//
// -prepareSpellingSuggestionMenu:tag:
//
// Adds suggestions to the top of |inMenu| for the currently misspelled word
// under the insertion point. Starts inserting before the first item in the menu
// with |inTag| and will insert up to |kMaxSuggestions|.
// Returns a BOOL indicating whether suggestions are shown.
//
- (BOOL)prepareSpellingSuggestionMenu:(NSMenu*)inMenu tag:(int)inTag
{
  nsCOMPtr<nsIDOMRange> misspelledRange;
  nsCOMPtr<nsIInlineSpellChecker> inlineChecker;
  [self getMisspelledWordRange:getter_AddRefs(misspelledRange) inlineSpellChecker:getter_AddRefs(inlineChecker)];
  if (!(misspelledRange && inlineChecker))
    return NO;

  nsCOMPtr<nsIEditorSpellCheck> spellCheck;
  inlineChecker->GetSpellChecker(getter_AddRefs(spellCheck));
  if (!spellCheck)
    return NO;

  // ask the spellchecker to check the misspelled word, which seems redundant but is also
  // used to generate the suggestions list. 
  nsString currentWord;
  misspelledRange->ToString(currentWord);
  PRBool isIncorrect = NO;
  spellCheck->CheckCurrentWord(currentWord.get(), &isIncorrect);
  if (!isIncorrect)
    return NO;

  // there's still a misspelled word, loop over the suggestions. The spellchecker will return
  // an empty string when it's done (NOT nil), so keep going until we get that or our max.
  const unsigned long insertBase = [inMenu indexOfItemWithTag:inTag];
  const unsigned long kMaxSuggestions = 7;
  unsigned long numSuggestions = 0;
  do {
    PRUnichar* suggestion = nil;
    spellCheck->GetSuggestedWord(&suggestion);
    if (!nsCRT::strlen(suggestion))
      break;

    NSString* suggStr = [NSString stringWithPRUnichars:suggestion];
    NSMenuItem* item = [inMenu insertItemWithTitle:suggStr action:@selector(replaceWord:) keyEquivalent:@"" atIndex:numSuggestions + insertBase];
    [item setTarget:self];

    ++numSuggestions;
    nsCRT::free(suggestion);
  } while (numSuggestions < kMaxSuggestions);

  if (numSuggestions == 0) {
    NSMenuItem* item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"No Guesses Found", nil) action:NULL keyEquivalent:@""] autorelease];
    [item setEnabled:NO];
    [inMenu insertItem:item atIndex:insertBase];
  }

  // |inTag| has moved to a new location; fetch the current index
  int dictionaryItemsInsertBase = [inMenu indexOfItemWithTag:inTag];

  [inMenu insertItem:[NSMenuItem separatorItem] atIndex:dictionaryItemsInsertBase];

  [inMenu insertItemWithTitle:NSLocalizedString(@"IgnoreSpelling", nil) 
                       action:@selector(ignoreWord:) 
                keyEquivalent:@"" 
                      atIndex:(dictionaryItemsInsertBase + 1)];

  [inMenu insertItemWithTitle:NSLocalizedString(@"LearnSpelling", nil) 
                       action:@selector(learnWord:) 
                keyEquivalent:@"" 
                      atIndex:(dictionaryItemsInsertBase + 2)];

  return YES;
}

- (void)addSpellingControlsToMenu:(NSMenu*)inMenu
{
  nsCOMPtr<nsIEditor> editor;
  [self currentEditor:getter_AddRefs(editor)];
  if (!editor)
    return;
  nsCOMPtr<nsIInlineSpellChecker> inlineChecker;
  editor->GetInlineSpellChecker(PR_TRUE, getter_AddRefs(inlineChecker));
  if (!inlineChecker)
    return;

  PRBool checkingIsEnabled = NO;
  inlineChecker->GetEnableRealTimeSpell(&checkingIsEnabled);

  [inMenu addItem:[NSMenuItem separatorItem]];
  NSString* enableTitle;
  if ([NSWorkspace isLeopardOrHigher])
    enableTitle = NSLocalizedString(@"CheckSpellingWhileTyping", nil);
  else
    enableTitle = NSLocalizedString(@"CheckSpellingAsYouType", nil);
  NSMenuItem* enableItem = [inMenu addItemWithTitle:enableTitle
                                             action:@selector(toggleSpellingEnabled:)
                                      keyEquivalent:@""];
  [enableItem setTarget:self];
  if (checkingIsEnabled) {
    [enableItem setState:NSOnState];

    NSMenuItem* languageMenu = [self spellingLanguageMenu];
    if (languageMenu)
      [inMenu addItem:languageMenu];
  }
}

- (NSMenuItem*)spellingLanguageMenu
{
  // We need the 10.5+ -[NSSpellChecker availableLanguages] to build this menu.
  if (![NSWorkspace isLeopardOrHigher])
    return nil;
  NSMenu* submenu = [[[NSMenu alloc] init] autorelease];

  NSLocale* currentLocale = [NSLocale currentLocale];

  NSMenuItem* multilingualEntry = nil;
  NSSpellChecker* spellChecker = [NSSpellChecker sharedSpellChecker];
  NSString* currentSpellingLanguage = [spellChecker language];
  NSEnumerator* languageEnumerator = [[spellChecker availableLanguages] objectEnumerator];
  NSString* languageCode;
  while ((languageCode = [languageEnumerator nextObject])) {
    NSMenuItem* languageItem = [[[NSMenuItem alloc] init] autorelease];
    [languageItem setRepresentedObject:languageCode];
    [languageItem setTarget:self];
    [languageItem setAction:@selector(setSpellingLanguage:)];
    if ([languageCode isEqualToString:currentSpellingLanguage])
      [languageItem setState:NSOnState];
    NSString *languageName = [currentLocale displayNameForKey:NSLocaleIdentifier
                                                        value:languageCode];
    if (!languageName)
      languageName = languageCode;
    [languageItem setTitle:languageName];
    // Separate out the magic "Multilingual" entry.
    if ([languageCode isEqualToString:@"Multilingual"])
      multilingualEntry = languageItem;
    else
      [submenu addItem:languageItem];
  }
  // Add Multilingual at the end
  if (multilingualEntry) {
    [submenu addItem:[NSMenuItem separatorItem]];
    [submenu addItem:multilingualEntry];
  }

  NSMenuItem* languageMenu =  [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"SpellingLanguage", nil)
                                                          action:NULL
                                                   keyEquivalent:@""] autorelease];
  [languageMenu setSubmenu:submenu];
  return languageMenu;
}

// Context menu methods

//
// -replaceWord:
//
// Context menu action for the suggestions in a text field. Replaces the
// current word in the editor with string that's the title of the chosen menu
// item.
//
- (IBAction)replaceWord:(id)inSender
{
  nsCOMPtr<nsIDOMRange> misspelledRange;
  nsCOMPtr<nsIInlineSpellChecker> inlineChecker;
  [self getMisspelledWordRange:getter_AddRefs(misspelledRange) inlineSpellChecker:getter_AddRefs(inlineChecker)];
  if (!(misspelledRange && inlineChecker))
    return;

  // a node and offset are used to replace the word.
  // it's unfortunate that we have to re-fetch this stuff since we just did it
  // when buliding the context menu, but we don't really have any convenient place
  // to stash it where we can guarantee it will get cleaned up when the menu goes
  // away.
  nsCOMPtr<nsIDOMNode> endNode;
  PRInt32 endOffset = 0;
  misspelledRange->GetEndContainer(getter_AddRefs(endNode));
  misspelledRange->GetEndOffset(&endOffset);
  nsString newWord;
  [[inSender title] assignTo_nsAString:newWord];
  inlineChecker->ReplaceWord(endNode, endOffset, newWord);
}

//
// -ignoreWord:
//
// Context menu action for ignoring a misspelled word in a text field.
// Ignores during the active editing session only.
//
- (IBAction)ignoreWord:(id)inSender
{
  nsCOMPtr<nsIDOMRange> misspelledRange;
  nsCOMPtr<nsIInlineSpellChecker> inlineChecker;
  [self getMisspelledWordRange:getter_AddRefs(misspelledRange) inlineSpellChecker:getter_AddRefs(inlineChecker)];
  if (!(misspelledRange && inlineChecker))
    return;

  nsString misspelledWord;
  misspelledRange->ToString(misspelledWord);
  inlineChecker->IgnoreWord(misspelledWord);
}

//
// -learnWord:
//
// Context menu action for adding a word to the spell checking dictionary.
//
// nsIInlineSpellChecker's AddWordToDictionary does not insert the learned
// word into the shared system dictionary and instead remembers it using its
// own personal dictionary. As an alternative, we use a currently undocumented
// NSSpellChecker method |learnWord:| to achieve this functionality.
//
- (IBAction)learnWord:(id)inSender
{
  nsCOMPtr<nsIDOMRange> misspelledRange;
  nsCOMPtr<nsIInlineSpellChecker> inlineChecker;
  [self getMisspelledWordRange:getter_AddRefs(misspelledRange) inlineSpellChecker:getter_AddRefs(inlineChecker)];
  if (!(misspelledRange && inlineChecker))
    return;

  nsString misspelledWord;
  misspelledRange->ToString(misspelledWord);
  [[NSSpellChecker sharedSpellChecker] learnWord:[NSString stringWith_nsAString:misspelledWord]];
  // check the range again to remove the misspelled word indication
  inlineChecker->SpellCheckRange(misspelledRange);
}

//
// -setSpellingLanguage:
//
// Context menu action for toggling spellcheck of the current field.
//
- (IBAction)toggleSpellingEnabled:(id)inSender {
  PRBool enableSpelling = ([inSender state] == NSOffState) ? PR_TRUE : PR_FALSE;

  nsCOMPtr<nsIEditor> editor;
  [self currentEditor:getter_AddRefs(editor)];
  if (editor)
    editor->SetSpellcheckUserOverride(enableSpelling);
}

//
// -setSpellingLanguage:
//
// Context menu action for changing the current spell check language.
//
- (IBAction)setSpellingLanguage:(id)inSender {
  [[NSSpellChecker sharedSpellChecker] setLanguage:[inSender representedObject]];

  // re-sync the spell checker to pick up the new language
  nsCOMPtr<nsIEditor> editor;
  [self currentEditor:getter_AddRefs(editor)];
  if (editor)
    editor->SyncRealTimeSpell();
}

- (IBAction)openLinkInNewWindow:(id)aSender
{
  [self openLinkInNewWindowOrTab:YES];
}

- (IBAction)openLinkInNewTab:(id)aSender
{
  [self openLinkInNewWindowOrTab:NO];
}

-(void)openLinkInNewWindowOrTab:(BOOL)aUseWindow
{
  NSString* hrefStr = [self contextMenuNodeHrefText];

  if ([hrefStr length] == 0)
    return;

  BOOL loadInBackground = [BrowserWindowController shouldLoadInBackgroundForDestination:(aUseWindow ? eDestinationNewWindow
                                                                                                    : eDestinationNewTab)
                                                                                 sender:nil];

  NSString* referrer = [[mBrowserView browserView] focusedURLString];

  if (aUseWindow)
    [self openNewWindowWithURL: hrefStr referrer:referrer loadInBackground: loadInBackground allowPopups:NO];
  else
    [self openNewTabWithURL: hrefStr referrer:referrer loadInBackground: loadInBackground allowPopups:NO setJumpback:YES];
}

- (IBAction)savePageAs:(id)aSender
{
  NSView* accessoryView = [[NSApp delegate] savePanelView];
  [self saveDocument:NO filterView:accessoryView];
}

- (IBAction)saveFrameAs:(id)aSender
{
  NSView* accessoryView = [[NSApp delegate] savePanelView];
  [self saveDocument:YES filterView:accessoryView];
}

- (IBAction)saveLinkAs:(id)aSender
{
  NSString* hrefStr = [self contextMenuNodeHrefText];
  if ([hrefStr length] == 0)
    return;

  // The user wants to save this link.
  nsAutoString text;
  GeckoUtils::GatherTextUnder(mDataOwner->mContextMenuNode, text);

  [self saveURL:nil url:hrefStr suggestedFilename:[NSString stringWith_nsAString:text]];
}

- (IBAction)saveImageAs:(id)aSender
{
  nsCOMPtr<nsIDOMHTMLImageElement> imgElement(do_QueryInterface(mDataOwner->mContextMenuNode));
  if (imgElement) {
      nsAutoString text;
      imgElement->GetAttribute(NS_LITERAL_STRING("src"), text);
      nsAutoString url;
      imgElement->GetSrc(url);

      NSString* hrefStr = [NSString stringWith_nsAString: url];

      [self saveURL:nil url:hrefStr suggestedFilename: [NSString stringWith_nsAString: text]];
  }
}

- (IBAction)copyImage:(id)sender
{
  nsCOMPtr<nsIWebBrowser> webBrowser = dont_AddRef([[[self browserWrapper] browserView] webBrowser]);
  nsCOMPtr<nsICommandManager> commandMgr(do_GetInterface(webBrowser));
  if (!commandMgr)
    return;

  (void)commandMgr->DoCommand("cmd_copyImageContents", nsnull, nsnull);
}

- (IBAction)copyImageLocation:(id)sender
{
  nsCOMPtr<nsIWebBrowser> webBrowser = dont_AddRef([[[self browserWrapper] browserView] webBrowser]);
  nsCOMPtr<nsIClipboardCommands> clipboard(do_GetInterface(webBrowser));
  if (clipboard)
    clipboard->CopyImageLocation();
}

- (IBAction)copyLinkLocation:(id)aSender
{
  nsCOMPtr<nsIWebBrowser> webBrowser = dont_AddRef([[[self browserWrapper] browserView] webBrowser]);
  nsCOMPtr<nsIClipboardCommands> clipboard(do_GetInterface(webBrowser));
  if (clipboard)
    clipboard->CopyLinkLocation();
}

- (IBAction)viewOnlyThisImage:(id)aSender
{
  nsCOMPtr<nsIDOMHTMLImageElement> imgElement(do_QueryInterface(mDataOwner->mContextMenuNode));
  if (imgElement) {
    nsAutoString url;
    imgElement->GetSrc(url);

    NSString* urlStr = [NSString stringWith_nsAString: url];
    NSString* referrer = [[mBrowserView browserView] focusedURLString];

    unsigned int modifiers = [aSender keyEquivalentModifierMask];

    if (modifiers & NSCommandKeyMask) {
      BOOL loadInTab = [[PreferenceManager sharedInstance] getBooleanPref:"browser.tabs.opentabfor.middleclick" withSuccess:NULL];
      BOOL loadInBG = [BrowserWindowController shouldLoadInBackgroundForDestination:(loadInTab ? eDestinationNewTab
                                                                                               : eDestinationNewWindow)
                                                                             sender:nil];
      if (loadInTab)
        [self openNewTabWithURL:urlStr referrer:referrer loadInBackground:loadInBG allowPopups:NO setJumpback:NO];
      else
        [self openNewWindowWithURL:urlStr referrer:referrer loadInBackground:loadInBG allowPopups:NO];
    }
    else
      [self loadURL:urlStr referrer:referrer focusContent:YES allowPopups:NO];
  }  
}

- (IBAction)showPageInfo:(id)sender
{
  PageInfoWindowController* pageInfoController = [PageInfoWindowController sharedPageInfoWindowController];

  [pageInfoController updateFromBrowserView:[[self browserWrapper] browserView]];
  [[pageInfoController window] makeKeyAndOrderFront:nil];
}

- (IBAction)showBookmarksInfo:(id)sender
{
    BookmarkViewController* bookmarksController = [self bookmarkViewControllerForCurrentTab];
    [bookmarksController ensureBookmarks];
    [bookmarksController showBookmarkInfo:sender];
}

- (IBAction)showSiteCertificate:(id)sender
{
  CertificateItem* certItem = [[self activeBrowserView] siteCertificate];
  if (certItem)
  {
    [ViewCertificateDialogController showCertificateWindowWithCertificateItem:certItem
                                                         certTypeForTrustSettings:nsIX509Cert::SERVER_CERT];
  }
}

- (BookmarkToolbar*) bookmarkToolbar
{
  return mPersonalToolbar;
}

- (BOOL)windowClosesQuietly
{
  return mWindowClosesQuietly;
}

- (void)setWindowClosesQuietly:(BOOL)inClosesQuietly
{
  mWindowClosesQuietly = inClosesQuietly;
}

// updateLock:
//
// updates the url bar display of security state appropriately.
- (void)updateLock:(unsigned int)inSecurityState
{
  unsigned char securityState = inSecurityState & 0x000000FF;
  [mURLBar setSecureState:securityState];
}

+ (NSImage*) insecureIcon
{
  static NSImage* sInsecureIcon = nil;
  if (!sInsecureIcon)
    sInsecureIcon = [[NSImage imageNamed:@"globe_ico"] retain];
  return sInsecureIcon;
}

+ (NSImage*) secureIcon
{
  static NSImage* sSecureIcon = nil;
  if (!sSecureIcon)
    sSecureIcon = [[NSImage imageNamed:@"security_lock"] retain];
  return sSecureIcon;
}

+ (NSImage*) brokenIcon
{
  static NSImage* sBrokenIcon = nil;
  if (!sBrokenIcon)
    sBrokenIcon = [[NSImage imageNamed:@"security_broken"] retain];
  return sBrokenIcon;
}

//
// -lastKnownPreferredSearchEngine
//
// Caching the existing preferred search engine gives us a reference to the previous value,
// should it be modified, and allows us to determine if a search field's selection was previously
// set to the preferred engine and preserved accordingly.
//
- (NSString*)lastKnownPreferredSearchEngine
{
  return mLastKnownPreferredSearchEngine; 
}

- (void)setLastKnownPreferredSearchEngine:(NSString*)inPreferredEngine
{
  [mLastKnownPreferredSearchEngine autorelease];
  mLastKnownPreferredSearchEngine = [inPreferredEngine retain];
}

- (void)populateEnginesIntoAllSearchFields
{
  [self populateEnginesIntoSearchField:mSearchBar];
  [self populateEnginesIntoSearchField:mSearchSheetTextField];
}

- (void)populateEnginesIntoSearchField:(WebSearchField*)searchField
{
  if (!searchField)
    return;

  SearchEngineManager* searchEngineManager = [SearchEngineManager sharedSearchEngineManager];

  // Grab onto the currently selected engine so we can restore it later.
  NSString* selectedEngine = [[[searchField currentSearchEngine] retain] autorelease];

  [searchField setSearchEngines:[searchEngineManager installedSearchEngines]];

  BOOL selectedEngineIsStillAvailable = [[searchEngineManager installedSearchEngineNames] containsObject:selectedEngine];

  NSString* lastKnownPreferredEngine = [self lastKnownPreferredSearchEngine];
  BOOL preferredEngineWasSelected = lastKnownPreferredEngine && [selectedEngine isEqualToString:lastKnownPreferredEngine];

  // Restore the selection if it was set to something other than the preferred engine.
  if (selectedEngineIsStillAvailable && !preferredEngineWasSelected)
    [searchField setCurrentSearchEngine:selectedEngine];
  else
    [searchField setCurrentSearchEngine:[searchEngineManager preferredSearchEngine]];
}

//
// Called whenever an engine has been added, removed, renamed, etc.
// in the collection of built-in search engines.
//
- (void)installedSearchEnginesDidChange:(NSNotification*)notification
{ 
  [self populateEnginesIntoAllSearchFields];
  [self showSearchPluginDetected:([[[self browserWrapper] detectedSearchPlugins] count] > 0)];
  [self setLastKnownPreferredSearchEngine:[[SearchEngineManager sharedSearchEngineManager] preferredSearchEngine]];
}

- (void)showSearchPluginDetected:(BOOL)pluginsAreDetected
{
  if (pluginsAreDetected) {
    NSArray* detectedPlugins = [[self browserWrapper] detectedSearchPlugins];
    [mSearchBar setDetectedSearchPlugins:detectedPlugins];
    [mSearchSheetTextField setDetectedSearchPlugins:detectedPlugins];
  }
  else {
    [mSearchBar setDetectedSearchPlugins:nil];
    [mSearchSheetTextField setDetectedSearchPlugins:nil];
  }
}

- (BOOL)webSearchField:(WebSearchField*)searchField shouldListDetectedSearchPlugin:(NSDictionary *)searchPluginInfoDict
{
  // Exclude search plugins which are already installed.
  NSString *searchPluginURL = [[searchPluginInfoDict objectForKey:kWebSearchPluginURLKey] absoluteString];
  return (![[SearchEngineManager sharedSearchEngineManager] hasSearchEngineFromPluginURL:searchPluginURL]);
}

- (IBAction)installSearchPlugin:(id)sender
{
  id searchPlugin = [sender representedObject];
  BOOL addedOK = [[SearchEngineManager sharedSearchEngineManager] addSearchEngineFromPlugin:searchPlugin];

  if (addedOK) {
    // Start using the installed engine.
    // The installed name sometimes differs from the name listed on the web page's autodiscovery link.
    // Because of this, select the last engine.
    NSString* installedPluginName = [[[SearchEngineManager sharedSearchEngineManager] installedSearchEngineNames] lastObject];
    [mSearchBar setCurrentSearchEngine:installedPluginName];
    [mSearchSheetTextField setCurrentSearchEngine:installedPluginName];
  }
  else {
    NSString* searchPluginName = [searchPlugin valueForKey:kWebSearchPluginNameKey];
    NSAlert* alert = [[[NSAlert alloc] init] autorelease];
    [alert addButtonWithTitle:NSLocalizedString(@"OKButtonText", nil)];
    [alert setMessageText:NSLocalizedString(@"SearchPluginInstallationErrorTitle", nil)];
    [alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"SearchPluginInstallationErrorMessage", nil), searchPluginName]];
    [alert setAlertStyle:NSWarningAlertStyle];
    if ([[self window] attachedSheet]) {
      [alert runModal];
    }
    else {
      [alert beginSheetModalForWindow:[self window] 
                        modalDelegate:self 
                       didEndSelector:NULL
                          contextInfo:NULL];
    }
  }
}

- (IBAction)manageSearchEngines:(id)sender
{
  [[SearchEngineEditor sharedSearchEngineEditor] showSearchEngineEditor:self];
}

- (IBAction)findSearchEngines:(id)sender
{
  NSString* findEnginesPage = NSLocalizedStringFromTable(@"FindEnginesPage", @"WebsiteDefaults", nil);
  if (![findEnginesPage isEqualToString:@"FindEnginesPage"])
    [[NSApp delegate] showURL:findEnginesPage];
}

- (void) focusChangedFrom:(NSResponder*) oldResponder to:(NSResponder*) newResponder
{
  BOOL oldResponderIsGecko = [self isResponderGeckoView:oldResponder];
  BOOL newResponderIsGecko = [self isResponderGeckoView:newResponder];

  if (oldResponderIsGecko != newResponderIsGecko && [[self window] isKeyWindow])
    [mBrowserView setBrowserActive:newResponderIsGecko];
}


- (PageProxyIcon *)proxyIconView
{
  return mProxyIcon;
}

// XXX this is only used to show bm after an import
- (BookmarkViewController *)bookmarkViewController
{
  return [self bookmarkViewControllerForCurrentTab];
}

- (CHBrowserView*)activeBrowserView
{
  return [mBrowserView browserView];
}

- (id)windowWillReturnFieldEditor:(NSWindow *)aWindow toObject:(id)anObject
{
  if ([anObject isEqual:mURLBar]) {
    if (!mURLFieldEditor) {
      mURLFieldEditor = [[AutoCompleteTextFieldEditor alloc] initWithFrame:[anObject bounds]
                                                               defaultFont:[mURLBar font]];
      [mURLFieldEditor setFieldEditor:YES];
      [mURLFieldEditor setAllowsUndo:YES];
    }
    return mURLFieldEditor;
  }
  return nil;
}

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)sender
{
  if ([[self window] firstResponder] == mURLFieldEditor)
    return [mURLFieldEditor undoManager];
  
  return [[BookmarkManager sharedBookmarkManager] undoManager];
}

- (IBAction)reloadWithNewCharset:(NSString*)charset
{
  [mBrowserView reloadWithNewCharset:charset];
}

- (NSString*)currentCharset
{
  return [mBrowserView currentCharset];
}

//
// -loadBookmarkBarIndex:
//
// Load the nth loadable item (bookmarks or tab groups) in the bookmark bar given by |inIndex| using 
// the given behavior.  Uses the top-level |-loadBookmark:...| in order to get the right behavior with 
// tab groups.
//
- (BOOL)loadBookmarkBarIndex:(unsigned short)inIndex openBehavior:(EBookmarkOpenBehavior)inBehavior
{
  // We don't want to trigger bookmark bar loads if the bookmark bar isn't visible
  if (![mPersonalToolbar isVisible])
    return NO;

  NSArray* bookmarkBarChildren   = [[[BookmarkManager sharedBookmarkManager] toolbarFolder] childArray];
  unsigned int bookmarkBarCount = [bookmarkBarChildren count];
  unsigned int i;
  int loadableItemIndex = -1;
  BookmarkItem* item = nil;

  // We cycle through all the toolbar items.  When we've skipped enough loadable items
  // (i.e., loadableItemIndex == inIndex), we've gotten there and |item| is the bookmark we want to load.
  for (i = 0; i < bookmarkBarCount; ++i) {
    item = [bookmarkBarChildren objectAtIndex:i];
    // Only real (non-seperator) bookmarks and tab groups count
    if (([item isKindOfClass:[Bookmark class]] && ![(Bookmark *)item isSeparator]) || 
        ([item isKindOfClass:[BookmarkFolder class]] && [(BookmarkFolder *)item isGroup]))
    {
      if (++loadableItemIndex == inIndex)
        break;
    }
  }

  if (loadableItemIndex == inIndex) {
    [[NSApp delegate] loadBookmark:item withBWC:self openBehavior:inBehavior reverseBgToggle:NO];
    [mPersonalToolbar momentarilyHighlightButtonAtIndex:i];
    return YES;
  }
  // We ran out of toolbar items before finding the nth loadable one
  return NO;
}

//
// -revealBookmark:
//
// Reveals a bookmark in the manager
//
- (void)revealBookmark:(BookmarkItem*)anItem
{
  BookmarkViewController* bvc = [self bookmarkViewControllerForCurrentTab];

  if (![self bookmarkManagerIsVisible]) {
    [bvc setItemToRevealOnLoad:anItem];
    [self manageBookmarks:nil];
  }
  else {
    [bvc revealItem:anItem scrollIntoView:YES selecting:YES byExtendingSelection:NO];
  }
}

//
// - handleCommandReturn:
//
// handle command-return in location or search field, opening a new tab or window as appropriate
//
- (BOOL)handleCommandReturn:(BOOL)aShiftIsDown
{
  // determine whether to load in tab or window
  BOOL loadInTab = [[PreferenceManager sharedInstance] getBooleanPref:"browser.tabs.opentabfor.middleclick" withSuccess:NULL];

  // determine whether to load in background
  BOOL loadInBG = NO;
  if (loadInTab)
    loadInBG = [[PreferenceManager sharedInstance] getBooleanPref:"browser.tabs.loadInBackground" withSuccess:NULL];
  if (aShiftIsDown)  // if shift is being held down, do the opposite of the pref
    loadInBG = !loadInBG;

  EOpenDestination destination = loadInTab ? eDestinationNewTab : eDestinationNewWindow;
  
  // see if command-return came in the url bar
  BOOL handled = NO;
  if ([mURLBar fieldEditor] && [[self window] firstResponder] == [mURLBar fieldEditor]) {
    handled = YES;
    [self goToLocationFromToolbarURLField:mURLBar inView:destination inBackground:loadInBG];
    // kill any autocomplete that was in progress
    [mURLBar revertText];
    // set the text in the URL bar back to the current URL
    [self updateLocationFields:[mBrowserView currentURI] ignoreTyping:YES];
    
  // see if command-return came in the search field
  } else if ([[[self window] firstResponder] isKindOfClass:[NSView class]] &&
           [(NSView*)[[self window] firstResponder] isDescendantOf:mSearchBar]) {
    handled = YES;
    [self performSearch:mSearchBar inView:destination inBackground:loadInBG]; 
  }
  return handled;
}

//
// -fillForm:
//
// Fills the form on the current web page using wallet
//
- (IBAction)fillForm:(id)sender
{
  CHBrowserView* browser = [[self browserWrapper] browserView];
  nsCOMPtr<nsIDOMWindow> domWindow = [browser contentWindow];
  nsCOMPtr<nsIDOMWindowInternal> internalDomWindow (do_QueryInterface(domWindow));
  
  Wallet_Prefill(internalDomWindow);
}

- (IBAction)toggleTabThumbnailView:(id)sender
{
  [mContentView toggleTabThumbnailGridView];
}

@end

#pragma mark -

@implementation ThrobberHandler

-(id)initWithToolbarItem:(NSToolbarItem*)inButton images:(NSArray*)inImages
{
  if ( (self = [super init]) ) {
    mImages = [inImages retain];
    mTimer = [[NSTimer scheduledTimerWithTimeInterval: 0.2
                        target: self selector: @selector(pulseThrobber:)
                        userInfo: inButton repeats: YES] retain];
    mFrame = 0;
    [self startThrobber];
  }
  return self;
}

-(void)dealloc
{
  [self stopThrobber];
  [mImages release];
  [super dealloc];
}


// Called by an NSTimer.

- (void)pulseThrobber:(id)aSender
{
  // advance to next frame.
  if (++mFrame >= [mImages count])
      mFrame = 0;
  NSToolbarItem* toolbarItem = (NSToolbarItem*) [aSender userInfo];
  [toolbarItem setImage: [mImages objectAtIndex: mFrame]];
}

#define QUICKTIME_THROBBER 0

#if QUICKTIME_THROBBER

#include <QuickTime/QuickTime.h>

static Boolean movieControllerFilter(MovieController mc, short action, void *params, long refCon)
{
    if (action == mcActionMovieClick || action == mcActionMouseDown) {
        EventRecord* event = (EventRecord*) params;
        event->what = nullEvent;
        return true;
    }
    return false;
}
#endif

- (void)startThrobber
{
#if QUICKTIME_THROBBER
    // Use Quicktime to draw the frames from a single Animated GIF. This works fine for the animation, but
    // when the frames stop, the poster frame disappears.
    NSToolbarItem* throbberItem = [self throbberItem];
    if (throbberItem != nil && [throbberItem view] == nil) {
        NSSize minSize = [throbberItem minSize];
        NSLog(@"Origin minSize = %f X %f", minSize.width, minSize.height);
        NSSize maxSize = [throbberItem maxSize];
        NSLog(@"Origin maxSize = %f X %f", maxSize.width, maxSize.height);
        
        NSURL* throbberURL = [NSURL fileURLWithPath: [[NSBundle mainBundle] pathForResource:@"throbber" ofType:@"gif"]];
        NSLog(@"throbberURL = %@", throbberURL);
        NSMovie* throbberMovie = [[[NSMovie alloc] initWithURL: throbberURL byReference: YES] autorelease];
        NSLog(@"throbberMovie = %@", throbberMovie);
        
        if ([throbberMovie QTMovie] != nil) {
            NSMovieView* throbberView = [[[NSMovieView alloc] init] autorelease];
            [throbberView setMovie: throbberMovie];
            [throbberView showController: NO adjustingSize: NO];
            [throbberView setLoopMode: NSQTMovieLoopingPlayback];
            [throbberItem setView: throbberView];
            NSSize size = NSMakeSize(32, 32);
            [throbberItem setMinSize: size];
            [throbberItem setMaxSize: size];
            [throbberView gotoPosterFrame: self];
            [throbberView start: self];
    
            // experiment, veto mouse clicks in the movie controller by using an action filter.
            MCSetActionFilterWithRefCon((MovieController) [throbberView movieController],
                                        NewMCActionFilterWithRefConUPP(movieControllerFilter),
                                        0);
        }
    }
#endif
}

- (void)stopThrobber
{
#if QUICKTIME_THROBBER
    // Stop the quicktime animation.
    NSToolbarItem* throbberItem = [self throbberItem];
    if (throbberItem != nil) {
        NSMovieView* throbberView = [throbberItem view];
        if ([throbberView isPlaying]) {
            [throbberView stop: self];
            [throbberView gotoPosterFrame: self];
        } else {
            [throbberView start: self];
        }
    }
#else
  if (mTimer) {
    [mTimer invalidate];
    [mTimer release];
    mTimer = nil;

    mFrame = 0;
  }
#endif
}

@end

#pragma mark -

//
// TabBarVisiblePrefChangedCallback
//
// Pref callback to tell us when the pref values for the visibility of the tab
// view with just one tab open.
//
int TabBarVisiblePrefChangedCallback(const char* inPref, void* inBWC)
{
  if (strcmp(inPref, gTabBarVisiblePref) == 0) {
    BOOL newValue = [[PreferenceManager sharedInstance] getBooleanPref:gTabBarVisiblePref withSuccess:nil];
    BrowserWindowController* bwc = (BrowserWindowController*)inBWC;
    [[bwc tabBrowser] setBarAlwaysVisible:newValue];
  }
  return NS_OK;
}


