import type { LucideIcon } from "lucide-react"

import type { NewKey } from "./projects"

export * from "./projects"

export interface Auth {
  user: User
  session: Pick<Session, "id">
}

export interface BreadcrumbItem {
  title: string
  href: string
}

export interface NavItem {
  title: string
  href: string
  icon?: LucideIcon | null
  isActive?: boolean
  /** Other paths that also mark this item as active. */
  activePrefixes?: string[]
}

export interface FlashData {
  alert?: string
  notice?: string
  new_key?: NewKey
}

export interface SharedProps {
  auth: Auth
}

export interface User {
  id: number
  name: string
  email: string
  avatar?: string
  verified: boolean
  created_at: string
  updated_at: string
  [key: string]: unknown // This allows for additional properties...
}

export interface Session {
  id: number
  user_agent: string
  ip_address: string
  created_at: string
}
