import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { useRole } from '@/hooks/useRole';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Alert, AlertDescription } from '@/components/ui/alert';
import {
  Users, FileText, AlertCircle, TrendingUp, XCircle, CreditCard,
  ChevronDown, ChevronUp, ExternalLink,
} from 'lucide-react';

export default function AdminDashboard() {
  const { isAdmin, isSuperAdmin, isLoading: roleLoading } = useRole();

  const [stats,       setStats]       = useState(null);
  const [notes,       setNotes]       = useState([]);
  const [decks,       setDecks]       = useState([]);
  const [creatorsMap, setCreatorsMap] = useState({}); // { userId: fullName }
  const [recentUsers, setRecentUsers] = useState([]);
  const [isLoading,   setIsLoading]   = useState(true);

  // ── State-based tab switching (tabs.jsx is a broken stub — never use it)
  const [activeTab, setActiveTab] = useState('content');

  // ── Access Requests state
  const [accessRequests, setAccessRequests] = useState([]);
  const [accessRequestsLoading, setAccessRequestsLoading] = useState(false);

  // ── Load-more limits
  const [notesLimit, setNotesLimit] = useState(10);
  const [decksLimit, setDecksLimit] = useState(10);
  const [usersLimit, setUsersLimit] = useState(20);

  // ── Inline deck preview (one open at a time)
  const [previewDeckId,   setPreviewDeckId]   = useState(null);
  const [previewCards,    setPreviewCards]    = useState([]);
  const [previewLoading,  setPreviewLoading]  = useState(false);

  useEffect(() => {
    if (!roleLoading && (isAdmin || isSuperAdmin)) {
      fetchAll();
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isAdmin, isSuperAdmin, roleLoading]);

  useEffect(() => {
    if (!roleLoading && (isAdmin || isSuperAdmin)) {
      fetchContent();
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [notesLimit, decksLimit]);

  useEffect(() => {
    if (!roleLoading && (isAdmin || isSuperAdmin)) {
      fetchUsers();
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [usersLimit]);

  async function fetchAll() {
    setIsLoading(true);
    await Promise.all([fetchStats(), fetchContent(), fetchUsers()]);
    setIsLoading(false);
  }

  async function fetchStats() {
    try {
      // Use get_platform_stats RPC (SECURITY DEFINER) for accurate totals — bypasses RLS
      // Direct table queries are RLS-limited and undercount (e.g. flashcards shows only public)
      const [platformRes, profilesRes, pendingRes] = await Promise.all([
        supabase.rpc('get_platform_stats'),
        supabase.from('profiles').select('created_at'),
        supabase.from('notes').select('*', { count: 'exact', head: true })
          .eq('visibility', 'public'),
      ]);

      const platform    = platformRes.data ?? {};
      const profiles    = profilesRes.data ?? [];
      const pendingCount = pendingRes.count ?? 0;

      const lastWeek = new Date();
      lastWeek.setDate(lastWeek.getDate() - 7);

      setStats({
        totalUsers:       (platform.student_count ?? 0) + (platform.educator_count ?? 0),
        newUsersThisWeek: profiles.filter(p => new Date(p.created_at) > lastWeek).length,
        totalNotes:       platform.total_notes ?? 0,
        publicNotes:      pendingCount,
        totalFlashcards:  platform.total_flashcards ?? 0,
        publicFlashcards: 0, // not shown in stat cards
        pendingReview:    pendingCount,
      });
    } catch (err) {
      console.error('AdminDashboard fetchStats:', err);
    }
  }

  async function fetchContent() {
    try {
      const [notesRes, decksRes] = await Promise.all([
        supabase
          .from('notes')
          .select('id, title, target_course, created_at, view_count, user_id')
          .eq('visibility', 'public')
          .order('created_at', { ascending: false })
          .limit(notesLimit),
        supabase
          .from('flashcard_decks')
          .select('id, name, description, target_course, card_count, created_at, user_id, subject_id, topic_id, custom_subject, custom_topic')
          .eq('visibility', 'public')
          .order('created_at', { ascending: false })
          .limit(decksLimit),
      ]);

      const fetchedNotes = notesRes.data ?? [];
      const fetchedDecks = decksRes.data ?? [];

      setNotes(fetchedNotes);
      setDecks(fetchedDecks);

      // Fetch creator names for all content in one query
      const userIds = [...new Set([
        ...fetchedNotes.map(n => n.user_id),
        ...fetchedDecks.map(d => d.user_id),
      ].filter(Boolean))];

      if (userIds.length > 0) {
        const { data: profiles } = await supabase
          .from('profiles')
          .select('id, full_name')
          .in('id', userIds);
        const map = {};
        (profiles ?? []).forEach(p => { map[p.id] = p.full_name || '(Unknown)'; });
        setCreatorsMap(map);
      }
    } catch (err) {
      console.error('AdminDashboard fetchContent:', err);
    }
  }

  async function fetchUsers() {
    try {
      const { data } = await supabase
        .from('profiles')
        .select('id, full_name, email, role, status, account_type, created_at')
        .order('created_at', { ascending: false })
        .limit(usersLimit);
      setRecentUsers(data ?? []);
    } catch (err) {
      console.error('AdminDashboard fetchUsers:', err);
    }
  }

  async function fetchAccessRequests() {
    setAccessRequestsLoading(true);
    try {
      const { data, error } = await supabase
        .from('access_requests')
        .select('*')
        .order('created_at', { ascending: false });
      if (error) throw error;
      setAccessRequests(data ?? []);
    } catch (err) {
      console.error('AdminDashboard fetchAccessRequests:', err);
    } finally {
      setAccessRequestsLoading(false);
    }
  }

  async function updateAccessRequestStatus(requestId, newStatus) {
    try {
      const { error } = await supabase
        .from('access_requests')
        .update({ status: newStatus })
        .eq('id', requestId);
      if (error) throw error;
      setAccessRequests(prev =>
        prev.map(r => r.id === requestId ? { ...r, status: newStatus } : r)
      );
    } catch (err) {
      console.error('updateAccessRequestStatus:', err);
      alert('Failed to update status');
    }
  }

  // ── Inline deck preview ────────────────────────────────────────────────────
  async function togglePreview(deckId) {
    if (previewDeckId === deckId) {
      setPreviewDeckId(null);
      setPreviewCards([]);
      return;
    }
    setPreviewDeckId(deckId);
    setPreviewCards([]);
    setPreviewLoading(true);

    // flashcards has no deck_id column — match by the deck's unique attributes
    const deck = decks.find(d => d.id === deckId);
    let query = supabase
      .from('flashcards')
      .select('id, front_text, back_text')
      .eq('user_id', deck.user_id)
      .limit(5);

    query = deck.subject_id
      ? query.eq('subject_id', deck.subject_id)
      : query.is('subject_id', null);

    query = deck.topic_id
      ? query.eq('topic_id', deck.topic_id)
      : query.is('topic_id', null);

    query = deck.custom_subject
      ? query.eq('custom_subject', deck.custom_subject)
      : query.is('custom_subject', null);

    query = deck.custom_topic
      ? query.eq('custom_topic', deck.custom_topic)
      : query.is('custom_topic', null);

    const { data } = await query;
    setPreviewCards(data ?? []);
    setPreviewLoading(false);
  }

  // ── Destructive actions ────────────────────────────────────────────────────
  async function deleteNote(noteId) {
    if (!confirm('Delete this note? This cannot be undone.')) return;
    try {
      const { error } = await supabase.from('notes').delete().eq('id', noteId);
      if (error) throw error;
      const { data: { user } } = await supabase.auth.getUser();
      await supabase.from('admin_audit_log').insert({
        action: 'delete_note', admin_id: user.id, details: { note_id: noteId },
      });
      setNotes(prev => prev.filter(n => n.id !== noteId));
    } catch (err) {
      console.error('deleteNote:', err);
      alert('Failed to delete note');
    }
  }

  async function deleteDeck(deckId) {
    if (!confirm('Delete this study set and ALL its cards? This cannot be undone.')) return;
    try {
      const { error } = await supabase.from('flashcard_decks').delete().eq('id', deckId);
      if (error) throw error;
      const { data: { user } } = await supabase.auth.getUser();
      await supabase.from('admin_audit_log').insert({
        action: 'delete_deck', admin_id: user.id, details: { deck_id: deckId },
      });
      setDecks(prev => prev.filter(d => d.id !== deckId));
      if (previewDeckId === deckId) { setPreviewDeckId(null); setPreviewCards([]); }
    } catch (err) {
      console.error('deleteDeck:', err);
      alert('Failed to delete study set');
    }
  }

  async function suspendUser(userId) {
    if (!confirm('Suspend this user?')) return;
    try {
      const { error } = await supabase
        .from('profiles').update({ status: 'suspended' }).eq('id', userId);
      if (error) throw error;
      const { data: { user } } = await supabase.auth.getUser();
      await supabase.from('admin_audit_log').insert({
        action: 'suspend_user', admin_id: user.id, target_user_id: userId,
        details: { reason: 'Suspended by admin' },
      });
      setRecentUsers(prev => prev.map(u => u.id === userId ? { ...u, status: 'suspended' } : u));
    } catch (err) {
      console.error('suspendUser:', err);
      alert('Failed to suspend user');
    }
  }

  // ── Guards ────────────────────────────────────────────────────────────────
  if (roleLoading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600" />
      </div>
    );
  }

  if (!isAdmin && !isSuperAdmin) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <Alert variant="destructive" className="max-w-md">
          <AlertCircle className="h-4 w-4" />
          <AlertDescription>Access Denied. Administrators only.</AlertDescription>
        </Alert>
      </div>
    );
  }

  // ── Render ────────────────────────────────────────────────────────────────
  return (
    <div className="container mx-auto py-8 px-4">

      {/* Header */}
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900 mb-1">Admin Dashboard</h1>
        <p className="text-gray-500 text-sm">Content moderation and user management</p>
      </div>

      {/* Stat cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        <StatCard icon={<Users className="h-4 w-4 text-gray-400" />}
          title="Total Users" value={stats?.totalUsers ?? 0}
          sub={`+${stats?.newUsersThisWeek ?? 0} this week`} />
        <StatCard icon={<FileText className="h-4 w-4 text-gray-400" />}
          title="Total Notes" value={stats?.totalNotes ?? 0}
          sub={`${stats?.publicNotes ?? 0} public`} />
        <StatCard icon={<TrendingUp className="h-4 w-4 text-gray-400" />}
          title="Study Items" value={stats?.totalFlashcards ?? 0}
          sub={`${stats?.publicFlashcards ?? 0} public`} />
        <StatCard icon={<AlertCircle className="h-4 w-4 text-gray-400" />}
          title="Public Notes" value={stats?.pendingReview ?? 0}
          sub="Shared by users" />
      </div>

      {/* Tab bar */}
      <div className="flex border-b border-gray-200 mb-6">
        <TabButton label="Content Moderation" active={activeTab === 'content'} onClick={() => setActiveTab('content')} />
        <TabButton label="User Management"    active={activeTab === 'users'}   onClick={() => setActiveTab('users')} />
        <TabButton label="Access Requests"    active={activeTab === 'access'}  onClick={() => { setActiveTab('access'); fetchAccessRequests(); }} />
      </div>

      {/* ── Content Moderation ── */}
      {activeTab === 'content' && (
        <div className="space-y-8">

          {/* Public Notes */}
          <section>
            <h2 className="text-base font-semibold text-gray-900 flex items-center gap-2 mb-1">
              <FileText className="h-4 w-4 text-gray-500" /> Public Notes
            </h2>
            <p className="text-xs text-gray-400 mb-3">
              Click a title to review content in a new tab before deciding to delete.
            </p>
            <Card>
              <CardContent className="pt-4">
                {isLoading ? (
                  <p className="text-center text-gray-400 py-8 text-sm">Loading…</p>
                ) : notes.length === 0 ? (
                  <p className="text-center text-gray-400 py-8 text-sm">No public notes</p>
                ) : (
                  <>
                    <div className="space-y-2">
                      {notes.map((note) => (
                        <div key={note.id} className="flex items-start justify-between p-3 border rounded-lg hover:bg-gray-50">
                          <div className="flex-1 min-w-0">
                            {/* Title links to note detail in new tab */}
                            <a
                              href={`/dashboard/notes/${note.id}?ref=admin`}
                              target="_blank"
                              rel="noopener noreferrer"
                              className="font-medium text-indigo-700 hover:text-indigo-900 hover:underline text-sm flex items-center gap-1 truncate"
                            >
                              {note.title}
                              <ExternalLink className="h-3 w-3 shrink-0 opacity-60" />
                            </a>
                            <div className="flex items-center gap-3 mt-1 text-xs text-gray-400 flex-wrap">
                              <span>{note.target_course}</span>
                              <span>·</span>
                              <span>By {creatorsMap[note.user_id] ?? '…'}</span>
                              <span>·</span>
                              <span>{new Date(note.created_at).toLocaleDateString()}</span>
                              <span>·</span>
                              <span>{note.view_count ?? 0} views</span>
                            </div>
                          </div>
                          <Button size="sm" variant="outline"
                            className="text-red-600 hover:text-red-700 ml-3 shrink-0"
                            onClick={() => deleteNote(note.id)}>
                            <XCircle className="h-3.5 w-3.5 mr-1" /> Delete
                          </Button>
                        </div>
                      ))}
                    </div>
                    <div className="mt-4 text-center">
                      <Button variant="ghost" size="sm" className="text-gray-500"
                        onClick={() => setNotesLimit(l => l + 10)}>
                        Load more notes
                      </Button>
                    </div>
                  </>
                )}
              </CardContent>
            </Card>
          </section>

          {/* Public Study Sets */}
          <section>
            <h2 className="text-base font-semibold text-gray-900 flex items-center gap-2 mb-1">
              <CreditCard className="h-4 w-4 text-gray-500" /> Public Study Sets
            </h2>
            <p className="text-xs text-gray-400 mb-3">
              Click "Preview items" to see up to 5 cards before deciding to delete.
              Bulk-uploaded sets have no custom name — use creator + date + item count to identify them.
            </p>
            <Card>
              <CardContent className="pt-4">
                {isLoading ? (
                  <p className="text-center text-gray-400 py-8 text-sm">Loading…</p>
                ) : decks.length === 0 ? (
                  <p className="text-center text-gray-400 py-8 text-sm">No public study sets</p>
                ) : (
                  <>
                    <div className="space-y-2">
                      {decks.map((deck) => (
                        <div key={deck.id} className="border rounded-lg overflow-hidden">

                          {/* Deck header row */}
                          <div className="flex items-start justify-between p-3 hover:bg-gray-50">
                            <div className="flex-1 min-w-0">
                              <p className="font-medium text-gray-900 text-sm">
                                {deck.name
                                  ? deck.name
                                  : deck.description
                                    ? <span className="text-gray-700">{deck.description}</span>
                                    : <span className="text-gray-400 italic">Bulk upload — no title</span>
                                }
                              </p>
                              <div className="flex items-center gap-3 mt-1 text-xs text-gray-400 flex-wrap">
                                <span>{deck.target_course}</span>
                                <span>·</span>
                                <span>By {creatorsMap[deck.user_id] ?? '…'}</span>
                                <span>·</span>
                                <span>{new Date(deck.created_at).toLocaleDateString()}</span>
                                <span>·</span>
                                <span>{deck.card_count ?? 0} items</span>
                              </div>
                            </div>
                            <div className="flex items-center gap-2 ml-3 shrink-0">
                              <button
                                onClick={() => togglePreview(deck.id)}
                                className="text-xs text-indigo-600 hover:text-indigo-800 flex items-center gap-1 px-2 py-1 rounded border border-indigo-200 hover:bg-indigo-50 transition-colors"
                              >
                                {previewDeckId === deck.id
                                  ? <><ChevronUp className="h-3 w-3" /> Hide</>
                                  : <><ChevronDown className="h-3 w-3" /> Preview items</>
                                }
                              </button>
                              <Button size="sm" variant="outline"
                                className="text-red-600 hover:text-red-700"
                                onClick={() => deleteDeck(deck.id)}>
                                <XCircle className="h-3.5 w-3.5 mr-1" /> Delete
                              </Button>
                            </div>
                          </div>

                          {/* Inline preview panel */}
                          {previewDeckId === deck.id && (
                            <div className="border-t border-gray-100 bg-gray-50 px-4 py-3">
                              {previewLoading ? (
                                <p className="text-xs text-gray-400 animate-pulse">Loading preview…</p>
                              ) : previewCards.length === 0 ? (
                                <p className="text-xs text-gray-400">No cards found in this set.</p>
                              ) : (
                                <div className="space-y-2">
                                  <p className="text-xs font-medium text-gray-500 mb-2">
                                    First {previewCards.length} of {deck.card_count ?? '?'} items:
                                  </p>
                                  {previewCards.map((card, i) => (
                                    <div key={card.id} className="bg-white rounded border border-gray-200 px-3 py-2">
                                      <p className="text-xs text-gray-500 mb-0.5">Q{i + 1}</p>
                                      <p className="text-sm text-gray-900">{card.front_text}</p>
                                      {card.back_text && (
                                        <p className="text-xs text-gray-500 mt-1 pt-1 border-t border-gray-100">
                                          {card.back_text}
                                        </p>
                                      )}
                                    </div>
                                  ))}
                                </div>
                              )}
                            </div>
                          )}

                        </div>
                      ))}
                    </div>
                    <div className="mt-4 text-center">
                      <Button variant="ghost" size="sm" className="text-gray-500"
                        onClick={() => setDecksLimit(l => l + 10)}>
                        Load more study sets
                      </Button>
                    </div>
                  </>
                )}
              </CardContent>
            </Card>
          </section>

        </div>
      )}

      {/* ── User Management ── */}
      {activeTab === 'users' && (
        <div className="space-y-6">
          <Card>
            <CardHeader>
              <CardTitle className="text-base">Users</CardTitle>
            </CardHeader>
            <CardContent>
              {isLoading ? (
                <p className="text-center text-gray-400 py-8 text-sm">Loading…</p>
              ) : recentUsers.length === 0 ? (
                <p className="text-center text-gray-400 py-8 text-sm">No users found</p>
              ) : (
                <>
                  <div className="space-y-3">
                    {recentUsers.map((u) => (
                      <div key={u.id} className="flex items-center justify-between p-3 border rounded-lg">
                        <div className="min-w-0 flex-1">
                          <p className="font-medium text-gray-900 text-sm">{u.full_name || '(No name)'}</p>
                          <p className="text-xs text-gray-500 truncate">{u.email}</p>
                          <div className="flex items-center gap-2 mt-1 flex-wrap">
                            <RoleBadge role={u.role} />
                            {u.account_type === 'self_registered' ? (
                              <span className="px-2 py-0.5 text-xs rounded-full bg-orange-100 text-orange-700">
                                Tier B
                              </span>
                            ) : (
                              <span className="px-2 py-0.5 text-xs rounded-full bg-green-100 text-green-700">
                                Enrolled
                              </span>
                            )}
                            {u.status === 'suspended' && (
                              <span className="px-2 py-0.5 text-xs rounded-full bg-red-100 text-red-700">
                                Suspended
                              </span>
                            )}
                            <span className="text-xs text-gray-400">
                              Joined {new Date(u.created_at).toLocaleDateString()}
                            </span>
                          </div>
                        </div>
                        {u.status !== 'suspended' && (
                          <Button size="sm" variant="outline"
                            className="text-red-600 ml-3 shrink-0"
                            onClick={() => suspendUser(u.id)}>
                            Suspend
                          </Button>
                        )}
                      </div>
                    ))}
                  </div>
                  <div className="mt-4 text-center">
                    <Button variant="ghost" size="sm" className="text-gray-500"
                      onClick={() => setUsersLimit(l => l + 20)}>
                      Load more users
                    </Button>
                  </div>
                </>
              )}
            </CardContent>
          </Card>

          <Alert>
            <AlertCircle className="h-4 w-4" />
            <AlertDescription>
              To promote users to Professor or Admin roles, contact the Super Administrator.
            </AlertDescription>
          </Alert>
        </div>
      )}

      {/* ── Access Requests ── */}
      {activeTab === 'access' && (
        <div className="space-y-6">
          <Card>
            <CardHeader>
              <CardTitle className="text-base">Access Requests</CardTitle>
              <p className="text-xs text-gray-400 mt-1">
                Self-registered users who submitted a WhatsApp lead capture form requesting full access.
              </p>
            </CardHeader>
            <CardContent>
              {accessRequestsLoading ? (
                <p className="text-center text-gray-400 py-8 text-sm">Loading…</p>
              ) : accessRequests.length === 0 ? (
                <p className="text-center text-gray-400 py-8 text-sm">No access requests yet</p>
              ) : (
                <div className="overflow-x-auto">
                  <table className="w-full text-sm">
                    <thead>
                      <tr className="text-left text-xs text-gray-500 border-b">
                        <th className="pb-2 pr-4 font-medium">Name</th>
                        <th className="pb-2 pr-4 font-medium">WhatsApp</th>
                        <th className="pb-2 pr-4 font-medium">Course</th>
                        <th className="pb-2 pr-4 font-medium">Content Seen</th>
                        <th className="pb-2 pr-4 font-medium">Date</th>
                        <th className="pb-2 font-medium">Status</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-gray-100">
                      {accessRequests.map((req) => (
                        <tr key={req.id} className="hover:bg-gray-50">
                          <td className="py-3 pr-4 font-medium text-gray-900">{req.name || '—'}</td>
                          <td className="py-3 pr-4 text-gray-700">{req.whatsapp_number || '—'}</td>
                          <td className="py-3 pr-4 text-gray-700">{req.course || '—'}</td>
                          <td className="py-3 pr-4 text-gray-500 max-w-xs truncate">
                            {req.content_name || req.content_type || '—'}
                          </td>
                          <td className="py-3 pr-4 text-gray-400 text-xs">
                            {new Date(req.created_at).toLocaleDateString()}
                          </td>
                          <td className="py-3">
                            <select
                              value={req.status || 'pending'}
                              onChange={(e) => updateAccessRequestStatus(req.id, e.target.value)}
                              className="text-xs border border-gray-200 rounded px-2 py-1 bg-white focus:outline-none focus:ring-1 focus:ring-indigo-400"
                            >
                              <option value="pending">Pending</option>
                              <option value="contacted">Contacted</option>
                              <option value="enrolled">Enrolled</option>
                              <option value="dismissed">Dismissed</option>
                            </select>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </CardContent>
          </Card>
        </div>
      )}

    </div>
  );
}

// ─── Sub-components ───────────────────────────────────────────────────────────
function TabButton({ label, active, onClick }) {
  return (
    <button onClick={onClick}
      className={`px-6 py-3 text-sm font-medium border-b-2 transition-colors ${
        active
          ? 'border-indigo-600 text-indigo-600'
          : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
      }`}>
      {label}
    </button>
  );
}

function StatCard({ icon, title, value, sub }) {
  return (
    <Card>
      <CardHeader className="flex flex-row items-center justify-between pb-2">
        <CardTitle className="text-sm font-medium text-gray-600">{title}</CardTitle>
        {icon}
      </CardHeader>
      <CardContent>
        <div className="text-2xl font-bold">{value}</div>
        <p className="text-xs text-gray-500 mt-1">{sub}</p>
      </CardContent>
    </Card>
  );
}

function RoleBadge({ role }) {
  const cls =
    role === 'super_admin' ? 'bg-purple-100 text-purple-800' :
    role === 'admin'       ? 'bg-red-100 text-red-800'       :
    role === 'professor'   ? 'bg-blue-100 text-blue-800'     :
                             'bg-green-100 text-green-800';
  return (
    <span className={`px-2 py-0.5 text-xs rounded-full ${cls}`}>
      {role?.replace('_', ' ') || 'student'}
    </span>
  );
}
