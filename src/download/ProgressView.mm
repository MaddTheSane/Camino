/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* ***** BEGIN LICENSE BLOCK *****
 * Version: NPL 1.1/GPL 2.0/LGPL 2.1
 *
 * The contents of this file are subject to the Netscape Public License
 * Version 1.1 (the "License"); you may not use this file except in
 * compliance with the License. You may obtain a copy of the License at
 * http://www.mozilla.org/NPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Original Code is mozilla.org code.
 *
 * The Initial Developer of the Original Code is 
 * Josh Aas.
 * Portions created by the Initial Developer are Copyright (C) 2003
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *    Josh Aas <josha@mac.com>
 *
 * Alternatively, the contents of this file may be used under the terms of
 * either the GNU General Public License Version 2 or later (the "GPL"), or 
 * the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
 * in which case the provisions of the GPL or the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of either the GPL or the LGPL, and not to allow others to
 * use your version of this file under the terms of the NPL, indicate your
 * decision by deleting the provisions above and replace them with the notice
 * and other provisions required by the GPL or the LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the NPL, the GPL or the LGPL.
 *
 * ***** END LICENSE BLOCK ***** */


#import "ProgressView.h"

@implementation ProgressView

- (id)initWithFrame:(NSRect)frame
{
  self = [super initWithFrame:frame];
  if (self) {
    mLastModifier = kNoKey;
    mIsSelected = NO;
  }
  return self;
}

-(void)drawRect:(NSRect)rect
{
  if (mIsSelected) {
    [[NSColor selectedTextBackgroundColor] set];
  }
  else {
    [[NSColor whiteColor] set];
  }
  [NSBezierPath fillRect:[self bounds]];
}

-(void)mouseDown:(NSEvent*)theEvent
{
  unsigned int mods = [theEvent modifierFlags];
  mLastModifier = kNoKey;
  BOOL shouldSelect = YES;
  // set mLastModifier to any relevant modifier key
  if (!((mods & NSShiftKeyMask) && (mods & NSCommandKeyMask))) {
    if (mods & NSShiftKeyMask) {
      mLastModifier = kShiftKey;
    }
    else if (mods & NSCommandKeyMask) {
      if (mIsSelected) {
        shouldSelect = NO;
      }
      mLastModifier = kCommandKey;
    }
  }
  [self setSelected:shouldSelect];
  [[NSNotificationCenter defaultCenter] postNotificationName:@"DownloadInstanceSelected" object:self];
}

-(BOOL)isSelected
{
  return mIsSelected;
}

-(void)setSelected:(BOOL)flag
{
  mIsSelected = flag;
  [self setNeedsDisplay:YES];
}

-(int)lastModifier
{
  return mLastModifier;
}

-(void)setController:(ProgressViewController*)controller
{
  // Don't retain since this view will only exist if its controller does
  mProgressController = controller;
}

-(ProgressViewController*)getController
{
  return mProgressController;
}

-(NSMenu*)menuForEvent:(NSEvent*)theEvent
{  
  // if the item is unselected, select it and deselect everything else before displaying the contextual menu
  if (!mIsSelected) {
    mLastModifier = kNoKey; // control is only special because it means its contextual menu time
    mIsSelected = YES;
    [self display]; // change selection immediately
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DownloadInstanceSelected" object:self];
  }
  return [[self getController] contextualMenu];
}

-(NSView*)hitTest:(NSPoint)aPoint
{
  if (NSMouseInRect(aPoint, [self frame], YES)) {
    return self;
  }
  else {
    return nil;
  }
}

@end
