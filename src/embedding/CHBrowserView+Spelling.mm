/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#import "CHBrowserView+Spelling.h"

#import "NSString+Gecko.h"

#include "nsCOMPtr.h"
#include "nsCRT.h"
#include "nsFocusManager.h"
#include "nsIDocShell.h"
#include "nsIDOMElement.h"
#include "nsIDOMNSEditableElement.h"
#include "nsIDOMNSHTMLDocument.h"
#include "nsIDOMRange.h"
#include "nsIDOMWindow.h"
#include "nsIEditingSession.h"
#include "nsIEditor.h"
#include "nsIEditorSpellCheck.h"
#include "nsIInlineSpellChecker.h"
#include "nsIInterfaceRequestorUtils.h"
#include "nsISelection.h"
#include "nsPIDOMWindow.h"
#include "nsServiceManagerUtils.h"
#include "nsString.h"

#if MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_4
// Declare private NSSpellChecker method (public as of 10.5).
@interface NSSpellChecker (PreLeopardWordLearning)
- (void)learnWord:(NSString *)word;
@end
#endif

@interface CHBrowserView (PrivateSpellingAdditions)

- (already_AddRefed<nsIEditor>)currentEditor;
- (void)getMisspelledWordRange:(nsIDOMRange**)outRange
            inlineSpellChecker:(nsIInlineSpellChecker**)outInlineChecker;

@end

@interface CHBrowserView (PrivateCHBrowserViewMethodsUsedForSpelling)

- (already_AddRefed<nsIDOMElement>)focusedDOMElement;

@end

@implementation CHBrowserView (SpellingMethods)

- (void)ignoreCurrentWord
{
  nsCOMPtr<nsIDOMRange> misspelledRange;
  nsCOMPtr<nsIInlineSpellChecker> inlineChecker;
  [self getMisspelledWordRange:getter_AddRefs(misspelledRange)
            inlineSpellChecker:getter_AddRefs(inlineChecker)];
  if (!(misspelledRange && inlineChecker))
    return;

  nsString misspelledWord;
  misspelledRange->ToString(misspelledWord);
  inlineChecker->IgnoreWord(misspelledWord);
}

- (void)learnCurrentWord
{
  nsCOMPtr<nsIDOMRange> misspelledRange;
  nsCOMPtr<nsIInlineSpellChecker> inlineChecker;
  [self getMisspelledWordRange:getter_AddRefs(misspelledRange)
            inlineSpellChecker:getter_AddRefs(inlineChecker)];
  if (!(misspelledRange && inlineChecker))
    return;

  nsString misspelledWord;
  misspelledRange->ToString(misspelledWord);
  // nsIInlineSpellChecker's AddWordToDictionary does not insert the learned
  // word into the shared system dictionary, and instead remembers it using its
  // own personal dictionary, so we use NSSpellChecker directly.
  // NSSpellChecker method |learnWord:| to achieve this functionality.
  [[NSSpellChecker sharedSpellChecker] learnWord:[NSString stringWith_nsAString:misspelledWord]];

  // check the range again to remove the misspelled word indication
  inlineChecker->SpellCheckRange(misspelledRange);
}

- (void)replaceCurrentWordWith:(NSString*)replacementText
{
  nsCOMPtr<nsIDOMRange> misspelledRange;
  nsCOMPtr<nsIInlineSpellChecker> inlineChecker;
  [self getMisspelledWordRange:getter_AddRefs(misspelledRange)
            inlineSpellChecker:getter_AddRefs(inlineChecker)];
  if (!(misspelledRange && inlineChecker))
    return;

  // Get the node and offset of the word to replace.
  nsCOMPtr<nsIDOMNode> endNode;
  PRInt32 endOffset = 0;
  misspelledRange->GetEndContainer(getter_AddRefs(endNode));
  misspelledRange->GetEndOffset(&endOffset);
  nsString newWord;
  [replacementText assignTo_nsAString:newWord];
  inlineChecker->ReplaceWord(endNode, endOffset, newWord);
}

- (NSArray*)suggestionsForCurrentWordWithMax:(unsigned int)maxSuggestions
{
  nsCOMPtr<nsIDOMRange> misspelledRange;
  nsCOMPtr<nsIInlineSpellChecker> inlineChecker;
  [self getMisspelledWordRange:getter_AddRefs(misspelledRange)
            inlineSpellChecker:getter_AddRefs(inlineChecker)];
  if (!(misspelledRange && inlineChecker))
    return nil;

  nsCOMPtr<nsIEditorSpellCheck> spellCheck;
  inlineChecker->GetSpellChecker(getter_AddRefs(spellCheck));
  if (!spellCheck)
    return nil;

  // ask the spellchecker to check the misspelled word, which seems redundant
  // but is necessary to generate the suggestions list.
  nsString currentWord;
  misspelledRange->ToString(currentWord);
  PRBool isIncorrect = NO;
  spellCheck->CheckCurrentWord(currentWord.get(), &isIncorrect);
  if (!isIncorrect)
    return nil;

  // Loop over the suggestions. The spellchecker will return an empty string
  // (*not* NULL) when it's done, so keep going until we get that or our max.
  NSMutableArray* suggestions = [NSMutableArray array];
  for (unsigned int i = 0; i < maxSuggestions; ++i) {
    PRUnichar* suggestion = nil;
    spellCheck->GetSuggestedWord(&suggestion);
    if (!nsCRT::strlen(suggestion))
      break;

    [suggestions addObject:[NSString stringWithPRUnichars:suggestion]];
    nsCRT::free(suggestion);
  }
  return suggestions;
}

