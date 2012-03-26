/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

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
