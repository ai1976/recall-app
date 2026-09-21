# Sprint 8.7.7 — Plan for auditor review: `get_browsable_decks` v8 (matching_card_count)

Status: PLAN ONLY. No SQL has been written or deployed. Prepared 21/09/2026.

## 1. Problem (proven in code, not a data error)
On Browse Study Sets, choosing a Question Type filter shows "N cards available" and "Study All (N)" with inflated numbers.
Live observation (professor account, 21/09/2026): filters Flashcard 699 + Theory 397 + Case study MCQ 129 = 1,225, while "All Types" shows 1,091.

Cause: `get_browsable_decks(p_question_type)` (v7, `docs/database/sprint8.7.4/02_FUNCTIONS_get_browsable_decks_v7_provenance.sql`)
returns every deck that has at least one viewer-visible card of the requested type, but its `card_count` is deliberately
type-agnostic (the deck's whole visible total; see the "QUESTION TYPE FILTER" comment in that file).
`ReviewFlashcards.jsx` sums `card_count`, so a filter shows deck totals, and a deck containing several types is counted under each filter.

## 2. Proposed change
Function `get_browsable_decks(p_question_type TEXT DEFAULT NULL)`, new version v8:
- Add ONE new output column at the end of the RETURNS TABLE: `matching_card_count INTEGER`.
  - No filter (`p_question_type IS NULL`): equals `visible_card_count` (unchanged behaviour).
  - Filter set: number of cards in the deck that the viewer may see (same visibility predicate as today) AND have `question_type = p_question_type`.
- `card_count`, the deck inclusion rule, provenance columns, ordering, SECURITY DEFINER, `search_path` and grants stay exactly as in v7.
- Because RETURNS TABLE changes, the function is dropped and recreated (same pattern v7 used), inside one statement batch; the one-argument signature is unchanged.
- Frontend (`ReviewFlashcards.jsx`, only caller — verified by grep) uses `matching_card_count` for the deck count, the subject totals and "N cards available" while a filter is active; otherwise it keeps using `card_count`. No other file changes.

## 3. Safety properties to verify
1. Visibility: the new count uses the identical viewer-visibility predicate as `visible_card_count` — a user must never see a count including cards they cannot see.
2. No filter: `matching_card_count = card_count` for every row.
3. Filter set: `matching_card_count <= card_count`, and `>= 1` for every returned deck; sum over filters of a deck's matching counts equals its total (mixed-type decks are no longer double counted).
4. Anonymous/other roles: grants and SECURITY DEFINER settings unchanged from v7 (compare `pg_proc` flags and ACL before/after).
5. No new write path, no table/column/policy change, no trigger involvement.

## 4. Deployment order (non-negotiable)
1. Operator runs a read-only diagnostic (current definition, grants, overloads).
2. Operator runs the v8 function file.
3. Operator runs the test file (rolls back; covers 2 and 3 above, plus visibility for an own / public / friends / private-other-user card).
4. Operator confirms results to the engineer.
5. Only then the frontend push. Rollback: re-create v7 from the existing sprint8.7.4 file.

## 5. Risks and mitigations
- Dropping/recreating a function used by the main browse screen: deploy in a quiet window; rollback file prepared and tested first.
- Extra column ignored by any other caller: only `ReviewFlashcards.jsx` calls it (grep-verified).
- Count semantics: deck-level `card_count` (unfiltered) remains available and unchanged.

## 6. Out of scope
Any change to study queue / SRS logic, provenance display, RLS or table schema.
