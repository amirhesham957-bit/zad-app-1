/**
 * الكيانات والزمن في remember (ZAD_LIVING_BRAIN.md الشريحة ١) — نفس الشكل في أداة التحليل
 * اليومي وأداة الشات. الـschema sanitizer بيشيل maxItems، فحد التلاتة في الوصف وفي
 * normalizeMemoryEntities.
 */
export const REMEMBER_ABOUT_AND_UNTIL = {
  about: {
    type: "array",
    description:
      "مين/إيه الملاحظة دي عنهم، ٣ بالكتير: شخص («ماما»، «يوسف»)، مكان («مدرسة النيل»، «كارفور المعادي»)، " +
      "صنف («قهوة»)، أو جهة («البنك الأهلي»). العميل نفسه مش كيان — ماتحطوش.",
    items: {
      type: "object",
      properties: {
        kind: { type: "string", enum: ["person", "place", "item", "org"] },
        name: { type: "string" },
      },
      required: ["kind", "name"],
    },
  },
  valid_until: {
    type: "string",
    description:
      "بس لو الحقيقة مؤقتة («أخويا عندنا لحد الجمعة»، «صايم الشهر ده»، «في إجازة الأسبوع ده»): آخر يوم ليها " +
      "YYYY-MM-DD. من غيرها الملاحظة دائمة.",
  },
  // م٩.٢ (memoryTime.ts): الفرد، والإيقاف المؤقت للعادة.
  member: {
    type: "string",
    description:
      "اسم فرد البيت اللي الحقيقة عنه بالظبط زي ما هو في أفراد البيت («أحمد»). فاضي لو عن العميل نفسه أو البيت كله.",
  },
  pause_note_id: {
    type: "string",
    description:
      "id عادة من memory وقفت **مؤقتاً** («أحمد وقف الجيم أسبوع»): مع valid_until = آخر يوم في الوقفة وnote = السبب، " +
      "والعادة بترجع لوحدها بعد التاريخ. من غير valid_until = العادة المتوقفة رجعت بدري («رجع الجيم»). " +
      "لو وقفت خالص سجّل حقيقة جديدة بدل كده.",
  },
  // الحساس مايتحفظش غير بعد «صح؟» (ZAD_PLAN ٥.٣، sensitiveMemory.ts).
  sensitive: {
    type: "boolean",
    description:
      "true لو الملاحظة خاصة أوي لو اتفهمت غلط أو اتشاركت تجرح (صحة، حمل، خلافات بيت، دين، قضايا) والكشف " +
      "ممكن يفوّتها. الملاحظة مش هتتحفظ، والأداة هتقولك تسأل العميل «صح؟».",
  },
  pending_id: {
    type: "string",
    description: "جواب العميل على ملاحظة حساسة سألته عليها: الـid من رسالة الأداة أو من memory_pending، ومعاه pending_yes.",
  },
  pending_yes: { type: "boolean", description: "true = قال «آه/صح» فتتحفظ، false = قال «لأ» فمش هتتحفظ ولا تتسأل تاني." },
} as const;
