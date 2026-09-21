# Bug Tracking

## Sprint 8.7.7 — 21/09/2026 (Theory display + console diagnosis)

### [21/09/2026] Reviewed-cards lookup returned 400 for large study sessions — ✅ FIXED (frontend push pending)
- **Proven:** URL 39,144 chars with 1,000 ids -> bare "Bad Request"; after chunking 20/20 requests return 200 (max URL ~4KB).
- **Effect while broken:** `reviewedIds` empty -> reviewed-but-not-due cards admitted as "new" in Study Mode.

### [21/09/2026] In-app `study_sessions` inserts below 600s rejected by `study_sessions_duration_floor` — ✅ CLOSED (SQL deployed D-25; live end-to-end proven: real Study Mode flow 27s study_mode session -> 201, row read back)
- **PROVEN 21/09/2026 on live (professor account):** POST /rest/v1/study_sessions with the exact Study Mode payload (source=study_mode, duration_seconds=60) returned 400, code 23514: new row violates check constraint "study_sessions_duration_floor". Nothing was written. (The originally observed console 400 was not separately captured, but this is the same table, same constraint.) Business rule: floor applies to source='manual' only. **Fix deployed & test-verified 21/09/2026:** floor re-scoped to source='manual'. In-app rows under 600s stopped appearing after 16/09 (8/2/1 rows on 14/15/16 Sep, none after); rejected sessions left no rows, so lost study time cannot be quantified. Study Mode insert also ignores the returned `error`.

### [21/09/2026] Question Type filter on Browse Study Sets was not carried into Study Mode — ✅ FIXED (frontend push pending)
- Observed live: filter = Case study MCQ, "Study All" navigated to /dashboard/study?subject=… only, so the session loaded the whole subject. **Fix:** ReviewFlashcards.jsx adds ?type=<question_type> when a type filter is active; StudyMode.jsx filters cards by it. **Verified on dev build (live DB):** URL carried type=case_study_mcq, first card was a case study, session showed 40 cards.

### [21/09/2026] Case-study scenario pushed question/options far below the fold on phones — ✅ FIXED (frontend push pending)
- Scenario stays expanded by default (students see the context) but is now a scroll box, max-h-[40vh]. **Verified at 375px:** 1,381px of scenario text in a 325px scroll area; the QUESTION label and question start on the first screen. Collapse toggle unchanged.

### [21/09/2026] Label alignment inconsistency on left-aligned cards — ✅ FIXED (operator request)
- QUESTION/ANSWER badges + speech icons were centred above left-aligned text. Now left-aligned for theory (front + answer), the ANSWER label in the shared layout, and the case_study_mcq QUESTION label. Verified on dev build (live DB).

### [21/09/2026] Browse count mismatch (type filters sum to 1,225 vs 1,091 "All Types") — CAUSE PROVEN IN CODE, fix needs SQL approval
- **Cause:** get_browsable_decks v7 (sprint8.7.4/02) returns decks that contain >=1 matching card when p_question_type is set, but its card_count is deliberately type-agnostic (the deck's whole visible total; comment at the "QUESTION TYPE FILTER" block). ReviewFlashcards.jsx sums card_count, so under a filter "N cards available" / "Study All (N)" show deck totals, and mixed-type decks are counted under several filters. Not a data error.
- **Proposed fix (awaiting operator approval):** get_browsable_decks v8 adds a matching_card_count column (visible cards of the requested type; equals visible_card_count when no filter); frontend uses it while a type filter is active. SQL must deploy first.

### [21/09/2026] Recorded for extraction workflow (not fixed here): theory answers stored with inline "•" bullets and no line breaks (0 LF/CR in 8 sampled rows); "▯" in place of bullets; case text as one paragraph.

### [21/09/2026] B1 — 400 on refresh_token + "Invalid Refresh Token" — ✅ CLOSED, stale-session noise, no code change
- **Reproduced on live** (bad refresh token + expired access token, browser pane only): exactly one 400 on /auth/v1/token?grant_type=refresh_token, AuthApiError in console, app cleared the stored session and redirected to /login. No stuck loading. Real session restored afterwards (refresh 200). AuthContext already recovers correctly; no auth change.

### [21/09/2026] B2 — 403 on admin_audit_log — ✅ FIXED and live-verified
- **Proven cause: role-gating bug.** BulkUploadFlashcards.jsx (/dashboard/bulk-upload, open to all signed-in users) inserted into admin_audit_log after every successful upload with no role check. admin_audit_log INSERT is RLS-restricted to admin/super_admin. **Proof (live, professor account, 21/09/2026):** POST /rest/v1/admin_audit_log -> 403, code 42501, "new row violates row-level security policy for table admin_audit_log" (nothing written). The supabase-js error is returned, not thrown, so the surrounding try/catch never fired — silent 403.
- **Ruled out (live):** professor login/study session (no audit request); admin login (201); admin on /super-admin ("Access Denied", no request); super_admin login (201) and /super-admin audit read (200).
- **Fix:** audit insert now runs only when isAdmin (admin or super_admin). No RLS/SQL change. Other writers (AdminDashboard, BulkUploadTopics) already role-gated.
- **Live verification (21/09/2026, after deploy 6dbbd65):** professor uploaded a 1-row private test CSV -> "Successfully uploaded 1 study item", **0 admin_audit_log requests, 0 errors** in the request log. Test card then deleted. Side effect: one orphaned flashcard_batch_provenance row (batch 5e76768d-…) — the known 8.7.6 final-card-delete gap, reproduced; cleanup in docs/database/sprint8.7.7/07_CLEANUP_remove_b2_test_provenance_row.sql (operator to run).


## Sprint 8.7.6 — 21/09/2026 (Merge-batches provenance)

### [21/09/2026] Merging batches silently overwrote provenance and left orphan provenance rows — ✅ FIXED (frontend push pending)
- **Symptom:** `executeMerge` moved cards to the first batch's `batch_id` from the browser; merged cards silently took the target's provenance label; merged-away batches kept orphan provenance rows. Resolves the 8.7.4 "known limitation" entry below.
- **Fix:** server-side triggers enforce identical-provenance-or-both-legacy and delete the emptied source batch's provenance row atomically. UI pre-check added. Live data at fix time: 0 existing orphans.

### [21/09/2026] Merging the "no-batch" group sent a non-UUID string to `.in('batch_id', …)` and failed — ✅ FIXED (frontend push pending)
- **Cause:** `getGroupedFlashcards` keys NULL-batch cards as `'no-batch'`; `executeMerge` passed that string to a uuid filter. **Currently unreachable** (0 NULL-batch cards, Step 0) but guarded: UI blocks with a message; server also blocks moves to/from NULL.

### [21/09/2026] OPEN (recorded, not fixed): deleting the final cards of a batch can leave its provenance row orphaned — out of scope for 8.7.6.

## Sprint 8.7.4 — 18/09/2026 (Content provenance display)

### [18/09/2026] `handleMergeBatches` (`MyFlashcards.jsx`) doesn't reconcile `flashcard_batch_provenance` on merge — KNOWN LIMITATION, deliberately deferred, not fixed
- **Found while:** an independent `/code-review` pass (SQL correctness + cross-file tracer angles) requested as part of an auditor reconciliation before declaring Sprint 8.7.4 done.
- **Symptom:** merging batch A into batch B (`MyFlashcards.jsx`'s batch-merge feature) does `UPDATE flashcards SET batch_id = targetBatchId WHERE batch_id IN (...)`, reassigning A's cards to B's `batch_id`, but never touches `flashcard_batch_provenance`. Post-merge, A's cards display B's provenance badge (or no badge, if B has none) regardless of what A's own declared source actually was.
- **Root Cause:** this is a **pre-existing gap**, not a regression introduced by 8.7.4 — the merge feature predates content provenance entirely and was never designed with it in mind. It had zero visible effect before this sprint (nothing displayed provenance at all); this sprint's badge display is what makes the misattribution visible for the first time.
- **Why not fixed now:** a correct fix requires a product decision this sprint's scope (display-only) doesn't cover — should a merge preserve each card's own original provenance (requiring per-card, not per-batch, provenance — a bigger architecture change than D-21's current batch-level model), require the user to re-declare a source for the merged batch, or show an explicit "mixed sources" state? None of these are a quick line fix.
- **Status:** ⚠️ KNOWN LIMITATION, not resolved. Flagged for a future sprint's disposition, same pattern this project uses for other found-but-deferred issues (see `flashcards.source` bug's own deferred-then-later-fixed history in this same file, Sprint 8.7.1→8.7.2).
- **Auditor disposition (Sprint 8.7.5, 18/09/2026):** re-raised during Phase 8.7's final reconciliation and explicitly kept as an **open backlog bug, not a qualification on Phase 8.7/D-21 completion** — it concerns provenance integrity under a separate, adjacent operation (merging batches), not the creation/enforcement/display paths D-21 actually scoped. Phase 8.7 and D-21 are marked complete with this bug still open, by design.

