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
 *   David Hyatt <hyatt@mozilla.org> (Original Author)
 *   Kathy Brade <brade@netscape.com>
 *   David Haas <haasd@cae.wisc.edu>
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

#import "NSView+Utils.h"

#import "BookmarkToolbar.h"

#import "CHBrowserService.h"
#import "BookmarkButton.h"
#import "BookmarkManager.h"
#import "BrowserWindowController.h"
#import "BrowserWindow.h"
#import "Bookmark.h"
#import "BookmarkFolder.h"
#import "CHGradient.h"
#import "NSPasteboard+Utils.h"
#import "NSBezierPath+Utils.h"
#import "NSWorkspace+Utils.h"

#define CHInsertNone 0
#define CHInsertInto  1
#define CHInsertBefore  2
#define CHInsertAfter  3

static const float kButtonRectHPadding = 3.0f;
static const float kButtonRectVPadding = 4.0f;

@interface BookmarkToolbar(Private)

- (void)rebuildButtonList;
- (void)setButtonInsertionPoint:(id <NSDraggingInfo>)sender;
- (NSRect)insertionHiliteRectForButton:(NSView*)aButton position:(int)aPosition;
- (BookmarkButton*)makeNewButtonWithItem:(BookmarkItem*)aItem;
- (void)managerStarted:(NSNotification*)inNotify;
- (BOOL)findDropAnchorAtPoint:(NSPoint)testPoint;
- (BOOL)findDropAnchorScanningFromPoint:(NSPoint)testPoint withStep:(int)step;
- (void)drawBackgroundInRect:(NSRect)rect;
- (void)drawInsertionHighlightForButtonRect:(NSRect)rect;
- (void)setupKeyViewLoop;

@end

#pragma mark -

@implementation BookmarkToolbar

static const int kBMBarScanningStep = 5;

- (id)initWithFrame:(NSRect)frame
{
  if ((self = [super initWithFrame:frame])) {
    mButtons = [[NSMutableArray alloc] init];
    mDragInsertionButton = nil;
    mDragInsertionPosition = CHInsertNone;
    mDrawBorder = YES;

    [self registerForDraggedTypes:[NSArray arrayWithObjects:kCaminoBookmarkListPBoardType,
                                                            kWebURLsWithTitlesPboardType,
                                                            NSStringPboardType,
                                                            NSURLPboardType,
                                                            nil]];

    mButtonListDirty = YES;

    // Generic notifications for Bookmark Client
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(bookmarkAdded:) name:BookmarkFolderAdditionNotification object:nil];
    [nc addObserver:self selector:@selector(bookmarkRemoved:) name:BookmarkFolderDeletionNotification object:nil];
    [nc addObserver:self selector:@selector(bookmarkChanged:) name:BookmarkItemChangedNotification object:nil];

    // register for notifications of when the BM manager starts up. Since it does it on a separate thread,
    // it can be created after we are and if we don't update ourselves, the bar will be blank. This
    // happens most notably when the app is launched with a 'odoc' or 'GURL' appleEvent.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(managerStarted:)
        name:kBookmarkManagerStartedNotification object:nil];
  }
  return self;
}

- (void)awakeFromNib
{
  // The BookmarkToolbar manages its key view loop like NSTabView.  The initially provided 
  // nextKeyView of the BookmarkToolbar is remembered as the "next external key view".  The last
  // bookmark button will then be given the "next external key view" as its next key view.
  // The nextKeyView of the toolbar itself is changed to instead be the first bookmark button.
  mNextExternalKeyView = [self nextKeyView];
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [mButtons release];
  [super dealloc];
}

//
// - managerStarted:
//
// Notification callback from the bookmark manager. Build the button list.
//
- (void)managerStarted:(NSNotification*)inNotify
{
  [self rebuildButtonList];
}

