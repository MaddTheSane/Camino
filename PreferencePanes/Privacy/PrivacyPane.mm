/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
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
 * The Original Code is mozilla.org code.
 *
 * The Initial Developer of the Original Code is
 * Netscape Communications Corporation.
 * Portions created by the Initial Developer are Copyright (C) 2002
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *   Stuart Morgan <stuart.morgan@alumni.case.edu>
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
 
#import "PrivacyPane.h"

#import "NSArray+Utils.h"
#import "CHCookieStorage.h"
#import "CHPermissionManager.h"
#import "ExtendedTableView.h"
#import "KeychainDenyList.h"

// prefs for keychain password autofill
static const char* const gUseKeychainPref = "chimera.store_passwords_with_keychain";

// network.cookie.lifetimePolicy settings
const int kAcceptCookiesNormally = 0;
const int kWarnAboutCookies = 1;

// sort order indicators
const int kSortReverse = 1;

@interface OrgMozillaCaminoPreferencePrivacy(Private)

+ (NSString*)superdomainForHost:(NSString*)host;

// helper method for blocking/allowing multiple sites at once
- (void)addPermissionForSelection:(int)inPermission;

- (int)numCookiesSelectedInCookiePanel;
- (int)numPermissionsSelectedInPermissionsPanel;
// get the number of unique cookie sites that are selected,
// and if it's just one, return the site name (with leading period removed, if necessary)
- (int)numUniqueCookieSitesSelected:(NSString**)outSiteName;
- (NSString*)permissionsBlockingNameForCookieHostname:(NSString*)inHostname;
- (NSArray*)selectedCookieSites;
- (int)indexForPolicy:(int)policy;
- (int)policyForIndex:(int)index;
- (void)updateSortIndicatorWithColumn:(NSTableColumn *)aTableColumn;
- (void)sortCookiesByColumn:(NSTableColumn *)aTableColumn
           inAscendingOrder:(BOOL)ascending;
- (void)sortPermissionsByKey:(NSString *)sortKey
            inAscendingOrder:(BOOL)ascending;
- (void)sortKeychainExclusionsByColumn:(NSTableColumn*)tableColumn
                      inAscendingOrder:(BOOL)asecending;

@end

#pragma mark -

@interface NSString(HostSortComparator)
- (NSComparisonResult)reverseHostnameCompare:(NSString *)otherString;
@end

@implementation NSString(HostSortComparator)
- (NSComparisonResult)reverseHostnameCompare:(NSString *)otherString {
  NSArray* selfComponents = [self componentsSeparatedByString:@"."];
  NSArray* otherStringComponents = [otherString componentsSeparatedByString:@"."];
  int selfIndex = [selfComponents count] - 1;
  int otherIndex = [otherStringComponents count] - 1;
  for (; selfIndex >= 0 && otherIndex >= 0; --selfIndex, --otherIndex) {
    NSComparisonResult result =
      [[selfComponents objectAtIndex:selfIndex] caseInsensitiveCompare:[otherStringComponents objectAtIndex:otherIndex]];
    if (result != NSOrderedSame)
      return result;
  }
  if (selfIndex < otherIndex)
    return NSOrderedAscending;
  else if (selfIndex > otherIndex)
    return NSOrderedDescending;
  else
    return NSOrderedSame;
}
@end

#pragma mark -

@implementation OrgMozillaCaminoPreferencePrivacy

-(void) dealloc
{
  // These should have been released when the sheets closed, but make sure.
  [mCachedPermissions release];
  [mCookies release];
  [mKeychainExclusions release];

  [super dealloc];
}

-(void) mainViewDidLoad
{
  // Hook up cookie prefs.
  BOOL gotPref = NO;
  int acceptCookies = [self getIntPref:"network.cookie.cookieBehavior"
                           withSuccess:&gotPref];
  if (!gotPref)
    acceptCookies = eAcceptAllCookies;
  [self mapCookiePrefToGUI:acceptCookies];

  // lifetimePolicy now controls asking about cookies, despite being totally unintuitive
  int lifetimePolicy = [self getIntPref:"network.cookie.lifetimePolicy"
                            withSuccess:&gotPref];
  if (!gotPref)
    lifetimePolicy = kAcceptCookiesNormally;
  if (lifetimePolicy == kWarnAboutCookies)
    [mAskAboutCookies setState:NSOnState];
  else if (lifetimePolicy == kAcceptCookiesNormally)
    [mAskAboutCookies setState:NSOffState];
  else
    [mAskAboutCookies setState:NSMixedState];

  // Keychain checkbox
  BOOL storePasswords = [self getBooleanPref:gUseKeychainPref withSuccess:NULL];
  [mStorePasswords setState:(storePasswords ? NSOnState : NSOffState)];

  // set up policy popups
  NSPopUpButtonCell *popupButtonCell = [mPermissionColumn dataCell];
  [popupButtonCell setEditable:YES];
  [popupButtonCell addItemsWithTitles:[NSArray arrayWithObjects:[self localizedStringForKey:@"Allow"],
                                                                [self localizedStringForKey:@"Allow for Session"],
                                                                [self localizedStringForKey:@"Deny"],
                                                                nil]];
}

-(void) mapCookiePrefToGUI:(int)pref
{
  [mCookieBehavior selectCellWithTag:pref];
  [mAskAboutCookies setEnabled:(pref == eAcceptAllCookies || pref == eAcceptCookiesFromOriginatingServer)];
}

//
// Stored cookie editing methods
//

