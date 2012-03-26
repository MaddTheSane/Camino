/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "CHBrowserView.h"

// Spelling methods for CHBrowserView. Note that these are all specific to the
// currently focused editor, not the whole browser view, so if there is ever a
// wrapper for nsIEditor these methods would belong there instead.
@interface CHBrowserView (SpellingMethods)

// Sets the spell checker to ignore the word under the text insertion point.
// Lasts for the duration of the active editing session only.
- (void)ignoreCurrentWord;

// Sets the spell checker to learn the word under the text insertion point.
// This permanently adds the word to the user's OS dictionary.
- (void)learnCurrentWord;

// Replaces the word under the text insertion point with |replacementText|.
- (void)replaceCurrentWordWith:(NSString*)replacementText;

// Returns an array of up to |maxSuggestions| suggested corrections for the word
// under the text insertion point, or |nil| if the word is not misspelled.
- (NSArray*)suggestionsForCurrentWordWithMax:(unsigned int)maxSuggestions;

// Returns whether or not spell check is enabled for the current editor.
- (BOOL)isSpellingEnabledForCurrentEditor;
// Enables or disables spelling for the current editor.
- (void)setSpellingEnabledForCurrentEditor:(BOOL)enabled;

// Re-runs the spell checker for the current editor.
- (void)recheckSpelling;

// Sets the current spelling language to |language| (a language/locale code).
- (void)setSpellingLanguage:(NSString*)language;

@end
