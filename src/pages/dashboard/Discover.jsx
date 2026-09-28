import { useSearchParams } from 'react-router-dom';
import ReviewFlashcards from '@/pages/dashboard/Study/ReviewFlashcards';
import BrowseNotes from '@/pages/dashboard/Content/BrowseNotes';

/**
 * Discover.jsx — canonical Discover destination (Sprint 8.8.5, D-36/D-37 rows 3/4).
 *
 * Composition, not a rebuild: this page owns only the tab switcher above.
 * ReviewFlashcards/BrowseNotes mount unmodified underneath and keep their own
 * page chrome (min-h-screen wrapper, max-w-7xl container, <h1>) — D-36 locks
 * "aggregate while retaining the specialized pages," so no second competing
 * title/container is added here merely for aesthetics. The canonical word
 * "Discover" is carried by the nav entry (NavDesktop.jsx Tier 1 / NavMenuSheet.jsx)
 * and this tab bar, not a duplicate large heading.
 *
 * Tab state is URL-addressable (?tab=study-sets|notes, default study-sets,
 * invalid falls back to study-sets) and switching tabs uses history.push (the
 * router's default setSearchParams behavior) rather than replace, so browser
 * Back/Forward step through prior tab views — required by this sprint's own
 * live-verification steps, which only make sense if each tab switch is a real
 * history entry. Unrelated existing search params (e.g. a Notes filter) are
 * preserved across a tab switch by copying the current searchParams rather
 * than constructing a fresh one.
 */

const TABS = [
  { value: 'study-sets', label: 'Study Sets' },
  { value: 'notes', label: 'Notes' },
];

export default function Discover() {
  const [searchParams, setSearchParams] = useSearchParams();
  const tabParam = searchParams.get('tab');
  const activeTab = tabParam === 'notes' ? 'notes' : 'study-sets';

  const handleTabChange = (tab) => {
    if (tab === activeTab) return;
    const next = new URLSearchParams(searchParams);
    next.set('tab', tab);
    setSearchParams(next);
  };

  return (
    <div>
      <div className="border-b border-rv-border bg-rv-bg-1 font-plex">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div role="tablist" aria-label="Discover" className="flex gap-1 py-2">
            {TABS.map((tab) => {
              const selected = tab.value === activeTab;
              return (
                <button
                  key={tab.value}
                  type="button"
                  role="tab"
                  aria-selected={selected}
                  onClick={() => handleTabChange(tab.value)}
                  className={`rounded-rec px-3 py-1.5 text-sm font-medium transition-colors ${
                    selected
                      ? 'bg-rv-navy-50 text-rv-navy'
                      : 'text-rv-ink-600 hover:bg-rv-bg-2 hover:text-rv-ink-900'
                  }`}
                >
                  {tab.label}
                </button>
              );
            })}
          </div>
        </div>
      </div>

      {activeTab === 'notes' ? <BrowseNotes /> : <ReviewFlashcards />}
    </div>
  );
}
