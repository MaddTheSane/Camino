/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
 
#import "JSConsole.h"
#import "NSString+Gecko.h"

#import "CHBrowserService.h"

#include "nsString.h"
#include "nsIServiceManager.h"
#include "nsIConsoleService.h"
#include "nsIConsoleListener.h"

/* Header file */
class nsConsoleListener : public nsIConsoleListener
{
public:
  NS_DECL_ISUPPORTS
  NS_DECL_NSICONSOLELISTENER
  
  nsConsoleListener();
  virtual ~nsConsoleListener();

protected:
  
};

NS_IMPL_ISUPPORTS1(nsConsoleListener, nsIConsoleListener)

nsConsoleListener::nsConsoleListener()
{
}

nsConsoleListener::~nsConsoleListener()
{
}

/* void observe (in nsIConsoleMessage aMessage); */
NS_IMETHODIMP nsConsoleListener::Observe(nsIConsoleMessage* aMessage)
{
  if (aMessage) {
    nsAutoString msgBuffer;
    aMessage->GetMessageMoz(getter_Copies(msgBuffer));
    [[JSConsole sharedJSConsole] logMessage:[NSString stringWith_nsAString:msgBuffer]];
  }
  
  return NS_OK;
}

/* End of implementation class template. */

#pragma mark -

@interface JSConsole(Private)

- (void)setupConsoleListener;
- (void)cleanupConsoleService;

- (void)registerNotificationListener;
- (void)shutdown: (NSNotification*)aNotification;

@end


@implementation JSConsole

static JSConsole* gJSConsole;

+ (JSConsole*)sharedJSConsole
{
  if (!gJSConsole)
    gJSConsole = [[JSConsole alloc] init];
  
  return gJSConsole;
}

- (id)init
{
  if ((self = [super init])) {
    [self registerNotificationListener];
    [self setupConsoleListener];
  }
  return self;
}

- (void)dealloc
{
  if (self == gJSConsole)
    gJSConsole = nil;

  [[NSNotificationCenter defaultCenter] removeObserver:self];
  NS_IF_RELEASE(mConsoleListener);
  [super dealloc];
}

- (void)logMessage:(NSString*)message
{
  NSLog(@"JS error: %@", message);
}

// gets called before XPCOM shutdown
- (void)cleanupConsoleService
{
  if (mConsoleListener) {
    nsCOMPtr<nsIConsoleService> consoleService = do_GetService(NS_CONSOLESERVICE_CONTRACTID);
    if (consoleService)
      consoleService->UnregisterListener(mConsoleListener);
      
    NS_RELEASE(mConsoleListener);  // nulls it out
  }
}

- (void)setupConsoleListener
{
  mConsoleListener = new nsConsoleListener;
  NS_IF_ADDREF(mConsoleListener);
  
  nsCOMPtr<nsIConsoleService> consoleService = do_GetService(NS_CONSOLESERVICE_CONTRACTID);
  if (consoleService)
    consoleService->RegisterListener(mConsoleListener);
}

- (void)registerNotificationListener
{
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(shutdown:)
                                               name:kTermEmbeddingNotification
                                             object:nil];
}

- (void)shutdown:(NSNotification*)aNotification
{
  [self cleanupConsoleService];
  [gJSConsole autorelease];
}

@end
