# RECALL APP - FILE STRUCTURE
**Last Updated: September 2026 (Sprint 6.1 — Design Foundation)**

---

recall-app
├── supabase
│   └── functions
│       ├── _shared                              ← shared helpers (NOT deployed as standalone functions)
│       │   ├── supabaseAdmin.ts                 ← service-role Supabase client (bypasses RLS)
│       │   └── sendPush.ts                      ← VAPID web-push utility (sendPushToUsers)
│       ├── push-subscribe
│       │   └── index.ts                         ← save device push subscription to DB
│       ├── push-unsubscribe
│       │   └── index.ts                         ← soft-delete push subscription (is_active = false)
│       ├── notify-friend-event
│       │   └── index.ts                         ← instant push for friend_request / friend_accepted
│       ├── notify-content-created
│       │   └── index.ts                         ← update-in-place aggregation + push (4h grouping window)
│       ├── cron-review-reminders
│       │   └── index.ts                         ← daily 08:00 IST push for due review cards (02:30 UTC cron)
│       └── cron-daily-study-summary
│           └── index.ts                         ← nightly 22:00 local-time study summary push (*/15 cron)
├── .env.local
├── .gitignore
├── components.json
├── docs
│   ├── active
│   │   ├── context.md                           ← project context, architecture decisions, bug protocols
│   │   ├── git-guide.md                         ← bash git commit guide (printf syntax, NEVER PowerShell heredoc)
│   │   ├── now.md                               ← current sprint status + session notes
│   │   └── design-review/                       ← screenshot-critique inputs + srs-ladder-proposal.md (SRS Ladder Epic Phase 0)
│   ├── archive
│   │   ├── APPROVED_DECISIONS.md
│   │   ├── CONTEXT_FOR_CLAUDE.md
│   │   └── FEATURE_PRIORITY.md
│   ├── database
│   │   ├── Reviews_Table_Usage.md
│   │   ├── sprint6/                            ← get_study_queue RPC (01) + tests (02, 03)
│   │   ├── sprint6.3/                          ← Dashboards reskin RPCs: 01_FUNCTIONS (get_due_forecast_buckets / get_educator_accuracy_by_qtype / get_educator_cohort_forecast_buckets) + 02_TEST (✅ deployed & verified 05/09/2026)
│   │   ├── sprint6.4/                          ← Study-loop reskin: 01_DIAGNOSTIC (last_reviewed_at coverage, read-only) + 02_DATA (NULL backfill, optional/idempotent) — no schema/function change
│   │   ├── sprint6.5/                          ← [FIX] get_following_leaderboard ambiguous "rank" (42702): 01_DIAGNOSTIC + 02_FUNCTIONS (in-place fix, no signature change — ✅ deployed 07/09/2026) + 03_TEST (✅ 9/9 PASS; ⏳ live "Following" tab check pending)
│   │   └── srs-ladder/                         ← SRS Ladder Epic: 00_DIAGNOSTIC .. 05_TEST (✅ deployed 03/09/2026) + 06_FUNCTIONS_get_mastered_cards (Phase 3, ⏳ deploy before frontend push)
│   ├── design
│   │   ├── ACHIEVEMENT_BADGES.md
│   │   ├── SPACED_REPETITION_PHILOSOPHY.md
│   │   └── UPVOTE_SYSTEM.md
│   ├── reference
│   │   ├── DATABASE_SCHEMA.md                   ← authoritative DB schema reference
│   │   └── FILE_STRUCTURE.md                    ← this file
│   └── tracking
│       ├── bugs.md
│       ├── changelog.md
│       └── ideas.md
├── middleware.js                                 ← Vercel Edge Middleware: OG tag injection for /deck/:id and /join/:token
├── eslint.config.js
├── index.html
├── jsconfig.json
├── package.json                                  ← react 19, react-router-dom v7, vite v7, recharts, tesseract.js
├── postcss.config.js
├── public
│   ├── android-chrome-192x192.png
│   ├── android-chrome-512x512.png
│   ├── apple-touch-icon.png
│   ├── favicon-16x16.png
│   ├── favicon-32x32.png
│   ├── favicon.ico
│   ├── site.webmanifest
│   ├── sw.js                                    ← Service Worker: push event handler + notificationclick + install/activate
│   └── vite.svg
├── src
│   ├── App.jsx                                  ← all routes (lazy-loaded), Auth/Course/NavData providers, AppContent postAuthRedirect
│   ├── contexts
│   │   ├── AuthContext.jsx                      ← auth state (identity-stable user), timezone sync (1×/session), updateUserTimezone
│   │   ├── CourseContext.jsx                    ← multi-course teaching context for professors/admins; activeCourse session state; exposes role/courseLevel
│   │   ├── NavDataContext.jsx                   ← Sprint 7.0, extended 7.2-F: one instance of useRole/useNotifications/useFriendRequestCount/useDueForecast for the whole app; useNavData() + useRole shim
│   │   ├── StudySessionContext.jsx              ← Sprint 7.1: boolean inStudySession (StudyMode sets it) so NavBottomTabs hides during the card loop
│   │   ├── StudyTimerContext.jsx                ← Sprint 7.3-C: app-wide manual-timer state + 3-tier stale-session policy; own localStorage key; cross-tab storage-event sync. Sprint 8.5: pendingLog state (own localStorage key) — duration finalized but category not yet chosen; confirmCategory() does the actual insert
│   │   └── ExamDateContext.jsx                  ← Sprint 8.4: exam_date/exam_month/has_dismissed_exam_prompt fetch-once + mutators (saveExamDate, dismissPrompt), shared by nav chip/Dashboard card/prompt modal/Profile Settings
│   ├── lib
│   │   ├── supabase.js                          ← Supabase client
│   │   ├── noteStorage.js                       ← 16/09/2026: extractNoteStoragePath()/deleteNoteStorageImage() — shared note-delete Storage cleanup (MyNotes.jsx, AdminDashboard.jsx)
│   │   ├── utils.js                             ← shadcn cn() utility
│   │   ├── qualityTier.js                       ← shared score/rate → colour-tier util (AdminAnalytics, SuperAdminDashboard) — Sprint 6.0
│   │   ├── notifyEdge.js                        ← fire-and-forget helpers: notifyContentCreated(), notifyFriendEvent()
│   │   └── examDate.js                          ← Sprint 8.4: daysUntilExamDate/formatExamMonth/buildExamMonthValue — timezone-safe date-only math (never toISOString())
│   ├── hooks
│   │   ├── use-toast.js                         ← shadcn toast hook
│   │   ├── useActivityFeed.js                   ← recent content feed for dashboard activity section
│   │   ├── useBadges.js                         ← badge data fetching (get_unnotified_badges RPC)
│   │   ├── useDueForecast.js                    ← Sprint 7.2-F: get_due_forecast wrapper (dueToday/dueNext7/dueNext30), consumed via NavDataContext
│   │   ├── useFriendRequestCount.js             ← realtime pending friend request count
│   │   ├── useNotifications.js                  ← realtime notifications (INSERT + UPDATE subscriptions)
│   │   ├── usePushNotifications.js              ← Web Push: permission, VAPID subscribe/unsubscribe, iOS detect
│   │   ├── useRole.js                           ← role helper (isAdmin, isSuperAdmin, isProfessor)
│   │   └── useSpeech.js                         ← Web Speech API TTS with sentence chunking (Chrome 15s bug fix)
│   ├── data
│   │   ├── helpContent.js                       ← role-filtered help tabs/sections/FAQs (single source of truth for Help.jsx)
│   │   └── guideContent.js                      ← SITUATIONS array for StudentGuide + GuideInfoModal (single source of truth)
│   ├── components
│   │   ├── badges
│   │   │   ├── BadgeCard.jsx                    ← badge display with per-badge privacy toggle
│   │   │   ├── BadgeIcon.jsx                    ← maps icon_key string to Lucide icon component
│   │   │   └── BadgeToast.jsx                   ← toast notification shown on dashboard when new badge earned
│   │   ├── dashboard
│   │   │   ├── ActivityFeed.jsx                 ← recent notes/decks from past 7 days (grouped by creator+date)
│   │   │   ├── AnonymousStats.jsx               ← "You vs Class" comparison bars (min 5 users for averages)
│   │   │   ├── GoalProgressWidget.jsx           ← daily review/study-time goal vs today's actual; writes via update_daily_goal RPC
│   │   │   ├── LeaderboardWidget.jsx            ← friends + following leaderboard tabs; isolated, zero parent re-renders
│   │   │   ├── OnboardingModal.jsx              ← 3-step first-login modal (shown when has_seen_onboarding = false)
│   │   │   ├── StudyTimerWidget.jsx             ← manual offline study timer; clock via DOM ref (zero React re-renders/tick)
│   │   │   └── ExamDatePromptModal.jsx          ← Sprint 8.4: dismissible first-login popup (month/year or exact date), permanent dismiss via has_dismissed_exam_prompt
│   │   ├── flashcards
│   │   │   ├── ConceptCardViewer.jsx            ← read-only concept_card accordion modal (Sprint 7.12) — summary + keyTerms, zero grade buttons, zero apply_review calls
│   │   │   ├── FlashcardCard.jsx                ← standalone flashcard display/edit card component
│   │   │   ├── SpeakButton.jsx                  ← TTS volume icon with pulse animation
│   │   │   └── SpeechSettings.jsx               ← voice selector + speed slider popover
│   │   ├── layout
│   │   │   ├── CourseSwitcher.jsx               ← indigo pill dropdown for multi-course professors (session-only, no DB write)
│   │   │   ├── NavBottomTabs.jsx                ← mobile bottom-tab bar (Sprint 7.1, due-badge 7.2-F, Bulk Upload removed/Log Study Time added 7.3-C/D): md:hidden, fixed; Dashboard·Review(badge)·＋(Note/Flashcard/Group, divider, Log Study Time)·Progress·Menu; data-driven, no own fetch
│   │   │   ├── NavDesktop.jsx                   ← desktop nav with dropdowns (Study▾, Create▾ incl. Log Study Time 7.3-C, Manage▾); active-route helpers from @/lib/navActive
│   │   │   ├── Navigation.jsx                   ← orchestrator; renders NavDesktop + NavMobile (top) + NavBottomTabs (bottom sibling)
│   │   │   ├── NavMenuSheet.jsx                 ← mobile "Menu" drawer (Sprint 7.1): the former NavMobile hamburger Sheet, content verbatim
│   │   │   ├── NavMobile.jsx                    ← mobile TOP bar (Sprint 7.2-B: Wordmark + single NotificationCenter bell + 7.3-C StudyTimerChip)
│   │   │   ├── NotificationCenter.jsx           ← Sprint 7.2-B: unified bell dropdown (merges former ActivityDropdown + FriendsDropdown) — friend requests (inline accept/decline) + notifications, one badge; shared by NavDesktop + NavMobile
│   │   │   ├── PageContainer.jsx                ← wrapper with width prop (full/medium/narrow); bottom-bar safe-area clearance
│   │   │   ├── ProfileDropdown.jsx              ← avatar dropdown (My Progress, My Contributions, My Achievements, Report History [7.3 follow-up], Help, Settings, Sign Out)
│   │   │   ├── StudyTimerChip.jsx               ← Sprint 7.3-C: nav-bar pill beside the bell, hidden unless a manual timer is running; tap-to-stop/navigate
│   │   │   └── ExamDateChip.jsx                 ← Sprint 8.4: nav-bar exam-date pill beside StudyTimerChip, student-only; countdown/month-text/CTA states, taps to Profile Settings
│   │   ├── notifications
│   │   │   └── PushPermissionBanner.jsx         ← one-time dismissible push prompt (Android: enable button; iOS: install guide)
│   │   ├── progress
│   │   │   ├── PlatformHeatmap.jsx              ← 52-week platform-wide heatmap (super_admin only; blue scale)
│   │   │   ├── StudyHeatmap.jsx                 ← 90-day per-user study heatmap (green scale)
│   │   │   └── SubjectMasteryTable.jsx          ← per-subject mastery %; responsive table + mobile card list
│   │   ├── revisop                             ← RevisOp reskin primitives (Phase 6 S6.1); --rv-* tokens + self-hosted Plex/Literata; NOT wired to prod pages (QA route only)
│   │   │   ├── AnswerOption.jsx                 ← answered choice row — glyph + label, slate miss (no red/green)
│   │   │   ├── Card.jsx                         ← study-object container (r14)
│   │   │   ├── ForwardLedgerMacro.jsx           ← scheduled-load bar rail (Today / cohort); consumes get_study_queue/get_due_forecast shapes
│   │   │   ├── ForwardLedgerMicro.jsx           ← single-item bucket rail (lives inside a grade button)
│   │   │   ├── GradeButtonRow.jsx               ← the climax — ≥48px navy-outline, mono interval, slate miss
│   │   │   ├── IntervalChip.jsx                 ← mono micro forward-ledger marker (r4)
│   │   │   ├── Label.jsx                        ← uppercase tracked eyebrow (type atom)
│   │   │   ├── MatchZone.jsx                    ← match_the_following pick/assign/reveal (Sprint 7.8) — wired into prod (StudyMode.jsx), unlike its QA-only siblings
│   │   │   ├── Num.jsx                          ← Plex Mono tabular numeric span (type atom)
│   │   │   ├── Row.jsx                          ← record container (r4) + optional VerifiedEdge
│   │   │   ├── VerifiedEdge.jsx                 ← 3px navy verified rail
│   │   │   ├── Wordmark.jsx                     ← two-tone logotype (amber Revis + navy Op), token-driven, no gradient
│   │   │   └── index.js                         ← barrel
│   │   ├── shared                               ← 16/09/2026: home for components with no thematic subfolder (previously loose at src/components/ root)
│   │   │   └── GuideInfoModal.jsx               ← contextual info modal for DeckPreview / NotePreview / GroupJoin
│   │   └── ui
│   │       ├── alert.jsx
│   │       ├── button.jsx
│   │       ├── card.jsx
│   │       ├── command.jsx
│   │       ├── ContentPreviewWall.jsx           ← Tier B preview wall after 10 professor cards (lead capture form)
│   │       ├── dialog.jsx                       ← has hideCloseButton prop for non-dismissible modals
│   │       ├── dropdown-menu.jsx
│   │       ├── FlagButton.jsx                   ← "Report" button (content_error / inappropriate / other)
│   │       ├── FlipCard.jsx                     ← presentational 3D flip (controlled isFlipped; front/back faces) — Phase 5 S1
│   │       ├── input.jsx
│   │       ├── label.jsx
│   │       ├── popover.jsx
│   │       ├── progress.jsx
│   │       ├── SearchableSelect.jsx
│   │       ├── select.jsx
│   │       ├── sheet.jsx                        ← Radix Dialog-based slide-in Sheet (NavMenuSheet drawer + NavBottomTabs ＋ action-sheet)
│   │       ├── StudyItemCard.jsx                ← presentational deck/study-set list card (prop-driven, brand tokens) — Phase 5 S1
│   │       ├── switch.jsx
│   │       ├── tabs.jsx
│   │       ├── textarea.jsx
│   │       ├── toast.jsx
│   │       ├── toaster.jsx
│   │       └── UpvoteButton.jsx                 ← polymorphic upvote toggle (notes + flashcard_decks); optimistic UI
│   ├── pages
│   │   ├── Home.jsx                             ← landing page (public, unauthenticated)
│   │   ├── Dashboard.jsx                        ← role-specific hub (student / professor / admin / super_admin views)
│   │   ├── PrivacyPolicy.jsx
│   │   ├── TermsOfService.jsx
│   │   ├── auth
│   │   │   ├── ForgotPassword.jsx
│   │   │   ├── Login.jsx                        ← reads+clears postAuthRedirect from localStorage BEFORE signIn()
│   │   │   ├── ResetPassword.jsx
│   │   │   └── Signup.jsx
│   │   ├── dev                                  ← DEV-ONLY pages (route + import gated on import.meta.env.DEV; absent from prod builds)
│   │   │   └── DesignShowcase.jsx               ← /__design — Phase 5 S1 tokens/components + Phase 6 S6.1 RevisOp reskin gallery (light/dark toggle); no auth, no DB
│   │   ├── guide
│   │   │   └── StudentGuide.jsx                 ← public /guide page; 9 situations; scroll spy; no auth, no DB calls
│   │   ├── public                               ← unauthenticated share/join pages (RPC-only data, no direct table access)
│   │   │   ├── DeckPreview.jsx                  ← /deck/:deckId — shareable study set preview with OG tags
│   │   │   ├── Educators.jsx                    ← /educators — B2B institute lead form (submit_institute_inquiry RPC, Phase 5 S5)
│   │   │   ├── GroupJoin.jsx                    ← /join/:token — group invite accept page
│   │   │   └── NotePreview.jsx                  ← /note/:noteId — shareable note preview with OG tags
│   │   ├── admin
│   │   │   ├── AdminAnalytics.jsx               ← /admin/analytics (admin + super_admin only)
│   │   │   ├── AdminDashboard.jsx               ← /admin (user management, content moderation, access requests)
│   │   │   ├── BulkUploadTopics.jsx             ← /admin/bulk-upload-topics (admin only)
│   │   │   ├── MigrateNoteImages.jsx            ← TEMP — delete after note image migration is confirmed complete
│   │   │   ├── SuperAdminAnalytics.jsx          ← /super-admin/analytics (super_admin only)
│   │   │   └── SuperAdminDashboard.jsx          ← /super-admin (user management, role promotion, hard delete)
│   │   └── dashboard
│   │       ├── BulkUploadFlashcards.jsx         ← /dashboard/bulk-upload (all users; 3-step CSV stepper)
│   │       ├── Help.jsx                         ← /dashboard/help (role-filtered tabs, search, accordion mobile)
│   │       ├── ProfessorAnalytics.jsx           ← /dashboard/professor-analytics (professor only)
│   │       ├── Content
│   │       │   ├── BrowseNotes.jsx              ← /dashboard/notes (subject-accordion layout, lazy images, pagination)
│   │       │   ├── FlashcardCreate.jsx          ← /dashboard/flashcards/new (useBlocker guard, localStorage autosave)
│   │       │   ├── MyContributions.jsx          ← /dashboard/my-contributions (upvote stats, who upvoted)
│   │       │   ├── MyFlashcards.jsx             ← /dashboard/flashcards (own cards, null-topic nudge)
│   │       │   ├── MyNotes.jsx                  ← /dashboard/my-notes
│   │       │   ├── NoteDetail.jsx               ← /dashboard/notes/:id (WhatsApp share for public notes)
│   │       │   ├── NoteEdit.jsx                 ← /dashboard/notes/edit/:id
│   │       │   └── NoteUpload.jsx               ← /dashboard/notes/new (image compression via browser-image-compression)
│   │       ├── Friends
│   │       │   ├── FindFriends.jsx              ← /dashboard/find-friends (renamed "Find People"; course-filtered via RPC)
│   │       │   ├── Following.jsx                ← /dashboard/following (one-way follows with stats)
│   │       │   ├── FriendRequests.jsx           ← /dashboard/friend-requests
│   │       │   └── MyFriends.jsx                ← /dashboard/my-friends (stats: streak, reviews, study time)
│   │       ├── Groups
│   │       │   ├── CreateGroup.jsx              ← /dashboard/groups/new
│   │       │   ├── GroupDetail.jsx              ← /dashboard/groups/:groupId (batch performance view for professors)
│   │       │   └── MyGroups.jsx                 ← /dashboard/groups (batch groups hidden from students server-side)
│   │       ├── Profile
│   │       │   ├── AuthorProfile.jsx            ← /dashboard/profile/:userId (follow button, teaching courses, public badges)
│   │       │   ├── MyAchievements.jsx           ← /dashboard/achievements (per-badge privacy toggle)
│   │       │   ├── MyReports.jsx                ← Sprint 7.3 follow-up: /dashboard/my-reports ("Report History") — status list of content_flags the student themselves filed; moved off the Dashboard
│   │       │   └── ProfileSettings.jsx          ← /dashboard/settings (name, course, institution, push notifications, teaching areas, Daily Goal)
│   │       └── Study
│   │           ├── Progress.jsx                 ← /dashboard/progress (heatmap, subject mastery, due forecast, question type perf)
│   │           ├── ReviewBySubject.jsx          ← /dashboard/review-by-subject
│   │           ├── ReviewFlashcards.jsx         ← /dashboard/review-flashcards (deck browser; "My Cards" pinned; share button)
│   │           ├── ReviewSession.jsx            ← /dashboard/review-session (due cards only)
│   │           └── StudyMode.jsx                ← /dashboard/study (SRS engine; TTS; Skip/Suspend/Reset; study time logging)
│   ├── App.css
│   ├── index.css
│   └── main.jsx                                 ← registers /sw.js service worker on window load (non-blocking)
├── tailwind.config.js
├── vercel.json
└── vite.config.js                               ← manualChunks: vendor-react, vendor-supabase, vendor-radix

