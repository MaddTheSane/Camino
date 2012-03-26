/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
 
#import <Cocoa/Cocoa.h>

@interface nsAlertController : NSObject
{
  // all dialogs are now created on the fly and sized to fit
}

- (IBAction)hitButton1:(id)sender;
- (IBAction)hitButton2:(id)sender;
- (IBAction)hitButton3:(id)sender;

+ (nsAlertController*)sharedController;

// 
// This is a version of [NSApp runModalForWindow:(relativeToWindow:)] that does
// some extra things:
// 
//  1. It verifies that inParentWindow is a valid window to show a sheet on
//     (i.e. that it's not nil, is visible, and doesn't already have a sheet).
//     If inParentWindow can't take a sheet, a modal dialog is displayed.
//
//  2. It doesn't show inWindow as a sheet if there is already a modal
//     (non-sheet) dialog on the screen, because that fubars AppKit.  Instead,
//     another modal dialog is displayed.
// 
//  3. It does some JS context stack magic that pushes a "native code" security
//     principal ("trust label") so that Gecko knows we're running native code,
//     and not calling from JS. This is important, because we can remain on the
//     stack while PLEvents are being handled in the sheet's event loop, and
//     those PLEvents can cause code to run that is sensitive to the security
//     context. See bug 179307 for details.
//
//  4. It closes any pull-down, pop-up, and contextual menus that are open
//     prior to displaying the sheet or dialog.  Open menus are displayed
//     on top of sheets or dialogs, but stop accepting input once a sheet or
//     dialog is displayed, leading to a situation where the UI can get stuck.
// 
+ (int)safeRunModalForWindow:(NSWindow*)inWindow
            relativeToWindow:(NSWindow*)inParentWindow;

+ (int)safeRunModalForWindow:(NSWindow*)window;

// 
// Nota Bene: all of these methods can throw Objective-C exceptions
// if there was an error displaying the dialog.
//
- (void)alert:(NSWindow*)parent title:(NSString*)title text:(NSString*)text;
- (void)alertCheck:(NSWindow*)parent title:(NSString*)title text:(NSString*)text checkMsg:(NSString*)checkMsg checkValue:(BOOL*)checkValue;

- (BOOL)confirm:(NSWindow*)parent title:(NSString*)title text:(NSString*)text;
- (BOOL)confirmCheck:(NSWindow*)parent title:(NSString*)title text:(NSString*)text checkMsg:(NSString*)checkMsg checkValue:(BOOL*)checkValue;

// these return NSAlertDefaultReturn, NSAlertAlternateReturn or NSAlertOtherReturn
- (int)confirmEx:(NSWindow*)parent title:(NSString*)title text:(NSString*)text
   button1:(NSString*)btn1 button2:(NSString*)btn2 button3:(NSString*)btn3;
- (int)confirmDestructive:(NSWindow*)parent
                    title:(NSString*)title
                     text:(NSString*)text
                  button1:(NSString*)button1
                  button2:(NSString*)button2
                  button3:(NSString*)button3;
- (int)confirmCheckEx:(NSWindow*)parent title:(NSString*)title text:(NSString*)text 
  button1:(NSString*)btn1 button2:(NSString*)btn2 button3:(NSString*)btn3
  checkMsg:(NSString*)checkMsg checkValue:(BOOL*)checkValue;

- (BOOL)prompt:(NSWindow*)parent title:(NSString*)title text:(NSString*)text promptText:(NSMutableString*)promptText checkMsg:(NSString*)checkMsg checkValue:(BOOL*)checkValue doCheck:(BOOL)doCheck;
- (BOOL)promptUserNameAndPassword:(NSWindow*)parent title:(NSString*)title text:(NSString*)text userNameText:(NSMutableString*)userNameText passwordText:(NSMutableString*)passwordText checkMsg:(NSString*)checkMsg checkValue:(BOOL*)checkValue doCheck:(BOOL)doCheck;
- (BOOL)promptPassword:(NSWindow*)parent title:(NSString*)title text:(NSString*)text passwordText:(NSMutableString*)passwordText checkMsg:(NSString*)checkMsg checkValue:(BOOL*)checkValue doCheck:(BOOL)doCheck;

- (BOOL)select:(NSWindow*)parent title:(NSString*)title text:(NSString*)text selectList:(NSArray*)selectList selectedIndex:(unsigned int*)selectedIndex;

- (BOOL)postToInsecureFromSecure:(NSWindow*)parent;

@end
