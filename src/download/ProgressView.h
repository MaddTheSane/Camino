/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */


#import <AppKit/AppKit.h>

@class ProgressViewController;

//
// interface ProgressView
//
// A NSView representing the state of a download in the download manager. There
// will be two of these per download: one for while it's downloading, the other
// for after it complete.
//

@interface ProgressView : NSView
{
@private
  IBOutlet NSImageView*   mFileIconView;
  ProgressViewController* mProgressController;     // WEAK reference
  NSEvent*                mFileIconMouseDownEvent; // STRONG reference

  NSColor*                mFilenameLabelUnselectedColor;
  NSColor*                mStatusLabelUnselectedColor;
  NSColor*                mTimeLabelUnselectedColor;
}

- (void)selectionChanged;

- (void)updateStatus:(NSString*)status;
- (void)updateFilename:(NSString*)filename;
- (void)updateTimeRemaining:(NSString*)timeRemaining;
- (void)updateFileIcon:(NSImage*)fileIcon;

// get/set our owning controller, to which we maintain a weak link
- (void)setController:(ProgressViewController*)controller;
- (ProgressViewController*)controller;

@end
