/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <AppKit/AppKit.h>

@interface ExtendedSplitView : NSSplitView
{
  NSString*       mAutosaveName;             // owned
  BOOL            mAutosaveSplitterPosition;
  NSMutableDictionary* mCollapsedSubviews;   // owned
}

- (void)setAutosaveName:(NSString *)name;
- (NSString *)autosaveName;

- (BOOL)autosaveSplitterPosition;
- (void)setAutosaveSplitterPosition:(BOOL)inAutosave;

- (void)collapseSubviewAtIndex:(int)inIndex;

@end
