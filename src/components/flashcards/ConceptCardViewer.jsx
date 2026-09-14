import { useState, useEffect } from 'react';
import { supabase } from '@/lib/supabase';
import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { X, ChevronDown, ChevronRight, BookOpen } from 'lucide-react';

/**
 * Read-only reference viewer for a deck's concept_card rows (Sprint 7.12).
 * Browse-only — no grade buttons, no apply_review call anywhere in this
 * component. Fetches directly (not via get_study_queue, which deliberately
 * excludes concept_card, D-06) using the same 5-column join deck-membership
 * pattern as everywhere else (D-04), scoped to question_type = 'concept_card'.
 */
export default function ConceptCardViewer({ deck, onClose }) {
  const [cards, setCards] = useState([]);
  const [loading, setLoading] = useState(true);
  const [expandedId, setExpandedId] = useState(null);

  useEffect(() => {
    let cancelled = false;

    async function fetchConceptCards() {
      setLoading(true);
      try {
        const { data: { user } } = await supabase.auth.getUser();
        if (!user) return;

        let query = supabase
          .from('flashcards')
          .select('id, front_text, back_text, options')
          .eq('question_type', 'concept_card')
          .eq('user_id', deck.user_id)
          .or(`visibility.eq.public,user_id.eq.${user.id},visibility.eq.friends`);

        query = deck.subject_id ? query.eq('subject_id', deck.subject_id) : query.is('subject_id', null);
        query = deck.topic_id ? query.eq('topic_id', deck.topic_id) : query.is('topic_id', null);
        query = deck.custom_subject ? query.eq('custom_subject', deck.custom_subject) : query.is('custom_subject', null);
        query = deck.custom_topic ? query.eq('custom_topic', deck.custom_topic) : query.is('custom_topic', null);

        const { data, error } = await query.order('created_at', { ascending: true });
        if (error) throw error;
        if (!cancelled) {
          setCards(data || []);
          if ((data || []).length > 0) setExpandedId(data[0].id);
        }
      } catch (err) {
        console.error('Error fetching concept cards:', err);
      } finally {
        if (!cancelled) setLoading(false);
      }
    }

    fetchConceptCards();
    return () => { cancelled = true; };
  }, [deck]);

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
      <Card className="w-full max-w-2xl max-h-[85vh] overflow-hidden flex flex-col shadow-xl">
        <div className="flex items-center justify-between p-4 border-b border-gray-200 bg-amber-50">
          <div className="flex items-center gap-2">
            <BookOpen className="h-5 w-5 text-amber-600" />
            <div>
              <h2 className="font-semibold text-gray-900">{deck.topicName || deck.custom_topic || 'Concepts'}</h2>
              <p className="text-xs text-gray-500">Reference material — not part of your review queue</p>
            </div>
          </div>
          <Button variant="ghost" size="sm" onClick={onClose}>
            <X className="h-4 w-4" />
          </Button>
        </div>

        <CardContent className="overflow-y-auto p-4 space-y-2">
          {loading ? (
            <div className="flex items-center justify-center py-12">
              <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-[#1e1b4b]" />
            </div>
          ) : cards.length === 0 ? (
            <p className="text-sm text-gray-500 text-center py-8">No concept cards found in this deck.</p>
          ) : (
            cards.map((card) => {
              const isExpanded = expandedId === card.id;
              const keyTerms = Array.isArray(card.options) ? card.options : [];
              return (
                <div key={card.id} className="border border-gray-200 rounded-lg overflow-hidden">
                  <button
                    type="button"
                    onClick={() => setExpandedId(isExpanded ? null : card.id)}
                    className="w-full flex items-center justify-between gap-2 px-4 py-3 text-left bg-white hover:bg-amber-50 transition-colors"
                  >
                    <span className="font-medium text-gray-900">{card.front_text}</span>
                    {isExpanded ? (
                      <ChevronDown className="h-4 w-4 text-gray-400 shrink-0" />
                    ) : (
                      <ChevronRight className="h-4 w-4 text-gray-400 shrink-0" />
                    )}
                  </button>
                  {isExpanded && (
                    <div className="px-4 pb-4 pt-1 bg-gray-50 border-t border-gray-200">
                      {card.back_text && (
                        <p className="text-sm text-gray-700 whitespace-pre-wrap mb-3">{card.back_text}</p>
                      )}
                      {keyTerms.length > 0 && (
                        <div className="space-y-1.5">
                          {keyTerms.map((kt, i) => (
                            <div key={i} className="text-sm">
                              <span className="font-semibold text-amber-700">{kt.term}</span>
                              <span className="text-gray-600"> — {kt.definition}</span>
                            </div>
                          ))}
                        </div>
                      )}
                    </div>
                  )}
                </div>
              );
            })
          )}
        </CardContent>
      </Card>
    </div>
  );
}
