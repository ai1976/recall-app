-- Name: [TEST] Verify insert without is_public
-- Description: Post-drop sanity check for 12_SCHEMA. Confirms is_public is actually gone
-- from the schema, and that a note + flashcard insert shaped exactly like the post-migration
-- frontend payload (visibility only, no is_public key) still succeeds. Run immediately after
-- 12_SCHEMA, then separately re-run 11_TEST in full (see the note at the top of that file).
-- Row-returning verdict pattern, matches 06_TEST. Write block uses BEGIN/ROLLBACK.

-- ============================================
-- 1. is_public is gone from both tables — Expected: PASS
-- ============================================
DO $$
DECLARE v_count int;
BEGIN
  SELECT count(*) INTO v_count FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name IN ('notes', 'flashcards')
    AND column_name = 'is_public';
  CREATE TEMP TABLE IF NOT EXISTS _r(verdict text);
  IF v_count = 0 THEN
    INSERT INTO _r VALUES ('PASS: is_public is gone from both notes and flashcards');
  ELSE
    INSERT INTO _r VALUES ('FAIL: is_public still exists on ' || v_count || ' table(s)');
  END IF;
END $$;
SELECT * FROM _r;
DROP TABLE IF EXISTS _r;

-- ============================================
-- 2. A note insert shaped like the post-migration NoteUpload.jsx/NoteEdit.jsx payload
--    (visibility only) still succeeds — Expected: PASS
-- ============================================
BEGIN;
CREATE TEMP TABLE _r(verdict text);
DO $$
DECLARE v_user_id uuid; v_id uuid; v_content_type text;
BEGIN
  SELECT id INTO v_user_id FROM public.profiles LIMIT 1;
  IF v_user_id IS NULL THEN
    INSERT INTO _r VALUES ('SKIP: no profile fixture available'); RETURN;
  END IF;
  -- Self-source a CHECK-valid content_type from an existing note (notes_content_type_check
  -- rejects arbitrary literals like 'Text'); this test targets is_public, not content_type.
  SELECT content_type INTO v_content_type FROM public.notes WHERE content_type IS NOT NULL LIMIT 1;
  BEGIN
    INSERT INTO public.notes (user_id, title, content_type, target_course, visibility)
    VALUES (v_user_id, '_L2TEST_post_drop_note', v_content_type, 'test_course', 'public')
    RETURNING id INTO v_id;
    INSERT INTO _r VALUES ('PASS: note insert succeeded without is_public, id=' || v_id);
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('FAIL: note insert errored — ' || SQLERRM);
  END;
END $$;
SELECT * FROM _r;
ROLLBACK;

-- ============================================
-- 3. A flashcard insert shaped like the post-migration FlashcardCreate.jsx/
--    BulkUploadFlashcards.jsx/ProfessorTools.jsx payload (visibility only) still
--    succeeds — Expected: PASS
-- ============================================
BEGIN;
CREATE TEMP TABLE _r(verdict text);
DO $$
DECLARE v_user_id uuid; v_id uuid;
BEGIN
  SELECT id INTO v_user_id FROM public.profiles LIMIT 1;
  IF v_user_id IS NULL THEN
    INSERT INTO _r VALUES ('SKIP: no profile fixture available'); RETURN;
  END IF;
  BEGIN
    INSERT INTO public.flashcards (user_id, target_course, front_text, back_text, visibility)
    VALUES (v_user_id, 'test_course', '_L2TEST_post_drop_card', 'x', 'public')
    RETURNING id INTO v_id;
    INSERT INTO _r VALUES ('PASS: flashcard insert succeeded without is_public, id=' || v_id);
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('FAIL: flashcard insert errored — ' || SQLERRM);
  END;
END $$;
SELECT * FROM _r;
ROLLBACK;
