/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "ABAddressBook+Utils.h"

#import <AppKit/NSWorkspace.h>

@interface ABAddressBook(CaminoPRIVATE)
- (void)openAddressBookAtRecord:(NSString*)uniqueId editFlag:(BOOL)withEdit;
@end

@implementation ABAddressBook (CaminoExtensions)

//
// Returns the record containing the specified e-mail, or nil if
// there is no such record. (If more than one record does!) we
// simply return the first.
//
- (ABPerson*)recordFromEmail:(NSString*)emailAddress
{
  ABSearchElement* search = [ABPerson searchElementForProperty:kABEmailProperty label:nil key:nil value:emailAddress comparison:kABEqualCaseInsensitive];
  
  NSArray* matches = [self recordsMatchingSearchElement:search];
  
  if ( [matches count] > 0 )
	  return [matches objectAtIndex:0];
	
	return nil;
}

//
// Determine if a record containing the given e-mail address as an e-mail address
// property exists in the address book.
//
- (BOOL)emailAddressExistsInAddressBook:(NSString*)emailAddress
{
  return ( [self recordFromEmail:emailAddress] != nil );
}

//
// Return the real name of the person in the address book with the
// specified e-mail address. Returns nil if the e-mail address does not
// occur in the address book.
//
- (NSString*)realNameForEmailAddress:(NSString*)emailAddress
{
  NSString* realName = nil;

  ABPerson* person = [self recordFromEmail:emailAddress];
  if ( person != nil ) {
	  
    NSNumber* flags = [person valueForProperty:@"ABPersonFlags"];
		
		int displayMode = kABShowAsPerson; // Default incase we're on 10.2 and property not set
		if ( flags != nil ) 
		  displayMode = [flags intValue] & kABShowAsMask;

		if (displayMode == kABShowAsPerson) {
      NSString* firstName = [person valueForProperty:kABFirstNameProperty];
      NSString* lastName  = [person valueForProperty:kABLastNameProperty];
    
      if ( firstName != nil && lastName != nil )
			  realName = [[firstName stringByAppendingString:@" "] stringByAppendingString:lastName];
			else if ( lastName != nil )
			  realName = lastName;
			else if ( firstName != nil )
			  realName = firstName;
			else
			  realName = emailAddress;

		} else {
		  realName = [person valueForProperty:kABOrganizationProperty];
		}
  }

  return realName;
}

//
// Add a new ABPerson record to the address book with the given e-mail address
// Then open the new record for edit so the user can fill in the rest of
// the details.
//
- (void)addNewPersonFromEmail:(NSString*)emailAddress
{
  ABPerson* newPerson = [[[ABPerson alloc] init] autorelease];
    
  ABMutableMultiValue* emailCollection = [[[ABMutableMultiValue alloc] init] autorelease];
  [emailCollection addValue:emailAddress withLabel:kABEmailWorkLabel];
  [newPerson setValue:emailCollection forProperty:kABEmailProperty];
    
  if ([self addRecord:newPerson]) {
    [self save];
    [self openAddressBookAtRecord:[newPerson uniqueId] editFlag:YES];
  }
}

//
// Opens the Address Book application at the record containing the given email address
//
- (void)openAddressBookForRecordWithEmail:(NSString*)emailAddress
{
  ABPerson* person = [self recordFromEmail:emailAddress];
	if ( person != nil ) {
	  [self openAddressBookAtRecord:[person uniqueId] editFlag:NO];
	}
}

//
// Opens the Address Book application at the specified record
// optionally sets up the record for editing, e.g. to complete remaining values
//
- (void)openAddressBookAtRecord:(NSString*)uniqueId editFlag:(BOOL)withEdit
{
  NSString *urlString = [NSString stringWithFormat:@"addressbook://%@", uniqueId];
	if ( withEdit )
	  urlString = [urlString stringByAppendingString:@"?edit"];
		
  [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:urlString]];
}

@end
