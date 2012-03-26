/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */


#import "nsISupportsUtils.h"

#import "CHISupportsOwner.h"

@implementation CHISupportsOwner

- (id)initWithValue:(nsISupports*)inValue
{
  if ((self = [super init]))
  {
    mISupports = inValue;
    NS_IF_ADDREF(mISupports);
  }
  return self;
}

- (void)dealloc
{
  NS_IF_RELEASE(mISupports);
  [super dealloc];
}

- (void)setValue:(nsISupports*)inValue
{
  if (mISupports != inValue)
  {
    NS_IF_RELEASE(mISupports);
    mISupports = inValue;
    NS_IF_ADDREF(mISupports);
  }
}

- (nsISupports*)value
{
  return mISupports;
}

@end
