import { describe, expect, mock, test } from 'claude-code/testing'

import { allocate, headlineFor, short } from '../hooks/register'
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
    expect(h.text).toBe('43.2k/200k 22% · 56.8k to compact')
    expect(h.color).toBe('text')
  })

  test('warns as compaction nears', () => {
    expect(headlineFor({ segments: [], used: 92_000, window: 200_000, compactAt: 100_000 }).color).toBe('error')
    expect(headlineFor({ segments: [], used: 101_000, window: 200_000, compactAt: 100_000 }).text).toContain('compacting')
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
    mock.store(on)
    await $.session.measure({ context: { window: 200_000 }, rateLimits: [] } as never)

    const ui = await $.ui.mount({
      plugin: 'context-bar',
      surface,
      component: 'AbovePrompt',
      props: { hasSurvey: false, isWorking: false, maxRows: 10, bodyColumns: 100 } as never,
    })
    expect(await ui.find({ type: 'Text', text: '56.8k to compact' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: 'Messages 40k' })).toBeDefined()

    const off = await $.command.run({ command: 'context-bar', args: '' } as never)
    expect(off).toMatchObject({ text: 'Context bar off.' })
    expect(await ui.find({ type: 'Text', text: 'to compact' })).toBeUndefined()
    expect(await ui.find({ type: 'Text', text: 'engine band' })).toBeDefined()
  })
}
