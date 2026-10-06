import { Head } from "@inertiajs/react"
import { CircleCheck } from "lucide-react"

import { ProjectHeader } from "@/components/projects/project-header"
import AppLayout from "@/layouts/app-layout"
import { formatDateTime, formatNumber, formatRelative } from "@/lib/format"
import { dashboard, project as projectRoute, projectErrors } from "@/routes"
import type { ErrorGroupRow, ReportProps } from "@/types"

type Props = ReportProps & {
  groups: ErrorGroupRow[]
}

export default function Errors({ project, days, periods, groups }: Props) {
  return (
    <AppLayout
      breadcrumbs={[
        { title: "Projects", href: dashboard.index().url },
        { title: project.name, href: projectRoute(project.id).url },
        { title: "Errors", href: projectErrors(project.id).url },
      ]}
    >
      <Head title={`Errors · ${project.name}`} />

      <div className="flex flex-col gap-4 p-4">
        <ProjectHeader project={project} days={days} periods={periods} />

        <p className="text-muted-foreground text-sm">
          Equal errors are grouped by their message and the first line of the
          stack. Counts cover the last {days} days.
        </p>

        {groups.length === 0 ? (
          <div className="border-sidebar-border/70 dark:border-sidebar-border flex flex-col items-center gap-2 rounded-xl border border-dashed px-6 py-14 text-center">
            <CircleCheck className="text-muted-foreground size-7" aria-hidden />
            <p className="font-medium">No errors in this period</p>
          </div>
        ) : (
          <div className="border-sidebar-border/70 bg-card dark:border-sidebar-border overflow-x-auto rounded-xl border">
            <table className="w-full text-sm">
              <thead className="text-muted-foreground text-left text-xs">
                <tr className="border-border border-b">
                  <th className="px-4 py-2 font-medium">Error</th>
                  <th className="px-4 py-2 text-right font-medium">
                    Occurrences
                  </th>
                  <th className="px-4 py-2 text-right font-medium">Crashes</th>
                  <th className="px-4 py-2 font-medium">First seen</th>
                  <th className="px-4 py-2 font-medium">Last seen</th>
                </tr>
              </thead>
              <tbody>
                {groups.map((group) => (
                  <tr
                    key={group.id}
                    className="border-border/60 border-b last:border-0"
                  >
                    <td className="max-w-md px-4 py-2.5 font-mono text-xs break-words">
                      {group.message}
                    </td>
                    <td className="px-4 py-2.5 text-right tabular-nums">
                      {formatNumber(group.occurrences)}
                    </td>
                    <td className="px-4 py-2.5 text-right tabular-nums">
                      {formatNumber(group.crashes)}
                    </td>
                    <td className="text-muted-foreground px-4 py-2.5 whitespace-nowrap">
                      {formatDateTime(group.first_seen_at)}
                    </td>
                    <td
                      className="text-muted-foreground px-4 py-2.5 whitespace-nowrap"
                      title={formatDateTime(group.last_seen_at)}
                    >
                      {formatRelative(group.last_seen_at)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </AppLayout>
  )
}
