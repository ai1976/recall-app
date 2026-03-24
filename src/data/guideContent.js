// Student Guide — situation content
// Each situation has steps with optional navigation chips.
// linkTo: null means no chip. isSignup: true routes to /signup directly.

export const SITUATIONS = [
  {
    id: 'enrollment',
    sidebarLabel: 'Getting In',
    emoji: '🎟️',
    headline: 'I received an invite link to join a class',
    steps: [
      {
        label: 'Open the invite link',
        detail:
          'Your professor or a classmate will share an invite link via WhatsApp, email, or another channel. Open the link in your browser — it will take you directly to the Recall sign-up or join page.',
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
        label: 'You are in — go to your Group',
        detail:
          'Once signed in, the invite link will take you into your class Group. This is where your professor shares notes and study sets. You can also reach it anytime from the Groups section.',
        linkLabel: 'Groups',
        linkTo: '/dashboard/groups',
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
          'Your Dashboard shows your review queue, streak counter, and recent activity. Start here every session.',
        linkLabel: 'Dashboard',
        linkTo: '/dashboard',
        isSignup: false,
      },
      {
        label: 'Find the Study menu',
        detail:
          'In the top navigation bar, click Study. It has two key links: Review Flashcards (your daily due cards) and Browse Notes (course material to read). These are the two things you will use most.',
        linkLabel: 'Review Flashcards',
        linkTo: '/dashboard/review-flashcards',
        isSignup: false,
      },
      {
        label: 'Join your class Group',
        detail:
          'Go to Groups and open your class group. Your professor shares notes and study sets there. Content shared in the group appears in your Notes and Study Sets sections automatically.',
        linkLabel: 'Groups',
        linkTo: '/dashboard/groups',
        isSignup: false,
      },
      {
        label: 'Do your first review',
        detail:
          'Even one card reviewed today starts your streak. Head to Review Flashcards and complete whatever is in the queue.',
        linkLabel: 'Review Flashcards',
        linkTo: '/dashboard/review-flashcards',
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
        linkLabel: 'Review Flashcards',
        linkTo: '/dashboard/review-flashcards',
        isSignup: false,
      },
      {
        label: 'Rate each card honestly',
        detail:
          'After seeing the answer, rate yourself: Hard (back tomorrow), Medium (back in 3 days), Easy (back in 7 days). There is also a Study Again option to repeat the card immediately without changing its schedule. Your future schedule is built from these ratings — honest ratings give you the most effective review plan.',
        linkLabel: null,
        linkTo: null,
        isSignup: false,
      },
      {
        label: 'Browse Notes for deeper reading',
        detail:
          'If a card stumps you, go to Browse Notes to read the fuller explanation before moving on.',
        linkLabel: 'Browse Notes',
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
        linkLabel: 'Review Flashcards',
        linkTo: '/dashboard/review-flashcards',
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
        label: 'Check My Progress after a few days',
        detail:
          'Once you are back on track, My Progress will show your retention rate recovering. Use it as motivation, not judgment.',
        linkLabel: 'My Progress',
        linkTo: '/dashboard/progress',
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
          'Go to Browse Notes and click New Note. Organise it under a Subject and Topic so it is easy to find later. Set visibility to Private if it is rough, Friends or Public when it is ready to share.',
        linkLabel: 'Browse Notes',
        linkTo: '/dashboard/notes',
        isSignup: false,
      },
      {
        label: 'Create a Flashcard',
        detail:
          'Use the Study menu → New Flashcard. Every card you create goes into your review queue automatically — there is no separate "add to deck" step.',
        linkLabel: 'New Flashcard',
        linkTo: '/dashboard/flashcards/new',
        isSignup: false,
      },
      {
        label: 'Group cards into a Study Set',
        detail:
          'Study Sets organise cards by Subject and Topic. Cards are grouped automatically by the Subject + Topic combination you chose when creating them — no manual grouping needed.',
        linkLabel: null,
        linkTo: null,
        isSignup: false,
      },
      {
        label: 'Set visibility thoughtfully',
        detail:
          'Private = only you. Friends = people you follow. Public = anyone on Recall. Content you share inside a Group is visible to group members only — your private content is never visible to anyone else.',
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
          'Recall uses a spaced repetition algorithm. Cards you know well appear less often. Cards you struggle with appear more often. The goal is to review each card just before you would forget it.',
        linkLabel: null,
        linkTo: null,
        isSignup: false,
      },
      {
        label: 'Your rating moves the next due date',
        detail:
          'Hard = card comes back tomorrow. Medium = 3 days. Easy = 7 days. There is also Study Again to repeat the card in the same session without changing its schedule. One honest rating per card is all the system needs.',
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
          'The Leaderboard on your Dashboard shows your ranking relative to classmates. Use it to gauge activity levels, not ability.',
        linkLabel: 'Dashboard',
        linkTo: '/dashboard',
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
        label: 'Open My Progress',
        detail:
          'My Progress shows your review history, retention rate, streak graph, and item counts over time. Find it under the Study menu or use the link below.',
        linkLabel: 'My Progress',
        linkTo: '/dashboard/progress',
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
          'The Leaderboard is on your Dashboard — it shows your weekly review ranking relative to classmates. Useful for spotting if you are significantly under- or over-studying relative to peers.',
        linkLabel: 'Dashboard',
        linkTo: '/dashboard',
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
          'Use Find People to search for classmates by name and follow them. Following someone lets you see their public and friends-visibility content.',
        linkLabel: 'Find People',
        linkTo: '/dashboard/find-friends',
        isSignup: false,
      },
      {
        label: 'Create a Group or join one',
        detail:
          'Groups are shared spaces where members post notes and study sets. You can create your own group and invite people using a shareable link — send it via WhatsApp, email, or any messaging app. People who are not yet on Recall can sign up and join using your link.',
        linkLabel: 'Groups',
        linkTo: '/dashboard/groups',
        isSignup: false,
      },
      {
        label: 'Browse shared Notes and Study Sets',
        detail:
          'Once you are in a group, content shared by the group admin or members appears in your Notes and Study Sets sections. You can view and study from it directly.',
        linkLabel: 'Browse Notes',
        linkTo: '/dashboard/notes',
        isSignup: false,
      },
      {
        label: 'Share your own content',
        detail:
          'Set a Note or Study Set to Public or Friends visibility to contribute back. Or share it directly into a Group so only group members can access it.',
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
        label: 'Flag a Flashcard during review',
        detail:
          'A flag icon is visible directly on each card during a review session. Tap it, select a reason — incorrect content, inappropriate, or other — and submit. No need to open any menu.',
        linkLabel: null,
        linkTo: null,
        isSignup: false,
      },
      {
        label: 'Your flag is sent to moderators',
        detail:
          'Flagged items are reviewed by your professor or a platform admin. Content errors go to the professor first; inappropriate content goes directly to an admin.',
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
