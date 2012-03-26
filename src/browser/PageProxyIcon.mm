/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*-
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "PageProxyIcon.h"

#import "NSImage+Utils.h"
#import "NSString+Utils.h"
#import "NSPasteboard+Utils.h"
#import "BrowserWindowController.h"

#include "nsCRT.h"
#include "nsNetUtil.h"
#include "nsString.h"

@implementation PageProxyIcon

- (void)awakeFromNib
{
}

- (void)dealloc
{
  [super dealloc];
}

- (BOOL)acceptsFirstResponder
{
  return NO;
}

- (void) resetCursorRects
{
  // XXX provide image for drag-hand cursor
  NSCursor* cursor = [NSCursor arrowCursor];
  [self addCursorRect:NSMakeRect(0,0,[self frame].size.width,[self frame].size.height) cursor:cursor];
  [cursor setOnMouseEntered:YES];
}

- (unsigned int)draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
  if (isLocal)
    return NSDragOperationGeneric;

  return (NSDragOperationLink | NSDragOperationCopy);
}

- (void)mouseDown:(NSEvent *)theEvent
{
  // need to implement this or else mouseDragged isn't called
}

- (void)mouseUp:(NSEvent *)theEvent
{
  // select the url bar text
  [[[self window] windowController] focusURLBar];
}

- (void) mouseDragged: (NSEvent*) event
{
  NSString*		urlString = nil;
  NSString*		titleString = nil;

  id parentWindowController = [[self window] windowController];
  if ([parentWindowController isKindOfClass:[BrowserWindowController class]]) {
    BrowserWrapper* browserWrapper = [(BrowserWindowController*)parentWindowController browserWrapper];
    urlString = [browserWrapper currentURI];
    titleString = [browserWrapper pageTitle];
  }

  // don't allow dragging of proxy icon for empty pages
  if ((!urlString) || [urlString isBlankURL])
    return;

  NSString     *cleanedTitle = [titleString stringByReplacingCharactersInSet:[NSCharacterSet controlCharacterSet] withString:@" "];

  NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSDragPboard];

  [pboard declareURLPasteboardWithAdditionalTypes:[NSArray array] owner:self];
  [pboard setDataForURL:urlString title:cleanedTitle];

  [self dragImage:[NSImage dragImageWithIcon:[self image] title:titleString]
               at:NSMakePoint(0,0)
           offset:NSMakeSize(0,0)
            event:event
       pasteboard:pboard
           source:self
        slideBack:YES];
}

@end
