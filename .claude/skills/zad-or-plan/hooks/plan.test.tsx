import { expect, test } from 'claude-code/testing'

const PLAN = `# خطة

## الحالة دلوقتي

- **المرحلة الجاية:** م١.

## المراحل

### ج١ — نسخة المتجر

- [x] ج١.١ شيل isMonitoringTool.
- [ ] ج١.٢ طلب الإذن بعد ٧ أيام.

### م١ — وقف النزيف

- [ ] م١.١ تريجر سجل الحذف.
`

const PANE = {
  plugin: 'zad-or-plan',
  component: 'Pane',
  requestId: 'zad-or-plan',
  props: { title: 'x', isFocused: false, bodyColumns: 60, placement: 'dock', scroll: { offset: 0, bodyRows: 40 }, view: {} },
} as const

test('the pane shows the next open item of the plan', async ($, on) => {
  on('clock.now', () => ({ value: 0 }))
  on('command.register', () => ({ value: { command: 'zad-plan' } }))
  on('ui.open', () => ({ value: { isPlaced: true } }))
  on('clock.every', () => ({ value: undefined }))
  on('session.cwd', () => ({ value: '/workspaces/zad-app-1' }))
  on('fs.exists', () => ({ value: true }))
  on('fs.stat', () => ({ value: { mtimeMs: 1, size: PLAN.length, kind: 'file', isLink: false } }))
  on('fs.read', () => ({ value: PLAN }))
  on('session.start', (_, e) => ({ cwd: e.cwd }))

  await $.session.start({ cwd: '/workspaces/zad-app-1', surface: 'desktop', isInteractive: true })
  const ui = await $.ui.mount({ ...PANE, surface: 'desktop' })
  expect((await ui.find({ type: 'Text', text: /بند خلص/ }))?.text).toMatch(/من/)
  expect((await ui.find({ type: 'Text', text: /الجاي:/ }))?.text).toContain('ج١')
  expect((await ui.find({ type: 'Text', text: /ج١\.٢/ }))).toBeTruthy()
  await ui.unmount()
})

test('on another branch the plan comes from git, and the command answers in text', async ($, on) => {
  on('command.register', () => ({ value: { command: 'zad-plan' } }))
  on('ui.open', () => ({ value: { isPlaced: false, reason: 'no pane here' } }))
  on('clock.every', () => ({ value: undefined }))
  on('session.cwd', () => ({ value: '/workspaces/zad-app-1' }))
  on('fs.exists', (_, e) => ({ value: String((e as { path?: string }).path ?? '').endsWith('.git') }))
  on('process.run', () => ({ value: { exitCode: 0, stdout: PLAN, stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }))
  on('session.start', (_, e) => ({ cwd: e.cwd }))

  await $.session.start({ cwd: '/workspaces/zad-app-1', surface: 'vscode', isInteractive: true })
  const out = await $.command.run({ command: 'zad-plan', args: '' } as never)
  expect(JSON.stringify(out)).toContain('ج١.٢')
})

test('the usage line says what is left of the context and of each limit', async ($, on) => {
  on('command.register', () => ({ value: { command: 'zad-plan' } }))
  on('ui.open', () => ({ value: { isPlaced: false, reason: 'no pane here' } }))
  on('clock.every', () => ({ value: undefined }))
  on('clock.now', () => ({ value: Date.parse('2026-11-21T12:00:00Z') }))
  on('session.cwd', () => ({ value: '/workspaces/zad-app-1' }))
  on('session.usage', () => ({ value: { context: { tokens: 300000, window: 1000000, percent: 30 }, rateLimits: [{ kind: 'five_hour', percentUsed: 40, resetsAt: '2026-11-21T14:00:00Z' }] } as never }))
  on('fs.exists', () => ({ value: false }))
  on('process.run', () => ({ value: { exitCode: 0, stdout: PLAN, stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }))
  on('session.start', (_, e) => ({ cwd: e.cwd }))

  await $.session.start({ cwd: '/workspaces/zad-app-1', surface: 'vscode', isInteractive: true })
  const out = JSON.stringify(await $.command.run({ command: 'zad-plan', args: '' } as never))
  expect(out).toContain('السياق باقي 70%')
  expect(out).toContain('الـ٥ ساعات باقي 60%')
})
