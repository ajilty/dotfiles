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
//   size (the response's input tokens) with the model and effort the request
//   went out with, so the band can show them when that agent's transcript is
//   on screen (down arrow from the main conversation).
// ui.render (AbovePrompt): the main bar with a legend, or the viewed agent's
//   one-color bar, sized to the band.

import { atom, read, update } from 'claude-code'
import type { EngineInterface, ModelUsage, Register } from 'claude-code'

import type { AgentReading, Mode, Reading, Segment } from '../types'

const reading = atom({ plugin: 'context-bar', key: 'reading' } as const, null)
const mode = atom({ plugin: 'context-bar', key: 'mode' } as const, 'off')
const agents = atom({ plugin: 'context-bar', key: 'agents' } as const, {})

const STORE_KEY = 'mode'
const LABEL = 'Context '
const AGENT_LABEL = 'Subagent '
const PADDING = 2
// Where auto-compact fires, on the bar and in the headline alike.
const MARK = '◆'
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
      await noteAgent($, e.agentId, result.usage, result.usage.model || e.model, e.effort)
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
            <Text dimColor>{AGENT_LABEL}no response yet</Text>
          </Box>
        )
      }
      // The engine reports no window or compaction point per agent. The
      // session's are used: right while the agent runs on the session's model,
      // an overstatement for one on a model with a smaller window.
      const label = `${a.description} · ${modelLabel(a.model, a.effort)} · ${usedText(a.tokens, r.window)}`
      const width = Math.max(MIN_BAR, Math.min(MAX_BAR, columns - AGENT_LABEL.length - label.length - 3))
      const segments = agentSegments(a.tokens, r)
      const cells = allocate(segments, width)
      return (
        <Box flexDirection="row" paddingX={1}>
          <Text dimColor>{AGENT_LABEL}</Text>
          {segments.map((s, i) => drawSegment(Text, s, cells[i] ?? 0, r.compactAt !== null))}
          <Text color={levelColor(a.tokens / r.window)}> {label}</Text>
        </Box>
      )
    }

    const headline = headlineFor(r)
    const width = Math.max(MIN_BAR, Math.min(MAX_BAR, columns - LABEL.length - headline.text.length - 3))
    const cells = allocate(r.segments, width)
    // The legend joins the bar's row when the whole of it fits there; else it
    // takes a row of its own, with as many categories as fit.
    // Every row loses PADDING to the band's paddingX; the inline legend also
    // its two-space gap after the headline.
    const barRow = PADDING + LABEL.length + width + 1 + headline.text.length
    const inline = legendFor(r.segments, columns - barRow - 2)
    const legend = inline.length === usedCount(r.segments) ? inline : legendFor(r.segments, columns - PADDING - LABEL.length)
    const sameRow = legend === inline

    const legendRow = legend.map(s => (
      <Text>
        <Text color={s.color}>■</Text>
        <Text dimColor> {s.name} {short(s.tokens)}  </Text>
      </Text>
    ))

    return (
      <Box flexDirection="column" paddingX={1}>
        <Box flexDirection="row">
          <Text dimColor>{LABEL}</Text>
          {r.segments.map((s, i) => drawSegment(Text, s, cells[i] ?? 0, r.compactAt !== null))}
          <Text color={headline.color}> {headline.text}</Text>
          {sameRow && <Text>  </Text>}
          {sameRow && legendRow}
        </Box>
        {!sameRow && legend.length > 0 && (
          <Box flexDirection="row">
            <Text>{' '.repeat(LABEL.length)}</Text>
            {legendRow}
          </Box>
        )}
      </Box>
    )
  })
}

