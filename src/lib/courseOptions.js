// T-002 F1 - the course catalogue as the database serves it (B-06a readers), and the study-log classification built from a picker selection.
//
// Every screen that offers a course (Signup, Profile Settings, the access form, the study-log picker) renders the typed rows of ONE catalogue; none keeps
// its own list. The rows, their order and the action rows ("Other", "General", "Skip") come from the database (plan v18 section 8). A result that breaks the
// contract (not an array, empty, no "Other" row, unknown kind, positions out of order) is a contract failure: the screen shows a neutral state and offers
// no choice, rather than guessing a list.
//
// The database stays the authority for every stored value (profiles trigger B-03, access_requests trigger B-07, study_sessions guard B-04a); the checks here
// only avoid sending a request that the database would refuse.

import { supabase } from '@/lib/supabase';
import { validateCourseLabel } from '@/lib/courseLabel';

// The dropdown's own value for "type a course that is not in the list". It is never sent as a course.
export const OTHER_OPTION = '__other__';

const COURSE_KINDS = new Set(['platform', 'current', 'catalogue', 'prior_custom', 'other_action', 'general']);
const SUBJECT_KINDS = new Set(['subject', 'prior_custom_subject', 'other_action', 'skip']);
const CHOICE_KINDS = new Set(['platform', 'current', 'catalogue', 'prior_custom']);

function positionsAreInOrder(rows) {
  return rows.every((row, index) => row.position === index + 1);
}

function isObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

/**
 * Check the rows of a course reader. `surface` is 'signup' (the public list), 'profile', 'access' or 'picker'.
 * Returns { ok: true, rows } (sorted by position) or { ok: false, reason }.
 */
export function checkCourseRows(data, surface) {
  if (!Array.isArray(data) || data.length === 0) return { ok: false, reason: 'empty' };
  if (!data.every(isObject)) return { ok: false, reason: 'row' };
  const rows = [...data].sort((a, b) => a.position - b.position);
  if (!positionsAreInOrder(rows)) return { ok: false, reason: 'positions' };
  for (const row of rows) {
    if (!COURSE_KINDS.has(row.kind)) return { ok: false, reason: 'kind' };
    if (typeof row.label !== 'string' || row.label === '') return { ok: false, reason: 'label' };
    if (row.kind === 'platform' && typeof row.discipline_id !== 'string') return { ok: false, reason: 'discipline' };
    if (CHOICE_KINDS.has(row.kind) && row.kind !== 'platform' && typeof row.custom_course_key !== 'string') return { ok: false, reason: 'key' };
  }
  const others = rows.filter((row) => row.kind === 'other_action');
  if (others.length !== 1 || others[0].action !== 'enter_text') return { ok: false, reason: 'other' };
  const generals = rows.filter((row) => row.kind === 'general');
  if (surface === 'picker' ? generals.length !== 1 || generals[0].action !== 'write_general' : generals.length !== 0) return { ok: false, reason: 'general' };
  if (!rows.some((row) => row.kind !== 'other_action' && row.kind !== 'general')) return { ok: false, reason: 'no-course' };
  return { ok: true, rows };
}

/**
 * Check the rows of the subject list. `custom` is true for a course key (the student's own earlier subject labels, with a typed "Other"), false for a
 * platform course (its active subjects only: no typed subject, because a platform session cannot carry a custom subject label).
 * Every list ends with exactly one Skip row, so it is never empty. Returns { ok: true, rows } or { ok: false, reason }.
 */
