// trace.ts — trace_id واحد بيمشي من زرار فلاتر (هيدر x-zad-trace-id) لحد صف zad_events وSentry. (P1.7)
// traceIdOf بيقرا الهيدر (A-Za-z0-9_- من ٨ لـ٦٤) أو بيولّد uuid من غير شرط. withTrace/currentTraceId بيحملوه
// للأدوات اللي بتكتب (commitIntent) من غير ما نمرّره في كل دالة.

import { AsyncLocalStorage } from "node:async_hooks";

export const TRACE_HEADER = "x-zad-trace-id";
const VALID = /^[A-Za-z0-9_-]{8,64}$/;

export function traceIdOf(req: Request): string {
  const given = req.headers.get(TRACE_HEADER)?.trim() ?? "";
  return VALID.test(given) ? given : crypto.randomUUID().replaceAll("-", "");
}

/** هيدرز نداء فانكشن→فانكشن بتحمل نفس الـtrace. */
export function withTraceHeaders(init: HeadersInit | undefined, traceId: string): Headers {
  const h = new Headers(init);
  h.set(TRACE_HEADER, traceId);
  return h;
}

const store = new AsyncLocalStorage<string>();

export function withTrace<T>(traceId: string, fn: () => T): T {
  return store.run(traceId, fn);
}

export function currentTraceId(): string | null {
  return store.getStore() ?? null;
}