- (void)drawRect:(NSRect)aRect
{
  [self drawBackgroundInRect:aRect];

  if (mDrawBorder) {
    [[NSColor controlShadowColor] set];
    float height = [self bounds].size.height;
    NSRectFill(NSMakeRect(aRect.origin.x, height - 1.0, aRect.size.width, height));
  }

  // The buttons will paint themselves. Just call our base class method.
  [super drawRect:aRect];

  // draw a separator at drag n drop insertion point if there is one
  if (mDragInsertionPosition) {
    NSRect buttonRect = [self insertionHiliteRectForButton:mDragInsertionButton
                                                  position:mDragInsertionPosition];
    if (NSIntersectsRect(buttonRect, aRect))
      [self drawInsertionHighlightForButtonRect:buttonRect];
  }
}

//
// -drawBackgroundInRect:
//
// Draws the background for the toolbar
//
- (void)drawBackgroundInRect:(NSRect)rect
{
  // On 10.4, if the unified title bar and toolbar is in use, the bookmark bar
  // gets a background gradient that matches the unified title bar/toolbar. This
  // gradient is only used if the window is main.  If the window is not main,
  // the title bar and toolbar will have a different (inactive) appearance, so
  // so the gradient won't be used.
  // On 10.5, a different gradient is used, and is always drawn.

  BrowserWindow* browserWin = (BrowserWindow*)[self window];
  BOOL isLeopardOrHigher = [NSWorkspace isLeopardOrHigher];
  if (isLeopardOrHigher ||
      ([browserWin hasUnifiedToolbarAppearance] && [browserWin isMainWindow]))
  {
    NSColor* startColor;
    NSColor* endColor;
    if (isLeopardOrHigher) {
      startColor = [NSColor colorWithDeviceWhite:(217.0/255.0) alpha:1.0];
      endColor = [NSColor colorWithDeviceWhite:(195.0/255.0) alpha:1.0];
    }
    else {
      startColor = [NSColor colorWithDeviceWhite:(235.0/255.0) alpha:1.0];
      endColor = [NSColor colorWithDeviceWhite:(214.0/255.0) alpha:1.0];
    }

    NSRect bounds = [self bounds];
    NSRect gradientRect = NSMakeRect(rect.origin.x, 0,
                                     rect.size.width, bounds.size.height - 1.0);

    CHGradient* backgroundGradient =
      [[[CHGradient alloc] initWithStartingColor:startColor
                                     endingColor:endColor] autorelease];
    [backgroundGradient drawInRect:gradientRect angle:90.0];
  }
}

//
// -drawInsertionHighlightInRect:
//
// Draws a visual indicator of where a bookmark/url drop will be inserted.
//
- (void)drawInsertionHighlightForButtonRect:(NSRect)rect
{
  if (mDragInsertionPosition == CHInsertInto) {
    rect = NSInsetRect(rect, kButtonRectHPadding - 1.0f, kButtonRectVPadding - 1.0f);
    NSBezierPath* dropTargetOutline = [NSBezierPath bezierPathWithRoundCorneredRect:rect
                                                                       cornerRadius:3.0f];

    [[NSColor colorWithCalibratedRed:0.12 green:0.36 blue:0.81 alpha:1.0f] set];
    [dropTargetOutline setLineWidth:2.0f];
    [dropTargetOutline stroke];

    [[[NSColor colorForControlTint:NSDefaultControlTint] colorWithAlphaComponent:0.5] set];
    [dropTargetOutline fill];
  }
  else {
    // rect is a 5-pixel rect before or after the button, offset a little so this draws
    // in the right place. We take care to keep our drawing inside the rect returned from
    // -insertionHiliteRectForButton, since that rect is used to do invalidations.
    NSBezierPath* insertionPointPath = [NSBezierPath bezierPath];
    float insertionPos = floorf(NSMidX(rect));    // avoid drawing at fractional offsets
    rect = NSInsetRect(rect, 0.0f, 2.0f);

    // top Y
    const float kTipsXOffset = 3.0f;
    const float kTipsYOffset = 2.0f;
    [insertionPointPath moveToPoint:NSMakePoint(insertionPos - kTipsXOffset, NSMinY(rect))];
    [insertionPointPath lineToPoint:NSMakePoint(insertionPos, NSMinY(rect) + kTipsYOffset)];
    [insertionPointPath lineToPoint:NSMakePoint(insertionPos + kTipsXOffset, NSMinY(rect))];

    // line
    [insertionPointPath moveToPoint:NSMakePoint(insertionPos, NSMinY(rect) + kTipsYOffset)];
    [insertionPointPath lineToPoint:NSMakePoint(insertionPos, NSMaxY(rect) - kTipsYOffset)];

    // bottom Y
    [insertionPointPath moveToPoint:NSMakePoint(insertionPos - kTipsXOffset, NSMaxY(rect))];
    [insertionPointPath lineToPoint:NSMakePoint(insertionPos, NSMaxY(rect) - kTipsYOffset)];
    [insertionPointPath lineToPoint:NSMakePoint(insertionPos + kTipsXOffset, NSMaxY(rect))];

    [[NSColor colorWithCalibratedRed:0.12 green:0.36 blue:0.81 alpha:1.0f] set];
    [insertionPointPath setLineCapStyle:NSRoundLineCapStyle];
    [insertionPointPath setLineWidth:2.0f];
    [insertionPointPath stroke];
  }
}

