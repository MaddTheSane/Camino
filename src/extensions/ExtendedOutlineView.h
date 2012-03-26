/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <AppKit/AppKit.h>

@interface ExtendedOutlineView : NSOutlineView
{
  SEL           mDeleteAction;

  NSRect        mOldFrameRect;
  int           mOldRows;
  BOOL          mDelegateImplementsTooltipStringForItem;

  int           mRowToBeEdited, mColumnToBeEdited;
  BOOL          mAllowsEditing;
  
  // sorting support
  NSImage*      mAscendingSortingImage;
  NSImage*      mDescendingSortingImage;
  
  NSString*     mSortColumnIdentifier;
  BOOL          mDescendingSort;
  
  BOOL          mAutosaveSort;
}

-(void)setAllowsEditing:(BOOL)inAllow;

-(void)keyDown:(NSEvent*)aEvent;

-(void)setDeleteAction: (SEL)deleteAction;
-(SEL)deleteAction;

- (NSArray*)selectedItems;

- (void)expandAllItems;

-(void)_editItem:(id)item;
-(void)_cancelEditItem;

// note that setting these just affect the outline state, they don't alter the data source
- (NSString*)sortColumnIdentifier;
- (void)setSortColumnIdentifier:(NSString*)inColumnIdentifier;

- (BOOL)sortDescending;
- (void)setSortDescending:(BOOL)inDescending;

- (void)setAutosaveTableSort:(BOOL)autosave;
- (BOOL)autosaveTableSort;

// Clipboard functions
-(BOOL) validateMenuItem:(id)aMenuItem;
-(IBAction) copy:(id)aSender;
-(IBAction) delete:(id)aSender;
-(IBAction) paste:(id)aSender;
-(IBAction) cut:(id)aSender;

@end

@interface NSObject (CHOutlineViewDataSourceToolTips)
- (NSString *)outlineView:(NSOutlineView *)outlineView tooltipStringForItem:(id)item;
@end

@interface NSObject (CHOutlneViewDataSourceInlineEditing)
- (BOOL)outlineView:(NSOutlineView*)inOutlineView columnHasIcon:(NSTableColumn*)inColumn;
@end

@interface NSObject (CHOutlineViewContextMenus)
- (NSMenu *)outlineView:(NSOutlineView *)outlineView contextMenuForItems:(NSArray*)items;
@end

@interface NSObject (CHOutlineViewDragSource)
- (unsigned int)outlineView:(NSOutlineView *)outlineView draggingSourceOperationMaskForLocal:(BOOL)localFlag;
@end

