/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>

#import "BreakpadWrapper.h"

static void SetupRuntimeOptions(int argc, const char *argv[])
{
  if (getenv("MOZ_UNBUFFERED_STDIO")) {
    printf("stdout and stderr unbuffered\n");
    setbuf(stdout, 0);
    setbuf(stderr, 0);
  }
}

int main(int argc, const char *argv[])
{
  BreakpadWrapper* breakpad = nil;
  NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
  NSDictionary* info = [[NSBundle mainBundle] infoDictionary];
  if ([[info valueForKey:@"BreakpadURL"] length] > 0) {
    breakpad = [[BreakpadWrapper alloc] init];
  }
  [pool release];

  SetupRuntimeOptions(argc, argv);

  int rv = NSApplicationMain(argc, argv);

  [breakpad release];

  return rv;
}
