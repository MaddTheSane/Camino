/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
* License, v. 2.0. If a copy of the MPL was not distributed with this
* file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>

// WebSearchField
//
// A search field that knows how to manage a web search engine list, for use as
// the toolbar web search field.
@interface WebSearchField : NSSearchField {
  NSImage* mDetectedSearchPluginImage; // strong
}

// Takes an array of dictionaries, using the keys declared in SearchEngineManger.h,
// describing the search engines to populate the menu with.
- (void)setSearchEngines:(NSArray*)searchEngines;

// Changes the current search engine setting to the one names |engineName|.
- (void)setCurrentSearchEngine:(NSString*)engineName;

// Takes an array of dictionaries, using the keys declared in XMLSearchPluginParser.h, to
// populate the menu with search plugins available to install. Plugin menu items send the
// |installSearchPlugin:| action to the search field's target, and each item's |representedObject|
// is the search plugin dictionary.
//
// The search field will automatically indicate if plugins are available in its menu.
// Calling this method with nil or an empty array will remove all existing items.
- (void)setDetectedSearchPlugins:(NSArray*)detectedSearchPlugins;

// Returns the name of the currently selected search engine.
- (NSString*)currentSearchEngine;

// Returns the search URL for the currently selected search engine.
- (NSString*)currentSearchURL;

@end

@interface WebSearchField (DelegateMethods)

- (BOOL)webSearchField:(WebSearchField*)webSearchField shouldListDetectedSearchPlugin:(NSDictionary *)searchPluginInfoDict;

@end
