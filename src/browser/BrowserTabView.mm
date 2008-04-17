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
 *   Matt Judy 	<matt@nibfile.com> 	(Original Author)
 *   David Haas 	<haasd@cae.wisc.edu>
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

#import "NSPasteboard+Utils.h"
#import "PreferenceManager.h"

#import "BrowserTabView.h"
#import "BrowserTabViewItem.h"
#import "TabButtonView.h"
#import "BrowserWrapper.h"
#import "BookmarkManager.h"
#import "BrowserTabBarView.h"
#import "BrowserWindowController.h"
#import "MainController.h"


NSString* const kTabBarBackgroundDoubleClickedNotification = @"kTabBarBackgroundDoubleClickedNotification";


//////////////////////////
//     NEEDS IMPLEMENTED : Implement drag tracking for moving tabs around.
//  Implementation hints : Track drags ;)
//                       : Change tab controlTint to indicate drag location?
//				   		 : Move tab titles around when dragging.
//////////////////////////

@interface BrowserTabView (Private)
- (void)showOrHideTabsAsAppropriate;
- (NSArray*)urlsFromPasteboard:(NSPasteboard*)pasteboard;
@end

#pragma mark -

@implementation BrowserTabView

/******************************************/
/*** Initialization                     ***/
/******************************************/

- (id)initWithFrame:(NSRect)frameRect
{
    if ( (self = [super initWithFrame:frameRect]) ) {
      mBarAlwaysVisible = NO;
      //mVisible = YES;
    }
    return self;
}

- (void)awakeFromNib
{
    mBarAlwaysVisible = NO;
    mVisible = YES;
    [self showOrHideTabsAsAppropriate];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(tabWillChange:)
        name:kTabWillChangeNotifcation object:nil];
}

- (void)dealloc 
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super dealloc];
}

/******************************************/
/*** Overridden Methods                 ***/
/******************************************/

- (void)addTabViewItem:(NSTabViewItem *)tabViewItem
{
  // creating a new tab means clearing the jumpback tab.
  [self setJumpbackTab:nil];
  
  [super addTabViewItem:tabViewItem];
  [self showOrHideTabsAsAppropriate];
}

- (void)removeTabViewItem:(NSTabViewItem *)tabViewItem
{
  // the normal behavior of the tab widget is to select the tab to the left
  // of the tab being removed. Users, however, want the tab to the right to
  // be selected. This also matches how mozilla works. Select the right tab
  // first so we don't take the hit of displaying the left tab before we switch.
  //
  // Ben and I talked about a way to improve this slightly, with the concept
  // of a "jumpback tab" that is associated with a tab that is opened via
  // cmd-click or single-window-mode. When the current tab is closed, we jump
  // back to that tab, the thought being they are related. Switching tabs in
  // any way (even closing a tab) will clear the jumpback tab and return to
  // the "select to the right" behavior. 
  
  // make sure the tab view is removed
  [(BrowserTabViewItem *)tabViewItem willBeRemoved];
  if ([self selectedTabViewItem] == tabViewItem) {
    BOOL tabJumpbackPref = [[PreferenceManager sharedInstance] getBooleanPref:kGeckoPrefEnableTabJumpback
                                                                  withSuccess:NULL];

    if (tabJumpbackPref && mJumpbackTab)
      [mJumpbackTab selectTab:self]; 
    else
      [self selectNextTabViewItem:self];
  }
  [super removeTabViewItem:tabViewItem];
  [self showOrHideTabsAsAppropriate];
  
  // clear the jumpback tab, it's served its purpose
  [self setJumpbackTab:nil];
}

- (void)insertTabViewItem:(NSTabViewItem *)tabViewItem atIndex:(int)index
{
  // inserting a new tab means clearing the jumpback tab.
  [self setJumpbackTab:nil];
  
  [super insertTabViewItem:tabViewItem atIndex:index];
  [self showOrHideTabsAsAppropriate];
}

- (BrowserTabViewItem*)itemWithTag:(int)tag
{
  NSArray* tabViewItems = [self tabViewItems];

  for (unsigned int i = 0; i < [tabViewItems count]; i ++)
  {
    id tabItem = [tabViewItems objectAtIndex:i];
    if ([tabItem isMemberOfClass:[BrowserTabViewItem class]] &&
      	([(BrowserTabViewItem*)tabItem tag] == tag))
    {
      return tabItem;
    }
  }

  return nil;
}

