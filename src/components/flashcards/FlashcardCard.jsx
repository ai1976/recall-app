import { Card, CardContent, CardHeader } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Textarea } from '@/components/ui/textarea';
import { Edit2, Save, X, Trash2, Globe, Lock, Users } from 'lucide-react';

const getVisibilityBadge = (visibility) => {
  switch(visibility) {
    case 'public':
      return (
        <span className="inline-flex items-center px-1.5 py-0.5 rounded text-xs bg-green-100 text-green-700">
          <Globe className="h-3 w-3 mr-0.5" />
          Public
        </span>
      );
    case 'friends':
      return (
        <span className="inline-flex items-center px-1.5 py-0.5 rounded text-xs bg-blue-100 text-blue-700">
          <Users className="h-3 w-3 mr-0.5" />
          Friends
        </span>
      );
    case 'private':
    default:
      return (
        <span className="inline-flex items-center px-1.5 py-0.5 rounded text-xs bg-gray-100 text-gray-600">
          <Lock className="h-3 w-3 mr-0.5" />
          Private
        </span>
      );
  }
};

const formatDate = (dateString) => {
  return new Date(dateString).toLocaleDateString('en-IN', {
    year: 'numeric',
    month: 'short',
    day: 'numeric'
  });
};

export default function FlashcardCard({
  card,
  isEditing,
  editingCard,
  onStartEdit,
  onCancelEdit,
  onSaveEdit,
  onEditChange,
  onDelete,
  onVisibilityChange
}) {
  return (
    <Card className={`hover:shadow-lg transition-shadow ${isEditing ? 'ring-2 ring-blue-500' : ''}`}>
      <CardHeader className="pb-3">
        <div className="flex items-start justify-between">
          <div className="flex-1">
            <div className="flex items-center gap-2 mb-1">
              <p className="text-xs text-gray-500">
                {card.target_course || 'No course'}
                {(card.subjects?.name || card.custom_subject) &&
                  ` • ${card.subjects?.name || card.custom_subject}`
                }
              </p>
              {getVisibilityBadge(card.visibility || 'private')}
            </div>
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
                onClick={() => onStartEdit(card)}
                className="text-blue-600 hover:text-blue-700 hover:bg-blue-50 -mt-2"
                title="Edit"
              >
                <Edit2 className="h-4 w-4" />
              </Button>

              <select
                value={card.visibility || 'private'}
                onChange={(e) => onVisibilityChange(card.id, e.target.value, e)}
                onClick={(e) => e.stopPropagation()}
                className="px-2 py-1 border border-gray-300 rounded text-xs hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-blue-500 cursor-pointer"
                title="Change visibility"
              >
                <option value="private">Private</option>
                <option value="friends">Friends</option>
                <option value="public">Public</option>
              </select>

              <Button
                variant="ghost"
                size="sm"
                onClick={(e) => onDelete(card.id, e)}
                className="text-red-600 hover:text-red-700 hover:bg-red-50 -mt-2 -mr-2"
                title="Delete"
              >
                <Trash2 className="h-4 w-4" />
              </Button>
            </div>
          )}
        </div>
      </CardHeader>
      <CardContent>
        {isEditing ? (
          <div className="space-y-4">
            <div>
              <label className="text-xs font-semibold text-gray-500 uppercase mb-2 block">
                Question
              </label>
              <Textarea
                value={editingCard?.front_text || ''}
                onChange={(e) => onEditChange('front_text', e.target.value)}
                placeholder="Enter question..."
                className="min-h-[80px]"
              />
            </div>
            <div>
              <label className="text-xs font-semibold text-gray-500 uppercase mb-2 block">
                Answer
              </label>
              <Textarea
                value={editingCard?.back_text || ''}
                onChange={(e) => onEditChange('back_text', e.target.value)}
                placeholder="Enter answer..."
                className="min-h-[80px]"
              />
            </div>
            <div className="flex gap-2 pt-2">
              <Button
                onClick={() => onSaveEdit(card.id)}
                className="flex-1 gap-2"
                size="sm"
              >
                <Save className="h-4 w-4" />
                Save
              </Button>
              <Button
                onClick={onCancelEdit}
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
          <>
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
            <div className="mt-4 pt-3 border-t border-gray-200 text-xs text-gray-500">
              Created {formatDate(card.created_at)}
            </div>
          </>
        )}
      </CardContent>
    </Card>
  );
}
