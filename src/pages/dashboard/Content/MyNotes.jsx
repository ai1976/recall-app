import { useState, useEffect, useMemo } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { FileText, Search, Lock, Globe, Trash2, Filter, Plus, ChevronDown, ChevronRight } from 'lucide-react';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { useToast } from '@/hooks/use-toast';
import { useAuth } from '@/contexts/AuthContext';

const VIEW_MODE_KEY = 'myNotes_viewMode';

export default function MyNotes() {
  const navigate = useNavigate();
  const { toast } = useToast();
  const { user } = useAuth();
  const [notes, setNotes] = useState([]);
  const [filteredNotes, setFilteredNotes] = useState([]);
  const [loading, setLoading] = useState(true);
  
  // Filter states
  const [searchQuery, setSearchQuery] = useState('');
  const [filterCourse, setFilterCourse] = useState('all');
  const [filterSubject, setFilterSubject] = useState('all');
  const [filterTopic, setFilterTopic] = useState('all');
  const [filterDate, setFilterDate] = useState('all');
  const [filterVisibility, setFilterVisibility] = useState('all');
  
  // Available options
  const [availableCourses, setAvailableCourses] = useState([]);
  const [availableSubjects, setAvailableSubjects] = useState([]);
  const [availableTopics, setAvailableTopics] = useState([]);
  
  // Store all topics for reference (needed for dependent filtering)
  const [allTopicsFromNotes, setAllTopicsFromNotes] = useState([]);

  // View mode state - persist in localStorage
  const [viewMode, setViewMode] = useState(() => {
    try {
      return localStorage.getItem(VIEW_MODE_KEY) || 'grid';
    } catch {
      return 'grid';
    }
  });

  // Collapsed groups state for grouped view
  const [collapsedGroups, setCollapsedGroups] = useState({});

  const handleViewModeChange = (mode) => {
    setViewMode(mode);
    try {
      localStorage.setItem(VIEW_MODE_KEY, mode);
    } catch {
      // localStorage unavailable
    }
  };

  useEffect(() => {
    fetchMyNotes();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    applyFilters();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [searchQuery, filterCourse, filterSubject, filterTopic, filterDate, filterVisibility, notes]);

  // Dependent topic filtering when subject changes
  useEffect(() => {
    if (filterSubject === 'all') {
      // Show all topics when "All Subjects" is selected
      setAvailableTopics(allTopicsFromNotes);
    } else {
      // Filter topics to only show those belonging to the selected subject
      const filteredTopics = notes
        .filter(note => {
          const noteSubject = note.subjects?.name || note.custom_subject;
          return noteSubject === filterSubject;
        })
        .map(note => note.topics?.name || note.custom_topic)
        .filter(Boolean);

      const uniqueTopics = [...new Set(filteredTopics)];
      setAvailableTopics(uniqueTopics);

      // Reset topic filter if current selection is not in filtered list
      if (filterTopic !== 'all' && !uniqueTopics.includes(filterTopic)) {
        setFilterTopic('all');
      }
    }
  }, [filterSubject, notes, allTopicsFromNotes, filterTopic]);

  const fetchMyNotes = async () => {
    try {
      if (!user) {
        navigate('/login');
        return;
      }

      const { data, error } = await supabase
        .from('notes')
        .select(`
          *,
          subjects:subject_id (id, name),
          topics:topic_id (id, name)
        `)
        .eq('user_id', user.id)
        .order('created_at', { ascending: false });

      if (error) throw error;

      setNotes(data || []);

      // Extract unique values for filters
      const courses = [...new Set(data.map(n => n.target_course).filter(Boolean))];
      const subjects = [...new Set(data.map(n => n.subjects?.name || n.custom_subject).filter(Boolean))];
      const topics = [...new Set(data.map(n => n.topics?.name || n.custom_topic).filter(Boolean))];

      setAvailableCourses(courses);
      setAvailableSubjects(subjects);
      setAvailableTopics(topics);
      setAllTopicsFromNotes(topics); // Store all topics for reference
    } catch (error) {
      console.error('Error fetching notes:', error);
      toast({
        title: "Error loading notes",
        description: error.message,
        variant: "destructive"
      });
    } finally {
      setLoading(false);
    }
  };

  const applyFilters = () => {
    let filtered = [...notes];

    // Search filter
    if (searchQuery.trim() !== '') {
      const query = searchQuery.toLowerCase();
      filtered = filtered.filter(note => 
        note.title?.toLowerCase().includes(query) ||
        note.description?.toLowerCase().includes(query) ||
        note.tags?.some(tag => tag.toLowerCase().includes(query))
      );
    }

    // Course filter
    if (filterCourse !== 'all') {
      filtered = filtered.filter(note => note.target_course === filterCourse);
    }

    // Subject filter
    if (filterSubject !== 'all') {
      filtered = filtered.filter(note => 
        (note.subjects?.name || note.custom_subject) === filterSubject
      );
    }

    // Topic filter
    if (filterTopic !== 'all') {
      filtered = filtered.filter(note => 
        (note.topics?.name || note.custom_topic) === filterTopic
      );
    }

    // Visibility filter
    if (filterVisibility !== 'all') {
      filtered = filtered.filter(note => 
        filterVisibility === 'public' ? note.is_public : !note.is_public
      );
    }

    // Date filter
    if (filterDate !== 'all') {
      const now = new Date();
      filtered = filtered.filter(note => {
        const noteDate = new Date(note.created_at);
        switch(filterDate) {
          case 'today':
            return noteDate.toDateString() === now.toDateString();
          case 'week': {
            const weekAgo = new Date(now - 7 * 24 * 60 * 60 * 1000);
            return noteDate >= weekAgo;
          }
          case 'month': {
            const monthAgo = new Date(now - 30 * 24 * 60 * 60 * 1000);
            return noteDate >= monthAgo;
          }
          default:
            return true;
        }
      });
    }

    setFilteredNotes(filtered);
  };

  const handleDelete = async (noteId, event) => {
    event.stopPropagation(); // Prevent card click
    
    if (!confirm('Are you sure you want to delete this note? This will also delete all associated flashcards. This action cannot be undone.')) {
      return;
    }

    try {
      const { error } = await supabase
        .from('notes')
        .delete()
        .eq('id', noteId);

      if (error) throw error;

      toast({
        title: "Note deleted",
        description: "Note and associated flashcards have been removed"
      });

      // Remove from local state
      setNotes(prev => prev.filter(note => note.id !== noteId));
    } catch (error) {
      console.error('Error deleting note:', error);
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
    setFilterVisibility('all');
  };

  // Handler for subject change
  const handleSubjectChange = (value) => {
    setFilterSubject(value);
  };

  const formatDate = (dateString) => {
    return new Date(dateString).toLocaleDateString('en-IN', { 
      year: 'numeric', 
      month: 'short', 
      day: 'numeric' 
    });
  };

  // Build grouped notes: Subject → Topic → notes[]
  const groupedNotes = useMemo(() => {
    const groups = {};

    filteredNotes.forEach(note => {
      const subject = note.subjects?.name || note.custom_subject || 'Uncategorized';
      const topic = note.topics?.name || note.custom_topic || 'Uncategorized';

      if (!groups[subject]) {
        groups[subject] = {};
      }
      if (!groups[subject][topic]) {
        groups[subject][topic] = [];
      }
      groups[subject][topic].push(note);
    });

    // Sort subjects: "Uncategorized" goes last
    const sortedSubjects = Object.keys(groups).sort((a, b) => {
      if (a === 'Uncategorized') return 1;
      if (b === 'Uncategorized') return -1;
      return a.localeCompare(b);
    });

    const sorted = {};
    sortedSubjects.forEach(subject => {
      const topicKeys = Object.keys(groups[subject]).sort((a, b) => {
        if (a === 'Uncategorized') return 1;
        if (b === 'Uncategorized') return -1;
        return a.localeCompare(b);
      });
      sorted[subject] = {};
      topicKeys.forEach(topic => {
        sorted[subject][topic] = groups[subject][topic];
      });
    });

    return sorted;
  }, [filteredNotes]);

  const toggleGroupCollapse = (groupKey) => {
    setCollapsedGroups(prev => ({
      ...prev,
      [groupKey]: !prev[groupKey]
    }));
  };

  // Render a single note card (shared between grid and grouped views)
  const renderNoteCard = (note) => (
    <Card 
      key={note.id} 
      className="cursor-pointer hover:shadow-lg transition group"
      onClick={() => navigate(`/dashboard/notes/${note.id}`)}
    >
      <CardHeader>
        <div className="flex items-start justify-between">
          <CardTitle className="text-lg line-clamp-2 flex-1 pr-2">
            {note.title || 'Untitled Note'}
          </CardTitle>
          <div className="flex items-center gap-2 flex-shrink-0">
            {note.is_public ? (
              <Globe className="h-4 w-4 text-green-600" title="Public" />
            ) : (
              <Lock className="h-4 w-4 text-gray-400" title="Private" />
            )}
            <Button
              variant="ghost"
              size="sm"
              onClick={(e) => handleDelete(note.id, e)}
              className="opacity-0 group-hover:opacity-100 text-red-600 hover:text-red-700 hover:bg-red-50 -mr-2"
            >
              <Trash2 className="h-4 w-4" />
            </Button>
          </div>
        </div>
      </CardHeader>
      <CardContent>
        {note.image_url && (
          <img 
            src={note.image_url} 
            alt={note.title}
            className="w-full h-48 object-cover rounded mb-4"
          />
        )}

        {note.description && (
          <p className="text-sm text-gray-600 mb-3 line-clamp-2">
            {note.description}
          </p>
        )}

        <div className="space-y-2">
          <div className="text-xs text-gray-500">
            {note.target_course && <span className="font-medium">{note.target_course}</span>}
            {(note.subjects?.name || note.custom_subject) && (
              <span> &bull; {note.subjects?.name || note.custom_subject}</span>
            )}
            {(note.topics?.name || note.custom_topic) && (
              <span> &bull; {note.topics?.name || note.custom_topic}</span>
            )}
          </div>

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

          <div className="text-xs text-gray-500 pt-2 border-t">
            {formatDate(note.created_at)}
          </div>
        </div>
      </CardContent>
    </Card>
  );

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary"></div>
      </div>
    );
  }

  const hasActiveFilters = searchQuery || filterCourse !== 'all' || filterSubject !== 'all' || 
    filterTopic !== 'all' || filterDate !== 'all' || filterVisibility !== 'all';

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        
        {/* Header */}
        <div className="mb-8 flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold text-gray-900 flex items-center gap-2">
              <FileText className="h-8 w-8 text-blue-600" />
              My Notes
            </h1>
            <p className="mt-2 text-gray-600">
              {notes.length} total notes (public and private)
            </p>
          </div>
          <div className="flex gap-3">
            {/* View Mode Toggle */}
            <div className="flex rounded-lg border border-gray-300 overflow-hidden">
              <Button
                variant={viewMode === 'grid' ? 'default' : 'ghost'}
                size="sm"
                onClick={() => handleViewModeChange('grid')}
                className="rounded-none"
              >
                Grid
              </Button>
              <Button
                variant={viewMode === 'grouped' ? 'default' : 'ghost'}
                size="sm"
                onClick={() => handleViewModeChange('grouped')}
                className="rounded-none"
              >
                Grouped
              </Button>
            </div>
            <Button onClick={() => navigate('/dashboard/notes/new')} className="gap-2">
              <Plus className="h-4 w-4" />
              Upload Note
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
                  placeholder="Search notes by title, description, or tags..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="pl-10"
                />
              </div>

              {/* Filter Dropdowns */}
              <div className="flex items-center gap-2 pt-2">
                <Filter className="h-4 w-4 text-gray-600" />
                <span className="text-sm font-medium text-gray-700">Filters</span>
              </div>
              
              <div className="grid grid-cols-1 md:grid-cols-5 gap-4">
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
                    <Select value={filterSubject} onValueChange={handleSubjectChange}>
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

                {/* Visibility Filter */}
                <div>
                  <label className="text-sm text-gray-600 mb-2 block">Visibility</label>
                  <Select value={filterVisibility} onValueChange={setFilterVisibility}>
                    <SelectTrigger>
                      <SelectValue placeholder="All" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="all">All Notes</SelectItem>
                      <SelectItem value="public">Public Only</SelectItem>
                      <SelectItem value="private">Private Only</SelectItem>
                    </SelectContent>
                  </Select>
                </div>

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
                  Showing {filteredNotes.length} of {notes.length} notes
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

        {/* Notes Display */}
        {filteredNotes.length === 0 ? (
          <Card>
            <CardContent className="py-12 text-center">
              <FileText className="h-16 w-16 text-gray-400 mx-auto mb-4" />
              <h3 className="text-lg font-semibold text-gray-900 mb-2">
                {notes.length === 0 ? 'No notes yet' : 'No notes match your filters'}
              </h3>
              <p className="text-gray-600 mb-4">
                {notes.length === 0 
                  ? 'Upload your first note to get started'
                  : 'Try adjusting your filters or search query'
                }
              </p>
              {notes.length === 0 ? (
                <Button onClick={() => navigate('/dashboard/notes/new')}>
                  Upload Your First Note
                </Button>
              ) : (
                <Button onClick={clearAllFilters}>
                  Clear All Filters
                </Button>
              )}
            </CardContent>
          </Card>
        ) : viewMode === 'grouped' ? (
          /* ==================== GROUPED VIEW ==================== */
          <div className="space-y-6">
            {Object.entries(groupedNotes).map(([subject, topics]) => {
              const subjectKey = `subject-${subject}`;
              const isSubjectCollapsed = collapsedGroups[subjectKey];
              const subjectNoteCount = Object.values(topics).reduce((sum, arr) => sum + arr.length, 0);
              const topicCount = Object.keys(topics).length;

              return (
                <Card key={subjectKey}>
                  {/* Subject Header */}
                  <CardHeader
                    className="cursor-pointer select-none bg-gradient-to-r from-blue-50 to-indigo-50 hover:from-blue-100 hover:to-indigo-100 transition-colors"
                    onClick={() => toggleGroupCollapse(subjectKey)}
                  >
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-3">
                        {isSubjectCollapsed ? (
                          <ChevronRight className="h-5 w-5 text-gray-500" />
                        ) : (
                          <ChevronDown className="h-5 w-5 text-gray-500" />
                        )}
                        <div>
                          <CardTitle className="text-lg">{subject}</CardTitle>
                          <p className="text-sm text-gray-600 mt-1">
                            {topicCount} topic{topicCount !== 1 ? 's' : ''} &bull; {subjectNoteCount} note{subjectNoteCount !== 1 ? 's' : ''}
                          </p>
                        </div>
                      </div>
                    </div>
                  </CardHeader>

                  {/* Topics & Notes (collapsible) */}
                  {!isSubjectCollapsed && (
                    <CardContent className="pt-4 space-y-6">
                      {Object.entries(topics).map(([topic, topicNotes]) => {
                        const topicKey = `${subjectKey}-topic-${topic}`;
                        const isTopicCollapsed = collapsedGroups[topicKey];

                        return (
                          <div key={topicKey}>
                            {/* Topic Sub-header */}
                            <div
                              className="flex items-center gap-2 mb-4 cursor-pointer select-none group/topic"
                              onClick={() => toggleGroupCollapse(topicKey)}
                            >
                              {isTopicCollapsed ? (
                                <ChevronRight className="h-4 w-4 text-gray-400" />
                              ) : (
                                <ChevronDown className="h-4 w-4 text-gray-400" />
                              )}
                              <h3 className="text-md font-semibold text-gray-700 group-hover/topic:text-gray-900">
                                {topic}
                              </h3>
                              <span className="text-sm text-gray-500">
                                ({topicNotes.length} note{topicNotes.length !== 1 ? 's' : ''})
                              </span>
                            </div>

                            {/* Note Cards Grid */}
                            {!isTopicCollapsed && (
                              <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
                                {topicNotes.map(note => renderNoteCard(note))}
                              </div>
                            )}
                          </div>
                        );
                      })}
                    </CardContent>
                  )}
                </Card>
              );
            })}
          </div>
        ) : (
          /* ==================== GRID VIEW ==================== */
          <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
            {filteredNotes.map(note => renderNoteCard(note))}
          </div>
        )}
      </div>
    </div>
  );
}
