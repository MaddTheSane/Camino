/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>

// 
// AutoSizingTextField
// 
// This is a text field that automatically adjusts its height
// to fit the text. The width remains unchanged. It will never
// shrink to be less that one lineheight tall.
// 
// Can be used in Interface Builder, if you have built and installed
// the CaminoView.palette IB Palette.
// 

@interface AutoSizingTextField : NSTextField
{
  BOOL      mSettingFrameSize;
}
@end