### [18/09/2026] `ReviewSession.jsx` dropped `get_study_queue`'s new `batch_id` field, silently defeating the SQL fix for the most common study entry point — ✅ FIXED
- **Found while:** resolving an auditor request to reconcile every consumer of `get_study_queue` against its new `batch_id` column, not just the RPC itself.
- **Symptom:** `get_study_queue` was correctly extended to return `batch_id` (SQL-side proven via a live spot-check, T6). But `ReviewSession.jsx`'s `fetchDueCards` maps each RPC row into a plain object literal (`cleanedCards`) passed to `StudyMode.jsx` — this mapping explicitly lists every field it forwards (`id`, `user_id`, `front_text`, `rung`, etc.) and never included `batch_id: row.batch_id`. Since this is the "Today's Reviews" due-queue path — the primary, most-used study entry point — every card studied through it would silently never show a provenance badge, even when the card's batch genuinely had one, while cards reached via `StudyMode.jsx`'s own direct deck-browse fetch (unaffected, already had `batch_id` via `SELECT *`) would work fine.
- **Root Cause:** the SQL change (add a column to the RPC) and the frontend change (wire the badge into `StudyMode.jsx`) were both done, but the intermediate consumer (`ReviewSession.jsx`'s row-mapping) was never traced as a distinct integration point — the original live verification only exercised the direct-fetch path (clicking into a deck from Browse Study Sets), never actually clicked "Today's Reviews," so this gap went unnoticed until specifically asked to re-verify.
- **Fix:** added `batch_id: row.batch_id` to the mapping (`src/pages/dashboard/Study/ReviewSession.jsx`), one line, same pattern as every other forwarded field.
- **Status:** ✅ RESOLVED — `npx eslint`/`npx vite build` clean. Live-verified the path doesn't crash and behaves correctly (no badge on a genuine no-provenance due card, via the real "Today's Reviews" flow) — a positive-case check (a due card that DOES have provenance) wasn't performed because the specific test card that would have proven it was already deleted by this sprint's own cleanup SQL before the gap was found; re-verified instead via a byte-exact diff of the SQL change (zero drift beyond the additive column) plus direct code inspection of the one-line fix.

### [18/09/2026] `MyFlashcards.jsx`'s "grouped" view (the page's own default) never passed the new `provenance` prop to individual cards inside a batch group — ✅ FIXED
- **Found while:** the same auditor-requested consumer trace above, checking every `<FlashcardCard>` render site.
- **Symptom:** `MyFlashcards.jsx` has two `<FlashcardCard>` call sites — the flat/filtered grid view (fixed first) and a second one inside the "grouped" (batch-header) view's per-card grid, which was missed on the first pass. The per-card badge silently never rendered there, even though the batch-group header directly above already showed it correctly.
- **Root Cause:** two near-identical `<FlashcardCard>` call sites in the same file; the provenance prop was added to one during the initial build and the second was overlooked.
- **Status:** ✅ RESOLVED — one line (`provenance={provenanceByBatch.get(card.batch_id)}`), `npx eslint`/`npx vite build` clean.

### [18/09/2026] `StudyMode.jsx`'s provenance fetch had no stale-response guard — a plausible race condition, not live-triggered — ✅ FIXED
- **Found while:** an auditor-requested line-by-line diff scan of the new `useEffect`.
- **Symptom:** the `useEffect` that fetches batch provenance re-fires whenever `batchIdKey` (the sorted, joined set of distinct batch_ids in the current card list) changes — session restart, suspend-topic, skip-topic. The `.then(setProvenanceByBatch)` callback had no guard against an older fetch resolving after a newer one; if two fetches overlapped (e.g. a user restarting a session twice in quick succession, or ordinary network jitter reversing response order), the map could briefly or persistently show the wrong batch's provenance data.
- **Root Cause:** no cleanup/cancellation token on the async effect — a well-known React pattern gap, not specific to this feature.
- **Fix:** added a `cancelled` flag set by the effect's cleanup function; the `.then()` callback now checks it before calling `setProvenanceByBatch`.
- **Status:** ✅ RESOLVED — `npx eslint`/`npx vite build` clean. Not independently live-reproduced (the race window is narrow and timing-dependent) — fixed on code-review confidence per the standard React stale-closure/cleanup pattern, same class of fix used elsewhere in this codebase's own `useEffect`s.

### [18/09/2026] `get_browsable_decks` v7's first deploy used `min(uuid)`, which doesn't exist — every call to the function failed — ✅ FIXED, live-verified
- **Found while:** the operator's own live T4 verification query (`SELECT id, provenance_source_type, provenance_source_name FROM get_browsable_decks() LIMIT 20;`), run immediately after deploying `docs/database/sprint8.7.4/02_FUNCTIONS_get_browsable_decks_v7_provenance.sql`.
- **Symptom:** `ERROR: 42883: function min(uuid) does not exist`, raised inside `RETURN QUERY` — meaning the `DROP FUNCTION`+`CREATE OR REPLACE FUNCTION` deploy itself succeeded with no syntax error, but the function was broken the moment anyone called it. `ReviewFlashcards.jsx` ("Browse Study Sets") would have been completely broken for every user had this reached the frontend before being caught.
- **Root Cause:** the new `sole_batch_id` expression, `CASE WHEN count(DISTINCT fc.batch_id) = 1 THEN min(fc.batch_id) ELSE NULL END`, used `min()` over a `uuid` column. Postgres has no default B-tree ordering operator class for `uuid` for `min()`/`max()` to use — this was written and reviewed without testing against a live Postgres instance, since this session had no SQL access of its own.
- **Fix:** replaced `min(fc.batch_id)` with `(array_agg(fc.batch_id))[1]` — picks an arbitrary element from the aggregated array, which is safe specifically because the surrounding `CASE` already gates on `count(DISTINCT fc.batch_id) = 1`, so every element in that array is guaranteed identical.
- **Status:** ✅ RESOLVED (18/09/2026) — re-deployed by the operator, re-verified live: `get_browsable_decks()` returns correctly for real deck data (1/20 sampled decks resolved real single-batch provenance, 19/20 correctly `NULL` for multi-batch/legacy decks). `docs/database/sprint8.7.4/02_FUNCTIONS_get_browsable_decks_v7_provenance.sql`.

## Sprint 8.7.1 — 18/09/2026 (Content provenance DB foundation)

### [18/09/2026] `flashcards.source` defaults to `'manual'` for every insert, including bulk uploads — ✅ FIXED Sprint 8.7.2, live-verified
- **Found while:** Step 0 diagnostic for the content-provenance sprint (`docs/database/sprint8.7/00_DIAGNOSTIC_pre_provenance.sql`), cross-checking `flashcards.source`'s column default against how it's actually populated.
- **Symptom:** `flashcards.source` is `NOT NULL DEFAULT 'manual'::text`. Neither `src/pages/dashboard/Content/FlashcardCreate.jsx` nor `src/pages/dashboard/BulkUploadFlashcards.jsx` ever sets `source` explicitly in their insert payloads (confirmed via code grep, zero matches for `source` in either file) — so every card, whether hand-authored or CSV-bulk-uploaded, silently gets `source = 'manual'` from the column default. `source` is therefore not a reliable signal of how a card was actually created.
- **Root Cause:** neither creation path ever passed `source`. Confirmed live pre-fix via Sprint 8.7.2's diagnostic (`docs/database/sprint8.7.2/00_DIAGNOSTIC_pre_restore.sql` §5b): 100% of production `flashcards.source` values were `'manual'`, with zero `'bulk_upload'` rows despite bulk uploads having occurred.
- **Fix (Sprint 8.7.2):** `create_flashcard_batches()` gained a `p_creation_channel` parameter (`'manual' | 'bulk_upload' | 'gemini_import'`, validated server-side), written to `flashcards.source` explicitly on every row the RPC inserts — never left to the column default. `FlashcardCreate.jsx` passes `'manual'`, `BulkUploadFlashcards.jsx` passes `'bulk_upload'`. See `docs/database/sprint8.7.2/01_FUNCTIONS_creation_channel.sql` and DATABASE_SCHEMA.md §4.0b.
- **Status:** ✅ FIXED, live-verified via a real bulk CSV upload post-deploy — resulting rows show `source='bulk_upload'`, manually-created rows show `source='manual'`. Closed on live verification, not code inspection alone.

## Sprint 8.3 — 16/09/2026 (Bug fixes + Help renderer: hyperlinks & screenshots)

### [16/09/2026] `create_batch_group` never set `study_groups.group_type` — every batch created through the live Admin Dashboard button silently skipped the student-approval gate — ✅ FIXED
- **Found while:** setting up a disposable test batch group to capture Sprint 8.3's admin-workflow screenshots. A dummy student account requested to join and landed as a full active member instantly, with no "Pending Batch Requests" row ever appearing — expected [D-15](active/blueprint.md)'s approval queue, got instant membership.
- **Symptom:** `join_group_by_token` only routes a student into `status='requested'` when `study_groups.group_type = 'batch'` (`IF v_group_type = 'batch' AND v_caller_role = 'student'`). The batch created via the live "Create Batch Group" button had `is_batch_group = true` but `group_type = 'custom'` — so both a genuine `role='student'` caller and a staff caller fell through to the function's final unconditional branch, which inserts `status='active'` directly.
- **Root Cause:** the live `create_batch_group(p_course_level, p_name, p_description, p_institution)` INSERTs `is_batch_group` but never includes `group_type` in its column list, so it silently took the column's own default (`'custom'`). `group_type` and `is_batch_group` are two separate columns describing the same concept — D-16's pre-flight (15/09/2026) confirmed them 1:1-consistent across the 3 real batches that existed *at that time*, so the check never caught that any *newly created* batch would drift, since apparently no new batch group had been created via the live function between then and this session.
- **Scope confirmed via diagnostic SQL** (`docs/database/sprint8.3/00_DIAGNOSTIC_batch_join_instant_approve.sql`, `01_DIAGNOSTIC_batch_group_type_scope.sql`, both run by the operator in Supabase SQL Editor): all 3 real production batches (CA Final, CA Foundation, CA Intermediate — all created 18-19/03/2026) correctly have `group_type = 'batch'` and were never affected. Only a batch created through the live (buggy) function after whichever change last replaced it would hit this — impact on real usage depends on whether any admin created a new batch group in that window, which this session could not determine.
- **Fix:** `docs/database/sprint8.3/02_FIX_create_batch_group_type.sql` — `CREATE OR REPLACE FUNCTION create_batch_group` now includes `group_type` (literal `'batch'`) in the INSERT; also backfills the one known bad row (this session's disposable test batch). Deployed and verified live by the operator (`03_TEST_verify_batch_group_type_fix.sql` — all batches now show `group_type='batch'`; re-creating a fresh test batch and re-running the student-join flow correctly produced a pending request, approved/rejected normally).
- **Status:** ✅ RESOLVED (16/09/2026) — SQL only, no frontend change needed (the frontend already correctly branches on `group_type === 'batch'` everywhere; only the write path was wrong). Confirmed via live re-test: a second disposable test batch + a dummy student account correctly produced a "Pending Batch Requests" row this time, approve/reject both worked.

## Sprint 8.2 — 16/09/2026 (Help documentation corrections)

### [16/09/2026] Deleting a note never removed its image from Storage — every note delete leaked its file forever — ✅ FIXED
- **Found while:** a file-cleanup audit (unrelated to Sprint 8.2) noticed 8 images in the `notes` Storage bucket with no matching `notes.image_url` anywhere; a diagnostic cross-referencing `storage.objects` against live `image_url` values confirmed 8 genuine orphans (~47MB).
- **Symptom:** `MyNotes.jsx`'s student self-delete (`handleDelete`) and `AdminDashboard.jsx`'s moderation delete (`deleteNote`) both did only `supabase.from('notes').delete().eq('id', noteId)` — the Storage object at `notes.image_url` was never removed. `NoteEdit.jsx` gets this right on image *replace* (calls `storage.remove()` on the old file), but outright note deletion leaked it.
- **Root Cause:** the delete handlers were written to remove the DB row only; nobody added the matching Storage cleanup when either handler was built. Confirmed no DB trigger covers this either — the only `DELETE` trigger on `notes` (`trg_aaa_counter_notes`) just decrements a counter.
- **Fix:** new `src/lib/noteStorage.js` (`extractNoteStoragePath`, `deleteNoteStorageImage` — best-effort, warns not throws so a Storage failure never blocks a DB delete that already succeeded). Both `MyNotes.jsx` and `AdminDashboard.jsx` now look up the note's `image_url` before deleting the row, then call `deleteNoteStorageImage()` after the DB delete succeeds (`AdminDashboard.jsx`'s `fetchContent()` select also needed `image_url` added — it wasn't previously fetched).
- **Not retroactive:** the fix only stops *future* leaks. The 8 pre-existing orphans required a one-time manual cleanup via the Supabase Dashboard (no trash/versioning on Storage — deletion there is immediate and permanent, so Claude does not perform it programmatically).
- **Status:** ✅ RESOLVED (16/09/2026) — `src/lib/noteStorage.js` (new), `src/pages/dashboard/Content/MyNotes.jsx`, `src/pages/admin/AdminDashboard.jsx`. `npm run build` + `npx eslint` both clean. **Not done:** live click-through delete of a real note (destructive against production data) — verified by lint/build/code-review only; operator should confirm on a throwaway note before trusting fully.

### [16/09/2026] Bulk Upload CSV silently downgrades `match_the_following`/`concept_card` rows to a plain flashcard instead of rejecting them — ✅ FIXED (Sprint 8.3)
- **Found while:** verifying the real CSV column set for the new Help documentation against `BulkUploadFlashcards.jsx`'s parser (Sprint 8.2).
- **Symptom:** `RECOGNIZED_QUESTION_TYPES` (`src/pages/dashboard/BulkUploadFlashcards.jsx:35`) is `['mcq', 'correct_incorrect', 'theory', 'case_study_mcq', 'fitb']`. The parser's fallback (`flashcard.question_type = RECOGNIZED_QUESTION_TYPES.includes(cleanQuestionType) ? cleanQuestionType : 'flashcard'`, line 435) meant a row with `question_type` set to `match_the_following` or `concept_card` — or any typo, e.g. `mcqq` — was never flagged as an error. It was silently created as a plain `flashcard` using whatever `front`/`back` text was supplied, with every type-specific column (options, scenario, key terms, etc.) discarded.
- **Root Cause:** the fallback was written as a permissive "unknown type → safe default" for genuinely blank cells (the common case — most rows have no `question_type` at all), but it did not distinguish "blank" from "recognized-but-unsupported" from "misspelled." All three fell into the same silent downgrade.
- **Impact:** a professor trying to bulk-create match_the_following or concept_card content (both unsupported by CSV, manual-authoring only) got no error message — just a pile of unexpectedly-plain flashcards missing the structure they typed into the wrong columns. A simple typo in `question_type` for any row had the same silent effect.
- **Fix (Sprint 8.3, A1):** a non-blank, unrecognized `question_type` now pushes a specific row error (`Row N: question_type 'X' isn't supported for bulk upload yet — create these individually.`) and the row is skipped, matching every other missing-required-field case in this function. A genuinely blank cell is unchanged — still silently defaults to `flashcard`, since that's the common, intentional case (most rows have no `question_type` at all).
- **Verified:** the exact gate logic was extracted and run standalone against 8 cases (`match_the_following`, `concept_card`, the typo `mcqq`, case-insensitive `MCQ`, blank, missing, whitespace-only, and a valid `fitb`) — all 8 matched expected accept/reject behavior. Not live-clicked through the actual file upload (the Browser pane tool used this session has no file-upload capability) — `npm run build` + `npx eslint` both clean.
- **Status:** ✅ RESOLVED (16/09/2026) — `src/pages/dashboard/BulkUploadFlashcards.jsx`.

### [16/09/2026] `downloadTemplate()`'s own CSV rows carried the same unqualified, regime/year-dependent tax figures the help docs were corrected for — ✅ FIXED (Sprint 8.3)
- **Found while:** Sprint 8.2's Quality Auditor follow-up fixed this exact class of issue in `helpContent.js`'s prose examples but explicitly left the app's own downloadable template untouched (logged as a follow-up here) since the help doc's copied-verbatim examples needed to stay byte-identical to the real download.
- **Symptom:** `downloadTemplate()` (`BulkUploadFlashcards.jsx`) had a flashcard row asking for "the basic exemption limit" answered `₹2.5 lakhs`, a `correct_incorrect` explanation citing `Rs 10000` under Section 80TTA, and a `fitb` row repeating the same `₹2.5 lakhs` figure as an acceptable answer — all real, budget-year-dependent numbers presented with no caveat, in a file professors download and could plausibly reuse or half-copy into real content.
- **Fix (Sprint 8.3, A2):** the flashcard row now asks a structural, non-time-dependent question ("difference between a direct tax and an indirect tax"); the `correct_incorrect` explanation now describes the *rule* (a limited exemption exists under 80TTA/80TTB, not unlimited) without citing a figure; the `fitb` row now asks for the section number governing 80C-type deductions (`80C`) instead of a rupee amount — a stable structural fact, not a number that moves every budget.
- **Verified:** the corrected template rows were parsed with the app's own `parseCSVLine` (copied verbatim into a standalone test) — all 10 example rows still produce exactly 18 columns each, including the new `fitb` row whose front field contains commas and needed proper quoting.
- **Status:** ✅ RESOLVED (16/09/2026) — `src/pages/dashboard/BulkUploadFlashcards.jsx`. Out of scope (per the sprint brief): the already-corrected `helpContent.js` CSV examples were left untouched, so those two files' example rows are now cosmetically different from each other (both are individually correct, just no longer verbatim copies) — a minor drift, not a defect.

### [16/09/2026] Seven Help sections described a batch-enrollment model D-15/D-16 had already replaced — ✅ FIXED (documentation only)
- **Found while:** the sprint's own pre-flight instruction to compare `prof-welcome`/`prof-profile-setup`/`prof-batch-groups`/`prof-batch-performance`/`admin-dashboard-overview`/`admin-access-requests`/`admin-batch-groups` against current code.
- **Symptom:** all seven sections still described the pre-Sprint-8.0 world — "Students enrolled in your batch are automatically assigned to the same course and institution group," "Batch auto-enrollment matches on both fields," "the system automatically enrolls that student in the matching batch group," "Students with matching institution + course level will be auto-enrolled when you grant them access." None of this has been true since Sprint 8.0 retired `fn_auto_enroll_batch_group` entirely (D-15). The admin section also named the wrong Admin Dashboard tabs ("Recent Users," "Content" instead of the real "User Management," "Content Moderation").
- **Root Cause:** the help text was never updated when D-15 (Sprint 8.0) and D-16 (Sprint 8.1) shipped — a documentation gap, not a code defect.
- **Fix:** all seven sections rewritten to describe the real invite-link → request → approve/reject (or direct-add) flow and the archive/restore lifecycle, with exact current button labels and tab names confirmed against `AdminDashboard.jsx`/`GroupJoin.jsx`.
- **Status:** ✅ RESOLVED (16/09/2026, `src/data/helpContent.js`).

### [16/09/2026] Three super-admin Help sections had wrong button labels, wrong confirmation flows, and misattributed analytics content — ✅ FIXED (documentation only)
- **Found while:** the sprint's own pre-flight instruction to spot-check the three existing super-admin-only sections against the current dashboard.
- **Symptom:** `superadmin-user-roles` described clicking a role badge to open a "role change dialog" with a free role picker including `super_admin` — the real UI (`SuperAdminDashboard.jsx`) is per-current-role "Prof"/"Admin"/"Student" buttons with no path to `super_admin`, confirmed via a plain browser `prompt()`. `superadmin-hard-delete` named a "Delete User" button and an email-confirmation step — the real control is an unlabeled trash icon and a "type DELETE in capital letters" `prompt()`; the deleted-data list also included "friend connections," not part of the real `admin_delete_user_data` scope, and omitted that the Supabase auth record survives and needs a manual follow-up delete in the Supabase Dashboard. `superadmin-sa-analytics` listed the wrong header stats and cohort-table columns, and attributed two features (Retention Cards, Audit Log) to SA Analytics that actually live on the separate Super Admin Dashboard page.
- **Root Cause:** documentation drift — these sections were apparently written to a planned design rather than kept in sync with what shipped.
- **Fix:** all three corrected in place (surgical fixes, not full rewrites, per the sprint's own scope instruction).
- **Status:** ✅ RESOLVED (16/09/2026, `src/data/helpContent.js`).

### [16/09/2026] Fabricated "Maximum 200 cards per upload" claim in Help — ✅ FIXED (documentation only)
- **Found while:** verifying the old `prof-bulk-csv` Help section's claims against the actual upload code.
- **Symptom:** the tip read "Maximum 200 cards per upload." A full search of `BulkUploadFlashcards.jsx` and every RPC it calls found no row-count cap anywhere in the pipeline — client-side or server-side.
- **Root Cause:** unknown — no corresponding limit has ever existed in the code searched.
- **Fix:** claim removed; no cap is now documented since none exists.
- **Status:** ✅ RESOLVED (16/09/2026, `src/data/helpContent.js`).

### [16/09/2026] Quality Auditor follow-up — CSV header-row example would have broken on copy-paste — ✅ FIXED
- **Found while:** independent Quality Auditor review of Sprint 8.2's new help content, checking the CSV example against the actual parser rather than trusting the "guaranteed to match the uploader" claim.
- **Symptom:** the earlier same-day overflow fix (see the note-delete/bulk-CSV work above) added a space after every comma in all raw CSV example lines, including the header-row example (`target_course, subject, topic, ...`). `BulkUploadFlashcards.jsx`'s parser (`const headers = parseCSVLine(headerLine)`) never trims header names — only cell *values* are trimmed (`cleanValue = value.toString().trim()`). A literal copy-paste of the spaced header would produce object keys like `" subject"` (with a leading space), which the parser's own `flashcard.subject`/`flashcard.target_course` lookups would never match, silently breaking every row.
- **Root Cause:** the wrapping fix was applied uniformly to all raw CSV example lines without checking that headers and values are parsed asymmetrically (values trimmed, headers not).
- **Fix:** removed the header-row example entirely rather than re-spacing it — it was redundant with the column-by-column bullet list already in the same section, and the exact literal header is one click away via "Download the Template." The data-row examples (Flashcard row, Theory row, etc.) were correctly left spaced, since those values are trimmed and were never actually at risk.
- **Status:** ✅ RESOLVED (16/09/2026, `src/data/helpContent.js`).

### [16/09/2026] Quality Auditor follow-up — new Help text mischaracterized `match_the_following`'s CSV support and FITB's grading — ✅ FIXED
- **Found while:** the same Quality Auditor review, checking every claim in the new `prof-question-type-authoring` section against the actual capability matrix already established during Sprint 8.2's own pre-flight.
- **Symptom 1:** the section's opening sentence read "Multiple Choice, Correct/Incorrect, Case study MCQ, Match the following, and Fill in the Blank are only creatable from a professor or admin account, in both manual creation and Bulk Upload" — grouping Match the following with the CSV-supported types, when it has never been CSV-supported for any role (confirmed earlier in the same sprint's own research).
- **Symptom 2:** the section's closing tip read "These five types are gated because a wrong verdict automatically marks the student's card Hard" — true for the other four, but Fill in the Blank has no "wrong" verdict at all (D-13's confidence-gated design) — only a match or a self-graded fallback. The blanket wording implied FITB could also auto-penalize a student, which it structurally cannot.
- **Root Cause:** both were drafting slips — writing about "the five gated types" as a single group when two of their properties (CSV support, grading mechanism) genuinely differ by type.
- **Fix:** the opening sentence now explicitly carves out Match the following as manual-only; the closing tip is split into two sentences, one for the four auto-Hard types and one describing FITB's actual mechanism (an incomplete answer list under-recognizes correct answers rather than penalizing them).
- **Status:** ✅ RESOLVED (16/09/2026, `src/data/helpContent.js`).

### [16/09/2026] Quality Auditor follow-up — Hard Delete help text guaranteed something not actually verified — ✅ FIXED
- **Found while:** the same review, checking the `superadmin-hard-delete` section's audit-log claim against what was actually confirmed about `admin_delete_user_data`'s transactional behavior.
- **Symptom:** the text read "The deletion is logged in admin_audit_log before it runs, so a record survives even if the delete itself fails partway." Only the ordering (log-then-delete) was ever actually confirmed via a code comment; whether the log entry survives a failed deletion depends on whether both operations share a transaction, which was never verified.
- **Root Cause:** an inferred guarantee stated as fact without checking the transactional boundary.
- **Fix:** replaced with "The system attempts to record the action before deletion runs" — accurate to what's actually known. Also removed the `admin_audit_log` table-name reference from the same sentence (implementation detail, doesn't belong in user-facing help per project convention).
- **Status:** ✅ RESOLVED (16/09/2026, `src/data/helpContent.js`).

### [16/09/2026] Quality Auditor follow-up — new tax examples in Help text had no year/regime qualifier — ✅ FIXED (own prose); ⚠️ OPEN (app's own CSV template)
- **Found while:** the same review, flagging that Sprint 8.2's new question-type examples (₹2.5 lakh basic exemption limit, Section 80TTA's ₹10,000 exemption) stated specific figures with no applicable year or tax regime — risking being read as current, authoritative tax advice rather than illustrative examples.
- **Fix (own prose):** every example that was newly written for this sprint (not copied from the app) was swapped to a timeless alternative already present in the app's own real template — a 20%-of-500 percentage question, and an "AS 1 — disclosure of accounting policies" example. A caveat tip was added next to the CSV example rows that couldn't be swapped (see below).
- **Real product issue found, not fixed (out of scope for a content-only sprint):** `BulkUploadFlashcards.jsx`'s `downloadTemplate()` function embeds the same unqualified ₹2.5 lakh/Section 80TTA figures as its own shipped example rows — the actual downloadable file a professor uses, not just this sprint's documentation of it. Sprint 8.2's help text copies these verbatim (by design, so the docs are guaranteed to match the real download) and now carries an explicit caveat, but the underlying template file itself still has no year/regime qualifier. A future sprint should either add one or swap those specific example rows to non-tax figures directly in `downloadTemplate()`.
- **Status:** ✅ RESOLVED for `src/data/helpContent.js`'s own prose (16/09/2026). ⚠️ OPEN for `BulkUploadFlashcards.jsx`'s template content — flagged for a future sprint.

## Sprint 8.1 — 15/09/2026 (batch group Active/Archived lifecycle)

### [15/09/2026] `sg_delete_creator` / `sg_update_creator` RLS had no batch-group clause — creating admin could delete a batch group or write `archived_at` directly, bypassing the snapshot transaction — ✅ FIXED
- **Found while:** pre-flight for D-16 (needed to confirm no existing "block batch deletion" guard existed before designing one) — read the live RLS policies on `study_groups` directly.
- **Symptom (theoretical, not observed live):** `sg_delete_creator` (`USING (created_by = auth.uid())`) and `sg_update_creator` (same) had no `is_batch_group` condition at all — pre-dating batch groups entirely, never revisited when the column was added. The only thing stopping a batch group's creating admin from deleting it, or from writing `archived_at` straight via a client `.update()` call (skipping `archive_batch_group`'s snapshot-capture transaction entirely, corrupting the archived-report requirement this sprint exists to build), was `MyGroups.jsx` hiding the button client-side — the RLS itself permitted both.
- **Root Cause:** both policies were written before batch groups existed and were never updated when `is_batch_group` was introduced.
- **Fix (`docs/database/sprint8.1/01_SCHEMA_add_archiving.sql`):** both narrowed to add `AND is_batch_group = false`. Safe — batch groups have never had a direct-edit UI (AdminDashboard's batch tab is read-only display), so no existing capability is removed; all batch group metadata changes now go exclusively through the new `SECURITY DEFINER` RPCs, which are unaffected by RLS.
- **Verified via:** a dedicated live diagnostic (`07_DIAGNOSTIC_rls_delete_investigation.sql`) impersonating the creating admin under `SET ROLE authenticated` (not just `postgres` with `jwt.claims` set, which still bypasses RLS as superuser) — confirmed the DELETE affects 0 rows and the row survives; `04_TEST`'s equivalent checks pass. (An earlier test-script draft checked row-visibility *before* resetting role, which made the same-working policy look like a failure — see `now.md`'s Sprint 8.1 entry for the full trail.)
- **Status:** ✅ RESOLVED (15/09/2026, SQL deployed & verified live).

