/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>

@class CHGradient;

extern NSString* const kWillShowFeedMenuNotification;

extern const int kPartitionViewTag;

// Container view for icons displayed at the end of the location bar.
@interface LocationBarPartitionView : NSView
{
  CHGradient*  mTopGradient;           // owned
  CHGradient*  mBottomGradient;        // owned
  CHGradient*  mLineGradient;          // owned
  NSColor*     mClearColor;            // owned

  NSImage*     mSecureImage;           // owned
  NSImage*     mFeedImage;             // owned

  NSMenu*      mSecureIconContextMenu; // owned

  BOOL         mDisplayFeedIcon;
  BOOL         mDisplaySecureIcon;

  NSRect       mSecureIconRect;
  NSRect       mFeedIconRect;
}

// Sets the visibility of the feed icon.
- (void)setDisplayFeedIcon:(BOOL)display;

// Sets the visibility of the secure icon.
- (void)setDisplaySecureIcon:(BOOL)display;

// Sets the image used by the secure icon.
- (void)setSecureImage:(NSImage *)image;

// Sets the context menu displayed when the secure icon is clicked.
- (void)setSecureIconContextMenu:(NSMenu *)aMenu;

// Returns the width of the opaque portion of the partition view.
- (float)opaqueWidth;

@end
