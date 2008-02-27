/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* ***** BEGIN LICENSE BLOCK *****
 * Version: MPL 1.1/GPL 2.0/LGPL 2.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Original Code is mozilla.org code.
 *
 * The Initial Developer of the Original Code is
 * Netscape Communications Corporation.
 * Portions created by the Initial Developer are Copyright (C) 2002
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *
 * Alternatively, the contents of this file may be used under the terms of
 * either the GNU General Public License Version 2 or later (the "GPL"), or
 * the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
 * in which case the provisions of the GPL or the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of either the GPL or the LGPL, and not to allow others to
 * use your version of this file under the terms of the MPL, indicate your
 * decision by deleting the provisions above and replace them with the notice
 * and other provisions required by the GPL or the LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the MPL, the GPL or the LGPL.
 *
 * ***** END LICENSE BLOCK ***** */

#include "nsServiceManagerUtils.h"
#include "GeckoUtils.h"
#include "NSMenu+Utils.h"

#import "nsAlertController.h"
#import "CHBrowserService.h"
#import "KeyEquivView.h"

const int kMinDialogWidth = 500;
const int kMaxDialogHeight = 400;
const int kMinDialogHeight = 130;
const int kIconSize = 64;
const int kWindowBorder = 20;
const int kIconMargin = 16;						//  space between the icon and text content
const int kButtonMinWidth = 82;
const int kButtonMaxWidth = 300;
const int kButtonHeight = 32;
const int kButtonRightMargin = 14;		//  space between right edge of button and window
const int kButtonBottomMargin = 12;		//  space between bottom edge of button and window
const int kGeneralViewSpace = 9;			//  space between one view and another (vertically)
const int kViewButtonSpace = 16;			//  space between the bottom view and the buttons
const int kMaxFieldHeight = 100;
const int kCheckBoxWidth = 20;
const int kCheckBoxHeight = 18;
const int kTextFieldHeight = 19;
const int kStaticTextFieldHeight = 14;	//  height of non-editable non-bordered text fields
const int kFieldLabelSpacer = 4;				//  space between a static label and an editabe text field (horizontal)
const int kOtherAltButtonSpace = 25;		//  minimum space between the 'other' and 'alternate' buttons
const int kButtonEndCapWidth = 6;
const int kLabelCheckboxAdjustment = 2; // # pixels the label must be pushed down to line up with checkbox


//
// QDCoordsView
//
// A view that uses the QD coordinate space (top left is (0,0))
//

@interface QDCoordsView : NSView
{
}
@end

@implementation QDCoordsView

- (BOOL) isFlipped
{
  return YES;
}

@end

#pragma mark -

@interface nsAlertController (nsAlertControllerPrivateMethods)

- (int)runModalWindow:(NSWindow*)inDialog relativeToWindow:(NSWindow*)inParentWindow;

- (NSPanel*)alertPanelWithTitle:(NSString*)title
                        message:(NSString*)message
                  defaultButton:(NSString*)defaultLabel  // "OK" or equiv.
                      altButton:(NSString*)altLabel      // "Cancel" or equiv.
                    otherButton:(NSString*)otherLabel
                      extraView:(NSView*)extraView       // Shown above buttons
                  lastResponder:(NSView*)lastResponder   // Last in extraView
                    destructive:(BOOL)destructive;       // Don't focus alt
        
- (NSButton*)makeButtonWithTitle:(NSString*)title;

- (float)contentWidthWithDefaultButton:(NSString*)defStr alternateButton:(NSString*)altStr otherButton:(NSString*)otherStr;
- (NSTextField*)titleView:(NSString*)title withWidth:(float)width;
- (NSTextField*)labelView:(NSString*)title withWidth:(float)width;
- (NSView*)loginField:(NSTextField**)field withWidth:(float)width;
- (NSView*)passwordField:(NSSecureTextField**)field withWidth:(float)width;
- (int)loginTextLabelSize;
- (NSView*)messageView:(NSString*)message withWidth:(float)width maxHeight:(float)maxHeight smallFont:(BOOL)useSmallFont;
- (NSView*)checkboxView:(NSButton**)checkBox withLabel:(NSString*)label andWidth:(float)width;

-(void)tester:(id)sender;

@end

#pragma mark -

@implementation nsAlertController

+ (nsAlertController*)sharedController {
  static nsAlertController* sController = nil;
  if (!sController) {
    sController = [[nsAlertController alloc] init];
  }
  return sController;
}

