/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Foundation/Foundation.h>

#import <AddressBook/AddressBook.h>

@interface ABAddressBook (CaminoExtensions)

// Returns the record containing the specified e-mail, or nil if
// there is no such record. (If more than one record does!) we
// simply return the first.
- (ABPerson*)recordFromEmail:(NSString*)emailAddress;

// Determine if a record containing the given e-mail address as an e-mail address
// property exists in the address book.
- (BOOL)emailAddressExistsInAddressBook:(NSString*)emailAddress;

// Return the real name of the person in the address book with the
// specified e-mail address. Returns nil if the e-mail address does not
// occur in the address book.
- (NSString*)realNameForEmailAddress:(NSString*)emailAddress;

// Add a new ABPerson record to the address book with the given e-mail address
// Then open the new record for edit so the user can fill in the rest of
// the details.
- (void)addNewPersonFromEmail:(NSString*)emailAddress;

// Opens the Address Book application at the record containing the given email address
- (void)openAddressBookForRecordWithEmail:(NSString*)emailAddress;

@end
