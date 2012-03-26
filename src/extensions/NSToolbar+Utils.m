
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "NSToolbar+Utils.h"
#import <Foundation/Foundation.h>

@implementation NSToolbar (CHToolbarCustomizableAdditions)

- (BOOL)alwaysCustomizableByDrag
{
  return (BOOL) _tbFlags.clickAndDragPerformsCustomization;
}

- (void)setAlwaysCustomizableByDrag:(BOOL)flag
{
  _tbFlags.clickAndDragPerformsCustomization = (unsigned int) flag & 1;
}

- (BOOL)showsContextMenu
{
  return (BOOL) ! _tbFlags.showsNoContextMenu;
}

- (void)setShowsContextMenu:(BOOL)flag
{
  _tbFlags.showsNoContextMenu = (unsigned int) ! flag & 1;
}

- (unsigned int)indexOfFirstMovableItem
{
  return (unsigned int) _tbFlags.firstMoveableItemIndex;
}

- (void)setIndexOfFirstMovableItem:(unsigned int)anIndex
{
  _tbFlags.firstMoveableItemIndex = (unsigned int) anIndex & 0x3F;
}

@end