// Returns the number of tabs, excluding ones which contain a URI unsuitable for
// bookmarking (e.g. a blank or unsafe URI)
- (int)numberOfBookmarkableTabViewItems
{
  int numberOfBookmarkableTabs = 0;
  int numberOfTabs = [self numberOfTabViewItems];
  for (int i = 0; i < numberOfTabs; i++) {
    BrowserWrapper* browserWrapper = (BrowserWrapper*)[[self tabViewItemAtIndex:i] view];
    if ([browserWrapper isBookmarkable])
      numberOfBookmarkableTabs++;
  }
  return numberOfBookmarkableTabs;
}

- (int)indexOfTabViewItemWithURL:(NSString*)aURL
{
  // Try the selected tab first.
  if ([[(BrowserWrapper*)[[self selectedTabViewItem] view] currentURI] isEqualToString:aURL])
    return [self indexOfTabViewItem:[self selectedTabViewItem]];
  // Otherwise just walk all the tabs and return the first match.
  NSArray* tabViewItems = [self tabViewItems];
  for (unsigned int i = 0; i < [tabViewItems count]; i++) {
    id tab = [tabViewItems objectAtIndex:i];
    if ([[(BrowserWrapper*)[tab view] currentURI] isEqualToString:aURL]) {
      return i;
    }
  }
  return NSNotFound;
}

/******************************************/
/*** Accessor Methods                   ***/
/******************************************/

- (BOOL)barAlwaysVisible
{
  return mBarAlwaysVisible;
}

- (void)setBarAlwaysVisible:(BOOL)newSetting
{
  BOOL oldSetting = mBarAlwaysVisible;
  mBarAlwaysVisible = newSetting;
  
  // if there was a change, make sure we update immediately
  if (newSetting != oldSetting)
    [self showOrHideTabsAsAppropriate];
}

/******************************************/
/*** Instance Methods                   ***/
/******************************************/

// redraws the tab bar, rebuilding it if instructed
- (void)refreshTabBar:(BOOL)rebuild
{
  // don't bother if it's not even visible
  if ([self tabsVisible]) {
    if (rebuild) {
      [mTabBar rebuildTabBar];
    } else {
      [mTabBar setNeedsDisplay:YES];
    }
  }
}

// Only to be used with the 2 types of tab view which we use in Camino.
- (void)showOrHideTabsAsAppropriate
{
  // don't bother if we're not visible
  if (mVisible) {
    BOOL tabVisibilityChanged = NO;
    BOOL tabsVisible = [mTabBar isVisible];
    int numItems = [[self tabViewItems] count];
    
    // if the number of tabs gets below a minimum threshold, we want to 
    // close the bar. That threshold is two if the user has auto-hide on,
    // otherwise it is one (meaning don't hide it at all).
    const short minTabThreshold = [self barAlwaysVisible] ? 1 : 2;
    
    if (numItems < minTabThreshold && tabsVisible) {
      tabVisibilityChanged = YES;
      // hide the tabs and give the view a chance to kill its tracking rects
      [mTabBar setVisible:NO];
    } 
    else if (numItems >= minTabThreshold && !tabsVisible) {
      // show the tabs allow the view to set up tracking rects
      [mTabBar setVisible:YES];
      tabVisibilityChanged = YES;
    }
    tabsVisible = [mTabBar isVisible];
    
    // Ensure that the last tab isn't closeable.
    if (tabsVisible && [self barAlwaysVisible])
      [[[[self tabViewItems] objectAtIndex:0] buttonView] setCloseButtonEnabled:(numItems > 1)];
    
    if (tabVisibilityChanged) {
      // tell the superview to resize its subviews
      [[self superview] resizeSubviewsWithOldSize:[[self superview] frame].size];
      [self setNeedsDisplay:YES];
    }
  }
}

// Checks each of the tabs to be sure that they are allowed to be closed.
- (BOOL)windowShouldClose
{
  const int numTabs = [self numberOfTabViewItems];
  for (int i = 0; i < numTabs; i++) {
    NSTabViewItem* item = [self tabViewItemAtIndex:i];
    if (![[item view] browserShouldClose])
      return NO;
  }
  return YES;
}

- (void)windowClosed
{
  // Loop over all tabs, and tell them that the window is closed. This
  // stops gecko from going any further on any of its open connections
  // and breaks all the necessary cycles between Gecko and the BrowserWrapper.
  int numTabs = [self numberOfTabViewItems];
  for (int i = 0; i < numTabs; i++) {
    NSTabViewItem* item = [self tabViewItemAtIndex: i];
    [[item view] browserClosed];
  }
}

- (BOOL)tabsVisible
{
  return ([mTabBar isVisible]);
}

