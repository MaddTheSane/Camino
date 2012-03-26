/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#ifndef KeyEquivView_h__
#define KeyEquivView_h__

#import <Cocoa/Cocoa.h>

@interface KeyEquivView : NSView
{
  NSString* mKeyEquivalent;
  unsigned int mKeyEquivalentModifierMask;
  id mTarget;  // weak
  SEL mAction;
}

// Convenience
+ (KeyEquivView*)kevWithKeyEquivalent:(NSString*)keyEquivalent
            keyEquivalentModifierMask:(unsigned int)keyEquivalentModifierMask
                               target:(id)target
                               action:(SEL)action;

// Constructors and destructors
- (id)initWithKeyEquivalent:(NSString*)keyEquivalent
  keyEquivalentModifierMask:(unsigned int)keyEquivalentModifierMask
                     target:(id)target
                     action:(SEL)action;
- (void)dealloc;

// Accessors and mutators
- (NSString*)keyEquivalent;
- (void)setKeyEquivalent:(NSString*)keyEquivalent;
- (unsigned int)keyEquivalentModifierMask;
- (void)setKeyEquivalentModifierMask:(unsigned int)keyEquivalentModifierMask;
- (id)target;
- (void)setTarget:(id)target;
- (SEL)action;
- (void)setAction:(SEL)action;

// Action
//
// performKeyEquivalent: first calls the superclass' performKeyEquivalent:
// selector, to try to pass the event to any view descendants, although it
// would be pretty weird to add descendants to this view.
//
// If no descendants handle the event, the event's keypress and modifier mask
// will be compared to the stored key equivalent character and modifiers.  If
// they match, [target action:self] will be invoked.
//
// If performKeyEquivalent: is able to find anything to process the event,
// either via the superclass or by invoking the stored object's selector,
// it returns YES.  If nothing handles the event, returns NO.
- (BOOL)performKeyEquivalent:(NSEvent*)event;

@end

#endif  // KeyEquivView_h__
