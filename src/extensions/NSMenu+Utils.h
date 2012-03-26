/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <AppKit/AppKit.h>

@interface NSMenu(ChimeraMenuUtils)

// Closes all open menus.  Use this before displaying a modal sheet or dialog.
// Requires that setUpMenuTrackingWatch has been called at some point.
+ (void)cancelAllTracking;

// Returns whether or not some menu is currently in tracking mode.
// Requires that setUpMenuTrackingWatch has been called at some point.
+ (BOOL)currentyInMenuTracking;

// Turns on menu state watchers to enable use of the above methods. Only needs
// to be called once.
+ (void)setUpMenuTrackingWatch;


// check one item on a menu, optionally unchecking all the others
- (void)checkItemWithTag:(int)tag uncheckingOtherItems:(BOOL)uncheckOthers;

// treat a set of items each sharing the same tagMask as a radio group,
// turning on the one with the given unmasked tag value.
- (void)checkItemWithTag:(int)unmaskedTag inGroupWithMask:(int)tagMask;

// gets the first checked item in the menu, or nil if none are checked.
- (NSMenuItem*)firstCheckedItem;

// enable or disable all items in the menu including and after inFirstItem,
// optionally recursing into submenus.
- (void)setAllItemsEnabled:(BOOL)inEnable startingWithItemAtIndex:(int)inFirstItem includingSubmenus:(BOOL)includeSubmenus;

// return the first item (if any) with the given target and action.
- (NSMenuItem*)itemWithTarget:(id)anObject andAction:(SEL)actionSelector;

// remove items after the given item, or all items if nil
- (void)removeItemsAfterItem:(NSMenuItem*)inItem;

// remove all items including and after the given index (i.e. all items if index is 0)
- (void)removeItemsFromIndex:(int)inItemIndex;

- (void)removeAllItemsWithTag:(int)tag;

// add command and shift-command alternate menu items with attributes matching
// the input param. Returns the number of alternates added.
- (int)addCommandKeyAlternatesForMenuItem:(NSMenuItem *)inMenuItem;

// Update the Command and Command-Shift alternate menu items for a given menu item.
- (void)updateCommandKeyAlternatesForMenuItem:(NSMenuItem*)inMenuItem;

@end


@interface NSMenuItem(ChimeraMenuItemUtils)

- (id)initAlternateWithTitle:(NSString *)title action:(SEL)action target:(id)target modifiers:(int)modifiers;

// create and return an autoreleased alternate menu item
+ (NSMenuItem *)alternateMenuItemWithTitle:(NSString *)title action:(SEL)action target:(id)target modifiers:(int)modifiers;

- (int)tagRemovingMask:(int)tagMask;

// copy the title and enabled state from the given item
- (void)takeStateFromItem:(NSMenuItem*)inItem;

// Returns YES if the item is a descendant (including direct child) of |aMenu|.
- (BOOL)isDescendantOfMenu:(NSMenu*)aMenu;

@end