//
// -rebuildButtonList
//
// this only gets called on startup OR window creation.  on the off chance that
// we're starting due to an appleevent from another program, we might call it twice.
// make sure nothing bad happens if we do that.
//
- (void)rebuildButtonList
{
  if (!mButtonListDirty)
    return;

  BookmarkFolder* toolbarFolder = [[BookmarkManager sharedBookmarkManager] toolbarFolder];
  if (!toolbarFolder) return;   // bookmarks haven't loaded yet

  [mButtons removeAllObjects];
  [self removeAllSubviews];

  unsigned int numItems = [toolbarFolder count];
  for (unsigned int i = 0; i < numItems; i++) {
    BookmarkButton* button = [self makeNewButtonWithItem:[toolbarFolder objectAtIndex:i]];
    if (button) {
      [self addSubview:button];
      [mButtons addObject:button];
    }
  }

  mButtonListDirty = NO;

  [self setupKeyViewLoop];

  if ([self isVisible])
    [self reflowButtons];
}

- (void)addButton:(BookmarkItem*)aItem atIndex:(int)aIndex
{
  BookmarkButton* button = [self makeNewButtonWithItem:aItem];
  if (!button)
    return;
  [self addSubview:button];
  [mButtons insertObject:button atIndex:aIndex];
  [self setupKeyViewLoop];
  if ([self isVisible])
    [self reflowButtonsStartingAtIndex:aIndex];
}

- (void)updateButton:(BookmarkItem*)aItem
{
  int count = [mButtons count];
  // XXX nasty linear search
  for (int i = 0; i < count; i++) {
    BookmarkButton* button = [mButtons objectAtIndex:i];
    if ([button bookmarkItem] == aItem) {
      BOOL needsReflow = NO;
      [button bookmarkChanged:&needsReflow];
      if (needsReflow && count > i && [self isVisible])
        [self reflowButtonsStartingAtIndex:i];
      break;
    }
  }
  [self setNeedsDisplay:YES];
}

- (void)removeButton:(BookmarkItem*)aItem
{
  int count = [mButtons count];
  for (int i = 0; i < count; i++) {
    BookmarkButton* button = [mButtons objectAtIndex:i];
    if ([button bookmarkItem] == aItem) {
      [mButtons removeObjectAtIndex:i];
      [button removeFromSuperview];
      if (count > i && [self isVisible])
        [self reflowButtonsStartingAtIndex:i];
      break;
    }
  }
  [self setNeedsDisplay:YES];
  [self setupKeyViewLoop];
}

- (void)reflowButtons
{
  [self reflowButtonsStartingAtIndex:0];
}

- (void)momentarilyHighlightButtonAtIndex:(int)aIndex
{
  BookmarkButton* button = [mButtons objectAtIndex:aIndex];
  [button highlight:YES];
  [NSTimer scheduledTimerWithTimeInterval:0.2
                                   target:self
                                 selector:@selector(unhighlightButton:)
                                 userInfo:(id)button
                                  repeats:NO];
}

- (void)unhighlightButton:(NSTimer*)timer
{
  [(BookmarkButton*)[timer userInfo] highlight:NO];
}

