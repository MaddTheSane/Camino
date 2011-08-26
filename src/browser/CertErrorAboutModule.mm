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
 * The Original Code is Camino code.
 *
 * The Initial Developer of the Original Code is
 * Sean Murphy.
 * Portions created by the Initial Developer are Copyright (C) 2008
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *   Sean Murphy <murph@seanmurph.com>
 *   Smokey Ardisson <alqahira@ardisson.org>
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

#import <Cocoa/Cocoa.h>
#import "NSString+Gecko.h"
#include "CertErrorAboutModule.h"
#import "PreferenceManager.h"

#include "nsCOMPtr.h"
#include "nsIChannel.h"
#include "nsIServiceManager.h"
#include "nsNetCID.h"
#include "nsString.h"
#include "nsIScriptSecurityManager.h"
#include "nsIPrincipal.h"
#include "nsStringStream.h"
#include "nsNetUtil.h"

// Placeholders in the certificate error HTML page to replace with localized strings.
static NSString *const kCertErrorTitleText = @"CertErrorTitleText";
static NSString *const kCertErrorPageHeadingText = @"CertErrorPageHeadingText";
static NSString *const kCertErrorIntroPara1 = @"CertErrorIntroPara1";
static NSString *const kCertErrorIntroPara2 = @"CertErrorIntroPara2";
static NSString *const kCertErrorAdviceHeadingText = @"CertErrorAdviceHeadingText";
static NSString *const kCertErrorAdviceText = @"CertErrorAdviceText";
static NSString *const kCertErrorGetMeOutButtonLabel = @"CertErrorGetMeOutButtonLabel";
static NSString *const kCertErrorTechnicalHeading = @"CertErrorTechnicalHeading";
static NSString *const kCertErrorExpertHeadingText = @"CertErrorExpertHeadingText";
static NSString *const kCertErrorExpertPara1 = @"CertErrorExpertPara1";
static NSString *const kCertErrorExpertPara2 = @"CertErrorExpertPara2";
static NSString *const kAddExceptionButtonLabel = @"AddExceptionButtonLabel";

NS_IMPL_ISUPPORTS1(CHCertErrorAboutModule, nsIAboutModule)

NS_IMETHODIMP
CHCertErrorAboutModule::NewChannel(nsIURI *aURI, nsIChannel **result)
{
  NS_ENSURE_ARG_POINTER(aURI);
  NS_ASSERTION(result, "must not be null");

  nsresult rv;

  nsCAutoString pageSource;
  rv = GetCertErrorPageSource(pageSource);
  NS_ENSURE_SUCCESS(rv, rv);

  nsCOMPtr<nsIInputStream> inputStream;
  rv = NS_NewCStringInputStream(getter_AddRefs(inputStream), pageSource);
  NS_ENSURE_SUCCESS(rv, rv);

  nsIChannel* channel = NULL;
  rv = NS_NewInputStreamChannel(&channel, aURI, inputStream,
                                NS_LITERAL_CSTRING("application/xhtml+xml"),
                                NS_LITERAL_CSTRING("UTF8"));
  NS_ENSURE_SUCCESS(rv, rv);

  channel->SetOriginalURI(aURI);

  nsCOMPtr<nsIScriptSecurityManager> securityManager = 
    do_GetService(NS_SCRIPTSECURITYMANAGER_CONTRACTID, &rv);
  NS_ENSURE_SUCCESS(rv, rv);

  nsCOMPtr<nsIPrincipal> principal;
  rv = securityManager->GetCodebasePrincipal(aURI, getter_AddRefs(principal));
  NS_ENSURE_SUCCESS(rv, rv);

  rv = channel->SetOwner(principal);
  NS_ENSURE_SUCCESS(rv, rv);

  *result = channel;
  NS_ADDREF(*result);
  return NS_OK;
}

NS_IMETHODIMP
CHCertErrorAboutModule::GetURIFlags(nsIURI *aURI, PRUint32 *result)
{
  // Since bad sites can cause this page to appear (e.g. by having an iframe pointing to 
  // another blacklisted site), we should allow URI_SAFE_FOR_UNTRUSTED_CONTENT.

  *result = nsIAboutModule::ALLOW_SCRIPT | nsIAboutModule::URI_SAFE_FOR_UNTRUSTED_CONTENT;
  return NS_OK;
}

NS_METHOD
CHCertErrorAboutModule::CreateCertErrorAboutModule(nsISupports *aOuter, REFNSIID aIID, void **aResult)
{
  CHCertErrorAboutModule *aboutModule = new CHCertErrorAboutModule();
  if (aboutModule == nsnull)
    return NS_ERROR_OUT_OF_MEMORY;
  NS_ADDREF(aboutModule);
  nsresult rv = aboutModule->QueryInterface(aIID, aResult);
  NS_RELEASE(aboutModule);
  return rv;
}

nsresult CHCertErrorAboutModule::GetCertErrorPageSource(nsACString &result) {

  NSString *pathToCertErrorPageSource = [[NSBundle mainBundle] pathForResource:@"certError"
                                                                          ofType:@"xhtml"];

  NSMutableString *CertErrorPageSource = [NSMutableString stringWithContentsOfFile:pathToCertErrorPageSource
                                                                            encoding:NSUTF8StringEncoding
                                                                               error:NULL];

  if (![CertErrorPageSource length] > 0)
    return NS_ERROR_FILE_NOT_FOUND;

  // Localize the certificate error page by swapping out placeholder strings.
  NSArray *stringPlaceholdersInPage = [NSArray arrayWithObjects:kCertErrorTitleText,
                                                                kCertErrorPageHeadingText,
                                                                kCertErrorIntroPara1,
                                                                kCertErrorIntroPara2,
                                                                kCertErrorAdviceHeadingText,
                                                                kCertErrorAdviceText,
                                                                kCertErrorGetMeOutButtonLabel,
                                                                kCertErrorTechnicalHeading,
                                                                kCertErrorExpertHeadingText,
                                                                kCertErrorExpertPara1,
                                                                kCertErrorExpertPara2,
                                                                kAddExceptionButtonLabel,
                                                                nil];

  NSEnumerator *placeholderEnum = [stringPlaceholdersInPage objectEnumerator];
  NSString *currentPlaceholder = nil;
  while ((currentPlaceholder = [placeholderEnum nextObject])) {
    [CertErrorPageSource replaceOccurrencesOfString:currentPlaceholder
                                           withString:NSLocalizedString(currentPlaceholder, nil)
                                              options:NULL
                                                range:NSMakeRange(0, [CertErrorPageSource length])];    
  }

  result.Assign([CertErrorPageSource UTF8String]);

  return NS_OK;
}
