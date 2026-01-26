# Achievement Badges Design Document

**Path:** `docs/design/ACHIEVEMENT_BADGES.md`

**Action:** CREATE new file

```markdown
# Achievement Badges System - Design Document

**Feature:** Phase 1E - Achievement Badges  
**Status:** Implemented  
**Date:** 2026-01-26  
**Author:** Anand (with Claude assistance)

---

## 1. Overview

### Purpose
Gamification system to motivate students through achievement badges that recognize study habits, content creation, and community participation.

### Goals
1. **Motivation:** Reward consistent study behavior
2. **Recognition:** Acknowledge content contributors
3. **Social Proof:** Help students identify active peers in Find Friends
4. **Retention:** Encourage daily app usage through streaks

### Non-Goals
- Leaderboards (avoided to prevent unhealthy competition)
- Badge revocation (earned badges are permanent)
- Monetary rewards or premium features tied to badges

---

## 2. Badge Types

### Content Creator Badges

| Badge | Icon | Threshold | Trigger | Rationale |
|-------|------|-----------|---------|-----------|
| **Digitalizer** | upload | 1 note | notes INSERT | Rewards first contribution, low barrier |
| **Memory Architect** | brain | 10 flashcards | flashcards INSERT | Rewards sustained content creation |

### Study Habits Badges

| Badge | Icon | Threshold | Trigger | Rationale |
|-------|------|-----------|---------|-----------|
| **Streak Master** | flame | 3 days | reviews INSERT | Encourages consistency, achievable goal |
| **Night Owl** | moon | 1 review | reviews INSERT (11PM-4AM IST) | Fun recognition of late-night studiers |

### Community Badges

| Badge | Icon | Threshold | Trigger | Rationale |
|-------|------|-----------|---------|-----------|
| **Rising Star** | star | 5 upvotes | upvotes INSERT | Rewards quality content that peers value |

---

## 3. Technical Architecture

### Database Design

```
┌─────────────────────┐      ┌─────────────────────┐
│  badge_definitions  │      │    user_badges      │
├─────────────────────┤      ├─────────────────────┤
│ id (PK)             │◄────┐│ id (PK)             │
│ key (UNIQUE)        │     ││ user_id (FK)        │
│ name                │     └┤ badge_id (FK)       │
│ description         │      │ earned_at           │
│ icon_key            │      │ notified            │
│ category            │      │ is_public           │
│ threshold           │      └─────────────────────┘
│ is_active           │
│ order_num           │      ┌─────────────────────┐
└─────────────────────┘      │  user_activity_log  │
                             ├─────────────────────┤
                             │ id (PK)             │
                             │ user_id (FK)        │
                             │ activity_type       │
                             │ activity_date       │
                             │ activity_hour       │
                             └─────────────────────┘
```

### Trigger Architecture

```
User Action              Trigger                    Badge Check
───────────────────────────────────────────────────────────────────
notes INSERT      →  trg_badge_note_upload     →  digitalizer
flashcards INSERT →  trg_badge_flashcard_create → memory_architect
reviews INSERT    →  trg_badge_review          →  streak_master, night_owl
upvotes INSERT    →  trg_badge_upvote          →  rising_star
```

### Award Flow

```
┌──────────────────┐
│ User completes   │
│ an action        │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Database trigger │
│ fires            │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐     No
│ User meets       │───────────► (No action)
│ threshold?       │
└────────┬─────────┘
         │ Yes
         ▼
┌──────────────────┐     Yes
│ Already has      │───────────► (No action)
│ badge?           │
└────────┬─────────┘
         │ No
         ▼
