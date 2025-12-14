import { useState, useRef, useEffect } from 'react';
import { ChevronDown, Search, X } from 'lucide-react';
import { cn } from '@/lib/utils';

export function SearchableSelect({ value, onValueChange, options, placeholder = "Select...", disabled = false, label }) {
  const [isOpen, setIsOpen] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');
  const [highlightedIndex, setHighlightedIndex] = useState(0);
  const dropdownRef = useRef(null);
  const searchInputRef = useRef(null);

  const filteredOptions = options.filter(option =>
    option.toLowerCase().includes(searchTerm.toLowerCase())
  );

  // Reset highlighted index when filter changes
  useEffect(() => {
    setHighlightedIndex(0);
  }, [searchTerm]);

  // Focus search input when dropdown opens
  useEffect(() => {
    if (isOpen && searchInputRef.current) {
      searchInputRef.current.focus();
    }
  }, [isOpen]);

  // Close dropdown when clicking outside
  useEffect(() => {
    const handleClickOutside = (event) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target)) {
        setIsOpen(false);
        setSearchTerm('');
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  // Handle keyboard navigation
  const handleKeyDown = (e) => {
    if (!isOpen) {
      if (e.key === 'Enter' || e.key === ' ') {
        setIsOpen(true);
        e.preventDefault();
      }
      return;
    }

    switch (e.key) {
      case 'ArrowDown':
        e.preventDefault();
        setHighlightedIndex(prev => 
          prev < filteredOptions.length - 1 ? prev + 1 : prev
        );
        break;
      case 'ArrowUp':
        e.preventDefault();
        setHighlightedIndex(prev => prev > 0 ? prev - 1 : 0);
        break;
      case 'Enter':
        e.preventDefault();
        if (filteredOptions[highlightedIndex]) {
          handleSelect(filteredOptions[highlightedIndex]);
        }
        break;
      case 'Escape':
        setIsOpen(false);
        setSearchTerm('');
        break;
    }
  };

  const handleSelect = (option) => {
    onValueChange(option);
    setIsOpen(false);
    setSearchTerm('');
  };

  const selectedLabel = value || placeholder;

  return (
    <div className="relative" ref={dropdownRef}>
      {label && (
        <label className="block text-sm font-medium text-gray-700 mb-1">
          {label}
        </label>
      )}
      
      {/* Trigger Button */}
      <button
        type="button"
        disabled={disabled}
        onClick={() => !disabled && setIsOpen(!isOpen)}
        onKeyDown={handleKeyDown}
        className={cn(
          "w-full flex items-center justify-between px-3 py-2 text-left bg-white border border-gray-300 rounded-md shadow-sm",
          "focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500",
          disabled && "bg-gray-100 cursor-not-allowed",
          !value && "text-gray-500"
        )}
      >
        <span className="truncate">{selectedLabel}</span>
        <ChevronDown className={cn(
          "h-4 w-4 text-gray-400 transition-transform",
          isOpen && "transform rotate-180"
        )} />
      </button>

      {/* Dropdown */}
      {isOpen && (
        <div className="absolute z-50 w-full mt-1 bg-white border border-gray-300 rounded-md shadow-lg">
          {/* Search Input */}
          <div className="p-2 border-b border-gray-200">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
              <input
                ref={searchInputRef}
                type="text"
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                onKeyDown={handleKeyDown}
                placeholder={`Search ${placeholder.toLowerCase()}...`}
                className="w-full pl-9 pr-8 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
              {searchTerm && (
                <button
                  onClick={() => setSearchTerm('')}
                  className="absolute right-2 top-1/2 transform -translate-y-1/2 text-gray-400 hover:text-gray-600"
                >
                  <X className="h-4 w-4" />
                </button>
              )}
            </div>
          </div>

          {/* Options List */}
          <div className="max-h-60 overflow-y-auto">
            {filteredOptions.length === 0 ? (
              <div className="px-4 py-6 text-center text-sm text-gray-500">
                No results found for "{searchTerm}"
              </div>
            ) : (
              <div className="py-1">
                {filteredOptions.map((option, index) => {
                  const isSelected = option === value;
                  const isHighlighted = index === highlightedIndex;

                  return (
                    <button
                      key={option}
                      type="button"
                      onClick={() => handleSelect(option)}
                      onMouseEnter={() => setHighlightedIndex(index)}
                      className={cn(
                        "w-full text-left px-4 py-2 text-sm transition-colors",
                        isSelected && "bg-blue-50 text-blue-700 font-medium",
                        isHighlighted && !isSelected && "bg-gray-100",
                        !isSelected && !isHighlighted && "text-gray-900 hover:bg-gray-50"
                      )}
                    >
                      <div className="flex items-center justify-between">
                        <span>{option}</span>
                        {isSelected && (
                          <svg className="h-4 w-4 text-blue-600" fill="currentColor" viewBox="0 0 20 20">
                            <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                          </svg>
                        )}
                      </div>
                    </button>
                  );
                })}
              </div>
            )}
          </div>

          {/* Footer showing count */}
          {filteredOptions.length > 0 && (
            <div className="px-4 py-2 border-t border-gray-200 bg-gray-50 text-xs text-gray-600">
              {filteredOptions.length} {filteredOptions.length === 1 ? 'option' : 'options'}
              {searchTerm && ` matching "${searchTerm}"`}
            </div>
          )}
        </div>
      )}
    </div>
  );
}