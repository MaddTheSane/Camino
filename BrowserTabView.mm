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
* Matt Judy 	<matt@nibfile.com> 	(Original Author)
* David Haas 	<haasd@cae.wisc.edu>
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

#import "NSString+Utils.h"

#import "BrowserTabView.h"
#import "BookmarksService.h"
#import "BookmarksDataSource.h"

#include "nsCOMPtr.h"
#include "nsIDOMElement.h"
#include "nsIContent.h"
#include "nsIAtom.h"
#include "nsString.h"
#include "nsCRT.h"

//////////////////////////
//     NEEDS IMPLEMENTED : Implement drag tracking for moving tabs around.
//  Implementation hints : Track drags ;)
//                       : Change tab controlTint to indicate drag location?
//				   		 : Move tab titles around when dragging.
//////////////////////////

@interface BrowserTabView (Private)

- (void)showOrHideTabsAsAppropriate;
- (BOOL)handleDropOnTab:(NSTabViewItem*)overTabViewItem overContent:(BOOL)overContentArea withURL:(NSString*)url;
- (BrowserTabViewItem*)getTabViewItemFromWindowPoint:(NSPoint)point;
- (void)showDragDestinationIndicator;
- (void)hideDragDestinationIndicator;

@end

@implementation BrowserTabView

/******************************************/
/*** Initialization                     ***/
/******************************************/

- (id)initWithFrame:(NSRect)frameRect
{
    if ( (self = [super initWithFrame:frameRect]) ) {
      autoHides = YES;
      maxNumberOfTabs = 0;		// no max
    }
    return self;
}

- (void)awakeFromNib
{
    [self showOrHideTabsAsAppropriate];
    [self registerForDraggedTypes:[NSArray arrayWithObjects:
        @"MozURLType", @"MozBookmarkType", NSStringPboardType, NSFilenamesPboardType, nil]];
}

/******************************************/
/*** Overridden Methods                 ***/
/******************************************/

- (BOOL)isOpaque
{
  if ( ([self tabViewType] == NSNoTabsBezelBorder) && (NSAppKitVersionNumber < 633) )
    return NO;

  return [super isOpaque];
}

- (void)drawRect:(NSRect)aRect
{
  if (mIsDropTarget)
  {
    NSRect	hilightRect = aRect;
    hilightRect.size.height = 18.0;		// no need to move origin.y; our coords are flipped
    NSBezierPath* dropTargetOutline = [NSBezierPath bezierPathWithRect:hilightRect];

    [[[NSColor colorForControlTint:NSDefaultControlTint] colorWithAlphaComponent:0.5] set];
    [dropTargetOutline fill];
  }

  [super drawRect:aRect];
}

- (void)addTabViewItem:(NSTabViewItem *)tabViewItem
{
  [super addTabViewItem:tabViewItem];
  [self showOrHideTabsAsAppropriate];
}

- (void)removeTabViewItem:(NSTabViewItem *)tabViewItem
{
  [super removeTabViewItem:tabViewItem];
  [self showOrHideTabsAsAppropriate];
}

- (void)insertTabViewItem:(NSTabViewItem *)tabViewItem atIndex:(int)index
{
  [super insertTabViewItem:tabViewItem atIndex:index];
  [self showOrHideTabsAsAppropriate];
}

/******************************************/
/*** Accessor Methods                   ***/
/******************************************/

- (BOOL)autoHides
{
    return autoHides;
}

- (void)setAutoHides:(BOOL)newSetting
{
    autoHides = newSetting;
}

- (int)maxNumberOfTabs
{
  return maxNumberOfTabs;
}

- (void)setMaxNumberOfTabs:(int)maxTabs
{
  maxNumberOfTabs = maxTabs;
}

- (BOOL)canMakeNewTabs
{
  return maxNumberOfTabs == 0 || [self numberOfTabViewItems]  < maxNumberOfTabs;
}

/******************************************/
/*** Instance Methods                   ***/
/******************************************/

