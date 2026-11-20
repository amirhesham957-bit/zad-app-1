export type Phase = { title: string; done: number; total: number; next?: string }
export type Plan = { status: string[]; phases: Phase[]; read: boolean; error?: string; mtimeMs: number }

declare module 'claude-code' {
  interface PluginState {
    'zad-or-plan': { plan: Shaped<Plan> }
  }
}
