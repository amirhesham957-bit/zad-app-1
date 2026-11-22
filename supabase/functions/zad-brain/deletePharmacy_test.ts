// delete_pharmacy_item: one clear medicine or nothing. It used to take the first row whose name
// contained the spoken one (or the reverse), so «مضاد» deleted «مضاد حيوي» while «مضاد للالتهاب»
// was there too — and the reply said «اتحذف».
import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { executeTool } from "./index.ts";
import { freshContext } from "./validators.ts";

const MEDS = [
  { id: "a", user_id: "me", name: "مضاد حيوي" },
  { id: "b", user_id: "me", name: "مضاد للالتهاب" },
  { id: "c", user_id: "me", name: "سيبرو سوبراكس" },
];

/** Answers reads from MEDS and records every delete. */
function fakePharmacy() {
  const deleted: string[] = [];
  const from = (_table: string) => {
    let deleting = false;
    let id: string | null = null;
    const b: any = {
      select: () => b,
      delete: () => { deleting = true; return b; },
      insert: () => b,
      eq: (col: string, v: string) => { if (col === "id") id = v; return b; },
      then: (resolve: (v: unknown) => void) => {
        if (deleting && id) {
          deleted.push(id);
          return resolve({ data: [{ id }], error: null });
        }
        return resolve({ data: deleting ? [] : MEDS, error: null });
      },
    };
    return b;
  };
  // The delete goes through the door now (zad_commit_intent, M2.5); the fake records it the same way.
  const rpc = (fn: string, args: { p_intent?: { kind?: string; payload?: { item_id?: string } } }) => {
    if (fn === "zad_commit_intent" && args.p_intent?.kind === "pharmacy.deleted" && args.p_intent.payload?.item_id) {
      deleted.push(args.p_intent.payload.item_id);
      return Promise.resolve({ data: { ok: true, duplicate: false, row_id: args.p_intent.payload.item_id }, error: null });
    }
    return Promise.resolve({ data: null, error: null });
  };
  return { sb: { from, rpc } as any, deleted };
}

Deno.test("a name that fits two medicines deletes nothing and asks", async () => {
  const { sb, deleted } = fakePharmacy();
  const out = await executeTool(sb, "me", "delete_pharmacy_item", { name: "مضاد" }, {}, freshContext("me"), {} as any);
  assertStringIncludes(out, "مرفوض");
  assertStringIncludes(out, "مضاد حيوي");
  assertStringIncludes(out, "مضاد للالتهاب");
  assertEquals(deleted, []);
});

Deno.test("a name that fits none deletes nothing and lists what is there", async () => {
  const { sb, deleted } = fakePharmacy();
  const out = await executeTool(sb, "me", "delete_pharmacy_item", { name: "بانادول" }, {}, freshContext("me"), {} as any);
  assertStringIncludes(out, "مرفوض");
  assertStringIncludes(out, "سيبرو سوبراكس");
  assertEquals(deleted, []);
});

Deno.test("one clear medicine is deleted, by one word of its name", async () => {
  const { sb, deleted } = fakePharmacy();
  const out = await executeTool(sb, "me", "delete_pharmacy_item", { name: "سيبرو" }, {}, freshContext("me"), {} as any);
  assert(!out.startsWith("مرفوض"), out);
  assertEquals(deleted, ["c"]);
});
