/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */


#import <Cocoa/Cocoa.h>

@class CertificateItem;
@class CHBrowserView;

@interface PageInfoWindowController : NSWindowController
{
  // general tab
  IBOutlet NSTextField*           mPageTitleField;
  IBOutlet NSTextField*           mPageLocationField;
  IBOutlet NSTextField*           mPageModDateField;

  // security tab
  IBOutlet NSImageView*           mSiteVerifiedImageView;
  IBOutlet NSTextField*           mSiteVerifiedTextField;
  IBOutlet NSTextField*           mSiteVerifiedDetailsField;
  IBOutlet NSButton*              mShowCertificateButton;
  
  IBOutlet NSImageView*           mConnectionImageView;
  IBOutlet NSTextField*           mConnectionTextField;
  IBOutlet NSTextField*           mConnectionDetailsField;
  
  CertificateItem*                mCertificateItem;   // retained
}

+ (PageInfoWindowController*)sharedPageInfoWindowController;
// return nil if page info is not open
+ (PageInfoWindowController*)visiblePageInfoWindowController;

- (IBAction)viewCertificate:(id)sender;

- (void)updateFromBrowserView:(CHBrowserView*)inBrowserView;


@end
