# Sprint 8.8.1 — Navigation & Discovery Inventory

**Type:** Read-only audit. No code changed, no IA proposed, no target structure recommended.
Every row below is traceable to a specific file:line read during this session. Where a doc
or a memory file said something different from the code, the code wins and the discrepancy
is called out inline.

---

## 1. Full Route Inventory

**Method:** Read `src/App.jsx` top to bottom (all `<Route>` elements inside `AppContent()`,
lines 171–387). For each route, grepped the codebase for every `<Link to=...>`, `navigate(...)`,
and `to={...}` reference to that path to find real entry points, rather than trusting the
route-map comment block at `App.jsx:128–168` (which is a comment, not verified code — it is
accurate for the component mapping but says nothing about reachability). Nav-shell entry
points were established by reading `src/components/layout/Navigation.jsx`, `NavDesktop.jsx`,
`NavMobile.jsx`, `NavBottomTabs.jsx`, `NavMenuSheet.jsx`, `ProfileDropdown.jsx`, and
`NotificationCenter.jsx` in full. "Route-level guard" means the guard written directly in the
`<Route element={...}>` ternary in `App.jsx`; an in-component check (done inside the page
itself, after mount) is called out separately since it is a different mechanism.

| # | Path | Component | Entry point(s) (all that apply) | Route-level role restriction |
|---|------|-----------|----------------------------------|-------------------------------|
| 1 | `/` | `pages/Home.jsx` | Direct URL / marketing (unauthenticated only — logged-in users are bounced to `/dashboard`, `App.jsx:172-174`) | None (public); redirects away if `user` truthy |
| 2 | `/signup` | `pages/auth/Signup.jsx` | `Home.jsx` (`:106-691`, multiple CTAs), `DeckPreview.jsx:94,156`, `NotePreview.jsx:71`, `StudentGuide.jsx`, `HeroFlipDemo.jsx:57` | None (public); redirects to `/dashboard` if already logged in (`App.jsx:178-180`) |
| 3 | `/login` | `pages/auth/Login.jsx` | `Home.jsx:106,130,204,691`, `DeckPreview.jsx:88,166`, `StudentGuide.jsx:68,108`, `Signup.jsx:308` | None (public); redirects to `/dashboard` if already logged in (`App.jsx:182-184`) |
| 4 | `/forgot-password` | `pages/auth/ForgotPassword.jsx` | `Login.jsx:113` — `onClick={() => navigate('/forgot-password')}` | None (`App.jsx:185`, no ternary) |
| 5 | `/reset-password` | `pages/auth/ResetPassword.jsx` | Deep-link only. Verified in code: `ForgotPassword.jsx:24-25` calls `supabase.auth.resetPasswordForEmail(email, { redirectTo: `${window.location.origin}/reset-password` })` — this is the source of the reset-password email link, not an in-app nav item | None (`App.jsx:186`, no ternary) |
| 6 | `/terms-of-service` | `pages/TermsOfService.jsx` | `Home.jsx:710` (footer link) | None (`App.jsx:189`) |
| 7 | `/privacy-policy` | `pages/PrivacyPolicy.jsx` | `Home.jsx:709` (footer link); cross-linked from `TermsOfService.jsx:292` | None (`App.jsx:190`) |
| 8 | `/join/:token` | `pages/public/GroupJoin.jsx` | Share-link only — generated in `GroupDetail.jsx:722,735` and `AdminDashboard.jsx:1590`; not a clickable nav item anywhere | None — public (`App.jsx:193`, comment "no auth guard" at `:192`) |
| 9 | `/deck/:deckId` | `pages/public/DeckPreview.jsx` | `Home.jsx:269` (featured decks on landing page) + share-link generated in `ReviewFlashcards.jsx:764` | None — public (`App.jsx:194`) |
| 10 | `/note/:noteId` | `pages/public/NotePreview.jsx` | `Home.jsx:281` (featured notes) + share-link generated in `NoteDetail.jsx:100` | None — public (`App.jsx:195`) |
| 11 | `/guide` | `pages/guide/StudentGuide.jsx` | `Home.jsx:114,124,659` | None — public (`App.jsx:196`) |
| 12 | `/educators` | `pages/public/Educators.jsx` | `Home.jsx:105,246,608,699` | None — public (`App.jsx:197`) |
| 13 | `/__design` | `pages/dev/DesignShowcase.jsx` | None — not in any nav by design; dev-only, route itself is conditionally registered only when `import.meta.env.DEV` (`App.jsx:79-81,199-203`) | N/A — dev build only, statically dropped in prod |
| 14 | `/dashboard` | `pages/Dashboard.jsx` | `Navigation` logo/Wordmark on both desktop (`NavDesktop.jsx:69-72`) and mobile (`NavMobile.jsx:28-30`); `NavDesktop.jsx:79-91` Dashboard link; `NavBottomTabs.jsx` Dashboard tab; `NavMenuSheet.jsx:135-141` | `user ? … : /login` (`App.jsx:206-209`) |
| 15 | `/dashboard/notes/new` | `Content/NoteUpload.jsx` | Desktop Create dropdown (`NavDesktop.jsx:172-176`); mobile Create sheet (`NavBottomTabs.jsx:98`); mobile hamburger Create section (`NavMenuSheet.jsx:230-235`) | `user ? … : /login` (`:212-215`) |
| 16 | `/dashboard/notes/:id` | `Content/NoteDetail.jsx` | In-page only, from `BrowseNotes.jsx:654,671`, `MyNotes.jsx:312`, `MyContributions.jsx:387`; also the post-auth target of `NotePreview.jsx:25,50` | `user ? … : /login` (`:216-219`) |
| 17 | `/dashboard/notes` | `Content/BrowseNotes.jsx` | Desktop "Browse Notes" in Study dropdown (`NavDesktop.jsx:139-143`); mobile hamburger Study section (`NavMenuSheet.jsx:207-213`) | `user ? … : /login` (`:220-223`) |
| 18 | `/dashboard/my-notes` | `Content/MyNotes.jsx` | **No nav-shell entry point.** Reachable only via `Dashboard.jsx:818` (inside the Professor-only render block, see §5) and `MyContributions.jsx:253,574` | `user ? … : /login` (`:224-227`) |
| 19 | `/dashboard/notes/edit/:id` | `Content/NoteEdit.jsx` | In-page only, from `NoteDetail.jsx:229` | `user ? … : /login` (`:228-231`) |
| 20 | `/notes/edit/:id` (legacy) | `LegacyNoteEditRedirect` (inline in `App.jsx:98-101`) | Old bookmarks only; immediately redirects to #19 | N/A — pure redirect, no gate of its own |
| 21 | `/dashboard/flashcards/new` | `Content/FlashcardCreate.jsx` | Desktop Create dropdown (`NavDesktop.jsx:177-182`); mobile Create sheet (`NavBottomTabs.jsx:99`); mobile hamburger (`NavMenuSheet.jsx:236-242`) | `user ? … : /login` (`:239-242`) |
| 22 | `/dashboard/flashcards` | `Content/MyFlashcards.jsx` | **No nav-shell entry point.** Reachable only via `Dashboard.jsx:835` (Professor block only), `MyContributions.jsx:270,582`, and the post-upload redirect in `BulkUploadFlashcards.jsx:1192` | `user ? … : /login` (`:243-246`) |
| 23 | `/dashboard/review-flashcards` | `Study/ReviewFlashcards.jsx` | Desktop "Browse Study Sets" (`NavDesktop.jsx:132-137`); mobile hamburger "Browse Study Sets" (`NavMenuSheet.jsx:200-206`) | `user ? … : /login` (`:247-250`) |
| 24 | `/dashboard/review-session` | `Study/ReviewSession.jsx` | Desktop "Today's Reviews" in Study dropdown (`NavDesktop.jsx:119-131`); mobile bottom-tab "Review" (`NavBottomTabs.jsx:61-67`); mobile hamburger "Today's Reviews" (`NavMenuSheet.jsx:193-199`) | `user ? … : /login` (`:251-254`) |
| 25 | `/dashboard/study` | `Study/StudyMode.jsx` | **Not in any nav.** Reached only via `navigate()` from `ReviewFlashcards.jsx:394` with query params, i.e. a deck action, not a nav destination | `user ? … : /login` (`:255-258`) |
| 26 | `/dashboard/practice` | `Study/PracticeMode.jsx` | **Not in any nav.** Reached only via `navigate()` from `ReviewFlashcards.jsx:403,418` with query params | `user ? … : /login` (`:259-262`) |
| 27 | `/dashboard/my-cards` | `Study/MyCards.jsx` ("My Study") | Desktop Study dropdown (`NavDesktop.jsx:144-149`); mobile hamburger Study section (`NavMenuSheet.jsx:214-220`) | `user ? … : /login` (`:263-266`) |
| 28 | `/dashboard/study-time` | `Study/StudyTimePage.jsx` | Desktop Create dropdown (`NavDesktop.jsx:190-195`); mobile Create sheet (`NavBottomTabs.jsx:146-151`); `StudyTimerChip.jsx:61` (both desktop and mobile chip). **Absent from `NavMenuSheet.jsx`** — not reachable from the mobile hamburger menu at all | `user ? … : /login` (`:267-270`) |
| 29 | `/dashboard/review-by-subject` | `Study/ReviewBySubject.jsx` | **Unreachable from any nav or any in-app `navigate()`/`Link` call.** Only two references exist in the whole codebase outside `App.jsx` itself: the highlight-grouping arrays in `src/lib/navActive.js:43,72`. This route is orphaned. | **No route-level guard at all** — `element={<ReviewBySubject />}` (`:271-274`), unlike every other `/dashboard/*` route. The page self-redirects to `/login` if `!user` inside the component (`ReviewBySubject.jsx:34-35`), which compensates for the missing route guard |
| 30 | `/dashboard/progress` | `Study/Progress.jsx` ("My Progress") | Mobile bottom-tab "Progress" (`NavBottomTabs.jsx:70-76`); `ProfileDropdown.jsx:91-96` "My Progress"; `NavMenuSheet.jsx:277-283` "My Progress" | `user ? … : /login` (`:277-280`) |
| 31 | `/dashboard/my-contributions` | `Content/MyContributions.jsx` | `ProfileDropdown.jsx:97-102`; `NavMenuSheet.jsx:284-290` | `user ? … : /login` (`:281-284`) |
| 32 | `/dashboard/achievements` | `Profile/MyAchievements.jsx` | `ProfileDropdown.jsx:103-108`; `NavMenuSheet.jsx:291-297`; also a notification-link target (`NotificationCenter.jsx:165`) | **No route-level guard at all** — `element={<MyAchievements />}` (`:285-288`). Unlike `ReviewBySubject`, this page does **not** self-redirect on `!user` — it only no-ops its data fetch (`MyAchievements.jsx:32,78: if (!user) return;`), so an anonymous visitor hitting this URL directly sees an empty shell, not a login redirect |
| 33 | `/dashboard/my-reports` | `Profile/MyReports.jsx` ("Report History") | `ProfileDropdown.jsx:109-114`; `NavMenuSheet.jsx:298-304` | `user ? … : /login` (`:289-292`) |
| 34 | `/dashboard/profile/:userId` | `Profile/AuthorProfile.jsx` | In-page author-name links only, e.g. `ReviewFlashcards.jsx:700` | `user ? … : /login` (`:293-296`) |
| 35 | `/dashboard/settings` | `Profile/ProfileSettings.jsx` | `ProfileDropdown.jsx:121-126`; `NavMenuSheet.jsx:312-318` | `user ? … : /login` (`:297-300`) |
| 36 | `/dashboard/help` | `dashboard/Help.jsx` ("Help & Guide") | `ProfileDropdown.jsx:115-120`; `NavMenuSheet.jsx:305-311` | `user ? … : /login` (`:301-304`) |
| 37 | `/dashboard/groups` | `Groups/MyGroups.jsx` | Desktop "Groups" link (`NavDesktop.jsx:200-212`); mobile hamburger "Study Groups" (`NavMenuSheet.jsx:258-264`) — see duplicate-label finding in §4 | `user ? … : /login` (`:307-310`) |
| 38 | `/dashboard/groups/new` | `Groups/CreateGroup.jsx` | Mobile Create sheet only (`NavBottomTabs.jsx:100`); in-page buttons in `MyGroups.jsx:208,286`, and cross-links from `NoteUpload.jsx:675` and `FlashcardCreate.jsx:1421`. **Not in the desktop Create dropdown** — desktop must go Groups → MyGroups → button | `user ? … : /login` (`:311-314`) |
| 39 | `/dashboard/groups/:groupId` | `Groups/GroupDetail.jsx` | In-page only, from `MyGroups.jsx:298` | `user ? … : /login` (`:315-318`) |
| 40 | `/dashboard/find-friends` | `Friends/FindFriends.jsx` ("Find People") | `NotificationCenter.jsx:419` (bell dropdown, shared by desktop + mobile) | `user ? … : /login` (`:321-324`) |
| 41 | `/dashboard/friend-requests` | `Friends/FriendRequests.jsx` | `NotificationCenter.jsx:364,434` | `user ? … : /login` (`:325-328`) |
| 42 | `/dashboard/my-friends` | `Friends/MyFriends.jsx` | `NotificationCenter.jsx:424` | `user ? … : /login` (`:329-332`) |
| 43 | `/dashboard/following` | `Friends/Following.jsx` | `NotificationCenter.jsx:429` **and** `NavMenuSheet.jsx:265-271` (Groups section) — two separate entry points | `user ? … : /login` (`:333-336`) |
| 44 | `/dashboard/professor-analytics` | `dashboard/ProfessorAnalytics.jsx` | Desktop, `isProfessor`-gated link (`NavDesktop.jsx:215-229`); mobile hamburger, `isProfessor`-gated (`NavMenuSheet.jsx:320-338`) | Route: `user ? … : /login` (`:339-342`). **In-component** redirect to `/dashboard` if `!isProfessor` (`ProfessorAnalytics.jsx:83-88`) |
| 45 | `/super-admin` | `admin/SuperAdminDashboard.jsx` | Desktop Manage dropdown, `isSuperAdmin`-gated (`NavDesktop.jsx:268-275`); mobile hamburger Super Admin section (`NavMenuSheet.jsx:375-390`) | Route: `user ? … : /login` (`:345-348`). **In-component** inline "Access Denied" render if `!isSuperAdmin` (`SuperAdminDashboard.jsx:609-623`) |
| 46 | `/super-admin/analytics` | `admin/SuperAdminAnalytics.jsx` | Desktop Manage dropdown (`NavDesktop.jsx:276-281`); mobile hamburger (`NavMenuSheet.jsx:391-397`) | Route guard as above. **In-component** inline "Access Denied" if `!isSuperAdmin` (`SuperAdminAnalytics.jsx:181-189`) |
| 47 | `/admin` | `admin/AdminDashboard.jsx` | Desktop Manage dropdown, `isAdmin\|\|isSuperAdmin`-gated (`NavDesktop.jsx:250-255`); mobile hamburger Admin section (`NavMenuSheet.jsx:341-356`) | Route: `user ? … : /login` (`:353-356`). **In-component** inline "Access Denied" if `!isAdmin && !isSuperAdmin` (`AdminDashboard.jsx:605-623`) |
| 48 | `/admin/analytics` | `admin/AdminAnalytics.jsx` | Desktop Manage dropdown (`NavDesktop.jsx:256-261`); mobile hamburger (`NavMenuSheet.jsx:357-363`) | Route guard as above. **In-component** `useEffect` redirect to `/dashboard` if `!isAdmin && !isSuperAdmin` (`AdminAnalytics.jsx:59-65`) — note this is a **different** enforcement style than `/admin` itself (redirect vs. inline message) |
| 49 | `/dashboard/bulk-upload` | `dashboard/BulkUploadFlashcards.jsx` | Desktop Create dropdown only (`NavDesktop.jsx:183-188`); mobile hamburger (`NavMenuSheet.jsx:243-249`). **Deliberately absent from the mobile Create sheet** — comment at `NavBottomTabs.jsx:84-86`: "CSV import isn't a phone workflow" | `user ? … : /login` (`:363-366`). No page-level role gate — any authenticated user can open it; a per-row content restriction applies at submit time (see §2) |
| 50 | `/admin/bulk-upload-topics` | `admin/BulkUploadTopics.jsx` | Desktop Manage dropdown (`NavDesktop.jsx:262-267`); mobile hamburger (`NavMenuSheet.jsx:364-370`); `Dashboard.jsx:989,1085` (Admin and Super-Admin dashboard blocks) | Route guard as above. **In-component** inline "Access Denied" if `!isAdmin && !isSuperAdmin` (`BulkUploadTopics.jsx:779-789`) |
| 51 | `/admin/migrate-note-images` | `admin/MigrateNoteImages.jsx` | **Unreachable from any nav or in-app link.** TEMP migration route (comment at `App.jsx:371` and `MigrateNoteImages.jsx:4`) | Route: `user ? … : /login` (`:373-375`) only. **No in-component role check exists at all** — grepped the file for `isAdmin`/`isSuperAdmin`/`isProfessor`/`useRole`, zero matches. Any authenticated user who knows the URL can open it |
| 52 | `/professor/tools` (legacy) | Inline redirect (`App.jsx:379-381`) | Not linked anywhere in current code; old-bookmark redirect to #49 | `user ? redirect : /login` |
| 53 | `*` (catch-all) | Inline redirect to `/` (`App.jsx:384-387`) | N/A | N/A |

