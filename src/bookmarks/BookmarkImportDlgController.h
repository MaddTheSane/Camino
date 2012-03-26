/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <AppKit/AppKit.h>


@interface BookmarkImportDlgController : NSWindowController {
  IBOutlet NSPopUpButton* mBrowserListButton;
  IBOutlet NSButton* mCancelButton;
  IBOutlet NSButton* mImportButton;
  IBOutlet NSProgressIndicator* mImportProgressBar;
  IBOutlet NSView* mImportView;
  IBOutlet NSView* mProgressView;
}

- (void)buildAvailableFileList;
- (IBAction)cancel:(id)aSender;
- (IBAction)import:(id)aSender;
- (IBAction)loadOpenPanel:(id)aSender;
- (IBAction)nullAction:(id)aSender;
- (void)alertSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)finishThreadedImport:(BOOL)success fromFile:(NSString *)aFile;

@end
