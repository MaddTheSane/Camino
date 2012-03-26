/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <AppKit/AppKit.h>

/**
 * Define a simple class to share some of the building tasks for populating
 * feed application popups.
 */

__attribute__((visibility("default"))) extern NSString* const kUserChosenBrowserUserDefaultsKey;
__attribute__((visibility("default"))) extern NSString* const kUserChosenFeedViewerUserDefaultsKey;
__attribute__((visibility("default"))) extern NSString* const kDefaultFeedViewerChanged;

@interface AppListMenuFactory : NSObject
{
}

+(AppListMenuFactory*)sharedAppListMenuFactory;

-(void)buildFeedAppsMenuForPopup:(NSPopUpButton*)inPopupButton 
                       andAction:(SEL)inAction 
                 andSelectAction:(SEL)inSelectAction
                       andTarget:(id)inTarget;

-(void)buildBrowserAppsMenuForPopup:(NSPopUpButton*)inPopupButton
                          andAction:(SEL)inAction
                    andSelectAction:(SEL)inSelectAction
                          andTarget:(id)inTarget;

-(BOOL)validateAndRegisterDefaultFeedViewer:(NSString*)inBundleID;
-(BOOL)validateAndRegisterDefaultBrowser:(NSString*)inBundleID;

@end