**Discrepancy flag:** routes #29 (`review-by-subject`) and #32 (`achievements`) break the
otherwise-universal `user ? <Component/> : <Navigate to="/login"/>` pattern used by all other
`/dashboard/*` routes — both render unconditionally at the route level. `blueprint.md` /
`now.md` were not consulted for this table (per the ground rule), so if either doc describes
these two routes as guarded the same way as the rest, the code above is authoritative.

---

## 2. Full Create-Action Inventory

**Method:** Found the two actual Create surfaces by reading `NavDesktop.jsx:153-197` (desktop
"Create" dropdown) and `NavBottomTabs.jsx:88-156` (mobile "＋" bottom-sheet, component
`CreateAction`) — there is no third Create surface; grepped `Dashboard.jsx` for
`notes/new|flashcards/new|bulk-upload|groups/new|study-time` and found no additional
quick-create cards there (only an admin shortcut to Bulk Upload Topics, not a content-create
action). Each target page was then read for its role gate and its post-success `navigate()`
call.

Two columns distinguish **whether the action is reachable on that platform at all** from
**whether it appears inside that platform's dedicated Create control** (the desktop Create
dropdown / the mobile "＋" sheet) — these are not the same question, and collapsing them into a
single yes/no cell was corrected after review.

| Action (UI label) | Route / component | Content vs. activity | Starts immediately vs. opens a screen | Role/permission restriction | Desktop — reachable at all / via Create dropdown | Mobile — reachable at all / via Create sheet | Return navigation after completion |
|---|---|---|---|---|---|---|---|
| Upload Note | `/dashboard/notes/new` → `NoteUpload.jsx` | Creates content (a note) | Opens a full screen | None on the route; any authenticated user | Yes / Yes — `NavDesktop.jsx:172-176` | Yes / Yes — `NavBottomTabs.jsx:98` | `navigate('/dashboard')` on success (`NoteUpload.jsx:387`) |
| Create Study Item | `/dashboard/flashcards/new` → `FlashcardCreate.jsx` | Creates content (a flashcard / concept card) | Opens a full screen | No page-level gate, but "graded" question types (mcq, mcq_multi, correct_incorrect, case_study_mcq, fitb, match_the_following) require professor/admin/super_admin — `canAuthorGradedTypes = isProfessor \|\| isAdmin \|\| isSuperAdmin` (`FlashcardCreate.jsx:93-100`); students can still create front/back and concept cards | Yes / Yes — `NavDesktop.jsx:177-182` | Yes / Yes — `NavBottomTabs.jsx:99` | `navigate('/dashboard')` on success (`FlashcardCreate.jsx:682,1051`) |
| Bulk Upload | `/dashboard/bulk-upload` → `BulkUploadFlashcards.jsx` | Creates content (many flashcards at once, CSV-style) | Opens a full screen | No page-level gate; but rows of the same "graded" question types require a professor/admin account or are rejected at upload (`BulkUploadFlashcards.jsx:271,1079-1107`) | Yes / Yes — `NavDesktop.jsx:183-188` | **Yes / No** — reachable on mobile via the hamburger menu (`NavMenuSheet.jsx:243-249`), but deliberately excluded from the mobile Create sheet specifically (`NavBottomTabs.jsx:84-86` comment: "CSV import isn't a phone workflow") | `navigate('/dashboard/flashcards')` on completion (`BulkUploadFlashcards.jsx:1192`) |
| Create Group | `/dashboard/groups/new` → `CreateGroup.jsx` | Creates content (a study group) | Opens a full screen | None found; any authenticated user | **Yes / No** — reachable on desktop via the Groups nav link → `MyGroups.jsx` → in-page "Create Group" button (`MyGroups.jsx:208,286`), but not present in the desktop Create dropdown itself | Yes / Yes — `NavBottomTabs.jsx:100` | `navigate('/dashboard/groups/${groupId}')` — lands on the **new group's own detail page**, not `/dashboard` (`CreateGroup.jsx:67`) — a different return pattern than every other Create action |
| Log Study Time | `/dashboard/study-time` → `StudyTimePage.jsx` (hosts `StudyTimerWidget`) | Logs an activity/session (offline study time), not content | Opens a full screen first; the timer itself then starts/stops with one click inside that screen (`StudyTimerWidget.jsx:92,98` `handleStart`/`handleStop`) — it does not start immediately from the nav itself | None found | Yes / Yes — `NavDesktop.jsx:190-195`, plus the persistent `StudyTimerChip` (`NavDesktop.jsx:297`) | Yes / Yes — `NavBottomTabs.jsx:146-151`, plus `StudyTimerChip` (`NavMobile.jsx:34`, `StudyTimerChip.jsx:61`). **Absent from `NavMenuSheet.jsx`** — no hamburger-menu entry at all, unlike Bulk Upload above | No navigation after Stop — `StudyTimerWidget.jsx` contains no `navigate()` call; the user stays on the same page |

