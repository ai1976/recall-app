import * as React from "react"
import { Layers, Star } from "lucide-react"

import { cn } from "@/lib/utils"

/**
 * StudyItemCard — presentational deck / study-set list card.
 *
 * Purely prop-driven: NO data fetching, NO Supabase, NO routing logic.
 * Pass everything in via props; use `onClick` to make it interactive.
 * Styled with the RevisOp brand tokens (brand.navy / brand.amber / surface.*).
 *
 * Props:
 *  - title         (string)   card heading
 *  - subjectLabel  (string)   optional subject chip
 *  - topicLabel    (string)   optional topic chip
 *  - itemCount     (number)   optional study-item count ("Items" per nomenclature)
 *  - authorName    (string)   optional educator / author name
 *  - badgeLabel    (string)   optional "Featured" / "Expert" badge text
 *  - icon          (Component) optional lucide icon (defaults to Layers)
 *  - onClick       (fn)       optional — makes the card a keyboard-accessible button
 *  - className     (string)   optional extra classes
 */
const StudyItemCard = React.forwardRef(
  (
    {
      className,
      title,
      subjectLabel,
      topicLabel,
      itemCount,
      authorName,
      badgeLabel,
      icon: Icon = Layers,
      onClick,
      ...props
    },
    ref
  ) => {
    const isInteractive = typeof onClick === "function"
    return (
      <div
        ref={ref}
        onClick={onClick}
        role={isInteractive ? "button" : undefined}
        tabIndex={isInteractive ? 0 : undefined}
        onKeyDown={
          isInteractive
            ? (e) => {
                if (e.key === "Enter" || e.key === " ") {
                  e.preventDefault()
                  onClick(e)
                }
              }
            : undefined
        }
        className={cn(
          "group relative flex flex-col gap-4 rounded-xl border border-surface-border bg-surface-card p-5 text-left shadow-sm transition",
          isInteractive &&
            "cursor-pointer hover:-translate-y-0.5 hover:border-brand-amber/60 hover:shadow-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-amber",
          className
        )}
        {...props}
      >
        <div className="flex items-start justify-between gap-3">
          <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-lg bg-brand-navy text-brand-navy-foreground">
            <Icon className="h-5 w-5" />
          </span>
          {badgeLabel ? (
            <span className="inline-flex items-center gap-1 rounded-full bg-brand-amber/15 px-2.5 py-1 text-xs font-semibold text-brand-amber">
              <Star className="h-3 w-3 fill-current" />
              {badgeLabel}
            </span>
          ) : null}
        </div>

        <div className="space-y-1.5">
          <h3 className="font-semibold leading-tight tracking-tight text-brand-navy">
            {title}
          </h3>
          {(subjectLabel || topicLabel) && (
            <div className="flex flex-wrap gap-1.5">
              {subjectLabel ? (
                <span className="inline-flex items-center rounded-md bg-surface-navy px-2 py-0.5 text-xs font-medium text-brand-navy">
                  {subjectLabel}
                </span>
              ) : null}
              {topicLabel ? (
                <span className="inline-flex items-center rounded-md bg-surface-amber px-2 py-0.5 text-xs font-medium text-brand-amber">
                  {topicLabel}
                </span>
              ) : null}
            </div>
          )}
        </div>

        <div className="mt-auto flex items-center justify-between text-sm text-muted-foreground">
          {typeof itemCount === "number" ? (
            <span className="font-medium text-foreground">
              {itemCount} {itemCount === 1 ? "item" : "items"}
            </span>
          ) : (
            <span />
          )}
          {authorName ? <span className="truncate">by {authorName}</span> : null}
        </div>
      </div>
    )
  }
)
StudyItemCard.displayName = "StudyItemCard"

export { StudyItemCard }
