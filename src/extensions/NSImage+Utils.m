/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>

#import "NSImage+Utils.h"

#import "NSWorkspace+Utils.h"

#if MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_4
NSString *const NSImageNameBonjour = @"NSBonjour";
#endif

@implementation NSImage (CaminoImageUtils)

- (void)drawTiledInRect:(NSRect)rect origin:(NSPoint)inOrigin operation:(NSCompositingOperation)inOperation
{
  NSGraphicsContext* gc = [NSGraphicsContext currentContext];
  [gc saveGraphicsState];

  [gc setPatternPhase:inOrigin];

  NSColor* patternColor = [NSColor colorWithPatternImage:self];
  [patternColor set];
  NSRectFillUsingOperation(rect, inOperation);

  [gc restoreGraphicsState];
}

- (NSImage*)imageByApplyingBadge:(NSImage*)badge withAlpha:(float)alpha scale:(float)scale;
{
  if (!badge)
    return self;

  // bad to actually change badge here  
  [badge setScalesWhenResized:YES];
  [badge setSize:NSMakeSize([self size].width * scale,[self size].height * scale)];

  // make a new image, copy over our best rep into it
  NSImage* newImage = [[[NSImage alloc] initWithSize:[self size]] autorelease];
  NSImageRep* imageRep = [[self bestRepresentationForDevice:nil] copy];
  [newImage addRepresentation:imageRep];
  [imageRep release];
  
  [newImage lockFocus];
  [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
  [badge dissolveToPoint:NSMakePoint([self size].width - [badge size].width, 0.0) fraction:alpha];
  [newImage unlockFocus];

  return newImage;
}

+ (NSImage*)dragImageWithIcon:(NSImage*)aIcon title:(NSString*)aTitle {
  if (!aIcon || !aTitle)
    return nil;

  const float kTitleOffset = 2.0f;

  NSDictionary* stringAttrs = [NSDictionary dictionaryWithObjectsAndKeys:
         [[NSColor textColor] colorWithAlphaComponent:0.8], NSForegroundColorAttributeName,
    [NSFont systemFontOfSize:[NSFont smallSystemFontSize]], NSFontAttributeName,
                                                      nil];

  // get the size of the new image we are creating
  NSSize titleSize = [aTitle sizeWithAttributes:stringAttrs];
  NSSize imageSize = NSMakeSize(titleSize.width + [aIcon size].width + kTitleOffset,
                                titleSize.height > [aIcon size].height ? titleSize.height
                                                                       : [aIcon size].height);

  // create the image and lock drawing focus on it
  NSImage* dragImage = [[[NSImage alloc] initWithSize:imageSize] autorelease];
  [dragImage lockFocus];

  // draw the image and title in image with translucency
  NSRect imageRect = NSMakeRect(0, 0, [aIcon size].width, [aIcon size].height);
  [aIcon drawAtPoint:NSMakePoint(0, 0) fromRect:imageRect operation:NSCompositeCopy fraction:0.8];

  [aTitle drawAtPoint:NSMakePoint([aIcon size].width + kTitleOffset, 0.0) withAttributes:stringAttrs];

  [dragImage unlockFocus];
  return dragImage;
}

+ (NSImage*)osBonjourIcon
{
  static NSImage* sBonjourImage = nil;
  if (!sBonjourImage) {
    if ([NSWorkspace isLeopardOrHigher]) {
      sBonjourImage = [[NSImage imageNamed:NSImageNameBonjour] retain];
      [sBonjourImage setSize:NSMakeSize(16, 16)];
    }
    else {
      sBonjourImage = [[NSImage imageNamed:@"rendezvous_icon"] retain];
    }
  }
  return sBonjourImage;
}

+ (NSImage*)osFolderIcon
{
  static NSImage* sFolderImage = nil;
  if (!sFolderImage) {
    if ([NSWorkspace isLeopardOrHigher]) {
      NSString* fileType = NSFileTypeForHFSTypeCode(kGenericFolderIcon);
      sFolderImage = [[[NSWorkspace sharedWorkspace] iconForFileType:fileType] retain];
      [sFolderImage setSize:NSMakeSize(16, 16)];
    }
    else {
      sFolderImage = [[NSImage imageNamed:@"folder"] retain];
    }
  }
  return sFolderImage;
}

@end
