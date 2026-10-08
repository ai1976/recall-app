# T-002 stream B: plan change log (append-only)

The current plan file is named in `CURRENT.md`. Plan files are immutable hashed snapshots; changes made after a snapshot are recorded here and apply on top of it. Newest entry last. Each entry names the thread round, the sections of the snapshot it changes, and the files it concerns.

## Snapshot: `00_PLAN_stream-B-execution-plan_v18.md`, sha256 short `88241bd6d514` (QA Round 38: PASS WITH CONDITIONS)

## Entry 1 (08/10/2026, thread Round 41; answers QA Round 40)
- **Section 2 / 5.1 / 8 / 10B, file B-01:** B-01 now creates THREE functions: `normalize_course_text(text)`, `course_catalogue_labels()` (the single, enumerable, owner-only, IMMUTABLE definition of the six CMA and CS labels, used by the resolver and by B-06a; B-06a must call it and never copy the literals) and `resolve_canonical_course_label(text)`. Section 10B gains a row for `course_catalogue_labels()`: INVOKER, IMMUTABLE, owner only.
- **Section 2 / 10B, file B-02a:** B-02a now also installs a statement-level BEFORE TRUNCATE guard (`trg_disciplines_no_truncate`, function `fn_guard_disciplines_no_truncate`), so TRUNCATE (held by `anon` and `authenticated` per D2 v3 P4) cannot empty the catalogue between B-02a and B-02b; B-02b still revokes the privilege. B-02a sets `lock_timeout` 5 s and `statement_timeout` 30 s and uses plain CREATE (fails closed on a pre-existing object). Section 10B rows for B-02a gain the TRUNCATE guard function.
- **Rollback order, all files:** B-06a, B-05, B-04a, B-07, B-03, B-02b, B-02a, B-01 (B-02b was missing from earlier text).
- **5.2 / 11 (service_role):** `service_role` holds UPDATE, DELETE and TRUNCATE on `study_sessions` (D2 v3 P4). Under the plan, effective UPDATE for `service_role` is a GATING item: D4 (v13, 08/10/2026) found no consumer, so UPDATE is closed and proved before B-04b. It is NOT a residual to accept. DELETE and TRUNCATE remain reported findings (DEC-4).
- **5.2 (`created_at`):** D2 v3 shows `authenticated` can insert `created_at`. Consequence stated: any row in the S1 delta stays unresolved (not legacy) unless a database-authored time fact and a comparable clock show it predates the F1 serving time; the cutover never absorbs such rows.
- **Files superseded:** B-01 v1 (`b0fe47bb2ed8`, `17f07893f74b`, `46e3d3cf75bb`) and B-02a v1 (`c5c85984ad28`, `a582c40c983c`, `173f0bdf20f8`).

## Entry 2 (08/10/2026, thread Round 47; answers QA Round 46)
- **Section 10B, B-02b:** `service_role` loses ALL privileges on `disciplines`, `subjects` and `topics` (R1: no edge function uses them, D4 v13); the SECURITY DEFINER catalogue readers run as the owner. `anon` keeps SELECT only until the Signup wrapper (B-06a/F1) removes it. `authenticated` keeps SELECT and INSERT on all three and UPDATE on `subjects` only. The three new policies are `admin_insert_subjects`, `admin_update_subjects`, `admin_insert_topics`, all through `is_admin()`.
- **Fail-closed rule (B-02b, applies to later schema files too):** a file that builds on a D2-recorded object binds its exact content (policy bodies by hash, function definition hash, owner, security mode, ACL, column and PUBLIC ACLs, starting privileges), not only its name.
- **Files superseded:** B-02b v1 (`82db0b313a80`, `8e6695557cf8`, `2539d617d931`).

## Entry 3 (08/10/2026, thread Round 52; file B-04a v1)
- **Section 5.1 / 10B R3, service_role on `study_sessions`:** D4 finds one service_role consumer: the edge function `cron-daily-study-summary` reads `study_sessions` (SELECT only, `index.ts` lines 161 and 209). So B-04a revokes UPDATE (gating) and INSERT (no consumer) from `service_role` and KEEPS SELECT. DELETE, TRUNCATE, REFERENCES, TRIGGER and MAINTAIN stay as they are (reported findings, DEC-4). B-04b still requires the fresh closure re-run.
- **Reported finding (not changed):** D2 shows `authenticated` also holds table-level MAINTAIN on `study_sessions` (VACUUM, ANALYZE, REINDEX, LOCK TABLE through direct SQL; not reachable through the Supabase REST API). Same for the other tables was not examined here.
- **Constraint names chosen by B-04a:** `study_sessions_discipline_id_fkey`, `study_sessions_discipline_subject_fkey`, `study_sessions_classification_values`, `study_sessions_classification_shape`, `study_sessions_machine_source_unclassified`; unique `subjects_discipline_id_id_key`; trigger `trg_study_sessions_label_guard` (function `fn_study_sessions_label_guard`). All shape CHECKs are written two-valued (`IS NOT DISTINCT FROM`), because a NULL-valued CHECK passes.
