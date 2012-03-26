/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

 
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#include "nsString.h"
#include "nsIInterfaceRequestor.h"
#include "nsIWebProgressListener.h"
#include "nsIWebBrowserPersist.h"
#include "nsIURI.h"
#include "nsILocalFile.h"
#include "nsIInputStream.h"
#include "nsIDOMDocument.h"


// Implementation of a header sniffer class that is used when saving Web pages and images.
// NB. GetInterface() for nsIProgressEventSink is called on this class, if we wanted to implement it.
class nsHeaderSniffer : public nsIInterfaceRequestor,
                        public nsIWebProgressListener
{
public:
    nsHeaderSniffer(nsIWebBrowserPersist* aPersist, nsIFile* aFile, nsIURI* aURL,
                    nsIDOMDocument* aDocument, nsIInputStream* aPostData,
                    const nsAString& aSuggestedFilename, PRBool aBypassCache,
                    NSView* aFilterView);
    virtual ~nsHeaderSniffer();

    NS_DECL_ISUPPORTS
    NS_DECL_NSIINTERFACEREQUESTOR
    NS_DECL_NSIWEBPROGRESSLISTENER
  
protected:

    nsresult  PerformSave(nsIURI* inOriginalURI);
    nsresult  InitiateDownload(nsISupports* inSourceData, nsString& inFileName, nsIURI* inOriginalURI);

private:

    nsIWebBrowserPersist*     mSniffingPersist; // Weak. It owns us as a listener. Only lives until we get the start state.
    nsCOMPtr<nsIFile>         mTmpFile;
    nsCOMPtr<nsIURI>          mURL;
    nsCOMPtr<nsIDOMDocument>  mDocument;
    nsCOMPtr<nsIInputStream>  mPostData;
    nsString                  mDefaultFilename;
    PRBool                    mBypassCache;
    nsCString                 mContentType;
    nsCString                 mContentDisposition;
    NSView*                   mFilterView;
};


@interface FilterViewController : NSObject
{
  IBOutlet NSPopUpButton* mSaveOptionsPopUpButton;
  IBOutlet NSView*        mFilterView;
}

-(IBAction)setNewSaveOption:(id)sender;

@end

