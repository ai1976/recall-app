# T-001 SQL work plan (a plan, not SQL)

**Status:** working paper for Gate 2. Written 05/10/2026. It authorizes nothing. SQL files named here do not exist yet; each will be hashed, audited by QA per exact hash, and approved by the Founder per exact hash (Gate 2) before any execution is even requested (Gate 3), and verified afterwards (Gate 4). Deployment order is fixed by the project rule: **SQL in Supabase, then frontend push, then verification on the live URL.**

## 1. What the Founder has approved and authorized (Round 41)
- **Gate 1 (design):** brief A v13 at `84d7157b06de` and brief B v10 at `0fe77dec72dc`, with decisions D1 to D11 and E1 to E10 confirmed as recommended. The briefs are the design; this plan changes none of it.
- **Authorized:** running read-only follow-up diagnostic 3 (`a5cf2dc36147`); **drafting** SQL, rollback and test files for Gate 2 review.
- **Not authorized:** executing any migration, deployment, commit or push of SQL or frontend.

## 2. Binding conditions carried into the SQL design and tests
These come from the Founder's Round 41 message and QA's Round 40 (`PASS WITH CONDITIONS`). Each is an acceptance criterion; a Gate 2 file that does not satisfy it is rejected.
| # | Condition | Where it lands | Proof required |
|---|---|---|---|
| C1 | During initialization (brief A step 3(b)) obtain the **membership-table and trigger lock first**, then take batch-row locks in ascending id order, initialize only NULL negative rows, re-enable the trigger and commit. Never hold a batch-row lock while waiting for the table lock. | file A-07 (data) | The SQL review rejects the reverse order. A test proves that an error or rollback in the middle **leaves the stamping trigger enabled**. A test with a concurrent membership writer proves no deadlock and no unstamped negative row. |
| C2 | Enforce and **verify the exact `grp_batch_writer` role-membership and privilege boundary**: `NOLOGIN`; not superuser, BYPASSRLS, CREATEROLE, CREATEDB or replication; **not inherited by or settable by** `authenticator`, `anon`, `authenticated`, service or application roles or any other untrusted role; only the trusted migration identity can `SET LOCAL ROLE` to it (steps 3, 5, 6); its object and table privileges are limited to the enumerated writer implementation. | file A-01 (roles) and its TEST file | A catalog test reads `pg_roles` and `pg_auth_members` and fails on any deviation; a real-role test shows each untrusted role gets "permission denied" on `SET ROLE grp_batch_writer`; a test lists every `SECURITY DEFINER` function that can write the three tables and fails unless exactly the approved set is owned by the role. |
| C3 | **One cross-column collision-safe allocation** is used for **every** replacement token (step 5 overwrite, new-batch tokens, rollback replacement tokens): regenerate if the value equals any invite token **or** any `study_groups.invite_token`, fail closed if not resolved. | one shared function used by A-06, A-07, A-09 and the rollback | Tests force **both** collision classes (a value equal to an invite token; a value equal to another group's column token) and check the retry and the fail-closed path. |
| C4 | QA Round 40 also requires: the stamping trigger has no exception of any kind; unrelated UPDATEs through direct and SECURITY DEFINER paths cannot change `last_inactive_seq` after initialization; initialization changes only NULL rows and allocates from the current counter (the original 1, invites 2 and 3, archive 4 example stays 4 on a rerun). | A-03, A-07 | Tests as listed in brief A section 5 (tests for the whole migration). |

## 3. Facts that must be measured before a file is authored (no file is written against an assumption)
| Fact | Needed by | How it will be measured | Status |
|---|---|---|---|
| Groups by (`is_batch_group`, `group_type`): any drift? | A-02 (step 0 policies and guard), possible data-fix file | diagnostic 3 run H1 | authorized, **not yet run** |
| Live bodies of `create_batch_group`, `archive_batch_group`, `restore_batch_group`, `get_study_time_stats` | A-06 (rewritten writers), A-08 | diagnostic 3 run H2 | authorized, not yet run |
| Definitions of every trigger (timing, events) | B-03 (profile trigger ordering relative to `trg_course_change_archive_restore` and `trg_guard_profiles_protected_columns`), A-02, A-03 | diagnostic 3 run H3 | authorized, not yet run |
| Policies on `disciplines`, `subjects`, `topics` | B-02 (catalogue guards and privilege revoke that keeps `BulkUploadTopics.jsx` working) | diagnostic 3 run H4 | authorized, not yet run |
| Role attributes and memberships (condition C2); the complete set of `SECURITY DEFINER` functions that can write `study_groups`, `study_group_members` or the future invite relation, with owners; live bodies of `create_study_group`, `invite_to_group`, `accept_group_invite`, `decline_group_invite`, `rename_batch_group` | A-01, A-02, A-06, the privilege contract of step 0(d) | follow-up diagnostic 4 (drafted, **not audited, not authorized**) | to be audited and authorized |
| Live body of `submit_access_request`, `link_access_request`, `admin_grant_access` (captured in RUN 1A) | A-10 | already saved (RUN 1A) | available |

## 4. File inventory and order (names follow the project SQL naming rule `[FOLDER] Name`; each file has a rollback and a real-role TEST file)
**Stream A, batch groups, invites, membership history (brief A):**
| File | Folder | Content | Depends on |
|---|---|---|---|
| A-01 | `[SCHEMA]` | `grp_batch_writer` role, grants, ownership plan, catalog assertions (C2) | diagnostic 4 |
| A-02 | `[SCHEMA]` | step 0: policies (`sg_insert`, `sg_update_creator`, `sg_delete_creator`, `sgm_insert_admin`, `sgm_delete`), guard trigger, the final privilege contract; `[FIX]` marker repair if H1 shows drift | H1, H3, diagnostic 4, A-01 |
| A-03 | `[SCHEMA]` | step 1: invite relation (RLS, no client grants, `is_original`, immutability trigger), `order_seq`, `last_inactive_seq`, stamping trigger (batch-shaped only), shared collision-safe token function (C3) | A-01, A-02 |
| A-04 | `[SCHEMA]` | widen the membership status CHECK (`rejected`, `removed`, `left`), events relation and its immutability trigger and RLS | A-03 |
| A-05 | `[FUNCTIONS]` | eligibility function; invite functions (`create_batch_invite`, `list_batch_invites`, `revoke_batch_invite`) with explicit EXECUTE grants | A-03, A-04 |
| A-06 | `[FUNCTIONS]` | rewritten writers: `create_batch_group` (original invite, dual-write), join, approve, reject, bulk resolve, enroll, remove, leave, archive, restore | H2, diagnostic 4, A-05 |
| A-07 | `[DATA]` | steps 3(a) and 3(b): backfill, catch-up, NULL-only initialization (C1, C4), verification queries | A-06 |
| A-08 | `[FUNCTIONS]` | step 4 cutover: `join_group_by_token`, `get_group_preview`, `get_admin_batch_groups` resolve batch-shaped tokens through invites | A-07 |
| A-09 | `[DATA]` | step 5: collision-safe token overwrite and verification (C3) | A-08 (frontend for the admin link must be deployed first) |
| A-10 | `[SCHEMA]` + `[FUNCTIONS]` | access requests: columns, the two partial unique indexes, target-validation trigger, claims relation, link functions, reader functions, `admin_grant_access` closure | RUN 1A bodies; independent of A-01 to A-09 |
| A-11 | `[SCHEMA]` | EXECUTE revokes for `PUBLIC` and `anon` on the functions found executable in G2 | A-06, A-08 |
**Stream B, course identity and reporting (brief B):**
| File | Folder | Content | Depends on |
|---|---|---|---|
| B-01 | `[FUNCTIONS]` | `normalize_course_text` (IMMUTABLE) and `resolve_canonical_course_label` (STABLE, pinned `search_path`) | none |
| B-02 | `[SCHEMA]` | `disciplines` guards: normalized-name unique index, rename and delete triggers; privilege revoke only after H4 | H4 |
| B-03 | `[SCHEMA]` | `profiles` canonicalization trigger (BEFORE, only on `course_level` change) | H3 (trigger order) |
| B-04 | `[SCHEMA]` | `study_sessions` classification columns, generated keys, constraints (`NOT VALID`), insert trigger, composite foreign key, unique pair on `subjects` | none |
| B-05 | `[SCHEMA]` | guard trigger on `flashcards` and `notes` for new platform rows | B-01 |
| B-06 | `[FUNCTIONS]` | student-only read function for the classified breakdown; the course catalogue function | B-01, B-04 |
**Stream order:** A-10 and Stream B do not depend on the group migration and have a smaller blast radius; the Founder may choose to review them first. The group migration (A-01 to A-09, A-11) is strictly ordered as shown, with real-role TEST and ROLLBACK files for each file.

## 5. Standards for every file (from project memory and CLAUDE.md)
- SQL is a file under `docs/database/t001/`, never pasted into chat as the deliverable; every query has a `[FOLDER]` name and description.
- The Supabase SQL Editor wraps one run in **one transaction**: never mix persistent DDL with a verification `ROLLBACK`; `search_path` is set unquoted (`TO public, extensions`); search-path tests exercise a real write.
- Absence of a constraint, trigger, policy or grant is catalog-verified, never inferred from code; every fact a file relies on cites a saved evidence file.
- Real-role tests run as `anon`, `authenticated` (student, professor, group admin, platform admin, super admin) where relevant, not as the migration owner.
- Each file states its lock order (invite row, batch row, membership rows in ascending id, events insert; table lock before batch locks in initialization, C1) and is checked statement by statement.
- Client behaviour that needs a frontend change is listed in section 6 and is not deployed before its SQL.

## 6. Frontend dependencies (for later; none authorized)
`AdminDashboard.jsx:1742` (copy invite link reads `list_batch_invites`), `GroupJoin.jsx` (recipient-bound refusals, preview shape), `ContentPreviewWall.jsx` and the access-request admin screens (claims, link, supersede, grouped anonymous requests), `GroupDetail.jsx:290` (kept, non-batch only), `StudyTimerWidget.jsx` and `StudyTimerContext.jsx` (`confirmCategory`, the course picker and the classification contract), `ProfileSettings.jsx` and `Signup.jsx` (catalogue and canonical labels), `Progress.jsx` (groups by course), `BulkUploadTopics.jsx` (must keep working through the admin write path of B-02). Frontend work starts only after the SQL it depends on is executed and verified.

## 7. Process
1. The Founder runs diagnostic 3 (authorized) and, once QA passes and the Founder authorizes it, diagnostic 4; results are saved unedited and audited.
2. Claude drafts the file set per section 4, in order, each with its ROLLBACK and TEST file, citing evidence.
3. QA audits each file by hash; the Founder approves per hash (Gate 2); only then does Claude ask for execution authorization (Gate 3), and verification follows (Gate 4).
