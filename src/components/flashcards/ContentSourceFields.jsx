import { Label } from '@/components/ui/label';
import { Input } from '@/components/ui/input';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';

/**
 * Content provenance fields (Sprint 8.7.2) — required before calling
 * create_flashcard_batches(), shared by FlashcardCreate.jsx (manual) and
 * BulkUploadFlashcards.jsx (CSV). `compact` matches BulkUploadFlashcards.jsx's
 * denser stepper styling (text-sm labels, mt-1 spacing) instead of
 * FlashcardCreate.jsx's default Card spacing (space-y-2).
 */
export default function ContentSourceFields({
  sourceType,
  onSourceTypeChange,
  sourceName,
  onSourceNameChange,
  idPrefix = 'source',
  compact = false,
  showCaption = false,
}) {
  const labelClass = compact ? 'text-sm' : undefined;
  const controlClass = compact ? 'mt-1' : undefined;
  const wrapperClass = compact ? undefined : 'space-y-2';

  return (
    <>
      <div className={wrapperClass}>
        <Label htmlFor={`${idPrefix}-type`} className={labelClass}>
          Where is this content from? <span className="text-red-500">*</span>
        </Label>
        <Select value={sourceType} onValueChange={onSourceTypeChange}>
          <SelectTrigger id={`${idPrefix}-type`} className={controlClass}>
            <SelectValue placeholder="Select source type..." />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="official_body">Official body (e.g. ICAI, university, board)</SelectItem>
            <SelectItem value="original_creator">Original creator (you wrote this yourself)</SelectItem>
          </SelectContent>
        </Select>
      </div>
      <div className={wrapperClass}>
        <Label htmlFor={`${idPrefix}-name`} className={labelClass}>
          Source name <span className="text-red-500">*</span>
        </Label>
        <Input
          id={`${idPrefix}-name`}
          value={sourceName}
          onChange={(e) => onSourceNameChange(e.target.value)}
          placeholder="e.g. ICAI Study Material, or your own name"
          className={controlClass}
        />
        {showCaption && (
          <p className="text-sm text-muted-foreground">Applies to every item created in this save</p>
        )}
      </div>
    </>
  );
}
