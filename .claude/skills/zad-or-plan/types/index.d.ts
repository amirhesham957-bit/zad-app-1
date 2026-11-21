export type Phase = { title: string; done: number; total: number; next?: string }
export type Usage = { ctxPct: number; ctxTokens: number; window: number; limits: { kind: string; percentUsed: number; resetsAt?: string }[]; at: number }
export type Plan = { status: string[]; phases: Phase[]; read: boolean; error?: string; mtimeMs: number; source?: 'file' | 'git' }

declare module 'claude-code' {
  interface PluginState {
    'zad-or-plan': { plan: Shaped<Plan>; usage: Shaped<Usage | null> }
  }
}