// 03-03-2002 mlj: Modifies tab view size and type appropriately... Fragile.
// Only to be used with the 2 types of tab view which we use in Chimera.
- (void)showOrHideTabsAsAppropriate
{
  //if ( autoHides == YES )
  {
    BOOL tabVisibilityChanged = NO;
    BOOL tabsVisible = NO;
    
    if ( [[self tabViewItems] count] < 2)
    {
      if ( [self tabViewType] != NSNoTabsBezelBorder )
        [self setFrameSize:NSMakeSize( NSWidth([self frame]), NSHeight([self frame]) + 10 )];

      [self setTabViewType:NSNoTabsBezelBorder];
      tabVisibilityChanged = YES;
      tabsVisible = NO;
    }
    else
    {
      if ( [self tabViewType] != NSTopTabsBezelBorder )
        [self setFrameSize:NSMakeSize( NSWidth([self frame]), NSHeight([self frame]) - 10 )];

      [self setTabViewType:NSTopTabsBezelBorder];
      tabVisibilityChanged = YES;
      tabsVisible = YES;
    }

    // tell the tabs that visibility changed
    NSArray* tabViewItems = [self tabViewItems];
    for (unsigned int i = 0; i < [tabViewItems count]; i ++)
    {
      NSTabViewItem* tabItem = [tabViewItems objectAtIndex:i];
      if ([tabItem isMemberOfClass:[BrowserTabViewItem class]])
        [(BrowserTabViewItem*)tabItem updateTabVisibility:tabsVisible];
    }

    [self display];
	}
}


- (BOOL)handleDropOnTab:(NSTabViewItem*)overTabViewItem overContent:(BOOL)overContentArea withURL:(NSString*)url
{
  if (overTabViewItem) 
  {
    [[overTabViewItem view] loadURI: url referrer:nil flags: NSLoadFlagsNone activate:NO];
    return YES;
  }
  else if (overContentArea)
  {
    [[[self selectedTabViewItem] view] loadURI: url referrer:nil flags: NSLoadFlagsNone activate:NO];
    return YES;
  }
  else if ([self canMakeNewTabs])
  {
    [self addTabForURL:url referrer:nil];
    return YES;
  }
  
  return NO;  
}

- (BrowserTabViewItem*)getTabViewItemFromWindowPoint:(NSPoint)point
{
  NSPoint         localPoint      = [self convertPoint: point fromView: nil];
  NSTabViewItem*  overTabViewItem = [self tabViewItemAtPoint: localPoint];
  return (BrowserTabViewItem*)overTabViewItem;
}

- (void)showDragDestinationIndicator
{
  if (!mIsDropTarget)
  {
    mIsDropTarget = YES;
    [self setNeedsDisplay:YES];
  }
}

- (void)hideDragDestinationIndicator
{
  if (mIsDropTarget)
  {
    mIsDropTarget = NO;
    [self setNeedsDisplay:YES];
  }
}

#pragma mark -

