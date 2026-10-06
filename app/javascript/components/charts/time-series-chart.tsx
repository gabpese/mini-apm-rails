import {
  CartesianGrid,
  Line,
  LineChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts"

import { formatCompact, formatDay, formatNumber } from "@/lib/format"

export interface Series {
  key: string
  label: string
  /** A CSS color, normally one of the --viz-* tokens: 'var(--viz-1)' */
  color: string
}

interface TooltipProps {
  active?: boolean
  label?: unknown
  payload?: readonly { dataKey?: unknown; value?: unknown }[]
}

/**
 * Lines over days. Marks follow the house style: 2px lines, an 8px end dot with
 * a surface ring, a hairline grid, and a crosshair tooltip. A legend is shown
 * whenever there is more than one series.
 */
export function TimeSeriesChart({
  data,
  series,
  ariaLabel,
  height = 260,
}: {
  /** One object per day, with a `date` and one number for each series key. */
  data: object[]
  series: Series[]
  ariaLabel: string
  height?: number
}) {
  return (
    <div>
      {series.length > 1 && (
        <ul className="text-muted-foreground mb-2 flex flex-wrap gap-x-4 gap-y-1 text-xs">
          {series.map((item) => (
            <li key={item.key} className="flex items-center gap-1.5">
              <span
                aria-hidden
                className="h-0.5 w-4 rounded-full"
                style={{ background: item.color }}
              />
              {item.label}
            </li>
          ))}
        </ul>
      )}

      <div role="img" aria-label={ariaLabel} style={{ height }}>
        <ResponsiveContainer width="100%" height="100%">
          <LineChart
            data={data}
            margin={{ top: 8, right: 12, bottom: 0, left: 0 }}
          >
            <CartesianGrid
              vertical={false}
              stroke="var(--border)"
              strokeWidth={1}
            />
            <XAxis
              dataKey="date"
              tickFormatter={formatDay}
              tickLine={false}
              axisLine={false}
              minTickGap={32}
              tick={{
                fill: "var(--muted-foreground)",
                fontSize: 12,
              }}
            />
            <YAxis
              width="auto"
              allowDecimals={false}
              tickFormatter={formatCompact}
              tickLine={false}
              axisLine={false}
              tick={{
                fill: "var(--muted-foreground)",
                fontSize: 12,
              }}
            />
            <Tooltip
              cursor={{ stroke: "var(--border)", strokeWidth: 1 }}
              content={<ChartTooltip series={series} />}
            />
            {series.map((item) => (
              <Line
                key={item.key}
                type="monotone"
                dataKey={item.key}
                name={item.label}
                stroke={item.color}
                strokeWidth={2}
                strokeLinecap="round"
                strokeLinejoin="round"
                dot={(props: { cx?: number; cy?: number; index?: number }) =>
                  props.index === data.length - 1 && props.cx !== undefined ? (
                    <circle
                      key={`end-${item.key}`}
                      cx={props.cx}
                      cy={props.cy}
                      r={4}
                      fill={item.color}
                      stroke="var(--card)"
                      strokeWidth={2}
                    />
                  ) : (
                    <g key={`none-${item.key}-${props.index}`} />
                  )
                }
                activeDot={{
                  r: 4,
                  fill: item.color,
                  stroke: "var(--card)",
                  strokeWidth: 2,
                }}
                isAnimationActive={false}
              />
            ))}
          </LineChart>
        </ResponsiveContainer>
      </div>
    </div>
  )
}

function ChartTooltip({
  active,
  label,
  payload,
  series,
}: TooltipProps & { series: Series[] }) {
  if (!active || !payload || payload.length === 0) {
    return null
  }

  return (
    <div className="border-border bg-popover rounded-lg border px-3 py-2 text-xs shadow-md">
      <p className="text-popover-foreground mb-1 font-medium">
        {formatDay(String(label))}
      </p>
      {series.map((item) => {
        const entry = payload.find((p) => p.dataKey === item.key)

        return (
          <p
            key={item.key}
            className="text-muted-foreground flex items-center gap-2"
          >
            <span
              aria-hidden
              className="size-2 rounded-full"
              style={{ background: item.color }}
            />
            <span>{item.label}</span>
            <span className="text-popover-foreground ml-auto pl-4 tabular-nums">
              {formatNumber(Number(entry?.value ?? 0))}
            </span>
          </p>
        )
      })}
    </div>
  )
}
