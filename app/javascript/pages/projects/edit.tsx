import { Form, Head, usePage } from "@inertiajs/react"
import { Check, Copy, KeyRound, TriangleAlert } from "lucide-react"
import type { ReactNode } from "react"

import { ProjectHeader } from "@/components/projects/project-header"
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert"
import { Badge } from "@/components/ui/badge"
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
import { useClipboard } from "@/hooks/use-clipboard"
import AppLayout from "@/layouts/app-layout"
import { formatRelative } from "@/lib/format"
import {
  apiKeys,
  dashboard,
  editProject,
  project as projectRoute,
  projectApiKeys,
  projects,
} from "@/routes"
import type { RouteDefinition } from "@/routes/runtime"
import type { ApiKeyRow, NewKey, ProjectSettings } from "@/types"

interface Props {
  project: ProjectSettings
  keys: ApiKeyRow[]
}

export default function Edit({ project, keys }: Props) {
  const { flash } = usePage()

  return (
    <AppLayout
      breadcrumbs={[
        { title: "Projects", href: dashboard.index().url },
        { title: project.name, href: projectRoute(project.id).url },
        { title: "Settings", href: editProject(project.id).url },
      ]}
    >
      <Head title={`Settings · ${project.name}`} />

      <div className="flex flex-col gap-4 p-4">
        <ProjectHeader project={project} />

        <div className="flex max-w-3xl flex-col gap-6">
          {flash.new_key && <NewKeyNotice newKey={flash.new_key} />}

          <Section
            title="API keys"
            description="Your app sends events with one of these keys. Only a fingerprint of each key is stored, so the full text is shown once, when you create it."
          >
            <KeyList keys={keys} />
            <CreateKey projectId={project.id} />
          </Section>

          <Section title="Send your first events">
            <UsageExample />
          </Section>

          <Section
            title="Project"
            description="The minimum requirements show how many users run below them. The alert settings decide when a version counts as a crash regression."
          >
            <ProjectForm project={project} />
          </Section>

          <Section title="Delete project">
            <DeleteProject project={project} />
          </Section>
        </div>
      </div>
    </AppLayout>
  )
}

function Section({
  title,
  description,
  children,
}: {
  title: string
  description?: string
  children: ReactNode
}) {
  return (
    <section className="border-sidebar-border/70 bg-card dark:border-sidebar-border space-y-4 rounded-xl border p-5">
      <header>
        <h2 className="font-medium">{title}</h2>
        {description && (
          <p className="text-muted-foreground mt-0.5 text-sm">{description}</p>
        )}
      </header>
      {children}
    </section>
  )
}

function NewKeyNotice({ newKey }: { newKey: NewKey }) {
  const [copied, copy] = useClipboard()

  return (
    <Alert>
      <KeyRound />
      <AlertTitle>
        Copy your new API key{newKey.name ? ` “${newKey.name}”` : ""} now
      </AlertTitle>
      <AlertDescription>
        <p>
          For your safety it will not be shown again. If you lose it, create
          another and revoke this one.
        </p>
        <div className="mt-2 flex items-center gap-2">
          <code className="bg-muted text-foreground min-w-0 flex-1 truncate rounded-md px-2 py-1.5 font-mono text-xs select-all">
            {newKey.key}
          </code>
          <Button
            type="button"
            size="sm"
            variant="outline"
            onClick={() => void copy(newKey.key)}
          >
            {copied === newKey.key ? <Check /> : <Copy />}
            {copied === newKey.key ? "Copied" : "Copy"}
          </Button>
        </div>
      </AlertDescription>
    </Alert>
  )
}

function KeyList({ keys }: { keys: ApiKeyRow[] }) {
  if (keys.length === 0) {
    return (
      <p className="text-muted-foreground text-sm">
        This project has no keys. Create one below.
      </p>
    )
  }

  return (
    <ul className="divide-border/60 border-border divide-y rounded-lg border">
      {keys.map((key) => (
        <li
          key={key.id}
          className="flex flex-wrap items-center justify-between gap-3 px-3 py-2.5 text-sm"
        >
          <div className="min-w-0">
            <p className="flex items-center gap-2">
              <span className="truncate font-medium">
                {key.name ?? "Unnamed key"}
              </span>
              {key.revoked_at && <Badge variant="outline">Revoked</Badge>}
            </p>
            <p className="text-muted-foreground text-xs">
              <code>{key.prefix}…</code> ·{" "}
              {key.last_used_at
                ? `last used ${formatRelative(key.last_used_at)}`
                : "never used"}
            </p>
          </div>

          {!key.revoked_at && (
            <Confirm
              trigger={
                <Button variant="outline" size="sm">
                  Revoke
                </Button>
              }
              title="Revoke this key?"
              description="Apps using it stop being able to send events right away. This cannot be undone."
              action={apiKeys.destroy(key.id)}
              label="Revoke key"
            />
          )}
        </li>
      ))}
    </ul>
  )
}

