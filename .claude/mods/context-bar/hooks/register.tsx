// Context bar: the context window as one stacked bar above the prompt, one
// color per /context category, plus how much room is left before
// auto-compact (the number that actually matters with
// CLAUDE_AUTOCOMPACT_PCT_OVERRIDE set below 100).
//
// session.start: register /context-bar, restore the on/off choice, read once.
// session.measure: the engine pushes this after each main-thread turn; take a
//   `summary` breakdown, which is estimated locally and sends no API request.
// ui.render (AbovePrompt): draw the bar and a legend sized to the band.

import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { Reading, Segment } from '../types'

const reading = atom({ plugin: 'context-bar', key: 'reading' } as const, null)
const isOn = atom({ plugin: 'context-bar', key: 'isOn' } as const, true)

const STORE_KEY = 'isOn'
const MIN_BAR = 10
const MAX_BAR = 48

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    const result = await next(e)
    await $.command.register({
      name: 'context-bar',
      description: 'Toggle the stacked context-window bar above the prompt',
    })
    const stored = await $.store.get(STORE_KEY)
    await update($, isOn, () => stored !== false)
    await takeReading($)

    return result
  })

  on('session.measure', async ($, e, next) => {
    const result = await next(e)
    await takeReading($)

    return result
  })

  on('command.run', { command: 'context-bar' }, async $ => {
    const now = !(await read($, isOn))
    await update($, isOn, () => now)
    await $.store.set(STORE_KEY, now)

    return { text: now ? 'Context bar on.' : 'Context bar off.' }
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const r = await read($, reading)
    if (e.props.hasSurvey || r === null || !(await read($, isOn))) {
      return next(e)
    }

    const { Box, Text } = $.ui.resolve(e)
    const columns = e.props.bodyColumns
    const headline = headlineFor(r)
    const width = Math.max(MIN_BAR, Math.min(MAX_BAR, columns - headline.text.length - 3))
    const cells = allocate(r.segments, width)
    const legend = legendFor(r.segments, columns)

    return (
      <Box flexDirection="column" paddingX={1}>
        <Box flexDirection="row">
          {r.segments.map((s, i) => {
            const n = cells[i] ?? 0
            return n > 0 ? (
              <Text color={s.kind === 'free' ? 'subtle' : s.color} dimColor={s.kind !== 'used'}>
                {(s.kind === 'used' ? '█' : s.kind === 'buffer' ? '░' : '·').repeat(n)}
              </Text>
            ) : null
          })}
          <Text color={headline.color}> {headline.text}</Text>
        </Box>
        {legend.length > 0 && (
          <Box flexDirection="row">
            {legend.map(s => (
              <Text>
                <Text color={s.color}>■</Text>
                <Text dimColor> {s.name} {short(s.tokens)}  </Text>
              </Text>
            ))}
          </Box>
        )}
      </Box>
    )
  })
}

async function takeReading($: EngineInterface) {
  try {
    const { context } = await $.session.usage({ breakdown: 'summary' })
    const b = context.breakdown
    let next: Reading | null = null

    if (b && b.rawMaxTokens > 0) {
      const segments: Segment[] = b.categories
        .filter(c => c.kind !== 'deferred' && c.tokens > 0)
        .map(c => ({ name: c.name, color: c.color, kind: c.kind as Segment['kind'], tokens: c.tokens }))
      next = {
        segments,
        used: b.totalTokens,
        window: b.rawMaxTokens,
        compactAt: b.isAutoCompactEnabled ? (b.autoCompactThreshold ?? null) : null,
      }
    } else if (context.window > 0 && context.tokens) {
      next = {
        segments: [
          { name: 'Used', color: 'claude', kind: 'used', tokens: context.tokens },
          { name: 'Free', color: 'subtle', kind: 'free', tokens: Math.max(0, context.window - context.tokens) },
        ],
        used: context.tokens,
        window: context.window,
        compactAt: null,
      }
    }

    if (next) {
      const value = next
      await update($, reading, () => value)
    }
  } catch {
    // Keep the last reading; the next measure tries again.
  }
}

// Split `width` cells across segments by largest remainder, so the bar is
// always exactly `width` wide; every used segment gets at least one cell.
export function allocate(segments: Segment[], width: number): number[] {
  const total = segments.reduce((n, s) => n + s.tokens, 0)
  if (total <= 0) return segments.map(() => 0)

  const exact = segments.map(s => (s.tokens / total) * width)
  const cells = exact.map(Math.floor)
  let left = width - cells.reduce((n, c) => n + c, 0)
  const order = exact.map((x, i) => ({ i, rest: x - Math.floor(x) })).sort((a, b) => b.rest - a.rest)
  for (const { i } of order) {
    if (left <= 0) break
    cells[i] = (cells[i] ?? 0) + 1
    left -= 1
  }

  segments.forEach((s, i) => {
    if (s.kind !== 'used' || (cells[i] ?? 0) > 0) return
    const donor = cells.reduce((best, c, j) => (c > (cells[best] ?? 0) ? j : best), 0)
    if ((cells[donor] ?? 0) > 1) {
      cells[donor] = (cells[donor] ?? 0) - 1
      cells[i] = 1
    }
  })

  return cells
}

export function headlineFor(r: Reading): { text: string; color: string } {
  const pct = Math.round((r.used / r.window) * 100)
  const base = `${short(r.used)}/${short(r.window)} ${pct}%`
  if (r.compactAt === null) {
    return { text: base, color: pct >= 90 ? 'error' : pct >= 70 ? 'warning' : 'text' }
  }

  const room = r.compactAt - r.used
  if (room <= 0) return { text: `${base} · compacting`, color: 'error' }
  const share = room / r.compactAt
  return {
    text: `${base} · ${short(room)} to compact`,
    color: share < 0.1 ? 'error' : share < 0.25 ? 'warning' : 'text',
  }
}

// The biggest used categories that fit on one row, biggest first.
export function legendFor(segments: Segment[], columns: number): Segment[] {
  const used = segments.filter(s => s.kind === 'used').sort((a, b) => b.tokens - a.tokens)
  const shown: Segment[] = []
  let room = columns - 2
  for (const s of used) {
    const cost = s.name.length + short(s.tokens).length + 5
    if (cost > room) break
    shown.push(s)
    room -= cost
  }

  return shown
}

export function short(n: number): string {
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1).replace(/\.0$/, '')}M`
  if (n >= 1_000) return `${(n / 1_000).toFixed(n >= 100_000 ? 0 : 1).replace(/\.0$/, '')}k`
  return String(n)
}
