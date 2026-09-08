/**
 * PageContainer.jsx
 * 
 * Reusable page wrapper component for consistent width and padding across all pages.
 * 
 * WIDTH CATEGORIES:
 * - full (default): max-w-7xl (~1280px) - Dashboard, Browse, Lists, Friends, Progress, Achievements
 * - medium: max-w-4xl (~896px) - Forms like Upload Note, Create Flashcard, Bulk Upload
 * - narrow: max-w-2xl (~672px) - Legal pages like Terms, Privacy Policy
 * 
 * USAGE:
 * import PageContainer from '@/components/layout/PageContainer';
 * 
 * <PageContainer width="full">
 *   <h1>Page Title</h1>
 *   ...content...
 * </PageContainer>
 */

import PropTypes from 'prop-types';

const WIDTH_CLASSES = {
  full: 'max-w-7xl',    // ~1280px - Lists, dashboards, browse pages
  medium: 'max-w-4xl',  // ~896px  - Forms, creation pages
  narrow: 'max-w-2xl',  // ~672px  - Legal, simple content pages
};

export default function PageContainer({ 
  children, 
  width = 'full',
  className = '',
  noPadding = false,
  noBackground = false,
}) {
  const widthClass = WIDTH_CLASSES[width] || WIDTH_CLASSES.full;

  // Mobile bottom-tab clearance (Sprint 7.1) — the fixed NavBottomTabs bar is
  // 3.5rem + iOS safe-area; pad the outer container so no page's last row / a
  // sticky CTA hides behind it. Removed at md (the bar is md:hidden).
  const bottomBarClearance = 'pb-[calc(3.5rem+env(safe-area-inset-bottom))] md:pb-0';

  // Base classes for outer container
  const outerClasses = noBackground
    ? `min-h-screen ${bottomBarClearance}`
    : `min-h-screen bg-rv-bg-0 ${bottomBarClearance}`;

  // Base classes for inner container
  const innerClasses = noPadding
    ? `${widthClass} mx-auto`
    : `${widthClass} mx-auto px-4 sm:px-6 lg:px-8 py-8`;

  return (
    <div className={outerClasses}>
      <div className={`${innerClasses} ${className}`.trim()}>
        {children}
      </div>
    </div>
  );
}

PageContainer.propTypes = {
  children: PropTypes.node.isRequired,
  width: PropTypes.oneOf(['full', 'medium', 'narrow']),
  className: PropTypes.string,
  noPadding: PropTypes.bool,
  noBackground: PropTypes.bool,
};