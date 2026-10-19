// كمية سطر الشرا (ZAD_PLAN ٣.٨، بلاغ المالك ١٩/١٠: «نص كيلو رز» كان بيتسجّل ١ كيلو).
//
// المخزن بياخد الكمية زي ما هي، ٣ أرقام عشرية (zad_inventory.quantity numeric(12,3) من 20261020110000)؛
// الصيدلية بالحبة. نفس قاعدة private.zad_record_purchase_impl، عشان تليجرام والعقل والسيرفر يتفقوا.

/** [to] = وجهة السطر. رقم مش صالح أو صفر أو بالسالب = ١. */
export function purchaseQuantity(raw: unknown, to: "pantry" | "pharmacy"): number {
  const q = Number(raw);
  if (!Number.isFinite(q) || q <= 0) return 1;
  const capped = Math.min(10000, q);
  if (to === "pharmacy") return Math.max(1, Math.round(capped));
  return Math.max(0.001, Math.round(capped * 1000) / 1000);
}
