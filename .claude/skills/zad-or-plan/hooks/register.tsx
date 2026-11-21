import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { Phase, Plan, Usage } from '../types'

const PANE = 'zad-or-plan'
const TITLE = 'خطة زاد الحسابية'
const REL = 'docs/agent/ZAD_OR_PLAN.md'
const FALLBACK_ROOT = '/workspaces/zad-app-1'
const BRANCHES = ['main', 'origin/main', 'docs/zad-or-plan', 'origin/docs/zad-or-plan']

const EMPTY: Plan = { status: [], phases: [], read: false, mtimeMs: 0 }
const plan = atom({ plugin: 'zad-or-plan', key: 'plan' } as const, EMPTY, {
  shape: 'plan-2',
})

const usage = atom({ plugin: 'zad-or-plan', key: 'usage' } as const, null as Usage | null, { shape: 'usage-1' })

const LIMIT_NAMES: Record<string, string> = { five_hour: 'الـ٥ ساعات', seven_day: 'الأسبوع', spend_limit: 'حد الصرف' }

/** الباقي من الكريدتس والسياق، بالنسبة. */
export function usageLine(u: Usage | null): string {
  if (!u) return ''
  const parts = [`السياق باقي ${Math.max(0, 100 - u.ctxPct)}%`]
  for (const l of u.limits) parts.push(`${LIMIT_NAMES[l.kind] ?? l.kind} باقي ${Math.max(0, 100 - l.percentUsed)}%`)
  return parts.join(' · ')
}

function untilText(iso: string | undefined, now: number): string {
  if (!iso) return ''
  const ms = Date.parse(iso) - now
  if (!(ms > 0)) return 'بيتجدد دلوقتي'
  const h = Math.floor(ms / 3_600_000)
  const m = Math.floor((ms % 3_600_000) / 60_000)
  return h >= 24 ? `بيتجدد بعد ${Math.floor(h / 24)} يوم و${h % 24} ساعة` : `بيتجدد بعد ${h} ساعة و${m} دقيقة`
}

async function refreshUsage($: EngineInterface): Promise<void> {
  try {
    const u = await $.session.usage()
    const next: Usage = {
      ctxPct: Math.round(u.context.percent ?? 0),
      ctxTokens: u.context.tokens ?? 0,
      window: u.context.window ?? 0,
      limits: u.rateLimits.map(r => ({ kind: r.kind, percentUsed: Math.round(r.percentUsed), resetsAt: r.resetsAt })),
      at: await $.clock.now(),
    }
    await update($, usage, () => next)
  } catch {
    // من غير قراية: اللوحة بتعرض الخطة بس.
  }
}

async function pushStatus($: EngineInterface): Promise<void> {
  const p = await read($, plan)
  const u = await read($, usage)
  const left = p.read ? summary(p) : 'خطة زاد: الملف مش لاقيه'
  const right = usageLine(u)
  $.ui.status((right ? `${right} · ${left}` : left).slice(0, 160))
}

/** Reads the plan's markdown: "### " headings are phases, "- [x]"/"- [ ]" lines their items,
 * and the bullets under "## الحالة دلوقتي" the status lines. */
