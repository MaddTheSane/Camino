/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*-
*
* The contents of this file are subject to the Mozilla Public
* License Version 1.1 (the "License"); you may not use this file
* except in compliance with the License. You may obtain a copy of
* the License at http://www.mozilla.org/MPL/
*
* Software distributed under the License is distributed on an "AS
* IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
* implied. See the License for the specific language governing
* rights and limitations under the License.
*
* The Original Code is the Mozilla browser.
*
* The Initial Developer of the Original Code is Matt Judy.
*/

#import "CHExtendedTabView.h"
#import "BookmarksService.h"
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

@interface CHExtendedTabView (Private)
- (void)showOrHideTabsAsAppropriate;
@end

@implementation CHExtendedTabView

/******************************************/
/*** Initialization                     ***/
/******************************************/

- (id)initWithFrame:(NSRect)frameRect
{
    if ( (self = [super initWithFrame:frameRect]) ) {
      autoHides = YES;
    }
    return self;
}

- (void)awakeFromNib
{
    [self showOrHideTabsAsAppropriate];
    [self registerForDraggedTypes:[NSArray arrayWithObjects:@"MozURLType", @"MozBookmarkType", nil]];
}

/******************************************/
/*** Overridden Methods                 ***/
/******************************************/

- (BOOL)isOpaque
{
    if ( ([self tabViewType] == NSNoTabsBezelBorder) && (NSAppKitVersionNumber < 633) ) {
        return NO;
    } else {
        return [super isOpaque];
    }
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


/******************************************/
/*** Instance Methods                   ***/
/******************************************/

// 03-03-2002 mlj: Modifies tab view size and type appropriately... Fragile.
// Only to be used with the 2 types of tab view which we use in Chimera.
- (void)showOrHideTabsAsAppropriate
{
//    if ( autoHides == YES ) {
        if ( [[self tabViewItems] count] < 2) {
            if ( [self tabViewType] != NSNoTabsBezelBorder ) {
                [self setFrameSize:NSMakeSize( NSWidth([self frame]), NSHeight([self frame]) + 10 )];
            }
            [self setTabViewType:NSNoTabsBezelBorder];
        } else {
            if ( [self tabViewType] != NSTopTabsBezelBorder ) {
                [self setFrameSize:NSMakeSize( NSWidth([self frame]), NSHeight([self frame]) - 10 )];
            }
            [self setTabViewType:NSTopTabsBezelBorder];
        }
        [self display];
//    }
}

// NSDraggingDestination ///////////

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender
{
  return NSDragOperationGeneric;
}

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender
{  
  return NSDragOperationGeneric;
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
  return YES;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
  NSArray* contentIds;
  NSTabViewItem* overTabViewItem = nil;
  BOOL overContentArea = NO;

  // determine if we are over a tab or the content area
  NSPoint localPoint = [self convertPoint: [sender draggingLocation] fromView: nil];
  overTabViewItem = [self tabViewItemAtPoint: localPoint];
  overContentArea = NSPointInRect(localPoint, [self contentRect]);
  
  // check for recognized drag types
  contentIds = [[sender draggingPasteboard] propertyListForType: @"MozBookmarkType"];
  if (contentIds) {
    // drag type is chimera bookmarks
    for (unsigned int i = 0; i < [contentIds count]; ++i) {
      BookmarkItem* item = [BookmarksService::gDictionary objectForKey: [contentIds objectAtIndex:i]];
      nsCOMPtr<nsIDOMElement> bookmarkElt = do_QueryInterface([item contentNode]);

      nsCOMPtr<nsIAtom> tagName;
      [item contentNode]->GetTag(*getter_AddRefs(tagName));
      
      nsAutoString href;
      bookmarkElt->GetAttribute(NS_LITERAL_STRING("href"), href);
      NSString* url = [NSString stringWithCharacters: href.get() length: nsCRT::strlen(href.get())];

      nsAutoString group;
      bookmarkElt->GetAttribute(NS_LITERAL_STRING("group"), group);
      if (!group.IsEmpty()) {
        BookmarksService::OpenBookmarkGroup(self, bookmarkElt);
      } else {
        if (overTabViewItem) {
          [[[overTabViewItem view] getBrowserView] loadURI: url
                                                   flags: NSLoadFlagsNone];
        } else if (overContentArea) {
          [[[[self selectedTabViewItem] view] getBrowserView] loadURI: url
                                                              flags: NSLoadFlagsNone];
        } else
          [self addTabForURL:url];
      }
    }
  } else {
    // add bookmark for chimera url type
    NSDictionary* data = [[sender draggingPasteboard] propertyListForType: @"MozURLType"];

    if (overTabViewItem || overContentArea) {
      [[[overTabViewItem view] getBrowserView] loadURI:[data objectForKey:@"url"]
                                                flags: NSLoadFlagsNone];
    } else
      [self addTabForURL:[data objectForKey:@"url"]];
  }
  
  return YES;    
}

-(void)addTabForURL:(NSString*)aURL
{
  NSTabViewItem* tabViewItem;
  CHBrowserWrapper* newView;
  
  // We need to make a new tab.
  tabViewItem = [[[NSTabViewItem alloc] initWithIdentifier: nil] autorelease];
  newView = [[[CHBrowserWrapper alloc] initWithTab: tabViewItem andWindow: [self window]] autorelease];
  [tabViewItem setLabel: @"Untitled"];
  [tabViewItem setView: newView];
  [self addTabViewItem: tabViewItem];
  
  [[[tabViewItem view] getBrowserView] loadURI: aURL
                                          flags: NSLoadFlagsNone];
}

@end
