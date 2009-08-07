/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* ***** BEGIN LICENSE BLOCK *****
 * Version: MPL 1.1/GPL 2.0/LGPL 2.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Original Code is mozilla.org code.
 *
 * The Initial Developer of the Original Code is
 * Netscape Communications Corporation.
 * Portions created by the Initial Developer are Copyright (C) 2002
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *   Simon Fraser <sfraser@netscape.com>
 *   Asaf Romano <mozilla.mano@sent.com>
 *
 * Alternatively, the contents of this file may be used under the terms of
 * either the GNU General Public License Version 2 or later (the "GPL"), or
 * the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
 * in which case the provisions of the GPL or the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of either the GPL or the LGPL, and not to allow others to
 * use your version of this file under the terms of the MPL, indicate your
 * decision by deleting the provisions above and replace them with the notice
 * and other provisions required by the GPL or the LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the MPL, the GPL or the LGPL.
 *
 * ***** END LICENSE BLOCK ***** */

#import "Appearance.h"

#import "GeckoPrefConstants.h"

@interface OrgMozillaCaminoPreferenceAppearance(Private)

- (void)setupFontRegionPopup;
- (void)updateFontPreviews;
- (void)loadFontPrefs;
- (void)saveFontPrefs;

- (NSMutableDictionary*)makeDictFromPrefsForFontType:(NSString*)fontType andRegion:(NSString*)regionCode;
- (NSMutableDictionary*)makeDefaultFontTypeDictFromPrefsForRegion:(NSString*)regionCode;
- (NSMutableDictionary*)makeFontSizesDictFromPrefsForRegion:(NSString*)regionCode;

- (NSMutableDictionary*)settingsForCurrentRegion;
- (NSString*)defaultProportionalFontTypeForCurrentRegion;

- (void)saveFontNamePrefsForRegion:(NSDictionary*)regionDict forFontType:(NSString*)fontType;
- (void)saveFontSizePrefsForRegion:(NSDictionary*)entryDict;
- (void)saveDefaultFontTypePrefForRegion:(NSDictionary*)entryDict;
- (void)saveAllFontPrefsForRegion:(NSDictionary*)regionDict;

- (BOOL)useMyFontsPref;
- (void)setUseMyFontsPref:(BOOL)checkboxState;

- (void)setupFontSamplesFromDict:(NSDictionary*)regionDict;
- (void)setupFontSampleOfType:(NSString*)fontType fromDict:(NSDictionary*)regionDict;

- (NSFont*)fontOfType:(NSString*)fontType fromDict:(NSDictionary*)regionDict;

- (void)setFontSampleOfType:(NSString*)fontType withFont:(NSFont*)font andDict:(NSDictionary*)regionDict;
- (void)saveFont:(NSFont*)font toDict:(NSMutableDictionary*)regionDict forType:(NSString*)fontType;

- (void)updateFontSampleOfType:(NSString*)fontType;
- (NSTextField*)fontSampleForType:(NSString*)fontType;
- (NSString*)fontSizeType:(NSString*)fontType;

- (IBAction)resetColorsToDefaults:(id)sender;
- (IBAction)resetFontsToDefaults:(id)sender;

@end

#pragma mark -

// We use instances of this class as the field editor, to allow us to catch
// |changeFont:| messages.

@interface SampleTextView : NSTextView
{
  id    mPrefPane;
}
- (void)setPrefPane:(id)inPrefPane;

@end

@implementation SampleTextView

- (void)setPrefPane:(id)inPrefPane
{
  mPrefPane = inPrefPane;
}

- (void)changeFont:(id)sender
{
  [mPrefPane changeFont:sender];
}

- (BOOL)fontManager:(id)theFontManager willIncludeFont:(NSString*)fontName
{
  return [mPrefPane fontManager:theFontManager willIncludeFont:fontName];
}

- (unsigned int)validModesForFontPanel:(NSFontPanel*)fontPanel
{
  return [mPrefPane validModesForFontPanel:fontPanel];
}

@end

#pragma mark -

@implementation OrgMozillaCaminoPreferenceAppearance

- (void)dealloc
{
  [mRegionMappingTable release];
  [mPropSampleFieldEditor release];
  [mMonoSampleFieldEditor release];

  [super dealloc];
}

- (id)initWithBundle:(NSBundle*)bundle
{
  self = [super initWithBundle:bundle];
  mFontButtonForEditor = nil;
  return self;
}

