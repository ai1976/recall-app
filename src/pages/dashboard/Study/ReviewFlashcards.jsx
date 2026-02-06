import { useState, useEffect, useCallback } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Input } from '@/components/ui/input';
import { Brain, Play, ChevronRight, ChevronDown, User, Users, Filter, Search } from 'lucide-react';
import { useAuth } from '@/contexts/AuthContext';
import UpvoteButton from '@/components/ui/UpvoteButton';

export default function ReviewFlashcards() {
  const navigate = useNavigate();
  const { user } = useAuth();
  const [loading, setLoading] = useState(true);
  const [flashcardSets, setFlashcardSets] = useState([]);
  const [allSets, setAllSets] = useState([]);
  const [allDecksFlat, setAllDecksFlat] = useState([]);
  
  const [filterCourse, setFilterCourse] = useState('all');
  const [filterSubject, setFilterSubject] = useState('all');
  const [filterTopic, setFilterTopic] = useState('all');
  const [filterRole, setFilterRole] = useState('all');
  const [filterAuthor, setFilterAuthor] = useState('all');
  const [searchQuery, setSearchQuery] = useState('');
  
  const [availableCourses, setAvailableCourses] = useState([]);
  const [availableSubjects, setAvailableSubjects] = useState([]);
  const [availableTopics, setAvailableTopics] = useState([]);
  const [allTopicsFromDecks, setAllTopicsFromDecks] = useState([]);
  const [availableAuthors, setAvailableAuthors] = useState([]);
  const [loadingAuthors, setLoadingAuthors] = useState(false);

  // Store subject name to ID mapping for RPC calls
  const [subjectNameToId, setSubjectNameToId] = useState({});

  // Collapsed groups state for collapsible sections
  const [collapsedGroups, setCollapsedGroups] = useState({});

  const toggleGroupCollapse = (groupKey) => {
    setCollapsedGroups(prev => ({
      ...prev,
      [groupKey]: !prev[groupKey]
    }));
  };

  useEffect(() => {
    fetchFlashcardSets();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    applyFilters();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [filterCourse, filterSubject, filterTopic, filterRole, filterAuthor, searchQuery, allSets, allDecksFlat]);

  // Dependent topic filtering when subject changes
  useEffect(() => {
    if (filterSubject === 'all') {
      setAvailableTopics(allTopicsFromDecks);
    } else {
      const filteredTopics = allDecksFlat
        .filter(deck => deck.subjectName === filterSubject)
        .map(deck => deck.topicName)
        .filter(Boolean);

      const uniqueTopics = [...new Set(filteredTopics)];
      setAvailableTopics(uniqueTopics);

      if (filterTopic !== 'all' && !uniqueTopics.includes(filterTopic)) {
        setFilterTopic('all');
      }
    }
  }, [filterSubject, allDecksFlat, allTopicsFromDecks, filterTopic]);

  // Fetch filtered authors from server when filters change
  const fetchFilteredAuthors = useCallback(async () => {
    setLoadingAuthors(true);
    try {
      // Get subject_id from subject name
      let subjectId = null;
      if (filterSubject !== 'all' && subjectNameToId[filterSubject]) {
        subjectId = subjectNameToId[filterSubject];
      }

      const { data, error } = await supabase.rpc('get_filtered_authors_for_flashcards', {
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

  const fetchFlashcardSets = async () => {
    try {
      if (!user) return;

      // STEP 1: Get user's accepted friendships
      const { data: friendships } = await supabase
        .from('friendships')
        .select('user_id, friend_id')
        .eq('status', 'accepted')
        .or(`user_id.eq.${user.id},friend_id.eq.${user.id}`);
        
      const friendIds = friendships?.map(f => 
        f.user_id === user.id ? f.friend_id : f.user_id
      ) || [];

      // STEP 2: Fetch flashcard_decks with visibility logic
      let deckQuery = supabase
        .from('flashcard_decks')
        .select(`
          id,
          user_id,
          subject_id,
          custom_subject,
          topic_id,
          custom_topic,
          target_course,
          visibility,
          card_count,
          upvote_count,
          created_at,
          subjects:subject_id (id, name),
          topics:topic_id (id, name)
        `)
        .gt('card_count', 0)
        .order('created_at', { ascending: false });

      // Apply visibility filter for decks
      if (friendIds.length > 0) {
        deckQuery = deckQuery.or(`visibility.eq.public,user_id.eq.${user.id},and(visibility.eq.friends,user_id.in.(${friendIds.join(',')}))`);
      } else {
        deckQuery = deckQuery.or(`visibility.eq.public,user_id.eq.${user.id}`);
      }

      const { data: decksData, error: decksError } = await deckQuery;

      if (decksError) throw decksError;

      // STEP 3: Get user profiles for deck owners
      const ownerIds = [...new Set(decksData?.map(d => d.user_id) || [])];
      const { data: profilesData } = await supabase
        .from('profiles')
        .select('id, full_name, role')
        .in('id', ownerIds);

      // Build subject name to ID mapping
      const nameToIdMap = {};
      decksData?.forEach(deck => {
        if (deck.subjects?.name && deck.subjects?.id) {
          nameToIdMap[deck.subjects.name] = deck.subjects.id;
        }
      });
      setSubjectNameToId(nameToIdMap);

      // STEP 4: Merge deck data with profiles
      const decksWithDetails = (decksData || []).map(deck => ({
        ...deck,
        owner: profilesData?.find(p => p.id === deck.user_id),
        subjectName: deck.subjects?.name || deck.custom_subject || 'Other',
        topicName: deck.topics?.name || deck.custom_topic || 'General'
      }));

      // Store flat decks for topic filtering
      setAllDecksFlat(decksWithDetails);

      // Extract unique courses, subjects, and topics
      const courses = [...new Set(decksWithDetails.map(d => d.target_course).filter(Boolean))];
      const subjects = [...new Set(decksWithDetails.map(d => d.subjectName).filter(Boolean))];
      const topics = [...new Set(decksWithDetails.map(d => d.topicName).filter(Boolean))];

      setAvailableCourses(courses);
      setAvailableSubjects(subjects);
      setAvailableTopics(topics);
      setAllTopicsFromDecks(topics);

      // Group decks by subject
      const grouped = groupDecksBySubject(decksWithDetails);
      setAllSets(grouped);
      setFlashcardSets(grouped);
    } catch (error) {
      console.error('Error fetching flashcard decks:', error);
    } finally {
      setLoading(false);
    }
  };

  const groupDecksBySubject = (decks) => {
    const grouped = {};
    
    decks.forEach(deck => {
      const subjectName = deck.subjectName;
      const isProfessor = deck.owner?.role === 'professor';
      const isOwn = deck.user_id === user.id;
      
      if (!grouped[subjectName]) {
        grouped[subjectName] = {
          name: subjectName,
          course: deck.target_course,
          decks: [],
          totalCards: 0,
          professorCards: 0,
          ownCards: 0
        };
      }
      
      grouped[subjectName].decks.push(deck);
      grouped[subjectName].totalCards += deck.card_count || 0;
      
      if (isProfessor) {
        grouped[subjectName].professorCards += deck.card_count || 0;
      }
      
      if (isOwn) {
        grouped[subjectName].ownCards += deck.card_count || 0;
      }
    });

    return Object.values(grouped);
  };

  const applyFilters = () => {
    let filtered = [...allSets];

    if (filterCourse !== 'all') {
      filtered = filtered.filter(subject => subject.course === filterCourse);
    }

    if (filterSubject !== 'all') {
      filtered = filtered.filter(subject => subject.name === filterSubject);
    }

    // Topic filter - filter decks within subjects
    if (filterTopic !== 'all') {
      filtered = filtered.map(subject => ({
        ...subject,
        decks: subject.decks.filter(deck => deck.topicName === filterTopic),
        totalCards: subject.decks
          .filter(deck => deck.topicName === filterTopic)
          .reduce((sum, deck) => sum + (deck.card_count || 0), 0)
      })).filter(subject => subject.decks.length > 0);
    }

    // Role filter - filter by author role
    if (filterRole === 'professor') {
      filtered = filtered.map(subject => ({
        ...subject,
        decks: subject.decks.filter(deck => deck.owner?.role === 'professor'),
        totalCards: subject.decks
          .filter(deck => deck.owner?.role === 'professor')
          .reduce((sum, deck) => sum + (deck.card_count || 0), 0)
      })).filter(subject => subject.decks.length > 0);
    } else if (filterRole === 'student') {
      filtered = filtered.map(subject => ({
        ...subject,
        decks: subject.decks.filter(deck => deck.owner?.role !== 'professor'),
        totalCards: subject.decks
          .filter(deck => deck.owner?.role !== 'professor')
          .reduce((sum, deck) => sum + (deck.card_count || 0), 0)
      })).filter(subject => subject.decks.length > 0);
    }

    // Author filter - filter by specific author ID
    if (filterAuthor !== 'all') {
      filtered = filtered.map(subject => ({
        ...subject,
        decks: subject.decks.filter(deck => deck.user_id === filterAuthor),
        totalCards: subject.decks
          .filter(deck => deck.user_id === filterAuthor)
          .reduce((sum, deck) => sum + (deck.card_count || 0), 0)
      })).filter(subject => subject.decks.length > 0);
    }

    if (searchQuery.trim() !== '') {
      const query = searchQuery.toLowerCase();
      filtered = filtered.map(subject => ({
        ...subject,
        decks: subject.decks.filter(deck =>
          deck.subjectName?.toLowerCase().includes(query) ||
          deck.topicName?.toLowerCase().includes(query) ||
          deck.owner?.full_name?.toLowerCase().includes(query)
        )
      })).filter(subject => subject.decks.length > 0);
    }

    setFlashcardSets(filtered);
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

  const startStudySession = (subjectName, topicName = null) => {
    const params = new URLSearchParams();
    params.set('subject', subjectName);
    if (topicName) {
      params.set('topic', topicName);
    }
    navigate(`/dashboard/study?${params.toString()}`);
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  const totalCards = flashcardSets.reduce((sum, subject) => sum + subject.totalCards, 0);
  const hasActiveFilters = searchQuery || filterCourse !== 'all' || filterSubject !== 'all' || filterTopic !== 'all' || filterRole !== 'all' || filterAuthor !== 'all';

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-gray-900 mb-2">
            Review Flashcards
          </h1>
          <p className="text-gray-600">
            Choose a subject or topic to start your study session
          </p>
        </div>

        <Card className="mb-6">
          <CardContent className="pt-6">
            <div className="space-y-4">
              <div className="relative">
                <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
                <Input
                  type="text"
                  placeholder="Search flashcards by subject, topic, or author..."
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
            {flashcardSets.map((subject, idx) => {
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
                            {subject.totalCards} total cards
                            {subject.professorCards > 0 && ` \u2022 ${subject.professorCards} from professors`}
                            {subject.ownCards > 0 && ` \u2022 ${subject.ownCards} yours`}
                          </p>
                        </div>
                      </div>
                      <Button
                        onClick={(e) => { e.stopPropagation(); startStudySession(subject.name); }}
                        className="gap-2"
                      >
                        <Play className="h-4 w-4" />
                        Study All ({subject.totalCards})
                      </Button>
                    </div>
                  </CardHeader>

                  {/* Collapsible Subject Content */}
                  {!isSubjectCollapsed && (
                    <CardContent className="pt-4">
                      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                        {subject.decks.map((deck) => (
                          <div
                            key={deck.id}
                            className="text-left p-4 border border-gray-200 rounded-lg hover:border-blue-300 hover:bg-blue-50 transition-colors group"
                          >
                            {/* Clickable Study Area */}
                            <button
                              onClick={() => startStudySession(subject.name, deck.topicName)}
                              className="w-full text-left"
                            >
                              <div className="flex items-start justify-between mb-2">
                                <div className="flex-1">
                                  <h4 className="font-medium text-gray-900 group-hover:text-blue-700">
                                    {deck.topicName}
                                  </h4>
                                  <p className="text-sm text-gray-600 mt-1">
                                    {deck.card_count} cards
                                  </p>
                                </div>
                                <ChevronRight className="h-5 w-5 text-gray-400 group-hover:text-blue-600 flex-shrink-0" />
                              </div>
                            </button>

                            {/* Author name (clickable) */}
                            {deck.owner && (
                              <p className="text-xs text-gray-400 mt-1">
                                by{' '}
                                <Link
                                  to={`/dashboard/profile/${deck.user_id}`}
                                  className="hover:text-blue-600 transition-colors"
                                  onClick={(e) => e.stopPropagation()}
                                >
                                  {deck.owner.full_name}
                                </Link>
                              </p>
                            )}

                            {/* Footer with badges and upvote */}
                            <div className="flex items-center justify-between mt-3 pt-2 border-t border-gray-100">
                              <div className="flex gap-2 flex-wrap">
                                {deck.owner?.role === 'professor' && (
                                  <span className="inline-flex items-center gap-1 px-2 py-1 bg-purple-100 text-purple-700 text-xs rounded">
                                    <Users className="h-3 w-3" />
                                    Verified
                                  </span>
                                )}
                                {deck.user_id === user.id && (
                                  <span className="inline-flex items-center gap-1 px-2 py-1 bg-blue-100 text-blue-700 text-xs rounded">
                                    <User className="h-3 w-3" />
                                    Yours
                                  </span>
                                )}
                              </div>

                              {/* Upvote Button for Deck */}
                              <UpvoteButton
                                contentType="flashcard_deck"
                                targetId={deck.id}
                                initialCount={deck.upvote_count || 0}
                                ownerId={deck.user_id}
                                size="sm"
                              />
                            </div>
                          </div>
                        ))}
                      </div>
                    </CardContent>
                  )}
                </Card>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
