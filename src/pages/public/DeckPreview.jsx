import { useState, useEffect } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { CreditCard, BookOpen, LogIn, User } from 'lucide-react';
import GuideInfoModal from '@/components/GuideInfoModal';

export default function DeckPreview() {
  const { deckId } = useParams();
  const navigate = useNavigate();
  const { user } = useAuth();

  const [preview, setPreview] = useState(null); // { deck, preview_items }
  const [loading, setLoading] = useState(true);
  const [notFound, setNotFound] = useState(false);

  useEffect(() => {
    async function load() {
      try {
        const { data, error } = await supabase.rpc('get_public_deck_preview', { p_deck_id: deckId });
        if (error) throw error;
        if (!data || !data.deck) {
          setNotFound(true);
        } else {
          setPreview(data);
        }
      } catch (err) {
        console.error('DeckPreview load:', err);
        setNotFound(true);
      } finally {
        setLoading(false);
      }
    }
    load();
  }, [deckId]);

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600" />
      </div>
    );
  }

  if (notFound) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50 px-4">
        <div className="text-center max-w-md">
          <CreditCard className="h-16 w-16 text-gray-300 mx-auto mb-4" />
          <h1 className="text-2xl font-bold text-gray-900 mb-2">Study set not found</h1>
          <p className="text-gray-500 mb-6">
            This study set is private or doesn&apos;t exist.
          </p>
          <Link to="/">
            <Button variant="outline">Go to Recall</Button>
          </Link>
        </div>
      </div>
    );
  }

  const { deck, preview_items } = preview;

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Top bar */}
      <div className="bg-white border-b">
        <div className="max-w-2xl mx-auto px-4 py-4 flex items-center justify-between">
          <Link to="/" className="flex items-center gap-2">
            <div className="flex items-center justify-center w-7 h-7 bg-gradient-to-br from-blue-600 to-purple-600 rounded-md">
              <span className="text-white font-bold text-sm">R</span>
            </div>
            <span className="text-xl font-bold bg-gradient-to-r from-blue-600 to-purple-600 bg-clip-text text-transparent">Recall</span>
          </Link>
          {user ? (
            <Button size="sm" onClick={() => navigate('/dashboard/review-flashcards')}>
              Study on Recall
            </Button>
          ) : (
            <div className="flex gap-2">
              <Link to="/login">
                <Button size="sm" variant="outline">
                  <LogIn className="h-4 w-4 mr-1" />
                  Log in
                </Button>
              </Link>
              <Link to="/signup">
                <Button size="sm">Sign up free</Button>
              </Link>
            </div>
          )}
        </div>
      </div>

      <div className="max-w-2xl mx-auto px-4 py-8">
        {/* Deck header */}
        <div className="mb-6">
          <h1 className="text-2xl font-bold text-gray-900">{deck.name}</h1>
          <div className="flex items-center gap-4 mt-2 text-sm text-gray-500">
            {deck.subject && <span>{deck.subject}</span>}
            {deck.topic && <><span>·</span><span>{deck.topic}</span></>}
            <span>·</span>
            <span>{deck.card_count} items</span>
          </div>
          <div className="flex items-center gap-1 mt-1 text-sm text-gray-500">
            <User className="h-3.5 w-3.5" />
            <Link
              to={user ? `/dashboard/profile/${deck.creator_id}` : '/login'}
              className="hover:text-indigo-600 hover:underline"
            >
              {deck.creator_name}
            </Link>
          </div>
        </div>

        {/* Preview items */}
        <Card className="mb-4">
          <CardHeader className="pb-3">
            <CardTitle className="text-base flex items-center gap-2">
              <BookOpen className="h-4 w-4" />
              Preview ({preview_items.length} of {deck.card_count} items)
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            {preview_items.map((item, i) => (
              <div key={i} className="p-3 bg-gray-50 rounded-lg border border-gray-200">
                <p className="text-xs text-gray-400 mb-1">Q{i + 1}</p>
                <p className="text-sm text-gray-900">{item.front_text}</p>
              </div>
            ))}
          </CardContent>
        </Card>

        {/* CTA — sign up to study full deck */}
        {!user && (
          <div className="text-center py-8 px-6 bg-white rounded-xl border border-gray-200">
            <h3 className="text-lg font-semibold text-gray-900 mb-2">
              Start studying on Recall — it&apos;s free
            </h3>
            <p className="text-sm text-gray-500 mb-5">
              Create a free account to study with spaced repetition and track your progress.
            </p>
            <Link
              to="/signup"
              onClick={() => localStorage.setItem('postAuthRedirect', `/dashboard/review-flashcards?deck=${deckId}`)}
            >
              <Button className="w-full sm:w-auto px-8">
                Sign up free
              </Button>
            </Link>
            <p className="text-xs text-gray-400 mt-3">
              Already on Recall?{' '}
              <Link
                to="/login"
                className="text-indigo-600 hover:underline"
                onClick={() => localStorage.setItem('postAuthRedirect', `/dashboard/review-flashcards?deck=${deckId}`)}
              >
                Sign in
              </Link>
            </p>
            <GuideInfoModal
              situationId="studying"
              triggerLabel="New to Recall? See how Study Sets work →"
            />
          </div>
        )}

        {/* CTA for logged-in users — deep-link directly to this deck's study session */}
        {user && (
          <div className="text-center py-6">
            <Button onClick={() => navigate(`/dashboard/review-flashcards?deck=${deckId}`)}>
              Study this set on Recall
            </Button>
          </div>
        )}
      </div>
    </div>
  );
}
