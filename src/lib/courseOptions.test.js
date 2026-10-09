import { describe, it, expect, vi, beforeEach } from 'vitest';
import {
  OTHER_OPTION, checkCourseRows, checkSubjectRows, buildClassification, isClassification, matchTypedCourse, defaultCourseChoice, describeCourseRow,
  lastSubjectKey, readLastSubject, rememberLastSubject, rememberedSubjectRow, fetchCourseOptions, fetchPickerSubjects,
} from '@/lib/courseOptions';
import { publicRows, pickerRows, subjectRows, customSubjectRows, courseRow } from '@/lib/courseOptions.fixtures';

const rpc = vi.fn();
vi.mock('@/lib/supabase', () => ({ supabase: { rpc: (...a) => rpc(...a) } }));

beforeEach(() => {
  rpc.mockReset();
  window.localStorage.clear();
});

describe('checkCourseRows (the contract of the course readers)', () => {
  it('accepts the public list and the picker list, sorted by position', () => {
    expect(checkCourseRows(publicRows(), 'signup').ok).toBe(true);
    expect(checkCourseRows([...pickerRows('CA Final', ['ZZ Prior'])].reverse(), 'picker').ok).toBe(true);
    expect(checkCourseRows([...publicRows()].reverse(), 'signup').rows.map((row) => row.position)).toEqual(publicRows().map((row) => row.position));
  });

  it('refuses anything that breaks the contract', () => {
    const base = publicRows();
    const bad = {
      'not an array': null,
      empty: [],
      'a row that is not an object': [...base, 'x'],
      'positions with a gap': base.map((row, i) => ({ ...row, position: i === 2 ? 99 : row.position })),
      'an unknown kind': base.map((row, i) => (i === 0 ? { ...row, kind: 'mystery' } : row)),
      'a blank label': base.map((row, i) => (i === 0 ? { ...row, label: '' } : row)),
      'a platform row without a discipline': base.map((row, i) => (i === 0 ? { ...row, discipline_id: null } : row)),
      'a catalogue row without a key': base.map((row) => (row.kind === 'catalogue' ? { ...row, custom_course_key: null } : row)),
      'no Other row': base.filter((row) => row.kind !== 'other_action'),
      'two Other rows': [...base, courseRow({ kind: 'other_action', label: 'Other again', action: 'enter_text', position: base.length + 1 })],
      'an Other row with the wrong action': base.map((row) => (row.kind === 'other_action' ? { ...row, action: 'skip' } : row)),
      'only action rows': base.filter((row) => row.kind === 'other_action').map((row) => ({ ...row, position: 1 })),
    };
    for (const [name, data] of Object.entries(bad)) expect(checkCourseRows(data, 'signup').ok, name).toBe(false);
  });

  it('requires General on the picker list and refuses it on every other list', () => {
    expect(checkCourseRows(publicRows(), 'picker').ok).toBe(false);
    expect(checkCourseRows(pickerRows('CA Final'), 'profile').ok).toBe(false);
    expect(checkCourseRows(pickerRows('CA Final').filter((row) => row.kind !== 'general').map((row, i) => ({ ...row, position: i + 1 })), 'picker').ok).toBe(false);
  });
});

describe('checkSubjectRows', () => {
  it('accepts a platform list (subjects and Skip, no typed subject) and a custom list (earlier labels, Other, Skip)', () => {
    expect(checkSubjectRows(subjectRows(['Audit', 'Tax'])).ok).toBe(true);
    expect(checkSubjectRows(subjectRows([])).ok).toBe(true);
    expect(checkSubjectRows(customSubjectRows(['Ethics']), { custom: true }).ok).toBe(true);
    expect(checkSubjectRows(customSubjectRows([]), { custom: true }).ok).toBe(true);
  });

  it('refuses a list that breaks the contract', () => {
    const platform = subjectRows(['Audit']);
    const custom = customSubjectRows(['Ethics']);
    const bad = {
      'no Skip row': [platform[0]],
      'empty list': [],
      'not an array': null,
      'a subject without an id': platform.map((row, i) => (i === 0 ? { ...row, subject_id: null } : row)),
      'a Skip row with the wrong action': platform.map((row) => (row.kind === 'skip' ? { ...row, action: 'enter_text' } : row)),
      'two Skip rows': [...platform, { ...platform[1], position: 3 }],
      'positions with a gap': platform.map((row, i) => (i === 1 ? { ...row, position: 5 } : row)),
      'an unknown kind': platform.map((row, i) => (i === 0 ? { ...row, kind: 'mystery' } : row)),
    };
    for (const [name, data] of Object.entries(bad)) expect(checkSubjectRows(data).ok, name).toBe(false);
    expect(checkSubjectRows(custom.filter((row) => row.kind !== 'other_action').map((row, i) => ({ ...row, position: i + 1 })), { custom: true }).ok, 'custom list without Other').toBe(false);
    expect(checkSubjectRows(custom.map((row) => (row.kind === 'other_action' ? { ...row, action: 'skip' } : row)), { custom: true }).ok, 'Other with the wrong action').toBe(false);
    expect(checkSubjectRows(custom.map((row, i) => (i === 0 ? { ...row, last_used_at: null } : row)), { custom: true }).ok, 'earlier label without a date').toBe(false);
    expect(checkSubjectRows(custom, { custom: false }).ok, 'typed subject offered on a platform course').toBe(false);
    expect(checkSubjectRows(platform, { custom: true }).ok, 'platform subjects on a custom list').toBe(false);
  });
});