+ (int)safeRunModalForWindow:(NSWindow*)window
            relativeToWindow:(NSWindow*)parentWindow {
  if (parentWindow) {
    // If there is already a modal window up, convert a sheet into a modal
    // window, otherwise AppKit will hang if a sheet is shown, possibly because
    // we're using the deprecated and sucky runModalForWindow:relativeToWindow:.
    // Also, if the parent window already has an attached sheet, or is not
    // visible, also null out the parent and show this as a modal dialog.
    if ([NSApp modalWindow] || [parentWindow attachedSheet] ||
        ![parentWindow isVisible])
      parentWindow = nil;
  }

  int result = NSAlertErrorReturn;
  nsresult rv = NS_OK;
  StNullJSContextScope hack(&rv);
  if (NS_SUCCEEDED(rv)) {
    // If a menu is open (pull-down, pop-up, context, whatever) when a
    // modal dialog or sheet is displayed, the menu will hang and be unusable
    // (not responding to any input) but visible.  The dialog will be usable
    // but possibly obscured by the menu, and will be unable to receive mouse
    // events in the obscured area.  If this happens, the user could wind up
    // stuck.  To account for this, close any open menus before showing a
    // modal dialog.
    [NSMenu cancelAllTracking];

    // be paranoid; we don't want to throw Obj-C exceptions over C++ code
    @try {
      if (parentWindow) {
        result = [NSApp runModalForWindow:window
                         relativeToWindow:parentWindow];
      }
      else {
        result = [NSApp runModalForWindow:window];
      }
    }
    @catch (id exception) {
      NSLog(@"Exception caught in safeRunModalForWindow:relativeToWindow: %@",
            exception);
    }
  }

  return result;
}

+ (int)safeRunModalForWindow:(NSWindow*)window {
  return [nsAlertController safeRunModalForWindow:window relativeToWindow:nil];
}

- (IBAction)hitButton1:(id)sender
{
  [NSApp stopModalWithCode:NSAlertDefaultReturn];
}

- (IBAction)hitButton2:(id)sender
{
  [NSApp stopModalWithCode:NSAlertAlternateReturn];
}

- (IBAction)hitButton3:(id)sender
{
  [NSApp stopModalWithCode:NSAlertOtherReturn];
}

- (void)alert:(NSWindow*)parent title:(NSString*)title text:(NSString*)text
{ 
  NSPanel* panel = [self alertPanelWithTitle:title
                                     message:text
                               defaultButton:NSLocalizedString(@"OKButtonText", nil)
                                   altButton:nil
                                 otherButton:nil
                                   extraView:nil
                               lastResponder:nil
                                 destructive:NO];
  [self runModalWindow:panel relativeToWindow:parent];
  [panel close];
}

- (void)alertCheck:(NSWindow*)parent title:(NSString*)title text:(NSString*)text checkMsg:(NSString*)checkMsg checkValue:(BOOL*)checkValue
{
  //  set up check box view
  NSButton* checkBox = nil;
  float width = [self contentWidthWithDefaultButton:NSLocalizedString(@"OKButtonText", nil)
                                    alternateButton:nil
                                        otherButton:nil];
  NSView* checkboxView = [self checkboxView:&checkBox withLabel:checkMsg andWidth:width];
  int state = (*checkValue ? NSOnState : NSOffState);
  [checkBox setState:state];
  
  //  get panel and display it
  NSPanel* panel = [self alertPanelWithTitle:title
                                     message:text
                               defaultButton:NSLocalizedString(@"OKButtonText", nil)
                                   altButton:nil
                                 otherButton:nil
                                   extraView:checkboxView
                               lastResponder:checkBox
                                 destructive:NO];
  [panel setInitialFirstResponder: checkBox];

  [self runModalWindow:panel relativeToWindow:parent];

  *checkValue = ([checkBox state] == NSOnState);  
  [panel close];
}

- (BOOL)confirm:(NSWindow*)parent title:(NSString*)title text:(NSString*)text
{
  NSPanel* panel = [self alertPanelWithTitle:title
                                     message:text
                               defaultButton:NSLocalizedString(@"OKButtonText", nil)
                                   altButton:NSLocalizedString(@"CancelButtonText", nil)
                                 otherButton:nil
                                   extraView:nil
                               lastResponder:nil
                                 destructive:NO];
  
  int result = [self runModalWindow:panel relativeToWindow:parent];
  
  [panel close];

  return (result == NSAlertDefaultReturn);
}

- (BOOL)confirmCheck:(NSWindow*)parent title:(NSString*)title text:(NSString*)text checkMsg:(NSString*)checkMsg checkValue:(BOOL*)checkValue
{
  //  get button titles
  NSString* okButton = NSLocalizedString(@"OKButtonText", @"");
  NSString* cancelButton = NSLocalizedString(@"CancelButtonText", @"");

  //  set up check box view
  NSButton* checkBox = nil;
  float width = [self contentWidthWithDefaultButton:okButton
                                    alternateButton:cancelButton
                                        otherButton:nil];
  NSView* checkboxView = [self checkboxView:&checkBox withLabel:checkMsg andWidth:width];
  int state = (*checkValue ? NSOnState : NSOffState);
  [checkBox setState:state];
  
  //  get panel and display it
  NSPanel* panel = [self alertPanelWithTitle:title
                                     message:text
                               defaultButton:okButton
                                   altButton:cancelButton
                                 otherButton:nil
                                   extraView:checkboxView
                               lastResponder:checkBox
                                 destructive:NO];
  [panel setInitialFirstResponder: checkBox];

  int result = [self runModalWindow:panel relativeToWindow:parent];

  *checkValue = ([checkBox state] == NSOnState);  
  [panel close];

  return (result == NSAlertDefaultReturn);
}

