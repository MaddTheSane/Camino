/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "PopupMenuButton.h"


NSString* const kPopupMenuButtonWillDisplayMenuNotification = @"PopupMenuButtonWillDisplayMenu";


@implementation PopupMenuButton

- (id) initWithCoder:(NSCoder *)coder
{
	if ((self = [super initWithCoder:coder]))
  {
  }
  return self;
}

- (void)keyDown:(NSEvent *)event
{
  unichar showMenuChars[] = {
        0x0020,               // space character
        NSUpArrowFunctionKey,
        NSDownArrowFunctionKey
  };
  
  NSString* showMenuString = [NSString stringWithCharacters:showMenuChars length:sizeof(showMenuChars) / sizeof(unichar)];
  NSCharacterSet *showMenuCharset = [NSCharacterSet characterSetWithCharactersInString:showMenuString];
  
  if ([[event characters] rangeOfCharacterFromSet:showMenuCharset].location == NSNotFound)
  {
    [super keyDown:event];
    return;
  }

  if (![self isEnabled])
    return;

  [[NSNotificationCenter defaultCenter] postNotificationName:kPopupMenuButtonWillDisplayMenuNotification object:self];

  NSPoint menuLocation = NSMakePoint(0, NSHeight([self frame]) + 4.0);
  // convert to window coords
  menuLocation = [self convertPoint:menuLocation toView:nil];
  
  NSEvent *newEvent = [NSEvent mouseEventWithType:NSLeftMouseDown
                     location: menuLocation
                modifierFlags: [event modifierFlags]
                    timestamp: [event timestamp]
                 windowNumber: [event windowNumber]
                      context: [event context]
                  eventNumber: 0
                   clickCount: 1
                     pressure: 1.0];

  
  [[self cell] setHighlighted:YES];
  [NSMenu popUpContextMenu:[self menu] withEvent:newEvent forView:self];
  [[self cell] setHighlighted:NO];
}

- (NSMenu *)menuForEvent:(NSEvent *)theEvent
{
  // the menu should only show when we explicitly show it (not for events like right-click)
  return nil;
}

- (void)mouseDown:(NSEvent *)event
{
  if (![self isEnabled])
    return;

  [[NSNotificationCenter defaultCenter] postNotificationName:kPopupMenuButtonWillDisplayMenuNotification object:self];

  NSPoint menuLocation = NSMakePoint(0, NSHeight([self frame]) + 4.0);
  // convert to window coords
  menuLocation = [self convertPoint:menuLocation toView:nil];

  NSEvent *newEvent = [NSEvent mouseEventWithType: [event type]
                     location: menuLocation
                modifierFlags: [event modifierFlags]
                    timestamp: [event timestamp]
                 windowNumber: [event windowNumber]
                      context: [event context]
                  eventNumber: [event eventNumber]
                   clickCount: [event clickCount]
                     pressure: [event pressure]];

  [[self cell] setHighlighted:YES];
  [NSMenu popUpContextMenu:[self menu] withEvent:newEvent forView:self];
  [[self cell] setHighlighted:NO];
}

@end
