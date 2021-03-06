/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "TabButtonView.h"

#import "NSBezierPath+Utils.h"
#import "NSImage+Utils.h"
#import "NSPasteboard+Utils.h"
#import "NSString+Utils.h"

#import "BrowserTabViewItem.h"
#import "BrowserWrapper.h"
#import "RolloverImageButton.h"
#import "TruncatingTextAndImageCell.h"

#import "CHSlidingViewAnimation.h"

static const int kTabLeftMargin = 4;
static const int kTabRightMargin = 4;
static const int kTabBottomPad = 4;      // unusable bottom space on the tab
static const int kTabCloseButtonPad = 2; // distance between close button and label
static const int kTabSelectOffset = 1;   // amount to drop everything down when selected

static const float kSlidingTabAnimationDuration = 0.4f;

static NSImage* sTabLeft = nil;
static NSImage* sTabRight = nil;
static NSImage* sActiveTabBg = nil;
static NSImage* sTabMouseOverBg = nil;
static NSImage* sTabButtonDividerImage = nil;

NSString* const kSlidingTabAnimationFinishedNotification  = @"SlidingTabAnimationFinishedNotification";
NSString* const kSlidingTabAnimationFinishedCompletelyKey = @"SlidingTabAnimationDidFinishCompletely";

@interface TabButtonView (Private)

- (void)repositionSubviews;
- (void)setDragTarget:(BOOL)isDragTarget;
+ (void)loadImages;
- (void)setSlideAnimationDirection:(ESlideAnimationDirection)animationDirection;
- (void)finishAnimation:(NSNumber*)animationFinishedCompletely;

@end


@implementation TabButtonView

- (id)initWithFrame:(NSRect)frameRect andTabItem:(BrowserTabViewItem*)tabViewItem
{
  if ((self = [super initWithFrame:frameRect])) {
    mTabViewItem = (BrowserTabViewItem*)tabViewItem;

    mCloseButton = [[RolloverImageButton alloc] initWithFrame:NSMakeRect(0, 0, 16, 16)];
    [mCloseButton setImage:[BrowserTabViewItem closeIcon]];
    [mCloseButton setAlternateImage:[BrowserTabViewItem closeIconPressed]];
    [mCloseButton setHoverImage:[BrowserTabViewItem closeIconHover]];
    [mCloseButton setImagePosition:NSImageOnly];
    [mCloseButton setBezelStyle:NSShadowlessSquareBezelStyle];
    [mCloseButton setBordered:NO];
    [mCloseButton setButtonType:NSMomentaryChangeButton];
    [mCloseButton setTarget:mTabViewItem];
    [mCloseButton setAction:@selector(closeTab:)];
    [mCloseButton setAutoresizingMask:NSViewMinXMargin];
    [mCloseButton setToolTip:NSLocalizedString(@"CloseTabButtonHelpText", nil)];
    id closeButtonAccessibilityElement = NSAccessibilityUnignoredDescendant(mCloseButton);
    [closeButtonAccessibilityElement accessibilitySetOverrideValue:NSLocalizedString(@"CloseTabButtonDescription", nil)
                                                      forAttribute:NSAccessibilityDescriptionAttribute];
    [self addSubview:mCloseButton];

    mLabelCell = [[TruncatingTextAndImageCell alloc] init];
    [mLabelCell setControlSize:NSSmallControlSize];		// doesn't work?
    [mLabelCell setImagePadding:0.0];
    [mLabelCell setImageSpace:2.0];
    [mLabelCell setMaxImageHeight:[mCloseButton frame].size.height];

#ifdef USE_PROGRESS_SPINNERS
    mLoadingIndicator = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(0, 0, 16, 16)];
    [mLoadingIndicator setStyle:NSProgressIndicatorSpinningStyle];
    [mLoadingIndicator setUsesThreadedAnimation:YES];
    [mLoadingIndicator setDisplayedWhenStopped:NO];
    [mLoadingIndicator setAutoresizingMask:NSViewMaxXMargin];
#else
    mLoadingIndicator = [[NSImageView alloc] init];
    [mLoadingIndicator setImage:[NSImage imageNamed:@"tab_loading"]];
#endif

    // Don't autoresize subviews since our subview layout isn't a function of
    // just our own frame
    [self setAutoresizesSubviews:NO];
    [self repositionSubviews];

    mSlideAnimationDirection = eSlideAnimationDirectionNone;

    [self registerForDraggedTypes:[NSArray arrayWithObjects:
                                   kCaminoBookmarkListPBoardType, kWebURLsWithTitlesPboardType,
                                   NSStringPboardType, NSFilenamesPboardType, NSURLPboardType, nil]];
  }
  return self;
}

