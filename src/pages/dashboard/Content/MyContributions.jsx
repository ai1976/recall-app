import { useState, useEffect } from 'react';
import { BarChart3, FileText, CreditCard, ThumbsUp, TrendingUp, Users, Heart, ChevronDown, ChevronUp, User } from 'lucide-react';
import { supabase } from '@/lib/supabase';
import { useNavigate } from 'react-router-dom';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { useAuth } from '@/contexts/AuthContext';

export default function MyContributions() {
  const navigate = useNavigate();
  const { user } = useAuth();
  const [loading, setLoading] = useState(true);
  const [stats, setStats] = useState({
    notesCount: 0,
    flashcardsCount: 0,
    decksCount: 0,
    totalNoteUpvotes: 0,
    totalDeckUpvotes: 0,
    uniqueUpvoters: 0,
    topNotes: [],
    topDecks: [],
    upvotersList: []
  });
  
  // Track which items have expanded upvoter lists
  const [expandedNotes, setExpandedNotes] = useState({});
  const [expandedDecks, setExpandedDecks] = useState({});

  useEffect(() => {
    fetchContributions();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const fetchContributions = async () => {
    try {
      if (!user) {
        navigate('/login');
        return;
      }

      // Fetch notes for THIS user
      const { data: notesData, error: notesError } = await supabase
        .from('notes')
        .select('id, title, upvote_count, created_at')
        .eq('user_id', user.id)
        .order('upvote_count', { ascending: false });

      if (notesError) throw notesError;

      // Fetch flashcards count for THIS user
      const { count: flashcardsCount } = await supabase
        .from('flashcards')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', user.id);

      // Fetch flashcard_decks for THIS user
      const { data: decksData, error: decksError } = await supabase
        .from('flashcard_decks')
        .select(`
          id, 
          custom_subject, 
          custom_topic, 
          card_count, 
          upvote_count,
          subject_id,
          topic_id,
          subjects:subject_id (name),
          topics:topic_id (name)
        `)
        .eq('user_id', user.id)
        .gt('card_count', 0)
        .order('upvote_count', { ascending: false });

      if (decksError) throw decksError;

      // Calculate total upvotes
      const totalNoteUpvotes = notesData?.reduce((sum, note) => sum + (note.upvote_count || 0), 0) || 0;
      const totalDeckUpvotes = decksData?.reduce((sum, deck) => sum + (deck.upvote_count || 0), 0) || 0;

      // Get all content IDs for upvote lookup
      const noteIds = notesData?.map(n => n.id) || [];
      const deckIds = decksData?.map(d => d.id) || [];
      const allContentIds = [...noteIds, ...deckIds];

      // Fetch upvotes (WHO upvoted) - separate query approach for reliability
      let upvotersData = [];
      
      if (allContentIds.length > 0) {
        // First, get all upvotes for this user's content
        const { data: upvotesRaw, error: upvotesError } = await supabase
          .from('upvotes')
          .select('id, user_id, content_type, target_id, created_at')
          .in('target_id', allContentIds)
          .order('created_at', { ascending: false });

        if (upvotesError) {
          console.error('Error fetching upvotes:', upvotesError);
        }

        if (upvotesRaw && upvotesRaw.length > 0) {
          // Get unique upvoter IDs
          const upvoterIds = [...new Set(upvotesRaw.map(u => u.user_id))];
          
          // Fetch profiles for all upvoters
          const { data: profilesData, error: profilesError } = await supabase
            .from('profiles')
            .select('id, full_name, role')
            .in('id', upvoterIds);

          if (profilesError) {
            console.error('Error fetching profiles:', profilesError);
          }

          // Merge upvotes with profile data
          upvotersData = upvotesRaw.map(upvote => ({
            ...upvote,
            profile: profilesData?.find(p => p.id === upvote.user_id) || null
          }));
        }
      }

      // Get unique upvoters count
      const uniqueUpvoters = new Set(upvotersData.map(u => u.user_id)).size;

      // Format top notes with upvoter details (max 5 with upvotes > 0)
      const topNotes = notesData
        ?.filter(note => (note.upvote_count || 0) > 0)
        .slice(0, 5)
        .map(note => {
          const noteUpvoters = upvotersData
            .filter(u => u.target_id === note.id && u.content_type === 'note')
            .map(u => ({
              id: u.user_id,
              name: u.profile?.full_name || 'Unknown',
              role: u.profile?.role || 'student',
              upvotedAt: u.created_at
            }));
          
          return {
            id: note.id,
            title: note.title || 'Untitled Note',
            upvotes: note.upvote_count || 0,
            upvoters: noteUpvoters
          };
        }) || [];

      // Format top decks with upvoter details (max 5 with upvotes > 0)
      const topDecks = decksData
        ?.filter(deck => (deck.upvote_count || 0) > 0)
        .slice(0, 5)
        .map(deck => {
          const deckUpvoters = upvotersData
            .filter(u => u.target_id === deck.id && u.content_type === 'flashcard_deck')
            .map(u => ({
              id: u.user_id,
              name: u.profile?.full_name || 'Unknown',
              role: u.profile?.role || 'student',
              upvotedAt: u.created_at
            }));
          
          return {
            id: deck.id,
            title: `${deck.subjects?.name || deck.custom_subject || 'Other'} - ${deck.topics?.name || deck.custom_topic || 'General'}`,
            upvotes: deck.upvote_count || 0,
            cardCount: deck.card_count || 0,
            upvoters: deckUpvoters
          };
        }) || [];

      // Create overall upvoters list (for summary)
      const upvotersList = Array.from(
        new Map(upvotersData.map(u => [u.user_id, {
          id: u.user_id,
          name: u.profile?.full_name || 'Unknown',
          role: u.profile?.role || 'student'
        }])).values()
      );

      console.log('📊 MyContributions Debug:', {
        noteIds,
        deckIds,
        upvotersDataCount: upvotersData.length,
        uniqueUpvoters,
        topNotesWithUpvoters: topNotes.map(n => ({ title: n.title, upvoterCount: n.upvoters.length })),
        topDecksWithUpvoters: topDecks.map(d => ({ title: d.title, upvoterCount: d.upvoters.length }))
      });

      setStats({
        notesCount: notesData?.length || 0,
        flashcardsCount: flashcardsCount || 0,
        decksCount: decksData?.length || 0,
        totalNoteUpvotes,
        totalDeckUpvotes,
        uniqueUpvoters,
        topNotes,
        topDecks,
        upvotersList
      });
    } catch (error) {
      console.error('Error fetching contributions:', error);
    } finally {
      setLoading(false);
    }
  };

  const toggleNoteExpand = (noteId) => {
    setExpandedNotes(prev => ({
      ...prev,
      [noteId]: !prev[noteId]
    }));
  };

  const toggleDeckExpand = (deckId) => {
    setExpandedDecks(prev => ({
      ...prev,
      [deckId]: !prev[deckId]
    }));
  };

  const formatDate = (dateString) => {
    const date = new Date(dateString);
    return date.toLocaleDateString('en-IN', { day: 'numeric', month: 'short' });
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary"></div>
      </div>
    );
  }

  const totalUpvotes = stats.totalNoteUpvotes + stats.totalDeckUpvotes;
  const hasUpvotes = totalUpvotes > 0;

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      {/* Header */}
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900 flex items-center gap-2">
          <BarChart3 className="h-8 w-8 text-blue-600" />
          My Contributions
        </h1>
        <p className="mt-2 text-gray-600">
          View your content and see how it's helping other students
        </p>
      </div>

      {/* Content Stats */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        <Card 
          className="cursor-pointer hover:shadow-lg transition"
          onClick={() => navigate('/dashboard/my-notes')}
        >
          <CardContent className="pt-6">
            <div className="flex items-center gap-4">
              <div className="p-3 bg-blue-100 rounded-lg">
                <FileText className="h-8 w-8 text-blue-600" />
              </div>
              <div>
                <p className="text-3xl font-bold text-gray-900">{stats.notesCount}</p>
                <p className="text-sm text-gray-600">Notes Uploaded</p>
              </div>
            </div>
          </CardContent>
        </Card>

        <Card 
          className="cursor-pointer hover:shadow-lg transition"
          onClick={() => navigate('/dashboard/flashcards')}
        >
          <CardContent className="pt-6">
            <div className="flex items-center gap-4">
              <div className="p-3 bg-purple-100 rounded-lg">
                <CreditCard className="h-8 w-8 text-purple-600" />
              </div>
              <div>
                <p className="text-3xl font-bold text-gray-900">{stats.flashcardsCount}</p>
                <p className="text-sm text-gray-600">Flashcards Created</p>
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="pt-6">
            <div className="flex items-center gap-4">
              <div className="p-3 bg-green-100 rounded-lg">
                <TrendingUp className="h-8 w-8 text-green-600" />
              </div>
              <div>
                <p className="text-3xl font-bold text-gray-900">{stats.decksCount}</p>
                <p className="text-sm text-gray-600">Flashcard Decks</p>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Community Feedback Section */}
      <Card className="mb-8">
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Heart className="h-6 w-6 text-red-500" />
            Community Feedback
          </CardTitle>
        </CardHeader>
        <CardContent>
          {hasUpvotes ? (
            <div className="space-y-6">
              {/* Impact Message */}
              <div className="bg-gradient-to-r from-blue-50 to-purple-50 rounded-lg p-6 border border-blue-100">
                <div className="flex items-center gap-4">
                  <div className="p-4 bg-white rounded-full shadow-sm">
                    <ThumbsUp className="h-10 w-10 text-blue-600" />
                  </div>
                  <div>
                    <p className="text-2xl font-bold text-gray-900">
                      Your content helped {stats.uniqueUpvoters} {stats.uniqueUpvoters === 1 ? 'student' : 'students'}!
                    </p>
                    <p className="text-gray-600 mt-1">
                      You've received {totalUpvotes} total {totalUpvotes === 1 ? 'upvote' : 'upvotes'} across all your content
                    </p>
                  </div>
                </div>
              </div>

              {/* Who Upvoted Summary */}
              {stats.upvotersList.length > 0 && (
                <div className="bg-green-50 border border-green-200 rounded-lg p-4">
                  <h3 className="text-sm font-semibold text-green-800 mb-3 flex items-center gap-2">
                    <Users className="h-4 w-4" />
                    Students Who Appreciated Your Content
                  </h3>
                  <div className="flex flex-wrap gap-2">
                    {stats.upvotersList.map((upvoter) => (
                      <span 
                        key={upvoter.id}
                        className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-white border border-green-200 rounded-full text-sm"
                      >
                        <User className="h-3.5 w-3.5 text-gray-500" />
                        <span className="text-gray-700">{upvoter.name}</span>
                        {upvoter.role === 'professor' && (
                          <span className="text-xs bg-purple-100 text-purple-700 px-1.5 py-0.5 rounded">
                            Prof
                          </span>
                        )}
                      </span>
                    ))}
                  </div>
                </div>
              )}

              {/* Upvote Breakdown */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div className="flex items-center gap-3 p-4 bg-gray-50 rounded-lg">
                  <FileText className="h-6 w-6 text-blue-600" />
                  <div>
                    <p className="text-xl font-semibold text-gray-900">{stats.totalNoteUpvotes}</p>
                    <p className="text-sm text-gray-600">Note Upvotes</p>
                  </div>
                </div>
                <div className="flex items-center gap-3 p-4 bg-gray-50 rounded-lg">
                  <CreditCard className="h-6 w-6 text-purple-600" />
                  <div>
                    <p className="text-xl font-semibold text-gray-900">{stats.totalDeckUpvotes}</p>
                    <p className="text-sm text-gray-600">Flashcard Deck Upvotes</p>
                  </div>
                </div>
              </div>

              {/* Top Performing Content */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                {/* Top Notes */}
                {stats.topNotes.length > 0 && (
                  <div>
                    <h3 className="text-sm font-semibold text-gray-700 uppercase tracking-wide mb-3">
                      Top Performing Notes
                    </h3>
                    <div className="space-y-2">
                      {stats.topNotes.map((note, idx) => (
                        <div key={note.id} className="border border-gray-200 rounded-lg overflow-hidden">
                          {/* Note Row */}
                          <div className="flex items-center justify-between p-3 bg-white hover:bg-gray-50">
                            <button
                              onClick={() => navigate(`/dashboard/notes/${note.id}`)}
                              className="flex items-center gap-3 flex-1 text-left min-w-0"
                            >
                              <span className="text-lg font-bold text-gray-400 flex-shrink-0">#{idx + 1}</span>
                              <span className="text-gray-900 font-medium truncate">
                                {note.title}
                              </span>
                            </button>
                            <div className="flex items-center gap-2 flex-shrink-0 ml-2">
                              <div className="flex items-center gap-1 text-blue-600">
                                <ThumbsUp className="h-4 w-4" />
                                <span className="font-semibold">{note.upvotes}</span>
                              </div>
                              {/* Expand button to see who upvoted */}
                              {note.upvoters.length > 0 && (
                                <button
                                  onClick={(e) => {
                                    e.stopPropagation();
                                    toggleNoteExpand(note.id);
                                  }}
                                  className="p-1.5 hover:bg-gray-100 rounded border border-gray-200"
                                  title="See who upvoted"
                                >
                                  {expandedNotes[note.id] ? (
                                    <ChevronUp className="h-4 w-4 text-gray-600" />
                                  ) : (
                                    <ChevronDown className="h-4 w-4 text-gray-600" />
                                  )}
                                </button>
                              )}
                            </div>
                          </div>
                          
                          {/* Expanded Upvoters List */}
                          {expandedNotes[note.id] && note.upvoters.length > 0 && (
                            <div className="px-3 pb-3 pt-2 bg-blue-50 border-t border-blue-100">
                              <p className="text-xs text-gray-500 mb-2 font-medium">Upvoted by:</p>
                              <div className="flex flex-wrap gap-1.5">
                                {note.upvoters.map((upvoter, upvoterIdx) => (
                                  <span 
                                    key={`${upvoter.id}-${upvoterIdx}`}
                                    className="inline-flex items-center gap-1 px-2 py-1 bg-white border border-blue-200 rounded text-xs"
                                  >
                                    <User className="h-3 w-3 text-gray-400" />
                                    <span className="font-medium">{upvoter.name}</span>
                                    <span className="text-gray-400">• {formatDate(upvoter.upvotedAt)}</span>
                                  </span>
                                ))}
                              </div>
                            </div>
                          )}
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                {/* Top Decks */}
                {stats.topDecks.length > 0 && (
                  <div>
                    <h3 className="text-sm font-semibold text-gray-700 uppercase tracking-wide mb-3">
                      Top Performing Decks
                    </h3>
                    <div className="space-y-2">
                      {stats.topDecks.map((deck, idx) => (
                        <div key={deck.id} className="border border-gray-200 rounded-lg overflow-hidden">
                          {/* Deck Row */}
                          <div className="flex items-center justify-between p-3 bg-white">
                            <div className="flex items-center gap-3 flex-1 min-w-0">
                              <span className="text-lg font-bold text-gray-400 flex-shrink-0">#{idx + 1}</span>
                              <div className="min-w-0">
                                <span className="text-gray-900 font-medium block truncate">
                                  {deck.title}
                                </span>
                                <span className="text-xs text-gray-500">{deck.cardCount} cards</span>
                              </div>
                            </div>
                            <div className="flex items-center gap-2 flex-shrink-0 ml-2">
                              <div className="flex items-center gap-1 text-purple-600">
                                <ThumbsUp className="h-4 w-4" />
                                <span className="font-semibold">{deck.upvotes}</span>
                              </div>
                              {/* Expand button to see who upvoted */}
                              {deck.upvoters.length > 0 && (
                                <button
                                  onClick={(e) => {
                                    e.stopPropagation();
                                    toggleDeckExpand(deck.id);
                                  }}
                                  className="p-1.5 hover:bg-gray-100 rounded border border-gray-200"
                                  title="See who upvoted"
                                >
                                  {expandedDecks[deck.id] ? (
                                    <ChevronUp className="h-4 w-4 text-gray-600" />
                                  ) : (
                                    <ChevronDown className="h-4 w-4 text-gray-600" />
                                  )}
                                </button>
                              )}
                            </div>
                          </div>
                          
                          {/* Expanded Upvoters List */}
                          {expandedDecks[deck.id] && deck.upvoters.length > 0 && (
                            <div className="px-3 pb-3 pt-2 bg-purple-50 border-t border-purple-100">
                              <p className="text-xs text-gray-500 mb-2 font-medium">Upvoted by:</p>
                              <div className="flex flex-wrap gap-1.5">
                                {deck.upvoters.map((upvoter, upvoterIdx) => (
                                  <span 
                                    key={`${upvoter.id}-${upvoterIdx}`}
                                    className="inline-flex items-center gap-1 px-2 py-1 bg-white border border-purple-200 rounded text-xs"
                                  >
                                    <User className="h-3 w-3 text-gray-400" />
                                    <span className="font-medium">{upvoter.name}</span>
                                    <span className="text-gray-400">• {formatDate(upvoter.upvotedAt)}</span>
                                  </span>
                                ))}
                              </div>
                            </div>
                          )}
                        </div>
                      ))}
                    </div>
                  </div>
                )}
              </div>
            </div>
          ) : (
            <div className="text-center py-8">
              <div className="p-4 bg-gray-100 rounded-full w-fit mx-auto mb-4">
                <Users className="h-12 w-12 text-gray-400" />
              </div>
              <h3 className="text-lg font-semibold text-gray-900 mb-2">
                No upvotes yet
              </h3>
              <p className="text-gray-600 mb-6 max-w-md mx-auto">
                Share your notes and flashcards with the community to start receiving feedback! 
                Make your content public or share with friends.
              </p>
              <div className="flex justify-center gap-4">
                <Button 
                  variant="outline"
                  onClick={() => navigate('/dashboard/notes/new')}
                >
                  <FileText className="h-4 w-4 mr-2" />
                  Upload Note
                </Button>
                <Button 
                  onClick={() => navigate('/dashboard/flashcards/new')}
                >
                  <CreditCard className="h-4 w-4 mr-2" />
                  Create Flashcard
                </Button>
              </div>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Quick Actions */}
      <Card>
        <CardHeader>
          <CardTitle>Quick Actions</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            <Button 
              variant="outline" 
              className="h-auto py-4 flex flex-col gap-2"
              onClick={() => navigate('/dashboard/notes/new')}
            >
              <FileText className="h-6 w-6 text-blue-600" />
              <span>Upload Note</span>
            </Button>
            <Button 
              variant="outline" 
              className="h-auto py-4 flex flex-col gap-2"
              onClick={() => navigate('/dashboard/flashcards/new')}
            >
              <CreditCard className="h-6 w-6 text-purple-600" />
              <span>Create Flashcard</span>
            </Button>
            <Button 
              variant="outline" 
              className="h-auto py-4 flex flex-col gap-2"
              onClick={() => navigate('/dashboard/my-notes')}
            >
              <FileText className="h-6 w-6 text-gray-600" />
              <span>View My Notes</span>
            </Button>
            <Button 
              variant="outline" 
              className="h-auto py-4 flex flex-col gap-2"
              onClick={() => navigate('/dashboard/flashcards')}
            >
              <CreditCard className="h-6 w-6 text-gray-600" />
              <span>View Flashcards</span>
            </Button>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}