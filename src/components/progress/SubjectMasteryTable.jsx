import { useState, useEffect } from 'react';
import { supabase } from '@/lib/supabase';
import { BookOpen } from 'lucide-react';

export default function SubjectMasteryTable({ userId, courseLevel }) {
  const [rows, setRows]       = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError]     = useState(null);

  useEffect(() => {
    if (!userId) return;
    const load = async () => {
      setLoading(true);
      setError(null);
      const { data, error: rpcError } = await supabase.rpc('get_subject_mastery_v1', {
        p_user_id:      userId,
        p_course_level: courseLevel ?? null,
      });
      if (rpcError) {
        setError(rpcError.message);
      } else {
        setRows(data || []);
      }
      setLoading(false);
    };
    load();
  }, [userId, courseLevel]);

  if (loading) {
    return (
      <div className="bg-white rounded-lg border border-gray-200 overflow-hidden animate-pulse">
        <div className="px-4 py-3 border-b border-gray-100 bg-gray-50">
          <div className="h-4 w-40 bg-gray-200 rounded" />
        </div>
        {[1, 2, 3].map((i) => (
          <div key={i} className="px-4 py-3 border-b border-gray-50">
            <div className="h-4 bg-gray-100 rounded w-3/4 mb-2" />
            <div className="h-2 bg-gray-100 rounded w-full" />
          </div>
        ))}
      </div>
    );
  }

  if (error) {
    return (
      <div className="bg-white rounded-lg border border-gray-200 p-4 text-sm text-red-500">
        Could not load subject mastery.
      </div>
    );
  }

  if (rows.length === 0) {
    return (
      <div className="bg-white rounded-lg border border-gray-200 p-6 text-center">
        <BookOpen className="h-8 w-8 text-gray-300 mx-auto mb-2" />
        <p className="text-sm text-gray-500">No items found for this filter.</p>
      </div>
    );
  }

  return (
    <div className="bg-white rounded-lg border border-gray-200 overflow-hidden">
      <div className="px-4 py-3 border-b border-gray-100 bg-gray-50 flex items-center justify-between">
        <h3 className="text-sm font-semibold text-gray-700">Subject Mastery</h3>
        <span className="text-xs text-gray-400">{rows.length} subject{rows.length !== 1 ? 's' : ''}</span>
      </div>

      {/* Desktop table */}
      <div className="hidden sm:block overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="text-xs text-gray-500 border-b border-gray-100">
              <th className="text-left px-4 py-2 font-medium">Subject</th>
              <th className="text-right px-3 py-2 font-medium">Total</th>
              <th className="text-right px-3 py-2 font-medium">Reviewed</th>
              <th className="px-4 py-2 font-medium w-48">Mastery</th>
              <th className="text-right px-4 py-2 font-medium">Due</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-50">
            {rows.map((row) => (
              <tr key={row.subject_id ?? row.subject_name} className="hover:bg-gray-50 transition-colors">
                <td className="px-4 py-3 font-medium text-gray-900 max-w-[200px] truncate">
                  {row.subject_name}
                </td>
                <td className="px-3 py-3 text-right text-gray-600">{row.total_cards}</td>
                <td className="px-3 py-3 text-right text-gray-600">{row.reviewed_count}</td>
                <td className="px-4 py-3">
                  <div className="flex items-center gap-2">
                    <div className="flex-1 bg-gray-100 rounded-full h-2 overflow-hidden">
                      <div
                        className="h-2 rounded-full bg-blue-500 transition-all"
                        style={{ width: `${Math.min(row.mastery_pct, 100)}%` }}
                      />
                    </div>
                    <span className="text-xs text-gray-600 w-9 text-right shrink-0">
                      {row.mastery_pct}%
                    </span>
                  </div>
                </td>
                <td className="px-4 py-3 text-right">
                  {row.due_count > 0 ? (
                    <span className="inline-flex items-center justify-center min-w-[1.5rem] px-1.5 py-0.5 rounded-full text-xs font-medium bg-amber-100 text-amber-700">
                      {row.due_count}
                    </span>
                  ) : (
                    <span className="text-xs text-gray-400">—</span>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Mobile card list */}
      <div className="sm:hidden divide-y divide-gray-50">
        {rows.map((row) => (
          <div key={row.subject_id ?? row.subject_name} className="px-4 py-3">
            <div className="flex items-start justify-between gap-2 mb-1.5">
              <span className="text-sm font-medium text-gray-900 leading-tight">
                {row.subject_name}
              </span>
              <div className="flex items-center gap-1.5 shrink-0">
                {row.due_count > 0 && (
                  <span className="inline-flex items-center justify-center min-w-[1.5rem] px-1.5 py-0.5 rounded-full text-xs font-medium bg-amber-100 text-amber-700">
                    {row.due_count}
                  </span>
                )}
              </div>
            </div>
            <div className="flex items-center gap-2">
              <div className="flex-1 bg-gray-100 rounded-full h-1.5 overflow-hidden">
                <div
                  className="h-1.5 rounded-full bg-blue-500"
                  style={{ width: `${Math.min(row.mastery_pct, 100)}%` }}
                />
              </div>
              <span className="text-xs text-gray-500 shrink-0">{row.mastery_pct}%</span>
            </div>
            <p className="text-xs text-gray-400 mt-1">
              {row.reviewed_count} of {row.total_cards} reviewed
            </p>
          </div>
        ))}
      </div>
    </div>
  );
}
