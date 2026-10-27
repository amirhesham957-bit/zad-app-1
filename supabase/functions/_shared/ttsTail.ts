// ttsTail.ts — the voice stops where the text stops, checked by listening (2026-10-27).
//
// ttsTrim.ts guesses a tail from the clip's length and its pauses. The owner still heard Zad
// finish an Arabic sentence and then answer in another language: a tail that follows the words
// with no clear pause, or one short enough to stay under the length limit, passes that guess.
// So a clip long enough to carry a tail (tailCheckSeconds) is transcribed by Whisper with word
// timestamps, and cut at the first word in a script the text does not use, or at the first word
// past the text's own words. Whisper missing, slow or failing = the clip goes on to ttsTrim
// unchanged — this check can only shorten a clip, never lose one.

import { groqKeys } from "./keyPool.ts";
import { tailCheckSeconds, TTS_SAMPLE_RATE } from "./ttsTrim.ts";

const WHISPER_URL = "https://api.groq.com/openai/v1/audio/transcriptions";
const WHISPER_MODEL = "whisper-large-v3-turbo";
/** The customer is waiting for this sentence: a slow check is dropped, not waited for. */
const TAIL_CHECK_TIMEOUT_MS = 3_000;
const FADE_MS = 40;

export interface SpokenWord {
  word: string;
  start: number;
}

type Script = "arabic" | "latin" | "other";

function scripts(text: string): Set<Script> {
  const out = new Set<Script>();
  for (const ch of text) {
    if (!/\p{L}/u.test(ch)) continue;
    out.add(/\p{Script=Arabic}/u.test(ch) ? "arabic" : /\p{Script=Latin}/u.test(ch) ? "latin" : "other");
  }
  return out;
}

function wordCount(text: string): number {
  return text.trim().split(/\s+/).filter((w) => /[\p{L}\p{N}]/u.test(w)).length;
}

/**
 * Where the tail starts, in seconds, or null when every word belongs to the text. A word is the
 * tail when its letters share no script with the text («Thank you» after Arabic) and half the
 * text was already heard, or when the words before it already cover the text with room to
 * spare — Whisper splits and joins Arabic words differently from how we count them, so a
 * quarter of slack (two words at least).
 */
export function tailStartSeconds(words: readonly SpokenWord[], text: string): number | null {
  const own = scripts(text);
  const allowed = wordCount(text) + Math.max(2, Math.ceil(wordCount(text) * 0.25));
  let counted = 0;
  let ownHeard = 0;
  for (const w of words) {
    const s = scripts(w.word);
    // Only once half the text was heard in its own script: a Whisper that misread the whole
    // clip as another language must not cut it to nothing.
    const foreign = s.size > 0 && own.size > 0 && ![...s].some((x) => own.has(x));
    if (foreign && ownHeard >= Math.ceil(wordCount(text) / 2)) return w.start;
    if (/[\p{L}\p{N}]/u.test(w.word)) counted++;
    if (!foreign && s.size > 0) ownHeard++;
    if (counted > allowed) return w.start;
  }
  return null;
}

/** The clip up to [seconds], with a short fade so the cut does not click. */
export function cutPcmAt(pcm: Uint8Array<ArrayBuffer>, seconds: number, sampleRate = TTS_SAMPLE_RATE): Uint8Array<ArrayBuffer> {
  const samples = new Int16Array(pcm.buffer, pcm.byteOffset, Math.floor(pcm.byteLength / 2));
  const cut = Math.max(0, Math.min(samples.length, Math.round(seconds * sampleRate)));
  const out = new Int16Array(cut);
  out.set(samples.subarray(0, cut));
  const fade = Math.min(cut, Math.round((sampleRate * FADE_MS) / 1000));
  for (let i = 0; i < fade; i++) {
    const idx = cut - fade + i;
    out[idx] = Math.round(out[idx] * (1 - (i + 1) / fade));
  }
  return new Uint8Array(out.buffer);
}

/** 16-bit mono PCM wrapped in a WAV header — what Whisper accepts. */
export function pcmToWav(pcm: Uint8Array, sampleRate = TTS_SAMPLE_RATE): Uint8Array<ArrayBuffer> {
  const out = new Uint8Array(44 + pcm.byteLength);
  const v = new DataView(out.buffer);
  const ascii = (at: number, s: string) => [...s].forEach((c, i) => v.setUint8(at + i, c.charCodeAt(0)));
  ascii(0, "RIFF");
  v.setUint32(4, 36 + pcm.byteLength, true);
  ascii(8, "WAVE");
  ascii(12, "fmt ");
  v.setUint32(16, 16, true);
  v.setUint16(20, 1, true);
  v.setUint16(22, 1, true);
  v.setUint32(24, sampleRate, true);
  v.setUint32(28, sampleRate * 2, true);
  v.setUint16(32, 2, true);
  v.setUint16(34, 16, true);
  ascii(36, "data");
  v.setUint32(40, pcm.byteLength, true);
  out.set(pcm, 44);
  return out;
}

/** Whisper's words with their start times, or null when it could not be asked. */
async function whisperWords(pcm: Uint8Array, keys: readonly string[], fetcher: typeof fetch): Promise<SpokenWord[] | null> {
  const signal = AbortSignal.timeout(TAIL_CHECK_TIMEOUT_MS);
  for (const key of keys) {
    const form = new FormData();
    form.append("file", new Blob([pcmToWav(pcm)], { type: "audio/wav" }), "zad.wav");
    form.append("model", WHISPER_MODEL);
    // No language on purpose: forced to Arabic, Whisper writes a foreign tail in Arabic letters.
    form.append("response_format", "verbose_json");
    form.append("timestamp_granularities[]", "word");
    try {
      const res = await fetcher(WHISPER_URL, { method: "POST", headers: { Authorization: `Bearer ${key}` }, body: form, signal });
      if (res.status === 401 || res.status === 403 || res.status === 429) {
        await res.body?.cancel();
        continue;
      }
      if (!res.ok) {
        await res.body?.cancel();
        return null;
      }
      const data = await res.json() as { words?: Array<{ word?: unknown; start?: unknown }> };
      if (!Array.isArray(data.words)) return null;
      return data.words
        .filter((w) => typeof w.word === "string" && typeof w.start === "number")
        .map((w) => ({ word: w.word as string, start: w.start as number }));
    } catch (_e) {
      return null;
    }
  }
  return null;
}

/**
 * The clip without what was said after the text. Short clips (no room for a tail) are not sent
 * to Whisper at all.
 */
export async function cutSpokenTail(
  pcm: Uint8Array<ArrayBuffer>,
  text: string,
  keys: readonly string[] = groqKeys((n) => Deno.env.get(n)),
  fetcher: typeof fetch = fetch,
): Promise<Uint8Array<ArrayBuffer>> {
  if (!keys.length || pcm.byteLength / 2 / TTS_SAMPLE_RATE <= tailCheckSeconds(text)) return pcm;
  const words = await whisperWords(pcm, keys, fetcher);
  if (!words) return pcm;
  const start = tailStartSeconds(words, text);
  if (start === null || start <= 0) return pcm;
  console.warn(`[ttsTail] cut a spoken tail at ${start.toFixed(2)}s of ${(pcm.byteLength / 2 / TTS_SAMPLE_RATE).toFixed(2)}s`);
  return cutPcmAt(pcm, start);
}
