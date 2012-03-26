/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <AppKit/AppKit.h>

#import "NSString+Utils.h"  // for ETruncationType

//
// TruncatingTextFieldCell
// 
// Text field cell that can be used to truncate text in a text field.
// 
// Use by creating one and setting it as the cell on an NSTextField.
//

@interface TruncatingTextFieldCell : NSTextFieldCell
{
  NSString*           mOriginalStringValue;   // copy of the whole string
  ETruncationType     mTruncationPosition;
}

- (id)initTextCell:(NSString*)inTextValue truncation:(ETruncationType)truncType;

- (void)setTruncationPosition:(ETruncationType)truncType;
- (ETruncationType)truncationPosition;

@end
