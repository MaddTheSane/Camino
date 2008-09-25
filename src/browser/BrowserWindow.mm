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
 * The Original Code is Chimera code.
 *
 * The Initial Developer of the Original Code is
 * Netscape Communications Corporation.
 * Portions created by the Initial Developer are Copyright (C) 2002
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *   Simon Fraser <sfraser@netscape.com>
 *   Nate Weaver (Wevah) <wevah@derailer.org>
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

#import "mozView.h"
#import "NSWorkspace+Utils.h"

#import "BrowserWindow.h"
#import "BrowserWindowController.h"
#import "MainController.h"
#import "AutoCompleteTextField.h"

static const int kEscapeKeyCode = 53;

@implementation BrowserWindow

- (void)dealloc
{
  [super dealloc];
}

- (BOOL)makeFirstResponder:(NSResponder*)responder
{
  NSResponder* oldResponder = [self firstResponder];
  BOOL madeFirstResponder = [super makeFirstResponder:responder];
  if (madeFirstResponder && oldResponder != [self firstResponder])
    [(BrowserWindowController*)[self delegate] focusChangedFrom:oldResponder to:[self firstResponder]];

  //NSLog(@"Old FR %@, new FR %@, responder %@, made %d", oldResponder, [self firstResponder], responder, madeFirstResponder);
  return madeFirstResponder;
}

// The opposite of makeKeyAndOrderFront; used to support window.blur()
- (void)resignKeyAndOrderBack
{
  NSArray *browserWindows = [(MainController*)[NSApp delegate] browserWindows];
  if ([browserWindows count] > 1) {
    // If we are key we need to pass key status to the window that will become
    // frontmost, but if we aren't then don't mess with the key status.
    if ([self isKeyWindow])
      [(NSWindow*)[browserWindows objectAtIndex:1] makeKeyAndOrderFront:nil];
    [self orderWindow:NSWindowBelow relativeTo:[[browserWindows lastObject] windowNumber]];
  }
}

// this gets called when the user hits the Escape key
- (void)cancel:(id)sender
{
  [(BrowserWindowController*)[self delegate] stop:nil];
}

- (BOOL)suppressMakeKeyFront
{
  return mSuppressMakeKeyFront;
}

- (void)setSuppressMakeKeyFront:(BOOL)inSuppress
{
	mSuppressMakeKeyFront = inSuppress;
}

- (void)becomeMainWindow
{
  [super becomeMainWindow];
  // There appears to be a bug on 10.4 where mouse moves don't get reactivated
  // when showing the application after it has been hidden. Furthermore,
  // we seem to have to do this after a delay (perhaps because we're not
  // actually the main window yet).
  [self performSelector:@selector(delayedTurnOnMouseMoves) withObject:nil afterDelay:0];
}

- (void)delayedTurnOnMouseMoves
{
  [self setAcceptsMouseMovedEvents:YES];
}

// Pass command-return off to the controller so that locations/searches may be opened in a new tab.
// Pass command-plus off to the controller to enlarge the text size.
// Pass command-1..9 to the controller to load that bookmark bar item
// Pass command-D off to the controller to add a bookmark
- (BOOL)performKeyEquivalent:(NSEvent *)theEvent
{
  BrowserWindowController* windowController = (BrowserWindowController*)[self delegate];
  NSString* keyString = [theEvent charactersIgnoringModifiers];
  if ([keyString length] < 1)
    return NO;
  unichar keyChar = [keyString characterAtIndex:0];
  unsigned int standardModifierKeys = NSShiftKeyMask | NSControlKeyMask | NSAlternateKeyMask | NSCommandKeyMask;

  BOOL handled = NO;
  if (keyChar == NSCarriageReturnCharacter) {
    BOOL shiftKeyIsDown = (([theEvent modifierFlags] & NSShiftKeyMask) != 0);
    handled = [windowController handleCommandReturn:shiftKeyIsDown];
  } else if (keyChar == '+') {
    if (([theEvent modifierFlags] & NSCommandKeyMask) != 0) {
      // If someone assigns this shortcut to a menu, we want that to win.
      if ([[NSApp mainMenu] performKeyEquivalent:theEvent])
        return YES;

      if ([theEvent modifierFlags] & NSAlternateKeyMask) {
        if ([windowController canMakeTextBigger])
          [windowController makeTextBigger:nil];
        else
          NSBeep();
      }
      else {
        if ([windowController canMakePageBigger])
          [windowController makePageBigger:nil];
        else
          NSBeep();
      }
      handled = YES;
    }
  } else if (keyChar >= '1' && keyChar <= '9') {
    if (([theEvent modifierFlags] & standardModifierKeys) == NSCommandKeyMask) {
      // If someone assigns one of these shortcuts to a menu, we want that to win.
      if ([[NSApp mainMenu] performKeyEquivalent:theEvent])
        return YES;

      // use |forceReuse| to disable looking at the modifier keys since we know the command
      // key is down right now.
      handled = [windowController loadBookmarkBarIndex:(keyChar - '1') openBehavior:eBookmarkOpenBehavior_ForceReuse];
    }
  }
  //Alpha shortcuts need to be handled differently because layouts like Dvorak-Qwerty Command give
  //completely different characters depending on whether or not you ignore the modifiers
  else {
    keyString = [theEvent characters];
    if ([keyString length] < 1)
      return NO;    
    keyChar = [keyString characterAtIndex:0];
    if (keyChar == 'd') {
      if ((([theEvent modifierFlags] & standardModifierKeys) == NSCommandKeyMask) &&
          [windowController validateActionBySelector:@selector(addBookmark:)])
      {
        // If someone assigns this shortcuts to a menu, we want that to win.
        if ([[NSApp mainMenu] performKeyEquivalent:theEvent])
          return YES;

        [windowController addBookmark:nil];
        handled = YES;
      }
    }
  }

  if (handled)
    return YES;

  return [super performKeyEquivalent:theEvent];
}

// accessor for the 'URL' Apple Event attribute
- (NSString*)getURL
{
  BrowserWrapper* browserWrapper = [(BrowserWindowController*)[self delegate] browserWrapper];

  return [browserWrapper currentURI];
}

// True when the window has the unified toolbar bit set and is capable of
// displaying the unified appearance, even if the window is not main.
// Use |hasUnifiedToolbarAppearance && isMainWindow| when necessary.
- (BOOL)hasUnifiedToolbarAppearance
{
  return [self styleMask] & NSUnifiedTitleAndToolbarWindowMask;
}

@end
