/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*-
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "GetURLCommand.h"
#import <AppKit/AppKit.h>

#import "MainController.h"
#import "NSString+Utils.h"
#import "NSURL+Utils.h"

static NSString* const kMainControllerIsInitializedKey = @"initialized";

@implementation GetURLCommand

- (id)performDefaultImplementation 
{
  MainController* mainController = (MainController*)[NSApp delegate];

  // We can get here before the application is fully initialized and the previous
  // session is restored.  We want to avoid opening URLs before that happens.
  if ([mainController isInitialized]) {
    NSString* urlString = [self directParameter];
    if ([urlString length] == 0) {
      [[NSScriptCommand currentCommand] setScriptErrorNumber:NSRequiredArgumentsMissingScriptError];
      [[NSScriptCommand currentCommand] setScriptErrorString:@"The location to open is missing."];
      return nil;
    }
    // If the string has a shell tilde-prefix, standardize the path.
    if ([urlString hasPrefix:@"~"])
      urlString = [urlString stringByStandardizingPath];

    NSURL* url = [NSURL URLWithString:urlString];
    NSString* urlScheme = [url scheme];
    // NSURL will fail to generate schemes from URLs that are not strictly 
    // RFC-compliant, which would allow, e.g., a creative mailto: to bypass
    // the supported protocol check below.  If NSURL does not provide a scheme,
    // fall back to a manual attempt to determine a scheme.
    //
    // Ensure that the string contains a colon (thus the string before the
    // colon is a probable scheme) and that the probable scheme does not
    // contain a slash (which could occur if the colon were in a filename or
    // path component of a POSIX file or a website-like string).
    if (!urlScheme) {
      unsigned int colonLocation = [urlString rangeOfString:@":"].location;
      if ((colonLocation != NSNotFound) &&
          ([urlString rangeOfString:@"/"
                            options:0
                              range:NSMakeRange(0, colonLocation)].location == NSNotFound))
      {
        urlScheme = [urlString substringToIndex:colonLocation];
      }
    }
    urlScheme = [urlScheme lowercaseString];
    // Setting Camino as the default app for protocols we do not handle creates
    // an infinite loop when those URIs are opened; avoid that by only handling
    // supported protocols.  However, we want to make sure to allow
    // website-like strings (www.apple.com) and raw POSIX paths to bypass the
    // protocol check so that they still load (see bug 629850); these will have
    // null schemes and will fail the scheme check unless explicitly excluded.
    if (urlScheme && !([urlScheme isEqualToString:@"http"] ||
                       [urlScheme isEqualToString:@"https"] ||
                       [urlScheme isEqualToString:@"ftp"] ||
                       [urlScheme isEqualToString:@"file"] ||
                       [urlScheme isEqualToString:@"data"] ||
                       [urlScheme isEqualToString:@"about"] ||
                       [urlScheme isEqualToString:@"view-source"]))
    {
      return nil;
    }
    NSString* referrer = [[self evaluatedArguments] objectForKey:@"referrer"];
    BOOL backgroundLoad = [[[self evaluatedArguments] objectForKey:@"background"] boolValue];
    if ([url isFileURL])
      urlString = [[NSURL decodeLocalFileURL:url] absoluteString];
    [mainController showURL:urlString
              usingReferrer:referrer
           loadInBackground:backgroundLoad];
  }
  else {
    [self suspendExecution];
    [mainController addObserver:self 
                     forKeyPath:kMainControllerIsInitializedKey
                        options:NSKeyValueObservingOptionNew 
                        context:NULL];
  }
  return nil;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
  if ([keyPath isEqualToString:kMainControllerIsInitializedKey] && [[change objectForKey:NSKeyValueChangeNewKey] boolValue]) {
    [object removeObserver:self forKeyPath:kMainControllerIsInitializedKey];
    // explicitly perform the command's default implementation again, 
    // since |resumeExecutionWithResult:| will not.
    id result = [self executeCommand];
    [self resumeExecutionWithResult:result];
  }
}

- (void)dealloc
{
  [super dealloc];
}

@end