#define kBookmarkButtonHeight            16.0
#define kMinBookmarkButtonWidth          16.0
#define kMaxBookmarkButtonWidth         150.0
#define kBookmarkButtonHorizPadding       5.0
#define kBookmarkToolbarTopPadding        1.0
#define kBookmarkButtonVerticalPadding    1.0
#define kBookmarkToolbarBottomPadding     2.0

- (void)reflowButtonsStartingAtIndex:(int)aIndex
{
  if (![self isVisible])
    return;

  // coordinates for this view are flipped, making it easier to lay out from top left
  // to bottom right.
  float oldHeight      = [self frame].size.height;
  float computedHeight = [self computeHeight:NSWidth([self bounds]) startingAtIndex:aIndex];

  // our size has changed, readjust our view's frame and the content area
  if (computedHeight != oldHeight) {
    [super setFrame:NSMakeRect([self frame].origin.x, [self frame].origin.y + (oldHeight - computedHeight),
                               [self frame].size.width, computedHeight)];

    // tell the superview to resize its subviews
    [[self superview] resizeSubviewsWithOldSize:[[self superview] frame].size];
  }

  [self setNeedsDisplay:YES];
}

- (float)computeHeight:(float)aWidth startingAtIndex:(int)aIndex
{
  int   count         = [mButtons count];
  float curRowYOrigin = kBookmarkToolbarTopPadding;
  float curX          = kBookmarkButtonHorizPadding;

  for (int i = 0; i < count; i++) {
    BookmarkButton* button = [mButtons objectAtIndex:i];
    NSRect buttonRect;

    if (i < aIndex) {
      buttonRect = [button frame];
      curRowYOrigin = NSMinY(buttonRect) - kBookmarkButtonVerticalPadding;
      curX = NSMaxX(buttonRect) + kBookmarkButtonHorizPadding;
    }
    else {
      [button sizeToFit];
      float width = [button frame].size.width;

      if (width > kMaxBookmarkButtonWidth)
        width = kMaxBookmarkButtonWidth;

      buttonRect = NSMakeRect(curX, curRowYOrigin + kBookmarkButtonVerticalPadding, width, kBookmarkButtonHeight);
      curX += NSWidth(buttonRect) + kBookmarkButtonHorizPadding;

      if (NSMaxX(buttonRect) > aWidth) {
        // jump to the next line
        curX = kBookmarkButtonHorizPadding;
        curRowYOrigin += (kBookmarkButtonHeight + 2 * kBookmarkButtonVerticalPadding);
        buttonRect = NSMakeRect(curX, curRowYOrigin + kBookmarkButtonVerticalPadding, width, kBookmarkButtonHeight);
        curX += NSWidth(buttonRect) + kBookmarkButtonHorizPadding;
      }

      [button setFrame:buttonRect];
    }
  }

  return curRowYOrigin + (kBookmarkButtonHeight + 2 * kBookmarkButtonVerticalPadding + kBookmarkToolbarBottomPadding);
}

- (BOOL)isFlipped
{
  return YES; // Use flipped coords, so we can layout out from top row to bottom row.
}

- (void)setFrame:(NSRect)aRect
{
  NSRect oldFrame = [self frame];
  [super setFrame:aRect];

  if (oldFrame.size.width == aRect.size.width || aRect.size.height == 0)
    return;

  int count = [mButtons count];
  int reflowStart = 0;

  // find out where we need to start reflowing
  for (int i = 0; i < count; i++) {
    BookmarkButton* button = [mButtons objectAtIndex:i];
    NSRect           buttonFrame = [button frame];

    if ((NSMaxX(buttonFrame) > NSMaxX(aRect)) ||       // we're overhanging the right
        (NSMaxY(buttonFrame) > kBookmarkButtonHeight)) // we're on the second row
    {
      reflowStart = i;
      break;
    }
  }

  [self reflowButtonsStartingAtIndex:reflowStart];
}

- (BOOL)isVisible
{
  return ![self isHidden];
}

