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

#import "Trie.h"

#import "NSArray+Utils.h"
#import "NSString+Utils.h"

// A node in a Trie, containing a dictionary of child nodes keyed by the next
// string segment, and a list of items matched by the prefix represented by
// the node.
// The item list is complete, so it is not necessary to recurse through a whole
// subtree to build the list of matches. This uses slightly more memory, but
// prevents an n-way merge of all of the sorted descendant nodes' lists.
@interface TrieNode : NSObject
{
 @private
  NSMutableDictionary*   mChildren;
  NSMutableArray*        mItems;
}

// Adds an item to the trie with the given keyword. |scorer| is used to order
// the list of items at the given node; it should always be the same for every
// node in a trie.
// This is intended to be called on the root node only.
- (void)addItem:(id)item
        withKey:(NSString*)key
         scorer:(id<TrieScorer>)scorer;

// Removes an item recursively, starting at this node.
- (void)removeItem:(id)item;

// Returns all items in the trie matching |key|.
- (NSArray*)itemsForKey:(NSString*)key;

// Prints the trie recursively, indented according to |depth|.
- (void)printAtDepth:(int)depth;

@end

@interface TrieNode (Private)

// Returns an empty, autoreleased trieNode.
+ (TrieNode*)trieNode;

// Helper for addItem:withKey:scorer:; stores the item in the child node
// corresponding to the character at |index| in |key|, then recurses.
- (void)addItem:(id)item
        withKey:(NSString*)key
      charIndex:(unsigned int)index
         scorer:(id<TrieScorer>)scorer;

// Stores the given item in this node's item list at the position indicated by
// scorer.
- (void)storeItem:(id)item withScorer:(id<TrieScorer>)scorer;

// Helper for itemsForKey:; if |index| is the end of |key|, returns the item
// array, otherwise recurses. May return duplicates.
- (NSArray*)itemsForKey:(NSString*)key charIndex:(unsigned int)index;

@end


@implementation TrieNode

- (id)init
{
  if ((self = [super init])) {
    mItems = [[NSMutableArray alloc] init];
  }
  return self;
}

- (void)dealloc
{
  [mChildren release];
  [mItems release];
  [super dealloc];
}

+ (TrieNode*)trieNode
{
  return [[[TrieNode alloc] init] autorelease];
}

- (void)addItem:(id)item
        withKey:(NSString*)key
         scorer:(id<TrieScorer>)scorer;
{
  [self addItem:item withKey:key charIndex:0 scorer:scorer];
}

- (void)addItem:(id)item
        withKey:(NSString*)key
      charIndex:(unsigned int)index
         scorer:(id<TrieScorer>)scorer;
{
  // Don't bother to store at the root node, since "" is an uninteresting query.
  if (index > 0)
    [self storeItem:item withScorer:scorer];

  if (index == [key length])
    return;
  NSRange charRange = [key rangeOfComposedCharacterSequenceAtIndex:index];
  NSString* keyChar = [key substringWithRange:charRange];
  TrieNode* node = [mChildren objectForKey:keyChar];
  if (!node) {
    if (!mChildren)
      mChildren = [[NSMutableDictionary alloc] init];
    node = [TrieNode trieNode];
    [mChildren setObject:node forKey:keyChar];
  }
  [node addItem:item withKey:key charIndex:NSMaxRange(charRange) scorer:scorer];
}

- (void)storeItem:(id)item withScorer:(id<TrieScorer>)scorer
{
  // Note: we explicitly don't do full duplicate detection here, since it is
  // incredibly expensive. We check for dups where it's easy, but it's not
  // intended to be robust; the real checking is done at query time.
  unsigned int index = 0;
  double score = [scorer scoreForItem:item];
  unsigned int maxIndex = [mItems count];
  while (index < maxIndex) {
    unsigned midIndex = (index + maxIndex) / 2;
    id testItem = [mItems objectAtIndex:midIndex];
    double testItemScore = [scorer scoreForItem:testItem];
    if (score < testItemScore)
      index = midIndex + 1;
    else if (item == testItem)  // deliberately a pointer compare; dup check.
      return;
    else
      maxIndex = midIndex;
  }
  [mItems insertObject:item atIndex:index];
}

- (void)removeItem:(id)item
{
  [mItems removeObjectIdenticalTo:item];
  NSEnumerator* childEnumerator = [mChildren objectEnumerator];
  id child;
  while ((child = [childEnumerator nextObject])) {
    [child removeItem:item];
  }
}

- (NSArray*)itemsForKey:(NSString*)key
{
  return [self itemsForKey:key charIndex:0];
}

