import { useState, useEffect, useCallback } from 'react';
import { useNavigate, Link, useSearchParams } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { FileText, Search, Filter, Users, ChevronDown, ChevronRight } from 'lucide-react';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import UpvoteButton from '@/components/ui/UpvoteButton';

const NOTES_PER_PAGE = 10;

export default function BrowseNotes() {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const { user } = useAuth();
  const [loading, setLoading] = useState(true);
  const [groupedNotes, setGroupedNotes] = useState([]);
  const [allGroupedNotes, setAllGroupedNotes] = useState([]);
  const [allNotesFlat, setAllNotesFlat] = useState([]);

  const [searchQuery, setSearchQuery] = useState('');
  const [filterCourse, setFilterCourse] = useState('all');
  const [filterSubject, setFilterSubject] = useState(searchParams.get('subject') || 'all');
  const [filterTopic, setFilterTopic] = useState('all');
  const [filterRole, setFilterRole] = useState('all');
  const [filterAuthor, setFilterAuthor] = useState(searchParams.get('author') || 'all');
  
  const [availableCourses, setAvailableCourses] = useState([]);
  const [availableSubjects, setAvailableSubjects] = useState([]);
  const [availableTopics, setAvailableTopics] = useState([]);
  const [allTopicsFromNotes, setAllTopicsFromNotes] = useState([]);
  const [availableAuthors, setAvailableAuthors] = useState([]);
  const [loadingAuthors, setLoadingAuthors] = useState(false);

  // Store subject name to ID mapping for RPC calls
  const [subjectNameToId, setSubjectNameToId] = useState({});

  // Collapsed groups state for collapsible sections
  const [collapsedGroups, setCollapsedGroups] = useState({});
  const [visibleCount, setVisibleCount] = useState(NOTES_PER_PAGE);

  const toggleGroupCollapse = (groupKey) => {
    setCollapsedGroups(prev => ({
      ...prev,
      [groupKey]: !prev[groupKey]
    }));
  };

  useEffect(() => {
    fetchNotes();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    applyFilters();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [searchQuery, filterCourse, filterSubject, filterTopic, filterRole, filterAuthor, allGroupedNotes, allNotesFlat]);

  // Dependent topic filtering when subject changes
  useEffect(() => {
    if (filterSubject === 'all') {
      setAvailableTopics(allTopicsFromNotes);
    } else {
      const filteredTopics = allNotesFlat
        .filter(note => {
          const noteSubject = note.subject?.name || 'Other';
          return noteSubject === filterSubject;
        })
        .map(note => note.topic?.name)
        .filter(Boolean);

      const uniqueTopics = [...new Set(filteredTopics)];
      setAvailableTopics(uniqueTopics);

      if (filterTopic !== 'all' && !uniqueTopics.includes(filterTopic)) {
        setFilterTopic('all');
      }
    }
  }, [filterSubject, allNotesFlat, allTopicsFromNotes, filterTopic]);

  // Fetch filtered authors from server when filters change
  const fetchFilteredAuthors = useCallback(async () => {
    setLoadingAuthors(true);
    try {
      // Get subject_id from subject name
      let subjectId = null;
      if (filterSubject !== 'all' && subjectNameToId[filterSubject]) {
        subjectId = subjectNameToId[filterSubject];
      }

      const { data, error } = await supabase.rpc('get_filtered_authors_for_notes', {
        p_course: filterCourse === 'all' ? null : filterCourse,
        p_subject_id: subjectId,
        p_role: filterRole === 'all' ? null : filterRole
      });

      if (error) {
        console.error('Error fetching filtered authors:', error);
        setAvailableAuthors([]);
      } else {
        setAvailableAuthors(data || []);
        // Reset author filter if current selection is no longer valid
        if (filterAuthor !== 'all') {
          const authorStillValid = data?.some(a => a.id === filterAuthor);
          if (!authorStillValid) {
            setFilterAuthor('all');
          }
        }
      }
    } catch (err) {
      console.error('Error in fetchFilteredAuthors:', err);
      setAvailableAuthors([]);
    } finally {
      setLoadingAuthors(false);
    }
  }, [filterCourse, filterSubject, filterRole, subjectNameToId, filterAuthor]);

  // Fetch authors when relevant filters change
  useEffect(() => {
    fetchFilteredAuthors();
  }, [fetchFilteredAuthors]);

  const fetchNotes = async () => {
    try {
      // Single server-side RPC handles all visibility logic
      // (own + public + friends + group-shared) in one query
      const { data: rpcData, error: rpcError } = await supabase.rpc('get_browsable_notes');

      if (rpcError) throw rpcError;

      const allNotesData = rpcData || [];

      // Build subject name to ID mapping
      const nameToIdMap = {};
      allNotesData.forEach(n => {
        if (n.subject_name && n.subject_id) {
          nameToIdMap[n.subject_name] = n.subject_id;
        }
      });
      setSubjectNameToId(nameToIdMap);

      // Map RPC result to the shape the rest of the component expects
      const notesWithDetails = allNotesData.map(note => ({
        ...note,
        user: { full_name: note.author_name, role: note.author_role },
        subject: { name: note.subject_name },
        topic: { name: note.topic_name }
      }));

      // Store flat notes for topic filtering
      setAllNotesFlat(notesWithDetails);

      // Extract unique values
      const courses = [...new Set(notesWithDetails.map(n => n.target_course).filter(Boolean))];
      const subjects = [...new Set(notesWithDetails.map(n => n.subject?.name).filter(Boolean))];
      const topics = [...new Set(notesWithDetails.map(n => n.topic?.name).filter(Boolean))];

      setAvailableCourses(courses);
      setAvailableSubjects(subjects);
      setAvailableTopics(topics);
      setAllTopicsFromNotes(topics);

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

    if (filterCourse !== 'all') {
      filtered = filtered.filter(subject => subject.course === filterCourse);
    }

    if (filterSubject !== 'all') {
      filtered = filtered.filter(subject => subject.name === filterSubject);
    }

    // Topic filter - filter within subjects
    if (filterTopic !== 'all') {
      filtered = filtered.map(subject => ({
        ...subject,
        topics: subject.topics.filter(topic => topic.name === filterTopic),
        totalNotes: subject.topics
          .filter(topic => topic.name === filterTopic)
          .reduce((sum, topic) => sum + topic.notes.length, 0)
      })).filter(subject => subject.topics.length > 0);
    }

    // Role filter - filter by author role
    if (filterRole === 'professor') {
      filtered = filtered.map(subject => ({
        ...subject,
        topics: subject.topics.map(topic => ({
          ...topic,
          notes: topic.notes.filter(note => note.user?.role === 'professor')
        })).filter(topic => topic.notes.length > 0),
        totalNotes: subject.topics.reduce((sum, topic) => 
          sum + topic.notes.filter(note => note.user?.role === 'professor').length, 0
        )
      })).filter(subject => subject.topics.length > 0);
    } else if (filterRole === 'student') {
      filtered = filtered.map(subject => ({
        ...subject,
        topics: subject.topics.map(topic => ({
          ...topic,
          notes: topic.notes.filter(note => note.user?.role !== 'professor')
        })).filter(topic => topic.notes.length > 0),
        totalNotes: subject.topics.reduce((sum, topic) => 
          sum + topic.notes.filter(note => note.user?.role !== 'professor').length, 0
        )
      })).filter(subject => subject.topics.length > 0);
    }

    // Author filter - filter by specific author ID
    if (filterAuthor !== 'all') {
      filtered = filtered.map(subject => ({
        ...subject,
        topics: subject.topics.map(topic => ({
          ...topic,
          notes: topic.notes.filter(note => note.user_id === filterAuthor)
        })).filter(topic => topic.notes.length > 0),
        totalNotes: subject.topics.reduce((sum, topic) => 
          sum + topic.notes.filter(note => note.user_id === filterAuthor).length, 0
        )
      })).filter(subject => subject.topics.length > 0);
    }

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

    setVisibleCount(NOTES_PER_PAGE);
    setGroupedNotes(filtered);
  };

  const clearAllFilters = () => {
    setSearchQuery('');
    setFilterCourse('all');
    setFilterSubject('all');
    setFilterTopic('all');
    setFilterRole('all');
    setFilterAuthor('all');
  };

  const handleSubjectChange = (value) => {
    setFilterSubject(value);
  };

  const handleRoleChange = (value) => {
    setFilterRole(value);
    // Reset author when role changes since available authors will change
    setFilterAuthor('all');
  };

  const formatDate = (dateString) => {
    const date = new Date(dateString);
    const now = new Date();
    const diffDays = Math.floor((now - date) / (1000 * 60 * 60 * 24));
    
    if (diffDays === 0) return 'Today';
    if (diffDays === 1) return 'Yesterday';
    if (diffDays < 7) return `${diffDays} days ago`;
    return date.toLocaleDateString('en-IN', { day: 'numeric', month: 'short' });
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  const totalNotes = groupedNotes.reduce((sum, subject) => sum + subject.totalNotes, 0);
  const flatFiltered = groupedNotes.flatMap(s => s.topics.flatMap(t => t.notes));
  const displayedGroupedNotes = groupNotesBySubject(flatFiltered.slice(0, visibleCount));
  const hasMore = flatFiltered.length > visibleCount;
  const hasActiveFilters = searchQuery || filterCourse !== 'all' || filterSubject !== 'all' || filterTopic !== 'all' || filterRole !== 'all' || filterAuthor !== 'all';

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-gray-900 mb-2">
            Browse Notes
          </h1>
          <p className="text-gray-600">
            Explore notes shared by professors and students
          </p>
        </div>

        {/* Filters Card */}
        <Card className="mb-6">
          <CardContent className="pt-6">
            <div className="space-y-4">
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

              <div className="flex items-center gap-2">
                <Filter className="h-4 w-4 text-gray-600" />
                <span className="text-sm font-medium text-gray-700">Filters</span>
              </div>

              <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
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

                <div>
                  <label className="text-sm text-gray-600 mb-2 block">Role</label>
                  <Select value={filterRole} onValueChange={handleRoleChange}>
                    <SelectTrigger>
                      <SelectValue placeholder="All Roles" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="all">All Roles</SelectItem>
                      <SelectItem value="professor">Professor</SelectItem>
                      <SelectItem value="student">Student</SelectItem>
                    </SelectContent>
                  </Select>
                </div>

                <div>
                  <label className="text-sm text-gray-600 mb-2 block">Author</label>
                  <Select value={filterAuthor} onValueChange={setFilterAuthor} disabled={loadingAuthors}>
                    <SelectTrigger>
                      <SelectValue placeholder={loadingAuthors ? "Loading..." : "All Authors"} />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="all">All Authors</SelectItem>
                      {availableAuthors.map(author => (
                        <SelectItem key={author.id} value={author.id}>
                          {author.full_name} {author.role === 'professor' ? '(Prof)' : ''}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
              </div>

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

        {groupedNotes.length === 0 ? (
          <Card>
            <CardContent className="py-12 text-center">
              <FileText className="h-16 w-16 text-gray-400 mx-auto mb-4" />
              <h3 className="text-lg font-semibold text-gray-900 mb-2">
                {allGroupedNotes.length === 0 ? 'No notes available' : 'No notes match your filters'}
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
            {displayedGroupedNotes.map((subject, idx) => {
              const subjectKey = `subject-${idx}-${subject.name}`;
              const isSubjectCollapsed = collapsedGroups[subjectKey];

              return (
                <Card key={idx}>
                  {/* Collapsible Subject Header */}
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
                          <CardTitle className="text-xl">{subject.name}</CardTitle>
                          <p className="text-sm text-gray-600 mt-1">
                            {subject.course && <span className="font-medium">{subject.course}</span>}
                            {subject.course && ' \u2022 '}
                            {subject.totalNotes} {subject.totalNotes === 1 ? 'note' : 'notes'}
                            {subject.professorNotes > 0 && ` \u2022 ${subject.professorNotes} from professors`}
                          </p>
                        </div>
                      </div>
                    </div>
                  </CardHeader>

                  {/* Collapsible Subject Content */}
                  {!isSubjectCollapsed && (
                    <CardContent className="pt-4">
                      {subject.topics.map((topic, topicIdx) => {
                        const topicKey = `${subjectKey}-topic-${topicIdx}-${topic.name}`;
                        const isTopicCollapsed = collapsedGroups[topicKey];

                        return (
                          <div key={topicIdx} className="mb-6 last:mb-0">
                            {/* Collapsible Topic Header */}
                            <div
                              className="flex items-center gap-2 mb-3 cursor-pointer select-none group/topic"
                              onClick={() => toggleGroupCollapse(topicKey)}
                            >
                              {isTopicCollapsed ? (
                                <ChevronRight className="h-4 w-4 text-gray-400" />
                              ) : (
                                <ChevronDown className="h-4 w-4 text-gray-400" />
                              )}
                              <h3 className="text-lg font-semibold text-gray-700 group-hover/topic:text-gray-900">
                                {topic.name}
                              </h3>
                              <span className="text-sm text-gray-500">
                                ({topic.notes.length} note{topic.notes.length !== 1 ? 's' : ''})
                              </span>
                            </div>

                            {/* Collapsible Topic Notes */}
                            {!isTopicCollapsed && (
                              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                                {topic.notes.map((note) => (
                                  <div
                                    key={note.id}
                                    className="text-left border border-gray-200 rounded-lg hover:border-blue-300 hover:shadow-md transition-all overflow-hidden group"
                                  >
                                    {/* Clickable Image Area */}
                                    {note.image_url && (
                                      <button
                                        onClick={() => navigate(`/dashboard/notes/${note.id}`)}
                                        className="w-full bg-gray-100"
                                      >
                                        <img
                                          src={note.image_url}
                                          alt={note.title}
                                          className="w-full h-40 object-cover"
                                          loading="lazy"
                                          decoding="async"
                                        />
                                      </button>
                                    )}

                                    {/* Card Content */}
                                    <div className="p-4">
                                      {/* Clickable Title/Description */}
                                      <button
                                        onClick={() => navigate(`/dashboard/notes/${note.id}`)}
                                        className="text-left w-full"
                                      >
                                        <h4 className="font-medium text-gray-900 group-hover:text-blue-700 mb-2 line-clamp-2">
                                          {note.title || 'Untitled Note'}
                                        </h4>

                                        {note.description && (
                                          <p className="text-sm text-gray-600 mb-3 line-clamp-2">
                                            {note.description}
                                          </p>
                                        )}
                                      </button>

                                      {note.tags && note.tags.length > 0 && (
                                        <div className="flex flex-wrap gap-1 mb-3">
                                          {note.tags.slice(0, 2).map((tag, tagIdx) => (
                                            <span
                                              key={tagIdx}
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

                                      {/* Footer with Author, Date, and Upvote */}
                                      <div className="flex items-center justify-between text-xs text-gray-500 pt-2 border-t">
                                        <Link
                                          to={`/dashboard/profile/${note.user_id}`}
                                          className="flex items-center gap-1 hover:text-blue-600 transition-colors"
                                          onClick={(e) => e.stopPropagation()}
                                        >
                                          {note.user?.role === 'professor' && (
                                            <Users className="h-3 w-3 text-purple-600" />
                                          )}
                                          {note.user?.full_name || 'Unknown'}
                                        </Link>

                                        <div className="flex items-center gap-2">
                                          <span>{formatDate(note.created_at)}</span>

                                          {/* Upvote Button */}
                                          <UpvoteButton
                                            contentType="note"
                                            targetId={note.id}
                                            initialCount={note.upvote_count || 0}
                                            ownerId={note.user_id}
                                            size="sm"
                                          />
                                        </div>
                                      </div>
                                    </div>
                                  </div>
                                ))}
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

            {hasMore && (
              <div className="flex justify-center pt-2 pb-4">
                <Button
                  variant="outline"
                  onClick={() => setVisibleCount(prev => prev + NOTES_PER_PAGE)}
                >
                  Load More ({flatFiltered.length - visibleCount} more {flatFiltered.length - visibleCount === 1 ? 'note' : 'notes'})
                </Button>
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
