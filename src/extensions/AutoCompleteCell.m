/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "AutoCompleteCell.h"
#import "AutoCompleteResult.h"
#import "CHGradient.h"
#import "NSWorkspace+Utils.h"


static NSSize kIconSize = {16, 16};

@interface AutoCompleteCell (Private)
// Creates and returns a dictionary of attributes for the title string.
- (NSMutableDictionary *)titleAttributes;

// Creates and returns a dictionary of attributes for the url string.
- (NSMutableDictionary *)urlAttributes;

// Creates and returns a dictionary of attributes for the url string.
- (NSDictionary *)headerAttributes;

// Divides a rectangle into appropriate-sized rectangles for the site
// favicon, title string, and url string.
- (void)createImageRect:(NSRect *)imageRect titleRect:(NSRect *)titleTextRect urlRect:(NSRect *)urlTextRect fromRect:(NSRect)cellFrame;

// Draws a highlight in the specified rectangle, taking into account
// the current control tint.
- (void)drawHighlightInRect:(NSRect)rect;
@end

@implementation AutoCompleteCell

- (NSMutableDictionary *)titleAttributes
{
  NSMutableParagraphStyle *paragraphStyle = [[[NSMutableParagraphStyle alloc] init] autorelease];
  [paragraphStyle setLineBreakMode:NSLineBreakByTruncatingMiddle];
  return [NSMutableDictionary dictionaryWithObjectsAndKeys:
          [NSColor blackColor], NSForegroundColorAttributeName,
          [NSFont systemFontOfSize:12.0], NSFontAttributeName,
          paragraphStyle, NSParagraphStyleAttributeName,
          nil];
}

- (NSMutableDictionary *)urlAttributes
{
  NSMutableParagraphStyle *paragraphStyle = [[[NSMutableParagraphStyle alloc] init] autorelease];
  [paragraphStyle setLineBreakMode:NSLineBreakByTruncatingTail];
  return [NSMutableDictionary dictionaryWithObjectsAndKeys:
          [NSColor grayColor], NSForegroundColorAttributeName,
          [NSFont systemFontOfSize:11.0], NSFontAttributeName,
          paragraphStyle, NSParagraphStyleAttributeName,
          nil];
}

- (NSDictionary *)headerAttributes
{
  return [NSDictionary dictionaryWithObjectsAndKeys:
          [NSColor grayColor], NSForegroundColorAttributeName,
          [NSFont systemFontOfSize:12.0], NSFontAttributeName,
          nil];
}

- (void)createImageRect:(NSRect *)imageRect titleRect:(NSRect *)titleTextRect urlRect:(NSRect *)urlTextRect fromRect:(NSRect)cellFrame
{
  const int kHorizontalPadding = 10;
  NSRect insetRect = NSInsetRect(cellFrame, kHorizontalPadding, 0);
  NSRect textRect;
  NSDivideRect(insetRect, imageRect, &textRect, kIconSize.width, NSMinXEdge);
  NSDivideRect(textRect, titleTextRect, urlTextRect, NSWidth(textRect) * 0.5, NSMinXEdge);

  // Set intercell spacing.
  const int kIntercellHorizontalPadding = 5;
  titleTextRect->origin.x += kIntercellHorizontalPadding;
  titleTextRect->size.width -= kIntercellHorizontalPadding;
  urlTextRect->origin.x += kIntercellHorizontalPadding;
  urlTextRect->size.width -= kIntercellHorizontalPadding;
}

