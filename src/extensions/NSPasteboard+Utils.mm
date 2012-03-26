/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "NSPasteboard+Utils.h"
#import "NSURL+Utils.h"
#import "NSString+Utils.h"

NSString* const kCorePasteboardFlavorType_url  = @"CorePasteboardFlavorType 0x75726C20"; // 'url '  url
NSString* const kCorePasteboardFlavorType_urln = @"CorePasteboardFlavorType 0x75726C6E"; // 'urln'  title
NSString* const kCorePasteboardFlavorType_urld = @"CorePasteboardFlavorType 0x75726C64"; // 'urld' URL description

NSString* const kCaminoBookmarkListPBoardType = @"MozBookmarkType"; // list of Camino bookmark UIDs
NSString* const kWebURLsWithTitlesPboardType  = @"WebURLsWithTitlesPboardType"; // Safari-compatible URL + title arrays

@interface NSPasteboard(ChimeraPasteboardURLUtilsPrivate)

- (NSString*)cleanedURLStringFromPasteboardType:(NSString*)aType;
- (NSString*)cleanedTitleStringFromPasteboardType:(NSString*)aType;

@end

@implementation NSPasteboard(ChimeraPasteboardURLUtilsPrivate)

//
// Utility method to ensure strings we're using in |containsURLData|
// and |getURLs:andTitles| are free of internal control characters
// and leading/trailing whitespace
//
- (NSString*)cleanedURLStringFromPasteboardType:(NSString*)aType
{
  NSString* cleanString = [[self stringForType:aType]
                           stringByRemovingCharactersInSet:[NSCharacterSet controlCharacterSet]];
  return [cleanString stringByTrimmingWhitespace];
}

- (NSString*)cleanedTitleStringFromPasteboardType:(NSString*)aType
{
  NSString* cleanString = [[self stringForType:aType]
                           stringByReplacingCharactersInSet:[NSCharacterSet controlCharacterSet]
                                                 withString:@" "];
  return [cleanString stringByTrimmingWhitespace];
}

@end

@implementation NSPasteboard(ChimeraPasteboardURLUtils)

- (int)declareURLPasteboardWithAdditionalTypes:(NSArray*)additionalTypes owner:(id)newOwner
{
  NSArray* allTypes = [additionalTypes arrayByAddingObjectsFromArray:
                            [NSArray arrayWithObjects:
                                        kWebURLsWithTitlesPboardType,
                                        NSURLPboardType,
                                        NSStringPboardType,
                                        kCorePasteboardFlavorType_url,
                                        kCorePasteboardFlavorType_urln,
                                        nil]];
	return [self declareTypes:allTypes owner:newOwner];
}

//
// Copy a single URL (with an optional title) to the clipboard in all relevant
// formats. Convenience method for clients that can only ever deal with one
// URL and shouldn't have to build up the arrays for setURLs:withTitles:.
//
- (void)setDataForURL:(NSString*)url title:(NSString*)title
{
  NSArray* urlList = [NSArray arrayWithObject:url];
  NSArray* titleList = nil;
  if (title)
    titleList = [NSArray arrayWithObject:title];
  
  [self setURLs:urlList withTitles:titleList];
}

