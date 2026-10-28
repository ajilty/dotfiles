import { describe, expect, mock, test } from 'claude-code/testing'

import { agentSegments, allocate, headlineFor, legendFor, modelLabel, short, splitAtCompact, withPctOverride } from '../hooks/register'
import type { Segment } from '../types'

const SEGMENTS: Segment[] = [
  { name: 'System prompt', color: 'promptBorder', kind: 'used', tokens: 3_000 },
  { name: 'Messages', color: 'permission', kind: 'used', tokens: 40_000 },
  { name: 'Memory files', color: 'claude', kind: 'used', tokens: 200 },
  { name: 'Free space', color: 'inactive', kind: 'free', tokens: 56_800 },
  { name: 'Autocompact buffer', color: 'inactive', kind: 'buffer', tokens: 100_000 },
]

describe('allocate', () => {
  test('fills the bar exactly and keeps tiny used categories visible', () => {
    const cells = allocate(SEGMENTS, 40)
    expect(cells.reduce((n, c) => n + c, 0)).toBe(40)
    expect(cells[2]).toBe(1)
  })
})

describe('headline', () => {
  test('reports headroom to auto-compact, not just percent of window', () => {
    const h = headlineFor({ segments: SEGMENTS, used: 43_200, window: 200_000, compactAt: 100_000 })
    expect(h.text).toBe('22% used (43.2k/200k) · ◆ compacts at 50% · 56.8k left')
    expect(h.color).toBe('text')
  })

  test('warns as compaction nears', () => {
    expect(headlineFor({ segments: [], used: 92_000, window: 200_000, compactAt: 100_000 }).color).toBe('error')
    expect(headlineFor({ segments: [], used: 101_000, window: 200_000, compactAt: 100_000 }).text).toContain('compacting')
  })

  test('applies the auto-compact percent override the breakdown leaves out', () => {
    // A 1M window: effective 980k, so the engine reports 967k; 60% fires at 588k.
    expect(withPctOverride(967_000, '60')).toBe(588_000)
    expect(withPctOverride(967_000, undefined)).toBe(967_000)
    expect(withPctOverride(967_000, '100')).toBe(967_000)
    expect(withPctOverride(967_000, 'junk')).toBe(967_000)
  })

  test('cuts the free space at the compaction point so the bar marks it', () => {
    const cut = splitAtCompact(SEGMENTS, 43_200, 200_000, 67_800)
    expect(cut.map(s => `${s.kind}:${s.tokens}`)).toEqual([
      'used:3000', 'used:40000', 'used:200', 'free:24600', 'buffer:132200',
    ])
    // Past the threshold: no free space, the buffer is what is left of the window.
    expect(splitAtCompact(SEGMENTS, 70_000, 200_000, 67_800).map(s => s.kind)).toEqual(['used', 'used', 'used', 'buffer'])
  })

  test("gives a subagent's bar the session's free space and buffer", () => {
    const r = { segments: [], used: 0, window: 200_000, compactAt: 100_000 }
    expect(agentSegments(30_000, r).map(s => `${s.kind}:${s.tokens}`)).toEqual(['used:30000', 'free:70000', 'buffer:100000'])
    expect(agentSegments(30_000, { ...r, compactAt: null }).map(s => s.kind)).toEqual(['used', 'free'])
  })

  test('fits the legend in the room it is given', () => {
    const width = (shown: Segment[]) => shown.reduce((n, s) => n + s.name.length + short(s.tokens).length + 5, 0)
    for (const room of [20, 33, 40, 60]) expect(width(legendFor(SEGMENTS, room))).toBeLessThanOrEqual(room)
  })

  test('labels a subagent model without the vendor prefix or date', () => {
    expect(modelLabel('claude-sonnet-4-5-20250929', 'high')).toBe('Sonnet 4.5 · high')
    expect(modelLabel('claude-opus-5-5[1m]')).toBe('Opus 5.5 1M')
    expect(modelLabel('claude-fable-5-1', 'medium')).toBe('Fable 5.1 · medium')
    expect(modelLabel('haiku')).toBe('Haiku')
  })

  test('formats token counts compactly', () => {
    expect(short(1_000_000)).toBe('1M')
    expect(short(134_400)).toBe('134k')
    expect(short(950)).toBe('950')
  })
})

