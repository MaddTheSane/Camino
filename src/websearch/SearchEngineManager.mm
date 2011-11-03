/* ***** BEGIN LICENSE BLOCK *****
 * Version: MPL 1.1/GPL 2.0/LGPL 2.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Original Code is Camino code.
 *
 * The Initial Developer of the Original Code is
 * Sean Murphy.
 * Portions created by the Initial Developer are Copyright (C) 2007
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *   Sean Murphy <murph@seanmurph.com>
 *
 * Alternatively, the contents of this file may be used under the terms of
 * either the GNU General Public License Version 2 or later (the "GPL"), or
 * the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
 * in which case the provisions of the GPL or the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of either the GPL or the LGPL, and not to allow others to
 * use your version of this file under the terms of the MPL, indicate your
 * decision by deleting the provisions above and replace them with the notice
 * and other provisions required by the GPL or the LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the MPL, the GPL or the LGPL.
 *
 * ***** END LICENSE BLOCK ***** */

#import "SearchEngineManager.h"
#import "PreferenceManager.h"
#import "XMLSearchPluginParser.h"
#import "NSFileManager+Utils.h"

NSString *const kInstalledSearchEnginesDidChangeNotification = @"InstalledSearchEnginesChangedNotification";

NSString *const kWebSearchEngineNameKey = @"SearchEngineName";
NSString *const kWebSearchEngineURLKey = @"SearchEngineURL";
NSString *const kWebSearchEngineWhereFromKey = @"PluginURL";

static NSString *const kListOfSearchEnginesKey = @"SearchEngineList";
static NSString *const kPreferredSearchEngineNameKey = @"PreferredSearchEngine";
static NSString *const kBuiltInEngineSetVersionKey = @"BuiltInEngineSetVersion";
static const int kCurrentBuiltInEngineSetVersion = 2;

@interface SearchEngineManager (Private)

- (NSString *)pathToSavedSearchEngineInformation;
- (void)loadSavedSearchEngineInformation;
- (void)upgradeSearchEnginesFromVersion:(int)oldVersion;
- (void)saveSearchEngineInformation;
- (void)setInstalledSearchEngines:(NSMutableArray *)newSearchEngines;
- (void)installedSearchEnginesChanged;
- (BOOL)filterDuplicatesFromEngines:(NSMutableArray *)searchEngines;
- (void)setPreferredSearchEngine:(NSString *)newPreferredSearchEngine sendingChangeNotification:(BOOL)shouldNotify;
- (void)loadDefaultSearchEngineInformationFromBundle;
- (NSString *)uniqueNameForEngine:(NSString *)engineName;

@end

#pragma mark -

@implementation SearchEngineManager

+ (SearchEngineManager *)sharedSearchEngineManager
{
  static SearchEngineManager *sharedSearchEngineManager = nil;
  if (!sharedSearchEngineManager) {
    sharedSearchEngineManager = [[SearchEngineManager alloc] init];
  }
  return sharedSearchEngineManager;
}

- (id)init
{
  if ((self = [super init]))
    [self loadSavedSearchEngineInformation];

  return self;
}

- (void)dealloc
{
  [mInstalledSearchEngines release];
  [mPreferredSearchEngine release];
  [mPathToSavedSearchEngineInfo release];

  [super dealloc];
}

#pragma mark -

- (NSString *)pathToSavedSearchEngineInformation
{
  if (!mPathToSavedSearchEngineInfo) {
    NSString *profileDirectory = [[PreferenceManager sharedInstance] profilePath];
    mPathToSavedSearchEngineInfo = [[profileDirectory stringByAppendingPathComponent:@"WebSearchEngines.plist"] retain];
  }
  return mPathToSavedSearchEngineInfo;
}