export function checkSubjectRows(data, { custom = false } = {}) {
  if (!Array.isArray(data) || data.length === 0) return { ok: false, reason: 'empty' };
  if (!data.every(isObject)) return { ok: false, reason: 'row' };
  const rows = [...data].sort((a, b) => a.position - b.position);
  if (!positionsAreInOrder(rows)) return { ok: false, reason: 'positions' };
  for (const row of rows) {
    if (!SUBJECT_KINDS.has(row.kind)) return { ok: false, reason: 'kind' };
    if (typeof row.label !== 'string' || row.label === '') return { ok: false, reason: 'label' };
    if (row.kind === 'subject' && (typeof row.subject_id !== 'string' || row.action !== null)) return { ok: false, reason: 'subject' };
    if (row.kind === 'prior_custom_subject' && (row.subject_id !== null || row.action !== null || typeof row.last_used_at !== 'string')) return { ok: false, reason: 'prior' };
    if (row.kind === 'skip' && (row.subject_id !== null || row.action !== 'skip')) return { ok: false, reason: 'skip' };
    if (row.kind === 'other_action' && (row.subject_id !== null || row.action !== 'enter_text')) return { ok: false, reason: 'other' };
  }
  if (rows.filter((row) => row.kind === 'skip').length !== 1) return { ok: false, reason: 'skip' };
  const others = rows.filter((row) => row.kind === 'other_action').length;
  if (custom ? others !== 1 : others !== 0) return { ok: false, reason: 'other' };
  if (custom ? rows.some((row) => row.kind === 'subject') : rows.some((row) => row.kind === 'prior_custom_subject')) return { ok: false, reason: 'kind' };
  return { ok: true, rows };
}

/**
 * Read the course list for a screen. Without a session only the public list exists (Signup, or the access form of a visitor); with a session the
 * authenticated reader adds the student's current course and own earlier labels. Never call this before the session state is known.
 */
export async function fetchCourseOptions(surface, hasSession) {
  try {
    const result = hasSession
      ? await supabase.rpc('get_course_options', { p_surface: surface })
      : await supabase.rpc('get_course_options_public');
    if (!result || result.error) return { ok: false, reason: 'error' };
    return checkCourseRows(result.data, hasSession ? surface : 'signup');
  } catch {
    return { ok: false, reason: 'error' };
  }
}

/** Read the subject list of a chosen platform course (disciplineId) or of a custom course (courseKey, as returned in `custom_course_key`). */
export async function fetchPickerSubjects({ disciplineId = null, courseKey = null }) {
  const params = disciplineId ? { p_discipline_id: disciplineId } : { p_course_key: courseKey };
  try {
    const result = await supabase.rpc('get_picker_subjects', params);
    if (!result || result.error) return { ok: false, reason: 'error' };
    return checkSubjectRows(result.data, { custom: !disciplineId });
  } catch {
    return { ok: false, reason: 'error' };
  }
}

/** The text a dropdown shows for a row: the database's label, marked "(current)" for the student's own custom course and "(no longer offered)" for an inactive platform course. */
export function describeCourseRow(row) {
  if (row.kind === 'platform' && row.is_active === false) return `${row.label} (no longer offered)`;
  if (row.kind === 'current') return `${row.label} (current)`;
  return row.label;
}

// A hint only (never stored): the same words in other case or spacing as a row of the list. The database applies the real rule.
function looseKey(text) {
  return text.replace(/\s+/g, ' ').trim().toLowerCase();
}

/** The row of the list that a typed course name equals (ignoring case and spacing), or null. Used so a typed "ca final" is stored as the platform course. */
export function matchTypedCourse(rows, typed) {
  const key = looseKey(typed);
  return rows.find((row) => CHOICE_KINDS.has(row.kind) && looseKey(row.label) === key) || null;
}

/**
 * Build the classification columns of a manual study log from a picker selection.
 *   course:  { type: 'row', row }  a row of the list (platform, current, catalogue or prior_custom)
 *            { type: 'other', text }  a typed course
 *            { type: 'general' }
 *   subject: null (skipped) | { type: 'row', row }  a subject-list row | { type: 'other', text }  a typed subject (custom courses only)
 *   rows:    the course rows that were shown (to recognise a typed platform course)
 * Returns { ok: true, value } with the columns to insert, or { ok: false, error }. A platform course carries its discipline and, optionally, a platform
 * subject; every other course is stored as the label text, with an optional subject label; General carries nothing else.
 */
