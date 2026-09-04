import * as React from "react"
import { cn } from "@/lib/utils"

// RevisOp reskin — Sprint 6.2. Shared chrome atom on the --rv-* token layer.
// Records-tier radius (rounded-rec). Focus ring navy (light) / accent (dark) —
// --rv-navy resolves to both. Error state via aria-invalid → --rv-danger edge.
// In light mode --rv-border === the old --input value, so the border colour is
// unchanged; the visible deltas are radius (6→4px), Plex Sans, and the navy
// focus ring.
const Input = React.forwardRef(({ className, type, ...props }, ref) => {
  return (
    <input
      type={type}
      className={cn(
        "flex h-9 w-full rounded-rec border border-rv-border bg-transparent px-3 py-1 font-plex text-sm text-rv-ink-900 shadow-sm transition-colors file:border-0 file:bg-transparent file:text-sm file:font-medium file:text-rv-ink-900 placeholder:text-rv-ink-400 focus-visible:outline-none focus-visible:border-rv-navy-400 focus-visible:ring-2 focus-visible:ring-rv-navy disabled:cursor-not-allowed disabled:opacity-50 disabled:bg-rv-bg-2 aria-[invalid=true]:border-rv-danger aria-[invalid=true]:focus-visible:ring-rv-danger",
        className
      )}
      ref={ref}
      {...props}
    />
  )
})
Input.displayName = "Input"

export { Input }
