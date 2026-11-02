// «آه» على «أحذف الدواء خالص من الصيدلية؟» (حساب المالك ٢/١١): الموديل عدّل الكمية لصفر وقال «شلتهولك».
import { assertEquals } from "jsr:@std/assert@1";
import { intentToolHints, unbackedDeleteClaim } from "./specialists.ts";

Deno.test("«آه» after «أحذف الدواء خالص؟» offers the delete tool", () => {
  const prior = "ولا يهمك، طالما خلصت الجرعة يبقاش ليها لازمة، أحذف الدواء خالص من الصيدلية؟";
  assertEquals(intentToolHints("آه", prior).includes("delete_pharmacy_item"), true);
  assertEquals(intentToolHints("آه", "تمام، سجلتلك القهوة").includes("delete_pharmacy_item"), false);
});

Deno.test("«شلتهولك» after an edit is not a deletion", () => {
  const reply = "ولا يهمك، شلتهولك من الصيدلية خالص وصفينا دنيته 👌";
  assertEquals(unbackedDeleteClaim(reply, ["update_pharmacy_item"]), true);
  assertEquals(unbackedDeleteClaim(reply, ["delete_pharmacy_item"]), false);
  assertEquals(unbackedDeleteClaim("عدّلتلك ميعاده لـ٧:٤٥", ["update_pharmacy_item"]), false);
  assertEquals(unbackedDeleteClaim("مش هشيله، قولّي لو عايز", ["update_pharmacy_item"]), false, "a negation is not a claim");
});
