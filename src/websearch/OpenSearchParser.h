/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import <Cocoa/Cocoa.h>
#import "XMLSearchPluginParser.h"

//
// OpenSearchParser
//
// A concrete subclass of XMLSearchPluginParser with the knowledge of how to
// parse the OpenSearch 1.1 description format for search plugins.
// See http://www.opensearch.org/Specifications/OpenSearch/1.1 for information about
// the description document.
//
@interface OpenSearchParser : XMLSearchPluginParser 
{
@private
  // Dictionaries of template URL parameters (keys) and their associated values (objects):
  // Parameters that we know the correct value for:
  NSDictionary *mURLParametersAndKnownValues;           // strong
  // Parameters that we try to determine a reasonable default if they're required:
  NSDictionary *mURLParametersAndGuessedDefaultValues;  // strong
}

@end
