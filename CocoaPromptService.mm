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
 *  Brian Ryner <bryner@netscape.com>
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

#import "nsCocoaBrowserService.h"
#import "CocoaPromptService.h"

#include "nsCRT.h"
#include "nsIWindowWatcher.h"
#include "nsIWebBrowserChrome.h"
#include "nsIEmbeddingSiteWindow.h"
#include "nsString.h"
#include "nsIServiceManagerUtils.h"

CocoaPromptService::CocoaPromptService()
{
  NS_INIT_ISUPPORTS();
}

CocoaPromptService::~CocoaPromptService()
{
}

NS_IMPL_ISUPPORTS1(CocoaPromptService, nsIPromptService);

/* void alert (in nsIDOMWindow parent, in wstring dialogTitle, in wstring text); */
NS_IMETHODIMP
CocoaPromptService::Alert(nsIDOMWindow *parent,
                          const PRUnichar *dialogTitle,
                          const PRUnichar *text)
{
  nsAlertController* controller = nsCocoaBrowserService::GetAlertController();
  if (!controller) {
    return NS_ERROR_FAILURE;
  }

  NSString* titleStr = [NSString stringWithCharacters:dialogTitle length:(dialogTitle ? nsCRT::strlen(dialogTitle) : 0)];
  NSString* textStr = [NSString stringWithCharacters:text length:(text ? nsCRT::strlen(text) : 0)];
  NSWindow* window = GetNSWindowForDOMWindow(parent);
  if (!window)
    return NS_ERROR_FAILURE;

  [controller alert:window title:titleStr text:textStr];

  return NS_OK;
}

/* void alertCheck (in nsIDOMWindow parent, in wstring dialogTitle, in wstring text, in wstring checkMsg, inout boolean checkValue); */
NS_IMETHODIMP
CocoaPromptService::AlertCheck(nsIDOMWindow *parent,
                               const PRUnichar *dialogTitle,
                               const PRUnichar *text,
                               const PRUnichar *checkMsg,
                               PRBool *checkValue)
{
  nsAlertController* controller = nsCocoaBrowserService::GetAlertController();
  if (!controller) {
    return NS_ERROR_FAILURE;
  }

  NSString* titleStr = [NSString stringWithCharacters:dialogTitle length:(dialogTitle ? nsCRT::strlen(dialogTitle) : 0)];
  NSString* textStr = [NSString stringWithCharacters:text length:(text ? nsCRT::strlen(text) : 0)];
  NSString* msgStr = [NSString stringWithCharacters:checkMsg length:(checkMsg ? nsCRT::strlen(checkMsg) : 0)];
  NSWindow* window = GetNSWindowForDOMWindow(parent);

  if (checkValue) {
    BOOL valueBool = *checkValue ? YES : NO;

    [controller alertCheck:window title:titleStr text:textStr checkMsg:msgStr checkValue:&valueBool];

    *checkValue = (valueBool == YES) ? PR_TRUE : PR_FALSE;
  }
  else {
    [controller alert:window title:titleStr text:textStr];
  }

  return NS_OK;
}

/* boolean confirm (in nsIDOMWindow parent, in wstring dialogTitle, in wstring text); */
NS_IMETHODIMP
CocoaPromptService::Confirm(nsIDOMWindow *parent,
                            const PRUnichar *dialogTitle,
                            const PRUnichar *text,
                            PRBool *_retval)
{
  nsAlertController* controller = nsCocoaBrowserService::GetAlertController();
  if (!controller) {
    return NS_ERROR_FAILURE;
  }

  NSString* titleStr = [NSString stringWithCharacters:dialogTitle length:(dialogTitle ? nsCRT::strlen(dialogTitle) : 0)];
  NSString* textStr = [NSString stringWithCharacters:text length:(text ? nsCRT::strlen(text) : 0)];
  NSWindow* window = GetNSWindowForDOMWindow(parent);

  *_retval = (PRBool)[controller confirm:window title:titleStr text:textStr];

  return NS_OK;
}

