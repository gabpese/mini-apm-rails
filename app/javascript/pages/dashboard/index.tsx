import { Form, Head, Link } from "@inertiajs/react"
import { FolderPlus, TriangleAlert } from "lucide-react"

import { Button } from "@/components/ui/button"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog"
import { Field, FieldError, FieldLabel } from "@/components/ui/field"
import { Input } from "@/components/ui/input"
import AppLayout from "@/layouts/app-layout"
import { formatNumber, formatPercent } from "@/lib/format"
import { dashboard, project, projects } from "@/routes"
import type { BreadcrumbItem, ProjectSummary } from "@/types"

const breadcrumbs: BreadcrumbItem[] = [
  { title: "Projects", href: dashboard.index().url },
]

export default function Dashboard({
  projects: summaries,
  period,
}: {
  projects: ProjectSummary[]
  period: number
}) {
  return (
    <AppLayout breadcrumbs={breadcrumbs}>
      <Head title="Projects" />

      <div className="flex flex-col gap-6 p-4">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div>
            <h1 className="text-xl font-semibold tracking-tight">Projects</h1>
            <p className="text-muted-foreground text-sm">
              One project per monitored application. Numbers cover the last{" "}
              {period} days.
            </p>
          </div>
          <NewProject />
        </div>

        {summaries.length === 0 ? (
          <EmptyState />
        ) : (
          <ul className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
            {summaries.map((summary) => (
              <li key={summary.id}>
                <ProjectCard summary={summary} />
              </li>
            ))}
          </ul>
        )}
      </div>
    </AppLayout>
  )
}

function ProjectCard({ summary }: { summary: ProjectSummary }) {
  return (
    <Link
      href={project(summary.id)}
      prefetch
      className="border-sidebar-border/70 bg-card hover:bg-accent dark:border-sidebar-border block rounded-xl border p-4 transition-colors"
    >
      <div className="flex items-start justify-between gap-2">
        <h2 className="truncate font-medium">{summary.name}</h2>
        {summary.regression && (
          <span className="flex shrink-0 items-center gap-1 rounded-md bg-(--viz-critical)/10 px-1.5 py-0.5 text-xs font-medium text-(--viz-critical)">
            <TriangleAlert className="size-3.5" aria-hidden />
            Regression
          </span>
        )}
      </div>

      <p className="text-muted-foreground mt-0.5 text-xs">
        {summary.latest_version
          ? `Latest version ${summary.latest_version}`
          : "No data yet"}
      </p>

      <dl className="mt-4 grid grid-cols-3 gap-2 text-sm">
        <Figure label="Sessions" value={formatNumber(summary.sessions)} />
        <Figure label="Crashes" value={formatNumber(summary.crashes)} />
        <Figure label="Crash rate" value={formatPercent(summary.crash_rate)} />
      </dl>
    </Link>
  )
}

function Figure({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <dt className="text-muted-foreground text-xs">{label}</dt>
      <dd className="text-lg font-semibold">{value}</dd>
    </div>
  )
}

function EmptyState() {
  return (
    <div className="border-sidebar-border/70 dark:border-sidebar-border flex flex-col items-center gap-3 rounded-xl border border-dashed px-6 py-16 text-center">
      <FolderPlus className="text-muted-foreground size-8" aria-hidden />
      <div>
        <h2 className="font-medium">No projects yet</h2>
        <p className="text-muted-foreground mx-auto mt-1 max-w-md text-sm">
          Create a project to get an API key, then send events from your app. To
          see the dashboard filled right away, run{" "}
          <code className="bg-muted rounded px-1 py-0.5">
            bin/rails apm:simulate
          </code>
          .
        </p>
      </div>
      <NewProject />
    </div>
  )
}

function NewProject() {
  return (
    <Dialog>
      <DialogTrigger asChild>
        <Button>
          <FolderPlus />
          New project
        </Button>
      </DialogTrigger>

      <DialogContent>
        <DialogHeader>
          <DialogTitle>New project</DialogTitle>
          <DialogDescription>
            You get a first API key right after creating it. The requirements
            are optional and show how many users run below them.
          </DialogDescription>
        </DialogHeader>

        <Form action={projects.create()} className="space-y-4">
          {({ processing, errors }) => (
            <>
              <Field>
                <FieldLabel htmlFor="name">Name</FieldLabel>
                <Input
                  id="name"
                  name="name"
                  required
                  autoFocus
                  placeholder="My desktop app"
                />
                <FieldError
                  errors={errors.name?.map((message) => ({ message }))}
                />
              </Field>

              <div className="grid grid-cols-2 gap-4">
                <Field>
                  <FieldLabel htmlFor="min_ram_mb">Minimum RAM (MB)</FieldLabel>
                  <Input
                    id="min_ram_mb"
                    name="min_ram_mb"
                    type="number"
                    min={0}
                    placeholder="8192"
                  />
                  <FieldError
                    errors={errors.min_ram_mb?.map((message) => ({ message }))}
                  />
                </Field>
                <Field>
                  <FieldLabel htmlFor="min_os">Minimum OS</FieldLabel>
                  <Input id="min_os" name="min_os" placeholder="Windows 10" />
                  <FieldError
                    errors={errors.min_os?.map((message) => ({ message }))}
                  />
                </Field>
              </div>

              <Button type="submit" disabled={processing} className="w-full">
                Create project
              </Button>
            </>
          )}
        </Form>
      </DialogContent>
    </Dialog>
  )
}
