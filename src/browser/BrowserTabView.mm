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
#import "NSPasteboard+Utils.h"
#import "NSArray+Utils.h"

#import "BrowserTabView.h"
#import "BrowserWrapper.h"
#import "BrowserWindowController.h"
#import "BookmarkFolder.h"
#import "Bookmark.h"
#import "BookmarkToolbar.h"

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


#define kTabDropTargetHeight  18.0

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
        @"MozURLType", @"MozBookmarkType", NSStringPboardType, NSFilenamesPboardType, NSURLPboardType, nil]];
}

/******************************************/
/*** Overridden Methods                 ***/
/******************************************/

- (BOOL)isOpaque
{
  // see http://developer.apple.com/qa/qa2001/qa1117.html
  if ( ([self tabViewType] == NSNoTabsBezelBorder) && (NSAppKitVersionNumber < 633) )
    return NO;

  return [super isOpaque];
}

- (void)drawRect:(NSRect)aRect
{
  if (mIsDropTarget)
  {
    NSRect	hilightRect = aRect;
    hilightRect.size.height = kTabDropTargetHeight;		// no need to move origin.y; our coords are flipped
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
  // the normal behavior of the tab widget is to select the tab to the left
  // of the tab being removed. Users, however, want the tab to the right to
  // be selected. This also matches how mozilla works. Select the right tab
  // first so we don't take the hit of displaying the left tab before we switch.
  if ( [self selectedTabViewItem] == tabViewItem )
    [self selectNextTabViewItem:self];
  [super removeTabViewItem:tabViewItem];
  [self showOrHideTabsAsAppropriate];
}

- (void)insertTabViewItem:(NSTabViewItem *)tabViewItem atIndex:(int)index
{
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
      {
        [self setTabViewType:NSNoTabsBezelBorder];
        tabVisibilityChanged = YES;
      }
      tabsVisible = NO;
    }
    else
    {
      if ( [self tabViewType] != NSTopTabsBezelBorder )
      {
        [self setTabViewType:NSTopTabsBezelBorder];
        tabVisibilityChanged = YES;
      }
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
    
    if (tabVisibilityChanged)
    {
      [[[[self window] windowController] bookmarkToolbar] setDrawBottomBorder:!tabsVisible];

      // tell the superview to resize its subviews
      [[self superview] resizeSubviewsWithOldSize:[[self superview] frame].size];
      [self setNeedsDisplay:YES];
    }
	}
}

//
// -getExtraTopSpace
//
// return the gap we want to have to make us display correctly. Note the tab dimensions
// changed in panther so we have to use different constants.
//
- (float)getExtraTopSpace;
{
  const float kPantherAppKit = 743.0;
  
  const float kTabsVisibleTopGap    = 4.0;      // space above the tabs
  const float kTabsVisibleTopGapPanther = 0.0;  // no gap above tabs on panther
  const float kTabsInvisibleTopGap  = -7.0;		  // space removed to push tab content up when no tabs are visible
  
	return ([self tabsVisible]) ? 
    ((NSAppKitVersionNumber >= kPantherAppKit) ? kTabsVisibleTopGapPanther : kTabsVisibleTopGap) : kTabsInvisibleTopGap;
}

- (BOOL)tabsVisible
{
  return ([[self tabViewItems] count] > 1);
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
    NSRect invalidRect = [self bounds];
    invalidRect.size.height = kTabDropTargetHeight;
    [self setNeedsDisplayInRect:invalidRect];
    mIsDropTarget = YES;
  }
}

- (void)hideDragDestinationIndicator
{
  if (mIsDropTarget)
  {
    NSRect invalidRect = [self bounds];
    invalidRect.size.height = kTabDropTargetHeight;
    [self setNeedsDisplayInRect:invalidRect];
    mIsDropTarget = NO;
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
    NSArray* draggedItems = [NSArray pointerArrayFromDataArrayForMozBookmarkDrop:[[sender draggingPasteboard] propertyListForType: @"MozBookmarkType"]];
    if (draggedItems)
    {
      id aBookmark;
      if ([draggedItems count] == 1) {
        aBookmark = [draggedItems objectAtIndex:0];
        if ([aBookmark isKindOfClass:[Bookmark class]])
          return [self handleDropOnTab:overTabViewItem overContent:overContentArea withURL:[aBookmark url]];
        else if ([aBookmark isKindOfClass:[BookmarkFolder class]]) {
          [[[self window] windowController] openURLArray:[aBookmark childURLs] replaceExistingTabs:YES];
          return YES;
        }
      } else if ([draggedItems count] > 1) {
        NSMutableArray *urlArray = [NSMutableArray arrayWithCapacity:[draggedItems count]];
        NSEnumerator *enumerator = [draggedItems objectEnumerator];
        while ((aBookmark = [enumerator nextObject])) {
          if ([aBookmark isKindOfClass:[Bookmark class]])
            [urlArray addObject:[aBookmark url]];
          else if ([aBookmark isKindOfClass:[BookmarkFolder class]])
            [urlArray addObjectsFromArray:[aBookmark childURLs]];
        }
        [[[self window] windowController] openURLArray:urlArray replaceExistingTabs:YES];
        return YES;
      }
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
  [[[self window] windowController] openNewTabWithURL:aURL referrer:aReferrer loadInBackground:YES];
}

#pragma mark -

+ (BrowserTabViewItem*)makeNewTabItem
{
  return [[[BrowserTabViewItem alloc] init] autorelease];
}

@end




