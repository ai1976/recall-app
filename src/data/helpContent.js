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
        title: 'Welcome to RevisOp',
        icon: 'BookOpen',
        defaultExpanded: true,
        content: [
          {
            type: 'paragraph',
            text: 'RevisOp is a study platform built around spaced repetition \u2014 a scientifically proven method to help you remember what you learn. Upload notes, create flashcards, review them at optimal intervals, and track your progress over time.',
          },
          {
            type: 'paragraph',
            text: 'Whether you are preparing for exams or just want to retain knowledge better, RevisOp helps you study smarter, not harder.',
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
            text: 'Here is how to get started with RevisOp in just a few minutes:',
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
            text: 'RevisOp tracks how long you spend studying so you can see your daily and weekly totals on the dashboard. Study time is captured in two ways:',
          },
          {
            type: 'list',
            items: [
              'Auto-capture \u2014 When you complete a Study Set session (reviewing flashcards), RevisOp automatically logs the session duration. No action needed on your part.',
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
            type: 'paragraph',
            text: 'What happens if you switch apps or the page reloads while the timer is running:',
          },
          {
            type: 'list',
            items: [
              'Under 4 hours away \u2014 Timer auto-resumes from where it left off. No prompt. This covers briefly switching to WhatsApp, a browser tab, or another app.',
              '4 to 16 hours away \u2014 Timer pauses and shows a prompt: \u201cYour timer ran for Xh Ym. Were you studying the whole time?\u201d You can log the full time, log fewer hours via a custom input (if you took breaks), or discard the session. Be honest \u2014 your time feeds the leaderboard.',
              'Over 16 hours away \u2014 Session is silently discarded. A session of that length cannot be genuine continuous study.',
            ],
          },
          {
            type: 'tip',
            text: 'The best habit is to press Stop before switching away. Auto-resume is a safety net for short breaks, not a substitute for managing your own timer.',
          },
          {
            type: 'paragraph',
            text: 'Accurate study time feeds the leaderboard and daily goals \u2014 logging honestly is what makes those features meaningful.',
          },
        ],
      },
      {
        id: 'daily-goals',
        title: 'Daily Goals',
        icon: 'Target',
        content: [
          {
            type: 'paragraph',
            text: 'The Daily Goal widget on your dashboard lets you set a personal daily target and track your progress against it in real time.',
          },
          {
            type: 'list',
            items: [
              'Review goal \u2014 A target number of flashcard reviews to complete each day (maximum 200).',
              'Study time goal \u2014 A target number of minutes to spend studying each day (maximum 480, i.e. 8 hours). This counts both Study Set sessions and manual timer sessions.',
            ],
          },
          {
            type: 'steps',
            items: [
              'Find the \u201cDaily Goal\u201d card in the Study Time section of your dashboard.',
              'Click \u201cReview goal\u201d or \u201cStudy time goal\u201d to set a target.',
              'Type a number and press Set (or press Enter). Only one goal type is active at a time.',
              'The widget immediately shows your progress: today\u2019s actual vs your target, a progress bar, and the percentage complete.',
              'When you hit 100%, the widget shows \u201cGoal reached \u2713\u201d in green.',
            ],
          },
          {
            type: 'list',
            items: [
              'Progress resets at midnight in your local timezone every day.',
              'To change your target, click the \u201cEdit\u201d link on the active goal.',
              'To switch goal types (e.g., from review to study time), click Edit and then choose the other type \u2014 this clears the old goal automatically.',
              'To remove a goal entirely, click Edit and then \u201cClear goal\u201d.',
            ],
          },
          {
            type: 'tip',
            text: 'Start small. A daily goal of 20 reviews is more sustainable than 100. Consistency over weeks builds more retention than high-volume cramming.',
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
        title: 'Creating Study Items',
        icon: 'CreditCard',
        content: [
          {
            type: 'paragraph',
            text: 'Every study item starts from the same form. Three types \u2014 Flashcard, Theory, and Concept Card \u2014 are open to everyone. Five more types are available only to professor and admin accounts \u2014 see "Question Types" below.',
          },
          {
            type: 'list',
            items: [
              'Flashcard \u2014 a plain front (question/prompt) and back (answer).',
              'Theory \u2014 a longer written answer. Choose a Subtype: Pure theory (a definition or rule) or Descriptive case study (a worked example).',
              'Concept Card \u2014 reference material, not a flashcard: a Concept Name, a short Summary, and 1-10 Key Terms (a term + definition each). It never enters your review queue \u2014 reopen it anytime from a study set\u2019s "Read Concepts" button.',
              'To add many items at once instead of one-by-one, use Bulk Upload \u2014 see "Bulk CSV Upload \u2014 Basics" below.',
            ],
          },
          {
            type: 'steps',
            items: [
              'Go to "Create" \u2192 "Create Study Item" from the navigation bar.',
              'Select the course, subject, and topic.',
              'Choose the Question Type.',
              'Fill in the front/back (or Concept Name / Summary / Key Terms for a concept card).',
              'Set the visibility and optional difficulty tag (Easy, Medium, Hard).',
              'Click "Create" to save.',
            ],
          },
          {
            type: 'tip',
            text: 'Keep flashcard fronts short and specific. A good flashcard tests one concept at a time. For example, instead of "Explain depreciation", try "What is the straight-line method of depreciation?"',
          },
        ],
      },
      {
        id: 'question-types-guide',
        title: 'Question Types',
        icon: 'Brain',
        content: [
          { type: 'paragraph', text: 'RevisOp has eight kinds of study item. You will see all of them while studying, even ones you cannot create yourself \u2014 here is what each is for and how to answer it.' },
          { type: 'paragraph', text: 'Flashcard \u2014 the simplest item: a front (question or prompt) and a back (the answer). Example: front "What is 20% of 500?", back "100". Anyone can create one. Keep the front to one idea \u2014 a card that asks two things at once is harder to grade honestly. To answer: try to recall it, tap "Show Answer", then rate how well you remembered it.' },
          { type: 'paragraph', text: 'Theory \u2014 for a longer, written-out answer that a one-line flashcard cannot hold. Every Theory item needs a Subtype: Pure theory (a definition, rule, or concept explained in words) or Descriptive case study (a worked example you reason through). Example: front "Explain the difference between exemption and deduction under the Income Tax Act." Anyone can create one. Do not use Theory for something a flashcard can answer in one line. To answer: same as a flashcard \u2014 recall it, tap "Show Answer", then rate yourself; the Subtype only changes how the item is filed, not how you study it.' },
          { type: 'paragraph', text: 'Concept Card \u2014 reference material, not a question. It has a Concept Name, a short Summary, and a list of Key Terms (1-10 term + definition pairs). Example: concept "Audit Materiality" with key terms like "Performance Materiality" and "Clearly Trivial Threshold". Anyone can create one. To use it: open "Read Concepts" on a study set and expand the terms you need \u2014 it is never graded and never scheduled for review, so there is nothing to answer or rate.' },
          { type: 'paragraph', text: 'Multiple Choice (MCQ) \u2014 a question with 2-6 answer options, one of them correct. Example: "Which of these is a deduction under Section 80C?" with four options. Only professor and admin accounts can create these. Write options that are all plausible \u2014 an obviously wrong option does not test anything, and RevisOp does not support marking more than one option correct. To answer: tap the option you think is right; a correct tap lets you self-grade, a wrong tap automatically marks the card Hard.' },
          { type: 'paragraph', text: 'Correct/Incorrect \u2014 a true-or-false style statement. The two answers, "Correct" and "Incorrect", are filled in for you \u2014 the author only marks which one is right. Example: "AS 1 deals with the disclosure of accounting policies" \u2192 Correct. Only professor and admin accounts can create these. Add an explanation so a wrong statement teaches something, not just that it was false. To answer: tap Correct or Incorrect; a wrong tap auto-marks the card Hard, a right one lets you self-grade.' },
          { type: 'paragraph', text: 'Case study MCQ \u2014 one shared scenario with several multiple-choice questions attached to it. Example: an audit scenario about an inventory valuation error, followed by questions on what opinion to issue and what to do next. Only professor and admin accounts can create these. To answer: the scenario appears in a "Case Scenario" panel above the question, open by default \u2014 read it, then answer the MCQ underneath exactly as you would a regular Multiple Choice question.' },
          { type: 'paragraph', text: 'Match the following \u2014 a left-hand list and a lettered right-hand list (A, B, C\u2026), paired one-to-one. Example: match accounting standards on the left to what they cover on the right. Only professor and admin accounts can create these, with 2-8 items on each side. To answer: build your pairings on screen, then tap "Check Answers" \u2014 every pairing is revealed at once; if anything is wrong the card is auto-marked Hard, if everything is right you self-grade.' },
          { type: 'paragraph', text: 'Fill in the Blank \u2014 a sentence with a blank (shown as ______) that you type an answer into. Example: "AS 1 deals with the disclosure of ______" with accepted answers "accounting policies", "accounting policy disclosures". Only professor and admin accounts can create these \u2014 a good one lists every phrasing it should accept, not just one. To answer: type your answer and submit. A match is confirmed immediately; a non-match is never marked wrong \u2014 you are shown the accepted answers and asked to self-grade, the same as a flashcard.' },
          { type: 'tip', text: 'No RevisOp question type currently supports more than one correct option \u2014 a real exam question with multiple correct answers needs a different item type (e.g. Theory), not Multiple Choice.' },
          { type: 'tip', text: 'Concept Cards are the only type that is never graded and never enters your review queue. Every other type \u2014 including a Fill in the Blank answer that does not match \u2014 always ends with a rating.' },
        ],
      },
      {
        id: 'prof-question-type-authoring',
        title: 'Authoring the Professor-Only Question Types',
        icon: 'Layers',
        roles: ['professor', 'admin', 'super_admin'],
        content: [
          { type: 'paragraph', text: 'Multiple Choice, Correct/Incorrect, Case study MCQ, Match the following, and Fill in the Blank are only creatable from a professor or admin account. Multiple Choice, Correct/Incorrect, Case study MCQ, and Fill in the Blank can be authored either manually or via Bulk Upload. Match the following is manual creation only — Bulk Upload does not support it for any role. Here is what each form looks like.' },
          { type: 'list', items: [
            'Multiple Choice \u2014 a Question field, 2-6 options (add or remove rows freely), and a radio button marking the correct one. Explanation is optional and shown after the student answers.',
            'Correct/Incorrect \u2014 a Statement field. The two options, "Correct" and "Incorrect", are already filled in \u2014 just mark which is right. Explanation is optional.',
            'Match the following \u2014 Left Items and Right Items (2-8 each, right items auto-lettered A, B, C\u2026 \u2014 do not type the letters yourself). Pick each left item\u2019s Correct Mapping from a dropdown of the right items. Optional "Why" explanation.',
            'Case study MCQ \u2014 write the Scenario once, then click "Add Question" to attach 2-8 MCQ-style questions under it, each with its own 2-6 options and its own optional explanation. You never repeat the scenario text or manage a grouping label by hand \u2014 that is only needed for CSV upload (see "Bulk CSV Upload \u2014 Professor & Admin Types" below).',
            'Fill in the Blank \u2014 a "Sentence with a blank" field that must contain ______ (at least three underscores) somewhere in it, plus up to 6 acceptable answers. List every phrasing you would accept (e.g. "accounting policies", "accounting policy disclosures"), not just one.',
          ]},
          { type: 'tip', text: 'Multiple Choice, Correct/Incorrect, Case study MCQ, and Match the following are gated because a wrong verdict automatically marks the student\u2019s card Hard \u2014 a badly written option actively sets a genuinely correct student back, not just an unhelpful card. Fill in the Blank works differently: it never has a "wrong" verdict, only a match or a self-graded fallback \u2014 but an incomplete acceptable-answers list still harms the student, by failing to recognize a genuinely correct answer as a confident match.' },
        ],
      },
      {
        id: 'bulk-csv-basics',
        title: 'Bulk CSV Upload — Basics',
        icon: 'Upload',
        content: [
          { type: 'paragraph', text: 'A CSV is a spreadsheet saved in CSV format rather than as an Excel workbook — plain text, one row per line, values separated by commas. Bulk Upload creates many study items at once from one.' },
          { type: 'steps', items: [
            'Go to "Create" → "Bulk Upload" in the navigation bar.',
            'Pick your course, then download "Valid Entries" — the exact Course/Subject/Topic names you can use, so your rows are accepted.',
            'Download the Template — a ready-made CSV with example rows and full column instructions built in.',
            'Fill in your rows, matching the course/subject/topic spelling exactly from Valid Entries, and save as a UTF-8 CSV.',
            'Back on the page, optionally label the batch, choose a visibility (Private, Friends Only, or Public — there is no Study Groups option here), and select your CSV file.',
            'Click "Upload" and review the results — any row with an error is skipped and listed; valid rows are created.',
          ]},
          { type: 'list', items: [
            'Course, subject, and topic are supplied in the CSV file itself, not chosen on screen — visibility and the optional batch label are the only settings you pick on the page.',
            'front is required on every row. back is required only for Flashcard and Theory rows — leave it blank for every other type, it is filled in automatically.',
            'tags (optional, comma-separated) and difficulty (optional: easy/medium/hard, defaults to medium) work the same way for every row.',
            'Theory rows need subtype set to pure_theory or descriptive_case_study.',
            'Everyone can bulk-upload plain Flashcard and Theory rows.',
            'Match the following and Concept Card cannot be created via CSV at all, for any role — create these individually instead.',
            'Multiple Choice, Correct/Incorrect, Case study MCQ, and Fill in the Blank rows need a professor or admin account — a student’s rows of these types are rejected on upload (see "Bulk CSV Upload — Professor & Admin Types" if you have that role).',
            'Quote a cell that contains a comma, e.g. "#ITR,#basics". Double up a quote mark inside a quoted cell, e.g. "she said ""exempt""" — that is standard CSV escaping, not a RevisOp rule.',
            'Blank cells are fine for anything optional. Text inside a quoted cell can span multiple lines, but line breaks inside front/back are collapsed into a single space either way.',
          ]},
          { type: 'list', items: [
            `Flashcard row: CA Intermediate, Taxation, Income Tax Basics, What is the basic exemption limit for individuals below 60 years?, ₹2.5 lakhs, "#ITR, #basics", easy, , , , , , , , , , , `,
            `Theory row: CA Intermediate, Taxation, Income Tax Basics, Explain the difference between exemption and deduction under the Income Tax Act., An exemption removes income from the tax base entirely; a deduction reduces taxable income after it's included., "#ITR", medium, theory, , , , , , , pure_theory, , , `,
          ]},
          { type: 'tip', text: 'Download the Template on the Bulk Upload page for the exact header row to copy — do not retype it by hand, since every column must be spelled exactly right.' },
          { type: 'tip', text: 'The figures in these examples (like the exemption limit above) are for illustrating the CSV format only, not current tax figures — always check the applicable year and regime before treating any number in a study item as authoritative.' },
          { type: 'tip', text: 'If question_type is spelled anything other than flashcard, theory, mcq, correct_incorrect, case_study_mcq, or fitb — including match_the_following or concept_card — the row is not rejected. It is silently created as a plain Flashcard instead. Double-check the spelling in that column.' },
        ],
      },
      {
        id: 'prof-bulk-csv',
        title: 'Bulk CSV Upload — Professor & Admin Types',
        icon: 'Upload',
        roles: ['professor', 'admin', 'super_admin'],
        content: [
          { type: 'paragraph', text: 'The same CSV template also carries four more question types. Their rows are only accepted from a professor or admin account — a student’s rows of these types are rejected on upload. Columns not needed for a given type can stay blank.' },
          { type: 'list', items: [
            'Write mcq, correct_incorrect, case_study_mcq, or fitb in the question_type column for these (leave it blank, or write flashcard/theory, for the basic types).',
            'Multiple Choice — fill option_1 through option_4 (2-4 filled in — CSV has only 4 option columns, so a 5th or 6th option needs manual creation instead) and set correct_option to the number of the right one. Leave back blank; it is derived automatically.',
            'Correct/Incorrect — leave option_1..option_4 blank (the Correct/Incorrect pair is automatic) and set correct_option to 1 for Correct or 2 for Incorrect.',
            'Case study MCQ — every row in one case needs the identical scenario text repeated, plus a case_group label of your choosing that is the same across every row in that case and unique to it within the file (e.g. "xyz-inventory-case"). Manual creation is simpler for a new case — you type the scenario once and add questions under it — so consider that route instead of CSV.',
            'Fill in the Blank — front must contain a blank marker (______, at least three underscores). List every acceptable answer in fitb_answers, separated by semicolons, and quote the whole cell if any answer contains a comma. CSV has no upper limit on how many you list, unlike manual creation’s cap of 6.',
            'explanation is optional and works the same way for all four of these types — shown to the student after they answer.',
          ]},
          { type: 'list', items: [
            `Multiple Choice row: CA Intermediate, Taxation, Income Tax Basics, Which of these is a deduction under Section 80C?, , "#ITR", medium, mcq, Life insurance premium, House rent paid, Medical insurance premium, Interest on savings account, 1, Life insurance premium qualifies under 80C; the others fall under different sections., , , , `, 
            `Correct/Incorrect row: CA Intermediate, Taxation, Income Tax Basics, Interest on savings account is fully exempt from tax regardless of amount., , "#ITR", medium, correct_incorrect, , , , , 2, Only up to Rs 10000 is exempt under Section 80TTA -- beyond that it's taxable., , , , `, 
            `Fill in the Blank row: CA Intermediate, Taxation, Income Tax Basics, The basic exemption limit for individuals below 60 years is ______., , "#ITR", medium, fitb, , , , , , No explanation needed -- this is a direct recall fact., , , , "₹2.5 lakhs;2.5 lakhs;250000;2,50,000"`, 
            `Case study MCQ — all three rows below belong to the SAME case, sharing one scenario and case_group:`,
            `CA Intermediate, Auditing, Audit Evidence, What type of audit opinion should be issued given the evidence described in the scenario?, , "#audit", medium, case_study_mcq, Unmodified opinion, Qualified opinion, Adverse opinion, Disclaimer of opinion, 2, The misstatement is material but not pervasive -- a qualified opinion is appropriate., , "During the audit of XYZ Ltd for FY 2025-26,  the auditor identified an inventory valuation error understating cost of goods sold by 8% of net profit. Management declined to adjust the financial statements.", xyz-inventory-case, `, 
            `CA Intermediate, Auditing, Audit Evidence, Which audit procedure would have been most effective in detecting this misstatement earlier?, , "#audit", medium, case_study_mcq, Analytical review of gross margin trends, Bank confirmation, Related party disclosure review, Subsequent events review, 1, A gross margin trend analysis would have flagged the anomaly before year-end., , "During the audit of XYZ Ltd for FY 2025-26,  the auditor identified an inventory valuation error understating cost of goods sold by 8% of net profit. Management declined to adjust the financial statements.", xyz-inventory-case, `, 
            `CA Intermediate, Auditing, Audit Evidence, What should the auditor do if management continues to refuse the adjustment?, , "#audit", medium, case_study_mcq, Issue an unmodified opinion anyway, Modify the opinion and describe the basis in the audit report, Withdraw from the engagement immediately, Ignore it as immaterial, 2, SA 705 requires a modified opinion with a clear basis-for-qualification paragraph., , "During the audit of XYZ Ltd for FY 2025-26,  the auditor identified an inventory valuation error understating cost of goods sold by 8% of net profit. Management declined to adjust the financial statements.", xyz-inventory-case, `, 
          ]},
          { type: 'tip', text: 'These example rows are copied from the Template you can download on the Bulk Upload page itself, so they are guaranteed to match what the uploader accepts. The figures and rulings in them (tax limits, audit opinions) are for illustrating the format only, not current authoritative figures — check the applicable year, regime, or standard before reusing any of them as real content.' },
          { type: 'tip', text: 'The easiest way to build a real case study is to copy its three example rows above and edit them, rather than typing one from scratch.' },
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
              'Friends \u2014 Visible to your accepted friends on RevisOp. Good for sharing with classmates you trust.',
              'Public \u2014 Visible to all RevisOp users. Ideal for sharing helpful material with the wider community.',
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
            text: 'All content in RevisOp is organized in a three-level hierarchy: Course \u2192 Subject \u2192 Topic. This makes it easy to find and browse specific material.',
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
            'Inappropriate flags go directly to the RevisOp admin team for review.',
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
            text: 'RevisOp uses a modified version of the SuperMemo-2 algorithm to schedule your reviews. Each time you review a card, you rate how well you remembered it, and the system adjusts the next review date accordingly.',
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
            text: 'RevisOp separates your study sessions into two distinct modes, because research shows that mixing review and new learning reduces effectiveness:',
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
              'Review by Subject \u2014 Go to "Study" \u2192 "Browse Study Sets" and select a specific subject to focus your review.',
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
        title: 'Skip, Suspend & Reset',
        icon: 'Pause',
        content: [
          {
            type: 'paragraph',
            text: 'During a review session you have several ways to manage cards. Safe snooze actions are at the top of the \u22ef menu; destructive actions are below the separator.',
          },
          {
            type: 'list',
            items: [
              'Skip 24hr \u2014 Hides this card until tomorrow. Your spaced repetition schedule is completely preserved \u2014 nothing is deleted or reset.',
              'Skip Topic (24hr) \u2014 Available from the \u22ef menu when a card belongs to a topic. Hides every card in that topic until tomorrow in one tap. Useful when one topic feels too heavy for today.',
              'Suspend Card \u2014 Removes this card from your review queue indefinitely. Unlike Skip, this does disrupt your spaced repetition schedule for that card. You can unsuspend it from the Progress page.',
              'Suspend Topic \u2014 Removes all cards in the current topic indefinitely. Use with caution \u2014 this affects your entire review schedule for that topic. Reversible from the Progress page.',
              'Reset Card \u2014 Deletes all review history for this card. It returns to the \u201cNew Cards\u201d pool as if never studied. This cannot be undone.',
            ],
          },
          {
            type: 'tip',
            text: 'When you are overwhelmed, reach for Skip (24hr) or Skip Topic (24hr) first \u2014 they are fully reversible and keep your schedule intact. Only use Suspend or Reset when you genuinely want to remove a card long-term.',
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
            text: 'Connect with classmates and study partners on RevisOp. Friends can share content with each other and see each other\'s public achievement badges.',
          },
          {
            type: 'steps',
            items: [
              'Click the Friends & Following icon in the navigation bar (or the people icon on mobile).',
              'Go to "Find People" to browse other RevisOp users on your course.',
              'Use the search bar to find specific people by name.',
              'Click "Add Friend" to send a friend request, or "Follow" to follow them without a mutual connection.',
            ],
          },
          {
            type: 'paragraph',
            text: 'Find People automatically shows only users on your course level — cross-institute connections are fine, but cross-course discovery is not supported. Each profile card shows public achievement badges to help you identify active study partners.',
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
            text: 'Every piece of content on RevisOp has a clickable author name. Clicking on an author\'s name takes you to their profile, where you can see:',
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
        id: 'follow-system',
        title: 'Following',
        icon: 'Rss',
        content: [
          {
            type: 'paragraph',
            text: 'Following is a one-way connection \u2014 no mutual agreement needed. Follow anyone on RevisOp: students from other courses, professors, or top performers you want to keep an eye on.',
          },
          {
            type: 'list',
            items: [
              'One-way \u2014 you follow them; they do not need to follow you back.',
              'No course restriction \u2014 follow anyone regardless of their course level.',
              'The person you follow gets a notification when you start following them.',
            ],
          },
          {
            type: 'paragraph',
            text: 'How to follow someone: go to Find People (Friends & Following icon \u2192 Find People) and tap Follow on any card, or visit their profile and tap the Follow button.',
          },
          {
            type: 'paragraph',
            text: 'For students you follow, each card shows three live stats for the current week: streak (consecutive study days), reviews this week, and study time this week. For professors and admins, stats are not shown \u2014 visit their profile to explore their notes and flashcards instead.',
          },
          {
            type: 'paragraph',
            text: 'To manage who you follow, go to the Following tab (Friends icon \u2192 Following, or Groups \u2192 Following on mobile). You can unfollow anyone from there.',
          },
          {
            type: 'tip',
            text: 'Following is for inspiration \u2014 use it to track high-performers or professors. For mutual stats-sharing and friends-only content, use the friend system instead.',
          },
        ],
      },
      {
        id: 'leaderboard',
        title: 'Leaderboard',
        icon: 'Trophy',
        content: [
          {
            type: 'paragraph',
            text: 'The Leaderboard widget on your dashboard lets you see how your study activity compares to the people you are connected with. It has two tabs:',
          },
          {
            type: 'list',
            items: [
              'Friends — Your mutual friends who are students, ranked by reviews this week. You always appear in this list so you can see your own rank.',
              'Following — Up to the top 20 students you follow, ranked by reviews this week. If you are outside the top 20, your own row is appended at the bottom with your actual rank.',
            ],
          },
          {
            type: 'list',
            items: [
              'Ranking is by reviews this week (Monday to Sunday, server time). Study time is the tiebreaker when two people have the same review count.',
              'Tied rows show the same rank number.',
              'Your row is highlighted in blue so it is easy to spot.',
              'Streak is not shown on the leaderboard — it is visible on your own dashboard only.',
              'There is no platform-wide public leaderboard by design — RevisOp values privacy and does not surface global rankings.',
              'Professors and admins are excluded — they are content creators, not reviewers, and their stats are not shown in any leaderboard context.',
            ],
          },
          {
            type: 'tip',
            text: 'To appear on your friends\u2019 leaderboard, add mutual friends from the Find People page. To appear on someone\u2019s Following tab, they need to follow you.',
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
            text: 'You can share any public note or flashcard deck directly to WhatsApp. When the recipient taps the link, they see a preview card with the title, subject, and author — and a link to open it in RevisOp.',
          },
          {
            type: 'steps',
            items: [
              'Open a note (from Browse Notes) or a study set (from Browse Flashcards).',
              'Click the Share button in the header (only visible on public content).',
              'On mobile: choose WhatsApp from the share sheet.',
              'On desktop: a WhatsApp link opens automatically in a new tab.',
              'The recipient sees a link preview. Clicking it opens the note or study set in RevisOp.',
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
              'Invite specific RevisOp users to join your group.',
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
              'Search for RevisOp users by name.',
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
            text: 'Earn badges by reaching milestones in your study journey. Badges appear on your profile and in the Find People page (if set to public).',
          },
          {
            type: 'list',
            items: [
              'Digitalizer \u2014 Upload your first note to RevisOp. Awarded for converting your study material to digital format.',
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
              'Welcome \u2014 A one-time welcome message when you first join RevisOp.',
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
            text: 'The "My Contributions" page (in the profile dropdown) shows all the content you have created on RevisOp:',
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
    roles: ['professor', 'admin', 'super_admin'],
    sections: [
      {
        id: 'prof-welcome',
        title: 'Welcome, Professor',
        icon: 'GraduationCap',
        defaultExpanded: true,
        roles: ['professor', 'admin', 'super_admin'],
        content: [
          { type: 'paragraph', text: "Your professor account gives you tools beyond the standard student experience. You can upload notes and flashcard sets that any student can find, create question types a plain student account cannot, track engagement with your content, and see study activity for your institution's batch group." },
          { type: 'list', items: [
            'Upload notes and flashcard decks — same workflow as students, plus five extra question types (see "Creating Flashcards" in the Content tab).',
            'Bulk upload many flashcards at once from a CSV file.',
            'View your Professor Analytics dashboard to see how students engage with your material.',
            "If your institution has a batch group, it gives you a private view of that batch's study activity — see Batch Groups below. A student joining it is always their own explicit action (or an admin adding them directly), never automatic.",
          ]},
          { type: 'tip', text: 'Complete your profile (institution and course level) so students and admins can identify you correctly and so your Analytics dashboard is scoped to the right course. It does not add anyone to a batch group by itself.' },
        ],
      },
      {
        id: 'prof-profile-setup',
        title: 'Profile Setup',
        icon: 'User',
        roles: ['professor', 'admin', 'super_admin'],
        content: [
          { type: 'paragraph', text: 'Set your institution and course level in your profile settings so students and admins can identify you, and so your Professor Analytics dashboard is scoped to the right course.' },
          { type: 'steps', items: [
            'Click your avatar or name in the top-right to open the Profile dropdown.',
            'Select "Profile Settings".',
            'Enter your Institution name (e.g., "More Classes Commerce") and Course Level (e.g., "CA Final").',
            'Save your profile.',
          ]},
          { type: 'tip', text: 'Your institution and course level do not add you or any student to a batch group, and they are never matched automatically to enroll anyone. Batch groups are created by an admin, and a student joins only by requesting through an invite link (or an admin adding them directly) — see Batch Groups below.' },
        ],
      },
      {
        id: 'prof-analytics',
        title: 'Professor Analytics Dashboard',
        icon: 'BarChart3',
        roles: ['professor', 'admin', 'super_admin'],
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
        title: 'Batch Groups',
        icon: 'Users',
        roles: ['professor', 'admin', 'super_admin'],
        content: [
          { type: 'paragraph', text: "A batch group is an official course group an admin creates for your institution. It gives you and your admin a private view of that batch's study activity — it does not control which students can see your content." },
          { type: 'list', items: [
            'You do not create batch groups yourself — an admin creates them and shares an invite link with students.',
            'A student joins by opening that link and requesting to join; an admin must approve the request before it counts as membership (or an admin can add a specific student directly). Nothing is added automatically by matching course or institution.',
            "Joining a batch group never changes a student's course, exam target, or institution profile.",
            "Batch groups exist for this monitoring view — they never appear in a student's own Groups list.",
            'Your Public content is visible to every RevisOp user whether or not they are in your batch. Content you set to "Study Groups" visibility only reaches a batch group if you specifically pick that group when sharing — batch membership by itself does not unlock or protect any of your content.',
            'The Professor Analytics dashboard shows aggregate study data by course, separate from any batch group.',
          ]},
          { type: 'tip', text: "If a student can't find your batch, check with your admin — they control the invite link and approve join requests. You cannot create, approve, or manage batch group membership yourself." },
        ],
      },
      {
        id: 'prof-batch-performance',
        title: 'Batch Performance View',
        icon: 'BarChart3',
        roles: ['professor', 'admin', 'super_admin'],
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
              '# — Rank based on the current sort order. Rank 1 is always the student at the top of whichever column you have sorted. Clicking a different column header re-ranks instantly.',
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
          {
            type: 'tip',
            text: "If a batch disappears from your Study Groups list, your admin likely archived it — its report is frozen exactly as it stood on the archive date and no longer updates. Ask your admin to restore it, or for a direct link, if you need to check an archived batch's report.",
          },
        ],
      },
      {
        id: 'prof-needs-attention',
        title: 'Responding to Content Flags (Needs Attention)',
        icon: 'AlertTriangle',
        roles: ['professor', 'admin', 'super_admin'],
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
        roles: ['professor', 'admin', 'super_admin'],
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
              'Students receive a preview link. Clicking it takes them to the note or deck on RevisOp.',
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
          { type: 'paragraph', text: 'The Admin Dashboard is at /admin (Manage → Admin Dashboard in the nav bar). It has four tabs:' },
          { type: 'list', items: [
            'Content Moderation — Browse all public notes and flashcard decks. Review or remove content that violates community guidelines.',
            'User Management — Browse all registered users, grant access to new signups, suspend accounts, and add an already-enrolled student directly to a batch group.',
            'Access Requests — Review new signup requests and educator (professor) applications.',
            'Batch Groups — Create batch groups, approve or reject students’ pending requests to join one, and archive or restore a batch group.',
          ]},
          { type: 'tip', text: 'Check Access Requests and the Batch Groups tab’s Pending Batch Requests regularly — students are waiting on both.' },
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
            'Click "Grant Access" to activate the student\'s account. This sets their account type to Enrolled and notifies them — it does not add them to any batch group.',
            'To decline, mark the request as declined.',
          ]},
          { type: 'tip', text: '"Grant Access" only unlocks full content access. To add the student to a batch group afterwards, either share your batch’s invite link so they can request to join themselves, or go to User Management and use the "Add to batch…" picker next to their name — batch membership is always this kind of explicit, one-student-at-a-time step, never automatic.' },
        ],
      },
      {
        id: 'admin-batch-groups',
        title: 'Batch Groups',
        icon: 'Users',
        roles: ['admin', 'super_admin'],
        content: [
          { type: 'paragraph', text: 'A batch group gives your institution a private view of one course’s study activity. Creating one adds no students — they join afterward, one at a time, with your approval.' },
          { type: 'steps', items: [
            'Go to Admin Dashboard → Batch Groups tab.',
            'Click "Create Batch Group".',
            'Choose the Course Level, enter a Group Name, an optional description, and select the Institution.',
            'Click "Create Group". The batch starts with no members.',
          ]},
          { type: 'list', items: [
            'Click "Copy Invite Link" on the batch’s card and share it with your students (for example, over WhatsApp).',
            'When a student opens the link and taps "Request to Join", their request appears under "Pending Batch Requests" above the batch list. Click "Approve" to add them or "Reject" to turn them down — approving is the only way a request becomes a real member.',
            'To add one specific student without an invite link, find them in User Management and use the "Add to batch…" picker next to their name. This counts as approval immediately.',
            'Course and institution are never matched automatically to add or remove a student — every membership change is one of these explicit steps.',
          ]},
          { type: 'steps', items: [
            'Once a course/cohort has ended, click "Archive" on its batch group.',
            'Archiving stops new join requests and invitations and closes any that were still pending. Approved members and their existing content access are unaffected.',
            'The batch’s report freezes exactly as it stood at the moment you archived it — later student activity, even from existing members, is not reflected.',
            'Click "Restore" to reopen an archived batch and resume live reporting. Restoring does not reopen requests or invitations that archiving closed — a student must request to join again.',
          ]},
          { type: 'tip', text: 'There is no way to permanently delete a batch group — archive it instead once it has ended.' },
          { type: 'tip', text: 'This Admin Dashboard tab is for managing membership and lifecycle only. To see a batch’s actual weekly performance report (reviews, streaks, study time per student), open Study Groups in the navigation bar and click into the batch — the same monitoring view professors use. See "Batch Performance View" under For Professors for what that report shows.' },
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
          { type: 'paragraph', text: 'The Super Admin Dashboard (Manage → Super Admin) lets you view all users across every role and promote or demote them.' },
          { type: 'steps', items: [
            'Go to Manage → Super Admin.',
            'Find the user in the Users table. Use the search bar or filter by role.',
            'In the Actions column, click the button for the role change you want — the available buttons depend on the user\'s current role (e.g. a student\'s row shows "Prof" and "Admin"; a professor\'s row shows "Admin" and "Student").',
            'A prompt asks you to type an optional reason, then confirm — this is a browser prompt, not a form on the page.',
            'The change takes effect immediately and is logged with the old role, new role, who changed it, and when.',
          ]},
          { type: 'list', items: [
            'There is no path to promote anyone to super_admin from this screen.',
            'A super_admin\'s own row shows no promote/demote buttons — you cannot change your own role or another super_admin\'s role.',
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
          { type: 'paragraph', text: 'Hard delete permanently removes a user and their data from RevisOp. This cannot be undone.' },
          { type: 'list', items: [
            'Deleted data: profile, notes, flashcards, flashcard decks, reviews, study group memberships, and course selections.',
            'The system attempts to record the action before deletion runs.',
            'You cannot hard delete a super_admin account — the delete button does not appear on their row.',
          ]},
          { type: 'steps', items: [
            'Go to Manage → Super Admin.',
            'Find the user and click the red trash icon in their row (it has no text label).',
            'A confirmation shows their name, email, and content count.',
            'Type DELETE in capital letters when prompted to confirm — there is no email-confirmation step.',
          ]},
          { type: 'list', items: [
            'This deletes the user\'s data from RevisOp, but not their login itself — you still need to remove their auth record separately from Supabase Dashboard → Authentication → Users, since that step requires service-role access the browser doesn\'t have.',
          ]},
          { type: 'tip', text: 'Use hard delete only for GDPR data removal requests or confirmed fraudulent accounts. For inactive users, suspending their account in Admin Dashboard → User Management is sufficient and reversible.' },
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
            'Header Strip — Total Users, Content Creators, Reviews This Month, and Active Courses.',
            'Cohort Comparison Table — per course: Students, Published Items, Reviews This Week, Avg Reviews/Student, and 7-Day Retention.',
            'Creator Leaderboard — top 20 content creators, ranked by items published, with role, course, and students reached.',
            'Platform Activity Heatmap — a calendar heatmap of total daily review volume across the entire platform, last 12 months.',
          ]},
          { type: 'tip', text: 'Looking for new-vs-inactive-student counts or the admin action audit log? Those live on the Super Admin Dashboard (Manage → Super Admin), not on this Analytics page.' },
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
    answer: 'By default, earned badges are public and visible on your profile and in Find People. You can toggle each badge individually from "My Achievements" to make it private. Private badges are only visible to you.',
  },
  {
    question: 'What is the difference between Skip and Suspend?',
    answer: 'Skip 24hr is a temporary snooze — the card comes back tomorrow and your spaced repetition schedule is fully preserved. Suspend is indefinite removal — the card disappears from your queue until you manually unsuspend it from the Progress page. Skip Topic (24hr) and Suspend Topic work the same way but apply to every card in a topic at once. Use Skip when you need a break; use Suspend when you genuinely want to remove a card or topic long-term.',
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