- (BOOL)isSpellingEnabledForCurrentEditor
{
  nsCOMPtr<nsIEditor> editor = [self currentEditor];
  if (!editor)
    return NO;
  nsCOMPtr<nsIInlineSpellChecker> inlineChecker;
  editor->GetInlineSpellChecker(PR_TRUE, getter_AddRefs(inlineChecker));
  if (!inlineChecker)
    return NO;

  PRBool checkingIsEnabled = NO;
  inlineChecker->GetEnableRealTimeSpell(&checkingIsEnabled);
  return checkingIsEnabled ? YES : NO;
}

- (void)setSpellingEnabledForCurrentEditor:(BOOL)enabled
{
  PRBool enableSpelling = enabled ? PR_TRUE : PR_FALSE;
  nsCOMPtr<nsIEditor> editor = [self currentEditor];
  if (editor)
    editor->SetSpellcheckUserOverride(enableSpelling);
}

- (void)recheckSpelling
{
  nsCOMPtr<nsIEditor> editor = [self currentEditor];
  if (editor)
    editor->SyncRealTimeSpell();
}

- (void)setSpellingLanguage:(NSString*)language
{
  // The underlying spellcheck system is built on NSSpellChecker, but doesn't
  // yet understand the dictionary selection system, so just set it directly.
  [[NSSpellChecker sharedSpellChecker] setLanguage:language];

  // re-sync the spell checker to pick up the new language
  [self recheckSpelling];
}

# pragma mark -

// Returns the nsIEditor of the currently focused text area, input, or
// midas editor. The return value is addref'd.
- (already_AddRefed<nsIEditor>)currentEditor
{
  nsIEditor *editor = NULL;
  nsCOMPtr<nsIDOMElement> focusedElement = [self focusedDOMElement];
  nsCOMPtr<nsIDOMNSEditableElement> editElement = do_QueryInterface(focusedElement);

  if (editElement) {
    editElement->GetEditor(&editor); // addrefs
  }
  else {
    // if there's no element focused, we're probably in a Midas editor
    nsresult rv;
    nsCOMPtr<nsIFocusManager> fm =
      do_GetService("@mozilla.org/focus-manager;1", &rv);
    NS_ENSURE_SUCCESS(rv, NULL);
    NS_ENSURE_TRUE(fm, NULL);

    nsCOMPtr<nsIDOMWindow> focusedWindow;
    fm->GetFocusedWindow(getter_AddRefs(focusedWindow));
    NS_ENSURE_TRUE(focusedWindow, NULL);

    nsCOMPtr<nsIDOMDocument> domDoc;
    rv = focusedWindow->GetDocument(getter_AddRefs(domDoc));
    NS_ENSURE_SUCCESS(rv, NULL);
    nsCOMPtr<nsIDOMNSHTMLDocument> htmlDoc = do_QueryInterface(domDoc);
    NS_ENSURE_TRUE(htmlDoc, NULL);

    nsAutoString designMode;
    rv = htmlDoc->GetDesignMode(designMode);
    NS_ENSURE_SUCCESS(rv, NULL);
    if (designMode.EqualsLiteral("on")) {
      // we are in a Midas editor, so find its editor
      nsCOMPtr<nsPIDOMWindow> privateWindow = do_QueryInterface(focusedWindow);
      NS_ENSURE_TRUE(privateWindow, NULL);

      nsIDocShell *docshell = privateWindow->GetDocShell();
      nsCOMPtr<nsIEditingSession> editSession = do_GetInterface(docshell, &rv);
      NS_ENSURE_SUCCESS(rv, NULL);
      NS_ENSURE_TRUE(editSession, NULL);

      rv = editSession->GetEditorForWindow(focusedWindow, &editor); // addrefs
      NS_ENSURE_SUCCESS(rv, NULL);
    }
  }
  return editor;
}

// Upon return, |outRange| contains the range of the currently misspelled word
// and |outInlineChecker| contains the inline spell checker to allow for further
// action. This method AddRef's both out parameters.
- (void)getMisspelledWordRange:(nsIDOMRange**)outRange
            inlineSpellChecker:(nsIInlineSpellChecker**)outInlineChecker
{
  if (!(outRange && outInlineChecker))
    return;
  *outRange = nsnull;
  *outInlineChecker = nsnull;

  nsCOMPtr<nsIEditor> editor = [self currentEditor];
  if (!editor)
    return;

  editor->GetInlineSpellChecker(PR_TRUE, outInlineChecker); // addrefs
  if (!*outInlineChecker)
    return;

  PRBool checkingIsEnabled = NO;
  (*outInlineChecker)->GetEnableRealTimeSpell(&checkingIsEnabled);
  if (!checkingIsEnabled)
    return;

  nsCOMPtr<nsISelection> selection;
  editor->GetSelection(getter_AddRefs(selection));
  if (!selection)
    return;

  nsCOMPtr<nsIDOMNode> selectionEndNode;
  PRInt32 selectionEndOffset = 0;
  selection->GetFocusNode(getter_AddRefs(selectionEndNode));
  selection->GetFocusOffset(&selectionEndOffset);

  (*outInlineChecker)->GetMisspelledWord(selectionEndNode,
                                         (long)selectionEndOffset,
                                         outRange); // addrefs
}

@end