- (void)mainViewDidLoad
{
  // should save and restore this
  [[NSColorPanel sharedColorPanel] setContinuous:NO];

  [self setupFontRegionPopup];
}

- (void)willSelect
{
  BOOL gotPref;
  [mUnderlineLinksCheckbox setState:
      [self getBooleanPref:kGeckoPrefUnderlineLinks withSuccess:&gotPref]];
  [mUseMyColorsCheckbox setState:
      ![self getBooleanPref:kGeckoPrefUsePageColors withSuccess:&gotPref]];

  [mBackgroundColorWell     setColor:[self getColorPref:kGeckoPrefPageBackgroundColor  withSuccess:&gotPref]];
  [mTextColorWell           setColor:[self getColorPref:kGeckoPrefPageForegroundColor  withSuccess:&gotPref]];
  [mUnvisitedLinksColorWell setColor:[self getColorPref:kGeckoPrefLinkColor            withSuccess:&gotPref]];
  [mVisitedLinksColorWell   setColor:[self getColorPref:kGeckoPrefVisitedLinkColor     withSuccess:&gotPref]];
  
  [mUseMyFontsCheckbox setState:[self useMyFontsPref]];

  [self loadFontPrefs];
  [self updateFontPreviews];
}

- (void)didUnselect
{
  // time to save stuff
  [self saveFontPrefs];
}

- (void)tabView:(NSTabView*)tabView didSelectTabViewItem:(NSTabViewItem*)tabViewItem
{
}

- (void)setupFontRegionPopup
{
  NSBundle* prefBundle = [NSBundle bundleForClass:[self class]];
  NSString* resPath = [prefBundle pathForResource:@"RegionMapping" ofType:@"plist"];

  // We use the dictionaries in this array as temporary storage of font
  // values until the pane is unloaded, at which time they are saved.
  [mRegionMappingTable release];
  mRegionMappingTable = [[NSArray arrayWithContentsOfFile:resPath] retain];

  [self loadFontPrefs];

  [mFontRegionPopup removeAllItems];
  for (unsigned int i = 0; i < [mRegionMappingTable count]; i++) {
    NSDictionary* regionDict = [mRegionMappingTable objectAtIndex:i];
    [mFontRegionPopup addItemWithTitle:[regionDict objectForKey:@"region"]];
  }
}

- (IBAction)buttonClicked:(id)sender
{
  if (sender == mUnderlineLinksCheckbox)
    [self setPref:kGeckoPrefUnderlineLinks toBoolean:[sender state]];
  else if (sender == mUseMyColorsCheckbox)
    [self setPref:kGeckoPrefUsePageColors toBoolean:![sender state]];
}

- (IBAction)colorChanged:(id)sender
{
  const char* prefName = NULL;
  
  if (sender == mBackgroundColorWell)
    prefName = kGeckoPrefPageBackgroundColor;
  else if (sender == mTextColorWell)
    prefName = kGeckoPrefPageForegroundColor;
  else if (sender == mUnvisitedLinksColorWell)
    prefName = kGeckoPrefLinkColor;
  else if (sender == mVisitedLinksColorWell)
    prefName = kGeckoPrefVisitedLinkColor;

  if (prefName)
    [self setPref:prefName toColor:[sender color]];
}

- (IBAction)proportionalFontChoiceButtonClicked:(id)sender
{
  NSFontManager* fontManager = [NSFontManager sharedFontManager];

  NSString* defaultFontType = [self defaultProportionalFontTypeForCurrentRegion];

  NSFont* newFont = [[self fontSampleForType:defaultFontType] font];
  mFontButtonForEditor = mChooseProportionalFontButton;
  [fontManager setSelectedFont:newFont isMultiple:NO];
  [[fontManager fontPanel:YES] makeKeyAndOrderFront:self];
}

- (IBAction)monospaceFontChoiceButtonClicked:(id)sender
{
  NSFontManager* fontManager = [NSFontManager sharedFontManager];
  NSFont* newFont = [[self fontSampleForType:@"monospace"] font];
  mFontButtonForEditor = mChooseMonospaceFontButton;
  [fontManager setSelectedFont:newFont isMultiple:NO];
  [[fontManager fontPanel:YES] makeKeyAndOrderFront:self];
}

- (IBAction)useMyFontsButtonClicked:(id)sender
{
  [self setUseMyFontsPref:[sender state]];
}

- (IBAction)fontRegionPopupClicked:(id)sender
{
  // save the old values
  [self updateFontPreviews];
}

