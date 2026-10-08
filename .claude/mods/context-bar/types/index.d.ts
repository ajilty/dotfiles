export type Segment = { name: string; color: string; kind: 'used' | 'free' | 'buffer'; tokens: number }

export type Reading = {
  segments: Segment[]
  used: number
  window: number
  compactAt: number | null
}

declare module 'claude-code' {
  interface PluginState {
    'context-bar': { reading: Reading | null; isOn: boolean }
  }
}
