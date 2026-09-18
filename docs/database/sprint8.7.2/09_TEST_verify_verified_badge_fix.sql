-- Name: [TEST] Sprint 8.7.2 — verify is_verified hotfix (08_HOTFIX) for professor bulk upload
SELECT id, source, is_verified, user_id, front_text
FROM public.flashcards
WHERE front_text = 'Sprint 8.7.2 verified badge retest card'
ORDER BY created_at DESC LIMIT 3;
