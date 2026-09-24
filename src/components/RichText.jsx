import PropTypes from 'prop-types';
import { parseRichText } from '@/lib/parseRichText';
import { cn } from '@/lib/utils';

/**
 * Sprint 8.7.9 (D-31) — shared pure presentational renderer for the locked
 * [[TABLE]] rich-content contract. Used by StudyMode and PracticeMode for
 * front_text / back_text / scenario. No fetching, grading, or session state.
 *
 * Plain text (the overwhelming majority of existing cards) renders as the
 * exact same single <p className={className}> element it did before this
 * component existed — no new wrapper, margin, or alignment change.
 */
export default function RichText({ text, className }) {
  const blocks = parseRichText(text);

  if (blocks.length === 1 && blocks[0].type === 'paragraph') {
    return <p className={className}>{blocks[0].text}</p>;
  }

  return (
    <div>
      {blocks.map((block, i) =>
        block.type === 'table' ? (
          <TableBlock key={i} headers={block.headers} rows={block.rows} />
        ) : (
          <p key={i} className={cn(className, 'mb-3 last:mb-0')}>
            {block.text}
          </p>
        ),
      )}
    </div>
  );
}

RichText.propTypes = {
  text: PropTypes.string,
  className: PropTypes.string,
};

function TableBlock({ headers, rows }) {
  return (
    <div className="mb-3 last:mb-0 w-full overflow-x-auto rounded-rec border border-rv-border">
      <table className="w-full border-collapse text-sm">
        <thead>
          <tr>
            {headers.map((header, hi) => (
              <th
                key={hi}
                scope="col"
                className="border-b border-rv-border bg-rv-bg-2 px-3 py-2 text-left font-semibold text-rv-ink-900 whitespace-pre-wrap align-top"
              >
                {header}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((row, ri) => (
            <tr key={ri} className="border-b border-rv-border last:border-b-0">
              {row.map((cell, ci) => (
                <td key={ci} className="px-3 py-2 align-top whitespace-pre-wrap text-rv-ink-900">
                  {cell}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

TableBlock.propTypes = {
  headers: PropTypes.arrayOf(PropTypes.string).isRequired,
  rows: PropTypes.arrayOf(PropTypes.arrayOf(PropTypes.string)).isRequired,
};
