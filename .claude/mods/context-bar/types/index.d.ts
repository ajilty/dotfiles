export type Segment = { name: string; color: string; kind: 'used' | 'free' | 'buffer'; tokens: number }

export type Reading = {
  segments: Segment[]
  used: number
  window: number
  compactAt: number | null
}

export type AgentReading = { tokens: number; description: string }

// off: hidden; peek: shown until the next prompt is sent; on: pinned.
export type Mode = 'off' | 'peek' | 'on'

declare module 'claude-code' {
  interface PluginState {
    'context-bar': { reading: Reading | null; mode: Mode; agents: Record<string, AgentReading> }
  }
}