┌──────────────────┐
│ INSERT into      │
│ user_badges      │
│ (notified=false) │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Frontend detects │
│ via useBadges()  │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Show toast       │
│ Mark notified    │
└──────────────────┘
```

---

## 4. Privacy Design

### Philosophy
Students should have **granular control** over which achievements are visible to peers. This is especially important for:
- **Night Owl:** Reveals late-night study habits
- **Streak badges:** May create social pressure
- **Low achievement counts:** May embarrass some students

### Implementation
- **Per-badge toggle:** Each earned badge has `is_public` (default: true)
- **No global toggle:** Gives users precise control
- **Default public:** Encourages sharing while allowing opt-out
- **Instant effect:** Toggle immediately affects Find Friends display

### Privacy Rules
1. Users can only see their own `is_public` toggles
2. `get_public_user_badges()` filters by `is_public = true`
3. FindFriends queries only public badges
4. Badge count on own profile shows all earned (public + private)

---

## 5. Timezone Handling

### Problem
Night Owl badge needs to detect reviews between 11 PM and 4 AM in **user's local time** (IST for Indian students).

### Solution
```sql
-- In trigger: Convert UTC to IST
v_ist_timestamp := NEW.created_at AT TIME ZONE 'Asia/Kolkata';
v_activity_hour := EXTRACT(HOUR FROM v_ist_timestamp)::INTEGER;

-- Check Night Owl hours (23, 0, 1, 2, 3, 4)
IF v_activity_hour >= 23 OR v_activity_hour <= 4 THEN
    PERFORM award_badge(NEW.user_id, 'night_owl');
END IF;
```

### Why IST Only?
- Current user base is 100% Indian students
- Simplifies implementation
- Can extend to user-specific timezones in future if needed

---

## 6. Streak Calculation

### Definition
Consecutive days where user completed at least one review.

### Algorithm
```
1. Get today's date in IST
2. Check if user has activity for today
3. If yes, increment streak and check yesterday
4. Repeat until a day with no activity is found
5. Return streak count
```

### Edge Cases
| Scenario | Behavior |
|----------|----------|
| No reviews ever | Streak = 0 |
| Reviewed today only | Streak = 1 |
| Reviewed yesterday but not today | Streak = 0 (broken) |
| Gap of 1+ days in past | Streak starts from most recent consecutive block |

### Data Source
Streaks are calculated from `user_activity_log` table, NOT raw `reviews` table. This ensures:
- Fast queries (one row per day per user)
- Accurate day boundaries (uses IST date)
- Efficient storage

---

## 7. Frontend Components

### Component Hierarchy

```
MyAchievements.jsx
├── BadgeCard.jsx (for each badge)
│   ├── BadgeIcon.jsx
│   └── Switch (privacy toggle)
└── BadgeIcon.jsx (in progress summary)

Dashboard.jsx
├── useBadges() hook
└── BadgeToast.jsx (in toast notification)

