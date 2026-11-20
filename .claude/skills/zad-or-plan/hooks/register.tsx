import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { Phase, Plan } from '../types'

const PANE = 'zad-or-plan'
const TITLE = 'خطة زاد الحسابية'
const REL = 'docs/agent/ZAD_OR_PLAN.md'
const FALLBACK_ROOT = '/workspaces/zad-app-1'

const EMPTY: Plan = { status: [], phases: [], read: false, mtimeMs: 0 }
const plan = atom({ plugin: 'zad-or-plan', key: 'plan' } as const, EMPTY, {
  shape: 'plan-1',
})

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

let path: string | undefined

async function refresh($: EngineInterface): Promise<void> {
  try {
    if (!path) {
      const cwd = await $.session.cwd()
      const here = `${cwd}/${REL}`
      path = (await $.fs.exists(here)) ? here : `${FALLBACK_ROOT}/${REL}`
    }
    const { mtimeMs } = await $.fs.stat(path)
    const current = await read($, plan)
    if (current.read && current.mtimeMs === mtimeMs) return
    const text = await $.fs.read(path)
    await update($, plan, () => parsePlan(text, mtimeMs))
  } catch (err) {
    await update($, plan, p => ({ ...p, read: false, error: String(err).slice(0, 200) }))
  }
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'zad-plan',
      description: 'افتح لوحة خطة زاد الحسابية (ZAD_OR_PLAN.md)',
    })
    await refresh($)
    $.clock.every(3000, () => refresh($))
    void $.ui.open({ id: PANE, title: TITLE })
    return next(e)
  })

  on('command.run', { command: 'zad-plan' }, async $ => {
    await refresh($)
    await $.ui.open({ id: PANE, title: TITLE })
    return { text: 'لوحة الخطة اتفتحت.' }
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
    return (
      <Box flexDirection="column">
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
