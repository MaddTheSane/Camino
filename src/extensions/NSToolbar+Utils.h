/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <AppKit/NSToolbar.h>

@interface NSToolbar (CHToolbarCustomizableAdditions)
- (BOOL)alwaysCustomizableByDrag;
- (void)setAlwaysCustomizableByDrag:(BOOL)flag;

- (BOOL)showsContextMenu;
- (void)setShowsContextMenu:(BOOL)flag;

- (unsigned int)indexOfFirstMovableItem;
- (void)setIndexOfFirstMovableItem:(unsigned int)anIndex;
@end