-(void) populateCookieCache
{
  if (mCookies)
    [mCookies release];
  mCookies = [[[CHCookieStorage cookieStorage] cookies] mutableCopy];
  if (!mCookies)
    mCookies = [[NSMutableArray alloc] init];
}

-(IBAction) editCookies:(id)aSender
{
  // build cookie list
  [self populateCookieCache];

  [mCookiesTable setDeleteAction:@selector(removeCookies:)];
  [mCookiesTable setTarget:self];
  
  CookieDateFormatter* cookieDateFormatter = [[CookieDateFormatter alloc] initWithDateFormat:@"%b %d, %Y" allowNaturalLanguage:NO];
  // Once we are 10.4+, the above and all the CF stuff in CookieDateFormatter
  // can be replaced with the following:
  //CookieDateFormatter* cookieDateFormatter = [[CookieDateFormatter alloc] init];
  //[cookieDateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
  //[cookieDateFormatter setDateStyle:NSDateFormatterMediumStyle];
  //[cookieDateFormatter setTimeStyle:NSDateFormatterNoStyle];
  [[[mCookiesTable tableColumnWithIdentifier:@"expiresDate"] dataCell] setFormatter:cookieDateFormatter];
  [cookieDateFormatter release];

  // start sorted by host
  mSortedAscending = YES;
  [self sortCookiesByColumn:[mCookiesTable tableColumnWithIdentifier:@"domain"]
           inAscendingOrder:YES];

  // ensure a row is selected (cocoa doesn't do this for us, but will keep
  // us from unselecting a row once one is set; go figure).
  [mCookiesTable selectRow:0 byExtendingSelection:NO];

  [mCookiesTable setUsesAlternatingRowBackgroundColors:YES];
  NSArray* columns = [mCookiesTable tableColumns];
  if (columns) {
    int numColumns = [columns count];
    for (int i = 0; i < numColumns; ++i)
      [[[columns objectAtIndex:i] dataCell] setDrawsBackground:NO];
  }

  //clear the filter field
  [mCookiesFilterField setStringValue:@""];

  [mCookiesPanel setFrameAutosaveName:@"cookies_sheet"];
  
  // bring up sheet
  [NSApp beginSheet:mCookiesPanel
     modalForWindow:[mAskAboutCookies window]   // any old window accessor
      modalDelegate:self
     didEndSelector:NULL
        contextInfo:NULL];
  NSSize min = {440, 240};
  [mCookiesPanel setMinSize:min];
}

-(IBAction) removeCookies:(id)aSender
{
  CHCookieStorage* cookieStorage = [CHCookieStorage cookieStorage];

  // Walk the selected rows backwards, removing cookies.
  NSIndexSet* selectedIndexes = [mCookiesTable selectedRowIndexes];
  for (unsigned int i = [selectedIndexes lastIndex];
       i != NSNotFound;
       i = [selectedIndexes indexLessThanIndex:i])
  {
    [cookieStorage deleteCookie:[mCookies objectAtIndex:i]];
    [mCookies removeObjectAtIndex:i];
  }

  [mCookiesTable reloadData];

  // Select the row after the last deleted row.
  if ([mCookiesTable numberOfRows] > 0) {
    int rowToSelect = [selectedIndexes lastIndex] - ([selectedIndexes count] - 1);
    if ((rowToSelect < 0) || (rowToSelect >= [mCookiesTable numberOfRows]))
      rowToSelect = [mCookiesTable numberOfRows] - 1;
    [mCookiesTable selectRow:rowToSelect byExtendingSelection:NO];
  }
}

-(IBAction) removeAllCookies: (id)aSender
{
  if (NSRunCriticalAlertPanel([self localizedStringForKey:@"RemoveAllCookiesWarningTitle"],
                              [self localizedStringForKey:@"RemoveAllCookiesWarning"],
                              [self localizedStringForKey:@"Remove All Cookies"],
                              [self localizedStringForKey:@"CancelButtonText"],
                              nil) == NSAlertDefaultReturn)
  {
    [[CHCookieStorage cookieStorage] deleteAllCookies];

    [mCookies release];
    mCookies = [[NSMutableArray alloc] init];

    [mCookiesTable reloadData];
  }
}

-(IBAction) allowCookiesFromSites:(id)aSender
{
  [self addPermissionForSelection:CHPermissionAllow];
}

-(IBAction) blockCookiesFromSites:(id)aSender
{
  [self addPermissionForSelection:CHPermissionDeny];
}

-(IBAction) removeCookiesAndBlockSites:(id)aSender
{
  // Block the sites.
  CHPermissionManager* permManager = [CHPermissionManager permissionManager];
  NSArray* selectedSites = [self selectedCookieSites];
  NSEnumerator* sitesEnum = [selectedSites objectEnumerator];
  NSString* curSite;
  while ((curSite = [sitesEnum nextObject])) {
    [permManager setPolicy:CHPermissionDeny
                    forHost:curSite
                      type:CHPermissionTypeCookie];
  }

  // Then remove the cookies.
  [self removeCookies:aSender];
}

-(IBAction) editCookiesDone:(id)aSender
{
  // save stuff
  [mCookiesPanel orderOut:self];
  [NSApp endSheet:mCookiesPanel];

  [mCookies release];
  mCookies = nil;
}

//
// Site permission editing methods

-(void) populatePermissionCache
{
  if (mCachedPermissions)
    [mCachedPermissions release];
  mCachedPermissions = [[[CHPermissionManager permissionManager]
                           permissionsOfType:CHPermissionTypeCookie] mutableCopy];
  if (!mCachedPermissions)
    mCachedPermissions = [[NSMutableArray alloc] init];
}

