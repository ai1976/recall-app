# Reviews Table Usage Guide

## Purpose
The `reviews` table is the **single source of truth** for all spaced repetition scheduling data.

## Schema
```sql
CREATE TABLE reviews (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id),
  flashcard_id UUID NOT NULL REFERENCES flashcards(id),
  quality INTEGER NOT NULL,                    -- 1-5 (SuperMemo-2 rating)
  interval INTEGER DEFAULT 0,                  -- Days until next review
  repetition INTEGER DEFAULT 0,                -- Number of times reviewed
  easiness DOUBLE PRECISION DEFAULT 2.5,       -- Ease factor (2.5 default)
  next_review_date DATE,                       -- ⚠️ CRITICAL: YYYY-MM-DD format
  last_reviewed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

## Critical Fields

### next_review_date (DATE)
**Format:** `'2026-01-26'` (YYYY-MM-DD string)  
**NOT:** `'2026-01-26T00:00:00.000Z'` (timestamp)

**Correct Usage:**
```javascript
const nextDate = new Date();
nextDate.setDate(nextDate.getDate() + intervalDays);
const dateString = nextDate.toISOString().split('T')[0]; // "2026-01-26"

await supabase.from('reviews').insert({
  next_review_date: dateString  // ✅ Correct
});
```

**Incorrect Usage:**
```javascript
await supabase.from('reviews').insert({
  next_review_date: new Date().toISOString()  // ❌ Wrong (timestamp)
});
```

## Query Patterns

### Get Due Reviews
```javascript
const today = new Date().toISOString().split('T')[0];

const { data } = await supabase
  .from('reviews')
  .select('flashcard_id, next_review_date')
  .eq('user_id', user.id)
  .lte('next_review_date', today);  // DATE comparison
```

### UPSERT Review
```javascript
// Check if exists
const { data: existing } = await supabase
  .from('reviews')
  .select('id, repetition')
  .eq('user_id', user.id)
  .eq('flashcard_id', cardId)
  .maybeSingle();

if (existing) {
  // UPDATE
  await supabase.from('reviews').update({
    quality: score,
    interval: days,
    repetition: existing.repetition + 1,
    easiness: factor,
    next_review_date: dateString,
    last_reviewed_at: new Date().toISOString()
  }).eq('id', existing.id);
} else {
  // INSERT
  await supabase.from('reviews').insert({
    user_id: user.id,
    flashcard_id: cardId,
    quality: score,
    interval: days,
    repetition: 1,
    easiness: factor,
    next_review_date: dateString
  });
}
```

## RLS Policies

### SELECT
```sql
Users can view their own reviews
WHERE auth.uid() = user_id
```

### INSERT
```sql
Users can insert their own reviews
WHERE auth.uid() = user_id
```

### UPDATE
```sql
Users can update their own reviews
WHERE auth.uid() = user_id
```

## Important Notes

1. **One Review Per User Per Card**
   - Use UPSERT pattern (UPDATE if exists, INSERT if new)
   - Never create duplicate reviews for same user + card

2. **Date Format is Critical**
   - PostgreSQL DATE type requires YYYY-MM-DD format
   - Sending timestamp may cause errors or incorrect comparisons

3. **Timezone Handling**
   - `next_review_date` is DATE only (no time component)
   - Comparisons use local midnight (user's timezone)
   - `last_reviewed_at` uses timestamp for audit trail

4. **Do Not Use flashcards.next_review**
   - Old column exists but is deprecated
   - Causes multi-user conflicts
   - RLS prevents student updates

## Migration Notes

- No schema changes required (column already exists)
- Old `flashcards.next_review` data can remain (unused)
- New system uses `reviews.next_review_date` exclusively

---