- (NSArray*)itemsForKey:(NSString*)key charIndex:(unsigned int)index
{
  if (index == [key length])
    return mItems;
  NSRange charRange = [key rangeOfComposedCharacterSequenceAtIndex:index];
  NSString* nextCharacter = [key substringWithRange:charRange];
  TrieNode* node = [mChildren objectForKey:nextCharacter];
  if (!node)
    return [NSArray array];
  return [node itemsForKey:key charIndex:NSMaxRange(charRange)];
}

- (void)printAtDepth:(int)depth {
  NSMutableString* padding = [NSMutableString string];
  for (int i = 0; i < depth; i++) {
    [padding appendString:@" "];
  }
  NSEnumerator* itemEnumerator = [mItems objectEnumerator];
  id item;
  while ((item = [itemEnumerator nextObject])) {
    NSLog(@"%@%@", padding, [item description]);
  }
  depth++;
  NSEnumerator* keyEnumerator = [mChildren keyEnumerator];
  NSString* key;
  while ((key = [keyEnumerator nextObject])) {
    NSLog(@"%@%@:", padding, key);
    id item = [mChildren objectForKey:key];
    [item printAtDepth:depth];
  }
}

@end

#pragma mark -

// Helper class which encapsulates evaluating possible search matches against
// the validation requirements.
@interface TrieQueryItemValidator : NSObject
{
  NSArray*                 mPotentialMatchLists;
  NSArray*                 mMatchTerms;
  id<TrieKeywordGenerator> mKeywordGenerator;
}

// Initializes a validator.
// - |lists| is an array of potential term match lists; an item must be in all
//   of the lists in order to be a match.
// - |terms| is a list of terms that must all appear in the item's list of
//   keywords in order for it to be a match. This should only contain terms
//   for which |lists| is not sufficient to determine a match, since checking
//   an item against |terms| requires generating keywords, thus is expensive.
// - |keywordGenerator| is used to generate keywords if necessary.
// |lists| and |terms| may be empty or nil.
- (id)initWithMatchLists:(NSArray*)lists
                   terms:(NSArray*)terms
        keywordGenerator:(id<TrieKeywordGenerator>)keywordGenerator;

// Returs YES if |item| satisfies this validator.
- (BOOL)matchesItem:(id)item;

@end

@implementation TrieQueryItemValidator

- (id)initWithMatchLists:(NSArray*)lists
                   terms:(NSArray*)terms
        keywordGenerator:(id<TrieKeywordGenerator>)keywordGenerator
{
  if ((self = [super init])) {
    mPotentialMatchLists = [lists retain];
    mMatchTerms = [terms retain];
    mKeywordGenerator = [keywordGenerator retain];
  }
  return self;
}

- (void)dealloc
{
  [mPotentialMatchLists release];
  [mMatchTerms release];
  [mKeywordGenerator release];
  [super dealloc];
}

// Return YES if the given object exists (by pointer equality) in every array
// in |arrays|.
- (BOOL)object:(id)object existsInEveryArray:(NSArray*)arrays
{
  NSEnumerator* arrayEnumerator = [arrays objectEnumerator];
  NSArray* array;
  while ((array = [arrayEnumerator nextObject])) {
    if ([array indexOfObjectIdenticalTo:object] == NSNotFound)
      return NO;
  }
  return YES;
}

// Returns YES if the |item| matches all of the given terms. This is an
// expensive operation, since it requires generating the item's keyword list and
// doing string comparisons.
- (BOOL)item:(id)item matchesTerms:(NSArray*)terms
{
  // If there are no terms to validate against, it trivially matches.
  if ([terms count] == 0)
    return YES;

  NSAutoreleasePool* localPool = [[NSAutoreleasePool alloc] init];
  NSArray* keys = [mKeywordGenerator keywordsForItem:item];
  NSEnumerator* termEnumerator = [terms objectEnumerator];
  NSString* term;
  BOOL matches = YES;
  while ((term = [termEnumerator nextObject])) {
    if (![keys containsStringWithPrefix:term]) {
      matches = NO;
      break;
    }
  }
  [localPool release];
  return matches;
}

- (BOOL)matchesItem:(id)item
{
  // Make sure |item| appears in all potential match lists (which is relatively
  // cheap), and if so that it actually matches every term (which is expensive).
  return [self object:item existsInEveryArray:mPotentialMatchLists] &&
         [self item:item matchesTerms:mMatchTerms];
}

@end

#pragma mark -

@interface Trie (Private)

// Returns everything from the trie for the given term, without doing any
// extra filtering. That means that for terms longer than mMaxDepth,
// not all of the returned items are necessarily matches. May return duplicates.
- (NSArray*)potentialMatchesForTerm:(NSString*)term;

// Returns a list of the potential matches for each term. See
// potentialMatchesForTerm: for details.
- (NSMutableArray*)potentialMatchListsForTerms:(NSArray*)terms;

// Returns YES if the query results for |newTerms| will be a subset of the
// possible results for the cached query.
- (BOOL)isQueryRefinementOfCachedQuery:(NSArray*)newTerms;

