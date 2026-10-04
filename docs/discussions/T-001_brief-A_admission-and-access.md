# T-001 · Design brief A — admission and content access (consolidated)

**Status:** DRAFT for QA audit. Not approved. No gate is given by this file.
**Version:** v3, consolidated. This file is the single source for brief A. It replaces, as a design, the brief A text spread across T-001 Round 13 sections B, Round 15 sections C-D and Round 17 sections B-C. Those rounds remain as history and are not to be read as design.
**Scope:** points 3 and 4 of the backlog (admission journey, content access by creator), with the batch invite and batch removal threads. **Out of scope and unchanged by this brief:** the Educators application flow (including the educator branch of `link_access_request`), institute inquiries, any in-app payment, implementation of creator-controlled content access (design principles only), and 8.8.6.
**Evidence used:** the admission-journey matrix (T-001 Round 13 section A, with row 10 as corrected in Round 15 section B); the ten production evidence files of 04/10/2026 (`docs/discussions/evidence/T-001_RUN-*_04-10-2026.md`, referred to as RUN 1A to RUN 8); code at `@ 6fc6ceb`. Items that depend on the follow-up diagnostic (`01_DIAGNOSTIC_follow-up_...sql`, not yet audited or run) are marked OPEN.

## 1. Invariants (every other artifact must respect these)
- **A-I1.** The only authoritative identity of a person is `auth.uid()`. A typed email, a ref token and an invite token are **claims**, never identity.
- **A-I2.** A claim becomes an authoritative link only by verification: (a) the claiming account's **confirmed** account email equals the request's contact email, or (b) an administrator explicitly confirms it. Until then it grants, closes and merges nothing.
- **A-I3.** No access request row is ever discarded or suppressed because of an unverified email. Repeats are grouped in the admin display and admin notifications are throttled; every row is stored.
- **A-I4.** Collapsing a duplicate request is allowed only for an authenticated requester (A-I1) and the same request target (section 3).
- **A-I5.** Closing a request happens only through an authoritative link or an explicit administrator selection, never through a broad email match.
- **A-I6.** Rejection, removal and leaving **preserve** the membership row; history is append-only; no row presence confers access: only status `active` does.
- **A-I7.** Batch membership and content entitlement are separate. One server-side eligibility rule governs every way of becoming a member.
- **A-I8.** Invites are enforced atomically on the server. One lock order applies to every writer (section 6).
- **A-I9.** No in-app payment in v1. Manual grants are called "creator-granted" or "externally fulfilled", never "paid", unless a real transaction is recorded.
- **A-I10.** Existing shared batch links keep working through the migration.

## 2. Defects the evidence proves
1. **Correlation and display, not absence of links.** A batch request is reliably keyed to the student's profile (`study_group_members.user_id`, foreign key, RUN 6). An access request can carry an email, a client-supplied `requester_user_id` and a ref-token correlation. The live `submit_access_request` stores whatever requester id the client sends (RUN 1A); the admin screen matches only on exact client-side email or ref-token comparison and ignores `requester_user_id` (`AdminDashboard.jsx:1386-1389`); `link_access_request` lets any signed-in user set `profiles.access_request_ref` once to any uuid (RUN 1A). The admin screens do not join or display the relationships (matrix rows 3, 8, 10, 20).
2. "Joining a batch" and "having content access" are separate in the data but promised together in the wording (rows 4, 6, 9).
3. The invite is a permanent, unlabelled token with no recipient, no expiry, no revocation and no UNIQUE constraint (RUN 6).
4. Rejection, removal and re-request leave no durable trace; removal and rejection notify nobody (rows 5, 17).
5. Granting access never closes the request (RUN 1A, RUN 7: 6 requests all `pending`, 240 enrolled students); duplicates are not controlled.
6. The Tier B content lock is located only in the screens (`NoteDetail.jsx:166`, `StudyMode.jsx:515-518`); database enforcement is OPEN.

