import { useState } from 'react';
import { FileText, Search } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';

export default function BrowseNotes() {
  const [searchQuery, setSearchQuery] = useState('');

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      {/* Header */}
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900 flex items-center gap-2">
          <FileText className="h-8 w-8 text-blue-600" />
          Browse Notes
        </h1>
        <p className="mt-2 text-gray-600">
          Explore notes from professors and classmates
        </p>
      </div>

      {/* Search Bar */}
      <div className="mb-6">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-5 w-5 text-gray-400" />
          <Input
            type="text"
            placeholder="Search notes by subject, topic, or keyword..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="pl-10"
          />
        </div>
      </div>

      {/* Coming Soon Message */}
      <div className="bg-blue-50 border border-blue-200 rounded-lg p-8 text-center">
        <FileText className="h-16 w-16 text-blue-600 mx-auto mb-4" />
        <h2 className="text-2xl font-bold text-gray-900 mb-2">
          Browse Notes - Coming Soon!
        </h2>
        <p className="text-gray-600 mb-4">
          This feature will let you explore notes from professors and classmates.
        </p>
        <p className="text-sm text-gray-500">
          Available after Phase 1 launch
        </p>
      </div>
    </div>
  );
}