- (void)loadSavedSearchEngineInformation
{
  NSString *pathToSavedEngineInfo = [self pathToSavedSearchEngineInformation];
  if (!pathToSavedEngineInfo)
    return;
  NSDictionary *savedSearchEngineInfoDict = [NSDictionary dictionaryWithContentsOfFile:pathToSavedEngineInfo];

  if (!savedSearchEngineInfoDict || 
      [[savedSearchEngineInfoDict objectForKey:kListOfSearchEnginesKey] count] == 0)
  {
    // We couldn't load the engines, but if a file actually did exist at |pathToSavedEngineInfo|,
    // move it aside before clobbering it with the defaults.
    if ([[NSFileManager defaultManager] fileExistsAtPath:pathToSavedEngineInfo]) {
      NSString *corruptedPath = [[NSFileManager defaultManager] backupFileNameFromPath:pathToSavedEngineInfo
                                                                            withSuffix:@"-corrupted"];
      [[NSFileManager defaultManager] copyPath:pathToSavedEngineInfo toPath:corruptedPath handler:nil];
      NSLog(@"Moved corrupted search engines file to '%@'", corruptedPath);
    }

#if DEBUG
    NSLog(@"No search engines found in the profile directory; loading the defaults");
#endif
    [self loadDefaultSearchEngineInformationFromBundle];
    [self saveSearchEngineInformation];
    return;
  }

  NSMutableArray *savedSearchEngines = [NSMutableArray arrayWithArray:[savedSearchEngineInfoDict objectForKey:kListOfSearchEnginesKey]];

  BOOL duplicatesWereRemoved = [self filterDuplicatesFromEngines:savedSearchEngines];

  [self setInstalledSearchEngines:savedSearchEngines];

  // Check for built-in engine updates.
  int version = [[savedSearchEngineInfoDict objectForKey:kBuiltInEngineSetVersionKey] intValue];
  BOOL needsUpdate = version < kCurrentBuiltInEngineSetVersion;
  if (needsUpdate)
    [self upgradeSearchEnginesFromVersion:version];

  // Validate and set the saved preferred engine name.
  NSString *savedPreferredEngine = [savedSearchEngineInfoDict objectForKey:kPreferredSearchEngineNameKey];
  if ([[self installedSearchEngineNames] containsObject:savedPreferredEngine])
    [self setPreferredSearchEngine:savedPreferredEngine sendingChangeNotification:NO];
  else
    [self setPreferredSearchEngine:[[self installedSearchEngineNames] objectAtIndex:0] sendingChangeNotification:NO];

  // Update the saved engines if any modifications were made during loading.
  if (duplicatesWereRemoved || needsUpdate ||
      ![[self preferredSearchEngine] isEqualToString:savedPreferredEngine])
  {
    [self saveSearchEngineInformation];
  }
}

// Updates the saved search engines to reflect changes in the built-in engines.
- (void)upgradeSearchEnginesFromVersion:(int)oldVersion {
  if (oldVersion < 2) {
    // Version 2 switched Google searches to HTTPS. Map the old URLs to the new
    // ones (if they are still there).
    NSDictionary *urlMap = [NSDictionary dictionaryWithObjectsAndKeys:
        // Web search, new and old.
        @"https://www.google.com/search?q=%s&ie=utf-8&oe=utf-8",
        @"http://www.google.com/search?q=%s&ie=utf-8&oe=utf-8",
        // Added Mozilla sourceid.
        @"https://www.google.com/search?q=%s&ie=utf-8&oe=utf-8",
        @"http://www.google.com/search?q=%s&sourceid=mozilla2&ie=utf-8&oe=utf-8",
        // Added UTF-8 (bug 201642).
        @"https://www.google.com/search?q=%s&ie=utf-8&oe=utf-8",
        @"http://www.google.com/search?ie=UTF-8&oe=UTF-8&q=%s",
        // Dawn of web search (bug 158246).
        @"https://www.google.com/search?q=%s&ie=utf-8&oe=utf-8",
        @"http://www.google.com/search?q=%s",
        // Image search, new and old.
        @"https://www.google.com/search?tbm=isch&ie=UTF-8&oe=UTF-8&q=%s",
        @"http://images.google.com/images?ie=UTF-8&oe=UTF-8&q=%s",
        // // Dawn of image search (bug 158246).
        @"https://www.google.com/search?tbm=isch&ie=UTF-8&oe=UTF-8&q=%s",
        @"http://images.google.com/images?q=%s",
        // Site search, new and old.
        @"https://www.google.com/search?ie=UTF-8&oe=UTF-8&q=%s site:%d",
        @"http://www.google.com/search?ie=UTF-8&oe=UTF-8&q=%s site:%d",
        // Dawn of site search (bug 158246).
        @"https://www.google.com/search?ie=UTF-8&oe=UTF-8&q=%s site:%d",
        @"http://www.google.com/search?q=%s site:%d",
        nil];
    // Loop, rather than enumerate, to allow modification.
    for (unsigned int i = 0; i < [mInstalledSearchEngines count]; ++i) {
      NSDictionary *engine = [mInstalledSearchEngines objectAtIndex:i];
      NSString *engineURL = [engine objectForKey:kWebSearchEngineURLKey];
      NSString *replacementURL = [urlMap objectForKey:engineURL];
      if (replacementURL) {
        NSMutableDictionary *newEngine = [[engine mutableCopy] autorelease];
        [newEngine setObject:replacementURL forKey:kWebSearchEngineURLKey];
        [mInstalledSearchEngines replaceObjectAtIndex:i withObject:newEngine];
      }
    }
  }
}