- (void)dealloc
{
  [self removeTrackingRect];
  [mLabelCell release];
  [mCloseButton release];
  [mLoadingIndicator removeFromSuperview];
  [mLoadingIndicator release];
  [mViewAnimation release];
  [super dealloc];
}

#pragma mark -

- (BrowserTabViewItem*)tabViewItem
{
  return mTabViewItem;
}

- (void)setLabel:(NSString*)label
{
  static NSDictionary* labelAttributes = nil;
  if (!labelAttributes) {
    NSMutableParagraphStyle *labelParagraphStyle = [[[NSMutableParagraphStyle alloc] init] autorelease];
    [labelParagraphStyle setParagraphStyle:[NSParagraphStyle defaultParagraphStyle]];
    [labelParagraphStyle setLineBreakMode:NSLineBreakByTruncatingMiddle];
    [labelParagraphStyle setAlignment:NSNaturalTextAlignment];

    NSFont *labelFont = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
    labelAttributes  = [[NSDictionary alloc] initWithObjectsAndKeys:
                        labelFont, NSFontAttributeName,
                        labelParagraphStyle, NSParagraphStyleAttributeName,
                        nil];
  }

  NSAttributedString* labelString = [[[NSAttributedString alloc] initWithString:label
                                                                     attributes:labelAttributes] autorelease];
  [mLabelCell setAttributedStringValue:labelString];
  [self setToolTip:label];
  [self setNeedsDisplayInRect:mLabelRect];
}

- (void)setIcon:(NSImage *)newIcon isDraggable:(BOOL)draggable
{
  [mLabelCell setImage:newIcon];
  [mLabelCell setImageAlpha:(draggable ? 1.0 : 0.6)];
  [self setNeedsDisplayInRect:mLabelRect];
}

- (void)startLoadAnimation
{
  [mLabelCell addProgressIndicator:mLoadingIndicator];
#ifdef USE_PROGRESS_SPINNERS
  [mLoadingIndicator startAnimation:self];
#endif
  [self setNeedsDisplayInRect:mLabelRect];
}

- (void)stopLoadAnimation
{
#ifdef USE_PROGRESS_SPINNERS
  [mLoadingIndicator stopAnimation:self];
#endif
  [mLabelCell removeProgressIndicator];
  [self setNeedsDisplayInRect:mLabelRect];
}

- (void)setDrawsLeftDivider:(BOOL)drawsLeftDivider
{
  mNeedsLeftDivider = drawsLeftDivider;
  [self setNeedsDisplay:YES];
}

- (void)setDrawsRightDivider:(BOOL)drawsRightDivider
{
  mNeedsRightDivider = drawsRightDivider;
  [self setNeedsDisplay:YES];
}

- (void)setCloseButtonEnabled:(BOOL)isEnabled
{
  [mCloseButton setEnabled:isEnabled];
}

- (RolloverImageButton*)closeButton
{
  return mCloseButton;
}

- (void)setMenu:(NSMenu *)aMenu
{
  // set the tag of every menu item to the tab view item's tag,
  // so that the target of the menu commands know which one they apply to.
  for (int i = 0; i < [aMenu numberOfItems]; i ++)
    [[aMenu itemAtIndex:i] setTag:[mTabViewItem tag]];

  [super setMenu:aMenu];
}

