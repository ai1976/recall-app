import { describe, it, expect } from 'vitest';
import { validateCourseLabel, isSelectableCourseName, profileCourseOptions, COURSE_LABEL_MAX } from '@/lib/courseLabel';

describe('validateCourseLabel (T-002 F0, brief B 5.1)', () => {
  it('refuses empty, missing and blank-after-trim values with a message', () => {
    for (const v of ['', '   ', undefined, null]) {
      const r = validateCourseLabel(v);
      expect(r.ok).toBe(false);
      expect(r.error).toMatch(/enter your course name/);
    }
  });

  it('accepts 1 and 120 characters and refuses 121, without truncating', () => {
    expect(validateCourseLabel('x')).toEqual({ ok: true, value: 'x' });
    const at = 'y'.repeat(COURSE_LABEL_MAX);
    expect(validateCourseLabel(at)).toEqual({ ok: true, value: at });
    const over = validateCourseLabel('z'.repeat(COURSE_LABEL_MAX + 1));
    expect(over.ok).toBe(false);
    expect(over.value).toBeUndefined();
  });

  it('counts the trimmed text: 120 characters plus outer spaces is accepted and stored trimmed', () => {
    const at = 'a'.repeat(120);
    expect(validateCourseLabel(`  ${at}  `)).toEqual({ ok: true, value: at });
  });

  it('counts characters like the database (code points), not UTF-16 units', () => {
    const emoji60 = '\u{1F4DA}'.repeat(60); // 120 UTF-16 units, 60 characters
    const emoji120 = '\u{1F4DA}'.repeat(120); // 240 units, 120 characters
    const emoji121 = '\u{1F4DA}'.repeat(121);
    expect(validateCourseLabel(emoji60).ok).toBe(true);
    expect(validateCourseLabel(emoji120)).toEqual({ ok: true, value: emoji120 });
    const over = validateCourseLabel(emoji121);
    expect(over.ok).toBe(false);
    expect(over.error).toMatch(/121 characters/);
  });

  it('trims outer spaces and keeps inner spacing as typed', () => {
    expect(validateCourseLabel('  CFA   Level 1  ')).toEqual({ ok: true, value: 'CFA   Level 1' });
  });

  it('refuses a control character anywhere, including at the edges (nothing is silently removed)', () => {
    const samples = ['ab\tc', 'ab\ncd', 'ab\u0000c', 'ab\u007Fc', 'ab\u0085c', 'ab c', 'CFA\t', 'CFA\n', '\tCFA', 'CFA ', '  \t  '];
    for (const v of samples) {
      const r = validateCourseLabel(v);
      expect(r.ok).toBe(false);
      expect(r.error).toMatch(/control characters/);
    }
  });

  it('treats the word Other as an ordinary custom label (no reserved word, plan v18 section 6)', () => {
    expect(validateCourseLabel('Other')).toEqual({ ok: true, value: 'Other' });
    expect(validateCourseLabel('Other Course').ok).toBe(true);
  });

  it('accepts ordinary custom and non-Latin course names', () => {
    expect(validateCourseLabel('CFA Level 1').ok).toBe(true);
    expect(validateCourseLabel('एमबीए प्रथम वर्ष').ok).toBe(true);
  });
});

describe('isSelectableCourseName (Signup options read from existing content)', () => {
  it('keeps clean labels and drops over-long, control-character, blank, untrimmed, non-text and the dropdown word Other', () => {
    expect(isSelectableCourseName('CFA Level 1')).toBe(true);
    const bad = ['x'.repeat(121), 'a\tb', '', '   ', ' CFA ', 'Other', 'OTHER', null, undefined, 42];
    for (const v of bad) {
      expect(isSelectableCourseName(v)).toBe(false);
    }
  });
});

describe('profileCourseOptions (Profile Settings dropdown)', () => {
  const listed = ['CA Foundation', 'CA Intermediate', 'CA Final'];

  it('returns just the listed courses when the saved course is listed, empty or missing', () => {
    const plain = listed.map((value) => ({ value, label: value }));
    expect(profileCourseOptions(listed, 'CA Final')).toEqual(plain);
    expect(profileCourseOptions(listed, '')).toEqual(plain);
    expect(profileCourseOptions(listed, null)).toEqual(plain);
    expect(profileCourseOptions(listed, undefined)).toEqual(plain);
  });

  it('adds a saved custom course at the end, marked current, so the dropdown is never blank for it', () => {
    const options = profileCourseOptions(listed, 'CFA Level 1');
    expect(options).toHaveLength(4);
    expect(options[3]).toEqual({ value: 'CFA Level 1', label: 'CFA Level 1 (current)' });
    expect(profileCourseOptions(listed, 'Other')[3]).toEqual({ value: 'Other', label: 'Other (current)' });
  });

  it('does not offer a saved value that fails the label rule (over-long, control character, untrimmed, blank)', () => {
    for (const bad of ['x'.repeat(121), 'a	b', ' CFA ', '   ']) {
      expect(profileCourseOptions(listed, bad)).toHaveLength(3);
    }
  });
});
