/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "PreferencePaneBase.h"

#import "PreferenceManager.h"

@implementation PreferencePaneBase

- (id)initWithBundle:(NSBundle*)bundle
{
  self = [super initWithBundle:bundle];

  // Grab the shared PreferenceManager to be sure it's inited. We use
  // sharedInstanceDontCreate everywhere else in case we live past Gecko teardown
  [PreferenceManager sharedInstance];

  return self;
}

#pragma mark -

- (NSString*)getStringPref:(const char*)prefName withSuccess:(BOOL*)outSuccess
{
  return [[PreferenceManager sharedInstanceDontCreate] getStringPref:prefName
                                                         withSuccess:outSuccess];
}

- (NSColor*)getColorPref:(const char*)prefName withSuccess:(BOOL*)outSuccess
{
  return [[PreferenceManager sharedInstanceDontCreate] getColorPref:prefName
                                                        withSuccess:outSuccess];
}

- (BOOL)getBooleanPref:(const char*)prefName withSuccess:(BOOL*)outSuccess
{
  return [[PreferenceManager sharedInstanceDontCreate] getBooleanPref:prefName
                                                          withSuccess:outSuccess];
}

- (int)getIntPref:(const char*)prefName withSuccess:(BOOL*)outSuccess
{
  return [[PreferenceManager sharedInstanceDontCreate] getIntPref:prefName
                                                      withSuccess:outSuccess];
}

- (void)setPref:(const char*)prefName toString:(NSString*)value
{
  [[PreferenceManager sharedInstanceDontCreate] setPref:prefName
                                               toString:value];
}

- (void)setPref:(const char*)prefName toColor:(NSColor*)value
{
  // make sure we have a color in the RGB colorspace
  NSColor*	rgbColor = [value colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
  
  int	redInt 		= (int)([rgbColor redComponent] * 255.0);
  int greenInt	= (int)([rgbColor greenComponent] * 255.0);
  int blueInt		= (int)([rgbColor blueComponent] * 255.0);

  NSString* colorString = [NSString stringWithFormat:@"#%02x%02x%02x", redInt, greenInt, blueInt];
  [self setPref:prefName toString:colorString];
}

- (void)setPref:(const char*)prefName toBoolean:(BOOL)value
{
  [[PreferenceManager sharedInstanceDontCreate] setPref:prefName
                                              toBoolean:value];
}

- (void)setPref:(const char*)prefName toInt:(int)value
{
  [[PreferenceManager sharedInstanceDontCreate] setPref:prefName
                                                  toInt:value];
}

- (void)clearPref:(const char*)prefName
{
  [[PreferenceManager sharedInstanceDontCreate] clearPref:prefName];
}

- (NSString*)localizedStringForKey:(NSString*)key
{
  return NSLocalizedStringFromTableInBundle(key, nil, [NSBundle bundleForClass:[self class]], @"");
}

- (NSString*)fontNameForGeckoFontName:(NSString*)geckoName
{
  return [[PreferenceManager sharedInstance] fontNameForGeckoFontName:geckoName];
}

@end

// Compatibility wrappers for third-party pref panes that use methods that we
// have renamed or modified. Should not be used for any new development.
@implementation PreferencePaneBase (LegacyCompatibility)

- (NSString*)getLocalizedString:(NSString*)key
{
  return [self localizedStringForKey:key];
}

@end

