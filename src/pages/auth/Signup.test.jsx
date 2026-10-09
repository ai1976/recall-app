import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import Signup from '@/pages/auth/Signup';
import { publicRows } from '@/lib/courseOptions.fixtures';

const signUp = vi.fn();
vi.mock('@/contexts/AuthContext', () => ({ useAuth: () => ({ signUp: (...a) => signUp(...a), user: null, loading: false }) }));

const rpc = vi.fn();
vi.mock('@/lib/supabase', () => ({ supabase: { rpc: (...a) => rpc(...a) } }));

beforeEach(() => {
  signUp.mockReset();
  signUp.mockResolvedValue({ user: { identities: [{ id: 1 }] } });
  rpc.mockReset();
  rpc.mockResolvedValue({ data: publicRows(), error: null });
  vi.spyOn(window, 'alert').mockImplementation(() => {});
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
  await waitFor(() => expect(select).not.toBeDisabled());
  fireEvent.change(select, { target: { value: '__other__' } });
  return screen.findByLabelText(/specify your course/i);
}

describe('Signup course list (T-002 F1)', () => {
  it('reads the public catalogue and nothing else: no table read, the database order, one custom-course entry', async () => {
    renderSignup();
    const select = await screen.findByLabelText(/which course/i);
    await waitFor(() => expect(select).not.toBeDisabled());
    expect(rpc).toHaveBeenCalledTimes(1);
    expect(rpc).toHaveBeenCalledWith('get_course_options_public');
    const values = Array.from(select.options).map((o) => o.value);
    expect(values).toEqual([
      '', 'CA Final', 'CA Foundation', 'CA Intermediate',
      'CMA Foundation', 'CMA Intermediate', 'CMA Final', 'CS Foundation', 'CS Executive', 'CS Professional', '__other__',
    ]);
  });

  it('shows the courses in the order the database serves them, even when that mixes the old CA, CMA and CS groups', async () => {
    const rows = publicRows();
    const mixed = [rows[3], rows[0], rows[6], rows[1], rows[4], rows[2], rows[5], rows[7], rows[8], rows[9]].map((row, i) => ({ ...row, position: i + 1 }));
    rpc.mockResolvedValue({ data: mixed, error: null });
    renderSignup();
    const select = await screen.findByLabelText(/which course/i);
    await waitFor(() => expect(select).not.toBeDisabled());
    expect(Array.from(select.options).map((o) => o.value)).toEqual([
      '', 'CMA Foundation', 'CA Final', 'CS Foundation', 'CA Foundation', 'CMA Intermediate', 'CA Intermediate', 'CMA Final', 'CS Executive', 'CS Professional', '__other__',
    ]);
    expect(select.querySelectorAll('optgroup')).toHaveLength(0);
  });

  it('shows a neutral state and sends nothing when the list cannot be loaded or breaks the contract', async () => {
    rpc.mockResolvedValue({ data: null, error: { message: 'down' } });
    renderSignup();
    fillBasics();
    const select = await screen.findByLabelText(/which course/i);
    await waitFor(() => expect(screen.getByRole('alert').textContent).toMatch(/could not be loaded/i));
    expect(select).toBeDisabled();
    fireEvent.submit(select.closest('form'));
    expect(signUp).not.toHaveBeenCalled();

    rpc.mockResolvedValue({ data: publicRows().filter((row) => row.kind !== 'other_action'), error: null });
    fireEvent.click(screen.getByRole('button', { name: /try again/i }));
    await waitFor(() => expect(rpc).toHaveBeenCalledTimes(2));
    await waitFor(() => expect(screen.getByRole('alert').textContent).toMatch(/could not be loaded/i));
    expect(select).toBeDisabled();
  });
});

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

  it('accepts the word Other as a typed course (the dropdown value is never sent)', async () => {
    renderSignup();
    fillBasics();
    const input = await chooseCustom();
    fireEvent.change(input, { target: { value: 'Other' } });
    fireEvent.submit(input.closest('form'));
    await waitFor(() => expect(signUp).toHaveBeenCalledTimes(1));
    expect(signUp.mock.calls[0][3]).toBe('Other');
  });
});