- (int)confirmEx:(NSWindow*)parent title:(NSString*)title text:(NSString*)text button1:(NSString*)btn1 button2:(NSString*)btn2 button3:(NSString*)btn3
{
   NSPanel* panel = [self alertPanelWithTitle:title
                                      message:text
                                defaultButton:btn1
                                    altButton:btn2
                                  otherButton:btn3
                                    extraView:nil
                                lastResponder:nil
                                  destructive:NO];

  int result = [self runModalWindow:panel relativeToWindow:parent];

   [panel close];
   return result;
}

- (int)confirmDestructive:(NSWindow*)parent
                    title:(NSString*)title
                     text:(NSString*)text
                  button1:(NSString*)button1
                  button2:(NSString*)button2
                  button3:(NSString*)button3 {
   NSPanel* panel = [self alertPanelWithTitle:title
                                      message:text
                                defaultButton:button1
                                    altButton:button2
                                  otherButton:button3
                                    extraView:nil
                                lastResponder:nil
                                  destructive:YES];

  int result = [self runModalWindow:panel relativeToWindow:parent];

   [panel close];
   return result;
}

- (int)confirmCheckEx:(NSWindow*)parent title:(NSString*)title text:(NSString*)text button1:(NSString*)btn1 button2:(NSString*)btn2 button3:(NSString*)btn3 checkMsg:(NSString*)checkMsg checkValue:(BOOL*)checkValue
{
  //  set up check box view
  NSButton* checkBox = nil;
  float width = [self contentWidthWithDefaultButton:btn1
                                    alternateButton:btn2
                                        otherButton:btn3];
  NSView* checkboxView = [self checkboxView:&checkBox withLabel:checkMsg andWidth:width];
  int state = (*checkValue ? NSOnState : NSOffState);
	[checkBox setState:state];
  
  //  get panel and display it
  NSPanel* panel = [self alertPanelWithTitle:title 
                                     message:text
                               defaultButton:btn1
                                   altButton:btn2
                                 otherButton:btn3
                                   extraView:checkboxView
                               lastResponder:checkBox
                                 destructive:NO];
  [panel setInitialFirstResponder: checkBox];

  int result = [self runModalWindow:panel relativeToWindow:parent];

  *checkValue = ([checkBox state] == NSOnState);  
  [panel close];

  return result;
}


- (BOOL)prompt:(NSWindow*)parent title:(NSString*)title text:(NSString*)text promptText:(NSMutableString*)promptText checkMsg:(NSString*)checkMsg checkValue:(BOOL*)checkValue doCheck:(BOOL)doCheck
{
  NSString* okButton = NSLocalizedString(@"OKButtonText", @"");
  NSString* cancelButton = NSLocalizedString(@"CancelButtonText", @"");
  float width = [self contentWidthWithDefaultButton:okButton
                                    alternateButton:cancelButton
                                        otherButton:nil];
  NSView* extraView = [[[NSView alloc] initWithFrame: NSMakeRect(0, 0, width, kTextFieldHeight)] autorelease];;

  //  set up input field
  NSTextField* field = [[[NSTextField alloc] initWithFrame: NSMakeRect(0, 0, width, kTextFieldHeight)] autorelease];
  NSTextFieldCell* cell = [field cell];
  [cell setControlSize: NSSmallControlSize];
  [cell setScrollable: YES];
  [field setStringValue: promptText];
  [field selectText: nil];
  [field setFont: [NSFont systemFontOfSize: [NSFont smallSystemFontSize]]];
  [field setAutoresizingMask: NSViewWidthSizable | NSViewMinYMargin];
  [extraView addSubview: field];
  [extraView setNextKeyView: field];

  //  set up check box view, and combine the checkbox and field into the entire extra view
  NSButton* checkBox = nil;  
  if (doCheck) {
    int state = (*checkValue ? NSOnState : NSOffState);
    NSView* checkboxView = [self checkboxView:&checkBox withLabel:checkMsg andWidth:width];
    [checkBox setState:state];
    [checkboxView setFrameOrigin: NSMakePoint(0, 0)];
    [extraView setFrameSize: NSMakeSize(width, kTextFieldHeight + kGeneralViewSpace + NSHeight([checkboxView frame]))];
    [extraView addSubview: checkboxView];
    [field setNextKeyView: checkBox];
  }
    
  //  get panel and display it
  NSView* lastResponder = (doCheck ? (NSView*)checkBox : (NSView*)field);
  NSPanel* panel = [self alertPanelWithTitle:title
                                     message:text
                               defaultButton:okButton
                                   altButton:cancelButton
                                 otherButton:nil
                                   extraView:extraView
                               lastResponder:lastResponder
                                 destructive:NO];
  [panel setInitialFirstResponder: field];

  int result = [self runModalWindow:panel relativeToWindow:parent];

  [panel close];
  
  [promptText setString: [field stringValue]];
  
  if (doCheck)
    *checkValue = ([checkBox state] == NSOnState);  
 
  return (result == NSAlertDefaultReturn);
}


