/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>

// Keys for describing search plugins:
extern NSString *const kWebSearchPluginNameKey;
extern NSString *const kWebSearchPluginMIMETypeKey;
extern NSString *const kWebSearchPluginURLKey;

// Supported MIME types:
extern NSString *const kOpenSearchMIMEType;

// For use with XMLSearchPluginParser's error reporting:
extern NSString *const kXMLSearchPluginParserErrorDomain;
typedef enum {
  // The search query URL template used by the plugin is not supported by the browser (e.g. it uses a POST method type):
  eXMLSearchPluginParserUnsupportedSearchURLError,
  // The search plugin description file could not be found on the server:
  eXMLSearchPluginParserPluginNotFoundError,
  // Indicates a parsing error, meaning the plugin is invalid for the MIME type it represents:
  eXMLSearchPluginParserInvalidPluginFormatError
} EXMLSearchPluginParserErrorCode;

//
// XMLSearchPluginParser
//
// A class cluster which is designed to support the flexible parsing
// of xml-based web search engine definitions.  XMLSearchPluginParser is
// an abstract superclass, and all creational methods transparently return
// a private concrete subclasses capable of parsing a certain type of plugin file.
//
// Instructions for subclassing are before the @implementation.
//
@interface XMLSearchPluginParser : NSObject
{
@private
  NSSet           *mElementsToParseContentsFor;   // strong
  NSSet           *mElementsToParseAttributesFor; // strong

  BOOL            mShouldParseContentsOfCurrentElement;

  NSString        *mSearchEngineName;             // strong
  NSString        *mSearchEngineURL;              // strong
  NSString        *mSearchEngineURLRequestMethod; // strong

  NSMutableString *mCurrentElementBuffer;
}

+ (BOOL)canParsePluginMIMEType:(NSString *)mimeType;

// Both methods return nil if the plugin type is not supported:
+ (id)searchPluginParserWithMIMEType:(NSString *)mimeType;
- (id)initWithPluginMIMEType:(NSString *)mimeType;

// If a parsing error occurs, returns NO and populates |outError| with an NSError object containing a
// localized description of the problem. Pass NULL if you do not want error information.
- (BOOL)parseSearchPluginAtURL:(NSURL *)searchPluginURL error:(NSError **)outError;

// Accessors to obtain parsed information:
- (NSString *)searchEngineName;
- (NSString *)searchEngineURL;
- (NSString *)searchEngineURLRequestMethod;

@end

#pragma mark -

@interface XMLSearchPluginParser (AbstractMethods)

// Abstract methods which should be implemented by subclasses:

- (void)foundContents:(NSString *)stringContents forElement:(NSString *)elementName;
- (void)foundAttributes:(NSDictionary *)attributeDict forElement:(NSString *)elementName;

@end

#pragma mark -

@interface XMLSearchPluginParser (SubclassUseOnly)

// Private, concrete methods which should only be used by subclasses:

// Establish which elements you're interested in:
- (void)setShouldParseContentsOfElements:(NSSet *)setOfElements;
- (void)setShouldParseAttributesOfElements:(NSSet *)setOfElements;
- (BOOL)shouldParseContentsOfElement:(NSString *)elementName;
- (BOOL)shouldParseAttributesOfElement:(NSString *)elementName;

// Set parsed properties:
- (void)setSearchEngineName:(NSString *)newSearchEngineName;
- (void)setSearchEngineURL:(NSString *)newSearchEngineURL;
- (void)setSearchEngineURLRequestMethod:(NSString *)newMethod;

- (BOOL)browserSupportsSearchQueryURLWithMIMEType:(NSString *)mimeType;
- (BOOL)browserSupportsSearchQueryURLWithRequestMethod:(NSString *)requestMethod;

@end