/* boolean confirmCheck (in nsIDOMWindow parent, in wstring dialogTitle, in wstring text, in wstring checkMsg, inout boolean checkValue); */
NS_IMETHODIMP
CocoaPromptService::ConfirmCheck(nsIDOMWindow *parent,
                                 const PRUnichar *dialogTitle,
                                 const PRUnichar *text,
                                 const PRUnichar *checkMsg,
                                 PRBool *checkValue, PRBool *_retval)
{
  nsAlertController* controller = nsCocoaBrowserService::GetAlertController();
  if (!controller) {
    return NS_ERROR_FAILURE;
  }

  NSString* titleStr = [NSString stringWithCharacters:dialogTitle length:(dialogTitle ? nsCRT::strlen(dialogTitle) : 0)];
  NSString* textStr = [NSString stringWithCharacters:text length:(text ? nsCRT::strlen(text) : 0)];
  NSString* msgStr = [NSString stringWithCharacters:checkMsg length:(checkMsg ? nsCRT::strlen(checkMsg) : 0)];
  NSWindow* window = GetNSWindowForDOMWindow(parent);

  if (checkValue) {
    BOOL valueBool = *checkValue ? YES : NO;

    *_retval = (PRBool)[controller confirmCheck:window title:titleStr text:textStr checkMsg:msgStr checkValue:&valueBool];

    *checkValue = (valueBool == YES) ? PR_TRUE : PR_FALSE;
  }
  else {
    *_retval = (PRBool)[controller confirm:window title:titleStr text:textStr];
  }

  return NS_OK;
}

// these constants are used for identifying the buttons and are intentionally overloaded to
// correspond to the number of bits needed for shifting to obtain the flags for a particular
// button (should be defined in nsIPrompt*.idl instead of here)
const PRUint32 kButton0 = 0;
const PRUint32 kButton1 = 8;
const PRUint32 kButton2 = 16;

/* void confirmEx (in nsIDOMWindow parent, in wstring dialogTitle, in wstring text, in unsigned long buttonFlags, in wstring button0Title, in wstring button1Title, in wstring button2Title, in wstring checkMsg, inout boolean checkValue, out PRInt32 buttonPressed); */
NS_IMETHODIMP
CocoaPromptService::ConfirmEx(nsIDOMWindow *parent,
                              const PRUnichar *dialogTitle,
                              const PRUnichar *text,
                              PRUint32 buttonFlags,
                              const PRUnichar *button0Title,
                              const PRUnichar *button1Title,
                              const PRUnichar *button2Title,
                              const PRUnichar *checkMsg,
                              PRBool *checkValue, PRInt32 *buttonPressed)
{
  nsAlertController* controller = nsCocoaBrowserService::GetAlertController();
  if (!controller) {
    return NS_ERROR_FAILURE;
  }

  NSString* titleStr = [NSString stringWithCharacters:dialogTitle length:(dialogTitle ? nsCRT::strlen(dialogTitle) : 0)];
  NSString* textStr = [NSString stringWithCharacters:text length:(text ? nsCRT::strlen(text) : 0)];
  NSString* msgStr = [NSString stringWithCharacters:checkMsg length:(checkMsg ? nsCRT::strlen(checkMsg) : 0)];
  NSWindow* window = GetNSWindowForDOMWindow(parent);

  NSString* btn1Str = GetButtonStringFromFlags(buttonFlags, kButton0, button0Title);
  NSString* btn2Str = GetButtonStringFromFlags(buttonFlags, kButton1, button1Title);
  NSString* btn3Str = GetButtonStringFromFlags(buttonFlags, kButton2, button2Title);

  if (checkValue) {
    BOOL valueBool = *checkValue ? YES : NO;

    *buttonPressed = [controller confirmCheckEx:window title:titleStr text:textStr
                                        button1: btn1Str button2: btn2Str button3: btn3Str
                                       checkMsg:msgStr checkValue:&valueBool];

    *checkValue = (valueBool == YES) ? PR_TRUE : PR_FALSE;
  }
  else {
    *buttonPressed = [controller confirmEx:window title:titleStr text:textStr
                                   button1: btn1Str button2: btn2Str button3: btn3Str];
  }

  return NS_OK;

}


/* boolean prompt (in nsIDOMWindow parent, in wstring dialogTitle, in wstring text, inout wstring value, in wstring checkMsg, inout boolean checkValue); */
NS_IMETHODIMP
CocoaPromptService::Prompt(nsIDOMWindow *parent,
                           const PRUnichar *dialogTitle,
                           const PRUnichar *text,
                           PRUnichar **value,
                           const PRUnichar *checkMsg,
                           PRBool *checkValue,
                           PRBool *_retval)
{
  nsAlertController* controller = nsCocoaBrowserService::GetAlertController();
  if (!controller) {
    return NS_ERROR_FAILURE;
  }

  NSString* titleStr = [NSString stringWithCharacters:dialogTitle length:(dialogTitle ? nsCRT::strlen(dialogTitle) : 0)];
  NSString* textStr = [NSString stringWithCharacters:text length:(text ? nsCRT::strlen(text) : 0)];
  NSString* msgStr = [NSString stringWithCharacters:checkMsg length:(checkMsg ? nsCRT::strlen(checkMsg) : 0)];
  NSMutableString* valueStr = [NSMutableString stringWithCharacters:*value length:(*value ? nsCRT::strlen(*value) : 0)];

  BOOL valueBool;
  if (checkValue) {
    valueBool = *checkValue ? YES : NO;
  }
  NSWindow* window = GetNSWindowForDOMWindow(parent);

  *_retval = (PRBool)[controller prompt:window title:titleStr text:textStr promptText:valueStr checkMsg:msgStr checkValue:&valueBool doCheck:(checkValue != nsnull)];

  if (checkValue) {
    *checkValue = (valueBool == YES) ? PR_TRUE : PR_FALSE;
  }
  PRUint32 length = [valueStr length];
  PRUnichar* retStr = (PRUnichar*)nsMemory::Alloc((length + 1) * sizeof(PRUnichar));
  [valueStr getCharacters:retStr];
  retStr[length] = PRUnichar(0);
  *value = retStr;

  return NS_OK;
}

