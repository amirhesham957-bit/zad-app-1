import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  CLOSE_UPSTREAM_ENDED,
  clientCloseForUpstream,
  closeReason,
  frameToText,
  normalizeClientFrame,
} from "./protocol.ts";

Deno.test("close reason never exceeds 123 UTF-8 bytes, even for Arabic", () => {
  const long = "خلص رصيدك من المكالمات الصوتية الحية ".repeat(10);
  const cut = closeReason(long);
  assert(new TextEncoder().encode(cut).length <= 123);
  assert(long.startsWith(cut));
  assertEquals(closeReason("short"), "short");
});

Deno.test("an abnormal upstream close keeps Gemini's reason instead of a bare 1011", () => {
  const out = clientCloseForUpstream(1011, "Resource has been exhausted (e.g. check quota).");
  assertEquals(out.code, CLOSE_UPSTREAM_ENDED);
  assert(out.reason.includes("1011"));
  assert(out.reason.includes("quota"));
  assertEquals(clientCloseForUpstream(1000, "").code, 1000);
});

Deno.test("binary Gemini frames are decoded to the same JSON text", () => {
  const json = '{"serverContent":{"turnComplete":true}}';
  const bytes = new TextEncoder().encode(json);
  assertEquals(frameToText(json), json);
  assertEquals(frameToText(bytes.buffer), json);
  assertEquals(frameToText(bytes), json);
  assertEquals(frameToText(42), null);
});

Deno.test("deprecated mediaChunks audio is rewritten to realtimeInput.audio", () => {
  const legacy = JSON.stringify({
    realtimeInput: { mediaChunks: [{ mimeType: "audio/pcm;rate=16000", data: "AAAA" }] },
  });
  assertEquals(
    JSON.parse(normalizeClientFrame(legacy)),
    { realtimeInput: { audio: { mimeType: "audio/pcm;rate=16000", data: "AAAA" } } },
  );
});

Deno.test("frames that are not a single legacy audio chunk pass through untouched", () => {
  const current = JSON.stringify({ realtimeInput: { audio: { mimeType: "audio/pcm;rate=16000", data: "AAAA" } } });
  const image = JSON.stringify({ realtimeInput: { mediaChunks: [{ mimeType: "image/jpeg", data: "AAAA" }] } });
  const toolResponse = JSON.stringify({ tool_response: { functionResponses: [] } });
  for (const frame of [current, image, toolResponse, "not json"]) {
    assertEquals(normalizeClientFrame(frame), frame);
  }
});

Deno.test("persona maps to the same Gemini voice the notification reader uses", async () => {
  const { LIVE_VOICE_BY_PERSONA, liveVoiceFor } = await import("./protocol.ts");
  const { VOICE_IDS } = await import("../zad-core-intelligence/voice.ts");
  assertEquals(LIVE_VOICE_BY_PERSONA, VOICE_IDS);
  assertEquals(liveVoiceFor("sarah_warm", "X"), "Aoede");
  assertEquals(liveVoiceFor("karim_pro", "X"), "Charon");
  assertEquals(liveVoiceFor(null, "Aoede"), "Aoede");
  assertEquals(liveVoiceFor("constructor", "Aoede"), "Aoede");
  assertEquals(liveVoiceFor("Puck; drop", "Aoede"), "Aoede");
});