**Finding for Phasebuilder:** the seed brief named four actions (single card, note, bulk
upload, offline timer). The actual Create surfaces expose **five** distinct actions — **Create
Group** is a full create action reachable from the mobile Create sheet
(`NavBottomTabs.jsx:97-101`) that has no desktop-Create-dropdown equivalent (though it is
reachable on desktop by a different path, via Groups → MyGroups). The two dedicated Create
controls are not parallel: desktop Create dropdown = {Upload Note, Create Study Item, Bulk
Upload, Log Study Time}; mobile Create sheet = {Upload Note, Create Study Item, Create Group,
Log Study Time}. Only 3 of the 5 actions appear in both dedicated Create controls — but all 5
are reachable on both platforms once the hamburger menu / MyGroups page are counted, so this is
a **Create-surface parity gap**, not a platform-reachability gap.

---

## 3. Role-Scoping Inventory

**Method:** Read `src/contexts/AuthContext.jsx` in full, `src/hooks/useRole.js` in full, and
`src/contexts/NavDataContext.jsx` in full. Then grepped `src/pages/**` for
`isProfessor|isAdmin|isSuperAdmin` (14 files matched) and read the surrounding lines in each
admin/professor page plus `GroupDetail.jsx` and `NoteDetail.jsx` to classify how the flag is
used in each. Grepped for `ProtectedRoute|RequireRole|RoleGuard` across `src/` — zero matches.