- (void)setVisible:(BOOL)isVisible
{
  [self setHidden:!isVisible];
  [[self superview] resizeSubviewsWithOldSize:[[self superview] frame].size];

  if (isVisible)
    [self reflowButtons];
}

- (void)setDrawBottomBorder:(BOOL)drawBorder
{
  if (mDrawBorder != drawBorder) {
    mDrawBorder = drawBorder;
    NSRect dirtyRect = [self bounds];
    dirtyRect.origin.y = dirtyRect.size.height - 1.0;
    dirtyRect.size.height = 1.0;
    [self setNeedsDisplayInRect:dirtyRect];
  }
}
//
// if the toolbar gets the message, we can only make a new folder.
// kinda dull.  but we'll do this on the fly.
//
- (NSMenu*)menuForEvent:(NSEvent*)aEvent
{
  NSMenu* myMenu = [[NSMenu alloc] initWithTitle:@"snookums"];
  NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Create New Folder", nil)
                                                    action:@selector(addFolder:)
                                             keyEquivalent:@""];
  [menuItem setTarget:self];
  [myMenu addItem:menuItem];
  [menuItem release];
  return [myMenu autorelease];
}

//
// context menu has only what we need
//
- (BOOL)validateMenuItem:(NSMenuItem*)aMenuItem
{
  // Window actions are disabled while a sheet is showing
  if ([[self window] attachedSheet])
    return NO;

  return YES;
}

- (IBAction)addFolder:(id)aSender
{
  BookmarkFolder* toolbar = [[BookmarkManager sharedBookmarkManager] toolbarFolder];
  BookmarkFolder* aFolder = [toolbar addBookmarkFolder];
  [aFolder setTitle:NSLocalizedString(@"NewBookmarkFolder", nil)];
}

- (void)setButtonInsertionPoint:(id <NSDraggingInfo>)sender
{
  NSPoint   dragLocation  = [sender draggingLocation];
  NSPoint   superviewLoc  = [[self superview] convertPoint:dragLocation fromView:nil]; // convert from window
  NSButton* sourceButton  = [sender draggingSource];

  mDragInsertionButton = nil;
  mDragInsertionPosition = CHInsertNone;

  // Try to find a drop anchor at or around the point until something works.
  // These methods will set mDragInsertion* as side-effects if they work.
  if (!([self findDropAnchorAtPoint:superviewLoc] ||
        [self findDropAnchorScanningFromPoint:superviewLoc withStep:(kBMBarScanningStep * -1)] ||
        [self findDropAnchorScanningFromPoint:superviewLoc withStep:kBMBarScanningStep]))
  {
    // If there's nothing on the line, then the point is probably the dead zone
    // between lines; treat that zone as the line above, and try again.
    superviewLoc.y += kBMBarScanningStep;
    if (!([self findDropAnchorAtPoint:superviewLoc] ||
          [self findDropAnchorScanningFromPoint:superviewLoc withStep:(kBMBarScanningStep * -1)] ||
          [self findDropAnchorScanningFromPoint:superviewLoc withStep:kBMBarScanningStep]))
    {
      // If nothing else worked, just toss it on the end.
      mDragInsertionButton = ([mButtons count] > 0) ? [mButtons objectAtIndex:[mButtons count] - 1] : 0;
      mDragInsertionPosition = CHInsertAfter;
    }
  }

  // If the insertion is on or next to the source button, it shouldn't be
  // treated an actual drag.
  if (mDragInsertionButton == sourceButton) {
    mDragInsertionButton = nil;
    mDragInsertionPosition = CHInsertNone;
  }
  else if (mDragInsertionPosition == CHInsertBefore ||
           mDragInsertionPosition == CHInsertAfter)
  {
    unsigned int targetButtonIndex = [mButtons indexOfObject:mDragInsertionButton];
    targetButtonIndex += (mDragInsertionPosition == CHInsertAfter) ? 1 : -1;
    if (targetButtonIndex >= 0 && targetButtonIndex < [mButtons count] &&
        [mButtons objectAtIndex:targetButtonIndex] == sourceButton)
    {
      mDragInsertionButton = nil;
      mDragInsertionPosition = CHInsertNone;
    }
  }
}

