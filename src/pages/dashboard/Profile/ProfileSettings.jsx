import { useState, useEffect } from 'react';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { useCourseContext } from '@/contexts/CourseContext';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { SearchableSelect } from '@/components/ui/SearchableSelect';
import { Save, Loader2, Plus, X, Star, GraduationCap } from 'lucide-react';
import { useToast } from '@/hooks/use-toast';
import PageContainer from '@/components/layout/PageContainer';

const COURSE_LEVELS = [
  'CA Foundation',
  'CA Intermediate',
  'CA Final',
];

// Static curated list — sorted alphabetically, "Other" always last.
// To add new institutions, append to this array before "Other".
const INSTITUTION_OPTIONS = [
  'Aldine CA',
  'Ambitions Commerce Institute Pvt Ltd',
  'EduSum',
  'Ektvam Academy',
  'JK Shah Classes',
  'More Classes Commerce',
  'PhysicsWallah',
  'Self Study',
  'Swapnil Patni Classes',
  'The Institute of Chartered Accountants of India (ICAI)',
  'Unacademy',
  'Other',
];

function toTitleCase(str) {
  return str
    .toLowerCase()
    .split(' ')
    .map(word => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ');
}

export default function ProfileSettings() {
  const { user } = useAuth();
  const { toast } = useToast();

  // Course context (multi-course features for professors/admins/super_admins)
  const {
    teachingCourses,
    isContentCreator,
    addCourse,
    removeCourse,
    setPrimaryCourse,
    refetchTeachingCourses,
    loading: courseLoading,
  } = useCourseContext();

  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [fullName, setFullName] = useState('');
  const [courseLevel, setCourseLevel] = useState('');
  const [institutionSelect, setInstitutionSelect] = useState('');
  const [customInstitution, setCustomInstitution] = useState('');
  const [email, setEmail] = useState('');

  // Teaching Areas state
  const [allDisciplines, setAllDisciplines] = useState([]);         // all active disciplines from DB
  const [selectedNewCourse, setSelectedNewCourse] = useState('');   // discipline_id to add
  const [addingCourse, setAddingCourse] = useState(false);
  const [removingId, setRemovingId] = useState(null);               // profile_courses.id being removed
  const [settingPrimaryId, setSettingPrimaryId] = useState(null);   // profile_courses.id being promoted

  useEffect(() => {
    fetchProfile();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user?.id]);

  // Load disciplines for the "Add Course" dropdown (professors/admins only)
  useEffect(() => {
    if (!isContentCreator) return;
    supabase
      .from('disciplines')
      .select('id, name')
      .eq('is_active', true)
      .order('order_num')
      .order('name')
      .then(({ data }) => {
        if (data) setAllDisciplines(data);
      });
  }, [isContentCreator]);

  const fetchProfile = async () => {
    try {
      const { data, error } = await supabase
        .from('profiles')
        .select('full_name, email, course_level, institution')
        .eq('id', user.id)
        .single();

      if (error) throw error;

      setFullName(data.full_name || '');
      setEmail(data.email || '');
      setCourseLevel(data.course_level || '');

      // Determine if saved institution matches a preset or is custom
      if (data.institution) {
        const presetMatch = INSTITUTION_OPTIONS.find(
          opt => opt !== 'Other' && opt === data.institution
        );
        if (presetMatch) {
          setInstitutionSelect(presetMatch);
          setCustomInstitution('');
        } else {
          setInstitutionSelect('Other');
          setCustomInstitution(data.institution);
        }
      }
    } catch (error) {
      console.error('Error fetching profile:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleSave = async () => {
    // Determine final institution value
    let finalInstitution = '';
    if (institutionSelect === 'Other') {
      const trimmed = customInstitution.trim();
      finalInstitution = trimmed ? toTitleCase(trimmed) : '';
    } else {
      finalInstitution = institutionSelect;
    }

    const trimmedName = fullName.trim();
    if (!trimmedName) {
      toast({
        title: 'Name required',
        description: 'Please enter your full name.',
        variant: 'destructive',
      });
      return;
    }

    setSaving(true);
    try {
      const { error } = await supabase
        .from('profiles')
        .update({
          full_name: trimmedName,
          course_level: courseLevel || null,
          institution: finalInstitution || null,
        })
        .eq('id', user.id);

      if (error) throw error;

      toast({
        title: 'Profile updated',
        description: 'Your changes have been saved.',
      });
    } catch (error) {
      console.error('Error saving profile:', error);
      toast({
        title: 'Error',
        description: error.message,
        variant: 'destructive',
      });
    } finally {
      setSaving(false);
    }
  };

  // ── Teaching Areas handlers ──────────────────────────────────────────────

  const handleAddCourse = async () => {
    if (!selectedNewCourse) return;
    setAddingCourse(true);
    const { error } = await addCourse(selectedNewCourse);
    if (error) {
      toast({ title: 'Error adding course', description: error.message, variant: 'destructive' });
    } else {
      toast({ title: 'Course added', description: 'New teaching course added to your profile.' });
      setSelectedNewCourse('');
    }
    setAddingCourse(false);
  };

  const handleRemoveCourse = async (profileCourseId, isPrimary) => {
    if (isPrimary) {
      toast({
        title: 'Cannot remove primary course',
        description: 'Set another course as primary first, then remove this one.',
        variant: 'destructive',
      });
      return;
    }
    setRemovingId(profileCourseId);
    const { error } = await removeCourse(profileCourseId);
    if (error) {
      toast({ title: 'Error removing course', description: error.message, variant: 'destructive' });
    } else {
      toast({ title: 'Course removed' });
    }
    setRemovingId(null);
  };

  const handleSetPrimary = async (profileCourseId, disciplineName) => {
    setSettingPrimaryId(profileCourseId);
    const { error } = await setPrimaryCourse(profileCourseId, disciplineName);
    if (error) {
      toast({ title: 'Error setting primary', description: error.message, variant: 'destructive' });
    } else {
      // Also update the local courseLevel state so the dropdown above reflects the new primary
      setCourseLevel(disciplineName);
      toast({
        title: 'Primary course updated',
        description: `${disciplineName} is now your primary course.`,
      });
    }
    setSettingPrimaryId(null);
  };

  // Disciplines not yet in teachingCourses (available to add)
  const availableDisciplines = allDisciplines.filter(
    (d) => !teachingCourses.some((tc) => tc.discipline_id === d.id)
  );

  if (loading || courseLoading) {
    return (
      <PageContainer width="narrow">
        <div className="flex items-center justify-center py-20">
          <Loader2 className="h-8 w-8 animate-spin text-gray-400" />
        </div>
      </PageContainer>
    );
  }

  return (
    <PageContainer width="narrow">
      <div className="mb-6">
        <h1 className="text-3xl font-bold mb-2">Profile Settings</h1>
        <p className="text-gray-600">
          Update your profile information
        </p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Personal Information</CardTitle>
          <CardDescription>
            This information is visible to other users on the platform.
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          {/* Email (read-only) */}
          <div className="space-y-2">
            <Label htmlFor="email">Email</Label>
            <Input
              id="email"
              value={email}
              disabled
              className="bg-gray-50"
            />
            <p className="text-xs text-gray-500">
              Email is managed by your login account and cannot be changed here.
            </p>
          </div>

          {/* Full Name */}
          <div className="space-y-2">
            <Label htmlFor="fullName">Full Name</Label>
            <Input
              id="fullName"
              value={fullName}
              onChange={(e) => setFullName(e.target.value)}
              placeholder="Enter your full name"
            />
          </div>

          {/* Primary Course */}
          <div className="space-y-2">
            <Label>Primary Course</Label>
            <Select value={courseLevel} onValueChange={setCourseLevel}>
              <SelectTrigger>
                <SelectValue placeholder="Select your active course" />
              </SelectTrigger>
              <SelectContent>
                {COURSE_LEVELS.map((level) => (
                  <SelectItem key={level} value={level}>
                    {level}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          {/* Institution */}
          <div className="space-y-2">
            <Label>Institution</Label>
            <SearchableSelect
              value={institutionSelect}
              onValueChange={(val) => {
                setInstitutionSelect(val);
                if (val !== 'Other') setCustomInstitution('');
              }}
              options={INSTITUTION_OPTIONS}
              placeholder="Select your institution"
            />
            {institutionSelect === 'Other' && (
              <Input
                value={customInstitution}
                onChange={(e) => setCustomInstitution(e.target.value)}
                placeholder="Enter your institution name"
                className="mt-2"
              />
            )}
          </div>

          {/* Save Button */}
          <Button onClick={handleSave} disabled={saving} className="w-full">
            {saving ? (
              <Loader2 className="h-4 w-4 mr-2 animate-spin" />
            ) : (
              <Save className="h-4 w-4 mr-2" />
            )}
            {saving ? 'Saving...' : 'Save Changes'}
          </Button>
        </CardContent>
      </Card>

      {/* ── Teaching Areas (professors, admins, super_admins only) ── */}
      {isContentCreator && (
        <Card className="mt-6">
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <GraduationCap className="h-5 w-5 text-indigo-600" />
              My Teaching Areas
            </CardTitle>
            <CardDescription>
              Add all courses you create content for. The <strong>Primary</strong> course is shown
              on your author profile and used as the default dashboard context.
              Switching the primary course also updates your &quot;Primary Course&quot; field above.
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">

            {/* Current teaching courses list */}
            {teachingCourses.length === 0 ? (
              <p className="text-sm text-gray-500 py-2">
                No teaching courses added yet. Add your first course below.
              </p>
            ) : (
              <div className="space-y-2">
                {teachingCourses.map((course) => {
                  const name      = course.disciplines?.name || 'Unknown';
                  const isPrimary = course.is_primary;

                  return (
                    <div
                      key={course.id}
                      className={`flex items-center justify-between px-3 py-2.5 rounded-lg border ${
                        isPrimary
                          ? 'border-indigo-200 bg-indigo-50'
                          : 'border-gray-200 bg-white'
                      }`}
                    >
                      {/* Course name + primary badge */}
                      <div className="flex items-center gap-2 min-w-0">
                        <span className="text-sm font-medium text-gray-900 truncate">{name}</span>
                        {isPrimary && (
                          <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-semibold bg-indigo-100 text-indigo-700 flex-shrink-0">
                            <Star className="h-3 w-3" />
                            Primary
                          </span>
                        )}
                      </div>

                      {/* Action buttons */}
                      <div className="flex items-center gap-2 flex-shrink-0 ml-3">
                        {/* Set as Primary — only for non-primary courses */}
                        {!isPrimary && (
                          <Button
                            variant="ghost"
                            size="sm"
                            className="h-7 px-2 text-xs text-gray-500 hover:text-indigo-700 hover:bg-indigo-50"
                            onClick={() => handleSetPrimary(course.id, name)}
                            disabled={settingPrimaryId === course.id}
                            title="Set as primary course"
                          >
                            {settingPrimaryId === course.id ? (
                              <Loader2 className="h-3.5 w-3.5 animate-spin" />
                            ) : (
                              <Star className="h-3.5 w-3.5" />
                            )}
                            <span className="ml-1">Set Primary</span>
                          </Button>
                        )}

                        {/* Remove — disabled for primary (must demote first) */}
                        <Button
                          variant="ghost"
                          size="sm"
                          className={`h-7 px-2 ${
                            isPrimary
                              ? 'text-gray-300 cursor-not-allowed'
                              : 'text-gray-400 hover:text-red-600 hover:bg-red-50'
                          }`}
                          onClick={() => handleRemoveCourse(course.id, isPrimary)}
                          disabled={removingId === course.id || isPrimary}
                          title={isPrimary ? 'Cannot remove primary course — set another as primary first' : 'Remove course'}
                        >
                          {removingId === course.id ? (
                            <Loader2 className="h-3.5 w-3.5 animate-spin" />
                          ) : (
                            <X className="h-3.5 w-3.5" />
                          )}
                        </Button>
                      </div>
                    </div>
                  );
                })}
              </div>
            )}

            {/* Add Course row */}
            {availableDisciplines.length > 0 && (
              <div className="flex items-center gap-2 pt-2">
                <div className="flex-1">
                  <Select value={selectedNewCourse} onValueChange={setSelectedNewCourse}>
                    <SelectTrigger className="h-9 text-sm">
                      <SelectValue placeholder="Select a course to add…" />
                    </SelectTrigger>
                    <SelectContent>
                      {availableDisciplines.map((d) => (
                        <SelectItem key={d.id} value={d.id}>
                          {d.name}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <Button
                  size="sm"
                  className="h-9 px-3 flex-shrink-0"
                  onClick={handleAddCourse}
                  disabled={!selectedNewCourse || addingCourse}
                >
                  {addingCourse ? (
                    <Loader2 className="h-4 w-4 animate-spin" />
                  ) : (
                    <Plus className="h-4 w-4" />
                  )}
                  <span className="ml-1">Add</span>
                </Button>
              </div>
            )}

            {availableDisciplines.length === 0 && teachingCourses.length > 0 && (
              <p className="text-xs text-gray-400 pt-1">
                You have added all available courses.
              </p>
            )}
          </CardContent>
        </Card>
      )}
    </PageContainer>
  );
}
