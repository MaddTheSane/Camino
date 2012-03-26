/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>

@class ToolTipView;

@interface ToolTip : NSObject
{
  NSWindow*     mTooltipWindow;
  NSTextField*  mTextField;
  NSTextView*   mTextView;
}

// Display a tooltip at |point| (in window coordinates) in |inWindow|.
- (void)showToolTipAtPoint:(NSPoint)point
                withString:(NSString*)string
                overWindow:(NSWindow*)inWindow;
- (void)closeToolTip;

@end
