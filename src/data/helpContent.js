// Help & Guide content data
// Organized by tabs > sections > content blocks
// Content blocks: paragraph, list, steps, tip

export const HELP_TABS = [
  // ─── TAB 1: GETTING STARTED ───
  {
    key: 'getting-started',
    label: 'Getting Started',
    icon: 'BookOpen',
    sections: [
      {
        id: 'welcome',
        title: 'Welcome to Recall',
        icon: 'BookOpen',
        defaultExpanded: true,
        content: [
          {
            type: 'paragraph',
            text: 'Recall is a study platform built around spaced repetition \u2014 a scientifically proven method to help you remember what you learn. Upload notes, create flashcards, review them at optimal intervals, and track your progress over time.',
          },
          {
            type: 'paragraph',
            text: 'Whether you are preparing for exams or just want to retain knowledge better, Recall helps you study smarter, not harder.',
          },
        ],
      },
      {
        id: 'first-steps',
        title: 'Your First Steps',
        icon: 'Play',
        content: [
          {
            type: 'paragraph',
            text: 'Here is how to get started with Recall in just a few minutes:',
          },
          {
            type: 'steps',
            items: [
              'Create your account and select your course level (e.g., Intermediate, Final).',
              'Head to the Dashboard \u2014 this is your home base. You will see quick stats, due reviews, and shortcuts to create content.',
              'Upload your first note or create a flashcard deck under the "Create" menu.',
              'Once you have flashcards, start a review session from the Dashboard or the "Study" menu.',
              'Check your progress anytime from "My Progress" in the profile menu.',
            ],
          },
          {
            type: 'tip',
            text: 'Your timezone is automatically detected when you sign up. This ensures streaks and study stats are calculated correctly based on your local time.',
          },
        ],
      },
      {
        id: 'dashboard-overview',
        title: 'Understanding the Dashboard',
        icon: 'LayoutDashboard',
        content: [
          {
            type: 'paragraph',
            text: 'The Dashboard is the first thing you see after signing in. It gives you a snapshot of your study activity and quick access to key actions.',
          },
          {
            type: 'list',
            items: [
              'Reviews Due Today \u2014 Cards scheduled for review based on spaced repetition. This is your primary study action each day.',
              'New Cards Available \u2014 Flashcards you haven\'t studied yet. These are separate from reviews.',
              'Study Streak \u2014 How many consecutive days you have completed at least one review.',
              'Accuracy \u2014 Your percentage of correct answers across all reviews.',
              'Quick Actions \u2014 Buttons to create a new note, new flashcard deck, start a study session, or browse content.',
              'Activity Feed \u2014 Recent notes and flashcard decks shared by the community in the past 7 days.',
            ],
          },
        ],
      },
    ],
  },

  // ─── TAB 2: CONTENT ───
  {
    key: 'content',
    label: 'Content',
    icon: 'Upload',
    sections: [
      {
        id: 'note-upload',
        title: 'Uploading Notes',
        icon: 'FileText',
        defaultExpanded: true,
        content: [
          {
            type: 'paragraph',
            text: 'Notes are the foundation of your study material. You can create notes using text, images, or PDFs:',
          },
          {
            type: 'list',
            items: [
              'Text Entry \u2014 Type or paste your notes directly into the text editor.',
              'Image Upload \u2014 Upload photos of notes, textbook pages, or handwritten material as image attachments.',
              'PDF Upload \u2014 Upload PDF documents to store alongside your notes.',
            ],
          },
          {
            type: 'steps',
            items: [
              'Go to "Create" \u2192 "Upload Note" from the navigation bar.',
              'Enter a title for your note.',
              'Select the course, subject, and topic to organize your note.',
              'Add your content \u2014 type text, upload an image, or upload a PDF (you can combine text with an image or PDF).',
              'Set the visibility level (Private, Study Groups, Friends, or Public).',
              'Click "Upload" to save your note.',
            ],
          },
          {
            type: 'tip',
            text: 'You can upload both text and an image in the same note \u2014 for example, type a summary and attach the original page photo for reference.',
          },
        ],
      },
      {
        id: 'flashcard-creation',
        title: 'Creating Flashcards',
        icon: 'CreditCard',
        content: [
          {
            type: 'paragraph',
            text: 'Flashcards are the core of your study sessions. Each card has a front (question/prompt) and a back (answer). Cards are organized into decks by subject and topic.',
          },
          {
            type: 'list',
            items: [
              'Manual Creation \u2014 Create cards one by one with a front and back. Great for adding cards as you study.',
              'Bulk Import (CSV) \u2014 Upload a CSV file with multiple cards at once. The file should have "front" and "back" columns. Available to professors and admins.',
            ],
          },
          {
            type: 'steps',
            items: [
              'Go to "Create" \u2192 "Create Flashcard" from the navigation bar.',
              'Select the course, subject, and topic.',
              'Enter the front (question) and back (answer) for each card.',
              'Set the visibility and optional difficulty tag (Easy, Medium, Hard).',
              'Click "Create" to save your flashcard deck.',
            ],
          },
          {
            type: 'tip',
            text: 'Keep flashcard fronts short and specific. A good flashcard tests one concept at a time. For example, instead of "Explain depreciation", try "What is the straight-line method of depreciation?"',
          },
        ],
      },
      {
        id: 'visibility',
        title: 'Visibility Settings',
        icon: 'Eye',
        content: [
          {
            type: 'paragraph',
            text: 'When you create a note or flashcard deck, you choose one of four visibility levels:',
          },
          {
            type: 'list',
            items: [
              'Private \u2014 Only you can see this content. Use this for personal notes or work-in-progress material.',
              'Study Groups \u2014 Share with specific study groups you belong to. When selected, you can pick which groups to share with from a checklist. If you are not in any groups yet, you will be prompted to create one.',
              'Friends \u2014 Visible to your accepted friends on Recall. Good for sharing with classmates you trust.',
              'Public \u2014 Visible to all Recall users. Ideal for sharing helpful material with the wider community.',
            ],
          },
          {
            type: 'paragraph',
            text: 'You can change the visibility of your content at any time from "My Contributions".',
          },
          {
            type: 'tip',
            text: 'Public content can receive upvotes from the community. Getting upvotes contributes toward earning the "Rising Star" achievement badge.',
          },
        ],
      },
      {
        id: 'organization',
        title: 'Organizing Content',
        icon: 'Folder',
        content: [
          {
            type: 'paragraph',
            text: 'All content in Recall is organized in a three-level hierarchy: Course \u2192 Subject \u2192 Topic. This makes it easy to find and browse specific material.',
          },
          {
            type: 'list',
            items: [
              'Course \u2014 Your main study program (e.g., your exam level or degree program).',
              'Subject \u2014 A specific subject within your course (e.g., Accounting, Law, Taxation).',
              'Topic \u2014 A focused topic within the subject (e.g., "Depreciation Methods", "Contract Law Basics").',
            ],
          },
          {
            type: 'paragraph',
            text: 'When browsing notes or flashcards, you can filter by any combination of course, subject, and topic to quickly find what you need.',
          },
        ],
      },
      {
        id: 'upvoting',
        title: 'Upvoting Content',
        icon: 'ThumbsUp',
        content: [
          {
            type: 'paragraph',
            text: 'The upvote system helps surface the best community content. When you find a note or flashcard deck that is helpful, give it an upvote to let others know.',
          },
          {
            type: 'list',
            items: [
              'Click the upvote button on any note or flashcard deck to upvote it.',
              'Click again to remove your upvote.',
              'You cannot upvote your own content.',
              'Each user can upvote a piece of content only once.',
              'Content creators can see who upvoted their work. Students see the upvote count only.',
            ],
          },
        ],
      },
    ],
  },

  // ─── TAB 3: STUDY SYSTEM ───
  {
    key: 'study',
    label: 'Study System',
    icon: 'Brain',
    sections: [
      {
        id: 'spaced-repetition',
        title: 'How Spaced Repetition Works',
        icon: 'Brain',
        defaultExpanded: true,
        content: [
          {
            type: 'paragraph',
            text: 'Spaced repetition is a learning technique where you review material at increasing intervals. Instead of cramming everything at once, you revisit cards just before you are about to forget them. This strengthens long-term memory far more effectively than re-reading notes.',
          },
          {
            type: 'paragraph',
            text: 'Recall uses a modified version of the SuperMemo-2 algorithm to schedule your reviews. Each time you review a card, you rate how well you remembered it, and the system adjusts the next review date accordingly.',
          },
          {
            type: 'list',
            items: [
              'Hard \u2014 You struggled or got it wrong. The card comes back in 1 day.',
              'Medium \u2014 You remembered with some effort. The card comes back in 3 days.',
              'Easy \u2014 You remembered effortlessly. The card comes back in 7 days.',
            ],
          },
          {
            type: 'paragraph',
            text: 'As you consistently rate cards "Easy", the intervals grow longer (weeks, then months). Cards you struggle with stay in shorter rotation until you master them.',
          },
          {
            type: 'tip',
            text: 'Be honest with your ratings! Rating cards as "Easy" when you actually struggled will hurt your long-term retention. The system works best when your ratings reflect your true recall ability.',
          },
        ],
      },
      {
        id: 'review-vs-new',
        title: 'Reviews vs. New Cards',
        icon: 'Layers',
        content: [
          {
            type: 'paragraph',
            text: 'Recall separates your study sessions into two distinct modes, because research shows that mixing review and new learning reduces effectiveness:',
          },
          {
            type: 'list',
            items: [
              'Reviews Due Today \u2014 Cards you have studied before that are scheduled for review. This is your primary daily activity. Completing these maintains your knowledge.',
              'New Cards \u2014 Flashcards you have never studied before. These represent new material to learn. You can browse and start studying them whenever you are ready.',
            ],
          },
          {
            type: 'paragraph',
            text: 'Your Dashboard shows both counts separately. We recommend completing your daily reviews first, then tackling new cards if you have time and energy.',
          },
          {
            type: 'tip',
            text: 'Seeing "15 Reviews Due" is much more manageable than "215 total cards". The separation keeps your daily workload clear and achievable.',
          },
        ],
      },
      {
        id: 'review-sessions',
        title: 'Starting a Review Session',
        icon: 'Play',
        content: [
          {
            type: 'paragraph',
            text: 'There are several ways to start reviewing your flashcards:',
          },
          {
            type: 'list',
            items: [
              'Dashboard Quick Action \u2014 Click "Study Session" on the Dashboard to review all due cards.',
              'Review by Subject \u2014 Go to "Study" \u2192 "Review Flashcards" and select a specific subject to focus your review.',
              'Browse & Study \u2014 Find a specific flashcard deck and click "Study" to review just that deck.',
            ],
          },
          {
            type: 'steps',
            items: [
              'A card appears with the front (question) showing.',
              'Think of the answer, then click "Show Answer" to reveal the back.',
              'Rate your recall: Hard, Medium, or Easy.',
              'The next card appears automatically. Continue until all due cards are reviewed.',
              'After completing the session, you will see a summary with your accuracy and streak info.',
            ],
          },
        ],
      },
      {
        id: 'progress-tracking',
        title: 'Progress & Stats',
        icon: 'BarChart3',
        content: [
          {
            type: 'paragraph',
            text: 'Track your study habits and improvement over time from the "My Progress" page (accessible from the profile dropdown).',
          },
          {
            type: 'list',
            items: [
              'Study Streak \u2014 Consecutive days with at least one completed review. Your streak resets if you miss a day.',
              'Total Reviews \u2014 Lifetime count of all card reviews you have completed.',
              'Accuracy Rate \u2014 Percentage of cards you rated "Easy" or "Medium" (vs. "Hard").',
              'Cards Mastered \u2014 Cards that have reached long review intervals, indicating strong retention.',
              'Weekly Review Count \u2014 How many reviews you completed in the past 7 days.',
            ],
          },
          {
            type: 'tip',
            text: 'Consistency matters more than volume. A short daily review session is far more effective than occasional marathon study sessions.',
          },
        ],
      },
      {
        id: 'skip-suspend',
        title: 'Skip, Suspend & Reset Cards',
        icon: 'Pause',
        content: [
          {
            type: 'paragraph',
            text: 'Sometimes you need more control over individual cards in your review sessions:',
          },
          {
            type: 'list',
            items: [
              'Skip \u2014 Temporarily skip a card during the current session. It will come back in your next review session as normal.',
              'Suspend \u2014 Remove a card from future reviews entirely. Useful for outdated or irrelevant cards. You can unsuspend it later.',
              'Reset \u2014 Reset a card\'s review history, treating it as if you have never studied it before. The card returns to the "New Cards" pool.',
            ],
          },
        ],
      },
    ],
  },

  // ─── TAB 4: SOCIAL ───
  {
    key: 'social',
    label: 'Social',
    icon: 'Users',
    sections: [
      {
        id: 'finding-friends',
        title: 'Finding Friends',
        icon: 'Search',
        defaultExpanded: true,
        content: [
          {
            type: 'paragraph',
            text: 'Connect with classmates and study partners on Recall. Friends can share content with each other and see each other\'s public achievement badges.',
          },
          {
            type: 'steps',
            items: [
              'Click the Friends icon in the navigation bar (or the people icon on mobile).',
              'Go to "Find Friends" to browse other Recall users.',
              'Use the search bar to find specific people by name.',
              'Filter by course level to find classmates in your program.',
              'Click "Add Friend" to send a friend request.',
            ],
          },
          {
            type: 'paragraph',
            text: 'Each user\'s profile card in Find Friends shows their public achievement badges, making it easy to identify active and experienced study partners.',
          },
        ],
      },
      {
        id: 'friend-requests',
        title: 'Friend Requests',
        icon: 'UserPlus',
        content: [
          {
            type: 'paragraph',
            text: 'All friend connections require mutual consent. Both users must agree to be friends.',
          },
          {
            type: 'list',
            items: [
              'Sending \u2014 Click "Add Friend" on someone\'s profile. They receive a notification.',
              'Accepting \u2014 When someone sends you a request, you will see a notification in your bell icon. Click "Accept" to become friends.',
              'Declining \u2014 Click "Decline" to reject the request. The sender will not be notified of the rejection.',
              'Canceling \u2014 You can cancel a pending friend request you sent before the other person responds.',
            ],
          },
          {
            type: 'paragraph',
            text: 'You can also manage friend requests from the Friends dropdown in the navigation bar, which shows a count of pending requests.',
          },
        ],
      },
      {
        id: 'author-profiles',
        title: 'Author Profiles',
        icon: 'User',
        content: [
          {
            type: 'paragraph',
            text: 'Every piece of content on Recall has a clickable author name. Clicking on an author\'s name takes you to their profile, where you can see:',
          },
          {
            type: 'list',
            items: [
              'Their public achievement badges.',
              'Their shared notes and flashcard decks.',
              'Total upvotes received on their content.',
              'An option to send a friend request (if you are not already friends).',
            ],
          },
        ],
      },
      {
        id: 'friends-content',
        title: 'Friends-Only Content',
        icon: 'Lock',
        content: [
          {
            type: 'paragraph',
            text: 'When you set content visibility to "Friends", only your accepted friends can see and study that material. This is useful for sharing study notes with a trusted circle without making them public.',
          },
          {
            type: 'paragraph',
            text: 'Friends-only content appears in your friends\' browse pages alongside public content, but is clearly marked with a friends-only indicator.',
          },
        ],
      },
    ],
  },

  // ─── TAB 5: STUDY GROUPS ───
  {
    key: 'groups',
    label: 'Study Groups',
    icon: 'Network',
    sections: [
      {
        id: 'groups-overview',
        title: 'What Are Study Groups?',
        icon: 'Network',
        defaultExpanded: true,
        content: [
          {
            type: 'paragraph',
            text: 'Study Groups let you create a private space to share notes and flashcards with a specific set of people. Unlike friends-only sharing (which goes to all your friends), groups let you target content to specific study circles.',
          },
          {
            type: 'list',
            items: [
              'Create multiple groups for different subjects or study sessions.',
              'Invite specific Recall users to join your group.',
              'Share notes and flashcard decks directly with the group.',
              'All group members can share content, not just the group creator.',
              'Group-shared content appears in members\' browse pages.',
            ],
          },
        ],
      },
      {
        id: 'create-group',
        title: 'Creating a Group',
        icon: 'Plus',
        content: [
          {
            type: 'steps',
            items: [
              'Go to "Groups" in the navigation bar.',
              'Click "Create Group".',
              'Enter a group name and optional description.',
              'Your group is created and you are the admin.',
              'Start inviting members from the group detail page.',
            ],
          },
          {
            type: 'tip',
            text: 'Use descriptive group names like "Tax Law Study Circle" or "Final Exam Prep" so members know the group\'s purpose at a glance.',
          },
        ],
      },
      {
        id: 'inviting-members',
        title: 'Inviting Members',
        icon: 'UserPlus',
        content: [
          {
            type: 'paragraph',
            text: 'Group membership is consent-based \u2014 users must accept an invitation before they can see group content.',
          },
          {
            type: 'steps',
            items: [
              'Open your group detail page.',
              'Click "Invite Members".',
              'Search for Recall users by name.',
              'Select users and send invitations.',
              'Invited users receive a notification with Accept/Decline options.',
            ],
          },
          {
            type: 'list',
            items: [
              'Pending invitations can be canceled by the admin before the user responds.',
              'Declined invitations are removed quietly \u2014 no notification is sent to the admin.',
            ],
          },
        ],
      },
      {
        id: 'sharing-with-groups',
        title: 'Sharing Content with Groups',
        icon: 'Share2',
        content: [
          {
            type: 'paragraph',
            text: 'There are two ways to share content with a study group:',
          },
          {
            type: 'list',
            items: [
              'At creation time \u2014 When creating a note or flashcard deck, select "Study Groups" as the visibility and check the groups you want to share with.',
              'From the group page \u2014 Open any group and click "Share Content" to share existing notes or flashcard decks from your library. Any group member can share, not just the admin.',
            ],
          },
          {
            type: 'paragraph',
            text: 'Shared content appears in members\' browse and review pages. If you remove content from the group, members can no longer access it through the group (though any reviews they already started will continue in their personal review queue).',
          },
          {
            type: 'tip',
            text: 'Content shared with groups is stored as "Private" in the database \u2014 it won\'t appear on the public browse page. Only group members can see it through the group.',
          },
        ],
      },
      {
        id: 'managing-groups',
        title: 'Managing & Leaving Groups',
        icon: 'Settings',
        content: [
          {
            type: 'list',
            items: [
              'Leave Group \u2014 Any member can leave a group at any time. You will lose access to group-shared content.',
              'Remove Members \u2014 Group admins can remove members from the group.',
              'Admin Transfer \u2014 If the last admin leaves, the longest-standing member is automatically promoted to admin.',
              'Delete Group \u2014 Admins can delete the group, which removes all sharing connections (individual content is not deleted).',
            ],
          },
        ],
      },
    ],
  },

  // ─── TAB 6: MORE ───
  {
    key: 'more',
    label: 'More',
    icon: 'Star',
    sections: [
      {
        id: 'badges',
        title: 'Achievement Badges',
        icon: 'Trophy',
        defaultExpanded: true,
        content: [
          {
            type: 'paragraph',
            text: 'Earn badges by reaching milestones in your study journey. Badges appear on your profile and in the Find Friends page (if set to public).',
          },
          {
            type: 'list',
            items: [
              'Digitalizer \u2014 Upload your first note to Recall. Awarded for converting your study material to digital format.',
              'Memory Architect \u2014 Create 10 flashcards. Shows your commitment to building a strong study foundation.',
              'Streak Master \u2014 Maintain a 3-day study streak. Demonstrates consistent daily review habits.',
              'Night Owl \u2014 Complete a review between 11 PM and 4 AM (your local time). For the dedicated late-night studiers.',
              'Rising Star \u2014 Receive 5 upvotes on your shared content. Recognizes your contribution to the community.',
            ],
          },
          {
            type: 'paragraph',
            text: 'View all your badges from "My Achievements" in the profile dropdown. You can toggle each badge\'s visibility individually \u2014 set it to public (visible to others) or private (only you can see it).',
          },
          {
            type: 'tip',
            text: 'Badges are awarded automatically when you hit the milestone. You will receive a notification when you earn a new badge.',
          },
        ],
      },
      {
        id: 'class-stats',
        title: 'Anonymous Class Statistics',
        icon: 'BarChart3',
        content: [
          {
            type: 'paragraph',
            text: 'The Dashboard includes an anonymous class statistics section that lets you see how your study habits compare to others in your course level \u2014 without revealing anyone\'s identity.',
          },
          {
            type: 'list',
            items: [
              'Average Reviews/Week \u2014 How many reviews your classmates complete on average per week.',
              'Students Studied Today \u2014 How many students in your course level studied today.',
              'Students with 7+ Day Streaks \u2014 How many classmates have maintained a week-long study streak.',
              'Your stats vs. class average \u2014 A side-by-side comparison showing where you stand.',
            ],
          },
          {
            type: 'paragraph',
            text: 'Class statistics require at least 5 students in your course level to protect privacy. If fewer than 5 students exist, the section will not appear.',
          },
        ],
      },
      {
        id: 'notifications',
        title: 'Notifications',
        icon: 'Bell',
        content: [
          {
            type: 'paragraph',
            text: 'The bell icon in the navigation bar shows your unread notifications. Notifications are automatically marked as read when you open the dropdown.',
          },
          {
            type: 'list',
            items: [
              'Badge Earned \u2014 When you earn a new achievement badge.',
              'Friend Request \u2014 When someone sends you a friend request. You can Accept or Decline directly from the notification.',
              'Friend Accepted \u2014 When someone accepts your friend request.',
              'Group Invite \u2014 When you are invited to a study group. You can Accept or Decline directly from the notification.',
              'Content Upvoted \u2014 When someone upvotes your note or flashcard deck.',
              'Welcome \u2014 A one-time welcome message when you first join Recall.',
            ],
          },
          {
            type: 'paragraph',
            text: 'Old notifications are automatically cleaned up after 60 days. You can also manually delete individual notifications using the delete option.',
          },
        ],
      },
      {
        id: 'my-contributions',
        title: 'My Contributions',
        icon: 'Folder',
        content: [
          {
            type: 'paragraph',
            text: 'The "My Contributions" page (in the profile dropdown) shows all the content you have created on Recall:',
          },
          {
            type: 'list',
            items: [
              'Your notes \u2014 with upvote counts and visibility status.',
              'Your flashcard decks \u2014 with card counts and upvote totals.',
              'Quick actions to edit, change visibility, or delete your content.',
            ],
          },
        ],
      },
    ],
  },
];