- (BOOL)findDropAnchorAtPoint:(NSPoint)testPoint
{
  NSView* foundView = [self hitTest:testPoint];
  if (foundView && [foundView isMemberOfClass:[BookmarkButton class]]) {
    BookmarkButton* targetButton = (BookmarkButton*)foundView;

    mDragInsertionButton = targetButton;
    if ([[targetButton bookmarkItem] isKindOfClass:[BookmarkFolder class]])
      mDragInsertionPosition = CHInsertInto;
    else {
      NSPoint localLocation = [[self superview] convertPoint:testPoint toView:foundView];
      mDragInsertionPosition = (localLocation.x < NSWidth([targetButton bounds]) / 2.0) ? CHInsertBefore : CHInsertAfter;
    }
    return YES;
  }
  return NO;
}

- (BOOL)findDropAnchorScanningFromPoint:(NSPoint)testPoint withStep:(int)step
{
  NSView* foundView;
  // scan horizontally until we find a bookmark or leave the view
  do {
    testPoint.x += step;
    foundView = [self hitTest:testPoint];
  } while (foundView && ![foundView isMemberOfClass:[BookmarkButton class]]);
  if (foundView && [foundView isMemberOfClass:[BookmarkButton class]]) {
    mDragInsertionButton = (BookmarkButton *)foundView;
    mDragInsertionPosition = (step < 0) ? CHInsertAfter : CHInsertBefore;
    return YES;
  }
  return NO;
}

- (BOOL)dropDestinationValid:(id <NSDraggingInfo>)sender
{
  NSPasteboard* draggingPasteboard = [sender draggingPasteboard];
  NSArray* types = [draggingPasteboard types];
  BookmarkManager *bmManager = [BookmarkManager sharedBookmarkManager];
  BookmarkFolder* toolbar = [bmManager toolbarFolder];

  if (!toolbar)
    return NO;

  if ([types containsObject:kCaminoBookmarkListPBoardType]) {
    NSArray *draggedItems = [BookmarkManager bookmarkItemsFromSerializableArray:[draggingPasteboard propertyListForType:kCaminoBookmarkListPBoardType]];
    BookmarkFolder* destFolder = nil;

    if (mDragInsertionButton == nil) {
      return NO;
    }
    else if (mDragInsertionPosition == CHInsertInto) {
      // drop onto folder
      destFolder = (BookmarkFolder*)[mDragInsertionButton bookmarkItem];
    }
    else if (mDragInsertionPosition == CHInsertBefore ||
             mDragInsertionPosition == CHInsertAfter) { // drop onto toolbar
      destFolder = toolbar;
    }

    return [bmManager isDropValid:draggedItems toFolder:destFolder];
  }

  return [draggingPasteboard containsURLData];
}