## 3. Request target (the term "scope" is not used)
A **request target** is the triple (`request_type`, `content_type`, `content_id`) already stored on `access_requests`. For this brief only `request_type = 'student_access'` is in play. Its targets are: **platform-level** (no content item: account-level full content access) or **one content item** (`content_type` note or flashcard_deck, with its `content_id`, as the preview wall stores today). `institute_inquiry` and `educator_application` are out of scope. A later creator-access epic adds creator targets; this brief does not.
**Open** means status `pending` or `contacted` (the two statuses of `access_requests_status_check` that still await a decision, RUN 7). Granting platform access (the existing `admin_grant_access`) satisfies every open `student_access` request of that account, whatever its content target.

## 4. Access-request contract
**4.1 At submission.**
- Signed-in caller: the requester stored is `auth.uid()`; a client-supplied requester id is ignored.
- Anonymous caller (logged-out visitor; `PUBLIC`/`anon` EXECUTE stays because logged-out visitors use the wall): no requester is stored.
- The typed email is normalized (trimmed, lower-cased) and stored as the **contact email**. It is a claim (A-I1).
- If a signed-in caller's contact email differs from their account email, the row is flagged "contact email differs from account email" for the admin. No link to any other account is made.
**4.2 Duplicates (A-I3, A-I4).**
- Authenticated: at most one **open** request per (requester, request target), enforced by a partial unique index on (requester id, request type, content type, content id) where status is open and requester is not null; a repeat returns the existing request.
- Anonymous: **never deduplicated or suppressed**. The admin screen groups anonymous repeats by contact email and target with a count; admin notifications are throttled to one per (contact email, target) per 24 hours; every row is stored.
- Abuse control is a separate requirement (rate limits at the function or edge level). When a rate limit rejects a request the caller receives an explicit "try again later" error, never a false "already received".
**4.3 Token claim (`link_access_request`, student-access branch only).** The educator branch is unchanged and out of scope.
- The token must belong to an existing `student_access` request that has not been claimed. The claim is atomic (a conditional update that succeeds only while the request is unclaimed) and records the claiming account and time.
- A claim alone is **not authoritative** (A-I2). It becomes an authoritative link when (a) the claiming account's confirmed email (from the authentication record, with its confirmation timestamp) equals the request's contact email, in the same statement, or (b) an administrator confirms it in the admin screen (the screen shows the claimant's name and email beside the request's contact details).
- Replay by the same account is a successful no-op. A different account receives a generic refusal. A claim never overwrites another account's claim or link.
- `profiles.access_request_ref` is written only by a successful claim.
- Threat model, stated: a forwarded signup link lets a second person claim; the claim is visible to the admin as unconfirmed and cannot grant, close or merge anything (A-I2). A confirmed-email match proves control of the mailbox the request named.
**4.4 Authoritative links.** A request has an authoritative link to account X exactly when its stored requester is X (set at submission from `auth.uid()`), or its confirmed link account is X (4.3).
**4.5 Closure (`admin_grant_access`).** In one transaction it grants access, then closes (a) the request the administrator explicitly selected, if any (that selection is itself the confirmation), and (b) every open `student_access` request that has an authoritative link to that account. It never closes by email. The audit entry lists the closed request ids.
**4.6 Admin screen.** Shows each request as: linked (authoritative); claimed, awaiting confirmation (with the confirm action); suggested by email (a profile whose email equals the contact email, not confirmed), each with an explicit administrator "link to this account" action that records the confirmation (basis: administrator); or not linked. All matching and normalization run on the server, not by exact client-side comparison. In User Management, a Tier B row shows the account's course, institution and any linked or suggested access request.
**4.7 New columns on `access_requests` (design list, no SQL).** claimed account and time; confirmed link account, confirming basis (confirmed email or administrator), confirming administrator and time; a flag for contact-email difference; email normalization on write; the partial unique index of 4.2.

