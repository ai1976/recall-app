// MyReports.jsx — "Report History"
// Status tracker for content the student has personally flagged (notes/
// flashcards reported as wrong, inappropriate, etc. via content_flags).
// Moved off the Dashboard (Sprint 7.3 follow-up) into its own page, linked
// from ProfileDropdown/NavMenuSheet — unrelated to My Progress (study stats).

import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Flag, Loader2 } from 'lucide-react';
import PageContainer from '@/components/layout/PageContainer';

const STATUS_CONFIG = {
  pending:  { label: 'Under review',    className: 'bg-amber-100 text-amber-800' },
  resolved: { label: 'Resolved',        className: 'bg-green-100 text-green-800' },
  rejected: { label: 'Dismissed',       className: 'bg-gray-100 text-gray-700'  },
  removed:  { label: 'Content removed', className: 'bg-red-100 text-red-800'    },
};

const REASON_LABEL = {
  content_error: 'Content Error',
  inappropriate: 'Inappropriate',
  other:         'Other',
};

export default function MyReports() {
  const navigate = useNavigate();
  const { user } = useAuth();
  const [loading, setLoading] = useState(true);
  const [reports, setReports] = useState([]);

  useEffect(() => {
    if (!user) {
      navigate('/login');
      return;
    }
    supabase
      .from('content_flags')
      .select('id, content_type, reason, status, resolution_note, created_at')
      .eq('flagged_by', user.id)
      .order('created_at', { ascending: false })
      .limit(50)
      .then(({ data }) => {
        setReports(data || []);
        setLoading(false);
      });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user?.id]);

  if (loading) {
    return (
      <PageContainer width="narrow">
        <div className="flex items-center justify-center py-20">
          <Loader2 className="h-8 w-8 animate-spin text-gray-400" />
        </div>
      </PageContainer>
    );
  }

  return (
    <PageContainer width="narrow">
      <div className="mb-6">
        <h1 className="text-2xl sm:text-3xl font-bold">Report History</h1>
        <p className="text-rv-ink-400 mt-2">
          Content you've flagged as wrong, inappropriate, or otherwise needing review, and its current status.
        </p>
      </div>

      {reports.length === 0 ? (
        <Card>
          <CardContent className="pt-6 pb-6 text-center text-sm text-rv-ink-400">
            You haven't flagged any content yet.
          </CardContent>
        </Card>
      ) : (
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-base sm:text-lg">
              <Flag className="h-4 w-4 sm:h-5 sm:w-5 text-rv-ink-400" />
              Flagged Content
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-2">
              {reports.map((report) => {
                const cfg = STATUS_CONFIG[report.status] || STATUS_CONFIG.pending;
                return (
                  <div
                    key={report.id}
                    className="flex items-start justify-between gap-3 p-3 border rounded-lg text-sm"
                  >
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2 flex-wrap">
                        <span className="text-rv-ink-400 capitalize">{report.content_type}</span>
                        <span className="text-rv-ink-400">·</span>
                        <span className="text-rv-ink-600">{REASON_LABEL[report.reason] || report.reason}</span>
                      </div>
                      {report.resolution_note && (
                        <p className="text-xs text-rv-ink-400 mt-1 italic">{report.resolution_note}</p>
                      )}
                    </div>
                    <span className={`text-xs font-medium px-2 py-0.5 rounded-full shrink-0 ${cfg.className}`}>
                      {cfg.label}
                    </span>
                  </div>
                );
              })}
            </div>
          </CardContent>
        </Card>
      )}
    </PageContainer>
  );
}
