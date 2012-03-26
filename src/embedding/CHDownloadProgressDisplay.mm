/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "CHDownloadProgressDisplay.h"

// CHDownloader is a simple class that that the download UI can talk to

CHDownloader::CHDownloader()
: mDisplayFactory(NULL)
, mDownloadDisplay(nil)
, mIsFileSave(PR_FALSE)
{
}

CHDownloader::~CHDownloader()
{
  [mDisplayFactory release];
}

NS_IMPL_ISUPPORTS1(CHDownloader, nsISupports)

void
CHDownloader::SetDisplayFactory(id<CHDownloadDisplayFactory> inDownloadControllerFactory)
{
  mDisplayFactory = inDownloadControllerFactory;
  [mDisplayFactory retain];
}

void
CHDownloader::CreateDownloadDisplay()
{
  NS_ASSERTION(mDisplayFactory, "Should have a UI factory");
  mDownloadDisplay = [mDisplayFactory createProgressDisplay];
  [mDownloadDisplay setDownloadListener:this];
}
