// T-002 F1 - the subject list of the course chosen in the study-log picker (B-06a get_picker_subjects).
//
// A platform course lists its active subjects; a custom course lists the student's own earlier subject labels for that course key. A course typed for the
// first time, or General, has no list (the picker offers a typed subject, or none). `status` is 'idle' (no list applies), 'loading', 'ready' or 'error'.

import { useCallback, useEffect, useState } from 'react';
import { fetchPickerSubjects } from '@/lib/courseOptions';

function subjectRequest(courseRow) {
  if (!courseRow) return null;
  if (courseRow.kind === 'platform') return { key: `d:${courseRow.discipline_id}`, params: { disciplineId: courseRow.discipline_id } };
  if (typeof courseRow.custom_course_key === 'string') return { key: `c:${courseRow.custom_course_key}`, params: { courseKey: courseRow.custom_course_key } };
  return null;
}

export function usePickerSubjects(courseRow, { enabled = true } = {}) {
  const request = enabled ? subjectRequest(courseRow) : null;
  const [reloadKey, setReloadKey] = useState(0);
  const [result, setResult] = useState(null);
  const requestKey = request ? `${request.key}|${reloadKey}` : null;
  const disciplineId = request ? request.params.disciplineId || null : null;
  const courseKey = request ? request.params.courseKey || null : null;

  useEffect(() => {
    if (requestKey === null) return undefined;
    let cancelled = false;
    fetchPickerSubjects({ disciplineId, courseKey }).then((fetched) => {
      if (!cancelled) setResult({ key: requestKey, ok: fetched.ok, rows: fetched.ok ? fetched.rows : [] });
    });
    return () => {
      cancelled = true;
    };
  }, [requestKey, disciplineId, courseKey]);

  const reload = useCallback(() => setReloadKey((key) => key + 1), []);

  if (requestKey === null) return { status: 'idle', rows: [], reload };
  if (result && result.key === requestKey) return { status: result.ok ? 'ready' : 'error', rows: result.rows, reload };
  return { status: 'loading', rows: [], reload };
}
