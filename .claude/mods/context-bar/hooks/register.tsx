// Context bar: the context window as one stacked bar above the prompt, one
// color per /context category, plus how much room is left before
// auto-compact (the number that actually matters with
// CLAUDE_AUTOCOMPACT_PCT_OVERRIDE set below 100).
//
// Hidden by default. /context-bar shows the band until the next prompt is
// sent; /context-bar on pins it, /context-bar off hides it (both remembered).
//
// session.start: register /context-bar, restore the pinned choice, read once.
// session.measure: the engine pushes this after each main-thread turn; take a
//   `summary` breakdown, which is estimated locally and sends no API request.
// turn.step: after each subagent model response, keep that agent's context
//   size (the response's input tokens), so the band can show it when that
//   agent's transcript is on screen (down arrow from the main conversation).
// ui.render (AbovePrompt): the main bar with a legend, or the viewed agent's
//   one-color bar, sized to the band.

import { atom, read, update } from 'claude-code'
import type { EngineInterface, ModelUsage, Register } from 'claude-code'

import type { AgentReading, Mode, Reading, Segment } from '../types'

const reading = atom({ plugin: 'context-bar', key: 'reading' } as const, null)
const mode = atom({ plugin: 'context-bar', key: 'mode' } as const, 'off')
const agents = atom({ plugin: 'context-bar', key: 'agents' } as const, {})

const STORE_KEY = 'mode'
const MIN_BAR = 10
const MAX_BAR = 48

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    const result = await next(e)
    await $.command.register({
      name: 'context-bar',
      description: 'Show the context bar until your next prompt; `on` pins it, `off` hides it',
    })
    const stored = await $.store.get(STORE_KEY)
    await update($, mode, () => (stored === 'on' ? 'on' : 'off'))
    await takeReading($)

    return result
  })

  on('session.measure', async ($, e, next) => {
    const result = await next(e)
    await takeReading($)

    return result
  })

  on('turn.step', async function* ($, e, next) {
    const result = yield* next(e)
    if (e.agentId && result.usage) {
      await noteAgent($, e.agentId, result.usage)
    }

    return result
  })

  on('command.run', { command: 'context-bar' }, async ($, e) => {
    const arg = e.args.trim()
    let next: Mode
    if (arg === 'on' || arg === 'off') {
      next = arg
      await $.store.set(STORE_KEY, next)
    } else {
      next = (await read($, mode)) === 'off' ? 'peek' : 'off'
    }
    await update($, mode, () => next)

    return {
      text:
        next === 'on' ? 'Context bar pinned. /context-bar off hides it.'
        : next === 'peek' ? 'Context bar shown until your next prompt. /context-bar on pins it.'
        : 'Context bar hidden.',
    }
  })

  // A peek lasts until the next prompt goes out.
  on('prompt.submit', async ($, e, next) => {
    if ((await read($, mode)) === 'peek') {
      await update($, mode, () => 'off')
    }

    return next(e)
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const r = await read($, reading)
    if (e.props.hasSurvey || r === null || (await read($, mode)) === 'off') {
      return next(e)
    }

    const { Box, Text } = $.ui.resolve(e)
    const columns = e.props.bodyColumns

    const agentId = e.props.view?.agentId
    if (agentId) {
      const a = (await read($, agents))[agentId]
      if (!a) {
        return (
          <Box paddingX={1}>
            <Text dimColor>subagent · no response yet</Text>
          </Box>
        )
      }
      const label = `${a.description} · ${short(a.tokens)}/${short(r.window)} ${pctOf(a.tokens, r.window)}%`
      const width = Math.max(MIN_BAR, Math.min(MAX_BAR, columns - label.length - 3))
      const filled = Math.min(width, Math.round((a.tokens / r.window) * width))
      return (
        <Box flexDirection="row" paddingX={1}>
          <Text color="claude">{'█'.repeat(filled)}</Text>
          <Text color="subtle" dimColor>{'·'.repeat(width - filled)}</Text>
          <Text color={levelColor(a.tokens / r.window)}> {label}</Text>
        </Box>
      )
    }

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

// A subagent's context is the input side of its last response: uncached,
// cache-written and cache-read together, as the status line counts it.
async function noteAgent($: EngineInterface, agentId: string, usage: ModelUsage) {
  try {
    const tokens = usage.input_tokens + usage.cache_read_input_tokens + usage.cache_creation_input_tokens
    const known = (await read($, agents))[agentId]
    let description = known?.description
    if (description === undefined) {
      const info = (await $.agent.list()).find(a => a.id === agentId)
      description = info ? `${info.type}: ${info.description}` : 'subagent'
    }
    const entry: AgentReading = { tokens, description }
    await update($, agents, all => ({ ...all, [agentId]: entry }))
  } catch {
    // Keep the last reading for this agent.
  }
}

export function pctOf(part: number, whole: number): number {
  return whole > 0 ? Math.round((part / whole) * 100) : 0
}

export function levelColor(share: number): string {
  return share >= 0.9 ? 'error' : share >= 0.7 ? 'warning' : 'text'
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
