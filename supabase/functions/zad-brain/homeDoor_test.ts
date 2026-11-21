// صيانة البيت والمستندات والمواعيد من الباب الوحيد (ZAD_OR_PLAN م٢.٥، ٢٢/١١): كل أداة بتبعت نية لـzad_commit_intent
// بالنوع الصح، ومابتكتبش الجدول بإيدها. القراية (المطابقة والتعارض) بتفضل من الجدول.
import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { executeTool } from "./index.ts";
import { freshContext } from "./validators.ts";

type Row = Record<string, unknown>;
const RUN = { source: "app_chat", runId: "run-1" } as const;
const APPT = { id: "11111111-1111-1111-1111-111111111111", title: "دكتور", starts_at: "2026-12-01T14:00:00Z", status: "upcoming", kind: "medical", recurrence: "once", for_person: null };

function fakeDb(door: (intent: Row) => Row) {
  const intents: Row[] = [];
  const directWrites: string[] = [];
  const tables: Record<string, Row[]> = {
    zad_maintenance_items: [{ id: "m1", name: "غسالة" }],
    zad_documents: [{ id: "d1", kind: "passport", holder: "أمير", label: "", expires_on: "2028-05-10" }],
    zad_appointments: [APPT],
  };
  const from = (table: string) => {
    let single = false;
    const b: any = {
      select: () => b, eq: () => b, order: () => b, limit: () => b, gte: () => b, lte: () => b, neq: () => b, in: () => b,
      maybeSingle: () => ((single = true), b), single: () => ((single = true), b),
      insert: () => (directWrites.push(`${table}.insert`), b),
      update: () => (directWrites.push(`${table}.update`), b),
      upsert: () => (directWrites.push(`${table}.upsert`), b),
      delete: () => (directWrites.push(`${table}.delete`), b),
      then: (ok: (v: unknown) => unknown) => {
        const rows = tables[table] ?? [];
        return Promise.resolve({ data: single ? rows[0] ?? null : rows, error: null }).then(ok);
      },
    };
    return b;
  };
  const rpc = (fn: string, args: Row) => {
    if (fn === "zad_commit_intent") {
      intents.push(args.p_intent as Row);
      return Promise.resolve({ data: door(args.p_intent as Row), error: null });
    }
    return Promise.resolve({ data: null, error: null });
  };
  return { sb: { from, rpc } as any, intents, directWrites };
}

const okDoor = (i: Row): Row => {
  const p = i.payload as Row;
  const after = i.kind === "appointment.added"
    ? { id: "a-new", title: String(p.title), starts_at: String(p.starts_at), expected_cost: p.expected_cost ?? null }
    : i.kind === "appointment.updated" ? { id: p.item_id, title: "دكتور", starts_at: "2026-12-01T14:00:00Z", status: "done", expected_cost: null }
    : i.kind === "document.saved" ? { id: "d1", ...p } : null;
  const before = i.kind === "document.saved" ? { id: "d1", expires_on: "2028-05-10" } : null;
  return { ok: true, duplicate: false, row_id: "r1", payload: { ...p, before, after } };
};

Deno.test("maintenance tools: add, update and delete send their intent, and none writes the table itself", async () => {
  const { sb, intents, directWrites } = fakeDb(okDoor);
  const ctx = () => freshContext("u1");
  await executeTool(sb, "u1", "add_maintenance_item", { name: "تلاجة", warranty_expiry_date: "2027-01-01" }, {}, ctx(), RUN);
  await executeTool(sb, "u1", "update_maintenance_item", { name: "غسالة", last_service_date: "2026-11-01" }, {}, ctx(), RUN);
  await executeTool(sb, "u1", "delete_maintenance_item", { name: "غسالة" }, {}, ctx(), RUN);
  assertEquals(intents.map((i) => i.kind), ["maintenance.added", "maintenance.updated", "maintenance.deleted"]);
  assertEquals((intents[0].payload as Row).category, "عام");
  assertEquals(intents[1].payload, { item_id: "m1", patch: { last_service_date: "2026-11-01" } });
  assertEquals(intents[2].payload, { item_id: "m1" });
  assertEquals(directWrites.filter((w) => w.startsWith("zad_maintenance_items")), []);
});

Deno.test("document tools: save sends the row and reads the old one from the event, delete sends the id", async () => {
  const { sb, intents, directWrites } = fakeDb(okDoor);
  const ctx = () => freshContext("u1");
  const saved = await executeTool(sb, "u1", "save_document", { kind: "passport", holder: "أمير", expires_on: "2033-05-10" }, {}, ctx(), RUN);
  const gone = await executeTool(sb, "u1", "delete_document", { kind: "passport", holder: "أمير" }, {}, ctx(), RUN);
  assertEquals(intents.map((i) => i.kind), ["document.saved", "document.deleted"]);
  assertEquals(intents[0].payload, { kind: "passport", holder: "أمير", label: "", expires_on: "2033-05-10" });
  assertEquals(intents[1].payload, { item_id: "d1" });
  assertStringIncludes(saved, "اتعدّل"); // before رجع من الباب = تجديد
  assertStringIncludes(gone, "اتشال");
  assertEquals(directWrites.filter((w) => w.startsWith("zad_documents")), []);
});

Deno.test("appointment tools: add, update and delete go through the door with the same fields as before", async () => {
  const { sb, intents, directWrites } = fakeDb(okDoor);
  const ctx = () => freshContext("u1");
  const snap = { now_local: { utc_offset: "+03:00", time_zone: "Africa/Cairo" } };
  const start = new Date(Date.now() + 2 * 86_400_000).toISOString();
  const added = await executeTool(sb, "u1", "add_appointment", {
    title: "دكتور أسنان", starts_at: start, kind: "medical", place_label: " عيادة ", remind_minutes_before: 30, for_person: "ماما",
    confirm_conflict: true,
  }, snap, ctx(), { source: "telegram", runId: "run-1" });
  await executeTool(sb, "u1", "update_appointment", { appointment_id: APPT.id, status: "done" }, snap, ctx(), RUN);
  await executeTool(sb, "u1", "delete_appointment", { appointment_id: APPT.id }, snap, ctx(), RUN);
  assertEquals(intents.map((i) => i.kind), ["appointment.added", "appointment.updated", "appointment.deleted"]);
  const p = intents[0].payload as Row;
  assertEquals([p.title, p.kind, p.place_label, p.remind_minutes_before, p.recurrence, p.source], ["دكتور أسنان", "medical", "عيادة", 30, "once", "telegram"]);
  assertStringIncludes(added, "تم تسجيل الميعاد");
  // updated_at بيحطه الباب، والتعديل بيبعت اللي اتغير بس.
  assertEquals(intents[1].payload, { item_id: APPT.id, patch: { status: "done" } });
  assertEquals(intents[2].payload, { item_id: APPT.id });
  assertEquals(directWrites.filter((w) => w.startsWith("zad_appointments")), []);
});

Deno.test("home tools: a door refusal reaches the model with its reason code, and counts no mutation", async () => {
  const { sb } = fakeDb(() => ({ ok: false, reason: "item_not_found" }));
  const ctx = freshContext("u1");
  const out = await executeTool(sb, "u1", "delete_appointment", { appointment_id: APPT.id }, {}, ctx, RUN);
  assert(out.startsWith("مرفوض") && out.includes("item_not_found"), out);
  assertEquals(ctx.mutationCount, 0);
});
