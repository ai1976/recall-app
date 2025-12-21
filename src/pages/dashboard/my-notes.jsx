import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { FileText, Search, Lock, Globe } from 'lucide-react';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';

export default function MyNotes() {
  const navigate = useNavigate();
  const [notes, setNotes] = useState([]);
  const [filteredNotes, setFilteredNotes] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');

  useEffect(() => {
    fetchMyNotes();
  }, []);

  useEffect(() => {
    // Filter notes based on search query
    if (searchQuery.trim() === '') {
      setFilteredNotes(notes);
    } else {
      const query = searchQuery.toLowerCase();
      const filtered = notes.filter(note => 
        note.title?.toLowerCase().includes(query) ||
        note.description?.toLowerCase().includes(query) ||
        note.subject?.toLowerCase().includes(query) ||
        note.topic?.toLowerCase().includes(query) ||
        note.tags?.some(tag => tag.toLowerCase().includes(query))
      );
      setFilteredNotes(filtered);
    }
  }, [searchQuery, notes]);

  const fetchMyNotes = async () => {
    try {
      // Get current user
      const { data: { user } } = await supabase.auth.getUser();
      
      if (!user) {
        navigate('/login');
        return;
      }

      // Fetch ALL notes created by this user (public AND private)
      const { data, error } = await supabase
        .from('notes')
        .select('*')
        .eq('user_id', user.id)
        .order('created_at', { ascending: false });

      if (error) throw error;

      setNotes(data || []);
      setFilteredNotes(data || []);
    } catch (error) {
      console.error('Error fetching notes:', error);
    } finally {
      setLoading(false);
    }
  };

  const formatDate = (dateString) => {
    const date = new Date(dateString);
    return date.toLocaleDateString('en-IN', { 
      year: 'numeric', 
      month: 'short', 
      day: 'numeric' 
    });
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary"></div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        
        {/* Header */}
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-gray-900 flex items-center gap-2">
            <FileText className="h-8 w-8 text-blue-600" />
            My Notes
          </h1>
          <p className="mt-2 text-gray-600">
            All notes you've created (public and private)
          </p>
        </div>

        {/* Search Bar */}
        <div className="mb-6">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-5 w-5 text-gray-400" />
            <Input
              type="text"
              placeholder="Search your notes..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="pl-10"
            />
          </div>
        </div>

        {/* Results Count */}
        <div className="mb-4 flex items-center justify-between">
          <p className="text-sm text-gray-600">
            {filteredNotes.length} {filteredNotes.length === 1 ? 'note' : 'notes'}
          </p>
          <Button onClick={() => navigate('/dashboard/notes/new')}>
            <FileText className="mr-2 h-4 w-4" />
            Upload New Note
          </Button>
        </div>

        {/* Notes Grid */}
        {filteredNotes.length === 0 ? (
          <Card>
            <CardContent className="p-12 text-center">
              <FileText className="h-16 w-16 text-gray-400 mx-auto mb-4" />
              <h3 className="text-lg font-semibold text-gray-900 mb-2">
                {searchQuery ? 'No notes found' : 'No notes yet'}
              </h3>
              <p className="text-gray-600 mb-4">
                {searchQuery 
                  ? 'Try a different search term'
                  : 'Upload your first note to get started!'
                }
              </p>
              {!searchQuery && (
                <Button onClick={() => navigate('/dashboard/notes/new')}>
                  Upload Your First Note
                </Button>
              )}
            </CardContent>
          </Card>
        ) : (
          <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
            {filteredNotes.map((note) => (
              <Card 
                key={note.id} 
                className="cursor-pointer hover:shadow-lg transition"
                onClick={() => navigate(`/dashboard/notes/${note.id}`)}
              >
                <CardHeader>
                  <div className="flex items-start justify-between">
                    <CardTitle className="text-lg line-clamp-2 flex-1">
                      {note.title || 'Untitled Note'}
                    </CardTitle>
                    {/* Public/Private Badge */}
                    {note.is_public ? (
                      <Globe className="h-4 w-4 text-green-600 flex-shrink-0 ml-2" title="Public" />
                    ) : (
                      <Lock className="h-4 w-4 text-gray-400 flex-shrink-0 ml-2" title="Private" />
                    )}
                  </div>
                </CardHeader>
                <CardContent>
                  {/* Preview Image */}
                  {note.image_url && (
                    <img 
                      src={note.image_url} 
                      alt={note.title}
                      className="w-full h-48 object-cover rounded mb-4"
                    />
                  )}

                  {/* Description */}
                  {note.description && (
                    <p className="text-sm text-gray-600 mb-3 line-clamp-2">
                      {note.description}
                    </p>
                  )}

                  {/* Metadata */}
                  <div className="space-y-2">
                    {/* Course/Subject */}
                    {(note.target_course || note.subject) && (
                      <div className="text-xs text-gray-500">
                        <span className="font-medium">For:</span>{' '}
                        {note.target_course && `${note.target_course}`}
                        {note.subject && ` • ${note.subject}`}
                        {note.topic && ` • ${note.topic}`}
                      </div>
                    )}

                    {/* Tags */}
                    {note.tags && note.tags.length > 0 && (
                      <div className="flex flex-wrap gap-1">
                        {note.tags.slice(0, 3).map((tag, idx) => (
                          <span 
                            key={idx}
                            className="px-2 py-1 bg-blue-100 text-blue-700 text-xs rounded"
                          >
                            {tag}
                          </span>
                        ))}
                        {note.tags.length > 3 && (
                          <span className="px-2 py-1 bg-gray-100 text-gray-600 text-xs rounded">
                            +{note.tags.length - 3}
                          </span>
                        )}
                      </div>
                    )}

                    {/* Date & Visibility */}
                    <div className="flex items-center justify-between text-xs text-gray-500 pt-2 border-t">
                      <span>{formatDate(note.created_at)}</span>
                      <span className="flex items-center gap-1">
                        {note.is_public ? (
                          <>
                            <Globe className="h-3 w-3" />
                            Public
                          </>
                        ) : (
                          <>
                            <Lock className="h-3 w-3" />
                            Private
                          </>
                        )}
                      </span>
                    </div>
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}