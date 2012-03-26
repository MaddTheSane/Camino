/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Foundation/Foundation.h>
#include "nsAboutBookmarks.h"

#include "nsIIOService.h"
#include "nsIServiceManager.h"
#include "nsStringStream.h"
#include "nsNetUtil.h"

#import "NSString+Gecko.h"

NS_IMPL_ISUPPORTS1(nsAboutBookmarks, nsIAboutModule)

nsAboutBookmarks::nsAboutBookmarks(PRBool inIsBookmarks)
: mIsBookmarks(inIsBookmarks)
{
}

NS_IMETHODIMP
nsAboutBookmarks::NewChannel(nsIURI *aURI, nsIChannel **result)
{
    static NSString* const kBlankPageHTML = @"<!DOCTYPE html PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\"> <html><head><title>%@</title></head><body></body></html>";

    nsresult rv;

    NSString* windowTitle = mIsBookmarks ? NSLocalizedString(@"BookmarksWindowTitle", nil)
                                         : NSLocalizedString(@"HistoryWindowTitle", nil);

    NSString* sourceString = [NSString stringWithFormat:kBlankPageHTML, windowTitle];
    nsAutoString pageSource;
    [sourceString assignTo_nsAString:pageSource];

    nsCOMPtr<nsIInputStream> in;
    rv = NS_NewCStringInputStream(getter_AddRefs(in),
                                  NS_ConvertUTF16toUTF8(pageSource));
    NS_ENSURE_SUCCESS(rv, rv);

    nsIChannel* channel = NULL;
    rv = NS_NewInputStreamChannel(&channel, aURI, in,
                                  NS_LITERAL_CSTRING("text/html"),
                                  NS_LITERAL_CSTRING("UTF8"));
    NS_ENSURE_SUCCESS(rv, rv);

    *result = channel;
    return rv;
}

NS_IMETHODIMP
nsAboutBookmarks::GetURIFlags(nsIURI *aURI, PRUint32 *result)
{
    *result = 0;
    return NS_OK;
}

NS_METHOD
nsAboutBookmarks::CreateBookmarks(nsISupports *aOuter, REFNSIID aIID, void **aResult)
{
    nsAboutBookmarks* about = new nsAboutBookmarks(PR_TRUE);
    if (about == nsnull)
        return NS_ERROR_OUT_OF_MEMORY;
    NS_ADDREF(about);
    nsresult rv = about->QueryInterface(aIID, aResult);
    NS_RELEASE(about);
    return rv;
}

NS_METHOD
nsAboutBookmarks::CreateHistory(nsISupports *aOuter, REFNSIID aIID, void **aResult)
{
    nsAboutBookmarks* about = new nsAboutBookmarks(PR_FALSE);
    if (about == nsnull)
        return NS_ERROR_OUT_OF_MEMORY;
    NS_ADDREF(about);
    nsresult rv = about->QueryInterface(aIID, aResult);
    NS_RELEASE(about);
    return rv;
}
