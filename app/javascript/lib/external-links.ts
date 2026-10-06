import { Code, Layers } from "lucide-react"

import type { NavItem } from "@/types"

/** Links to the source code, shown at the bottom of the navigation. */
export const externalNavItems: NavItem[] = [
  {
    title: "Source code",
    href: "https://github.com/gabpese/mini-apm-rails",
    icon: Code,
  },
  {
    title: "Laravel version",
    href: "https://github.com/gabpese/mini-apm-laravel",
    icon: Layers,
  },
]