#pragma mark -

- (void)setFrame:(NSRect)frameRect
{
  [super setFrame:frameRect];
  [self repositionSubviews];
  [self setNeedsDisplay:YES];
}

// Note: if the tab drawing system ever changes such that the bar isn't rebuilt
// whenever the active tab changes (thus calling setFrame:), this will need be
// called when the tab is selected or unselected.
- (void)repositionSubviews
{
  const float kTextHeight = 16.0; // XXX this probably shouldn't be hard-coded

  // center based on the larger of the two heights if there's a difference
  NSRect tabRect = [self bounds];
  NSRect buttonRect = [mCloseButton frame];
  float maxHeight = kTextHeight > NSHeight(buttonRect) ? kTextHeight : NSHeight(buttonRect);
  buttonRect.origin = NSMakePoint(kTabLeftMargin,
                                 (int)((NSHeight(tabRect) - kTabBottomPad - maxHeight)/2.0 + kTabBottomPad));
  mLabelRect = NSMakeRect(NSMaxX(buttonRect) + kTabCloseButtonPad,
                          (int)((NSHeight(tabRect) - kTabBottomPad - maxHeight)/2.0 + kTabBottomPad),
                          NSWidth(tabRect) - (NSMaxX(buttonRect) + kTabCloseButtonPad + kTabRightMargin),
                          kTextHeight);

  if ([mTabViewItem tabState] == NSSelectedTab) {
    // move things down a little, to give the impression of being pulled forward
    mLabelRect.origin.y -= kTabSelectOffset;
    buttonRect.origin.y -= kTabSelectOffset;
  }

  [mCloseButton setFrame:buttonRect];
}

- (void)drawRect:(NSRect)rect
{
  if (!(sTabLeft && sTabRight && sActiveTabBg && sTabMouseOverBg && sTabButtonDividerImage))
    [TabButtonView loadImages];

  NSRect tabRect = [self bounds];

  if (mNeedsLeftDivider) {
    NSPoint dividerOrigin = NSMakePoint(NSMinX(tabRect), 0);
    [sTabButtonDividerImage compositeToPoint:dividerOrigin
                                   operation:NSCompositeSourceOver];
  }

  if (mNeedsRightDivider) {
    tabRect.size.width -= [sTabButtonDividerImage size].width;
    NSPoint dividerOrigin = NSMakePoint(NSMaxX(tabRect), 0);
    [sTabButtonDividerImage compositeToPoint:dividerOrigin
                                   operation:NSCompositeSourceOver];
  }

  NSPoint patternOrigin = [self convertPoint:NSMakePoint(0, 0) toView:[[self window] contentView]];
  if ([mTabViewItem tabState] == NSSelectedTab) {
    // XXX would it be better to maintain a CGContext and do a real gradient here?
    // it sounds heavier, but I haven't tested to be sure. This looks just as nice so long as
    // the tabbar height is fixed.
    NSRect bgRect = tabRect;
    bgRect.origin.x += [sTabLeft size].width;
    bgRect.size.width -= ([sTabRight size].width + [sTabLeft size].width);
    [sActiveTabBg drawTiledInRect:tabRect origin:patternOrigin operation:NSCompositeSourceOver];
    [sTabLeft compositeToPoint:tabRect.origin operation:NSCompositeSourceOver];
    [sTabRight compositeToPoint:NSMakePoint(NSMaxX(bgRect), bgRect.origin.y) operation:NSCompositeSourceOver];
  } else if (mMouseWithin && !mIsDragTarget && [[self window] isKeyWindow]) {
    [sTabMouseOverBg drawTiledInRect:tabRect origin:patternOrigin operation:NSCompositeSourceOver];
  }
  // TODO: Make this look nicer
  if (mIsDragTarget) {
    NSRect dropFrame = tabRect;
    dropFrame.origin.y += kTabBottomPad;
    dropFrame.size.height -= kTabBottomPad;
    NSBezierPath* dropTargetOutline = [NSBezierPath bezierPathWithRoundCorneredRect:dropFrame
                                                                       cornerRadius:2.0f];
    [[[NSColor colorForControlTint:NSDefaultControlTint] colorWithAlphaComponent:0.5] set];
    [dropTargetOutline fill];
  }

  [mLabelCell setShowsFirstResponder:NO];
  [mLabelCell drawInteriorWithFrame:mLabelRect inView:self];

  // Draw a focus rect on the tab if we are the current key view.
  if ([[self window] firstResponder] == self) {
    [NSGraphicsContext saveGraphicsState];
    NSSetFocusRingStyle(NSFocusRingOnly);
    [[NSBezierPath bezierPathWithRect:mLabelRect] fill];
    [NSGraphicsContext restoreGraphicsState];    
  }
}