- (void)saveSearchEngineInformation
{
  NSDictionary *searchEngineInfoDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                  [self preferredSearchEngine], kPreferredSearchEngineNameKey,
                                 [self installedSearchEngines], kListOfSearchEnginesKey,
      [NSNumber numberWithInt:kCurrentBuiltInEngineSetVersion], kBuiltInEngineSetVersionKey,
                                                                nil];

  [searchEngineInfoDict writeToFile:[self pathToSavedSearchEngineInformation] atomically:YES];
}

- (void)setInstalledSearchEngines:(NSMutableArray *)newSearchEngines
{
  if (mInstalledSearchEngines != newSearchEngines) {
    [mInstalledSearchEngines release];
    mInstalledSearchEngines = [newSearchEngines retain];
  }
}

- (void)installedSearchEnginesChanged
{
  [self saveSearchEngineInformation];
  [[NSNotificationCenter defaultCenter] postNotificationName:kInstalledSearchEnginesDidChangeNotification object:self];
}

// Return value indicates if any engines were removed from |searchEngines|.
- (BOOL)filterDuplicatesFromEngines:(NSMutableArray *)searchEngines;
{
  NSMutableSet *engineNamesAlreadySeen = [NSMutableSet setWithCapacity:[searchEngines count]];
  // Enumerate a copy, since we can't remove directly from an enumerated collection
  NSMutableArray *enumeratingSearchEngines = [NSMutableArray arrayWithArray:searchEngines];
  NSEnumerator *engineEnumerator = [enumeratingSearchEngines objectEnumerator];
  NSDictionary *currentEngine = nil;
  while ((currentEngine = [engineEnumerator nextObject])) {
    NSString *currentEngineName = [currentEngine objectForKey:kWebSearchEngineNameKey];
    if ([engineNamesAlreadySeen containsObject:currentEngineName])
      [searchEngines removeObjectIdenticalTo:currentEngine];
    else
      [engineNamesAlreadySeen addObject:currentEngineName];
  }
  // Determine if we removed an engine
  return ([enumeratingSearchEngines count] != [searchEngines count]);
}

- (void)loadDefaultSearchEngineInformationFromBundle
{
  NSString *pathToDefaultEnginesInBundle = [[NSBundle mainBundle] pathForResource:@"WebSearchEngines" ofType:@"plist"];
  NSDictionary *defaultEngineInfo = [NSDictionary dictionaryWithContentsOfFile:pathToDefaultEnginesInBundle];

  [self setInstalledSearchEngines:[defaultEngineInfo objectForKey:kListOfSearchEnginesKey]];
  [self setPreferredSearchEngine:[defaultEngineInfo objectForKey:kPreferredSearchEngineNameKey]];
}

