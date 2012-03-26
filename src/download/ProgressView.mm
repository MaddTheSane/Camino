/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */


#import "ProgressView.h"
#import "ProgressViewController.h"

enum {
  kLabelTagFilename = 1000,
  kLabelTagStatus,
  kLabelTagTimeRemaining,
  kLabelTagIcon
};

@interface ProgressView(ProgressViewPrivate)

- (NSColor*)labelColorForTag:(int)labelTag;
- (void)refreshLabelColors;

@end

@implementation ProgressView

- (NSColor*)labelColorForTag:(int)labelTag
{
  return [[self viewWithTag:labelTag] textColor];
}

- (void)awakeFromNib
{
  // Cache the labels' unselected text color specified in IB.
  mFilenameLabelUnselectedColor = [[self labelColorForTag:kLabelTagFilename] retain];
  mStatusLabelUnselectedColor   = [[self labelColorForTag:kLabelTagStatus] retain];
  mTimeLabelUnselectedColor     = [[self labelColorForTag:kLabelTagTimeRemaining] retain];

}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [mFileIconMouseDownEvent release];
  [mFilenameLabelUnselectedColor release];
  [mStatusLabelUnselectedColor release];
  [mTimeLabelUnselectedColor release];
  [super dealloc];
}

- (void)viewDidMoveToWindow
{
  if ([self window]) {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(windowKeyStatusChanged:)
                                                 name:NSWindowDidBecomeKeyNotification
                                               object:[self window]];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(windowKeyStatusChanged:)
                                                 name:NSWindowDidResignKeyNotification
                                               object:[self window]];
    [self refreshLabelColors];
  }
}

- (void)windowKeyStatusChanged:(NSNotification *)aNotification
{
  [self refreshLabelColors];
  [self setNeedsDisplay:YES];
}

- (void)selectionChanged
{
  [self refreshLabelColors];
  [self setNeedsDisplay:YES];
}

- (void)refreshLabelColors
{
  NSTextField* filenameLabel = [self viewWithTag:kLabelTagFilename];
  NSTextField* statusLabel = [self viewWithTag:kLabelTagStatus];
  NSTextField* timeLabel = [self viewWithTag:kLabelTagTimeRemaining];

  if ([mProgressController isSelected] && [[self window] isKeyWindow]) {
    NSColor* selectedLabelColor = [NSColor alternateSelectedControlTextColor];
    [filenameLabel setTextColor:selectedLabelColor];
    [statusLabel setTextColor:selectedLabelColor];
    [timeLabel setTextColor:selectedLabelColor];
  }
  else {
    // Use the labels' unselected text color specified in IB.
    [filenameLabel setTextColor:mFilenameLabelUnselectedColor];
    [statusLabel setTextColor:mStatusLabelUnselectedColor];
    [timeLabel setTextColor:mTimeLabelUnselectedColor];
  }
}

- (void)drawRect:(NSRect)rect
{
  if ([mProgressController isSelected]) {
    if ([[self window] isKeyWindow])
      [[NSColor alternateSelectedControlColor] set];
    else
      [[NSColor secondarySelectedControlColor] set];
  }
  else {
    [[NSColor controlBackgroundColor] set];
  }
  [NSBezierPath fillRect:[self bounds]];
}

- (void)mouseDown:(NSEvent*)theEvent
{
  unsigned int mods = [theEvent modifierFlags];
  DownloadSelectionBehavior selectionBehavior;
  // Favor command behavior over shift, like most table views do
  if (mods & NSCommandKeyMask)
    selectionBehavior = DownloadSelectByInverting;
  else if (mods & NSShiftKeyMask)
    selectionBehavior = DownloadSelectByExtending;
  else
    selectionBehavior = DownloadSelectExclusively;
  [mProgressController updateSelectionWithBehavior:selectionBehavior];

  [mFileIconMouseDownEvent release];
  mFileIconMouseDownEvent = nil;
  if ([theEvent type] == NSLeftMouseDown) {
    // See if it's a double-click; if so, send a notification off to the
    // controller which will handle it accordingly. Doing it after processing
    // the selection change allows someone to shift-double-click and open all
    // selected items in the list in one action.
    if ([theEvent clickCount] == 2) {
      [mProgressController openSelectedDownloads];
    }
    // If not, and the download isn't active, see if it's a click on the icon.
    else if (![mProgressController isActive]) {
      NSPoint clickPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
      if (NSPointInRect(clickPoint, [mFileIconView frame]))
        mFileIconMouseDownEvent = [theEvent retain];
    }
  }
}

- (BOOL)acceptsFirstMouse:(NSEvent*)theEvent {
  // Allow click-through on the file icon to allow dragging files even if the
  // view is in a background window.
  NSPoint clickPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
  return NSPointInRect(clickPoint, [mFileIconView frame]);
}

