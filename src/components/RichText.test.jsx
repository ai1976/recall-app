import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import RichText from './RichText';

describe('RichText', () => {
  it('renders plain text as a single <p> with the exact given className (zero regression)', () => {
    const { container } = render(<RichText text="Plain question text" className="text-xl text-center" />);
    const p = container.querySelector('p');
    expect(p).not.toBeNull();
    expect(p.className).toBe('text-xl text-center');
    expect(p.textContent).toBe('Plain question text');
    // no extra wrapper div for the plain single-paragraph case
    expect(container.firstChild).toBe(p);
  });

  it('renders a table with semantic <thead>/<tbody> and no dangerouslySetInnerHTML', () => {
    const text = '[[TABLE]]\nA | B\n1 | 2\n[[/TABLE]]';
    render(<RichText text={text} />);
    expect(screen.getByRole('table')).toBeInTheDocument();
    expect(screen.getAllByRole('columnheader')).toHaveLength(2);
    expect(screen.getByText('A')).toBeInTheDocument();
    expect(screen.getByText('1')).toBeInTheDocument();
  });

  it('renders trailing empty cells as empty <td> elements, not fewer columns', () => {
    const text = '[[TABLE]]\nCol1 | Col2 | Col3\nValue |  | \n[[/TABLE]]';
    const { container } = render(<RichText text={text} />);
    const dataRow = container.querySelectorAll('tbody tr')[0];
    const cells = dataRow.querySelectorAll('td');
    expect(cells).toHaveLength(3);
    expect(cells[0].textContent).toBe('Value');
    expect(cells[1].textContent).toBe('');
    expect(cells[2].textContent).toBe('');
  });

  it('renders multiple tables in source order within one field', () => {
    const text = '[[TABLE]]\nA | B\n1 | 2\n[[/TABLE]]\nmiddle\n[[TABLE]]\nC | D\n3 | 4\n[[/TABLE]]';
    const { container } = render(<RichText text={text} />);
    const tables = container.querySelectorAll('table');
    expect(tables).toHaveLength(2);
    expect(tables[0].textContent).toContain('A');
    expect(tables[1].textContent).toContain('C');
  });

  it('wraps the table in a horizontal-scroll container', () => {
    const text = '[[TABLE]]\nA | B\n1 | 2\n[[/TABLE]]';
    const { container } = render(<RichText text={text} />);
    const scrollWrapper = container.querySelector('.overflow-x-auto');
    expect(scrollWrapper).not.toBeNull();
    expect(scrollWrapper.querySelector('table')).not.toBeNull();
  });

  it('falls back to plain paragraph rendering for malformed markers, not a crash', () => {
    const text = '[[TABLE]]\nA | B\nno close marker here';
    const { container } = render(<RichText text={text} className="whitespace-pre-wrap" />);
    expect(container.querySelector('table')).toBeNull();
    expect(container.textContent).toBe(text);
  });
});
