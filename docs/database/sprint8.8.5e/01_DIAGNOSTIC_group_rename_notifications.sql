-- Name: [DIAGNOSTIC] Group rename - notification name copies (block H, corrected)
-- Description: notifications keep the group name in the title/message text and in
-- metadata->>'group_name'. Counts how many stored copies a rename would leave stale. READ-ONLY.
SELECT n.type,
       count(*) AS total,
       count(*) FILTER (WHERE n.metadata ? 'group_name') AS with_group_name_in_metadata,
       count(*) FILTER (WHERE n.metadata ? 'group_id')   AS with_group_id
FROM public.notifications n
WHERE n.metadata ? 'group_name' OR n.metadata ? 'group_id'
GROUP BY n.type ORDER BY total DESC;