#pragma mark -

- (void)viewWillMoveToWindow:(NSWindow*)window
{
  [self removeTrackingRect];
  [super viewWillMoveToWindow:window];
}

-(void)addTrackingRect
{
  if (mTrackingTag)
    [self removeTrackingRect];

  NSPoint mouseLocation = [[self window] convertScreenToBase:[NSEvent mouseLocation]];
  mouseLocation = [self convertPoint:mouseLocation fromView:nil];
  mMouseWithin = NSPointInRect(mouseLocation, [self bounds]);
  mTrackingTag = [self addTrackingRect:[self bounds]
                                  owner:self
                               userData:nil
                           assumeInside:mMouseWithin];
  if (mMouseWithin)
    [mCloseButton setTrackingEnabled:YES];
}

-(void)removeTrackingRect
{
  if (mTrackingTag)
    [self removeTrackingRect:mTrackingTag];
  mTrackingTag = 0;
  [mCloseButton setTrackingEnabled:NO];
}

-(void)updateHoverState:(BOOL)isHovered
{
  [mCloseButton setTrackingEnabled:isHovered];
  mMouseWithin = isHovered;
  [self setNeedsDisplay:YES];
}

- (void)mouseEntered:(NSEvent *)theEvent
{
  mMouseWithin = YES;
  // only act on the mouseEntered if the we are active or accept the first mouse click
  if ([[self window] isKeyWindow] || [self acceptsFirstMouse:theEvent]) {
    [mCloseButton setTrackingEnabled:YES];
    [self setNeedsDisplay:YES];
    // calling displayIfNeeded prevents the "lag" observed when displaying rollover events
    [self displayIfNeeded];
  }
}

- (void)mouseExited:(NSEvent*)theEvent
{
  mMouseWithin = NO;
  // only act on the mouseExited if the we are active or accept the first mouse click
  if ([[self window] isKeyWindow] || [self acceptsFirstMouse:theEvent]) {
    [mCloseButton setTrackingEnabled:NO];
	  [self setNeedsDisplay:YES];
    // calling displayIfNeeded prevents the "lag" observed when displaying rollover events
    [self displayIfNeeded];
  }
}

#pragma mark -

- (void)setDragTarget:(BOOL)isDragTarget
{
  mMouseWithin = isDragTarget;

  if (mIsDragTarget != isDragTarget) {
    mIsDragTarget = isDragTarget;
    [self setNeedsDisplay:YES];
    [self displayIfNeeded];
  }
}

// NSDraggingDestination destination methods
- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
  if (![mTabViewItem shouldAcceptDrag:sender])
    return NSDragOperationNone;

  [self setDragTarget:YES];

  if ([sender draggingSourceOperationMask] & NSDragOperationCopy)
    return NSDragOperationCopy;

  return NSDragOperationGeneric;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
  [self setDragTarget:NO];
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
  return YES;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
  [self setDragTarget:NO];

  return [mTabViewItem handleDrop:sender];
}

#pragma mark -

- (unsigned int)draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
  if (isLocal)
    return (NSDragOperationGeneric | NSDragOperationCopy);

  return (NSDragOperationGeneric | NSDragOperationCopy | NSDragOperationLink);
}

