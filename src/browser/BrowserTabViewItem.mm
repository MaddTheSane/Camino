/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "NSImage+Utils.h"
#import "NSString+Utils.h"

#import "BrowserTabViewItem.h"
#import "BrowserTabView.h"
#import "TabButtonView.h"

#import "BrowserWindowController.h"
#import "BrowserWrapper.h"
#import "TruncatingTextAndImageCell.h"

NSString* const kTabWillChangeNotification = @"TabWillChangeNotification";

// truncate menuitem title to the same width as the bookmarks menu
static const int kMenuTruncationChars = 60;

@interface BrowserTabViewItem(Private)
- (void)setTag:(int)tag;
@end

#pragma mark -

@implementation BrowserTabViewItem

-(id)initWithIdentifier:(id)identifier
{
  if ((self = [super initWithIdentifier:identifier])) {
    static int sTabItemTag = 1; // used to uniquely identify tabs for context menus  
    [self setTag:sTabItemTag];
    sTabItemTag++;

    mTabButtonView = [[TabButtonView alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)
                                               andTabItem:self];
    
    // create a menu item, to be used when there are more tabs than screen real estate. keep a strong ref
    // since it will be added to and removed from the menu repeatedly
    mMenuItem = [[NSMenuItem alloc] initWithTitle:[self label] action:@selector(selectTab:) keyEquivalent:@""];
    [mMenuItem setTarget:self];

    [[self tabView] setAutoresizesSubviews:YES];

    mDraggable = NO;
  }
  return self;
}

-(void)dealloc
{	
  // We can either be closing a single tab here, in which case we need to remove our view
  // from the superview, or the tab view may be closing, in which case it has already
  // removed all its subviews.
  [mTabButtonView removeFromSuperview];   // may be noop
  [mTabButtonView release];
  [mTabIcon release];
  [mMenuItem release];
  [super dealloc];
}

- (TabButtonView*)buttonView
{
  return mTabButtonView;
}

- (void)setTag:(int)tag
{
  mTag = tag;
}

- (int)tag
{
  return mTag;
}

- (void)closeTab:(id)sender
{
  if ([[self view] browserShouldClose]) {
    [[self view] browserClosed];
    [[self tabView] removeTabViewItem:self];
  }
}

- (BOOL)draggable
{
  return mDraggable;
}

- (void)setLabel:(NSString *)label
{
  [super setLabel:label];
  [mMenuItem setTitle:[label stringByTruncatingTo:kMenuTruncationChars
                                               at:kTruncateAtMiddle]];
  [mTabButtonView setLabel:label];
}

-(NSImage *)tabIcon
{
  return mTabIcon;
}

- (void)setTabIcon:(NSImage *)newIcon isDraggable:(BOOL)draggable
{
  mDraggable = draggable;

  [mTabIcon autorelease];
  mTabIcon = [newIcon copy];

  [mMenuItem setImage:mTabIcon];
  [mTabButtonView setIcon:mTabIcon isDraggable:draggable];
}

- (void)willBeRemoved
{
  [mTabButtonView removeFromSuperview];
}

#pragma mark -

- (void)startLoadAnimation
{
  [mTabButtonView startLoadAnimation];
}

- (void)stopLoadAnimation
{
  [mTabButtonView stopLoadAnimation];
}

- (NSMenuItem *) menuItem
{
  return mMenuItem;
}

- (void) selectTab:(id)sender
{
  [[NSNotificationCenter defaultCenter] postNotificationName:kTabWillChangeNotification object:self];
  [[self tabView] selectTabViewItem:self];
}

// called by delegate when a tab will be deselected
- (void) willDeselect
{
  [mMenuItem setState:NSOffState];
}
// called by delegate when a tab will be selected
- (void) willSelect
{
  [mMenuItem setState:NSOnState];
}

#pragma mark -

+ (NSImage*)closeIcon
{
  static NSImage* sCloseIcon = nil;
  if ( !sCloseIcon )
    sCloseIcon = [[NSImage imageNamed:@"tab_close"] retain];
  return sCloseIcon;
}

+ (NSImage*)closeIconPressed
{
  static NSImage* sCloseIconPressed = nil;
  if ( !sCloseIconPressed )
    sCloseIconPressed = [[NSImage imageNamed:@"tab_close_pressed"] retain];
  return sCloseIconPressed;
}

+ (NSImage*)closeIconHover
{
  static NSImage* sCloseIconHover = nil;
  if ( !sCloseIconHover )
    sCloseIconHover = [[NSImage imageNamed:@"tab_close_hover"] retain];
  return sCloseIconHover;
}

#pragma mark -

- (BOOL)shouldAcceptDrag:(id <NSDraggingInfo>)dragInfo
{
  id dragSource = [dragInfo draggingSource];
  if ((dragSource == self) || (dragSource == mTabButtonView))
    return NO;

  // TODO: find another way to do this that doesn't involve knowledge about BWC.
  BrowserWindowController *windowController = [[[self view] window] windowController];
  if (dragSource && dragSource == [windowController proxyIconView])
    return NO;

  return [(BrowserTabView*)[self tabView] shouldAcceptDrag:dragInfo];
}

- (BOOL)handleDrop:(id <NSDraggingInfo>)dragInfo
{
  return [(BrowserTabView*)[self tabView] handleDrop:dragInfo onTab:self];
}

@end
