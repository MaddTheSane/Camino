/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>


@interface TruncatingTextAndImageCell : NSCell
{
  NSImage         *mImage;
  NSMutableString *mTruncLabelString;
  int             mLabelStringWidth;      // -1 if not known
  float           mImagePadding;
  float           mImageSpace;
  float           mImageAlpha;
  float           mRightGutter;           // leave space for an icon on the right
  float           mMaxImageHeight;
  NSRect          mImageFrame;
  NSView          *mProgressIndicator;
}

-(id)initTextCell:(NSString*)aString;
-(void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView*)controlView;
-(void)setImagePadding:(float)padding;
-(void)setImageSpace:(float)space;
-(void)setImageAlpha:(float)alpha;
-(void)setMaxImageHeight:(float)height;
-(void)setRightGutter:(float)rightPadding;
-(void)setImage:(NSImage *)anImage;
-(NSImage*)image;
-(NSRect)imageFrame;
-(void)addProgressIndicator:(/*NSProgressIndicator * */NSView*)indicator;
-(void)removeProgressIndicator;

@end
