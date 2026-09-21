# Sprint 8.7.6 — Live regression checklist (run by Anand, logged in, after the frontend push)

Live URL: https://www.recallapp.co.in. Report back for each line: what you saw. Note "phantom" = a source label that doesn't match what the batch was created with.

## A. Provenance display (Sprint 8.7.5 only checked these structurally)
For each surface, check: (1) a label appears on content that HAS a source, (2) it's the right source, (3) nothing appears on old content with no source, and no label shows a source that doesn't belong.

| Surface | Where | Seen? | Correct? | No phantom? |
|---|---|---|---|---|
| MyFlashcards (grouped view + a card inside a group) | Dashboard > My Flashcards | | | |
| NoteDetail (note label + linked flashcards list) | open any note | | | |
| BrowseNotes | Browse Notes | | | |
| StudyMode (deck opened from Browse Study Sets, and via Today's Reviews) | Study | | | |
| Browsable decks | Browse Study Sets | | | |

## B. Merge behaviour (MyFlashcards, grouped view). Use only batches you can afford to merge; a merge can't be undone.
Tip: create two tiny test batches per case using Create Flashcard with the source you need, then delete them afterwards.

1. **Identical provenance (allowed):** two batches, same source type and same name. Select both, Merge. Expected: "Batches Merged"; one batch remains; its label unchanged. (Optional SQL check afterwards: the merged-away batch's provenance row is gone.)
2. **Different provenance (blocked):** two batches, different name (or different type). Expected: friendly "content sources differ" message BEFORE the dialog opens, nothing changes.
3. **Provenance vs legacy (blocked):** one batch with a source, one old batch without. Expected: same friendly message.
4. **Legacy vs legacy (allowed):** two old batches with no source. Expected: merges successfully.
5. **No-batch group:** if a "no batch" group ever appears (none exist today), select it with another batch. Expected: friendly message, no error/crash. If none appears, write "not reachable — 0 no-batch cards".
6. **Server block message (optional):** not reachable from the normal UI because the pre-check catches it first; already proven by the SQL test (02).

Report: for each numbered case, what happened and the exact message text.
