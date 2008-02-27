/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*-
 *
 * ***** BEGIN LICENSE BLOCK *****
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
 * The Original Code is Camino code.
 *
 * The Initial Developer of the Original Code is The Mozilla Foundation.
 * Portions created by the Initial Developer are Copyright (C) 2008
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *   Peter Jaros <peter.a.jaros@gmail.com> (Original Author)
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

#import "MoveCommand.h"
#import <AppKit/AppKit.h>

@implementation MoveCommand

// NSMoveCommand interprets "move to <collection>" as "replace <collection>".
// In those cases, substitute the semantic "move to end of <collection>".
// If <collection> is not actually a collection, the user will get an error.
- (id)performDefaultImplementation
{
  NSMutableDictionary *args = [NSMutableDictionary dictionaryWithDictionary:[self arguments]];
  id toLoc = [args objectForKey:@"ToLocation"];
  // If we were planning to replace something...
  if (toLoc && [toLoc isKindOfClass:[NSPositionalSpecifier class]] && [toLoc insertionReplaces]) {
    // ...substitute a similar NSPositionalSpecifier, only inserting at the end of the collection.
    NSPositionalSpecifier *newToLoc = [[[NSPositionalSpecifier alloc] initWithPosition:NSPositionEnd
                                                                       objectSpecifier:[toLoc objectSpecifier]] autorelease];
    [args setValue:newToLoc forKey:@"ToLocation"];
    [self setArguments:args];
  }

  // Let NSMoveCommand do what it does.
  return [super performDefaultImplementation];
}

@end
