import * as React from "react"
import * as LabelPrimitive from "@radix-ui/react-label"
import { cva } from "class-variance-authority"
import { cn } from "@/lib/utils"

// RevisOp reskin — Sprint 6.2. Form-field label chrome atom: Plex Sans + --rv-*
// ink. (Distinct from src/components/revisop/Label.jsx, which is the uppercase
// section eyebrow.)
const labelVariants = cva(
  "font-plex text-sm font-medium leading-none text-rv-ink-900 peer-disabled:cursor-not-allowed peer-disabled:opacity-70"
)

const Label = React.forwardRef(({ className, ...props }, ref) => (
  <LabelPrimitive.Root
    ref={ref}
    className={cn(labelVariants(), className)}
    {...props}
  />
))
Label.displayName = LabelPrimitive.Root.displayName

export { Label }
