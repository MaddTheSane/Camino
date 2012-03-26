/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*-
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "ToolbarScriptItem.h"

NSString * const kScriptItemIdentifierPrefix = @"ScriptItem:";

@implementation ToolbarScriptItem

// Returns an array of toolbar item identifiers for the script items available.
+ (NSArray *)scriptItemIdentifiers
{
  // Get script paths.
  NSString *libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
  NSString *appName = [[[NSBundle mainBundle] infoDictionary] valueForKey:@"CFBundleName"];
  NSString *scriptDirPath = [[libraryPath stringByAppendingPathComponent:@"Scripts/Applications"] stringByAppendingPathComponent:appName];

  NSMutableArray *identifiers = [[[NSMutableArray alloc] init] autorelease];
  NSDirectoryEnumerator *dirEnum = [[NSFileManager defaultManager] enumeratorAtPath:scriptDirPath];
  id eachRelativePath;
  // -nextObject yields relative paths.  We need absolute paths.
  while ((eachRelativePath = [dirEnum nextObject])) {
    NSString *eachAbsolutePath = [scriptDirPath stringByAppendingPathComponent:eachRelativePath];
    NSString *eachPathExtension = [eachAbsolutePath pathExtension];
    if ([eachPathExtension isEqualToString:@"scpt"] ||
        [eachPathExtension isEqualToString:@"applescript"] ||
        [eachPathExtension isEqualToString:@"scptd"] ||
        [eachPathExtension isEqualToString:@"app"]) {
      [identifiers addObject:[NSString stringWithFormat:@"%@%@", kScriptItemIdentifierPrefix, eachAbsolutePath]];
    }
    // Don't look inside script bundles or application bundles.
    if ([eachPathExtension isEqualToString:@"scptd"] ||
        [eachPathExtension isEqualToString:@"app"]) {
      [dirEnum skipDescendents];
    }
  }

  return identifiers;
}


- (id)initWithItemIdentifier:(NSString *)ident
{
  // Sanity check: Make sure this is a valid ToolbarScriptItem identifier.
  if ([ident hasPrefix:kScriptItemIdentifierPrefix] && [super initWithItemIdentifier:ident]) {
    [self setLabel:[self scriptName]];
    [self setPaletteLabel:[NSString stringWithFormat:@"%@: %@", NSLocalizedString(@"ScriptItem", nil), [self scriptName]]];
    [self setToolTip:[NSString stringWithFormat:NSLocalizedString(@"ScriptItemToolTipFormat", nil), [self scriptName]]];
    [self setImage:[[NSWorkspace sharedWorkspace] iconForFile:[self scriptPath]]];
    [self setTarget:self];
    [self setAction:@selector(runScript:)];

    return self;
  }
  return nil;
}

- (NSString *)scriptPath
{
  return [[self itemIdentifier] substringFromIndex:[kScriptItemIdentifierPrefix length]];
}

- (NSString *)scriptName
{
  return [[[self scriptPath] lastPathComponent] stringByDeletingPathExtension];
}

- (void)runScript:(id)sender
{
  NSDictionary *errDict = nil;
  
  // Load the script.
  NSAppleScript *script = [[[NSAppleScript alloc] initWithContentsOfURL:[NSURL fileURLWithPath:[self scriptPath]] error:&errDict] autorelease];
  if (!script) {
    NSBeep();
    NSLog(@"Error loading script at %@: %@", [self scriptPath], [errDict valueForKey:NSAppleScriptErrorMessage]);
    return;
  }
  
  // Run the script.
  NSAppleEventDescriptor *result = [script executeAndReturnError:&errDict];
  if (!result && [[errDict objectForKey:NSAppleScriptErrorNumber] intValue] != userCanceledErr) {
    NSBeep();
    NSLog(@"Error running script at %@: %@", [self scriptPath], [errDict valueForKey:NSAppleScriptErrorMessage]);
  }
}

@end
