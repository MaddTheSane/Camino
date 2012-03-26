/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "NSView+Utils.h"

#import "CHStackView.h"

@interface NSObject(PrivateAPI)
+ (BOOL)isInInterfaceBuilder;
+ (BOOL)editingInInterfaceBuilder;
@end

@interface CHShrinkWrapView(Private)

+ (BOOL)drawPlacementRect;

- (void)setupNotifications;
- (void)viewBoundsChangedNotification:(NSNotification*)inNotification;
- (void)viewFrameChangedNotification:(NSNotification*)inNotification;
- (void)recalcPadding;

@end

#pragma mark -

@implementation CHShrinkWrapView

- (id)initWithFrame:(NSRect)inFrame
{
  if ((self = [super initWithFrame:inFrame]))
  {
    [self setupNotifications];
  }
  return self;
}

- (id)initWithCoder:(NSCoder *)decoder
{
  if ((self = [super initWithCoder:decoder]))
  {
    [self setupNotifications];
  }
  
  return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
  [super encodeWithCoder:coder];
}

- (void)awakeFromNib
{
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super dealloc];
}

- (void)drawRect:(NSRect)inRect
{
  if ([NSObject respondsToSelector:@selector(editingInInterfaceBuilder)] &&
      [NSObject editingInInterfaceBuilder])
  {
    [[NSColor blueColor] set];
    NSFrameRect([self bounds]);
  } 
}

- (void)setIntrinsicPadding:(float)inPadding forEdge:(NSRectEdge)inEdge
{
  if ((int)inEdge < 0 || (int)inEdge > 3)
    return;

  mIntrinsicPadding[inEdge] = inPadding;
  mPaddingSetManually = YES;
}

- (void)setNoIntrinsicPadding
{
  mIntrinsicPadding[NSMinXEdge] = 0.0f;
  mIntrinsicPadding[NSMinYEdge] = 0.0f;
  mIntrinsicPadding[NSMaxXEdge] = 0.0f;
  mIntrinsicPadding[NSMaxYEdge] = 0.0f;
  mPaddingSetManually = YES;
}

- (float)paddingForEdge:(NSRectEdge)inEdge
{
  if ((int)inEdge < 0 || (int)inEdge > 3)
    return 0.0f;

  return mIntrinsicPadding[inEdge];
}

- (void)didAddSubview:(NSView *)subview
{
  [subview setPostsBoundsChangedNotifications:YES];
  [subview setPostsFrameChangedNotifications:YES];
  
  mFetchedIntrinsicPadding = NO;
}

- (void)willRemoveSubview:(NSView *)subview
{
}

