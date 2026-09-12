import { useState } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import {
  LayoutDashboard,
  Play,
  BarChart3,
  Plus,
  FileText,
  CreditCard,
  Network,
  Timer,
} from 'lucide-react';
import {
  Sheet,
  SheetContent,
  SheetTrigger,
  SheetTitle,
  SheetDescription,
} from '@/components/ui/sheet';
import { useStudySession } from '@/contexts/StudySessionContext';
import {
  isExact,
  underAny,
  isReviewTabActive,
} from '@/lib/navActive';
import NavMenuSheet from './NavMenuSheet';

/**
 * NavBottomTabs — mobile bottom-tab bar (Sprint 7.1, Layout A).
 *
 * `md:hidden`, fixed to the bottom edge, full-width (rendered by Navigation.jsx
 * as a SIBLING of the top <nav>, so it is NOT inside the max-w-7xl container).
 *
 * Consumes ONLY the `navProps` bundle already assembled in Navigation.jsx from
 * the single NavDataProvider instance — it does NOT call useRole /
 * useNotifications / useFriendRequestCount (that would re-introduce the Sprint
 * 7.0 over-fetch). It adds no data fetching of its own.
 *
 * Slots (exactly 5): Dashboard · Review · ＋ (create action-sheet, not a route) ·
 * Progress · Menu (opens the existing NavMobile drawer, verbatim).
 *
 * The tab list is data-driven — a later top-level destination (e.g. an exam
 * anchor / a new question-type route) is a one-line addition to TABS.
 */

const ROUTE_TAB_CLASS =
  'flex flex-1 flex-col items-center justify-center gap-0.5 min-h-[48px] border-t-2 px-1 text-[11px] font-medium transition-colors';

// Data-driven slot list. `route` slots render a <Link>; `create` and `menu` are
// structural (an action-sheet and the drawer) and always sit centre / last.
const TABS = [
  {
    type: 'route',
    key: 'dashboard',
    label: 'Dashboard',
    Icon: LayoutDashboard,
    to: '/dashboard',
    isActive: (p) => isExact(p, '/dashboard'),
  },
  {
    type: 'route',
    key: 'review',
    label: 'Review',
    Icon: Play,
    to: '/dashboard/review-session',
    isActive: isReviewTabActive,
  },
  { type: 'create', key: 'create' },
  {
    type: 'route',
    key: 'progress',
    label: 'Progress',
    Icon: BarChart3,
    to: '/dashboard/progress',
    isActive: (p) => underAny(p, ['/dashboard/progress']),
  },
  { type: 'menu', key: 'menu' },
];

/**
 * Centre ＋ — opens a small bottom action-sheet: content-creation actions
 * (Upload Note / Create Flashcard / Create Group), then a divider, then
 * "Log Study Time" — which isn't content creation, so it's visually separated
 * (Sprint 7.3-C). Bulk Upload is deliberately absent here for ALL roles
 * (Sprint 7.3-D) — CSV import isn't a phone workflow; it stays on the desktop
 * Create dropdown only.
 */
