/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#ifndef nsAboutBookmarks_h__
#define nsAboutBookmarks_h__

#include "nsIAboutModule.h"

class nsAboutBookmarks : public nsIAboutModule
{
public:
    NS_DECL_ISUPPORTS

    NS_DECL_NSIABOUTMODULE

                      nsAboutBookmarks(PRBool inIsBookmarks);
    virtual           ~nsAboutBookmarks() {}

    static NS_METHOD  CreateBookmarks(nsISupports *aOuter, REFNSIID aIID, void **aResult);
    static NS_METHOD  CreateHistory(nsISupports *aOuter, REFNSIID aIID, void **aResult);

protected:

    PRBool            mIsBookmarks;   // or history
};

#define NS_ABOUT_BOOKMARKS_MODULE_CID                 \
{ /* AF110FA0-8C4D-11D9-83C4-00 03 93 D7 25 4A */     \
    0xAF110FA0,                                       \
    0x8C4D,                                           \
    0x11D9,                                           \
    { 0x83, 0xC4, 0x00, 0x03, 0x93, 0xD7, 0x25, 0x4A} \
}

#endif // nsAboutBookmarks_h__
