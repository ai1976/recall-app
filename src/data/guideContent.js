// Student Guide — situation content
// Each situation has steps with optional navigation chips.
// linkTo: null means no chip. isSignup: true routes to /signup directly.

export const SITUATIONS = [
  {
    id: 'enrollment',
    sidebarLabel: 'Getting In',
    emoji: '🎟️',
    headline: 'I just received an enrollment code',
    steps: [
      {
        label: 'Create your account',
        detail:
          'Open Recall and click Sign Up. Paste your enrollment code in the field provided — this links your account to your professor\'s class automatically.',
        linkLabel: 'Sign Up',
        linkTo: '/signup',
        isSignup: true,
      },
      {
        label: 'Set your display name',
        detail:
          'During signup you will be asked for a display name. This is what your professor and classmates will see on leaderboards and shared content.',
        linkLabel: null,
        linkTo: null,
        isSignup: false,
      },
      {
        label: 'Go to your Dashboard',
        detail:
          'Once signed in, your Dashboard is home base. Your review queue, streak counter, and recent activity all live here.',
        linkLabel: 'Dashboard',
        linkTo: '/dashboard',
        isSignup: false,
      },
    ],
  },
  {
    id: 'orientation',
    sidebarLabel: 'First Day',
    emoji: '🗺️',
    headline: 'I just signed up — what do I do first?',
    steps: [
      {
        label: 'Check your Dashboard',
        detail:
          'Your Dashboard shows your review queue, streak, and any content your professor has shared. Start here every session.',
        linkLabel: 'Dashboard',
        linkTo: '/dashboard',
        isSignup: false,
      },
      {
        label: 'Explore your Notes',
        detail:
          'Notes are longer-form study material — summaries, chapter breakdowns, anything you want to read before drilling. Browse what your professor has shared or create your own.',
        linkLabel: 'Notes',
        linkTo: '/dashboard/notes',
        isSignup: false,
      },
      {
        label: 'Look at your Study Sets',
        detail:
          'Study Sets (flashcard decks) are what power your daily review. Your professor may have seeded some already.',
        linkLabel: 'Study Sets',
        linkTo: '/dashboard/decks',
        isSignup: false,
      },
      {
        label: 'Do your first review',
        detail:
          'Even one card reviewed today starts your streak. Head to the Review section and complete whatever is in the queue.',
        linkLabel: 'Review',
        linkTo: '/dashboard/review',
        isSignup: false,
      },
    ],
  },
  {
    id: 'studying',
    sidebarLabel: 'Studying',
    emoji: '📖',
    headline: 'I want to study today',
    steps: [
      {
        label: 'Open your Review queue',
        detail:
          'Your queue shows every card that is due today based on spaced repetition. Work through this first before adding new cards.',
        linkLabel: 'Review',
        linkTo: '/dashboard/review',
        isSignup: false,
      },
      {
        label: 'Rate each card honestly',
        detail:
          'After seeing the answer, rate yourself: Again (completely forgot), Hard (struggled), Good (recalled with effort), Easy (instant recall). Your future schedule is built from these ratings — gaming them only hurts you.',
        linkLabel: null,
        linkTo: null,
        isSignup: false,
      },
      {
        label: 'Browse Notes for deeper reading',
        detail:
          'If a card stumps you, go to Notes to read the fuller explanation before moving on.',
        linkLabel: 'Notes',
        linkTo: '/dashboard/notes',
        isSignup: false,
      },
      {
        label: 'Check your streak before closing',
        detail:
          'Your streak increments once you complete at least one review session per day. Do not close the tab mid-session.',
        linkLabel: 'Dashboard',
        linkTo: '/dashboard',
        isSignup: false,
      },
    ],
  },
  {
    id: 'behind',
    sidebarLabel: 'Falling Behind',
    emoji: '🔥',
    headline: "I'm behind on my reviews",
    steps: [
      {
        label: 'Open your Review queue now',
        detail:
          'The longer you wait, the larger the backlog grows. Even 10 cards today is better than zero.',
        linkLabel: 'Review',
        linkTo: '/dashboard/review',
        isSignup: false,
      },
      {
        label: 'Do not add new cards yet',
        detail:
          'Adding new cards while behind makes the backlog worse. Clear existing dues first, then resume adding.',
        linkLabel: null,
        linkTo: null,
        isSignup: false,
      },
      {
        label: 'Use shorter sessions',
        detail:
          'You do not have to finish the entire queue in one sitting. Break it into 15-minute blocks across the day. The system will reprioritise overdue cards automatically.',
        linkLabel: null,
        linkTo: null,
        isSignup: false,
      },
      {
        label: 'Check your Stats after a few days',
        detail:
          'Once you are back on track, your Stats page will show your retention rate recovering. Use it as motivation, not judgment.',
        linkLabel: 'Stats',
        linkTo: '/dashboard/stats',
        isSignup: false,
      },
    ],
  },
  {
    id: 'content',
    sidebarLabel: 'Adding Content',
    emoji: '✏️',
    headline: 'I want to add my own notes or flashcards',
    steps: [
      {
        label: 'Create a Note',
        detail:
          'Go to Notes and click New Note. Organise it under a Subject and Topic so it is easy to find later. Set visibility to Private if it is rough, Friends or Public when it is ready to share.',
        linkLabel: 'Notes',
        linkTo: '/dashboard/notes',
        isSignup: false,
      },
      {
        label: 'Create a Flashcard',
        detail:
          'Go to Flashcards and click New Card. Every card you create goes into your review queue automatically — there is no separate "add to deck" step.',
        linkLabel: 'New Flashcard',
        linkTo: '/dashboard/flashcards/create',
        isSignup: false,
      },
      {
        label: 'Group cards into a Study Set',
        detail:
          'Study Sets let you organise cards by subject and topic. Cards are grouped by the Subject + Topic combination you chose when creating them.',
        linkLabel: 'Study Sets',
        linkTo: '/dashboard/decks',
        isSignup: false,
      },
      {
        label: 'Set visibility thoughtfully',
        detail:
          'Private = only you. Friends = your followers. Public = everyone on Recall. Your professor can see everything in your enrolled class regardless of visibility.',
        linkLabel: null,
        linkTo: null,
        isSignup: false,
      },
    ],
  },
  {
    id: 'scoring',
    sidebarLabel: 'Scoring',
    emoji: '🧮',
    headline: "I don't understand how scoring works",
    steps: [
      {
        label: 'Spaced repetition sets your schedule',
        detail:
          'Recall uses a spaced repetition algorithm (SM-2). Cards you know well appear less often. Cards you struggle with appear more often. The goal is to review each card just before you would forget it.',
        linkLabel: null,
        linkTo: null,
        isSignup: false,
      },
      {
        label: 'Your rating moves the next due date',
        detail:
          'Again = card comes back very soon. Hard = sooner than scheduled. Good = on schedule. Easy = pushed further into the future. One honest rating per card is all the system needs.',
        linkLabel: null,
        linkTo: null,
        isSignup: false,
      },
      {
        label: 'Points and streaks are motivational, not academic',
        detail:
          'Points accumulate from reviews and content creation. Streaks track consecutive days of activity. Neither affects your professor\'s assessment — they exist to keep you consistent.',
        linkLabel: null,
        linkTo: null,
        isSignup: false,
      },
      {
        label: 'Check the Leaderboard for context',
        detail:
          'The Leaderboard shows points relative to classmates. Use it to gauge activity, not ability.',
        linkLabel: 'Leaderboard',
        linkTo: '/dashboard/leaderboard',
        isSignup: false,
      },
    ],
  },
  {
    id: 'stats',
    sidebarLabel: 'My Progress',
    emoji: '📊',
    headline: "I want to see how I'm doing",
    steps: [
      {
        label: 'Open My Stats',
        detail:
          'Your Stats page shows review history, retention rate, streak graph, and card counts over time.',
        linkLabel: 'My Stats',
        linkTo: '/dashboard/stats',
        isSignup: false,
      },
      {
        label: 'Retention rate is the key number',
        detail:
          'Retention rate measures what percentage of due cards you are recalling correctly. Above 80% is healthy. Below 60% usually means you need shorter, more frequent sessions.',
        linkLabel: null,
        linkTo: null,
        isSignup: false,
      },
      {
        label: 'Check the Leaderboard',
        detail:
          'Points-based ranking across your class. Useful for spotting if you are significantly under- or over-studying relative to peers.',
        linkLabel: 'Leaderboard',
        linkTo: '/dashboard/leaderboard',
        isSignup: false,
      },
      {
        label: 'Review streaks on your Dashboard',
        detail:
          'Streaks are visible on your Dashboard and profile. A broken streak is not a crisis — resume the next day.',
        linkLabel: 'Dashboard',
        linkTo: '/dashboard',
        isSignup: false,
      },
    ],
  },
  {
    id: 'social',
    sidebarLabel: 'Study Circle',
    emoji: '👥',
    headline: 'I want to connect with classmates',
    steps: [
      {
        label: 'Find People',
        detail:
          'Use the Find People page to search for classmates by name and follow them. Following someone lets you see their public and friends-visibility content.',
        linkLabel: 'Find People',
        linkTo: '/dashboard/find-people',
        isSignup: false,
      },
      {
        label: 'Join a Group',
        detail:
          'Groups are shared spaces where classmates and professors post content. You may have been auto-added to one via your enrollment code, or you can request to join.',
        linkLabel: 'Groups',
        linkTo: '/dashboard/groups',
        isSignup: false,
      },
      {
        label: 'Browse shared Notes and Decks',
        detail:
          'Once you follow someone or join a group, their shared content appears in your feed. You can save or copy items you find useful.',
        linkLabel: 'Notes',
        linkTo: '/dashboard/notes',
        isSignup: false,
      },
      {
        label: 'Share your own content',
        detail:
          'Set a Note or Study Set to Public or Friends visibility to contribute back. Your profile shows everything you have shared.',
        linkLabel: 'My Profile',
        linkTo: '/dashboard/profile',
        isSignup: false,
      },
    ],
  },
  {
    id: 'reports',
    sidebarLabel: 'Reports',
    emoji: '🚩',
    headline: 'I want to flag something or check my reports',
    steps: [
      {
        label: 'Flag a Note or Flashcard',
        detail:
          'On any Note or Flashcard, open the options menu (···) and choose Flag. Select a reason — incorrect content, inappropriate, or other — and submit.',
        linkLabel: null,
        linkTo: null,
        isSignup: false,
      },
      {
        label: 'Your flag is sent to moderators',
        detail:
          'Flagged items are reviewed by your professor or a platform admin. You will not be notified of the outcome but the item will be reviewed within the platform\'s moderation cycle.',
        linkLabel: null,
        linkTo: null,
        isSignup: false,
      },
      {
        label: 'Check your submitted reports',
        detail:
          'Go to My Reports to see the items you have flagged and their current status.',
        linkLabel: 'My Reports',
        linkTo: '/dashboard/reports',
        isSignup: false,
      },
      {
        label: 'Use flags responsibly',
        detail:
          'Flags are for genuinely incorrect or harmful content. Do not flag content simply because you disagree with it — repeated misuse may restrict your flagging ability.',
        linkLabel: null,
        linkTo: null,
        isSignup: false,
      },
    ],
  },
]
