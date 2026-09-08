# Design Review — Screenshot Checklist (for ChatGPT + Gemini critique)

**Purpose:** Capture every meaningful page (public + post-login, all roles) and feed the screenshots directly to ChatGPT + Gemini for an external design critique BEFORE Phase 6 (dashboard reskin).
**Prepared:** 04/07/2026 · **Updated:** 05/07/2026 (switched from single-PDF to direct image upload — PDF shrank images below legibility)
**Live URL:** https://www.recallapp.co.in

## How to capture
- **Two widths each:** Desktop **1280px** wide (GoFullPage extension), Mobile **390px** wide (Chrome DevTools → iPhone 12 Pro preset → ⋮ → *Capture full size screenshot*). Portrait only, no rotation.
- **Full page** in both cases — GoFullPage/DevTools give you the whole scroll in one image. Don't downscale.
- **Show real content**, not empty states, wherever you have seeded data.
- Save each image as a `.png` and **rename it to the filename in the tables below.** The number forces upload order; the name tells the model what it's looking at.

## Naming convention
`NN-role-page-width.png` — e.g. `01-public-landing-desktop.png`, `12-student-dashboard-mobile.png`.
Each page has **two files** (desktop + mobile) sharing the same number, so both widths of a page sit together in order.
- **Tall landing page:** if one image is too big, slice into `01-public-landing-desktop-1.png`, `-2.png`, `-3.png` (and same for mobile).
- **Review session** has two states — use `16-student-review-session-question-*.png` and `16-student-review-session-answer-*.png`.

## Don't use a PDF — upload the images directly
The PDF route shrank the full-page captures until the text was unreadable. Feed the renamed images straight to each model instead — they keep native resolution.
- **Neither model has true "folder upload," but you don't need it** — in the file picker, `Ctrl+A` / `Ctrl+click` to multi-select all images at once.
- **Gemini → use Google AI Studio (aistudio.google.com), not the consumer app.** Free, large context, swallows all ~40 images in one prompt. This is the better bulk pass.
- **ChatGPT → upload in section batches** within one conversation (~10 images/message is the safe cap): public → student → professor → admin, then send the critique prompt last. It remembers earlier images in the thread.
- **Roles:** log in as three account types to capture everything — a **Student**, a **Professor** (educator), and a **Super Admin**.

**Confirmed 12/07/2026 — PDFs really do fail, ZIPs of native PNGs work:** tried uploading the two-PDF variant (Prompt B2) to ChatGPT first; it correctly refused, saying the rendered pages were too low-res to judge spacing/contrast/tap targets. Re-uploaded as two ZIPs (`RevisOp-LoggedIn-Desktop.zip` / `-Mobile.zip`, one per width, containing the same PNGs at native resolution) and it accepted them. ChatGPT briefly hedged a second time claiming filenames "didn't correspond" to the page order — they do; the numeric prefix on each filename (`12-student-dashboard-desktop.png`, etc.) already encodes the page map, so no separate mapping doc is needed when using this ZIP approach. If a model stalls a second time after receiving native-resolution files, explicitly tell it to sort by filename and commit to delivering the review in that same response.

---

## SECTION 1 — Public pages (no login) · PRIORITY
Anonymous visitor. This is your conversion surface — highest design stakes.

> **⚠️ Known nav inconsistency to point reviewers at (don't silently fix before the review — it's a valid finding):** the landing nav has TWO educator links. **"For Educators"** scrolls to an on-page anchor section (`/#educators`); **"For Institutes"** navigates to a separate page (`/educators`). Both destinations carry the *same* heading "For Institutes & Educators", and the labels feel swapped. The anchor section is captured as part of #01 (full landing scroll); the standalone page is #02. Flag this IA overlap explicitly in the critique prompt.