FindFriends.jsx
└── BadgeIcon.jsx (next to user names)
```

### BadgeIcon Mapping

| icon_key | Lucide Icon | Color | Background |
|----------|-------------|-------|------------|
| upload | Upload | blue-600 | blue-500 |
| brain | Brain | purple-600 | purple-500 |
| flame | Flame | orange-600 | orange-500 |
| moon | Moon | indigo-600 | indigo-500 |
| star | Star | yellow-600 | yellow-500 |

### Size Variants

| Size | Icon Class | Container Class |
|------|------------|-----------------|
| xs | h-4 w-4 | h-6 w-6 |
| sm | h-5 w-5 | h-7 w-7 |
| md | h-6 w-6 | h-8 w-8 |
| lg | h-8 w-8 | h-10 w-10 |
| xl | h-10 w-10 | h-12 w-12 |

---

## 8. Toast Notifications

### Trigger
- `useBadges()` hook polls for unnotified badges every 30 seconds
- On Dashboard mount, checks immediately
- `get_unnotified_badges()` returns badges where `notified = false`

### Display
```
┌─────────────────────────────────────┐
│ [🔥]  Badge Unlocked!               │
│       Streak Master                 │
└─────────────────────────────────────┘
```

### After Display
- Function marks `notified = true` in database
- Badge won't appear in toast again
- User can still see badge in MyAchievements

---

## 9. Future Enhancements

### Potential New Badges

| Badge | Category | Threshold | Notes |
|-------|----------|-----------|-------|
| Social Butterfly | social | 5 friends | Rewards network building |
| Subject Expert | content | 10 cards in 1 subject | Rewards depth |
| Early Adopter | special | Registered before March 2026 | Rewards beta testers |
| Perfectionist | study | 100% accuracy for 7 days | High bar, prestigious |
| Marathon Runner | study | 30-day streak | Long-term commitment |

### Technical Improvements
1. **User timezone:** Store timezone in profiles, use for Night Owl
2. **Badge tiers:** Bronze → Silver → Gold for increasing thresholds
3. **Badge sharing:** "Share to WhatsApp" button for earned badges
4. **Leaderboard opt-in:** Optional badge leaderboard for competitive users

---

## 10. Decisions Log

| Decision | Chosen Option | Rationale |
|----------|---------------|-----------|
| Badge visibility | Public by default | Encourages sharing, network effects |
| Privacy control | Per-badge toggle | Granular control, Night Owl concern |
| Streak length | 3 days | Achievable for beginners |
| Night Owl hours | 11 PM - 4 AM IST | Matches actual late-night study patterns |
| Badge revocation | Never revoke | Permanent achievements feel more valuable |
| Badge name | "Streak Master" not "The Grinder" | Grinder has inappropriate connotations |
| Nav badge count | Removed | Confusing UX, not like friend requests |

---

## 11. Testing Checklist

### Badge Award Tests
- [ ] Upload 1 note → Digitalizer badge awarded
- [ ] Create 10 flashcards → Memory Architect badge awarded
- [ ] Review 3 consecutive days → Streak Master badge awarded
- [ ] Review at 11:30 PM IST → Night Owl badge awarded
- [ ] Receive 5 upvotes → Rising Star badge awarded

### Privacy Tests
- [ ] Toggle badge to private → Hidden in Find Friends
- [ ] Toggle badge to public → Visible in Find Friends
- [ ] New badge defaults to public

### Edge Case Tests
- [ ] Second badge of same type → No duplicate
- [ ] Deleted user → No FK errors (CASCADE)
- [ ] Orphaned reviews → Backfill script handles gracefully

### UI Tests
- [ ] Toast appears on new badge
- [ ] Toast doesn't repeat after page refresh
- [ ] MyAchievements shows progress for locked badges
- [ ] FindFriends shows max 4 badges + "+N" overflow

---

## 12. SQL File Reference

| File | Folder | Purpose |
|------|--------|---------|
| badges_tables_and_seed.sql | SCHEMA | Tables + 5 badge definitions |
| badges_rls_policies.sql | SCHEMA | RLS for all 3 tables |
| badges_core_functions.sql | FUNCTIONS | 6 core functions |
| badges_triggers.sql | FUNCTIONS | 4 triggers |
| badges_backfill_existing_users.sql | FIX | Backfill for existing users |
| badges_per_badge_privacy.sql | SCHEMA | Added is_public column |
| badges_per_badge_rls_update.sql | SCHEMA | Updated RLS for is_public |
| badges_public_function_v2.sql | FUNCTIONS | Updated functions for privacy |
| rename_grinder_badge.sql | FIX | Renamed to Streak Master |

---

## 13. Metrics to Track

### Engagement Metrics
- % of users with at least 1 badge
- Average badges per user
- Most common badge
- Least common badge (hardest to earn)

### Privacy Metrics
- % of badges set to private
- Which badges are most often hidden (Night Owl?)

### Retention Metrics
- Does Streak Master badge correlate with higher retention?
- Do users with badges visit app more frequently?

---

*Document maintained by Anand. Last updated: 2026-01-26*
```

---

This comprehensive design document covers:
1. Purpose and goals
2. All badge types with rationale
3. Technical architecture diagrams
4. Privacy design philosophy
5. Timezone and streak handling
6. Frontend component structure
7. Toast notification flow
8. Future enhancement ideas
9. Decision log
10. Testing checklist
11. SQL file reference
12. Metrics to track
