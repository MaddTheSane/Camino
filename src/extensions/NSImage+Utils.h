/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <AppKit/NSImage.h>

@interface NSImage (CaminoImageUtils)

// the origin is relative to the bottom, left of the window.
- (void)drawTiledInRect:(NSRect)rect origin:(NSPoint)inOrigin operation:(NSCompositingOperation)inOperation;

- (NSImage*)imageByApplyingBadge:(NSImage*)badge withAlpha:(float)alpha scale:(float)scale;

// Returns a drag image for an icon/title pair. Assumes that the title should
// be shown to the right of the icon, at small system font size.
// |aIcon| and |aTitle| must both be non-nil.
+ (NSImage*)dragImageWithIcon:(NSImage*)aIcon title:(NSString*)aTitle;

// Returns the standard OS folder icon; unfortunately there's no convenient
// name constant for it.
+ (NSImage*)osFolderIcon;

@end
