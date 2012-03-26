/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "RolloverImageButton.h"

@interface RolloverImageButton (Private)

- (void)updateImage:(BOOL)inIsInside;
- (BOOL)isMouseInside;
- (void)removeTrackingRect;
- (void)updateTrackingRect;
- (void)setupDefaults;

@end

@implementation RolloverImageButton

- (id)initWithFrame:(NSRect)inFrame
{
  if ((self = [super initWithFrame:inFrame]))
    [self setupDefaults];

  return self;
}

- (void)awakeFromNib
{
  [self setupDefaults];
}

- (void)setupDefaults
{
  mTrackingTag = -1;
  mTrackingIsEnabled = YES;
}

- (void)dealloc
{
  [self removeTrackingRect];
  [mImage release];
  [mHoverImage release];
  
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc removeObserver:self];
  [super dealloc];
}

- (void)setEnabled:(BOOL)inStatus
{
  [super setEnabled:inStatus];
  if ([self isEnabled])
    [self updateTrackingRect];
  else {
    [self updateImage:NO];
    [self removeTrackingRect];
  }
}

- (void)setTrackingEnabled:(BOOL)enableTracking
{
  mTrackingIsEnabled = enableTracking;
  if (mTrackingIsEnabled)
    [self updateTrackingRect];
  else
    [self removeTrackingRect];
}

- (void)viewWillMoveToWindow:(NSWindow*)window
{
  [self removeTrackingRect];
  // unregister the button from observering the current window
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super viewWillMoveToWindow:window];
}

- (void)viewDidMoveToWindow
{
  [self updateTrackingRect];
  if ([self window]) {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(handleWindowIsKey:)
          name:NSWindowDidBecomeKeyNotification object:[self window]];
    [nc addObserver:self selector:@selector(handleWindowResignKey:)
          name:NSWindowDidResignKeyNotification object:[self window]];
  }
}

- (void)setBounds:(NSRect)inBounds
{
  [super setBounds:inBounds];
  [self updateTrackingRect];
}

- (void)setFrame:(NSRect)inFrame
{
  NSRect oldFrame = [self frame];
  // setFrame: is implemented in terms of setFrameOrigin: and setFrameSize:.
  // We can't rely on it, since it's undocumented, but while it's true we don't
  // want to do three times as much work for every frame update, so check.
  mSettingFrame = YES;
  [super setFrame:inFrame];
  mSettingFrame = NO;
  if (!NSEqualRects(oldFrame, [self frame]))
    [self updateTrackingRect];
}

- (void)setFrameOrigin:(NSPoint)inOrigin
{
  NSPoint oldOrigin = [self frame].origin;
  [super setFrameOrigin:inOrigin];
  if (!mSettingFrame && !NSEqualPoints(oldOrigin,[self frame].origin))
    [self updateTrackingRect];
}

- (void)setFrameSize:(NSSize)inSize
{
  NSSize oldSize = [self frame].size;
  [super setFrameSize:inSize];
  if (!mSettingFrame && !NSEqualSizes(oldSize,[self frame].size))
    [self updateTrackingRect];
}

- (void)mouseEntered:(NSEvent*)theEvent
{
  if (([[self window] isKeyWindow] || [self acceptsFirstMouse:theEvent])
    && [theEvent trackingNumber] == mTrackingTag)
      [self updateImage:YES];
}

- (void)mouseExited:(NSEvent*)theEvent
{
  if (([[self window] isKeyWindow] || [self acceptsFirstMouse:theEvent]) 
    && [theEvent trackingNumber] == mTrackingTag) 
      [self updateImage:NO];
}

- (void)mouseDown:(NSEvent*)theEvent
{
  [self updateImage:NO];
  // [super mouseDown:] might destroy this object (e.g., the tab close button),
  // so make sure that the updateImage is safe.
  [[self retain] autorelease];
  [super mouseDown:theEvent];
  // update button's image based on location of mouse after button has been released
  [self updateImage:[self isMouseInside]];
}

- (BOOL)acceptsFirstMouse:(NSEvent*)theEvent
{
  return NO;
}

- (void)setImage:(NSImage*)inImage
{
  if (mImage != inImage) {
    [mImage release];
    mImage = [inImage retain];
    [self updateImage:[self isMouseInside]];
  }
}

- (void)setHoverImage:(NSImage*)inImage
{
  if (mHoverImage != inImage) {
    [mHoverImage release];
    mHoverImage = [inImage retain];
    [self updateImage:[self isMouseInside]];
  }
}

- (void)handleWindowIsKey:(NSWindow *)inWindow
{
  [self updateImage:[self isMouseInside]];
}

- (void)handleWindowResignKey:(NSWindow *)inWindow
{
  [self updateImage:NO];
}

- (void)resetCursorRects
{
  [self updateTrackingRect];
}

- (void)updateImage:(BOOL)inIsInside
{
  if (inIsInside) {
    if ([self isEnabled])
      [super setImage:mHoverImage];
  }
  else
    [super setImage:mImage];
}

- (BOOL)isMouseInside
{
  NSPoint mousePointInWindow = [[self window] convertScreenToBase:[NSEvent mouseLocation]];
  NSPoint mousePointInView = [self convertPoint:mousePointInWindow fromView:nil];
  return NSMouseInRect(mousePointInView, [self bounds], NO);
}

- (void)removeTrackingRect
{
  if (mTrackingTag != -1) {
    [self removeTrackingRect:mTrackingTag];
    mTrackingTag = -1;
    [self updateImage:NO];
  }
}

- (void)updateTrackingRect
{
  if (!mTrackingIsEnabled)
    return;
  [self removeTrackingRect];
  BOOL mouseInside = [self isMouseInside];
  mTrackingTag = [self addTrackingRect:[self bounds] owner:self userData:nil assumeInside:mouseInside];
  [self updateImage:mouseInside];
}

@end
