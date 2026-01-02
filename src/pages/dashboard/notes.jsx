import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { FileText, Search, Filter, Users } from 'lucide-react';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';

export default function BrowseNotes() {
  const navigate = useNavigate();
  const [loading, setLoading] = useState(true);
  const [groupedNotes, setGroupedNotes] = useState([]);
  const [allGroupedNotes, setAllGroupedNotes] = useState([]);
  
  // Filter states
  const [searchQuery, setSearchQuery] = useState('');
  const [filterCourse, setFilterCourse] = useState('all');
  const [filterSubject, setFilterSubject] = useState('all');
  const [filterAuthor, setFilterAuthor] = useState('all');
  
  const [availableCourses, setAvailableCourses] = useState([]);
  const [availableSubjects, setAvailableSubjects] = useState([]);

  useEffect(() => {
    fetchNotes();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    applyFilters();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [searchQuery, filterCourse, filterSubject, filterAuthor, allGroupedNotes]);

  const fetchNotes = async () => {
    try {
      // Fetch all PUBLIC notes
      const { data: notesData, error: notesError } = await supabase
        .from('notes')
        .select('*')
        .eq('is_public', true)
        .order('created_at', { ascending: false });

      if (notesError) throw notesError;

      // Get unique user IDs
      const userIds = [...new Set(notesData.map(note => note.user_id))];

      // Fetch user profiles
      const { data: profilesData, error: profilesError } = await supabase
        .from('profiles')
        .select('id, full_name, role')
        .in('id', userIds);

      if (profilesError) throw profilesError;

      // Fetch subjects
      const subjectIds = [...new Set(notesData.map(n => n.subject_id).filter(Boolean))];
      const { data: subjectsData } = await supabase
        .from('subjects')
        .select('id, name')
        .in('id', subjectIds);

      // Fetch topics
      const topicIds = [...new Set(notesData.map(n => n.topic_id).filter(Boolean))];
      const { data: topicsData } = await supabase
        .from('topics')
        .select('id, name')
        .in('id', topicIds);

      // Merge data
      const notesWithDetails = notesData.map(note => ({
        ...note,
        user: profilesData.find(p => p.id === note.user_id),
        subject: subjectsData?.find(s => s.id === note.subject_id) || 
                 { name: note.custom_subject || 'Other' },
        topic: topicsData?.find(t => t.id === note.topic_id) || 
               { name: note.custom_topic || 'General' }
      }));

      // Extract unique values
      const courses = [...new Set(notesWithDetails.map(n => n.target_course).filter(Boolean))];
      const subjects = [...new Set(notesWithDetails.map(n => n.subject?.name).filter(Boolean))];

      setAvailableCourses(courses);
      setAvailableSubjects(subjects);

      // Group notes
      const grouped = groupNotesBySubject(notesWithDetails);
      setAllGroupedNotes(grouped);
      setGroupedNotes(grouped);
    } catch (error) {
      console.error('Error fetching notes:', error);
    } finally {
      setLoading(false);
    }
  };

  const groupNotesBySubject = (notes) => {
    const grouped = {};

    notes.forEach(note => {
      const subjectName = note.subject?.name || 'Other';
      const topicName = note.topic?.name || 'General';
      const isProfessor = note.user?.role === 'professor';

      if (!grouped[subjectName]) {
        grouped[subjectName] = {
          name: subjectName,
          course: note.target_course,
          topics: {},
          totalNotes: 0,
          professorNotes: 0
        };
      }

      if (!grouped[subjectName].topics[topicName]) {
        grouped[subjectName].topics[topicName] = {
          name: topicName,
          notes: []
        };
      }

      grouped[subjectName].topics[topicName].notes.push(note);
      grouped[subjectName].totalNotes++;
      
      if (isProfessor) {
        grouped[subjectName].professorNotes++;
      }
    });

    return Object.values(grouped).map(subject => ({
      ...subject,
      topics: Object.values(subject.topics)
    }));
  };

  const applyFilters = () => {
    let filtered = [...allGroupedNotes];

    // Course filter
    if (filterCourse !== 'all') {
      filtered = filtered.filter(subject => subject.course === filterCourse);
    }

    // Subject filter
    if (filterSubject !== 'all') {
      filtered = filtered.filter(subject => subject.name === filterSubject);
    }

    // Author filter
    if (filterAuthor === 'professor') {
      filtered = filtered.map(subject => ({
        ...subject,
        topics: subject.topics.map(topic => ({
          ...topic,
          notes: topic.notes.filter(note => note.user?.role === 'professor')
        })).filter(topic => topic.notes.length > 0)
      })).filter(subject => subject.topics.length > 0);
    } else if (filterAuthor === 'student') {
      filtered = filtered.map(subject => ({
        ...subject,
        topics: subject.topics.map(topic => ({
          ...topic,
          notes: topic.notes.filter(note => note.user?.role !== 'professor')
        })).filter(topic => topic.notes.length > 0)
      })).filter(subject => subject.topics.length > 0);
    }

    // Search filter
    if (searchQuery.trim() !== '') {
      const query = searchQuery.toLowerCase();
      filtered = filtered.map(subject => ({
        ...subject,
        topics: subject.topics.map(topic => ({
          ...topic,
          notes: topic.notes.filter(note =>
            note.title?.toLowerCase().includes(query) ||
            note.description?.toLowerCase().includes(query) ||
            note.tags?.some(tag => tag.toLowerCase().includes(query)) ||
            note.user?.full_name?.toLowerCase().includes(query)
          )
        })).filter(topic => topic.notes.length > 0)
      })).filter(subject => subject.topics.length > 0);
    }

    setGroupedNotes(filtered);
  };

  const clearAllFilters = () => {
    setSearchQuery('');
    setFilterCourse('all');
    setFilterSubject('all');
    setFilterAuthor('all');
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
      <div className="flex items-center justify-center min-h-screen">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary"></div>
      </div>
    );
  }

  const totalNotes = groupedNotes.reduce((sum, subject) => sum + subject.totalNotes, 0);
  const hasActiveFilters = searchQuery || filterCourse !== 'all' || filterSubject !== 'all' || filterAuthor !== 'all';

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        
        {/* Header */}
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-gray-900 mb-2">Browse Notes</h1>
          <p className="text-gray-600">
            Explore notes from professors and classmates
          </p>
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
                  placeholder="Search notes by title, description, tags, or author..."
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

              {/* Filter Dropdowns - Single Row */}
              <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
                {/* Course Filter */}
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

                {/* Subject Filter */}
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

                {/* Author Filter */}
                <div>
                  <label className="text-sm text-gray-600 mb-2 block">Author</label>
                  <Select value={filterAuthor} onValueChange={setFilterAuthor}>
                    <SelectTrigger>
                      <SelectValue placeholder="All Authors" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="all">All Authors</SelectItem>
                      <SelectItem value="professor">Professors Only</SelectItem>
                      <SelectItem value="student">Students Only</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
              </div>

              {/* Results Count & Clear Button */}
              <div className="flex items-center justify-between pt-2">
                <p className="text-sm text-gray-600">
                  {totalNotes} {totalNotes === 1 ? 'note' : 'notes'} found
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
        {groupedNotes.length === 0 ? (
          <Card>
            <CardContent className="py-12 text-center">
              <FileText className="h-16 w-16 text-gray-400 mx-auto mb-4" />
              <h3 className="text-lg font-semibold text-gray-900 mb-2">
                {allGroupedNotes.length === 0 ? 'No public notes available' : 'No notes match your filters'}
              </h3>
              <p className="text-gray-600 mb-6">
                {allGroupedNotes.length === 0
                  ? 'Be the first to share your notes with the community'
                  : 'Try adjusting your filters or search query'}
              </p>
              {allGroupedNotes.length === 0 ? (
                <Button onClick={() => navigate('/dashboard/notes/new')}>
                  Upload Note
                </Button>
              ) : (
                <Button onClick={clearAllFilters}>
                  Clear All Filters
                </Button>
              )}
            </CardContent>
          </Card>
        ) : (
          <div className="space-y-6">
            {groupedNotes.map((subject, idx) => (
              <Card key={idx}>
                <CardHeader>
                  <div className="flex items-center justify-between">
                    <div>
                      <CardTitle className="text-xl">{subject.name}</CardTitle>
                      <p className="text-sm text-gray-600 mt-1">
                        {subject.course && <span className="font-medium">{subject.course}</span>}
                        {subject.course && ' • '}
                        {subject.totalNotes} {subject.totalNotes === 1 ? 'note' : 'notes'}
                        {subject.professorNotes > 0 && ` • ${subject.professorNotes} from professors`}
                      </p>
                    </div>
                  </div>
                </CardHeader>
                <CardContent>
                  {subject.topics.map((topic, topicIdx) => (
                    <div key={topicIdx} className="mb-6 last:mb-0">
                      <h3 className="text-lg font-semibold text-gray-900 mb-3">
                        {topic.name}
                      </h3>
                      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                        {topic.notes.map((note) => (
                          <button
                            key={note.id}
                            onClick={() => navigate(`/dashboard/notes/${note.id}`)}
                            className="text-left border border-gray-200 rounded-lg hover:border-blue-300 hover:shadow-md transition-all overflow-hidden group"
                          >
                            {/* Image Preview */}
                            {note.image_url && (
                              <img
                                src={note.image_url}
                                alt={note.title}
                                className="w-full h-40 object-cover"
                              />
                            )}
                            
                            <div className="p-4">
                              <h4 className="font-medium text-gray-900 group-hover:text-blue-700 mb-2 line-clamp-2">
                                {note.title || 'Untitled Note'}
                              </h4>
                              
                              {note.description && (
                                <p className="text-sm text-gray-600 mb-3 line-clamp-2">
                                  {note.description}
                                </p>
                              )}

                              {/* Tags */}
                              {note.tags && note.tags.length > 0 && (
                                <div className="flex flex-wrap gap-1 mb-3">
                                  {note.tags.slice(0, 2).map((tag, idx) => (
                                    <span 
                                      key={idx}
                                      className="px-2 py-1 bg-blue-100 text-blue-700 text-xs rounded"
                                    >
                                      {tag}
                                    </span>
                                  ))}
                                  {note.tags.length > 2 && (
                                    <span className="px-2 py-1 bg-gray-100 text-gray-600 text-xs rounded">
                                      +{note.tags.length - 2}
                                    </span>
                                  )}
                                </div>
                              )}

                              {/* Author & Date */}
                              <div className="flex items-center justify-between text-xs text-gray-500 pt-2 border-t">
                                <span className="flex items-center gap-1">
                                  {note.user?.role === 'professor' && (
                                    <Users className="h-3 w-3 text-purple-600" />
                                  )}
                                  {note.user?.full_name || 'Unknown'}
                                </span>
                                <span>{formatDate(note.created_at)}</span>
                              </div>
                            </div>
                          </button>
                        ))}
                      </div>
                    </div>
                  ))}
                </CardContent>
              </Card>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}