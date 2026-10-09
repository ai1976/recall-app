// T-002 F0 - the one rule for a typed course label (brief B v10, 5.1 and 5.2): trimmed, 1 to 120 characters, no control characters, never truncated.
// Used by Signup, Profile Settings and the access-request form. The database applies the same rule (profiles trigger B-03, access_requests trigger B-07,
// study_sessions label guard B-04a); this check only shows the error before the request is sent.

export const COURSE_LABEL_MAX = 120;

// C0 controls (tab and line breaks included), DEL, C1 controls, and the Unicode line and paragraph separators.
function hasControlCharacter(text) {
  for (let i = 0; i < text.length; i += 1) {
    const code = text.charCodeAt(i);
    if (code <= 0x1f || (code >= 0x7f && code <= 0x9f) || code === 0x2028 || code === 0x2029) return true;
  }
  return false;
}

// PostgreSQL char_length counts characters (code points), not UTF-16 code units: an emoji is one character.
function characterCount(text) {
  return Array.from(text).length;
}

/**
 * Check a typed course label. Returns { ok: true, value } with the text to send, or { ok: false, error } with a message for the student.
 * A control character anywhere, including at the edges, is refused (the database refuses it too); only ordinary outer spaces are removed,
 * and the text is never shortened (an over-long label is refused, not cut). A typed course named "Other" is an ordinary label (no reserved word).
 */
export function validateCourseLabel(raw) {
  const text = typeof raw === 'string' ? raw : '';
  if (hasControlCharacter(text)) {
    return { ok: false, error: 'Your course name cannot contain line breaks, tabs or other control characters.' };
  }
  const value = text.trim();
  if (value === '') {
    return { ok: false, error: 'Please enter your course name.' };
  }
  const length = characterCount(value);
  if (length > COURSE_LABEL_MAX) {
    return { ok: false, error: `Your course name is too long (${length} characters). Please use ${COURSE_LABEL_MAX} characters or fewer.` };
  }
  return { ok: true, value };
}