/* boolean promptUsernameAndPassword (in nsIDOMWindow parent, in wstring dialogTitle, in wstring text, inout wstring username, inout wstring password, in wstring checkMsg, inout boolean checkValue); */
NS_IMETHODIMP
CocoaPromptService::PromptUsernameAndPassword(nsIDOMWindow *parent,
                                              const PRUnichar *dialogTitle,
                                              const PRUnichar *text,
                                              PRUnichar **username,
                                              PRUnichar **password,
                                              const PRUnichar *checkMsg,
                                              PRBool *checkValue,
                                              PRBool *_retval)
{
  nsAlertController* controller = nsCocoaBrowserService::GetAlertController();
  if (!controller) {
    return NS_ERROR_FAILURE;
  }

  NSString* titleStr = [NSString stringWithCharacters:dialogTitle length:(dialogTitle ? nsCRT::strlen(dialogTitle) : 0)];
  NSString* textStr = [NSString stringWithCharacters:text length:(text ? nsCRT::strlen(text) : 0)];
  NSString* msgStr = [NSString stringWithCharacters:checkMsg length:(checkMsg ? nsCRT::strlen(checkMsg) : 0)];
  NSMutableString* userNameStr = [NSMutableString stringWithCharacters:*username length:(*username ? nsCRT::strlen(*username) : 0)];
  NSMutableString* passwordStr = [NSMutableString stringWithCharacters:*password length:(*password ? nsCRT::strlen(*password) : 0)];

  BOOL valueBool;
  if (checkValue) {
    valueBool = *checkValue ? YES : NO;
  }
  NSWindow* window = GetNSWindowForDOMWindow(parent);

  *_retval = (PRBool)[controller promptUserNameAndPassword:window title:titleStr text:textStr userNameText:userNameStr passwordText:passwordStr checkMsg:msgStr checkValue:&valueBool doCheck:(checkValue != nsnull)];

  if (checkValue) {
    *checkValue = (valueBool == YES) ? PR_TRUE : PR_FALSE;
  }

  PRUint32 length = [userNameStr length];
  PRUnichar* retStr = (PRUnichar*)nsMemory::Alloc((length + 1) * sizeof(PRUnichar));
  [userNameStr getCharacters:retStr];
  retStr[length] = PRUnichar(0);
  *username = retStr;

  length = [passwordStr length];
  retStr = (PRUnichar*)nsMemory::Alloc((length + 1) * sizeof(PRUnichar));
  [passwordStr getCharacters:retStr];
  retStr[length] = PRUnichar(0);
  *password = retStr;

  return NS_OK;
}

/* boolean promptPassword (in nsIDOMWindow parent, in wstring dialogTitle, in wstring text, inout wstring password, in wstring checkMsg, inout boolean checkValue); */
NS_IMETHODIMP
CocoaPromptService::PromptPassword(nsIDOMWindow *parent,
                                   const PRUnichar *dialogTitle,
                                   const PRUnichar *text,
                                   PRUnichar **password,
                                   const PRUnichar *checkMsg,
                                   PRBool *checkValue,
                                   PRBool *_retval)
{
  nsAlertController* controller = nsCocoaBrowserService::GetAlertController();
  if (!controller) {
    return NS_ERROR_FAILURE;
  }

  NSString* titleStr = [NSString stringWithCharacters:dialogTitle length:(dialogTitle ? nsCRT::strlen(dialogTitle) : 0)];
  NSString* textStr = [NSString stringWithCharacters:text length:(text ? nsCRT::strlen(text) : 0)];
  NSString* msgStr = [NSString stringWithCharacters:checkMsg length:(checkMsg ? nsCRT::strlen(checkMsg) : 0)];
  NSMutableString* passwordStr = [NSMutableString stringWithCharacters:*password length:(*password ? nsCRT::strlen(*password) : 0)];

  BOOL valueBool;
  if (checkValue) {
    valueBool = *checkValue ? YES : NO;
  }
  NSWindow* window = GetNSWindowForDOMWindow(parent);

  *_retval = (PRBool)[controller promptPassword:window title:titleStr text:textStr passwordText:passwordStr checkMsg:msgStr checkValue:&valueBool doCheck:(checkValue != nsnull)];

  if (checkValue) {
    *checkValue = (valueBool == YES) ? PR_TRUE : PR_FALSE;
  }

  PRUint32 length = [passwordStr length];
  PRUnichar* retStr = (PRUnichar*)nsMemory::Alloc((length + 1) * sizeof(PRUnichar));
  [passwordStr getCharacters:retStr];
  retStr[length] = PRUnichar(0);
  *password = retStr;

  return NS_OK;
}

