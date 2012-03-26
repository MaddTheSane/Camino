/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "NSDate+Utils.h"

@implementation NSDate(ChimeraDateUtils)

+ (id)dateWithPRTime:(PRTime)microseconds
{
  // assume we have 64-bit math
  return [NSDate dateWithTimeIntervalSince1970:(double)(microseconds / 1000000LL)];
}

@end
