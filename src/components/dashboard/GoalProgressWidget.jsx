// GoalProgressWidget.jsx
// Shows the student's daily goal (review count or study minutes) vs today's actual.
//
// States:
//   No goal set  → two buttons: "Review goal" | "Study time goal"
//   Editing      → inline input (not a modal) — confirm or cancel
//   Goal active  → progress bar, today's actual vs target, "Edit" link
//
// Data sources (all passed as props — no new network calls here):
//   reviewGoal        → profiles.daily_review_goal
//   studyGoalMinutes  → profiles.daily_study_goal_minutes
//   todayReviews      → computed in Dashboard.fetchPersonalStats
//   todaySeconds      → studyTimeStats.today_seconds from Dashboard
//
// Goal update is written via update_daily_goal() RPC. On success, onGoalUpdated
// is called so Dashboard can update its profile state.
//
// Only one goal type is active at a time (UI enforced). Setting a new type
// passes NULL for the other, clearing it.

import { useState } from 'react';
import { supabase } from '@/lib/supabase';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Progress } from '@/components/ui/progress';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Target, CheckCircle2 } from 'lucide-react';

// ── Formatting ────────────────────────────────────────────────────────────────

function formatMinutes(totalMinutes) {
  if (!totalMinutes || totalMinutes <= 0) return '0m';
  const h = Math.floor(totalMinutes / 60);
  const m = totalMinutes % 60;
  if (h === 0) return `${m}m`;
  if (m === 0) return `${h}h`;
  return `${h}h ${m}m`;
}

// ── Component ─────────────────────────────────────────────────────────────────

