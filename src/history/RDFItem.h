/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* ***** BEGIN LICENSE BLOCK *****
 * Version: NPL 1.1/GPL 2.0/LGPL 2.1
 *
 * The contents of this file are subject to the Netscape Public License
 * Version 1.1 (the "License"); you may not use this file except in
 * compliance with the License. You may obtain a copy of the License at
 * http://www.mozilla.org/NPL/
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
 *   Ben Goodger <ben@netscape.com> (Original Author)
 *   Simon Woodside <sbwoodside@yahoo.com>
 *
 * Alternatively, the contents of this file may be used under the terms of
 * either the GNU General Public License Version 2 or later (the "GPL"), or 
 * the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
 * in which case the provisions of the GPL or the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of either the GPL or the LGPL, and not to allow others to
 * use your version of this file under the terms of the NPL, indicate your
 * decision by deleting the provisions above and replace them with the notice
 * and other provisions required by the GPL or the LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the NPL, the GPL or the LGPL.
 *
 * ***** END LICENSE BLOCK ***** */

#import <Appkit/Appkit.h>

class nsIRDFDataSource;
class nsIRDFContainer;
class nsIRDFContainerUtils;
class nsIRDFResource;
class nsIRDFService;


// RDFItems make up rows of an RDF outline view
@interface RDFItem : NSObject
{
  NSMutableArray* mChildNodes;      // array of RDFItem
  RDFItem* mParent;
  NSMutableDictionary * mPropertyCache;

  nsIRDFResource*         mRDFResource;
  nsIRDFDataSource*       mRDFDataSource;
  nsIRDFContainer*        mRDFContainer;
  nsIRDFContainerUtils*   mRDFContainerUtils;
  nsIRDFService*          mRDFService;
}

- (id)initWithRDFResource:(nsIRDFResource*)aRDFResource RDFDataSource:(nsIRDFDataSource*)aRDFDataSource parent:(RDFItem*)newparent;
- (NSString*)getStringForRDFPropertyURI:(NSString*)aPropertyURI;
- (BOOL)isExpandable;
- (RDFItem*)childAtIndex:(int)index;
- (int)numChildren;
- (RDFItem*)parent;

- (void)deleteChildFromCache:(RDFItem*)child;

- (void)buildChildCache;
- (void)invalidateCache;

@end