**Discrepancy vs. the sprint brief:** the brief assumed role logic lives in
`src/contexts/AuthContext.jsx`. It does not — `AuthContext.jsx` (194 lines, read in full) holds
only `user`, `loading`, `signIn`, `signUp`, `signOut`. It has no `role` field and no role
values anywhere in it. Role is a **separate** hook, `src/hooks/useRole.js`, wired into the app
once via `src/contexts/NavDataContext.jsx`.

| Mechanism | Where | What it does |
|---|---|---|
| Role source | `useRole.js:22-30` | Queries `profiles.role` (single row, by `user.id`) on every user change; falls back to `'student'` on error or null (`:34,39,57`) |
| Role values | `useRole.js:77-80` | Exactly four: `super_admin`, `admin`, `professor`, `student` (default). `isAdmin` is **true for both** `admin` and `super_admin` (`:78`); `isProfessor` is exclusive to `professor` (`:79`) |
| Permissions | `useRole.js:42-52,63-75` | A second query to `role_permissions` by role name, with a 9-flag client-side default object (`can_manage_users`, `can_bulk_upload`, etc.) if that query fails. `hasPermission()` (`:82-85`) is exposed but not observed in use in any of the files read this session |
| App-wide singleton | `NavDataContext.jsx:33-39,92-105` | `useRole()` is called exactly once, in `<NavDataProvider>` (mounted above the router in `App.jsx:403-419`). Every consumer reads the shared context via the drop-in `useRole` export (`NavDataContext.jsx:92-105`) instead of re-querying |
| Route-level guard | `App.jsx`, all `/dashboard/*` and admin/super-admin routes | Checks **only** `user` truthiness (`user ? <X/> : <Navigate to="/login"/>`) — never role. Two routes (`review-by-subject`, `achievements`) don't even do this (§1) |
| In-component guard, style A — inline "Access Denied" | `AdminDashboard.jsx:614-623`, `SuperAdminDashboard.jsx:609-623`, `SuperAdminAnalytics.jsx:181-189`, `BulkUploadTopics.jsx:779-789` | Same URL loads for anyone logged in; the component itself renders an `<Alert>` "Access Denied" in place of its content if the role check fails. No redirect, no URL change |
| In-component guard, style B — `useEffect` redirect | `ProfessorAnalytics.jsx:83-88`, `AdminAnalytics.jsx:59-65` | `navigate('/dashboard', { replace: true })` inside a `useEffect` if the role check fails. Different UX from style A for a comparable failure case (silent bounce vs. visible denial message) |
| In-component guard, style C — none | `MigrateNoteImages.jsx` | No role check of any kind (grepped the whole file for `isAdmin`/`isSuperAdmin`/`isProfessor`/`useRole` — zero hits). Only the route-level `user` check applies |
| Nav-item conditional rendering | `NavDesktop.jsx:215,232,268`; `NavMenuSheet.jsx:321,341,375` | `isProfessor && (...)`, `(isAdmin \|\| isSuperAdmin) && (...)`, `isSuperAdmin && (...)` gate whole menu sections. Same pattern, same flags, in both desktop and mobile nav components — this part is consistent |
| Separate layouts per role | **None as separate files/components.** `Dashboard.jsx` is ONE component/ONE route (`/dashboard`) that internally branches into four disjoint JSX blocks on `userRole`: `=== 'professor'` (`Dashboard.jsx:639`), `=== 'admin'` (`:934`), `=== 'super_admin'` (`:1030`), and a plain `else` that is the student view **and** the fallback for any unrecognized/null role (`:1169-1171`) | All four blocks live in the same file and share state/fetch logic above the branch |
| In-page permission checks (not page-access gates) | `BulkUploadFlashcards.jsx:1079-1107`, `FlashcardCreate.jsx:93-100`, `NoteDetail.jsx:212` | Role flags used to gate a specific field/row/button inside an otherwise-shared page, not the page itself. Different category from all the guards above |
| **Naming collision** | `GroupDetail.jsx:51` | `const [isAdmin, setIsAdmin] = useState(false)` — this is **local component state** meaning "is this user an admin/creator of *this group*", set by a separate members-lookup effect. It has no relationship to the global `useRole().isAdmin` (site admin/super_admin) despite the identical name. `GroupDetail.jsx` does not import `useRole` or `useNavData` at all. Anyone reusing role-scoping logic from this file by name alone would silently reuse the wrong concept |

