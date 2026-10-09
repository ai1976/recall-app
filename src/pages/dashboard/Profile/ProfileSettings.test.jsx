import { describe, it, expect, vi, beforeAll, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import ProfileSettings from '@/pages/dashboard/Profile/ProfileSettings';
import { publicRows } from '@/lib/courseOptions.fixtures';

vi.mock('@/contexts/AuthContext', () => ({ useAuth: () => ({ user: { id: 'u1', email: 'asha@example.com' }, loading: false }) }));
vi.mock('@/contexts/CourseContext', () => ({
  useCourseContext: () => ({
    teachingCourses: [], isContentCreator: false, addCourse: vi.fn(), removeCourse: vi.fn(), setPrimaryCourse: vi.fn(), refetchTeachingCourses: vi.fn(), loading: false,
  }),
}));
vi.mock('@/contexts/ExamDateContext', () => ({ useExamDateContext: () => ({ examDate: null, examMonth: null, loading: false, saveExamDate: vi.fn() }) }));
vi.mock('@/hooks/usePushNotifications', () => ({
  usePushNotifications: () => ({ isSupported: false, isSubscribed: false, permission: 'default', isLoading: false, needsIOSInstall: false, subscribe: vi.fn(), unsubscribe: vi.fn() }),
}));
vi.mock('@/components/profile/ChangeEmail', () => ({ default: () => null }));
let courseListOverride = null;
vi.mock('@/hooks/useCourseOptions', async (importOriginal) => {
  const real = await importOriginal();
  // The real hook always runs (hook order stays fixed); a test may replace what it returns to simulate the list failing after a choice was made.
  return { useCourseOptions: (...args) => { const live = real.useCourseOptions(...args); return courseListOverride || live; } };
});
vi.mock('@/components/layout/PageContainer', () => ({ default: ({ children }) => <div>{children}</div> }));
const toast = vi.fn();
vi.mock('@/hooks/use-toast', () => ({ useToast: () => ({ toast: (...a) => toast(...a) }) }));

const updateProfileDueFields = vi.fn();
vi.mock('@/lib/dueSet', () => ({
  updateProfileDueFields: (...a) => updateProfileDueFields(...a),
  updateDailyGoal: vi.fn(),
}));

let savedCourse = 'CA Final';
let readBackFails = false;
let rowsToServe;
const rpc = vi.fn();
vi.mock('@/lib/supabase', () => ({
  supabase: {
    rpc: (...a) => rpc(...a),
    from: () => ({
      select: (columns) => ({
        eq: () => ({
          single: () => (readBackFails && !columns.includes('full_name')
            ? Promise.resolve({ data: null, error: { message: 'down' } })
            : Promise.resolve({
            data: columns.includes('full_name')
              ? { full_name: 'Asha', course_level: savedCourse, institution: null, daily_review_goal: null, daily_study_goal_minutes: null }
              : { course_level: savedCourse },
            error: null,
          })),
        }),
      }),
    }),
  },
}));

beforeAll(() => {
  window.HTMLElement.prototype.hasPointerCapture = () => false;
  window.HTMLElement.prototype.releasePointerCapture = () => {};
  window.HTMLElement.prototype.scrollIntoView = () => {};
});

function profileRows(overrides = {}) {
  return publicRows().map((row) => ({ ...row, ...(overrides[row.label] || {}) }));
}

beforeEach(() => {
  toast.mockReset();
  updateProfileDueFields.mockReset();
  updateProfileDueFields.mockResolvedValue({ error: null });
  savedCourse = 'CA Final';
  readBackFails = false;
  courseListOverride = null;
  rowsToServe = profileRows({ 'CA Final': { is_current: true } });
  rpc.mockReset();
  rpc.mockImplementation((name) => {
    if (name === 'get_course_options') return Promise.resolve({ data: rowsToServe, error: null });
    if (name === 'preview_course_change') return Promise.resolve({ data: { moving_out: 0, returning: 0 }, error: null });
    return Promise.resolve({ data: null, error: { message: 'unexpected ' + name } });
  });
});

async function loaded() {
  render(<ProfileSettings />);
  const trigger = await screen.findByText('Primary Course');
  await waitFor(() => expect(screen.getAllByRole('combobox')[0]).not.toBeDisabled());
  return trigger;
}

function openCourseList() {
  fireEvent.keyDown(screen.getAllByRole('combobox')[0], { key: 'Enter' });
}

describe('Profile Settings course (T-002 F1)', () => {
  it('reads the profile list from the database and shows the saved course, marked when it is the student\'s own custom course', async () => {
    savedCourse = 'CFA Level 1';
    rowsToServe = [
      ...profileRows().filter((row) => row.kind !== 'other_action'),
      { ...publicRows()[0], kind: 'current', label: 'CFA Level 1', discipline_id: null, is_active: null, is_current: true, custom_course_key: 'cfa level 1' },
      publicRows().find((row) => row.kind === 'other_action'),
    ].map((row, i) => ({ ...row, position: i + 1 }));
    await loaded();
    expect(rpc).toHaveBeenCalledWith('get_course_options', { p_surface: 'profile' });
    await waitFor(() => expect(screen.getAllByRole('combobox')[0].textContent).toMatch(/CFA Level 1 \(current\)/));
  });

  it('marks an inactive current course as no longer offered', async () => {
    rowsToServe = profileRows({ 'CA Final': { is_current: true, is_active: false } });
    await loaded();
    await waitFor(() => expect(screen.getAllByRole('combobox')[0].textContent).toMatch(/CA Final \(no longer offered\)/));
  });

  it('says why when the saved course is too long to use as a name', async () => {
    savedCourse = 'z'.repeat(121);
    rowsToServe = profileRows();
    await loaded();
    await waitFor(() => expect(screen.getByRole('status').textContent).toMatch(/too long to use as a name/));
  });

  it('saves a typed course trimmed after the confirmation preview, and reads back what the database stored', async () => {
    await loaded();
    openCourseList();
    fireEvent.click(await screen.findByRole('option', { name: 'Other, type your own' }));
    const input = await screen.findByLabelText('Your course');
    fireEvent.change(input, { target: { value: '  CFA Level 1  ' } });
    savedCourse = 'CFA Level 1';
    fireEvent.click(screen.getByRole('button', { name: /Save Changes/ }));
    await waitFor(() => expect(rpc).toHaveBeenCalledWith('preview_course_change', { p_new_course: 'CFA Level 1' }));
    fireEvent.click(await screen.findByRole('button', { name: /Change course and save/ }));
    await waitFor(() => expect(updateProfileDueFields).toHaveBeenCalledTimes(1));
    expect(updateProfileDueFields.mock.calls[0][1].course_level).toBe('CFA Level 1');
  });

  it('blocks an invalid typed course with a message and saves nothing', async () => {
    await loaded();
    openCourseList();
    fireEvent.click(await screen.findByRole('option', { name: 'Other, type your own' }));
    const input = await screen.findByLabelText('Your course');
    fireEvent.change(input, { target: { value: 'x'.repeat(121) } });
    expect(screen.getAllByRole('alert')[0].textContent).toMatch(/too long/);
    fireEvent.click(screen.getByRole('button', { name: /Save Changes/ }));
    await waitFor(() => expect(toast).toHaveBeenCalled());
    expect(updateProfileDueFields).not.toHaveBeenCalled();
  });

  it('does not save a course chosen earlier when the list becomes unavailable, but the other details can still be saved', async () => {
    await loaded();
    openCourseList();
    fireEvent.click(await screen.findByRole('option', { name: 'CA Foundation' }));
    courseListOverride = { status: 'error', rows: [], reload: vi.fn() };
    fireEvent.change(screen.getByDisplayValue('Asha'), { target: { value: 'Asha K' } });
    fireEvent.click(screen.getByRole('button', { name: /Save Changes/ }));
    await waitFor(() => expect(toast).toHaveBeenCalled());
    expect(toast.mock.calls[0][0].title).toBe('Course list not available');
    expect(updateProfileDueFields).not.toHaveBeenCalled();
  });

  it('says so when the stored course cannot be re-read after a save, and keeps what was saved', async () => {
    await loaded();
    openCourseList();
    fireEvent.click(await screen.findByRole('option', { name: 'Other, type your own' }));
    fireEvent.change(await screen.findByLabelText('Your course'), { target: { value: 'CFA Level 1' } });
    readBackFails = true;
    fireEvent.click(screen.getByRole('button', { name: /Save Changes/ }));
    fireEvent.click(await screen.findByRole('button', { name: /Change course and save/ }));
    await waitFor(() => expect(updateProfileDueFields).toHaveBeenCalledTimes(1));
    await waitFor(() => expect(toast.mock.calls.map((c) => c[0].title)).toContain('Saved, but your course could not be re-read'));
    expect(toast.mock.calls.map((c) => c[0].title)).toContain('Profile updated');
  });

  it('does not block saving the other details when the course list cannot be loaded', async () => {
    rpc.mockImplementation((name) => (name === 'get_course_options'
      ? Promise.resolve({ data: null, error: { message: 'down' } })
      : Promise.resolve({ data: null, error: { message: 'unexpected' } })));
    render(<ProfileSettings />);
    await waitFor(() => expect(screen.getByText(/course list could not be loaded/i)).toBeTruthy());
    expect(screen.getAllByRole('combobox')[0]).toBeDisabled();
    fireEvent.click(screen.getByRole('button', { name: /Save Changes/ }));
    await waitFor(() => expect(updateProfileDueFields).toHaveBeenCalledTimes(1));
    expect(updateProfileDueFields.mock.calls[0][1].course_level).toBe('CA Final');
  });
});
