/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
* License, v. 2.0. If a copy of the MPL was not distributed with this
* file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "ThumbnailView.h"

#import <Carbon/Carbon.h>

static const int kShadowX = 0;
static const int kShadowY = -3;
static const int kShadowRadius = 5;
static const int kShadowPadding = 5;
static const int kThumbnailTitleHeight = 20;

@interface ThumbnailView (Private)
// Causes the browser to select the tab corresponding to this thumbnail.
- (void)selectTab;
@end


@implementation ThumbnailView

- (id)initWithFrame:(NSRect)frame {
  if ((self = [super initWithFrame:frame])) {
    mThumbnail = nil;
    mTitleCell = [[NSCell alloc] initTextCell:@""];
    [mTitleCell setLineBreakMode:NSLineBreakByTruncatingTail];
    [mTitleCell setAlignment:NSCenterTextAlignment];
  }

  return self;
}

- (void)setThumbnail:(NSImage*)image
{
  if (image != mThumbnail) {
    [mThumbnail release];
    mThumbnail = [image retain];
    [self setNeedsDisplay:YES];
  }
}

- (void)setTitle:(NSString*)title
{
  [mTitleCell setTitle:title];
  [self setToolTip:title];
}

- (void)setRepresentedObject:(id)object
{
  if (mRepresentedObject != object) {
    [mRepresentedObject release];
    mRepresentedObject = [object retain];
  }
}

- (id)representedObject;
{
  return mRepresentedObject;
}

- (void)setDelegate:(id)delegate
{
  mDelegate = delegate;
}

- (id)delegate
{ 
  return mDelegate;
}

- (BOOL)acceptsFirstResponder
{
  return YES;
}

- (BOOL)becomeFirstResponder
{
  [self setNeedsDisplay:YES];
  return YES;
}

- (BOOL)resignFirstResponder
{
  [self setNeedsDisplay:YES];
  return YES;
}

- (void)drawRect:(NSRect)rect
{
  NSShadow* shadow = [[[NSShadow alloc] init] autorelease];
  [shadow setShadowOffset:NSMakeSize(kShadowX, kShadowY)];
  [shadow setShadowBlurRadius:kShadowRadius];
  [shadow set];

  NSRect thumbnailImageRect;
  NSRect thumbnailTitleRect;
  NSDivideRect([self bounds], &thumbnailTitleRect, &thumbnailImageRect, kThumbnailTitleHeight, NSMinYEdge);

  if (mThumbnail) {
    [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
    [mThumbnail setScalesWhenResized:YES];
    // Adjust the target drawing area as necessary to preserve aspect ratio.
    float xScaleFactor = thumbnailImageRect.size.width / [mThumbnail size].width;
    float yScaleFactor = thumbnailImageRect.size.height / [mThumbnail size].height;
    if (xScaleFactor < yScaleFactor) {
      thumbnailImageRect.size.height = [mThumbnail size].height * xScaleFactor;
    }
    else {
      thumbnailImageRect.size.width = [mThumbnail size].width * yScaleFactor;
      thumbnailImageRect.origin.x = ([self bounds].size.width - thumbnailImageRect.size.width) / 2.0;
    }

    NSRect insetRect = NSInsetRect(thumbnailImageRect, kShadowPadding, kShadowPadding);
    [mThumbnail drawInRect:insetRect
                  fromRect:NSZeroRect
                 operation:NSCompositeSourceOver
                  fraction:1];
    if ([[self window] firstResponder] == self) {
      CGRect focusRect = CGRectMake(insetRect.origin.x, insetRect.origin.y,
                                    insetRect.size.width, insetRect.size.height);
      HIThemeDrawFocusRect(&focusRect, true,
                           [[NSGraphicsContext currentContext] graphicsPort],
                           kHIThemeOrientationNormal);
    }
  }

  if (mTitleCell)
    [mTitleCell drawWithFrame:thumbnailTitleRect inView:self];
}

- (void)mouseUp:(NSEvent*)theEvent
{
  NSPoint location = [self convertPoint:[theEvent locationInWindow]
                               fromView:nil];
  if (NSPointInRect(location, [self bounds]))
    [self selectTab];
}

- (void)keyDown:(NSEvent*)theEvent
{
  if (([theEvent modifierFlags] & NSDeviceIndependentModifierFlagsMask) == 0 &&
      [[theEvent charactersIgnoringModifiers] isEqualToString:@" "]) {
    [self selectTab];
    return;
  }
  [super keyDown:theEvent];
}

- (void)selectTab
{
  if ([mDelegate respondsToSelector:@selector(thumbnailViewWasSelected:)])
    [mDelegate thumbnailViewWasSelected:self];
}

- (void)dealloc
{
  [mThumbnail release];
  [mTitleCell release];
  [mRepresentedObject release];
  [super dealloc];
}

@end
