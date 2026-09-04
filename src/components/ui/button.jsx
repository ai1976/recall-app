import * as React from "react"
import { Slot } from "@radix-ui/react-slot"
import { cva } from "class-variance-authority"
import { cn } from "@/lib/utils"

// RevisOp reskin — Sprint 6.2. Shared chrome atom migrated onto the additive
// --rv-* token layer + Plex Sans. Records-tier radius (rounded-rec = 4px).
// Variant mapping (blueprint §Chrome / Sprint 6.2):
//   default     → navy fill                (--rv-navy, flips to accent in dark)
//   secondary   → navy-tint fill
//   outline     → navy border, neutral ink
//   ghost       → no chrome until hover     (matches nav inactive language)
//   link        → navy text link
//   destructive → --rv-danger (#b91c1c)     — delete-confirmations only
// Focus ring is navy in light / accent in dark (one token, --rv-navy, does both).
// NOTE: GradeButtonRow does NOT use this atom (raw <button>) — study-loop
// grade styling stays a 6.4 concern and is untouched here.
const buttonVariants = cva(
  "inline-flex items-center justify-center whitespace-nowrap rounded-rec font-plex text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-rv-navy focus-visible:ring-offset-1 focus-visible:ring-offset-rv-bg-1 disabled:pointer-events-none disabled:opacity-50",
  {
    variants: {
      variant: {
        default: "bg-rv-navy text-rv-bg-1 shadow-sm hover:bg-rv-navy-400",
        destructive: "bg-rv-danger text-white shadow-sm hover:bg-rv-danger/90",
        outline: "border border-rv-navy-400 bg-rv-bg-1 text-rv-ink-900 shadow-sm hover:bg-rv-navy-50 hover:text-rv-navy",
        secondary: "bg-rv-navy-50 text-rv-navy shadow-sm hover:bg-rv-navy-100",
        ghost: "text-rv-ink-600 hover:bg-rv-bg-2 hover:text-rv-ink-900",
        link: "text-rv-navy underline-offset-4 hover:underline",
      },
      size: {
        default: "h-9 px-4 py-2",
        sm: "h-8 rounded-rec px-3 text-xs",
        lg: "h-10 rounded-rec px-8",
        icon: "h-9 w-9",
      },
    },
    defaultVariants: {
      variant: "default",
      size: "default",
    },
  }
)

const Button = React.forwardRef(({ className, variant, size, asChild = false, ...props }, ref) => {
  const Comp = asChild ? Slot : "button"
  return (
    <Comp
      className={cn(buttonVariants({ variant, size, className }))}
      ref={ref}
      {...props}
    />
  )
})
Button.displayName = "Button"

export { Button, buttonVariants }