- (BOOL)promptUserNameAndPassword:(NSWindow*)parent title:(NSString*)title text:(NSString*)text userNameText:(NSMutableString*)userNameText passwordText:(NSMutableString*)passwordText checkMsg:(NSString*)checkMsg checkValue:(BOOL*)checkValue doCheck:(BOOL)doCheck
{
  NSString* okButton = NSLocalizedString(@"OKButtonText", @"");
  NSString* cancelButton = NSLocalizedString(@"CancelButtonText", @"");
  float width = [self contentWidthWithDefaultButton:okButton
                                    alternateButton:cancelButton
                                        otherButton:nil];
  NSView* extraView = [[[NSView alloc] initWithFrame: NSMakeRect(0, 0, width, 2*kTextFieldHeight + kGeneralViewSpace)] autorelease];

  //  set up username field
  NSTextField* userField = nil;
  NSView* userView = [self loginField:&userField withWidth:width];
  [userView setAutoresizingMask: NSViewMinYMargin];
  [userView setFrameOrigin: NSMakePoint(0, kTextFieldHeight + kGeneralViewSpace)];
  [userField setStringValue: userNameText];
  [extraView addSubview: userView];
  [extraView setNextKeyView: userField];
  
  //  set up password field
  NSSecureTextField* passField = nil;
  NSView* passView = [self passwordField:&passField withWidth:width];
  [passView setAutoresizingMask: NSViewMinYMargin];
  [passView setFrameOrigin: NSMakePoint(0, 0)];
  [passField setStringValue: passwordText];
  [extraView addSubview: passView];
  [userField setNextKeyView: passField];

  //  set up check box view, and combine the checkbox and field into the entire extra view
  NSButton* checkBox = nil;  
  if (doCheck) {
    int state = (*checkValue ? NSOnState : NSOffState);
    NSView* checkboxView = [self checkboxView:&checkBox withLabel:checkMsg andWidth:width];
    [checkBox setState:state];
    [checkboxView setFrameOrigin: NSMakePoint(0, 0)];
    [extraView setFrameSize: NSMakeSize(width,  2*kTextFieldHeight + 2*kGeneralViewSpace + NSHeight([checkboxView frame]))];
    [extraView addSubview: checkboxView];
    [passField setNextKeyView: checkBox];
  }
    
  //  get panel and display it
  NSView* lastResponder = (doCheck ? (NSView*)checkBox : (NSView*)passField);
  NSPanel* panel = [self alertPanelWithTitle:title
                                     message:text
                               defaultButton:okButton
                                   altButton:cancelButton
                                 otherButton:nil
                                   extraView:extraView
                               lastResponder:lastResponder
                                 destructive:NO];
  [panel setInitialFirstResponder: userField];

  int result = [self runModalWindow:panel relativeToWindow:parent];

  [panel close];
  
  [userNameText setString: [userField stringValue]];
  [passwordText setString: [passField stringValue]];
  
  if (doCheck)
    *checkValue = ([checkBox state] == NSOnState);  
 
  return (result == NSAlertDefaultReturn);
}

- (BOOL)promptPassword:(NSWindow*)parent title:(NSString*)title text:(NSString*)text passwordText:(NSMutableString*)passwordText
        checkMsg:(NSString*)checkMsg checkValue:(BOOL*)checkValue doCheck:(BOOL)doCheck
{
  NSString* okButton = NSLocalizedString(@"OKButtonText", @"");
  NSString* cancelButton = NSLocalizedString(@"CancelButtonText", @"");
  float width = [self contentWidthWithDefaultButton:okButton
                                    alternateButton:cancelButton
                                        otherButton:nil];
  NSView* extraView = [[[NSView alloc] initWithFrame: NSMakeRect(0, 0, width, kTextFieldHeight)] autorelease];;

  //  set up input field
  NSSecureTextField* passField = nil;
  NSView* passView = [self passwordField:&passField withWidth:width];
  [passView setAutoresizingMask: NSViewMinYMargin];
  [passView setFrameOrigin: NSMakePoint(0, 0)];
  [passField setStringValue: passwordText];
  [extraView addSubview: passView];
  [extraView setNextKeyView: passField];

  //  set up check box view, and combine the checkbox and field into the entire extra view
  NSButton* checkBox = nil;  
  if (doCheck) {
    int state = (*checkValue ? NSOnState : NSOffState);
    NSView* checkboxView = [self checkboxView:&checkBox withLabel:checkMsg andWidth:width];
    [checkBox setState:state];
    [checkboxView setFrameOrigin: NSMakePoint(0, 0)];
    [extraView setFrameSize: NSMakeSize(width, kTextFieldHeight + kGeneralViewSpace + NSHeight([checkboxView frame]))];
    [extraView addSubview: checkboxView];
    [passField setNextKeyView: checkBox];
  }
    
  //  get panel and display it
  NSView* lastResponder = (doCheck ? (NSView*)checkBox : (NSView*)passField);
  NSPanel* panel = [self alertPanelWithTitle:title
                                     message:text
                               defaultButton:okButton
                                   altButton:cancelButton
                                 otherButton:nil
                                   extraView:extraView
                               lastResponder:lastResponder
                                 destructive:NO];
  [panel setInitialFirstResponder: passField];

  int result = [self runModalWindow:panel relativeToWindow:parent];

  [panel close];
  
  [passwordText setString: [passField stringValue]];
  
  if (doCheck)
    *checkValue = ([checkBox state] == NSOnState);  
 
  return (result == NSAlertDefaultReturn);
}


