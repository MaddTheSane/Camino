/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "LocationBarPartitionView.h"

#import "NSWorkspace+Utils.h"

#import "AutoCompleteTextField.h"
#import "CHGradient.h"

// Posted just before the feed menu is going to be displayed.
NSString* const kWillShowFeedMenuNotification = @"WillShowFeedMenuNotification";

const int kPartitionViewTag = 1;

static const int kPartitionViewLeftPadding = 3;
static const int kPartitionViewFadeWidth = 30;

@interface LocationBarPartitionView (Private)
// Resizes the partition view to accommodate visible icons.
- (void)sizeToFitIcons;
@end

// Returns a retained opaque greyscale CHGradient with the given start and end
// values (in the range 0-255).
static CHGradient *CreateGreyGradientWithValues(int startValue, int endValue)
{
  float startNormalized = startValue / 255.0;
  float endNormalized = endValue / 255.0;
  NSColor *startColor = [NSColor colorWithCalibratedRed:startNormalized
                                                  green:startNormalized
                                                   blue:startNormalized
                                                  alpha:1.0];
  NSColor *endColor = [NSColor colorWithCalibratedRed:endNormalized
                                                green:endNormalized
                                                 blue:endNormalized
                                                alpha:1.0];
  return [[CHGradient alloc] initWithStartingColor:startColor
                                       endingColor:endColor];
}

@implementation LocationBarPartitionView

- (id)initWithFrame:(NSRect)frameRect
{
  if ((self = [super initWithFrame:frameRect])) {
    mTopGradient = CreateGreyGradientWithValues(253, 243);
    mBottomGradient = CreateGreyGradientWithValues(230, 230);
    mLineGradient = CreateGreyGradientWithValues(203, 218);
    mClearColor = [[NSColor colorWithDeviceRed:1.0 green:1.0 blue:1.0 alpha:0.0] retain];

    mFeedImage = [[NSImage imageNamed:@"feed"] retain];
  }
  return self;
}

- (void)dealloc
{
  [mTopGradient release];
  [mBottomGradient release];
  [mLineGradient release];
  [mClearColor release];
  [mFeedImage release];

  [mSecureImage release];
  [mSecureIconContextMenu release];

  [super dealloc];
}

