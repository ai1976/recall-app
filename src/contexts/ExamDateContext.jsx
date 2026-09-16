/**
 * ExamDateContext.jsx — Sprint 8.4
 *
 * Owns a student's exam_date / exam_month / has_dismissed_exam_prompt so the
 * nav chip, the Dashboard countdown card, the first-login prompt modal, and
 * Profile Settings all read one fetch and stay in sync — same
 * fetch-once-expose-mutators-that-refetch shape as CourseContext.jsx.
 */

import { createContext, useContext, useEffect, useState, useCallback } from 'react';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';

const ExamDateContext = createContext({
  examDate: null,                  // 'YYYY-MM-DD' | null
  examMonth: null,                 // 'YYYY-MM-01' | null
  hasDismissedExamPrompt: false,
  loading: true,
  saveExamDate: async () => ({ error: null }),
  dismissPrompt: async () => ({ error: null }),
  refetch: () => {},
});

// eslint-disable-next-line react-refresh/only-export-components
export const useExamDateContext = () => useContext(ExamDateContext);

export const ExamDateProvider = ({ children }) => {
  const { user } = useAuth();

  const [examDate, setExamDate] = useState(null);
  const [examMonth, setExamMonth] = useState(null);
  const [hasDismissedExamPrompt, setHasDismissedExamPrompt] = useState(false);
  const [loading, setLoading] = useState(true);

  const fetchExamDate = useCallback(async () => {
    if (!user) {
      setLoading(false);
      return;
    }
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('profiles')
        .select('exam_date, exam_month, has_dismissed_exam_prompt')
        .eq('id', user.id)
        .single();

      if (error) {
        console.error('🔴 ExamDateContext: fetch error:', error);
      } else if (data) {
        setExamDate(data.exam_date);
        setExamMonth(data.exam_month);
        setHasDismissedExamPrompt(!!data.has_dismissed_exam_prompt);
      }
    } catch (err) {
      console.error('🔴 ExamDateContext: unexpected error:', err);
    } finally {
      setLoading(false);
    }
  }, [user]);

  useEffect(() => {
    fetchExamDate();
  }, [fetchExamDate]);

  /**
   * Set or change exam_date and/or exam_month. Pass whichever the caller has —
   * the prompt modal and Profile Settings both call this with one or the
   * other depending on which toggle the student picked.
   */
  const saveExamDate = async ({ examDate: newExamDate = null, examMonth: newExamMonth = null }) => {
    if (!user) return { error: new Error('Not authenticated') };

    const { error } = await supabase
      .from('profiles')
      .update({ exam_date: newExamDate, exam_month: newExamMonth })
      .eq('id', user.id);

    if (!error) {
      setExamDate(newExamDate);
      setExamMonth(newExamMonth);
    }
    return { error };
  };

  const dismissPrompt = async () => {
    if (!user) return { error: new Error('Not authenticated') };

    setHasDismissedExamPrompt(true); // optimistic — this is a one-way, low-stakes flag
    const { error } = await supabase
      .from('profiles')
      .update({ has_dismissed_exam_prompt: true })
      .eq('id', user.id);

    if (error) console.error('🔴 ExamDateContext: dismiss error:', error);
    return { error };
  };

  return (
    <ExamDateContext.Provider
      value={{
        examDate,
        examMonth,
        hasDismissedExamPrompt,
        loading,
        saveExamDate,
        dismissPrompt,
        refetch: fetchExamDate,
      }}
    >
      {children}
    </ExamDateContext.Provider>
  );
};