function CreateAction() {
  const [open, setOpen] = useState(false);
  const navigate = useNavigate();

  const go = (path) => {
    setOpen(false);
    navigate(path);
  };

  const createItems = [
    { label: 'Upload Note', Icon: FileText, to: '/dashboard/notes/new' },
    { label: 'Create Flashcard', Icon: CreditCard, to: '/dashboard/flashcards/new' },
    { label: 'Create Group', Icon: Network, to: '/dashboard/groups/new' },
  ];

  return (
    <Sheet open={open} onOpenChange={setOpen}>
      <SheetTrigger asChild>
        <button
          type="button"
          aria-label="Create"
          className={`${ROUTE_TAB_CLASS} ${
            open ? 'border-rv-navy text-rv-navy' : 'border-transparent text-rv-ink-400'
          }`}
        >
          <span className="flex h-7 w-7 items-center justify-center rounded-rec bg-rv-navy text-white">
            <Plus className="h-5 w-5" />
          </span>
          <span>Create</span>
        </button>
      </SheetTrigger>

      <SheetContent
        side="bottom"
        className="rounded-t-obj border-rv-border bg-rv-bg-1 p-0 font-plex text-rv-ink-900 pb-[env(safe-area-inset-bottom)]"
      >
        <SheetTitle className="px-5 pt-5 pb-2 text-sm font-semibold text-rv-ink-900">
          Create
        </SheetTitle>
        <SheetDescription className="sr-only">
          Choose what to create: a note, a flashcard, or a bulk upload.
        </SheetDescription>
        <div className="pb-3">
          {createItems.map((item) => {
            const ItemIcon = item.Icon;
            return (
              <button
                key={item.to}
                onClick={() => go(item.to)}
                className="flex w-full items-center gap-3 px-5 py-3 text-left hover:bg-rv-bg-2"
              >
                <ItemIcon className="h-5 w-5 text-rv-ink-400" />
                <span className="text-sm font-medium text-rv-ink-900">{item.label}</span>
              </button>
            );
          })}
          <div className="my-1 border-t border-rv-border" />
          <button
            onClick={() => go('/dashboard/study-time')}
            className="flex w-full items-center gap-3 px-5 py-3 text-left hover:bg-rv-bg-2"
          >
            <Timer className="h-5 w-5 text-rv-ink-400" />
            <span className="text-sm font-medium text-rv-ink-900">Log Study Time</span>
          </button>
        </div>
      </SheetContent>
    </Sheet>
  );
}

export default function NavBottomTabs({
  user,
  role,
  isSuperAdmin,
  isAdmin,
  isProfessor,
  isLoading,
  dueToday,
  handleSignOut,
}) {
  const { pathname } = useLocation();
  const { inStudySession } = useStudySession();

  // Same gate as Navigation.jsx — never on public / logged-out pages.
  if (!user) return null;
  // Item 6a: drop the bottom bar while the full-screen card loop is mounted so it
  // can never overlap GradeButtonRow / Show Answer. `StudyMode` sets this flag on
  // mount / clears it on unmount — so the `/dashboard/review-session` subject
  // PICKER keeps the bar, but tapping "Start" (which mounts StudyMode) removes it.
  if (inStudySession) return null;

  return (
    <nav
      aria-label="Primary"
      className="fixed inset-x-0 bottom-0 z-50 border-t border-rv-border bg-rv-bg-1 font-plex shadow-rv-bar md:hidden pb-[env(safe-area-inset-bottom)]"
    >
      <div className="flex h-14 items-stretch">
        {TABS.map((tab) => {
          if (tab.type === 'create') {
            return <CreateAction key={tab.key} />;
          }
          if (tab.type === 'menu') {
            return (
              <NavMenuSheet
                key={tab.key}
                user={user}
                role={role}
                isSuperAdmin={isSuperAdmin}
                isAdmin={isAdmin}
                isProfessor={isProfessor}
                isLoading={isLoading}
                handleSignOut={handleSignOut}
              />
            );
          }
          const { key, label, Icon, to } = tab;
          const active = tab.isActive(pathname);
          return (
            <Link
              key={key}
              to={to}
              aria-current={active ? 'page' : undefined}
              className={`${ROUTE_TAB_CLASS} ${
                active
                  ? 'border-rv-navy text-rv-navy'
                  : 'border-transparent text-rv-ink-400 hover:text-rv-ink-900'
              }`}
            >
              <span className="relative">
                <Icon className="h-5 w-5" />
                {/* 7.2-F: due-count pill, Review tab only, hidden at 0. Solid red,
                    matching the existing notification/friend-request badge
                    convention (bg-red-500/text-white) rather than the pale
                    amber-tint surfaces used elsewhere — a nav badge needs to
                    read as a badge, not a tinted surface. */}
                {key === 'review' && dueToday > 0 && (
                  <span className="absolute -right-2.5 -top-1.5 flex h-3.5 min-w-[14px] items-center justify-center rounded-full bg-red-500 px-0.5 text-[9px] font-bold leading-none text-white">
                    {dueToday > 9 ? '9+' : dueToday}
                  </span>
                )}
              </span>
              <span>{label}</span>
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
