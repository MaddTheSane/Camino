/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/*
  The classes and protocol in this file allow Cocoa applications to easily
  reuse the underlying download implementation, which deals with the complexity
  of Gecko's downloading callbacks.
  
  There are three things here:
  
  1.  The CHDownloadProgressDisplay protocol.
  
      This is a formal protocol that needs to be implemented by
      an object (eg. a window controller or a view controller) 
      for your progress window. Its methods will be called by the
      underlying C++ downloading classes.
     
  2.  The CHDownloadDisplayFactory protocol
  
      This is a formal protocol that can be implemented by
      any object that can create objects that themselves
      implement CHDownloadProgressDisplay. This would probably be 
      an NSWindowController. 
            
  3.  The CHDownloader C++ class
  
      This base class exists to hide the complextity of the download
      listener classes (which deal with Gecko callbacks) from the
      window controller.  Embedders don't need to do anything with it.

  How these classes fit together:
  
  There are 2 ways in which a download is initiated:
  
  (i)   File->Save.
  
        Chimera does a complex dance here in order to get certain
        information about the data being downloaded (it needs to
        start the download before it can read some optional MIME headers).
        
        CBrowserView creates an nsIWebBrowserPersist (WBP), and then a
        nsHeaderSniffer, which implements nsIWebProgressListener and is set to
        observer the WBP. When nsHeaderSniffer hears about the start of the
        download, it decides on a file name, and what format to save the data
        in. It then cancels the current WPB, makes another one, and does
        a CreateInstance of an nsIDownload (making one of our nsDownloadListener
        -- aka nsDownloder -- objects), and sets that as the nsIWebProgressListener.
        The full download procedes from there.
        
  (ii)  Click to download (e.g. FTP link)
  
        This is simpler. The backend (necko) does the CreateInstance of the
        nsIDownload, and the download progresses.
        
  In both cases, creating the nsDownloadListener and calling its Init() method
  calls nsDownloder::CreateDownloadDisplay(). The nsDownloder has as a member
  variable an object that implements CHDownloadDisplayFactory (see above), which got set
  on it via a call to SetDisplayFactory. It then uses that CHDownloadDisplayFactory
  to create an instance of the download progress display, which then controls
  something (like a view or window) that shows in the UI.
  
  Simple, eh?
  
*/

#import <AppKit/AppKit.h>

#include "nsISupports.h"

class CHDownloader;

// A formal protocol for something that implements progress display.
// Embedders can make a window or view controller that conforms to this
// protocol, and reuse nsDownloadListener to get download UI.
@protocol CHDownloadProgressDisplay <NSObject>

- (void)onStartDownload:(BOOL)isFileSave;
- (void)onEndDownload:(BOOL)completedOK statusCode:(nsresult)aStatus;

- (void)setProgressTo:(long long)aCurProgress ofMax:(long long)aMaxProgress;

- (void)setDownloadListener:(CHDownloader*)aDownloader;
- (void)setSourceURL:(NSString*)aSourceURL;
- (NSString*)sourceURL;

- (void)setDestinationPath:(NSString*)aDestPath;
- (NSString*)destinationPath;

- (void)displayWillBeRemoved;

@end

// A formal protocol which is implemented by a factory of progress UI.
@protocol CHDownloadDisplayFactory <NSObject>

- (id <CHDownloadProgressDisplay>)createProgressDisplay;

@end


// Pure virtual base class for a generic downloader, that the progress UI can talk to.
// It implements nsISupports so that it can be refcounted. This class insulates the
// UI code from having to know too much about the nsDownloadListener.
// It is responsible for creating the download UI, via the CHDownloadController
// that it owns.
class CHDownloader : public nsISupports
{
public:
                  CHDownloader();
    virtual       ~CHDownloader();

    NS_DECL_ISUPPORTS

    virtual void SetDisplayFactory(id<CHDownloadDisplayFactory> inDownloadDisplayFactory);    // retains

    virtual void PauseDownload() = 0;
    virtual void ResumeDownload() = 0;
    virtual void CancelDownload() = 0;
    virtual void DownloadDone(nsresult aStatus) = 0;
    virtual void DetachDownloadDisplay() = 0;   // tell downloader to forget about its display
    virtual void CreateDownloadDisplay();
    virtual PRBool IsDownloadPaused() = 0;
    
protected:
  
    PRBool      IsFileSave() { return mIsFileSave; }
    void        SetIsFileSave(PRBool inIsFileSave) { mIsFileSave = inIsFileSave; }

protected:

    id<CHDownloadDisplayFactory>    mDisplayFactory;
    id<CHDownloadProgressDisplay>   mDownloadDisplay;   // something that implements the CHDownloadProgressDisplay protocol
    PRBool                          mIsFileSave;        // true if we're doing a save, rather than a download
};