---

## 4. Duplicate-Entry-Point Inventory

**Method:** Verified each of the four seeded pairs by reading the actual target components and
every Link/label pointing at them (already cited in §1). Then grepped nav-label text
(`grep "My Cards|My Flashcards|My Study"`, `grep "Discover|/dashboard/search|SearchPage"`) and
walked `MyContributions.jsx`, `MyNotes.jsx`, `MyFlashcards.jsx` for additional overlapping
concepts not in the seed list.

| # | Concept | Routes / labels involved | Same component, overlapping data, or genuinely different? | Verdict |
|---|---|---|---|---|
| 1 | Today's Reviews vs. Review | "Today's Reviews" (`NavDesktop.jsx:120-124`, `NavMenuSheet.jsx:193-199`) and "Review" (mobile bottom tab, `NavBottomTabs.jsx:61-67`) | **Same route, same component** (`/dashboard/review-session` → `ReviewSession.jsx`) | Not a true duplicate destination — one destination, two labels depending on which nav surface you're on |
| 2 | My Cards vs. My Study | Nav-facing label today is uniformly **"My Study"** (`NavDesktop.jsx:147`, `NavMenuSheet.jsx:219`) → `/dashboard/my-cards` → `MyCards.jsx`, whose own `<h1>` reads "My Study" (`MyCards.jsx:416`) | "My Cards" survives only as: the route path segment (`/dashboard/my-cards`), the backend RPC name (`get_my_cards`, referenced in `ReviewFlashcards.jsx:411`), scattered code comments, and **one dropdown filter option** literally labeled "My Cards (Private & Public)" inside `ReviewFlashcards.jsx:548` (a source-filter value, not a nav destination) | **Already resolved in the UI** — there is no second nav destination called "My Cards" today. The seed pair is stale; only the legacy name lingers in code/DB, not in any user-facing nav |
| 3 | Browse Study Sets vs. Search | "Browse Study Sets" → `/dashboard/review-flashcards` (`NavDesktop.jsx:132-137`) | Grepped for `Discover`, `/dashboard/search`, `SearchPage` — zero matches anywhere in `src/`. "Search" is an `<input>` embedded inside `ReviewFlashcards.jsx` itself (`:34,455`) | **Not a real duplicate** — there is no separate Search route; search is in-page filtering on the same destination |
| 4 | Browse Notes vs. Search/Discover | "Browse Notes" → `/dashboard/notes` (`NavDesktop.jsx:139-143`) | Same result as #3 — no `Discover` route exists; search is an embedded `<input>` inside `BrowseNotes.jsx` itself (`:28,426`) | **Not a real duplicate**, same reasoning as #3 |
| 5 (new) | Groups vs. Study Groups | Desktop label "Groups" (`NavDesktop.jsx:200-212`) vs. mobile hamburger label "Study Groups" (`NavMenuSheet.jsx:258-264`) | **Same route, same component** (`/dashboard/groups` → `MyGroups.jsx`) | Label inconsistency across surfaces, same pattern as #1 |
| 6 (new) | Progress vs. My Progress | Mobile bottom-tab label "Progress" (`NavBottomTabs.jsx` TABS array, `:70-76`) vs. "My Progress" in `ProfileDropdown.jsx:91-96` and `NavMenuSheet.jsx:277-283` | **Same route, same component** (`/dashboard/progress` → `Progress.jsx`) | Label inconsistency across surfaces, same pattern as #1 |
| 7 (new) | My Contributions vs. My Notes vs. My Study Sets | "My Contributions" (`/dashboard/my-contributions` → `MyContributions.jsx`) queries **both** `notes` (`:43`) and `flashcards` (`:52`) tables directly and renders an aggregate "your content" view (h1 at `:240-243`), with in-page buttons that jump into `/dashboard/my-notes` (`:253,574`) and `/dashboard/flashcards` (`:270,582`) — which are the **same two content types** shown standalone, one-per-page, on those two routes (h1s: "My Notes" at `MyNotes.jsx:413`, "My Study Sets" at `MyFlashcards.jsx:724`) | Overlapping data (a user's own notes + flashcards), three different components, three different UIs (aggregate stats/engagement view vs. two plain list-manage views) | Genuine three-way overlap not in the seed list. Also note: none of the three routes/labels involved here is directly reachable from the persistent nav shell except "My Contributions" itself (§1, rows 18 & 22) |
| 8 (new, minor) | Help & Guide vs. `/guide` | "Help & Guide" → `/dashboard/help` → `Help.jsx` (authed, data from `helpContent.js`) vs. public `/guide` → `StudentGuide.jsx` (unauthenticated, data from `guideContent.js`) | Different components, different data files, different audiences — confirmed by reading both imports | **Not a duplicate** — flagging only because the names are similar enough to cause confusion in conversation/planning, not because the destinations overlap |

---

## 5. Home vs. Review Overlap Inventory

**Method:** Confirmed which page is the authed home by reading `App.jsx:171-174` — `/` renders
`Home.jsx` only when `!user`; a logged-in user hitting `/` is redirected to `/dashboard`, which
renders `Dashboard.jsx`. So `Dashboard.jsx` is the authed home and `Home.jsx` is the
unauthenticated public landing page (not part of this comparison). Read `Dashboard.jsx`'s
state declarations (`:102-174`), its `@/components` imports (`:20-31`), and its four role-branch
JSX blocks (`:639,934,1030,1171`, see §3). Read `ReviewSession.jsx` in full (269 lines) as the
actual study-queue page reachable at `/dashboard/review-session` (the "Review"/"Today's
Reviews" destination from §1/§4).

| # | Aspect | Dashboard.jsx (authed home, `/dashboard`) | ReviewSession.jsx (study-queue page, `/dashboard/review-session`) | Overlap? |
|---|---|---|---|---|
| 1 | Widgets / components owned | `OnboardingModal`, `ExamDatePromptModal`, `LeaderboardWidget`, `GoalProgressWidget`, `ActivityFeed`, `PushPermissionBanner`, `BadgeToast` (imports, `:20-30`) | None of the above — only plain `Card`/`Button` primitives (`:4-5`) | No |
| 2 | Exam-date UI | Exam-countdown card + exam-runway strip, student block only (`:1188-1252`) | Not present | No |
| 3 | Content-flag widgets | "Needs Attention" list, professor-only (`:655-719`); "Needs Review" count, admin/super-admin, rendered once per role block (`:1008-1023`, `:1147-1162`) | Not present | No |
| 4 | Study-time stats | `studyTimeStats` via `get_study_time_stats` RPC (`:448`) | Not present | No |
| 5 | Role branching | Four disjoint JSX blocks on `userRole` — professor/admin/super_admin/student (`:639,934,1030,1171`, detailed in §3) | None — single view for every role | No |
| 6 | Due-queue data source | Calls `get_study_queue` RPC once (`:349`), comment "single source of truth" (`:347-348`) — but uses the result **only for a count** (`reviewsDue`, `:350`), consumed by exactly one JSX gate `reviewsDue === 0` (`:1288`). The due cards themselves are never rendered on the Dashboard | Calls the **same** `get_study_queue` RPC (`:39-40`), same "single source of truth" comment (`:36-38`) — but maps the full result into card objects (`:45-80`), groups them by subject (`:97-110`), and renders a clickable subject list with due counts (`:241-264`); selecting one embeds `StudyMode` in place (`:178-182`) to actually run the review | **Yes — same RPC/data source, non-overlapping presentation.** This is the one real overlap point between the two pages |
| 7 | Historical precedent | Comment at `:1284-1287` records that a near-identical overlap existed before and was deliberately removed in Sprint 7.2-D: a standalone "N items ready" / "All caught up" CTA card was deleted because it duplicated the header subtitle and the nav Review-tab due badge (7.2-F). The current `reviewsDue` count is what's left of that — it now drives only the `=== 0` branch, not a displayed number | N/A | This exact category of overlap has been found and partially resolved once before, per the code's own comment |
