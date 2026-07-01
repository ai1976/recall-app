-- Name: [DIAGNOSTIC] Trigger Collision Scan (public schema)
-- Description: Lists every trigger currently defined in the public schema, grouped by table,
-- to check for collisions before adding the new BEFORE UPDATE triggers on flashcard_decks
-- and notes for the is_featured_on_landing auto-clear logic (Sprint 2). Per CLAUDE.md DB rule:
-- always scan trigger_schema='public' broadly rather than filtering by event_object_table alone.
-- Read-only — safe to run anytime.

SELECT trigger_name, event_object_table, action_timing, event_manipulation
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY event_object_table;
