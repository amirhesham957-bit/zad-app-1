import { assert, assertEquals, assertNotEquals, assertThrows } from "jsr:@std/assert@1";
import {
  isUndoable,
  isUndoPhrase,
  NON_REVERSIBLE_TOOLS,
  parseUndoCallback,
  pickTargetForPhrase,
  type Surface,
  undoButton,
  undoCallbackData,
  undoResultText,
  type UndoableAction,
  UNDO_WINDOW_MS,
} from "./undoPolicy.ts";

const ID = "3f2a9c1e-7b4d-4e8a-9f10-2c5d6e7a8b9c";
const ID2 = "11111111-2222-4333-8444-555555555555";
const NOW = new Date("2026-11-22T12:00:00.000Z");

function act(over: Partial<UndoableAction> = {}): UndoableAction {
  return {
    id: ID,
    tool: "add_inventory",
    status: "applied",
    createdAt: new Date(NOW.getTime() - 60_000).toISOString(),
    ...over,
  };
}

Deno.test("شباك التراجع ٢٤ ساعة بالظبط", () => {
  assertEquals(UNDO_WINDOW_MS, 24 * 60 * 60 * 1000);
});

Deno.test("حد الشباك: الفعل عمره = الشباك بالظبط لسه ينفع", () => {
  const created = new Date(NOW.getTime() - UNDO_WINDOW_MS).toISOString();
  assertEquals(isUndoable(act({ createdAt: created }), NOW), { ok: true });
});

Deno.test("حد الشباك: ميلي ثانية بعده = expired", () => {
  const created = new Date(NOW.getTime() - UNDO_WINDOW_MS - 1).toISOString();
  assertEquals(isUndoable(act({ createdAt: created }), NOW), { ok: false, reason: "expired" });
});

Deno.test("تاريخ في المستقبل (فرق ساعة) مابيتعدّش كـexpired", () => {
  const created = new Date(NOW.getTime() + 3_600_000).toISOString();
  assertEquals(isUndoable(act({ createdAt: created }), NOW), { ok: true });
});

Deno.test("createdAt مش قابل للقراءة = expired (نقفل)", () => {
  assertEquals(isUndoable(act({ createdAt: "مش تاريخ" }), NOW), { ok: false, reason: "expired" });
});

Deno.test("status = undone أو undoneAt موجود = already_undone", () => {
  assertEquals(isUndoable(act({ status: "undone" }), NOW), { ok: false, reason: "already_undone" });
  assertEquals(
    isUndoable(act({ undoneAt: NOW.toISOString() }), NOW),
    { ok: false, reason: "already_undone" },
  );
});

Deno.test("فعل rejected (ماتطبّقش أصلاً) = not_reversible", () => {
  assertEquals(isUndoable(act({ status: "rejected" }), NOW), { ok: false, reason: "not_reversible" });
});

Deno.test("أدوات الإرسال والإشعارات = not_reversible حتى لو طازة", () => {
  for (const tool of NON_REVERSIBLE_TOOLS) {
    assertEquals(
      isUndoable(act({ tool }), NOW),
      { ok: false, reason: "not_reversible" },
      tool,
    );
  }
});

Deno.test("حذف مايتعملش تاني: فعل delete قابل للتراجع (التراجع = إعادة إدراج)", () => {
  assertEquals(isUndoable(act({ tool: "delete_inventory" }), NOW), { ok: true });
});

Deno.test("status غريب = unknown_status", () => {
  assertEquals(isUndoable(act({ status: "pending" }), NOW), { ok: false, reason: "unknown_status" });
});

Deno.test("callback roundtrip: undo:<uuid> بيرجع نفس الـid", () => {
  const data = undoCallbackData(ID);
  assertEquals(data, "undo:" + ID);
  assertEquals(parseUndoCallback(data), { actionId: ID });
});

Deno.test("callback bad input: بادئة غلط، uuid غلط، فاضي، أو نوع غلط = null", () => {
  assertEquals(parseUndoCallback("redo:" + ID), null);
  assertEquals(parseUndoCallback("undo:not-a-uuid"), null);
  assertEquals(parseUndoCallback("undo:"), null);
  assertEquals(parseUndoCallback(""), null);
  assertEquals(parseUndoCallback("undo:" + ID + " extra"), null);
  assertEquals(parseUndoCallback(undefined as unknown as string), null);
  assertThrows(() => undoCallbackData("مش-uuid"));
});

Deno.test("callback length: الـ payload ٤١ بايت، وأي حاجة فوق ٦٤ بايت = null", () => {
  const data = undoCallbackData(ID);
  assert(new TextEncoder().encode(data).byteLength <= 64);
  assertEquals(new TextEncoder().encode(data).byteLength, 41);
  assertEquals(parseUndoCallback(data + "x".repeat(24)), null);
});

