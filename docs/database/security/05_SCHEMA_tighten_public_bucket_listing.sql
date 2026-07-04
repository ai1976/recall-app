-- Name: [SCHEMA] L5 — remove broad list policies on public buckets
-- Description: Advisor "Public Bucket Allows Listing": flashcard-images (policy
-- public_read_flashcard_images) and note-files (policy "Users can view all note files") each have a
-- broad SELECT policy on storage.objects that lets any client LIST every file in the bucket. Public
-- buckets serve individual objects via their public URL WITHOUT this policy, so dropping it stops
-- filename enumeration without breaking image/file display (the app renders via stored public URLs,
-- not by listing). Block 1 confirms the policies before Block 2 drops them.
--
-- ⚠️ Prereq check: confirm no app code calls supabase.storage.from('<bucket>').list(...). Grep of
-- src/ shows image/file access via getPublicUrl/stored image_url, not .list() — safe. If a .list()
-- exists, it will start returning empty for anon after this; re-scope with a narrower policy instead.

-- ============================================
-- 1. Show the current SELECT policies on storage.objects for these buckets (confirm names/scope).
-- ============================================
SELECT policyname, cmd, roles, qual
FROM pg_policies
WHERE schemaname = 'storage' AND tablename = 'objects'
  AND (qual ILIKE '%flashcard-images%' OR qual ILIKE '%note-files%'
       OR policyname IN ('public_read_flashcard_images', 'Users can view all note files'))
ORDER BY policyname;

-- ============================================
-- 2. Drop the two broad list policies. Object URL access is unaffected (public buckets).
-- ============================================
DROP POLICY IF EXISTS "public_read_flashcard_images" ON storage.objects;
DROP POLICY IF EXISTS "Users can view all note files" ON storage.objects;

-- Post-deploy: confirm images/notes still render on the live site (they load via public URL), and
-- re-run the advisor — the two "Public Bucket Allows Listing" findings should clear.
