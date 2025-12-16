import { BarChart3, FileText, CreditCard } from 'lucide-react';

export default function MyContributions() {
  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      {/* Header */}
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900 flex items-center gap-2">
          <BarChart3 className="h-8 w-8 text-blue-600" />
          My Contributions
        </h1>
        <p className="mt-2 text-gray-600">
          View all the notes and flashcards you've created
        </p>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
        <div className="bg-white rounded-lg shadow p-6">
          <div className="flex items-center gap-4">
            <FileText className="h-10 w-10 text-blue-600" />
            <div>
              <p className="text-2xl font-bold text-gray-900">4</p>
              <p className="text-sm text-gray-600">Notes Uploaded</p>
            </div>
          </div>
        </div>

        <div className="bg-white rounded-lg shadow p-6">
          <div className="flex items-center gap-4">
            <CreditCard className="h-10 w-10 text-purple-600" />
            <div>
              <p className="text-2xl font-bold text-gray-900">2</p>
              <p className="text-sm text-gray-600">Flashcards Created</p>
            </div>
          </div>
        </div>
      </div>

      {/* Coming Soon Message */}
      <div className="bg-blue-50 border border-blue-200 rounded-lg p-8 text-center">
        <BarChart3 className="h-16 w-16 text-blue-600 mx-auto mb-4" />
        <h2 className="text-2xl font-bold text-gray-900 mb-2">
          Detailed Contributions View - Coming Soon!
        </h2>
        <p className="text-gray-600 mb-4">
          See all your uploaded notes and created flashcards in one place.
        </p>
        <p className="text-sm text-gray-500">
          Available after Phase 1 launch
        </p>
      </div>
    </div>
  );
}