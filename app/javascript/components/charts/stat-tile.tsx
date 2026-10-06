import { cn } from "@/lib/utils"

/**
 * One headline number. The value uses proportional figures, as it is large and
 * stands alone; tabular figures are for columns that must line up.
 */
export function StatTile({
  label,
  value,
  hint,
  critical = false,
}: {
  label: string
  value: string
  hint?: string
  /** Marks a value that needs attention. The color is paired with the hint text. */
  critical?: boolean
}) {
  return (
    <div className="border-sidebar-border/70 bg-card dark:border-sidebar-border rounded-xl border p-4">
      <p className="text-muted-foreground text-sm">{label}</p>
      <p
        className={cn(
          "mt-1 text-3xl font-semibold tracking-tight",
          critical && "text-(--viz-critical)",
        )}
      >
        {value}
      </p>
      {hint && <p className="text-muted-foreground mt-1 text-xs">{hint}</p>}
    </div>
  )
}
