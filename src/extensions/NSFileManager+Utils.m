/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */


#import "NSFileManager+Utils.h"

@implementation NSFileManager(CaminoFileManagerUtils)

- (BOOL)createDirectoriesInPath:(NSString *)path attributes:(NSDictionary *)attributes
{
  NSArray*        dirs = [[path stringByStandardizingPath] pathComponents];
  NSString* curPath = nil;
  
  unsigned i, numDirs = [dirs count];
  for (i = 0; i < numDirs; i ++)
  {
    if (curPath)
      curPath = [curPath stringByAppendingPathComponent:[dirs objectAtIndex:i]];
    else
      curPath = [dirs objectAtIndex:i];

    BOOL isDir;
    if ([self fileExistsAtPath:curPath isDirectory:&isDir])
    {
      if (!isDir)
        return NO;    // can't replace file with directory

      continue;
    }
    
    BOOL created = [self createDirectoryAtPath:curPath attributes:attributes];
    if (!created)
      return NO;
  }
  
  return YES;
}

- (long long)sizeOfFileAtPath:(NSString*)inPath traverseLink:(BOOL)inTraverseLink
{
  NSDictionary* fileAttribs = [self fileAttributesAtPath:inPath traverseLink:inTraverseLink];
  if (!fileAttribs) return -1LL;
  
  NSNumber* fileSize = [fileAttribs objectForKey:NSFileSize];
  if (!fileSize) return -1LL;
  
  return [fileSize longLongValue];
}

- (NSString*)backupFileNameFromPath:(NSString*)inPath withSuffix:(NSString*)inFileSuffix
{
  NSString* pathWithoutExtension = [inPath stringByDeletingPathExtension];
  NSString* fileExtension = [inPath pathExtension];

  int sequenceNumber = 1;
  
  NSString* newName = nil;

  do {
    NSString* sequenceString = [NSString stringWithFormat:@"%@-%d", inFileSuffix, sequenceNumber];
    
    newName = [pathWithoutExtension stringByAppendingString:sequenceString];
    newName = [newName stringByAppendingPathExtension:fileExtension];
    
    ++sequenceNumber;
  } while ([self fileExistsAtPath:newName]);

  return newName;
}

- (NSString *)lastModifiedSubdirectoryAtPath:(NSString *)inPath
{
  inPath = [inPath stringByStandardizingPath];

  NSFileManager* fileManager = [NSFileManager defaultManager];
  BOOL isDirectory = NO;
  if (!([fileManager fileExistsAtPath:inPath isDirectory:&isDirectory] && isDirectory))
    return nil;

  NSDate* newestModificationDateFound = [NSDate distantPast];
  NSString* lastModifiedSubdirectory = nil;
  NSEnumerator* directoryContentsEnumerator = [[fileManager directoryContentsAtPath:inPath] objectEnumerator];
  NSString* subpath = nil;
  while ((subpath = [directoryContentsEnumerator nextObject])) {
    if ([subpath hasPrefix:@"."])
      continue;

    subpath = [inPath stringByAppendingPathComponent:subpath];

    if (!([fileManager fileExistsAtPath:subpath isDirectory:&isDirectory] && isDirectory))
      continue;

    NSDate* currentFileModificationDate = [[fileManager fileAttributesAtPath:subpath
                                                                traverseLink:NO] fileModificationDate];
    if ([currentFileModificationDate timeIntervalSinceDate:newestModificationDateFound] > 0) {
      newestModificationDateFound = currentFileModificationDate;
      lastModifiedSubdirectory = subpath;
    }
  }
  return lastModifiedSubdirectory;
}

@end
