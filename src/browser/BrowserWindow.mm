/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "mozView.h"
#import "NSWorkspace+Utils.h"

#import "BrowserWindow.h"
#import "BrowserWindowController.h"
#import "MainController.h"
#import "AutoCompleteTextField.h"
#import "PreferenceManager.h"

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

// This gets called when the user hits the Escape key.
- (void)cancel:(id)sender
{
  BrowserWindowController* windowController = (BrowserWindowController*)[self delegate];
  if ([windowController tabThumbnailViewIsVisible])
    [windowController toggleTabThumbnailView:nil];
  else 
    [windowController stop:nil];
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

      BOOL zoomTextOnly = ![[PreferenceManager sharedInstance] getBooleanPref:kGeckoPrefFullContentZoom
                                                                  withSuccess:NULL];

      if (([theEvent modifierFlags] & NSAlternateKeyMask) != 0)
        zoomTextOnly = !zoomTextOnly;

      if (zoomTextOnly) {
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
    // Check for both d and D in case of caps lock (this is safe because the
    // modifierFlags check will filter out shift-command-d).
    if (keyChar == 'd' || keyChar == 'D') {
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
  return ([self styleMask] & NSUnifiedTitleAndToolbarWindowMask) ? YES : NO;
}

@end
