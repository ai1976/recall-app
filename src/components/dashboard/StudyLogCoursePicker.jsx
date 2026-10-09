// T-002 F1 - the "Course" and optional "Subject" rows of the study-log picker (brief B 4.5).
//
// Presentational: the widget owns the choices. The course row is preselected (the student's current course) and always visible before Save; the subject is
// optional and skippable; General is one tap away; "Other" opens a typed course (or subject) that follows the same rule as every other course text.
// The options and their order are the database's (B-06a readers); nothing is added or reordered here.

import { useState } from 'react';
import { Input } from '@/components/ui/input';
import { cn } from '@/lib/utils';
import { validateCourseLabel } from '@/lib/courseLabel';
import { describeCourseRow } from '@/lib/courseOptions';

function optionClass(selected) {
  return cn(
    'h-8 w-full rounded-md border px-3 text-left text-xs transition-colors',
    selected ? 'border-amber-500 bg-amber-50 font-medium text-amber-800' : 'border-input hover:bg-muted'
  );
}

function courseSummary(course) {
  if (!course) return 'Choose a course';
  if (course.type === 'general') return 'General (no specific course)';
  if (course.type === 'other') return 'Other';
  return describeCourseRow(course.row);
}

function subjectSummary(subject) {
  if (!subject) return 'Skip';
  if (subject.type === 'other') return 'Other';
  return subject.row.label;
}

export default function StudyLogCoursePicker({
  courseStatus, courseRows, onRetryCourses,
  course, onCourse, courseText, onCourseText,
  subjectStatus, subjectRows, onRetrySubjects,
  subject, onSubject, subjectText, onSubjectText,
}) {
  const [courseOpen, setCourseOpen] = useState(false);
  const [subjectOpen, setSubjectOpen] = useState(false);

  const courseTextError = course && course.type === 'other' && courseText !== '' && !validateCourseLabel(courseText).ok ? validateCourseLabel(courseText).error : '';
  const subjectTextError = subject && subject.type === 'other' && subjectText !== '' && !validateCourseLabel(subjectText).ok
    ? validateCourseLabel(subjectText).error.replace('course name', 'subject name')
    : '';

  const hasSubjectStep = course && course.type !== 'general';
  const typedCourse = course && course.type === 'other';

  return (
    <div className="space-y-3" data-testid="study-log-course-picker">
      <div className="space-y-1.5">
        <p className="text-xs sm:text-sm font-medium leading-snug">Course</p>
        {(courseStatus === 'loading' || courseStatus === 'idle') && (
          <p className="text-xs text-muted-foreground">Loading courses...</p>
        )}
        {courseStatus === 'error' && (
          <p role="alert" className="text-xs text-red-600">
            The course list could not be loaded.{' '}
            <button type="button" className="underline" onClick={onRetryCourses}>Try again</button>
          </p>
        )}
        {courseStatus === 'ready' && (
          <>
            <button type="button" className={optionClass(true)} onClick={() => setCourseOpen((open) => !open)} aria-expanded={courseOpen}>
              {courseSummary(course)} <span className="text-muted-foreground">{courseOpen ? '(close)' : '(change)'}</span>
            </button>
            {courseOpen && (
              <div className="grid grid-cols-1 gap-1.5">
                {courseRows.map((row) => {
                  const isOther = row.kind === 'other_action';
                  const isGeneral = row.kind === 'general';
                  const selected = isOther ? course && course.type === 'other' : isGeneral ? course && course.type === 'general' : course && course.type === 'row' && course.row === row;
                  return (
                    <button
                      key={`${row.kind}-${row.label}`}
                      type="button"
                      className={optionClass(Boolean(selected))}
                      onClick={() => {
                        onCourse(isOther ? { type: 'other' } : isGeneral ? { type: 'general' } : { type: 'row', row });
                        setSubjectOpen(false);
                        if (!isOther) setCourseOpen(false);
                      }}
                    >
                      {isOther || isGeneral ? row.label : describeCourseRow(row)}
                    </button>
                  );
                })}
              </div>
            )}
          </>
        )}
        {typedCourse && (
          <div className="space-y-1">
            <Input
              value={courseText}
              onChange={(e) => onCourseText(e.target.value)}
              placeholder="Type your course"
              className="h-8 text-xs"
              aria-label="Your course"
              aria-invalid={courseTextError ? 'true' : 'false'}
            />
            {courseTextError && <p role="alert" className="text-xs text-red-600">{courseTextError}</p>}
          </div>
        )}
      </div>

      {hasSubjectStep && (
        <div className="space-y-1.5">
          <p className="text-xs sm:text-sm font-medium leading-snug">Subject <span className="font-normal text-muted-foreground">(optional)</span></p>
          {typedCourse ? (
            <div className="space-y-1">
              <Input
                value={subjectText}
                onChange={(e) => { onSubjectText(e.target.value); onSubject(e.target.value === '' ? null : { type: 'other' }); }}
                placeholder="Subject, if you want to add one"
                className="h-8 text-xs"
                aria-label="Subject"
                aria-invalid={subjectTextError ? 'true' : 'false'}
              />
              {subjectTextError && <p role="alert" className="text-xs text-red-600">{subjectTextError}</p>}
            </div>
          ) : (
            <>
              {(subjectStatus === 'loading' || subjectStatus === 'idle') && <p className="text-xs text-muted-foreground">Loading subjects...</p>}
              {subjectStatus === 'error' && (
                <p role="alert" className="text-xs text-red-600">
                  The subject list could not be loaded, so this log cannot be saved yet.{' '}
                  <button type="button" className="underline" onClick={onRetrySubjects}>Try again</button>
                </p>
              )}
              {subjectStatus === 'ready' && (
                <>
                  <button type="button" className={optionClass(true)} onClick={() => setSubjectOpen((open) => !open)} aria-expanded={subjectOpen}>
                    {subjectSummary(subject)} <span className="text-muted-foreground">{subjectOpen ? '(close)' : '(change)'}</span>
                  </button>
                  {subjectOpen && (
                    <div className="grid grid-cols-1 gap-1.5">
                      {subjectRows.map((row) => {
                        const isSkip = row.kind === 'skip';
                        const isOther = row.kind === 'other_action';
                        const selected = isSkip ? !subject : isOther ? subject && subject.type === 'other' : subject && subject.type === 'row' && subject.row === row;
                        return (
                          <button
                            key={`${row.kind}-${row.label}-${row.subject_id || ''}`}
                            type="button"
                            className={optionClass(Boolean(selected))}
                            onClick={() => {
                              onSubject(isSkip ? null : isOther ? { type: 'other' } : { type: 'row', row });
                              if (!isOther) setSubjectOpen(false);
                            }}
                          >
                            {row.label}
                          </button>
                        );
                      })}
                    </div>
                  )}
                  {subject && subject.type === 'other' && (
                    <div className="space-y-1">
                      <Input
                        value={subjectText}
                        onChange={(e) => onSubjectText(e.target.value)}
                        placeholder="Type the subject"
                        className="h-8 text-xs"
                        aria-label="Subject"
                        aria-invalid={subjectTextError ? 'true' : 'false'}
                      />
                      {subjectTextError && <p role="alert" className="text-xs text-red-600">{subjectTextError}</p>}
                    </div>
                  )}
                </>
              )}
            </>
          )}
        </div>
      )}
    </div>
  );
}
