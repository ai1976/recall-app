-- Name: [TEST] Sprint 8.7.2 — confirm atomicity probe left zero rows
--
-- Description: Verifies the direct-RPC atomicity test (multi-batch call, one good
-- batch + one deliberately malformed card in a second batch) left no trace —
-- neither the good batch's card nor any provenance row for either batch_id.
-- goodBatchId f85ba7de-40b2-4de6-9acb-5252cfc1ea65,
-- badBatchId  92218e65-cba2-4686-8497-f61242d6704c (from the probe's JS output).

SELECT count(*) AS should_be_zero_cards
FROM public.flashcards
WHERE front_text = 'atomicity-probe-8.7.2 good'
   OR batch_id IN ('f85ba7de-40b2-4de6-9acb-5252cfc1ea65', '92218e65-cba2-4686-8497-f61242d6704c');

SELECT count(*) AS should_be_zero_provenance
FROM public.flashcard_batch_provenance
WHERE batch_id IN ('f85ba7de-40b2-4de6-9acb-5252cfc1ea65', '92218e65-cba2-4686-8497-f61242d6704c');