export function buildClassification({ course, subject = null, rows = [] }) {
  if (!course) return { ok: false, error: 'Please choose a course.' };
  if (course.type === 'general') return { ok: true, value: { classification: 'general' } };

  let chosen = null;
  if (course.type === 'row') {
    chosen = course.row;
  } else if (course.type === 'other') {
    const check = validateCourseLabel(course.text);
    if (!check.ok) return { ok: false, error: check.error };
    chosen = matchTypedCourse(rows, check.value) || { kind: 'typed', label: check.value };
  } else {
    return { ok: false, error: 'Please choose a course.' };
  }

  if (chosen.kind === 'platform') {
    if (typeof chosen.discipline_id !== 'string') return { ok: false, error: 'Please choose a course.' };
    const value = { classification: 'platform', discipline_id: chosen.discipline_id };
    if (subject && subject.type === 'row' && subject.row.kind === 'subject') value.subject_id = subject.row.subject_id;
    else if (subject && subject.type !== 'row') return { ok: false, error: 'Please choose a subject from the list, or skip it.' };
    return { ok: true, value };
  }

  if (!CHOICE_KINDS.has(chosen.kind) && chosen.kind !== 'typed') return { ok: false, error: 'Please choose a course.' };
  const value = { classification: 'custom', custom_course_label: chosen.label };
  if (subject && subject.type === 'row' && subject.row.kind === 'prior_custom_subject') {
    value.custom_subject_label = subject.row.label;
  } else if (subject && subject.type === 'other') {
    const check = validateCourseLabel(subject.text);
    if (!check.ok) return { ok: false, error: check.error.replace('course name', 'subject name').replace('course', 'subject') };
    value.custom_subject_label = check.value;
  } else if (subject && subject.type === 'row') {
    return { ok: false, error: 'Please choose a subject from the list, or skip it.' };
  }
  return { ok: true, value };
}

/** The picker's starting choice: the student's current course (the list marks it `is_current`), or nothing when they have none. */
export function defaultCourseChoice(rows) {
  const current = rows.find((row) => row.is_current && CHOICE_KINDS.has(row.kind));
  return current ? { type: 'row', row: current } : null;
}

const CLASSIFICATION_KEYS = {
  platform: ['classification', 'discipline_id', 'subject_id'],
  custom: ['classification', 'custom_course_label', 'custom_subject_label'],
  general: ['classification'],
};

/** True when `value` is exactly the shape buildClassification returns (the insert refuses anything else before it reaches the database). */
export function isClassification(value) {
  if (!isObject(value) || !Object.prototype.hasOwnProperty.call(CLASSIFICATION_KEYS, value.classification)) return false;
  const allowed = CLASSIFICATION_KEYS[value.classification];
  if (!Object.keys(value).every((key) => allowed.includes(key) && typeof value[key] === 'string' && value[key] !== '')) return false;
  if (value.classification === 'platform') return typeof value.discipline_id === 'string';
  if (value.classification === 'custom') return typeof value.custom_course_label === 'string';
  return true;
}

// The last subject used per course is remembered on this device only (brief B 4.5); nothing is stored in the database for it.
const LAST_SUBJECT_PREFIX = 'revisop_last_subject_';

export function lastSubjectKey(courseRow) {
  if (!courseRow) return null;
  if (courseRow.kind === 'platform') return `${LAST_SUBJECT_PREFIX}d:${courseRow.discipline_id}`;
  if (typeof courseRow.custom_course_key === 'string') return `${LAST_SUBJECT_PREFIX}c:${courseRow.custom_course_key}`;
  return null;
}

export function readLastSubject(courseRow) {
  const key = lastSubjectKey(courseRow);
  if (!key) return null;
  try {
    return window.localStorage.getItem(key);
  } catch {
    return null;
  }
}

export function rememberLastSubject(courseRow, subjectRow) {
  const key = lastSubjectKey(courseRow);
  if (!key) return;
  try {
    if (subjectRow && (subjectRow.kind === 'subject' || subjectRow.kind === 'prior_custom_subject')) {
      window.localStorage.setItem(key, subjectRow.kind === 'subject' ? subjectRow.subject_id : subjectRow.label);
    } else {
      window.localStorage.removeItem(key);
    }
  } catch {
    // Remembering is a convenience only.
  }
}

/** The subject row that matches the remembered value, if it is still offered. */
export function rememberedSubjectRow(subjectRows, remembered) {
  if (!remembered) return null;
  return subjectRows.find((row) => (row.kind === 'subject' && row.subject_id === remembered) || (row.kind === 'prior_custom_subject' && row.label === remembered)) || null;
}