#pragma mark -

- (void)mouseDown:(NSEvent *)theEvent
{
  NSRect  iconRect   = [self convertRect:[mLabelCell imageFrame] fromView:nil];
  NSPoint localPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];

  // Don't select the tab when the click is on the icon, so that background
  // tabs are draggable.
  if (NSPointInRect(localPoint, iconRect) && [mTabViewItem draggable]) {
    mSelectTabOnMouseUp = YES;
    return;
  }

  mSelectTabOnMouseUp = NO;
  [[NSNotificationCenter defaultCenter] postNotificationName:kTabWillChangeNotification object:mTabViewItem];
  [[mTabViewItem tabView] selectTabViewItem:mTabViewItem];
}

- (void)mouseUp:(NSEvent *)theEvent
{
  if (mSelectTabOnMouseUp) {
    [[NSNotificationCenter defaultCenter] postNotificationName:kTabWillChangeNotification object:mTabViewItem];
    [[mTabViewItem tabView] selectTabViewItem:mTabViewItem];
    mSelectTabOnMouseUp = NO;
  }
}

- (void)mouseDragged:(NSEvent*)theEvent
{
  NSRect  iconRect   = [self convertRect:[mLabelCell imageFrame] fromView:nil];//NSMakeRect(0, 0, 16, 16);
  NSPoint localPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];

  if (!NSPointInRect(localPoint, iconRect) || ![mTabViewItem draggable])
    [super mouseDragged:theEvent];
  
  // only initiate the drag if the original mousedown was in the right place...
  // implied by mSelectTabOnMouseUp
  if (mSelectTabOnMouseUp) {
    mSelectTabOnMouseUp = NO;

    BrowserWrapper* browserView = (BrowserWrapper*)[mTabViewItem view];

    NSString     *url = [browserView currentURI];
    NSString     *title = [mLabelCell stringValue];
    NSString     *cleanedTitle = [title stringByReplacingCharactersInSet:[NSCharacterSet controlCharacterSet] withString:@" "];

    NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
    [pboard declareURLPasteboardWithAdditionalTypes:[NSArray array] owner:self];
    [pboard setDataForURL:url title:cleanedTitle];

    NSPoint dragOrigin = [self frame].origin;
    dragOrigin.y += [self frame].size.height;

    [self dragImage:[NSImage dragImageWithIcon:[mLabelCell image] title:title]
                 at:iconRect.origin
             offset:NSMakeSize(0.0, 0.0)
              event:theEvent
         pasteboard:pboard
             source:self
          slideBack:YES];
  }
}

- (BOOL)mouseDownCanMoveWindow
{
  return NO;
}

#pragma mark -

+(void)loadImages
{
  if (!sTabLeft)
      sTabLeft             = [[NSImage imageNamed:@"tab_left_side"] retain];
  if (!sTabRight)
    sTabRight              = [[NSImage imageNamed:@"tab_right_side"] retain];
  if (!sActiveTabBg)
    sActiveTabBg           = [[NSImage imageNamed:@"tab_active_bg"] retain];
  if (!sTabMouseOverBg)
    sTabMouseOverBg        = [[NSImage imageNamed:@"tab_hover"] retain];
  if (!sTabButtonDividerImage)
    sTabButtonDividerImage = [[NSImage imageNamed:@"tab_button_divider"] retain];
}

#pragma mark -

- (BOOL)accessibilityIsIgnored
{
  return NO;
}

- (NSArray*)accessibilityAttributeNames
{
  NSMutableArray* attributes = [[[super accessibilityAttributeNames] mutableCopy] autorelease];
  [attributes addObject:NSAccessibilityLinkedUIElementsAttribute];
  [attributes addObject:NSAccessibilityTitleAttribute];
  [attributes addObject:NSAccessibilityEnabledAttribute];
  [attributes addObject:NSAccessibilityValueAttribute];
  // Accessibility doesn't like buttons to have children, so we suppress the
  // close box.
  [attributes removeObject:NSAccessibilityChildrenAttribute];
  [attributes removeObject:NSAccessibilitySelectedChildrenAttribute];
  return attributes;
}

