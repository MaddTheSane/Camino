/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "TruncatingTextAndImageCell.h"
#import "NSString+Utils.h"

// this was in BrowserTabViewItem, but the comment stated that it needed to be moved
// since I needed it outside BrowserTabViewItem, I moved it. I also renamed it since it was
// easy and I'm confused by non-Apple names that start with NS :-)

@implementation TruncatingTextAndImageCell

-(id)initTextCell:(NSString*)aString
{
  if ((self = [super initTextCell:aString])) {
    mLabelStringWidth = -1;
    mImagePadding = 0;
    mImageSpace = 2;
    mMaxImageHeight = 16;
	  mRightGutter = 0.0;
  }
  return self;
}

-(void)dealloc
{
  [mProgressIndicator removeFromSuperview];
  [mProgressIndicator release];
  [mImage release];
  [mTruncLabelString release];
  [super dealloc];
}

-copyWithZone:(NSZone *)zone
{
  TruncatingTextAndImageCell *cell = (TruncatingTextAndImageCell *)[super copyWithZone:zone];
  cell->mImage = [mImage retain];
  cell->mTruncLabelString = nil;
  cell->mLabelStringWidth = -1;
  cell->mRightGutter = mRightGutter;
  return cell;
}

-(NSRect )imageFrame
{
  return mImageFrame;
}

// currently draws progress indicator or favicon followed by label
-(void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView*)controlView
{
  NSRect textRect = cellFrame;
  NSRect imageRect;
  
  // we always reserve space for the image, even if there isn't one
  // assume the image rect is always square
  float imageWidth = NSHeight(cellFrame) - 2 * mImagePadding;
  //Put the favicon/spinner to the left of the text
  NSDivideRect(cellFrame, &imageRect, &textRect, imageWidth, NSMinXEdge);

  // draw the progress indicator if we have a reference to it, otherwise draw the favicon
  if (mProgressIndicator) {
    if (controlView != [mProgressIndicator superview]) {
      [controlView addSubview:mProgressIndicator];
    }
    [mProgressIndicator setFrame:imageRect];
    [mProgressIndicator setNeedsDisplay:YES];
  }
  else if (mImage) {
    NSRect imageSrcRect = NSZeroRect;
    imageSrcRect.size = [mImage size];
    float imagePadding = mImagePadding;
    // I don't think this will be needed in practice, but if the favicon is smaller than
    // our planned size, it should be padded rather than left on the bottom of the cell IMO
    if (imageRect.size.height > mMaxImageHeight)
      imagePadding += (imageRect.size.height - mMaxImageHeight);
    [mImage drawInRect:NSInsetRect(imageRect, mImagePadding, mImagePadding)
            fromRect:imageSrcRect operation:NSCompositeSourceOver fraction:mImageAlpha];
  }

  mImageFrame = [controlView convertRect:imageRect toView:nil];
  // remove image space
  NSDivideRect(textRect, &imageRect, &textRect, mImageSpace, NSMinXEdge);
  
  int cellWidth = (int)NSWidth(textRect) - (int)mRightGutter;
  NSDictionary *cellAttributes = [[self attributedStringValue] attributesAtIndex:0 effectiveRange:nil];
  
  if (mLabelStringWidth != cellWidth || !mTruncLabelString) {
    [mTruncLabelString release];
    mTruncLabelString = [[NSMutableString alloc] initWithString:[self stringValue]];
    [mTruncLabelString truncateToWidth:cellWidth at:kTruncateAtEnd withAttributes:cellAttributes];
    mLabelStringWidth = cellWidth;
  }
  
  // shift the text slightly to vertically align it with the site icon
  textRect.origin.y -= 1.0;
  [mTruncLabelString drawInRect:textRect withAttributes:cellAttributes];
}

-(void)setStringValue:(NSString *)aString
{
  if (![aString isEqualToString:[self stringValue]]) {
    [mTruncLabelString release];
    mTruncLabelString = nil;
  }
  [super setStringValue:aString];
}

-(void)setAttributedStringValue:(NSAttributedString *)attribStr
{
  if (![attribStr isEqualToAttributedString:[self attributedStringValue]]) {
    [mTruncLabelString release];
    mTruncLabelString = nil;
  }
  [super setAttributedStringValue:attribStr];
}

-(void)setImage:(NSImage *)anImage 
{
  if (anImage != mImage) {
    [mImage release];
    mImage = [anImage retain];
  }
}

-(NSImage *)image
{
  return mImage;
}

-(void)setImagePadding:(float)padding
{
  mImagePadding = padding;
}

-(void)setRightGutter:(float)rightPadding
{
  mRightGutter = rightPadding;
}

-(void)setImageSpace:(float)space
{
  mImageSpace = space;
}

-(void)setImageAlpha:(float)alpha
{
  mImageAlpha = alpha;
}

// called by BrowserTabViewItem when progress display should start
- (void)addProgressIndicator:(NSView*)indicator
{
  if (mProgressIndicator)
    [self removeProgressIndicator];
  mProgressIndicator = [indicator retain];
}

// called by BrowserTabviewItem when progress display is finished
// and the progress indicator should be replaced with the favicon
- (void)removeProgressIndicator
{
  [mProgressIndicator removeFromSuperview];
  [mProgressIndicator release];
  mProgressIndicator = nil;
}

// called by TabButtonView to constrain the height of the favicon to the height of the close button
// for best results, both should be 16x16
- (void)setMaxImageHeight:(float)height
{
  mMaxImageHeight = height;
}

@end