-(IBAction) editPermissions:(id)aSender
{
  // build parallel permission list for speed with a lot of blocked sites
  [self populatePermissionCache];

  [mPermissionsTable setDeleteAction:@selector(removeCookiePermissions:)];
  [mPermissionsTable setTarget:self];

  [mPermissionsTable setUsesAlternatingRowBackgroundColors:YES];

  //clear the filter field
  [mPermissionFilterField setStringValue: @""];

  // start sorted by host
  mSortedAscending = YES;
  [self sortPermissionsByKey:@"host" inAscendingOrder:YES];

  // ensure a row is selected (cocoa doesn't do this for us, but will keep
  // us from unselecting a row once one is set; go figure).
  if ([mPermissionsTable numberOfRows] > 0)
    [mPermissionsTable selectRow:0 byExtendingSelection:NO];

  [mPermissionsPanel setFrameAutosaveName:@"permissions_sheet"];
  
  // bring up sheet
  [NSApp beginSheet:mPermissionsPanel
     modalForWindow:[mAskAboutCookies window]   // any old window accessor
      modalDelegate:self
     didEndSelector:NULL
        contextInfo:NULL];
  NSSize min = {440, 240};
  [mPermissionsPanel setMinSize:min];
}

// Note that this operates only a single row (enforced by menu validation),
// unlike many of the other context menu actions.
- (IBAction)expandCookiePermission:(id)aSender
{
  CHPermission* selectedPermission = [mCachedPermissions objectAtIndex:[mPermissionsTable selectedRow]];
  NSString* host = [selectedPermission host];
  NSString* superdomain = [[self class] superdomainForHost:host];
  int policy = [selectedPermission policy];

  CHPermissionManager* permManager = [CHPermissionManager permissionManager];
  // Walk the permissions, cleaning up any that are superceded by the general
  // policy (but leaving any that have a different policy).
  NSString* domainSuffix = [NSString stringWithFormat:@".%@", superdomain];
  NSEnumerator* permEnumerator = [mCachedPermissions objectEnumerator];
  CHPermission* perm;
  while ((perm = [permEnumerator nextObject])) {
    if ([perm policy] == policy && [[perm host] hasSuffix:domainSuffix])
      [permManager removePermissionForHost:[perm host]
                                      type:CHPermissionTypeCookie];
  }
  // Add the new general policy.
  [permManager setPolicy:policy forHost:superdomain type:CHPermissionTypeCookie];

  // Re-applying the filter will take care of refreshing the cache
  [self filterCookiesPermissionsWithString:[mPermissionFilterField stringValue]];
  [self sortPermissionsByKey:[[mPermissionsTable highlightedTableColumn] identifier]
            inAscendingOrder:mSortedAscending];
  [mPermissionsTable reloadData];

  // Select the new permission.
  if ([mPermissionsTable numberOfRows] > 0) {
    int rowToSelect = [self rowForPermissionWithHost:superdomain];
    if ((rowToSelect >= 0) && (rowToSelect < [mPermissionsTable numberOfRows])) {
      [mPermissionsTable selectRow:rowToSelect byExtendingSelection:NO];
      [mPermissionsTable scrollRowToVisible:rowToSelect];
    }
  }
}

// Returns the host that is one level more broad than the given host (e.g.,
// foo.bar.com -> bar.com), or nil if the given host has only one component.
+ (NSString*)superdomainForHost:(NSString*)host
{
  NSRange dotRange = [host rangeOfString:@"."];
  if (dotRange.location == NSNotFound || dotRange.location == ([host length] - 1))
    return nil;
  if (dotRange.location == 0) // .bar.com == bar.com
    return [[self class] superdomainForHost:[host substringFromIndex:1]];
  else
    return [host substringFromIndex:(dotRange.location + 1)];
}

-(IBAction) removeCookiePermissions:(id)aSender
{
  CHPermissionManager* permManager = [CHPermissionManager permissionManager];
    
  // Walk the selected rows backwards, removing permissions.
  NSIndexSet* selectedIndexes = [mPermissionsTable selectedRowIndexes];
  for (unsigned int i = [selectedIndexes lastIndex];
       i != NSNotFound;
       i = [selectedIndexes indexLessThanIndex:i])
  {
    [permManager removePermissionForHost:[[mCachedPermissions objectAtIndex:i] host]
                                    type:CHPermissionTypeCookie];
    [mCachedPermissions removeObjectAtIndex:i];
  }

  [mPermissionsTable reloadData];

  // Select the row after the last deleted row.
  if ([mPermissionsTable numberOfRows] > 0) {
    int rowToSelect = [selectedIndexes lastIndex] - ([selectedIndexes count] - 1);
    if ((rowToSelect < 0) || (rowToSelect >= [mPermissionsTable numberOfRows]))
      rowToSelect = [mPermissionsTable numberOfRows] - 1;
    [mPermissionsTable selectRow:rowToSelect byExtendingSelection:NO];
  }
}

-(IBAction) removeAllCookiePermissions: (id)aSender
{
  CHPermissionManager* permManager = [CHPermissionManager permissionManager];
  if (!permManager)
    return;
  if (NSRunCriticalAlertPanel([self localizedStringForKey:@"RemoveAllCookiePermissionsWarningTitle"],
                              [self localizedStringForKey:@"RemoveAllCookiePermissionsWarning"],
                              [self localizedStringForKey:@"Remove All Exceptions"],
                              [self localizedStringForKey:@"CancelButtonText"],
                              nil) == NSAlertDefaultReturn)
  {
    NSEnumerator* permissionEnumerator = [mCachedPermissions objectEnumerator];
    CHPermission* permission;
    while ((permission = [permissionEnumerator nextObject])) {
      [permManager removePermissionForHost:[permission host] type:[permission type]];
      }

    [mCachedPermissions release];
    mCachedPermissions = [[NSMutableArray alloc] init];

    [mPermissionsTable reloadData];
  }
}