- (void)loadFontPrefs
{
  for (unsigned int i = 0; i < [mRegionMappingTable count]; i++) {
    NSMutableDictionary* regionDict = [mRegionMappingTable objectAtIndex:i];
    NSString* regionCode = [regionDict objectForKey:@"code"];
    
    /*
      For each region in the array, there is a dictionary of 
        {
          code   =
          region = (from localized strings file)

      to which we add here a sub-dictionary per font type, thus:
        
          serif = {
              fontfamily = Times-Regular
            }
          sans-serif = {
              fontfamily =
              missing  =      // set if a font is missing
            }
          monospace =   {
              fontfamily =
            }

      an entry that stores the default font type:

          defaultFontType = {
              type =
            }

      and an entry that stores font sizes:
          
          fontsize = {
            variable = 
            fixed = 
            minimum =   // optional
          }
      
        }
    */
    NSString* regionName = NSLocalizedStringFromTableInBundle(regionCode, @"RegionNames",
        [NSBundle bundleForClass:[self class]], @"");
    [regionDict setObject:regionName forKey:@"region"];
    
    NSMutableDictionary* serifDict = [self makeDictFromPrefsForFontType:@"serif" andRegion:regionCode];
    [regionDict setObject:serifDict forKey:@"serif"];

    NSMutableDictionary* sanssDict = [self makeDictFromPrefsForFontType:@"sans-serif" andRegion:regionCode];
    [regionDict setObject:sanssDict forKey:@"sans-serif"];

    NSMutableDictionary* monoDict = [self makeDictFromPrefsForFontType:@"monospace" andRegion:regionCode];
    [regionDict setObject:monoDict forKey:@"monospace"];

    // font sizes dict
    NSMutableDictionary* sizesDict = [self makeFontSizesDictFromPrefsForRegion:regionCode];
    [regionDict setObject:sizesDict forKey:@"fontsize"];

    // default font type dict
    NSMutableDictionary* defaultFontTypeDict = [self makeDefaultFontTypeDictFromPrefsForRegion:regionCode];
    [regionDict setObject:defaultFontTypeDict forKey:@"defaultFontType"];
  }
}

- (void)saveFontPrefs
{
  if (!mRegionMappingTable)
    return;

  for (unsigned int i = 0; i < [mRegionMappingTable count]; i++) {
    NSMutableDictionary* regionDict = [mRegionMappingTable objectAtIndex:i];
    [self saveAllFontPrefsForRegion:regionDict];
  }
}

#pragma mark -

- (NSMutableDictionary*)makeDictFromPrefsForFontType:(NSString*)fontType andRegion:(NSString*)regionCode
{
  NSMutableDictionary* fontDict = [NSMutableDictionary dictionaryWithCapacity:1];
  NSString* fontPrefName = [NSString stringWithFormat:@"font.name.%@.%@", fontType, regionCode];

  BOOL gotPref;
  NSString* fontName = [self getStringPref:[fontPrefName UTF8String] withSuccess:&gotPref];

  if (gotPref)
    [fontDict setObject:fontName forKey:@"fontfamily"];

  return fontDict;
}

- (NSMutableDictionary*)makeDefaultFontTypeDictFromPrefsForRegion:(NSString*)regionCode
{
  NSMutableDictionary* fontTypeDict = [NSMutableDictionary dictionaryWithCapacity:1];
  NSString* prefName = [NSString stringWithFormat:@"font.default.%@", regionCode];

  BOOL gotPref;
  NSString* fontType = [self getStringPref:[prefName UTF8String] withSuccess:&gotPref];

  if (gotPref)
    [fontTypeDict setObject:fontType forKey:@"type"];

  return fontTypeDict;
}

- (NSMutableDictionary*)makeFontSizesDictFromPrefsForRegion:(NSString*)regionCode
{
  NSMutableDictionary* fontDict = [NSMutableDictionary dictionaryWithCapacity:2];

  NSString* variableSizePref = [NSString stringWithFormat:@"font.size.variable.%@", regionCode];
  NSString* fixedSizePref = [NSString stringWithFormat:@"font.size.fixed.%@", regionCode];
  NSString* minSizePref = [NSString stringWithFormat:@"font.minimum-size.%@", regionCode];

  BOOL gotFixed, gotVariable, gotMinSize;
  int variableSize = [self getIntPref:[variableSizePref UTF8String] withSuccess:&gotVariable];
  int fixedSize = [self getIntPref:[fixedSizePref UTF8String] withSuccess:&gotFixed];
  int minSize = [self getIntPref:[minSizePref UTF8String] withSuccess:&gotMinSize];

  if (gotVariable)
    [fontDict setObject:[NSNumber numberWithInt:variableSize] forKey:@"variable"];
  
  if (gotFixed)
    [fontDict setObject:[NSNumber numberWithInt:fixedSize] forKey:@"fixed"];

  if (gotMinSize)
    [fontDict setObject:[NSNumber numberWithInt:minSize] forKey:@"minimum"];
    
  return fontDict;
}