- (BOOL)isVisible
{
  return mVisible;
}

// inform the view that it will be shown or hidden; e.g. prior to showing or hiding the bookmarks
- (void)setVisible:(BOOL)show
{
  mVisible = show;
  // if the tabs' visibility is different, and we're being, hidden explicitly hide them.
  // otherwise show or hide them according to current settings
  if (([mTabBar isVisible] != mVisible) && !mVisible)
    [mTabBar setVisible:show];
  else
    [self showOrHideTabsAsAppropriate];
}

#pragma mark -
// Drag helpers for tabs and the tab bar.

// Private method to extract recognized URL types from the pasteboard.
- (NSArray*)urlsFromPasteboard:(NSPasteboard*)pasteboard
{
  NSArray* urls = nil;
  NSArray* pasteBoardTypes = [pasteboard types];
  if ([pasteBoardTypes containsObject:kCaminoBookmarkListPBoardType]) {
    NSArray* bookmarkUUIDs = [pasteboard propertyListForType:kCaminoBookmarkListPBoardType];
    urls = [BookmarkManager bookmarkURLsFromSerializableArray:bookmarkUUIDs];
  }
  else if ([pasteboard containsURLData]) {
    NSArray* titles; // discarded
    [pasteboard getURLs:&urls andTitles:&titles];
  }
  return urls;
}

- (BOOL)shouldAcceptDrag:(id <NSDraggingInfo>)dragInfo
{
  // This must stay in sync with the behavior of urlsForDrag:; we don't just
  // call through to it because it does more work than we need for a yes/no.
  NSArray* pasteBoardTypes = [[dragInfo draggingPasteboard] types];
  return ([pasteBoardTypes containsObject:kCaminoBookmarkListPBoardType] ||
          [[dragInfo draggingPasteboard] containsURLData]);
}

- (BOOL)handleDrop:(id <NSDraggingInfo>)dragInfo onTab:(NSTabViewItem*)targetTab
{
  NSArray* urls = [self urlsFromPasteboard:[dragInfo draggingPasteboard]];
  if ([urls count] == 0)
    return NO;

  if ([urls count] == 1) {
    NSString* url = [urls objectAtIndex:0];
    BOOL loadInBackground = [BrowserWindowController shouldLoadInBackgroundForDestination:eDestinationNewTab
                                                                                   sender:nil];
    if (targetTab) {
      [[targetTab view] loadURI:url referrer:nil flags:NSLoadFlagsNone focusContent:YES allowPopups:NO];
      
      if (!loadInBackground)
        [self selectTabViewItem:targetTab];
    }
    else {
      [self addTabForURL:url referrer:nil inBackground:loadInBackground];
    }
  }
  else {
    [[[self window] windowController] openURLArray:urls tabOpenPolicy:(targetTab ? eReplaceTabs : eAppendTabs) allowPopups:NO];
  }
  return YES;
}

#pragma mark -

-(void)addTabForURL:(NSString*)aURL referrer:(NSString*)aReferrer inBackground:(BOOL)inBackground
{
  [[[self window] windowController] openNewTabWithURL:aURL referrer:aReferrer loadInBackground:inBackground allowPopups:NO setJumpback:NO];
}

#pragma mark -

+ (BrowserTabViewItem*)makeNewTabItem
{
  return [[[BrowserTabViewItem alloc] init] autorelease];
}

#pragma mark -

//
// get and set the "jumpback tab", the tab that is jumped to when the currently
// visible tab is closed. Reset automatically when switching tabs or after
// jumping back. This isn't designed to be a tab history, it only lives for a very
// well-defined period.
//

- (void)setJumpbackTab:(BrowserTabViewItem*)inTab
{
  mJumpbackTab = inTab;
}

- (BrowserTabViewItem*)jumpbackTab
{
  return mJumpbackTab;
}

//
// tabWillChange:
//
// Called when the tab is about to change and is our cue to clear out the jumpback tab.
//
- (void)tabWillChange:(NSNotification*)inNotify
{
  // If the user clicks on the same tab that's already selected, we'll still get
  // a notification, so do nothing if we're "switching" to the currently selected tab
  id object = [inNotify object];
  if (!object || object != [self selectedTabViewItem])
    [self setJumpbackTab:nil];
}

// Tabs should be scrolled into view when selected.
-(void)selectTabViewItem:(NSTabViewItem*)item
{
  [super selectTabViewItem:item];
  [mTabBar scrollTabIndexToVisible:[self indexOfTabViewItem:item]];
}

@end
