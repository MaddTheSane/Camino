/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>

//
// SessionManager
//
// A shared object capable of saving and restoring the application state
// so that user sessions can be persisted across quit/relaunch.
//
@interface SessionManager : NSObject
{
  NSString* mSessionStatePath;    // strong
  NSTimer*  mDelayedPersistTimer; // strong
  BOOL      mDirty;
}

+ (SessionManager*)sharedInstance;

// Notifies the SessionManager that the window state has changed. This
// will eventually cause the window state to be saved to a file in the
// profile directory, but changes may be coalesced before saving.
- (void)windowStateChanged;

// Immediately saves the window state to a file in the profile directory.
- (void)saveWindowState;

// Restores the window state from a file in the profile directory.
- (void)restoreWindowState;

// Deletes the window state file from the profile directory.
- (void)clearSavedState;

// Indicates whether there is persisted state available to restore.
- (BOOL)hasSavedState;

@end
