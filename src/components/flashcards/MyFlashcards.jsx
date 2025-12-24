import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Brain, Plus, Search, Trash2, Filter, Edit2, Save, X } from 'lucide-react';
import { useToast } from '@/hooks/use-toast';
import { useAuth } from '@/contexts/AuthContext';

export default function MyFlashcards() {
  const navigate = useNavigate();
  const { toast } = useToast();
  const { user } = useAuth();
  const [flashcards, setFlashcards] = useState([]);
  const [filteredCards, setFilteredCards] = useState([]);
  const [loading, setLoading] = useState(true);
  
  // Filter states
  const [searchQuery, setSearchQuery] = useState('');
  const [filterCourse, setFilterCourse] = useState('all');
  const [filterSubject, setFilterSubject] = useState('all');
  const [filterTopic, setFilterTopic] = useState('all');
  const [filterDate, setFilterDate] = useState('all');
  
  // Available options
  const [availableCourses, setAvailableCourses] = useState([]);
  const [availableSubjects, setAvailableSubjects] = useState([]);
  const [availableTopics, setAvailableTopics] = useState([]);

  // Edit state
  const [editingCardId, setEditingCardId] = useState(null);
  const [editForm, setEditForm] = useState({
    front_text: '',
    back_text: ''
  });

  useEffect(() => {
    fetchFlashcards();
  }, []);

  useEffect(() => {
    applyFilters();
  }, [searchQuery, filterCourse, filterSubject, filterTopic, filterDate, flashcards]);

  const fetchFlashcards = async () => {
    try {
      if (!user) return;

      const { data, error } = await supabase
        .from('flashcards')
        .select(`
          *,
          subjects:subject_id (id, name),
          topics:topic_id (id, name)
        `)
        .eq('user_id', user.id)
        .order('created_at', { ascending: false });

      if (error) throw error;

      // Clean diamond characters
      const cleanedData = (data || []).map(card => ({
        ...card,
        front_text: card.front_text?.replace(/[\u25C6\u2666◆�]/g, '').trim() || '',
        back_text: card.back_text?.replace(/[\u25C6\u2666◆�]/g, '').trim() || '',
        custom_subject: card.custom_subject?.replace(/[\u25C6\u2666◆�]/g, '').trim() || null,
        custom_topic: card.custom_topic?.replace(/[\u25C6\u2666◆�]/g, '').trim() || null
      }));

      setFlashcards(cleanedData);

      // Extract unique values for filters
      const courses = [...new Set(cleanedData.map(c => c.target_course).filter(Boolean))];
      const subjects = [...new Set(cleanedData.map(c => c.subjects?.name || c.custom_subject).filter(Boolean))];
      const topics = [...new Set(cleanedData.map(c => c.topics?.name || c.custom_topic).filter(Boolean))];

      setAvailableCourses(courses);
      setAvailableSubjects(subjects);
      setAvailableTopics(topics);
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

  const applyFilters = () => {
    let filtered = [...flashcards];

    // Search filter
    if (searchQuery.trim() !== '') {
      const query = searchQuery.toLowerCase();
      filtered = filtered.filter(card =>
        card.front_text?.toLowerCase().includes(query) ||
        card.back_text?.toLowerCase().includes(query)
      );
    }

    // Course filter
    if (filterCourse !== 'all') {
      filtered = filtered.filter(card => card.target_course === filterCourse);
    }

    // Subject filter
    if (filterSubject !== 'all') {
      filtered = filtered.filter(card => 
        (card.subjects?.name || card.custom_subject) === filterSubject
      );
    }

    // Topic filter
    if (filterTopic !== 'all') {
      filtered = filtered.filter(card => 
        (card.topics?.name || card.custom_topic) === filterTopic
      );
    }

    // Date filter
    if (filterDate !== 'all') {
      const now = new Date();
      filtered = filtered.filter(card => {
        const cardDate = new Date(card.created_at);
        switch(filterDate) {
          case 'today':
            return cardDate.toDateString() === now.toDateString();
          case 'week':
            const weekAgo = new Date(now - 7 * 24 * 60 * 60 * 1000);
            return cardDate >= weekAgo;
          case 'month':
            const monthAgo = new Date(now - 30 * 24 * 60 * 60 * 1000);
            return cardDate >= monthAgo;
          default:
            return true;
        }
      });
    }

    setFilteredCards(filtered);
  };

  const startEdit = (card) => {
    setEditingCardId(card.id);
    setEditForm({
      front_text: card.front_text,
      back_text: card.back_text
    });
  };

  const cancelEdit = () => {
    setEditingCardId(null);
    setEditForm({
      front_text: '',
      back_text: ''
    });
  };

  const handleSaveEdit = async (cardId) => {
    try {
      // Validate
      if (!editForm.front_text.trim()) {
        toast({
          title: "Validation Error",
          description: "Question cannot be empty",
          variant: "destructive"
        });
        return;
      }

      const { error } = await supabase
        .from('flashcards')
        .update({
          front_text: editForm.front_text.trim(),
          back_text: editForm.back_text.trim(),
          
        })
        .eq('id', cardId);

      if (error) throw error;

      toast({
        title: "Flashcard updated",
        description: "Your changes have been saved"
      });

      // Update local state
      setFlashcards(prev => prev.map(card => 
        card.id === cardId 
          ? { ...card, front_text: editForm.front_text.trim(), back_text: editForm.back_text.trim() }
          : card
      ));

      // Exit edit mode
      cancelEdit();
    } catch (error) {
      console.error('Error updating flashcard:', error);
      toast({
        title: "Update failed",
        description: error.message,
        variant: "destructive"
      });
    }
  };

  const handleDelete = async (cardId, event) => {
    event.stopPropagation();
    
    if (!confirm('Are you sure you want to delete this flashcard? This action cannot be undone.')) {
      return;
    }

    try {
      const { error } = await supabase
        .from('flashcards')
        .delete()
        .eq('id', cardId);

      if (error) throw error;

      toast({
        title: "Flashcard deleted",
        description: "Flashcard has been removed successfully"
      });

      setFlashcards(prev => prev.filter(card => card.id !== cardId));
      
      // Exit edit mode if deleting card being edited
      if (editingCardId === cardId) {
        cancelEdit();
      }
    } catch (error) {
      console.error('Error deleting flashcard:', error);
      toast({
        title: "Delete failed",
        description: error.message,
        variant: "destructive"
      });
    }
  };

  const clearAllFilters = () => {
    setSearchQuery('');
    setFilterCourse('all');
    setFilterSubject('all');
    setFilterTopic('all');
    setFilterDate('all');
  };

  const formatDate = (dateString) => {
    return new Date(dateString).toLocaleDateString('en-IN', {
      year: 'numeric',
      month: 'short',
      day: 'numeric'
    });
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  const hasActiveFilters = searchQuery || filterCourse !== 'all' || filterSubject !== 'all' || 
                          filterTopic !== 'all' || filterDate !== 'all';

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        
        {/* Header */}
        <div className="mb-8 flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold text-gray-900 flex items-center gap-2">
              <Brain className="h-8 w-8 text-purple-600" />
              My Flashcards
            </h1>
            <p className="mt-2 text-gray-600">
              {flashcards.length} total flashcards created
            </p>
          </div>
          <div className="flex gap-3">
            <Button
              onClick={() => navigate('/dashboard/review-flashcards')}
              className="gap-2"
              disabled={flashcards.length === 0}
            >
              <Brain className="h-4 w-4" />
              Review
            </Button>
            <Button
              onClick={() => navigate('/dashboard/flashcards/new')}
              variant="outline"
              className="gap-2"
            >
              <Plus className="h-4 w-4" />
              Create New
            </Button>
          </div>
        </div>

        {/* Filters & Search */}
        <Card className="mb-6">
          <CardContent className="pt-6">
            <div className="space-y-4">
              {/* Search Bar */}
              <div className="relative">
                <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
                <Input
                  type="text"
                  placeholder="Search flashcards by question or answer..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="pl-10"
                />
              </div>

              {/* Filters Section */}
              <div className="flex items-center gap-2">
                <Filter className="h-4 w-4 text-gray-600" />
                <span className="text-sm font-medium text-gray-700">Filters</span>
              </div>
              
              <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                {/* Course Filter */}
                {availableCourses.length > 0 && (
                  <div>
                    <label className="text-sm text-gray-600 mb-2 block">Course</label>
                    <Select value={filterCourse} onValueChange={setFilterCourse}>
                      <SelectTrigger>
                        <SelectValue placeholder="All Courses" />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="all">All Courses</SelectItem>
                        {availableCourses.map(course => (
                          <SelectItem key={course} value={course}>
                            {course}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>
                )}

                {/* Subject Filter */}
                {availableSubjects.length > 0 && (
                  <div>
                    <label className="text-sm text-gray-600 mb-2 block">Subject</label>
                    <Select value={filterSubject} onValueChange={setFilterSubject}>
                      <SelectTrigger>
                        <SelectValue placeholder="All Subjects" />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="all">All Subjects</SelectItem>
                        {availableSubjects.map(subject => (
                          <SelectItem key={subject} value={subject}>
                            {subject}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>
                )}

                {/* Topic Filter */}
                {availableTopics.length > 0 && (
                  <div>
                    <label className="text-sm text-gray-600 mb-2 block">Topic</label>
                    <Select value={filterTopic} onValueChange={setFilterTopic}>
                      <SelectTrigger>
                        <SelectValue placeholder="All Topics" />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="all">All Topics</SelectItem>
                        {availableTopics.map(topic => (
                          <SelectItem key={topic} value={topic}>
                            {topic}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>
                )}

                {/* Date Filter */}
                <div>
                  <label className="text-sm text-gray-600 mb-2 block">Date Created</label>
                  <Select value={filterDate} onValueChange={setFilterDate}>
                    <SelectTrigger>
                      <SelectValue placeholder="All Time" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="all">All Time</SelectItem>
                      <SelectItem value="today">Today</SelectItem>
                      <SelectItem value="week">Last 7 Days</SelectItem>
                      <SelectItem value="month">Last 30 Days</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
              </div>

              {/* Results & Clear */}
              <div className="flex items-center justify-between pt-2">
                <p className="text-sm text-gray-600">
                  Showing {filteredCards.length} of {flashcards.length} flashcards
                </p>
                {hasActiveFilters && (
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={clearAllFilters}
                    className="text-sm"
                  >
                    Clear All Filters
                  </Button>
                )}
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Flashcards Display */}
        {filteredCards.length === 0 ? (
          <Card>
            <CardContent className="py-12 text-center">
              <Brain className="h-16 w-16 text-gray-400 mx-auto mb-4" />
              <h3 className="text-lg font-semibold text-gray-900 mb-2">
                {flashcards.length === 0 ? 'No flashcards yet' : 'No flashcards match your filters'}
              </h3>
              <p className="text-gray-600 mb-6">
                {flashcards.length === 0
                  ? 'Create your first flashcard to start learning'
                  : 'Try adjusting your filters or search query'}
              </p>
              {flashcards.length === 0 ? (
                <Button onClick={() => navigate('/dashboard/flashcards/new')} className="gap-2">
                  <Plus className="h-4 w-4" />
                  Create Flashcard
                </Button>
              ) : (
                <Button onClick={clearAllFilters}>
                  Clear All Filters
                </Button>
              )}
            </CardContent>
          </Card>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {filteredCards.map((card) => {
              const isEditing = editingCardId === card.id;
              
              return (
                <Card key={card.id} className={`hover:shadow-lg transition-shadow ${isEditing ? 'ring-2 ring-blue-500' : ''}`}>
                  <CardHeader className="pb-3">
                    <div className="flex items-start justify-between">
                      <div className="flex-1">
                        <p className="text-xs text-gray-500 mb-1">
                          {card.target_course || 'No course'} 
                          {(card.subjects?.name || card.custom_subject) && 
                            ` • ${card.subjects?.name || card.custom_subject}`
                          }
                        </p>
                        {(card.topics?.name || card.custom_topic) && (
                          <p className="text-xs text-gray-400">
                            {card.topics?.name || card.custom_topic}
                          </p>
                        )}
                      </div>
                      {!isEditing && (
                        <div className="flex gap-1">
                          <Button
                            variant="ghost"
                            size="sm"
                            onClick={() => startEdit(card)}
                            className="text-blue-600 hover:text-blue-700 hover:bg-blue-50 -mt-2"
                          >
                            <Edit2 className="h-4 w-4" />
                          </Button>
                          <Button
                            variant="ghost"
                            size="sm"
                            onClick={(e) => handleDelete(card.id, e)}
                            className="text-red-600 hover:text-red-700 hover:bg-red-50 -mt-2 -mr-2"
                          >
                            <Trash2 className="h-4 w-4" />
                          </Button>
                        </div>
                      )}
                    </div>
                  </CardHeader>
                  <CardContent>
                    {isEditing ? (
                      // EDIT MODE
                      <div className="space-y-4">
                        {/* Front Text */}
                        <div>
                          <label className="text-xs font-semibold text-gray-500 uppercase mb-2 block">
                            Question
                          </label>
                          <Textarea
                            value={editForm.front_text}
                            onChange={(e) => setEditForm(prev => ({ ...prev, front_text: e.target.value }))}
                            placeholder="Enter question..."
                            className="min-h-[80px]"
                            autoFocus
                          />
                        </div>

                        {/* Back Text */}
                        <div>
                          <label className="text-xs font-semibold text-gray-500 uppercase mb-2 block">
                            Answer
                          </label>
                          <Textarea
                            value={editForm.back_text}
                            onChange={(e) => setEditForm(prev => ({ ...prev, back_text: e.target.value }))}
                            placeholder="Enter answer..."
                            className="min-h-[80px]"
                          />
                        </div>

                        {/* Action Buttons */}
                        <div className="flex gap-2 pt-2">
                          <Button
                            onClick={() => handleSaveEdit(card.id)}
                            className="flex-1 gap-2"
                            size="sm"
                          >
                            <Save className="h-4 w-4" />
                            Save
                          </Button>
                          <Button
                            onClick={cancelEdit}
                            variant="outline"
                            className="flex-1 gap-2"
                            size="sm"
                          >
                            <X className="h-4 w-4" />
                            Cancel
                          </Button>
                        </div>
                      </div>
                    ) : (
                      // VIEW MODE
                      <>
                        {/* Front Side */}
                        <div className="mb-4 pb-4 border-b border-gray-200">
                          <p className="text-xs font-semibold text-gray-500 uppercase mb-2">Question</p>
                          {card.front_image_url && (
                            <img
                              src={card.front_image_url}
                              alt="Front"
                              className="w-full h-32 object-cover rounded mb-2"
                            />
                          )}
                          <p className="text-sm text-gray-900 whitespace-pre-wrap line-clamp-3">
                            {card.front_text}
                          </p>
                        </div>

                        {/* Back Side */}
                        <div className="bg-blue-50 -mx-6 -mb-6 p-4 rounded-b-lg">
                          <p className="text-xs font-semibold text-gray-500 uppercase mb-2">Answer</p>
                          {card.back_image_url && (
                            <img
                              src={card.back_image_url}
                              alt="Back"
                              className="w-full h-32 object-cover rounded mb-2"
                            />
                          )}
                          {card.back_text ? (
                            <p className="text-sm text-gray-900 whitespace-pre-wrap line-clamp-3">
                              {card.back_text}
                            </p>
                          ) : (
                            <p className="text-sm text-gray-500 italic">No answer provided</p>
                          )}
                        </div>

                        {/* Footer */}
                        <div className="mt-4 pt-3 border-t border-gray-200 text-xs text-gray-500">
                          Created {formatDate(card.created_at)}
                        </div>
                      </>
                    )}
                  </CardContent>
                </Card>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}