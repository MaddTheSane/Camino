/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>

@class SearchEngineManager;
@class ExtendedTableView;

//
// SearchEngineEditor
//
// A GUI for customizing the collection of built-in
// web search engines.
//
@interface SearchEngineEditor : NSWindowController
{
@private
  IBOutlet ExtendedTableView *mSearchEnginesTableView;
  IBOutlet NSButton          *mActionButton;

  SearchEngineManager        *mSearchEngineManager; // weak
}

+ (SearchEngineEditor *)sharedSearchEngineEditor;

- (IBAction)showSearchEngineEditor:(id)sender;
- (IBAction)makeSelectedSearchEngineDefault:(id)sender;
- (IBAction)removeSelectedSearchEngines:(id)sender;
- (IBAction)editSelectedSearchEngine:(id)sender;
- (IBAction)restoreDefaultSearchEngines:(id)sender;

@end
