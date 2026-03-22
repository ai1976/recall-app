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
      {
        id: 'study-timer',
        title: 'Study Timer',
        icon: 'Timer',
        content: [
          {
            type: 'paragraph',
            text: 'Recall tracks how long you spend studying so you can see your daily and weekly totals on the dashboard. Study time is captured in two ways:',
          },
          {
            type: 'list',
            items: [
              'Auto-capture \u2014 When you complete a Study Set session (reviewing flashcards), Recall automatically logs the session duration. No action needed on your part.',
              'Manual timer \u2014 For offline study \u2014 reading notes, textbooks, or practising problems on paper \u2014 use the Study Timer widget on your dashboard. Press Start when you begin and Stop when you finish.',
            ],
          },
          {
            type: 'steps',
            items: [
              'Find the \u201cStudy Timer\u201d card in the Study Time section of your dashboard.',
              'Press \u201cStart\u201d when you begin offline study.',
              'Press \u201cStop\u201d when you finish. The session is saved immediately.',
              'Your Today and This Week totals update instantly.',
            ],
          },
          {
            type: 'tip',
            text: 'If you accidentally close the tab while the timer is running, Recall will detect the unfinished session next time you open the dashboard and ask whether you want to log it. Sessions older than 4 hours are discarded automatically.',
          },
          {
            type: 'paragraph',
            text: 'Study time is the foundation for upcoming features including the leaderboard, daily study goals, and friend comparisons \u2014 so keeping it accurate helps you track your real progress.',
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
        id: 'prof-bulk-csv',
        title: 'Bulk CSV Upload (Professors)',
        icon: 'Upload',
        roles: ['professor'],
        content: [
          { type: 'paragraph', text: 'Professors can upload many flashcards at once using a CSV file. Go to Create → Bulk Upload.' },
          { type: 'steps', items: [
            'Prepare a CSV with two columns: "front" and "back". Each row is one flashcard.',
            'Go to Create → Bulk Upload in the navigation bar.',
            'Select the course, subject, and topic for the batch.',
            'Upload your CSV file. A preview appears before you confirm.',
            'Review any validation errors (blank fronts, duplicates) flagged in the preview.',
            'Click "Upload" to create all cards as a new deck.',
          ]},
          { type: 'tip', text: 'Keep the CSV header row as exactly "front,back" (lowercase). Extra columns are ignored. Maximum 200 cards per upload.' },
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
      {
        id: 'flagging-content',
        title: 'Reporting Incorrect or Inappropriate Content',
        icon: 'Flag',
        content: [
          { type: 'paragraph', text: 'If you find a flashcard or note with wrong information, outdated content, or inappropriate material, you can flag it for review.' },
          { type: 'steps', items: [
            'Click the "Report" button (flag icon) on any note or flashcard.',
            'Select a reason: Content Error (wrong/outdated information), Inappropriate (offensive or off-topic), or Other.',
            'Add a brief description in the details field — for content errors, explain what is wrong.',
            'Submit the report.',
          ]},
          { type: 'list', items: [
            'Content Error flags are sent to the educator who created the material to correct it.',
            'Inappropriate flags go directly to the Recall admin team for review.',
            'You can only submit one flag per item — duplicate reports from the same account are blocked.',
            'If 3 or more students flag the same item, it is automatically escalated to high priority.',
          ]},
          { type: 'tip', text: 'For content errors, the more detail you add in the description, the faster the educator can fix it. For example: "The income tax basic exemption limit shown is ₹2.5L but it was revised to ₹3L from FY 2023-24."' },
          { type: 'tip', text: 'You can track the status of your reports in your dashboard under "My Reports". You will see whether your report is under review, resolved, or dismissed.' },
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
              'Go to "Find Friends" to browse other Recall users on your course.',
              'Use the search bar to find specific people by name.',
              'Click "Add Friend" to send a friend request.',
            ],
          },
          {
            type: 'paragraph',
            text: 'Find Friends automatically shows only users on your course level — cross-institute connections are fine, but cross-course discovery is not supported. Each profile card shows public achievement badges to help you identify active study partners.',
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
        id: 'friend-stats',
        title: 'Friend Stats',
        icon: 'BarChart2',
        content: [
          {
            type: 'paragraph',
            text: 'Once a friend request is accepted, each friend card in My Friends shows three live stats for the current week:',
          },
          {
            type: 'list',
            items: [
              'Streak \u2014 Consecutive study days. Shown as \u201c7d\u201d; displayed as \u201c\u2014\u201d if the streak is zero.',
              'Reviews this week \u2014 Total flashcard reviews completed since Monday.',
              'Study time \u2014 Total time logged in the study timer this week, formatted as \u201c1h 23m\u201d, \u201c45m\u201d, or \u201c< 1m\u201d.',
            ],
          },
          {
            type: 'paragraph',
            text: 'Stats only appear for confirmed friends \u2014 pending requests do not show activity. All stats reset at the start of each week (Monday).',
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
      {
        id: 'sharing-whatsapp',
        title: 'Sharing Study Content via WhatsApp',
        icon: 'Share2',
        content: [
          {
            type: 'paragraph',
            text: 'You can share any public note or flashcard deck directly to WhatsApp. When the recipient taps the link, they see a preview card with the title, subject, and author — and a link to open it in Recall.',
          },
          {
            type: 'steps',
            items: [
              'Open a note (from Browse Notes) or a study set (from Browse Flashcards).',
              'Click the Share button in the header (only visible on public content).',
              'On mobile: choose WhatsApp from the share sheet.',
              'On desktop: a WhatsApp link opens automatically in a new tab.',
              'The recipient sees a link preview. Clicking it opens the note or study set in Recall.',
            ],
          },
          {
            type: 'tip',
            text: 'The Share button only appears on content with Public visibility. If you do not see a Share button, go to the note or deck settings and change visibility to Public.',
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

  // ─── TAB 7: FOR PROFESSORS (role-gated) ───
  {
    key: 'professor-guide',
    label: 'For Professors',
    icon: 'GraduationCap',
    roles: ['professor'],
    sections: [
      {
        id: 'prof-welcome',
        title: 'Welcome, Professor',
        icon: 'GraduationCap',
        defaultExpanded: true,
        roles: ['professor'],
        content: [
          { type: 'paragraph', text: "Your professor account gives you tools beyond the standard student experience. You can upload notes and flashcard sets that appear directly in your enrolled students' study queues, track engagement with your content, and see how your batch is progressing." },
          { type: 'list', items: [
            'Upload notes and flashcard decks — same workflow as students, with public or private visibility.',
            'Bulk upload flashcards from a CSV file for faster content creation.',
            'View your Professor Analytics dashboard to see how students engage with your material.',
            'Students enrolled in your batch are automatically assigned to the same course and institution group.',
          ]},
          { type: 'tip', text: 'Complete your profile (institution and course level) before uploading content. Your content is grouped by these fields, which is how students in your batch discover it.' },
        ],
      },
      {
        id: 'prof-profile-setup',
        title: 'Profile Setup',
        icon: 'User',
        roles: ['professor'],
        content: [
          { type: 'paragraph', text: 'Before uploading content, set your institution and course level in your profile settings.' },
          { type: 'steps', items: [
            'Click your avatar or name in the top-right to open the Profile dropdown.',
            'Select "Profile Settings".',
            'Enter your Institution name (e.g., "More Classes Commerce") and Course Level (e.g., "CA Final").',
            'Save your profile.',
          ]},
          { type: 'tip', text: 'The institution and course level you set here must exactly match what your students select during signup. Batch auto-enrollment matches on both fields — a mismatch means students miss the batch group.' },
        ],
      },
      {
        id: 'prof-analytics',
        title: 'Professor Analytics Dashboard',
        icon: 'BarChart3',
        roles: ['professor'],
        content: [
          { type: 'paragraph', text: 'Access your analytics from the "Analytics" link in the top navigation bar (visible only to professors).' },
          { type: 'list', items: [
            'Course Selector — If you teach multiple courses, switch between them at the top.',
            'Overview Cards — Total students in your batch, total reviews of your content this week, and total published notes and study sets.',
            'Subject Breakdown Table — Per-subject review counts, unique reviewers, and your weakest and strongest-performing flashcards.',
            'Weak Cards — Cards with the lowest easy-rate across your batch. These topics need more reinforcement.',
            'Top Cards — Cards students find easiest — good indicators of mastered material.',
            'Weekly New Student Reach — How many new students reviewed your content each week.',
          ]},
          { type: 'tip', text: 'The weak cards list is your most actionable insight. If a topic consistently appears there, consider adding more flashcards or a supplementary note on that subject.' },
        ],
      },
      {
        id: 'prof-batch-groups',
        title: 'Batch Groups and Auto-Enrollment',
        icon: 'Users',
        roles: ['professor'],
        content: [
          { type: 'paragraph', text: 'Batch groups are created by admins and group students by course level and institution. When an admin grants a student access, the system automatically enrolls that student in the matching batch group.' },
          { type: 'list', items: [
            'You do not create batch groups yourself — admins create them.',
            'All students at your institution + course level are automatically in the same batch group.',
            'Your published content (notes and flashcard decks set to Public or Study Groups visibility) becomes visible to all enrolled students in your batch.',
            'The Professor Analytics dashboard shows aggregate study data for students in your batch.',
          ]},
          { type: 'tip', text: "If a student is not seeing your content, check that their institution and course level in their profile exactly matches yours. Mismatches prevent auto-enrollment." },
        ],
      },
      {
        id: 'prof-batch-performance',
        title: 'Batch Performance View',
        icon: 'BarChart3',
        roles: ['professor'],
        content: [
          {
            type: 'paragraph',
            text: 'Each batch group has a Batch Performance view — a private table showing this week\'s study activity for every student in that group. It is only visible to professors, admins, and super admins. Students cannot see it, and they cannot see batch groups in their Groups list at all. This is intentional: keeping the classroom social dynamic comfortable means students study for themselves, not to avoid appearing at the bottom of a leaderboard.',
          },
          {
            type: 'steps',
            items: [
              'Go to Study Groups in the navigation bar.',
              'Batch groups appear in your groups list with an "Official" badge. Click one.',
              'The Batch Performance table loads automatically — you do not need to click anything extra.',
              'Click any column header to sort. Click again to reverse the sort direction.',
            ],
          },
          {
            type: 'list',
            items: [
              'Name — The student\'s full name.',
              'Reviews This Week — Total flashcard reviews completed since Monday (server time). The primary measure of active study.',
              'Streak — Current consecutive-day review streak shown as e.g. "7d". A dash (—) means no active streak.',
              'Study Time This Week — Total time logged via the Study Timer since Monday. Shown as e.g. "1h 23m", "45m", or "< 1m".',
              'Last Active — When the student last completed a flashcard review. Shows "Today", "2 days ago", or a date for older activity.',
            ],
          },
          {
            type: 'tip',
            text: 'Last Active reflects the last flashcard review only — it does not update when a student logs offline study time using the manual timer. Study Time This Week does include manual timer sessions, so a student can have Study Time with no Last Active date if they have only used the manual timer and not reviewed any cards.',
          },
          {
            type: 'tip',
            text: 'Batch groups are created by admins — you cannot create them yourself. If your batch group is missing or has the wrong students, contact your admin.',
          },
        ],
      },
      {
        id: 'prof-needs-attention',
        title: 'Responding to Content Flags (Needs Attention)',
        icon: 'AlertTriangle',
        roles: ['professor'],
        content: [
          { type: 'paragraph', text: 'When students flag one of your notes or flashcards as containing an error, it appears in the "Needs Attention" section on your dashboard. You are expected to review and respond.' },
          { type: 'steps', items: [
            'Go to your Dashboard. The "Needs Attention" card shows flagged items.',
            'Click "Review" next to an item to open the edit page.',
            "Read the student's description of the issue in the flag.",
            'If the flag is valid: edit the content and save.',
            'If the flag is incorrect: the admin can dismiss it — contact admin if a flag is clearly wrong.',
          ]},
          { type: 'list', items: [
            'Items are shown in order of priority. 🔴 High priority means 3+ students flagged the same item.',
            'You only see "Content Error" flags — Inappropriate flags go to the admin team, not to you.',
            'Resolving a flag quickly keeps your content quality high and protects your reputation on the platform.',
          ]},
          { type: 'tip', text: 'If a tax law or syllabus changes, proactively update your flashcards before students flag them. One update can resolve multiple flags at once.' },
        ],
      },
      {
        id: 'prof-share-content',
        title: 'Sharing Content via WhatsApp',
        icon: 'Share2',
        roles: ['professor'],
        content: [
          {
            type: 'paragraph',
            text: 'Share any public note or flashcard deck directly to WhatsApp. Recipients see a link preview card with the title, subject, and your name as author.',
          },
          {
            type: 'steps',
            items: [
              'Open a note or study set you created.',
              'Click the Share button in the header (only available for Public content).',
              'On mobile: choose WhatsApp from the share sheet. On desktop: WhatsApp opens in a new tab.',
              'Students receive a preview link. Clicking it takes them to the note or deck on Recall.',
              'If a student is not yet signed up, they are prompted to create a free account before viewing.',
            ],
          },
          {
            type: 'tip',
            text: 'Sharing is the fastest way to get students started. Share your first few public decks in your class WhatsApp group and students can begin reviewing immediately — even before their batch group is set up.',
          },
        ],
      },
    ],
  },

  // ─── TAB 8: FOR ADMINS (role-gated) ───
  {
    key: 'admin-guide',
    label: 'For Admins',
    icon: 'Shield',
    roles: ['admin', 'super_admin'],
    sections: [
      {
        id: 'admin-dashboard-overview',
        title: 'Admin Dashboard Overview',
        icon: 'LayoutDashboard',
        defaultExpanded: true,
        roles: ['admin', 'super_admin'],
        content: [
          { type: 'paragraph', text: 'The Admin Dashboard is at /admin (Manage → Admin Dashboard in the nav bar). It has four main tabs:' },
          { type: 'list', items: [
            'Access Requests — Students who signed up requesting access appear here. Process them one at a time.',
            'Batch Groups — View all batch groups and create new ones. Batch groups are the mechanism for auto-enrolling students.',
            'Recent Users — Browse all registered users, their role, account type, and join date.',
            'Content — Browse all public notes and flashcard decks. You can review or remove content that violates community guidelines.',
          ]},
          { type: 'tip', text: 'Process Access Requests first each day — students are waiting for access. Batch Groups setup should be done before students start registering.' },
        ],
      },
      {
        id: 'admin-access-requests',
        title: 'Processing Access Requests',
        icon: 'UserPlus',
        roles: ['admin', 'super_admin'],
        content: [
          { type: 'paragraph', text: "When a student signs up and requests access, their request appears in the Access Requests tab. Review each request and grant or decline access." },
          { type: 'steps', items: [
            'Go to Admin Dashboard → Access Requests tab.',
            "Each request shows the student's name, email, institution, and course level.",
            "Click \"Grant Access\" to activate the student's account. This sets their account type to enrolled and auto-enrolls them in the matching batch group.",
            'To decline, mark the request as declined.',
          ]},
          { type: 'tip', text: "Auto-enrollment matches on both institution AND course level. If the student's institution or course level does not exactly match an existing batch group, they get access but land in no batch. You can create the matching batch group and re-run access grant." },
        ],
      },
      {
        id: 'admin-batch-groups',
        title: 'Creating Batch Groups',
        icon: 'Users',
        roles: ['admin', 'super_admin'],
        content: [
          { type: 'paragraph', text: 'Batch groups link students to professors by institution and course level. Always create batch groups before granting student access.' },
          { type: 'steps', items: [
            'Go to Admin Dashboard → Batch Groups tab.',
            'Click "New Batch Group".',
            'Enter the Group Name (e.g., "CA Final - More Classes Commerce"), select the Course, and enter the Institution name exactly as students will enter it in their profiles.',
            'Click "Create Group".',
            'Students with matching institution + course level will be auto-enrolled when you grant them access.',
          ]},
          { type: 'list', items: [
            'You can create multiple batch groups for the same course at different institutions.',
            'Institution matching is exact — confirm spelling before creating.',
          ]},
        ],
      },
      {
        id: 'admin-bulk-topics',
        title: 'Bulk Topic Upload',
        icon: 'Upload',
        roles: ['admin', 'super_admin'],
        content: [
          { type: 'paragraph', text: 'The Manage Topics page (Manage → Manage Topics) lets you seed the subject/topic taxonomy in bulk.' },
          { type: 'steps', items: [
            'Go to Manage → Manage Topics.',
            'Select or create a discipline (course program, e.g., "CA Final").',
            'Select or create a subject within that discipline (e.g., "Indirect Tax").',
            'Upload a CSV or paste topic names. Each row is one topic name.',
            'Review the parsed list and fix any errors.',
            'Click "Upload Topics" to add them to the database.',
          ]},
          { type: 'tip', text: 'Topics uploaded here become immediately available in the subject/topic selectors when creating notes and flashcards. Do this before professors start uploading content.' },
        ],
      },
      {
        id: 'admin-analytics',
        title: 'Admin Analytics',
        icon: 'BarChart3',
        roles: ['admin', 'super_admin'],
        content: [
          { type: 'paragraph', text: 'Admin Analytics (Manage → Admin Analytics) shows course-level study engagement across all students.' },
          { type: 'list', items: [
            'Overview Cards — Total users, total notes, total flashcards, and pending access requests.',
            'Content Health Table — Per-subject breakdown of review counts and average easy rate.',
            'Onboarding Funnel — Signed up → Access granted → First review completed.',
            'Weekly Reviews Chart — Total review volume across the platform per week.',
          ]},
        ],
      },
      {
        id: 'admin-flagged-content',
        title: 'Reviewing Flagged Content',
        icon: 'Flag',
        roles: ['admin', 'super_admin'],
        content: [
          { type: 'paragraph', text: 'Flagged content appears in Admin Dashboard → Content tab at the top of the page. Content Error flags go to the professor first — you see them too and can override. Inappropriate/Other flags come directly to you.' },
          { type: 'list', items: [
            '🔴 High Priority — 3 or more students flagged the same item. Act on these first.',
            'Content Error — Student believes the answer or information is wrong. Professor should fix it; you can dismiss if the flag is incorrect.',
            'Inappropriate — Content is offensive or off-topic. You must decide: dismiss or remove.',
            'Other — Review case by case.',
          ]},
          { type: 'steps', items: [
            'Go to Admin Dashboard → Content tab. Flagged items appear above Public Notes.',
            "Read the flag reason and student's details.",
            'Click "Dismiss" to reject the flag (adds it to Rejected history).',
            'Click "Remove" to delete the content permanently and mark the flag as removed.',
            'Use the status filter (Pending / Resolved / Rejected / Removed) to view history.',
          ]},
          { type: 'tip', text: 'For Content Error flags where the professor has already corrected the content, the flag will automatically appear as Resolved. You do not need to action those manually.' },
        ],
      },
      {
        id: 'superadmin-user-roles',
        title: 'Viewing and Changing User Roles',
        icon: 'Shield',
        roles: ['super_admin'],
        content: [
          { type: 'paragraph', text: 'The Super Admin Dashboard (Manage → Super Admin) lets you view all users across every role and change their role assignment.' },
          { type: 'steps', items: [
            'Go to Manage → Super Admin.',
            'Find the user in the Users table. Use the search bar or filter by role.',
            "Click the role badge next to the user's name to open the role change dialog.",
            'Select the new role (student, professor, admin, super_admin).',
            'Enter an optional reason (logged for audit purposes).',
            'Confirm the change. It is logged with old role, new role, changed_by, and timestamp.',
          ]},
          { type: 'list', items: [
            'You cannot change your own role.',
            'All role changes are visible in the Audit Log tab.',
            'Role changes take effect immediately — the user does not need to log out.',
          ]},
        ],
      },
      {
        id: 'superadmin-hard-delete',
        title: 'Hard Delete (Remove All User Data)',
        icon: 'Layers',
        roles: ['super_admin'],
        content: [
          { type: 'paragraph', text: 'Hard delete permanently removes a user and ALL their data from Recall. This cannot be undone.' },
          { type: 'list', items: [
            'Deleted data: profile, all notes, all flashcards, all decks, all reviews, friend connections, group memberships.',
            'The deletion is logged in admin_audit_log before execution.',
            'You cannot hard delete a super_admin account.',
          ]},
          { type: 'steps', items: [
            'Go to Manage → Super Admin.',
            'Find the user and click "Delete User" (shown in red).',
            "A confirmation dialog shows their name, email, and content count.",
            "Type the user's email to confirm, then click \"Delete Permanently\".",
          ]},
          { type: 'tip', text: 'Use hard delete only for GDPR data removal requests or confirmed fraudulent accounts. For inactive users, suspending their account in Admin Dashboard → Recent Users is sufficient and reversible.' },
        ],
      },
      {
        id: 'superadmin-sa-analytics',
        title: 'Super Admin Analytics',
        icon: 'BarChart3',
        roles: ['super_admin'],
        content: [
          { type: 'paragraph', text: 'Super Admin Analytics (Manage → SA Analytics) provides platform-wide metrics beyond admin analytics.' },
          { type: 'list', items: [
            'Header Strip — Platform totals (users, notes, flashcards, reviews this week).',
            'Cohort Comparison Table — Per-course review volume, active students, and average streak.',
            'Creator Leaderboard — Top 20 content creators by total items published.',
            'Platform Activity Heatmap — Calendar heatmap of total daily review volume across the entire platform.',
            'Retention Cards — New this week, inactive (30+ days no reviews), retained (signed up this week + already reviewed).',
            'Audit Log — 20 most recent admin actions with actor name and timestamp.',
          ]},
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
