/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*-
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "History.h"
#import "NSString+Utils.h"

#import "GeckoPrefConstants.h"

#include "nsCOMPtr.h"
#include "nsIServiceManager.h"
#include "nsIBrowserHistory.h"
#include "nsICacheService.h"

static const int kDefaultExpireDays = 9;

// A formatter for the history duration that only accepts integers >= 0
@interface NonNegativeIntegerFormatter : NSFormatter
{
}
@end

@implementation NonNegativeIntegerFormatter

- (NSString*)stringForObjectValue:(id)anObject
{
  // Normally we could just return [anObject stringValue], but since the pref is
  // being read after the formatter is set, this raises an exception if we do that.
  // Check for the proper class first to avoid this problem and return "" otherwise.
  return [anObject isKindOfClass:[NSNumber class]] ? [anObject stringValue] : @"";
}

- (BOOL)getObjectValue:(id*)anObject forString:(NSString*)string errorDescription:(NSString**)error
{
  *anObject = [NSNumber numberWithInt:[string intValue]];
  return YES;
}

- (BOOL)isPartialStringValid:(NSString*)partialString newEditingString:(NSString**)newString errorDescription:(NSString**)error
{
  NSCharacterSet* nonDigitSet = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
  if ([partialString rangeOfCharacterFromSet:nonDigitSet].location != NSNotFound) {
    *newString = [partialString stringByRemovingCharactersInSet:nonDigitSet];
    return NO;
  }
  return YES;
}

@end

#pragma mark -

@implementation OrgMozillaCaminoPreferenceHistory

- (void)mainViewDidLoad
{
  [textFieldHistoryDays setFormatter:[[[NonNegativeIntegerFormatter alloc] init] autorelease]];
}

- (void)willSelect
{
  BOOL gotPref;
  int expireDays = [self getIntPref:kGeckoPrefHistoryLifetimeDays withSuccess:&gotPref];
  if (!gotPref)
    expireDays = kDefaultExpireDays;

  [textFieldHistoryDays setIntValue:expireDays];
}

- (void)didUnselect
{
  [self setPref:kGeckoPrefHistoryLifetimeDays toInt:[textFieldHistoryDays intValue]];
}

- (IBAction)historyDaysModified:(id)sender
{
  [self setPref:kGeckoPrefHistoryLifetimeDays toInt:[sender intValue]];
}

// Clear the user's disk cache.
- (IBAction)clearDiskCache:(id)aSender
{
  NSAlert* clearCacheAlert = [[[NSAlert alloc] init] autorelease];
  [clearCacheAlert setMessageText:NSLocalizedString(@"EmptyCacheTitle", nil)];
  [clearCacheAlert setInformativeText:NSLocalizedString(@"EmptyCacheMessage", nil)];
  [clearCacheAlert addButtonWithTitle:NSLocalizedString(@"EmptyCacheButtonText", nil)];
  NSButton* dontEmptyButton = [clearCacheAlert addButtonWithTitle:NSLocalizedString(@"DontEmptyButtonText", nil)];
  [dontEmptyButton setKeyEquivalent:@"\e"]; // escape

  [clearCacheAlert setAlertStyle:NSCriticalAlertStyle];
  [clearCacheAlert beginSheetModalForWindow:[textFieldHistoryDays window]
                              modalDelegate:self
                             didEndSelector:@selector(clearDiskCacheAlertDidEnd:returnCode:contextInfo:)
                                contextInfo:nil];
}

// Use the browser history service to clear out the user's global history.
- (IBAction)clearGlobalHistory:(id)sender
{
  NSAlert* clearGlobalHistoryAlert = [[[NSAlert alloc] init] autorelease];
  [clearGlobalHistoryAlert setMessageText:NSLocalizedString(@"ClearHistoryTitle", nil)];
  [clearGlobalHistoryAlert setInformativeText:NSLocalizedString(@"ClearHistoryMessage", nil)];
  [clearGlobalHistoryAlert addButtonWithTitle:NSLocalizedString(@"ClearHistoryButtonText", nil)];
  NSButton* dontClearButton = [clearGlobalHistoryAlert addButtonWithTitle:NSLocalizedString(@"DontClearButtonText", nil)];
  [dontClearButton setKeyEquivalent:@"\e"]; // Escape

  [clearGlobalHistoryAlert setAlertStyle:NSCriticalAlertStyle];
  [clearGlobalHistoryAlert beginSheetModalForWindow:[textFieldHistoryDays window]
                                      modalDelegate:self
                                     didEndSelector:@selector(clearGlobalHistoryAlertDidEnd:returnCode:contextInfo:)
                                        contextInfo:nil];
}

#pragma mark -

- (void)clearDiskCacheAlertDidEnd:(NSAlert*)alert returnCode:(int)returnCode contextInfo:(void*)contextInfo
{
  if (returnCode == NSAlertFirstButtonReturn) {
    nsCOMPtr<nsICacheService> cacheServ (do_GetService("@mozilla.org/network/cache-service;1"));
    if (cacheServ)
      cacheServ->EvictEntries(nsICache::STORE_ANYWHERE);
  }
}

- (void)clearGlobalHistoryAlertDidEnd:(NSAlert*)alert returnCode:(int)returnCode contextInfo:(void*)contextInfo
{
  if (returnCode == NSAlertFirstButtonReturn) {
    nsCOMPtr<nsIBrowserHistory> hist (do_GetService("@mozilla.org/browser/global-history;2"));
    if (hist)
      hist->RemoveAllPages();
  }
}

@end