//
// Copy a set of URLs, each of which may have a title, to the pasteboard
// using all the available formats.
// The title array should be nil, or must have the same length as the URL array.
//
- (void)setURLs:(NSArray*)inUrls withTitles:(NSArray*)inTitles
{
  unsigned int urlCount = [inUrls count];

  // Best format that we know about is Safari's URL + title arrays - build these up
  if (!inTitles) {
    NSMutableArray* tmpTitleArray = [NSMutableArray arrayWithCapacity:urlCount];
    for (unsigned int i = 0; i < urlCount; ++i)
      [tmpTitleArray addObject:[inUrls objectAtIndex:i]];
    inTitles = tmpTitleArray;
  }

  NSMutableArray* filePaths = [NSMutableArray array];
  for (unsigned int i = 0; i < urlCount; ++i) {
    NSURL* url = [NSURL URLWithString:[inUrls objectAtIndex:i]];
    if ([url isFileURL] && [[NSFileManager defaultManager] fileExistsAtPath:[url path]])
      [filePaths addObject:[url path]];
  }
  if ([filePaths count] > 0) {
    [self addTypes:[NSArray arrayWithObject:NSFilenamesPboardType] owner:nil];
    [self setPropertyList:filePaths forType:NSFilenamesPboardType];
  }

  NSMutableArray* clipboardData = [NSMutableArray array];
  [clipboardData addObject:[NSArray arrayWithArray:inUrls]];
  [clipboardData addObject:inTitles];

  [self setPropertyList:clipboardData forType:kWebURLsWithTitlesPboardType];

  if (urlCount == 1) {
    NSString* url = [inUrls objectAtIndex:0];
    NSString* title = [inTitles objectAtIndex:0];

    [[NSURL URLWithString:url] writeToPasteboard:self];
    [self setString:url forType:NSStringPboardType];

    const char* tempCString = [url UTF8String];
    [self setData:[NSData dataWithBytes:tempCString length:strlen(tempCString)] forType:kCorePasteboardFlavorType_url];

    if (inTitles)
      tempCString = [title UTF8String];
    [self setData:[NSData dataWithBytes:tempCString length:strlen(tempCString)] forType:kCorePasteboardFlavorType_urln];
  }
  else if (urlCount > 1)
  {
    // With multiple URLs there aren't many other formats we can use
    // Just write a string of each URL (ignoring titles) on a separate line
    [self setString:[inUrls componentsJoinedByString:@"\n"] forType:NSStringPboardType];

    // but we have to put something in the carbon style flavors, otherwise apps will think
    // there is data there, but get nothing

    NSString* firstURL   = [inUrls objectAtIndex:0];
    NSString* firstTitle = [inTitles objectAtIndex:0];

    const char* tempCString = [firstURL UTF8String];
    [self setData:[NSData dataWithBytes:tempCString length:strlen(tempCString)] forType:kCorePasteboardFlavorType_url];

    tempCString = [firstTitle UTF8String];    // not i18n friendly
    [self setData:[NSData dataWithBytes:tempCString length:strlen(tempCString)] forType:kCorePasteboardFlavorType_urln];
  }
}

