import * as React from "react"
import { cn } from "@/lib/utils"

// RevisOp reskin — Sprint 6.2. Same input-shell language as <Input>: --rv-*
// border, records-tier radius, Plex Sans, navy focus ring, tokenised
// disabled/error states.
const Textarea = React.forwardRef(({ className, ...props }, ref) => {
  return (
    <textarea
      className={cn(
        "flex min-h-[60px] w-full rounded-rec border border-rv-border bg-transparent px-3 py-2 font-plex text-sm text-rv-ink-900 shadow-sm placeholder:text-rv-ink-400 focus-visible:outline-none focus-visible:border-rv-navy-400 focus-visible:ring-2 focus-visible:ring-rv-navy disabled:cursor-not-allowed disabled:opacity-50 disabled:bg-rv-bg-2 aria-[invalid=true]:border-rv-danger aria-[invalid=true]:focus-visible:ring-rv-danger",
        className
      )}
      ref={ref}
      {...props}
    />
  )
})
Textarea.displayName = "Textarea"

export { Textarea }
