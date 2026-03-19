import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { useToast } from '@/hooks/use-toast';
import PageContainer from '@/components/layout/PageContainer';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { ArrowLeft } from 'lucide-react';

export default function CreateGroup() {
  const navigate = useNavigate();
  const { user } = useAuth();
  const { toast } = useToast();
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [loading, setLoading] = useState(false);

  // Group type state
  const [userCourseLevel, setUserCourseLevel] = useState(null);
  const [selectedOption, setSelectedOption] = useState(null); // 'system_course' | 'custom'
  const [customCourseName, setCustomCourseName] = useState('');

  useEffect(() => {
    async function fetchProfile() {
      const { data } = await supabase
        .from('profiles')
        .select('course_level')
        .eq('id', user.id)
        .single();
      if (data?.course_level) {
        setUserCourseLevel(data.course_level);
        setSelectedOption('system_course');
      } else {
        setSelectedOption('custom');
      }
    }
    fetchProfile();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!name.trim()) {
      toast({
        title: 'Error',
        description: 'Group name is required',
        variant: 'destructive',
      });
      return;
    }

    setLoading(true);
    try {
      const { data: groupId, error } = await supabase.rpc('create_study_group', {
        p_name: name.trim(),
        p_description: description.trim() || null,
        p_group_type: selectedOption === 'system_course' ? 'system_course' : 'custom',
        p_linked_course: selectedOption === 'system_course' ? userCourseLevel : null,
      });
      if (error) throw error;

      toast({ title: 'Group created!', description: `"${name.trim()}" is ready` });
      navigate(`/dashboard/groups/${groupId}`);
    } catch (error) {
      console.error('Error creating group:', error);
      toast({
        title: 'Error',
        description: error.message || 'Failed to create group',
        variant: 'destructive',
      });
    } finally {
      setLoading(false);
    }
  };

  return (
    <PageContainer width="medium">
      <Button variant="ghost" onClick={() => navigate(-1)} className="mb-6">
        <ArrowLeft className="mr-2 h-4 w-4" />
        Back
      </Button>

      <div className="space-y-6">
        <div>
          <h1 className="text-3xl font-bold">Create Study Group</h1>
          <p className="text-muted-foreground mt-2">
            Create a group to share notes and flashcards with selected classmates
          </p>
        </div>

        <form onSubmit={handleSubmit} className="space-y-6">
          <Card>
            <CardHeader>
              <CardTitle>Group Details</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="group-name">Group Name *</Label>
                <Input
                  id="group-name"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  placeholder="e.g., CA Inter May 2026, Audit Study Circle"
                  maxLength={100}
                  required
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="group-description">Description (Optional)</Label>
                <Textarea
                  id="group-description"
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                  placeholder="What is this group for?"
                  rows={3}
                  maxLength={500}
                />
              </div>
            </CardContent>
          </Card>

          {/* Group type selector */}
          <Card>
            <CardHeader>
              <CardTitle>This group is for</CardTitle>
            </CardHeader>
            <CardContent className="space-y-3">
              {userCourseLevel && (
                <label className="flex items-start gap-3 p-3 border rounded-lg cursor-pointer hover:border-blue-400 transition-colors"
                  style={{ borderColor: selectedOption === 'system_course' ? '#3b82f6' : undefined,
                           background: selectedOption === 'system_course' ? '#eff6ff' : undefined }}>
                  <input
                    type="radio"
                    name="groupType"
                    value="system_course"
                    checked={selectedOption === 'system_course'}
                    onChange={() => setSelectedOption('system_course')}
                    className="mt-0.5"
                  />
                  <div>
                    <p className="font-medium text-sm">{userCourseLevel}</p>
                    <p className="text-xs text-gray-500">Group linked to your course</p>
                  </div>
                </label>
              )}
              <label className="flex items-start gap-3 p-3 border rounded-lg cursor-pointer hover:border-blue-400 transition-colors"
                style={{ borderColor: selectedOption === 'custom' ? '#3b82f6' : undefined,
                         background: selectedOption === 'custom' ? '#eff6ff' : undefined }}>
                <input
                  type="radio"
                  name="groupType"
                  value="custom"
                  checked={selectedOption === 'custom'}
                  onChange={() => setSelectedOption('custom')}
                  className="mt-0.5"
                />
                <div className="flex-1">
                  <p className="font-medium text-sm">Custom / Other</p>
                  <p className="text-xs text-gray-500">Any topic, language, or exam</p>
                  {selectedOption === 'custom' && (
                    <Input
                      className="mt-2"
                      placeholder="e.g. French language, UPSC Polity, Photography"
                      value={customCourseName}
                      onChange={(e) => setCustomCourseName(e.target.value)}
                      maxLength={100}
                    />
                  )}
                </div>
              </label>
            </CardContent>
          </Card>

          <Card className="bg-blue-50 border-blue-200">
            <CardContent className="pt-6">
              <p className="text-sm text-blue-800">
                You will be the admin of this group. After creating it, you can invite members and share your notes/flashcards with them.
              </p>
            </CardContent>
          </Card>

          <div className="flex gap-4">
            <Button
              type="button"
              variant="outline"
              onClick={() => navigate(-1)}
              className="flex-1"
            >
              Cancel
            </Button>
            <Button type="submit" disabled={loading} className="flex-1">
              {loading ? 'Creating...' : 'Create Group'}
            </Button>
          </div>
        </form>
      </div>
    </PageContainer>
  );
}
