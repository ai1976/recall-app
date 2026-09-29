# Design: Course-change archival (item 2) + Batch↔Professor assignment (item 8)

Status: DESIGN ONLY — no SQL deployed, no code written. Decisions from 29/09/2026 chat.
Facts below marked (verified) come from the live diagnostics run 29/09/2026 or from docs; facts marked (TO VERIFY)
must be catalog-checked in Step 0 before any SQL is written (CLAUDE.md Database Rules).

---------------------------------------------------------------------------------------------------
## A. Course-change archival

### A.1 What the diagnostics showed (verified)
- Shriya: profile = CA Intermediate, 37 active enrollments, all CA Foundation / Business Laws (35 external, 2 own).
- Rujuta: profile = CA Intermediate, 69 active enrollments, all CA Foundation / Business Laws.
- get_study_queue already filters by `flashcards.target_course = profiles.course_level` at read time (DATABASE_SCHEMA
  line ~1836), so the Review queue already hides old-course cards. The gap is `get_my_cards` (My Study), which has no
  course filter, and My Study's own "Study" buttons.

### A.2 Which cards count as "old course"
`flashcards.target_course = <old course_level>` (text NOT NULL, verified in schema). Not the subject→discipline join.
Cards whose target_course is neither old nor new are left alone.

### A.3 Data model change (my_cards_enrollment)
- status CHECK widened: `('active','removed','course_archived')`  — a distinct state, NOT 'removed' + a flag, so no
  existing function that reads 'removed' (History "Removed", add_to_my_cards re-add→unsuspend) can mistake it for a
  manual removal.
- New nullable columns: `archived_course text`, `archived_at timestamptz`.
- `reviews` is NOT touched by archival. So a card's Active / Paused / Mastered state is preserved automatically, and
  restore is just flipping the enrollment back. (remove_from_my_cards suspends the review row; course archival
  deliberately does not — that is why prior state survives with no snapshot column.)

### A.4 Transition rules (single source of truth = one SECURITY DEFINER trigger function)
Fires AFTER UPDATE OF course_level ON profiles, only when OLD.course_level IS DISTINCT FROM NEW.course_level and the
user's role is 'student' (TO VERIFY role value; professors keep course_level as a teaching primary — never archive theirs).
Runs in the same transaction as the profile update, so it is atomic by construction.
1. ARCHIVE: enrollments with status='active' whose card target_course = OLD course →
   status='course_archived', archived_course=OLD, archived_at=now().
2. RESTORE: enrollments with status='course_archived' AND archived_course = NEW course → status='active',
   archived_course=NULL, archived_at=NULL.
3. Manually removed rows (status='removed') are never touched by either step.
4. Chain A→B→C→A works because each archived row is tagged with the course it was archived from.
Why a trigger and not only an RPC: it covers every path that changes a course (student, admin edit, future code) and
cannot be bypassed. (TO VERIFY first: broad `information_schema.triggers WHERE trigger_schema='public'` scan and
whether any existing profiles trigger touches course_level; whether profile_courses is used for students.)

### A.5 Existing functions that must be patched (small, additive)
- add_to_my_cards / add_batch_to_my_cards: on conflict they set status='active' — also clear archived_course/at.
  (A student who deliberately re-adds an archived card from Practice makes it a normal active enrollment.)
