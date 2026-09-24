# My Cards Enrollment — Phase 0 Diagnostic (Sprint 8.7.8a)

**Status:** DIAGNOSTIC ONLY — no SQL, no frontend, nothing built. This document is the design-of-record input to the 8.7.8b (schema+RPC) prompt, which is gated on Anand's approval of the findings below.
**Author:** Claude Code
**Date:** 22/09/2026
**Method:** Every claim below was checked against the live SQL migration files in `docs/database/**` (the last-known-deployed function bodies, in strict deploy order per file) and the live frontend source in `src/**`. No live Supabase introspection tool was available in this session — where a claim could only be confirmed by querying the running database directly, it is flagged as **NOT LIVE-VERIFIED** rather than presented as fact. `docs/active/context.md` is known-stale (predates the SRS ladder, `review_events`, the current role/visibility model) and was not relied on; `docs/active/blueprint.md` (§1.1/§1.4/§3.1) and the raw `docs/database/**` SQL were the primary sources.
**Modeled on:** `docs/active/design-review/srs-ladder-proposal.md`'s structure (measured findings → recommendation → open questions → next-phase scope).

---

## 1. Purpose and product model

RevisOp is moving from "all visible content behaves like your own SRS deck" to a three-stage model:

```
Authoritative / external library → Practice / Explore → Add selected items to My Cards → Existing SRS
```

- **Own content** (`flashcards.user_id = viewer`) keeps behaving exactly as today: visible in My Study Sets, auto-enters the SRS ladder on first grade.
- **Not-own content** (official-body, professor, or another student's public/friends/group-visible cards) becomes browse/practice-only by default — inspectable and attemptable, but never silently added to the viewer's SRS workload.
- A student who wants a not-own card in their queue explicitly **adds it to My Cards** — a durable, separate decision from viewing or practising it.
- The existing graded SRS ladder engine (`apply_review`, `srs_ladder_curves`, `srs_ladder_rules`, `get_study_queue`) is **frozen** — this epic adds an enrollment layer in front of it, it does not touch its internals.

---

## 2. Confirmed Phase 0 findings — the core problem, proven from live code

**Finding: today, viewing → grading ANY visible card silently enrolls it — this is the bug the epic exists to fix, and it is worse than "no distinction exists," it actively already happens.**

`StudyMode.jsx`'s standalone-mode `fetchFlashcards()` (`src/pages/dashboard/Study/StudyMode.jsx:304-312`) queries:

```js
supabase.from('flashcards').select(...)
  .or(`visibility.eq.public,user_id.eq.${user.id},visibility.eq.friends`)
```

— i.e. **every card the viewer may see**, not just their own. It then unions this with the due set from `get_study_queue` (also visibility-agnostic — own/public/friends, §2.1 below) and treats anything with no `reviews` row as "new" (`StudyMode.jsx:403-411`). Grading a never-reviewed card — own or not — calls `apply_review`'s brand-new-card branch (`docs/database/sprint7.4/02_FUNCTIONS_apply_review.sql:114-134`), which does a bare `INSERT INTO reviews`. There is no separate "enrollment" step today: **the first grade on ANY visible card, regardless of ownership, IS the enrollment event.** This confirms the product problem statement (auto-enrolling ICAI's exhaustive corpus créates unsustainable daily volume) is not hypothetical — it is exactly what the current code does for every visible card a student ever taps "Show Answer" → grade on.

This also means the enrollment marker being introduced is not adding a step in front of a gate that exists — it is inserting a gate that does not exist today. Every current "Study All" / deck-click / subject-click entry into `StudyMode` (standalone mode) needs to become scoped to **My Cards** (own + enrolled), while `ReviewFlashcards.jsx` ("Browse Study Sets", already visibility-agnostic today) becomes the Practice/Explore surface. `ReviewSession.jsx` (the due-queue "Review Session" entry point, via `get_study_queue`) is unaffected by this split **once graded** — see §2.1.

### 2.1 `get_study_queue` is already visibility-agnostic, and that is fine post-launch

`get_study_queue` (`docs/database/sprint6/01_FUNCTIONS_get_study_queue.sql`) returns due cards for `(user_id, flashcard_id)` pairs that already have an **active** `reviews` row, re-applying the same visibility predicate (own / public / friends+accepted) as a defensive re-check, not as an inclusion gate — the row only exists because something already graded it once. Once an external card has a genuine `reviews` row (because the student added it to My Cards and then graded it), it needs **zero new logic** to surface correctly in `get_study_queue` / `ReviewSession.jsx` / Dashboard's `reviewsDue` — this path is already correct and stays frozen. The problem is entirely upstream: which cards are allowed to acquire that first `reviews` row in the first place, and through which UI surface.

### 2.2 Visibility/entitlement predicate — the one true source

The **same five-clause OR** appears, independently re-implemented, in `get_study_queue`, `get_browsable_decks` (v8, `docs/database/sprint8.7.7/11_...sql:109-125` and again at `:146-162` for the type-filter EXISTS, and again at `:167-189` for the deck-level gate), `get_question_type_performance`, `get_subject_mastery_v1`, and StudyMode's own client-side `.or()`:

```
owner (user_id = viewer)
OR visibility = 'public'
OR (visibility = 'friends' AND accepted friendship exists)
OR viewer role IN ('admin','super_admin')          -- decks/cards only, not every RPC
OR content shared to a study_group the viewer is an active member of   -- decks only
```

Plus, separately, a **course gate** on `flashcard_decks` (professor/admin bypass; students see own course + own content) in `get_browsable_decks` only — not in `get_study_queue`, which instead does its own null-safe course match. **This predicate, wherever it currently lives, is the one every future My Cards / enrolled-external-card query must re-apply** (§5). It is not centralized in one function today — it is copy-pasted per RPC — which is a real risk for 8.7.8b: a new enrollment-aware query that reimplements it again is one more copy to keep in sync, not a new problem, but worth flagging.

---

## 3. Enrollment storage recommendation

### A. Enrollment-marker semantics and lifecycle

**Confirmed: the durable key is `(user_id, flashcard_id)`, and exactly one row per pair is correct and sufficient** — this mirrors the existing `reviews` table's own `UNIQUE(user_id, flashcard_id)` pattern exactly (`docs/active/blueprint.md:232`), which is the established precedent in this schema for "one durable fact per student per card."