| # | Page | Route | Desktop filename | Mobile filename |
|---|------|-------|------------------|-----------------|
| 01 | **Landing** ⭐ | `/` | `01-public-landing-desktop.png` | `01-public-landing-mobile.png` |
| 02 | For Institutes & Educators _(one page — capture FULL scroll: institute inquiry section **and** educator application section)_ | `/educators` | `02-public-educators-desktop.png` | `02-public-educators-mobile.png` |
| 03 | Student Guide | `/guide` | `03-public-guide-desktop.png` | `03-public-guide-mobile.png` |
| 04 | Login | `/login` | `04-public-login-desktop.png` | `04-public-login-mobile.png` |
| 05 | Signup | `/signup` | `05-public-signup-desktop.png` | `05-public-signup-mobile.png` |
| 06 | Forgot Password | `/forgot-password` | `06-public-forgot-password-desktop.png` | `06-public-forgot-password-mobile.png` |
| 07 | Public Deck Preview | `/deck/:deckId` | `07-public-deck-preview-desktop.png` | `07-public-deck-preview-mobile.png` |
| 08 | Public Note Preview | `/note/:noteId` | `08-public-note-preview-desktop.png` | `08-public-note-preview-mobile.png` |
| 09 | Group Join _(optional)_ | `/join/:token` | `09-public-group-join-desktop.png` | `09-public-group-join-mobile.png` |
| 10 | Terms of Service _(optional)_ | `/terms-of-service` | `10-public-terms-desktop.png` | — |
| 11 | Privacy Policy _(optional)_ | `/privacy-policy` | `11-public-privacy-desktop.png` | — |

---

## SECTION 2 — Student (logged in as a normal student) · PRIORITY
The core daily-use surface. This is what Phase 6 reskins.

| # | Page | Route | Desktop filename | Mobile filename |
|---|------|-------|------------------|-----------------|
| 12 | **Student Dashboard** ⭐ | `/dashboard` | `12-student-dashboard-desktop.png` | `12-student-dashboard-mobile.png` |
| 13 | Navigation / menu | — | `13-student-navigation-desktop.png` | `13-student-navigation-mobile.png` |
| 14 | **Study Mode** ⭐ | `/dashboard/study` | `14-student-study-mode-desktop.png` | `14-student-study-mode-mobile.png` |
| 15 | Review Flashcards (due list) | `/dashboard/review-flashcards` | `15-student-review-flashcards-desktop.png` | `15-student-review-flashcards-mobile.png` |
| 16 | Review Session (front + back) | `/dashboard/review-session` | `16-student-review-session-desktop.png` | `16-student-review-session-mobile.png` |
| 17 | Review by Subject | `/dashboard/review-by-subject` | `17-student-review-by-subject-desktop.png` | `17-student-review-by-subject-mobile.png` |
| 18 | My Flashcards (Study Sets) | `/dashboard/flashcards` | `18-student-my-flashcards-desktop.png` | `18-student-my-flashcards-mobile.png` |
| 19 | **Create Flashcard** ⭐ | `/dashboard/flashcards/new` | `19-student-create-flashcard-desktop.png` | `19-student-create-flashcard-mobile.png` |
| 20 | My Notes | `/dashboard/my-notes` | `20-student-my-notes-desktop.png` | `20-student-my-notes-mobile.png` |
| 21 | Browse Notes | `/dashboard/notes` | `21-student-browse-notes-desktop.png` | `21-student-browse-notes-mobile.png` |
| 22 | Note Detail | `/dashboard/notes/:id` | `22-student-note-detail-desktop.png` | `22-student-note-detail-mobile.png` |
| 23 | Note Upload / New | `/dashboard/notes/new` | `23-student-note-upload-desktop.png` | `23-student-note-upload-mobile.png` |
| 24 | My Contributions | `/dashboard/my-contributions` | `24-student-my-contributions-desktop.png` | `24-student-my-contributions-mobile.png` |
| 25 | **Progress** ⭐ | `/dashboard/progress` | `25-student-progress-desktop.png` | `25-student-progress-mobile.png` |
| 26 | Achievements / Badges | `/dashboard/achievements` | `26-student-achievements-desktop.png` | `26-student-achievements-mobile.png` |
| 27 | Author / Public Profile | `/dashboard/profile/:userId` | `27-student-author-profile-desktop.png` | `27-student-author-profile-mobile.png` |
| 28 | Profile Settings | `/dashboard/settings` | `28-student-profile-settings-desktop.png` | `28-student-profile-settings-mobile.png` |
| 29 | Find Friends | `/dashboard/find-friends` | `29-student-find-friends-desktop.png` | `29-student-find-friends-mobile.png` |
| 30 | My Friends _(optional)_ | `/dashboard/my-friends` | `30-student-my-friends-desktop.png` | `30-student-my-friends-mobile.png` |
| 31 | Following _(optional)_ | `/dashboard/following` | `31-student-following-desktop.png` | `31-student-following-mobile.png` |
| 32 | Friend Requests _(optional)_ | `/dashboard/friend-requests` | `32-student-friend-requests-desktop.png` | `32-student-friend-requests-mobile.png` |
| 33 | My Groups | `/dashboard/groups` | `33-student-my-groups-desktop.png` | `33-student-my-groups-mobile.png` |
| 34 | Group Detail | `/dashboard/groups/:groupId` | `34-student-group-detail-desktop.png` | `34-student-group-detail-mobile.png` |
| 35 | Create Group _(optional)_ | `/dashboard/groups/new` | `35-student-create-group-desktop.png` | `35-student-create-group-mobile.png` |
| 36 | Help _(optional)_ | `/dashboard/help` | `36-student-help-desktop.png` | `36-student-help-mobile.png` |