- (BOOL)postToInsecureFromSecure:(NSWindow*)parent
{
  NSString* title = NSLocalizedString(@"Security Warning", @"");
  NSString* message = NSLocalizedString(@"Post To Insecure", @"");
  NSString* continueButton = NSLocalizedString(@"ContinueButton", @"");
  NSString* stopButton = NSLocalizedString(@"StopButton", @"");
  
  id panel = NSGetAlertPanel(title, message, continueButton, stopButton, nil);

  int result = [self runModalWindow:panel relativeToWindow:parent];

  [panel close];
  NSReleaseAlertPanel(panel);
  
  return (result == NSAlertDefaultReturn);
}

#pragma mark -

//  implementation of private methods

- (int)runModalWindow:(NSWindow*)inDialog relativeToWindow:(NSWindow*)inParentWindow
{
  int result = [nsAlertController safeRunModalForWindow:inDialog
                                       relativeToWindow:inParentWindow];

  // Convert any error into an exception
  if (result == NSAlertErrorReturn)
      [NSException raise:NSInternalInconsistencyException
                  format:@"-runModalForWindow returned error"];

  return result;
}

// The content width is determined by how much space is needed to display all 3 buttons,
// since every other view in the dialog can wrap if necessary
- (float)contentWidthWithDefaultButton:(NSString*)defStr
                       alternateButton:(NSString*)altStr
                           otherButton:(NSString*)otherStr
{
  NSButton* defButton = [self makeButtonWithTitle: defStr];
  NSButton* altButton = [self makeButtonWithTitle: altStr];
  NSButton* otherButton = [self makeButtonWithTitle: otherStr];

  float defWidth = NSWidth([defButton frame]);
  float altWidth = (altButton) ? NSWidth([altButton frame]) : 0;
  float otherWidth = (otherButton) ? NSWidth([otherButton frame]) : 0;
  
  float minContentWidth = kMinDialogWidth - 2*kWindowBorder - kIconMargin - kIconSize;
  float buttonWidth = defWidth + altWidth + otherWidth + kOtherAltButtonSpace;

  //  return the larger of the two
  return (minContentWidth > buttonWidth) ? minContentWidth : buttonWidth;
}

