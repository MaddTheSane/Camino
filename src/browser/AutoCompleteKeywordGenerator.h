/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>

#import "Trie.h"

// Generates keywords for autocomplete suggestions.
@interface AutoCompleteKeywordGenerator : NSObject<TrieKeywordGenerator> {
  NSMutableDictionary* mSchemeToPlaceholderMap;  // owned

  BOOL                 mGeneratesTitleKeywords;  
}

// TrieKeywordGenerator implementation.
- (NSArray*)keywordsForItem:(id)item;

// Allows clients to disable keyword generation for titles if desired, e.g.
// based on a user's hidden preference setting.
- (void)setGeneratesTitleKeywords:(BOOL)useTitles;

// Returns the set of query terms to use when searching a trie for the given
// search string. It uses the same word breaking, standardization/substitution,
// etc. that keywordsForItem: uses.
- (NSArray*)searchTermsForString:(NSString*)searchString;

@end
