/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */


#include <Foundation/Foundation.h>

class StAutoreleasePool
{
public:
  StAutoreleasePool()
  {
    mPool = [[NSAutoreleasePool alloc] init];
  }
  
  ~StAutoreleasePool()
  {
    [mPool release];
  }

protected:

  NSAutoreleasePool*    mPool;
};


// handy utility class for timing actions
class StActionTimer
{
public:

  StActionTimer(NSString* inActionName)
  : mActionName(inActionName)
  {
    Microseconds(&mStartTime);
  }

  ~StActionTimer()
  {
    UnsignedWide endTime;
    Microseconds(&endTime);

    long long actionTime = UnsignedWideToUInt64(endTime) - UnsignedWideToUInt64(mStartTime);
    NSLog(@"%@ took %qi us", mActionName, actionTime); 
  }

protected:
  UnsignedWide    mStartTime;
  NSString*       mActionName;
};
