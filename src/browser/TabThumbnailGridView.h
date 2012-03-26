/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
* License, v. 2.0. If a copy of the MPL was not distributed with this
* file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>

//
// TabThumbnailGridView
//
// The TabThumbnailGridView is used for displaying a quick overview
// of all the current tabs in its browser window.
//
// When this view is added to a browesr window it will proceed to take
// thumbnails of each site opened and lay them out in a grid.
//

@interface TabThumbnailGridView : NSView {
  unsigned int mNumCols;
  unsigned int mNumRows;
}

@end