- (NSMutableDictionary*)settingsForCurrentRegion
{
  int selectedRegion = [mFontRegionPopup indexOfSelectedItem];
  if (selectedRegion == -1)
    return nil;

  return [mRegionMappingTable objectAtIndex:selectedRegion];
}

- (NSString*)defaultProportionalFontTypeForCurrentRegion
{
  NSDictionary* regionDict = [self settingsForCurrentRegion];
  return [[regionDict objectForKey:@"defaultFontType"] objectForKey:@"type"];
}

- (void)saveFontNamePrefsForRegion:(NSDictionary*)regionDict forFontType:(NSString*)fontType
{
  NSString* regionCode = [regionDict objectForKey:@"code"];

  if (!regionDict || !fontType || !regionCode) return;

  NSDictionary* fontTypeDict = [regionDict objectForKey:fontType];
  
  NSString* fontName = [fontTypeDict objectForKey:@"fontfamily"];
  NSString* fontPrefName = [NSString stringWithFormat:@"font.name.%@.%@", fontType, regionCode];

  if (fontName) {
    [self setPref:[fontPrefName UTF8String] toString:fontName];
  }
  else {
    // If the preferences were reset to defaults, this key could be gone.
    [self clearPref:[fontPrefName UTF8String]];
  }
}

- (void)saveFontSizePrefsForRegion:(NSDictionary*)regionDict
{
  NSString* regionCode = [regionDict objectForKey:@"code"];
  
  NSString* variableSizePref = [NSString stringWithFormat:@"font.size.variable.%@", regionCode];
  NSString* fixedSizePref = [NSString stringWithFormat:@"font.size.fixed.%@", regionCode];
  NSString* minSizePref = [NSString stringWithFormat:@"font.minimum-size.%@", regionCode];

  NSDictionary* fontSizeDict = [regionDict objectForKey:@"fontsize"];

  int variableSize = [[fontSizeDict objectForKey:@"variable"] intValue];
  int fixedSize = [[fontSizeDict objectForKey:@"fixed"] intValue];
  int minSize = [[fontSizeDict objectForKey:@"minimum"] intValue];

  // If the preferences were reset to defaults, these keys could be gone.
  if (variableSize)
    [self setPref:[variableSizePref UTF8String] toInt:variableSize];
  else
    [self clearPref:[variableSizePref UTF8String]];

  if (fixedSize)
    [self setPref:[fixedSizePref UTF8String] toInt:fixedSize];
  else
    [self clearPref:[fixedSizePref UTF8String]];

  if (minSize)
    [self setPref:[minSizePref UTF8String] toInt:minSize];
  else
    [self clearPref:[minSizePref UTF8String]];
}

- (void)saveDefaultFontTypePrefForRegion:(NSDictionary*)regionDict
{
  NSString* regionCode = [regionDict objectForKey:@"code"];
  
  NSString* prefName = [NSString stringWithFormat:@"font.default.%@", regionCode];
  NSString* value = [[regionDict objectForKey:@"defaultFontType"] objectForKey:@"type"];

  // If the preferences were reset to defaults, this key could be gone.
  if (value)
    [self setPref:[prefName UTF8String] toString:value];
  else
    [self clearPref:[prefName UTF8String]];
}

- (void)saveAllFontPrefsForRegion:(NSDictionary*)regionDict
{
  [self saveFontNamePrefsForRegion:regionDict forFontType:@"serif"];
  [self saveFontNamePrefsForRegion:regionDict forFontType:@"sans-serif"];
  [self saveFontNamePrefsForRegion:regionDict forFontType:@"monospace"];
    
  [self saveDefaultFontTypePrefForRegion:regionDict];
  [self saveFontSizePrefsForRegion:regionDict];
}

// The exposed "Use My Fonts" pref has reverse logic from the internal pref 
// (when mUseMyFontsCheckbox == 1, use_document_fonts == 0).  These private accessor methods allow code
// elsewhere to use the exposed pref's logic.
- (BOOL)useMyFontsPref
{
  BOOL gotPref;
  return [self getIntPref:kGeckoPrefUsePageFonts withSuccess:&gotPref] == 0;
}