### [15/09/2026] `sgm_insert_admin` RLS had no archived check — direct client INSERT could add a member to an archived batch, bypassing `enroll_user_in_batch_group`'s guard — ✅ FIXED
- **Found while:** same pre-flight pass, checking every write path to `study_group_members` for an archived-bypass risk (the sprint's own "ensure direct client writes cannot bypass the restriction" requirement).
- **Symptom (theoretical):** the INSERT policy allows any caller who is `role='admin'` in a group's own `study_group_members` to insert new member rows for that `group_id` — with no check against the target group's archived state. A client call built directly against this policy (skipping `enroll_user_in_batch_group` entirely) could add a member to an archived batch.
- **Root Cause:** the policy predates the archived_at concept (this sprint introduces it) and, more generally, predates any RPC-guard-bypass consideration for this INSERT path.
- **Fix (`docs/database/sprint8.1/01_SCHEMA_add_archiving.sql`):** added `AND NOT EXISTS (SELECT 1 FROM study_groups sg WHERE sg.id = group_id AND sg.archived_at IS NOT NULL)` to the policy's `WITH CHECK`.
- **Status:** ✅ RESOLVED (15/09/2026, SQL deployed; covered indirectly by `04_TEST`'s enrollment-path checks — `enroll_user_in_batch_group` itself refuses first, so this INSERT policy is defense-in-depth not separately exercised by a raw client-side INSERT in the test).

### [15/09/2026] `leave_group` cascade-delete had no batch-group exclusion — a batch group's last active member leaving would delete the group row — ✅ FIXED
- **Found while:** pre-flight audit of every existing `study_groups` deletion path, per the sprint's "existing deletion routes must also refuse batch-group deletion" requirement.
- **Symptom (theoretical, not observed live):** `leave_group`'s `IF v_member_count = 1 THEN DELETE FROM study_groups...` fires for any group, batch or not, whenever its last **active** member leaves — cascading to `study_group_members` and `content_group_shares`. A batch group could reach that state (e.g. an admin removing everyone down to one member, who then leaves), silently deleting the group and losing the ability to ever archive/restore or report on it again.
- **Root Cause:** the branch was written before batch groups existed and was never given a batch-aware exclusion.
- **Fix (`docs/database/sprint8.1/03_FUNCTIONS_guard_enrollment_paths.sql`):** condition changed to `IF v_member_count = 1 AND NOT v_is_batch THEN` — a batch group's lifecycle is now exclusively `archive_batch_group`/`restore_batch_group`. Ordinary-group behavior (the delete still fires) is unchanged.
- **Verified via:** `04_TEST` — a batch group's last active member leaving no longer deletes the row (group persists), while an ordinary group under the identical scenario still cascade-deletes (unchanged) — both PASS.
- **Status:** ✅ RESOLVED (15/09/2026, SQL deployed & verified live, 04_TEST 33/33 PASS).

## Sprint 8.0 — 15/09/2026 (batch invite-link joining with admin approval)

### [15/09/2026] `create_batch_group` had no admin guard — any authenticated user could call it — ✅ FIXED
- **Found while:** rewriting `create_batch_group` for Sprint 8.0's approval workflow (unrelated to that change) — `pg_get_functiondef` on the live body showed no `is_admin()`/role check anywhere before its writes.
- **Symptom (theoretical, not observed live):** any authenticated user (not just an admin) could call `create_batch_group` directly and create arbitrary batch groups.
- **Root Cause:** same class of gap already found and fixed for `enroll_user_in_batch_group`/`notify_access_granted` in the earlier residual-IDOR sweep (`docs/database/security/15`) — this function was never included in that sweep.
- **Fix:** added `IF NOT public.is_admin() THEN RAISE EXCEPTION` at the top, matching the established pattern. Bundled into `docs/database/sprint8.0/02_FUNCTIONS_batch_join_approval.sql` since the function was already being replaced for the approval-workflow change; verified via `03_TEST`'s "non-admin create_batch_group blocked" check — PASS.
- **Status:** ✅ RESOLVED (15/09/2026, SQL deployed & verified live).

### [15/09/2026] `fn_auto_enroll_batch_group` could enroll a student into the wrong batch — ✅ FIXED (by removal, not a targeted patch)
- **Found while:** Sprint 8.0's mandatory pre-flight, before any implementation code was written (the sprint spec's own STOP condition).
- **Symptom (theoretical — 0 duplicate-pair batch groups existed live):** the trigger resolved "the" batch group for a student purely by `(batch_course, batch_institution)`, `LIMIT 1`, with no group-id awareness. If two batch groups ever shared the same course+institution (realistic once a class runs multiple batches per level, e.g. separate exam-attempt cohorts), the trigger could silently enroll a student into the wrong one.
- **Root Cause:** the trigger's matching logic assumed one batch group per course+institution — an assumption the real teaching model (multiple batches per level per year) doesn't hold.
- **Fix:** rather than making the match deterministic, removed the trigger's enrollment logic entirely — batch membership now only ever comes from an explicit action (`join_group_by_token` or `enroll_user_in_batch_group`), never a guess. The trigger's course-change cleanup branch (removing membership from a student's *old* matched group) was kept, since it deletes real existing membership rather than generating a guessed one — it still resolves that old group via the same `LIMIT 1` lookup, so it carries a smaller, symmetric version of the same risk on the removal side. Flagged in blueprint.md §3.1 D-15, not fixed this sprint.
- **Status:** ✅ RESOLVED for the enrollment (grant) side (15/09/2026, SQL deployed & verified live). Removal-side residual left open, documented.

## Follow-up — 14/09/2026 (skip_card / suspend_card atomic-upsert fix)

### [14/09/2026] skip_card / suspend_card — non-atomic UPDATE-then-INSERT race, `23505` on a concurrent call — ✅ FIXED
- **Found while:** Sprint 7.12's live verification (see below) — attempting to manually click through a deck to prove the concept_card StudyMode fix, before switching to a DB pipeline-replay instead.
- **Symptom:** `Error skipping card: {code: 23505, details: Key (user_id, flashcard_id)=(...) already exists., message: duplicate key value violates unique constraint "reviews_user_flashcard_unique"}`, toast "Failed to skip card," card never advances.
- **Investigation:** `StudyMode.jsx`'s `handleSkip` does no direct client-side write — it calls a single `skip_card(p_user_id, p_flashcard_id)` RPC (confirmed by reading the handler, correcting the original "unconditional client INSERT" hypothesis). The live RPC body (confirmed via `docs/database/bugfixes/16_DIAGNOSTIC_skip_card_race_condition.sql`, run by the operator, matching `docs/database/bugfixes/09_FUNCTIONS_fix_skip_suspend_card_reviews_columns.sql` exactly) already does a proper existence check — `UPDATE reviews SET skip_until = ...; IF NOT FOUND THEN INSERT ...` — but this is a classic **TOCTOU race, not an ordering bug**: none of StudyMode.jsx's 5 "Skip 24hr" buttons disable while the call is in flight, so two near-simultaneous calls for the same never-reviewed card can both see "NOT FOUND" on their own `UPDATE` and both attempt the `INSERT`; the second violates `reviews_user_flashcard_unique`. `suspend_card` has the identical shape and the identical latent race.
- **Root Cause:** a non-atomic two-statement upsert (`UPDATE` + conditional `INSERT`) is not safe under concurrent invocation, regardless of how careful the "check first" logic is — the check and the write aren't in the same atomic operation.
- **Fix (`docs/database/bugfixes/17_FUNCTIONS_skip_suspend_card_atomic_upsert.sql`):** replaced both functions' bodies with a single atomic `INSERT ... ON CONFLICT (user_id, flashcard_id) DO UPDATE SET ...` — Postgres resolves the conflict inside one statement, so a concurrent duplicate call now always resolves as an update, never a failed insert. IDOR guard, timezone logic, and search_path reproduced verbatim from the confirmed-live body — pure write-path change, no behavior change to any successful single call.
- **Verified via:** `docs/database/bugfixes/18_TEST_verify_skip_suspend_atomic_upsert.sql` — **7/7 PASS**, including calling `skip_card`/`suspend_card` twice in a row on the same never-reviewed card (deterministically exercises the exact path a race's "loser" call takes) with no error and exactly one surviving `reviews` row each time, plus an IDOR regression check (cross-user call still rejected).
- **Files:** *new* — `docs/database/bugfixes/{16_DIAGNOSTIC_skip_card_race_condition,17_FUNCTIONS_skip_suspend_card_atomic_upsert,18_TEST_verify_skip_suspend_atomic_upsert}.sql` (all 3 ✅ run against production). No frontend change needed — the race lived entirely in the RPC.
- **Status:** ✅ RESOLVED (14/09/2026, SQL deployed & verified live, 7/7 PASS).

## Sprint 7.12 — 14/09/2026 (concept_card structured authoring + browse-only viewer)

### [14/09/2026] StudyMode's "never-reviewed → new card" fallback didn't exclude concept_card — could reach a student and be graded — ✅ FIXED
- **Found while:** Task B's pre-flight investigation, following an explicit lead in the sprint spec pointing at `StudyMode.jsx` ~line 352.
- **Symptom:** `get_study_queue` correctly excludes `concept_card` from the *due*-set (D-06, since Sprint 6.0). But `StudyMode.jsx`'s `fetchFlashcards` applies a SEPARATE filter on top of that RPC result — `cleanedData.filter(c => dueIds.has(c.id) || !reviewedIds.has(c.id))` — meant to also surface never-reviewed ("new") cards, since `get_study_queue` only returns already-scheduled cards. This second filter never checked `question_type`. Since a concept card by definition has no `reviews` row (it's never graded), it always satisfies `!reviewedIds.has(c.id)` and would pass straight through as a "new card," reaching a student in the plain flashcard flip UI and becoming gradeable via `apply_review` exactly like a real flashcard — the precise violation D-06 exists to prevent.
- **Root Cause:** `get_study_queue`'s due-set exclusion and this client-side new-card fallback were never audited as a pair — the RPC-level fix (Sprint 6.0) covered one of the two paths a card can enter a study session by, not both.
- **Fix:** added an explicit `c.question_type !== 'concept_card'` clause to the same filter, so concept cards are excluded at every point in the pipeline regardless of due/reviewed status.
- **Verified via:** pre-flight confirmed 0 `reviews`/`review_events` rows had ever existed for `concept_card` (live gap, not a live incident — no real content or students were ever actually affected, since no professor had a real reason to author one before this sprint gave it a real authoring path). Post-fix, replayed the exact fetch pipeline (deck's 5-column-join card set + `get_study_queue` due-set + `reviews` reviewed-set + the fixed filter) against the live DB with a real test card: present in the deck's raw card set, never-due, never-reviewed (exactly the leak condition), and absent from the final filtered study list.
- **Files:** `src/pages/dashboard/Study/StudyMode.jsx`.
- **Status:** ✅ RESOLVED (14/09/2026, same session as the Sprint 7.12 concept_card build).

### [14/09/2026] Skip-24hr fails with a duplicate-key error — ✅ FIXED same day, see "Follow-up" section above
- **Found while:** attempting to manually click through a 29-card deck to live-verify the concept_card leak fix above (abandoned in favor of a direct DB pipeline-replay, which is what actually proved the fix — see the leak entry above and Sprint 7.12 in `now.md`).
- **Symptom:** clicking "Skip 24hr" on a card threw a toast ("Failed to skip card") and the console logged `Error skipping card: {code: 23505, ...}`. The card never advanced.
- Initially flagged out of scope for this sprint and spun off — **fixed the same day as a dedicated follow-up** (a real TOCTOU race in `skip_card`/`suspend_card`'s RPC body, not the client-INSERT hypothesis originally guessed here). Full root cause, fix, and verification: see the "Follow-up — 14/09/2026 (skip_card / suspend_card atomic-upsert fix)" section at the top of this file.
- **Status:** ✅ RESOLVED (14/09/2026).

## Sprint 7.11 — 14/09/2026 (fitb authoring + confidence-gated grading)

### [14/09/2026] Bulk-upload template's `descriptive_case_study` example row had an unquoted comma, corrupting its column count — ✅ FIXED
- **Found while:** Task 0's live re-verification of the Sprint 7.10 bulk-upload path — before uploading a real test CSV, ran the app's own `parseCSVLine` logic (copied into a throwaway Node script) against the shipped template to check every row's field count against the header, as a sanity check before adding an 18th column (`fitb_answers`) for this sprint.
- **Symptom:** the `theory`/`descriptive_case_study` example row's `back` field read `Net price = 1.25 x 0.9 = 1.125x cost, so a 12.5% margin over cost.` — an unquoted comma inside an unquoted CSV field, which `parseCSVLine` (correctly) treats as a field separator, producing 19 fields instead of the expected 18 (17 pre-Sprint-7.11) and silently shifting every column after `back` in that one row.
- **Root Cause:** pre-existing since Sprint 7.9 (when this example row was added for the `theory` subtype rollout) — never caught because no prior sprint re-parsed the shipped template programmatically to check field counts; it only ever looked correct by eye.
- **Fix:** wrapped the field in quotes: `"Net price = 1.25 x 0.9 = 1.125x cost, so a 12.5% margin over cost."`. Re-verified via the same Node script — all 12 example rows now parse to exactly 18 fields matching the header.
- **Files:** `src/pages/dashboard/BulkUploadFlashcards.jsx` (template string only).
- **Status:** ✅ RESOLVED (14/09/2026, same session as the Sprint 7.11 fitb build).

## Sprint 7.6 — 13/09/2026 (Browse/My Study Sets rename + question-type filter)

### [13/09/2026] `guideContent.js` due-queue steps link to the wrong page — ✅ FIXED (follow-up to the sprint 7.6 flag, same day)
- **Found while:** renaming "Review Flashcards" → "Browse Study Sets" throughout the app and sweeping every place the old label appeared, to avoid reintroducing the same naming confusion this sprint fixes.
- **Symptom:** 3 onboarding-guide steps in `src/data/guideContent.js` — "Open your Review queue" ("Your queue shows every card that is due today..."), "Don't panic — start small" ("...reviewing just 20 cards today..."), and "One topic too heavy? Skip it for today." ("During a review session, tap the ⋯ menu...") — all describe the due-today spaced-repetition queue, but their `linkTo` was `/dashboard/review-flashcards` (`ReviewFlashcards.jsx`, "Browse Study Sets" — subject/topic browsing). The actual due-queue page is `/dashboard/review-session` (`ReviewSession.jsx`, "Today's Reviews" in the nav), confirmed by reading its body: it calls `get_study_queue` (the due-today RPC) and embeds `StudyMode` directly, matching all 3 steps' copy exactly (including the Skip Topic ⋯-menu action, which lives inside `StudyMode`).
- **Root Cause:** initially flagged rather than fixed within the original sprint (correcting `linkTo` is a functional/routing change, judged out of scope for that sprint's copy-only rename) — investigated and fixed as an immediate same-day follow-up once flagged back via the spawned task.
- **Fix:** `linkTo` on all 3 steps changed `/dashboard/review-flashcards` → `/dashboard/review-session`; `linkLabel` changed "Browse Study Sets" → "Today's Reviews" to match. The 4th occurrence ("Do your first review", orientation section) was deliberately left pointing at Browse Study Sets — a brand-new, never-reviewed card has no due-queue entry yet (per `get_study_queue`'s "due" definition), so that step is genuinely about finding a deck to study for the first time, not the due queue.
- **Verified via:** live click-through on `/guide` (public route, no login needed) — confirmed via DOM query that exactly 3 buttons now read "Today's Reviews →" and 1 reads "Browse Study Sets →" (matching the intended split); clicked a "Today's Reviews" button and confirmed `localStorage.postAuthRedirect` was set to `/dashboard/review-session` (the page's actual pre-login redirect mechanism — `handleStepLink` in `StudentGuide.jsx` stores `linkTo` and redirects to `/login`, then post-login logic reads it back).
- **Files:** `src/data/guideContent.js`.
- **Status:** ✅ RESOLVED (13/09/2026, same session as the sprint 7.6 rename).

### [13/09/2026] "No flashcards to study" clicking directly into a deck whose cards are all already graded — 🔍 INVESTIGATED, NOT A BUG (real UX gap flagged, not fixed)
- **Found while:** live-verifying the Sprint 7.6 Question Type filter — clicking the Income Tax → Deductions from Gross Total Income deck (id `72837683-e562-48c3-b700-e8d8e28f2241`) as TestOutlook showed "No flashcards to study," reproducing identically with the filter on or off, ruling out the filter as the cause. A different deck (GST) opened and graded normally in the same session.
- **Investigation:** read `StudyMode.jsx`'s `fetchFlashcards` (the handler behind `/dashboard/study`, used both by the due-queue entry point and a direct deck click) — it applies the exact same SRS-aware filter regardless of entry path: `cleanedData.filter(c => dueIds.has(c.id) || !reviewedIds.has(c.id))`. A card with an existing `reviews` row that isn't currently due gets excluded even when the student explicitly clicked into that specific deck, not the due queue.
- **Confirmed via `docs/database/bugfixes/15_DIAGNOSTIC_deductions_deck_no_cards_to_study.sql`** (live, 13/09/2026): all 3 of TestOutlook's visible cards in this deck have `status='active'`, a real `reviews` row, and `next_review_date` in the future (09-14/09-16/09-20, run on 09-13); querying the real `get_study_queue` RPC restricted to these 3 ids returned zero rows. Root cause: this deck's cards were graded during Sprint 7.5's own live MCQ testing earlier the same day (same deck, same account — it's literally the card Sprint 7.5 used to test both grading paths), so they're scheduled forward and correctly excluded from "due."
- **Conclusion: NOT a bug.** `StudyMode.jsx` is behaving exactly as designed. The real issue is a **UX gap**: the generic "No flashcards to study" empty state doesn't distinguish "this deck has zero cards" from "you already reviewed everything in this deck today, come back when it's due" — both render identically. Fixing that (e.g. a different empty-state message when `cleanedData` was non-empty before the SRS filter ran) is a `StudyMode.jsx` change, explicitly out of scope for Sprint 7.6.
- **Files:** none changed — investigation only. Diagnostic: `docs/database/bugfixes/15_DIAGNOSTIC_deductions_deck_no_cards_to_study.sql`.
- **Status:** 🔍 Root cause confirmed, no fix applied. Worth a `StudyMode.jsx` empty-state improvement in a future sprint if this UX gap is worth spending on.

## Sprint 7.5 — 13/09/2026 (MCQ-single vertical slice)

### [13/09/2026] flashcard_decks.visibility desynced from member cards — public content invisible in Browse + Recent Activity — ✅ FIXED
- **Reported by:** Operator, while live-testing Sprint 7.5 as a student — noticed the notification bell fired for a professor's new public content, but neither `/dashboard/review-flashcards` (Browse) nor the Dashboard "Recent Activity" card showed it. Pre-existing bug, unrelated to MCQ — found only because this sprint's live testing happened to create cards with mixed visibility into the same subject/topic.
- **Symptom:** a `flashcard_decks` row's `visibility` column gets set once — either by `FlashcardCreate.jsx`'s explicit find-or-create deck logic, or by the `update_deck_card_count()` trigger's auto-create-on-first-card branch — and is never updated again. If the deck's first-ever card was `private` and a later card added to the same (user, subject, topic) group is `public`, the deck row stays `private` forever, even though the individual `flashcards.visibility` is correct. `get_browsable_decks` and `get_recent_activity_feed` both gate on the DECK's visibility (a known pattern from the 04/07/2026 "0 viewer-visible cards" bug below), so the public card became permanently invisible to Browse and Recent Activity — while `notifyContentCreated()` still fired correctly, since it's called with the *current submission's* visibility, independent of the stale deck row. Confirmed via `docs/database/sprint7.5/03_DIAGNOSTIC_deck_visibility_desync.sql`: 4 live decks already desynced, 3 belonging to other users — this predates Sprint 7.5's testing and has been silently affecting the platform.
- **Root Cause:** `update_deck_card_count()`'s `TG_OP = 'INSERT'` branch's UPDATE statement (the common case — most inserts land in an already-existing deck) only incremented `card_count`, never touched `visibility`.
- **Fix:** `docs/database/sprint7.5/04_FUNCTIONS_fix_deck_visibility_widen.sql` — the same UPDATE now also widens `visibility` in one statement if the new flashcard's visibility is more permissive (private < friends < public); never narrows, matching this project's "asymmetrically safer default" pattern (same reasoning as D-10). `CREATE OR REPLACE`, no signature change, so the existing `trigger_update_deck_card_count` picks it up automatically. `05_FIX_backfill_desynced_deck_visibility.sql` — one-time backfill widening the 4 already-desynced decks to the widest visibility among their actual member cards.
- **Verified via:** `05_FIX`'s built-in verification query — **0 rows returned** (no desynced decks remain) after the backfill, confirmed live 13/09/2026. **Also UI-verified end to end** (not just SQL) as a real CA Intermediate student, post-fix: Dashboard "Recent Activity" now shows "Income Tax — Deductions from Gross Total Income by Prof. CA" (previously absent entirely, despite the notification bell having fired for it); `/dashboard/review-flashcards` Browse now lists the "Income Tax" subject with "3 cards... by CA Anand More" — correctly still excluding the deck's 1 private card, surfacing only the 3 public ones.
- **Key lesson:** same class of issue as the 04/07/2026 bug below (a container whose visibility is decoupled from its children) — but in the opposite direction (under-reporting/invisible rather than leaking). Any future write path that inserts into a deck-like container needs to ask not just "does this row exist" but "is its cached visibility still correct given what's actually inside it now."
- **Files:** DB only (`update_deck_card_count()` trigger function), `docs/database/sprint7.5/{03_DIAGNOSTIC,04_FUNCTIONS,05_FIX}*.sql`.
- **Status:** ✅ RESOLVED (deployed & verified live 13/09/2026)

### [13/09/2026] flashcard_decks.target_course NULL on trigger-auto-created decks — same 2 decks invisible to every student for 5 months — ✅ FIXED
- **Reported by:** Operator, spawned as a targeted follow-up after the visibility-desync bug above — reading `update_deck_card_count()`'s live body during that investigation showed its auto-create-deck branch's INSERT column list omitted `target_course`, contradicting this same file's own "[Mar 2, 2026] CA Foundation Flashcards Invisible" entry below, which describes the historical fix as setting `target_course` too. That description was never accurate for the live function — confirmed by reading the actual body, not assumed.
- **Symptom:** `get_browsable_decks` and `get_recent_activity_feed` both gate on `fd.target_course = v_user_course` / `p_course_level`. A deck with `target_course = NULL` fails that comparison for every course (`NULL = anything` is never true in SQL), making it permanently undiscoverable to any student regardless of visibility. `get_browsable_decks`'s course gate additionally lets `professor`/`admin`/`super_admin` bypass it entirely — which is exactly why nobody had noticed: the affected professor and any admin checking their own content would see it fine; only students hit the gap.
- **Root Cause:** `update_deck_card_count()`'s auto-create-deck branch (fires when a flashcard INSERT finds no matching existing `flashcard_decks` row) never included `target_course` in its INSERT column list — confirmed via live `pg_get_functiondef`, not the (inaccurate) historical bug description.
- **Live impact, measured not assumed:** `docs/database/sprint7.5/06_DIAGNOSTIC_deck_target_course_null.sql` found exactly 2 affected decks, both `visibility='public'`, both belonging to the same professor, 23 and 11 cards respectively (**34 public cards total**), created **07/04/2026** — five months before this diagnostic, confirming this predates and is unrelated to Sprint 7.5.
- **Fix:** `07_FUNCTIONS_fix_deck_target_course.sql` — added `target_course` (copied from `NEW.target_course`) to the auto-create branch's INSERT, same pattern as the visibility fix above. `08_FIX_backfill_deck_target_course.sql` — recovered the correct `target_course` for both affected decks from their own member flashcards (which are `NOT NULL` on that column) via the standard 5-column grouping join, using the most-common value among matching cards as a defensive measure against disagreement.
- **Verified via:** `08_FIX`'s built-in verification query — **0 rows** (`still_null_target_course = 0`) after the backfill, confirmed live 13/09/2026. **⚠️ Known gap:** unlike the visibility-desync fix above, this one was NOT independently confirmed through the application UI — both affected decks are `target_course = 'CA Foundation'` ("Business Laws"), and no CA Foundation student test account was available this session (only CA Intermediate). The fix uses the identical code pattern already UI-verified for the visibility bug, on the same trigger, but a CA Foundation student account should confirm Browse/Recent Activity surface this content before treating it as fully closed.
- **Correction to this file:** the "[Mar 2, 2026] CA Foundation Flashcards Invisible" entry's "Solution" line below is now known to be inaccurate — it describes the fix as including `target_course` in the auto-create INSERT, which the live function never actually did until today. Left as-is below rather than rewritten, so the historical record of what was believed at the time stays intact; this entry is the correction.
- **Key lesson:** the same class of bug as the visibility desync above, on a different column, found only because reading the trigger's actual live body (rather than trusting a 7-month-old bug-report description of it) surfaced the discrepancy. A second reminder that any "container caches an attribute of its children" pattern (`flashcard_decks` caching `visibility` and now confirmed `target_course`) needs the same scrutiny — worth a full audit of every column `flashcard_decks` denormalizes from `flashcards` before the next question-type sprint.
- **Files:** DB only (`update_deck_card_count()` trigger function), `docs/database/sprint7.5/{06_DIAGNOSTIC,07_FUNCTIONS,08_FIX}*.sql`.
- **Status:** ✅ RESOLVED (deployed & verified live 13/09/2026)

## Sprint 7.3 — 12/09/2026 (Dashboard Reporting Surface & Study-Time Split)

### [12/09/2026] Manual timer / in-app study session localStorage collision — ✅ FIXED
- **Symptom (latent, never reported live — caught during the 7.3-C rebuild):** `StudyTimerWidget.jsx` (manual "offline study" timer) and `StudyMode.jsx` (in-app review-session auto tracker) both read/wrote the exact same localStorage keys — `revisop_session_started_at` / `revisop_session_source`. Starting a manual timer while an in-app study session was also in flight (or vice versa) meant whichever wrote last silently clobbered the other's timestamp/source, corrupting whichever session tried to log second (wrong duration, or a `source` mismatch that made the reader bail entirely).
- **Root cause:** both features were built independently against the same two key names, with no ownership boundary — neither writer checked whether the other's session was active before overwriting.
- **Fix (Sprint 7.3-C):** the manual timer moved into a new **`src/contexts/StudyTimerContext.jsx`**, which uses its own key — **`revisop_manual_timer_started_at`** — never touching `revisop_session_started_at`/`revisop_session_source`. `StudyMode.jsx`/`ReviewSession.jsx` keep their original keys/values exactly as-is. No shared keys between the two features going forward.
- **Files:** `src/contexts/StudyTimerContext.jsx` (new), `src/components/dashboard/StudyTimerWidget.jsx` (rewritten to consume the context).
- **Status:** ✅ RESOLVED — live-verified 12/09/2026 that the manual timer's key is distinct from `StudyMode`'s (code review + live start/stop test); a true concurrent-session regression test (start the manual timer, then complete a real review session at the same time) was not run live this session — worth a quick manual pass.

## Sprint 6.5 — 07/09/2026 (Phase 6 live-verification close-out)

### [07/09/2026] Finding 1 — `Progress.jsx` un-migrated + stale "Items Mastered" + over-eager "Due Today" — ✅ FIXED (frontend)
- **Symptom (live, `/dashboard/progress`, all roles):**
  1. "Items Mastered" stat tile = **28** (professor) / **29** (student), while the SSOT (`reviews.status='mastered'`) = **1** for that student, and the same page's own "Mastered Items (1)" list section is correct. The tile still read the old "distinct cards ever reviewed" proxy — it was never re-pointed when the dashboard "Mastered" tile was in Sprint 6.3.
  2. "Due Items Forecast" tiles on legacy Tailwind (`red-50/red-600/red-200`, `amber-50/600/200`) — not `--rv-*`.
  3. "Due Today" rendered the red alarm for **any** count `> 0` (professor's `7` → red). Per the Sprint 6.0 note the red alarm should engage only at a genuine backlog, not a normal daily pile.
  4. Stat numerals in sans, not the mono `Num` atom.
- **Root cause:** Phase 6 never migrated this page; the Mastered tile computed `new Set(activeReviews.map(r => r.flashcard_id)).size` in the lifetime-stats effect.
- **Fix (Sprint 6.5, frontend-only):** `Progress.jsx` + `StudyHeatmap.jsx` + `SubjectMasteryTable.jsx` migrated onto `--rv-*` + Plex + `Num`/`Label` (class-reference swaps only, no DOM change). The "Items Mastered" effect now reads `supabase.rpc('get_mastered_cards', { p_user_id }).length` — the exact SSOT the dashboard tile and the "Mastered Items (N)" list use. `ForecastCard` → a `tone` prop on `--rv-*`; "Due Today" = `0` calm-green / `1..24` neutral (no alarm) / `> 24` (`DUE_TODAY_ALARM_THRESHOLD`) `--rv-danger`.
- **Files:** `src/pages/dashboard/Study/Progress.jsx`, `src/components/progress/StudyHeatmap.jsx`, `src/components/progress/SubjectMasteryTable.jsx`.
- **Status:** ✅ RESOLVED — **live-verified per-role 07/09/2026** (dev server → live Supabase): student three-way Mastered equality `1 == 1 == 1` (was 29); professor "Items Mastered" `0` (was 28); professor **"Due Today: 7" renders NEUTRAL, not the red alarm**; student "Due Today: 0" calm-green; all sections on `--rv-*` / Plex / mono `Num` (computed-style confirmed); heatmap green ramp → navy; console zero errors all roles. The `>24` danger branch is a one-line ternary + confirmed CSS (`border-rv-danger` → `#b91c1c`), unexercised live only for want of a >24-backlog account. Ships with the 6.5 push.

### [07/09/2026] Finding 2 — Leaderboard "Following" tab 400s (`get_following_leaderboard` ambiguous "rank") — ✅ FIXED, LIVE-VERIFIED & AUDITED FAITHFUL (Task 6.5-D)
- **Symptom (live):** `POST …/rpc/get_following_leaderboard` → `400`; Postgres `42702`: `column reference "rank" is ambiguous — could refer to either a PL/pgSQL variable or a table column`. The "Friends" tab (`get_friends_leaderboard`) works.
- **Root cause:** the `RETURNS TABLE (rank integer, …)` OUT column is an implicit plpgsql variable; the body also produces a `rank` (a `DENSE_RANK() … AS rank` alias / CTE column) → a bare `rank` in `ORDER BY` / `WHERE` / `SELECT` is ambiguous. **Pre-existing** — no Phase 6 sprint touched any leaderboard RPC (Sprint 3.5 function).
- **Fix (Sprint 6.5, `docs/database/sprint6.5/`):** `01_DIAGNOSTIC` pulls the live body; `02_FUNCTIONS` fixes **in place, no OUT-column rename** — `#variable_conflict use_column` pragma + the window-function result aliased `rnk` (never `rank`) + every reference table-qualified. RETURNS TABLE shape, `SECURITY DEFINER`, `STABLE`, unquoted `search_path`, the `auth.uid()` gate and the `authenticated`-only grant preserved → `LeaderboardWidget.jsx` (`row.rank`) needs **no change**, SQL ships alone. `03_TEST` = shape parity + security preservation + no-`42702` behavioural run + `DENSE_RANK` order + students-only + null-session reject.
- **Deploy:** run `01` → diff `02` against the live body → apply `02` → run `03` → live-verify both tabs on `revisop.com`.
- **Progress log (07/09/2026):** `01` run (grants confirmed: `authenticated` + `postgres` + `service_role`). **`02_FUNCTIONS` DEPLOYED — ran clean** (`CREATE OR REPLACE` "Success. No rows returned"); the reconstructed body compiled against the live schema so all referenced columns (`follows.follower_id`/`followee_id`, `reviews.created_at`, `study_sessions.duration_seconds`, `profiles.role`/`full_name`) resolve. `03_TEST` first run hit `42725 operator is not unique: text || "char"` (`p.provolatile`) → re-issued with `::text` casts, the repo `request.jwt.claims` JSON impersonation idiom, and a semantic-parity check → **9/9 PASS**: shape identical to `get_friends_leaderboard`, `SECURITY DEFINER`/`STABLE`/unquoted `search_path` preserved, grant = `authenticated`, no `42702` (returns 2 rows), rank non-decreasing, exactly one `is_self`, students-only, null-session rejected, **weekly stats == `get_friends_leaderboard` for shared users (0 mismatches)** → the reconstructed body is behaviourally faithful.
- **Reconstruction audit (Task 6.5-D, 07/09/2026 — `docs/database/sprint6.5/04_AUDIT_*`):** the 6.5 fix replaced the *whole* body (01_DIAGNOSTIC's live-body output was lost before 02 overwrote the function), so faithfulness of the follow-scope was unverified — `03_TEST`'s parity check validates the stat math, not the membership set.
  - **Current live body — CAPTURED 07/09/2026** (`pg_get_functiondef('public.get_following_leaderboard()'::regprocedure)`, pasted verbatim into `04_AUDIT_current_definition.sql`): **byte-identical to `02_FUNCTIONS`** → the deployed reconstruction is confirmed live, no out-of-band hand-edit. Signature row: `SECURITY DEFINER`, `STABLE` (`s`), `proconfig = {search_path=public, extensions}`. (`pg_get_functiondef` echoes `SET search_path TO 'public', 'extensions'` — two separately-quoted identifiers, equivalent to unquoted `public, extensions`; NOT the single-string `'public, extensions'` outage form. Sibling `get_friends_leaderboard` is `VOLATILE` not `STABLE` — minor, `STABLE` is stricter/correct for a pure read.)
  - **Original body — UNRECOVERABLE from git.** `git log -S 'get_following_leaderboard' --all` → 3 commits only (071395d create, 4c5c884 doc, 72693fe fix); Sprint 3.5 ran the `CREATE` directly in Supabase, no `.sql` ever committed; `--diff-filter=A/D` over `*leaderboard*` confirms sprint6.5/01–03 are the only leaderboard SQL files that ever existed. Supabase backup restore not exercised. **Reference used:** the original *behavioural contract* documented in `DATABASE_SCHEMA.md` @ 071395d (verbatim: "top 20 followees (students only) + the caller's own row regardless of rank", "Aggregates full followee set before applying top-20 limit — caller's rank is exact", "SECURITY DEFINER … Students only", week = `date_trunc('week', CURRENT_DATE)`).
  - **Diff — 3 focus areas, all MATCH the documented contract:** (1) **follow-graph join** — `cohort` = `SELECT v_uid UNION SELECT f.followee_id FROM public.follows f WHERE f.follower_id = v_uid`: table `public.follows`, predicate `follower_id = auth.uid()`, projects `followee_id` → **directional**, correct for "Following"; no `friendships` join, no reciprocal `AND EXISTS (reverse follow)` clause (that would be the friends semantic). (2) **population filter** — `JOIN public.profiles p ON p.id = c.uid AND p.role = 'student'`, students-only, no course/`account_type` filter — matches the contract and both siblings. (3) **result window** — `DENSE_RANK() OVER (ORDER BY reviews_this_week DESC, study_time_this_week_seconds DESC)` over the full cohort, then `WHERE rnk <= 20 OR uid = v_uid` → N=20, self always included regardless of rank, caller's rank exact; `is_self = (uid = v_uid)` true on exactly one row. Incidental checks (RETURNS TABLE shape, week boundary, COALESCE-to-0, all security attributes) also match.
  - **Live membership set-equality assertion — RUN 07/09/2026, 5/5 PASS.** `04_AUDIT_membership_test.sql` built the expected set independently (caller ∪ followed-students) and asserted `get_following_leaderboard()`'s `user_id` set. Live follow graph is sparse — 6 rows, 4 distinct followers, **max 1 followed-student per student** (no account follows ≥2), so the test ran on the richest available account `f9377860-0991-4cdc-9679-f347c61d71b4` (follows 1 student → 2 expected rows): **exact set equality PASS** (no extras → scope not too wide; nothing missing → not collapsed to the caller), **exactly one `is_self` PASS**, **rank ordered by reviews DESC PASS**. The tiny graph means the >20 top-N cutoff and multi-followee ordering are unexercised on live data — contract-trivial paths, code matches. This also explains the earlier "TestOutlook (you)"-only row: almost nobody follows anyone.
- **Status:** ✅ **RESOLVED & AUDITED FAITHFUL (fix + Task 6.5-D).** `02_FUNCTIONS` deployed 07/09/2026; `03_TEST` 9/9 PASS; **live body captured via `pg_get_functiondef` — byte-identical to `02_FUNCTIONS`**; Task 6.5-D contract-diff = faithful on all three membership dimensions (follow-join / filter / window); **live membership set-equality PASS** on a real followee-bearing account; Following tab renders live, no `400`, no `console.error`. No `[FIX]` shipped — no divergence found. Frontend unchanged (`row.rank` preserved). **Finding 2 fully closed.**

### [07/09/2026] Finding 4 (partial) — `⏰ Timezone already set` logged 77×/page — ✅ FIXED
- **Fix:** module-scoped `tzAlreadySetLogged` guard in `src/contexts/AuthContext.jsx` — the "already set" branch logs at most once per session. Other timezone-sync branches untouched.
- **Status:** ✅ RESOLVED — **live-verified 07/09/2026**: `⏰ Timezone already set` fires exactly 1× per page load across all 3 role sessions / ~6 loads (console tail shows one `⏰` per `[vite] connecting` block). Was 77+/load.

### [07/09/2026] Findings 3, 5, 6 — ✅ RESOLVED in Sprint 7.0 (08/09/2026)

#### Finding 5 — nav/notification over-fetch — ✅ FIXED (frontend, no SQL)
- **Symptom:** one `/dashboard/notes` load queried `profiles` **46×**; `get_recent_notifications` / `friendships` / `role_permissions` / `get_unread_notification_count` each **12×** (production Phase-6 measurement).
- **Root cause:** `src/contexts/AuthContext.jsx` called `setUser(session?.user ?? null)` on every supabase-js auth event (`INITIAL_SESSION`, `SIGNED_IN` — re-emitted on each tab focus — `TOKEN_REFRESHED`), each with a **fresh object reference**. `user` identity changed on every event → every `[user]`-keyed effect app-wide (`useRole`, `useNotifications`, `useFriendRequestCount`, `CourseContext.fetchTeachingCourses`, `updateUserTimezone`, `useActivityFeed`) re-fired. The ×12 ≈ the number of auth events during load/settle. Each `useRole()` consumer (nav + ~9 pages) also fetched independently, and `CourseContext` + `BrowseNotes` + `ProfileDropdown` + the timezone sync each read `profiles` again.
- **Fix (Sprint 7.0 7.0-A):** (1) `applySession()` sets `user` via a functional updater returning the previous reference when `prev?.id === next?.id` → React bails, `user` is identity-stable across token refreshes. (2) new `src/contexts/NavDataContext.jsx` — `<NavDataProvider>` (mounted once above the router) owns the three nav hooks; `Navigation.jsx` + 9 `useRole()` consumers read the shared context. (3) `updateUserTimezone` gated by a module-scoped `tzSyncedThisSession` → ≤1 `profiles` read/session. (4) `ProfileDropdown` reads the name from `user_metadata.full_name` first. (5) `CourseContext` exposes `role`/`courseLevel`; `BrowseNotes` consumes them instead of its own `profiles` read.
- **After (dev server → live Supabase, one `/dashboard/notes` load, all three roles):** `profiles` **17 → 3** (student / professor / super-admin — `timezone` + `useRole` role + `CourseContext` role/course, one each); `get_recent_notifications` / `get_unread_notification_count` / `friendships` / `role_permissions` **6 → 1 each** all three roles. Targets (`profiles ≤ 3`, nav RPCs ≤ 2) met. Realtime notification + friend-request channels unaffected (one each). Role gating identical: student = no Manage / no Analytics + Browse-Notes course-lock via `CourseContext`; professor = Analytics present, no Manage; super-admin = Manage + admin/super-admin sections.
- **Files:** `src/contexts/{AuthContext,NavDataContext,CourseContext}.jsx`, `src/App.jsx`, `src/components/layout/{Navigation,ProfileDropdown}.jsx`, `src/pages/dashboard/Content/BrowseNotes.jsx`, + import-path swap on 9 `useRole` consumers.
- **Status:** ✅ RESOLVED (Sprint 7.0, shipped `6c78f73` → `main`). Per-role verified on the dev server against live Supabase 08/09/2026.

#### Finding 6 — 2× `400` on every authed page — ✅ FIXED (frontend timing, no SQL)
- **Symptom:** 2× `Failed to load resource: 400` on essentially every authed page (nav/notification RPC family; reported as "4× 401" in the Sprint 6.3 report, later presenting as 400).
- **Root cause (named, evidence):** `get_recent_notifications` and `get_unread_notification_count` `RAISE EXCEPTION 'Not authenticated'` when `auth.uid() IS NULL` (and `'Access denied'` when `auth.uid() != p_user_id`). A plpgsql `RAISE` surfaces as **HTTP 400** (`P0001`) — this is the *only* way these RPCs 400. Direct calls with a valid session (captured via the app's `supabase` client, token 3519s to expiry) **all return 200** — no grant / overload / signature / L5-revoke defect. The 400 is the hook firing during the auth-init window where the access token is stale / not-yet-attached, so `auth.uid()` is NULL server-side. Could not be reproduced on a warm dev session (consistent with the report's "intermittent on production cold start / bfcache").
- **Fix layer = frontend, no SQL:** the 7.0-A `user`-identity stabilisation removes the ~12× churn that kept the race landing; the only remaining fire is the single post-`getSession` one, when the token is already valid.
- **After:** zero 4xx across soft-nav sweeps (9–10 routes + `history.back()`) for all three roles on the dev server. The true cold session-restore path (near-expired token) is only reproducible on production; could not repro the 400 on the warm dev server even pre-fix.
- **Status:** ✅ RESOLVED (Sprint 7.0, shipped `6c78f73`). No SQL. Optional operator cold-load spot-check on `revisop.com`; if a 400 recurs there, a targeted retry-on-`P0001` in the three hooks is the next step.

#### Finding 3 — web-vitals `startTime` TypeError — ✅ CLOSED (documented benign-upstream)
- **Symptom:** `Uncaught TypeError: Cannot read properties of undefined (reading 'startTime')` with `reportAllChanges` / `n.timeout` in the stack. Seen once on a soft navigation; did not recur across the Phase-6 6-session sweep.
- **Root cause:** **not in the repo** — no `web-vitals` / `@vercel/speed-insights` / `@vercel/analytics` in `package.json`, no import in `src/`, nothing in `index.html` or `vercel.json`. The `web-vitals` code is injected by **Vercel Speed Insights** at the edge (`/_vercel/speed-insights/script.js`), toggled on in the Vercel *project dashboard*. Not in our bundle, not version-pinnable by us. The error is a known upstream web-vitals issue on soft-nav / bfcache restore (an entry list is momentarily empty); it fires inside the RUM reporter and does not affect app behaviour.
- **Resolution:** operator to disable Speed Insights in the Vercel project settings (RUM data unused) → removes the script at source. Otherwise: benign, upstream, non-reproducing.
- **Status:** ✅ CLOSED (Sprint 7.0). No in-repo fix exists; disposition is an operator/Vercel-dashboard action.

## Sprint 6.4 — 05/09/2026

### [05/09/2026] "Items Reviewed (last 7 days)" undercounts — reads first-review date, not last — ✅ FIXED (frontend re-point; no schema change)
- **Symptom:** the student dashboard "Reviews / Last 7 days" tile (and the GoalProgressWidget today-count, and the Progress 7d/30d "Items Reviewed" window) show far fewer reviews than the user actually did — often 0 for an active daily reviewer whose cards were all first seen more than 7 days ago.
- **Root cause:** those stat queries filter `reviews` by **`created_at`**. `reviews` is `UNIQUE(user_id, flashcard_id)` — one row per card — and every re-review **UPDATEs** that row (both the pre-ladder `handleRating` and, since 03/09/2026, `submit_review`). So `created_at` is frozen at the card's *first* review and never moves; a rolling-7-day filter on it misses every repeat review.
- **Not new to the SRS ladder** — the SELECT-or-UPDATE shape predates it; the ladder just made `submit_review` the writer.
- **Fix (no SQL):** `reviews.last_reviewed_at` already exists (`timestamptz`, `DEFAULT now()`) and has always been set on every rating by both write paths. Re-pointed the "Items Reviewed" recency filter to `last_reviewed_at ?? created_at` in `src/pages/Dashboard.jsx` (`fetchPersonalStats` — the 7d tile count + the today-count) and `src/pages/dashboard/Study/Progress.jsx` (7d/30d window). **Streak + weekly-accuracy deliberately left on `created_at`** (subtler semantics — Phase 7 analytics pass; operator decision).
- **Backfill:** `docs/database/sprint6.4/01_DIAGNOSTIC_items_reviewed_recency.sql` (read-only) measures `last_reviewed_at IS NULL` coverage — expected **0** rows. `02_DATA_backfill_last_reviewed_at.sql` sets `last_reviewed_at = created_at` for any NULLs (idempotent). Not a deployment-order blocker — the frontend falls back to `created_at` for NULL rows.
- **Status:** ✅ RESOLVED in code (Sprint 6.4) — ships with the frontend push. Live check: "Items Reviewed (7d)" goes non-zero after a re-review on a card first seen > 7 days ago.

### [05/09/2026] Seeded test card for live verification — optional `[CLEANUP]`
- The Sprint 6.4 brief suggested resetting `review 8e7a8b6c…` (TestOutlook) from `status='mastered'` back to `active` at its prior rung so it re-enters the queue for the live full-session run. This is a one-off convenience for verification only — no deployment-order concern, no schema dependency (§C's schema/function work was found unnecessary). Run it (or don't) as part of the operator live-verification pass.

## Sprint 6.3 — 05/09/2026

### [05/09/2026] "Items Mastered" dashboard stat was a misnomer — ✅ FIXED (re-pointed in Sprint 6.3)
- **Symptom:** the student dashboard "Mastered" tile counted **distinct flashcards ever reviewed** (`new Set(activeReviews.map(r => r.flashcard_id)).size` in `Dashboard.jsx` `fetchPersonalStats`) — i.e. "cards started", not "cards mastered". Carried as a known item from the SRS Ladder Epic (Phase 3 left the tile untouched under the settled-stat rule) and earmarked for Sprint 6.4.
- **Why fixed now:** Sprint 6.3 rebuilds that tile as part of the dashboards reskin, so re-pointing it is a trivial ride-along rather than a standalone settled-stat change. Operator approved the ride-along explicitly (asked, with before/after).
- **Fix:** the tile now reads the real mastered count — `supabase.rpc('get_mastered_cards', { p_user_id }).length` (`reviews.status = 'mastered'`, the SRS ladder's graduation state, live since 03/09/2026). The old `uniqueCards` block in `fetchPersonalStats` is removed; the mastered count is fetched next to the `get_study_queue` call. Sublabel "Unique items" → "Items mastered".
- **Files:** `src/pages/Dashboard.jsx`.
- **Status:** ✅ RESOLVED in code (Sprint 6.3) — ships with the sprint's frontend push. Pending per-role live verification.
- **Carried items now addressed in the Sprint 6.4 section above:** Items-Reviewed `created_at` re-point (✅ FIXED, no schema change) + the seeded test-card `[CLEANUP]` (optional, folded into the operator live-verification pass).

## Sprint 6.0 follow-ups — 03/09/2026

### [03/09/2026] Review-session queue had no in-app nav link (any role) — ✅ FIXED
- **Found:** during 6.0 live QA on a professor account. `/dashboard/review-session` was reachable only via the student dashboard's green "Start Review Session" CTA (professors render a different dashboard branch with no review UI) and the push-notification deep link. The **Study** nav dropdown had only "Review Flashcards" + "Browse Notes". So a professor with due personal reviews — or any user not on the dashboard — had no way in.
- **Not a 6.0 regression:** the professor dashboard branch never had a review CTA; 6.0 only swapped the `reviewsDue` *count* computation to `get_study_queue`. `fetchPersonalStats` does run for professors, so `reviewsDue` was computed — just never rendered in that branch.
- **Fix (Option A):** "Today's Reviews" → `/dashboard/review-session` added as the first item in the Study menu, all roles — `NavDesktop.jsx` dropdown + `NavMobile.jsx` Study section. No dashboard restructure (Option B — a professor-dashboard CTA card — was declined to avoid touching the settled professor dashboard).
- **Status:** ✅ RESOLVED (pushed 03/09/2026).

### [03/09/2026] Progress "Due Items Forecast" disagrees with the review queue — ✅ RESOLVED (SRS Ladder Phase 1, deployed 03/09/2026)
- **Symptom:** `/dashboard/progress` "Due Today" showed **24** for a student whose Dashboard CTA + Review Session (both `get_study_queue`-backed) showed **4**. Student on CA Intermediate; the 20-card gap = due reviews on out-of-course cards the queue correctly filters out.
- **Root cause:** `Progress.jsx` "Due Items Forecast" reads a separate `forecast` source (`get_due_forecast`) that was **not** wired to the `get_study_queue` predicate — no course filter, no concept-card exclusion, server date instead of user-tz. A 4th "due" surface off the SSOT.
- **Not a 6.0 regression:** Progress was not among the three call sites 6.0 rewired, and the forecast was always its own query. But it contradicts the sprint objective ("every surface showing 'due' counts reads from one RPC").
- **Fix (SRS Ladder Epic, `docs/database/srs-ladder/02_FUNCTIONS_srs_ladder_engine.sql`):** rewrite the body of `get_due_forecast(p_user_id)` (signature unchanged → no frontend change). `due_today` now uses the **exact** `get_study_queue` due predicate (user-tz today, `status='active'`, `next_review_date <= today`, `skip_until` null/≤today, `question_type <> 'concept_card'`, read-time course filter, L2 visibility guard); `due_next_7`/`due_next_30` = same predicate, forward cumulative window. Auditor decision: Option (a), single source of truth for the "due" predicate.
- **Expected visible effect:** ~25 CA-Intermediate students will see "Due Today" drop (their CA-Foundation review rows are now course-filtered — the same 1,648 rows behind the course-"drift" note below). This is the fix working as designed; worth a release note **when Phase 3 ships** (the RPC is live now, but no UI text has changed yet).
- **Status:** ✅ RESOLVED — `get_due_forecast` body rewritten to the exact `get_study_queue` due predicate; deployed 03/09/2026 (`docs/database/srs-ladder/02_FUNCTIONS`); `03_TEST` block 17 (forecast course-filter parity) PASS. Signature unchanged → no `Progress.jsx` change.

### [03/09/2026] Course "drift" — 1,648 cross-level review rows (CA-Inter students on CA-Foundation cards) — ℹ️ INFORMATIONAL (no action)
- **Found by:** SRS Ladder Phase 0 diagnostics (Q8/Q9/Q10/Q10b, `docs/database/srs-ladder/00_DIAGNOSTIC_srs_ladder_phase0.sql`).
- **Measurement:** 1,659 active reviews across 25 students / 256 cards where `flashcards.target_course <> profiles.course_level`. Q10b: **1,648 are CA-Intermediate students with review history on CA-Foundation cards** (legitimate cross-level revision), + 11 stragglers.
- **Not a data-quality bug:** Q8/Q9 show `course_level` (`CA Foundation`/`CA Intermediate`/`CA Final` + 5 one-off test values) and `target_course` (`CA Intermediate`/`CA Foundation`) are **clean exact-match values with zero spelling variants**. The feared `CA Inter` vs `CA Intermediate` normalization problem does not exist.
- **Interpretation:** this is the Sprint 6.0 read-time course filter working as designed — a CA-Inter student's `get_study_queue` excludes CA-Foundation cards; Custom Course is the accepted escape hatch (per the 6.0 auditor). It is also the mechanism behind the forecast discrepancy above.
- **Status:** ℹ️ INFORMATIONAL — no normalization slice. Recorded for context.

## Resolved — Sprint 6.0 (c) — ✅ FIXED & PUSHED 02/09/2026 (commit under changelog [2026-09-02])

### [02/09/2026] C1 — Admin stat-card user/published counts disagree between Dashboard and Analytics
- **Root cause:** `AdminDashboard.fetchStats` computed `totalUsers = get_platform_stats.student_count + educator_count` — but `get_platform_stats` is the **anon landing** RPC and `student_count`/`educator_count` = `role='student'` + `role='professor'` only (**excludes admin/super_admin**). `AdminAnalytics` "Total Users" reads `get_admin_platform_overview.total_users` (all roles). Two RPCs → two numbers. Separately, *within* AdminAnalytics: the "Published Items" stat card (`overview.published_items`) and the Content-Health table's "Published Items" column (`Σ get_content_health_stats.total_items`) are different things sharing a label.
- **Fix:** `AdminDashboard.fetchStats` now reads `get_admin_platform_overview` for user/public counts (same RPC as `AdminAnalytics` → they agree); `get_platform_stats` removed from admin (landing-only). Raw note/flashcard totals via direct admin `COUNT(*)`. `publicFlashcards` sub (was hardcoded `0`) now real. AdminAnalytics stat card 4 relabelled **"Published Items" → "Public Flashcards"** / sub **"Public flashcards" → "visibility = public"** to kill the collision with the table column.
- **Canonical source:** `get_admin_platform_overview` for all internal admin platform stat cards; `get_platform_stats` for the anon landing page only.
- **Files:** `src/pages/admin/AdminDashboard.jsx` (`fetchStats`), `src/pages/admin/AdminAnalytics.jsx` (overview stat strip).
- **Status:** ✅ RESOLVED (pushed 02/09/2026). Live screenshot comparison of the two dashboards still needs an admin account.

### [02/09/2026] C2 — Quality-tier → colour logic duplicated & inconsistent
- **Root cause:** no shared util. `AdminAnalytics.QualityBadge` tiered a 0–5 value `>=4/>=3/else`; `SuperAdminDashboard` tiered 0–100% active-rate inline ~8 times (daily `>=60/>=40`, weekly `>=80/>=60`).
- **Fix:** new `src/lib/qualityTier.js` — `qualityTier(value, [strongMin, okMin])` → `{key,text,bar,badge,emoji,label}`. Consumers migrated: `AdminAnalytics.QualityBadge` + the `lowQuality` row-highlight; `SuperAdminDashboard` daily/weekly cards extracted to an `ActiveUsersCard` helper that calls `qualityTier`. Distinct thresholds preserved via the arg.
- **Caption:** see C1 (the mislabelled caption was AdminAnalytics stat card 4 "Published Items").
- **Status:** ✅ RESOLVED (pushed 02/09/2026).

### [02/09/2026] C3 — Active-nav highlight matched exact route only
- **Root cause:** `NavDesktop.jsx` `isActive`/`isStudyActive`/`isCreateActive` used `location.pathname === path`. Nested routes (`/dashboard/notes/:id`, `/dashboard/review-session`, `/dashboard/study`, `/dashboard/progress`) never lit their parent.
- **Fix:** `underAny(paths)` prefix matcher. `isCreateActive` checked first so Create wins the tie over Study's broader `/dashboard/notes` + `/dashboard/flashcards` prefixes. Dashboard link stays exact (`isActive`).
- **Status:** ✅ RESOLVED (pushed 02/09/2026). **Sprint 6.2 dependency satisfied.**

### [02/09/2026] C4 — Featured-note "Currently Live" control — NON-ISSUE
- **Verified working.** `AdminDashboard.jsx` `unfeatureContent()` calls the `unfeature_content` RPC and refetches; wired to the "Currently Live" table. No code change.
- **Status:** ✅ NON-ISSUE (no change).

### [02/09/2026] C5 — Anon "Sign up free" wall shown to logged-in students on share pages
- **Root cause:** `NotePreview.jsx` (`/note/:noteId`, public) rendered the blurred preview + "Sign up free to read the full note" overlay unconditionally; only the CTA block was gated on `!user`. `DeckPreview.jsx` had the sibling issue (public preview shown to logged-in users).
- **Fix:** `NotePreview.jsx` — when `getUser()` returns a user, `navigate('/dashboard/notes/' + noteId, { replace: true })` and skip the preview fetch. `DeckPreview.jsx` — an effect redirects to `/dashboard/review-flashcards?deck=:deckId` when `useAuth().user` is set.
- **Status:** ✅ RESOLVED (pushed 02/09/2026). Live check (logged-in student on a `/note/:id` link) still needs a student account. `NoteDetail.jsx`'s Tier-B `ContentPreviewWall` is the intentional B2C freemium gate — untouched.

### [02/09/2026] C6 — "Due Today: 0" rendered as a red alarm
- **Root cause:** `Progress.jsx` ForecastCard for "Due Today" hardcoded `accent="text-red-600 bg-red-50 border-red-200"` regardless of `forecast.due_today`.
- **Fix:** `accent` is now `text-green-700 bg-green-50 border-green-200` when `due_today === 0`, red only when `> 0` (existing tokens, no new ones). *(Sprint-prompt tension noted: the prompt says "reserve alarm styling for genuine problems"; the coordinator directed "red only when >0" — followed the coordinator. Flip one ternary branch to amber if the >0 case should also be de-alarmed.)*
- **Status:** ✅ RESOLVED (pushed 02/09/2026).

## Resolved Bugs

### [04/07/2026] Unguarded admin/internal writers + a read-guard over-guard regression
- **Found by:** the residual-IDOR sweep (`docs/database/security/12_DIAGNOSTIC...`), run to *prove* the advisor's 116 WARNs harmless. The advisor doesn't detect IDOR — this sweep did.
- **Gaps found & fixed:**
  - `enroll_user_in_batch_group(p_user_id)` + `notify_access_granted(p_user_id)` — SECURITY DEFINER writers taking a *target* user with no auth check; any authenticated user could enroll/notify arbitrary users. Admin-RPC-only (confirmed via `14_DIAGNOSTIC` caller audit) → added `IF NOT is_admin() THEN RAISE` (`15_FUNCTIONS`).
  - `log_review_activity(p_user_id, …)` — internal helper (only the `fn_badge_check_reviews` trigger calls it) but `authenticated`-executable + unguarded → inject-activity-for-anyone. Revoked `authenticated`/`anon` EXECUTE (`16_SCHEMA`); trigger path (runs as owner) unaffected. Verified: `17_TEST` 6/6.
- **Regression I introduced & fixed same session:** the read-IDOR pass (`08`) guarded `get_user_streak` to self-only, but a streak is **social** data — `get_following_with_stats` / `get_my_friends_with_stats` / `get_batch_group_member_stats` call `get_user_streak(other_user)` to show friends'/members' streaks. The guard broke those 3 pages for non-admins. Reverted (`bugfixes/13_FUNCTIONS`); `bugfixes/14_DIAGNOSTIC` confirmed it was the only misclassification.
- **Key lesson:** **audit internal callers before adding a guard that RAISEs.** The admin-writer fixes did this (`14`) and were clean; the read guards (`08`) didn't and broke a social path. A guard on a SECURITY DEFINER function affects *every* caller, including triggers and other functions — not just the frontend.
- **Status:** ✅ RESOLVED (deployed & verified live 04/07/2026)

### [04/07/2026] Read-side IDOR — SECURITY DEFINER RPCs let any user read another user's private data
- **Found by:** the read-IDOR audit (`docs/database/security/07_DIAGNOSTIC...`), requested after L5.
- **Symptom:** several SECURITY DEFINER functions took `p_user_id`/`p_professor_id` and returned that user's data **without checking it against `auth.uid()`**. SECURITY DEFINER bypasses RLS, so the param was fully trusted. An authenticated user could pass another person's UUID and read their study stats, notifications, suspended cards (incl. card text), streaks, subject mastery, and professor analytics. **`get_user_badges` was a *live* leak** — the returned data includes **private** badges (no `is_public` filter), and a dead-but-present hook helper (`useBadges.js` `fetchUserBadges`) called it cross-user.
- **Also caught:** **`unsuspend_card`** — a card-scheduling **write** RPC that the L5 IDOR pass missed. Root cause of the miss: the L5 write-guard audit's regex used `update ` with a trailing word-boundary that never matched `UPDATE`-only functions, so UPDATE-only writers (`unsuspend_card`, `get_unnotified_badges`) were misclassified as reads.
- **Confirmed via:** `07_DIAGNOSTIC` (classified secdef reads taking a user-id param by whether they reference `auth.uid()`) + `07b_DIAGNOSTIC` (bodies of the ambiguous/professor fns). `get_unread_notification_count` + `mark_notifications_read` were already guarded (no change).
- **Fix:** `08_FUNCTIONS` (10 group-A self-only guards; 4 `LANGUAGE sql` → `plpgsql` to allow the `RAISE`), `09_FUNCTIONS` (5 professor guards, `p_professor_id = auth.uid() OR is_admin()`), `10_FUNCTIONS` (`get_user_badges` self-only), + removed the dead cross-user `fetchUserBadges` from `useBadges.js` (FindFriends already fetches others' badges via a direct `is_public = true` query; `get_public_user_badges` is the correct cross-user RPC).
- **Verified via:** `11_TEST_verify_read_idor_guards.sql` — 7/7 PASS (cross-user reads/writes RAISE `Access denied`; self-calls work).
- **Key lessons:** (1) SECURITY DEFINER reads taking an identity param must constrain it to `auth.uid()` (or admin) exactly like writes — the READ side leaks too. (2) A write-detection regex must actually match `UPDATE`/`INSERT`/`DELETE` — verify the audit's own coverage, or writers slip through.
- **Status:** ✅ RESOLVED (deployed & verified live 04/07/2026)

### [04/07/2026] skip_card / suspend_card errored on first-ever skip/suspend of a card (wrong reviews columns)
- **Found by:** L5 SECURITY DEFINER write-guard audit (flagged during IDOR-guard work, fixed in a follow-up pass).
- **Symptom (latent):** `skip_card` / `suspend_card`'s `IF NOT FOUND THEN INSERT INTO reviews (...)` branch — which fires the **first time** a user skips/suspends a card they have **no review row** for — named columns `easiness_factor` and `repetitions`, which don't exist. That path threw `42703 column "easiness_factor" of relation "reviews" does not exist`. The common path (card with an existing review → `UPDATE`) worked, so it went unnoticed.
- **Root Cause:** the reviews table uses `easiness` (double precision) + `repetition` (integer) — same wrong-column-name bug fixed in `skip_topic_cards`/`suspend_topic_cards` on Apr 4, 2026, but these two single-card functions were missed then.
- **Confirmed via:** `docs/database/bugfixes/08_DIAGNOSTIC_reviews_columns_for_skip_suspend_fix.sql` — Block 1 showed `easiness`/`repetition` (not `easiness_factor`/`repetitions`); `next_review_date` is a `date` column (branch passed `NOW()`).
- **Fix:** `docs/database/bugfixes/09_FUNCTIONS_fix_skip_suspend_card_reviews_columns.sql` — `CREATE OR REPLACE` both with `easiness`/`repetition`, and `CURRENT_DATE` for `next_review_date` (matching `skip_topic_cards`). L5 IDOR guard + `search_path` preserved verbatim.
- **Verified via:** `10_TEST_verify_skip_suspend_card_insert.sql` — skip/suspend a card with no prior review → review row created (`active`/`suspended`), no `42703`. 2/2 `[CRITICAL]` PASS.
- **Key lesson:** when fixing a column-name bug in one function, grep for the same wrong names across ALL functions — the Apr 4 fix corrected the topic-scoped RPCs but left the single-card twins with the same defect for ~3 months.
- **Status:** ✅ RESOLVED (deployed & verified live 04/07/2026)

### [04/07/2026] IDOR — card-scheduling RPCs let any user modify another user's review schedule
- **Found by:** L5 SECURITY DEFINER write-guard audit (`docs/database/security/01_DIAGNOSTIC...`), not a user report.
- **Symptom (latent, not observed in the wild):** `skip_card`, `suspend_card`, `reset_card`, `skip_topic_cards`, `suspend_topic_cards` are SECURITY DEFINER, take `p_user_id`, and wrote to `reviews` **without checking `p_user_id = auth.uid()`**. Any authenticated user could call `/rest/v1/rpc/skip_topic_cards` with another student's UUID and tamper with their spaced-repetition schedule (horizontal privilege escalation). No data theft — unauthorized modification.
- **Root Cause:** the functions trusted the caller-supplied `p_user_id` (frontend always passes `user.id`, but nothing enforced it server-side).
- **Fix:** `docs/database/security/02_FUNCTIONS...` + `02b_FUNCTIONS...` — added `IF p_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN RAISE EXCEPTION 'Access denied'` to all five; bodies otherwise verbatim.
- **Verified via:** `06_TEST_verify_l5_hardening.sql` — cross-user `skip_card`/`suspend_topic_cards` RAISE `[CRITICAL]`; own-card action allowed.
- **Key lesson:** any SECURITY DEFINER function that takes a `p_user_id` (or other identity param) and writes must verify it against `auth.uid()` — SECURITY DEFINER bypasses RLS, so the param is otherwise fully trusted.
- **Status:** ✅ RESOLVED (deployed & verified live 04/07/2026)

### [04/07/2026] Dashboard deck grid + Recent Activity listed public decks with 0 viewer-visible cards
- **Reported by:** Founder (logged in as CA Anand More, professor) — after a student set their only card to private, the deck still appeared in Review Flashcards ("1 card, by TestOutlook") and in dashboard Recent Activity; clicking it opened an empty study session ("No flashcards to study").
- **Symptom:** a public deck whose only card is now private still leaked its **metadata** (name, author, count, activity) to other users, though the card **content** was correctly hidden. Distinct surface from the public-preview bug above — this is the authenticated dashboard, which was the report's actual context.
- **Root Cause:** `get_browsable_decks` and `get_recent_activity_feed` (its `recent_decks` CTE) gated at the **deck** level (`fd.visibility`) and (for the grid) returned the denormalized `fd.card_count` — neither checked per-**card** visibility. A public deck around private cards therefore listed. `get_browsable_notes` was NOT affected (notes are atomic).
- **Confirmed via:** `docs/database/bugfixes/04_DIAGNOSTIC_listing_surfaces_visibility.sql` — dumped both function bodies; Query 3 showed deck `1e521de5` = public, stored_count 1, **0 public / 1 private**.
- **Fix (SQL only):** `05_FUNCTIONS` (`get_browsable_decks` v4 — `LATERAL` viewer-visible card count, exclude decks with 0, return that as `card_count`) + `06_FUNCTIONS` (`get_recent_activity_feed` — `EXISTS` a viewer-visible card in `recent_decks`).
- **Verified via:** `07_TEST` 4/4 PASS — non-owner professor sees deck `1e521de5` in neither surface `[CRITICAL]`; owner still sees it with `card_count=1`.
- **Key lesson:** for a **container** whose visibility is decoupled from its children (deck→cards), gating the container is not enough — any listing/feed surface must check per-child visibility for the viewer, and denormalized counts (`card_count`) leak child existence. (Atomic content like notes is fine gated on its own visibility.)
- **Status:** ✅ RESOLVED (deployed & verified live 04/07/2026)

### [04/07/2026] Public deck preview leaked private/friends cards to anyone (incl. anonymous)
- **Reported by:** Founder — a flashcard created public by a student (TestOutlook), then changed to **private** by the creator, was still visible inside the deck to another user (CA Anand More, professor).
- **Symptom:** After a creator set a card to `private`, its `front_text` still appeared on the public deck preview page (`/deck/:id`). Reproducible by **anyone**, including logged-out visitors — broader than the reported professor case.
- **Root Cause:** `get_public_deck_preview(p_deck_id)` is a `SECURITY DEFINER` RPC (bypasses RLS). It gated the **deck** on `visibility='public'` but its inner `preview_items` subquery selected the first cards **with no per-card visibility filter**. So private/friends cards inside a public deck leaked. The in-app StudyMode view was NOT affected (RLS-protected direct query that also excludes `private` client-side).
- **Confirmed via:** `docs/database/bugfixes/01_DIAGNOSTIC_deck_preview_visibility_leak.sql` — Block 1 showed the live body had no `fc.visibility` predicate in the preview subquery; Block 2 found 1 live public deck (`1e521de5…`) with 1 non-public card being served. Not on `deck_id` (never populated) — the RPC uses the 5-grouping-column join.
- **Fix (SQL only, no frontend change):** `docs/database/bugfixes/02_FUNCTIONS_fix_public_deck_preview_visibility.sql` — `CREATE OR REPLACE` adding `AND fc.visibility = 'public'` to the preview subquery. Also made the public `card_count` count public cards only (was `fd.card_count`, a trigger-maintained total that revealed how many hidden cards exist) and added deterministic `ORDER BY created_at`. Signature unchanged → safe in-place replace; `NOTIFY pgrst`.
- **Verified via:** `docs/database/bugfixes/03_TEST_verify_public_deck_preview_visibility.sql` — public deck with one public + one private card; all 3 assertions PASS (private card NOT in preview `[CRITICAL]`, public card present, `card_count`=1).
- **Key lessons:**
  - Any `SECURITY DEFINER` RPC that returns content on a public/anon surface must filter visibility **explicitly** — RLS does not protect it. The deck-level gate is not enough; per-**card** visibility must be filtered too.
  - The 5-grouping-column flashcards→decks join returns **all** visibility tiers by itself; content-returning RPCs must add `fc.visibility = 'public'` (or the appropriate per-viewer predicate) on top of it.
  - Context of the L2 migration: `is_public` was dropped 03/07/2026; `visibility` is the sole gate.
- **Status:** ✅ RESOLVED (deployed & verified live 04/07/2026)

### [Apr 4, 2026] Suspend Topic — "Failed to suspend topic" error after Sprint 4.0 deploy
- **Reported by:** Aryan Pamnani (iOS, live session)
- **Symptom:** Tapping "Suspend Topic" in the `...` dropdown showed the red "Failed to suspend topic." error toast immediately. Affected all cards regardless of topic type.
- **Root Cause:** PostgreSQL's `CREATE OR REPLACE FUNCTION` only replaces a function if the parameter signature is identical. The Sprint 4.0 SQL for `suspend_topic_cards` changed the signature from `(UUID, UUID)` to `(UUID, UUID DEFAULT NULL, TEXT DEFAULT NULL)` — a different signature. PostgreSQL created a second overloaded version rather than replacing the original. PostgREST then found two functions with the same name and refused to resolve the call, returning an ambiguity error. The frontend's `catch` block displayed "Failed to suspend topic."
- **Confirmed via:** `SELECT pg_get_function_arguments(p.oid) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'public' AND p.proname = 'suspend_topic_cards'` — returned two rows.
- **Fix (step 1):** `DROP FUNCTION IF EXISTS public.suspend_topic_cards(UUID, UUID)` — removed the stale 2-param overload. The new 3-param version handles all existing callers via `DEFAULT NULL` on the added parameter.
- **Fix (step 2):** `NOTIFY pgrst, 'reload schema'` — PostgREST caches function signatures and continued serving the stale two-function schema even after the DROP. The NOTIFY forces an immediate schema reload, resolving the ambiguity error for live users.
- **Fix (step 3):** Wrong column names in both RPC bodies — `easiness_factor` (actual: `easiness`) and `repetitions` (actual: `repetition`). Both RPCs were written from DATABASE_SCHEMA.md which itself had the wrong column names. The error only surfaced when Aryan triggered an INSERT path (cards with no existing review record). The SQL Editor diagnostic passed silently because the test student+topic combination had zero matching flashcards — the INSERT never ran. Confirmed via browser console: `code 42703 — column "easiness_factor" of relation "reviews" does not exist`. Fixed by `CREATE OR REPLACE` of both functions with correct column names + `NOTIFY pgrst, 'reload schema'` in same execution.
- **Root cause of the root cause:** DATABASE_SCHEMA.md had wrong column names for the `reviews` table (`easiness_factor` instead of `easiness`, `repetitions` instead of `repetition`). The schema doc was the single source of truth used to write the SQL. DATABASE_SCHEMA.md has been corrected and the CRITICAL section updated with a rule: any SQL against `reviews` must be cross-checked against the actual column names in `StudyMode.jsx` handleRating before deploying.
- **Key lessons:**
  - When adding parameters to an existing RPC, always explicitly DROP the old signature before or after the `CREATE OR REPLACE`. Never assume `CREATE OR REPLACE` replaces across signature changes — in PostgreSQL it does not.
  - After any DROP FUNCTION or signature change, always run `NOTIFY pgrst, 'reload schema'` immediately. Without it, PostgREST continues to serve the stale cache and users continue to see the error even though the database is already correct.
  - SQL Editor diagnostics that return "Success" on a function with zero matching rows DO NOT validate the INSERT body. Always test with data that actually triggers the INSERT path.
  - Never trust schema docs alone for column names. Cross-check against the working frontend code (handleRating in StudyMode.jsx is the ground truth for `reviews` column names).
- **Status:** ✅ RESOLVED

### [Apr 4, 2026] FlashcardCreate — Back button discards all unsaved cards with no warning
- **Symptom:** User creates multiple flashcards using "Add Another Flashcard", then accidentally taps the Back button. All card content is lost immediately. No confirmation, no recovery. Reported by Pareesa after losing 45 cards in a single session.
- **Root Cause:** The Back button and Cancel button both called `navigate(-1)` directly with no navigation guard. No autosave existed.
- **Fix:** Three-layer protection added to `FlashcardCreate.jsx`: (1) `useBlocker` intercepts in-app navigation when dirty and shows a confirmation modal; (2) `beforeunload` event intercepts tab close/reload; (3) localStorage autosave (1s debounce) persists card content, with a recovery banner shown on next visit. See Sprint 4.1 in changelog for full details.
- **Status:** ✅ RESOLVED

### [Mar 30, 2026] Push notifications never delivered since Sprint 3.6 — CRON_SECRET mismatch
- **Symptom:** No student received any push notification (nightly study summary or morning review reminder) since Sprint 3.6 shipped on 2026-03-25. Edge Function invocations all returned HTTP 401.
- **Root Cause (primary):** `cron-daily-study-summary` pg_cron job was created with the literal placeholder `YOUR_CRON_SECRET_HERE` as the `x-cron-secret` header value, never replaced with the real secret. Function's auth guard rejected every call.
- **Root Cause (secondary):** Fixing required rotating `CRON_SECRET` via Supabase CLI (`npx supabase secrets set`). `daily-review-reminders` was correctly configured with the original hash but that hash no longer matched after rotation → also broke until resynced.
- **Fix:** Recreated both pg_cron jobs via `cron.unschedule()` + `cron.schedule()` with correct matching secret. Confirmed 200 response on next invocation.
- **Key lesson:** `CRON_SECRET` is shared by all cron-triggered Edge Functions. Before rotating it, audit every cron job command that sends it in an `x-cron-secret` header — resync all jobs atomically.
- **Status:** ✅ RESOLVED

### [Mar 27, 2026] iOS 16.7.5 — Push notification install instructions never shown
- **Symptom:** iOS users in regular Safari saw neither the push enable button nor the "Add to Home Screen" instructions.
- **Root Cause:** `PushPermissionBanner.jsx` evaluated `if (!isSupported) return null` before the `needsIOSInstall` check. On iOS in-browser, `PushManager` is not in `window`, so `isSupported = false` and the component returned `null` before reaching the iOS-specific render path. The iOS instructions were dead code.
- **Fix:** Moved `handleDismiss` above all guards; inserted the `needsIOSInstall` early return (with `isDismissed` guard) before the `isSupported` guard.
- **Status:** ✅ RESOLVED

### [Mar 27, 2026] Study time not updating after flashcard review session
- **Symptom:** Completing a flashcard study session did not add time to the "Study time today" dashboard stat. Affected all platforms (not just iOS).
- **Root Cause:** `handleRating()` in `StudyMode.jsx` handled the last-card completion inline: `if (onComplete) onComplete(sessionStats); else { toast(); onExit(); }`. This code path never called `finishSession()` or `logStudyModeSession()`. Only the skip/suspend/reset-on-last-card paths called `finishSession()`. The rating path — the primary completion path for all students — silently discarded the session.
- **Fix:** Replaced the inline last-card completion block in `handleRating` with a single `finishSession()` call.
- **Status:** ✅ RESOLVED

### [Mar 27, 2026] handleStop — 21h+ sessions bypass leaderboard protection
- **Symptom:** A student who kept the browser tab open (never reloading the page) and manually pressed Stop after 21+ hours would have the full duration logged to the DB, bypassing leaderboard integrity protection. Confirmed via diagnostic: a 76,035s (21.1h) session existed in `study_sessions`.
- **Root Cause:** The 16h discard threshold only ran on page **mount** (stale session recovery). `handleStop` had no duration check at all — it passed any elapsed time directly to `insertSession`.
- **Fix:** Applied the same 3-tier policy to `handleStop` as mount-time stale session recovery: `< 4h` logs normally; `4–16h` routes to the honest-session prompt (localStorage keys preserved for mount recovery if student navigates away); `> 16h` discards and shows a destructive toast. Added `useToast` import to `StudyTimerWidget.jsx`.
- **Status:** ✅ RESOLVED

### [Mar 27, 2026] Android — After recovery prompt, second study session not started (UX gap)
- **Symptom:** After the 4–16h stale-session recovery prompt logged a session, students did not realize they needed to press Start again for a new session. Total study time appeared lower than actual.
- **Root Cause:** No code-level cap found in `insertSession`, `GoalProgressWidget`, or `get_study_time_stats` (RPC diagnostic pending). The UX gap: post-recovery idle state showed "Session logged: Xh Ym" + Start button but no guidance linking the two.
- **Fix:** Added `postRecovery` boolean state in `StudyTimerWidget`. Set to `true` after recovery-prompt log, cleared on Start. When true, a "Tap Start to begin a new session." hint appears below the confirmation text.
- **Status:** ✅ UX fixed. SQL diagnostic for RPC cap still pending — run `[DIAGNOSTIC] Inspect get_study_time_stats for duration cap` in Supabase to confirm no server-side filter exists.

### [Mar 22, 2026] FindFriends — Raw email exposed in network payload (client-side masking only)
- **Symptom:** `FindFriends.jsx` queried `profiles` with `email` in the select. `maskEmail()` hid the address in the UI but any user with DevTools could read the full email of every user on the platform in the network response.
- **Root Cause:** No server-side filtering. The function `maskEmail()` was purely cosmetic. The comment at line 14 acknowledged this explicitly: "NOTE: Email masking is cosmetic only. Full email is present in data payload."
- **Fix:** Replaced direct `.from('profiles')` query with `.rpc('get_discoverable_users')` SECURITY DEFINER function. Masking now happens inside PostgreSQL — `left(email, 1) || '***@' || domain`. Raw email never appears in the RPC response.
- **Status:** ✅ RESOLVED

### [Mar 22, 2026] FindFriends — No course-level filtering (all users shown to all users)
- **Symptom:** `FindFriends.jsx` returned every user on the platform regardless of course. A CA Foundation student saw CA Final, CMA, and all other users.
- **Root Cause:** The direct `profiles` query had no `course_level` filter. There was a stale help section entry ("Filter by course level") but no such client-side filter existed in the code.
- **Fix:** `get_discoverable_users()` RPC filters `WHERE p.course_level = v_course_level` server-side. Cross-institute same-course connections are still allowed (intentional product design).
- **Status:** ✅ RESOLVED

### [Mar 20, 2026] AuthContext signUp — profile INSERT fails with 401 (no session during email-confirmation flow)
- **Symptom:** New user signs up → email confirmed → logs in → intermittent missing profile rows; browser console showed 401 on `profiles` INSERT during signup.
- **Root Cause:** `AuthContext.signUp()` called `supabase.from('profiles').insert(...)` client-side immediately after `supabase.auth.signUp()`. With email confirmation ON, `signUp()` returns a `user` object but **no session** — `auth.uid()` is null. RLS blocked the insert silently (returned a `profileError` but the code only logged a warning and continued). Users who signed up could sometimes land in a state with no profile row.
- **Discovery:** Pre-flight diagnostic in Sprint 2.4 confirmed no `auth.users` trigger existed for profile creation — the client-side insert was the only write path, and it was unreliable.
- **Fix:** Deployed `trg_create_profile_on_signup` — a SECURITY DEFINER trigger on `auth.users` INSERT that creates the profile row server-side using `raw_user_meta_data`. Removed the client-side insert and the 100ms delay from `AuthContext.signUp()`. Timezone defaults to `Asia/Kolkata` and is overwritten on first login by `updateUserTimezone()`.
- **Status:** ✅ RESOLVED

### [Mar 19, 2026] Group Invite Links Return "Link not found" for Batch Groups
- **Symptom:** Visiting `/join/:token` for a batch group token showed "This invite link is invalid or the group no longer exists."
- **Root Cause:** `get_group_preview` had `AND is_batch_group = false` in the token lookup query. Batch group tokens always returned `{ group: null, stats: null }`. GroupJoin set `notFound = true` and showed the error screen.
- **Fix:** Removed `is_batch_group = false` filter from both `get_group_preview` and `join_group_by_token` RPCs. Also fixed two bugs in `get_group_preview` stats query: (1) `p.current_streak` column doesn't exist anywhere in the DB — hardcoded `0` for avg_streak; (2) `badges` table doesn't exist — corrected to `badge_definitions`.
- **Status:** ✅ RESOLVED

### [Mar 19, 2026] postAuthRedirect Race Condition — Always Lands on /dashboard Instead of Join Page
- **Symptom:** User visits `/join/:token` → clicks "Sign in" → logs in → lands at `/dashboard` instead of back at the join page. `localStorage` was confirmed to be set correctly before login, but was `null` by the time Login.jsx or AppContent read it post-login.
- **Root Cause:** Supabase's `onAuthStateChange` fires synchronously inside `signIn()` (before the Promise resolves). This triggers React's auth state update, which fires AppContent's `useEffect([user, loading])`. That effect reads AND removes `localStorage.postAuthRedirect`, then navigates to `/join/:token`. Then `signIn()` Promise resolves and Login.jsx's code continues — reads localStorage (now null) — navigates to `/dashboard`, overriding AppContent's navigation. Last `navigate()` wins.
- **Secondary issue:** PostAuthRedirect component (tried as intermediate solution) suffered from React 18 StrictMode double-invocation: effects run twice in development. First run navigated correctly; second run found empty localStorage and navigated to `/dashboard`.
- **Fix:** Read and remove `localStorage.postAuthRedirect` BEFORE calling `signIn()` in Login.jsx. Store in a local variable. AppContent's useEffect fires during signIn() but finds nothing (already cleared) and does nothing. After signIn() resolves, Login.jsx navigates using the local variable. On error, key is restored to localStorage.
- **Status:** ✅ RESOLVED

### [Mar 19, 2026] DeckPreview Public Page Shows "Preview (0 of N items)"
- **Symptom:** Public deck URL shared via WhatsApp showed correct deck metadata but 0 preview cards ("Preview (0 of 21 items)"). The ContentPreviewWall appeared but no question cards were visible.
- **Root Cause:** `get_public_deck_preview` fetched flashcards using `WHERE fc.deck_id = p_deck_id`. The `deck_id` column on the `flashcards` table exists as a FK to `flashcard_decks.id` but is **never populated** by any write path. The `update_deck_card_count` trigger (which correctly maintains `card_count`) matches flashcards to decks via 5 grouping columns `(user_id, subject_id, topic_id, custom_subject, custom_topic)` — not by `deck_id`.
- **Fix:** Rebuilt `get_public_deck_preview` to join flashcards to the deck using the same 5 grouping columns the trigger uses.
- **Documentation:** Added critical rule to CLAUDE.md and DATABASE_SCHEMA.md — `deck_id` on flashcards is never populated; always join on grouping columns.
- **Why it wasn't caught earlier:** Was tested in localhost with a different (newer) deck whose creation flow happened to populate `deck_id`; or tested while logged in where the ContentPreviewWall appearing masked the 0-card count.
- **Status:** ✅ RESOLVED

### [Mar 19, 2026] Groups Page — Professor Course Switch Does Not Update Batch Groups
- **Symptom:** Professor with 3 teaching courses (CA Intermediate primary, CA Foundation + CA Final secondary) saw only the CA Intermediate batch group regardless of which course was selected in the top menu.
- **Root Cause:** `get_my_batch_groups` professor path was returning only batch groups for the professor's primary/teaching courses via a course-name match that had an issue (likely matched only primary). All 3 batch groups were confirmed to exist with correct `batch_course` values matching discipline names exactly.
- **Fix:** Rebuilt professor path in `get_my_batch_groups` to return ALL batch groups. Client-side `activeCourse` filter in `MyGroups.jsx` already correctly handles per-course display — no frontend change needed.
- **Status:** ✅ RESOLVED

### [Mar 19, 2026] DeckPreview CTA Misleading for Professor Decks
- **Symptom:** CTA on public DeckPreview page said "Sign up free to study all 21 cards." For professor-created decks, Tier B students after signup only get a 10-card preview — the CTA was a false promise.
- **Root Cause:** CTA copy assumed signup = full access, which is true only for student-created public decks.
- **Fix:** CTA changed to "Start studying on Recall — it's free" with subtext about spaced repetition and progress tracking. Card count no longer mentioned in CTA (it's already visible in the deck header). Accurate for both professor and student decks.
- **Status:** ✅ RESOLVED

### [Mar 19, 2026] Groups Page Shows No Batch Groups for Admin / Super Admin
- **Symptom:** After creating batch groups, admin and super_admin logins showed no batch groups on the Groups page. Personal groups were visible. Batch groups only visible in Admin Dashboard.
- **Root Cause:** Admin/super_admin accounts had `profile_courses` entries left over from when they were originally created as students and later promoted. `CourseContext` reads `profile_courses` and sets `activeCourse` to the primary teaching course. `MyGroups.jsx` filter: `groups.filter(g => !g.is_batch_group || g.batch_course === activeCourse)` then hid all batch groups whose `batch_course` didn't match that stale `activeCourse`. `get_my_batch_groups` RPC was correctly returning all batch groups server-side, but the client-side filter discarded them.
- **Fix:**
  1. SQL: `DELETE FROM profile_courses WHERE user_id IN (SELECT id FROM profiles WHERE role IN ('admin', 'super_admin'))` — clears stale entries → `activeCourse` falls back to `null` → filter skipped → all batch groups visible
  2. Also nulled `course_level` for admin/super_admin since student course data is irrelevant to their role
- **Status:** ✅ RESOLVED

### [Mar 19, 2026] Super Admin User Hard Delete — Profile Silently Not Deleted, Auth Deletion Blocked
- **Symptom:** When super_admin clicked Delete on a user in SuperAdminDashboard, the confirmation completed with no error. But going to Supabase Auth dashboard and trying to delete the auth user showed "Database error deleting user". User remained in the system.
- **Root Cause (stage 1):** `deleteUser` called direct `.delete()` on `profiles` from the client. RLS on profiles has no DELETE policy for super_admin → delete was silently blocked (Supabase returns success with 0 rows affected, no error). Profile was never actually deleted.
- **Root Cause (stage 2):** `admin_audit_log.target_user_id` FK referenced `profiles(id)` with `ON DELETE NO ACTION`. Retained audit log entries (from the deletion attempt itself) prevented the profile row from being deleted even when tried manually. And without the profile being deleted, auth user deletion failed due to `profiles.id → auth.users(id)` FK.
- **Fix:**
  1. `ALTER TABLE admin_audit_log` FK changed to `ON DELETE SET NULL` — audit records retained with `target_user_id = null`; user details preserved in `details` JSONB
  2. Created `admin_delete_user_data(p_user_id uuid)` SECURITY DEFINER RPC — bypasses RLS; deletes all related rows (study_group_members, profile_courses, reviews, flashcards, flashcard_decks, notes, profiles) in correct order
  3. `SuperAdminDashboard.jsx` `deleteUser` — replaced direct cascade deletes with single `rpc('admin_delete_user_data')` call
- **Note:** Auth record (`auth.users`) still requires manual deletion from Supabase dashboard. Automating this requires a service-role Edge Function (planned future sprint).
- **Status:** ✅ RESOLVED

### [Mar 19, 2026] Profile Creation Silently Fails for All New Signups (9 Orphaned Accounts)
- **Symptom:** Auth users existed in `auth.users` but had no corresponding row in `profiles`. These users could not log in or use the app. 9 affected accounts discovered via `SELECT u.id FROM auth.users u LEFT JOIN profiles p ON p.id = u.id WHERE p.id IS NULL`.
- **Root Cause:** `signUp()` with Supabase email confirmation ON returns no session (user must verify email first). `AuthContext.jsx` then attempted `supabase.from('profiles').insert()` with `auth.uid() = null` → RLS INSERT policy requires `id = auth.uid()` → INSERT silently blocked. No error thrown (code used `console.warn` and continued). Auth user was created; profile was not.
- **Why earlier users were unaffected:** Email confirmation was ON from Day 1. Investigation ongoing — likely a code path change in AuthContext around mid-March caused the direct insert to be reached after the RLS policy was added (Mar 12 RLS sprint).
- **Fix:**
  1. Created `handle_new_user()` SECURITY DEFINER trigger on `auth.users` AFTER INSERT — creates profile from `raw_user_meta_data` at DB level regardless of session state
  2. Bulk backfill: `INSERT INTO profiles SELECT ... FROM auth.users LEFT JOIN profiles WHERE profiles.id IS NULL`
- **Lesson added to CLAUDE.md:** When enabling RLS on a table, audit every existing INSERT path. Any write that must succeed without a client session (signup, email confirmation flows) MUST use a SECURITY DEFINER trigger or RPC.
- **Status:** ✅ RESOLVED

### [Mar 19, 2026] ContentPreviewWall Form Submission — HTTP 400 (Two Separate Causes)
- **Symptom:** Submitting the WhatsApp lead capture form returned HTTP 400. Form appeared to submit but nothing was saved.
- **Root Cause 1:** `access_requests.status` and `requested_at` columns had no DEFAULT values. NOT NULL constraint with no DEFAULT → INSERT from RPC failed.
- **Fix 1:** `ALTER TABLE access_requests ALTER COLUMN status SET DEFAULT 'pending', ALTER COLUMN requested_at SET DEFAULT now()`
- **Root Cause 2:** `anon` role lacked EXECUTE permission on `submit_access_request` RPC. SECURITY DEFINER bypasses RLS inside the function but the `anon` role still needs explicit GRANT to call it at all.
- **Fix 2:** `GRANT EXECUTE ON FUNCTION submit_access_request(...) TO anon`
- **Status:** ✅ RESOLVED

### [Mar 19, 2026] DeckPreview Access Request — content_type Check Constraint Violation
- **Symptom:** Submitting the ContentPreviewWall form from a deck preview page returned a check constraint violation error.
- **Root Cause:** `DeckPreview.jsx` passed `contentType = 'deck'` but `access_requests.content_type` CHECK constraint only allows `'flashcard_deck'` and `'note'`.
- **Fix:** Changed `contentType` prop in `DeckPreview.jsx` to `'flashcard_deck'`.
- **Status:** ✅ RESOLVED

### [Mar 19, 2026] Admin/Super Admin Not Receiving Access Request Notifications
- **Symptom:** When a student submitted an access request form, no notification appeared in admin/super admin accounts.
- **Root Cause:** `notify_access_request` function filtered with `WHERE account_type IN ('admin', 'super_admin')`. All profiles have `account_type = 'enrolled'` (or `'self_registered'`). Admin/super admin distinction is stored in the separate `role` column.
- **Fix:** Changed WHERE clause to `WHERE role IN ('admin', 'super_admin')`.
- **Status:** ✅ RESOLVED

### [Mar 19, 2026] Notification INSERT Failing — notifications_type_check Constraint
- **Symptom:** `submit_access_request` RPC failed when trying to insert a notification of type `'access_request'`.
- **Root Cause:** `notifications_type_check` constraint did not include `'access_request'` as an allowed type.
- **Fix:** Dropped and recreated constraint adding `'access_request'` to the allowed values array.
- **Status:** ✅ RESOLVED

### [Mar 19, 2026] User Management Tab Shows Empty List
- **Symptom:** Admin Dashboard → User Management tab showed no users despite 141+ accounts existing.
- **Root Cause:** `fetchUsers` query selected `status` column which did not exist on the `profiles` table. Supabase returned an error which was caught silently → empty list rendered.
- **Fix:** `ALTER TABLE profiles ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','suspended'))`
- **Status:** ✅ RESOLVED

### [Mar 19, 2026] Blank Course Dropdown in ReviewFlashcards + BrowseNotes
- **Symptom:** For users enrolled in a course that has no public content yet (e.g. CA Final student Aaryaman More), the Course filter dropdown showed a blank selected value instead of "All Courses".
- **Root Cause:** Filter defaulted to the user's `course_level` but no content existed for that course, so the dropdown option was never populated — blank option was selected.
- **Fix:** Frontend fix to default to "All Courses" when the user's course has no content in the available options.
- **Status:** ✅ RESOLVED

### [Mar 15, 2026] Progress Page "All My Content" Shows Subjects from Non-Enrolled Courses
- **Symptom:** A student enrolled in CA Intermediate saw "Business Laws" (a CA Foundation subject) in their Subject Mastery table on the "All My Content" tab, with 0 reviews and 201 total cards. Similarly, a CA Foundation student saw CA Intermediate subjects.
- **Root Cause:** "All My Content" tab passed `courseLevel={null}` to `get_subject_mastery_v1` and `get_question_type_performance`. The RPCs interpret `null` as "no course filter" → return all public cards across all courses. With 659 total public cards spread across CA Foundation, Intermediate, and Final, any student saw every subject in the system.
- **Fix:** Added `allTabCourseLevel` computed value in `Progress.jsx`. Logic: if user has exactly 1 enrolled course (`courseOptions.length === 1`), scope "All My Content" to that course. Professors with 2+ teaching courses remain unscoped (`null`) — they legitimately own content across all courses.
- **No SQL changes required** — frontend-only fix.
- **Status:** ✅ RESOLVED — commit pending

### [Mar 13, 2026] Progress Page Tabs Broken — Both Tab Contents Always Visible
- **Symptom:** Clicking "All My Content" / "Course: CA Intermediate" tabs had no effect (cursor changed to pointer but nothing happened). Full report appeared twice on the page — once for "All" and once for "Course".
- **Root Cause:** `src/components/ui/tabs.jsx` is a custom stub — `Tabs`, `TabsList`, `TabsTrigger`, `TabsContent` are plain `<div>`/`<button>` elements with no `value`/`onValueChange` wiring and no show/hide logic. Both `TabsContent` elements always rendered. `TabsTrigger` click events were swallowed (no `onClick` passed through).
- **Fix:** Removed `Tabs`/`TabsContent`/`TabsList`/`TabsTrigger` usage from `Progress.jsx`. Replaced with direct conditional rendering: `{tab === 'all' && <div>...</div>}` / `{tab === 'course' && <div>...</div>}`. Tab buttons call `setTab()` directly.
- **Note:** `tabs.jsx` stub remains as-is (other pages may use it or not). The fix is isolated to `Progress.jsx`.
- **Status:** ✅ RESOLVED — commit `eed55c0`



### [Mar 12, 2026] Ghost Empty Flashcard Decks Accumulating
- **Symptom:** `flashcard_decks` rows with `card_count = 0` visible to professors in Contributions view; appear as empty deck entries.
- **Root Cause:** `update_deck_card_count` trigger decremented `card_count` with `GREATEST(card_count - 1, 0)` on DELETE but never deleted the deck row when count reached 0.
- **Contributing factor:** Previous bug (Excel drag-fill) created many single-card decks with wrong topic names; when those cards were fixed/deleted, decks were left orphaned at 0.
- **Fix:** Added `DELETE FROM flashcard_decks WHERE ... AND card_count = 0` after the UPDATE in the trigger's DELETE branch. Two pre-existing empty decks deleted manually.
- **Status:** ✅ RESOLVED (DB trigger fix only)

### [Mar 12, 2026] RLS Enabled on Profiles Broke Entire App (Recursive Policy Cascade)
- **Symptom:** After enabling RLS on `profiles`, `subjects`, `topics`, `content_creators`: super admin saw "Access Denied", all students' dashboards showed "new user" state, professor contributions and progress showed zeros.
- **Root Cause:** 25 policies across 13 tables all used `EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = ...)` or similar direct subqueries against `profiles`. When `profiles` itself gained RLS, these cross-table references evaluated under RLS context — the policies became recursive and errored. Cascading effects:
  - `useRole.js`: on `profileError`, defaults role to `'student'` — everyone downgraded
  - `Dashboard.jsx`: review/note/flashcard count queries error → undefined treated as 0 → "new user" state
  - `Progress.jsx`: reviews query errors → 0 progress shown
- **Fix:** Created `is_super_admin()` and `is_admin()` as `SECURITY DEFINER` functions (bypass RLS). Dropped and recreated all 25 affected policies using these functions instead of inline subqueries. Added INSERT policy on profiles for new signups.
- **Status:** ✅ RESOLVED (DB-only fix)

### [Mar 11, 2026] Bulk Upload Silently Created Custom Topics (Excel Drag-Fill Artefacts)
- **Reported by:** Professor (bulk upload of Companies Act flashcards; Excel auto-incremented "The Companies Act, 2013" to 2014–2033 across rows)
- **Symptom:** 20 variations of the topic name ("The Companies Act, 2014" … "2033") stored as `custom_topic`, bypassing the intended validation that bulk upload cannot create new topics.
- **Root Cause:** `uploadFlashcards()` used `custom_topic: card.topic` as a fallback when a topic name wasn't found in the DB, instead of aborting with an error.
- **Data Fix:** SQL `UPDATE flashcards SET topic_id = <correct_id>, custom_topic = NULL WHERE custom_topic LIKE 'The Companies Act, 20%' AND custom_topic != 'The Companies Act, 2013'`
- **Code Fix:** Added a pre-insert validation loop that collects errors for every row with an unrecognised subject or topic, then aborts the upload and shows per-row error messages. `custom_subject` and `custom_topic` are now always `null` in bulk inserts.
- **Status:** ✅ RESOLVED

### [Mar 6, 2026] Blank Study Screen for Student-Created Decks with No Topic
- **Reported by:** CA Foundation student (Shriya Sundaram), Safari on iPhone
- **Symptom:** Self-created flashcard deck visible in Review Flashcards browse page, but clicking it shows "No flashcards to study / No flashcards found for this selection". Cards accessible from My Contributions page.
- **Affected users:** All students who created flashcards without selecting a topic (systemic, not user-specific).
- **Root Cause (confirmed by DB query):** Topic is optional in `FlashcardCreate`. When skipped, both the `flashcard_decks` and `flashcards` rows get `topic_id = null`, `custom_topic = null`. The `get_browsable_decks` RPC returns `"General"` as a fallback `topic_name` for null-topic decks. `ReviewFlashcards.startStudySession` puts this label into the URL as `?topic=General`. `StudyMode` then filters ALL cards (including 78 professor cards) for `topics.name = "General"` OR `custom_topic = "General"` — matching nothing. Result: 0 cards for every user clicking such a deck.
- **Why CA Intermediate student unaffected:** All his cards have `topic_id` properly set via FK. Topic string matching succeeds. He also has one latent null-topic deck (`cca04e35`, 2 cards) that would exhibit the same bug if clicked.
- **Solution:**
  1. Topic made mandatory in `FlashcardCreate` (validation + label)
  2. Individual deck clicks now navigate with `?deck=<uuid>` instead of `?topic=<name>`; `StudyMode` filters by `card.deck_id` when `deck` param present
  3. Null-topic nudge banner in `MyFlashcards` + `handleSaveGroupInfo` now updates `flashcard_decks` record
  4. Topic made required in `MyFlashcards` Edit Info dialog
- **Status:** ✅ RESOLVED

### [Mar 6, 2026] RPC Returns 0 Results — Ambiguous Column "id" (Error 42702)
- **Files:** `get_browsable_decks` v3, `get_browsable_notes` v3
- **Symptom:** After deploying the course-aware v3 RPCs, Review Flashcards and Browse Notes showed 0 results for all students despite correct data in the DB. Browser console showed HTTP 400 with `kode: "42702"`, `message: "column reference \"id\" is ambiguous"`, `details: "It could refer to either a PL/pgSQL variable or a table column."`
- **Root Cause:** Both functions are declared as `RETURNS TABLE(id UUID, ...)`. PostgreSQL treats output column names as PL/pgSQL variables inside the function body. The profile lookup query `WHERE id = v_user_id` was ambiguous — PostgreSQL couldn't determine whether `id` referred to the `RETURNS TABLE` output variable or the `profiles.id` column.
- **Why it wasn't caught at compile time:** `CREATE OR REPLACE FUNCTION` succeeded without error; PostgreSQL only raises 42702 at runtime when the ambiguous column reference is evaluated.
- **Solution:** Qualify the column with the table name: `WHERE profiles.id = v_user_id` in both v3 functions.
- **Lesson:** In PL/pgSQL functions using `RETURNS TABLE(id ...)`, always qualify any SQL column named `id` with its table alias/name to avoid runtime ambiguity.
- **Status:** ✅ RESOLVED



### [Mar 5, 2026] Duplicate Friend Request/Accepted Notifications
- **Location:** DB — triggers on `friendships` table
- **Symptom:** Every friend request and acceptance generated two notification entries in the bell icon — one with no title (e.g. just "Aayodh Inamke sent you a friend request") and one with a proper title ("New Friend Request" / message). Affected all users.
- **Root Cause:** Two undocumented DB triggers (`trg_notify_friend_request` on INSERT, `trg_notify_friend_accepted` on UPDATE) called `create_notification()` directly at the DB level, creating a null-title notification row ~1 second before the frontend's `notifyFriendEvent()` Edge Function call created the proper titled row. Both pathways active simultaneously.
- **Why triggers didn't show initially:** First diagnostic query filtered `WHERE event_object_table = 'friendships'` but missed them; the broader `trigger_schema = 'public'` query revealed them.
- **Solution:** Dropped both triggers (`DROP TRIGGER IF EXISTS trg_notify_friend_request ON friendships` and `trg_notify_friend_accepted ON friendships`). Deleted all existing null-title duplicate rows (`DELETE FROM notifications WHERE type IN ('friend_request','friend_accepted') AND title IS NULL`). Edge Function remains sole notification path.
- **Status:** ✅ RESOLVED (DB-only fix, no code changes)

### [Mar 5, 2026] Student Cannot Filter to Study Only Own Cards
- **File:** `ReviewFlashcards.jsx`
- **Symptom:** A student with only private flashcard decks could not see their own name in the Author dropdown. Even switching the Role filter to "Student" did not surface them. Students had no way to study exclusively their own cards without professor cards mixing in.
- **Root Cause:** `get_filtered_authors_for_flashcards()` RPC inner-joins `flashcard_decks fd` and filters `fd.visibility = 'public'`. Authors with only private (`is_public = false`) decks are excluded from the result set entirely.
- **Solution:** Added a hardcoded "My Cards (Private & Public)" `SelectItem` pinned at the top of the Author dropdown with `value={user.id}`. No DB changes needed — StudyMode already fetches the current user's private cards via the visibility OR clause (`user_id.eq.${user.id}`) and applies `card.user_id === authorParam` correctly for any UUID.
- **Status:** ✅ RESOLVED

### [Mar 5, 2026] StudyMode Mixes Cards from All Authors + Ignores Review History
- **Files:** `ReviewFlashcards.jsx`, `StudyMode.jsx`
- **Symptom (Bug 1):** When a student filtered by a specific professor in ReviewFlashcards and clicked "Study All", the session showed all visible cards for the subject — including the student's own cards — not just the professor's. Studying a professor's deck of ~30 cards would show 50+ cards.
- **Root Cause (Bug 1):** `startStudySession()` built the URL with only `subject` and `topic` params; `filterAuthor` was never forwarded. `StudyMode.fetchFlashcards` had no author filter.
- **Solution (Bug 1):** `startStudySession()` now appends `author=<userId>` when `filterAuthor !== 'all'`. `StudyMode` reads this param and filters `card.user_id === authorParam` after the visibility fetch.
- **Symptom (Bug 2):** Exiting a session partway through and returning would reload all cards from scratch (including those already reviewed that session). No way to "continue from where you left off".
- **Root Cause (Bug 2):** `fetchFlashcards` had no awareness of the user's `reviews` table — every session was stateless and returned the full matching card set.
- **Solution (Bug 2):** Added a second query fetching `reviews` for the candidate card IDs. Cards are excluded if `status = 'suspended'`, `next_review_date > today`, or `skip_until > today`. Cards with no review record (first-time/new) are always included — no cold-start problem. Equivalent to LEFT JOIN WHERE r.id IS NULL OR next_review_date <= today.
- **Status:** ✅ RESOLVED

### [Mar 4, 2026] Subject Dropdown Not Filtered by Course in Study Section
- **Files:** `ReviewFlashcards.jsx`, `BrowseNotes.jsx`
- **Symptom:** Selecting "CA Foundation" in the Course filter still showed subjects from all courses (e.g., CA Intermediate subjects) in the Subject dropdown.
- **Root Cause:** `availableSubjects` was built from all decks/notes at initial load and never recomputed when `filterCourse` changed. Topic dropdown cascaded correctly from Subject, but Course→Subject cascade was never implemented.
- **Solution:** Added `allSubjectsFrom*` state storing `{name, course}` pairs. New `useEffect` (mirroring the existing topic cascade pattern) filters `availableSubjects` when `filterCourse` changes and auto-resets `filterSubject` if it's no longer valid (which then cascades to reset topics).
- **Status:** ✅ RESOLVED

### [Mar 2, 2026] CA Foundation Flashcards Invisible in Study Page and Author Profile
- **Files:** DB only (`update_deck_card_count` trigger function)
- **Symptom:** CA Foundation flashcards visible in My Contributions (flashcard count) but absent from Study Page course filter, deck list, and Author Profile flashcard counts/links. Notes for CA Foundation were unaffected.
- **Root Cause:** `update_deck_card_count()` trigger only ran `UPDATE flashcard_decks SET card_count = card_count + 1 WHERE ...`. When flashcards were bulk-uploaded and no matching `flashcard_decks` row existed, the UPDATE matched 0 rows and silently did nothing — no deck row was ever created. Both `get_browsable_decks` RPC (Study Page) and `get_author_content_summary` RPC (Author Profile) query `flashcard_decks`, not the `flashcards` table directly. My Contributions used a direct `COUNT(*) FROM flashcards` query, which is why the count was visible there but nowhere else.
- **Why notes were unaffected:** Notes don't use a separate aggregation table — they are queried directly from `notes` table in all contexts.
- **Solution:** Changed trigger function to UPDATE-then-INSERT: attempts `UPDATE card_count + 1`; if `NOT FOUND` (no deck row yet), inserts a new `flashcard_decks` row with `card_count = 1`, `target_course`, and `visibility` from the new flashcard row. One-time backfill ran to create missing deck entries for already-uploaded CA Foundation flashcards.
- **Prevention:** The trigger now self-heals for all future courses and all insertion paths (single card, bulk upload, professor tools). No manual SQL needed for new courses.
- **Status:** ✅ RESOLVED

### [Feb 20, 2026] Activity Feed "View" Button — Invalid UUID Error
- **Files:** `ActivityFeed.jsx`
- **Issue:** Clicking "View" on any note in the Dashboard Recent Activity section showed "Page Not Found" with Supabase error "invalid input syntax for type uuid: 'undefined'"
- **Root Cause:** `ActivityFeed.jsx` accessed `activity.content_id` for both the React key and the navigate call, but the `get_recent_activity_feed` RPC returns the note/deck UUID as `id` (consistent with all other RPCs in the codebase). `activity.content_id` was always `undefined`, so the URL became `/dashboard/notes/undefined`.
- **Solution:** Changed `activity.content_id` → `activity.id` in two places: the `handleActivityClick` navigate call and the `key` prop on the activity row.
- **Status:** ✅ RESOLVED

### [Feb 24, 2026] card_count Double-Counting in flashcard_decks — FULLY RESOLVED
- **Files:** `FlashcardCreate.jsx`, `flashcard_decks` table, `flashcards` table
- **Issue:** Study mode showed ~2x actual card count (e.g., 46 shown when 23 created). Recurred after initial fix attempt.
- **True Root Cause:** `trigger_update_deck_card_count` (existing DB trigger) was already correctly maintaining `card_count`. The frontend was ALSO manually incrementing it — double-counting on every save.
- **Feb 12 mis-fix:** Removed frontend increment (correct) but added a second trigger `flashcards_count_trigger` (wrong) — replaced app+trigger with trigger+trigger. Issue recurred identically.
- **Feb 24 final fix:**
  1. Dropped `flashcards_count_trigger` (the duplicate added Feb 12)
  2. SQL recalculated all `card_count` values from actual `flashcards` rows
  3. `trigger_update_deck_card_count` remains as sole source of truth
- **Frontend:** No `card_count` logic in `FlashcardCreate.jsx`. New decks insert with `card_count: 0`.
- **Prevention rule:** Before adding any DB trigger, always run: `SELECT trigger_name FROM information_schema.triggers WHERE event_object_table = '<table>';`
- **Status:** ✅ RESOLVED (final)

### [Feb 9, 2026] Flashcard Deck Names Missing in Share Content Dialog
- **Files:** GroupDetail.jsx
- **Issue:** Share Content dialog showed "Flashcard Deck" for every deck instead of actual subject/topic names, making it impossible to identify which deck to share
- **Root Cause:** `fetchUserContent()` query selected `custom_subject, custom_topic` but NOT `subject_id, topic_id`. The subject name lookup used `d.subject_id` which was always `undefined` (never fetched). Topic names were never looked up at all.
- **Solution:** Added `subject_id, topic_id` to the select query. Added topic name lookup from `topics` table. Created `display_topic` field. Updated display to show "Subject - Topic".
- **Status:** ✅ RESOLVED

### [Feb 6, 2026] Groups Link Not Working on Production Vercel — Duplicate HTML in index.html
- **Files:** index.html
- **Issue:** Groups navigation link worked on localhost but refreshed to Dashboard on production Vercel. Hard refresh and browser restart did not help.
- **Root Cause:** `index.html` had duplicate HTML structure — lines 24-29 were a copy of lines 18-23 (`</head>`, `<body>`, `<div id="root">`, `<script>`, `</body>`, `</html>`). This created two `<div id="root">` elements in the DOM. Vite's dev server was forgiving, but the production build copied the malformed HTML into `dist/index.html`, confusing React Router's client-side navigation.
- **Solution:** Removed duplicate lines 24-29 from `index.html`. Rebuilt to verify clean `dist/index.html`.
- **Status:** ✅ RESOLVED

### [Feb 6, 2026] Blank Page — NavDesktop/NavMobile Missing Props
- **Files:** NavDesktop.jsx, NavMobile.jsx
- **Issue:** App rendered blank white page after adding notification props to ActivityDropdown
- **Root Cause:** `deleteNotification` and `refetchNotifications` were passed from Navigation.jsx but never destructured in NavDesktop/NavMobile prop definitions
- **Console Error:** `Uncaught ReferenceError: deleteNotification is not defined at NavDesktop (NavDesktop.jsx:203:11)`
- **Solution:** Added `deleteNotification` and `refetchNotifications` to prop destructuring in both components
- **Status:** ✅ RESOLVED

### [Feb 6, 2026] Notifications RPC Fails — `column n.title does not exist`
- **Files:** SQL 14 (notification RPCs), SQL 25 (fix)
- **Issue:** `get_recent_notifications` RPC returned 400 error
- **Root Cause:** `notifications` table pre-existed from Phase 1B with different schema (no `title`, `metadata`, `is_read` columns). `CREATE TABLE IF NOT EXISTS` in SQL #13 skipped creation.
- **Solution:** SQL #25 — `ALTER TABLE` to add missing columns + backfill title from message
- **Status:** ✅ RESOLVED

### [Feb 6, 2026] Ambiguous `group_id` in `get_pending_group_invites`
- **Files:** SQL 19, SQL 25 (fix)
- **Issue:** MyGroups page error: `column reference "group_id" is ambiguous`
- **Root Cause:** Subquery `WHERE group_id = sg.id` conflicted with `RETURNS TABLE` which also declares `group_id`
- **Solution:** Aliased subquery table as `sub`: `WHERE sub.group_id = sg.id`
- **Status:** ✅ RESOLVED

### [Feb 6, 2026] Invitation Fails — `notifications_type_check` Constraint Violation
- **Files:** SQL 26 (fix)
- **Issue:** `invite_to_group()` failed with `new row for relation "notifications" violates check constraint "notifications_type_check"`
- **Root Cause:** Existing CHECK constraint on `type` column only allowed original types, not `group_invite`
- **Solution:** SQL #26 — DROP and recreate constraint with `group_invite` added
- **Status:** ✅ RESOLVED

### [Feb 6, 2026] React Key Warning — Pending Invitations in GroupDetail
- **Files:** GroupDetail.jsx
- **Issue:** Console warning: `Each child in a list should have a unique "key" prop`
- **Root Cause:** JSX used `invite.id` but SQL returns `invite.membership_id` as the field name
- **Solution:** Changed `key={invite.id}` → `key={invite.membership_id}` (and matching cancel/disable refs)
- **Status:** ✅ RESOLVED

### [Feb 5, 2026] Back Button Navigates to Dashboard Instead of Previous Page
- **Files:** NoteDetail.jsx, ReviewBySubject.jsx, ReviewSession.jsx
- **Issue:** Back button always went to `/dashboard` even when user came from another page (e.g., Browse Notes)
- **Root Cause:** Hardcoded `navigate('/dashboard')` instead of browser history navigation
- **Solution:** Changed to `navigate(-1)` with fallback: `if (window.history.length > 1) { navigate(-1) } else { navigate('/dashboard') }`
- **Status:** ✅ RESOLVED

### [Feb 5, 2026] Subject and Topic Filters Are Independent
- **Files:** MyNotes.jsx, MyFlashcards.jsx, BrowseNotes.jsx, ReviewFlashcards.jsx
- **Issue:** Selecting a Subject did not filter the Topic dropdown - users could select topics unrelated to subject
- **Root Cause:** Topic dropdown was populated with all available topics regardless of subject selection
- **Solution:** Added useEffect that filters `availableTopics` based on `filterSubject` selection, resets topic if not in filtered list
- **Status:** ✅ RESOLVED

### [Feb 3, 2026] Cursor Jumping in Inline Flashcard Editing
- **File:** MyFlashcards.jsx
- **Issue:** Cursor would jump to beginning of textarea on every keystroke during inline editing
- **Root Cause:** FlashcardCard component was defined inside MyFlashcards, causing re-creation on every render
- **Solution:** Extracted FlashcardCard to separate file with props and useCallback handlers
- **Status:** ✅ RESOLVED

### [Feb 3, 2026] Cannot Replace Uploaded Image/PDF in Note Edit
- **File:** NoteEdit.jsx
- **Issue:** Once an image/PDF was uploaded to a note, there was no way to replace it
- **Solution:** Added file replacement feature with preview, validation, upload, and old file deletion
- **Status:** ✅ RESOLVED

---
