import * as React from "react"

import { cn } from "@/lib/utils"

/**
 * FlipCard — presentational 3D flip between a front (question) and back (answer) face.
 *
 * The flip is CONTROLLED via the `isFlipped` prop. This component deliberately
 * contains NO SRS / rating / next-card logic — that behaviour is Sprint 4's job.
 *
 * 3D utilities (perspective / preserve-3d / backface-hidden / rotate-y-180 /
 * flip-transition) live in src/index.css @layer utilities, where reduced-motion
 * is also respected.
 *
 * NOTE: the faces are absolutely positioned, so give the wrapper an explicit
 * height (and width) via `className` (e.g. "h-48 w-80").
 *
 * Props:
 *  - front          (node)    front / question face content
 *  - back           (node)    back / answer face content
 *  - isFlipped      (bool)    controlled flip state (default false)
 *  - faceClassName  (string)  optional extra classes applied to BOTH faces
 *  - className      (string)  optional classes for the sizing wrapper
 */
const FlipCard = React.forwardRef(
  ({ className, front, back, isFlipped = false, faceClassName, ...props }, ref) => (
    <div ref={ref} className={cn("perspective-1000", className)} {...props}>
      <div
        className={cn(
          "relative h-full w-full preserve-3d flip-transition",
          isFlipped && "rotate-y-180"
        )}
      >
        {/* Front / question face */}
        <div
          className={cn(
            "absolute inset-0 backface-hidden flex items-center justify-center rounded-xl border border-surface-border bg-surface-card p-6 text-card-foreground shadow",
            faceClassName
          )}
        >
          {front}
        </div>
        {/* Back / answer face (pre-rotated so it faces out when flipped) */}
        <div
          className={cn(
            "absolute inset-0 backface-hidden rotate-y-180 flex items-center justify-center rounded-xl border border-brand-navy bg-brand-navy p-6 text-brand-navy-foreground shadow",
            faceClassName
          )}
        >
          {back}
        </div>
      </div>
    </div>
  )
)
FlipCard.displayName = "FlipCard"

export { FlipCard }