/* boolean select (in nsIDOMWindow parent, in wstring dialogTitle, in wstring text, in PRUint32 count, [array, size_is (count)] in wstring selectList, out long outSelection); */
NS_IMETHODIMP
CocoaPromptService::Select(nsIDOMWindow *parent,
                           const PRUnichar *dialogTitle,
                           const PRUnichar *text,
                           PRUint32 count,
                           const PRUnichar **selectList,
                           PRInt32 *outSelection,
                           PRBool *_retval)
{
#if DEBUG
  NSLog(@"Uh-oh. Select has not been implemented.");
#endif
  return NS_ERROR_NOT_IMPLEMENTED;
}


NSWindow*
CocoaPromptService::GetNSWindowForDOMWindow(nsIDOMWindow* window)
{
  nsCOMPtr<nsIWindowWatcher> watcher(do_GetService("@mozilla.org/embedcomp/window-watcher;1"));
  if (!watcher) {
    return nsnull;
  }

  nsCOMPtr<nsIWebBrowserChrome> chrome;
  watcher->GetChromeForWindow(window, getter_AddRefs(chrome));
  if (!chrome) {
    return nsnull;
  }

  nsCOMPtr<nsIEmbeddingSiteWindow> siteWindow(do_QueryInterface(chrome));
  if (!siteWindow) {
    return nsnull;
  }

  NSWindow* nswin;
  nsresult rv = siteWindow->GetSiteWindow((void**)&nswin);
  if (NS_FAILED(rv))
    return nsnull;

  return nswin;
}

NSString *
CocoaPromptService::GetCommonDialogLocaleString(const char *key)
{
  NSString *returnValue = @"";

  nsresult rv;
  if (!mCommonDialogStringBundle) {
#define kCommonDialogsStrings "chrome://global/locale/commonDialogs.properties"
    nsCOMPtr<nsIStringBundleService> service = do_GetService(NS_STRINGBUNDLE_CONTRACTID);
    if ( service )
      rv = service->CreateBundle(kCommonDialogsStrings, getter_AddRefs(mCommonDialogStringBundle));
    else
      rv = NS_ERROR_FAILURE;
    if (NS_FAILED(rv)) return returnValue;
  }

  nsXPIDLString string;
  rv = mCommonDialogStringBundle->GetStringFromName(NS_ConvertASCIItoUCS2(key).get(), getter_Copies(string));
  if (NS_FAILED(rv)) return returnValue;

  returnValue = [NSString stringWithCharacters:string length:(string ? nsCRT::strlen(string) : 0)];
  return returnValue;
}

NSString *
CocoaPromptService::GetButtonStringFromFlags(PRUint32 btnFlags,
                                             PRUint32 btnIDAndShift,
                                             const PRUnichar *btnTitle)
{
  NSString *btnStr = nsnull;
  switch ((btnFlags >> btnIDAndShift) & 0xff) {
    case BUTTON_TITLE_OK:
      btnStr = GetCommonDialogLocaleString("OK");
      break;
    case BUTTON_TITLE_CANCEL:
      btnStr = GetCommonDialogLocaleString("Cancel");
      break;
    case BUTTON_TITLE_YES:
      btnStr = GetCommonDialogLocaleString("Yes");
      break;
    case BUTTON_TITLE_NO:
      btnStr = GetCommonDialogLocaleString("No");
      break;
    case BUTTON_TITLE_SAVE:
      btnStr = GetCommonDialogLocaleString("Save");
      break;
    case BUTTON_TITLE_DONT_SAVE:
      btnStr = GetCommonDialogLocaleString("DontSave");
      break;
    case BUTTON_TITLE_REVERT:
      btnStr = GetCommonDialogLocaleString("Revert");
      break;
    case BUTTON_TITLE_IS_STRING:
      btnStr = [NSString stringWithCharacters:btnTitle length:(btnTitle ? nsCRT::strlen(btnTitle) : 0)];
  }

  return btnStr;
}
