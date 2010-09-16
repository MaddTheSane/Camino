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

// Adds an item to the trie with the given keyword. |sortOrder| is used to order
// the list of items at the given node; it should always be the same for every
// node in a trie.
// This is intended to be called on the root node only.
- (void)addItem:(id)item
        withKey:(NSString*)key
      sortOrder:(NSSortDescriptor*)sortOrder;

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

// Helper for addItem:withKey:sortOrder:; stores the item in the child node
// corresponding to the character at |index| in |key|, then recurses.
- (void)addItem:(id)item
        withKey:(NSString*)key
      charIndex:(unsigned int)index
      sortOrder:(NSSortDescriptor*)sortOrder;

// Stores the given item in this node's item list at the position indicated by
// sortOrder.
- (void)storeItem:(id)item withSortOrder:(NSSortDescriptor*)sortOrder;

// Helper for itemsForKey:; if |index| is the end of |key|, returns the item
// array, otherwise recurses.
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
      sortOrder:(NSSortDescriptor*)sortOrder;
{
  [self addItem:item withKey:key charIndex:0 sortOrder:sortOrder];
}

- (void)addItem:(id)item
        withKey:(NSString*)key
      charIndex:(unsigned int)index
      sortOrder:(NSSortDescriptor*)sortOrder;
{
  // Don't bother to store at the root node, since "" is an uninteresting query.
  if (index > 0)
    [self storeItem:item withSortOrder:sortOrder];

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
  [node addItem:item withKey:key charIndex:NSMaxRange(charRange) sortOrder:sortOrder];
}

- (void)storeItem:(id)item withSortOrder:(NSSortDescriptor*)sortOrder
{
  if ([mItems indexOfObjectIdenticalTo:item] != NSNotFound)
    return;
  unsigned index = 0;
  unsigned maxIndex = [mItems count];
  while (index < maxIndex) {
    unsigned midIndex = (index + maxIndex) / 2;
    id testItem = [mItems objectAtIndex:midIndex];
    if ([sortOrder compareObject:item toObject:testItem] == NSOrderedDescending)
      index = midIndex + 1;
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
  while((item = [itemEnumerator nextObject])) {
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

@interface Trie (Private)

// Returns everything from the trie for the given term, without doing any
// extra filtering. That means that for terms longer than mMaxDepth,
// not all of the returned items are necessarily matches.
- (NSArray*)potentialMatchesForTerm:(NSString*)term;

// Returns a list of the potential matches for each term. See
// potentialMatchesForTerm: for details.
- (NSMutableArray*)potentialMatchListsForTerms:(NSArray*)term;

// Returns a term array with any whitespace trimmed, and empty terms discarded.
- (NSArray*)cleanedTerms:(NSArray*)terms;

// Returns the terms from |terms| that will need extended match validation
// (i.e., have more characters than mMaxDepth).
- (NSArray*)termsNeedingExtendedValidation:(NSArray*)terms;

// Return YES if the given object exists (by pointer equality) in every array
// in |arrays|.
- (BOOL)object:(id)object existsInEveryArray:(NSArray*)arrays;

// Returns YES if the given item matches all of the given terms. This is an
// expensive operation, since it requires generating the item's keyword list and
// doing string comparisons.
- (BOOL)item:(id)item matchesTerms:(NSArray*)terms;

// Returns YES if the term is longer than mMaxDepth.
- (BOOL)termExceedsTrieDepth:(NSString*)term;

@end


@implementation Trie

- (id)initWithKeywordDelegate:(id<TrieKeywordGenerationDelegate>)delegate
                    sortOrder:(NSSortDescriptor*)sortOrder
                     maxDepth:(unsigned int)maxDepth
{
  if ((self = [super init])) {
    mRoot = [[TrieNode alloc] init];
    mSortOrder = [sortOrder retain];
    mDelegate = delegate;
    mMaxDepth = maxDepth;
  }
  return self;
}

- (void)dealloc
{
  [mRoot release];
  [mSortOrder release];
  [super dealloc];
}

- (void)addItem:(id)item
{
  NSArray* keys = [mDelegate keywordsForObject:item];
  NSEnumerator* keyEnumerator = [keys objectEnumerator];
  NSString* key;
  while ((key = [keyEnumerator nextObject])) {
    if ([key length] == 0)
      continue;
    key = [key prefixWithCharacterCount:mMaxDepth];
    [mRoot addItem:item withKey:key sortOrder:mSortOrder];
  }
}

- (void)removeItem:(id)item
{
  [mRoot removeItem:item];
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

  // Find the terms that will require more validation than just checking to
  // see if the item was found in the Trie.
  NSArray* termsRequiringValidation = [self termsNeedingExtendedValidation:cleanTerms];

  // Now walk one of the lists--the first is chosen arbitrarily--to find actual
  // matches, by first making sure an item appears in every potential match list
  // (which is relatively cheap), and if so that it actually matches every
  // search term (which is expensive).
  NSArray* candidateList = [[[potentialMatchLists firstObject] retain] autorelease];
  [potentialMatchLists removeObjectAtIndex:0];
  NSMutableArray* matchingItems = [NSMutableArray arrayWithCapacity:limit];
  NSEnumerator* candidateEnumerator = [candidateList objectEnumerator];
  id item;
  while ((item = [candidateEnumerator nextObject])) {
    if (([potentialMatchLists count] > 0 &&
         ![self object:item existsInEveryArray:potentialMatchLists]) ||
        ([termsRequiringValidation count] > 0 &&
         ![self item:item matchesTerms:termsRequiringValidation]))
    {
      continue;
    }

    [matchingItems addObject:item];
    if (limit && [matchingItems count] == limit)
      break;
  }
  return matchingItems;
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

- (BOOL)item:(id)item matchesTerms:(NSArray*)terms
{
  NSAutoreleasePool* localPool = [[NSAutoreleasePool alloc] init];
  NSArray* keys = [mDelegate keywordsForObject:item];
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