// ─── FAQ ITEMS ───
export const FAQ_ITEMS = [
  {
    question: 'How does the review scheduling work?',
    answer: 'When you review a flashcard, you rate it Hard, Medium, or Easy. Hard cards come back in 1 day, Medium in 3 days, and Easy in 7 days. As you consistently rate cards Easy, the intervals grow longer (weeks, then months). This is based on the SuperMemo-2 spaced repetition algorithm.',
  },
  {
    question: 'Why are "Reviews Due" and "New Cards" shown separately?',
    answer: 'Research shows that mixing review of known material with brand-new learning reduces effectiveness for both. Reviews are about strengthening existing memories, while new cards require initial encoding. Keeping them separate helps you manage your daily workload and study more effectively.',
  },
  {
    question: 'Can I share private content with a study group?',
    answer: 'Yes. You can share content with a study group in two ways: select "Study Groups" visibility when creating the content, or share existing content from the group\'s detail page. Either way, the content is stored as private \u2014 it won\'t appear on the public browse page, but group members can access it through the group.',
  },
  {
    question: 'What happens if I leave a study group?',
    answer: 'You will lose access to content that was shared with the group by other members. Content you shared with the group will be removed from the group (but not deleted from your account). Any reviews you already started on group-shared cards will remain in your personal review queue.',
  },
  {
    question: 'How are my streaks calculated?',
    answer: 'Your streak counts consecutive days where you completed at least one flashcard review. Streaks are calculated based on your local timezone, which is automatically detected when you sign in. If you miss a day, your streak resets to zero.',
  },
  {
    question: 'Can others see my study statistics?',
    answer: 'Your individual stats are private. The anonymous class statistics on the Dashboard show aggregate data only (averages, totals) and require at least 5 students to display. No one can see your personal accuracy, streak, or review counts.',
  },
  {
    question: 'How do achievement badge privacy toggles work?',
    answer: 'By default, earned badges are public and visible on your profile and in Find Friends. You can toggle each badge individually from "My Achievements" to make it private. Private badges are only visible to you.',
  },
  {
    question: 'What does suspending a card do?',
    answer: 'Suspending a card removes it from all future review sessions. The card stays in your collection but will not appear during reviews. You can unsuspend it at any time to bring it back into your review rotation.',
  },
  {
    question: 'Can I edit my notes and flashcards after creating them?',
    answer: 'Yes. You can edit your notes (including replacing images/PDFs), modify flashcard content, change visibility settings, and update the course/subject/topic organization at any time from "My Contributions".',
  },
  {
    question: 'How do upvotes work?',
    answer: 'Anyone can upvote public notes and flashcard decks they find helpful. Each user can upvote a piece of content only once, and you cannot upvote your own content. Content creators can see who upvoted their work. Earning 5 upvotes unlocks the "Rising Star" badge.',
  },
];
