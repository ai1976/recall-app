import * as React from "react"
import * as SwitchPrimitives from "@radix-ui/react-switch"
import { cn } from "@/lib/utils"

// RevisOp reskin — Sprint 6.3. On-state navy (--rv-navy), off-state
// --rv-border-strong, navy focus ring. No shadcn token value edited.

const Switch = React.forwardRef(({ className, ...props }, ref) => (
  <SwitchPrimitives.Root
    className={cn(
      "peer inline-flex h-6 w-11 shrink-0 cursor-pointer items-center rounded-full border-2 border-transparent transition-colors",
      "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-rv-navy focus-visible:ring-offset-2 focus-visible:ring-offset-rv-bg-1",
      "disabled:cursor-not-allowed disabled:opacity-50",
      "data-[state=checked]:bg-rv-navy data-[state=unchecked]:bg-rv-border-strong",
      className
    )}
    {...props}
    ref={ref}
  >
    <SwitchPrimitives.Thumb
      className={cn(
        "pointer-events-none block h-5 w-5 rounded-full bg-rv-bg-1 shadow-lg ring-0 transition-transform",
        "data-[state=checked]:translate-x-5 data-[state=unchecked]:translate-x-0"
      )}
    />
  </SwitchPrimitives.Root>
))
Switch.displayName = SwitchPrimitives.Root.displayName

export { Switch }
