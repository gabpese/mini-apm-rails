export interface ProjectRef {
  id: number
  name: string
}

export interface ProjectSummary extends ProjectRef {
  sessions: number
  crashes: number
  crash_rate: number
  latest_version: string | null
  regression: boolean
}

export interface Totals {
  sessions: number
  users: number
  errors: number
  crashes: number
  crash_rate: number
}

export interface DailyRow {
  date: string
  sessions: number
  errors: number
  crashes: number
}

export interface FeatureRow {
  name: string
  uses: number
}

export interface DistributionRow {
  label: string
  users: number
}

export interface Environment {
  users: number
  below_minimum: number
  below_ram: number
  below_os: number
  os: DistributionRow[]
  ram: DistributionRow[]
  gpu: DistributionRow[]
}

/** The newest version's regression against the one before it. */
export interface Regression {
  version: string
  crash_rate: number
  previous_version: string
  previous_rate: number
  ratio: number | null
}

export interface VersionRow {
  version: string
  sessions: number
  users: number
  crashes: number
  crash_rate: number
  regression: {
    previous_version: string
    previous_rate: number
    ratio: number | null
  } | null
}

export interface Adoption {
  versions: string[]
  rows: Record<string, number | string>[]
}

export interface ErrorGroupRow {
  id: number
  message: string
  occurrences: number
  crashes: number
  first_seen_at: string
  last_seen_at: string
}

export interface ApiKeyRow {
  id: number
  name: string | null
  prefix: string
  last_used_at: string | null
  revoked_at: string | null
  created_at: string
}

export interface ProjectSettings extends ProjectRef {
  min_ram_mb: number | null
  min_os: string | null
  regression_ratio: number
  regression_min_sessions: number
}

/** A key that was just created: the only time its full text exists. */
export interface NewKey {
  name: string | null
  key: string
}

/** Props shared by the project report pages. */
export interface ReportProps {
  project: ProjectRef
  days: number
  periods: number[]
}
