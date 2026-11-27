/**
 * What still has to be sent as `{t}` chunks once the turn is over: the whole reply when
 * nothing streamed (a tool turn, a fast reply), the rest when the reply grew past what
 * streamed, and nothing when a guard changed it — the `done` frame's `reply` carries that.
 */
export function streamTail(streamed: string, finalReply: string): string {
  if (!streamed) return finalReply;
  return finalReply.startsWith(streamed) ? finalReply.slice(streamed.length) : "";
}