- (void)setUseMyFontsPref:(BOOL)checkboxState
{
  int useDocumentFonts = checkboxState ? 0 : 1;
  [self setPref:kGeckoPrefUsePageFonts toInt:useDocumentFonts];
}

#pragma mark -

- (void)saveFont:(NSFont*)font toDict:(NSMutableDictionary*)regionDict forType:(NSString*)fontType
{
  NSMutableDictionary* fontTypeDict = [regionDict objectForKey:fontType];
  NSMutableDictionary* fontSizeDict = [regionDict objectForKey:@"fontsize"];
  
  if (font)
  {
    // clear any missing flag
    [fontTypeDict removeObjectForKey:@"missing"];

    NSString* fontNameToSave = [font familyName];

    // XXX Special-case Osaka-Mono as part of bug 391076.
    // When using Osaka as a monospace font, we must use its exact font name (Osaka-Mono),
    // since the family name (just Osaka) will be incorrect in this case.
    if ([fontType isEqualToString:@"monospace"] && [[font fontName] isEqualToString:@"Osaka"])
      fontNameToSave = @"Osaka-Mono";

    [fontTypeDict setObject:fontNameToSave forKey:@"fontfamily"];
    [fontSizeDict setObject:[NSNumber numberWithInt:(int)[font pointSize]] forKey:[self fontSizeType:fontType]];
  }
}

// Returns nil if the font could not be found.
- (NSFont*)fontOfType:(NSString*)fontType fromDict:(NSDictionary*)regionDict
{
  NSDictionary* fontTypeDict = [regionDict objectForKey:fontType];
  NSDictionary* fontSizeDict = [regionDict objectForKey:@"fontsize"];

  NSString* fontFamilyFromPrefs = [fontTypeDict objectForKey:@"fontfamily"];
  int fontSize = [[fontSizeDict objectForKey:[self fontSizeType:fontType]] intValue];

  NSFont* returnFont = nil;

  if (fontFamilyFromPrefs) {
    returnFont = [NSFont fontWithName:[self fontNameForGeckoFontName:fontFamilyFromPrefs] size:fontSize];
    if (!returnFont)
      returnFont = [[NSFontManager sharedFontManager] fontWithFamily:fontFamilyFromPrefs traits:0 weight:5 size:fontSize];
    // Some fonts are not specified as a family name in prefs, but a single face
    // (e.g. Osaka-Mono). If we still could not create a font, try to use the pref
    // value as a face name instead of family name.
    if (!returnFont)
      returnFont = [NSFont fontWithName:fontFamilyFromPrefs size:fontSize];
  }
  else {
    returnFont = ([fontType isEqualToString:@"monospace"]) ? [NSFont userFixedPitchFontOfSize:14.0]
                                                           : [NSFont userFontOfSize:16.0];
  }

  return returnFont;
}

- (void)setupFontSamplesFromDict:(NSDictionary*)regionDict
{
  // For proportional, show either serif or sans-serif font,
  // per region's default-font-type (font.default.%regionCode% pref).
  NSString* defaultFontType = [[regionDict objectForKey:@"defaultFontType"] objectForKey:@"type"];
  [self setupFontSampleOfType:defaultFontType fromDict:regionDict];
  [self setupFontSampleOfType:@"monospace" fromDict:regionDict];
}

- (void)setupFontSampleOfType:(NSString*)fontType fromDict:(NSDictionary*)regionDict
{
  NSFont* foundFont = [self fontOfType:fontType fromDict:regionDict];
  [self setFontSampleOfType:fontType withFont:foundFont andDict:regionDict];
}

