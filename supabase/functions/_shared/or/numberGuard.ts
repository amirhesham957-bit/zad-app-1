const NUMBER_RE = /[0-9٠-٩۰-۹]+(?:[٬,][0-9٠-٩۰-۹]+)*(?:[٫.][0-9٠-٩۰-۹]+)?/gu;
const DEFAULT_FREE = [0, 1, 2, 3, 7, 14, 24, 30, 100];

function normalizeDigits(value: string): string {
  return value
    .replace(/[٠-٩]/g, (digit) => String(digit.charCodeAt(0) - 0x0660))
    .replace(/[۰-۹]/g, (digit) => String(digit.charCodeAt(0) - 0x06f0));
}

/** Extract numbers in reply order, accepting Western, Arabic-Indic, and Persian digits. */
export function extractNumbers(text: string): number[] {
  const numbers: number[] = [];
  for (const match of text.matchAll(NUMBER_RE)) {
    const start = match.index;
    if (start === undefined) continue;
    const raw = match[0];
    const before = text.slice(0, start);
    const after = text.slice(start + raw.length);

    // A standalone one-letter Arabic prefix (و ب ل ك ف), with or without a tatweel, introduces a number
    // (و٣٥، بـ٧٥); other letter-glued runs are identifiers.
    const letterBefore = /\p{L}$/u.test(before) && !/(?:^|[^\p{L}])[وبلكف]ـ?$/u.test(before) && !/[^\p{L}]ـ$|^ـ$/u.test(before);
    if (letterBefore || /^\p{L}/u.test(after)) continue;

    const normalized = normalizeDigits(raw).replace(/[٬,]/g, "").replace("٫", ".");
    numbers.push(Number(normalized));
  }
  return numbers;
}

export interface GuardResult {
  ok: boolean;
  unknown: number[];
}

/** Reject reply numbers that are neither naturally free nor close to an engine-provided number. */
export function checkNumbers(
  reply: string,
  allowed: readonly number[],
  opts?: { tolerance?: number; free?: readonly number[] },
): GuardResult {
  const tolerance = opts?.tolerance ?? 0.01;
  const free = opts?.free ?? DEFAULT_FREE;
  const unknown: number[] = [];

  for (const n of extractNumbers(reply)) {
    if (free.includes(n)) continue;
    const matched = allowed.some((a) => Math.abs(n - a) <= Math.max(tolerance * Math.abs(a), 0.5));
    if (!matched && !unknown.includes(n)) unknown.push(n);
  }
  return { ok: unknown.length === 0, unknown };
}