- (void)viewDidMoveToWindow
{
  if ([self window])
  {
    [self adaptToSubviews];
  }
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldBoundsSize
{
  BOOL alreadyResizing = mSelfResizing;

  // avoid layout out our subviews once for every subview resize...
  mSelfResizing = YES;
  [super resizeSubviewsWithOldSize:oldBoundsSize];
  mSelfResizing = alreadyResizing;
  
  // ...by doing it just once here
  if (!alreadyResizing)
    [self adaptToSubviews];
}

- (void)recalcPadding
{
  if (mPaddingSetManually || mFetchedIntrinsicPadding)
    return;

  NSRect subframeBounds = NSZeroRect;
  NSEnumerator* subviewsEnum = [[self subviews] objectEnumerator];
  NSView* curSubView;
  while ((curSubView = [subviewsEnum nextObject]))
  {
    NSRect subviewFrame = [curSubView frame];
    subframeBounds = NSUnionRect(subviewFrame, subframeBounds);
  }
  
  NSRect myBounds = [self bounds];
  mIntrinsicPadding[NSMinXEdge] = NSMinX(subframeBounds);
  mIntrinsicPadding[NSMinYEdge] = NSMinY(subframeBounds);
  mIntrinsicPadding[NSMaxXEdge] = NSWidth(myBounds)  - NSMaxX(subframeBounds);
  mIntrinsicPadding[NSMaxYEdge] = NSHeight(myBounds) - NSMaxY(subframeBounds);
  
  mFetchedIntrinsicPadding = YES;
}

- (void)adaptToSubviews
{
  // we can't rely on -awakeFromNib being called in any particular order,
  // so we have to call -recalcPadding here, rather than from -awakeFromNib.
  [self recalcPadding];
    
  if (mSelfResizing) return;

  if ([NSObject respondsToSelector:@selector(editingInInterfaceBuilder)] &&
      [NSObject editingInInterfaceBuilder])
  {
    return;
  }

#if 0
  NSLog(@"%@ padding: %f %f %f %f", self, mIntrinsicPadding[0],
                                          mIntrinsicPadding[1],
                                          mIntrinsicPadding[2],
                                          mIntrinsicPadding[3]);
#endif


  NSRect subframeBounds = NSZeroRect;
  NSEnumerator* subviewsEnum = [[self subviews] objectEnumerator];
  NSView* curSubView;
  while ((curSubView = [subviewsEnum nextObject]))
  {
    NSRect subviewFrame = [curSubView frame];
    subframeBounds = NSUnionRect(subviewFrame, subframeBounds);
  }

  subframeBounds.origin.x = mIntrinsicPadding[NSMinXEdge];
  subframeBounds.origin.y = mIntrinsicPadding[NSMinYEdge];

  subframeBounds.size.width  += mIntrinsicPadding[NSMaxXEdge];
  subframeBounds.size.height += mIntrinsicPadding[NSMaxYEdge];
  
  NSSize curSize = [self frame].size;
  NSSize newSize = curSize;
  if (!([self autoresizingMask] & NSViewWidthSizable))
    newSize.width = NSMaxX(subframeBounds);

  if (!([self autoresizingMask] & NSViewHeightSizable))
    newSize.height = NSMaxY(subframeBounds);
  
  if (!NSEqualSizes(curSize, newSize))
  {
    // NSLog(@"resize %@ to %@", self, NSStringFromSize(newSize));
    mSelfResizing = YES;
    [self setFrameSizeMaintainingTopLeftOrigin:newSize];
    mSelfResizing = NO;

    [super setNeedsDisplay:YES];
  }
}

- (void)setupNotifications
{
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(viewBoundsChangedNotification:)
                                               name:NSViewBoundsDidChangeNotification
                                             object:nil];

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(viewFrameChangedNotification:)
                                               name:NSViewFrameDidChangeNotification
                                             object:nil];
}

- (void)viewBoundsChangedNotification:(NSNotification*)inNotification
{
  NSView* changedView = [inNotification object];
  if (changedView == self)
    [self recalcPadding];
  else if ([self hasSubview:changedView])
    [self adaptToSubviews];
}

- (void)viewFrameChangedNotification:(NSNotification*)inNotification
{
  NSView* changedView = [inNotification object];
  if (changedView == self)
    [self recalcPadding];
  else if ([self hasSubview:changedView])
    [self adaptToSubviews];
}

- (BOOL)isFlipped
{
  // not flipped because that IB freaks out when editing if it is
  return NO;
}

@end


#pragma mark -

@implementation CHFlippedShrinkWrapView

- (BOOL)isFlipped
{
  return YES;
}

@end

#pragma mark -

NSString* const kStackViewReloadNotification  = @"ReloadStackView";
NSString* const kStackViewResizedNotification = @"StackViewResized";

@interface CHStackView(Private)

- (NSArray*)managedSubviews;

@end

@implementation CHStackView

-(id)initWithFrame:(NSRect)frameRect
{
  if ((self = [super initWithFrame:frameRect]))
  {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reloadNotification:)
                                                 name:kStackViewReloadNotification
                                               object:nil];
  }
  return self;
}

- (void)awakeFromNib
{
  // if we're thawed from a nib, and we don't have any subviews, then we seem
  // to have subview resizing turned off, but we want it on.
  [self setAutoresizesSubviews:YES];

  if ([super respondsToSelector:@selector(awakeFromNib)])
    [super awakeFromNib];

  [self adaptToSubviews];
}

-(void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super dealloc];
}

-(void)setDataSource:(id)aDataSource
{
  mDataSource = aDataSource; // should this retain?
  [self adaptToSubviews];
}

-(void)reloadNotification:(NSNotification*)notification
{
  [self adaptToSubviews];
}

