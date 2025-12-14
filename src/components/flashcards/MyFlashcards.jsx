import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Brain, Plus, Search, Trash2, BookOpen, Image as ImageIcon, FileText } from 'lucide-react';
import { useToast } from '@/hooks/use-toast';

export default function MyFlashcards() {
  const navigate = useNavigate();
  const { toast } = useToast();
  const [flashcards, setFlashcards] = useState([]);
  const [filteredCards, setFilteredCards] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [filterSubject, setFilterSubject] = useState('all');
  const [subjects, setSubjects] = useState([]);

  useEffect(() => {
    fetchFlashcards();
  }, []);

  useEffect(() => {
    filterFlashcards();
  }, [searchTerm, filterSubject, flashcards]);

  const fetchFlashcards = async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      const { data, error } = await supabase
        .from('flashcards')
        .select(`
          *,
          notes (
            id,
            title,
            subject,
            topic
          )
        `)
        .eq('user_id', user.id)
        .order('created_at', { ascending: false });

      if (error) throw error;

      setFlashcards(data || []);

      // Extract unique subjects
      const uniqueSubjects = [...new Set(data?.map(card => card.notes?.subject).filter(Boolean))];
      setSubjects(uniqueSubjects);
    } catch (error) {
      console.error('Error fetching flashcards:', error);
      toast({
        title: "Error loading flashcards",
        description: error.message,
        variant: "destructive"
      });
    } finally {
      setLoading(false);
    }
  };

  const filterFlashcards = () => {
    let filtered = [...flashcards];

    // Filter by search term
    if (searchTerm) {
      filtered = filtered.filter(card =>
        card.front_text.toLowerCase().includes(searchTerm.toLowerCase()) ||
        card.back_text?.toLowerCase().includes(searchTerm.toLowerCase())
      );
    }

    // Filter by subject
    if (filterSubject !== 'all') {
      filtered = filtered.filter(card => card.notes?.subject === filterSubject);
    }

    setFilteredCards(filtered);
  };

  const handleDelete = async (cardId) => {
    if (!confirm('Are you sure you want to delete this flashcard?')) return;

    try {
      const { error } = await supabase
        .from('flashcards')
        .delete()
        .eq('id', cardId);

      if (error) throw error;

      toast({
        title: "Flashcard deleted",
        description: "Flashcard has been removed"
      });

      fetchFlashcards();
    } catch (error) {
      console.error('Error deleting flashcard:', error);
      toast({
        title: "Delete failed",
        description: error.message,
        variant: "destructive"
      });
    }
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
      {/* Header */}
      <header className="bg-white border-b border-gray-200">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            <div className="flex items-center gap-3">
              <Brain className="h-8 w-8 text-purple-600" />
              <div>
                <h1 className="text-xl font-bold text-gray-900">My Flashcards</h1>
                <p className="text-sm text-gray-500">{flashcards.length} total flashcards</p>
              </div>
            </div>
            <div className="flex items-center gap-3">
              <Button
                onClick={() => navigate('/dashboard/study')}
                className="gap-2 bg-purple-600 hover:bg-purple-700 text-white shadow-lg"
                disabled={flashcards.length === 0}
              >
                <Brain className="h-4 w-4" />
                Start Studying
              </Button>
              <Button
                onClick={() => navigate('/dashboard/flashcards/new')}
                variant="outline"
                className="gap-2"
              >
                <Plus className="h-4 w-4" />
                New Flashcard
              </Button>
              <Button
                variant="outline"
                onClick={() => navigate('/dashboard')}
              >
                Dashboard
              </Button>
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Search and Filter */}
        <div className="bg-white rounded-lg shadow-sm p-6 mb-6">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
              <Input
                placeholder="Search flashcards..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="pl-10"
              />
            </div>
            <Select value={filterSubject} onValueChange={setFilterSubject}>
              <SelectTrigger>
                <SelectValue placeholder="Filter by subject" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All Subjects</SelectItem>
                {subjects.map(subject => (
                  <SelectItem key={subject} value={subject}>
                    {subject}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          <p className="text-sm text-gray-500 mt-3">
            Showing {filteredCards.length} of {flashcards.length} flashcards
          </p>
        </div>

        {/* Flashcards Grid */}
        {filteredCards.length === 0 ? (
          <div className="bg-white rounded-lg shadow-sm p-12 text-center">
            <Brain className="h-16 w-16 text-gray-400 mx-auto mb-4" />
            <h3 className="text-lg font-semibold text-gray-900 mb-2">
              {flashcards.length === 0 ? 'No flashcards yet' : 'No flashcards found'}
            </h3>
            <p className="text-gray-600 mb-6">
              {flashcards.length === 0
                ? 'Create your first flashcard to start learning with spaced repetition'
                : 'Try adjusting your search or filters'}
            </p>
            {flashcards.length === 0 && (
              <Button onClick={() => navigate('/dashboard/flashcards/new')} className="gap-2">
                <Plus className="h-4 w-4" />
                Create Flashcard
              </Button>
            )}
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {filteredCards.map((card) => (
              <div
                key={card.id}
                className="bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden hover:shadow-md transition-shadow"
              >
                {/* Card Header */}
                <div className="p-4 border-b border-gray-100 bg-gray-50">
                  <div className="flex items-start justify-between">
                    <div className="flex-1">
                      {card.notes && (
                        <div className="mb-2">
                          <button
                            onClick={() => navigate(`/dashboard/notes/${card.notes.id}`)}
                            className="text-xs text-blue-600 hover:text-blue-700 hover:underline flex items-center gap-1"
                          >
                            <FileText className="h-3 w-3" />
                            {card.notes.title}
                          </button>
                          <p className="text-xs text-gray-500 mt-0.5">
                            {card.notes.subject} {card.notes.topic && `• ${card.notes.topic}`}
                          </p>
                        </div>
                      )}
                    </div>
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={() => handleDelete(card.id)}
                      className="text-red-600 hover:text-red-700 hover:bg-red-50 -mt-1 -mr-2"
                    >
                      <Trash2 className="h-4 w-4" />
                    </Button>
                  </div>
                </div>

                {/* Front Side */}
                <div className="p-4 border-b border-gray-100">
                  <p className="text-xs font-semibold text-gray-500 uppercase mb-2">Front</p>
                  {card.front_image_url && (
                    <img
                      src={card.front_image_url}
                      alt="Front"
                      className="w-full h-32 object-cover rounded mb-2"
                    />
                  )}
                  <p className="text-sm text-gray-900 whitespace-pre-wrap">
                    {card.front_text}
                  </p>
                </div>

                {/* Back Side */}
                <div className="p-4 bg-blue-50">
                  <p className="text-xs font-semibold text-gray-500 uppercase mb-2">Back</p>
                  {card.back_image_url && (
                    <img
                      src={card.back_image_url}
                      alt="Back"
                      className="w-full h-32 object-cover rounded mb-2"
                    />
                  )}
                  {card.back_text ? (
                    <p className="text-sm text-gray-900 whitespace-pre-wrap">
                      {card.back_text}
                    </p>
                  ) : (
                    <p className="text-sm text-gray-500 italic">No answer provided</p>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}
      </main>
    </div>
  );
}