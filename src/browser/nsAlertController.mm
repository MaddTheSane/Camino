/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* ***** BEGIN LICENSE BLOCK *****
 * Version: NPL 1.1/GPL 2.0/LGPL 2.1
 *
 * The contents of this file are subject to the Netscape Public License
 * Version 1.1 (the "License"); you may not use this file except in
 * compliance with the License. You may obtain a copy of the License at
 * http://www.mozilla.org/NPL/
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
 * use your version of this file under the terms of the NPL, indicate your
 * decision by deleting the provisions above and replace them with the notice
 * and other provisions required by the GPL or the LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the NPL, the GPL or the LGPL.
 *
 * ***** END LICENSE BLOCK ***** */
 
#import "nsAlertController.h"
#import "nsCocoaBrowserService.h"

#include "nsIBadCertListener.h"

@implementation nsAlertController

- (IBAction)hitButton1:(id)sender
{
  [NSApp stopModalWithCode:1];
}

- (IBAction)hitButton2:(id)sender
{
  [NSApp stopModalWithCode:2];
}

- (IBAction)hitButton3:(id)sender
{
  [NSApp stopModalWithCode:3];
}


- (void)awakeFromNib
{
  nsCocoaBrowserService::SetAlertController(self);
}

- (void)alert:(NSWindow*)parent title:(NSString*)title text:(NSString*)text
{
  [alertPanelText setStringValue:text];
  [alertPanel setTitle:title];

  [NSApp runModalForWindow:alertPanel relativeToWindow:parent];
  
  [alertPanel close];
}

- (void)alertCheck:(NSWindow*)parent title:(NSString*)title text:(NSString*)text checkMsg:(NSString*)checkMsg checkValue:(BOOL*)checkValue
{
  [alertCheckPanelText setStringValue:text];
  [alertCheckPanel setTitle:title];
  int state = (*checkValue ? NSOnState : NSOffState);
  [alertCheckPanelCheck setState:state];
  [alertCheckPanelCheck setTitle:checkMsg];

  [NSApp runModalForWindow:alertCheckPanel relativeToWindow:parent];

  *checkValue = ([alertCheckPanelCheck state] == NSOnState);
  [alertCheckPanel close];
}

- (BOOL)confirm:(NSWindow*)parent title:(NSString*)title text:(NSString*)text
{
  [confirmPanelText setStringValue:text];
  [confirmPanel setTitle:title];

  int result = [NSApp runModalForWindow:confirmPanel relativeToWindow:parent];
  
  [confirmPanel close];

  return (result == 1);
}

- (BOOL)confirmCheck:(NSWindow*)parent title:(NSString*)title text:(NSString*)text checkMsg:(NSString*)checkMsg checkValue:(BOOL*)checkValue
{
  [confirmCheckPanelText setStringValue:text];
  [confirmCheckPanel setTitle:title];
  int state = (*checkValue ? NSOnState : NSOffState);
  [confirmCheckPanelCheck setState:state];
  [confirmCheckPanelCheck setTitle:checkMsg];

  int result = [NSApp runModalForWindow:confirmCheckPanel relativeToWindow:parent];

  *checkValue = ([confirmCheckPanelCheck state] == NSOnState);
  [confirmCheckPanel close];

  return (result == 1);
}

- (int)confirmEx:(NSWindow*)parent title:(NSString*)title text:(NSString*)text
   button1:(NSString*)btn1 button2:(NSString*)btn2 button3:(NSString*)btn3
{
  printf("ConfirmEx invoked, and this is not yet implemented!\n");
  return 0;
}

- (int)confirmCheckEx:(NSWindow*)parent title:(NSString*)title text:(NSString*)text 
  button1:(NSString*)btn1 button2:(NSString*)btn2 button3:(NSString*)btn3
  checkMsg:(NSString*)checkMsg checkValue:(BOOL*)checkValue
{
  printf("ConfirmCheckEx invoked, and this is not yet implemented!\n");
  return 0;
}