describe('fetch wrappers', () => {
  it('uses the public reader without a session and the authenticated reader with one', async () => {
    rpc.mockResolvedValue({ data: publicRows(), error: null });
    expect((await fetchCourseOptions('signup', false)).ok).toBe(true);
    expect(rpc).toHaveBeenLastCalledWith('get_course_options_public');
    rpc.mockResolvedValue({ data: pickerRows('CA Final'), error: null });
    expect((await fetchCourseOptions('picker', true)).ok).toBe(true);
    expect(rpc).toHaveBeenLastCalledWith('get_course_options', { p_surface: 'picker' });
  });

  it('treats a rejected call as a failure (never an endless wait)', async () => {
    rpc.mockRejectedValue(new Error('network'));
    expect(await fetchCourseOptions('signup', false)).toEqual({ ok: false, reason: 'error' });
    expect(await fetchCourseOptions('picker', true)).toEqual({ ok: false, reason: 'error' });
    expect(await fetchPickerSubjects({ disciplineId: 'd1' })).toEqual({ ok: false, reason: 'error' });
    rpc.mockResolvedValue(undefined);
    expect(await fetchCourseOptions('signup', false)).toEqual({ ok: false, reason: 'error' });
  });

  it('reports a failed call and a contract failure as not ok', async () => {
    rpc.mockResolvedValue({ data: null, error: { message: 'x' } });
    expect(await fetchCourseOptions('signup', false)).toEqual({ ok: false, reason: 'error' });
    rpc.mockResolvedValue({ data: [], error: null });
    expect((await fetchCourseOptions('signup', false)).ok).toBe(false);
  });

  it('asks the subject list with exactly one argument', async () => {
    rpc.mockResolvedValue({ data: subjectRows(['Audit']), error: null });
    expect((await fetchPickerSubjects({ disciplineId: 'd1' })).ok).toBe(true);
    expect(rpc).toHaveBeenLastCalledWith('get_picker_subjects', { p_discipline_id: 'd1' });
    rpc.mockResolvedValue({ data: customSubjectRows(['Ethics']), error: null });
    expect((await fetchPickerSubjects({ courseKey: 'cfa level 1' })).ok).toBe(true);
    expect(rpc).toHaveBeenLastCalledWith('get_picker_subjects', { p_course_key: 'cfa level 1' });
    // a platform list is not a valid answer for a course key, and the other way round
    expect((await fetchPickerSubjects({ disciplineId: 'd1' })).ok).toBe(false);
    rpc.mockResolvedValue({ data: null, error: { message: 'x' } });
    expect((await fetchPickerSubjects({ disciplineId: 'd1' })).ok).toBe(false);
  });
});

describe('buildClassification (the columns of a manual log)', () => {
  const rows = pickerRows('CA Final', ['CFA Level 1']);
  const platform = rows.find((row) => row.label === 'CA Foundation');
  const prior = rows.find((row) => row.kind === 'prior_custom');
  const subjectRow = subjectRows(['Audit'])[0];

  it('stores a platform course with its discipline and an optional platform subject', () => {
    expect(buildClassification({ course: { type: 'row', row: platform }, rows }).value).toEqual({ classification: 'platform', discipline_id: platform.discipline_id });
    expect(buildClassification({ course: { type: 'row', row: platform }, subject: { type: 'row', row: subjectRow }, rows }).value)
      .toEqual({ classification: 'platform', discipline_id: platform.discipline_id, subject_id: 's-0' });
  });

  it('refuses a typed subject on a platform course', () => {
    expect(buildClassification({ course: { type: 'row', row: platform }, subject: { type: 'other', text: 'Anything' }, rows }).ok).toBe(false);
  });

  it('stores an earlier custom label as custom text, with an optional subject label', () => {
    expect(buildClassification({ course: { type: 'row', row: prior }, rows }).value).toEqual({ classification: 'custom', custom_course_label: 'CFA Level 1' });
    const priorSubject = { kind: 'prior_custom_subject', label: 'Ethics', subject_id: null };
    expect(buildClassification({ course: { type: 'row', row: prior }, subject: { type: 'row', row: priorSubject }, rows }).value)
      .toEqual({ classification: 'custom', custom_course_label: 'CFA Level 1', custom_subject_label: 'Ethics' });
    expect(buildClassification({ course: { type: 'row', row: prior }, subject: { type: 'other', text: '  Derivatives ' }, rows }).value.custom_subject_label).toBe('Derivatives');
  });

  it('stores a typed course trimmed, recognises a typed platform course, and refuses invalid text', () => {
    expect(buildClassification({ course: { type: 'other', text: '  ACCA  ' }, rows }).value).toEqual({ classification: 'custom', custom_course_label: 'ACCA' });
    expect(buildClassification({ course: { type: 'other', text: 'ca   FOUNDATION' }, rows }).value).toEqual({ classification: 'platform', discipline_id: platform.discipline_id });
    for (const text of ['', '   ', 'x'.repeat(121), 'a\tb']) expect(buildClassification({ course: { type: 'other', text }, rows }).ok).toBe(false);
    const subject = buildClassification({ course: { type: 'other', text: 'ACCA' }, subject: { type: 'other', text: 'x'.repeat(121) }, rows });
    expect(subject.ok).toBe(false);
    expect(subject.error).toMatch(/subject name/);
  });

  it('stores General with nothing else and refuses a missing course', () => {
    expect(buildClassification({ course: { type: 'general' }, subject: { type: 'row', row: subjectRow }, rows }).value).toEqual({ classification: 'general' });
    expect(buildClassification({ course: null, rows }).ok).toBe(false);
    expect(buildClassification({ course: { type: 'row', row: courseRow({ kind: 'other_action', label: 'Other' }) }, rows }).ok).toBe(false);
  });
});

