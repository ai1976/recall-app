import { useState, useEffect, useMemo } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import {
  ArrowLeft,
  ArrowUp,
  Search,
  X,
  ChevronDown,
  ChevronRight,
  HelpCircle,
  BookOpen,
  Upload,
  Brain,
  Users,
  Network,
  Star,
  Play,
  LayoutDashboard,
  FileText,
  CreditCard,
  Eye,
  Folder,
  ThumbsUp,
  Layers,
  BarChart3,
  Pause,
  UserPlus,
  User,
  Lock,
  Plus,
  Share2,
  Settings,
  Trophy,
  Bell,
} from 'lucide-react';
import PageContainer from '@/components/layout/PageContainer';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { HELP_TABS, FAQ_ITEMS } from '@/data/helpContent';

// ─── Icon mapping for data-driven rendering ───
const ICON_MAP = {
  BookOpen, Upload, Brain, Users, Network, Star, Play, LayoutDashboard,
  FileText, CreditCard, Eye, Folder, ThumbsUp, Layers, BarChart3, Pause,
  UserPlus, User, Lock, Plus, Share2, Settings, Trophy, Bell, Search,
  HelpCircle, ChevronDown, ChevronRight,
};

function DynamicIcon({ name, className }) {
  const Icon = ICON_MAP[name];
  if (!Icon) return null;
  return <Icon className={className} />;
}

// ─── Content block renderer ───
function ContentBlock({ item }) {
  switch (item.type) {
    case 'paragraph':
      return <p className="text-gray-700 mb-4 leading-relaxed">{item.text}</p>;
    case 'list':
      return (
        <ul className="list-disc pl-6 text-gray-700 space-y-2 mb-4">
          {item.items.map((li, i) => (
            <li key={i} className="leading-relaxed">{li}</li>
          ))}
        </ul>
      );
    case 'steps':
      return (
        <ol className="list-decimal pl-6 text-gray-700 space-y-2 mb-4">
          {item.items.map((step, i) => (
            <li key={i} className="leading-relaxed">{step}</li>
          ))}
        </ol>
      );
    case 'tip':
      return (
        <div className="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-4 flex gap-3">
          <HelpCircle className="h-5 w-5 text-blue-600 shrink-0 mt-0.5" />
          <p className="text-sm text-blue-800 leading-relaxed">
            <span className="font-semibold">Tip:</span> {item.text}
          </p>
        </div>
      );
    default:
      return null;
  }
}

// ─── Collapsible section ───
function CollapsibleSection({ section, isExpanded, onToggle, tabLabel }) {
  return (
    <Card className="mb-3">
      <CardHeader
        className="cursor-pointer hover:bg-gray-50 transition-colors py-4"
        onClick={onToggle}
      >
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <DynamicIcon name={section.icon} className="h-5 w-5 text-blue-600" />
            <CardTitle className="text-base font-semibold">{section.title}</CardTitle>
            {tabLabel && (
              <span className="text-xs bg-gray-100 text-gray-500 px-2 py-0.5 rounded-full">
                {tabLabel}
              </span>
            )}
          </div>
          {isExpanded
            ? <ChevronDown className="h-5 w-5 text-gray-400" />
            : <ChevronRight className="h-5 w-5 text-gray-400" />
          }
        </div>
      </CardHeader>
      {isExpanded && (
        <CardContent className="pt-0 pb-5">
          {section.content.map((item, idx) => (
            <ContentBlock key={idx} item={item} />
          ))}
        </CardContent>
      )}
    </Card>
  );
}

// ─── FAQ item ───
function FAQItem({ item, isExpanded, onToggle }) {
  return (
    <Card className="mb-3">
      <CardHeader
        className="cursor-pointer hover:bg-gray-50 transition-colors py-4"
        onClick={onToggle}
      >
        <div className="flex items-center justify-between">
          <CardTitle className="text-base font-semibold pr-4">{item.question}</CardTitle>
          {isExpanded
            ? <ChevronDown className="h-5 w-5 text-gray-400 shrink-0" />
            : <ChevronRight className="h-5 w-5 text-gray-400 shrink-0" />
          }
        </div>
      </CardHeader>
      {isExpanded && (
        <CardContent className="pt-0 pb-5">
          <p className="text-gray-700 leading-relaxed">{item.answer}</p>
        </CardContent>
      )}
    </Card>
  );
}

