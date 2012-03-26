/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <AppKit/AppKit.h>
#import "ExtendedOutlineView.h"

// subclassed to override some drag and drop methods
@interface BookmarkOutlineView : ExtendedOutlineView
{
}

// Actions for the edit menu
- (BOOL)validateMenuItem:(id)aMenuItem;
- (IBAction)delete:(id)aSender;

@end