describe('isClassification', () => {
  it('accepts exactly the shapes the picker builds', () => {
    expect(isClassification({ classification: 'general' })).toBe(true);
    expect(isClassification({ classification: 'platform', discipline_id: 'd1' })).toBe(true);
    expect(isClassification({ classification: 'platform', discipline_id: 'd1', subject_id: 's1' })).toBe(true);
    expect(isClassification({ classification: 'custom', custom_course_label: 'ACCA', custom_subject_label: 'Tax' })).toBe(true);
  });

  it('refuses a missing, mixed or empty shape', () => {
    for (const value of [undefined, null, {}, 'general', { classification: 'other' }, { classification: 'platform' }, { classification: 'platform', discipline_id: '' },
      { classification: 'custom' }, { classification: 'custom', custom_course_label: 'A', discipline_id: 'd1' }, { classification: 'general', custom_course_label: 'A' },
      { classification: 'platform', discipline_id: 'd1', source: 'manual' }, [{ classification: 'general' }]]) {
      expect(isClassification(value)).toBe(false);
    }
  });
});

describe('small helpers', () => {
  it('matches a typed course to a row ignoring case and spacing, never to an action row', () => {
    const rows = publicRows();
    expect(matchTypedCourse(rows, ' cma   FINAL ').label).toBe('CMA Final');
    expect(matchTypedCourse(rows, 'Other, type your own')).toBeNull();
    expect(matchTypedCourse(rows, 'Nothing like it')).toBeNull();
  });

  it('starts the picker on the current course, or on nothing', () => {
    expect(defaultCourseChoice(pickerRows('CA Final')).row.label).toBe('CA Final');
    expect(defaultCourseChoice(pickerRows(null))).toBeNull();
  });

  it('describes rows the way the dropdowns show them', () => {
    expect(describeCourseRow(courseRow({ kind: 'platform', label: 'CA Final', is_active: true }))).toBe('CA Final');
    expect(describeCourseRow(courseRow({ kind: 'platform', label: 'CA Final', is_active: false, is_current: true }))).toBe('CA Final (no longer offered)');
    expect(describeCourseRow(courseRow({ kind: 'current', label: 'CFA Level 1', custom_course_key: 'cfa level 1' }))).toBe('CFA Level 1 (current)');
    expect(OTHER_OPTION).toBe('__other__');
  });

  it('remembers the last subject per course on this device only', () => {
    const platform = pickerRows('CA Final')[0];
    const custom = pickerRows('CA Final', ['CFA Level 1']).find((row) => row.kind === 'prior_custom');
    expect(lastSubjectKey(platform)).toBe(`revisop_last_subject_d:${platform.discipline_id}`);
    expect(lastSubjectKey(custom)).toBe('revisop_last_subject_c:cfa level 1');
    const list = subjectRows(['Audit', 'Tax']);
    rememberLastSubject(platform, list[1]);
    expect(readLastSubject(platform)).toBe('s-1');
    expect(rememberedSubjectRow(list, readLastSubject(platform)).label).toBe('Tax');
    rememberLastSubject(platform, null);
    expect(readLastSubject(platform)).toBeNull();
    expect(rememberedSubjectRow(list, 'gone')).toBeNull();
    rememberLastSubject(custom, { kind: 'prior_custom_subject', label: 'Ethics' });
    expect(readLastSubject(custom)).toBe('Ethics');
  });
});
