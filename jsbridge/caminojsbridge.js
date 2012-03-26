/*
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
*/

Components.utils.import("resource://gre/modules/XPCOMUtils.jsm");

function CaminoJavascriptBridge() { }

CaminoJavascriptBridge.prototype = {
  classDescription: "Camino-to-JS Bridging Component",
  classID:          Components.ID("{d2364e73-56e8-4e69-95e9-64ac83b83e25}"),
  contractID:       "@mozilla.org/camino/javascript-bridge;1",
  QueryInterface: XPCOMUtils.generateQI([Components.interfaces.chIJavascriptBridge]),

  startMaintenance: function() {
    // Initialize the PlacesDBUtils, which does maintenance on a timer.
    Components.utils.import("resource://gre/modules/PlacesDBUtils.jsm");
  }
};

var components = [CaminoJavascriptBridge];

function NSGetModule(compMgr, fileSpec) {
  return XPCOMUtils.generateModule(components);
}