-(IBAction) editPermissionsDone:(id)aSender
{
  // save stuff
  [mPermissionsPanel orderOut:self];
  [NSApp endSheet:mPermissionsPanel];
  
  [mCachedPermissions release];
  mCachedPermissions = nil;
}

-(int) rowForPermissionWithHost:(NSString *)aHost
{
  int numRows = [mCachedPermissions count];
  for (int row = 0; row < numRows; ++row) {
    if ([[[mCachedPermissions objectAtIndex:row] host] isEqualToString:aHost])
      return row;
  }
  return -1;
}

//
// NSTableDataSource protocol methods
//

-(int) numberOfRowsInTableView:(NSTableView *)aTableView
{
  int numRows = 0;
  if (aTableView == mPermissionsTable) {
    numRows = [mCachedPermissions count];
  } else if (aTableView == mCookiesTable) {
    numRows = [mCookies count];
  } else if (aTableView == mKeychainExclusionsTable) {
    numRows = [mKeychainExclusions count];
  }

  return numRows;
}

-(id) tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
  if (aTableView == mPermissionsTable) {
    if ([[aTableColumn identifier] isEqualToString: @"host"]) {
      return [[mCachedPermissions objectAtIndex:rowIndex] host];
    }
    else {
      int policy = [[mCachedPermissions objectAtIndex:rowIndex] policy];
      return [NSNumber numberWithInt:[self indexForPolicy:policy]];
    }
  }
  else if (aTableView == mCookiesTable) {
    if ([[aTableColumn identifier] isEqualToString: @"isSecure"]) {
      BOOL secure = [[mCookies objectAtIndex:rowIndex] isSecure];
      return [self localizedStringForKey:(secure ? @"yes": @"no")];
    } else if ([[aTableColumn identifier] isEqualToString: @"expiresDate"]) {
      NSHTTPCookie* cookie = [mCookies objectAtIndex:rowIndex];
      BOOL isSessionCookie = [cookie isSessionOnly];
      // If it's a session cookie, set the expiration date to the epoch,
      // so the custom formatter can display a localized string.
      return isSessionCookie ? [NSDate dateWithTimeIntervalSince1970:0]
                             : [cookie expiresDate];
    } else {
      return [[mCookies objectAtIndex:rowIndex] valueForKey:[aTableColumn identifier]];
    }
  }
  else if (aTableView == mKeychainExclusionsTable) {
    if ([[aTableColumn identifier] isEqualToString:@"Website"]) {
      return [mKeychainExclusions objectAtIndex:rowIndex];
    }
  }

  return nil;
}

// currently, this only applies to the site allow/deny, since that's the only editable column
-(void) tableView:(NSTableView *)aTableView
   setObjectValue:anObject
   forTableColumn:(NSTableColumn *)aTableColumn
              row:(int)rowIndex
{
  if (aTableView == mPermissionsTable && aTableColumn == mPermissionColumn) {
    CHPermission* permission = [mCachedPermissions objectAtIndex:rowIndex];
    [permission setPolicy:[self policyForIndex:[anObject intValue]]];
    
    // Re-sort if policy was the sort column.
    if ([mPermissionsTable highlightedTableColumn] == mPermissionColumn) {
      [self sortPermissionsByKey:[mPermissionColumn identifier] inAscendingOrder:mSortedAscending];
      int newRowIndex = [mCachedPermissions indexOfObject:permission];
      if (newRowIndex != NSNotFound) {
        [aTableView selectRow:newRowIndex byExtendingSelection:NO];
        [aTableView scrollRowToVisible:newRowIndex];
      }
    }
  }
}

-(void) sortPermissionsByKey:(NSString *)sortKey inAscendingOrder:(BOOL)ascending
{
  NSMutableArray* sortDescriptors;
  if ([sortKey isEqualToString:@"host"]) {
    NSSortDescriptor* sort =
      [[[NSSortDescriptor alloc] initWithKey:sortKey
                                   ascending:ascending
                                    selector:@selector(reverseHostnameCompare:)] autorelease];
    sortDescriptors = [NSArray arrayWithObject:sort];
  }
  else {
    NSSortDescriptor* mainSort =
      [[[NSSortDescriptor alloc] initWithKey:sortKey
                                   ascending:ascending] autorelease];
    // When not sorted by host, break ties in host order.
    NSSortDescriptor *hostSort = [[[NSSortDescriptor alloc] initWithKey:@"host"
                                                              ascending:YES
                                                               selector:@selector(reverseHostnameCompare:)] autorelease];
    sortDescriptors = [NSArray arrayWithObjects:mainSort, hostSort, nil];
  }
  [mCachedPermissions sortUsingDescriptors:sortDescriptors];

  [mPermissionsTable reloadData];

  [self updateSortIndicatorWithColumn:[mPermissionsTable tableColumnWithIdentifier:sortKey]];
}

