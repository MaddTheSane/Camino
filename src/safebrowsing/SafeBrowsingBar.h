/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>
#import "TransientBar.h"

@class RolloverImageButton;

//
// SafeBrowsingBar
//
// A TransientBar subclass which is displayed when the user ignores the blocked
// site error overlay and continues on to the dangerous site.
//
@interface SafeBrowsingBar : TransientBar {
  IBOutlet RolloverImageButton *mCloseButton;
  IBOutlet NSTextField *mWarningLabelTextField;
}

@end
