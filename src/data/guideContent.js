// Student Guide — situation content
// Each situation has steps with optional navigation chips.
// linkTo: null means no chip. isSignup: true routes to /signup directly.

export const SITUATIONS = [
  {
    id: 'enrollment',
    sidebarLabel: 'Getting In',
    emoji: '🎟️',
    headline: 'I want to set up my account',
    steps: [
      {
        label: 'Is your Institute on Recall?',
        detail:
          'If your institute enrolled you, simply sign up using the email you provided them. Your class\'s premium study material is already waiting for you — no code needed.',
        linkLabel: 'Sign Up',
        linkTo: '/signup',
        isSignup: true,
      },
      {
        label: 'Studying on your own?',
        detail:
          'No problem. Just sign up and select your target exam (e.g., CA Intermediate). You can create unlimited flashcards for free and preview expert content from day one.',
        linkLabel: 'Sign Up',
        linkTo: '/signup',
        isSignup: true,
      },
      {
        label: 'Set your display name',
        detail:
          'During signup you will be asked for a display name. This is what others will see on leaderboards and shared content — choose something you are happy with publicly.',
        linkLabel: null,
        linkTo: null,
        isSignup: false,
      },
      {
        label: 'Received a group invite link?',
        detail:
          'If someone shared a Recall group link with you via WhatsApp, email, or another channel — open it once you are signed in. It will drop you straight into the group where shared notes and study sets live.',
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
        label: 'Your Dashboard is home base',
        detail:
          'Your Dashboard shows your review queue, streak counter, and recent activity. It starts empty — that is normal. It fills up as you add content or join groups.',
        linkLabel: 'Dashboard',
        linkTo: '/dashboard',
        isSignup: false,
      },
      {
        label: 'Add your first content',
        detail:
          'Use the Create menu to Upload a Note or Create a Flashcard. Every flashcard you create goes straight into your review queue. There is no separate "add to deck" step.',
        linkLabel: 'Create Flashcard',
        linkTo: '/dashboard/flashcards/new',
        isSignup: false,
      },
      {
        label: 'Studying with a class? Check Groups',
        detail:
          'If a professor or study group invited you, go to Groups to find and open that group. Notes and study sets shared there will appear in your account automatically. If you are studying independently, skip this step.',
        linkLabel: 'Groups',
        linkTo: '/dashboard/groups',
        isSignup: false,
      },
      {
        label: 'Do your first review',
        detail:
          'Once you have at least one flashcard — your own or from a group — head to Review Flashcards and work through the queue. Even one card today starts your streak.',
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
        label: "Don't panic — start small",
        detail:
          "Recall queues cards so you don't forget them, but you don't have to clear everything in one day. Focus on reviewing just 20 cards today to protect your streak. That is enough to get moving again.",
        linkLabel: 'Review Flashcards',
        linkTo: '/dashboard/review-flashcards',
        isSignup: false,
      },
      {
        label: 'Hold off on adding new cards',
        detail:
          'Adding new cards while behind makes the backlog larger. Work through what is already due first — new cards can wait a day or two.',
        linkLabel: null,
        linkTo: null,
        isSignup: false,
      },
      {
        label: 'Break it into short blocks',
        detail:
          'You do not need to finish the whole queue in one sitting. Try two or three 15-minute sessions across the day. Recall reprioritises overdue cards automatically — just keep showing up.',
        linkLabel: null,
        linkTo: null,
        isSignup: false,
      },
      {
        label: 'One topic too heavy? Skip it for today.',
        detail:
          'During a review session, tap the \u22ef menu on any card and choose Skip Topic (24hr). Every card from that topic disappears until tomorrow — your schedule is preserved and nothing is deleted. Use it to clear the overwhelming topic from today\'s queue and come back to it fresh.',
        linkLabel: 'Review Flashcards',
        linkTo: '/dashboard/review-flashcards',
        isSignup: false,
      },
      {
        label: 'Watch your retention rate recover',
        detail:
          'After a few consistent days, open My Progress. Your retention rate will start climbing again. Use it as motivation, not judgment — a dip is normal and fully recoverable.',
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
        label: 'Upload a Note',
        detail:
          'Use the Create menu in the top navigation → Upload Note. Organise it under a Subject and Topic so it is easy to find later. Set visibility to Private if it is rough, Friends or Public when it is ready to share.',
        linkLabel: 'Upload Note',
        linkTo: '/dashboard/notes/new',
        isSignup: false,
      },
      {
        label: 'Create a Flashcard',
        detail:
          'Use the Create menu → Create Flashcard. Every card you create goes into your review queue automatically — there is no separate "add to deck" step.',
        linkLabel: 'Create Flashcard',
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
        label: 'Recall uses a Memory Engine, not a fixed schedule',
        detail:
          'Instead of studying everything every day, Recall\'s Memory Engine shows you each card just before you are likely to forget it. If you mark a card Hard, it comes back tomorrow. If you mark it Easy, it will not bother you for a week — saving you time for cards that actually need work.',
        linkLabel: null,
        linkTo: null,
        isSignup: false,
      },
      {
        label: 'Three ratings, three outcomes',
        detail:
          'Hard = back tomorrow. Medium = back in 3 days. Easy = back in 7 days. There is also Study Again to repeat a card immediately in the same session without changing its future schedule. One honest rating per card is all the system needs.',
        linkLabel: null,
        linkTo: null,
        isSignup: false,
      },
      {
        label: 'Points and streaks are motivational, not academic',
        detail:
          'Points accumulate from reviews and content creation. Streaks track consecutive days of activity. Neither reflects your knowledge level — they exist purely to keep you consistent.',
        linkLabel: null,
        linkTo: null,
        isSignup: false,
      },
      {
        label: 'Check the Leaderboard for context',
        detail:
          'The Leaderboard on your Dashboard shows your activity ranking relative to others. Use it to gauge study volume, not ability.',
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
