import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import Signup from '@/pages/auth/Signup';

const signUp = vi.fn();
vi.mock('@/contexts/AuthContext', () => ({ useAuth: () => ({ signUp: (...a) => signUp(...a) }) }));

let courseRows = [];
vi.mock('@/lib/supabase', () => ({
  supabase: {
    from: () => ({
      select: () => ({ not: () => Promise.resolve({ data: courseRows, error: null }) }),
    }),
  },
}));

beforeEach(() => {
  signUp.mockReset();
  signUp.mockResolvedValue({ user: { identities: [{ id: 1 }] } });
  vi.spyOn(window, 'alert').mockImplementation(() => {});
  courseRows = [];
});

function renderSignup() {
  return render(<MemoryRouter><Signup /></MemoryRouter>);
}

function fillBasics() {
  fireEvent.change(screen.getByLabelText(/full name/i), { target: { value: 'Asha' } });
  fireEvent.change(screen.getByLabelText(/email/i), { target: { value: 'asha@example.com' } });
  fireEvent.change(screen.getByLabelText(/password/i), { target: { value: 'secret123' } });
}

async function chooseCustom() {
  const select = await screen.findByLabelText(/which course/i);
  fireEvent.change(select, { target: { value: 'Other' } });
  return screen.findByLabelText(/specify your course/i);
}

describe('Signup custom course (T-002 F0)', () => {
  it('sends the trimmed custom course to signUp', async () => {
    renderSignup();
    fillBasics();
    const input = await chooseCustom();
    fireEvent.change(input, { target: { value: '  CFA Level 1  ' } });
    expect(screen.queryByRole('alert')).toBeNull();
    fireEvent.submit(input.closest('form'));
    await waitFor(() => expect(signUp).toHaveBeenCalledTimes(1));
    expect(signUp).toHaveBeenCalledWith('asha@example.com', 'secret123', 'Asha', 'CFA Level 1');
  });

  it('shows a visible message and sends nothing for whitespace-only, 121-character and control-character courses', async () => {
    renderSignup();
    fillBasics();
    const input = await chooseCustom();
    const cases = [
      ['   ', /enter your course name/],
      ['x'.repeat(121), /too long/],
      ['ab\tc', /control characters/],
      ['CFA\t', /control characters/],
    ];
    for (const [value, message] of cases) {
      fireEvent.change(input, { target: { value } });
      expect(screen.getAllByRole('alert')[0].textContent).toMatch(message);
      fireEvent.submit(input.closest('form'));
      await waitFor(() => expect(screen.getAllByText(message).length).toBeGreaterThan(1));
    }
    expect(signUp).not.toHaveBeenCalled();
  });

  it('accepts exactly 120 characters', async () => {
    renderSignup();
    fillBasics();
    const input = await chooseCustom();
    fireEvent.change(input, { target: { value: 'y'.repeat(120) } });
    fireEvent.submit(input.closest('form'));
    await waitFor(() => expect(signUp).toHaveBeenCalledTimes(1));
    expect(signUp.mock.calls[0][3]).toBe('y'.repeat(120));
  });

  it('does not offer existing course names that fail the rule, or the word Other, as dropdown options', async () => {
    courseRows = [
      { target_course: 'CFA Level 1' },
      { target_course: 'x'.repeat(121) },
      { target_course: 'bad\tname' },
      { target_course: 'Other' },
      { target_course: ' padded ' },
    ];
    renderSignup();
    const select = await screen.findByLabelText(/which course/i);
    await waitFor(() => expect(Array.from(select.options).map((o) => o.value)).toContain('CFA Level 1'));
    const values = Array.from(select.options).map((o) => o.value);
    expect(values).not.toContain('x'.repeat(121));
    expect(values).not.toContain('bad\tname');
    expect(values).not.toContain(' padded ');
    expect(values.filter((v) => v === 'Other')).toHaveLength(1);
  });
});
