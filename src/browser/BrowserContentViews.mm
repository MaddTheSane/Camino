/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "BrowserContentViews.h"

#import "BookmarkToolbar.h"
#import "BrowserTabView.h"
#import "BrowserTabBarView.h"
#import "TabThumbnailGridView.h"

/*
  These various content views are required to deal with several non-standard sizing issues
  in the bookmarks toolbar and browser tab view.
  
  First, the bookmarks toolbar can expand downwards as it reflows its buttons. The 
  BrowserContentView is required to deal with this, shrinking the BrowserContainerView
  to accomodate it.
  
  Second, we have to play tricks with the BrowserTabView, shifting it around
  when showing and hiding tabs, and expanding it outside the bounds of its
  enclosing control to clip out the shadows. The BrowserContainerView exists
  to handle this, and to draw background in extra space that is created as
  a result.
  
  Finally, the find bar can come and go depending on user action. It also 
  can be either the temporary "quickfind" or the persistant find bar, depending
  on the context. It's up to an external controller to set the find bar to the
  appropriate variant. Both setting and clearing the bar forces a reflow. 
  
  Note that having this code overrides the autoresize behaviour of these views
  as set in IB.
 ______________
 | Window
 | 
 | 
 |  _________________________________________________________________
    | BrowserContentView                                            |
    | ____________________________________________________________  |
    | | BookmarkToolbar                                           | |
    | |___________________________________________________________| |
    |                                                               |
    | ____________________________________________________________  |
    | | BrowserContainerView                                      | |
    | |                  _______  ________                        | |
    | | ________________/       \/        \_____________________  | |
    | | | BrowserTabView                                        | | |
    | | |                                                       | | |
    | | |                                                       | | |
    | | |                                                       | | |
    | | |                                                       | | |
    | | |                                                       | | |
    | | |                                                       | | |
    | | |_______________________________________________________| | |
    | |___________________________________________________________| |
    | ____________________________________________________________  |
    | | Status bar                                                | |
    | |___________________________________________________________| |
    |_______________________________________________________________|
    
*/

static const float kMinBrowserViewHeight = 100.0;

@implementation BrowserContentView

- (void) dealloc
{
  [mTabThumbnailGridView release];
  [super dealloc];
}

- (void)awakeFromNib
{
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldFrameSize
{
  float bmToolbarHeight = 0.0;
  float statusBarHeight = 0.0;

  if (mBookmarksToolbar) {
    // first resize the toolbar, which can reflow to a different height
    [mBookmarksToolbar resizeWithOldSuperviewSize: oldFrameSize];
      
    // make sure the toolbar doesn't get pushed off the top. This view is not flipped,
    // so the top is MaxY
    if (NSMaxY([mBookmarksToolbar frame]) > NSMaxY([self bounds])) {
      NSRect	newFrame = [mBookmarksToolbar frame];
      newFrame = NSOffsetRect(newFrame, 0, NSMaxY([self bounds]) - NSMaxY([mBookmarksToolbar frame]));
      [mBookmarksToolbar setFrame:newFrame];
    }
    
    if (![mBookmarksToolbar isHidden])
      bmToolbarHeight = NSHeight([mBookmarksToolbar frame]);
  }

  // enforce a minimum content size dynamically, based on the bars showing
  float minContentHeight = kMinBrowserViewHeight + bmToolbarHeight + statusBarHeight;
  NSSize currentContentSize = [NSWindow contentRectForFrameRect:[[self window] frame]
                                                      styleMask:[[self window] styleMask]].size;
  [[self window] setContentMinSize:NSMakeSize([[self window] contentMinSize].width,
                                              minContentHeight)];
  // if the bookmark reflow made the window too short, force it to grow
  if (currentContentSize.height < minContentHeight)
    [[self window] setContentSize:NSMakeSize(currentContentSize.width, minContentHeight)];

  // size/position the status bar, if present
  if (mStatusBar && ![mStatusBar isHidden]) {
    statusBarHeight = NSHeight([mStatusBar frame]);
    NSRect statusRect = [self bounds];
    statusRect.size.height = statusBarHeight;
    [mStatusBar setFrame:statusRect];
  }
  
  // figure out how much space is left for the browser view
  NSRect browserRect = [self bounds];
  // subtract bm toolbar
  browserRect.size.height -= bmToolbarHeight;
  
  // subtract status bar
  browserRect.size.height -= statusBarHeight;
  browserRect.origin.y += statusBarHeight;
  
  // resize our current content area, whatever it may be. We will
  // take care of resizing the other view when we toggle it to
  // match the size to avoid taking the hit of resizing it when it's
  // not visible.
  [mBrowserContainerView setFrame:browserRect];
  [mBrowserContainerView setNeedsDisplay:YES];
  // NSLog(@"resizing to %f %f", browserRect.size.width, browserRect.size.height);

  if (mTabThumbnailGridView)
  {
    NSRect tabposeRect = NSMakeRect(0, 0, browserRect.size.width,browserRect.size.height + statusBarHeight);
    [mTabThumbnailGridView setFrame:tabposeRect];
  }
}

- (void)willRemoveSubview:(NSView *)subview
{
  if (subview == mBookmarksToolbar)
    mBookmarksToolbar = nil;
  else if (subview == mStatusBar)
    mStatusBar = nil;

  [super willRemoveSubview:subview];
}

- (void)didAddSubview:(NSView *)subview
{
  // figure out if mStatusBar or mBookmarksToolbar has been added back?
  [super didAddSubview:subview];
}

- (void)showTabThumbnailGridView
{
  if (!mTabThumbnailGridView) {
    NSRect browserRect = [self bounds];
    mTabThumbnailGridView = [[TabThumbnailGridView alloc] initWithFrame:browserRect];
  }

  mStatusBarWasHidden = [mStatusBar isHidden];
  [mStatusBar setHidden:YES];

  mBookmarksToolbarWasHidden = [mBookmarksToolbar isHidden];
  [mBookmarksToolbar setHidden:YES];

  [mBrowserContainerView setHidden:YES];

  [self addSubview:mTabThumbnailGridView];
  [[self window] makeFirstResponder:[mTabThumbnailGridView nextValidKeyView]];
}

- (void)hideTabThumbnailGridView
{
  [mTabThumbnailGridView removeFromSuperview];
  [mBrowserContainerView setHidden:NO];

  if (!mStatusBarWasHidden)
    [mStatusBar setHidden:NO];
  if (!mBookmarksToolbarWasHidden)
    [mBookmarksToolbar setHidden:NO];

  [mTabThumbnailGridView release];
  mTabThumbnailGridView = nil;

  [self resizeSubviewsWithOldSize:[self frame].size];
}

- (void)toggleTabThumbnailGridView
{
  if ([mTabThumbnailGridView isDescendantOf:self])
    [self hideTabThumbnailGridView];
  else
    [self showTabThumbnailGridView];
}

- (BOOL)tabThumbnailGridViewIsVisible
{
  return [mTabThumbnailGridView isDescendantOf:self];
}

@end

#pragma mark -

@implementation BrowserContainerView

- (void)resizeSubviewsWithOldSize:(NSSize)oldFrameSize
{
  NSRect adjustedRect = [self bounds];
  if ([mTabBarView isVisible]) {
    adjustedRect.size.height -= [mTabBarView frame].size.height;

    NSRect tbRect = adjustedRect;
    tbRect.size.height = [mTabBarView frame].size.height;
    tbRect.origin.x = 0;
    tbRect.origin.y = NSMaxY(adjustedRect);
    [mTabBarView setFrame:tbRect];
  }
  [mTabView setFrame:adjustedRect];
}

@end