- (NSString *)uniqueNameForEngine:(NSString *)engineName
{
  NSString *uniqueEngineName = engineName;
  NSArray *installedEngineNames = [self installedSearchEngineNames];
  int nameUseCount = 2;
  while ([installedEngineNames containsObject:uniqueEngineName]) {
    uniqueEngineName = [engineName stringByAppendingFormat:@" (%i)", nameUseCount];
    ++nameUseCount;
  }
  return uniqueEngineName;
}

#pragma mark -

- (NSArray *)installedSearchEngines
{
  return [[mInstalledSearchEngines retain] autorelease];
}

- (NSArray *)installedSearchEngineNames
{
  return [mInstalledSearchEngines valueForKey:kWebSearchEngineNameKey];
}

- (NSString *)preferredSearchEngine
{
  return [[mPreferredSearchEngine retain] autorelease];
}

- (void)setPreferredSearchEngine:(NSString *)newPreferredSearchEngine
{
  [self setPreferredSearchEngine:newPreferredSearchEngine sendingChangeNotification:YES];
}

- (void)setPreferredSearchEngine:(NSString *)newPreferredSearchEngine sendingChangeNotification:(BOOL)shouldNotify
{
  if (mPreferredSearchEngine == newPreferredSearchEngine)
    return;

  [mPreferredSearchEngine release];
  mPreferredSearchEngine = [newPreferredSearchEngine retain];

  if (shouldNotify)
    [self installedSearchEnginesChanged];
}

- (BOOL)addSearchEngineFromPlugin:(NSDictionary *)searchPluginInfoDict error:(NSError **)outError
{
  if (outError)
    *outError = nil;

  XMLSearchPluginParser *pluginParser = [XMLSearchPluginParser searchPluginParserWithMIMEType:[searchPluginInfoDict objectForKey:kWebSearchPluginMIMETypeKey]];
  if (!pluginParser) {
    if (outError) {
      NSDictionary *errorInfo = [NSDictionary dictionaryWithObject:NSLocalizedString(@"XMLSearchPluginParserInvalidPluginFormat", nil)
                                                            forKey:NSLocalizedDescriptionKey];
      *outError = [NSError errorWithDomain:kXMLSearchPluginParserErrorDomain 
                                      code:eXMLSearchPluginParserInvalidPluginFormatError 
                                  userInfo:errorInfo];
    }
    return NO;
  }

  NSURL *pluginURL = [searchPluginInfoDict objectForKey:kWebSearchPluginURLKey];
  BOOL parsedOk = [pluginParser parseSearchPluginAtURL:pluginURL error:outError];

  if (parsedOk) {
    [self addSearchEngineWithName:[pluginParser searchEngineName]
                        searchURL:[pluginParser searchEngineURL]
                        pluginURL:[pluginURL absoluteString]];
    return YES;
  }
  else {
    return NO;
  }
}

- (NSDictionary *)searchEngineFromPluginURL:(NSString *)pluginURL
{
  NSEnumerator *installedEnginesEnumerator = [mInstalledSearchEngines objectEnumerator];
  NSDictionary *searchEngine = nil;
  while ((searchEngine = [installedEnginesEnumerator nextObject])) {
    if ([[searchEngine objectForKey:kWebSearchEngineWhereFromKey] isEqualToString:pluginURL])
      return searchEngine;
  }
  return nil;  
}

- (BOOL)hasSearchEngineFromPluginURL:(NSString *)pluginURL
{
  return ([self searchEngineFromPluginURL:pluginURL] != nil);
}

- (void)addSearchEngineWithName:(NSString *)engineName searchURL:(NSString *)engineURL pluginURL:(NSString *)pluginURL
{
  // Ensure the engine name is unique.
  engineName = [self uniqueNameForEngine:engineName];

  NSDictionary *searchEngine = [NSDictionary dictionaryWithObjectsAndKeys:engineName, kWebSearchEngineNameKey,
                                                                          engineURL, kWebSearchEngineURLKey,
                                                                          pluginURL, kWebSearchEngineWhereFromKey,
                                                                          nil];
  [mInstalledSearchEngines addObject:searchEngine];
  [self installedSearchEnginesChanged];
}

