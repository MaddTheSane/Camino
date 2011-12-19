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
 * Stuart Morgan
 * Portions created by the Initial Developer are Copyright (C) 2011
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
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

#import "AutoCompleteScorer.h"

#include <sys/time.h>

#import "Bookmark.h"
#import "HistoryItem.h"

// Bookmarks are given slightly higher score; all else being equal a bookmark
// is more likely to be relevant since the user has explicitly expressed
// interest in it. The boost shouldn't be too high, however, or bookmarks
// will drown out commonly visited sites.
static const double kBookmarkScoreMultiplier = 1.1;

// Items that haven't been visited recently are much less likely to be relevant
// even if they used to be visited frequently.
static const double kOlderThanAYearScoreMultiplier = 0.01;
static const double kOlderThanSixMonthsScoreMultiplier = 0.1;
static const double kOlderThanAMonthScoreMultiplier = 0.5;
static const double kOlderThanAWeekScoreMultiplier = 0.9;

static const NSTimeInterval kSecondsInAWeek = 60 * 60 * 24 * 7;
static const NSTimeInterval kSecondsInAMonth = 60 * 60 * 24 * 30;
static const NSTimeInterval kSecondsInSixMonths = 60 * 60 * 24 * 182;
static const NSTimeInterval kSecondsInAYear = 60 * 60 * 24 * 365;

// Returns the relevance portion of the score for the given item.
static unsigned int RelevanceScoreForItem(id item,
                                          NSTimeInterval secondsSinceLastVisit)
{
  unsigned int visitCount = [item visitCount];
  double score = sqrt(visitCount);

  if (secondsSinceLastVisit > kSecondsInAYear)
    score *= kOlderThanAYearScoreMultiplier;
  else if (secondsSinceLastVisit > kSecondsInSixMonths)
    score *= kOlderThanSixMonthsScoreMultiplier;
  else if (secondsSinceLastVisit > kSecondsInAMonth)
    score *= kOlderThanAMonthScoreMultiplier;
  else if (secondsSinceLastVisit > kSecondsInAWeek)
    score *= kOlderThanAWeekScoreMultiplier;

  // For sufficiently old results, cap the relevance.
  if (secondsSinceLastVisit > kSecondsInSixMonths && score > 1.0)
    score = 1.0;

  if ([item isKindOfClass:[Bookmark class]])
    score *= kBookmarkScoreMultiplier;

  // Multiply by ten before truncating, to keep tenths of a point.
  return (unsigned int)(score * 10);
}

// Returns the recency portion of the score for the given item, as a a number
// between 0 and 1; the higher the number, the more recent the last visit.
// Returns 0 if the item has never been visited.
// |lastVisitInSeconds| is the number of seconds since 1970.
static double RecencyScoreForLastVisit(NSTimeInterval lastVisitInSeconds)
{
  // A number to divide seconds since 1970 by to get a number between 0 and 1.
  // This was chosen to be large enough that the result of the division will
  // never hit 1 (it's in 2128) but not so large that it will just be lost in
  // rounding error once it's added to the integer score.
  const double kMaxSeconds = 5000000000.0;
  return lastVisitInSeconds / kMaxSeconds;
}

@interface AutoCompleteScorer (Private)
// Returns the number of seconds since 1970, using the cached value if there
// is one.
- (NSTimeInterval)secondsSince1970;
@end

@implementation AutoCompleteScorer

// TODO: Make a protocol or base class for "persistent site references", and
// have both history and bookmarks implement/use that, to avoid having to know
// about specific classes here.
- (double)scoreForItem:(id)item
{
  // Compute the necessary time values. While it would be cleaner for these
  // computations to be done in the scoring helper methods, this function is
  // called so often during trie construction that optimization is important.
  NSTimeInterval lastVisitInSeconds = [[item lastVisit] timeIntervalSince1970];
  NSTimeInterval secondsSinceLastVisit =
      [self secondsSince1970] - lastVisitInSeconds;
  // The score is made up of two parts; the integer part is the relevance score,
  // and the fractional part is used to break relevance ties in favor of more
  // recently visited items.
  return RelevanceScoreForItem(item, secondsSinceLastVisit) +
         RecencyScoreForLastVisit(lastVisitInSeconds);
}

- (NSTimeInterval)secondsSince1970
{
  if (mCachedCurrentTime > 0)
    return mCachedCurrentTime;
  // Call gettimeofday directly, since higher-level constructs are slower.
  struct timeval time;
  gettimeofday(&time, NULL);
  return time.tv_sec;
}

- (void)cacheCurrentTime
{
  [self clearTimeCache];
  mCachedCurrentTime = [self secondsSince1970];
}

- (void)clearTimeCache
{
  mCachedCurrentTime = 0;
}

@end
