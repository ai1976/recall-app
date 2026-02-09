import { useState, useEffect } from 'react';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { SearchableSelect } from '@/components/ui/SearchableSelect';
import { Save, Loader2 } from 'lucide-react';
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

  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [fullName, setFullName] = useState('');
  const [courseLevel, setCourseLevel] = useState('');
  const [institutionSelect, setInstitutionSelect] = useState('');
  const [customInstitution, setCustomInstitution] = useState('');
  const [email, setEmail] = useState('');

  useEffect(() => {
    fetchProfile();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user?.id]);

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

  if (loading) {
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
    </PageContainer>
  );
}