- (NSPanel*)alertPanelWithTitle:(NSString*)title
                        message:(NSString*)message
                  defaultButton:(NSString*)defaultLabel
                      altButton:(NSString*)altLabel
                    otherButton:(NSString*)otherLabel
                      extraView:(NSView*)extraView
                  lastResponder:(NSView*)lastResponder
                    destructive:(BOOL)destructive
{
  NSRect rect = NSMakeRect(0, 0, kMinDialogWidth, kMaxDialogHeight);
  NSPanel* panel = [[[NSPanel alloc] initWithContentRect: rect styleMask: NSTitledWindowMask backing: NSBackingStoreBuffered defer: YES] autorelease];
  // hiding on deactivation will sometimes misplace the dialog
  [panel setHidesOnDeactivate:NO];
  NSImageView* imageView = [[[NSImageView alloc] initWithFrame: NSMakeRect(kWindowBorder, kMaxDialogHeight - kWindowBorder - kIconSize, kIconSize, kIconSize)] autorelease];
  
  //  app icon
  
  [imageView setImage: [NSImage imageNamed: @"NSApplicationIcon"]];
  [imageView setImageFrameStyle: NSImageFrameNone];
  [imageView setImageScaling: NSScaleProportionally];
  [imageView setAutoresizingMask: NSViewMinYMargin | NSViewMaxXMargin];
  [[panel contentView] addSubview: imageView];

  //  create buttons

  NSButton* defButton = [self makeButtonWithTitle: defaultLabel];
  [defButton setAction: @selector(hitButton1:)];
  [defButton setAutoresizingMask: NSViewMinXMargin | NSViewMaxYMargin];
  [defButton setKeyEquivalent:@"\r"];  // Return
  [[panel contentView] addSubview: defButton];
  [panel setDefaultButtonCell: [defButton cell]];

  if (destructive) {
    // If the dialog has a destructive action, the default button will map
    // roughly to "Cancel", and Esc should trigger that action.
    KeyEquivView* defEquiv = [KeyEquivView kevWithKeyEquivalent:@"\e"  // Esc
                                      keyEquivalentModifierMask:0
                                                         target:defButton
                                                         action:@selector(performClick:)];
    [[panel contentView] addSubview:defEquiv];
  }

  // Keep track of the leftmost created button for setting up the tab chain.
  // The tab chain should generally cycle top to bottom (if an extraView was
  // supplied), and within that, left to right.
  NSView* leftmostButton = defButton;

  NSButton* altButton = nil;
  if (altLabel) {
    altButton = [self makeButtonWithTitle: altLabel];
    [altButton setAction: @selector(hitButton2:)];
    [altButton setAutoresizingMask: NSViewMinXMargin | NSViewMaxYMargin];
    if (!destructive) {
      // In a normal dialog, the alternate button will map roughly to "Cancel",
      // and Esc should trigger that action.
      [altButton setKeyEquivalent:@"\e"];  // Esc
    }
    [[panel contentView] addSubview: altButton];
    [altButton setNextKeyView:leftmostButton];
    leftmostButton = altButton;
  }

  NSButton* otherButton = nil;
  if (otherLabel) {
    otherButton = [self makeButtonWithTitle: otherLabel];
    [otherButton setAction: @selector(hitButton3:)];
    [otherButton setAutoresizingMask: NSViewMaxXMargin | NSViewMaxYMargin];
    [[panel contentView] addSubview: otherButton];
    [otherButton setNextKeyView:leftmostButton];
    leftmostButton = otherButton;
  }

  //  position buttons
  
  float defWidth = NSWidth([defButton frame]);
  float altWidth = (altButton) ? NSWidth([altButton frame]) : 0;
  
  [defButton setFrameOrigin: NSMakePoint(NSWidth([panel frame]) - defWidth - kButtonRightMargin, kButtonBottomMargin)];
  [altButton setFrameOrigin: NSMakePoint(NSMinX([defButton frame]) - altWidth, kButtonBottomMargin)];
  [otherButton setFrameOrigin: NSMakePoint(kIconSize + kWindowBorder + kIconMargin, kButtonBottomMargin)];
  
  //  set the window width
  //  contentWidth is the width of the area with text, buttons, etc
  //  windowWidth is the total window width (contentWidth + margins + icon)
  
  float contentWidth = [self contentWidthWithDefaultButton:defaultLabel
                                           alternateButton:altLabel
                                               otherButton:otherLabel];
  float windowWidth = kIconSize + kIconMargin + 2*kWindowBorder + contentWidth;
  if (windowWidth < kMinDialogWidth)
    windowWidth = kMinDialogWidth;

  //  get the height of all elements, and set the window height
  
  NSTextField* titleField = [self titleView:title withWidth:contentWidth];
  
  float titleHeight = [title length] ? NSHeight([titleField frame]) : 0;
  float extraViewHeight = (extraView) ? NSHeight([extraView frame]) : 0;
  float totalHeight = kWindowBorder + titleHeight + kGeneralViewSpace + kViewButtonSpace + kButtonHeight + kButtonBottomMargin;
  if (extraViewHeight > 0)
    totalHeight += extraViewHeight + kGeneralViewSpace;
  
  float maxMessageHeight = kMaxDialogHeight - totalHeight;
  NSView* messageView = [self messageView:message
                                withWidth:contentWidth
                                maxHeight:maxMessageHeight
                                smallFont:[title length]];
  float messageHeight = NSHeight([messageView frame]);
  totalHeight += messageHeight;
  
  if (totalHeight < kMinDialogHeight)
    totalHeight = kMinDialogHeight;
  
  [panel setContentSize: NSMakeSize(windowWidth, totalHeight)];
  
  //  position the title
  
  float contentLeftEdge = kWindowBorder + kIconSize + kIconMargin;
  NSRect titleRect = NSMakeRect(contentLeftEdge, totalHeight - titleHeight - kWindowBorder, contentWidth, titleHeight);
  [titleField setFrame: titleRect];
  if ( [title length] )
    [[panel contentView] addSubview: titleField];
  
  //  position the message
  
  NSRect messageRect = NSMakeRect(contentLeftEdge, NSMinY([titleField frame]) - kGeneralViewSpace - messageHeight, contentWidth, messageHeight);
  [messageView setFrame: messageRect];
  [[panel contentView] addSubview: messageView];
  
  //  position the extra view

  NSRect extraRect = NSMakeRect(contentLeftEdge, NSMinY([messageView frame]) - kGeneralViewSpace - extraViewHeight, contentWidth, extraViewHeight);
  [extraView setFrame: extraRect];
  [[panel contentView] addSubview: extraView];

  // Close the tab chain.  If an extraView is present, make it the initial
  // first responder and hook its lastResponder (the last item within
  // extraView's tab chain) up to the buttons.  If there is no extraView,
  // make altButton, used for "Cancel" buttons, the initial first responder if
  // there is one.  Otherwise, make the default button the initial first
  // responder.

  if (extraView && lastResponder) {
    [panel setInitialFirstResponder:extraView];
    [lastResponder setNextKeyView:leftmostButton];
    [defButton setNextKeyView:extraView];
  }
  else {
    if (altButton && !destructive) {
      // Only set the second button as the initial first responder if it exists
      // and if its action is not destructive.
      [panel setInitialFirstResponder:altButton];
    }
    else {
      [panel setInitialFirstResponder:defButton];
    }

    if (defButton != leftmostButton) {
      [defButton setNextKeyView:leftmostButton];
    }
  }

  return panel;
}

- (NSButton*)makeButtonWithTitle:(NSString*)title
{
  if (title == nil)
    return nil;

  NSButton* button = [[[NSButton alloc] initWithFrame: NSMakeRect(0, 0, kButtonMinWidth, kButtonHeight)] autorelease];

  [button setTitle: title];
  [button setFont: [NSFont systemFontOfSize: [NSFont systemFontSize]]];
  [button setBordered: YES];
  [button setButtonType: NSMomentaryPushButton];
  [button setBezelStyle: NSRoundedBezelStyle];
  [button setTarget: self];
  [button sizeToFit];
  
  NSRect buttonFrame = [button frame];
  
  //  make sure the button is within our allowed size range
  if (NSWidth(buttonFrame) < (kButtonMinWidth - 2 * kButtonEndCapWidth))
    buttonFrame.size.width = kButtonMinWidth;
  else
     buttonFrame.size.width += 2 * kButtonEndCapWidth;

  if (NSWidth(buttonFrame) > kButtonMaxWidth)
    buttonFrame.size.width = kButtonMaxWidth;
   
  [button setFrame: buttonFrame];

  return button;
}