- (void)mouseDragged:(NSEvent*)aEvent
{
  if (!mFileIconMouseDownEvent)
    return;

  // Check that the controller thinks this view represents a file we know about,
  // but also that the file is actually still there in case the controller's
  // information is stale.
  if (![mProgressController fileExists])
    return;
  NSString* filePath = [mProgressController representedFilePath];
  if (!(filePath && [[NSFileManager defaultManager] fileExistsAtPath:filePath]))
    return;

  NSPasteboard* pasteboard = [NSPasteboard pasteboardWithName:NSDragPboard];
  [pasteboard declareTypes:[NSArray arrayWithObject:NSFilenamesPboardType] owner:nil];
  [pasteboard setPropertyList:[NSArray arrayWithObject:filePath] forType:NSFilenamesPboardType];

  NSRect fileIconFrame = [mFileIconView frame];

  NSImage* dragImage = [[[NSImage alloc] initWithSize:fileIconFrame.size] autorelease];
  [dragImage lockFocus];
  NSRect imageRect = NSMakeRect(0, 0, fileIconFrame.size.width, fileIconFrame.size.height);
  [[mFileIconView image] drawAtPoint:NSMakePoint(0, 0)
                           fromRect:imageRect
                          operation:NSCompositeCopy
                           fraction:0.8];
  [dragImage unlockFocus];

  NSPoint clickLocation = [self convertPoint:[mFileIconMouseDownEvent locationInWindow] fromView:nil];
  [self dragImage:dragImage
               at:fileIconFrame.origin
           offset:NSMakeSize(clickLocation.x - fileIconFrame.origin.x,
                             clickLocation.y - fileIconFrame.origin.y)
            event:mFileIconMouseDownEvent
       pasteboard:pasteboard
           source:self
        slideBack:YES];
}

- (unsigned int)draggingSourceOperationMaskForLocal:(BOOL)localFlag
{
  return NSDragOperationEvery;
}

- (void)draggedImage:(NSImage *)anImage endedAt:(NSPoint)aPoint operation:(NSDragOperation)operation
{
  if (operation == NSDragOperationDelete) {
    [mProgressController deleteFile];
    [mProgressController remove:self];
  }
  if (operation == NSDragOperationMove)
    [mProgressController remove:self];
}

- (void)updateFilename:(NSString*)filename
{
  NSTextField* filenameLabelView = [self viewWithTag:kLabelTagFilename];
  if ([[filenameLabelView stringValue] isEqualToString:filename])
    return;
  
  [filenameLabelView setStringValue:filename];
  [filenameLabelView setNeedsDisplay:YES];
}

- (void)updateFileIcon:(NSImage*)fileIcon
{
  NSImageView* fileIconView = [self viewWithTag:kLabelTagIcon];
  [fileIconView setImage:fileIcon];
  [fileIconView setNeedsDisplay:YES];
}

- (void)updateStatus:(NSString*)status
{
  NSTextField* statusLabelView = [self viewWithTag:kLabelTagStatus];
  if ([[statusLabelView stringValue] isEqualToString:status])
    return;
  
  [statusLabelView setStringValue:status];
  [statusLabelView setNeedsDisplay:YES];
}

- (void)updateTimeRemaining:(NSString*)timeRemaining
{
  NSTextField* timeLabelView = [self viewWithTag:kLabelTagTimeRemaining];
  if ([[timeLabelView stringValue] isEqualToString:timeRemaining])
    return;

  [timeLabelView setStringValue:timeRemaining];
  [timeLabelView setNeedsDisplay:YES];
}

- (void)setController:(ProgressViewController*)controller
{
  mProgressController = controller;
}

- (ProgressViewController*)controller
{
  return mProgressController;
}

- (NSMenu*)menuForEvent:(NSEvent*)theEvent
{  
  // if the item is unselected, select it and deselect everything else before displaying the contextual menu
  if (![mProgressController isSelected]) {
    [mProgressController updateSelectionWithBehavior:DownloadSelectExclusively];
    [self display]; // change visual selection immediately
  }
  return [[self controller] contextualMenu];
}

- (BOOL)performKeyEquivalent:(NSEvent*)theEvent
{
  if (([theEvent type] == NSKeyDown && 
      ([theEvent modifierFlags] & NSCommandKeyMask) != 0)) 
  {
    // Catch a command-period key down event and send the cancel request.
    if ([[theEvent characters] isEqualToString:@"."]) {
      [mProgressController cancelSelectedDownloads];
      return YES;
    }
    
    // Catch a command-down-arrow key down event and send the open request.
    if ([[theEvent characters] characterAtIndex:0] == NSDownArrowFunctionKey) {
      [mProgressController openSelectedDownloads];
      return YES;
    }
  }
  
  return [super performKeyEquivalent:theEvent];
}

- (NSView*)hitTest:(NSPoint)aPoint
{
  if (NSMouseInRect(aPoint, [self frame], YES)) {
    return self;
  }
  else {
    return nil;
  }
}

@end