- (void)drawHighlightInRect:(NSRect)rect
{
  if ([NSWorkspace isLeopardOrHigher]) {
    NSColor *topColor, *startColor, *endColor, *bottomColor;
    if ([NSColor currentControlTint] == NSGraphiteControlTint) {
      topColor = [NSColor colorWithCalibratedRed:(96/255.0) green:(105/255.0) blue:(113/255.0) alpha:1.0];
      startColor = [NSColor colorWithCalibratedRed:(107/255.0) green:(115/255.0) blue:(123/255.0) alpha:1.0];
      endColor = [NSColor colorWithCalibratedRed:(85/255.0) green:(94/255.0) blue:(105/255.0) alpha:1.0];
      bottomColor = [NSColor colorWithCalibratedRed:(68/255.0) green:(79/255.0) blue:(90/255.0) alpha:1.0];
    } else {
      topColor = [NSColor colorWithCalibratedRed:(73/255.0) green:(104/255.0) blue:(234/255.0) alpha:1.0];
      startColor = [NSColor colorWithCalibratedRed:(81/255.0) green:(112/255.0) blue:(246/255.0) alpha:1.0];
      endColor = [NSColor colorWithCalibratedRed:(26/255.0) green:(67/255.0) blue:(243/255.0) alpha:1.0];
      bottomColor = [NSColor colorWithCalibratedRed:(14/255.0) green:(55/255.0) blue:(231/255.0) alpha:1.0];
    }
    CHGradient *gradient = [[[CHGradient alloc] initWithStartingColor:startColor endingColor:endColor] autorelease];
    [gradient drawInRect:rect angle:90.0];
    [topColor set];
    NSRectFill(NSMakeRect(rect.origin.x, rect.origin.y - 1, rect.size.width, 1));
    [bottomColor set];
    NSRectFill(NSMakeRect(rect.origin.x, rect.origin.y - 1 + rect.size.height + 1, rect.size.width, 1));
  } else {
    NSColor *highlightColor;
    if ([NSColor currentControlTint] == NSGraphiteControlTint)
      highlightColor = [NSColor colorWithDeviceRed:0.392157 green:0.474510 blue:0.568627 alpha:1.0];
    else
      highlightColor = [NSColor colorWithDeviceRed:0.000000 green:0.392157 blue:0.901961 alpha:1.0];
    [highlightColor set];
    NSRectFill(NSInsetRect(rect, 0, -1));
  }
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
  NSImage *siteIcon = [[self objectValue] icon];
  NSString *title = [[self objectValue] title];
  NSString *url = [[self objectValue] url];

  NSDictionary *titleAttributes = [self titleAttributes];
  NSDictionary *urlAttributes = [self urlAttributes];
  const float titleTextHeight = [title sizeWithAttributes:titleAttributes].height;
  const float urlTextHeight = [url sizeWithAttributes:urlAttributes].height;

  // Start drawing.
  [controlView lockFocus];
  if ([[self objectValue] isHeader]) {
    // Draw a header row.
    const int kHorizontalPadding = 10;
    const int kTextVerticalPadding = (NSHeight(cellFrame) - titleTextHeight) * 0.5;
    [title drawInRect:NSMakeRect(cellFrame.origin.x + kHorizontalPadding, 
                                 cellFrame.origin.y + kTextVerticalPadding,
                                 cellFrame.size.width - kHorizontalPadding * 2,
                                 titleTextHeight)
       withAttributes:[self headerAttributes]];
  } else {
    if ([self isHighlighted]) {
      // We're highlighted, so draw selection gradient.
      [self drawHighlightInRect:cellFrame];
      // Set highlighted text colors.
      [titleAttributes setValue:[NSColor whiteColor] forKey:NSForegroundColorAttributeName];
      [urlAttributes setValue:[NSColor whiteColor] forKey:NSForegroundColorAttributeName];
    }
    NSRect imageRect;
    NSRect titleTextRect;
    NSRect urlTextRect;
    [self createImageRect:&imageRect titleRect:&titleTextRect urlRect:&urlTextRect fromRect:cellFrame];
    // Move the origin of the smaller-size url text so it aligns with the title text.
    urlTextRect.origin.y += titleTextHeight - urlTextHeight;

    // Draw the columns.
    [siteIcon setFlipped:YES];
    [siteIcon drawInRect:imageRect fromRect:NSMakeRect(0, 0, kIconSize.width, kIconSize.height) operation:NSCompositeSourceOver fraction:1.0];
    // The icon needs to be flipped back so it displays properly in other places where it's used.
    [siteIcon setFlipped:NO];
    [title drawInRect:titleTextRect withAttributes:titleAttributes];
    [url drawInRect:urlTextRect withAttributes:urlAttributes];
  }
  [controlView unlockFocus];
}

@end
