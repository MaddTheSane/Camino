/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>

extern NSString* const kMVPreferencesWindowNotification;

@interface MVPreferencesController : NSObject
{
    IBOutlet NSWindow*      mWindow;
    IBOutlet NSView*        mLoadingView;
    IBOutlet NSImageView*   mLoadingImageView;
    IBOutlet NSTextField*   mLoadingTextFeld;

    NSView*                 mMainView;

    NSMutableArray*         mPaneBundles;   // array of NSBundle*
    NSMutableDictionary*    mLoadedPanes;   // panes indexed by identifier
    NSMutableDictionary*    mPaneInfo;      // mutable dicts indexed by identifier

    NSString*               mCurrentPaneIdentifier;
    NSString*               mPendingPaneIdentifier;

    NSArray*                mToolbarItemIdentifiers;

    BOOL                    mCloseWhenPaneIsReady;
}

+ (MVPreferencesController *) sharedInstance;
+ (void)clearSharedInstance;

- (NSWindow *)window;
- (void) showPreferences:(id) sender;
- (void) selectPreferencePaneByIdentifier:(NSString *) identifier;

@end

@interface NSObject (PreferencePaneFieldEditorOverride)

- (id)fieldEditorForObject:(id)inObject;

@end
