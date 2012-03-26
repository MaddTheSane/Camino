/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Foundation/Foundation.h>

@class TrieNode;

// Protocol used by a Trie to generate keywords for an object.
@protocol TrieKeywordGenerator <NSObject>
// Returns the keywords for the given item. This may be called during both
// insertion and searching. For searching to work correctly, it must return
// the same keywords every time (although order is not important).
- (NSArray*)keywordsForItem:(id)item;
@end

// Protocol used by a Trie to generate scores for an object.
@protocol TrieScorer <NSObject>
// Returns the score for the given item. The score of an item relative to other
// items should not change without the item being removed from the trie and
// re-inserted, but the absolute score can change over time.
// The higher the score, the higher the ranking in search results.
- (double)scoreForItem:(id)item;
@end

// Trie implementation for storing objects keyed by strings, for doing fast
// prefix searching.
@interface Trie : NSObject
{
 @private
  TrieNode*                         mRoot;
  id<TrieScorer>                    mScorer;
  id<TrieKeywordGenerator>          mKeywordGenerator;
  unsigned int                      mMaxDepth;

  // Previous query cache.
  NSMutableArray*                   mPreviousMatches;
  NSArray*                          mPreviousQueryTerms;
  NSArray*                          mPreviousCandidateList;
  unsigned int                      mLastCheckedCandidateIndex;
}

// Initializes a Trie that uses the given keyword generation generator to
// determine query matches, and the scorer to order the results.
// maxDepth is the maximum depth of the Trie; search terms longer than this
// depth require expensive validation at search time, so this paramater allows
// tuning between memory usage and search speed.
- (id)initWithKeywordGenerator:(id<TrieKeywordGenerator>)keywordGenerator
                        scorer:(id<TrieScorer>)scorer
                      maxDepth:(unsigned int)maxDepth;

// Adds the given item to the trie under all relevent search terms.
- (void)addItem:(id)item;

// Removes the given item from the trie.
- (void)removeItem:(id)item;

// Removes all items from the trie.
- (void)removeAllItems;

// Returns up to |limit| items matching all of the given search terms, using
// prefix matching. If |limit| is 0, all matching items will be returned.
- (NSArray*)itemsForTerms:(NSArray*)terms withLimit:(unsigned int)limit;

// Prints the trie to the console, for debugging.
- (void)print;

@end