- (NSArray*)accessibilityActionNames
{
  // The superclass actions are wrong, since for accessibility purposes the
  // tabs are actually radio buttons, so don't bother calling through.
  return [NSArray arrayWithObject:NSAccessibilityPressAction];
}

- (void)accessibilityPerformAction:(NSString *)action
{
  if ([action isEqual:NSAccessibilityPressAction]) {
    [[NSNotificationCenter defaultCenter] postNotificationName:kTabWillChangeNotification object:mTabViewItem];
    [[mTabViewItem tabView] selectTabViewItem:mTabViewItem];
  }
}

- (id)accessibilityAttributeValue:(NSString*)attribute
{
  if ([attribute isEqual:NSAccessibilityRoleAttribute]) {
    // This is what NSTabViews return, so emulate them.
    return NSAccessibilityRadioButtonRole;
  }
  if ([attribute isEqual:NSAccessibilityTitleAttribute]) {
    return [mLabelCell stringValue];
  }
  if ([attribute isEqual:NSAccessibilityValueAttribute]) {
    return [NSNumber numberWithBool:([mTabViewItem tabState] == NSSelectedTab)];
  }
  if ([attribute isEqual:NSAccessibilityEnabledAttribute]) {
    return [NSNumber numberWithBool:YES];
  }
  if ([attribute isEqual:NSAccessibilityLinkedUIElementsAttribute]) {
    if ([mTabViewItem tabState] == NSSelectedTab)
      return [NSArray arrayWithObject:[mTabViewItem view]];
    else
      return [NSArray array];
  }
  
  return [super accessibilityAttributeValue:attribute];
}

- (BOOL)accessibilityIsAttributeSettable:(NSString *)attribute
{
  if ([attribute isEqual:NSAccessibilityLinkedUIElementsAttribute] ||
      [attribute isEqual:NSAccessibilityTitleAttribute] ||
      [attribute isEqual:NSAccessibilityEnabledAttribute] ||
      [attribute isEqual:NSAccessibilityValueAttribute])
  {
    return NO;
  }
  return [super accessibilityIsAttributeSettable:attribute];
}

#pragma mark -

- (BOOL)canBecomeKeyView
{
  // This a hack; NSView isn't smart about conditionally accepting first
  // responder only when FKA is enabled, but NSButton apparently is, so
  // piggy-back on our close button to get this information (there's no API;
  // WebKit gets the information by manually reading the pref from the
  // accessibility domain then watching for an undocumented notification).
  // Perhaps we should look into making our tabs controls/buttons instead of
  // views?
  //
  // mCloseButton will also return NO when it's disabled, so enable it before
  // asking, then put it back.
  BOOL closeButtonEnabled = [[self closeButton] isEnabled];
  [self setCloseButtonEnabled:YES];
  BOOL canBecomeKey = [mCloseButton canBecomeKeyView];
  [self setCloseButtonEnabled:closeButtonEnabled];
  return canBecomeKey;
}

- (BOOL)acceptsFirstResponder
{
  return YES;
}

- (BOOL)becomeFirstResponder
{
  // The TabButton should not become the key view (and draw a focus rect) if it was clicked
  // on with the mouse.  Only becomeFirstResponder when tabbing from the previous key view.
  if ([[NSApp currentEvent] type] != NSKeyDown)
    return NO;

  [self setNeedsDisplay:YES];
  return YES;
}

- (BOOL)resignFirstResponder
{
  [self setNeedsDisplay:YES];
  return YES;
}

