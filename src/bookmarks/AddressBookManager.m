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
 *   David Haas <haasd@cae.wisc.edu>
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

/*
 * Lets us have address book code and still run on 10.1.  When/if 10.1
 * support goes away, merge this into SmartBookmarkManger class.
 */
#import "AddressBookManager.h"
#import "BookmarkFolder.h"
#import "Bookmark.h"
#import <AddressBook/AddressBook.h>


@implementation AddressBookManager

- (id)initWithFolder:(id)folder
{
  if ((self = [super init])) {
    [ABAddressBook sharedAddressBook];    // ensure notification constants are valid, docs say they're not until this is called
    mAddressBookFolder = [folder retain];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(fillAddressBook:) name:kABDatabaseChangedNotification object:nil];
    [nc addObserver:self selector:@selector(fillAddressBook:) name:kABDatabaseChangedExternallyNotification object:nil];
    [self fillAddressBook:nil];
  }
  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [mAddressBookFolder release];
  [super dealloc];
}

- (void)fillAddressBook:(NSNotification *)note
{
  // to fill, you must empty.
  unsigned i, count = [mAddressBookFolder count];
  for (i = 0; i < count; i++)
    [mAddressBookFolder deleteChild:[mAddressBookFolder objectAtIndex:0]];
  // fill address book with people.  could probably do this smarter,
  // but it's a start for now.
  ABAddressBook* ab = [ABAddressBook sharedAddressBook];
  NSEnumerator* peopleEnumerator = [[ab people] objectEnumerator];
  ABPerson* person;
  while ((person = [peopleEnumerator nextObject])) {
    // |kABHomePageProperty| is deprecated on Tiger. Look for the new property first and then
    // the old one (as the old one is still present, just no longer updated).
    ABMultiValue* urls = [person valueForProperty:kABURLsProperty];
    NSString* homepage = [urls valueAtIndex:[urls indexForIdentifier:[urls primaryIdentifier]]];
    if (!homepage)
      homepage = [person valueForProperty:kABHomePageProperty];
    if ([homepage length] > 0) {
      NSString* name = nil;
      NSString* firstName = [person valueForProperty:kABFirstNameProperty];
      NSString* lastName = [person valueForProperty:kABLastNameProperty];

      if (firstName || lastName) {
        if (!firstName)
          name = lastName;
        else if (!lastName)
          name = firstName;
        else {
          // Build the name string in a l10n-friendly manner: respect the name ordering flag if present,
          // or use the Address Book's default pref otherwise.
          int nameOrderFlag = [[person valueForProperty:kABPersonFlags] intValue] & kABNameOrderingMask;
          if (nameOrderFlag == kABDefaultNameOrdering)
            nameOrderFlag = [ab defaultNameOrdering];

          if (nameOrderFlag == kABLastNameFirst)
            name = [NSString stringWithFormat:@"%@ %@", lastName, firstName];
          else // Default to the standard in the English-speaking world.
            name = [NSString stringWithFormat:@"%@ %@", firstName, lastName];
        }
      }

      int personShowAsFlag = [[person valueForProperty:kABPersonFlags] intValue] & kABShowAsMask;

      if (personShowAsFlag == kABShowAsCompany) {
        NSString* company = [person valueForProperty:kABOrganizationProperty];
        if (!company)
          company = NSLocalizedString(@"<No Company Name>", nil);

        if (name) {
          name = [NSString stringWithFormat:NSLocalizedString(@"CompanyCardWithPersonNameFormat", @""),
                                            company,
                                            name];
        }
        else {
          name = [NSString stringWithFormat:@"%@", company];
        }
      }
      
      // We ought to have something by now, but if not, use the placeholder.
      if (!name)
        name = NSLocalizedString(@"<No Name>", nil);

      [mAddressBookFolder appendChild:[Bookmark bookmarkWithTitle:name
                                                              url:homepage
                                                        lastVisit:nil]];
    }
  }
}

@end
