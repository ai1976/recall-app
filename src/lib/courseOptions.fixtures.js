// Test fixtures for the course catalogue rows (B-06a readers). Not imported by application code.

export function courseRow(overrides) {
  return {
    kind: 'platform',
    position: 1,
    label: 'CA Final',
    discipline_id: null,
    is_active: null,
    is_current: false,
    is_catalogue: false,
    is_prior_custom: false,
    custom_course_key: null,
    last_used_at: null,
    action: null,
    ...overrides,
  };
}

const PLATFORM = ['CA Final', 'CA Foundation', 'CA Intermediate'];
const CATALOGUE = ['CMA Foundation', 'CMA Intermediate', 'CMA Final', 'CS Foundation', 'CS Executive', 'CS Professional'];

/** The Signup base list as the database returns it: active platform courses, the six catalogue labels, Other. */
export function publicRows() {
  const rows = [
    ...PLATFORM.map((label, i) => courseRow({ kind: 'platform', label, discipline_id: `d-${i}`, is_active: true })),
    ...CATALOGUE.map((label) => courseRow({ kind: 'catalogue', label, is_catalogue: true, custom_course_key: label.toLowerCase() })),
    courseRow({ kind: 'other_action', label: 'Other, type your own', action: 'enter_text' }),
  ];
  return rows.map((row, i) => ({ ...row, position: i + 1 }));
}

/** A picker list for a student whose current course is `current` (a platform label) with earlier custom labels `prior`. */
export function pickerRows(current, prior = []) {
  const platform = PLATFORM.map((label, i) => courseRow({ kind: 'platform', label, discipline_id: `d-${i}`, is_active: true, is_current: label === current }));
  const currentRow = platform.filter((row) => row.is_current);
  const others = platform.filter((row) => !row.is_current);
  const priorRows = prior.map((label) => courseRow({ kind: 'prior_custom', label, is_prior_custom: true, custom_course_key: label.toLowerCase(), last_used_at: '2026-10-01T00:00:00Z' }));
  const rows = [
    ...currentRow, ...others, ...priorRows,
    courseRow({ kind: 'general', label: 'General', action: 'write_general' }),
    courseRow({ kind: 'other_action', label: 'Other...', action: 'enter_text' }),
  ];
  return rows.map((row, i) => ({ ...row, position: i + 1 }));
}

export function subjectRows(labels) {
  const rows = [
    ...labels.map((label, i) => ({ kind: 'subject', subject_id: `s-${i}`, label, position: 0, last_used_at: null, action: null })),
    { kind: 'skip', subject_id: null, label: 'Skip', position: 0, last_used_at: null, action: 'skip' },
  ];
  return rows.map((row, i) => ({ ...row, position: i + 1 }));
}

/** The subject list of a custom course (a course key): earlier subject labels, Other, Skip. */
export function customSubjectRows(labels) {
  const rows = [
    ...labels.map((label) => ({ kind: 'prior_custom_subject', subject_id: null, label, position: 0, last_used_at: '2026-10-01T00:00:00Z', action: null })),
    { kind: 'other_action', subject_id: null, label: 'Other, type your own', position: 0, last_used_at: null, action: 'enter_text' },
    { kind: 'skip', subject_id: null, label: 'Skip', position: 0, last_used_at: null, action: 'skip' },
  ];
  return rows.map((row, i) => ({ ...row, position: i + 1 }));
}