// NSDraggingDestination ///////////

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender
{
  NSPoint         localPoint      = [self convertPoint: [sender draggingLocation] fromView: nil];
  NSTabViewItem*  overTabViewItem = [self tabViewItemAtPoint: localPoint];
  BOOL            overContentArea = NSPointInRect(localPoint, [self contentRect]);

  if (overTabViewItem)
    return NSDragOperationNone;	// the tab will handle it

  if (!overContentArea && ![self canMakeNewTabs])
    return NSDragOperationNone;
  
  [self showDragDestinationIndicator];	// XXX optimize
  return NSDragOperationGeneric;
}

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender
{  
  NSPoint         localPoint      = [self convertPoint: [sender draggingLocation] fromView: nil];
  NSTabViewItem*  overTabViewItem = [self tabViewItemAtPoint: localPoint];
  BOOL            overContentArea = NSPointInRect(localPoint, [self contentRect]);

  if (overTabViewItem)
    return NSDragOperationNone;	// the tab will handle it

  if (!overContentArea && ![self canMakeNewTabs])
  {
    [self hideDragDestinationIndicator];
    return NSDragOperationNone;
  }

  [self showDragDestinationIndicator];
  return NSDragOperationGeneric;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
  [self hideDragDestinationIndicator];
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
  return YES;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
  // determine if we are over a tab or the content area
  NSPoint         localPoint      = [self convertPoint: [sender draggingLocation] fromView: nil];
  NSTabViewItem*  overTabViewItem = [self tabViewItemAtPoint: localPoint];
  BOOL            overContentArea = NSPointInRect(localPoint, [self contentRect]);
  NSArray*        pasteBoardTypes = [[sender draggingPasteboard] types];

  [self hideDragDestinationIndicator];

  if ([pasteBoardTypes containsObject: @"MozBookmarkType"])
  {
    NSArray* contentIds = [[sender draggingPasteboard] propertyListForType: @"MozBookmarkType"];
    if (contentIds) {
      // drag type is chimera bookmarks
      for (unsigned int i = 0; i < [contentIds count]; ++i) {
        BookmarkItem* item = [BookmarksService::gDictionary objectForKey: [contentIds objectAtIndex:i]];
        nsCOMPtr<nsIDOMElement> bookmarkElt = do_QueryInterface([item contentNode]);
  
        nsCOMPtr<nsIAtom> tagName;
        [item contentNode]->GetTag(*getter_AddRefs(tagName));
        
        nsAutoString href;
        bookmarkElt->GetAttribute(NS_LITERAL_STRING("href"), href);
        NSString* url = [NSString stringWith_nsAString: href];
  
        nsAutoString group;
        bookmarkElt->GetAttribute(NS_LITERAL_STRING("group"), group);
        if (!group.IsEmpty()) {
          BookmarksService::OpenBookmarkGroup(self, bookmarkElt);
        } else {
          return [self handleDropOnTab:overTabViewItem overContent:overContentArea withURL:url];
        }
      }	// for each item
    }
  }
  else if ([pasteBoardTypes containsObject: @"MozURLType"])
  {
    // drag type is MozURLType
    NSDictionary* data = [[sender draggingPasteboard] propertyListForType: @"MozURLType"];
    if (data) {
      NSString*	urlString = [data objectForKey:@"url"];
      return [self handleDropOnTab:overTabViewItem overContent:overContentArea withURL:urlString];
    }
  }
  else if ([pasteBoardTypes containsObject: NSStringPboardType])
  {
    NSString*	urlString = [[sender draggingPasteboard] stringForType: NSStringPboardType];
    return [self handleDropOnTab:overTabViewItem overContent:overContentArea withURL:urlString];
  }
  else if ([pasteBoardTypes containsObject: NSURLPboardType])
  {
    NSURL*	urlData = [NSURL URLFromPasteboard:[sender draggingPasteboard]];
    return [self handleDropOnTab:overTabViewItem overContent:overContentArea withURL:[urlData absoluteString]];
  }
  else if ([pasteBoardTypes containsObject: NSFilenamesPboardType])
  {
    NSString*	urlString = [[sender draggingPasteboard] stringForType: NSFilenamesPboardType];
    return [self handleDropOnTab:overTabViewItem overContent:overContentArea withURL:urlString];
  }
  
  return NO;    
}

#pragma mark -

-(void)addTabForURL:(NSString*)aURL referrer:(NSString*)aReferrer
{
  // We need to make a new tab.
  BrowserTabViewItem *tabViewItem= [BrowserTabView makeNewTabItem];
  CHBrowserWrapper *newView = [[[CHBrowserWrapper alloc] initWithTab: tabViewItem andWindow: [self window]] autorelease];
  [tabViewItem setLabel: NSLocalizedString(@"UntitledPageTitle", @"")];
  [tabViewItem setView: newView];
  [self addTabViewItem: tabViewItem];

  [[tabViewItem view] loadURI: aURL referrer:aReferrer flags: NSLoadFlagsNone activate:NO];
}

#pragma mark -

+ (BrowserTabViewItem*)makeNewTabItem
{
  return [[[BrowserTabViewItem alloc] init] autorelease];
}

@end