// Iterates through |candidates|, starting at |startIndex|, and adds items that
// satisfy |validator| to |matches|, until |matches| contains |limit| items.
// If |limit| is 0, it will be treated as no limit.
// Returns the last index in |candidates| that was checked for matching. Returns
// NSNotFound if no items were checked during this call (e.g., because the match
// list was already full, or the start index was past the end of |canditates|).
- (unsigned int)fillMatchList:(NSMutableArray*)matches
                      toLimit:(unsigned int)limit
            withItemsFromList:(NSArray*)candidates
                    fromIndex:(unsigned int)startIndex
            matchingValidator:(TrieQueryItemValidator*)validator;

// Clears the cached query state. Must be called any time the trie changes.
- (void)invalidateCachedQuery;

// Stores the given query state for potential use in speeding up the next query.
- (void)cacheQueryResults:(NSArray*)matches
               candidates:(NSArray*)candidates
                lastIndex:(unsigned int)lastIndex
                 forTerms:(NSArray*)terms;

// Returns a term array with any whitespace trimmed, and empty terms discarded.
- (NSArray*)cleanedTerms:(NSArray*)terms;

// Returns the terms from |terms| that will need extended match validation
// because potentialMatchesForTerm: won't give a definitive answer
// (i.e., those that have more characters than mMaxDepth).
- (NSArray*)termsNeedingExtendedValidation:(NSArray*)terms;

// Returns YES if the term is longer than mMaxDepth.
- (BOOL)termExceedsTrieDepth:(NSString*)term;

@end


@implementation Trie

- (id)initWithKeywordGenerator:(id<TrieKeywordGenerator>)keywordGenerator
                        scorer:(id<TrieScorer>)scorer
                      maxDepth:(unsigned int)maxDepth
{
  if ((self = [super init])) {
    mRoot = [[TrieNode alloc] init];
    mScorer = [scorer retain];
    mKeywordGenerator = [keywordGenerator retain];
    mMaxDepth = maxDepth;
  }
  return self;
}

- (void)dealloc
{
  [self invalidateCachedQuery];
  [mRoot release];
  [mScorer release];
  [mKeywordGenerator release];
  [super dealloc];
}

- (void)addItem:(id)item
{
  [self invalidateCachedQuery];

  NSArray* keys = [mKeywordGenerator keywordsForItem:item];
  NSEnumerator* keyEnumerator = [keys objectEnumerator];
  NSString* key;
  while ((key = [keyEnumerator nextObject])) {
    if ([key length] == 0)
      continue;
    key = [key prefixWithCharacterCount:mMaxDepth];
    [mRoot addItem:item withKey:key scorer:mScorer];
  }
}

- (void)removeItem:(id)item
{
  [self invalidateCachedQuery];

  [mRoot removeItem:item];
}

- (void)removeAllItems
{
  [self invalidateCachedQuery];

  [mRoot release];
  mRoot = [[TrieNode alloc] init];
}

- (NSMutableArray*)potentialMatchListsForTerms:(NSArray*)terms
{
  NSMutableArray* potentialMatchLists =
      [NSMutableArray arrayWithCapacity:[terms count]];
  NSEnumerator* termEnumerator = [terms objectEnumerator];
  NSString* term;
  while ((term = [termEnumerator nextObject])) {
    [potentialMatchLists addObject:[self potentialMatchesForTerm:term]];
  }
  return potentialMatchLists;
}

- (NSArray*)potentialMatchesForTerm:(NSString*)term
{
  NSString* prefix = [term prefixWithCharacterCount:mMaxDepth];
  return [mRoot itemsForKey:prefix];
}

- (NSArray*)itemsForTerms:(NSArray*)terms withLimit:(unsigned int)limit
{
  NSArray* cleanTerms = [self cleanedTerms:terms];
  if (![cleanTerms count])
    return [NSArray array];

  // First, get all the potential matches by term. This only requires Trie
  // lookups, so it's inexpensive.
  NSMutableArray* potentialMatchLists =
      [self potentialMatchListsForTerms:cleanTerms];

  // Use the first list (arbitrarily) as a canditate list to walk looking for
  // actual matches, and use the others in the validator to do fast first pass
  // check of potential matches.
  NSArray* candidateList = [[[potentialMatchLists firstObject] retain] autorelease];
  [potentialMatchLists removeObjectAtIndex:0];

  // Create a validator for the query.
  NSArray* termsNeedingValidation = [self termsNeedingExtendedValidation:cleanTerms];
  TrieQueryItemValidator* validator =
      [[[TrieQueryItemValidator alloc]
          initWithMatchLists:potentialMatchLists
                       terms:termsNeedingValidation
            keywordGenerator:mKeywordGenerator] autorelease];

  NSMutableArray* matches = [NSMutableArray arrayWithCapacity:limit];
  unsigned int startIndex = 0;
  BOOL isRefinement = [self isQueryRefinementOfCachedQuery:cleanTerms];
  if (isRefinement) {
    // If the candidate list is the same as the last query, revalidate the
    // matches and then pick up where the last query left off.
    if (candidateList == mPreviousCandidateList) {
      startIndex = mLastCheckedCandidateIndex + 1;
      [self fillMatchList:matches
                  toLimit:limit
        withItemsFromList:mPreviousMatches
                fromIndex:0
        matchingValidator:validator];
    }
  }

  unsigned int lastCheckedIndex = [self fillMatchList:matches
                                              toLimit:limit
                                    withItemsFromList:candidateList
                                            fromIndex:startIndex
                                    matchingValidator:validator];

  // If nothing was checked during the search, then the cached query state
  // doesn't need to be updated (and shouldn't be, otherwise repeating a search
  // with a lower limit would destroy useful cache data).
  if (lastCheckedIndex != NSNotFound) {
    [self cacheQueryResults:matches
                 candidates:candidateList
                  lastIndex:lastCheckedIndex
                   forTerms:cleanTerms];
  }

  return matches;
}