- (void)keyDown:(NSEvent *)theEvent
{
  // If the spacebar key is pressed while we are the window's first responder, it should simulate
  // a mouse click and select the highlighted tab.
  if ([[self window] firstResponder] == self &&
      [[theEvent characters] isEqualToString:@" "])
  {
    [[NSNotificationCenter defaultCenter] postNotificationName:kTabWillChangeNotification object:mTabViewItem];
    [[mTabViewItem tabView] selectTabViewItem:mTabViewItem];
  }
  else
  {
    [super keyDown:theEvent];
  }
}

#pragma mark -

- (void)setSlideAnimationDirection:(ESlideAnimationDirection)animationDirection
{
  mSlideAnimationDirection = animationDirection;
}

- (ESlideAnimationDirection)slideAnimationDirection;
{
  return mSlideAnimationDirection;
}

- (void)slideToLocation:(NSPoint)newLocation
{
  NSPoint currentLocation = [self frame].origin;

  // Avoid sliding if we're already moving in the same direction.
  if (mSlideAnimationDirection == eSlideAnimationDirectionRight && 
      newLocation.x > currentLocation.x)
  {
    return;
  }

  if ([mViewAnimation isAnimating])
    [mViewAnimation stopAnimation];

  [self setDrawsLeftDivider:YES];
  [self setDrawsRightDivider:YES];

  if (!mViewAnimation) {
    mViewAnimation = [[CHSlidingViewAnimation alloc] initWithAnimationTarget:self];
    [mViewAnimation setDuration:kSlidingTabAnimationDuration];
    [mViewAnimation setFrameRate:0.0f]; // 0.0 -> Go as fast as possible.
    [mViewAnimation setAnimationBlockingMode:NSAnimationNonblockingThreaded];
    [mViewAnimation setAnimationCurve:NSAnimationEaseInOut];
    [mViewAnimation setDelegate:self];
  }

  [mViewAnimation setStartLocation:currentLocation];
  [mViewAnimation setEndLocation:newLocation];

  if (newLocation.x > currentLocation.x)
    [self setSlideAnimationDirection:eSlideAnimationDirectionRight];
  else
    [self setSlideAnimationDirection:eSlideAnimationDirectionLeft];

  // Our tooltip rects remain stuck in the original location when animating,
  // so we need to disable them when animating.
  [self setToolTip:nil];
  [mCloseButton setToolTip:nil];

  [mViewAnimation startAnimation];
}

- (void)stopSliding
{
  [mViewAnimation stopAnimation];
}

// Note: If the animation's blocking mode is set to |NSAnimationNonblockingThreaded|,
// this delegate method will be called on a background thread.
- (void)animationDidStop:(NSAnimation*)animation
{
  [self performSelectorOnMainThread:@selector(finishAnimation:) 
                         withObject:[NSNumber numberWithBool:NO]
                      waitUntilDone:YES];
}

// Note: If the animation's blocking mode is set to |NSAnimationNonblockingThreaded|,
// this delegate method will be called on a background thread.
- (void)animationDidEnd:(NSAnimation*)animation
{
  [self performSelectorOnMainThread:@selector(finishAnimation:) 
                         withObject:[NSNumber numberWithBool:YES]
                      waitUntilDone:YES];
}

- (void)finishAnimation:(NSNumber*)animationFinishedCompletely;
{
  [self setSlideAnimationDirection:eSlideAnimationDirectionNone];

  NSDictionary *notificationUserInfo = 
    [NSDictionary dictionaryWithObject:animationFinishedCompletely 
                                forKey:kSlidingTabAnimationFinishedCompletelyKey];
  [[NSNotificationCenter defaultCenter] postNotificationName:kSlidingTabAnimationFinishedNotification
                                                      object:self
                                                    userInfo:notificationUserInfo];

  // Restore the tool tips that were disabled while animating.
  [self setToolTip:[mLabelCell stringValue]];
  [mCloseButton setToolTip:NSLocalizedString(@"CloseTabButtonHelpText", nil)];

  // NSAnimation does not seem to clean up threads appropriately. Creating a new animation
  // each time prevents our thread count from getting out of control.
  [mViewAnimation release];
  mViewAnimation = nil;
}

@end
