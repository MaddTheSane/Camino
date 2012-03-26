/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Foundation/Foundation.h>


// Cocoa wrapper for the Breakpad framework. This is not a true singleton, in
// that it is expected to be explicitly alloc'd and released, but there should
// never be more than one created in an application.
// Creating a BreakpadWrapper instance will set up Breakpad for crash reporting,
// and releasing it will shut Breakpad down.
@interface BreakpadWrapper : NSObject {
  void* mBreakpadReference;
}

// Returns the global breakpad instance, if there is one. If breakpad has not
// been set up, this will return nil.
+ (BreakpadWrapper*)sharedInstance;

// Sets the URL that should be sent with any crash report. This should be
// called whenever we believe that a new URL is "active".
- (void)setReportedURL:(NSString*)url;

@end