-(void) sortCookiesByColumn:(NSTableColumn *)aTableColumn inAscendingOrder:(BOOL)ascending
{
  NSArray* sortDescriptors = nil;
  if ([[aTableColumn identifier] isEqualToString:@"domain"]) {
    NSSortDescriptor *sort = [[[NSSortDescriptor alloc] initWithKey:@"domain"
                                                          ascending:ascending
                                                           selector:@selector(reverseHostnameCompare:)] autorelease];
    sortDescriptors = [NSArray arrayWithObject:sort];
  }
  else if ([[aTableColumn identifier] isEqualToString:@"expiresDate"]) {
    NSSortDescriptor *sessionSort = [[[NSSortDescriptor alloc] initWithKey:@"isSessionOnly"
                                                                 ascending:ascending] autorelease];
    NSSortDescriptor *expirySort = [[[NSSortDescriptor alloc] initWithKey:@"expiresDate"
                                                                ascending:ascending] autorelease];
    sortDescriptors = [NSArray arrayWithObjects:sessionSort, expirySort, nil];
  }
  else { // All the other column just use a default sort
    NSSortDescriptor *sort = [[[NSSortDescriptor alloc] initWithKey:[aTableColumn identifier]
                                                          ascending:ascending] autorelease];
    sortDescriptors = [NSArray arrayWithObject:sort];
  }
  [mCookies sortUsingDescriptors:sortDescriptors];

  [mCookiesTable reloadData];

  [self updateSortIndicatorWithColumn:aTableColumn];
}

- (void)sortKeychainExclusionsByColumn:(NSTableColumn*)tableColumn
                      inAscendingOrder:(BOOL)ascending {
  NSArray* sortDescriptors = nil;
  if ([[tableColumn identifier] isEqualToString:@"Website"]) {
    NSSortDescriptor* sort =
        [[[NSSortDescriptor alloc] initWithKey:@"self"
                                     ascending:ascending
                                      selector:@selector(reverseHostnameCompare:)] autorelease];
    sortDescriptors = [NSArray arrayWithObject:sort];
  }
  [mKeychainExclusions sortUsingDescriptors:sortDescriptors];

  [mKeychainExclusionsTable reloadData];

  [self updateSortIndicatorWithColumn:tableColumn];
}

- (void)updateSortIndicatorWithColumn:(NSTableColumn *)aTableColumn
{
  NSTableView* table = [aTableColumn tableView];
  NSTableColumn* oldColumn = [table highlightedTableColumn];
  if (oldColumn)
    [table setIndicatorImage:nil inTableColumn:oldColumn];
  
  NSImage *sortIndicator = [NSImage imageNamed:(mSortedAscending ? @"NSAscendingSortIndicator"
                                                                 : @"NSDescendingSortIndicator")];
  [table setIndicatorImage:sortIndicator inTableColumn:aTableColumn];
  [table setHighlightedTableColumn:aTableColumn];
}

// NSTableView delegate methods

- (void) tableView:(NSTableView *)aTableView didClickTableColumn:(NSTableColumn *)aTableColumn
{
  // reverse the sort if clicking again on the same column
  if (aTableColumn == [aTableView highlightedTableColumn])
    mSortedAscending = !mSortedAscending;
  else
    mSortedAscending = YES;

  NSArray* dataSource = nil;
  if (aTableView == mPermissionsTable)
    dataSource = mCachedPermissions;
  else if (aTableView == mCookiesTable)
    dataSource = mCookies;
  else if (aTableView == mKeychainExclusionsTable)
    dataSource = mKeychainExclusions;

  if (!dataSource)
    return;

  // Save the currently selected rows, if any.
  NSMutableArray* selectedItems = [NSMutableArray array];
  NSIndexSet* selectedIndexes = [aTableView selectedRowIndexes];
  for (unsigned int i = [selectedIndexes lastIndex];
       i != NSNotFound;
       i = [selectedIndexes indexLessThanIndex:i])
  {
    [selectedItems addObject:[dataSource objectAtIndex:i]];
  }

  // Sort the table data.
  if (aTableView == mPermissionsTable) {
    [self sortPermissionsByKey:[aTableColumn identifier]
              inAscendingOrder:mSortedAscending];
  } else if (aTableView == mCookiesTable) {
    [self sortCookiesByColumn:aTableColumn
             inAscendingOrder:mSortedAscending];
  } else if (aTableView == mKeychainExclusionsTable) {
    [self sortKeychainExclusionsByColumn:aTableColumn
                        inAscendingOrder:mSortedAscending];
  }

  // If any rows were selected before, find them again.
  [aTableView deselectAll:self];
  for (unsigned int i = 0; i < [selectedItems count]; ++i) {
    int newRowIndex = [dataSource indexOfObject:[selectedItems objectAtIndex:i]];
    if (newRowIndex != NSNotFound) {
      // scroll to the first item (arbitrary, but at least one should show)
      if (i == 0)
        [aTableView scrollRowToVisible:newRowIndex];
      [aTableView selectRow:newRowIndex byExtendingSelection:YES];
    }
  }
}

//
// Buttons
//

-(IBAction) clickCookieBehavior:(id)sender
{
  int row = [mCookieBehavior selectedRow];
  [self setPref:"network.cookie.cookieBehavior" toInt:row];
  [self mapCookiePrefToGUI:row];
}

-(IBAction) clickAskAboutCookies:(id)sender
{
  [sender setAllowsMixedState:NO];
  [self setPref:"network.cookie.lifetimePolicy" toInt:([sender state] == NSOnState) ? kWarnAboutCookies : kAcceptCookiesNormally];
}


//
// clickStorePasswords
//
-(IBAction) clickStorePasswords:(id)sender
{
  [self setPref:gUseKeychainPref toBoolean:([mStorePasswords state] == NSOnState)];
}

