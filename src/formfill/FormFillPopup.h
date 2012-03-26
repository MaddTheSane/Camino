/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>

@class FormFillController;

//
// FormFillPopupWindow
//
// The popup window needs to look like a "key" (activated) window even thought it's
// a child window. This subclass overrides |isKeyWindow| to return YES so that it is
// able to be a key window (and have activated scrollbars, etc) but not steal focus.
//
@interface FormFillPopupWindow : NSPanel
@end

// FormFillPopup
//
// Manages the display of the popup window and receives data from the FormFillController.
//
@interface FormFillPopup : NSObject
{
  FormFillPopupWindow*  mPopupWin;        // strong
  NSArray*              mItems;           // strong

  NSTableView*          mTableView;       // weak
  FormFillController*   mController;      // weak
}

- (void)attachToController:(FormFillController*)controller;

// openPopup expects an origin point in Cocoa coordinates and a width that
// should be equal to the text box.
- (void)openPopup:(NSWindow*)browserWindow withOrigin:(NSPoint)origin width:(float)width;
- (void)resizePopup;
- (void)closePopup;
- (BOOL)isPopupOpen;

- (int)visibleRows;
- (int)rowCount;
- (void)selectRow:(int)index;
- (int)selectedRow;

- (void)setItems:(NSArray*)items;
- (NSString*)resultForRow:(int)index;

@end
