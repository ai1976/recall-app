import { useState, useEffect } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { Button } from '@/components/ui/button';
import { FileText, LogIn, User } from 'lucide-react';

export default function NotePreview() {
  const { noteId } = useParams();
  const navigate = useNavigate();

  const [note, setNote] = useState(null);
  const [loading, setLoading] = useState(true);
  const [notFound, setNotFound] = useState(false);
  const [user, setUser] = useState(null);

  useEffect(() => {
    async function load() {
      // Check auth state
      const { data: { user: currentUser } } = await supabase.auth.getUser();
      setUser(currentUser);

      // Fetch note preview (works for anonymous users via SECURITY DEFINER)
      try {
        const { data, error } = await supabase.rpc('get_public_note_preview', { p_note_id: noteId });
        if (error) throw error;
        const row = Array.isArray(data) ? data[0] : null;
        if (!row) {
          setNotFound(true);
        } else {
          setNote(row);
        }
      } catch (err) {
        console.error('NotePreview load:', err);
        setNotFound(true);
      } finally {
        setLoading(false);
      }
    }
    load();
  }, [noteId]);

  const setRedirectAndNavigate = (path) => {
    localStorage.setItem('postAuthRedirect', `/dashboard/notes/${noteId}`);
    navigate(path);
  };

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
          <FileText className="h-16 w-16 text-gray-300 mx-auto mb-4" />
          <h1 className="text-2xl font-bold text-gray-900 mb-2">Note not available</h1>
          <p className="text-gray-500 mb-6">
            This note is private or no longer available.
          </p>
          <Link to="/signup">
            <Button variant="outline">Browse public study materials</Button>
          </Link>
        </div>
      </div>
    );
  }

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
            <Button size="sm" onClick={() => navigate(`/dashboard/notes/${noteId}`)}>
              Open on Recall
            </Button>
          ) : (
            <div className="flex gap-2">
              <Button
                size="sm"
                variant="outline"
                onClick={() => setRedirectAndNavigate('/login')}
              >
                <LogIn className="h-4 w-4 mr-1" />
                Log in
              </Button>
              <Button size="sm" onClick={() => setRedirectAndNavigate('/signup')}>
                Sign up free
              </Button>
            </div>
          )}
        </div>
      </div>

      <div className="max-w-2xl mx-auto px-4 py-8">
        {/* Note header */}
        <div className="mb-6">
          {/* Subject / topic breadcrumb */}
          {(note.subject_name || note.topic_name) && (
            <div className="flex items-center gap-2 mb-3 flex-wrap">
              {note.subject_name && (
                <span className="px-2.5 py-1 bg-blue-100 text-blue-700 text-xs font-medium rounded-full">
                  {note.subject_name}
                </span>
              )}
              {note.topic_name && (
                <span className="px-2.5 py-1 bg-purple-100 text-purple-700 text-xs font-medium rounded-full">
                  {note.topic_name}
                </span>
              )}
            </div>
          )}

          <h1 className="text-2xl font-bold text-gray-900">{note.title}</h1>

          {note.author_name && (
            <div className="flex items-center gap-1 mt-2 text-sm text-gray-500">
              <User className="h-3.5 w-3.5" />
              <span>{note.author_name}</span>
            </div>
          )}

          {note.description && (
            <p className="mt-3 text-sm text-gray-600 bg-white border border-gray-200 rounded-lg p-3">
              {note.description}
            </p>
          )}
        </div>

        {/* Blurred content preview */}
        <div className="relative rounded-xl overflow-hidden border border-gray-200 mb-6">
          <div className="p-6 bg-white space-y-3 select-none" style={{ filter: 'blur(4px)', userSelect: 'none' }}>
            <div className="h-4 bg-gray-200 rounded w-3/4" />
            <div className="h-4 bg-gray-200 rounded w-full" />
            <div className="h-4 bg-gray-200 rounded w-5/6" />
            <div className="h-4 bg-gray-200 rounded w-2/3" />
            <div className="h-4 bg-gray-200 rounded w-full" />
            <div className="h-4 bg-gray-200 rounded w-4/5" />
            <div className="h-4 bg-gray-200 rounded w-3/4" />
            <div className="h-4 bg-gray-200 rounded w-full" />
          </div>
          <div className="absolute inset-0 flex items-center justify-center bg-white/60">
            <div className="text-center px-4">
              <FileText className="h-10 w-10 text-blue-600 mx-auto mb-2" />
              <p className="text-sm font-semibold text-gray-800">Sign up free to read the full note</p>
            </div>
          </div>
        </div>

        {/* CTA */}
        {!user && (
          <div className="text-center py-8 px-6 bg-white rounded-xl border border-gray-200">
            <h3 className="text-lg font-semibold text-gray-900 mb-2">
              Start studying on Recall — it&apos;s free
            </h3>
            <p className="text-sm text-gray-500 mb-5">
              Create a free account to read this note, make flashcards, and track your progress with spaced repetition.
            </p>
            <Button
              className="w-full sm:w-auto px-8"
              onClick={() => setRedirectAndNavigate('/signup')}
            >
              Sign up free
            </Button>
            <p className="text-xs text-gray-400 mt-3">
              Already on Recall?{' '}
              <button
                className="text-indigo-600 hover:underline"
                onClick={() => setRedirectAndNavigate('/login')}
              >
                Sign in
              </button>
            </p>
          </div>
        )}

        {user && (
          <div className="text-center py-6">
            <Button onClick={() => navigate(`/dashboard/notes/${noteId}`)}>
              Open this note on Recall
            </Button>
          </div>
        )}
      </div>
    </div>
  );
}
