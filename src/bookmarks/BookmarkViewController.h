/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>

#import "BrowserWrapper.h"    // for ContentViewProvider

@class ExtendedTableView;
@class ExtendedOutlineView;

@class HistoryTree;
@class HistoryOutlineViewDelegate;

@class BrowserWindowController;
@class BookmarkOutlineView;
@class BookmarkFolder;
@class BookmarkItem;

// Tags for arrange menu items
enum
{
  kArrangeBookmarksByLocationMask     = (1 << 0),
  kArrangeBookmarksByTitleMask        = (1 << 1),

  // currently unused (but implemented)
  kArrangeBookmarksByShortcutMask     = (1 << 2),
  kArrangeBookmarksByDescriptionMask  = (1 << 3),
  kArrangeBookmarksByLastVisitMask    = (1 << 4),
  kArrangeBookmarksByVisitCountMask   = (1 << 5),

  kArrangeBookmarksByTypeMask         = (1 << 6),   // folder < item < separator

  kArrangeBookmarksAscendingMask      = (0),
  kArrangeBookmarksDescendingMask     = (1 << 7),

  kArrangeBookmarksFieldMask          = kArrangeBookmarksDescendingMask - 1
};

// a simple view subclass that allows us to override viewDidMoveToWindow
@interface BookmarksEditingView : NSView
{
  id    mDelegate;
}

- (id)delegate;
- (void)setDelegate:(id)inDelegate;

@end

/* This is how focus works in the history and bookmarks view:

   1. When someone invokes the history or bookmarks view in setActiveOutlineView:, we make sure
      that the controls before know about it (setting the right nextKeyView, etc).
   2. The initial focus is set by contentView:usedForURL: and is normally set to the Search
      field unless setItemToRevealOnLoad: is used.
   3. Other than that, the whole responder chain is set up in the nib.
*/

@interface BookmarkViewController : NSObject<ContentViewProvider>
{
  IBOutlet BookmarksEditingView*  mBookmarksEditingView;

  IBOutlet NSButton*        mAddCollectionButton;

  IBOutlet NSButton*        mAddButton;
  IBOutlet NSButton*        mActionButton;
  IBOutlet NSButton*        mSortButton;

  IBOutlet NSMenu*          mActionMenuBookmarks;
  IBOutlet NSMenu*          mActionMenuHistory;

  IBOutlet NSMenu*          mSortMenuBookmarks;
  IBOutlet NSMenu*          mSortMenuHistory;

  IBOutlet NSMenu*          mQuickSearchMenuBookmarks;
  IBOutlet NSMenu*          mQuickSearchMenuHistory;

  IBOutlet NSSearchField*   mSearchField;

  IBOutlet NSSplitView*     mContainersSplit;

  IBOutlet ExtendedTableView*     mContainersTableView;

  // the bookmarks and history outliners are swapped in and out of this container
  IBOutlet NSView*        mOutlinerHostView;

  // hosting views for the outliners
  IBOutlet NSView*        mBookmarksHostView;
  IBOutlet NSView*        mHistoryHostView;

  IBOutlet BookmarkOutlineView*   mBookmarksOutlineView;
  IBOutlet ExtendedOutlineView*   mHistoryOutlineView;

  IBOutlet HistoryOutlineViewDelegate*   mHistoryOutlineViewDelegate;

  BrowserWindowController*  mBrowserWindowController; // not retained

  BOOL                    mSetupComplete;       // have we been fully initialized?
  BOOL                    mSplittersRestored;   // splitters can only be positioned after we resize to fit the window

  BOOL                    mBookmarkUpdatesDisabled;

  NSMutableDictionary*    mExpandedStates;

  BookmarkFolder*         mActiveRootCollection;
  BookmarkFolder*         mBookmarkRoot;
  NSArray*                mSearchResultArray;
  int                     mSearchTag;
  int                     mOpenActionFlag;

  BookmarkItem*           mItemToReveal;

  HistoryTree*            mHistoryTree;

  NSImage*                mSeparatorImage;
}

+ (NSAttributedString*)greyStringWithItemCount:(int)itemCount;

- (id)initWithBrowserWindowController:(BrowserWindowController*)bwController;

//
// IBActions
//
- (IBAction)toggleIsDockMenuFolder:(id)aSender;
- (IBAction)addCollection:(id)aSender;
- (IBAction)addBookmarkSeparator:(id)aSender;
- (IBAction)addBookmarkFolder:(id)aSender;
- (IBAction)openBookmark:(id)aSender;
- (IBAction)openBookmarkInNewTab:(id)aSender;
- (IBAction)openBookmarkInNewWindow:(id)aSender;
- (IBAction)openBookmarksInTabsInNewWindow:(id)aSender;
- (IBAction)deleteBookmarks:(id)aSender;
- (IBAction)showBookmarkInfo:(id)aSender;
- (IBAction)revealBookmark:(id)aSender;
- (IBAction)cut:(id)aSender;
- (IBAction)copy:(id)aSender;
- (IBAction)paste:(id)aSender;
- (IBAction)delete:(id)aSender;
- (IBAction)searchStringChanged:(id)aSender;

// uses the tag of the sender to determine the sort order
- (IBAction)arrange:(id)aSender;

- (IBAction)copyURLs:(id)aSender;

- (IBAction)quicksearchPopupChanged:(id)aSender;
- (void)resetSearchField;
- (void)focusSearchField;

- (NSView*)bookmarksEditingView;

- (int)containerCount;
- (void)selectLastContainer;
- (BOOL)haveSelectedRow;
- (int)numberOfSelectedRows;

- (void)setActiveCollection:(BookmarkFolder *)aFolder;
- (BookmarkFolder *)activeCollection;

- (BookmarkFolder *)selectedItemFolderAndIndex:(int*)outIndex;
- (void)selectAndRevealItem:(BookmarkItem*)item byExtendingSelection:(BOOL)inExtendSelection;

- (void)setItemToRevealOnLoad:(BookmarkItem*)inItem;

- (void)deleteCollection:(id)aSender;
- (void)completeSetup;
- (void)ensureBookmarks;

- (BOOL)canPasteFromPasteboard:(NSPasteboard*)aPasteboard;
- (void)copyBookmarks:(NSArray*)bookmarkItemsToCopy toPasteboard:(NSPasteboard*)aPasteboard;

- (BOOL)validateActionBySelector:(SEL)action;
@end