## 5. Invites (batch groups)
- **Invite records** replace the bare token for batches: id, batch, a **UNIQUE** token, label (for example "Inter May 27 – WhatsApp group A", length-limited), created by and when, optional expiry, revoked flag with who and when, and an optional intended recipient (an account, or a verified email). A shared **cohort link** (no recipient) stays the default; recipient-bound invites are an option for known students; single-use links are deferred until a need is confirmed.
- **Migration (A-I10).** Each existing batch's current `study_groups.invite_token` becomes that batch's first cohort invite, so every link already shared keeps working. The admin "Copy Invite Link" action then reads the active invites.
- **Enforcement.** `join_group_by_token` resolves the token to its invite and, in one transaction holding a row lock on that invite, checks in order: invite exists; not revoked; not expired (against the transaction's current time); batch not archived; caller is a student; and, if the invite has a recipient, the caller matches it (a recipient account equals `auth.uid()`; a recipient email equals the caller's **confirmed** account email, lower-cased). Any failure returns one generic refusal ("This invite isn't available for your account.") that does not reveal who it was meant for. Revoking takes the same lock, so a revoke committed before the join wins; a revoke after a completed join does not delete the request (the administrator may reject it).
- `get_group_preview` returns the same "link no longer valid" shape for revoked, expired and unknown tokens, with no batch details.
- Every request records the invite it came through, so the pending list shows "via <label>".

## 6. Membership states, history and authorization (batch groups only)
**6.1 States.** `invited`, `requested`, `active`, `closed` (existing) plus `rejected`, `removed` and `left` (new). `UNIQUE (group_id, user_id)` stays: one row per student and batch is the **current state**; history lives in an append-only events relation.
**6.2 Transitions.**
| # | From to | Trigger and function | Event kind | Actor kind | No-op or refused outcome (no event written) |
|---|---|---|---|---|---|
| 1 | none to requested | student with a valid invite, `join_group_by_token` | requested | self | already requested: "already_requested"; already active: "already_active" |
| 2 | none to invited | staff invites a student to a batch (0 such rows today in batch groups, RUN 6) | invited | admin or group_admin | row exists: refused with outcome |
| 3 | invited to active | the invited student uses the link | accepted_invite | self | - |
| 4 | requested to active | approve, single or bulk | approved | admin | already resolved: "already_resolved" |
| 5 | requested to rejected | reject, single or bulk (reason optional) | rejected | admin | already resolved: "already_resolved" |
| 6 | none, rejected, removed or left to active | admin direct add, `enroll_user_in_batch_group` | added_by_admin | admin | already active: "already_active" |
| 7 | rejected, removed or left to requested | student reuses the link | reopened_request | self | already requested: "already_requested" |
| 8 | active to removed | admin or group admin removes, hardened `remove_group_member` (reason required; archived batch refused) | removed | admin or group_admin | not active: refused "not_active" |
| 9 | active to left | student leaves, `leave_group` | left | self | not active: refused |
| 10 | requested or invited to closed | batch archived, `archive_batch_group` (VERIFIED-in-repo: only those two states are closed, with reason batch_archived; active rows are unchanged) | closed_by_archive (one per affected row) | admin | already archived: no events |
| 11 | closed to requested | student reuses the link after restore (restore does not revive closed rows, VERIFIED-in-repo) | reopened_request | self | - |
| 12 | active stays active | archive and restore | none per member (group-level audit only) | - | - |
| 13 | none to active (staff) | admin or super_admin uses a link | joined_as_staff | self | row exists: no-op |
**Actor kinds:** `self`, `admin` (platform admin or super_admin), `group_admin`, `system` (backfills, migrations, automation). `actor_id` is NULL only for `system`.
**6.3 Events relation (new, append-only).** One row per event: batch, user, event kind, actor kind, actor id, actor role at the time, optional reason (length-limited), the invite id when the event is a request, and a timestamp. Rows are inserted only by SECURITY DEFINER functions in the same transaction as the state change; no client role may update or delete them (the same immutability trigger pattern as `admin_audit_log`, RUN 4). Row-level security is enabled with **no client policies and no direct client privileges**.
**6.4 Who can read events (least privilege), through SECURITY DEFINER read functions only.**
- the affected student: their own events; event kind, time and batch name only (no actor, reason or invite label);
- platform admin and super_admin: all fields for any batch;
- an active group admin member of that batch: all fields for that batch, with the actor shown by kind not identity;
- an assigned professor: nothing (roster view only, per 8.8.5d);
- everyone else: nothing.
**6.5 Re-request after rejection or removal.** The server creates a fresh request, writes `reopened_request`, and the admin queue shows a history summary ("previously rejected 12/09; removed 20/09"). A rejected or removed student sees a plain message on the join page. Whether a cooldown applies is decision D7.
**6.6 Writers and lock order.** Writers: `join_group_by_token`, `approve_batch_join_request`, `reject_batch_join_request`, `admin_bulk_resolve_batch_requests`, `enroll_user_in_batch_group`, `remove_group_member`, `leave_group`, `archive_batch_group`, `restore_batch_group`, and the invite create, list and revoke functions. Today (RUN 1A, repo): join, approve, reject, bulk resolve, enroll, archive and restore take the batch row lock; **`remove_group_member` and `leave_group` take no lock**. Every revised writer **will** take the same lock order: **invite row, then batch row, then membership rows in ascending id order, then the events insert**, each state change and its event in one transaction.
**6.7 Readers.** A preserved `rejected`, `removed`, `left` or `closed` row must never grant anything. Live policies `sg_select_member` (any membership row lets the user read the `study_groups` row, which includes `invite_token`; column-level privileges not yet captured) and `sgm_select_own` ignore `status` (RUN 6). Every reader of `study_group_members` (policies, `batch_group_access_denial`, `get_my_batch_groups`, content-sharing paths, front-end direct selects) must be audited so that only `active` confers access, and no stale row exposes an invite token.
**6.8 Privileges.** If effective INSERT or DELETE exists for `authenticated` on `study_group_members` (open S-1/S-2, follow-up RUN F1), it is closed or the policies tightened so the functions are the only write path.