**Minimum necessary columns** — deliberately not more:

| column | type | why it's needed |
|---|---|---|
| `id` | uuid PK | standard, no functional need beyond convention |
| `user_id` | uuid FK→profiles/auth.users, cascade | who |
| `flashcard_id` | uuid FK→flashcards | what |
| `added_at` | timestamptz default now() | when — also usable as `mastered_at`/`suspended_at` are used elsewhere: last-meaningful-transition timestamp |
| `status` | text, `'active'`/`'removed'` | **needed, not speculative** — see the Remove/Re-add analysis in §7. A hard DELETE-on-remove loses the "was this suspended for Pause or for Remove" distinction that §7's Pause/Remove coupling requires answering. A soft-delete status column, mirroring `reviews.status`'s own precedent, is the smallest fix. (Alternative considered: hard-delete-and-reinsert on re-add, discussed and rejected in §7 — it cannot represent the distinction the product spec explicitly asks for.) |

**Rejected as premature:** a `source` column (how the card was discovered — browse vs. recommended vs. group). Nothing in the confirmed scope reads or displays this. `enrolled_by`/notes/reason fields — same, no confirmed consumer. Add only when a concrete feature needs them (YAGNI, matches this project's own stated standard).

**Should the table technically permit own cards too?**
**Recommendation: the smallest invariant is to allow it technically (no CHECK forbidding `flashcards.user_id = enrollment.user_id`), but the product flow never writes one** — own content auto-enrolls via the existing first-grade path and never routes through the "Add to My Cards" button (which only ever appears on not-own content in Practice Mode, per the confirmed scope). Adding a DB-level CHECK to forbid it would be extra invariant-enforcement machinery for a case the UI already never produces — not worth it. This mirrors the project's general pattern of RLS predicates and RPC gating being the actual enforcement layer, not exotic CHECK constraints.

**Deletion of the source flashcard:**
Every existing per-user, per-card table in this schema (`reviews.flashcard_id`, `review_events.flashcard_id`) is declared `ON DELETE CASCADE` (`docs/active/blueprint.md:221, 243`). The new enrollment table should follow the identical established pattern: `flashcard_id uuid REFERENCES flashcards(id) ON DELETE CASCADE`. This is the only pattern that exists anywhere in this schema for "per-user record of a flashcard" — no alternative (e.g. soft-null-out) is used anywhere else, so introducing one here would be inconsistent for no stated benefit. If a professor deletes a card that's both enrolled AND has review history, the CASCADE removes the enrollment row and the `reviews`/`review_events` rows the same way it already does today for any deleted card that had review history — **no new behavior, existing cascade already covers this** (confirmed by the schema declaration; not independently re-tested live in this diagnostic).

**"No `reviews` row = not selected/not owned/not in My Cards" — assumptions that become false, enumerated:**

Grep of every current use of "does a `reviews` row exist" as an implicit ownership/selection signal:

1. `StudyMode.jsx:403-411` — "never-reviewed → treat as new, eligible to grade" fallback. **Becomes wrong**: a not-own, not-enrolled card must NOT hit this fallback once My Cards scoping ships (today it already incorrectly does, per §2 — this is the exact bug being fixed, not a new one being introduced).
2. `get_suspended_cards()` / `get_mastered_cards()` (`docs/database/security/08_...sql`, `docs/database/srs-ladder/06_...sql`) — both list "cards with a `reviews` row in status X." Once enrolled-but-never-graded cards exist, these lists correctly continue to show nothing for them (they have no `reviews` row yet) — **not broken**, just incomplete by construction; a future "enrolled but not yet started" list is a separate, additive surface (§10), not a fix to these two.
3. `Progress.jsx`'s `get_question_type_performance`/`get_subject_mastery_v1` "available cards" CTEs (`docs/database/security/02b_...sql:44-49, 106-111`) already define "available" as the full visibility predicate (own/public), independent of `reviews` — these are already correctly scoped to "everything visible," not "everything owned," so enrollment does not change their meaning, only what fraction of that "available" set has been graded.
4. `MyFlashcards.jsx` ("My Study Sets") — filters strictly `user_id = auth.uid()` (`:138`), **never** used `reviews` as a proxy for selection. Confirms this page needs an explicit code change to union in enrolled external cards (§6 inventory) — it does not silently break, it is simply incomplete for the new model until updated.

No hidden assumption was found that would silently corrupt data; the risk is entirely "surfaces that used to show the complete picture (because ownership and SRS-participation were the same axis) now need to explicitly union in the enrollment axis," enumerated fully in §6.

---

## 4. Practice-attempt log

**Re-confirmed (this diagnostic, not just inherited from memory):**
- `grep -r "question_attempts"` across `src/**` and `docs/database/**` returns nothing — no such table or concept exists in this codebase.
- `review_events` (`docs/active/blueprint.md:236-258`, live body in `docs/database/sprint7.4/02_FUNCTIONS_apply_review.sql:172-178`) has **required, ladder-derived columns that only make sense as an SRS-transition side effect**: `rung_before`/`rung_after` (nullable NULL only for "was new," never "no ladder involved"), `status_after` (NOT NULL, values `active`/`suspended`/`mastered` — an SRS state, not applicable to a non-enrolling attempt), `interval_days`/`next_review_date` (both computed by the ladder transition math, meaningless for a practice attempt that never touches `reviews`). Writing a practice attempt into `review_events` would mean inventing sentinel values for all four (e.g. `rung_before=NULL, rung_after=NULL, status_after=???`) — there is no valid `status_after` for "this was never on the ladder," and RETURNS/callers downstream (`get_study_heatmap`, `get_user_streak` via `reviews.created_at` — not `review_events`, but the *intent* of the table is SRS history) would need new NULL-handling everywhere they read it. This is real structural unsuitability, not a naming quibble — confirms the memory's prior conclusion.

**Proposed minimum practice-attempt-log schema** (exactly the epic's stated starting point — nothing added):

| column | type | notes |
|---|---|---|
| `id` | bigint identity or uuid PK | |
| `user_id` | uuid FK→auth.users (match `reviews`/`review_events`'s own referent, not `profiles`) | |
| `flashcard_id` | uuid FK→flashcards ON DELETE CASCADE | |
| `attempted_at` | timestamptz default now() | |
| `is_correct` | boolean, nullable | |

**`is_correct` populate-ability per live question type** (checked against `StudyMode.jsx`'s actual grading branches, not assumed from the type name):

| question_type | deterministic verdict today? | practice `is_correct` |
|---|---|---|
| `flashcard` | No — self-graded only (`handleRating(quality)`, no `isCorrect` arg) | always NULL |
| `theory` | No — same self-graded flashcard path | always NULL |
| `concept_card` | N/A — never graded, never enters a study/practice loop at all (D-06) | never logged |
| `mcq` | Yes — `handleMcqSelect` computes `optIndex === correct_answer` | true/false |
| `mcq_multi` | Yes — exact-set comparison in `handleMcqMultiSubmit` | true/false |
| `case_study_mcq` | Yes — same mcq branch (`GRADED_QUESTION_TYPES`) | true/false |
| `match_the_following` | Yes — all-or-nothing in `handleMatchSubmit` | true/false |
| `fitb` | **Confidence-gated, not binary (D-13)** — `isFitbMatch` returns matched/not-matched, but a non-match is explicitly "unanticipated phrasing," never asserted wrong (`StudyMode.jsx:590-596`) | `true` on match, **NULL** on no-match (never `false` — same rule as the live grading path, D-13 must carry over unchanged) |

This exactly matches the epic's own expectation ("for theory/free-recall content it may legitimately be NULL") and additionally surfaces that `fitb` is a **third** state, not binary — worth stating explicitly for 8.7.8b's RPC signature rather than assuming a plain boolean.

**Hard/Medium/Easy in Practice Mode — recommend NOT required**, confirmed against the actual grading flows above: for graded types (mcq family, match, fitb-matched), `GradeButtonRow`'s role today is exclusively **SRS scheduling input** — `onGrade={(g) => handleRating(g.rating, true)}` — it never gates whether the objective verdict is shown; the verdict (`AnswerOption` correct/missed coloring, the WHY block) renders immediately on answer, before any Hard/Medium/Easy tap. This means **objective feedback (verdict + WHY) can be shown in Practice Mode without ever mounting `GradeButtonRow`** — Practice Mode's flow for a graded type is: answer → see verdict + WHY → log the attempt → advance, with no rating step. For free-recall types (`flashcard`/`theory`), the entire point of the flip+grade loop **is** the self-assessment — but that self-assessment is exactly the SRS-commitment signal the product spec says Practice Mode should not require. The clean answer: **Practice Mode for free-recall types is a plain flip (front → back), with an explicit "Add to My Cards" affordance instead of a grade row** — no self-rating collected at all in Practice. This is a genuine product decision, not purely a technical finding — flagged as confirmed-by-inspection but worth Anand's explicit sign-off in 8.7.8b's kickoff.

**Side-effect isolation, verified against the specific mechanisms named in the brief:**
- `reviews` / `review_events`: a practice-attempt-log INSERT touches neither table — confirmed, it is a new, unrelated table.
- `trg_badge_review`: fires `AFTER INSERT ON reviews` (per blueprint's trigger table, `docs/active/blueprint.md:687`) — a practice log INSERT never reaches it.
- `get_user_streak`: reads `reviews.created_at` directly (`docs/database/security/02b_...sql:213`) — untouched.
- `user_stats` counters (`trg_aaa_counter_*`): fire on `flashcards, notes, reviews, upvotes, friendships` INSERT/UPDATE (blueprint `:686`) — practice log and enrollment tables are neither, so these triggers never fire for either new table, by construction (they are only ever attached to the tables named).
- `user_activity_log`: written by `log_review_activity()`, called from inside `apply_review`'s callers — **NOT LIVE-VERIFIED** whether it's `apply_review` itself or a separate trigger; either way, a practice log INSERT is a different table and cannot trigger it unless a NEW trigger is explicitly added in 8.7.8b, which should not happen.

**`study_sessions` timing — mechanism, re-verified from `StudyMode.jsx:842-891`, not inherited from memory:**
The **client-side timer** starts in a `useEffect` on mount (`localStorage.setItem('revisop_session_started_at', ...)`, guarded by `!previewModeParam` — no minimum-duration gate at start) and is flushed by `logStudyModeSession()` on exit/backgrounding/unmount, which computes `durationSeconds` and **only inserts the `study_sessions` row if `durationSeconds >= 10`** (`:874` — this is the "online study has no meaningful minimum" the product rule refers to; 10 seconds is a noise floor, not a policy minimum, confirmed by the code comment at `:839` calling it exactly that). The manual/offline 600-second minimum lives elsewhere (**NOT located in this diagnostic** — not present in `StudyMode.jsx`; presumably a separate manual-logging surface not touched by this epic, out of scope to chase further here). **Practice Mode, if it reuses this same `useEffect`+`logStudyModeSession` pattern with its own `source: 'practice_mode'` value** (the column already supports a `source` string, confirmed at `:884`), inherits the 10-second noise floor automatically and correctly continues to count as real in-app study time — no new mechanism needed, only a new `source` value threaded through, exactly matching the confirmed product rule.

---

## 5. Current visibility/entitlement rule (Security diagnostic — mandatory section)

**Rule adopted (confirmed correct by inspection, not just asserted): enrollment expresses intent, not access.** A membership row must never be treated as a visibility grant. The safe pattern for any future "get my enrolled cards" query is: `JOIN` the enrollment table to `flashcards`, then **re-apply the exact §2.2 predicate** as a `WHERE`, exactly the way `get_study_queue` already re-applies it even though it's a `SECURITY DEFINER` function that bypasses RLS (`docs/database/sprint6/01_...sql:27-28` comment: *"Visibility guard (SECURITY DEFINER bypasses RLS, so we re-assert the L2 predicates)"* — this exact idiom is the one to copy for the enrolled-cards retrieval RPC in 8.7.8b).

**Answers to the four mandatory questions:**

1. **Another student's public card, added to My Cards, later goes private → should it still render?**
   **No** — the predicate re-check on every read means it naturally stops rendering the moment `visibility` flips, with **zero enrollment-specific code**. This is a direct, mechanical consequence of "enrollment ≠ access," not a policy that needs separate implementation. (If the product wants a softer "you had already started this, keep it" grace period, that is a new decision not currently in scope — not needed unless Anand asks for it.)
2. **Professor content is paid; the student's entitlement later expires — does enrollment preserve access?**
   **No payment/entitlement system exists in this codebase today** — confirmed via `docs/active/blueprint.md:1505` ("Billing/subscription system (Razorpay, ₹149/month premium) — High — monetization" is listed under *Pending Work & Roadmap*, not built) and zero hits for `entitlement`/`subscription`/`payment` logic gating content reads anywhere in `src/**` or `docs/database/**`. **This is a real, explicit gap, recorded rather than invented**: there is currently no predicate to "expire" — when a paid-content/entitlement system is eventually built, its access predicate must be added to the same §2.2 list everywhere it's re-implemented (including any new enrolled-cards RPC from 8.7.8b), and the same "enrollment ≠ access" rule applies automatically once it exists. No design work is possible on this sub-question today beyond stating the principle.
3. **A professor/source owner deletes or unpublishes content — what happens to the membership row?**
   **Deletes: CASCADE removes the enrollment row along with `reviews`/`review_events`, per §3's FK recommendation** — consistent, no dangling state. **Unpublish (visibility change, not delete):** the row is untouched (it's just a `(user_id, flashcard_id)` fact), but per the predicate re-check in every read path, it stops resolving to a visible card — functionally invisible without being deleted, matching Q1's answer. This is intentional: the *intent to study this if it ever becomes visible again* is worth preserving; the *content* is what's temporarily gone.
4. **Which existing visibility/entitlement predicate must every My Cards query continue to apply?**
   The exact §2.2 five-clause union, reproduced (not paraphrased) from `get_browsable_decks` v8 / `get_study_queue`'s current live bodies, at write time in 8.7.8b — plus the course gate where the query is deck/browse-shaped (not card-shaped, since `get_study_queue` itself does its own course check without the deck-level course gate).

**No membership-UNION visibility leak found in the current codebase** — because the enrollment table does not exist yet, there is nothing to audit for this specific bug today; this is a forward-looking constraint on 8.7.8b's RPC design, verified as achievable (the pattern to copy already exists and works, per `get_study_queue`), not a currently-present bug.

---

## 6. My Cards composition — full inventory

Every `.from('flashcards')` call site in `src/**`, classified:

| File / function | Query shape | Classification | Notes |
|---|---|---|---|
| `MyFlashcards.jsx:132-139` (main fetch, "My Study Sets") | `.eq('user_id', user.id)` | **MY CARDS MEMBERSHIP** — needs to change | Currently pure ownership. This is the page students think of as "my cards" — it must eventually union in enrolled external cards, or a new "My Cards" surface must be built and this page relabeled/kept as "My Authored Content." Product decision needed in 8.7.8d, not this diagnostic. |
| `MyFlashcards.jsx:335-340` (inline edit) | `.eq('id', cardId)` on an owned card | AUTHORING/OWNERSHIP — unchanged | Editing front/back text of an authored card. RLS already restricts this to the owner; enrollment is irrelevant. |
| `MyFlashcards.jsx:376-378`, `:414-416` (delete, bulk delete) | `.delete().eq('id', ...)` / `.in('id', ...)` | AUTHORING/OWNERSHIP — unchanged | Deleting authored content. Cascades into any enrollment rows per §3 — no code change needed here, the FK does it. |
| `StudyMode.jsx:304-312` (`fetchFlashcards`, standalone mode) | `.or('visibility.eq.public,user_id.eq.…,visibility.eq.friends')` | **MY CARDS MEMBERSHIP — the core bug**, see §2 | Must become "own ∪ enrolled," not "everything visible." This is the change that actually fixes the auto-enrollment problem. |
| `ReviewSession.jsx` via `get_study_queue` | RPC, not direct `.from()` | **SRS/REVIEW STATE — unchanged** | Already correctly scoped to cards with a `reviews` row; needs zero change (§2.1). |
| `Dashboard.jsx:323-326` (`isNewUser` check) | `.eq('user_id', authUser.id)`, count | AUTHORING/OWNERSHIP — unchanged | "Has this student ever created anything" onboarding check — correctly ownership-scoped, not a My Cards concept. |
| `Dashboard.jsx:385-389` (`fetchContentCounts`, "flashcardsCount") | `.eq('user_id', userId)`, count | AUTHORING/OWNERSHIP — unchanged, but **user-facing label risk** | This count feeds whatever UI shows "X flashcards" on the dashboard — confirm at 8.7.8d time that its label says "created" not "my cards," since it will visibly diverge from a future My Cards count once enrollment exists. Not a code bug today, a wording risk later. |
| `Dashboard.jsx:349` (`reviewsDue` via `get_study_queue`) | RPC | SRS/REVIEW STATE — unchanged | Correct today, stays correct (§2.1). |
| `Dashboard.jsx:355-358` ("today's reviews" for `GoalProgressWidget`) | `.from('reviews')...eq('user_id', userId)` | SRS/REVIEW STATE — unchanged | Reads `reviews`, not `flashcards`; unaffected by ownership vs. enrollment distinction by construction. |
| `NoteDetail.jsx:75-79` (linked flashcards) | `.eq('note_id', id)` | UNRELATED | Note↔flashcard linkage, not a study-collection concept. |
| `NoteDetail.jsx:122-125` (delete linked card) | `.delete().eq('id', cardId)` | AUTHORING/OWNERSHIP — unchanged | |
| `NoteUpload.jsx:146-149`, `NoteEdit.jsx:74-76`, `MyFlashcards.jsx:73-74`, `Signup.jsx:35-38` | `.select('target_course')`, unfiltered/broad | UNRELATED | Course-dropdown population utility queries, not a collection view. |
| `MyContributions.jsx:51-54` | `.eq('user_id', user.id)`, count | AUTHORING/OWNERSHIP — unchanged | "My Contributions" is explicitly an authorship/creator page (upvotes received, content created), distinct in intent from a study collection. |
| `AdminDashboard.jsx:180`, `:326-333`; `SuperAdminDashboard.jsx:149-150, :268, :446-448` | Various, unfiltered or admin cross-user | UNRELATED | Platform-wide admin analytics / user-management tooling, not any student's study collection. |
| `ConceptCardViewer.jsx:29-37` | `.eq('question_type','concept_card')` + visibility `.or()` | UNRELATED | Concept cards are explicitly never graded/reviewed/enrolled (D-06) — Browse-only, orthogonal to this epic entirely. |
| `get_question_type_performance` / `get_subject_mastery_v1` (`Progress.jsx` via RPC) | "available cards" = full visibility predicate, independent of ownership | UNRELATED today, becomes a design question later | These already treat "available" as visibility-scoped, not ownership-scoped — they are arguably already closer to the future My Cards semantics than `MyFlashcards.jsx` is. Not in scope to change now; flagged for 8.7.8d discussion on whether Progress's stats should report against "My Cards" or stay "everything visible." |

### StudyMode specifically — due ∪ new, traced exactly

Current logic (`StudyMode.jsx:376-412`, standalone mode only — `ReviewSession.jsx`'s embedded mode skips this entirely and only ever receives `get_study_queue`'s output as props):
1. Fetch all visibility-eligible cards (the §2 bug).
2. Fetch `get_study_queue` → build a `dueIds` Set and a `rungById` Map.
3. Chunk-fetch `reviews.flashcard_id` for every candidate card → `reviewedIds` Set.
4. Keep a card if `dueIds.has(id) OR !reviewedIds.has(id)` (i.e., due, or never-reviewed) — excluding `concept_card` always.

**How an enrolled-but-never-graded external card should enter this flow, given `get_study_queue`'s contract is frozen:** step 1 must change from "everything visible" to "own ∪ enrolled" (a new query joining `flashcards` to the enrollment table, unioned with the existing own-card query, both re-applying §2.2's predicate — or more simply, since enrollment already implies the predicate passed at add-time, re-checking it at read-time per §5's "enrollment ≠ access" rule). Steps 2–4 need **no change at all** — `get_study_queue` already only returns cards with an active `reviews` row (enrolled-and-graded ones, indistinguishably from always-own ones — see §2.1), and step 4's "never-reviewed → treat as new" fallback is exactly the correct behavior for an enrolled-but-ungraded card **once step 1 correctly excludes everything not enrolled**. **Recommended smallest additive path for 8.7.8b: a new RPC (e.g. `get_my_cards(p_user_id)`, shaped like `get_suspended_cards`/`get_mastered_cards`) returning own ∪ enrolled flashcard rows, re-applying §2.2** — `StudyMode.jsx` swaps its step-1 direct `.from('flashcards')` call for this RPC; everything downstream (steps 2-4, `get_study_queue`, `apply_review`) is untouched. This satisfies "additive RPC/query, not a change to `get_study_queue`'s frozen contract."

---

## 7. First-grade lifecycle — traced against live code, step by step

| step | mechanism | confirmed? |
|---|---|---|
| 1. External card available in Practice/Explore | `get_browsable_decks` / `ReviewFlashcards.jsx` — already visibility-agnostic today, exactly the surface Practice Mode repurposes | ✅ live-confirmed, needs no new backend query, only a new frontend entry point that doesn't call `apply_review` |
| 2. Student adds it to My Cards | **New** — 8.7.8b RPC, e.g. `add_to_my_cards(p_user_id, p_flashcard_id)`, INSERT into the new enrollment table after re-checking §2.2's predicate server-side (never trust the client's "I saw this card" claim — same IDOR-guard idiom as every other RPC here) | Not built; design only |
| 3. Membership row exists | enrollment table row, `status='active'` | design only |
| 4. No `reviews` row exists yet | Confirmed structurally true — nothing in the add-to-My-Cards path touches `reviews`/`review_events` (§4's side-effect isolation applies equally here — adding to My Cards is not a practice attempt either, it's a third, even lighter-weight action) | ✅ by construction |
| 5. Student later encounters it in normal Study Mode | Via the new `get_my_cards`-style union (§6) — needs 8.7.8b to ship, not present today | design only |
| 6. Student genuinely grades it | `handleRating` → `submitReview` → `supabase.rpc('apply_review', ...)` — **completely unchanged code path**, confirmed at `StudyMode.jsx:441-489` | ✅ live-confirmed, zero changes needed |
| 7. `apply_review` runs unchanged | Confirmed — the "brand-new card" branch (`docs/database/sprint7.4/02_FUNCTIONS_apply_review.sql:114-134`) has no ownership check of any kind today, it only checks `p_user_id = auth.uid()` (IDOR) and that the flashcard exists and isn't `concept_card`. It does not care, and after this epic still should not care, whether the caller owns the card — enrollment gating happens entirely **upstream**, at which cards are ever shown to grade, not inside `apply_review` itself. | ✅ confirmed — this is the epic's central design insight, verified true against the actual function body, not assumed |
| 8. First real `reviews` row created | Same INSERT as always | ✅ |
| 9. Membership row remains untouched | True by construction — nothing in `apply_review` touches the enrollment table (it doesn't know it exists) | ✅ |
| 10. Existing badges/streak/SRS now apply normally | `trg_badge_review` fires on the `reviews` INSERT exactly as it does for any other first-ever grade — no special-casing exists or is needed, because from `apply_review`'s perspective this was always just "a card's first grade," identical to today's own-content flow | ✅ |

**No blocking code found.** The entire lifecycle already works correctly for step 6 onward, purely because `apply_review` was never ownership-aware to begin with — the only genuinely missing piece is steps 1–2 and 5 (the enrollment record and the surfaces that read it), confirming the epic's "zero changes to `submit_review`/`apply_review`/`srs_ladder_*`/`get_study_queue`" claim as accurate, not aspirational.

---

## 8. Pause / Resume / Remove / Re-add — state table

| operation | precondition | mechanism | confirmed against |
|---|---|---|---|
| **Pause** | Membership row exists, **and** an active `reviews` row exists | `suspend_card(p_user_id, p_flashcard_id)` — unchanged, existing RPC. Membership row untouched. | `docs/database/bugfixes/17_...sql:54-71` — atomic upsert, sets `status='suspended', skip_until=NULL`. Live-confirmed it does NOT touch `rung`/`easiness`/`repetition` — only `status`. |
| **Pause, never graded** | Membership row exists, **no** `reviews` row | **No meaningful role, per the epic's own instruction not to invent one unless needed.** Confirmed: nothing to pause — the card isn't in any active schedule yet. The only sensible UI action pre-grade is Remove (below), which already fully covers "I don't want this in My Cards anymore." | Design conclusion, not a code finding — no code path currently would even let this be attempted (Pause UI, when built, should simply not offer itself for an ungraded enrolled card). |
| **Resume** | Membership row exists, `reviews.status='suspended'` | `unsuspend_card(p_user_id, p_flashcard_id)` — unchanged. | `docs/database/security/08_...sql:247-262` — `UPDATE reviews SET status='active', next_review_date=today WHERE ... status='suspended'`. **Confirmed live: only `status` and `next_review_date` are written — `rung`, `easiness`, `repetition` are left exactly as they were pre-suspend.** This directly proves the epic's expectation ("verify `unsuspend_card` preserves rung/repetition/easiness") — confirmed true by reading the actual UPDATE's column list, not inferred. |
| **Remove, never graded** | Membership row exists, no `reviews` row | Delete (or soft-delete, per §3's `status='removed'` recommendation) the membership row only. **Confirmed no other state needs to change** — nothing else references the row (§3's assumption audit found no other consumer of "does this enrollment exist" besides the membership-scoped read surfaces themselves). | Design conclusion + §3/§6 audit |
| **Remove, already graded** | Membership row exists, `reviews` row exists with `status='active'` (or `'mastered'`) | **Confirmed coupled/atomic, exactly as the epic anticipates.** Deleting only the membership row leaves the `reviews` row `status='active'`, and `get_study_queue` (`docs/database/sprint6/01_...sql:121-124`) filters purely on `r.status='active' AND r.next_review_date <= today` — it has and needs **zero awareness of the enrollment table** (frozen contract). A removed-but-still-active `reviews` row would keep surfacing as due forever. **The only correct implementation is a single RPC that, in one transaction, (a) soft-removes the membership row and (b) calls the same `suspend_card` logic** (or its body inlined) to stop the card surfacing. **Must NOT use `reset_card`** — confirmed destructive: `docs/database/security/02b_...sql:15-30` shows `reset_card` is a hard `DELETE FROM reviews` — this permanently discards `rung`/`easiness`/`repetition`/history, which directly contradicts "preserve history for re-add" below. |
| **Re-add, previously graded** | A `status='removed'` membership row exists; its paired `reviews` row was suspended by the coupled Remove above | Recreate/reactivate the membership row (`status='active'`), then call `unsuspend_card` — **not** `reset_card` — so rung/easiness/repetition/history survive exactly as the Resume case does. | Same evidence as Resume above |
| **Re-add, never graded before removal** | A `status='removed'` membership row exists; no `reviews` row was ever created | Recreate/reactivate the membership row. No `reviews` action needed — re-enters exactly like a fresh enrollment (§7 step 3-5). | Design conclusion |

**The Pause-vs-Remove-suspension distinguishability gap — resolved by the §3 schema, not left open:**
The epic explicitly asks whether `reviews.status='suspended'` alone can distinguish "user-initiated Pause" from "system-initiated stop-surfacing-because-Removed," and says to record it as a requirement if it can't. **It cannot — `reviews.status` has no third value for this, and adding one would mean teaching `get_study_queue` and every other `status`-aware reader about a new value, which is explicitly against the "no changes to the frozen SRS engine" guardrail.** The correct fix, already implicit in §3's schema recommendation, is that **the distinction lives entirely on the enrollment table's own `status` column**, not on `reviews.status`: a `reviews.status='suspended'` row is ambiguous in isolation, but is *never read in isolation* — every UI/RPC path that would show "why is this suspended" (Pause-list vs. a Removed card) joins through the enrollment row and reads **its** status first. This requires **zero new column on `reviews`**, confirming the "no ladder engine changes" guardrail holds, and should be stated explicitly to 8.7.8b as a **hard design requirement**: any Pause/Remove UI must always resolve state via the enrollment row, never by reading `reviews.status='suspended'` alone and guessing which of the two it means.

**Known separate, pre-existing issue — recorded, not fixed here (per the epic's own instruction):**
`skip_card`/`suspend_card` already INSERT a bare `reviews` row (quality=0, easiness=2.5, rung unset) for a **never-reviewed** card today (`docs/database/bugfixes/17_...sql:47-50, :66-69`), which — per §2's finding — fires `trg_badge_review`/counts toward `get_user_streak` even though no real grade ever happened. This is a **pre-existing bug independent of this epic**, confirmed to already exist today for any card (own or not), not introduced or worsened by My Cards/enrollment. Logged here per the diagnostic's instruction to record it, not to fix it in 8.7.8a/b.

---

## 9. Component-reuse inventory (Practice Mode renderer)

**Correction to the epic's framing:** the diagnostic asks to inventory "component(s) used" per question type as if each type has its own mountable renderer component. **It does not** — `StudyMode.jsx` is a single ~1870-line component with **inline JSX branches per `question_type`**, all sharing one `currentCard`/`currentIndex` state machine. The actual reusable units are the **leaf components** imported at the top (`Card`, `GradeButtonRow`, `VerifiedEdge`, `AnswerOption`, `MatchZone` from `@/components/revisop`), each already driven by a plain callback prop (`onClick`, `onGrade`), confirmed in the JSX read above. This is good news for reuse (the leaf components are already decoupled from SRS submission — see below) but means "Practice Mode reuses the renderer" in practice means **either** (a) a new `PracticeMode.jsx` component that duplicates the same per-type inline branches wired to a different set of callbacks, or (b) extracting each branch into its own small component first (front-loading refactor work this diagnostic was told not to do). **Recommendation for 8.7.8c: option (a)** — duplicate the branch structure into a new component, since the branches are already fairly self-contained JSX blocks with no deep StudyMode-only state dependencies beyond the per-card interaction state already itemized at the top of the file (`mcqSelectedIndex`, `matchPairs`, `fitbAnswer`, etc. — all of which a `PracticeMode.jsx` would need its own copies of regardless of approach).

| type | leaf component(s) | mountable in Practice? | current SRS-submit callback | practice callback needed | reveal/correctness coupled to `apply_review`? | hidden-state risk |
|---|---|---|---|---|---|---|
| `flashcard` / `theory` | none (plain text blocks) + `GradeButtonRow` | Yes, but **per §4's recommendation, Practice Mode should not mount `GradeButtonRow` here at all** — just front→back flip, then "Add to My Cards" | `onGrade={(g) => handleRating(g.rating)}` | none — no grade collected in Practice | No — `showAnswer` is pure local state, reveal is free | None found |
| `mcq` | `AnswerOption` × N + `GradeButtonRow` (only after a correct tap) | Yes | `handleMcqSelect` → `submitReview('hard', false)` immediately on wrong tap; `GradeButtonRow.onGrade` on correct tap | new: log practice attempt with `is_correct`, no `apply_review` call either way | **Yes, tightly** — a wrong answer today calls `submitReview` (→ `apply_review`) *immediately on tap*, before any grade button. Practice Mode must replace this exact call with the practice-log INSERT, not just skip the grade-button step. | The immediate-submit-on-wrong path is the one place per type where "just swap the callback" is not quite enough — needs its own careful rewiring, not a pure prop swap |
| `mcq_multi` | `AnswerOption` × N + `GradeButtonRow` | Yes | `handleMcqMultiSubmit` → `submitReview('hard', false, selected)` on wrong; `GradeButtonRow` on correct | same shape as mcq | Same coupling as mcq — wrong-answer path submits immediately | Same as mcq |
| `case_study_mcq` | Same as `mcq` (shares `GRADED_QUESTION_TYPES` branch) + scenario collapsible | Yes | Same as mcq | Same as mcq | Same as mcq | Same as mcq, plus the scenario-expanded local state (trivial to duplicate) |
| `match_the_following` | `MatchZone` + `GradeButtonRow` | Yes | `handleMatchSubmit` → `submitReview('hard', false)` on any wrong pair | same shape as mcq | Same immediate-submit-on-wrong coupling | Same as mcq |
| `fitb` | plain input + `GradeButtonRow` | Yes, but the **matched** branch still routes through `GradeButtonRow` for the free-recall-style self-assessment (D-13) — per §4, Practice Mode should skip this too and just log `is_correct: matched ? true : null` | `handleFitbSubmit` → local state only (no `submitReview` call at all until the student's own `GradeButtonRow` tap) | Actually the **easiest** type to adapt — unlike mcq/match, nothing auto-submits on this branch today, so there's no wrong-immediate-submit coupling to rewire, only the final `GradeButtonRow` tap to replace with a plain log-and-advance | None — already the most "practice-shaped" type in the current code |
| `concept_card` | N/A | N/A — already fully excluded from grading (D-06); Practice Mode is irrelevant to it, it's pure Browse content via `ConceptCardViewer.jsx`, unrelated to this epic | never grades | N/A | N/A | N/A |

**Summary finding for 8.7.8c:** the mcq-family and match_the_following's "wrong answer submits immediately" behavior is the one real coupling risk in reuse — every other interaction point is a clean callback swap. No hidden hooks/context/state in `StudyMode.jsx` was found that would make mounting these leaf components elsewhere unsafe (no `useStudySession`/`setInStudySession` dependency inside the leaf components themselves — that hook is called at the top of `StudyMode` only, and a `PracticeMode.jsx` would call it independently if it wants the same "hide bottom nav" behavior, which is a UI nicety, not a correctness dependency).

---

## 10. Count/analytics semantics

Traced every count named in the epic against its live source:

| count | current source | affected by enrollment-without-grading? | correct future semantics |
|---|---|---|---|
| "Flashcards created" (Dashboard, MyContributions) | `flashcards` count, `user_id = auth.uid()` | **No** — ownership-scoped, enrollment is an orthogonal axis | Unchanged. Consider a label check at 8.7.8d (§6) so "created" isn't confused with "in My Cards." |
| "My Cards" (does not exist as a distinct count yet) | N/A | N/A | **New**: `COUNT(*)` from own-cards ∪ enrollment table, both re-applying §2.2's predicate at read time |
| Due today (`reviewsDue`, Dashboard; `get_due_forecast`) | `get_study_queue` length / `get_due_forecast` — both scoped to rows with an **active** `reviews` row | **No** — an enrolled-but-ungraded card has no `reviews` row, so it structurally cannot appear here, by the same mechanism proven in §2.1/§7 | Unchanged — correct by construction, zero code change |
| Reviewed count (`get_question_type_performance.reviewed_count`) | `COUNT(DISTINCT flashcard_id)` from `reviews WHERE status='active'` joined to the "available" (visibility-scoped) set | **No** — same reasoning, no `reviews` row yet means not counted | Unchanged |
| Mastered (`get_mastered_cards`, Progress "Items Mastered") | `reviews.status='mastered'` — confirmed this is **already the real SSOT count today**, not the placeholder the older SRS-ladder doc (§0/§3.3) once described — `Progress.jsx:150` calls `get_mastered_cards` directly and uses `.length`, matching the "real thing" the ladder doc flagged as a future fix. **Correction to that older doc, confirmed by reading the current live `Progress.jsx`.** | No — same reasoning | Unchanged |
| Suspended (`get_suspended_cards`) | `reviews.status='suspended'` | No — same reasoning; a Paused (post-grade) card counts here exactly as today; a Removed pre-grade card never had a row to begin with | Unchanged, but per §8's resolution, any UI built on this list must disambiguate Pause-vs-Remove via the enrollment row, not this RPC alone |
| Streak (`get_user_streak`) | `reviews.created_at`, unfiltered by status/quality | No — same reasoning | Unchanged |
| Study-set / deck totals (`flashcard_decks.card_count`, `get_browsable_decks.visible_card_count`) | Trigger-maintained / live-computed over `flashcards`, entirely independent of `reviews` or any future enrollment table | No — these already count "how many cards exist in this grouping that I can see," which is exactly the Practice/Explore-surface number, unaffected by who has or hasn't added any of them to My Cards | Unchanged — this is in fact already the right "browse" number for Practice Mode's deck tiles |

**Explicit semantic for an enrolled-but-never-genuinely-reviewed external card, stated plainly:** it counts toward **My Cards membership** (a new count) and toward **new/unreviewed study material within My Cards** (naturally, via the existing "no `reviews` row = new" logic once step-1 scoping in §6 ships) — it must not and structurally cannot (per the table above) count as reviewed, mastered, due, or streak activity, because every one of those reads is already gated on an active `reviews` row that does not exist until a genuine grade happens.

---

## 11. Security/RLS implications for 8.7.8b

- The new enrollment and practice-attempt-log tables should follow `review_events`' precedent exactly: **RLS enabled, zero client-facing policies, zero direct grants** (`REVOKE ALL FROM PUBLIC, anon, authenticated`) — every read/write goes through a `SECURITY DEFINER` RPC with the same self-only IDOR guard idiom used everywhere else in this codebase (`IF p_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN RAISE`). This is not a new pattern to invent — it's the one every single scheduling/analytics RPC in `docs/database/security/08` and `02b` already uses, and `review_events`' own zero-policy design (§4) is the exact precedent for a table nobody should ever query directly from the client.
- **`add_to_my_cards`/`remove_from_my_cards`-shaped RPCs must re-check §2.2's visibility predicate server-side at write time**, not trust that the client only ever offers the button on eligible content — this is the one place a real IDOR/visibility-bypass could be introduced if skipped (a malicious client could otherwise call `add_to_my_cards` with any `flashcard_id`, including a private card belonging to someone else, and get a membership row pointing at content it can no longer even read once the predicate is re-checked on subsequent reads — harmless in that specific case per §5's "enrollment ≠ access" rule, but wasteful/confusing state to allow, and outright wrong if the predicate is entitlement-bearing once paid content exists per §5 Q2).
- The Remove-coupled-with-suspend operation (§8) must be a **single RPC doing both writes in one transaction**, mirroring exactly how `apply_review` does its `reviews` + `review_events` writes atomically in one function body (§7's proof, `docs/database/sprint7.4/02_...sql`) — not two separate client-side RPC calls, which would leave a window where a card is un-enrolled but still due.
- No RLS policy anywhere in this codebase currently distinguishes "is this row visible to me" from "do I have an entitlement to it" — because no entitlement concept exists yet (§5 Q2). This means 8.7.8b's enrollment RLS/RPC design inherits today's visibility-only model faithfully, but **whoever eventually builds paid-content entitlement must be pointed at this document's §2.2/§5 list of every place the predicate lives**, so entitlement gets added everywhere, not just in the newest RPC.

---

## 12. Open questions

| # | question | status |
|---|---|---|
| 1 | Should `MyFlashcards.jsx` ("My Study Sets") itself become the My Cards surface (union own+enrolled), or should a new, separate page be built and this one relabeled "My Authored Content"? | **Unresolved — product decision, not a technical finding.** §6 documents the current page's exact scope so either choice is a bounded, well-understood change; recommend Anand decide explicitly before 8.7.8d starts, since it changes the page's information architecture, not just its query. |
| 2 | Should Practice Mode's free-recall types (`flashcard`/`theory`) skip `GradeButtonRow` entirely, per §4/§9's recommendation? | **Recommended answer given (skip it)**, reasoning fully stated in §4 — flagged for Anand's explicit sign-off since it's a product-feel decision, not purely technical. |
| 3 | Paid-content entitlement and its interaction with enrollment | **Explicitly unresolved — no entitlement system exists to design against (§5 Q2).** Not answerable now; the principle ("enrollment ≠ access, re-check the live predicate always") is future-proof and requires no rework later, confirmed by construction. |
| 4 | Exact mechanism/location of the manual/offline 600-second study-time minimum | **Not located in this diagnostic** — confirmed absent from `StudyMode.jsx`, presumably lives in a separate manual-logging surface not touched by this epic. Does not block 8.7.8b/c (Practice Mode only needs the already-confirmed in-app 10-second noise floor, §4), but should be located before anyone touches study-time logic generally. |
| 5 | Whether `Progress.jsx`'s "available cards" stats (already visibility-scoped, not ownership-scoped, per §6) should be redefined against "My Cards" once enrollment exists, or kept as "everything visible" | **Unresolved, flagged for 8.7.8d** — not needed for 8.7.8b/c to proceed, since Progress isn't in either sub-sprint's scope. |
| 6 | The mcq/mcq_multi/match "wrong answer auto-submits immediately" rewiring for Practice Mode (§9) | **Not a question so much as flagged implementation risk** — the one place in 8.7.8c where "swap the callback prop" isn't sufficient; needs its own small design pass at that time, not resolved here since no frontend code is being written in 8.7.8a. |

Everything else asked in the kickoff prompt has a confirmed answer, given with its live-code citation, in §2–§10 above.

---

## 13. Proposed 8.7.8b scope, derived from the above

Directly justified by this diagnostic, nothing speculative added:

1. **`my_cards_enrollment` table** — `id, user_id, flashcard_id (FK CASCADE), added_at, status ('active'/'removed')` (§3). RLS enabled, zero client policies (§11).
2. **`practice_attempts` table** — `id, user_id, flashcard_id (FK CASCADE), attempted_at, is_correct nullable` (§4). Same RLS posture.
3. **RPCs**, all following the established self-only-IDOR-guard + re-asserted-§2.2-predicate pattern:
   - `add_to_my_cards(p_user_id, p_flashcard_id)` — re-checks visibility server-side (§11), inserts/reactivates the enrollment row.
   - `remove_from_my_cards(p_user_id, p_flashcard_id)` — branches on whether a `reviews` row exists: bare delete/soft-remove if not (§8), or the atomic coupled remove+suspend if so (§8, §11).
   - `get_my_cards(p_user_id)` — additive retrieval RPC, own ∪ enrolled, re-applying §2.2, shaped for `StudyMode.jsx` to swap in at its current `fetchFlashcards` step 1 (§6). Does **not** touch or wrap `get_study_queue`.
   - `log_practice_attempt(p_user_id, p_flashcard_id, p_is_correct)` — writes only to `practice_attempts`, nothing else (§4, §11).
4. **No changes** to `apply_review`, `submit_review`, `srs_ladder_curves`, `srs_ladder_rules`, `get_study_queue`, `suspend_card`, `unsuspend_card` — all confirmed usable unmodified (§7, §8).
5. **Explicitly deferred past 8.7.8b**: any frontend work (8.7.8c/d), the Progress.jsx semantic question (§12.5), the MyFlashcards.jsx identity question (§12.1), paid entitlement (§12.3/§5 Q2), and the pre-existing skip_card/suspend_card bare-row badge/streak edge case (§8, recorded not fixed).

---

*No SQL files accompany this document. No frontend code was changed. Awaiting Anand's review before any 8.7.8b SQL is drafted.*