// ─── Main Help page ───
export default function Help() {
  const [searchParams, setSearchParams] = useSearchParams();
  const [searchQuery, setSearchQuery] = useState('');
  const [expandedSections, setExpandedSections] = useState(new Set());
  const [showBackToTop, setShowBackToTop] = useState(false);

  // Sync active tab with URL search params
  const activeTab = searchParams.get('tab') || 'getting-started';
  const setActiveTab = (tabKey) => {
    setSearchParams({ tab: tabKey }, { replace: true });
  };

  // Seed default expanded sections on mount
  useEffect(() => {
    const defaults = new Set();
    HELP_TABS.forEach(tab => {
      tab.sections.forEach(section => {
        if (section.defaultExpanded) {
          defaults.add(section.id);
        }
      });
    });
    setExpandedSections(defaults);
  }, []);

  // Scroll listener for back-to-top button
  useEffect(() => {
    const handleScroll = () => {
      setShowBackToTop(window.scrollY > 400);
    };
    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  const toggleSection = (sectionId) => {
    setExpandedSections(prev => {
      const next = new Set(prev);
      if (next.has(sectionId)) {
        next.delete(sectionId);
      } else {
        next.add(sectionId);
      }
      return next;
    });
  };

  // Search across all tabs
  const searchResults = useMemo(() => {
    if (!searchQuery.trim()) return null;

    const query = searchQuery.toLowerCase();
    const results = [];

    HELP_TABS.forEach(tab => {
      tab.sections.forEach(section => {
        const titleMatch = section.title.toLowerCase().includes(query);
        const contentMatch = section.content.some(item => {
          if (item.type === 'paragraph' || item.type === 'tip') {
            return item.text.toLowerCase().includes(query);
          }
          if (item.type === 'list' || item.type === 'steps') {
            return item.items.some(i => i.toLowerCase().includes(query));
          }
          return false;
        });

        if (titleMatch || contentMatch) {
          results.push({ ...section, tabLabel: tab.label, tabKey: tab.key });
        }
      });
    });

    // Also search FAQs
    FAQ_ITEMS.forEach((faq, idx) => {
      if (
        faq.question.toLowerCase().includes(query) ||
        faq.answer.toLowerCase().includes(query)
      ) {
        results.push({
          id: `faq-${idx}`,
          title: faq.question,
          icon: 'HelpCircle',
          tabLabel: 'FAQ',
          tabKey: 'faq',
          isFaq: true,
          answer: faq.answer,
          content: [{ type: 'paragraph', text: faq.answer }],
        });
      }
    });

    return results;
  }, [searchQuery]);

  const currentTab = HELP_TABS.find(t => t.key === activeTab) || HELP_TABS[0];
  const isSearching = searchResults !== null;

  return (
    <PageContainer width="medium">
      {/* Header */}
      <Link
        to="/dashboard"
        className="inline-flex items-center text-blue-600 hover:text-blue-700 mb-4 text-sm"
      >
        <ArrowLeft className="h-4 w-4 mr-1" />
        Back to Dashboard
      </Link>

      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-2">
          <HelpCircle className="h-7 w-7 text-blue-600" />
          Help & Guide
        </h1>
        <p className="text-gray-500 mt-1">
          Learn how to use Recall to study smarter with spaced repetition.
        </p>
      </div>

      {/* Search bar */}
      <div className="relative mb-6">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
        <Input
          type="text"
          placeholder="Search help topics..."
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          className="pl-10 pr-10"
        />
        {searchQuery && (
          <button
            onClick={() => setSearchQuery('')}
            className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
          >
            <X className="h-4 w-4" />
          </button>
        )}
      </div>

      {/* Tab bar (hidden during search) */}
      {!isSearching && (
        <div className="flex overflow-x-auto gap-1 bg-gray-100 p-1 rounded-lg mb-6 scrollbar-hide">
          {HELP_TABS.map(tab => (
            <button
              key={tab.key}
              onClick={() => setActiveTab(tab.key)}
              className={`flex items-center gap-2 px-3 py-2 text-sm font-medium rounded-md whitespace-nowrap transition-colors ${
                activeTab === tab.key
                  ? 'bg-white text-gray-900 shadow-sm'
                  : 'text-gray-500 hover:text-gray-700'
              }`}
            >
              <DynamicIcon name={tab.icon} className="h-4 w-4" />
              {tab.label}
            </button>
          ))}
        </div>
      )}

      {/* Search results */}
      {isSearching && (
        <div className="mb-6">
          <p className="text-sm text-gray-500 mb-4">
            {searchResults.length === 0
              ? `No results found for "${searchQuery}"`
              : `${searchResults.length} result${searchResults.length === 1 ? '' : 's'} for "${searchQuery}"`
            }
          </p>
          {searchResults.map((section) => (
            <CollapsibleSection
              key={section.id}
              section={section}
              isExpanded={expandedSections.has(section.id)}
              onToggle={() => toggleSection(section.id)}
              tabLabel={section.tabLabel}
            />
          ))}
        </div>
      )}

      {/* Tab content (hidden during search) */}
      {!isSearching && (
        <div>
          {currentTab.sections.map((section) => (
            <CollapsibleSection
              key={section.id}
              section={section}
              isExpanded={expandedSections.has(section.id)}
              onToggle={() => toggleSection(section.id)}
            />
          ))}

          {/* FAQ section in "More" tab */}
          {activeTab === 'more' && (
            <div className="mt-8">
              <h2 className="text-lg font-semibold text-gray-900 mb-4 flex items-center gap-2">
                <HelpCircle className="h-5 w-5 text-blue-600" />
                Frequently Asked Questions
              </h2>
              {FAQ_ITEMS.map((faq, idx) => (
                <FAQItem
                  key={idx}
                  item={faq}
                  isExpanded={expandedSections.has(`faq-${idx}`)}
                  onToggle={() => toggleSection(`faq-${idx}`)}
                />
              ))}
            </div>
          )}
        </div>
      )}

      {/* Back to top button */}
      {showBackToTop && (
        <button
          onClick={() => window.scrollTo({ top: 0, behavior: 'smooth' })}
          className="fixed bottom-6 right-6 bg-blue-600 text-white p-3 rounded-full shadow-lg hover:bg-blue-700 transition-colors z-50"
          aria-label="Back to top"
        >
          <ArrowUp className="h-5 w-5" />
        </button>
      )}
    </PageContainer>
  );
}
