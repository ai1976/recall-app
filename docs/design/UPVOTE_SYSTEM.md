# Upvote System Design

**Implemented:** 2026-01-24 (Phase 1D)

---

## Overview

The upvote system allows users to show appreciation for helpful content. It serves two purposes:
1. **Social validation** - Motivates content creators
2. **Quality signal** - Helps students identify valuable content

---

## Architecture Decisions

### Polymorphic Upvotes Table
Instead of separate `note_upvotes` and `deck_upvotes` tables, we use a single `upvotes` table with:
- `content_type`: 'note' | 'flashcard_deck'
- `target_id`: UUID pointing to the content

**Rationale:** Easier to extend for future content types (comments, study guides, etc.)

### Flashcard Decks as First-Class Entities
Created `flashcard_decks` table to solidify the concept of a "deck" (user + subject + topic grouping).

**Rejected Alternative:** Deterministic UUID from hash of composite key
**Reason:** Brittle - renaming a topic would orphan upvotes

### Denormalized Counts
Both `notes.upvote_count` and `flashcard_decks.upvote_count` are maintained by database triggers.

**Rationale:** Avoids COUNT(*) queries on every page load

---

## Visibility Rules

| Content Visibility | Who Can Upvote |
|-------------------|----------------|
| Public | Any authenticated user |
| Friends | Only accepted friends |
| Private | Nobody (no upvote button shown) |

**Self-Upvoting:** Blocked at both RLS and frontend level

---

## Who Sees What

| Viewer | Upvote Count | Upvoter Names |
|--------|--------------|---------------|
| Content Creator | ✅ | ✅ |
| Professor | ✅ | ✅ |
| Admin/Super Admin | ✅ | ✅ |
| Other Students | ✅ | ❌ |

---

## Frontend Implementation

### UpvoteButton Component
```jsx
<UpvoteButton
  contentType="note"           // or "flashcard_deck"
  targetId={note.id}
  initialCount={note.upvote_count}
  ownerId={note.user_id}
  size="sm"                    // sm | md | lg
/>
```

### Toggle Flow
1. User clicks button
2. Optimistic UI update (instant feedback)
3. Call `toggle_upvote()` RPC
4. Update with actual count from server
5. On error: revert optimistic update

---

## Database Functions

### toggle_upvote(p_content_type, p_target_id)
- Validates content exists
- Prevents self-upvoting
- Inserts or deletes upvote
- Returns action ('added'/'removed') and new count

### get_upvote_details(p_content_type, p_target_id)
- Returns upvoter names for creators/professors
- Returns empty for regular students

---

## Future Enhancements (Not Implemented)

1. **Notifications** - Alert creators when content is upvoted
2. **Trending Content** - Surface highly-upvoted content
3. **Downvotes** - Currently not planned (negative feedback handled via reports)
4. **Upvote Leaderboard** - Privacy concerns in small classrooms