- (NSTextField*)titleView:(NSString*)title withWidth:(float)width
{
  NSTextView* textView = [[[NSTextView alloc] initWithFrame: NSMakeRect(0, 0, width, 100)] autorelease];		
  [textView setString: title];
  [textView setMinSize: NSMakeSize(width, 0.0)];
  [textView setMaxSize: NSMakeSize(width, kMaxFieldHeight)];
  [textView setVerticallyResizable: YES];
  [textView setHorizontallyResizable: NO];
  [textView setFont: [NSFont boldSystemFontOfSize: [NSFont systemFontSize]]];
  [textView sizeToFit];
  NSSize textSize = NSMakeSize( ceil( NSWidth([textView frame]) ), ceil( NSHeight([textView frame]) ) );
  
  NSTextField* field = [[[NSTextField alloc] initWithFrame: NSMakeRect(0, 0, textSize.width, textSize.height)] autorelease];
  [field setStringValue: title];
  [field setFont: [NSFont boldSystemFontOfSize: [NSFont systemFontSize]]];
  [field setEditable: NO];
  [field setSelectable: NO];
  [field setBezeled: NO];
  [field setBordered: NO];
  [field setDrawsBackground: NO];

  return field;
}

- (NSTextField*)labelView:(NSString*)title withWidth:(float)width
{
  NSTextView* textView = [[[NSTextView alloc] initWithFrame: NSMakeRect(0, 0, width, 100)] autorelease];		
  [textView setString: title];
  [textView setMinSize: NSMakeSize(width, 0.0)];
  [textView setMaxSize: NSMakeSize(width, kMaxFieldHeight)];
  [textView setVerticallyResizable: YES];
  [textView setHorizontallyResizable: NO];
  [textView setFont: [NSFont systemFontOfSize: [NSFont smallSystemFontSize]]];
  [textView sizeToFit];
  NSSize textSize = NSMakeSize(ceil(NSWidth([textView frame])), ceil(NSHeight([textView frame])) + 5);
  
  NSTextField* field = [[[NSTextField alloc] initWithFrame: NSMakeRect(0, 0, textSize.width, textSize.height)] autorelease];
  [field setStringValue: title];
  [field setFont: [NSFont systemFontOfSize: [NSFont smallSystemFontSize]]];
  [field setEditable: NO];
  [field setSelectable: NO];
  [field setBezeled: NO];
  [field setBordered: NO];
  [field setDrawsBackground: NO];

  return field;
}

- (NSView*)messageView:(NSString*)message
             withWidth:(float)width
             maxHeight:(float)maxHeight 
             smallFont:(BOOL)useSmallFont
{
  NSTextView* textView = [[[NSTextView alloc] initWithFrame: NSMakeRect(0, 0, width, 100)] autorelease];		
  [textView setString: message];
  [textView setMinSize: NSMakeSize(width, 0.0)];
  [textView setVerticallyResizable: YES];
  [textView setHorizontallyResizable: NO];
  float displayFontSize = useSmallFont ? [NSFont smallSystemFontSize] : [NSFont systemFontSize];
  [textView setFont: [NSFont systemFontOfSize:displayFontSize]];
  [textView sizeToFit];
  NSSize textSize = NSMakeSize(ceil(NSWidth([textView frame])), ceil(NSHeight([textView frame])) + 5);
  
  //  if the text is small enough to fit, then display it
  
  if (textSize.height <= maxHeight) {
    NSTextField* field = [[[NSTextField alloc] initWithFrame: NSMakeRect(0, 0, textSize.width, textSize.height)] autorelease];
    [field setStringValue: message];
    [field setFont: [NSFont systemFontOfSize: displayFontSize]];
    [field setEditable: NO];
    [field setSelectable: YES];
    [field setBezeled: NO];
    [field setBordered: NO];
    [field setDrawsBackground: NO];
    
    return field;
  }
  
  //  if not, create scrollers
  
  NSScrollView* scrollView = [[[NSScrollView alloc] initWithFrame: NSMakeRect(0, 0, width, maxHeight)] autorelease];
  [scrollView setDocumentView: textView];
  [scrollView setDrawsBackground: NO];
  [scrollView setBorderType: NSBezelBorder];
  [scrollView setHasHorizontalScroller: NO];
  [scrollView setHasVerticalScroller: YES];
  
  [textView setSelectable: YES];
  [textView setEditable: NO];
  [textView setDrawsBackground: NO];
  [textView setFrameSize: [scrollView contentSize]];

  return scrollView;
}

