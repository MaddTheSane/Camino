/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "PreferencePaneBase.h"

@interface OrgMozillaCaminoPreferenceAppearance : PreferencePaneBase 
{
  IBOutlet NSTabView*     mTabView;
  IBOutlet NSButton*      mResetButton;

  // colors tab
  IBOutlet NSColorWell*   mTextColorWell;
  IBOutlet NSColorWell*   mBackgroundColorWell;

  IBOutlet NSColorWell*   mVisitedLinksColorWell;  
  IBOutlet NSColorWell*   mUnvisitedLinksColorWell;

  IBOutlet NSButton*      mUnderlineLinksCheckbox;

  // fonts tab
  IBOutlet NSButton*      mChooseProportionalFontButton;
  IBOutlet NSButton*      mChooseMonospaceFontButton;
  IBOutlet NSPopUpButton* mFontRegionPopup;

  IBOutlet NSTextField*   mFontSampleProportional;
  IBOutlet NSTextField*   mFontSampleMonospace;

  IBOutlet NSTextField*   mProportionalSampleLabel;

  IBOutlet NSPopUpButton* mMinFontSizePopup;
  IBOutlet NSMatrix*      mDefaultFontMatrix;
  IBOutlet NSButton*      mUseMyFontsCheckbox;

  IBOutlet NSView*        mPreviousBottomControl;

  NSArray*                mRegionMappingTable;

  NSButton*               mFontButtonForEditor;

  NSTextView*             mPropSampleFieldEditor;
  NSTextView*             mMonoSampleFieldEditor;

  BOOL                    mFontPanelWasVisible;
}

- (void)mainViewDidLoad;

- (IBAction)buttonClicked:(id)sender; 
- (IBAction)colorChanged:(id)sender;

- (IBAction)proportionalFontChoiceButtonClicked:(id)sender;
- (IBAction)useMyFontsButtonClicked:(id)sender;
- (IBAction)monospaceFontChoiceButtonClicked:(id)sender;
- (IBAction)fontRegionPopupClicked:(id)sender;

- (IBAction)minFontSizePopupClicked:(id)sender;
- (IBAction)defaultFontTypeClicked:(id)sender;

- (IBAction)resetToDefaults:(id)sender;

@end