---

## KEY FILE LOCATIONS

### Authentication
- `src/contexts/AuthContext.jsx` — auth state, timezone auto-sync on login
- `src/pages/auth/Login.jsx` — postAuthRedirect captured BEFORE signIn() to avoid race
- `src/pages/auth/Signup.jsx` — profile created by DB trigger, NOT client-side insert

### Navigation
- `src/components/layout/Navigation.jsx` — orchestrator (thin); reads `useNavData()` (Sprint 7.0) — one shared fetch, not 3 per mount
- `src/contexts/NavDataContext.jsx` — `<NavDataProvider>` owns role + notifications + friend-request count + due-forecast (7.2-F) app-wide; `useNavData()` + a `useRole` shim
- `src/contexts/StudySessionContext.jsx` — Sprint 7.1: `inStudySession` flag set by `StudyMode`; `NavBottomTabs` hides while true
- `src/components/layout/NavDesktop.jsx` — desktop layout with dropdowns
- `src/components/layout/NavMobile.jsx` — mobile top bar (Wordmark + single `NotificationCenter` bell; Sprint 7.2-B, was Wordmark + Friends + Bell since 7.1)
- `src/components/layout/NavBottomTabs.jsx` — mobile bottom-tab bar (Sprint 7.1, due-badge 7.2-F); consumes `navProps`, no own fetch
- `src/components/layout/NavMenuSheet.jsx` — mobile "Menu" drawer (Sprint 7.1); the former NavMobile hamburger Sheet
- `src/components/layout/NotificationCenter.jsx` — Sprint 7.2-B: unified bell dropdown (merged `ActivityDropdown` + `FriendsDropdown`, both deleted); shared by `NavDesktop` + `NavMobile`
- `src/lib/navActive.js` — shared active-route predicates for NavDesktop + NavBottomTabs (Sprint 7.1)