// NSDraggingDestination ///////////

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
  // we have to set the drag target before we can test for drop validation
  [self setButtonInsertionPoint:sender];

  if (![self dropDestinationValid:sender]) {
    mDragInsertionButton = nil;
    mDragInsertionPosition = CHInsertNone;
    return NSDragOperationNone;
  }

  NSDragOperation dragOpMask = [sender draggingSourceOperationMask];
  // see if the user forced copy by holding the appropriate modifier - the OS will AND the mask with the Copy flag
  if (dragOpMask == NSDragOperationCopy)
    return NSDragOperationCopy;
  if (dragOpMask & NSDragOperationGeneric)
    return NSDragOperationGeneric;

  return NSDragOperationNone;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
  if (mDragInsertionPosition)
    [self setNeedsDisplayInRect:[self insertionHiliteRectForButton:mDragInsertionButton position:mDragInsertionPosition]];

  mDragInsertionButton = nil;
  mDragInsertionPosition = CHInsertNone;
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
  if (mDragInsertionPosition)
    [self setNeedsDisplayInRect:[self insertionHiliteRectForButton:mDragInsertionButton position:mDragInsertionPosition]];

  // we have to set the drag target before we can test for drop validation
  [self setButtonInsertionPoint:sender];

  if (![self dropDestinationValid:sender]) {
    mDragInsertionButton = nil;
    mDragInsertionPosition = CHInsertNone;
    return NSDragOperationNone;
  }

  if (mDragInsertionPosition)
    [self setNeedsDisplayInRect:[self insertionHiliteRectForButton:mDragInsertionButton position:mDragInsertionPosition]];

  NSDragOperation dragOpMask = [sender draggingSourceOperationMask];
  // see if the user forced copy by holding the appropriate modifier - the OS will AND the mask with the Copy flag
  if (dragOpMask == NSDragOperationCopy)
    return NSDragOperationCopy;
  if (dragOpMask & NSDragOperationGeneric)
    return NSDragOperationGeneric;

  return NSDragOperationNone;
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
  return YES;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
  unsigned index = 0;
  BookmarkFolder* toolbar = [[BookmarkManager sharedBookmarkManager] toolbarFolder];
  if (!toolbar)
    return NO;

  if (mDragInsertionPosition == CHInsertInto) { // drop onto folder
    toolbar = (BookmarkFolder *)[mDragInsertionButton bookmarkItem];
    index = [toolbar count];
  }
  else if (mDragInsertionPosition == CHInsertBefore ||
           mDragInsertionPosition == CHInsertAfter) { // drop onto toolbar
    index = [mButtons indexOfObjectIdenticalTo:mDragInsertionButton];
    if (index == NSNotFound)
      index = [toolbar count];
    else if (mDragInsertionPosition == CHInsertAfter)
      index++;
  }
  else {
    mDragInsertionButton = nil;
    mDragInsertionPosition = CHInsertNone;
    [self setNeedsDisplay:YES];
    return NO;
  }

  BOOL dropHandled = NO;
  BOOL isCopy = ([sender draggingSourceOperationMask] == NSDragOperationCopy);

  NSArray *draggedTypes = [[sender draggingPasteboard] types];

  if ([draggedTypes containsObject:kCaminoBookmarkListPBoardType]) {
    NSArray *draggedItems = [BookmarkManager bookmarkItemsFromSerializableArray:[[sender draggingPasteboard] propertyListForType:kCaminoBookmarkListPBoardType]];
    // added sequentially, so use reverse object enumerator to preserve order.
    NSEnumerator *enumerator = [draggedItems reverseObjectEnumerator];
    id aKid;
    while ((aKid = [enumerator nextObject])) {
      if (isCopy)
        [(BookmarkFolder*)[aKid parent] copyChild:aKid toBookmarkFolder:toolbar atIndex:index];
      else
        [(BookmarkFolder*)[aKid parent] moveChild:aKid toBookmarkFolder:toolbar atIndex:index];
    }
    dropHandled = YES;
  }
  else if ([[sender draggingPasteboard] containsURLData]) {
    NSArray* urls = nil;
    NSArray* titles = nil;
    [[sender draggingPasteboard] getURLs:&urls andTitles:&titles];

    // Add in reverse order to preserve order
    for (int i = [urls count] - 1; i >= 0; --i) {
      NSString* url = [urls objectAtIndex:i];
      NSString* title = [titles objectAtIndex:i];
      if ([title length] == 0)
        title = url;
      [toolbar insertChild:[Bookmark bookmarkWithTitle:title
                                                   url:url
                                             lastVisit:nil]
                   atIndex:index
                    isMove:NO];
    }
    dropHandled = YES;
  }

  mDragInsertionButton = nil;
  mDragInsertionPosition = CHInsertNone;
  [self setNeedsDisplay:YES];
  return dropHandled;
}

- (NSRect)insertionHiliteRectForButton:(NSView*)aButton position:(int)aPosition
{
  NSRect buttonFrame = [aButton frame];

  if (aPosition == CHInsertInto)
    return NSInsetRect(buttonFrame, -kButtonRectHPadding, -kButtonRectVPadding);

  // we fudge the rect for before/after so that it's equivalent to the space between buttons,
  // and covers the insertion indicate that we draw (since we use this rect to refresh)
  NSRect gapRect;
  if (aPosition == CHInsertAfter)
    gapRect = NSMakeRect(buttonFrame.origin.x + buttonFrame.size.width, buttonFrame.origin.y, kBookmarkButtonHorizPadding, buttonFrame.size.height);
  else
    gapRect = NSMakeRect(buttonFrame.origin.x - kBookmarkButtonHorizPadding, buttonFrame.origin.y, kBookmarkButtonHorizPadding, buttonFrame.size.height);

  gapRect.origin.x -= 1.0f;   // tweak to prevent the insertion point drawing over favicons
  return NSInsetRect(gapRect, -2.0f, -2.0f);
}

