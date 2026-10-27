import { assert, assertEquals } from "jsr:@std/assert@1";
import { cutSpokenTail, pcmToWav, tailStartSeconds } from "./ttsTail.ts";
import { TTS_SAMPLE_RATE } from "./ttsTrim.ts";

const SR = TTS_SAMPLE_RATE;
const TEXT = "صباح الخير يا قمر، متنساش تفطر وتاخد دواك"; // 8 words

const words = (list: string): Array<{ word: string; start: number }> =>
  list.split(" ").map((word, i) => ({ word, start: i * 0.5 }));

function tone(seconds: number): Uint8Array<ArrayBuffer> {
  const out = new Int16Array(Math.round(seconds * SR));
  for (let i = 0; i < out.length; i++) out[i] = Math.round(8000 * Math.sin((2 * Math.PI * 220 * i) / SR));
  return new Uint8Array(out.buffer);
}

const secondsOf = (pcm: Uint8Array) => pcm.byteLength / 2 / SR;

function whisper(answer: Array<{ word: string; start: number }> | null, status = 200) {
  const calls: string[] = [];
  const fetcher = ((_url: string, init: RequestInit) => {
    calls.push(String((init.headers as Record<string, string>).Authorization));
    return Promise.resolve(answer === null ? new Response("{}", { status }) : Response.json({ words: answer }, { status }));
  }) as typeof fetch;
  return { fetcher, calls };
}

Deno.test("the owner's case: an Arabic sentence and then an answer in another language", () => {
  const heard = words("صباح الخير يا قمر متنساش تفطر وتاخد دواك Thank you for listening");
  assertEquals(tailStartSeconds(heard, TEXT), 4);
});

Deno.test("the text alone, or with Whisper splitting a word or two, has no tail", () => {
  assertEquals(tailStartSeconds(words("صباح الخير يا قمر متنساش تفطر وتاخد دواك"), TEXT), null);
  assertEquals(tailStartSeconds(words("صباح ال خير يا قمر متنساش تفطر و تاخد دواك"), TEXT), null);
});

Deno.test("an Arabic tail with nothing foreign in it is cut once the words run past the text", () => {
  const heard = words("صباح الخير يا قمر متنساش تفطر وتاخد دواك وده كان صوت زاد من جوجل شكرا");
  const start = tailStartSeconds(heard, TEXT);
  assert(start !== null && start >= 4.5, String(start));
});

Deno.test("a Whisper that heard the whole clip as another language does not cut it to nothing", () => {
  assertEquals(tailStartSeconds(words("Sabah el kheir ya amar matensash teftar"), TEXT), null);
});

Deno.test("a text with a brand in Latin letters keeps it", () => {
  assertEquals(tailStartSeconds(words("اشتراك Netflix اتجدد النهارده"), "اشتراك Netflix اتجدد النهارده"), null);
});

Deno.test("the clip is cut at the tail, through Whisper's word times", async () => {
  const pcm = tone(8);
  const { fetcher } = whisper(words("صباح الخير يا قمر متنساش تفطر وتاخد دواك Thank you"));
  const out = await cutSpokenTail(pcm, TEXT, ["k"], fetcher);
  assertEquals(secondsOf(out), 4);
});

Deno.test("a short clip is never sent to Whisper, and no key means no check", async () => {
  const { fetcher, calls } = whisper([]);
  const short = tone(2);
  assertEquals(await cutSpokenTail(short, TEXT, ["k"], fetcher), short);
  const long = tone(8);
  assertEquals(await cutSpokenTail(long, TEXT, [], fetcher), long);
  assertEquals(calls.length, 0);
});

Deno.test("Whisper failing leaves the clip whole; a refused key tries the next", async () => {
  const pcm = tone(8);
  assertEquals(await cutSpokenTail(pcm, TEXT, ["k"], whisper(null, 500).fetcher), pcm);
  let n = 0;
  const fetcher = (() => {
    n++;
    return Promise.resolve(n === 1 ? new Response("{}", { status: 401 }) : Response.json({ words: words("صباح الخير يا قمر متنساش تفطر وتاخد دواك Merci") }));
  }) as typeof fetch;
  assertEquals(secondsOf(await cutSpokenTail(pcm, TEXT, ["bad", "good"], fetcher)), 4);
  assertEquals(n, 2);
});

Deno.test("the WAV header says 24 kHz, 16-bit mono", () => {
  const wav = pcmToWav(new Uint8Array(10));
  const v = new DataView(wav.buffer);
  assertEquals(new TextDecoder().decode(wav.slice(0, 4)), "RIFF");
  assertEquals(v.getUint32(24, true), SR);
  assertEquals(v.getUint16(34, true), 16);
  assertEquals(v.getUint32(40, true), 10);
});
