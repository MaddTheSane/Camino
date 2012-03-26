/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
* License, v. 2.0. If a copy of the MPL was not distributed with this
* file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>

//
// ThumbnailView
//
// The ThumbnailView is primarly used as a subview for TabThumbnailGridView.
// It draws its set thumbnail with a dropshadow.
//

@interface ThumbnailView : NSView {
  NSImage*  mThumbnail;
  NSObject* mRepresentedObject;
  NSCell*   mTitleCell;
  id        mDelegate;
}

- (void)setThumbnail:(NSImage*)image;
- (void)setRepresentedObject:(id)object;
- (id)representedObject;
- (void)setTitle:(NSString*)title;
- (void)setDelegate:(id)delegate;
- (id)delegate;

@end

@interface NSObject (ThumbnailViewDelegate)

- (void)thumbnailViewWasSelected:(ThumbnailView*)selectedView;

@end