-(IBAction) launchKeychainAccess:(id)sender
{
  FSRef fsRef;
  CFURLRef urlRef;
  OSErr err = ::LSGetApplicationForInfo('APPL', 'kcmr', NULL, kLSRolesAll, &fsRef, &urlRef);
  if (!err) {
    CFStringRef fileSystemURL = ::CFURLCopyFileSystemPath(urlRef, kCFURLPOSIXPathStyle);
    [[NSWorkspace sharedWorkspace] launchApplication:(NSString*)fileSystemURL];
    CFRelease(fileSystemURL);
  }
}

// Delegate method for the filter search fields. Watches for an Enter or
// Return in the filter, and passes it off to the sheet to trigger the default
// button to dismiss the sheet.
- (void)controlTextDidEndEditing:(NSNotification *)aNotification {
  id source = [aNotification object];
  if (!(source == mCookiesFilterField || source == mPermissionFilterField ||
        source == mKeychainExclusionsFilterField)) {
    return;
  }
  
  NSEvent* currentEvent = [NSApp currentEvent];
  if (([currentEvent type] == NSKeyDown) && [[currentEvent characters] length] > 0) {
    unichar character = [[currentEvent characters] characterAtIndex:0];
    if ((character == NSCarriageReturnCharacter) || (character == NSEnterCharacter)) {
      if (source == mCookiesFilterField)
        [mCookiesPanel performKeyEquivalent:currentEvent];
      else if (source == mPermissionFilterField)
        [mPermissionsPanel performKeyEquivalent:currentEvent];
      else if (source == mKeychainExclusionsFilterField)
        [mKeychainExclusionsPanel performKeyEquivalent:currentEvent];
    }
  }
}

- (IBAction)cookieFilterChanged:(id)sender
{
  if (!mCookies)
    return;

  NSString* filterString = [sender stringValue];

  // reinitialize the list of cookies in case user deleted or replaced a letter
  [self filterCookiesWithString:filterString];
  // re-sort
  [self sortCookiesByColumn:[mCookiesTable highlightedTableColumn] inAscendingOrder:mSortedAscending];
  [mCookiesTable deselectAll:self];   // don't want any traces of previous selection
  [mCookiesTable reloadData];
}

- (IBAction)permissionFilterChanged:(id)sender
{
  if (!mCachedPermissions)
    return;

  NSString* filterString = [sender stringValue];

  // reinitialize the list of permission in case user deleted or replaced a letter.
  [self filterCookiesPermissionsWithString:filterString];
  // re-sort
  [self sortPermissionsByKey:[[mPermissionsTable highlightedTableColumn] identifier]
            inAscendingOrder:mSortedAscending];

  [mPermissionsTable deselectAll:self];   // don't want any traces of previous selection
  [mPermissionsTable reloadData];
}

- (IBAction)keychainExclusionsFilterChanged:(id)sender {
  NSString* filterString = [sender stringValue];

  [self filterKeychainExclusionsWithString:filterString];
  [self sortKeychainExclusionsByColumn:[mKeychainExclusionsTable highlightedTableColumn]
                      inAscendingOrder:mSortedAscending];
  [mKeychainExclusionsTable deselectAll:self];
  [mKeychainExclusionsTable reloadData];
}

- (void)filterCookiesPermissionsWithString:(NSString*)inFilterString
{
  // Reinitialize the list in case the user deleted or replaced a letter.
  [self populatePermissionCache];

  if ([inFilterString length] == 0)
    return;

  for (int i = [mCachedPermissions count] - 1; i >= 0; --i) {
    NSString* host = [[mCachedPermissions objectAtIndex:i] host];
    if ([host rangeOfString:inFilterString].location == NSNotFound)
      [mCachedPermissions removeObjectAtIndex:i];
  }
}

- (void) filterCookiesWithString: (NSString*) inFilterString
{
  // Reinitialize the list in case the user deleted or replaced a letter.
  [self populateCookieCache];

  if ([inFilterString length] == 0)
    return;

  for (int i = [mCookies count] - 1; i >= 0; --i) {
    NSString* host = [[mCookies objectAtIndex:i] domain];
    // Only search by host; other fields are probably not interesting to users
    if ([host rangeOfString:inFilterString].location == NSNotFound)
      [mCookies removeObjectAtIndex:i];
  }
}

- (void)filterKeychainExclusionsWithString: (NSString*)filterString {
  [self loadKeychainExclusions];

  if ([filterString length]) {
    for (int index = [mKeychainExclusions count] - 1; index >= 0; --index) {
      if ([[mKeychainExclusions objectAtIndex:index] rangeOfString:filterString].location == NSNotFound) {
        [mKeychainExclusions removeObjectAtIndex:index];
      }
    }
  }
}

- (void)addPermissionForSelection:(int)inPermission
{
  CHPermissionManager* permManager = [CHPermissionManager permissionManager];
  NSIndexSet* selectedIndexes = [mCookiesTable selectedRowIndexes];
  for (unsigned int index = [selectedIndexes lastIndex];
       index != NSNotFound;
       index = [selectedIndexes indexLessThanIndex:index])
  {
    NSString* host = [[mCookies objectAtIndex:index] domain];
    if ([host hasPrefix:@"."] && [host length] > 1)
      host = [host substringFromIndex:1];
    [permManager setPolicy:inPermission
                   forHost:host
                      type:CHPermissionTypeCookie];
  }
}

- (int)numCookiesSelectedInCookiePanel
{
  int numSelected = 0;
  if ([mCookiesPanel isVisible])
    numSelected = [mCookiesTable numberOfSelectedRows];

  return numSelected;
}