- (NSView*)checkboxView:(NSButton**)checkBoxPtr withLabel:(NSString*)label andWidth:(float)width
{
  NSTextField* textField = [self labelView:label withWidth:(width - kCheckBoxWidth)];
  float height = NSHeight([textField frame]);
  
  //  one line of text isn't as tall as the checkbox.  make the view taller, or the checkbox will get clipped
  if (height < kCheckBoxHeight)
    height = kCheckBoxHeight;
  
  // use a flipped view so we can more easily align everything at the top/left.
  NSView* view = [[[QDCoordsView alloc] initWithFrame: NSMakeRect(0, 0, width, height)] autorelease];
  
  [view addSubview: textField];
  [view setNextKeyView: textField];
  [textField setFrameOrigin: NSMakePoint(kCheckBoxWidth, kLabelCheckboxAdjustment)];
  
  NSButton* checkBox = [[[NSButton alloc] initWithFrame: NSMakeRect(0, 0, kCheckBoxWidth, kCheckBoxHeight)] autorelease];
  *checkBoxPtr = checkBox;
  [checkBox setButtonType: NSSwitchButton];
  [[checkBox cell] setControlSize: NSSmallControlSize];
  [view addSubview: checkBox];
  [textField setNextKeyView: checkBox];
  
  // overlay the label with a transparent button that will push the checkbox
  // when clicked on
  NSButton* labelOverlay = [[[NSButton alloc] initWithFrame:[textField frame]] autorelease];
  [labelOverlay setTransparent:YES];
  [labelOverlay setTarget:[checkBox cell]];
  [labelOverlay setAction:@selector(performClick:)];
  [view addSubview:labelOverlay positioned:NSWindowAbove relativeTo:checkBox];

  return view;
}

- (NSView*)loginField:(NSTextField**)fieldPtr withWidth:(float)width
{
  int labelSize = [self loginTextLabelSize];
  int fieldLeftEdge = labelSize + kFieldLabelSpacer;

  NSView* view = [[[NSView alloc] initWithFrame: NSMakeRect(0, 0, width, kTextFieldHeight)] autorelease];
  NSTextField* label = [[[NSTextField alloc] initWithFrame: NSMakeRect(0, 3, labelSize, kStaticTextFieldHeight)] autorelease];
  [[label cell] setControlSize: NSSmallControlSize];
  [label setFont: [NSFont systemFontOfSize: [NSFont smallSystemFontSize]]];
  [label setStringValue: NSLocalizedString(@"Username Label", @"")];
  [label setEditable: NO];
  [label setSelectable: NO];
  [label setBordered: NO];
  [label setDrawsBackground: NO];
  [label setAlignment: NSRightTextAlignment];
  [view addSubview: label];
  
  NSTextField* field = [[[NSTextField alloc] initWithFrame: NSMakeRect(fieldLeftEdge, 0, width - fieldLeftEdge, kTextFieldHeight)] autorelease];
  [[field cell] setControlSize: NSSmallControlSize];
  [field setFont: [NSFont systemFontOfSize: [NSFont smallSystemFontSize]]];
  [view addSubview: field];
  [view setNextKeyView: field];
  *fieldPtr = field;
  
  return view;
}

- (NSView*)passwordField:(NSSecureTextField**)fieldPtr withWidth:(float)width
{
  int labelSize = [self loginTextLabelSize];
  int fieldLeftEdge = labelSize + kFieldLabelSpacer;

  NSView* view = [[[NSView alloc] initWithFrame: NSMakeRect(0, 0, width, kTextFieldHeight)] autorelease];
  NSTextField* label = [[[NSTextField alloc] initWithFrame: NSMakeRect(0, 3, labelSize, kStaticTextFieldHeight)] autorelease];
  [[label cell] setControlSize: NSSmallControlSize];
  [label setFont: [NSFont systemFontOfSize: [NSFont smallSystemFontSize]]];
  [label setStringValue: NSLocalizedString(@"Password Label", @"")];
  [label setEditable: NO];
  [label setSelectable: NO];
  [label setBordered: NO];
  [label setDrawsBackground: NO];
  [label setAlignment: NSRightTextAlignment];
  [view addSubview: label];
  
  NSSecureTextField* field = [[[NSSecureTextField alloc] initWithFrame: NSMakeRect(fieldLeftEdge, 0, width - fieldLeftEdge, kTextFieldHeight)] autorelease];
  [[field cell] setControlSize: NSSmallControlSize];
  [field setFont: [NSFont systemFontOfSize: [NSFont smallSystemFontSize]]];
  [view addSubview: field];
  [view setNextKeyView: field];
  *fieldPtr = field;
  
  return view;
}

- (int)loginTextLabelSize
{
  NSTextField* label = [[[NSTextField alloc] initWithFrame: NSMakeRect(0, 0, 200, kStaticTextFieldHeight)] autorelease];
  [[label cell] setControlSize: NSSmallControlSize];
  [label setFont: [NSFont systemFontOfSize: [NSFont smallSystemFontSize]]];
  [label setEditable: NO];
  [label setSelectable: NO];
  [label setBordered: NO];
  [label setDrawsBackground: NO];
  [label setAlignment: NSRightTextAlignment];
  
  [label setStringValue: NSLocalizedString(@"Username Label", @"")];
  [label sizeToFit];
  float userSize = NSWidth([label frame]);
  
  [label setStringValue: NSLocalizedString(@"Password Label", @"")];
  [label sizeToFit];
  float passSize = NSWidth([label frame]);
  
  float largest = (userSize > passSize) ? userSize : passSize;
  return (int)ceil(largest) + 6;
}

@end
