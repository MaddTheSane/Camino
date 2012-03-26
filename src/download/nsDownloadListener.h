/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

 
 
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#import "CHDownloadProgressDisplay.h"

#include "nsString.h"
#include "nsIInterfaceRequestor.h"
#include "nsIDownload.h"
#include "nsIWebBrowserPersist.h"
#include "nsIURI.h"
#include "nsIRequest.h"
#include "nsILocalFileMac.h"

#include "nsIExternalHelperAppService.h"


// maybe this should replace nsHeaderSniffer too?
// NB. GetInterface() for nsIProgressEventSink is called on this class, if we wanted to implement it.
class nsDownloadListener :  public CHDownloader,
                            public nsIInterfaceRequestor,
                            public nsIDownload
{
public:
            nsDownloadListener();
    virtual ~nsDownloadListener();

    NS_DECL_ISUPPORTS_INHERITED
    NS_DECL_NSIINTERFACEREQUESTOR
    NS_DECL_NSIDOWNLOAD
    NS_DECL_NSITRANSFER
    NS_DECL_NSIWEBPROGRESSLISTENER
    NS_DECL_NSIWEBPROGRESSLISTENER2
    
public:
    
    virtual void PauseDownload();
    virtual void ResumeDownload();
    virtual void CancelDownload();
    virtual void DownloadDone(nsresult aStatus);
    virtual void DetachDownloadDisplay();
    virtual PRBool IsDownloadPaused();
    
private:

    void InitDialog();
    void QuarantineDownload();
    void SetMetadata();
    void FigureOutReferrer();
    nsresult GetFileDownloadedTo(nsILocalFileMac** aMacFile);

    nsCOMPtr<nsICancelable>         mCancelable;        // Object to cancel the download
    nsCOMPtr<nsIRequest>            mRequest;           // Request to hook on status change, allows pause/resume
    nsCOMPtr<nsIURI>                mReferrer;          // The URI that referred us to the download.
    nsCOMPtr<nsIURI>                mURI;               // The URI of our source file. Null if we're saving a complete document.
    nsCOMPtr<nsIURI>                mDestination;       // Our destination URL.
    nsCOMPtr<nsILocalFile>          mDestinationFile;   // Our destination file.
    nsCOMPtr<nsILocalFile>          mTempFile;          // The file that receives downloaded content, which will ultimately replace mDestinationFile.
    nsresult                        mDownloadStatus;		// status from last nofication
    PRInt64                         mStartTime;         // When the download started
    PRPackedBool                    mBypassCache;       // Whether we should bypass the cache or not.
    PRPackedBool                    mNetworkTransfer;     // true if the first OnStateChange has the NETWORK bit set
    PRPackedBool                    mGotFirstStateChange; // true after we've seen the first OnStateChange
    PRPackedBool                    mUserCanceled;        // true if the user canceled the download
    PRPackedBool                    mSentCancel;          // true when we've notified the backend of the cancel
    PRPackedBool                    mDownloadPaused;      // true when download is paused
};

