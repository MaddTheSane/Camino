/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <AppKit/AppKit.h>

// views contained in the stack should send this notification when they change size
extern NSString* const kStackViewReloadNotification;

// the stack view sends this notification after it has adjusted to subview sizes
extern NSString* const kStackViewResizedNotification;


// 
// CHShrinkWrapView
// 
// A view that resizes to contain its subviews.
// 
// Early on, it will look at its subview positions, and calculate
// the "intrinsic padding" (i.e. the space around the subviews),
// and use this when sizing itself. It will then resize itself to
// contain its subviews, plus the padding, whenever one if its
// direct subviews resizes.
// 
// Can be used in Interface Builder, if you have built and installed
// the CaminoView.palette IB Palette.
// 

@interface CHShrinkWrapView : NSView
{
  float       mIntrinsicPadding[4];  // NSMinXEdge, NSMinYEdge, NSMaxXEdge, NSMaxYEdge
  BOOL        mFetchedIntrinsicPadding;
  BOOL        mPaddingSetManually;
  BOOL        mSelfResizing;
}

// padding will normally be calculated automatically from the subview positions,
// but you can set it explicilty if you wish.
- (void)setIntrinsicPadding:(float)inPadding forEdge:(NSRectEdge)inEdge;
// shortcut to set no padding on all edges
- (void)setNoIntrinsicPadding;
- (float)paddingForEdge:(NSRectEdge)inEdge;

- (void)adaptToSubviews;

@end



// 
// CHFlippedShrinkWrapView
// 
// A subview of CHShrinkWrapView that is flipped.
// 
// This is used when nesting a CHStackView inside an NSScrollView,
// because NSScrollView messes up is its containerView isn't flipped
// (really).
// 
// If you have one of these in IB, editing contained views is broken
// (view outlines draw flipped, mouse interaction is busted).
// 

@interface CHFlippedShrinkWrapView : CHShrinkWrapView
{
}

@end

// 
// CHStackView
// 
// A view that lays out its subviews top to bottom.
// 
// It can either manage a static set of subviws as specified in
// the nib, or the subviews can be supplied by a "data source".
// If using a data source, the stack view can optionally insert
// a separator view after each supplied view.
// 
// The data source, if used, must retain the views.
// 
// Can be used in Interface Builder, if you have built and installed
// the CaminoView.palette IB Palette.
// 

@interface CHStackView : CHShrinkWrapView
{
  IBOutlet id mDataSource;
  BOOL        mShowsSeparators;
//  BOOL        mIsResizingSubviews;
}

- (void)setDataSource:(id)aDataSource;

// default is NO
- (BOOL)showsSeparators;
- (void)setShowsSeparators:(BOOL)inShowSeparators;

@end

@protocol CHStackViewDataSource

- (NSArray*)subviewsForStackView:(CHStackView *)stackView;

@end
