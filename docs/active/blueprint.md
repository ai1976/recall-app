# RevisOp — Complete Project Blueprint
**Prepared:** June 26, 2026 | **Based on:** Full codebase audit + documentation review
**Status:** Pre-rebrand (currently live as Recall / recallapp.co.in)
**Prepared for:** Quality auditor handoff

---

## 1. What Is This Product

**RevisOp** (Revision Operating System) is a web-based spaced-repetition study platform serving both B2C students and B2B institutions (coaching classes, colleges). It is **not** CA-specific — the current beta cohort happens to be CA/CMA/CS students from the founder's coaching class.

**Core proposition:** Students review flashcards and notes using SM-2 spaced repetition; the system schedules what to study each day so nothing is forgotten. Professors/educators publish content; students consume it. Institutions can onboard entire batches and monitor engagement.

**Live URL:** `https://www.recallapp.co.in` (being migrated to `https://www.revisop.com`)

**Current scale (June 2026):** 161 active students, 3 expert educators, 2,182 flashcards, 128 notes. ~130 more students expected imminently.

---

## 2. Tech Stack (Verified from package.json)

| Layer | Technology | Version |
|-------|-----------|---------|
| Frontend framework | React | 19.2.0 |
| Routing | React Router DOM | 7.9.6 |
| Build tool | Vite | 7.2.4 |
| Styling | TailwindCSS | 3.4.1 |
| UI components | Radix UI (Dialog, Dropdown, Select, Switch, Toast, etc.) | various |
| Icons | lucide-react | 0.554.0 |
| Charts | Recharts | 3.8.0 |
| Backend/DB | Supabase (PostgreSQL + Auth + Storage + Realtime + Edge Functions) | 2.84.0 (JS client) |
| Image compression | browser-image-compression | 2.0.2 |
| OCR | tesseract.js | 6.0.1 (in package.json — likely dead dependency, useOCR.js deleted) |
| Command palette | cmdk | 1.1.1 |
| Deployment | Vercel | — |
| Email | Google Workspace SMTP via Supabase auth settings | hello@recallapp.co.in |
| Push notifications | Web Push API + VAPID + Supabase Edge Functions | — |
| Error tracking | Not integrated (mentioned in Privacy Policy only) | — |
| Analytics | Not integrated (mentioned in Privacy Policy only) | — |

---

## 3. User Roles

| Role | Who | Access |
|------|-----|--------|
| `student` | Learners | Dashboard, review, notes, social features |
| `professor` | Educators | All student features + content publishing + analytics |
| `admin` | Platform staff | All professor features + user management + moderation |
| `super_admin` | Founder | Full platform control including role assignment and hard delete |

Sub-types within students:
- `self_registered` (Tier B) — can preview first 10 cards of professor decks only
- `enrolled` (Tier A) — full access, added by admin when batch access is granted

---

## 4. Architecture

### Frontend
- **React 19 SPA** served via Vercel
- **React Router v7** — all routing client-side, with a Vercel Edge Middleware (`middleware.js`, root-level) that intercepts `/deck/:deckId` and `/join/:token` bot requests to inject Open Graph meta tags for WhatsApp link previews
- **`@/` path alias** for all imports
- **PageContainer** wrapper component controls page width (full/medium/narrow)
- **AuthContext** — global auth state, session management
- **CourseContext** — active course selection for multi-course users (professors)

### Backend
- **Supabase PostgreSQL** — all data
- **Row Level Security (RLS)** — enabled on all tables; all public-facing data served via `SECURITY DEFINER` RPC functions (never direct table queries from unauthenticated context)
- **Supabase Auth** — email/password, email confirmation enabled
- **Supabase Storage** — two buckets: `notes` (note images, public read), `flashcard-images` (flashcard images, public read)
- **Supabase Realtime** — enabled on `notifications` table for live bell icon updates
- **Supabase Edge Functions** (Deno) — 5 functions + 2 cron functions + shared utilities

