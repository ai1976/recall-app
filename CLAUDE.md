# Recall App - Claude Code Instructions

## Environment
- **OS:** Windows 11 + PowerShell
- **Stack:** React 18 + Vite, Supabase (PostgreSQL + Auth + RLS), TailwindCSS
- **Live URL:** https://recall-app-omega.vercel.app

## Git Commits (CRITICAL - PowerShell)
PowerShell interprets hyphens at line starts as parameters. NEVER use HEREDOC or backtick syntax.
ALWAYS use PowerShell Here-String variable syntax:

```powershell
$msg = @"
feat: Description here

- Detail 1
- Detail 2
"@

git commit -m $msg
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
