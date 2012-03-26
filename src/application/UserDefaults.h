/* -*- Mode: C; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */


/*
  This file contains a list of #defines for our user default entries. They
  are collected here, rather than being scattered throughout the code, for
  easier documentation.
*/

// Support for firefox-style command-line arguments, mostly for test harnesses.
#define USER_DEFAULTS_URL_KEY                   @"url"                           /* String */
#define USER_DEFAULTS_PROFILE_KEY               @"profile"                       /* String */

#define USER_DEFAULTS_HIDE_PERS_TOOLBAR_KEY     @"Hide Personal Toolbar"         /* Integer */
#define USER_DEFAULTS_HIDE_STATUS_BAR_KEY       @"Hide Status Bar"               /* Boolean */
#define USER_DEFAULTS_HOMEPAGE_KEY              @"HomePage"                      /* String */
#define USER_DEFAULTS_CONTAINER_SPLITTER_WIDTH  @"Bookmarks Splitter position"   /* Float */
#define USER_DEFAULTS_LAST_SELECTED_BM_FOLDER   @"Last Selected Bookmark Folder" /* String */

