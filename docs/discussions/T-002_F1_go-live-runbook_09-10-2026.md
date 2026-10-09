# T-002 F1 go-live runbook (09/10/2026)

Plain-language steps for putting F1 live and testing it. **Nothing here runs until you say so.** Plan v18 section 5.2 is the authority; this file only orders the steps. The Founder is the sole approver: pushing is Gate 6 and the live tests are Gate 7.

## 0. What goes live, and what does not
- **Goes live when you push:** commit `6afed64` (F1: the course screens and the study-log picker). Hosting is Vercel, which deploys automatically from GitHub, so **the push is the promotion**.
- **Does not change:** the database (B-01 to B-06a are already live). Students see no change until the push.
- **If something goes wrong:** the go-back is a "revert" commit of `6afed64` pushed to GitHub (about 2 minutes). The database stays as it is: it accepts logs with or without a course until a later step (B-04b) makes the course compulsory, so the old screens keep working after a go-back.

## 1. What I need from you before we start
1. **A quiet time** (a time when few students log study time; the snapshot before and after the push should be a few minutes apart). Tell me the date and time.
2. **Two different browsers** you can sign in with in the test account (for example Chrome and Edge), both on the live site. Below they are **Browser A** and **Browser B**. They must be different browsers (not two tabs of one), because a browser keeps one saved copy of the timer for the whole site.
3. **The test account.** The account called "TestOutlook" in the plan: the test student account you already used for the Profile Settings check (name `Anand Testing T002`, saved course `CFA Level 1`). Tell me its e-mail address when you run the checking query (section 6); I never need its password.
4. Your acceptance of the **test rows** this creates (study logs, one access request, one new sign-up). They are removed at the very end of T-002, as before.

## 2. Rehearsal now (no waiting, safe to do today)
The snapshot tool has never been run, so do one practice run before the real night:
1. Open `docs/database/t002/CURRENT.md` and find the row **D-07**. Check the file name `D-07_DIAGNOSTIC_D7_manual-null-snapshot_v1.sql` and the first 12 characters of its sha256.
2. In the Supabase SQL Editor, run **RUN S** (select from its banner line to its closing `;`). Copy the single result cell.
3. Save it as `docs/discussions/evidence/T-002_D7-rehearsal-summary_<dd-mm-yyyy>.raw.txt`.
4. Check inside it: `"tool_version":"D7-v1"`, `"columns_match":true`, a `set_count` (about 1,300), and `pages_needed` (about 3).
5. Run **RUN P1** too and save the grid as `docs/discussions/evidence/T-002_D7-rehearsal-pages_<dd-mm-yyyy>.raw.txt` (500 rows of id and a long fingerprint).
Tell me "rehearsal saved". If anything errors, save the text and send it; do not edit and re-run.

## 3. Before the push (old version still live)
Do all of this **before** step 4, because it needs the old screens.

**3.1 Prepare the "pending log" state in Browser A.**
1. In Browser A, sign in to the live site as the test account. Open Study Timer (the page `/dashboard/study-time`). Press **Start**.
2. Press F12, open the **Console** tab, paste this one line and press Enter (it pretends the timer started 15 minutes ago, because logs under 10 minutes are not saved):
   `localStorage.setItem('revisop_manual_timer_started_at', new Date(Date.now()-15*60000).toISOString()); location.reload()`
3. The timer now shows about 15 minutes. Press **Stop**. The old screen asks "What were you studying?" with category buttons. **Do not choose anything. Do not press Save.** Close that browser tab (do not sign out, do not clear site data).
4. This leaves an unconfirmed log saved inside Browser A. We will use it in test 7.4.

**3.2 Prepare the "old tab" state in Browser B.**
1. In Browser B, sign in as the same test account and open Study Timer. Press **Start**, then do the same one line from 3.1 step 2 (it reloads the page once; this is the last reload this tab is allowed).
2. Leave this tab open on the timer page, running, and **never reload or navigate it** until test 7.5. Do not let the computer sleep.

**3.3 Check the starting point.** Tell me when 3.1 and 3.2 are done. I will check `CURRENT.md`, that `6afed64` is the commit being pushed, that the tests and the build are green on main, and then I ask you for **Gate 6** with the exact commit hash.

## 4. The push (Gate 6) and the snapshots
Gate 6 is a separate approval, asked in the chat with the exact commit. After you give it:
1. **S0 (immediately before the push).** Run the D-07 tool: **RUN S**, then **RUN P1, P2, P3** (as many as `pages_needed` says). Save the summary as `docs/discussions/evidence/T-002_S0-summary_<dd-mm-yyyy>.raw.txt` and the pages, in order, as `docs/discussions/evidence/T-002_S0-pages_<dd-mm-yyyy>.raw.txt`. Write down the clock time of your own computer when you pressed Run on RUN S (hh:mm:ss).
2. **Push.** I run the push of local main to GitHub (you only watch). Vercel starts building.
3. **Wait until Vercel says Ready.** In the Vercel dashboard (project, Deployments), open the newest deployment: it must show the commit `6afed64`-or-later hash I give you and the status **Ready**. Write down the deployment's **Ready time** exactly as Vercel shows it, with its time zone. That is the "served time".
4. **S1 (immediately after Ready).** Run **RUN S** again and save it as `docs/discussions/evidence/T-002_S1-summary_<dd-mm-yyyy>.raw.txt`. Write down your computer's clock time again.
5. **Compare.** Count, total minutes and the overall hash in S1 must equal S0. If they are equal, S0 is the fixed "anchor set" and no pages are needed for S1. **If they differ, stop and send both files to me.** A difference means a student saved an old-style log during the push; it is never treated as old data by default, and I will take it to you as a decision (plan 5.2).

