#!/bin/bash
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Xcode doesn't understand that our third-party frameworks are built into different directories
# than Camino is built into, so doing a normal copy phase doesn't work. Instead, we copy them
# manually.
# (This issue seems to be fixed in Snow Leopard, so we can hopefully eliminate this someday)

echo Copying third-party frameworks to Camino build directory

mkdir -p "${BUILT_PRODUCTS_DIR}/$WRAPPER_NAME/Contents/Frameworks/"

BREAKPAD_DEST="${BUILT_PRODUCTS_DIR}/Breakpad.framework"
rm -rf "$BREAKPAD_DEST"
/Developer/Tools/CpMac -r "${SOURCE_ROOT}/google-breakpad/src/client/mac/build/${CONFIGURATION}/Breakpad.framework" "$BREAKPAD_DEST"

GROWL_DEST="${BUILT_PRODUCTS_DIR}/Growl.framework"
rm -rf "$GROWL_DEST"
/Developer/Tools/CpMac -r "${SOURCE_ROOT}/growl/build/${CONFIGURATION}/Growl.framework" "$GROWL_DEST"

SPARKLE_DEST="${BUILT_PRODUCTS_DIR}/Sparkle.framework"
rm -rf "$SPARKLE_DEST"
/Developer/Tools/CpMac -r "${SOURCE_ROOT}/sparkle/build/${CONFIGURATION}/Sparkle.framework" "$SPARKLE_DEST"
