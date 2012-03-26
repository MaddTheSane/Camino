/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#ifndef PluginBlocklistService_h__
#define PluginBlocklistService_h__

#include "nsIBlocklistService.h"

// Contros plugin blocklisting.
class PluginBlocklistService : public nsIBlocklistService
{
public:
  NS_DECL_ISUPPORTS
  NS_DECL_NSIBLOCKLISTSERVICE

  PluginBlocklistService() {}
  virtual ~PluginBlocklistService() {}
};

/* C2D9F69B-8AA2-4247-8B8B-DA C9 FE 2E 00 CE */
#define PLUGIN_BLOCKLIST_SERVICE_CID \
{ 0xC2D9F69B, 0x8AA2, 0x4247, \
{ 0x8B, 0x8B, 0xDA, 0xC9, 0xFE, 0x2E, 0x00, 0xCE}}

#endif // PluginBlocklistService_h__