- get_my_cards: unchanged (already active-only → archived cards leave My Study).
- get_removed_my_cards: unchanged (removed-only → archived cards do NOT appear as "Removed").
- apply_review guard: unchanged (requires active enrollment → archived cards can't be graded).
- Anything else that reads status (TO VERIFY by grep + catalog scan): get_browsable_decks added_count (active-only,
  fine), log_practice_attempt.

### A.6 New RPCs
- `preview_course_change(p_new_course text)` → jsonb { old_course, new_course, archive_count, archive_active,
  archive_paused, archive_mastered, restore_count }. Read-only, caller = self. Used by the confirmation dialog.
- `get_course_archived_my_cards(p_user_id)` → SETOF flashcards (+ a tiny summary RPC or the archived_course via a
  second call) for the History tab section "Archived — course change".

### A.7 Frontend flow (ProfileSettings)
Select → (course_level is NOT part of the generic Save any more) → consequence dialog using preview_course_change
("N cards from CA Foundation will leave My Study and Review. Your history is kept. They return automatically if you
switch back. M cards from CA Intermediate will come back.") → explicit Confirm → single profile update (trigger does
the rest) → refresh CourseContext + My Study. Cancel leaves the profile unchanged.
History tab gets a third section, read-only, labelled with the source course, with the "returns automatically" note.

### A.8 One-time backfill for already-switched students
Shriya (37) and Rujuta (69): archive their CA Foundation enrollments with archived_course='CA Foundation' so they
are restorable if either switches back. Separate [DATA] file, run only after their approval of the exact list.
A read-only sweep for other switched students should run first.

### A.9 Separate feature: bulk actions in My Study (general purpose)
`bulk_pause_my_cards`, `bulk_resume_my_cards`, `bulk_remove_from_my_cards`(p_user_id, p_flashcard_ids uuid[], cap ~500),
each a loop over the existing single-card semantics (suspend_card / unsuspend_card / remove_from_my_cards) in ONE
transaction, so per-card behaviour is identical. UI: "Pause all / Resume all / Remove all" on every subject and topic
header with a confirm dialog stating the count.

---------------------------------------------------------------------------------------------------
## B. Professor ↔ Batch assignment

### B.1 Today (verified from pg_get_functiondef)
- get_my_batch_groups: professor branch returns EVERY active batch group; role gate only.
- get_batch_group_member_stats / get_batch_group_archive: gated on role only (per docs).
- The 3 professors (Anand More, Niraj Mahajan, Abhay More) are also *members* of the one batch, which means they
  also appear as rows in that batch's student report (get_batch_group_member_stats lists all active members).

### B.2 Table
`batch_group_professors (group_id uuid → study_groups ON DELETE CASCADE, professor_id uuid → profiles,
assigned_by uuid, assigned_at timestamptz DEFAULT now(), PRIMARY KEY (group_id, professor_id))`
+ index on professor_id. RLS enabled, zero policies, REVOKE ALL (same house pattern as my_cards_enrollment).
Many-to-many by construction. No membership row involved.

### B.3 RPCs (admin/super_admin only via is_admin())
assign_professor_to_batch(p_group_id, p_professor_id) — checks group is_batch_group, professor's role='professor',
idempotent. unassign_professor_from_batch(...). get_batch_group_professors(p_group_id). get_assignable_professors().

### B.4 Authorization changes (CREATE OR REPLACE, additive)
- get_my_batch_groups professor branch: JOIN batch_group_professors on professor_id = auth.uid(); returns
  user_role='professor'. Admin branch unchanged.
- get_batch_group_member_stats, get_batch_group_archive: allow admin/super_admin as today; professor only if
  assigned to THAT group. (archive_batch_group calls the stats function as admin — unaffected.)
- get_group_detail (and anything GroupDetail.jsx calls) must let an ASSIGNED, NON-MEMBER professor open the page in a
  read-only monitoring view (TO VERIFY current membership check + UI branch at GroupDetail.jsx:443 which keys off
  role === 'student').
- Assignment is checked together with profiles.role='professor' at call time, so demoting a professor revokes access.

### B.5 Admin UI (AdminDashboard batch section)
On each batch: "Professors" list with Assign / Remove, backed by get_assignable_professors.

### B.6 Migration
Backfill assignments for the 3 professors on the one existing batch so nobody loses access on deploy day, in the same
SQL file that adds the table, BEFORE the authorization functions are tightened. Their memberships are left as they are
unless the founder decides to remove them (that would also clean them out of the student report).

---------------------------------------------------------------------------------------------------
## C. Deployment order (per CLAUDE.md — SQL first, then frontend)
1. Step 0 catalog diagnostics (triggers on profiles, my_cards_enrollment CHECK, all readers of enrollment.status,
   role values, get_group_detail body, batch report functions' gates).
2. SQL files in docs/database/sprint8.8.5b… (schema → functions → test → data backfill), run + verified by the founder.
3. Frontend push. 4. Live verification with a disposable student account. 5. Docs (blueprint, now, changelog,
   DATABASE_SCHEMA, FILE_STRUCTURE, bugs).
