import { assertEquals } from "jsr:@std/assert@1";
import { accumulateGeminiStream, sseData } from "./callModel.ts";
import { streamTail } from "./index.ts";

async function* events(...frames: unknown[]): AsyncGenerator<string> {
  for (const f of frames) yield JSON.stringify(f);
}

const part = (p: unknown) => ({ candidates: [{ content: { parts: [p] } }] });

Deno.test("text reaches the client as it is written, and the reply is whole", async () => {
  const seen: string[] = [];
  const reply = await accumulateGeminiStream(
    events(part({ text: "أهلاً " }), part({ text: "يا فندم" }), { usageMetadata: { promptTokenCount: 900, candidatesTokenCount: 12 } }),
    (d) => seen.push(d),
  );
  assertEquals(seen, ["أهلاً ", "يا فندم"]);
  assertEquals(reply.text, "أهلاً يا فندم");
  assertEquals(reply.toolCalls, []);
  assertEquals(reply.usage, { inTok: 900, outTok: 12 });
});

Deno.test("a tool call stops the stream and comes back as a call", async () => {
  const seen: string[] = [];
  const reply = await accumulateGeminiStream(
    events(
      part({ functionCall: { name: "add_expense", args: { amount: 50 } }, thoughtSignature: "sig" }),
      part({ text: "سجلتها" }),
    ),
    (d) => seen.push(d),
  );
  assertEquals(seen, []);
  assertEquals(reply.toolCalls.length, 1);
  assertEquals(reply.toolCalls[0].name, "add_expense");
  assertEquals(reply.toolCalls[0].input, { amount: 50 });
  assertEquals(reply.toolCalls[0].thoughtSignature, "sig");
});

Deno.test("the model's thoughts and broken frames never reach the customer", async () => {
  const seen: string[] = [];
  async function* raw(): AsyncGenerator<string> {
    yield JSON.stringify(part({ text: "خليني أفكر", thought: true }));
    yield "{not json";
    yield JSON.stringify(part({ text: "الرد" }));
  }
  const reply = await accumulateGeminiStream(raw(), (d) => seen.push(d));
  assertEquals(seen, ["الرد"]);
  assertEquals(reply.text, "الرد");
});

Deno.test("the tail: everything when nothing streamed, the rest, or nothing after a guard", () => {
  assertEquals(streamTail("", "سجلت ٥٠ جنيه قهوة"), "سجلت ٥٠ جنيه قهوة");
  assertEquals(streamTail("أهلاً", "أهلاً يا فندم"), " يا فندم");
  assertEquals(streamTail("أهلاً يا فندم", "أهلاً يا فندم"), "");
  assertEquals(streamTail("فكّرتك الساعة ٧", "لسه ماسجلتش التذكير"), "");
});

Deno.test("an event split across network chunks is read whole", async () => {
  async function* chunks(): AsyncGenerator<string> {
    yield 'data: {"a":';
    yield '1}\r\n\ndata: {"b":2}\n';
    yield "\n: keep-alive\n\ndata: {\"c\":3}";
  }
  const out: string[] = [];
  for await (const d of sseData(chunks())) out.push(d);
  assertEquals(out, ['{"a":1}', '{"b":2}', '{"c":3}']);
});