I record in the run record: the two summaries' database clock times (the tool prints them in UTC), your computer's clock times, Vercel's Ready time, and a skew margin. Proposed margin for QA: 2 minutes, because the hosting and database clocks are both network-time synchronised; a log whose creation time falls within 2 minutes of the served time counts as unresolved, not as old.

## 5. Quick safety check right after Ready (2 minutes)
In a **private window** (not signed in): open the live Signup page. The course list must appear (the same courses, then "+ Add custom course"). If it shows "Courses could not be loaded", stop and tell me: that is the neutral state and means the new screens cannot reach the database; I decide with you whether to go back (section 0).

## 6. Gate 7: the live tests (in this order)
After each group, run the checking query `docs/database/t002/F1_VERIFY_gate7-test-sessions_v1.sql` (replace `REPLACE-WITH-TEST-ACCOUNT-EMAIL` once with the test account's address), copy the single result cell and save it as `docs/discussions/evidence/T-002_F1-gate7-<step>_<dd-mm-yyyy>.raw.txt` with the step name given. It shows only that test account's logs.

**7.1 Signup** (a real new sign-up, with an e-mail you control; tell me which alias you used). In a private window open Signup: the list matches section 5. (a) Choose "+ Add custom course", type `  CFA Level 2  ` (with spaces) and sign up; confirm the e-mail and sign in. In Profile Settings the course must read `CFA Level 2 (current)` without the spaces. (b) Sign out, and also try typing a 121-character course: the form must refuse it with a message before sending. Save nothing for 7.1 beyond telling me the result.

**7.2 Profile Settings** (test account). (a) The course shows with "(current)" if it is a custom one. (b) Choose "Other, type your own", type `ACCA`, press Save Changes; a confirmation about moving cards appears; confirm. Reload: the course reads `ACCA (current)`. (c) Change it back the same way to `CFA Level 1`. (d) Choose "Other", type `ca   final` (odd spacing and lower case): after saving it must be stored as `CA Final` (the database's exact name). Then set it back to `CFA Level 1`. Say what you saw.

**7.3 Access form** (the form on a note or deck preview: open a public note while **not signed in**, and again signed in as the test account). (a) Not signed in: the list is the public list. (b) Signed in: your current course is already selected. (c) Submit once while signed in with a typed course ` CFA Level 1 ` (spaces): you should see the thank-you message. Save the checking query output as step `7-3` (it does not show access requests; I check that row myself afterwards).

**7.4 Study-log picker, including the saved pending log.**
1. **Restored pending log (Browser A).** Open the live site in Browser A (the one prepared in 3.1), signed in as the test account, and go to Study Timer. The unconfirmed log must appear with the new **Course** row above the category buttons, with your current course already chosen. Choose a category and press **Save**. Run the checking query: the newest row must have a classification (platform or custom), **not empty**. *If that row shows an empty classification, F1 has failed this test: stop and tell me.* Save as step `7-4-restored`.
2. **New log in Browser A, platform course.** Start, use the one line from 3.1 step 2, Stop. Change the course to a platform course (for example CA Final), choose a subject from the list (or leave Skip), choose a category, Save. Check: classification `platform` with the course and subject names. Save as step `7-4-platform`.
3. **General.** Another log: choose **General**, a category, Save. Check: classification `general`, no course. Step `7-4-general`.
4. **Typed course and subject.** Another log: **Other...**, type `ACCA`, type a subject `Taxation`, a category, Save. Check: `custom` with label `ACCA`, subject label `Taxation`. Then another log: the course list now offers **ACCA** under earlier courses, and the subject list offers **Taxation**. Step `7-4-custom`.
5. **A failed save.** (Optional) turn off the internet, Save: a message says it was not saved and the log is kept; turn the internet on, Save again.

**7.5 Stale old tab (Browser B, the tab prepared in 3.2, never reloaded).** Press **Stop** in that tab, choose a category, Save. By design the old screen stores a log **without a course**. Run the checking query now: `account_manual_null_last_24h` must contain **exactly one** row. Write down its `id` (I record it). Step `7-5-stale`. Then reload Browser B: the new screens appear.

**7.6 Final comparison.** I compare the manual-without-course set (summary in the last query) with S0: it must equal S0 **plus exactly the one row from 7.5** (nothing else was added). Everything saved in 7.4 was classified, so none of it counts.

## 7. What I do after your results
- Record the evidence and the run record (served time, clock samples, the test row id) in the thread; then Gate 7 is complete only if 7.4 step 1 and 7.5 gave exactly the expected results.
- The extra row from 7.5 is removed later by the separately reviewed data-fix file (plan 5.2 step 3), then the observation period, then B-04b.
- The test rows (study logs of 7.4, the access request of 7.3, the new account of 7.1) go on the cleanup list for the end of T-002.

## 8. Stop rules
- Any error from a SQL file: save the error, do not edit and re-run, tell me.
- S1 differs from S0: stop (section 4, step 5).
- Section 5 shows the neutral state, or test 7.4 step 1 shows an empty classification: stop and tell me; we decide whether to go back (section 0).
- Never clear site data or sign out in Browser A or B between 3.1 and 7.5.
