# RevisOp pre-8.8.6 backlog tracker

One page, kept by Claude, updated in every round that changes a status. Numbers are the Founder's own (message of 02/10/2026) plus the items added later. If this page and a thread disagree, tell Claude: the page is wrong until fixed.
Last updated: 10/10/2026 (T-002 Round 117).

## A. The Founder's points

| # | Point (short) | Status | Where | What is left | Waiting for |
|---|---|---|---|---|---|
| 1 | Remove students from a batch group | PENDING (design approved) | brief A v13 (v14 to write) | SQL, frontend, tests | brief A thread (T-003) |
| 2 | Know which student joined with which invite | PENDING (design approved) | brief A | same | T-003 |
| 3 | Review all admission steps and dialogs | PENDING (design approved) | brief A | build and live checks | T-003 |
| 4 | Content access given by the creator, not the admin | PENDING (design approved, no in-app payment in v1) | brief A (slice 3) | build | T-003 |
| 5 | Progress by course (current course first) | IN PROGRESS | T-002, brief B v10 | B-04b, B-06b, B-06c, F2 screen | B-04b (after 13/10/2026) |
| 6 | Red badge on Review stays | DONE 07/10/2026 | T-001 slice 1 (C-03) | nothing | - |
| 7 | Heatmap shows in-app and offline time | DONE 07/10/2026 | T-001 slice 1 (C-03) | live checks not done: time zone west of UTC, touch device, screen reader | - |
| 10 | Course and subject on offline study logs | ALMOST DONE | T-002, brief B v10 | B-04b cutover, test 7.6, then closure | end of observation, evening 13/10/2026 |

Numbering note: point 10 was added during T-001 (the records say "seven-point backlog plus point 10"). I cannot find a point 8 or 9 anywhere in the records. The admin-screen items 2.6 to 2.10 of T-001 were proposed as a possible "point 11"; the Founder has not decided.

## B. Items that belong to no numbered point (so they do not get lost)

| Item | Status | Next step |
|---|---|---|
| Subject Mastery table shows 7 subjects incl. Business Laws (24 due) after a course round trip (`get_subject_mastery_v1`) | UNEXPLAINED | look at it with point 5 (F2) |
| QA's two test additions (save equals preview; failed-preview retry) | CARRIED | add with the next frontend change |
| Stale-tab residual (tab opened before 09/10/2026 23:27 IST, never refreshed) | OPEN, Founder decision needed before B-04b Gate 3 | decision at end of window |
| Simultaneous save at the cutover instant | NOT COVERED, Founder decision before Gate 3 | decision at end of window |
| Optional reload-on-chunk-error handler for stale tabs | IDEA, not decided | decide with the stale-tab residual |
| Professor course switcher for students (bottom left) | DEFERRED by the Founder 10/10/2026 | only if asked again |
| Supabase log-volume fix (badge polling every 30 s, per-deck upvote lookups) | DEFERRED; Claude must remind the Founder BEFORE T-003 starts | reminder at T-003 start |
| Remove all T-002 test rows (one cleanup SQL file) | WAITING for all T-002 tests | end of T-002 |
| Draft worktree `recall-app-f1` | still on disk | remove safely (delete the node_modules junction first) |

## C. Order of work (Founder, T-001)
Step 0, then two design streams, then 6+7 (done), 10 (almost), 1+2, 8.8.6, 5, 4. T-002 delivers 10 and 5. Brief A (1 to 4) is the next thread. 8.8.6 scope is locked (D-38): none of these points are absorbed into it.
