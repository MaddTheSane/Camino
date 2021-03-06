/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "SessionManager.h"

#import "PreferenceManager.h"
#import "ProgressDlgController.h"
#import "BrowserWrapper.h"
#import "BrowserTabView.h"
#import "BrowserWindowController.h"
#import "BrowserTabViewItem.h"
#import "BookmarkToolbar.h"

static NSString* const kBrowserWindowListKey = @"BrowserWindows";
static NSString* const kDownloadWindowKey = @"DownloadWindow";
static NSString* const kTabListKey = @"Tabs";
static NSString* const kSelectedTabKey = @"SelectedTab";
static NSString* const kFrameKey = @"Frame";
static NSString* const kIsVisibleKey = @"Visible";
static NSString* const kIsKeyWindowKey = @"Key";
static NSString* const kIsMiniaturizedKey = @"Miniaturized";
static NSString* const kToolbarIsVisibleKey = @"ToolbarVisible";
static NSString* const kBookmarkBarIsVisibleKey = @"BookmarkBarVisible";
static NSString* const kStatusBarIsVisibleKey = @"StatusBarVisible";

// Number of seconds to coalesce changes before saving them
const NSTimeInterval kPersistDelay = 10.0;

@interface SessionManager(Private)

- (NSDictionary*)dictionaryForCurrentWindowState;
- (void)setWindowStateFromDictionary:(NSDictionary*)windowState;
- (void)setWindowStateIsDirty:(BOOL)isDirty;

// Returns the serializable dictionary for the given window's state.
- (NSDictionary*)serializationForBrowserWindow:(NSWindow*)window;
// Creates a new browser window, restored from the given state serialization.
- (void)createBrowserWindowFromSerialization:(NSDictionary*)state;

@end

@implementation SessionManager

- (id)init
{
  if ((self = [super init])) {
    NSString* profileDir = [[PreferenceManager sharedInstance] profilePath];
    mSessionStatePath = [[profileDir stringByAppendingPathComponent:@"WindowState.plist"] retain];
  }
  return self;
}

- (void)dealloc
{
  [mSessionStatePath release];
  [mDelayedPersistTimer release];
  [super dealloc];
}

+ (SessionManager*)sharedInstance
{
  static SessionManager* sharedSessionManager = nil;
  if (!sharedSessionManager)
    sharedSessionManager = [[SessionManager alloc] init];

  return sharedSessionManager;
}

// Private method to gather all the window state into an NSDictionary. The
// dictionary must contain only plist-safe types so that it can be written
// to file.
- (NSDictionary*)dictionaryForCurrentWindowState
{
  NSArray* windows = [NSApp orderedWindows];
  NSMutableDictionary* state = [NSMutableDictionary dictionary];

  // save browser windows
  NSMutableArray* storedBrowserWindows = [NSMutableArray arrayWithCapacity:[windows count]];
  NSEnumerator* windowEnumerator = [windows objectEnumerator];
  NSWindow* window;
  while ((window = [windowEnumerator nextObject])) {
    if ([[window windowController] isMemberOfClass:[BrowserWindowController class]])
      [storedBrowserWindows addObject:[self serializationForBrowserWindow:window]];
  }
  [state setValue:storedBrowserWindows forKey:kBrowserWindowListKey];

  // save download window state
  ProgressDlgController* downloadWindowController = [ProgressDlgController existingSharedDownloadController];
  NSDictionary* downloadWindowState = [NSDictionary dictionaryWithObjectsAndKeys:
      [NSNumber numberWithBool:[[downloadWindowController window] isMiniaturized]], kIsMiniaturizedKey,
      [NSNumber numberWithBool:[[downloadWindowController window] isKeyWindow]], kIsKeyWindowKey,
      [NSNumber numberWithBool:[[downloadWindowController window] isVisible]], kIsVisibleKey,
      nil];
  [state setValue:downloadWindowState forKey:kDownloadWindowKey];

  return state;
}

// Private method to restore the window state from an NSDictionary.
// Note that any windows currently open are unaffected by the restore, so to
// get a clean restore all windows should be closed before calling this.
- (void)setWindowStateFromDictionary:(NSDictionary*)windowState
{
  // restore download window if it was showing
  NSDictionary* downloadWindowState = [windowState objectForKey:kDownloadWindowKey];
  ProgressDlgController* downloadController = nil;
  if ([[downloadWindowState objectForKey:kIsVisibleKey] boolValue] ||
      [[downloadWindowState objectForKey:kIsMiniaturizedKey] boolValue]) {
    downloadController = [ProgressDlgController sharedDownloadController];
    [downloadController showWindow:self];
    if ([[downloadWindowState objectForKey:kIsMiniaturizedKey] boolValue])
      [[downloadController window] miniaturize:self];
  }

  // restore browser windows
  NSArray* storedBrowserWindows = [windowState objectForKey:kBrowserWindowListKey];
  // the array is in front to back order, so we want to restore windows in reverse
  NSEnumerator* storedWindowEnumerator = [storedBrowserWindows reverseObjectEnumerator];
  NSDictionary* windowInfo;
  while ((windowInfo = [storedWindowEnumerator nextObject])) {
    [self createBrowserWindowFromSerialization:windowInfo];
  }

  // if the download window was key, pull it to the front
  if ([[downloadWindowState objectForKey:kIsKeyWindowKey] boolValue])
    [[downloadController window] makeKeyAndOrderFront:self];
}