### Dashboard
- `src/pages/Dashboard.jsx` — 4-way role conditional (student / professor / admin / super_admin)
- `src/components/dashboard/StudyTimerWidget.jsx` — clock via DOM ref, not React state (zero re-renders/tick)
- `src/components/dashboard/LeaderboardWidget.jsx` — isolated; Following tab lazy-fetched
- `src/components/dashboard/GoalProgressWidget.jsx` — inline edit, no modal

### Study / SRS
- `src/pages/dashboard/Study/StudyMode.jsx` — SRS engine, TTS, Skip/Suspend/Reset/Skip-Topic, study time logging, visibilitychange listener
- `src/pages/dashboard/Study/ReviewFlashcards.jsx` — deck browser; deep-link via ?deck= param
- `src/pages/dashboard/Study/ReviewSession.jsx` — due-cards-only session

### Content Creation
- `src/pages/dashboard/Content/FlashcardCreate.jsx` — useBlocker guard + beforeunload + localStorage autosave (1s debounce)
- `src/pages/dashboard/Content/NoteUpload.jsx` — image compression (maxSizeMB: 0.5, maxWidthOrHeight: 1920)
- `src/components/content/FeatureNominationButton.jsx` — Phase 5 S3 curation control (3 states: nominate/pending/live); used in `MyFlashcards.jsx` + `NoteDetail.jsx`; gated on `docs/database/phase5/09–11` deployment
- `src/components/content/ProvenanceBadge.jsx` — Sprint 8.7.4 D-21 display. Renders nothing when `sourceType`/`sourceName` are absent (legacy content or ambiguous multi-batch deck) — no "Unknown source" placeholder. Used in `MyFlashcards.jsx`, `MyNotes.jsx`, `NoteDetail.jsx`, `BrowseNotes.jsx`, `ReviewFlashcards.jsx`, `StudyMode.jsx`.

