/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "NSURL+Utils.h"


@implementation NSURL (CaminoExtensions)

+ (NSURL*)decodeLocalFileURL:(NSURL*)url
{
  NSString* urlPathString = [url path];
  NSString* ext = [[urlPathString pathExtension] lowercaseString];
  OSType fileType = NSHFSTypeCodeFromFileType(NSHFSTypeOfFile(urlPathString));

  if ([ext isEqualToString:@"caminobookmark"])
    return [NSURL URLFromPlist:urlPathString];
  if ([ext isEqualToString:@"url"] || fileType == 'LINK')
    return [NSURL URLFromIEURLFile:urlPathString];
  if ([ext isEqualToString:@"webloc"] || [ext isEqualToString:@"ftploc"] ||
      [ext isEqualToString:@"fileloc"] || fileType == 'ilht' ||
      fileType == 'ilft' || fileType == 'ilfi')
  {
    return [NSURL URLFromInetloc:urlPathString];
  }

  return url;
}

+(NSURL*)URLFromPlist:(NSString*)inFile
{
  if (!inFile)
    return nil;
  NSDictionary* plist =
      [[[NSDictionary alloc] initWithContentsOfFile:inFile] autorelease];
  return [NSURL URLWithString:[plist objectForKey:@"URL"]];
}

//
// Reads the URL from a .webloc/.ftploc/.fileloc file.
// Returns the URL, or nil on failure.
//
+(NSURL*)URLFromInetloc:(NSString*)inFile
{
  FSRef ref;
  NSURL *ret = nil;
  
  if (inFile && FSPathMakeRef((UInt8 *)[inFile fileSystemRepresentation], &ref, NULL) == noErr) {
    short resRef;
    
    resRef = FSOpenResFile(&ref, fsRdPerm);
    
    if (resRef != -1) { // Has resouce fork.
      Handle urlResHandle;
      
      if ((urlResHandle = Get1Resource('url ', 256))) { // Has 'url ' resource with ID 256.
        long size;
        
        size = GetMaxResourceSize(urlResHandle);
        NSString *urlString = [[[NSString alloc] initWithBytes:(void *)*urlResHandle
                                                        length:size
                                                      encoding:NSMacOSRomanStringEncoding]  // best guess here
                               autorelease];
        ret = [NSURL URLWithString:urlString];
      }
      
      CloseResFile(resRef);
    }

    if (!ret) { // Look for valid plist data.
      ret = [NSURL URLFromPlist:inFile];
    }
  }
  
  return ret;
}

//
// Reads the URL from a .url file.
// Returns the URL or nil on failure.
//
+(NSURL*)URLFromIEURLFile:(NSString*)inFile
{
  NSURL *ret = nil;
  
  // Is this really an IE .url file?
  if (inFile) {
    NSCharacterSet *newlines = [NSCharacterSet characterSetWithCharactersInString:@"\r\n"];
    NSString *fileString = [NSString stringWithContentsOfFile:inFile
                                                     encoding:NSWindowsCP1252StringEncoding  // best guess here
                                                        error:nil];
    NSScanner *scanner = [NSScanner scannerWithString:fileString];
    [scanner scanUpToString:@"[InternetShortcut]" intoString:nil];
    
    if ([scanner scanString:@"[InternetShortcut]" intoString:nil]) {
      // Scan each non-empty line in this section. We don't need to explicitly scan the newlines or
      // whitespace because NSScanner ignores these by default.
      NSString *line;
      
      while ([scanner scanUpToCharactersFromSet:newlines intoString:&line]) {
        if ([line hasPrefix:@"URL="]) {
          ret = [NSURL URLWithString:[line substringFromIndex:4]];
          break;
        }
        else if ([line hasPrefix:@"["]) {
          // This is the start of a new section, so if we haven't found an URL yet, we should bail.
          break;
        }
      }
    }
  }
  
  return ret;
}

@end