async function takeReading($: EngineInterface) {
  try {
    const { context } = await $.session.usage({ breakdown: 'summary' })
    const pct = await $.env.get('CLAUDE_AUTOCOMPACT_PCT_OVERRIDE')
    const b = context.breakdown
    let next: Reading | null = null

    if (b && b.rawMaxTokens > 0) {
      const segments: Segment[] = b.categories
        .filter(c => c.kind !== 'deferred' && c.tokens > 0)
        .map(c => ({ name: c.name, color: c.color, kind: c.kind as Segment['kind'], tokens: c.tokens }))
      const compactAt = b.isAutoCompactEnabled && b.autoCompactThreshold !== undefined
        ? withPctOverride(b.autoCompactThreshold, pct)
        : null
      next = {
        segments: compactAt === null ? segments : splitAtCompact(segments, b.totalTokens, b.rawMaxTokens, compactAt),
        used: b.totalTokens,
        window: b.rawMaxTokens,
        compactAt,
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
// cache-written and cache-read together, as the status line counts it. The
// model is the id the API answered with; the effort is the request's, the only
// place the engine reports it.
async function noteAgent(
  $: EngineInterface,
  agentId: string,
  usage: ModelUsage,
  model: string,
  effort: string | number | undefined,
) {
  try {
    const tokens = usage.input_tokens + usage.cache_read_input_tokens + usage.cache_creation_input_tokens
    const known = (await read($, agents))[agentId]
    let description = known?.description
    if (description === undefined) {
      const info = (await $.agent.list()).find(a => a.id === agentId)
      description = info ? `${info.type}: ${info.description}` : 'subagent'
    }
    const entry: AgentReading = { tokens, description, model, effort: effort === undefined ? undefined : String(effort) }
    await update($, agents, all => ({ ...all, [agentId]: entry }))
  } catch {
    // Keep the last reading for this agent.
  }
}

// The model as the status line spells it: `claude-sonnet-4-5-20250929` reads
// `Sonnet 4.5`, `claude-opus-5-5[1m]` `Opus 5.5 1M`, an alias `Haiku`.
export function modelLabel(model: string, effort?: string): string {
  const variant = /\[(\w+)\]$/.exec(model)?.[1]
  const parts = model.replace(/\[\w+\]$/, '').replace(/^claude-/, '').replace(/-\d{8}$/, '').split('-')
  const name = parts[0] ?? model
  const version = parts.slice(1).filter(p => /^\d+$/.test(p)).join('.')
  const words = [name.charAt(0).toUpperCase() + name.slice(1), version, variant?.toUpperCase()].filter(Boolean)
  const label = words.join(' ')
  return effort === undefined ? label : `${label} · ${effort}`
}

// The breakdown's threshold leaves out CLAUDE_AUTOCOMPACT_PCT_OVERRIDE, which
// real compaction applies (Claude Code 2.1.302). The engine computes both from
// the effective window: the threshold is that window less a 13k summary
// buffer, and the override lowers it to that percent of the window. Recompute
// it here so the headroom matches when compaction actually fires.
const SUMMARY_BUFFER = 13_000

export function withPctOverride(threshold: number, pct: string | undefined): number {
  const p = pct === undefined ? NaN : parseFloat(pct)
  if (isNaN(p) || p <= 0 || p > 100) return threshold
  return Math.min(Math.floor((threshold + SUMMARY_BUFFER) * (p / 100)), threshold)
}

// One run of the bar: used in its category's colour, free as dots, the buffer
// hatched, its first cell the mark where auto-compact fires.
function drawSegment(Text: any, s: Segment, n: number, marked: boolean) {
  if (n <= 0) return null
  if (s.kind === 'buffer' && marked) {
    return (
      <Text>
        <Text color="text" bold>{MARK}</Text>
        <Text color="subtle" dimColor>{'░'.repeat(n - 1)}</Text>
      </Text>
    )
  }
  return (
    <Text color={s.kind === 'free' ? 'subtle' : s.color} dimColor={s.kind !== 'used'}>
      {(s.kind === 'used' ? '█' : s.kind === 'buffer' ? '░' : '·').repeat(n)}
    </Text>
  )
}

function usedCount(segments: Segment[]): number {
  return segments.filter(s => s.kind === 'used').length
}

// A subagent's bar: one used run, then the session's free space and buffer.
export function agentSegments(tokens: number, r: Reading): Segment[] {
  const used: Segment = { name: 'Used', color: 'claude', kind: 'used', tokens }
  if (r.compactAt === null) {
    return [used, { name: 'Free space', color: 'subtle', kind: 'free', tokens: Math.max(0, r.window - tokens) }]
  }
  return splitAtCompact([used], tokens, r.window, r.compactAt)
}

// Re-cut the free space so it ends where auto-compact fires: the breakdown's
// own free/buffer split follows its threshold, not the override. The bar then
// reads used, free until compact, then the buffer past it.
export function splitAtCompact(segments: Segment[], used: number, window: number, compactAt: number): Segment[] {
  const kept = segments.filter(s => s.kind === 'used')
  const free = Math.max(0, compactAt - used)
  const buffer = Math.max(0, window - Math.max(used, compactAt))
  if (free > 0) kept.push({ name: 'Free space', color: 'subtle', kind: 'free', tokens: free })
  if (buffer > 0) kept.push({ name: 'Autocompact buffer', color: 'subtle', kind: 'buffer', tokens: buffer })
  return kept
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

// `16% used (163k/1M) · ◆ compacts at 49% · 327k left`: each percent is of
// the window, and names what it measures.
export function usedText(tokens: number, window: number): string {
  return `${pctOf(tokens, window)}% used (${short(tokens)}/${short(window)})`
}

export function headlineFor(r: Reading): { text: string; color: string } {
  const pct = pctOf(r.used, r.window)
  const base = usedText(r.used, r.window)
  if (r.compactAt === null) {
    return { text: base, color: pct >= 90 ? 'error' : pct >= 70 ? 'warning' : 'text' }
  }

  const room = r.compactAt - r.used
  const at = `${MARK} compacts at ${pctOf(r.compactAt, r.window)}%`
  if (room <= 0) return { text: `${base} · ${at} · compacting`, color: 'error' }
  const share = room / r.compactAt
  return {
    text: `${base} · ${at} · ${short(room)} left`,
    color: share < 0.1 ? 'error' : share < 0.25 ? 'warning' : 'text',
  }
}

// The biggest used categories that fit on one row, biggest first.
export function legendFor(segments: Segment[], room: number): Segment[] {
  const used = segments.filter(s => s.kind === 'used').sort((a, b) => b.tokens - a.tokens)
  const shown: Segment[] = []
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