### Infrastructure
- **SMTP:** Google Workspace, `smtp.gmail.com:587`, sender `hello@recallapp.co.in`, configured in Supabase Dashboard auth settings
- **Push notifications:** VAPID keys stored as Supabase secrets; `CRON_SECRET` shared across all cron Edge Functions (rotating it breaks all cron until resynced)
- **pg_cron jobs:** Two scheduled jobs — `daily-review-reminders` (02:30 UTC = 08:00 IST daily) and `cron-daily-study-summary` (every 15 minutes, delivers to users whose local time is 22:00)
- **Vercel env vars:** `SUPABASE_SERVICE_ROLE_KEY` (marked Sensitive), `SUPABASE_URL` — used by `middleware.js`
- **Frontend env vars:** `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, `VITE_VAPID_PUBLIC_KEY`

---

## 5. Complete Feature Inventory

### Public (no login required)
- Landing page (`/`) — hero, feature pitch, institute B2B pitch, live stats, educator profiles
- Student Guide (`/guide`) — 9 situational guides with scroll-spy sidebar
- Login, Signup, Forgot Password, Reset Password
- Terms of Service, Privacy Policy
- Public deck preview (`/deck/:deckId`) — first 5 cards shown; WhatsApp OG tags injected by middleware
- Public group join page (`/join/:token`) — group preview + join flow; WhatsApp OG tags
- Public note preview (`/note/:noteId`) — blurred content preview, auth-aware CTA

### Student Dashboard
- **Dashboard home** — streak, daily reviews stat, anonymous class comparison, study time (today + week), study timer widget, leaderboard (friends/following tabs), goal progress widget, activity feed, onboarding modal (first login), push notification opt-in banner
- **Study mode** — SM-2 spaced repetition review with Skip Topic (24hr), Suspend Card/Topic, Reset Card options; study time auto-logged; 3-tier session recovery for iOS force-quits and mid-session exits
- **Review Flashcards** — browse and launch study sessions by deck; public deck sharing via Web Share API / WhatsApp
- **Review by Subject** — subject-scoped review sessions
- **Progress page** — streak, mastery stats, time-window selector (7d/30d/all), content partition (all vs by course), subject mastery table, question type performance, 90-day study heatmap, due items forecast
- **Browse Notes** — public notes library with course/subject filtering
- **Note Detail** — full note view, upvote, flag, share (public notes via Web Share API)
- **Upload Note** — image upload with compression, subject/topic assignment
- **Edit Note** — in-place editing
- **Create Flashcards** — manual card creation with OCR image capture, subject/topic assignment (FK for system courses, free-text for custom), unsaved work protection (localStorage autosave + beforeunload + navigation guard)
- **Bulk Upload Flashcards** — CSV upload with validation, downloadable error report
- **My Notes** — own notes list
- **My Flashcards** — own decks list (UI label: "Study Sets")
- **My Contributions** — all created content (notes + decks)
- **My Achievements** — badges earned, progress toward unearned
- **Author Profile** — any user's public profile with their content; follow/unfollow button
- **Profile Settings** — name, avatar, course, institution, timezone
- **Study Groups** — create (custom or system-course type), join via link, group content sharing; batch groups visible but read-only for students
- **Find People** — discover students in same course, send friend requests
- **Friend Requests** — accept/decline incoming
- **My Friends** — friend list with stats (streak, reviews this week, study time)
- **Following** — users you follow with stats; unfollow
- **Help** — role-filtered searchable help center (6 tabs for students, 7 for professors/admins)

### Professor Features (additional)
- Professor Analytics (`/dashboard/professor-analytics`) — header stats, per-subject engagement table, weakest/top cards panels, weekly reach bar chart, quality distribution donut chart
- Batch Group performance view in GroupDetail — sortable student stats table (reviews, streak, study time, last active)

### Admin Features (`/admin`)
- Admin Dashboard — platform stats, notes moderation (verify/reject), user access request management (grant/deny), batch group creation, flagged content review (Needs Review card), admin audit log
- Admin Analytics (`/admin/analytics`) — platform overview stats, content health per course, student onboarding funnel, 8-week review bar chart
- Bulk Upload Topics — taxonomy management (subjects/topics)
- MigrateNoteImages — TEMP page (one-time migration, can be deleted)

### Super Admin Features (`/super-admin`)
- Super Admin Dashboard — full user management (search, filter by role/status/activity, hard delete via RPC), role promotion/demotion, retention stats drill-down (new this week / inactive / retained)
- Super Admin Analytics (`/super-admin/analytics`) — header stats, cohort comparison by discipline, creator leaderboard, 52-week platform heatmap, admin activity feed

### Notifications
- **In-app bell** — Realtime-powered; friend requests, follows, group invites, content upvotes
- **Push notifications** — Web Push (browser + PWA); morning review reminders 08:00 IST; nightly study summary 22:00 local; friend events; new content
- **iOS PWA note** — Push on iOS requires "Add to Home Screen"; banner handles this case with instructions

---

## 6. Database — Table Inventory

All tables are RLS-enabled. All public data served via SECURITY DEFINER RPCs.

| Table | Purpose |
|-------|---------|
| `profiles` | Extended user data (role, course, institution, avatar, streak, goals, account_type, status) |
| `profile_courses` | Courses a professor teaches (multi-course support) |
| `disciplines` | Master list of courses (CA Foundation, CA Intermediate, etc.) |
| `subjects` | Subject taxonomy, linked to discipline |
| `topics` | Topic taxonomy, linked to subject |
| `flashcards` | All flashcard content (34 columns incl. question_type, options, hints, scenario, etc.) |
| `flashcard_decks` | Auto-maintained deck groupings (trigger-managed card_count) |
| `notes` | Uploaded notes with visibility, verification status |
| `reviews` | SM-2 review records per user per card (easiness, repetition, interval, next_due) |
| `study_sessions` | Manual timer sessions (duration, session_date as local date) |
| `user_activity_log` | Daily review counts for heatmap |
| `user_stats` | Badge counter aggregates |
| `follows` | Follow graph (follower_id → followee_id) |
| `friendships` | Friend request lifecycle (pending/accepted) |
| `study_groups` | Groups (batch/system_course/custom type), invite tokens |
| `study_group_members` | Group membership |
| `notifications` | In-app notifications (Realtime-enabled) |
| `badge_definitions` | Badge catalog |
| `user_badges` | Awarded badges |
| `push_subscriptions` | Device push endpoints (is_active flag) |
| `push_notification_preferences` | Per-user notification type opt-ins |
| `access_requests` | B2C lead capture (self-registered users requesting full access) |
| `content_flags` | Reported content (reason, priority, resolution tracking) |
| `admin_audit_log` | Super admin actions |

### Critical DB Rules (must not violate)
- `deck_id` on `flashcards` is **NEVER populated** — always join on 5 grouping columns: `(user_id, subject_id, topic_id, custom_subject, custom_topic)`
- `reviews` columns: `easiness` (not `easiness_factor`), `repetition` (not `repetitions`), `created_at` (not `reviewed_at`)
- Unauthenticated pages **MUST** go through SECURITY DEFINER RPCs — direct table queries return 0 rows silently for anon users
- Group flashcards by `batch_id`, never by timestamp

### Active DB Triggers (10+)
- `trg_create_profile_on_signup` — creates profile row on auth.users INSERT
- `trigger_update_deck_card_count` — maintains `flashcard_decks.card_count`
- `trg_aaa_counter_flashcards` — updates `user_stats` for badge counters on flashcard INSERT
- `trg_badge_flashcard_create` — awards deck_builder badge
- `trg_auto_resolve_note_flags` / `trg_auto_resolve_flashcard_flags` — auto-resolves `content_error` flags when content is edited by creator
- `fn_auto_enroll_batch_group` — auto-enrolls new students into matching batch groups on account_type change
- Plus streak and activity log triggers

---

## 7. Edge Functions

| Function | Purpose |
|----------|---------|
| `push-subscribe` | Registers device push subscription endpoint |
| `push-unsubscribe` | Deactivates push subscription on user opt-out |
| `notify-content-created` | Sends push when new public note/deck is published |
| `notify-friend-event` | Sends push for friend request / acceptance |
| `cron-review-reminders` | Morning push reminders (02:30 UTC daily via pg_cron) |
| `cron-daily-study-summary` | Nightly study summary push (22:00 local, 15-min check cycle via pg_cron) |
| `_shared/sendPush.ts` | Shared VAPID push sender utility |
| `_shared/supabaseAdmin.ts` | Shared Supabase admin client |

---

## 8. Key Design Decisions (Permanent — Do Not Revert)

1. **"Recall/RevisOp" h1 gets the gradient, tagline is solid text** — eye lands on brand name first (Home.jsx). Intentional hierarchy. Do not revert.
2. **Batch groups hidden from student MyGroups** — server-side filtered via RPC, never hits client.
3. **`postAuthRedirect` via localStorage** — set before `signIn()` call to beat AppContent race condition.
4. **Study time deduplication** — localStorage cleared BEFORE DB write; second caller finds empty keys and returns early. Do not change order.
5. **LocalStorage autosave on FlashcardCreate** — Safari Private Browsing (0-byte quota) fails silently with try/catch; navigation guard still protects the user.
6. **"Needs Attention" professor card is always visible** (even when empty shows "All clear" state) — settled design, never conditionally hide without explicit approval. Same rule for admin "Needs Review" card.
7. **Leaderboard 3-tier session protection** — sessions over 16h silently discarded; 4–16h triggers honest-session prompt; under 4h auto-resumes.
8. **UI nomenclature:** "Items" (not "Cards"), "Study Sets" (not "Flashcard Decks") — decided March 2026.
9. **Educator profiles on landing page** served via `get_public_educators()` SECURITY DEFINER RPC (not direct table query — would return 0 rows for anon users).

---

## 9. All Routes

### Public (no auth required)
| Path | Component |
|------|-----------|
| `/` | Home.jsx |
| `/login` | auth/Login.jsx |
| `/signup` | auth/Signup.jsx |
| `/forgot-password` | auth/ForgotPassword.jsx |
| `/reset-password` | auth/ResetPassword.jsx |
| `/terms-of-service` | TermsOfService.jsx |
| `/privacy-policy` | PrivacyPolicy.jsx |
| `/guide` | guide/StudentGuide.jsx |
| `/deck/:deckId` | public/DeckPreview.jsx |
| `/join/:token` | public/GroupJoin.jsx |
| `/note/:noteId` | public/NotePreview.jsx |

### Authenticated (student + all roles)
| Path | Component |
|------|-----------|
| `/dashboard` | Dashboard.jsx |
| `/dashboard/notes` | Content/BrowseNotes.jsx |
| `/dashboard/notes/new` | Content/NoteUpload.jsx |
| `/dashboard/notes/:id` | Content/NoteDetail.jsx |
| `/dashboard/notes/edit/:id` | Content/NoteEdit.jsx |
| `/dashboard/my-notes` | Content/MyNotes.jsx |
| `/dashboard/my-contributions` | Content/MyContributions.jsx |
| `/dashboard/flashcards` | Content/MyFlashcards.jsx |
| `/dashboard/flashcards/new` | Content/FlashcardCreate.jsx |
| `/dashboard/bulk-upload` | BulkUploadFlashcards.jsx |
| `/dashboard/review-flashcards` | Study/ReviewFlashcards.jsx |
| `/dashboard/review-session` | Study/ReviewSession.jsx |
| `/dashboard/review-by-subject` | Study/ReviewBySubject.jsx |
| `/dashboard/study` | Study/StudyMode.jsx |
| `/dashboard/progress` | Study/Progress.jsx |
| `/dashboard/achievements` | Profile/MyAchievements.jsx |
| `/dashboard/profile/:userId` | Profile/AuthorProfile.jsx |
| `/dashboard/settings` | Profile/ProfileSettings.jsx |
| `/dashboard/help` | Help.jsx |
| `/dashboard/groups` | Groups/MyGroups.jsx |
| `/dashboard/groups/new` | Groups/CreateGroup.jsx |
| `/dashboard/groups/:groupId` | Groups/GroupDetail.jsx |
| `/dashboard/find-friends` | Friends/FindFriends.jsx |
| `/dashboard/friend-requests` | Friends/FriendRequests.jsx |
| `/dashboard/my-friends` | Friends/MyFriends.jsx |
| `/dashboard/following` | Friends/Following.jsx |
| `/dashboard/professor-analytics` | ProfessorAnalytics.jsx |
| `/admin` | admin/AdminDashboard.jsx |
| `/admin/analytics` | admin/AdminAnalytics.jsx |
| `/admin/bulk-upload-topics` | admin/BulkUploadTopics.jsx |
| `/admin/migrate-note-images` | admin/MigrateNoteImages.jsx (TEMP) |
| `/super-admin` | admin/SuperAdminDashboard.jsx |
| `/super-admin/analytics` | admin/SuperAdminAnalytics.jsx |

---

## 10. Rebranding Work — Complete Inventory

### A. Infrastructure (do before code changes)

| Step | Action |
|------|--------|
| 1 | Create `hello@revisop.com` mailbox in Google Workspace |
| 2 | Add `www.revisop.com` as custom domain in Vercel |
| 3 | Configure DNS CNAME/A in GoDaddy for revisop.com → Vercel |
| 4 | Promote `www.revisop.com` to primary domain in Vercel |
| 5 | Set 301 redirect: `www.recallapp.co.in` → `https://www.revisop.com` |
| 6 | Supabase → Auth → Email Templates → update all redirect URLs to `https://www.revisop.com` |
| 7 | Supabase secrets: update `VAPID_SUBJECT` to `mailto:hello@revisop.com` |

