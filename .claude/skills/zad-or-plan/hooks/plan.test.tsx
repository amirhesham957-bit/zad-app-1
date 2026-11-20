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
  on('command.register', () => ({ value: { command: 'zad-plan' } }))
  on('ui.open', () => ({ value: { isPlaced: true } }))
  on('clock.every', () => ({ value: undefined }))
  on('session.cwd', () => ({ value: '/workspaces/zad-app-1' }))
  on('fs.exists', () => ({ value: true }))
  on('fs.stat', () => ({ value: { mtimeMs: 1, size: PLAN.length, isFile: true, isDirectory: false } }))
  on('fs.read', () => ({ value: PLAN }))
  on('session.start', (_, e) => ({ cwd: e.cwd }))

  await $.session.start({ cwd: '/workspaces/zad-app-1', surface: 'desktop', isInteractive: true })
  const ui = await $.ui.mount({ ...PANE, surface: 'desktop' })
  expect((await ui.find({ type: 'Text', text: /بند خلص/ }))?.text).toMatch(/من/)
  expect((await ui.find({ type: 'Text', text: /الجاي:/ }))?.text).toContain('ج١')
  expect((await ui.find({ type: 'Text', text: /ج١\.٢/ }))).toBeTruthy()
  await ui.unmount()
})
