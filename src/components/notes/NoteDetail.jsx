import { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { Button } from '@/components/ui/button';
import { ArrowLeft, FileText, File, Calendar, Tag, Plus, Brain, Trash2, Edit } from 'lucide-react';
import { useToast } from '@/hooks/use-toast';

export default function NoteDetail() {
  const { id } = useParams();
  const navigate = useNavigate();
  const { toast } = useToast();
  const [note, setNote] = useState(null);
  const [flashcards, setFlashcards] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchNote();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id]);

  const fetchNote = async () => {
    try {
      // Fetch note with subject and topic relationships
      const { data, error } = await supabase
        .from('notes')
        .select(`
          *,
          subject:subjects(id, name),
          topic:topics(id, name)
        `)
        .eq('id', id)
        .single();

      if (error) throw error;
      setNote(data);

      // Fetch linked flashcards
      const { data: flashcardsData, error: flashcardsError } = await supabase
        .from('flashcards')
        .select('*')
        .eq('note_id', id)
        .order('created_at', { ascending: false });

      if (flashcardsError) throw flashcardsError;
      setFlashcards(flashcardsData || []);
    } catch (error) {
      console.error('Error fetching note:', error);
      toast({
        title: "Error loading note",
        description: error.message,
        variant: "destructive"
      });
    } finally {
      setLoading(false);
    }
  };

  const handleDeleteFlashcard = async (cardId) => {
    if (!confirm('Delete this flashcard?')) return;

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

      // Refresh flashcards
      fetchNote();
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

  if (!note) {
    return (
      <div className="min-h-screen flex flex-col items-center justify-center">
        <FileText className="h-16 w-16 text-gray-400 mb-4" />
        <h2 className="text-2xl font-bold text-gray-900 mb-2">Note not found</h2>
        <Button onClick={() => navigate('/dashboard')}>Back to Dashboard</Button>
      </div>
    );
  }

  const isPDF = note.image_url?.toLowerCase().endsWith('.pdf');

  // Get display names for subject and topic
  const displaySubject = note.custom_subject || note.subject?.name || 'No subject';
  const displayTopic = note.custom_topic || note.topic?.name || '';

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white border-b border-gray-200 sticky top-0 z-10">
        <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            <Button
              variant="ghost"
              onClick={() => navigate('/dashboard')}
              className="gap-2"
            >
              <ArrowLeft className="h-4 w-4" />
              Back
            </Button>
            <div className="flex gap-2">
              <Button
                variant="outline"
                onClick={() => navigate(`/notes/edit/${note.id}`)}
                className="gap-2"
              >
                <Edit className="h-4 w-4" />
                Edit Note
              </Button>
              <Button
                onClick={() => navigate(`/dashboard/flashcards/new?noteId=${note.id}`)}
                className="gap-2"
              >
                <Plus className="h-4 w-4" />
                Create Flashcards
              </Button>
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Note Details Card */}
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden mb-6">
          {/* Note Header */}
          <div className="p-6 border-b border-gray-200">
            <h1 className="text-2xl font-bold text-gray-900 mb-4">{note.title}</h1>
            
            {/* Description */}
            {note.description && (
              <div className="mb-4 p-3 bg-gray-50 rounded-lg">
                <p className="text-sm text-gray-700">{note.description}</p>
              </div>
            )}
            
            <div className="flex flex-wrap gap-4 text-sm text-gray-600">
              <div className="flex items-center gap-2">
                <FileText className="h-4 w-4" />
                <span className="font-medium">Subject:</span>
                <span>{displaySubject}</span>
              </div>
              {displayTopic && (
                <div className="flex items-center gap-2">
                  <Tag className="h-4 w-4" />
                  <span className="font-medium">Topic:</span>
                  <span>{displayTopic}</span>
                </div>
              )}
              <div className="flex items-center gap-2">
                <Calendar className="h-4 w-4" />
                <span className="font-medium">Created:</span>
                <span>{new Date(note.created_at).toLocaleDateString()}</span>
              </div>
            </div>

            {note.tags && note.tags.length > 0 && (
              <div className="flex flex-wrap gap-2 mt-4">
                {note.tags.map(tag => (
                  <span
                    key={tag}
                    className="px-2 py-1 bg-blue-100 text-blue-700 text-xs rounded-full"
                  >
                    {tag}
                  </span>
                ))}
              </div>
            )}
          </div>

          {/* Note Image/PDF */}
          <div className="p-6 border-b border-gray-200 bg-gray-50">
            {isPDF ? (
              <div className="text-center py-8">
                <File className="h-16 w-16 text-blue-600 mx-auto mb-4" />
                <p className="text-gray-700 font-medium mb-4">{note.title}.pdf</p>
                <Button
                  onClick={() => window.open(note.image_url, '_blank')}
                  className="gap-2"
                >
                  <File className="h-4 w-4" />
                  Open PDF
                </Button>
              </div>
            ) : (
              <img
                src={note.image_url}
                alt={note.title}
                className="w-full h-auto rounded-lg shadow-sm"
              />
            )}
          </div>

          {/* Extracted Text */}
          <div className="p-6">
            <h2 className="text-lg font-semibold text-gray-900 mb-3">Extracted Text</h2>
            {note.extracted_text ? (
              <div className="bg-gray-50 p-4 rounded-lg">
                <p className="text-gray-800 whitespace-pre-wrap font-mono text-sm">
                  {note.extracted_text}
                </p>
              </div>
            ) : (
              <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
                <p className="text-yellow-800 text-sm">
                  {isPDF 
                    ? "PDF text extraction is not yet available. You can manually create flashcards from this note."
                    : "No text was extracted from this image. You can manually create flashcards from this note."}
                </p>
              </div>
            )}
          </div>
        </div>

        {/* Linked Flashcards Section */}
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden">
          <div className="p-6 border-b border-gray-200 bg-gray-50">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                <Brain className="h-6 w-6 text-purple-600" />
                <div>
                  <h2 className="text-lg font-semibold text-gray-900">Linked Flashcards</h2>
                  <p className="text-sm text-gray-600">{flashcards.length} flashcard{flashcards.length !== 1 ? 's' : ''} created from this note</p>
                </div>
              </div>
              <Button
                onClick={() => navigate(`/dashboard/flashcards/new?noteId=${note.id}`)}
                size="sm"
                className="gap-2"
              >
                <Plus className="h-4 w-4" />
                Add More
              </Button>
            </div>
          </div>

          <div className="p-6">
            {flashcards.length === 0 ? (
              <div className="text-center py-8">
                <Brain className="h-12 w-12 text-gray-400 mx-auto mb-3" />
                <p className="text-gray-600 mb-4">No flashcards created yet</p>
                <Button
                  onClick={() => navigate(`/dashboard/flashcards/new?noteId=${note.id}`)}
                  className="gap-2"
                >
                  <Plus className="h-4 w-4" />
                  Create Your First Flashcard
                </Button>
              </div>
            ) : (
              <div className="space-y-4">
                {flashcards.map((card) => (
                  <div
                    key={card.id}
                    className="border border-gray-200 rounded-lg overflow-hidden hover:shadow-md transition-shadow"
                  >
                    {/* Front Side */}
                    <div className="p-4 bg-white border-b border-gray-100">
                      <div className="flex items-start justify-between mb-2">
                        <p className="text-xs font-semibold text-gray-500 uppercase">Front (Question)</p>
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={() => handleDeleteFlashcard(card.id)}
                          className="text-red-600 hover:text-red-700 hover:bg-red-50 -mt-2 -mr-2"
                        >
                          <Trash2 className="h-4 w-4" />
                        </Button>
                      </div>
                      {card.front_image_url && (
                        <img
                          src={card.front_image_url}
                          alt="Front"
                          className="w-full max-w-xs h-32 object-cover rounded mb-2"
                        />
                      )}
                      <p className="text-sm text-gray-900 whitespace-pre-wrap">
                        {card.front_text}
                      </p>
                    </div>

                    {/* Back Side */}
                    <div className="p-4 bg-blue-50">
                      <p className="text-xs font-semibold text-gray-500 uppercase mb-2">Back (Answer)</p>
                      {card.back_image_url && (
                        <img
                          src={card.back_image_url}
                          alt="Back"
                          className="w-full max-w-xs h-32 object-cover rounded mb-2"
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
          </div>
        </div>
      </main>
    </div>
  );
}