### B. Source Files Requiring Brand Name Changes (28 files)

**App shell & PWA:**
- `index.html` — `<title>` tag
- `public/site.webmanifest` — `name` and `short_name`
- `public/sw.js` — comment, `APP_NAME` const, default notification tag

**Navigation (visible to all logged-in users):**
- `src/components/layout/NavDesktop.jsx` — logo text "RECALL" → "REVISOP"
- `src/components/layout/NavMobile.jsx` — logo text "RECALL" → "REVISOP"

**Auth pages:**
- `src/pages/auth/Login.jsx` — brand name in form UI
- `src/pages/auth/Signup.jsx` — brand name in form UI

**Dashboard & onboarding:**
- `src/pages/Dashboard.jsx` — 3 user-visible strings + localStorage key names
- `src/components/dashboard/OnboardingModal.jsx` — "Welcome to Recall" dialog title
- `src/components/dashboard/AnonymousStats.jsx` — "vs all Recall students" labels

**Public share pages (high impact — these are what WhatsApp recipients see):**
- `src/pages/public/DeckPreview.jsx` — logo, CTA copy, all product references
- `src/pages/public/NotePreview.jsx` — logo, CTA copy, all product references
- `src/pages/public/GroupJoin.jsx` — logo, CTA copy, all product references

