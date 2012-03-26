/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <AppKit/AppKit.h>

@interface ExtendedTableView : NSTableView
{
  SEL mDeleteAction;
}

-(void)setDeleteAction: (SEL)deleteAction;
-(SEL)deleteAction;

@end

// Informal protocol for delegates to handle context menus.
@interface NSObject (TableViewContextMenuDelegate)

- (NSMenu *)tableView:(NSTableView *)aTableView contextMenuForRow:(int)rowIndex;

@end
