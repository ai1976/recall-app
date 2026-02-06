import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
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
  const { toast } = useToast();
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [loading, setLoading] = useState(false);

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
