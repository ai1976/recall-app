import { useState, useEffect } from 'react';
import { BarChart3, FileText, CreditCard } from 'lucide-react';
import { supabase } from '@/lib/supabase';
import { useNavigate } from 'react-router-dom';

export default function MyContributions() {
  const navigate = useNavigate();
  const [loading, setLoading] = useState(true);
  const [notesCount, setNotesCount] = useState(0);
  const [flashcardsCount, setFlashcardsCount] = useState(0);

  useEffect(() => {
    fetchContributions();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const fetchContributions = async () => {
    try {
      // Get current user
      const { data: { user } } = await supabase.auth.getUser();
      
      if (!user) {
        navigate('/login');
        return;
      }

      // Fetch notes count for THIS user
      const { count: notes } = await supabase
        .from('notes')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', user.id);

      // Fetch flashcards count for THIS user
      const { count: flashcards } = await supabase
        .from('flashcards')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', user.id);

      setNotesCount(notes || 0);
      setFlashcardsCount(flashcards || 0);
    } catch (error) {
      console.error('Error fetching contributions:', error);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary"></div>
      </div>
    );
  }

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      {/* Header */}
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900 flex items-center gap-2">
          <BarChart3 className="h-8 w-8 text-blue-600" />
          My Contributions
        </h1>
        <p className="mt-2 text-gray-600">
          View all the notes and flashcards you've created
        </p>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
        <div 
          className="bg-white rounded-lg shadow p-6 cursor-pointer hover:shadow-lg transition"
          onClick={() => navigate('/dashboard/my-notes')}
        >
          <div className="flex items-center gap-4">
            <FileText className="h-10 w-10 text-blue-600" />
            <div>
              <p className="text-2xl font-bold text-gray-900">{notesCount}</p>
              <p className="text-sm text-gray-600">Notes Uploaded</p>
            </div>
          </div>
        </div>

        <div 
          className="bg-white rounded-lg shadow p-6 cursor-pointer hover:shadow-lg transition"
          onClick={() => navigate('/dashboard/flashcards')}
        >
          <div className="flex items-center gap-4">
            <CreditCard className="h-10 w-10 text-purple-600" />
            <div>
              <p className="text-2xl font-bold text-gray-900">{flashcardsCount}</p>
              <p className="text-sm text-gray-600">Flashcards Created</p>
            </div>
          </div>
        </div>
      </div>

      {/* Coming Soon Message */}
      <div className="bg-blue-50 border border-blue-200 rounded-lg p-8 text-center">
        <BarChart3 className="h-16 w-16 text-blue-600 mx-auto mb-4" />
        <h2 className="text-2xl font-bold text-gray-900 mb-2">
          Detailed Contributions View - Coming Soon!
        </h2>
        <p className="text-gray-600 mb-4">
          See all your uploaded notes and created flashcards in one place.
        </p>
        <p className="text-sm text-gray-500">
          Available after Phase 1 launch
        </p>
      </div>
    </div>
  );
}