-- Name: [DIAGNOSTIC] Theory answer raw line-break check
-- Description: READ-ONLY. Sprint 8.7.7 Step 0. For recent theory cards, shows whether the stored
--   back_text contains real line breaks (LF / CRLF) and shows the raw text with breaks escaped as
--   \n / \r so they are visible. Run in Supabase SQL Editor and paste the result.
--   To target the "Tasty Foods" case, uncomment the ILIKE line.

SELECT
  id,
  subtype,
  length(back_text)                                         AS answer_len,
  length(back_text) - length(replace(back_text, E'\n', '')) AS lf_count,
  length(back_text) - length(replace(back_text, E'\r', '')) AS cr_count,
  (back_text LIKE '%•%')                                    AS has_bullet_char,
  (length(back_text) - length(replace(back_text, '•', ''))) AS bullet_count,
  replace(replace(left(back_text, 600), E'\r', '\r'), E'\n', '\n') AS answer_escaped_first_600,
  left(front_text, 120)                                     AS question_start
FROM flashcards
WHERE question_type = 'theory'
  AND back_text LIKE '%•%'
  -- AND (front_text ILIKE '%Tasty Foods%' OR scenario ILIKE '%Tasty Foods%')
ORDER BY created_at DESC
LIMIT 8;