## 7. Eligibility and the Tier B question
One server function decides whether a student may become a member, called by single Add, bulk Add, single approve and bulk approve: role is student; profile status is not suspended (OPEN: no live join, approve or enroll body checks status, RUN 1A); the batch is not archived; and the access rule of decision D4. Batch membership never grants content entitlement (A-I7). Today the rules differ: bulk Add refuses Tier B students, single Add shows no picker for them, approve does not check (matrix rows 4, 6, 11).

## 8. Content access model (principles; implementation is a later epic)
No payment is taken in the app in v1 (A-I9): a manual grant reads "creator-granted" or "externally fulfilled", never "paid", unless a real transaction is recorded. Keep as independent concepts, never one flag: **provenance** (official ICAI versus creator material; `content_creators` exists only for revenue-share attribution today, `DATABASE_SCHEMA.md:72,241`); **access policy** per item (`free`, `private`, `preview`, `restricted`; official material always `free`); **entitlement** (who, from whom, why, until when, revoked or not; origin one of creator direct, batch rule, delegate, promotion, externally fulfilled); batch membership; My Study enrollment; authorship. A batch grants content only through an explicit entitlement rule. Admin override is an audited emergency action. Enforcement must be in RLS and `get_browsable_*` together, not only in screens. `account_type` stays as the platform "full content access" flag during the transition (240 enrolled, 16 Tier B students, RUN 7); the entitlement model starts empty and existing grants are migrated by a separate reviewed step.

