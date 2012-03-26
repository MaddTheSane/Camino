/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>

// this implements the mozWindow protocol (see mozView.h)

@interface BrowserWindow : NSWindow
{
  // mSuppressSetVisible is used to overcome a problem of communication between
  // gecko and the front end. Gecko tries to make the window visible and frontmost
  // on every focus() call, and we don't want that.
  BOOL       	mSuppressMakeKeyFront;
}

- (BOOL)makeFirstResponder:(NSResponder*) responder;

- (void)resignKeyAndOrderBack;

// mozWindow protocol
- (BOOL)suppressMakeKeyFront;
- (void)setSuppressMakeKeyFront:(BOOL)inSuppress;

// scripting
- (NSString*)getURL;

// look and feel
- (BOOL)hasUnifiedToolbarAppearance;

@end