- (void)drawRect:(NSRect)rect
{
  NSRect leftRect;
  NSDivideRect(rect, &leftRect, &rect, kPartitionViewFadeWidth, NSMinXEdge);
  NSRect topRect;
  NSRect bottomRect;
  NSDivideRect(rect, &bottomRect, &topRect, floor(NSHeight(rect) * 0.5), NSMinYEdge);
  [mTopGradient drawInRect:topRect angle:90.0];
  [mBottomGradient drawInRect:bottomRect angle:90.0];
  [mLineGradient drawInRect:NSMakeRect(NSMinX(rect), NSMinY(rect), 1, NSHeight(rect))
                      angle:90.0];
  NSColor *currentBackgroundColor = [(NSTextField *)[self superview] backgroundColor];
  if ([NSWorkspace isLeopardOrHigher]) {
    CHGradient *fadeGradient =
        [[[CHGradient alloc] initWithStartingColor:currentBackgroundColor
                                       endingColor:mClearColor] autorelease];
    [fadeGradient drawInRect:leftRect angle:180.0];
  }

  if (mDisplayFeedIcon)
    [mFeedImage drawAtPoint:mFeedIconRect.origin fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
  if (mDisplaySecureIcon)
    [mSecureImage drawAtPoint:mSecureIconRect.origin fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
}

- (void)setDisplayFeedIcon:(BOOL)display
{
  mDisplayFeedIcon = display;
  [self sizeToFitIcons];
}

- (void)setDisplaySecureIcon:(BOOL)display
{
  mDisplaySecureIcon = display;
  [self sizeToFitIcons];
}

- (NSMenu*)menuForEvent:(NSEvent *)theEvent
{
  [self setMenu:nil];
  NSPoint clickPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
  if (NSPointInRect(clickPoint, mFeedIconRect)) {
    [[NSNotificationCenter defaultCenter] postNotificationName:kWillShowFeedMenuNotification object:self];
  } else if (NSPointInRect(clickPoint, mSecureIconRect)) {
    [self setMenu:mSecureIconContextMenu];
  }
  return [self menu];
}

- (void)setSecureIconContextMenu:(NSMenu *)aMenu
{
  [mSecureIconContextMenu autorelease];
  mSecureIconContextMenu = [aMenu retain];
}

- (void)mouseDown:(NSEvent*)theEvent
{
  // By default a left click will not show a context menu. Since we want to show
  // the context menus on a left click, foward this mouse down event as a right
  // mouse down event: [self rightMouseDown:theEvent].
  NSPoint clickPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
  if (clickPoint.x > kPartitionViewFadeWidth - kPartitionViewLeftPadding)
    [self rightMouseDown:theEvent];
  else
    [super mouseDown:theEvent];
}

- (void)resetCursorRects
{
  [self addCursorRect:NSMakeRect(kPartitionViewFadeWidth, 0, NSWidth([self bounds]),
                                 NSHeight([self bounds])) cursor:[NSCursor arrowCursor]];
}

- (void)sizeToFitIcons
{
  int partitionFrameCount = 0;
  if (mDisplayFeedIcon)
    partitionFrameCount++;
  if (mDisplaySecureIcon)
    partitionFrameCount++;

  const int kPartitionHeight = 19;
  const int kPartitionMinY = 2;
  const int kPartitionFrameWidth = 20;
  const int kLeftHorizontalPadding = 2;
  const int kMaxIconSize = 14;

  // These two values are based on the height of the icons and
  // determine where they should be positioned vertically.
  const int kSecureIconMinY = 2;
  const int kFeedIconMinY = 3;

  // Calculate partition bounds.
  NSRect textFieldRect = [[self superview] bounds];
  NSRect frame;
  frame.size.width = partitionFrameCount * kPartitionFrameWidth;
  frame.size.height = kPartitionHeight;
  frame.origin.x = NSWidth(textFieldRect) - NSWidth(frame) - kLocationFieldFrameMargin;
  frame.origin.y = kPartitionMinY;

  // If the width is 0, there is no need to do any other work.
  // Skip to the end and set the partition frame.
  if (NSWidth(frame) > 0.0001) {
    // Add room for the fade gradient.
    frame.size.width += kLeftHorizontalPadding + kPartitionViewFadeWidth;
    frame.origin.x -= kLeftHorizontalPadding + kPartitionViewFadeWidth;
    // Calculate rects for secure icon and feed icon.
    NSRect leftRect = NSMakeRect(kPartitionViewFadeWidth + kLeftHorizontalPadding, 0, kMaxIconSize, kMaxIconSize);
    NSRect rightRect = NSOffsetRect(leftRect, kPartitionFrameWidth, 0);
    if (mDisplayFeedIcon && mDisplaySecureIcon) {
      mSecureIconRect = NSOffsetRect(rightRect, 0.5 * (kPartitionFrameWidth - [mSecureImage size].width), kSecureIconMinY);
      mFeedIconRect = NSOffsetRect(leftRect, 0.5 * (kPartitionFrameWidth - [mFeedImage size].width), kFeedIconMinY);
    } else if (mDisplayFeedIcon) {
      mSecureIconRect = NSZeroRect;
      mFeedIconRect = NSOffsetRect(leftRect, 0.5 * (kPartitionFrameWidth - [mFeedImage size].width), kFeedIconMinY);
    } else if (mDisplaySecureIcon) {
      mSecureIconRect = NSOffsetRect(leftRect, 0.5 * (kPartitionFrameWidth - [mSecureImage size].width), kSecureIconMinY);
      mFeedIconRect = NSZeroRect;
    }
  }

  [self setFrame:frame];
  [self setNeedsDisplay:YES];
}

- (float)opaqueWidth
{
  float width = NSWidth([self bounds]);
  if (width > 0.0001)
    width -= kPartitionViewFadeWidth - kPartitionViewLeftPadding;
  return width;
}

- (void)setSecureImage:(NSImage *)image
{
  [mSecureImage autorelease];
  mSecureImage = [image retain];
}

- (int)tag
{
  return kPartitionViewTag;
}

@end