export default function GoalProgressWidget({
  reviewGoal,
  studyGoalMinutes,
  todayReviews,
  todaySeconds,
  onGoalUpdated,
}) {
  // 'display' = show progress or no-goal buttons
  // 'editing' = show inline input form
  const [mode, setMode]           = useState('display');
  const [inputType, setInputType] = useState(null);  // 'review' | 'study'
  const [inputValue, setInputValue] = useState('');
  const [inputError, setInputError] = useState('');
  const [saving, setSaving]       = useState(false);

  // Derive active goal type from which column is set
  const hasGoal    = reviewGoal != null || studyGoalMinutes != null;
  const activeType = reviewGoal != null ? 'review' : 'study';
  const goalTarget = activeType === 'review' ? reviewGoal : studyGoalMinutes;

  // Today's actual in the same unit as the goal target
  const todayActual  = activeType === 'review'
    ? todayReviews
    : Math.floor((todaySeconds || 0) / 60);

  const progressPct  = goalTarget ? Math.min(100, Math.round((todayActual / goalTarget) * 100)) : 0;
  const goalReached  = hasGoal && todayActual >= goalTarget;

  // ── Handlers ──────────────────────────────────────────────────────────────

  const startEdit = (type) => {
    setInputType(type);
    // Pre-fill with current value when editing an existing goal of the same type
    if (type === 'review' && reviewGoal) setInputValue(String(reviewGoal));
    else if (type === 'study' && studyGoalMinutes) setInputValue(String(studyGoalMinutes));
    else setInputValue('');
    setInputError('');
    setMode('editing');
  };

  const handleSave = async () => {
    const raw = inputValue.trim();
    const val = parseInt(raw, 10);
    if (!raw || isNaN(val) || val <= 0 || String(val) !== raw) {
      setInputError('Enter a whole number greater than 0');
      return;
    }
    if (inputType === 'review' && val > 200) {
      setInputError('Maximum is 200 reviews per day');
      return;
    }
    if (inputType === 'study' && val > 480) {
      setInputError('Maximum is 480 minutes per day');
      return;
    }

    setSaving(true);
    try {
      const newReviewGoal = inputType === 'review' ? val : null;
      const newStudyGoal  = inputType === 'study'  ? val : null;
      const { error } = await supabase.rpc('update_daily_goal', {
        p_review_goal:        newReviewGoal,
        p_study_goal_minutes: newStudyGoal,
      });
      if (error) throw error;
      onGoalUpdated(newReviewGoal, newStudyGoal);
      setMode('display');
    } catch (err) {
      console.error('GoalProgressWidget save error:', err);
      setInputError('Failed to save. Please try again.');
    } finally {
      setSaving(false);
    }
  };

  const handleClear = async () => {
    setSaving(true);
    try {
      const { error } = await supabase.rpc('update_daily_goal', {
        p_review_goal:        null,
        p_study_goal_minutes: null,
      });
      if (error) throw error;
      onGoalUpdated(null, null);
      setMode('display');
    } catch (err) {
      console.error('GoalProgressWidget clear error:', err);
      setInputError('Failed to clear goal. Please try again.');
    } finally {
      setSaving(false);
    }
  };

  const handleCancel = () => {
    setMode('display');
    setInputValue('');
    setInputError('');
  };

  // ── Render ────────────────────────────────────────────────────────────────

  return (
    <Card>
      <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
        <CardTitle className="text-xs sm:text-sm font-medium">Daily Goal</CardTitle>
        <Target className="h-3 w-3 sm:h-4 sm:w-4 text-blue-500" />
      </CardHeader>
      <CardContent>

        {mode === 'editing' ? (
          /* ── Inline input form ── */
          <div className="space-y-2">
            <p className="text-xs text-muted-foreground">
              {inputType === 'review' ? 'Reviews per day (max 200)' : 'Minutes per day (max 480)'}
            </p>
            <div className="flex gap-2 items-center">
              <Input
                type="number"
                min="1"
                max={inputType === 'review' ? 200 : 480}
                value={inputValue}
                onChange={(e) => { setInputValue(e.target.value); setInputError(''); }}
                onKeyDown={(e) => {
                  if (e.key === 'Enter') handleSave();
                  if (e.key === 'Escape') handleCancel();
                }}
                className="h-8 text-sm w-28"
                placeholder={inputType === 'review' ? '1–200' : '1–480'}
                autoFocus
                disabled={saving}
              />
              <Button size="sm" className="h-8" onClick={handleSave} disabled={saving}>
                {saving ? 'Saving…' : 'Set'}
              </Button>
              <Button size="sm" variant="ghost" className="h-8" onClick={handleCancel} disabled={saving}>
                Cancel
              </Button>
            </div>
            {inputError && (
              <p className="text-xs text-red-500">{inputError}</p>
            )}
            {hasGoal && (
              <button
                className="text-xs text-gray-400 hover:text-red-500 transition-colors"
                onClick={handleClear}
                disabled={saving}
              >
                Clear goal
              </button>
            )}
          </div>

        ) : hasGoal ? (
          /* ── Active goal progress ── */
          <div className="space-y-2">
            <div className="flex items-center justify-between">
              <p className="text-xs text-muted-foreground">
                {activeType === 'review' ? 'Reviews today' : 'Study time today'}
              </p>
              <button
                className="text-xs text-muted-foreground hover:text-primary transition-colors"
                onClick={() => startEdit(activeType)}
              >
                Edit
              </button>
            </div>

            {goalReached ? (
              <div className="flex items-center gap-2 py-0.5">
                <CheckCircle2 className="h-4 w-4 text-green-500 shrink-0" />
                <span className="text-sm font-semibold text-green-700">Goal reached ✓</span>
              </div>
            ) : (
              <div className="text-xl sm:text-2xl font-bold">
                {activeType === 'review'
                  ? `${todayActual} / ${goalTarget}`
                  : `${formatMinutes(todayActual)} / ${formatMinutes(goalTarget)}`
                }
              </div>
            )}

            <Progress
              value={progressPct}
              className={goalReached ? '[&>div]:bg-green-500' : ''}
            />
            <p className="text-[10px] text-muted-foreground">
              {progressPct}% of daily target · resets at midnight
            </p>
          </div>

        ) : (
          /* ── No goal set ── */
          <div className="space-y-2">
            <p className="text-xs text-muted-foreground">
              Set a daily target to track your progress
            </p>
            <div className="flex gap-2">
              <Button
                size="sm"
                variant="outline"
                className="h-8 text-xs flex-1"
                onClick={() => startEdit('review')}
              >
                Review goal
              </Button>
              <Button
                size="sm"
                variant="outline"
                className="h-8 text-xs flex-1"
                onClick={() => startEdit('study')}
              >
                Study time goal
              </Button>
            </div>
          </div>
        )}

      </CardContent>
    </Card>
  );
}