function CreateKey({ projectId }: { projectId: number }) {
  return (
    <Form
      action={projectApiKeys(projectId)}
      resetOnSuccess
      className="flex items-start gap-2"
    >
      {({ processing, errors }) => (
        <>
          <Field className="flex-1">
            <FieldLabel htmlFor="key-name" className="sr-only">
              Key name
            </FieldLabel>
            <Input
              id="key-name"
              name="name"
              placeholder="Name, for example “production”"
            />
            <FieldError errors={errors.name?.map((message) => ({ message }))} />
          </Field>
          <Button type="submit" disabled={processing}>
            Create key
          </Button>
        </>
      )}
    </Form>
  )
}

function UsageExample() {
  const origin =
    typeof window === "undefined"
      ? "https://your-server"
      : window.location.origin

  return (
    <div className="space-y-2 text-sm">
      <p className="text-muted-foreground">
        Send a batch of up to 100 events with the key in the{" "}
        <code>Authorization</code> header. The API answers 202 when it accepts
        them.
      </p>
      <pre className="bg-muted overflow-x-auto rounded-lg p-3 text-xs leading-relaxed">
        {`curl -X POST ${origin}/api/v1/events \\
  -H "Authorization: Bearer apm_your_key" \\
  -H "Content-Type: application/json" \\
  -d '{"events":[{"type":"session_start","occurred_at":"${new Date().toISOString()}","app_version":"1.0.0","user_ref":"u_1","env":{"os":"Windows 11","ram_mb":16384}}]}'`}
      </pre>
      <p className="text-muted-foreground">
        The browser and Ruby clients in the <code>mini-apm-laravel</code>{" "}
        repository (<code>clients/</code>) do this for you, and work with this
        server unchanged.
      </p>
    </div>
  )
}

function ProjectForm({ project }: { project: ProjectSettings }) {
  return (
    <Form
      action={projects.update(project.id)}
      options={{ preserveScroll: true }}
      className="space-y-5"
    >
      {({ processing, errors }) => (
        <>
          <Field>
            <FieldLabel htmlFor="name">Name</FieldLabel>
            <Input id="name" name="name" defaultValue={project.name} required />
            <FieldError errors={errors.name?.map((message) => ({ message }))} />
          </Field>

          <div className="grid gap-4 sm:grid-cols-2">
            <Field>
              <FieldLabel htmlFor="min_ram_mb">Minimum RAM (MB)</FieldLabel>
              <Input
                id="min_ram_mb"
                name="min_ram_mb"
                type="number"
                min={0}
                defaultValue={project.min_ram_mb ?? ""}
              />
              <FieldError
                errors={errors.min_ram_mb?.map((message) => ({ message }))}
              />
            </Field>
            <Field>
              <FieldLabel htmlFor="min_os">Minimum OS</FieldLabel>
              <Input
                id="min_os"
                name="min_os"
                defaultValue={project.min_os ?? ""}
                placeholder="Windows 10"
              />
              <FieldError
                errors={errors.min_os?.map((message) => ({ message }))}
              />
            </Field>
          </div>

          <div className="grid gap-4 sm:grid-cols-2">
            <Field>
              <FieldLabel htmlFor="regression_ratio">
                Alert when a version crashes … times more
              </FieldLabel>
              <Input
                id="regression_ratio"
                name="regression_ratio"
                type="number"
                min={1}
                step={0.1}
                defaultValue={project.regression_ratio}
              />
              <FieldError
                errors={errors.regression_ratio?.map((message) => ({
                  message,
                }))}
              />
            </Field>
            <Field>
              <FieldLabel htmlFor="regression_min_sessions">
                Minimum sessions per version
              </FieldLabel>
              <Input
                id="regression_min_sessions"
                name="regression_min_sessions"
                type="number"
                min={1}
                defaultValue={project.regression_min_sessions}
              />
              <FieldError
                errors={errors.regression_min_sessions?.map((message) => ({
                  message,
                }))}
              />
            </Field>
          </div>

          <Button type="submit" disabled={processing}>
            Save
          </Button>
        </>
      )}
    </Form>
  )
}

function DeleteProject({ project }: { project: ProjectSettings }) {
  return (
    <div className="flex flex-wrap items-center justify-between gap-3">
      <p className="text-muted-foreground text-sm">
        Deletes the project, its keys and all of its sessions, events and
        errors.
      </p>
      <Confirm
        trigger={<Button variant="destructive">Delete project</Button>}
        title={`Delete “${project.name}”?`}
        description="All of its data is removed for good. This cannot be undone."
        action={projects.destroy(project.id)}
        label="Delete project"
        destructive
      />
    </div>
  )
}

/** A button that opens a dialog and only sends the request once the user confirms. */
function Confirm({
  trigger,
  title,
  description,
  action,
  label,
  destructive = false,
}: {
  trigger: ReactNode
  title: string
  description: string
  action: RouteDefinition<"post" | "patch" | "delete">
  label: string
  destructive?: boolean
}) {
  return (
    <Dialog>
      <DialogTrigger asChild>{trigger}</DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <TriangleAlert
              className="size-5 text-(--viz-critical)"
              aria-hidden
            />
            {title}
          </DialogTitle>
          <DialogDescription>{description}</DialogDescription>
        </DialogHeader>

        <Form action={action} className="flex justify-end">
          {({ processing }) => (
            <Button
              type="submit"
              variant={destructive ? "destructive" : "default"}
              disabled={processing}
            >
              {label}
            </Button>
          )}
        </Form>
      </DialogContent>
    </Dialog>
  )
}
