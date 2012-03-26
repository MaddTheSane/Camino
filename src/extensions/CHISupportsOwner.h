/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Foundation/Foundation.h>

// 
// CHISupportsOwner is a simple Obj-C class whose only task is to
// keep an add-reffed pointer to an XPCOM object. This allows you to
// put XPCOM objects into Cocoa containers, and have them retained.
// 

@interface CHISupportsOwner : NSObject
{
@private

  nsISupports*            mISupports;   // AddReffed (that's the point of this class)
}

- (id)initWithValue:(nsISupports*)inValue;

- (void)setValue:(nsISupports*)inValue;
- (nsISupports*)value;    // return value not addreffed

@end