## 9. Draft dialogue wording (for audit)
- Join page, signed in, not a member: "Request to join <batch> (<course> · <institution>). Your admin will review your request."
- After requesting: "Request sent to <institution>. You'll get a notification when it's reviewed."
- Already a member: "You're already in <batch>."
- Rejected or removed, on reopening the link: "Your request to join <batch> isn't active. Contact your institute, or send a new request."
- Approved: "You're in <batch>. You can now see this batch's shared content." For a Tier B student, add: "Some professor content needs separate access. Request it here."
- Removed (notification): "You've been removed from <batch>. Your study history is kept."
- Access wall (replaces "Full access coming soon"): "This content needs access from its creator or your institute. Request access", with the form prefilled from the profile.
- Professor on a batch link: "Batch access for professors is set by an admin. Ask your admin to assign you."
- Invite not available (any invite failure): "This invite isn't available for your account."

## 10. What the SQL would have to include (no SQL written)
The invite table with a UNIQUE token and the create, list and revoke functions; the events relation with its immutability guard and read functions; the widened membership status set and the invite reference; rewritten writers (section 6.6) that preserve rows, write events and take the lock order; a hardened `remove_group_member` (platform admins allowed, reason required, archived batch refused); `enroll_user_in_batch_group` returning an outcome instead of `void`; the single eligibility function; the access-request columns, index and rewritten `submit_access_request`, `link_access_request` (student branch), `admin_grant_access` and the admin matching functions (section 4); the reader audit of 6.7; the privilege closure of 6.8.
**Acceptance tests, to be run as real roles in a later gate:** attacker submits a victim's email and the victim's later request is still stored; a forwarded token claimed by a second account stays unconfirmed and cannot grant, close or merge; confirmed-email match produces an authoritative link; closure uses only authoritative links or the explicit selection; authenticated duplicate collapse and the unique index; anonymous repeats all stored and grouped; throttled notifications; token collision and uniqueness; wrong-recipient and second-account use of a recipient-bound invite; expiry at the boundary; revoke between preview and join; concurrent revoke versus join in both orders; concurrent approvals; duplicate requests; repeated remove, leave and rejoin cycles; rejected and removed re-requests with history; a stale row not granting access and not exposing an invite token; single and bulk eligibility parity; lock-order deadlock tests; existing shared links still working after migration.

## 11. Decisions for the Founder (none requested until QA has audited this file)
- **D1.** Labelled invites with expiry and revoke, recipient binding optional; each request attempt linked to its invite through the events relation. Recommend yes.
- **D2.** No push notification on rejection (the Founder's earlier rule), but rejection is a durable state with history, so the student sees the "isn't active" message on reopening the link and the admin sees the earlier attempt. Needs a Founder choice.
- **D3.** Pending list: show the student's course and via-label always; the student's email only on an explicit admin "details" action. Recommend yes.
- **D4.** Approving a Tier B student into a batch: allow, with a banner "needs content access", through one server-enforced eligibility rule used by single Add, bulk Add, approve and bulk approve. Recommend yes.
- **D5.** Replace the "Full access coming soon" wording as drafted and prefill the form. Recommend yes.
- **D6.** Use "creator-granted / externally fulfilled" wording only. Recommend yes.
- **D7.** A rejected student may re-request immediately, with history visible to the admin; no cooldown in v1. Recommend yes.
- **D8.** Students see only event kind, time and batch name, never reason or actor. Recommend yes.
- **D9 (new).** Anonymous requests are never deduplicated; the admin sees them grouped, with notification throttling. Recommend yes.

## 12. Gate 1 prerequisites and OPEN items
Before this brief goes to the Founder for Gate 1: the follow-up diagnostic (RUN F1, F2, F4, F7, F8) must be audited by QA, authorized by the Founder by its hash, run, and its evidence audited, **or** an explicit target deny/allow rule with real-role acceptance tests must replace the open facts. OPEN: whether the Tier B lock is enforced in row-level security or `get_browsable_*`; whether a suspended account can reach and use the join functions; effective table privileges on `study_group_members`, `study_groups`, `admin_audit_log`, `access_requests`; whether column privileges hide `invite_token`. Retention and erasure of event rows, reason-text privacy, and invite lifecycle details are later-gate items. The Educators flow and institute inquiries are outside this brief; the bearer-token nature of the educator claim in `link_access_request` is noted for a separate security review.
