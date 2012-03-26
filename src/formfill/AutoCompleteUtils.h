/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>

// AutoCompleteResults
//
// Container object for generic auto complete.
// Holds the search string, array of matched objects and the default item.
//
@interface AutoCompleteResults : NSObject
{
  NSString*  mSearchString;     // strong
  NSArray*   mMatches;          // strong
  int        mDefaultIndex;
}
- (NSString*)searchString;
- (void)setSearchString:(NSString*)string;

- (NSArray*)matches;
- (void)setMatches:(NSArray*)matches;

- (int)defaultIndex;
- (void)setDefaultIndex:(int)defaultIndex;

@end

// AutoCompleteListener
//
// This defines the protocol methods for the object that listens for auto complete
// results.  |onAutoComplete| is called by the object that searches the data and
// the results are returned to the originating caller as AutoCompleteResults.
//
@protocol AutoCompleteListener
- (void)autoCompleteFoundResults:(AutoCompleteResults*)results;
@end

// AutoCompleteSession
//
// An AutoCompleteSession object listens for search requests and searches a set of data 
// |startAutoCompleteWithSearch| initiates the process.  Previous results are passed in 
// as well as the listener object for when the search is complete.
//
@protocol AutoCompleteSession
- (void)startAutoCompleteWithSearch:(NSString*)searchString 
                    previousResults:(AutoCompleteResults*)previousSearchResults
                           listener:(id<AutoCompleteListener>)listener;
@end