- (void)didAddSubview:(NSView *)subview
{
  [super didAddSubview:subview];
  // [subview setAutoresizingMask:([subview autoresizingMask] | NSViewMinYMargin)];
}

- (void)drawRect:(NSRect)inRect
{
  if ([NSObject respondsToSelector:@selector(editingInInterfaceBuilder)] &&
      [NSObject editingInInterfaceBuilder])
  {
    [[NSColor orangeColor] set];
    NSFrameRect([self bounds]);
  } 
}

-(void)adaptToSubviews
{
  if (mSelfResizing) return;   // avoid re-entry

  if ([NSObject respondsToSelector:@selector(editingInInterfaceBuilder)] &&
      [NSObject editingInInterfaceBuilder])
  {
    return;
  }

  // NSLog(@"%@ frame %@", self, NSStringFromRect([self frame]));
  const float kSeparatorHeight = 1.0f;
  
  NSSize mySize  = [self frame].size;
  NSSize oldSize = mySize;
    
  float totalHeightOfSubviews = 0.0f;
  // we're not flipped because that freaks out editing in IB. So
  // we have to do this in 2 passes; one to resize the subviews, and
  // a second to place them (after sizing ourselves).
  NSEnumerator* stackViewsEnum = [[self managedSubviews] objectEnumerator];
  NSView* curView;
  while ((curView = [stackViewsEnum nextObject]))
  {
    NSSize  subviewFrameSize = [curView frame].size;
    
    unsigned int autoResizeMask = [curView autoresizingMask];
    if ((autoResizeMask & NSViewWidthSizable) && (subviewFrameSize.width != mySize.width))
    {
      subviewFrameSize.width = mySize.width;
      mSelfResizing = YES;
      [curView setFrameSize:subviewFrameSize];
      mSelfResizing = NO;
      
      // setting the width may have changed the height, so fetch it again
      subviewFrameSize = [curView frame].size;
    }

    totalHeightOfSubviews += subviewFrameSize.height;
    
    if (mShowsSeparators && mDataSource)
      totalHeightOfSubviews += kSeparatorHeight;
  }

  // resize self now
  mySize.height = totalHeightOfSubviews;
  
  mSelfResizing = YES;
  [self setFrameSizeMaintainingTopLeftOrigin:mySize];
  mSelfResizing = NO;
  [self setNeedsDisplay:YES];
  
  // now place the subviews
  if (mDataSource)
    [self removeAllSubviews];   // should we keep a copy of the array to make sure they survive?

  float curMaxY = totalHeightOfSubviews;
  
  stackViewsEnum = [[self managedSubviews] objectEnumerator];
  while ((curView = [stackViewsEnum nextObject]))
  {
    NSRect  subviewFrame = [curView frame];

    curMaxY -= NSHeight(subviewFrame);
    subviewFrame.origin.y = curMaxY;

    mSelfResizing = YES;
    [curView setFrameOrigin:subviewFrame.origin];
    mSelfResizing = NO;
    
    if (mDataSource)
      [self addSubview:curView];
    
    if (mShowsSeparators && mDataSource)
    {
      curMaxY -= kSeparatorHeight;

      NSBox* separator = [[NSBox alloc] initWithFrame:
                                 NSMakeRect(subviewFrame.origin.x, curMaxY, NSWidth(subviewFrame), kSeparatorHeight)];      
      [separator setBoxType:NSBoxSeparator];
      [separator setAutoresizingMask:NSViewWidthSizable];
      [self addSubview:separator];
      [separator release];
    }
  }
    
  [[NSNotificationCenter defaultCenter] postNotificationName:kStackViewResizedNotification
                                        object:self
                                        userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSValue valueWithSize:oldSize], @"oldsize", nil]];
}

- (BOOL)showsSeparators
{
  return mShowsSeparators;
}

- (void)setShowsSeparators:(BOOL)inShowSeparators
{
  mShowsSeparators = inShowSeparators;
}

-(BOOL)isFlipped
{
  // not flipped because that IB freaks out when editing if it is
  // (so the math is harder in -adaptToSubviews. oh well).
  return NO;
}

- (NSArray*)managedSubviews
{
  if (mDataSource)
    return [mDataSource subviewsForStackView:self];

  return [self subviews];
}

@end
