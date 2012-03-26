/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */


// Put UI constants (menu item tags etc) in this file to reduce the
// chance of conflicts.

// Go menu

// the tag of the separator after which to insert history menu items
const int kRendezvousRelatedItemTag = 3000;
const int kDividerTag = 4000;

// Tags 10-80 are reserved for text encoding items
const int kEncodingMenuTagBase = 10;
const int kEncodingMenuAutodetectItemTag = 200;


// Bookmarks menu

// the tag of the separator after which to insert bookmark items
const int kBookmarksDividerTag = -1;

// Save file dialog
const int kSaveFormatPopupTag = 1000;

enum
{
  eSaveFormatHTMLComplete = 0,
  eSaveFormatHTMLSource,
  eSaveFormatPlainText
};

// Help menu
const int kHelpMenuItemTag = 7000;
