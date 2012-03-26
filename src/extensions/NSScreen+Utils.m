/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */


#import "NSScreen+Utils.h"


@implementation NSScreen (CHScreenAdditions)

+ (NSScreen*)screenForPoint:(NSPoint)point
{
	NSArray* screens = [NSScreen screens];
	NSEnumerator* screenEnum = [screens objectEnumerator];
	NSScreen* screen;
	
	while ( (screen = [screenEnum nextObject]) ) {
		NSRect frame = [screen frame];
		if (NSPointInRect(point, frame))
			break;
	}
	
	return screen;
}

@end