// TODO: This code modifies sub-dictionaries of regionDict, which works only
// because they happen to have been constructed as mutableDictionaries. This
// API (and likely others in this class) should be re-worked to either remove or
// enforce that assumption.
- (void)setFontSampleOfType:(NSString*)fontType withFont:(NSFont*)font andDict:(NSDictionary*)regionDict
{
  NSMutableDictionary* fontTypeDict = [regionDict objectForKey:fontType];

  NSTextField* sampleCell = [self fontSampleForType:fontType];
  NSString* displayString = nil;

  // Font may be nil here, in which case the font is missing, and we construct
  // a string to display from the dict.
  if (font == nil) {
    if (regionDict) {
      NSDictionary* fontSizeDict = [regionDict objectForKey:@"fontsize"];
      NSString* fontName = [fontTypeDict objectForKey:@"fontfamily"];
      int fontSize = [[fontSizeDict objectForKey:[self fontSizeType:fontType]] intValue];

      displayString = [NSString stringWithFormat:@"%@, %dpx %@", fontName, fontSize, [self localizedStringForKey:@"Missing"]];
      font = [NSFont userFontOfSize:14.0];

      // Set the missing flag in the dict.
      if (![fontTypeDict objectForKey:@"missing"] || ![[fontTypeDict objectForKey:@"missing"] boolValue])
        [fontTypeDict setObject:[NSNumber numberWithBool:YES] forKey:@"missing"];
    }
    else {
      // should never happen
      displayString = [self localizedStringForKey:@"FontMissing"];
      font = [NSFont userFontOfSize:16.0];
    }
  }
  else {
    // The fact that font != nil merely indicates that the font specified in prefs 
    // is not missing on the system.  There could actually be no font pref set for
    // this region and type, in which case |font| is only a default value.
    // Check if there is an actual value set in prefs.
    BOOL fontIsSpecifiedInPrefs = ([fontTypeDict objectForKey:@"fontfamily"] != nil);

    if (fontIsSpecifiedInPrefs) {
      NSString* localizedFamilyName = [[NSFontManager sharedFontManager] localizedNameForFamily:[font familyName] face:nil];
      displayString = [NSString stringWithFormat:@"%@, %dpx", localizedFamilyName, (int)[font pointSize]];
    }
    else {
      displayString = [self localizedStringForKey:@"NoFontSelected"];
    }

    // Make sure we don't have a "missing" entry.
    [fontTypeDict removeObjectForKey:@"missing"];
  }

  [sampleCell setFont:font];
  [sampleCell setStringValue:displayString];
}

- (void)updateFontSampleOfType:(NSString*)fontType
{
  NSMutableDictionary* regionDict = [self settingsForCurrentRegion];
  if (!regionDict) return;

  NSTextField* sampleCell = [self fontSampleForType:fontType];
  NSFont* sampleFont = [[NSFontManager sharedFontManager] convertFont:[sampleCell font]];

  // Save the font in the dictionaries...
  [self saveFont:sampleFont toDict:regionDict forType:fontType];

  // Update the font sample.
  // Even though we know the new font we actually re-fetch it, as some fonts are
  // actually modified when saving, to account for Gecko/Cocoa naming conflicts.
  NSFont* fontAsSaved = [self fontOfType:fontType fromDict:regionDict];
  [self setFontSampleOfType:fontType withFont:fontAsSaved andDict:regionDict];
}

- (NSTextField*)fontSampleForType:(NSString*)fontType
{
  if ([fontType isEqualToString:@"serif"] || [fontType isEqualToString:@"sans-serif"])
    return mFontSampleProportional;

  if ([fontType isEqualToString:@"monospace"])
    return mFontSampleMonospace;

  return nil;
}

- (NSString*)fontSizeType:(NSString*)fontType
{
  if ([fontType isEqualToString:@"monospace"])
    return @"fixed";

  return @"variable";
}

- (void)updateFontPreviews
{
  NSDictionary* regionDict = [self settingsForCurrentRegion];
  if (!regionDict) return;

  NSString* defaultFontType = [self defaultProportionalFontTypeForCurrentRegion];
  // Make sure the "proportional" label matches.
  NSString* propLabelString = [NSString stringWithFormat:[self localizedStringForKey:@"ProportionalLabelFormat"],
                                                         [self localizedStringForKey:defaultFontType]];
  [mProportionalSampleLabel setStringValue:propLabelString];
  
  NSString* sublabelValue = [self localizedStringForKey:[defaultFontType stringByAppendingString:@"_note"]];
  [mProportionalSubLabel setStringValue:sublabelValue];

  NSString* noteFontExample = [defaultFontType isEqualToString:@"serif"] ? @"Times" : @"Helvetica";
  [mProportionalSubLabel setFont:[[NSFontManager sharedFontManager] fontWithFamily:noteFontExample
                                                                            traits:0
                                                                            weight:5 /* normal weight */
                                                                              size:[[mProportionalSubLabel font] pointSize]]];

  [self setupFontSamplesFromDict:regionDict];
}

#pragma mark -

const int kDefaultFontSerifTag = 0;
const int kDefaultFontSansSerifTag = 1;

