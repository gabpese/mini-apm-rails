import { Link, router, usePage } from "@inertiajs/react"

import { ToggleGroup, ToggleGroupItem } from "@/components/ui/toggle-group"
import { cn } from "@/lib/utils"
import { editProject, project, projectErrors, projectVersions } from "@/routes"
import type { RouteDefinition } from "@/routes/runtime"
import type { ProjectRef } from "@/types"

interface Tab {
  title: string
  route: (id: number, days?: number) => RouteDefinition<"get">
  /** Whether the page depends on the selected period. */
  period: boolean
}

const withDays = (days?: number) => (days ? { query: { days } } : undefined)

const tabs: Tab[] = [
  {
    title: "Overview",
    route: (id, days) => project(id, withDays(days)),
    period: true,
  },
  {
    title: "Errors",
    route: (id, days) => projectErrors(id, withDays(days)),
    period: true,
  },
  {
    title: "Versions",
    route: (id, days) => projectVersions(id, withDays(days)),
    period: true,
  },
  { title: "Settings", route: (id) => editProject(id), period: false },
]

/**
 * Title, tabs and period selector shared by the project pages. Switching tabs
 * keeps the chosen period.
 */
export function ProjectHeader({
  project: current,
  days,
  periods,
}: {
  project: ProjectRef
  /** The selected period. Leave out on pages that do not use one. */
  days?: number
  periods?: number[]
}) {
  const { url } = usePage()
  const path = new URL(url, "http://localhost").pathname

  return (
    <header className="space-y-3">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h1 className="text-xl font-semibold tracking-tight">{current.name}</h1>

        {days !== undefined && periods && (
          <ToggleGroup
            type="single"
            variant="outline"
            size="sm"
            value={String(days)}
            aria-label="Period"
            onValueChange={(value) => {
              // An empty value means the active item was clicked again: keep it.
              if (value) {
                router.get(
                  path,
                  { days: value },
                  { preserveScroll: true, preserveState: true },
                )
              }
            }}
          >
            {periods.map((period) => (
              <ToggleGroupItem key={period} value={String(period)}>
                {period} days
              </ToggleGroupItem>
            ))}
          </ToggleGroup>
        )}
      </div>

      <nav aria-label="Project" className="border-border flex gap-1 border-b">
        {tabs.map((tab) => {
          const route = tab.route(current.id, tab.period ? days : undefined)
          const active = path === tab.route(current.id).url

          return (
            <Link
              key={tab.title}
              href={route}
              prefetch
              aria-current={active ? "page" : undefined}
              className={cn(
                "-mb-px border-b-2 px-3 py-2 text-sm transition-colors",
                active
                  ? "border-foreground text-foreground font-medium"
                  : "text-muted-foreground hover:text-foreground border-transparent",
              )}
            >
              {tab.title}
            </Link>
          )
        })}
      </nav>
    </header>
  )
}
