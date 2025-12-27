import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Input } from '@/components/ui/input';
import { Brain, Play, ChevronRight, User, Users, Filter, Search } from 'lucide-react';
import { useAuth } from '@/contexts/AuthContext';

export default function ReviewFlashcards() {
  const navigate = useNavigate();
  const { user } = useAuth();
  const [loading, setLoading] = useState(true);
  const [flashcardSets, setFlashcardSets] = useState([]);
  const [allSets, setAllSets] = useState([]);
  
  // Filter states
  const [filterCourse, setFilterCourse] = useState('all');
  const [filterSubject, setFilterSubject] = useState('all');
  const [filterAuthor, setFilterAuthor] = useState('all');
  const [searchQuery, setSearchQuery] = useState('');
  
  const [availableCourses, setAvailableCourses] = useState([]);
  const [availableSubjects, setAvailableSubjects] = useState([]);

  useEffect(() => {
    fetchFlashcardSets();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    applyFilters();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [filterCourse, filterSubject, filterAuthor, searchQuery, allSets]);

  const fetchFlashcardSets = async () => {
    try {
      if (!user) return;

      // Fetch all public flashcards + user's own flashcards
      const { data, error } = await supabase
        .from('flashcards')
        .select(`
          id,
          user_id,
          contributed_by,
          target_course,
          subject_id,
          custom_subject,
          topic_id,
          custom_topic,
          difficulty,
          is_verified,
          front_text,
          back_text,
          subjects:subject_id (id, name),
          topics:topic_id (id, name),
          contributors:contributed_by (id, full_name, role)
        `)
        .or(`is_public.eq.true,user_id.eq.${user.id}`);

      if (error) throw error;

      // Clean diamond characters from text
      const cleanedData = (data || []).map(card => ({
        ...card,
        front_text: card.front_text?.replace(/[\u25C6\u2666◆�]/g, '').trim() || '',
        back_text: card.back_text?.replace(/[\u25C6\u2666◆�]/g, '').trim() || '',
        custom_subject: card.custom_subject?.replace(/[\u25C6\u2666◆�]/g, '').trim() || null,
        custom_topic: card.custom_topic?.replace(/[\u25C6\u2666◆�]/g, '').trim() || null
      }));

      // Extract unique courses and subjects
      const courses = [...new Set(cleanedData.map(card => card.target_course).filter(Boolean))];
      const subjects = [...new Set(cleanedData.map(card => 
        card.subjects?.name || card.custom_subject
      ).filter(Boolean))];

      setAvailableCourses(courses);
      setAvailableSubjects(subjects);

      // Group by subject
      const grouped = groupFlashcards(cleanedData);
      setAllSets(grouped);
      setFlashcardSets(grouped);
    } catch (error) {
      console.error('Error fetching flashcards:', error);
    } finally {
      setLoading(false);
    }
  };

  const groupFlashcards = (data) => {
    const grouped = {};
    
    data.forEach(card => {
      const subjectName = card.subjects?.name || card.custom_subject || 'Other';
      const topicName = card.topics?.name || card.custom_topic || 'General';
      const isProfessor = card.contributors?.role === 'professor';
      const isOwn = card.user_id === user.id;
      
      if (!grouped[subjectName]) {
        grouped[subjectName] = {
          name: subjectName,
          course: card.target_course,
          topics: {},
          totalCards: 0,
          professorCards: 0,
          ownCards: 0
        };
      }
      
      if (!grouped[subjectName].topics[topicName]) {
        grouped[subjectName].topics[topicName] = {
          name: topicName,
          cards: [],
          professorCards: 0,
          ownCards: 0
        };
      }
      
      grouped[subjectName].topics[topicName].cards.push(card);
      grouped[subjectName].totalCards++;
      
      if (isProfessor) {
        grouped[subjectName].professorCards++;
        grouped[subjectName].topics[topicName].professorCards++;
      }
      
      if (isOwn) {
        grouped[subjectName].ownCards++;
        grouped[subjectName].topics[topicName].ownCards++;
      }
    });

    // Convert to array
    return Object.values(grouped).map(subject => ({
      ...subject,
      topics: Object.values(subject.topics)
    }));
  };

  const applyFilters = () => {
    let filtered = [...allSets];

    // Filter by course
    if (filterCourse !== 'all') {
      filtered = filtered.filter(subject => subject.course === filterCourse);
    }

    // Filter by subject
    if (filterSubject !== 'all') {
      filtered = filtered.filter(subject => subject.name === filterSubject);
    }

    // Filter by author (professor/student)
    if (filterAuthor === 'professor') {
      filtered = filtered.map(subject => ({
        ...subject,
        topics: subject.topics.map(topic => ({
          ...topic,
          cards: topic.cards.filter(card => card.contributors?.role === 'professor')
        })).filter(topic => topic.cards.length > 0),
        totalCards: subject.topics.reduce((sum, topic) => 
          sum + topic.cards.filter(card => card.contributors?.role === 'professor').length, 0
        )
      })).filter(subject => subject.topics.length > 0);
    } else if (filterAuthor === 'student') {
      filtered = filtered.map(subject => ({
        ...subject,
        topics: subject.topics.map(topic => ({
          ...topic,
          cards: topic.cards.filter(card => card.contributors?.role !== 'professor')
        })).filter(topic => topic.cards.length > 0),
        totalCards: subject.topics.reduce((sum, topic) => 
          sum + topic.cards.filter(card => card.contributors?.role !== 'professor').length, 0
        )
      })).filter(subject => subject.topics.length > 0);
    }

    // Filter by search query
    if (searchQuery.trim() !== '') {
      const query = searchQuery.toLowerCase();
      filtered = filtered.map(subject => ({
        ...subject,
        topics: subject.topics.map(topic => ({
          ...topic,
          cards: topic.cards.filter(card =>
            card.front_text?.toLowerCase().includes(query) ||
            card.back_text?.toLowerCase().includes(query) ||
            card.contributors?.full_name?.toLowerCase().includes(query)
          )
        })).filter(topic => topic.cards.length > 0)
      })).filter(subject => subject.topics.length > 0);
    }

    setFlashcardSets(filtered);
  };

  const startStudySession = (subjectName, topicName = null) => {
    const params = new URLSearchParams();
    params.set('subject', subjectName);
    if (topicName && topicName !== 'General') {
      params.set('topic', topicName);
    }
    navigate(`/dashboard/study?${params.toString()}`);
  };

  const clearAllFilters = () => {
    setSearchQuery('');
    setFilterCourse('all');
    setFilterSubject('all');
    setFilterAuthor('all');
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  const totalCards = flashcardSets.reduce((sum, subject) => sum + subject.totalCards, 0);
  const hasActiveFilters = searchQuery || filterCourse !== 'all' || filterSubject !== 'all' || filterAuthor !== 'all';

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Header */}
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-gray-900 mb-2">
            Review Flashcards
          </h1>
          <p className="text-gray-600">
            Choose a subject or topic to start your study session
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
                  placeholder="Search flashcards by question, answer, or author..."
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
                  {totalCards} {totalCards === 1 ? 'card' : 'cards'} available
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
        {flashcardSets.length === 0 ? (
          <Card>
            <CardContent className="py-12 text-center">
              <Brain className="h-16 w-16 text-gray-400 mx-auto mb-4" />
              <h3 className="text-lg font-semibold text-gray-900 mb-2">
                {allSets.length === 0 ? 'No flashcards available' : 'No flashcards match your filters'}
              </h3>
              <p className="text-gray-600 mb-6">
                {allSets.length === 0 
                  ? 'Create your first flashcard or wait for professor content'
                  : 'Try adjusting your filters or search query'
                }
              </p>
              {allSets.length === 0 ? (
                <Button onClick={() => navigate('/dashboard/flashcards/new')}>
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
          <div className="space-y-6">
            {flashcardSets.map((subject, idx) => (
              <Card key={idx}>
                <CardHeader>
                  <div className="flex items-center justify-between">
                    <div>
                      <CardTitle className="text-xl">{subject.name}</CardTitle>
                      <p className="text-sm text-gray-600 mt-1">
                        {subject.course && <span className="font-medium">{subject.course}</span>}
                        {subject.course && ' • '}
                        {subject.totalCards} total cards
                        {subject.professorCards > 0 && ` • ${subject.professorCards} from professors`}
                        {subject.ownCards > 0 && ` • ${subject.ownCards} yours`}
                      </p>
                    </div>
                    <Button
                      onClick={() => startStudySession(subject.name)}
                      className="gap-2"
                    >
                      <Play className="h-4 w-4" />
                      Study All ({subject.totalCards})
                    </Button>
                  </div>
                </CardHeader>
                <CardContent>
                  <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                    {subject.topics.map((topic, topicIdx) => (
                      <button
                        key={topicIdx}
                        onClick={() => startStudySession(subject.name, topic.name)}
                        className="text-left p-4 border border-gray-200 rounded-lg hover:border-blue-300 hover:bg-blue-50 transition-colors group"
                      >
                        <div className="flex items-start justify-between mb-2">
                          <div className="flex-1">
                            <h4 className="font-medium text-gray-900 group-hover:text-blue-700">
                              {topic.name}
                            </h4>
                            <p className="text-sm text-gray-600 mt-1">
                              {topic.cards.length} cards
                            </p>
                          </div>
                          <ChevronRight className="h-5 w-5 text-gray-400 group-hover:text-blue-600" />
                        </div>
                        
                        {/* Badges */}
                        <div className="flex gap-2 flex-wrap">
                          {topic.professorCards > 0 && (
                            <span className="inline-flex items-center gap-1 px-2 py-1 bg-purple-100 text-purple-700 text-xs rounded">
                              <Users className="h-3 w-3" />
                              {topic.professorCards} verified
                            </span>
                          )}
                          {topic.ownCards > 0 && (
                            <span className="inline-flex items-center gap-1 px-2 py-1 bg-blue-100 text-blue-700 text-xs rounded">
                              <User className="h-3 w-3" />
                              {topic.ownCards} yours
                            </span>
                          )}
                        </div>
                      </button>
                    ))}
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