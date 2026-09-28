/**
 * navActive.js — shared active-route predicates for the nav shell.
 *
 * Sprint 7.1 factored these out of NavDesktop.jsx so NavDesktop (desktop nav)
 * and NavBottomTabs (mobile bottom bar) resolve the active item from ONE place.
 *
 * Every function is a pure predicate over `pathname` (string). The Sprint 6.0 /
 * 6.2 nested-route tie-break is LOCKED — behaviour here must stay byte-identical
 * to NavDesktop's previous inline helpers:
 *   - exact match only for the top-level Dashboard link
 *   - prefix ("under") match keeps a parent highlighted on nested routes
 *   - Create wins the tie against Study's broader prefixes
 *     (/dashboard/flashcards/new → Create, /dashboard/notes/new → Create)
 */

/** Exact match — only for the top-level Dashboard link (every route lives under /dashboard). */
export const isExact = (pathname, path) => pathname === path;

/**
 * Prefix match — a route is "under" `path` when it equals it or is nested beneath it.
 * Keeps the parent nav item highlighted on nested routes (e.g. /dashboard/notes/:id).
 */
export const underAny = (pathname, paths) =>
  paths.some((p) => pathname === p || pathname.startsWith(p + '/'));

/**
 * Create routes are nested under /dashboard/notes and /dashboard/flashcards, so
 * Create must win the tie against Study's broader prefixes.
 */
export const isCreateActive = (pathname) =>
  underAny(pathname, [
    '/dashboard/notes/new',
    '/dashboard/flashcards/new',
    '/dashboard/bulk-upload',
  ]);

/**
 * Desktop rail Tier-1 "Review" active-state (Sprint 8.8.3).
 *
 * Deliberately narrower than the old isStudyActive/isReviewTabActive clusters:
 * Browse Study Sets (`/dashboard/review-flashcards`) is now its own Tier-3 rail
 * row (temporary, pending Discover — D-36), so it must NOT also light up Review,
 * or two rail rows would show active at once. Review lights only for the actual
 * review/study-session cluster.
 */
export const isReviewRailActive = (pathname) =>
  underAny(pathname, [
    '/dashboard/review-session',
    '/dashboard/review-by-subject',
    '/dashboard/study',
  ]);

/** Desktop rail Tier-1 "My Study" active-state. */
export const isMyStudyActive = (pathname) =>
  underAny(pathname, ['/dashboard/my-cards']);

/**
 * Desktop rail Tier-1 "Discover" active-state (Sprint 8.8.5, D-33/D-36).
 *
 * Its own route identity, not a combined alias over the retired
 * isBrowseStudySetsActive/isBrowseNotesActive predicates — D-36 explicitly
 * made Discover its own route, and the old Browse routes it composes
 * (/dashboard/review-flashcards, /dashboard/notes) stay directly routable
 * without lighting up this nav item (D-37 rows 3/4: they retire as separate
 * nav labels, the routes/components survive underneath).
 */
export const isDiscoverActive = (pathname) =>
  underAny(pathname, ['/dashboard/discover']);

/** Desktop rail Tier-3 "Progress" active-state. Same rule as the mobile bottom tab's inline check. */
export const isProgressActive = (pathname) =>
  underAny(pathname, ['/dashboard/progress']);

/**
 * Desktop rail Tier-3 "My Contributions" active-state — the parent plus its two
 * drill-downs (My Notes, My Study Sets/MyFlashcards — D-37 row 7). Guarded
 * against Create the same way the old isStudyActive was, since /dashboard/flashcards
 * is a prefix of /dashboard/flashcards/new.
 */
export const isMyContributionsActive = (pathname) =>
  !isCreateActive(pathname) &&
  underAny(pathname, [
    '/dashboard/my-contributions',
    '/dashboard/my-notes',
    '/dashboard/flashcards',
  ]);

/** Desktop rail Tier-3 "Report History" active-state. */
export const isReportHistoryActive = (pathname) =>
  underAny(pathname, ['/dashboard/my-reports']);

/** Desktop rail Tier-3 "Achievements" active-state. */
export const isAchievementsActive = (pathname) =>
  underAny(pathname, ['/dashboard/achievements']);

/** Desktop "Manage" dropdown active-state. */
export const isManageActive = (pathname) =>
  pathname.startsWith('/admin') || pathname.startsWith('/super-admin');

/** Desktop "Groups" link active-state. */
export const isGroupsActive = (pathname) =>
  isExact(pathname, '/dashboard/groups') || pathname.startsWith('/dashboard/groups/');

/**
 * "Find People" Community nav-entry active-state (Sprint 8.8.5 Part B —
 * revises D-33's Community disposition, see blueprint.md new Decision Log
 * entry). Shared by NavDesktop.jsx (Tier-3 Community) and NavMenuSheet.jsx.
 */
export const isFindFriendsActive = (pathname) =>
  underAny(pathname, ['/dashboard/find-friends']);

/** "Friend Requests" Community nav-entry active-state (Sprint 8.8.5 Part B). */
export const isFriendRequestsActive = (pathname) =>
  underAny(pathname, ['/dashboard/friend-requests']);

/**
 * Mobile bottom-bar "Review" tab active-state (Sprint 7.1).
 *
 * A tighter slice than isStudyActive: the bottom bar has its own Dashboard and
 * Progress tabs, and the Browse-Notes / My-Flashcards *list* routes read better
 * as "no active tab" than as Review (a student browsing the library is not in a
 * review session). So Review lights only for the study-session cluster.
 */
export const isReviewTabActive = (pathname) =>
  !isCreateActive(pathname) &&
  underAny(pathname, [
    '/dashboard/review-flashcards',
    '/dashboard/review-session',
    '/dashboard/review-by-subject',
    '/dashboard/study',
  ]);

// NOTE: the bottom bar is hidden during a study session via <StudySessionContext>
// (StudyMode flips a flag on mount), NOT by a route match — because
// `/dashboard/review-session` is a subject-picker list until the user taps Start.