- (void)saveWindowState
{
  NSData* stateData = [NSPropertyListSerialization dataFromPropertyList:[self dictionaryForCurrentWindowState]
                                                                 format:NSPropertyListBinaryFormat_v1_0
                                                       errorDescription:NULL];
  [stateData writeToFile:mSessionStatePath atomically:YES];
  [self setWindowStateIsDirty:NO];
}

- (void)restoreWindowState
{
  NSData* stateData = [NSData dataWithContentsOfFile:mSessionStatePath];
  NSDictionary* state = [NSPropertyListSerialization propertyListFromData:stateData
                                                         mutabilityOption:NSPropertyListImmutable
                                                                   format:NULL
                                                         errorDescription:NULL];
  if (state)
    [self setWindowStateFromDictionary:state];
}

- (void)clearSavedState
{
  NSFileManager* fileManager = [NSFileManager defaultManager];
  if ([fileManager fileExistsAtPath:mSessionStatePath])
    [fileManager removeFileAtPath:mSessionStatePath handler:nil];

  // Ensure that we don't immediately write out a new file
  [self setWindowStateIsDirty:NO];
}

- (void)windowStateChanged
{
  [self setWindowStateIsDirty:YES];
}

- (void)setWindowStateIsDirty:(BOOL)isDirty
{
  if (isDirty == mDirty)
    return;

  mDirty = isDirty;
  if (mDirty) {
    mDelayedPersistTimer = [[NSTimer scheduledTimerWithTimeInterval:kPersistDelay
                                                             target:self
                                                           selector:@selector(performDelayedPersist:)
                                                           userInfo:nil
                                                            repeats:NO] retain];
  }
  else {
    [mDelayedPersistTimer invalidate];
    [mDelayedPersistTimer release];
    mDelayedPersistTimer = nil;
  }
}

- (void)performDelayedPersist:(NSTimer*)theTimer
{
  [self saveWindowState];
}

- (BOOL)hasSavedState
{
  NSFileManager* fileManager = [NSFileManager defaultManager];
  return [fileManager fileExistsAtPath:mSessionStatePath];
}

// TODO: The BWC-specific part of these two methods should be moved into BWC
// itself, and this should just tack on the general window state.
- (NSDictionary*)serializationForBrowserWindow:(NSWindow*)window
{
  BrowserWindowController* browser =
      (BrowserWindowController*)[window windowController];

  BrowserTabView* tabView = [browser tabBrowser];
  NSMutableArray* storedTabs = [NSMutableArray array];
  NSEnumerator* tabEnumerator = [[tabView tabViewItems] objectEnumerator];
  BrowserTabViewItem* tab;
  while ((tab = [tabEnumerator nextObject])) {
    BrowserWrapper* browser = (BrowserWrapper*)[tab view];
    // if the user quits too quickly, the pages in the process of being restored
    // will still be blank; in those cases, save the URI they are trying to load
    // instead.
    NSString* tabURL = ([browser isEmpty] && [browser pendingURI]) ?
        [browser pendingURI] : [browser currentURI];
    [storedTabs addObject:tabURL];
  }
  int selectedTabIndex = [tabView indexOfTabViewItem:[tabView selectedTabViewItem]];
  
  // TODO (possibly): session history, scroll position, chrome flags, tab bar
  // scroll positon.

  return [NSDictionary dictionaryWithObjectsAndKeys:
                                                  storedTabs, kTabListKey,
                   [NSNumber numberWithInt:selectedTabIndex], kSelectedTabKey,
           [NSNumber numberWithBool:[window isMiniaturized]], kIsMiniaturizedKey,
      [NSNumber numberWithBool:[[window toolbar] isVisible]], kToolbarIsVisibleKey,
    [NSNumber numberWithBool:[browser bookmarkBarIsVisible]], kBookmarkBarIsVisibleKey,
      [NSNumber numberWithBool:[browser statusBarIsVisible]], kStatusBarIsVisibleKey,
                            NSStringFromRect([window frame]), kFrameKey,
                                                              nil];
}

- (void)createBrowserWindowFromSerialization:(NSDictionary*)state
{
  BrowserWindowController* browser =
      [[BrowserWindowController alloc] initWithWindowNibName:@"BrowserWindow"];

  // Make sure we have entries for anything where nil would wreak havoc.
  if (!([state valueForKey:kTabListKey] && [state valueForKey:kFrameKey]))
    return;

  [[[browser window] toolbar] setVisible:[[state valueForKey:kToolbarIsVisibleKey] boolValue]];
  [browser setBookmarkBarIsVisible:[[state valueForKey:kBookmarkBarIsVisibleKey] boolValue]];
  if ([state valueForKey:kStatusBarIsVisibleKey])
    [browser setStatusBarIsVisible:[[state valueForKey:kStatusBarIsVisibleKey] boolValue]];
  [[browser window] setFrame:NSRectFromString([state valueForKey:kFrameKey]) display:YES];

  [browser showWindow:self];
  [browser openURLArray:[state objectForKey:kTabListKey]
          tabOpenPolicy:eReplaceTabs
            allowPopups:NO];
  int selectedTabIndex = [[state objectForKey:kSelectedTabKey] intValue];
  [[browser tabBrowser] selectTabViewItemAtIndex:selectedTabIndex];

  if ([[state valueForKey:kIsMiniaturizedKey] boolValue])
    [[browser window] miniaturize:self];
}

@end