- (BOOL)prompt:(NSWindow*)parent title:(NSString*)title text:(NSString*)text promptText:(NSMutableString*)promptText checkMsg:(NSString*)checkMsg checkValue:(BOOL*)checkValue doCheck:(BOOL)doCheck
{
  [promptPanelText setStringValue:text];
  [promptPanel setTitle:title];
  if (doCheck) {
    int state = (*checkValue ? NSOnState : NSOffState);
    [promptPanelCheck setState:state];
    [promptPanelCheck setEnabled:YES];
  }
  else {
    [promptPanelCheck setEnabled:NO];
  }  
  [promptPanelCheck setTitle:checkMsg];
  [promptPanelInput setStringValue:promptText];

  int result = [NSApp runModalForWindow:promptPanel relativeToWindow:parent];

  *checkValue = ([promptPanelCheck state] == NSOnState);

  NSString* value = [promptPanelInput stringValue];
  PRUint32 length = [promptText length];
  if (length) {
    NSRange all;
    all.location = 0;
    all.length = [promptText length];
    [promptText deleteCharactersInRange:all];
  }
  [promptText appendString:value];

  [promptPanel close];

  return (result == 1);	
}

- (BOOL)promptUserNameAndPassword:(NSWindow*)parent title:(NSString*)title text:(NSString*)text userNameText:(NSMutableString*)userNameText passwordText:(NSMutableString*)passwordText checkMsg:(NSString*)checkMsg checkValue:(BOOL*)checkValue doCheck:(BOOL)doCheck
{
  [usernamePanelText setStringValue:text];
  [usernamePanel setTitle:title];
  if (doCheck) {
    int state = (*checkValue ? NSOnState : NSOffState);
    [usernamePanelCheck setState:state];
    [usernamePanelCheck setEnabled:YES];
  }
  else {
    [usernamePanelCheck setEnabled:NO];
  }  
  [usernamePanelCheck setTitle:checkMsg];
  [usernamePanelPassword setStringValue:passwordText];
  [usernamePanelUserName setStringValue:userNameText];

  int result = [NSApp runModalForWindow:usernamePanel relativeToWindow:parent];

  *checkValue = ([usernamePanelCheck state] == NSOnState);

  NSString* value = [usernamePanelUserName stringValue];
  PRUint32 length = [userNameText length];
  if (length) {
    NSRange all;
    all.location = 0;
    all.length = [userNameText length];
    [userNameText deleteCharactersInRange:all];
  }
  [userNameText appendString:value];

  value = [usernamePanelPassword stringValue];
  length = [passwordText length];
  if (length) {
    NSRange all;
    all.location = 0;
    all.length = [passwordText length];
    [passwordText deleteCharactersInRange:all];
  }
  [passwordText appendString:value];

  [usernamePanel close];

  return (result == 1);	
}

- (BOOL)promptPassword:(NSWindow*)parent title:(NSString*)title text:(NSString*)text passwordText:(NSMutableString*)passwordText checkMsg:(NSString*)checkMsg checkValue:(BOOL*)checkValue doCheck:(BOOL)doCheck
{
  [passwordPanelText setStringValue:text];
  [passwordPanel setTitle:title];
  if (doCheck) {
    int state = (*checkValue ? NSOnState : NSOffState);
    [passwordPanelCheck setState:state];
    [passwordPanelCheck setEnabled:YES];
  }
  else {
    [passwordPanelCheck setEnabled:NO];
  }  
  [passwordPanelCheck setTitle:checkMsg];
  [passwordPanelInput setStringValue:passwordText];

  int result = [NSApp runModalForWindow:passwordPanel relativeToWindow:parent];

  *checkValue = ([passwordPanelCheck state] == NSOnState);

  NSString* value = [passwordPanelInput stringValue];
  PRUint32 length = [passwordText length];
  if (length) {
    NSRange all;
    all.location = 0;
    all.length = [passwordText length];
    [passwordText deleteCharactersInRange:all];
  }
  [passwordText appendString:value];

  [passwordPanel close];

  return (result == 1);	
}


- (BOOL)badCert:(NSWindow*)parent
{
  int result = [NSApp runModalForWindow:securityMismatchPanel relativeToWindow:parent];
  [securityMismatchPanel close];

  return (result == 1);
}

- (int)unknownCert:(NSWindow*)parent
{
  int result = [NSApp runModalForWindow:securityUnknownPanel relativeToWindow:parent];
  [securityUnknownPanel close];

  return result;
}

@end