**Landing page:**
- `src/pages/Home.jsx` — 20+ occurrences; all `mailto:hello@recallapp.co.in` links

**Legal pages:**
- `src/pages/TermsOfService.jsx` — all product name, domain, and email references
- `src/pages/PrivacyPolicy.jsx` — all product name, domain, email references + stale `recall.moreclassescommerce.com` on line 62

**In-app content:**
- `src/pages/guide/StudentGuide.jsx` — `document.title` calls + header wordmark
- `src/pages/dashboard/Help.jsx` — product description text
- `src/pages/dashboard/Groups/GroupDetail.jsx` — WhatsApp share text
- `src/pages/dashboard/Study/ReviewFlashcards.jsx` — WhatsApp share text
- `src/pages/dashboard/Content/NoteDetail.jsx` — WhatsApp share text
- `src/pages/dashboard/BulkUploadFlashcards.jsx` — CSV filename + error message
- `src/pages/professor/ProfessorTools.jsx` — CSV filename + instruction text

**Data files (user-facing help/guide text):**
- `src/data/helpContent.js` — 29 occurrences in help center copy
- `src/data/guideContent.js` — 9 occurrences in student guide copy

**Vercel Edge Middleware:**
- `middleware.js` (root-level) — OG tag text for WhatsApp previews contains "Recall" brand name in all three handlers (deck, join, note). Specific occurrences: fallback titles ("Study Set on Recall", "Study Group on Recall"), description strings ("Study for free on Recall", "Join on Recall", "Study note shared on Recall"), and the body redirect anchor text. No `og:image` tag exists in this file — the auditor's og:image concern does not apply. Note: the page URL in OG tags is derived dynamically from `request.url`, so it will automatically reflect revisop.com after the domain cutover with no code change required.

