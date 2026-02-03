import { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Brain, Plus, Search, Trash2, Filter, Edit2, Calendar, Package, AlertTriangle } from 'lucide-react';
import { useToast } from '@/hooks/use-toast';
import { useAuth } from '@/contexts/AuthContext';
import FlashcardCard from '@/components/flashcards/FlashcardCard';

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

  // Edit state - ISOLATED to prevent cursor jumping
  const [editingCardId, setEditingCardId] = useState(null);
  const [editingCard, setEditingCard] = useState(null);

  // View mode state
  const [viewMode, setViewMode] = useState('grid');

  // Merge functionality states
  const [selectedBatches, setSelectedBatches] = useState(new Set());
  const [showMergeDialog, setShowMergeDialog] = useState(false);
  const [newBatchName, setNewBatchName] = useState('');

  // Edit Group Info states
  const [editingGroupBatchId, setEditingGroupBatchId] = useState(null);
  const [showEditGroupDialog, setShowEditGroupDialog] = useState(false);
  const [editGroupForm, setEditGroupForm] = useState({
    course: '',
    subject: '',
    topic: '',
    description: ''
  });
  const [allCourses, setAllCourses] = useState([]);
  const [allSubjects, setAllSubjects] = useState([]);
  const [allTopics, setAllTopics] = useState([]);

  const fetchAllCoursesSubjectsTopics = useCallback(async () => {
    try {
      const [notesRes, flashcardsRes, profilesRes] = await Promise.all([
        supabase.from('notes').select('target_course').not('target_course', 'is', null),
        supabase.from('flashcards').select('target_course').not('target_course', 'is', null),
        supabase.from('profiles').select('course_level').not('course_level', 'is', null)
      ]);

      const courses = new Set([
        ...(notesRes.data || []).map(n => n.target_course),
        ...(flashcardsRes.data || []).map(f => f.target_course),
        ...(profilesRes.data || []).map(p => p.course_level)
      ]);
      setAllCourses([...courses].sort());

      const { data: subjects } = await supabase
        .from('subjects')
        .select('id, name')
        .order('name');
      setAllSubjects(subjects || []);

      const { data: topics } = await supabase
        .from('topics')
        .select('id, name, subject_id')
        .order('name');
      setAllTopics(topics || []);

    } catch (error) {
      console.error('Error fetching options:', error);
    }
  }, []);

  const fetchFlashcards = useCallback(async () => {
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

      const cleanedData = (data || []).map(card => ({
        ...card,
        front_text: card.front_text?.replace(/[\u25C6\u2666◆�]/g, '').trim() || '',
        back_text: card.back_text?.replace(/[\u25C6\u2666◆�]/g, '').trim() || '',
        custom_subject: card.custom_subject?.replace(/[\u25C6\u2666◆�]/g, '').trim() || null,
        custom_topic: card.custom_topic?.replace(/[\u25C6\u2666◆�]/g, '').trim() || null,
        visibility: card.visibility || 'private',
        is_public: card.is_public || false
      }));

      setFlashcards(cleanedData);

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
  }, [user, toast]);

  const applyFilters = useCallback(() => {
    let filtered = [...flashcards];

    if (searchQuery.trim() !== '') {
      const query = searchQuery.toLowerCase();
      filtered = filtered.filter(card =>
        card.front_text?.toLowerCase().includes(query) ||
        card.back_text?.toLowerCase().includes(query)
      );
    }

    if (filterCourse !== 'all') {
      filtered = filtered.filter(card => card.target_course === filterCourse);
    }

    if (filterSubject !== 'all') {
      filtered = filtered.filter(card =>
        (card.subjects?.name || card.custom_subject) === filterSubject
      );
    }

    if (filterTopic !== 'all') {
      filtered = filtered.filter(card =>
        (card.topics?.name || card.custom_topic) === filterTopic
      );
    }

    if (filterDate !== 'all') {
      const now = new Date();
      filtered = filtered.filter(card => {
        const cardDate = new Date(card.created_at);
        switch(filterDate) {
          case 'today':
            return cardDate.toDateString() === now.toDateString();
          case 'week': {
            const weekAgo = new Date(now - 7 * 24 * 60 * 60 * 1000);
            return cardDate >= weekAgo;
          }
          case 'month': {
            const monthAgo = new Date(now - 30 * 24 * 60 * 60 * 1000);
            return cardDate >= monthAgo;
          }
          default:
            return true;
        }
      });
    }

    setFilteredCards(filtered);
  }, [flashcards, searchQuery, filterCourse, filterSubject, filterTopic, filterDate]);

  useEffect(() => {
    fetchFlashcards();
    fetchAllCoursesSubjectsTopics();
  }, [fetchFlashcards, fetchAllCoursesSubjectsTopics]);

  useEffect(() => {
    applyFilters();
  }, [applyFilters]);

  const getGroupedFlashcards = () => {
    const grouped = {};

    filteredCards.forEach(card => {
      const batchId = card.batch_id || 'no-batch';
      const course = card.target_course || 'No Course';
      const subject = card.subjects?.name || card.custom_subject || 'Uncategorized';
      const topic = card.topics?.name || card.custom_topic || 'No Topic';

      const key = batchId;

      if (!grouped[key]) {
        grouped[key] = {
          batchId: batchId,
          batchDescription: card.batch_description || null,
          course,
          subject,
          topic,
          subjectId: card.subject_id,
          topicId: card.topic_id,
          customSubject: card.custom_subject,
          customTopic: card.custom_topic,
          createdDate: new Date(card.created_at),
          cards: []
        };
      }

      grouped[key].cards.push(card);
    });

    const sortedGroups = Object.entries(grouped).sort((a, b) => {
      return b[1].createdDate - a[1].createdDate;
    });

    return Object.fromEntries(sortedGroups);
  };

  // Start editing - copy card data to isolated state
  const startEdit = useCallback((card) => {
    setEditingCardId(card.id);
    setEditingCard({
      front_text: card.front_text,
      back_text: card.back_text
    });
  }, []);

  // Cancel editing - clear isolated state
  const cancelEdit = useCallback(() => {
    setEditingCardId(null);
    setEditingCard(null);
  }, []);

  // Handle input changes on the ISOLATED editingCard state (prevents cursor jumping)
  const handleEditChange = useCallback((field, value) => {
    setEditingCard(prev => ({
      ...prev,
      [field]: value
    }));
  }, []);

  // Save edit - update database and main array, then clear editing state
  const handleSaveEdit = useCallback(async (cardId) => {
    try {
      if (!editingCard.front_text.trim()) {
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
          front_text: editingCard.front_text.trim(),
          back_text: editingCard.back_text.trim(),
        })
        .eq('id', cardId);

      if (error) throw error;

      toast({
        title: "Flashcard updated",
        description: "Your changes have been saved"
      });

      // Update local state immediately for better UX
      setFlashcards(prev => prev.map(card =>
        card.id === cardId
          ? { ...card, front_text: editingCard.front_text.trim(), back_text: editingCard.back_text.trim() }
          : card
      ));

      cancelEdit();
    } catch (error) {
      console.error('Error updating flashcard:', error);
      toast({
        title: "Update failed",
        description: error.message,
        variant: "destructive"
      });
    }
  }, [editingCard, toast, cancelEdit]);

  const handleDelete = useCallback(async (cardId, event) => {
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
  }, [toast, editingCardId, cancelEdit]);

  const handleDeleteGroup = async (groupCards, groupInfo) => {
    const count = groupCards.length;
    const groupName = `${groupInfo.course} > ${groupInfo.subject}`;

    if (!confirm(`Delete entire group?\n\n${groupName}\n${count} card${count !== 1 ? 's' : ''}\n\nThis action CANNOT be undone!`)) {
      return;
    }

    try {
      const cardIds = groupCards.map(c => c.id);

      const { error } = await supabase
        .from('flashcards')
        .delete()
        .in('id', cardIds);

      if (error) throw error;

      toast({
        title: "Group deleted",
        description: `${count} flashcard${count !== 1 ? 's' : ''} removed successfully`
      });

      setFlashcards(prev => prev.filter(card => !cardIds.includes(card.id)));

    } catch (error) {
      console.error('Error deleting group:', error);
      toast({
        title: "Delete failed",
        description: error.message,
        variant: "destructive"
      });
    }
  };

  const openEditGroupDialog = async (group) => {
    if (allCourses.length === 0 || allSubjects.length === 0) {
      await fetchAllCoursesSubjectsTopics();
    }

    setEditingGroupBatchId(group.batchId);
    setEditGroupForm({
      course: group.course || '',
      subject: group.subject || '',
      topic: group.topic || '',
      description: group.batchDescription || ''
    });
    setShowEditGroupDialog(true);
  };

  const handleSaveGroupInfo = async () => {
    try {
      if (!editGroupForm.course.trim() || !editGroupForm.subject.trim()) {
        toast({
          title: "Validation Error",
          description: "Course and Subject are required",
          variant: "destructive"
        });
        return;
      }

      const subject = allSubjects.find(s => s.name === editGroupForm.subject);
      const topic = editGroupForm.topic ? allTopics.find(t => t.name === editGroupForm.topic) : null;

      const updates = {
        target_course: editGroupForm.course.trim(),
        subject_id: subject?.id || null,
        custom_subject: subject ? null : editGroupForm.subject.trim(),
        topic_id: topic?.id || null,
        custom_topic: (topic || !editGroupForm.topic) ? null : editGroupForm.topic.trim(),
        batch_description: editGroupForm.description.trim() || null
      };

      const { error } = await supabase
        .from('flashcards')
        .update(updates)
        .eq('batch_id', editingGroupBatchId);

      if (error) throw error;

      toast({
        title: "Group updated",
        description: "All cards in this group have been updated"
      });

      setShowEditGroupDialog(false);
      setEditingGroupBatchId(null);
      setEditGroupForm({ course: '', subject: '', topic: '', description: '' });

      fetchFlashcards();

    } catch (error) {
      console.error('Error updating group:', error);
      toast({
        title: "Update failed",
        description: error.message,
        variant: "destructive"
      });
    }
  };

  const handleCardVisibilityChange = useCallback(async (cardId, newVisibility, event) => {
    event.stopPropagation();

    try {
      const { error } = await supabase
        .from('flashcards')
        .update({
          visibility: newVisibility,
          is_public: newVisibility === 'public'
        })
        .eq('id', cardId);

      if (error) throw error;

      toast({
        title: "Visibility updated",
        description: `Flashcard is now ${newVisibility}`
      });

      setFlashcards(prev => prev.map(card =>
        card.id === cardId
          ? { ...card, visibility: newVisibility, is_public: newVisibility === 'public' }
          : card
      ));
    } catch (error) {
      console.error('Error toggling visibility:', error);
      toast({
        title: "Update failed",
        description: error.message,
        variant: "destructive"
      });
    }
  }, [toast]);

  const handleGroupVisibilityChange = async (group, newVisibility) => {
    if (newVisibility === 'change-visibility') return;

    try {
      const cardIds = group.cards.map(card => card.id);

      const { error } = await supabase
        .from('flashcards')
        .update({
          visibility: newVisibility,
          is_public: newVisibility === 'public'
        })
        .in('id', cardIds);

      if (error) throw error;

      toast({
        title: "Group visibility updated!",
        description: `All ${cardIds.length} card${cardIds.length !== 1 ? 's' : ''} set to ${newVisibility}`,
      });

      fetchFlashcards();

    } catch (error) {
      console.error('Error updating group visibility:', error);
      toast({
        title: "Error",
        description: error.message,
        variant: "destructive",
      });
    }
  };

  const toggleBatchSelection = (batchId) => {
    const newSelection = new Set(selectedBatches);
    if (newSelection.has(batchId)) {
      newSelection.delete(batchId);
    } else {
      newSelection.add(batchId);
    }
    setSelectedBatches(newSelection);
  };

  const handleMergeBatches = () => {
    if (selectedBatches.size < 2) {
      toast({
        title: "Selection Required",
        description: "Please select at least 2 batches to merge",
        variant: "destructive"
      });
      return;
    }
    setShowMergeDialog(true);
  };

  const executeMerge = async () => {
    try {
      const batchIds = Array.from(selectedBatches);
      const targetBatchId = batchIds[0];
      const finalDescription = newBatchName.trim() || null;

      const { error } = await supabase
        .from('flashcards')
        .update({
          batch_id: targetBatchId,
          batch_description: finalDescription
        })
        .in('batch_id', batchIds);

      if (error) throw error;

      toast({
        title: "Batches Merged",
        description: `${batchIds.length} batches merged successfully`
      });

      setSelectedBatches(new Set());
      setShowMergeDialog(false);
      setNewBatchName('');

      fetchFlashcards();

    } catch (error) {
      console.error('Merge error:', error);
      toast({
        title: "Merge Failed",
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

  const formatDateTime = (dateString) => {
    return new Date(dateString).toLocaleString('en-IN', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
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

  const groupedFlashcards = viewMode === 'grouped' ? getGroupedFlashcards() : null;

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">

        <div className="mb-8 flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold text-gray-900 flex items-center gap-2">
              <Brain className="h-8 w-8 text-purple-600" />
              My Flashcards
            </h1>
            <p className="mt-2 text-gray-600">
              {flashcards.length} total flashcard{flashcards.length !== 1 ? 's' : ''} created
            </p>
          </div>
          <div className="flex gap-3">
            <div className="flex rounded-lg border border-gray-300 overflow-hidden">
              <Button
                variant={viewMode === 'grid' ? 'default' : 'ghost'}
                size="sm"
                onClick={() => setViewMode('grid')}
                className="rounded-none"
              >
                Grid
              </Button>
              <Button
                variant={viewMode === 'grouped' ? 'default' : 'ghost'}
                size="sm"
                onClick={() => setViewMode('grouped')}
                className="rounded-none"
              >
                Grouped
              </Button>
            </div>
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

        <Card className="mb-6">
          <CardContent className="pt-6">
            <div className="space-y-4">
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

              <div className="flex items-center gap-2">
                <Filter className="h-4 w-4 text-gray-600" />
                <span className="text-sm font-medium text-gray-700">Filters</span>
              </div>

              <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
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

              <div className="flex items-center justify-between pt-2">
                <p className="text-sm text-gray-600">
                  Showing {filteredCards.length} of {flashcards.length} flashcard{flashcards.length !== 1 ? 's' : ''}
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

        {viewMode === 'grouped' && selectedBatches.size > 0 && (
          <div className="mb-4 p-4 bg-blue-50 border border-blue-200 rounded-lg flex items-center justify-between">
            <p className="text-sm text-blue-800">
              {selectedBatches.size} batch{selectedBatches.size !== 1 ? 'es' : ''} selected
            </p>
            <div className="flex gap-2">
              <Button
                onClick={() => setSelectedBatches(new Set())}
                variant="outline"
                size="sm"
              >
                Clear Selection
              </Button>
              <Button
                onClick={handleMergeBatches}
                size="sm"
                disabled={selectedBatches.size < 2}
              >
                <Package className="h-4 w-4 mr-2" />
                Merge Selected Batches
              </Button>
            </div>
          </div>
        )}

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
        ) : viewMode === 'grouped' ? (
          <div className="space-y-6">
            {Object.entries(groupedFlashcards).map(([groupKey, group]) => {
              const allPublic = group.cards.every(c => c.visibility === 'public');
              const allPrivate = group.cards.every(c => c.visibility === 'private');
              const publicCount = group.cards.filter(c => c.visibility === 'public').length;

              return (
                <Card key={groupKey}>
                  <CardHeader className="bg-gradient-to-r from-blue-50 to-purple-50">
                    <div className="flex items-center gap-3">
                      <input
                        type="checkbox"
                        checked={selectedBatches.has(group.batchId)}
                        onChange={() => toggleBatchSelection(group.batchId)}
                        className="h-5 w-5 rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                      />

                      <div className="flex-1">
                        <CardTitle className="text-lg">
                          {group.course} &gt; {group.subject}
                        </CardTitle>
                        <p className="text-sm text-gray-600 mt-1">
                          {group.topic} ({group.cards.length} card{group.cards.length !== 1 ? 's' : ''})
                          {!allPublic && !allPrivate && (
                            <span className="ml-2 text-xs">
                              • {publicCount} public, {group.cards.length - publicCount} private
                            </span>
                          )}
                        </p>

                        {group.batchDescription && (
                          <p className="text-sm text-blue-600 mt-1 font-medium flex items-center gap-1">
                            <Package className="h-3 w-3" />
                            {group.batchDescription}
                          </p>
                        )}

                        <p className="text-xs text-gray-500 mt-1 flex items-center gap-1">
                          <Calendar className="h-3 w-3" />
                          Uploaded: {formatDateTime(group.createdDate)}
                        </p>
                      </div>

                      <div className="flex gap-2">
                        <Button
                          onClick={() => openEditGroupDialog(group)}
                          size="sm"
                          variant="outline"
                          className="gap-2"
                          title="Edit group info (course, subject, topic, description)"
                        >
                          <Edit2 className="h-4 w-4" />
                          Edit Info
                        </Button>

                        <select
                          value={
                            group.cards.every(c => c.visibility === 'public') ? 'public' :
                            group.cards.every(c => c.visibility === 'friends') ? 'friends' :
                            group.cards.every(c => c.visibility === 'private') ? 'private' :
                            'mixed'
                          }
                          data-group-id={group.batchId}
                          onChange={(e) => handleGroupVisibilityChange(group, e.target.value)}
                          className="px-4 py-2 border border-gray-300 rounded-md bg-white text-sm font-medium hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 cursor-pointer"
                        >
                          <option value="mixed" disabled>Mixed Visibility</option>
                          <option value="private">Private</option>
                          <option value="friends">Friends</option>
                          <option value="public">Public</option>
                        </select>

                        <Button
                          onClick={() => handleDeleteGroup(group.cards, group)}
                          size="sm"
                          variant="destructive"
                          className="gap-2"
                          title="Delete entire group"
                        >
                          <Trash2 className="h-4 w-4" />
                          Delete Group ({group.cards.length})
                        </Button>
                      </div>
                    </div>
                  </CardHeader>
                  <CardContent className="pt-6">
                    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                      {group.cards.map(card => (
                        <FlashcardCard
                          key={card.id}
                          card={card}
                          isEditing={editingCardId === card.id}
                          editingCard={editingCard}
                          onStartEdit={startEdit}
                          onCancelEdit={cancelEdit}
                          onSaveEdit={handleSaveEdit}
                          onEditChange={handleEditChange}
                          onDelete={handleDelete}
                          onVisibilityChange={handleCardVisibilityChange}
                        />
                      ))}
                    </div>
                  </CardContent>
                </Card>
              );
            })}
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {filteredCards.map(card => (
              <FlashcardCard
                key={card.id}
                card={card}
                isEditing={editingCardId === card.id}
                editingCard={editingCard}
                onStartEdit={startEdit}
                onCancelEdit={cancelEdit}
                onSaveEdit={handleSaveEdit}
                onEditChange={handleEditChange}
                onDelete={handleDelete}
                onVisibilityChange={handleCardVisibilityChange}
              />
            ))}
          </div>
        )}
      </div>

      {showMergeDialog && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <Card className="w-full max-w-md">
            <CardHeader>
              <CardTitle>Merge Batches</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <p className="text-sm text-gray-600">
                Merging {selectedBatches.size} batches. All cards will be combined into one batch.
              </p>

              <div className="space-y-2">
                <label className="text-sm font-medium text-gray-700">
                  New Batch Name (Optional)
                </label>
                <Input
                  value={newBatchName}
                  onChange={(e) => setNewBatchName(e.target.value)}
                  placeholder="e.g., Treasury - Complete"
                />
                <p className="text-xs text-gray-500">
                  Leave blank to remove batch description
                </p>
              </div>

              <div className="flex gap-2 pt-4">
                <Button
                  onClick={() => {
                    setShowMergeDialog(false);
                    setNewBatchName('');
                  }}
                  variant="outline"
                  className="flex-1"
                >
                  Cancel
                </Button>
                <Button
                  onClick={executeMerge}
                  className="flex-1"
                >
                  Merge Batches
                </Button>
              </div>
            </CardContent>
          </Card>
        </div>
      )}

      {showEditGroupDialog && editingGroupBatchId && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <Card className="w-full max-w-lg max-h-[90vh] overflow-y-auto">
            <CardHeader>
              <CardTitle>Edit Group Information</CardTitle>
              <p className="text-sm text-gray-600">
                Changes will apply to all {groupedFlashcards[editingGroupBatchId]?.cards.length || 0} cards in this group
              </p>
            </CardHeader>
            <CardContent className="space-y-4">

              <div className="space-y-2">
                <label className="text-sm font-medium text-gray-700">
                  Course <span className="text-red-500">*</span>
                </label>
                {allCourses.length > 0 ? (
                  <select
                    value={editGroupForm.course || ''}
                    onChange={(e) => setEditGroupForm(prev => ({ ...prev, course: e.target.value }))}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                  >
                    <option value="">Select course...</option>
                    {allCourses.map(course => (
                      <option key={course} value={course}>
                        {course}
                      </option>
                    ))}
                  </select>
                ) : (
                  <Input
                    value={editGroupForm.course || ''}
                    onChange={(e) => setEditGroupForm(prev => ({ ...prev, course: e.target.value }))}
                    placeholder="Enter course..."
                  />
                )}
              </div>

              <div className="space-y-2">
                <label className="text-sm font-medium text-gray-700">
                  Subject <span className="text-red-500">*</span>
                </label>
                {allSubjects.length > 0 ? (
                  <select
                    value={editGroupForm.subject || ''}
                    onChange={(e) => setEditGroupForm(prev => ({ ...prev, subject: e.target.value }))}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                  >
                    <option value="">Select subject...</option>
                    {allSubjects.map(subject => (
                      <option key={subject.id} value={subject.name}>
                        {subject.name}
                      </option>
                    ))}
                  </select>
                ) : (
                  <Input
                    value={editGroupForm.subject || ''}
                    onChange={(e) => setEditGroupForm(prev => ({ ...prev, subject: e.target.value }))}
                    placeholder="Enter subject..."
                  />
                )}
              </div>

              <div className="space-y-2">
                <label className="text-sm font-medium text-gray-700">
                  Topic (Optional)
                </label>
                {allTopics.length > 0 ? (
                  <select
                    value={editGroupForm.topic || ''}
                    onChange={(e) => setEditGroupForm(prev => ({ ...prev, topic: e.target.value }))}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                  >
                    <option value="">No Topic</option>
                    {allTopics
                      .filter(topic => {
                        const selectedSubject = allSubjects.find(s => s.name === editGroupForm.subject);
                        return !selectedSubject || topic.subject_id === selectedSubject.id;
                      })
                      .map(topic => (
                        <option key={topic.id} value={topic.name}>
                          {topic.name}
                        </option>
                      ))}
                  </select>
                ) : (
                  <Input
                    value={editGroupForm.topic || ''}
                    onChange={(e) => setEditGroupForm(prev => ({ ...prev, topic: e.target.value }))}
                    placeholder="Enter topic (optional)..."
                  />
                )}
              </div>

              <div className="space-y-2">
                <label className="text-sm font-medium text-gray-700">
                  Batch Description (Optional)
                </label>
                <Input
                  value={editGroupForm.description || ''}
                  onChange={(e) => setEditGroupForm(prev => ({ ...prev, description: e.target.value }))}
                  placeholder="e.g., Treasury Management - Part 1"
                />
              </div>

              <div className="bg-amber-50 border border-amber-200 rounded-lg p-3">
                <p className="text-sm text-amber-800 flex items-start gap-2">
                  <AlertTriangle className="h-4 w-4 mt-0.5 flex-shrink-0" />
                  <span>
                    Changing course or subject will update <strong>all cards</strong> in this group.
                    Make sure the new values are correct before saving.
                  </span>
                </p>
              </div>

              <div className="flex gap-2 pt-4">
                <Button
                  onClick={() => {
                    setShowEditGroupDialog(false);
                    setEditingGroupBatchId(null);
                    setEditGroupForm({ course: '', subject: '', topic: '', description: '' });
                  }}
                  variant="outline"
                  className="flex-1"
                >
                  Cancel
                </Button>
                <Button
                  onClick={handleSaveGroupInfo}
                  className="flex-1"
                  disabled={!editGroupForm.course?.trim() || !editGroupForm.subject?.trim()}
                >
                  Save Changes
                </Button>
              </div>
            </CardContent>
          </Card>
        </div>
      )}
    </div>
  );
}