---

## SECTION 3 — Professor / Educator (logged in as an educator)
Only the pages that differ from a student, plus professor-only tools.

| # | Page | Route | Desktop filename | Mobile filename |
|---|------|-------|------------------|-----------------|
| 37 | **Professor Dashboard** ⭐ | `/dashboard` | `37-professor-dashboard-desktop.png` | `37-professor-dashboard-mobile.png` |
| 38 | **Professor Analytics** ⭐ | `/dashboard/professor-analytics` | `38-professor-analytics-desktop.png` | `38-professor-analytics-mobile.png` |
| 39 | Bulk Upload Flashcards | `/dashboard/bulk-upload` | `39-professor-bulk-upload-desktop.png` | `39-professor-bulk-upload-mobile.png` |

---

## SECTION 4 — Admin / Super Admin (logged in as super admin)
Internal, but still worth a consistency pass.

| # | Page | Route | Desktop filename | Mobile filename |
|---|------|-------|------------------|-----------------|
| 40 | Admin Dashboard | `/admin` | `40-admin-dashboard-desktop.png` | `40-admin-dashboard-mobile.png` |
| 41 | Admin Analytics | `/admin/analytics` | `41-admin-analytics-desktop.png` | `41-admin-analytics-mobile.png` |
| 42 | Super Admin Dashboard | `/super-admin` | `42-superadmin-dashboard-desktop.png` | `42-superadmin-dashboard-mobile.png` |
| 43 | Super Admin Analytics | `/super-admin/analytics` | `43-superadmin-analytics-desktop.png` | `43-superadmin-analytics-mobile.png` |
| 44 | Bulk Upload Topics _(optional)_ | `/admin/bulk-upload-topics` | `44-admin-bulk-upload-topics-desktop.png` | `44-admin-bulk-upload-topics-mobile.png` |

---