**Edge Functions:**
- `supabase/functions/_shared/sendPush.ts` — fallback VAPID email
- `supabase/functions/cron-daily-study-summary/index.ts` — fallback VAPID email

**package.json:**
- `"name": "recall-app"` → `"name": "revisop"` (low priority, not user-facing)

### C. localStorage Key Renames (affects existing user sessions)

Changing these keys will reset existing users' preferences. Use a **migrate-on-mount** pattern: on first read, check for the new key; if absent, read the old key, write it to the new key, and delete the old key. This silently migrates each user on their next session with zero data loss.

**Implementation pattern (apply to every key rename):**

```js
// Example for recall_session_started_at → revisop_session_started_at
let value = localStorage.getItem('revisop_session_started_at');
if (!value) {
  value = localStorage.getItem('recall_session_started_at');
  if (value) {
    localStorage.setItem('revisop_session_started_at', value);
    localStorage.removeItem('recall_session_started_at');
  }
}
```

Remove the old-key fallback reads in the sprint after the rebrand deploys (all active users will have migrated by then).

| Current Key | New Key | User Impact Without Migration |
|-------------|---------|-------------------------------|
| `recall_access_ref` | `revisop_access_ref` | Loses in-flight referral tracking |
| `recall_session_started_at` | `revisop_session_started_at` | Loses in-progress manual timer sessions |
| `recall_session_source` | `revisop_session_source` | Same |
| `recall-push-banner-dismissed` | `revisop-push-banner-dismissed` | Users see push banner once more |
| `recall-tts-voice-uri` | `revisop-tts-voice-uri` | Loses TTS voice preference |
| `recall-tts-rate` | `revisop-tts-rate` | Loses TTS speed preference |

