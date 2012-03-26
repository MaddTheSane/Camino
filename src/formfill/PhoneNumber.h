/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>

//
// PhoneNumber
//
// A helper class for parsing a phone number into its respective parts. If
// initialization fails, the getters will return nil strings.
//

@interface PhoneNumber : NSObject 
{
@private
  NSString* remainderString;    // XXX(111)111-1111
  NSString* areaCodeString;     // (XXX)111-1111
  NSString* prefixString;       // (111)XXX-1111
  NSString* suffixString;       // (111)111-XXXX
}

-(id)initWithPhoneNumberString:(NSString*)phoneString;
-(NSString*)remainderString;
-(NSString*)areaCodeString;
-(NSString*)prefixString;
-(NSString*)suffixString;

@end
