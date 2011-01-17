/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* ***** BEGIN LICENSE BLOCK *****
 * Version: MPL 1.1/GPL 2.0/LGPL 2.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Original Code is Camino code.
 *
 * The Initial Developer of the Original Code is
 * Stuart Morgan.
 * Portions created by the Initial Developer are Copyright (C) 2011
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *   Stuart Morgan <stuart.morgan@alumni.case.edu>
 *
 * Alternatively, the contents of this file may be used under the terms of
 * either the GNU General Public License Version 2 or later (the "GPL"), or
 * the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
 * in which case the provisions of the GPL or the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of either the GPL or the LGPL, and not to allow others to
 * use your version of this file under the terms of the MPL, indicate your
 * decision by deleting the provisions above and replace them with the notice
 * and other provisions required by the GPL or the LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the MPL, the GPL or the LGPL.
 *
 * ***** END LICENSE BLOCK ***** */

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
