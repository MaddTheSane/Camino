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
 * The Original Code is Camino code.
 *
 * The Initial Developer of the Original Code is
 * Daniel Weber
 * Portions created by the Initial Developer are Copyright (C) 2009
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *   Daniel Weber <dan.j.weber@gmail.com>
 *   Stuart Morgan <stuart.morgan@alumni.case.edu>
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
