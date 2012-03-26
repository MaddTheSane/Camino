/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>

#import "Trie.h"

// Generates scores for ranking autocomplete suggestions.
@interface AutoCompleteScorer : NSObject<TrieScorer> {
  NSTimeInterval mCachedCurrentTime;
}

// TrieScorer implementation.
- (double)scoreForItem:(id)item;

// Sets the current time for use in scoring. This allows callers to optimize
// repeated calls to scoreForItem: in a tight loop, since finding the current
// time is relatively expensive.
- (void)cacheCurrentTime;
// Clears the cached time, so future calls to scoreForItem: will get the current
// time internally.
- (void)clearTimeCache;

@end