- (int)numPermissionsSelectedInPermissionsPanel
{
  int numSelected = 0;
  if ([mPermissionsPanel isVisible])
    numSelected = [mPermissionsTable numberOfSelectedRows];

  return numSelected;
}

- (int)numUniqueCookieSitesSelected:(NSString**)outSiteName
{
  if (outSiteName)
    *outSiteName = nil;

  NSArray* selectedSites = [self selectedCookieSites];
  unsigned int numHosts = [selectedSites count];
  if (numHosts == 1 && outSiteName)
    *outSiteName = [self permissionsBlockingNameForCookieHostname:[selectedSites firstObject]];

  return numHosts;
}

- (NSString*)permissionsBlockingNameForCookieHostname:(NSString*)inHostname
{
  // if the host string starts with a '.', remove it (because this is
  // how the permissions manager looks up hosts)
  if ([inHostname hasPrefix:@"."])
    inHostname = [inHostname substringFromIndex:1];
  return inHostname;
}

- (NSArray*)selectedCookieSites
{
  // the set does the uniquifying for us
  NSMutableSet* selectedHostsSet = [[[NSMutableSet alloc] init] autorelease];
  NSIndexSet* selectedIndexes = [mCookiesTable selectedRowIndexes];
  for (unsigned int index = [selectedIndexes lastIndex];
       index != NSNotFound;
       index = [selectedIndexes indexLessThanIndex:index])
  {
    [selectedHostsSet addObject:[[mCookies objectAtIndex:index] domain]];
  }
  return [selectedHostsSet allObjects];
}

- (BOOL)validateMenuItem:(NSMenuItem*)inMenuItem
{
  SEL action = [inMenuItem action];
  
  // cookies context menu
  if (action == @selector(removeCookies:))
    return ([self numCookiesSelectedInCookiePanel] > 0);

  // only allow "remove all" when there are items and when not filtering
  if (action == @selector(removeAllCookies:))
    return ([mCookiesTable numberOfRows] > 0 &&
            [[mCookiesFilterField stringValue] length] == 0);

  if (action == @selector(allowCookiesFromSites:)) {
    NSString* siteName = nil;
    int numCookieSites = [self numUniqueCookieSitesSelected:&siteName];
    NSString* menuTitle = (numCookieSites == 1) ?
                            [NSString stringWithFormat:[self localizedStringForKey:@"AllowCookieFromSite"], siteName] :
                            [self localizedStringForKey:@"AllowCookiesFromSites"];
    [inMenuItem setTitle:menuTitle];
    return (numCookieSites > 0);
  }

  if (action == @selector(blockCookiesFromSites:)) {
    NSString* siteName = nil;
    int numCookieSites = [self numUniqueCookieSitesSelected:&siteName];
    NSString* menuTitle = (numCookieSites == 1) ?
                            [NSString stringWithFormat:[self localizedStringForKey:@"BlockCookieFromSite"], siteName] :
                            [self localizedStringForKey:@"BlockCookiesFromSites"];
    [inMenuItem setTitle:menuTitle];
    return (numCookieSites > 0);
  }

  if (action == @selector(removeCookiesAndBlockSites:)) {
    NSString* siteName = nil;
    int numCookieSites = [self numUniqueCookieSitesSelected:&siteName];

    NSString* menuTitle = (numCookieSites == 1) ?
                            [NSString stringWithFormat:[self localizedStringForKey:@"RemoveAndBlockCookieFromSite"], siteName] :
                            [self localizedStringForKey:@"RemoveAndBlockCookiesFromSites"];
    [inMenuItem setTitle:menuTitle];
    return (numCookieSites > 0);
  }

  if (action == @selector(expandCookiePermission:)) {
    // If there is excatly one row selected and it is expandable (i.e., not
    // just a TLD already), enable the menu and give it a  descriptive title,
    // otherwise disable it and give it a generic title.
    int selectedRowCount = [[mPermissionsTable selectedRowIndexes] count];
    NSString* superdomain = nil;
    if (selectedRowCount == 1) {
      NSString* selectedHost = [[mCachedPermissions objectAtIndex:[mPermissionsTable selectedRow]] host];
      superdomain = [[self class] superdomainForHost:selectedHost];
    }
    NSString* menuTitle = superdomain ? [NSString stringWithFormat:[self localizedStringForKey:@"ExpandExceptionForSite"], superdomain]
                                      : [self localizedStringForKey:@"ExpandException"];
    [inMenuItem setTitle:menuTitle];
    return (superdomain != nil);
  }

  // permissions context menu
  if (action == @selector(removeCookiePermissions:))
    return ([self numPermissionsSelectedInPermissionsPanel] > 0);

  // only allow "remove all" when there are items and when not filtering
  if (action == @selector(removeAllCookiePermissions:))
    return ([mPermissionsTable numberOfRows] > 0 &&
            [[mPermissionFilterField stringValue] length] == 0);

  // Keychain Exclusions context/action menu
  if (action == @selector(removeKeychainExclusions:)) {
    return ([mKeychainExclusionsTable numberOfSelectedRows] > 0);
  }

  if (action == @selector(removeAllKeychainExclusions:)) {
    // Only allow "Remove All..." when there are items to remove, and when
    // no filer is applied.
    return ([mKeychainExclusionsTable numberOfRows] > 0 &&
            [[mKeychainExclusionsFilterField stringValue] length] == 0);
  }

  return YES;
}

- (void)loadKeychainExclusions {
  [mKeychainExclusions release];
  mKeychainExclusions = [[[KeychainDenyList instance] listHosts] mutableCopy];
}

