# IDEAS - Feature Backlog

**Project:** Recall  
**Last Updated:** March 25, 2026

---

## Phase 0.5: Professor Content Seeding (NEXT)

### Required Before Student Launch
- [ ] Recruit 2-3 CA Inter professors
- [ ] Seed 220 flashcards (target)
- [ ] Seed 35 notes (target)
- [ ] Cover all 6 CA Inter subjects
- [ ] Professor profile pages
- [ ] "Verified Faculty Content" badges

### Content Targets by Subject
| Subject | Flashcards | Notes |
|---------|------------|-------|
| Taxation | 50 | 8 |
| Advanced Accounting | 50 | 8 |
| Auditing & Assurance | 40 | 6 |
| Cost Accounting | 30 | 5 |
| Corporate Law | 30 | 5 |
| Strategic Management | 20 | 3 |

---

## Phase 2: Foundation Scale (150 Students)

### Features
- [ ] AI-generated flashcards from notes
- [ ] Study groups/collections
- [ ] Export notes to PDF
- [ ] Mobile app installation prompts (PWA)
- [ ] Push notifications
- [ ] CA Foundation content (150 flashcards)

### Admin Enhancements
- [ ] Hire first admin for 150+ users
- [ ] Content moderation queue
- [ ] Support ticket system

---

## Phase 3: External CA Students (750+)

### Features
- [ ] Advanced search (OCR text search within notes)
- [ ] Leaderboards
- [ ] Professor Marketplace (paid content)
- [ ] Note marketplace (buy/sell)
- [ ] Verified notes badge (from rankers)
- [ ] Video notes support

### Growth
- [ ] Marketing to external CA students
- [ ] Referral program
- [ ] Coaching institute partnerships

---

## Phase 4: Multi-Discipline (4,200+ Users)

### New Courses
- [ ] CMA (Foundation, Intermediate, Final)
- [ ] CS (Foundation, Executive, Professional)
- [ ] JEE preparation
- [ ] NEET preparation
- [ ] CFA/ACCA (international)

### Features
- [ ] Multi-language support
- [ ] Voice notes with transcription
- [ ] Collaborative note editing
- [ ] Quiz generation from notes
- [ ] White-label solutions for coaching institutes

---

## Social Features (Future)


### Community Features
- [ ] Study groups (private collections)
- [ ] Group flashcard decks
- [ ] Shared study sessions
- [ ] Comments on shared notes
- [ ] Upvote quality content

---

## Gamification (Future)

### Engagement
- [ ] XP points system
- [ ] Achievement badges
- [ ] Weekly challenges
- [ ] Class leaderboards
- [ ] Streak freeze (skip one day)
- [ ] Daily goals

### Rewards
- [ ] Monthly top contributor awards
- [ ] Premium feature unlocks
- [ ] Physical merchandise (Phase 4)

---

## Analytics & Reporting (Future)

### Student Dashboard
- [ ] Study time tracking (minutes/day)
- [ ] Subject-wise progress
- [ ] Weakness identification
- [ ] Exam readiness score
- [ ] Comparison with class average (anonymous)

### Admin Reports
- [ ] Daily active users
- [ ] Content growth metrics
- [ ] Retention analysis
- [ ] Revenue tracking
- [ ] Churn prediction

---

## Technical Debt

### Performance
- [ ] Image lazy loading
- [ ] Pagination for large note lists
- [ ] Database query optimization
- [ ] CDN for static assets
- [ ] **Tech Debt (Target: ~5,000 active students):** Refactor `cron-daily-study-summary` Edge Function. Currently scans the entire `profiles` table every 15 minutes and calculates each user's local timezone at runtime. This works fine at ~140 users but will hit Edge Function timeout limits at scale. **Fix:** Add a `notification_bucket_utc` column to `profiles` (e.g. `'16:30'` for IST users — their 10 PM in UTC). Add an index on this column. The cron job then runs a single indexed lookup `WHERE notification_bucket_utc = <current_utc_time>` instead of doing datetime math on every row. Calculate and write the bucket value once at signup or timezone change, not on every cron tick.

### Code Quality
- [ ] Remove console.log statements
- [ ] Add TypeScript (Phase 4)
- [ ] Unit tests for spaced repetition
- [ ] E2E tests with Playwright

### Security
- [ ] Rate limiting on API
- [ ] Two-factor authentication (admin/super_admin)
- [ ] IP-based login alerts
- [ ] Export audit logs to CSV

---

## Business Features (Future)

### Monetization
- [ ] Razorpay payment integration
- [ ] Subscription management
- [ ] Usage-based limits (free tier)
- [ ] Course-specific pricing
- [ ] Exam bundles (₹499/6 months)

### B2B Expansion
- [ ] Vivitsu partnership (30% revenue share)
- [ ] Coaching institute bulk licenses
- [ ] API for third-party integrations
- [ ] Custom branding (white-label)

---

## Content Partnerships

### Identified Partners
- [ ] Vivitsu (CA content organization)
- [ ] Local coaching institutes
- [ ] CA rankers (verified notes)
- [ ] Subject matter experts

### Revenue Model
- Individual professors: 40% revenue share
- Organizations (Vivitsu): 30% revenue share
- Student creators: 40% revenue share (future)

---

## Ideas Parking Lot

*Unvalidated ideas to revisit later:*

- [ ] AI tutor chatbot
- [ ] Offline mode (PWA)
- [ ] Dark mode
- [ ] Pomodoro timer integration
- [ ] Calendar integration (study planning)
- [ ] Browser extension for web clipping
- [ ] OCR for handwritten notes (advanced)
- [ ] Audio flashcards (text-to-speech)
- [ ] Spaced repetition for reading (not just flashcards)