- (BookmarkButton*)makeNewButtonWithItem:(BookmarkItem*)aItem
{
  return [[[BookmarkButton alloc] initWithFrame:NSMakeRect(0.0f, 0.0f, kMaxBookmarkButtonWidth, kBookmarkButtonHeight)
                                           item:aItem] autorelease];
}

- (void)setupKeyViewLoop
{
  unsigned int totalButtons = [mButtons count];
  // If the bar is empty, just make sure we pass to the next view.
  if (totalButtons == 0) {
    [self setNextKeyView:mNextExternalKeyView];
    return;
  }

  // First, point the toolbar's nextKeyView to the first button.
  [self setNextKeyView:[mButtons objectAtIndex:0]];
  
  // Then, except for the last button, connect the key view loop among each bookmark button.
  for (unsigned int i = 0; i < (totalButtons - 1); i++) {
    BookmarkButton* currentButton = [mButtons objectAtIndex:i];
    [currentButton setNextKeyView:[mButtons objectAtIndex:(i + 1)]];
  }

  // Set the last button's nextKeyView to the next external key view of the toolbar itself.
  BookmarkButton* lastButton = [mButtons objectAtIndex:(totalButtons - 1)];
  [lastButton setNextKeyView:mNextExternalKeyView];
}

#pragma mark -

- (void)bookmarkAdded:(NSNotification *)aNote
{
  BookmarkItem* changedItem = [aNote object];
  if (changedItem != [[BookmarkManager sharedBookmarkManager] toolbarFolder])
    return;

  NSDictionary *dict = [aNote userInfo];
  [self addButton:[dict objectForKey:BookmarkFolderChildKey] atIndex:[[dict objectForKey:BookmarkFolderChildIndexKey] unsignedIntValue]];
}

- (void)bookmarkRemoved:(NSNotification *)aNote
{
  BookmarkItem* changedItem = [aNote object];
  if (changedItem != [[BookmarkManager sharedBookmarkManager] toolbarFolder])
    return;

  NSDictionary *dict = [aNote userInfo];
  [self removeButton:[dict objectForKey:BookmarkFolderChildKey]];
}

- (void)bookmarkChanged:(NSNotification *)aNote
{
  BookmarkItem* changedItem = [aNote object];
  BookmarkFolder* toolbarFolder = [[BookmarkManager sharedBookmarkManager] toolbarFolder];

  if (!toolbarFolder)
    return;   // haven't finished loading bookmarks yet

  if (changedItem == toolbarFolder) {
    const unsigned int kSignificantRootChangeFlags = (kBookmarkItemTitleChangedMask |
                                                      kBookmarkItemStatusChangedMask |
                                                      kBookmarkItemChildrenChangedMask);

    if ([BookmarkItem bookmarkChangedNotificationUserInfo:[aNote userInfo] containsFlags:kSignificantRootChangeFlags]) {
      mButtonListDirty = YES;
      [self rebuildButtonList];
    }
  }
  else if ([changedItem parent] == toolbarFolder) {
    const unsigned int kSignificantItemChangeFlags = (kBookmarkItemTitleChangedMask |
                                                      kBookmarkItemIconChangedMask |
                                                      kBookmarkItemStatusChangedMask |
                                                      kBookmarkItemChildrenChangedMask);

    if ([BookmarkItem bookmarkChangedNotificationUserInfo:[aNote userInfo] containsFlags:kSignificantItemChangeFlags]) {
      // note that this gets called as we're building the toolbar for the first time, since that's
      // setting the icons on the bookmarks. It's slightly expensive, but harmless.
      [self updateButton:changedItem];
    }
  }
}

@end
