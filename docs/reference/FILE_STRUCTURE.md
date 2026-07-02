# RECALL APP - FILE STRUCTURE
**Last Updated: July 2026 (Phase 5 Sprint 5)**

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
│   │   └── now.md                               ← current sprint status + session notes
│   ├── archive
│   │   ├── APPROVED_DECISIONS.md
│   │   ├── CONTEXT_FOR_CLAUDE.md
│   │   └── FEATURE_PRIORITY.md
│   ├── database
│   │   └── Reviews_Table_Usage.md
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
│   ├── App.jsx                                  ← all routes (lazy-loaded), CourseContextProvider, AppContent postAuthRedirect
│   ├── contexts
│   │   ├── AuthContext.jsx                      ← auth state, timezone sync, updateUserTimezone
│   │   └── CourseContext.jsx                    ← multi-course teaching context for professors/admins; activeCourse session state
│   ├── lib
│   │   ├── supabase.js                          ← Supabase client
│   │   ├── utils.js                             ← shadcn cn() utility
│   │   └── notifyEdge.js                        ← fire-and-forget helpers: notifyContentCreated(), notifyFriendEvent()
│   ├── hooks
│   │   ├── use-toast.js                         ← shadcn toast hook
│   │   ├── useActivityFeed.js                   ← recent content feed for dashboard activity section
│   │   ├── useBadges.js                         ← badge data fetching (get_unnotified_badges RPC)
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
│   │   │   └── StudyTimerWidget.jsx             ← manual offline study timer; clock via DOM ref (zero React re-renders/tick)
│   │   ├── flashcards
│   │   │   ├── FlashcardCard.jsx                ← standalone flashcard display/edit card component
│   │   │   ├── SpeakButton.jsx                  ← TTS volume icon with pulse animation
│   │   │   └── SpeechSettings.jsx               ← voice selector + speed slider popover
│   │   ├── layout
│   │   │   ├── ActivityDropdown.jsx             ← bell icon + notifications dropdown (group_invite inline Accept/Decline)
│   │   │   ├── CourseSwitcher.jsx               ← indigo pill dropdown for multi-course professors (session-only, no DB write)
│   │   │   ├── FriendsDropdown.jsx              ← friends icon + friend requests + following links
│   │   │   ├── NavDesktop.jsx                   ← desktop nav with dropdowns (Study▾, Create▾, Manage▾)
│   │   │   ├── Navigation.jsx                   ← orchestrator (55 lines); renders NavDesktop + NavMobile
│   │   │   ├── NavMobile.jsx                    ← hamburger sheet nav
│   │   │   ├── PageContainer.jsx                ← wrapper with width prop (full/medium/narrow)
│   │   │   └── ProfileDropdown.jsx              ← avatar dropdown (Settings, Help, Sign Out)
│   │   ├── notifications
│   │   │   └── PushPermissionBanner.jsx         ← one-time dismissible push prompt (Android: enable button; iOS: install guide)
│   │   ├── progress
│   │   │   ├── PlatformHeatmap.jsx              ← 52-week platform-wide heatmap (super_admin only; blue scale)
│   │   │   ├── StudyHeatmap.jsx                 ← 90-day per-user study heatmap (green scale)
│   │   │   └── SubjectMasteryTable.jsx          ← per-subject mastery %; responsive table + mobile card list
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
│   │       ├── sheet.jsx                        ← Radix Dialog-based slide-in Sheet (used by NavMobile)
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
│   │   ├── dev                                  ← DEV-ONLY pages (not in nav; safe to remove)
│   │   │   └── DesignShowcase.jsx               ← /__design — Phase 5 S1 token + component QA (no auth, no DB)
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
│   │   ├── professor
│   │   │   └── ProfessorTools.jsx               ← legacy; /professor/tools redirects to /dashboard/bulk-upload
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
│   │       │   └── ProfileSettings.jsx          ← /dashboard/settings (name, course, institution, push notifications, teaching areas)
│   │       └── Study
│   │           ├── Progress.jsx                 ← /dashboard/progress (heatmap, subject mastery, due forecast, question type perf)
│   │           ├── ReviewBySubject.jsx          ← /dashboard/review-by-subject
│   │           ├── ReviewFlashcards.jsx         ← /dashboard/review-flashcards (deck browser; "My Cards" pinned; share button)
│   │           ├── ReviewSession.jsx            ← /dashboard/review-session (due cards only)
│   │           └── StudyMode.jsx                ← /dashboard/study (SRS engine; TTS; Skip/Suspend/Reset; study time logging)
│   ├── GuideInfoModal.jsx                       ← shared contextual info modal for DeckPreview / NotePreview / GroupJoin
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
- `src/components/layout/Navigation.jsx` — orchestrator (thin, ~55 lines)
- `src/components/layout/NavDesktop.jsx` — desktop layout with dropdowns
- `src/components/layout/NavMobile.jsx` — hamburger + Sheet

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
- `src/lib/notifyEdge.js` — fire-and-forget helpers for Edge Function calls
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
- `src/components/GuideInfoModal.jsx` — contextual modal on DeckPreview / NotePreview / GroupJoin

### Configuration
- `vite.config.js` — manualChunks splits vendor bundles for caching
- `public/sw.js` — service worker (push + notificationclick + install/activate)
- `vercel.json` — routing config
- `package.json` — React 19, React Router v7, Vite 7, Recharts, Tesseract.js

---

## FILE NAMING CONVENTIONS
- Pages (routes): PascalCase (e.g., `Dashboard.jsx`, `MyNotes.jsx`)
- Components: PascalCase (e.g., `Navigation.jsx`, `StudyTimerWidget.jsx`)
- Hooks: camelCase with `use` prefix (e.g., `useBadges.js`, `use-toast.js`)
- Utilities / libs: camelCase (e.g., `supabase.js`, `notifyEdge.js`)
- Data files: camelCase (e.g., `helpContent.js`, `guideContent.js`)
