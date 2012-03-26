/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>

// The following notification is sent whenever a search engine has been
// added, renamed, moved, etc. in the |installedSearchEngines| collection.
// Also sent when the preferred search engine is modified.
extern NSString *const kInstalledSearchEnginesDidChangeNotification;

// Search engine description keys.
extern NSString *const kWebSearchEngineNameKey;
extern NSString *const kWebSearchEngineURLKey;
// Optional key so we can identify engines installed from a plugin without relying on their name:
extern NSString *const kWebSearchEngineWhereFromKey;

//
// SearchEngineManager
//
// A shared object that coordinates all interaction with our collection
// of built-in web search engines. 
//
@interface SearchEngineManager : NSObject
{
@private
  NSMutableArray *mInstalledSearchEngines;      // strong
  NSString       *mPreferredSearchEngine;       // strong
  NSString       *mPathToSavedSearchEngineInfo; // strong
}

+ (SearchEngineManager *)sharedSearchEngineManager;

// Returns an array of dictionaries, using the keys above, to describe the
// installed search engines. There will always be at least one engine installed.
- (NSArray *)installedSearchEngines;

// Convienence method; returns an array of strings, consisting of only the names of the
// installed search engines. Ordered identically to |installedSearchEngines|.
- (NSArray *)installedSearchEngineNames;

- (NSString *)preferredSearchEngine;
- (void)setPreferredSearchEngine:(NSString *)newPreferredSearchEngine;

// Adds the plugin to the end of |installedSearchEngines|.
// Return value indicates whether the plugin was successfully parsed and a new engine added.
// If NO is returned, |outError| is populated with an NSError object containing a localized
// description of the problem. Pass NULL if you do not want error information.
- (BOOL)addSearchEngineFromPlugin:(NSDictionary *)searchPluginInfoDict error:(NSError**)error;

- (BOOL)hasSearchEngineFromPluginURL:(NSString *)pluginURL;
- (NSDictionary *)searchEngineFromPluginURL:(NSString *)pluginURL;

- (void)addSearchEngineWithName:(NSString *)engineName searchURL:(NSString *)engineURL pluginURL:(NSString *)pluginURL;

- (void)renameSearchEngineAtIndex:(unsigned)index to:(NSString *)newEngineName;
- (void)moveSearchEnginesAtIndexes:(NSIndexSet *)indexes toIndex:(unsigned)destinationIndex;

- (void)removeSearchEngineAtIndex:(unsigned)index;
- (void)removeSearchEnginesAtIndexes:(NSIndexSet *)indexes;

// Removes all existing engine info and reverts back to the initial default engine list 
// and preferred engine selection from the application bundle.
- (void)revertToDefaultSearchEngines;

@end
