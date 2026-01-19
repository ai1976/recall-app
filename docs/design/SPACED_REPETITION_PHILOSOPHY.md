# Spaced Repetition Philosophy - Recall App

## Core Principle
**Spaced repetition is about REVIEWING at optimal intervals, not about exposing users to all available content.**

## The Two Learning Modes

### 1. Review Mode (Spaced Repetition)
**What it is:**
- Revisiting cards you've already studied
- Triggered by scheduled review dates
- Goal: Combat forgetting curve through optimal spacing

**When shown:**
- Card has `next_review_date <= today`
- User has previously rated this card
- Record exists in `reviews` table

**User Experience:**
- "You have 15 cards to review today"
- Clear, manageable number
- Completion feels achievable

**Cognitive State:**
- Recognition: "I've seen this before"
- Recall: "I remember (some of) this"
- Reinforcement: Strengthening neural pathways

---

### 2. Learning Mode (New Material)
**What it is:**
- First-time exposure to new cards
- User chooses when to learn new content
- Goal: Initial encoding into memory

**When shown:**
- Card does NOT exist in user's `reviews` table
- User explicitly selects "Learn New Cards"
- Should have daily limit (e.g., max 20 new cards/day)

**User Experience:**
- "45 new cards available to learn"
- Separate from review count
- User controls pacing

**Cognitive State:**
- Processing: "This is completely new"
- Encoding: Creating initial memory trace
- Higher cognitive load than review

---

## Why Separation Matters

### 1. Psychological Impact
❌ **Bad UX:** "You have 200 cards due today"
- User feels overwhelmed
- Likely to avoid studying
- Demotivating

✅ **Good UX:** "You have 15 reviews today | 45 new cards available"
- Clear expectations
- Manageable numbers
- User chooses when to tackle new content

### 2. Pedagogical Effectiveness
**Research shows:**
- Mixing review and new learning reduces effectiveness
- Brain processes familiar vs. novel information differently
- Optimal learning requires separating these activities

**From cognitive science:**
- **Spacing Effect:** Reviews work because of intervals between exposures
- **Desirable Difficulty:** Reviews should be challenging but not overwhelming
- **Cognitive Load Theory:** New learning requires more mental resources

### 3. Algorithm Integrity
**Spaced Repetition algorithms assume:**
- You've seen the card before
- You're rating recognition/recall strength
- Intervals are based on previous performance

**New cards:**
- Have no previous performance data
- Can't be "spaced" (no prior exposure)
- Require different introduction strategy

---

## Implementation in Recall

### Dashboard Metrics
```
┌─────────────────────────────┐
│  📅 Reviews Due Today: 15   │  ← Only cards with next_review_date <= today
├─────────────────────────────┤
│  ✨ New Cards: 45           │  ← Cards never studied (future feature)
└─────────────────────────────┘
```

### Study Flow
```
User clicks "Start Review Session"
  ↓
Load ONLY cards with next_review_date <= today
  ↓
User reviews these cards (rate Easy/Medium/Hard)
  ↓
next_review_date updated based on rating
  ↓
Session complete when all scheduled reviews done
```

### Future: New Card Learning
```
User clicks "Learn New Cards"
  ↓
Load cards NOT in reviews table 
  ↓
User studies new cards (rate Easy/Medium/Hard)
  ↓
Creates FIRST entry in reviews table
  ↓
Card now enters spaced repetition cycle
```

---

## Common Pitfalls to Avoid

### ❌ Pitfall 1: Counting All Accessible Cards as "Due"
**Wrong:**
```sql
SELECT COUNT(*) FROM flashcards WHERE user_can_access = true
```

**Problem:** This counts cards user has never seen as "due for review"

---

### ❌ Pitfall 2: Adding New Cards to Review Sessions
**Wrong:**
```javascript
const dueCards = await getDueReviews();
const newCards = await getNewCards();
const allCards = [...dueCards, ...newCards];  // ❌ Don't do this
```

**Problem:** Mixes pedagogically distinct activities

---

### ❌ Pitfall 3: Showing Combined Count
**Wrong UI:**
```
Reviews Due: 215  // (15 actual reviews + 200 new cards)
```

**Problem:** Demotivates users, creates anxiety

---

## References

### Academic Research
- Ebbinghaus, H. (1885). Memory: A Contribution to Experimental Psychology
- Cepeda et al. (2006). Distributed practice in verbal recall tasks
- Pashler et al. (2007). Organizing instruction and study to improve student learning

### Industry Standards
- Anki: Separates "Reviews" from "New Cards"
- SuperMemo: Distinct "Learning" vs "Review" modes
- Duolingo: Clear separation between lessons and practice

### Key Principle
> "Spaced repetition is not about studying everything; it's about reviewing what matters, when it matters, in the quantity that matters."

---

## Decision Authority
**This philosophy document is APPROVED and must guide all future development.**

Any feature that mixes review and new learning must be rejected in code review.

---