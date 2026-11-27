/**
 * ساعة اللفة: كل lap بيسجل الوقت من البداية لحد العلامة دي بالملي ثانية، وdone بيضيف الإجمالي.
 * الأرقام بتتخزن في zad_brain_runs.prompt_sizes.timings، فالبطء بيتقاس بمراحله من الداتابيز.
 */
export function turnTimer(now: () => number = Date.now): { lap: (name: string) => void; done: () => Record<string, number> } {
  const t0 = now();
  const marks: Record<string, number> = {};
  return {
    lap: (name) => { marks[`${name}_ms`] = now() - t0; },
    done: () => ({ ...marks, total_ms: now() - t0 }),
  };
}