- (IBAction)showAdvancedFontsDialog:(id)sender
{
  NSDictionary* regionDict = [self settingsForCurrentRegion];
  if (!regionDict) return;

  NSString* advancedLabel = [NSString stringWithFormat:[self localizedStringForKey:@"AdditionalFontsLabelFormat"],
                                                       [regionDict objectForKey:@"region"]];
  [mAdvancedFontsLabel setStringValue:advancedLabel];
  
  // set up min size popup
  int itemIndex = 0;
  NSMutableDictionary* fontSizeDict = [regionDict objectForKey:@"fontsize"];
  NSNumber* minSize = [fontSizeDict objectForKey:@"minimum"];
  if (minSize) {
    itemIndex = [mMinFontSizePopup indexOfItemWithTag:[minSize intValue]];
    if (itemIndex == -1)
      itemIndex = 0;
  }
  [mMinFontSizePopup selectItemAtIndex:itemIndex];
  
  // set up default font radio buttons (default to serif)
  NSString* defaultFontType = [self defaultProportionalFontTypeForCurrentRegion];
  [mDefaultFontMatrix selectCellWithTag:([defaultFontType isEqualToString:@"sans-serif"] ? kDefaultFontSansSerifTag : kDefaultFontSerifTag)];
  
  mFontPanelWasVisible = [[NSFontPanel sharedFontPanel] isVisible];
  [[NSFontPanel sharedFontPanel] orderOut:nil];
  
  [NSApp beginSheet:mAdvancedFontsDialog
     modalForWindow:[mTabView window] // any old window accessor
      modalDelegate:self
     didEndSelector:@selector(advancedFontsSheetDidEnd:returnCode:contextInfo:)
        contextInfo:NULL];
}

- (IBAction)advancedFontsDone:(id)sender
{
  // save settings
  NSDictionary* regionDict = [self settingsForCurrentRegion];
  if (!regionDict) return;

  int minSize = [[mMinFontSizePopup selectedItem] tag];
  // A value of 0 indicates "none"; we'll clear the pref on save.
  NSMutableDictionary* fontSizeDict = [regionDict objectForKey:@"fontsize"];
  [fontSizeDict setObject:[NSNumber numberWithInt:(int)minSize] forKey:@"minimum"];

  // Save the default font type.
  NSMutableDictionary* defaultFontTypeDict = [regionDict objectForKey:@"defaultFontType"];
  NSString* defaultFontType = ([[mDefaultFontMatrix selectedCell] tag] == kDefaultFontSerifTag) ? @"serif" : @"sans-serif";
  [defaultFontTypeDict setObject:defaultFontType forKey:@"type"];
  
  [mAdvancedFontsDialog orderOut:self];
  [NSApp endSheet:mAdvancedFontsDialog];

  // Apply the changes for the current region.
  [self saveAllFontPrefsForRegion:regionDict];

  [self updateFontPreviews];

  if (mFontPanelWasVisible)
     [[NSFontPanel sharedFontPanel] makeKeyAndOrderFront:self];    
}

- (IBAction)resetToDefaults:(id)sender {
  NSString* selectedTabViewIdentifier = [[mTabView selectedTabViewItem] identifier];
  if ([selectedTabViewIdentifier isEqual:@"colors"]) {
    [self resetColorsToDefaults:sender];
  }
  else if ([selectedTabViewIdentifier isEqual:@"fonts"]) {
    [self resetFontsToDefaults:sender];
  }
}

// Reset the "Colors and Links" tab to application factory defaults.
- (IBAction)resetColorsToDefaults:(id)sender
{
  [self clearPref:kGeckoPrefUnderlineLinks];
  [self clearPref:kGeckoPrefUsePageColors];
  [self clearPref:kGeckoPrefPageBackgroundColor];
  [self clearPref:kGeckoPrefPageForegroundColor];
  [self clearPref:kGeckoPrefLinkColor];
  [self clearPref:kGeckoPrefVisitedLinkColor];
  
  // update UI
  int state;
  state = [self getBooleanPref:kGeckoPrefUnderlineLinks withSuccess:NULL] ? NSOnState : NSOffState;
  [mUnderlineLinksCheckbox setState:state];
  state = [self getBooleanPref:kGeckoPrefUsePageColors withSuccess:NULL] ? NSOffState : NSOnState;
  [mUseMyColorsCheckbox setState:state];
  
  [mBackgroundColorWell setColor:[self getColorPref:kGeckoPrefPageBackgroundColor withSuccess:NULL]];
  [mTextColorWell setColor:[self getColorPref:kGeckoPrefPageForegroundColor withSuccess:NULL]];
  [mUnvisitedLinksColorWell setColor:[self getColorPref:kGeckoPrefLinkColor withSuccess:NULL]];
  [mVisitedLinksColorWell setColor:[self getColorPref:kGeckoPrefVisitedLinkColor withSuccess:NULL]];
}

