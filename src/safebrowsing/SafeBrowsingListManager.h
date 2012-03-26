/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>

class nsIUrlListManager;

// Used to specify a type of list which can be obtained from the data provider.
typedef enum {
  eSafeBrowsingPhishingListType = (1 << 0),
  eSafeBrowsingMalwareListType  = (1 << 1),
  eSafeBrowsingAnyListType      = 0xFFFFFFFF
} ESafeBrowsingListType;

// A bit mask specifying a combination of |ESafeBrowsingListType| values.
typedef int SafeBrowsingListTypesMask;

#pragma mark -

//
// SafeBrowsingList
//
// Simple data object used by the SafeBrowsingListManager 
// to represent a data provider list.
//
@interface SafeBrowsingList : NSObject
{
 @private
  NSString              *mName;
  ESafeBrowsingListType  mType;
}

+ (id)listWithName:(NSString *)aName type:(ESafeBrowsingListType)aType;
- (id)initWithName:(NSString *)aName type:(ESafeBrowsingListType)aType;

- (NSString *)name;
- (void)setName:(NSString *)aName;
- (ESafeBrowsingListType)type;
- (void)setType:(ESafeBrowsingListType)aListType;

@end

#pragma mark -

//
// SafeBrowsingListManager
//
// A shared object offering control over the maintenance and update process of the
// local database of safe browsing information, which is populated from lists made 
// available by remote data providers. Data provider properties are stored in Gecko's
// preferences.
//
//
@interface SafeBrowsingListManager : NSObject
{
 @private
  nsIUrlListManager *mListManager;               // strong
  NSMutableArray    *mRegisteredLists;           // strong; An array of SafeBrowsingList objects.
}

+ (SafeBrowsingListManager *)sharedInstance;

// The SafeBrowsingListManager will determine which list types to enable updates on based
// on current preference values.
- (void)enableUpdateCheckingAccordingToPrefs;

// |listTypesMask| should contain |ESafeBrowsingListType| values combined with the C bitwise
// OR operator.
- (void)enableUpdateCheckingForListTypes:(SafeBrowsingListTypesMask)aListTypesMask;
- (void)disableUpdateCheckingForListTypes:(SafeBrowsingListTypesMask)aListTypesMask;
- (void)disableAllUpdateChecking;

// Calling this method with |eSafeBrowsingAnyListType| will return YES if update checking
// is enabled for at least one list type.
- (BOOL)updatesAreEnabledInPrefsForListType:(ESafeBrowsingListType)aListType;

// Registered lists are fetched from the data provider during each update cycle.
- (void)registerListWithName:(NSString *)aListName type:(ESafeBrowsingListType)aListType;
- (void)unregisterListWithName:(NSString *)aListName;

// While update checks are performed periodically on enabled lists, this method forces a manual
// check to take place immediately.
- (void)checkForUpdates;

// Obtains a URL to report list information to the data provider, filling in all URL
// parameters. |prefKeyTemplate| is a Gecko pref key for the type of reporting URL.
- (NSString *)listReportingURLForPrefKey:(NSString *)prefKeyTemplate
                             urlToReport:(NSString *)urlToReport;

@end
