// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at http://mozilla.org/MPL/2.0/.

//
//  CaminoViewsInspector.m
//  CaminoViewsPalette
//
//  Created by Simon Fraser on 21/11/05.

#import "CaminoViewsInspector.h"
#import "CaminoViewsPalette.h"

@implementation CaminoViewsInspector

- (id)init
{
    self = [super init];
    [NSBundle loadNibNamed:@"CaminoViewsInspector" owner:self];
    return self;
}

- (void)ok:(id)sender
{
	/* Your code Here */
    [super ok:sender];
}

- (void)revert:(id)sender
{
	/* Your code Here */
    [super revert:sender];
}

@end