// Reset the Fonts tab to application factory defaults.
- (IBAction)resetFontsToDefaults:(id)sender
{
  // Clear all the preferences for the various font regions.
  for (unsigned int i = 0; i < [mRegionMappingTable count]; i++) {
    NSMutableDictionary* regionDict = [mRegionMappingTable objectAtIndex:i];
    // NSString* regionCode = [regionDict objectForKey:@"code"];
    
    // For each region, we reset the dictionaries to be empty.
    [regionDict setObject:[NSMutableDictionary dictionary] forKey:@"serif"];
    [regionDict setObject:[NSMutableDictionary dictionary] forKey:@"sans-serif"];
    [regionDict setObject:[NSMutableDictionary dictionary] forKey:@"monospace"];
    [regionDict setObject:[NSMutableDictionary dictionary] forKey:@"fontsize"];
    [regionDict setObject:[NSMutableDictionary dictionary] forKey:@"defaultFontType"];
  }
  
  [self clearPref:kGeckoPrefUsePageFonts];

  // Commit the changes:
  // First, we clear the preferences by saving them. This clears the values that are returned by
  // -[self getPref:].
  [self saveFontPrefs];
  // Since the rest of the Appearance code doesn't access the prefs by getPref directly,
  // we need to re-store the default preference values in the region dicts.
  [self loadFontPrefs];
  
  // Update the UI. Order is important here -- syncing the font panel depends on the
  // font previews being correct.
  [self updateFontPreviews];
  [mUseMyFontsCheckbox setState:[self useMyFontsPref]];
}

- (void)advancedFontsSheetDidEnd:(NSWindow*)sheet returnCode:(int)returnCode contextInfo:(void*)contextInfo
{
}

@end

@implementation OrgMozillaCaminoPreferenceAppearance (FontManagerDelegate)

- (id)fieldEditorForObject:(id)inObject
{
  if (inObject == mFontSampleProportional) {
    if (!mPropSampleFieldEditor) {
      SampleTextView* propFieldEditor = [[SampleTextView alloc] initWithFrame:[inObject bounds]];
      [propFieldEditor setPrefPane:self];
      [propFieldEditor setFieldEditor:YES];
      [propFieldEditor setDelegate:inObject];
      mPropSampleFieldEditor = propFieldEditor;
    }
      
    return mPropSampleFieldEditor;
  }
  else if (inObject == mFontSampleMonospace) {
    if (!mMonoSampleFieldEditor) {
      SampleTextView* monoFieldEditor = [[SampleTextView alloc] initWithFrame:[inObject bounds]];
      [monoFieldEditor setPrefPane:self];
      [monoFieldEditor setFieldEditor:YES];
      [monoFieldEditor setDelegate:inObject];
      mMonoSampleFieldEditor = monoFieldEditor;
    }
    
    return mMonoSampleFieldEditor;
  }
  
  return nil;
}

- (void)changeFont:(id)sender
{
  // Ignore font panel changes if the advanced panel is up.
  if ([mAdvancedFontsDialog isVisible])
    return;
  
  NSDictionary* regionDict = [self settingsForCurrentRegion];

  if (mFontButtonForEditor == mChooseProportionalFontButton) {
    NSString* fontType = [self defaultProportionalFontTypeForCurrentRegion];
    [self updateFontSampleOfType:fontType];
    [self saveFontNamePrefsForRegion:regionDict forFontType:fontType];
  }
  else if (mFontButtonForEditor == mChooseMonospaceFontButton) {
    [self updateFontSampleOfType:@"monospace"];
    [self saveFontNamePrefsForRegion:regionDict forFontType:@"monospace"];
  }
  
  [self saveFontSizePrefsForRegion:regionDict];
}

- (BOOL)fontManager:(id)theFontManager willIncludeFont:(NSString*)fontName
{
  // Filter out fonts for the selected language.
  return YES;
}

- (unsigned int)validModesForFontPanel:(NSFontPanel*)fontPanel
{
  // Hide the font face panel.
  return (NSFontPanelStandardModesMask & ~NSFontPanelFaceModeMask);
}

@end