export function parsePlan(text: string, mtimeMs: number): Plan {
  const phases: Phase[] = []
  const status: string[] = []
  let section = ''
  let phase: Phase | undefined
  for (const raw of text.split('\n')) {
    const line = raw.trimEnd()
    if (line.startsWith('## ')) {
      section = line.slice(3).trim()
      phase = undefined
      continue
    }
    if (line.startsWith('### ')) {
      phase = { title: line.slice(4).trim(), done: 0, total: 0 }
      phases.push(phase)
      continue
    }
    if (section.startsWith('الحالة دلوقتي') && line.startsWith('- ')) {
      status.push(line.slice(2).replace(/\*\*/g, '').replace(/`/g, ''))
      continue
    }
    const box = /^\s*- \[( |x|X)\]\s+(.*)$/.exec(line)
    if (box && phase) {
      phase.total += 1
      if (box[1] !== ' ') phase.done += 1
      else if (!phase.next) phase.next = (box[2] ?? '').replace(/`/g, '').slice(0, 140)
    }
  }
  return { status, phases: phases.filter(p => p.total > 0), read: true, mtimeMs }
}

let root: string | undefined

/** الملف من شجرة الشغل، ولو مش موجود (فرع تاني) من فرع الخطة في git. */
async function loadPlan($: EngineInterface): Promise<{ text: string; mtimeMs: number }> {
  if (!root) {
    const cwd = await $.session.cwd()
    root = (await $.fs.exists(`${cwd}/${REL}`)) || (await $.fs.exists(`${cwd}/.git`)) ? cwd : FALLBACK_ROOT
  }
  const file = `${root}/${REL}`
  if (await $.fs.exists(file)) {
    const { mtimeMs } = await $.fs.stat(file)
    const current = await read($, plan)
    if (current.read && current.mtimeMs === mtimeMs && current.source === 'file') return { text: '', mtimeMs: -1 }
    return { text: await $.fs.read(file), mtimeMs }
  }
  for (const ref of BRANCHES) {
    const out = await $.process.run(['git', 'show', `${ref}:${REL}`], { cwd: root })
    if (out.exitCode === 0 && out.stdout) return { text: out.stdout, mtimeMs: 0 }
  }
  throw new Error(`${REL} مش موجود في الشغل ولا في ${BRANCHES.join(' أو ')}`)
}

function summary(p: Plan): string {
  const done = p.phases.reduce((n, x) => n + x.done, 0)
  const total = p.phases.reduce((n, x) => n + x.total, 0)
  const current = p.phases.find(x => x.done < x.total)
  return `خطة زاد ${done}/${total}` + (current ? ` · الجاي: ${current.next ?? current.title}` : '')
}

async function refresh($: EngineInterface): Promise<void> {
  try {
    const { text, mtimeMs } = await loadPlan($)
    if (mtimeMs === -1) return
    const parsed: Plan = { ...parsePlan(text, mtimeMs), source: mtimeMs === 0 ? 'git' : 'file' }
    const before = await read($, plan)
    if (before.read && mtimeMs === 0 && summary(before) === summary(parsed) && before.source === 'git') return
    await update($, plan, () => parsed)
    await pushStatus($)
  } catch (err) {
    await update($, plan, p => ({ ...p, read: false, error: String(err).slice(0, 200) }))
    await pushStatus($)
  }
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'zad-plan',
      description: 'افتح لوحة خطة زاد الحسابية (ZAD_OR_PLAN.md)',
    })
    await refreshUsage($)
    await refresh($)
    $.clock.every(3000, () => refresh($))
    void $.ui.open({ id: PANE, title: TITLE })
    return next(e)
  })

  on('session.measure', async ($, e, next) => {
    const out = await next(e)
    await refreshUsage($)
    await pushStatus($)
    return out
  })

  on('command.run', { command: 'zad-plan' }, async $ => {
    await refreshUsage($)
    await refresh($)
    const placed = await $.ui.open({ id: PANE, title: TITLE })
    const p = await read($, plan)
    if (!p.read) return { text: p.error ?? 'الخطة مش لاقيها' }
    const u = await read($, usage)
    const lines = [usageLine(u), summary(p), ...p.status, '', ...p.phases.map(x => `${x.done === x.total ? 'خلص' : `${x.done}/${x.total}`}  ${x.title}`)]
    return { text: (placed.isPlaced ? '' : 'اللوحة مش ظاهرة هنا، دي الخطة:\n') + lines.join('\n') }
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text } = $.ui.resolve(e)
    const p = await read($, plan)
    if (!p.read) {
      return (
        <Box flexDirection="column">
          <Text dimColor>مش لاقي {REL}</Text>
          {p.error ? <Text dimColor>{p.error}</Text> : null}
        </Box>
      )
    }
    const done = p.phases.reduce((n, x) => n + x.done, 0)
    const total = p.phases.reduce((n, x) => n + x.total, 0)
    const current = p.phases.find(x => x.done < x.total)
    const u = await read($, usage)
    const now = await $.clock.now()
    return (
      <Box flexDirection="column">
        {u ? (
          <Box flexDirection="column" marginBottom={1}>
            <Text bold>الباقي</Text>
            <Text color={u.ctxPct >= 85 ? 'red' : u.ctxPct >= 70 ? 'yellow' : 'green'}>
              السياق: باقي {Math.max(0, 100 - u.ctxPct)}% ({Math.round((u.window - u.ctxTokens) / 1000)}k من {Math.round(u.window / 1000)}k)
            </Text>
            {u.limits.map(l => (
              <Text color={l.percentUsed >= 90 ? 'red' : l.percentUsed >= 70 ? 'yellow' : 'green'}>
                {LIMIT_NAMES[l.kind] ?? l.kind}: باقي {Math.max(0, 100 - l.percentUsed)}% {untilText(l.resetsAt, now)}
              </Text>
            ))}
          </Box>
        ) : null}
        <Text bold>
          {done} من {total} بند خلص
        </Text>
        {current ? (
          <Box flexDirection="column" marginTop={1}>
            <Text bold>الجاي: {current.title}</Text>
            {current.next ? <Text>{current.next}</Text> : null}
          </Box>
        ) : null}
        {p.status.length > 0 ? (
          <Box flexDirection="column" marginTop={1}>
            {p.status.map(s => (
              <Text dimColor>{s}</Text>
            ))}
          </Box>
        ) : null}
        <Box flexDirection="column" marginTop={1}>
          {p.phases.map(x => (
            <Text dimColor={x.done === x.total} bold={x === current}>
              {x.done === x.total ? 'خلص ' : `${x.done}/${x.total} `}
              {x.title}
            </Text>
          ))}
        </Box>
      </Box>
    )
  })
}
