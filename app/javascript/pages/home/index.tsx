import { Head, Link, usePage } from "@inertiajs/react"
import { Activity, Boxes, TriangleAlert } from "lucide-react"

import AppLogoIcon from "@/components/app-logo-icon"
import { Button } from "@/components/ui/button"
import { dashboard, sessions, users } from "@/routes"

const features = [
  {
    icon: Activity,
    title: "Usage, errors and crashes",
    text: "Your apps send events to a REST API, in batches, with a key for each project.",
  },
  {
    icon: Boxes,
    title: "Stability per version",
    text: "Sessions, users and crash rate of every release, and how fast each one spreads.",
  },
  {
    icon: TriangleAlert,
    title: "Crash regression alert",
    text: "The dashboard flags the version that crashes much more than the one before it.",
  },
]

export default function Welcome() {
  const { auth } = usePage().props

  return (
    <>
      <Head title="Welcome" />

      <div className="bg-background text-foreground flex min-h-screen flex-col">
        <header className="mx-auto flex w-full max-w-4xl items-center justify-between p-6">
          <span className="flex items-center gap-2 font-semibold">
            <AppLogoIcon className="size-5" />
            mini-apm
          </span>
          <nav className="flex items-center gap-2">
            {auth.user ? (
              <Button asChild variant="outline">
                <Link href={dashboard.index()}>Projects</Link>
              </Button>
            ) : (
              <>
                <Button asChild variant="ghost">
                  <Link href={sessions.new()}>Log in</Link>
                </Button>
                <Button asChild>
                  <Link href={users.new()}>Create account</Link>
                </Button>
              </>
            )}
          </nav>
        </header>

        <main className="mx-auto flex w-full max-w-4xl flex-1 flex-col justify-center gap-10 p-6 pb-20">
          <div className="max-w-2xl space-y-3">
            <h1 className="text-4xl font-semibold tracking-tight text-balance">
              Know which version started crashing.
            </h1>
            <p className="text-muted-foreground text-lg text-balance">
              A small, open source application performance monitor, built with
              Ruby on Rails and React. The same product as the Laravel version,
              with the same API.
            </p>
          </div>

          <ul className="grid gap-4 sm:grid-cols-3">
            {features.map(({ icon: Icon, title, text }) => (
              <li
                key={title}
                className="border-sidebar-border/70 bg-card dark:border-sidebar-border rounded-xl border p-4"
              >
                <Icon
                  className="text-muted-foreground mb-3 size-5"
                  aria-hidden
                />
                <h2 className="font-medium">{title}</h2>
                <p className="text-muted-foreground mt-1 text-sm">{text}</p>
              </li>
            ))}
          </ul>
        </main>
      </div>
    </>
  )
}