- (IBAction)editKeychainExclusions:(id)sender {
  [self loadKeychainExclusions];

  [mKeychainExclusionsTable setDeleteAction:@selector(removeKeychainExclusions:)];
  [mKeychainExclusionsTable setTarget:self];

  mSortedAscending = YES;
  [self sortKeychainExclusionsByColumn:[mKeychainExclusionsTable tableColumnWithIdentifier:@"Website"]
                      inAscendingOrder:mSortedAscending];

  // ensure a row is selected (cocoa doesn't do this for us, but will keep
  // us from unselecting a row once one is set; go figure).
  if ([mKeychainExclusionsTable numberOfRows] > 0) {
    [mKeychainExclusionsTable selectRow:0 byExtendingSelection:NO];
  }

  [mKeychainExclusionsTable setUsesAlternatingRowBackgroundColors:YES];

  [mKeychainExclusionsFilterField setStringValue:@""];

  // we shouldn't need to do this, but the scrollbar won't enable unless we
  // force the table to reload its data. Oddly it gets the number of rows
  // correct, it just forgets to tell the scrollbar. *shrug*
  [mKeychainExclusionsTable reloadData];

  [mKeychainExclusionsPanel setFrameAutosaveName:@"keychain_exclusions_sheet"];

  [NSApp beginSheet:mKeychainExclusionsPanel
     modalForWindow:[sender window]
      modalDelegate:self
     didEndSelector:NULL
        contextInfo:NULL];

  NSSize min = {350, 225};
  [mKeychainExclusionsPanel setMinSize:min];
}

- (IBAction)editKeychainExclusionsDone:(id)sender {
  [mKeychainExclusionsPanel orderOut:self];
  [NSApp endSheet:mKeychainExclusionsPanel];
  [mKeychainExclusions release];
  mKeychainExclusions = nil;
}

- (IBAction)removeKeychainExclusions:(id)sender {
  NSIndexSet* selectedIndexes = [mKeychainExclusionsTable selectedRowIndexes];
  for (unsigned int index = [selectedIndexes lastIndex];
       index != NSNotFound;
       index = [selectedIndexes indexLessThanIndex:index]) {
    [[KeychainDenyList instance] removeHost:[mKeychainExclusions objectAtIndex:index]];
    [mKeychainExclusions removeObjectAtIndex:index];
  }

  [mKeychainExclusionsTable reloadData];

  // Select the row after the last deleted row.
  if ([mKeychainExclusionsTable numberOfRows] > 0) {
    int rowToSelect = [selectedIndexes lastIndex] - ([selectedIndexes count] - 1);
    if ((rowToSelect < 0) ||
        (rowToSelect >= [mKeychainExclusionsTable numberOfRows])) {
      rowToSelect = [mKeychainExclusionsTable numberOfRows] - 1;
    }
    [mKeychainExclusionsTable selectRow:rowToSelect byExtendingSelection:NO];
  }
}

- (IBAction)removeAllKeychainExclusions:(id)sender {
  if (NSRunCriticalAlertPanel([self localizedStringForKey:@"RemoveAllKeychainExclusionsWarningTitle"],
                              [self localizedStringForKey:@"RemoveAllKeychainExclusionsWarning"],
                              [self localizedStringForKey:@"RemoveAllKeychainExclusionsButton"],
                              [self localizedStringForKey:@"CancelButtonText"],
                              nil) == NSAlertDefaultReturn) {
    [[KeychainDenyList instance] removeAllHosts];
    [mKeychainExclusions removeAllObjects];
    [mKeychainExclusionsTable reloadData];
  }
}

// Private method to convert from a popup index to the corresponding policy.
- (int)indexForPolicy:(int)policy
{
  if (policy == CHPermissionDeny)
    return eDenyIndex;
  if (policy == CHPermissionAllowForSession)
    return eSessionOnlyIndex;
  return eAllowIndex;
}

// Private method to convert from a policy to the corresponding popup index.
- (int)policyForIndex:(int)index
{
  switch (index) {
    case eDenyIndex:
      return CHPermissionDeny;
    case eSessionOnlyIndex:
      return CHPermissionAllowForSession;
    case eAllowIndex:
    default:
      return CHPermissionAllow;
  }
}

@end

#pragma mark -

@implementation CookieDateFormatter

- (id)initWithDateFormat:(NSString*)format allowNaturalLanguage:(BOOL)flag;
{
  if ((self = [super initWithDateFormat:format allowNaturalLanguage:flag])) {
    CFLocaleRef userLocale = CFLocaleCopyCurrent();
    if (userLocale) {
      mLocaleFormatter = CFDateFormatterCreate(NULL,
                                               userLocale,
                                               kCFDateFormatterMediumStyle,
                                               kCFDateFormatterNoStyle);
      CFRelease(userLocale);
    }
  }
  return self;
}

- (void)dealloc
{
  if (mLocaleFormatter)
    CFRelease(mLocaleFormatter);
  [super dealloc];
}

- (NSString*)stringForObjectValue:(id)anObject
{
  if ([(NSDate*)anObject timeIntervalSince1970] == 0)
    return NSLocalizedStringFromTableInBundle(@"CookieExpiresOnQuit", nil,
                                              [NSBundle bundleForClass:[self class]], nil);
  if (mLocaleFormatter) {
    NSString* dateString = (NSString*)CFDateFormatterCreateStringWithDate(NULL,
                                                                          mLocaleFormatter,
                                                                          (CFDateRef)anObject);
    if (dateString)
      return [dateString autorelease];
  }

  // If all else fails, fall back on the standard date formatter
  return [super stringForObjectValue:anObject];
}

@end