- (BOOL)isQueryRefinementOfCachedQuery:(NSArray*)newTerms
{
  if (!mPreviousQueryTerms)
    return NO;
  if ([newTerms count] < [mPreviousQueryTerms count])
    return NO;
  for (unsigned int i = 0; i < [mPreviousQueryTerms count]; ++i) {
    if (![[newTerms objectAtIndex:i] hasPrefix:[mPreviousQueryTerms objectAtIndex:i]])
      return NO;
  }
  return YES;
}

- (unsigned int)fillMatchList:(NSMutableArray*)matches
                      toLimit:(unsigned int)limit
            withItemsFromList:(NSArray*)candidates
                    fromIndex:(unsigned int)startIndex
            matchingValidator:(TrieQueryItemValidator*)validator
{
  if ((limit && [matches count] >= limit) || startIndex >= [candidates count])
    return NSNotFound;

  // Walk the candidate list to find actual matches, eliminating duplicates.
  unsigned int candidateCount = [candidates count];
  unsigned int i = startIndex;
  for (; i < candidateCount; ++i) {
    id item = [candidates objectAtIndex:i];
    if ([matches indexOfObjectIdenticalTo:item] != NSNotFound)
      continue;
    if (![validator matchesItem:item])
      continue;

    [matches addObject:item];
    if (limit && [matches count] >= limit)
      break;
  }
  return i;
}

- (void)invalidateCachedQuery
{
  [mPreviousQueryTerms release];
  mPreviousQueryTerms = nil;
  [mPreviousCandidateList release];
  mPreviousCandidateList = nil;
  [mPreviousMatches release];
  mPreviousMatches = nil;
}

- (void)cacheQueryResults:(NSArray*)matches
               candidates:(NSArray*)candidates
                lastIndex:(unsigned int)lastIndex
                 forTerms:(NSArray*)terms
{
  [self invalidateCachedQuery];
  mPreviousMatches = [matches copy];
  mPreviousQueryTerms = [terms copy];
  // Retain, rather than copy, because we control this list and will invalidate
  // mPreviousCandidateList if it changes, so there's no need for an extra copy.
  mPreviousCandidateList = [candidates retain];
  mLastCheckedCandidateIndex = lastIndex;
}

- (NSArray*)cleanedTerms:(NSArray*)terms
{
  NSMutableArray* cleanTerms = [NSMutableArray arrayWithCapacity:[terms count]];
  NSEnumerator* termEnumerator = [terms objectEnumerator];
  NSString* term;
  while ((term = [termEnumerator nextObject])) {
    NSString* trimmedTerm = [term stringByTrimmingWhitespace];
    if ([trimmedTerm length])
      [cleanTerms addObject:trimmedTerm];
  }
  return cleanTerms;
}

- (NSArray*)termsNeedingExtendedValidation:(NSArray*)terms
{
  NSMutableArray* longTerms = [NSMutableArray array];
  NSEnumerator* termEnumerator = [terms objectEnumerator];
  NSString* term;
  while ((term = [termEnumerator nextObject])) {
    if ([self termExceedsTrieDepth:term])
      [longTerms addObject:term];
  }
  return longTerms;
}

- (BOOL)termExceedsTrieDepth:(NSString*)term
{
  if ([term length] < mMaxDepth)
    return NO;

  NSRange charRange = NSMakeRange(0, 0);
  for (unsigned int i = 0; NSMaxRange(charRange) < [term length]; ++i) {
    if (i == mMaxDepth)
      return YES;
    charRange = [term rangeOfComposedCharacterSequenceAtIndex:NSMaxRange(charRange)];
  }
  return NO;
}

- (void)print {
  [mRoot printAtDepth:0];
}

@end
