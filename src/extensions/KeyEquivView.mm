/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "KeyEquivView.h"

@implementation KeyEquivView

+ (KeyEquivView*)kevWithKeyEquivalent:(NSString*)keyEquivalent
            keyEquivalentModifierMask:(unsigned int)keyEquivalentModifierMask
                               target:(id)target
                               action:(SEL)action {
  return [[[KeyEquivView alloc] initWithKeyEquivalent:keyEquivalent
                            keyEquivalentModifierMask:keyEquivalentModifierMask
                                               target:target 
                                               action:action] autorelease];
}

- (id)initWithKeyEquivalent:(NSString*)keyEquivalent
  keyEquivalentModifierMask:(unsigned int)keyEquivalentModifierMask
                     target:(id)target
                     action:(SEL)action {
  if ((self = [super initWithFrame:NSMakeRect(0, 0, 0, 0)])) {
    mKeyEquivalent = [keyEquivalent retain];
    mKeyEquivalentModifierMask = keyEquivalentModifierMask;
    mTarget = target;
    mAction = action;
  }
  return self;
}

- (void)dealloc {
  [mKeyEquivalent release];
  [super dealloc];
}

- (NSString*)keyEquivalent {
  return mKeyEquivalent;
}

- (void)setKeyEquivalent:(NSString*)keyEquivalent {
  [mKeyEquivalent release];
  mKeyEquivalent = keyEquivalent;
}

- (unsigned int)keyEquivalentModifierMask {
  return mKeyEquivalentModifierMask;
}

- (void)setKeyEquivalentModifierMask:(unsigned int)keyEquivalentModifierMask {
  mKeyEquivalentModifierMask = keyEquivalentModifierMask;
}

- (id)target {
  return mTarget;
}

- (void)setTarget:(id)target {
  mTarget = target;
}

- (SEL)action {
  return mAction;
}

- (void)setAction:(SEL)action {
  mAction = action;
}

- (BOOL)performKeyEquivalent:(NSEvent *)event {
  BOOL performed = [super performKeyEquivalent:event];

  if (!performed) {
    NSString* character = [event charactersIgnoringModifiers];
    unsigned int modifier = [event modifierFlags];

    if ((modifier & NSDeviceIndependentModifierFlagsMask) == mKeyEquivalentModifierMask &&
        [character isEqualToString:mKeyEquivalent]) {
        [mTarget performSelector:mAction withObject:self];
      performed = YES;
    }
  }

  return performed;
}

@end