Files containing these keys: `Signup.jsx`, `Dashboard.jsx`, `StudyMode.jsx`, `StudyTimerWidget.jsx`, `PushPermissionBanner.jsx`, `useSpeech.js`

### D. Brand Assets — New Artwork Required

| File | Action |
|------|--------|
| `public/favicon.ico` | Replace with RevisOp favicon |
| `public/favicon-16x16.png` | Replace |
| `public/favicon-32x32.png` | Replace |
| `public/apple-touch-icon.png` | Replace |
| `public/android-chrome-192x192.png` | Replace |
| `public/android-chrome-512x512.png` | Replace |

---

## 11. Known Issues & Pending Work

### Technical Debt
- **`tesseract.js` likely dead dependency** — `useOCR.js` was deleted; package.json still lists `tesseract.js 6.0.1`. Verify no imports remain, then remove from package.json.
- **`MigrateNoteImages.jsx`** — Temp admin page for one-time note image migration (Feb 2026). If migration confirmed complete: delete file + remove route from `App.jsx`.
- **`public/vite.svg`** — Default Vite asset, unused. Safe to delete.

### Infrastructure Pending
- **DKIM for `recallapp.co.in`** — Gmail activated, MX done, but DKIM step was shown as optional-but-recommended on the Workspace activation screen. Complete to cover email during migration transition.
- **GitHub PAT "recall-app-push"** — Expires ~July 2, 2026. Regenerate with "No expiration" before rebrand sprint starts.
- **Sentry** — Not integrated. User confirmed intent. Requires: DSN from sentry.io, install `@sentry/react`, initialize in `src/main.jsx`.
- **PostHog** — Not integrated. User confirmed intent. Requires: API key from posthog.com, install `posthog-js`, initialize in `src/main.jsx`.
- **JWT expiry** — Actual value in Supabase Dashboard → Authentication → Settings unconfirmed. Per-role session timeouts are NOT implemented in code; Supabase has one global setting.

### Sprint Backlog
- Data Contract UI enforcement for FlashcardCreate
- Content notification preferences UI (backend `push_notification_preferences` table exists; no settings UI)
- Full flagging resolution UI for professors

---

## 12. Rebrand Sprint — Recommended Execution Order

**Phase 1 — Infrastructure (no code push needed)**
1. Create `hello@revisop.com` mailbox in Google Workspace
2. Add revisop.com domain to Vercel; configure DNS in GoDaddy
3. Update Supabase → Authentication → Email Templates → all redirect URLs to `https://www.revisop.com`
4. Update Supabase `VAPID_SUBJECT` secret to `mailto:hello@revisop.com`
5. Confirm Vercel env var names — current vars are `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, `VITE_VAPID_PUBLIC_KEY`, `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`. None contain "RECALL" so no Vercel env var renames are needed. If any new env var is added during the rebrand sprint that references the brand name, add it to Vercel before pushing code that uses it.
> **Note on CORS:** Supabase does not require a CORS origins setting for API calls — the JS client communicates with the Supabase project URL (`*.supabase.co`) which is managed by Supabase. The only domain-sensitive Supabase setting is the auth redirect URL covered in step 3 above.

**Phase 2 — Code changes (single PR)**
5. Replace all brand references in 28 files (§10B)
6. Update localStorage keys with backward-compatible fallback reads (§10C)
7. Replace all 6 brand asset files in `/public` (§10D)

**Phase 3 — Cutover**
8. Promote `www.revisop.com` to primary domain in Vercel
9. Set `www.recallapp.co.in` → 301 redirect to `https://www.revisop.com`
10. Verify on live URL

**Phase 4 — Cleanup (one week later)**
11. Remove localStorage fallback reads
12. Delete `MigrateNoteImages.jsx` if migration confirmed complete
13. Remove `tesseract.js` from package.json if confirmed unused

---

*Blueprint prepared June 26, 2026. All file references, version numbers, and feature descriptions verified against live source code via full codebase audit.*
