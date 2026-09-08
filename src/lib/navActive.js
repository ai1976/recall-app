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

/** Desktop "Study" dropdown active-state. Unchanged from NavDesktop's Sprint 6.0/6.2 logic. */
export const isStudyActive = (pathname) =>
  !isCreateActive(pathname) &&
  underAny(pathname, [
    '/dashboard/review-flashcards',
    '/dashboard/review-session',
    '/dashboard/review-by-subject',
    '/dashboard/study',
    '/dashboard/notes',       // Browse Notes + note detail/edit
    '/dashboard/flashcards',  // My Flashcards + card detail/edit
    '/dashboard/progress',
  ]);

/** Desktop "Manage" dropdown active-state. */
export const isManageActive = (pathname) =>
  pathname.startsWith('/admin') || pathname.startsWith('/super-admin');

/** Desktop "Groups" link active-state. */
export const isGroupsActive = (pathname) =>
  isExact(pathname, '/dashboard/groups') || pathname.startsWith('/dashboard/groups/');

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
