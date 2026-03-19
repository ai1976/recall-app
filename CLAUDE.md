# Recall App - Claude Code Instructions

## Environment
- **OS:** Windows 11
- **Shell:** bash (NOT PowerShell — Claude Code runs in bash even on Windows)
- **Stack:** React 18 + Vite, Supabase (PostgreSQL + Auth + RLS), TailwindCSS
- **Live URL:** https://recall-app-omega.vercel.app

## Git Commits (CRITICAL - bash)
The shell is bash. NEVER use PowerShell Here-String syntax (`$msg = @"..."@`) — it will fail.
ALWAYS use bash printf syntax:

```bash
git commit -m "$(printf 'feat: Description here\n\n- Detail 1\n- Detail 2')"
```

Full git guide: `docs/active/git-guide.md`

## Code Standards
- Use `@/` alias for ALL imports (e.g., `import { supabase } from '@/lib/supabase'`)
- Match existing UI patterns from similar components before creating new ones
- Pages use PascalCase (e.g., `MyNotes.jsx`), utilities use camelCase (e.g., `use-toast.js`)

## Project Documentation
Read these before making changes:
- **Current status:** `docs/active/now.md`
- **Architecture/context:** `docs/active/context.md`
- **File structure:** `docs/reference/FILE_STRUCTURE.md`
- **Database schema:** `docs/reference/DATABASE_SCHEMA.md`
- **Changelog:** `docs/tracking/changelog.md`
- **Bug tracking:** `docs/tracking/bugs.md`

## After Making Changes
Always update these docs:
1. `docs/active/now.md` - Update "Just Completed" section and session notes
2. `docs/tracking/changelog.md` - Prepend new entry with Added/Changed/Files Changed sections
3. `docs/tracking/bugs.md` - If any bugs were fixed
4. `docs/reference/FILE_STRUCTURE.md` - Only if new files were created

## Database Rules
- **Supabase client:** `src/lib/supabase.js`
- Reviews table is single source of truth for student progress
- NEVER use `toISOString()` for date calculations
- Group flashcards by `batch_id`, NEVER by timestamp
- Column is `created_at` in reviews table, NOT `reviewed_at`

## SQL Query Naming (Supabase SQL Editor)
When providing SQL queries, ALWAYS include:
1. **Name** with folder prefix in block letters: `[FOLDER] Descriptive Name`
2. **Description** explaining what the query does and when to use it

### Existing Folders
- `[CLEANUP]` - Data cleanup, removing duplicates, fixing bad data
- `[DATA]` - Data inserts, updates, bulk operations
- `[DIAGNOSTIC]` - Investigating issues, checking state, debugging
- `[FIX]` - One-time fixes for bugs or migration issues
- `[FUNCTIONS]` - CREATE/ALTER FUNCTION statements
- `[REPORTS]` - Analytics, aggregations, dashboards
- `[SCHEMA]` - ALTER TABLE, CREATE TABLE, indexes, constraints, RLS policies
- `[TEST]` - Verification queries to confirm changes worked

### Example Format
```
Name: [SCHEMA] Add visibility column to notes
Description: Adds three-tier visibility system (private/friends/public) replacing is_public boolean. Run once during migration.
```

If SQL doesn't fit existing folders, suggest a new folder name with justification.

## Testing Mindset
When implementing features, consider:
- Happy path + edge cases
- Empty states and loading states
- Multi-user scenarios (professor vs student)
- Database RLS policy implications

## Pre-Push Dependency Checklist (MANDATORY)
Before committing or pushing ANY change, work through this checklist. Do not skip steps.

### 1. Auth Context Check (for every DB query added or modified)
Identify the auth context of the page/component being changed:
- **Unauthenticated** = landing page, login, signup, public routes
- **Authenticated** = anything inside `/dashboard` or behind auth guard

Rule: **Unauthenticated pages MUST NOT query tables directly.** All data for public pages must come through a `SECURITY DEFINER` RPC function. Direct Supabase table queries are RLS-filtered and return 0 rows (silently) for anonymous visitors.

### 2. RLS Impact Check (for every new or modified query)
For each `.from('table')` call added or changed, answer:
- Is this table RLS-protected? (All tables in this project are.)
- Will this query ever run in an unauthenticated context?
- Does the query rely on `auth.uid()` being set? If so, it will silently fail for logged-out users.

If YES to unauthenticated context → route through an existing or new SECURITY DEFINER RPC.

### 3. SQL Deployment Dependency Check (CRITICAL before push)
If the frontend change depends on a new or updated SQL object (function, column, policy, index):
- **STOP. Do not push the frontend yet.**
- State explicitly: "This frontend change requires the following SQL to be deployed first in Supabase: [SQL name]"
- Only push frontend after confirming the user has run the SQL.

If you are unsure whether the SQL is already deployed, ASK before pushing.

### 4. Bidirectional Field Tracing
For any data field displayed in the UI, trace it end-to-end:
- What Supabase table/column does it come from?
- What query fetches it? (direct table query or RPC?)
- What is the auth context of the page showing it?
- Does the query correctly handle the auth context?

### 5. New Column / New RPC Field
If a fix requires a new column or a new field in an RPC response:
- The SQL change is a **hard prerequisite** — frontend must not be pushed first
- Provide the SQL with proper `[FOLDER] Name` format
- Explicitly tell the user: "Run this SQL in Supabase before I push."

### 6. Enabling RLS on an Existing Table (CRITICAL)
When enabling RLS on any table that already has data or active write paths:
- **Audit every existing INSERT/UPDATE/DELETE path to that table** — grep the codebase for `.from('table_name')`
- For each write path, ask: **does a valid session (`auth.uid()`) exist at the exact moment this runs?**
- Signup flows, email-confirmation flows, and any server-side trigger run WITHOUT a client session — `auth.uid()` is null
- **Profile creation during signup is the highest-risk path**: `signUp()` with email confirmation ON returns no session → any client-side profile INSERT will be silently blocked by RLS
- Rule: **Any write that must succeed without a client session MUST use a SECURITY DEFINER trigger or RPC** — never a direct client insert
- After enabling RLS, **immediately test the signup flow** with a real new account before pushing

### Deployment Order Rule (non-negotiable)
```
SQL changes in Supabase → THEN frontend push → THEN verify on live URL
```
Never reverse this order. If the SQL cannot be deployed yet, hold the frontend commit and say so.
