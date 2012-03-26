/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>


//
// Stores information about a bookmark or history item that is pertinent to
// displaying it in an AutoCompleteCell.
//
@interface AutoCompleteResult : NSObject
{
  NSImage*           mSiteIcon;
  NSString*          mSiteURL;
  NSString*          mSiteTitle;
  BOOL               mIsHeader;
}

- (void)setIcon:(NSImage *)anImage;
- (NSImage *)icon;
- (void)setUrl:(NSString *)aURL;
- (NSString *)url;
- (void)setTitle:(NSString *)aString;
- (NSString *)title;
- (void)setIsHeader:(BOOL)aBOOL;
- (BOOL)isHeader;

@end
