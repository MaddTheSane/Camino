/* -*- Mode: Java; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
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
 * The Original Code is Chimera.
 *
 * The Initial Developer of the Original Code is
 * Netscape Communications Corporation.
 * Portions created by the Initial Developer are Copyright (C) 2002
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *  Brian Ryner <bryner@brianryner.com>
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

// This file contains Camino-specific default preferences.

// What to load in a new tab: 0 = blank, 1 = homepage, 2 = last page
pref("browser.tabs.startPage", 0);

// Pick some reasonable OS X default fonts
pref("font.name.serif.x-western", "Lucida Grande");
pref("font.name.sans-serif.x-western", "Lucida Grande");
pref("font.size.variable.x-western", 15);
pref("font.size.fixed.x-western", 12);
pref("font.size.minimum-size.x-western", 10);

// turn on universal character detection
pref("intl.charset.detector", "universal_charset_detector");

pref("chimera.store_passwords_with_keychain", true);
pref("chimera.keychain_passwords_autofill", true);

pref("chimera.enable_plugins", true);
pref("chimera.log_js_to_console", true);

// Identify Camino in the UA string
pref("general.useragent.vendor", "Camino");
pref("general.useragent.vendorSub", "0.7+");

pref("browser.chrome.favicons", true);

// Default to auto download enabled but auto helper dispatch disabled
pref("browser.download.autoDownload", true);
pref("browser.download.autoDispatch", false);

pref("chimera.enable_rendezvous", true);

// set typeahead find to search all text by default
pref("accessibility.typeaheadfind.linksonly", false);

// image resizing
pref("browser.enable_automatic_image_resizing", true);

pref("browser.chrome.favicons", false);
