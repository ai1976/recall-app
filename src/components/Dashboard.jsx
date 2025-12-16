import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { Button } from '@/components/ui/button';
import { FileText, Brain, Flame, Upload, Calendar, Tag } from 'lucide-react';

export default function Dashboard() {
  const navigate = useNavigate();
  const [user, setUser] = useState(null);
  const [notes, setNotes] = useState([]);
  const [stats, setStats] = useState({
    totalNotes: 0,
    totalFlashcards: 0,
    dayStreak: 0
  });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    getUser();
  }, []);

  useEffect(() => {
    if (user) {
      fetchNotes();
    }
  }, [user]);

  const getUser = async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      setUser(user);
    } catch (error) {
      console.error('Error fetching user:', error);
    } finally {
      setLoading(false);
    }
  };

  const fetchNotes = async () => {
    try {
      // Fetch notes WITH subject and topic relationships
      const { data: notesData, error: notesError } = await supabase
        .from('notes')
        .select(`
          *,
          subject:subjects(id, name),
          topic:topics(id, name)
        `)
        .eq('user_id', user.id)
        .order('created_at', { ascending: false });

      if (notesError) throw notesError;

      // Fetch flashcards count
      const { count: flashcardsCount, error: flashcardsError } = await supabase
        .from('flashcards')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', user.id);

      if (flashcardsError) throw flashcardsError;

      // Calculate study streak
      const streak = await calculateStudyStreak();

      setNotes(notesData || []);
      setStats(prev => ({ 
        ...prev, 
        totalNotes: notesData?.length || 0,
        totalFlashcards: flashcardsCount || 0,
        dayStreak: streak
      }));
    } catch (error) {
      console.error('Error fetching data:', error);
    }
  };

  const calculateStudyStreak = async () => {
    try {
      // Get all review dates (distinct dates when user studied)
      const { data: reviews, error } = await supabase
        .from('reviews')
        .select('created_at')
        .eq('user_id', user.id)
        .order('created_at', { ascending: false });

      if (error) throw error;
      if (!reviews || reviews.length === 0) return 0;

      // Extract unique dates (YYYY-MM-DD format)
      const studyDates = [...new Set(
        reviews.map(r => new Date(r.created_at).toISOString().split('T')[0])
      )].sort().reverse(); // Most recent first

      if (studyDates.length === 0) return 0;

      // Check if studied today
      const today = new Date().toISOString().split('T')[0];
      const yesterday = new Date(Date.now() - 86400000).toISOString().split('T')[0];

      // Streak must include today or yesterday (grace period)
      if (studyDates[0] !== today && studyDates[0] !== yesterday) {
        return 0; // Streak broken
      }

      // Count consecutive days
      let streak = 0;
      let currentDate = new Date();
      
      for (let i = 0; i < studyDates.length; i++) {
        const expectedDate = new Date(currentDate);
        expectedDate.setDate(currentDate.getDate() - i);
        const expectedDateStr = expectedDate.toISOString().split('T')[0];

        if (studyDates[i] === expectedDateStr) {
          streak++;
        } else {
          break; // Streak broken
        }
      }

      return streak;
    } catch (error) {
      console.error('Error calculating streak:', error);
      return 0;
    }
  };

  const handleSignOut = async () => {
    await supabase.auth.signOut();
    navigate('/login');
  };

  const formatDate = (dateString) => {
    const date = new Date(dateString);
    return date.toLocaleDateString('en-US', { 
      month: 'short', 
      day: 'numeric',
      year: 'numeric'
    });
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Welcome Section */}
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-gray-900">
            Welcome back! 👋
          </h1>
          <p className="text-gray-600 mt-2">Ready to make your study session count?</p>
        </div>

        {/* Stats Cards */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
          <div className="bg-white p-6 rounded-lg shadow">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-gray-600">Notes Uploaded</p>
                <p className="text-3xl font-bold text-gray-900 mt-2">{stats.totalNotes}</p>
              </div>
              <FileText className="h-8 w-8 text-blue-600" />
            </div>
          </div>

          <div 
            onClick={() => navigate('/dashboard/flashcards')}
            className="bg-white p-6 rounded-lg shadow hover:shadow-md transition-shadow cursor-pointer"
          >
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-gray-600">Flashcards Created</p>
                <p className="text-3xl font-bold text-gray-900 mt-2">{stats.totalFlashcards}</p>
              </div>
              <Brain className="h-8 w-8 text-purple-600" />
            </div>
          </div>

          <div className="bg-white p-6 rounded-lg shadow">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-gray-600">Day Streak</p>
                <p className="text-3xl font-bold text-gray-900 mt-2">{stats.dayStreak}</p>
              </div>
              <Flame className="h-8 w-8 text-orange-600" />
            </div>
          </div>
        </div>

        {/* Quick Actions */}
        <div className="mb-8">
          <h2 className="text-xl font-semibold text-gray-900 mb-4">Quick Actions</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <button
              onClick={() => navigate('/dashboard/notes/new')}
              className="bg-white p-6 rounded-lg shadow hover:shadow-md transition-shadow text-left border-2 border-transparent hover:border-blue-500"
            >
              <Upload className="h-6 w-6 text-blue-600 mb-2" />
              <h3 className="font-semibold text-gray-900 mb-1">Upload Note</h3>
              <p className="text-sm text-gray-600">Add a new photo or PDF of your notes</p>
            </button>

            <button
              onClick={() => navigate('/dashboard/notes')}
              className="bg-white p-6 rounded-lg shadow hover:shadow-md transition-shadow text-left border-2 border-transparent hover:border-gray-300"
            >
              <FileText className="h-6 w-6 text-gray-600 mb-2" />
              <h3 className="font-semibold text-gray-900 mb-1">My Notes</h3>
              <p className="text-sm text-gray-600">View and manage your notes</p>
            </button>
          </div>
        </div>

        {/* Notes List or Empty State */}
        {notes.length === 0 ? (
          <div className="bg-white rounded-lg shadow p-12 text-center border-2 border-dashed border-gray-300">
            <Upload className="h-16 w-16 text-gray-400 mx-auto mb-4" />
            <h3 className="text-lg font-semibold text-gray-900 mb-2">No notes yet</h3>
            <p className="text-gray-600 mb-6">Upload your first note to get started</p>
            <Button onClick={() => navigate('/dashboard/notes/new')}>
              <Upload className="h-4 w-4 mr-2" />
              Upload Your First Note
            </Button>
          </div>
        ) : (
          <div>
            <div className="flex justify-between items-center mb-4">
              <h2 className="text-xl font-semibold text-gray-900">Recent Notes</h2>
              <Button variant="outline" onClick={() => navigate('/dashboard/notes')}>
                View All
              </Button>
            </div>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {notes.slice(0, 6).map((note) => {
                // Get display names for subject and topic
                const displaySubject = note.custom_subject || note.subject?.name || 'No subject';
                const displayTopic = note.custom_topic || note.topic?.name || '';

                return (
                  <div
                    key={note.id}
                    className="bg-white rounded-lg shadow hover:shadow-md transition-shadow cursor-pointer overflow-hidden"
                    onClick={() => navigate(`/dashboard/notes/${note.id}`)}
                  >
                    {/* Note Image Preview */}
                    {note.image_url && (
                      <div className="h-40 bg-gray-100 overflow-hidden">
                        <img 
                          src={note.image_url} 
                          alt={note.title}
                          className="w-full h-full object-cover"
                        />
                      </div>
                    )}
                    
                    {/* Note Content */}
                    <div className="p-4">
                      <h3 className="font-semibold text-gray-900 mb-2 line-clamp-1">
                        {note.title}
                      </h3>
                      
                      <div className="space-y-1 text-sm text-gray-600 mb-3">
                        <p className="line-clamp-1">
                          <span className="font-medium">Subject:</span> {displaySubject}
                        </p>
                        {displayTopic && (
                          <p className="line-clamp-1">
                            <span className="font-medium">Topic:</span> {displayTopic}
                          </p>
                        )}
                      </div>

                      {/* Tags */}
                      {note.tags && note.tags.length > 0 && (
                        <div className="flex flex-wrap gap-1 mb-3">
                          {note.tags.slice(0, 3).map((tag, index) => (
                            <span
                              key={index}
                              className="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-blue-100 text-blue-800"
                            >
                              <Tag className="w-3 h-3 mr-1" />
                              {tag}
                            </span>
                          ))}
                          {note.tags.length > 3 && (
                            <span className="text-xs text-gray-500">
                              +{note.tags.length - 3} more
                            </span>
                          )}
                        </div>
                      )}

                      {/* Footer */}
                      <div className="flex items-center justify-between text-xs text-gray-500 pt-3 border-t">
                        <div className="flex items-center">
                          <Calendar className="w-3 h-3 mr-1" />
                          {formatDate(note.created_at)}
                        </div>
                        {note.is_public && (
                          <span className="px-2 py-0.5 bg-green-100 text-green-800 rounded font-medium">
                            Public
                          </span>
                        )}
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        )}
      </main>
    </div>
  );
}