for (const surface of ['terminal', 'desktop'] as const) {
  test(`draws the band from a breakdown on ${surface}`, async ($, on) => {
    on('session.usage', () => ({ value: {
      context: {
        tokens: 43_200,
        window: 200_000,
        percent: 22,
        breakdown: {
          categories: SEGMENTS.map(s => ({ ...s, isDeferred: false })),
          totalTokens: 43_200,
          maxTokens: 200_000,
          rawMaxTokens: 200_000,
          autocompactSource: 'env',
          percentage: 22,
          gridRows: [],
          model: 'test',
          memoryFiles: [],
          mcpTools: [],
          agents: [],
          autoCompactThreshold: 100_000,
          isAutoCompactEnabled: true,
          apiUsage: null,
        },
      },
    } }) as never)

    on('session.measure', () => ({ changed: [] }) as never)
    // The engine's own band, drawn when the mod hands the render on.
    on('ui.render', ($, e) => $.ui.resolve(e).Text({ children: 'engine band' }) as never)
    on('command.run', () => ({ text: '' }) as never)
    on('prompt.submit', ($, e) => ({ text: e.text }) as never)
    mock.store(on)
    // The breakdown says 100k; a 60% override fires at 60% of 113k instead.
    mock.env(on, { CLAUDE_AUTOCOMPACT_PCT_OVERRIDE: '60' })
    await $.session.measure({ context: { window: 200_000 }, rateLimits: [] } as never)

    // Hidden by default: the engine's own band shows.
    const hidden = await $.ui.mount({
      plugin: 'context-bar',
      surface,
      component: 'AbovePrompt',
      props: { hasSurvey: false, isWorking: false, maxRows: 10, bodyColumns: 100 } as never,
    })
    expect(await hidden.find({ type: 'Text', text: 'engine band' })).toBeDefined()
    await hidden.unmount()

    const pinned = await $.command.run({ command: 'context-bar', args: 'on' } as never)
    expect(pinned).toMatchObject({ text: 'Context bar pinned. /context-bar off hides it.' })

    const ui = await $.ui.mount({
      plugin: 'context-bar',
      surface,
      component: 'AbovePrompt',
      props: { hasSurvey: false, isWorking: false, maxRows: 10, bodyColumns: 100 } as never,
    })
    expect(await ui.find({ type: 'Text', text: '22% used (43.2k/200k) · ◆ compacts at 34% · 24.6k left' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: '◆' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: 'Messages 40k' })).toBeDefined()

    const off = await $.command.run({ command: 'context-bar', args: '' } as never)
    expect(off).toMatchObject({ text: 'Context bar hidden.' })
    expect(await ui.find({ type: 'Text', text: 'left' })).toBeUndefined()
    expect(await ui.find({ type: 'Text', text: 'engine band' })).toBeDefined()

    // A bare /context-bar peeks: shown now, gone once a prompt goes out.
    const peek = await $.command.run({ command: 'context-bar', args: '' } as never)
    expect(peek).toMatchObject({ text: 'Context bar shown until your next prompt. /context-bar on pins it.' })
    expect(await ui.find({ type: 'Text', text: 'left' })).toBeDefined()
    await $.prompt.submit({ text: 'next thing', origin: { kind: 'composer' } } as never)
    expect(await ui.find({ type: 'Text', text: 'left' })).toBeUndefined()
    expect(await ui.find({ type: 'Text', text: 'engine band' })).toBeDefined()
  })

  test(`shows the viewed subagent's context on ${surface}`, async ($, on) => {
    on('session.usage', () => ({ value: { context: { tokens: 10_000, window: 200_000, percent: 5 } } }) as never)
    on('session.measure', () => ({ changed: [] }) as never)
    on('agent.list', () => ({ value: [{ id: 'a1', description: 'Survey the repo', type: 'Explore', status: 'running' }] }) as never)
    on('command.run', () => ({ text: '' }) as never)
    on('turn.step', async function* ($, e) {
      yield { kind: 'text', index: 0, text: 'ok' } as never
      return {
        turnId: e.turnId, index: e.index, answer: 'ok', toolUses: [], stopReason: 'end_turn',
        usage: { input_tokens: 1_000, output_tokens: 50, cache_read_input_tokens: 150_000, cache_creation_input_tokens: 9_000, model: 'claude-sonnet-4-5-20250929' },
      } as never
    })
    mock.store(on)
    mock.env(on, {})
    await $.session.measure({ context: { window: 200_000 }, rateLimits: [] } as never)
    await $.command.run({ command: 'context-bar', args: 'on' } as never)

    const stream = $.turn.step({ turnId: 't', index: 0, model: 'sonnet', effort: 'high', messageCount: 1, agentId: 'a1' } as never)
    let step = await stream.next()
    while (step.done !== true) step = await stream.next()

    const props = { hasSurvey: false, isWorking: false, maxRows: 10, bodyColumns: 100 }
    const agentView = await $.ui.mount({ plugin: 'context-bar', surface, component: 'AbovePrompt', props: { ...props, view: { agentId: 'a1' } } as never })
    expect(await agentView.find({ type: 'Text', text: 'Explore: Survey the repo · Sonnet 4.5 · high · 80% used (160k/200k)' })).toBeDefined()
    expect(await agentView.find({ type: 'Text', text: 'Subagent ' })).toBeDefined()
    await agentView.unmount()

    const unknown = await $.ui.mount({ plugin: 'context-bar', surface, component: 'AbovePrompt', props: { ...props, view: { agentId: 'nobody' } } as never })
    expect(await unknown.find({ type: 'Text', text: 'no response yet' })).toBeDefined()
    await unknown.unmount()

    const main = await $.ui.mount({ plugin: 'context-bar', surface, component: 'AbovePrompt', props: { ...props, view: {} } as never })
    expect(await main.find({ type: 'Text', text: '5% used (10k/200k)' })).toBeDefined()
  })
}