Deno.test("تطبيع العبارات: تشكيل، ألف، ياء، علامات ترقيم، وحروف كبيرة", () => {
  assert(isUndoPhrase("ارجع في اللي عملته"));
  assert(isUndoPhrase("اِرْجِعْ فِي اللِّي عَمِلْتُه"));
  assert(isUndoPhrase("إرجع في اللي عملته؟"));
  assert(isUndoPhrase("  رجّع  "));
  assert(isUndoPhrase("الغى ده"));
  assert(isUndoPhrase("الغي ده!"));
  assert(isUndoPhrase("تراجع"));
  assert(isUndoPhrase("UNDO"));
  assert(isUndoPhrase("Undo."));
});

Deno.test("عبارات مش تراجع: جملة أطول، أو أمر حذف، أو فاضي", () => {
  assertEquals(isUndoPhrase("احذف الفاتورة دي"), false);
  assertEquals(isUndoPhrase("امسح اللي عملته"), false);
  assertEquals(isUndoPhrase("ارجع في اللي عملته بتاع الفاتورة"), false);
  assertEquals(isUndoPhrase("تراجع عن الحذف ده"), false);
  assertEquals(isUndoPhrase(""), false);
});

Deno.test("اختيار الهدف: أحدث فعل قابل للتراجع، حتى لو الـarray مش مرتب", () => {
  const older = act({ id: ID2, createdAt: new Date(NOW.getTime() - 5 * 60_000).toISOString() });
  const newer = act({ id: ID, createdAt: new Date(NOW.getTime() - 60_000).toISOString() });
  assertEquals(pickTargetForPhrase([older, newer], NOW), newer);
  assertEquals(pickTargetForPhrase([newer, older], NOW), newer);
});

Deno.test("اختيار الهدف: بيتخطى المتراجع عنه والإرسال والمنتهي، ويرجع null لو مفيش", () => {
  const undone = act({ id: ID2, status: "undone" });
  const sent = act({ id: ID2, tool: "send_telegram" });
  const expired = act({ id: ID2, createdAt: new Date(0).toISOString() });
  assertEquals(pickTargetForPhrase([undone, sent, expired], NOW), null);
  const good = act({ id: ID2, createdAt: new Date(NOW.getTime() - 120_000).toISOString() });
  assertEquals(pickTargetForPhrase([undone, sent, expired, good], NOW), good);
  assertEquals(pickTargetForPhrase([], NOW), null);
});

Deno.test("الزرار بنفس الشكل على كل القنوات (chat, telegram, push, log)", () => {
  const surfaces: Surface[] = ["chat", "telegram", "push", "log"];
  const shapes = surfaces.map((s) => undoButton(act(), s, NOW));
  for (const shape of shapes) {
    assertEquals(shape, shapes[0]);
  }
  assertEquals(shapes[0], { show: true, label: "ارجع فيه", payload: "undo:" + ID });
});

Deno.test("الزرار: الـid مش uuid = null، والفعل مش قابل للتراجع = show=false", () => {
  assertEquals(undoButton(act({ id: "x" }), "chat", NOW), null);
  const hidden = undoButton(act({ tool: "send_push" }), "push", NOW);
  assertEquals(hidden?.show, false);
  assertNotEquals(hidden, null);
});

Deno.test("نص الرد: كل سبب ليه رسالة مختلفة، والمجهول له fallback", () => {
  const texts = [
    undoResultText({ ok: true }),
    undoResultText({ ok: false, reason: "expired" }),
    undoResultText({ ok: false, reason: "already_undone" }),
    undoResultText({ ok: false, reason: "not_reversible" }),
    undoResultText({ ok: false, reason: "unknown_status" }),
  ];
  assertEquals(new Set(texts).size, texts.length);
  for (const t of texts) assert(t.length > 0);
  assertEquals(undoResultText({ ok: false, reason: "newer_action_exists" }), undoResultText({ ok: false }));
});

Deno.test("المساعدات مابتطلعش أي اسم أداة فيه delete، والـpick بيرجع نفس الـobject من الـinput", () => {
  const outputs: string[] = [];
  for (const s of ["chat", "telegram", "push", "log"] as Surface[]) {
    const b = undoButton(act(), s, NOW);
    if (b) outputs.push(b.label, b.payload);
  }
  for (const r of ["expired", "already_undone", "not_reversible", "unknown_status"]) {
    outputs.push(undoResultText({ ok: false, reason: r }));
  }
  outputs.push(undoResultText({ ok: true }));
  for (const o of outputs) assertEquals(o.toLowerCase().includes("delete"), false, o);

  const input = [act({ tool: "delete_inventory" })];
  const picked = pickTargetForPhrase(input, NOW);
  assert(picked === input[0]); // بيرجع الفعل الأصلي، ماينفعش يخترع أداة جديدة
  assertEquals(picked?.tool, "delete_inventory");
  for (const phrase of ["ارجع في اللي عملته", "رجّع", "الغي ده", "تراجع", "undo"]) {
    assert(isUndoPhrase(phrase));
  }
});