- (void)renameSearchEngineAtIndex:(unsigned)index to:(NSString *)newEngineName
{
  if (index >= [mInstalledSearchEngines count] || !newEngineName) {
    NSLog(@"Cannot rename search engine at index: %u (engine doesn't exist)",
          index);
    return;
  }

  NSMutableDictionary *searchEngine = [NSMutableDictionary dictionaryWithDictionary:[mInstalledSearchEngines objectAtIndex:index]];

  // If this is the default engine, update that value (but don't notify observers
  // since we haven't actually renamed the engine yet)
  if ([[self preferredSearchEngine] isEqualToString:[searchEngine valueForKey:kWebSearchEngineNameKey]])
    [self setPreferredSearchEngine:newEngineName sendingChangeNotification:NO];

  [searchEngine setObject:newEngineName forKey:kWebSearchEngineNameKey];
  [mInstalledSearchEngines replaceObjectAtIndex:index withObject:searchEngine];

  [self installedSearchEnginesChanged];
}

- (void)moveSearchEnginesAtIndexes:(NSIndexSet *)indexes toIndex:(unsigned)destinationIndex
{
  if (destinationIndex > [mInstalledSearchEngines count]) {
    NSLog(@"Cannot move the specified search engines to index: %u (out of bounds)", destinationIndex);
    return;
  }

  // Gather the engines to be moved, and mark each original as NSNull so we can remove it later.
  // (removing them before the move could throw off the destination index).
  NSMutableArray *movingSearchEngines = [NSMutableArray arrayWithCapacity:[indexes count]];
  unsigned currentIndex = [indexes firstIndex];
  while (currentIndex != NSNotFound) {
    if (currentIndex < [mInstalledSearchEngines count]) {
      [movingSearchEngines addObject:[mInstalledSearchEngines objectAtIndex:currentIndex]];
      [mInstalledSearchEngines replaceObjectAtIndex:currentIndex withObject:[NSNull null]];
    }
    else {
      NSLog(@"Cannot move search engine at index: %u (engine doesn't exist)",
            currentIndex);
    }
    currentIndex = [indexes indexGreaterThanIndex:currentIndex];
  }

  [mInstalledSearchEngines replaceObjectsInRange:NSMakeRange(destinationIndex, 0)
                            withObjectsFromArray:movingSearchEngines];
  [mInstalledSearchEngines removeObjectIdenticalTo:[NSNull null]];

  [self installedSearchEnginesChanged];
}

- (void)removeSearchEngineAtIndex:(unsigned)index
{
  [self removeSearchEnginesAtIndexes:[NSIndexSet indexSetWithIndex:index]];
}

- (void)removeSearchEnginesAtIndexes:(NSIndexSet *)indexes
{
  // Make sure we'll have at least one engine left.
  if ([indexes count] >= [mInstalledSearchEngines count]) {
    NSLog(@"Cannot remove all search engines");
    return;
  }

  // Reverse enumerate the indexes to avoid shifting the index of items
  // which will eventually be removed.
  unsigned currentIndex = [indexes lastIndex];
  while (currentIndex != NSNotFound) {
    if (currentIndex < [mInstalledSearchEngines count])
      [mInstalledSearchEngines removeObjectAtIndex:currentIndex];
    else
      NSLog(@"Cannot remove search engine at index: %u (engine doesn't exist)", currentIndex);
    currentIndex = [indexes indexLessThanIndex:currentIndex];
  }

  // Handle case where default engine was removed.
  if (![[self installedSearchEngineNames] containsObject:[self preferredSearchEngine]])
    [self setPreferredSearchEngine:[[self installedSearchEngineNames] objectAtIndex:0] sendingChangeNotification:NO];

  [self installedSearchEnginesChanged];
}

- (void)revertToDefaultSearchEngines
{
  [self loadDefaultSearchEngineInformationFromBundle];
  [self installedSearchEnginesChanged];
}

@end