## SKIP (don't screenshot)
- `/__design` — dev-only design-system showcase, not user-facing
- `/admin/migrate-note-images` — temp migration tool, being deleted
- `/professor/tools`, `/notes/edit/:id` — pure redirects
- `/reset-password` — only reachable from an email link
- `/dashboard/notes/edit/:id` — same editor as Note Upload (#23), redundant

---

## Review plan — sequencing & tooling (decided 05/07/2026)

**Two separate reviews, not one.** Public and logged-in pages have different jobs, so mixing them muddies the critique:
- **Public pages (01–11)** = convert a stranger in 5 seconds → run this FIRST (it's captured, and the landing sets the visual language Phase 6 will follow).
- **Logged-in app (12–44)** = help a committed user study efficiently → run as a SECOND thread once Sections 2–4 are captured.

**Tooling decision:**
- **Gemini** — use the **Gemini app** (gemini.google.com), **Pro model** (not Flash). Your Workspace/Pro plan lives here. *Google AI Studio ignores the subscription (separate free API) and is often admin-blocked — don't bother with it.* Upload caps ~10 images/message → batch within ONE conversation, then send the prompt last.
- **Claude** — second independent voice AND the reconciler (it can see the code + S1 design tokens, so it knows cheap-token-tweak vs. component-rewrite). Run it BLIND first (don't show it Gemini's answer), then hand it Gemini's output to merge.
- **ChatGPT** — skip. Free tier throttles uploads (~3 files/day) — impractical for 11–44 images. *Optional:* reserve its daily quota for the landing page only (3 slices fits).
- **Codex** — NOT for this. It's a coding agent, not a visual critic.
- **Do NOT feed** `FILE_STRUCTURE.md` (irrelevant to a visual critique) or `blueprint.md` (internal SSOT — pasting it into a 3rd-party LLM leaks strategy/DB details for zero design benefit). Use the short context brief below instead.

**Keep the two models independent** (anchoring is the risk): run Gemini and Claude separately on the same screenshots, then let Claude reconcile both into one ranked punch-list for the Phase 6 sprint.

### Context brief (prepend to whichever prompt — all public/harmless)
```
Context: RevisOp is a course-agnostic spaced-repetition revision tool (SM-2).
Current beta cohort: ~162 commerce/professional-exam students and 3 expert
educators in India. Three audiences: students (free), individual educators,
and institutes (batch onboarding). We're about to reskin the logged-in
dashboard, so I want an honest baseline critique first.
```

### PROMPT A — Public pages (conversion-focused) · run now
```
You are a senior conversion-focused product designer. These are the PUBLIC
(logged-out) pages of RevisOp — a spaced-repetition revision platform for
serious professional-exam candidates. Goal of these pages: convert a first-
time visitor into a signup, and get institutes/educators to enquire.
Brand direction: calm, focused, trustworthy — not gamified or childish.

Images are numbered in order; the filename gives page + width (e.g.
"01-public-landing-mobile"). Landing is 01, the Institutes/Educators page 02,
guide/login/signup/previews follow.

Critique for CONVERSION specifically:
1. First 5 seconds — is the value prop instantly clear on the landing?
2. CTA hierarchy — is the primary action obvious on every page? Competing CTAs?
3. Trust & credibility — social proof; are the claims believable/legible?
4. Nav & IA — is anything confusing? (Note: "For Educators" scrolls to a
   section while "For Institutes" opens a separate page, both titled the same —
   tell me if that hurts.)
5. Mobile — does the landing hold up at 390px? Fold placement?
6. Visual consistency across the public pages.

For each issue: page (by filename), severity (high/med/low), specific fix.
End with the TOP 5 conversion changes ranked by impact-to-effort. Be blunt.
```

### PROMPT A2 — Public pages, TWO-PDF variant for ChatGPT (desktop PDF + mobile PDF)
Use this when uploading two PDFs instead of loose images (fits ChatGPT free's ~3-file/day limit). Pages carry no header labels, so the prompt supplies the page-number → page-name map. Name the files `RevisOp-Public-Desktop.pdf` and `RevisOp-Public-Mobile.pdf` before uploading.
```
You are a senior conversion-focused product designer. I'm the founder of
RevisOp — a course-agnostic spaced-repetition revision tool (SM-2) for
serious professional-exam candidates. Beta cohort: ~162 students and 3 expert
educators in India. Audiences: students (free), individual educators, and
institutes (batch onboarding). Brand direction: calm, focused, trustworthy —
NOT gamified or childish.

I've attached TWO PDFs of the PUBLIC (logged-out) pages — the same 11 pages at
two screen widths:
• PDF 1 = DESKTOP (1280px wide), 11 pages
• PDF 2 = MOBILE (390px wide), 11 pages
Both PDFs are in the SAME page order, so page N in the desktop PDF and page N
in the mobile PDF are the same page. Pages have no headers/labels — use this map:

  Page 1  — Landing / home page
  Page 2  — "For Institutes & Educators" page
  Page 3  — Student Guide
  Page 4  — Login
  Page 5  — Sign Up
  Page 6  — Forgot Password
  Page 7  — Public Deck (Study Set) Preview — the page seen from a shared deck link
  Page 8  — Public Note Preview — the page seen from a shared note link
  Page 9  — Group Join — the landing page from a group invite link
  Page 10 — Terms of Service   (legal/content — low design priority)
  Page 11 — Privacy Policy      (legal/content — low design priority)

The job of these pages is to convert a first-time visitor into a signup, and
to get institutes/educators to enquire. Focus your critique on CONVERSION:

1. First 5 seconds — is the value prop instantly clear on the Landing (page 1)?
2. CTA hierarchy — is the primary action obvious on each page? Any competing CTAs?
3. Trust & credibility — social proof; are the claims believable and legible?
4. Nav & IA — is anything confusing? (Note: in the top nav, "For Educators"
   scrolls to a section on the landing while "For Institutes" opens a separate
   page — and both are titled "For Institutes & Educators". Tell me if that hurts.)
5. Mobile — compare the mobile PDF to desktop: does the layout hold at 390px?
   Is the fold placement right? Anything cramped or broken on mobile?
6. Visual consistency across the public pages (spacing, type scale, colour).

For EACH issue, give: page number + which width (desktop/mobile/both), severity
(high/med/low), and a specific fix. Then end with the TOP 5 conversion changes
ranked by impact-to-effort. Be blunt. Don't flatter. Skip pages 10–11 unless
something is genuinely broken.
```

### PROMPT B — Logged-in app (consistency & task-flow) · run after Sections 2–4 captured
```
You are a senior product designer reviewing the LOGGED-IN experience of
RevisOp — a spaced-repetition revision platform for serious professional-
exam candidates. These users are already committed; the goal is task
efficiency, clarity, and a calm, CONSISTENT daily-use interface (not
conversion). Brand direction: calm, focused, trustworthy — not gamified.

Images are numbered in viewing order; each filename gives page + role +
width (e.g. "12-student-dashboard-mobile"). Student pages 12–36, professor
37–39, admin 40–44.

Critique across:
1. Visual hierarchy — does the eye land on the right thing first per page?
2. Consistency — spacing, type scale, colour, component style ACROSS pages.
   THIS IS THE PRIORITY — flag anything that drifts page to page.
3. Task flow — is the primary action on each page obvious and quick?
4. Information density — too cramped / too sparse for a study tool?
5. Accessibility — contrast, tap targets, readability.
6. Mobile — does each layout hold at 390px?

For each issue: page (by filename), severity (high/med/low), specific fix.
End with the TOP 5 changes ranked by impact-to-effort. Be blunt. Don't flatter.
```

### PROMPT B2 — Logged-in app, TWO-PDF variant (for ChatGPT or Gemini)
Use this when uploading two PDFs instead of loose images. Name the files `RevisOp-LoggedIn-Desktop.pdf` (29 pages) and `RevisOp-LoggedIn-Mobile.pdf` (30 pages) before uploading — **the two PDFs are NOT page-aligned**: the mobile PDF has one extra page (the hamburger nav menu) inserted after the dashboard, so everything from page 3 onward is offset by one versus desktop. Each PDF's own page order matches the numbered map below.

**Captured 12/07/2026.** Student pages use the "TestOutlook" test account (24 reviews done, 67% accuracy, 3 flashcards, 1 note — real activity, not an empty account). The three Review Session pages (subject list / question / answer) were captured on a different test account (the Professor/educator login, which had real due cards) since the student account had nothing due that day — so its stats won't match the Dashboard/Progress numbers elsewhere in the deck. That's a data quirk of how the screenshots were sourced, not a product bug — don't flag the mismatch itself as a finding.

```
You are a senior product designer reviewing the LOGGED-IN experience of
RevisOp — a spaced-repetition revision tool (SM-2) for serious professional-
exam candidates. Beta cohort: ~162 students and 3 expert educators in India.
These users are already committed; the goal is task efficiency, clarity, and
a calm, CONSISTENT daily-use interface (not conversion). Brand direction:
calm, focused, trustworthy — not gamified or childish.

I've attached TWO PDFs of the LOGGED-IN app across three roles (student,
professor, admin/super-admin):
• PDF 1 = DESKTOP (1280px wide), 29 pages
• PDF 2 = MOBILE (390px wide), 30 pages
These are NOT page-aligned — the mobile PDF has one extra page (the mobile
nav menu) after the dashboard, so page N in mobile ≠ page N in desktop from
that point on. Use the two page maps below, not a shared one.

DESKTOP PDF page map (29 pages):
 1  Dashboard
 2  Study Mode — question
 3  Study Mode — answer
 4  Review Flashcards (due list)
 5  Review Session — subject picker ("Today's Reviews")
 6  Review Session — question
 7  Review Session — answer
 8  Review by Subject
 9  My Flashcards (Study Sets)
10  Create Flashcard
11  My Notes
12  Browse Notes
13  Note Detail
14  Note Upload
15  My Contributions
16  Progress
17  Achievements
18  Author / Public Profile
19  Profile Settings
20  Find Friends
21  My Groups
22  Group Detail
23  Professor Dashboard
24  Professor Analytics
25  Professor Bulk Upload
26  Admin Dashboard
27  Admin Analytics
28  Super Admin Dashboard
29  Super Admin Analytics

MOBILE PDF page map (30 pages):
 1  Dashboard
 2  Navigation — mobile hamburger menu open
 3  Study Mode — question
 4  Study Mode — answer
 5  Review Flashcards (due list)
 6  Review Session — subject picker ("Today's Reviews")
 7  Review Session — question
 8  Review Session — answer
 9  Review by Subject
10  My Flashcards (Study Sets)
11  Create Flashcard
12  My Notes
13  Browse Notes
14  Note Detail
15  Note Upload
16  My Contributions
17  Progress
18  Achievements
19  Author / Public Profile
20  Profile Settings
21  Find Friends
22  My Groups
23  Group Detail
24  Professor Dashboard
25  Professor Analytics
26  Professor Bulk Upload
27  Admin Dashboard
28  Admin Analytics
29  Super Admin Dashboard
30  Super Admin Analytics

Known data quirk (don't flag as a finding): the Review Session pages (both
PDFs, pages 5-7 desktop / 6-8 mobile) were captured on a different test
account than every other page, so its numbers won't match the Dashboard or
Progress pages elsewhere in the deck. Ignore that inconsistency — it's a
screenshot-sourcing artifact, not a product bug.

Critique across:
1. Visual hierarchy — does the eye land on the right thing first per page?
2. Consistency — spacing, type scale, colour, component style ACROSS pages
   and ACROSS the two widths. THIS IS THE PRIORITY — flag anything that
   drifts page to page or breaks between desktop and mobile.
3. Task flow — is the primary action on each page obvious and quick? Does
   the Study Mode → Review Session → grading flow feel coherent as a whole?
4. Information density — too cramped / too sparse for a study tool?
5. Accessibility — contrast, tap targets (mobile especially), readability.
6. Mobile — does each layout hold at 390px? Anything cramped, cut off, or
   broken (check especially for clipped button labels or overflow text)?

For EACH issue: page number + which PDF (desktop/mobile/both), severity
(high/med/low), and a specific fix. Then end with the TOP 5 changes ranked
by impact-to-effort. Be blunt. Don't flatter.
```