//
// Get the set of URLs and their corresponding titles from the clipboards
// If there are no URLs in a format we understand on the pasteboard empty
// arrays will be returned. The two arrays will always be the same size.
// The arrays returned are on the auto release pool.
//
- (void) getURLs:(NSArray**)outUrls andTitles:(NSArray**)outTitles
{
  NSArray* types = [self types];
  NSURL* urlFromNSURL = nil;  // Used below in getting an URL from the NSURLPboardType.
  if ([types containsObject:kWebURLsWithTitlesPboardType]) {
    NSArray* urlAndTitleContainer = [self propertyListForType:kWebURLsWithTitlesPboardType];
    *outUrls = [urlAndTitleContainer objectAtIndex:0];
    *outTitles = [urlAndTitleContainer objectAtIndex:1];
  } else if ([types containsObject:NSFilenamesPboardType]) {
    NSArray *files = [self propertyListForType:NSFilenamesPboardType];
    *outUrls = [NSMutableArray arrayWithCapacity:[files count]];
    *outTitles = [NSMutableArray arrayWithCapacity:[files count]];
    for ( unsigned int i = 0; i < [files count]; ++i ) {
      NSString *file = [files objectAtIndex:i];
      NSString *ext = [[file pathExtension] lowercaseString];
      NSString *urlString = nil;
      NSString *title = @"";
      OSType fileType = NSHFSTypeCodeFromFileType(NSHFSTypeOfFile(file));
      
      // Check whether the file is a .webloc, a .ftploc, a .fileloc, a .url, or
      // some other kind of file.
      if ([ext isEqualToString:@"webloc"] || [ext isEqualToString:@"ftploc"] ||
          [ext isEqualToString:@"fileloc"] || fileType == 'ilht' ||
          fileType == 'ilft' || fileType == 'ilfi')
      {
        NSURL* urlFromInetloc = [NSURL URLFromInetloc:file];
        if (urlFromInetloc) {
          urlString = [urlFromInetloc absoluteString];
          title     = [[file lastPathComponent] stringByDeletingPathExtension];
        }
      } else if ([ext isEqualToString:@"url"] || fileType == 'LINK') {
        NSURL* urlFromIEURLFile = [NSURL URLFromIEURLFile:file];
        if (urlFromIEURLFile) {
          urlString = [urlFromIEURLFile absoluteString];
          title     = [[file lastPathComponent] stringByDeletingPathExtension];
        }
      }
      
      // Use the filename if not a .webloc or .url file, or if either of the
      // functions returns nil.
      if (!urlString) {
        urlString = file;
        title     = [file lastPathComponent];
      }

      [(NSMutableArray*) *outUrls addObject:urlString];
      [(NSMutableArray*) *outTitles addObject:title];
    }
  } else if ([types containsObject:NSURLPboardType] && (urlFromNSURL = [NSURL URLFromPasteboard:self])) {
    *outUrls = [NSArray arrayWithObject:[urlFromNSURL absoluteString]];
    NSString* title = nil;
    if ([types containsObject:kCorePasteboardFlavorType_urld])
      title = [self cleanedTitleStringFromPasteboardType:kCorePasteboardFlavorType_urld];
    if (!title && [types containsObject:kCorePasteboardFlavorType_urln])
      title = [self cleanedTitleStringFromPasteboardType:kCorePasteboardFlavorType_urln];
    if (!title && [types containsObject:NSStringPboardType])
      title = [self cleanedTitleStringFromPasteboardType:NSStringPboardType];
    *outTitles = [NSArray arrayWithObject:(title ? title : @"")];
  } else if ([types containsObject:NSStringPboardType]) {
    NSString* potentialURLString = [self cleanedURLStringFromPasteboardType:NSStringPboardType];
    if ([potentialURLString isValidURI]) {
      *outUrls = [NSArray arrayWithObject:potentialURLString];
      NSString* title = nil;
      if ([types containsObject:kCorePasteboardFlavorType_urld])
        title = [self cleanedTitleStringFromPasteboardType:kCorePasteboardFlavorType_urld];
      if (!title && [types containsObject:kCorePasteboardFlavorType_urln])
        title = [self cleanedTitleStringFromPasteboardType:kCorePasteboardFlavorType_urln];
      *outTitles = [NSArray arrayWithObject:(title ? title : @"")];
    } else {
      // The string doesn't look like a URL - return empty arrays
      *outUrls = [NSArray array];
      *outTitles = [NSArray array];
    }
  } else {
    // We don't recognise any of these formats - return empty arrays
    *outUrls = [NSArray array];
    *outTitles = [NSArray array];
  }
}

//
// Indicates if this pasteboard contains URL data that we understand
// Deals with all our URL formats. Only strings that are valid URLs count.
// If this returns YES it is safe to use getURLs:andTitles: to retrieve the data.
//
// NB: Does not consider our internal bookmark list format, because callers
// usually need to deal with this separately because it can include folders etc.
//
- (BOOL) containsURLData
{
  NSArray* types = [self types];
  if (    [types containsObject:kWebURLsWithTitlesPboardType]
       || [types containsObject:NSURLPboardType]
       || [types containsObject:NSFilenamesPboardType] )
    return YES;
  
  if ([types containsObject:NSStringPboardType]) {
    // Trim whitespace off the ends and newlines out of the middle so we don't reject otherwise-valid URLs;
    // we'll do another cleaning when we set the URLs and titles later, so this is safe.
    NSString* potentialURLString = [self cleanedURLStringFromPasteboardType:NSStringPboardType];
    return [potentialURLString isValidURI];
  }
  
  return NO;
}
@end