### Landing
- `src/components/landing/HeroFlipDemo.jsx` — Phase 5 S4 anonymous hero flip-card demo; controlled `FlipCard` + cosmetic Hard/Medium/Easy rating (no SRS writes); falls back to 3 hardcoded generic cards when no featured deck has teaser cards; ends with a "Sign up to save your progress" soft wall linking to `/signup`

### Public / Share Pages
- `src/pages/public/DeckPreview.jsx` — /deck/:deckId (OG tags via middleware.js)
- `src/pages/public/NotePreview.jsx` — /note/:noteId (OG tags via middleware.js)
- `src/pages/public/GroupJoin.jsx` — /join/:token
- `src/pages/public/Educators.jsx` — /educators, B2B institute lead form (Phase 5 S5). Zero direct `.from()`; calls `submit_institute_inquiry` RPC only.
- `middleware.js` — Vercel Edge Middleware injects OG tags for bots on /deck/* and /note/* and /join/*

### Admin
- `src/pages/admin/AdminDashboard.jsx` — user management, content flags, access requests (Type badge + filter, Phase 5 S5), batch groups, landing-page featured content curation queues (Phase 5 S3)
- `src/pages/admin/SuperAdminDashboard.jsx` — role promotion, hard delete via admin_delete_user_data RPC
- `src/pages/admin/MigrateNoteImages.jsx` — **TEMP: delete after note image migration confirmed complete**

### Supabase / Backend
- `src/lib/supabase.js` — Supabase client
- `src/lib/navActive.js` — pure `(pathname) => boolean` active-route predicates shared by NavDesktop + NavBottomTabs (Sprint 7.1); no Supabase, no React
- `src/lib/notifyEdge.js` — fire-and-forget helpers for Edge Function calls
- `src/lib/revisop-tokens.js` — RevisOp reskin shared JS (Phase 6 S6.1): `REVISOP_LITERATA_ENABLED` gate (off), `REVISOP_BUCKETS`, `bucketForDays()` / `ledgerFromForecast()`. No Supabase.
- `src/lib/mcq.js` — Sprint 7.5 MCQ authoring helpers shared by `FlashcardCreate.jsx` + `BulkUploadFlashcards.jsx`: `compactMcqOptions()` (drops blank option rows, remaps correct index by original position), `deriveMcqBackText()`, `toPointsToRemember()`, `validateMcqOptions()`. Pure functions, no Supabase, no React.
- `src/lib/matchTheFollowing.js` — Sprint 7.8 match_the_following authoring helpers, `FlashcardCreate.jsx` only (bulk upload deferred, 7.8-C): `keyForRightIndex()` (auto-generates A/B/C... right-item keys by list position), `buildMatchOptions()` (assembles the `{left,right,correct}` options jsonb shape), `deriveMatchBackText()`, `validateMatchPairs()`. Pure functions, no Supabase, no React.
- `src/lib/caseStudyMcq.js` — Sprint 7.10 case_study_mcq authoring helpers, used by both `FlashcardCreate.jsx` (manual) and `BulkUploadFlashcards.jsx` (CSV, unlike match_the_following's manual-only 7.8-C): `emptyCaseQuestion()` (fresh mcq-shaped question block), `validateCaseStudy()` (scenario + 2-8 question blocks, each validated via `validateMcqOptions()` from `src/lib/mcq.js` — a case question IS an mcq question). Row fan-out (one authoring block → N `flashcards` INSERTs sharing a `batch_id`) lives inline in each caller, not here. Pure functions, no Supabase, no React.
- `src/lib/fitb.js` — Sprint 7.11 fill-in-the-blank helpers, used by `FlashcardCreate.jsx`/`BulkUploadFlashcards.jsx` (authoring) and `StudyMode.jsx` (grading): `normalizeFitbAnswer()` (trim/lowercase/strip punctuation/collapse whitespace — called identically on the student's typed answer and every authored acceptable answer, must never diverge between call sites), `isFitbMatch()`, `deriveFitbBackText()` (first accepted answer), `validateFitbBlank()`/`validateFitbOptions()`/`compactFitbOptions()`, `splitFitbSentence()` (splits front_text around the blank marker for StudyMode's inline `<input>`). Pure functions, no Supabase, no React.
- `src/lib/provenance.js` — Sprint 8.7.4 D-21 display. `fetchBatchProvenanceMap(batchIds)` — queries `flashcard_batch_provenance` for a set of batch_ids, returns a `Map` keyed by `batch_id`. Missing ids (legacy pre-8.7.1 batches) simply have no entry. Used by every surface that queries flashcards directly (`MyFlashcards.jsx`, `StudyMode.jsx`, `NoteDetail.jsx`'s linked-flashcards list) — RPC-based surfaces (`ReviewFlashcards.jsx`, `BrowseNotes.jsx`) get provenance server-side instead, via `get_browsable_decks`/`get_browsable_notes`.
- `src/lib/conceptCard.js` — Sprint 7.12 concept_card authoring helpers, `FlashcardCreate.jsx` only (bulk upload deferred, same call as match_the_following's 7.8-C — keyTerms is a variable-length list of `{term, definition}` pairs, doesn't fit the flat CSV convention): `buildConceptOptions()` (drops any row missing either half of a term/definition pair), `validateConceptTerms()`, `emptyConceptTerm()`/`emptyConceptTerms()`. Pure functions, no Supabase, no React.
- `src/lib/questionTypes.js` — Sprint 7.6: `formatQuestionType()` (question_type slug → label; moved out of a `Dashboard.jsx`-local const so `ReviewFlashcards.jsx`'s Question Type filter uses identical labels) + `BROWSABLE_QUESTION_TYPES` (types with a real authoring path — `flashcard`/`mcq` since 7.6, `true_false`/`correct_incorrect`/`theory`/`test_your_understanding` added Sprint 7.7, `match_the_following` added Sprint 7.8, `case_study_mcq` added Sprint 7.10, `fitb` added Sprint 7.11, `concept_card` added Sprint 7.12 (`true_false`/`test_your_understanding` since removed, Sprint 7.9); extend this array, not JSX, for future types). **Sprint 7.7 additions:** `GRADED_QUESTION_TYPES` (`['mcq','correct_incorrect','case_study_mcq']` — drives StudyMode.jsx's shared AnswerOption-list rendering branch; `match_the_following`, `fitb`, and `concept_card` deliberately NOT added here — the first two render through their own StudyMode branch, `concept_card` never renders in StudyMode at all) + `VERDICT_OPTION_LABELS` (auto-populated option pairs for correct_incorrect authoring). Pure functions, no Supabase, no React.
- `src/lib/flashcardBatches.js` — Sprint 8.7.2, used by both `FlashcardCreate.jsx` (manual) and `BulkUploadFlashcards.jsx` (CSV): `groupCardsIntoBatches()` (folds a flat card-row list, each already carrying its own `batch_id`, into `create_flashcard_batches()`'s `p_batches` shape — `batch_description` deliberately stays on each card, not hoisted to the batch object, since the RPC reads it per-card), `isD10Rejection()`/`D10_REJECTION_MESSAGE` (matches the RPC's D-10 error message substring rather than hard-coding the restricted question_type list, which would drift from the RPC's own `v_verdict_types`). Extracted post-`/code-review` from near-identical duplicated logic in both pages. Pure functions, no Supabase, no React.
- `src/components/flashcards/ContentSourceFields.jsx` — Sprint 8.7.2, shared `source_type`/`source_name` form fields (required before calling `create_flashcard_batches()`), used by both `FlashcardCreate.jsx` and `BulkUploadFlashcards.jsx`. `compact` prop switches between `BulkUploadFlashcards.jsx`'s denser stepper styling and `FlashcardCreate.jsx`'s default Card spacing — visual parity with each page's pre-extraction markup, not a new look.
- `src/hooks/usePushNotifications.js` — Web Push permission + VAPID subscribe/unsubscribe
- `src/components/notifications/PushPermissionBanner.jsx` — one-time push opt-in prompt on Dashboard

### Course Context (Multi-Course Professors)
- `src/contexts/CourseContext.jsx` — activeCourse session state, addCourse/removeCourse/setPrimaryCourse
- `src/components/layout/CourseSwitcher.jsx` — indigo pill dropdown (only when ≥2 courses)

### Help & Guide
- `src/pages/dashboard/Help.jsx` — role-filtered, searchable, accordion mobile / sidebar desktop
- `src/data/helpContent.js` — single source of truth for all help content
- `src/pages/guide/StudentGuide.jsx` — public /guide page (no auth, no DB)
- `src/data/guideContent.js` — single source of truth for Student Guide + GuideInfoModal
- `src/components/shared/GuideInfoModal.jsx` — contextual modal on DeckPreview / NotePreview / GroupJoin (moved from `src/components/` root, 16/09/2026)
- `public/help-screenshots/*.png` — Sprint 8.3, first static content images this codebase has shipped (root-relative path, referenced by `helpContent.js`'s new `image` content-block type in `Help.jsx`). Dummy test-account/test-batch data only, resized/recompressed with `sharp` before commit.

### Configuration
- `vite.config.js` — manualChunks splits vendor bundles for caching
- `public/sw.js` — service worker (push + notificationclick + install/activate)
- `public/fonts/*.woff2` — self-hosted Latin-subset webfonts (Phase 6 S6.1): `plex-sans.woff2` (variable), `plex-mono-400/500.woff2`, `literata.woff2` (variable, gated off). `@font-face` in `src/index.css`, `font-display: swap`, same-origin — no font-CDN request.
- `vercel.json` — routing config
- `package.json` — React 19, React Router v7, Vite 7, Recharts, Tesseract.js

---

## FILE NAMING CONVENTIONS
- Pages (routes): PascalCase (e.g., `Dashboard.jsx`, `MyNotes.jsx`)
- Components: PascalCase (e.g., `Navigation.jsx`, `StudyTimerWidget.jsx`)
- Hooks: camelCase with `use` prefix (e.g., `useBadges.js`, `use-toast.js`)
- Utilities / libs: camelCase (e.g., `supabase.js`, `notifyEdge.js`)
- Data files: camelCase (e.g., `helpContent.js`, `guideContent.js`)
