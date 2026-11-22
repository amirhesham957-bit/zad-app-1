// أداة المحادثة (CHAT_TOOLS): بيانات صرف اتنقلت من index.ts (م٤.٥) من غير أي تغيير في السلوك.
import type { ToolDef } from "./callModel.ts";
import { APP_COMMAND_SCREENS } from "./validators.ts";
import { DOCUMENT_KINDS } from "./documents.ts";

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

/** متجدد ولا كورس — بيقرر هل الدوا ينزل قايمة البقالة لوحده لما يقرب يخلص (قرار المالك ٢٠٢٦-١٠-٠١). */
const RECURRING_HINT =
  "true لو دوا مزمن أو مستمر بيتجدد (ضغط، سكر، غدة، «باخده على طول»، «كل شهر»). false لو كورس ليه نهاية " +
  "(مضاد حيوي، «لمدة ٥ أيام»، مسكن وقت اللزوم، كريم لفترة). سيبه فاضي لو العميل ماقالش ومش باين. " +
  "المتجدد بس هو اللي بينزل قايمة التسوق لوحده لما يقرب يخلص.";

/** تكلفة الميعاد (20261010190000) — الوصف في الأداتين. */
const EXPECTED_COST_HINT =
  "تكلفة الميعاد اللي العميل قالها بالرقم («الكشف بـ٤٠٠») — بتتحجز من المتاح لحد الميعاد وبعده بتقع. ماتقدّرهاش أبداً.";

export const CHAT_TOOLS: ToolDef[] = [
  {
    name: "log_transaction",
    description: "سجّل مصروف أو دخل حصل فعلاً. نادِها بس لما العميل يقول إن فلوس اتصرفت أو اتقبضت (مثال: \"صرفت ٥٠ بقالة\"، \"قبضت الراتب\")، مش على سؤال أو استفسار. العميل هيشوف تأكيد قبل الكتابة.",
    input_schema: {
      type: "object",
      properties: {
        amount: { type: "number", description: "المبلغ بالأرقام الإنجليزية" },
        txn_kind: { type: "string", enum: ["expense", "income"] },
        title: { type: "string", description: "وصف قصير من كلام العميل نفسه" },
        category: { type: "string", description: "البقالة، المطاعم، الفواتير، المواصلات، الوقود، الاشتراكات، الأقساط، الرعاية الصحية، التعليم، الترفيه، الملابس، تحويلات، أخرى (السيرفر بيوحّد أي صيغة تانية)" },
        wallet: { type: "string", enum: ["card", "cash"], description: "cash لو العميل قال إنه دفع كاش" },
        for_person: { type: "string", description: "لمين في البيت؛ فاضي = العميل/البيت" },
        occurred_on: {
          type: "string",
          description:
            "YYYY-MM-DD بتاريخ العميل المحلي (now_local.date = النهارده). ابعته بس لو العميل قال إنها حصلت في يوم فات " +
            "(«امبارح»، «يوم ٥»)، وإلا بتتحسب في الشهر الحالي.",
        },
        lines: {
          type: "array",
          description:
            "الأصناف اللي اتشرت بالمبلغ ده لو العميل سمّاها («اشتريت لبن وعيش بـ٤٠»). بتدخل المخزن (أو الصيدلية) " +
            "مع المصروف — ماتندهش add_inventory_item لنفسها. مصروف بس.",
          items: {
            type: "object",
            properties: {
              name: { type: "string" },
              product: { type: "string", description: "الصنف من غير ماركة ولا حجم: «مياه»، «زيت عباد الشمس»، «توست»" },
              quantity: { type: "number" },
              unit: { type: "string", description: "حبة، كيلو، لتر، علبة، كيس..." },
              category: { type: "string" },
              price: { type: "number", description: "سعر السطر كله لو العميل قاله" },
              to: { type: "string", enum: ["pantry", "pharmacy"], description: "pharmacy للدوا، غير كده pantry" },
            },
            required: ["name"],
          },
        },
        allow_duplicate: {
          type: "boolean",
          // مختصرة عن قصد: log_transaction بيتبعت كامل لـGroq دايماً (GROQ_ALWAYS_FULL)، وكل حرف هنا على حساب أداة تانية.
          description: "true بس بعد ما العميل يأكد إنها عملية تانية — الأداة بترفض نفس المبلغ والنوع خلال ١٠ دقايق.",
        },
      },
      required: ["amount", "txn_kind", "title"],
    },
  },
  {
    name: "allocate_income",
    description:
      "قرّر إيداع معيّن هيتحسب في سقف مصروف الشهر ولا لأ. استخدم id من " +
      "budget.income_awaiting_decision في الـ snapshot. نادِها بس بعد ما العميل يجاوب على " +
      "سؤالك بوضوح: counts=true لو قال إن الإيداع ده للبيت/المصروف، counts=false لو قال " +
      "إنه مش للمصروف (مدخرات، فلوس حد تاني، تحويل بيعدّي). متخمّنش من غير إجابة صريحة — " +
      "لو مش متأكد اسأل الأول.",
    input_schema: {
      type: "object",
      properties: {
        transaction_id: { type: "string", description: "id الإيداع من income_awaiting_decision" },
        counts: { type: "boolean", description: "true = يتحسب في مصروف الشهر، false = لأ" },
      },
      required: ["transaction_id", "counts"],
    },
  },
  {
    name: "update_transaction",
    description: "عدّل معاملة موجودة (المبلغ/الوصف/الفئة/النوع). استخدم transaction_id من قايمة المعاملات في الـ snapshot. العميل هيشوف تأكيد قبل الكتابة.",
    input_schema: {
      type: "object",
      properties: {
        transaction_id: { type: "string" },
        amount: { type: "number" },
        title: { type: "string" },
        category: { type: "string" },
        txn_kind: { type: "string", enum: ["expense", "income"] },
        for_person: { type: "string", description: "لمين في البيت؛ \"\" يشيله" },
      },
      required: ["transaction_id"],
    },
  },
  {
    name: "delete_transaction",
    description: "احذف معاملة موجودة نهائياً (مثلاً لو العميل قال إنها مكررة أو غلط). استخدم transaction_id من قايمة المعاملات في الـ snapshot. العميل هيشوف تأكيد قبل الحذف — الحذف نهائي ومش راجع.",
    input_schema: {
      type: "object",
      properties: {
        transaction_id: { type: "string" },
      },
      required: ["transaction_id"],
    },
  },
  {
    name: "set_monthly_limit",
    description:
      "اظبط **رصيد العميل** — الرقم اللي الكارت الأخضر بيعرضه. مفيش سقف ميزانية في زاد " +
      "خلاص: الرصيد = اللي بدأت بيه + كل اللي دخل - كل اللي اتصرف، والأداة دي بتحط نقطة " +
      "البداية.\n" +
      // الوصف القديم كان \"نادِها بس لما العميل يطلب صراحة يغيّر ميزانيته\"، وكلمة \"صراحة\"
      // كانت بتقفل الباب على أكتر الصيغ اللي العملاء بيستخدموها فعلاً. حد بيقول \"معايا
      // 3000 الشهر ده\" بيطلب نفس الحاجة بالظبط، والنموذج كان بيقراها كخبر مش كطلب —
      // فيرد بكلام ومايناديش الأداة، والعميل يفتكر إن البوت رافض.
      "نادِها لما العميل يقول مبلغ ويقصد بيه اللي معاه، بأي صيغة:\n" +
      "• \"معايا 3000 الشهر ده\" / \"مش معايا غير 3000\" / \"رصيدي 3000\"\n" +
      "• \"خلي الكارت الأخضر 3000\" / \"عدّل الكارت على 3000\"\n" +
      "• \"ميزانيتي 3000\" / \"غيّر ميزانيتي لـ3000\"\n" +
      "لو المبلغ واضح، نادِها على طول — متقولش للعميل يعملها من التطبيق، دي شغلانتك.\n" +
      "التمييز اللي كان بين \"سقف صرفه\" و\"فلوس في إيده\" مابقاش موجود — الاتنين بقوا " +
      "نفس الرقم، فمفيش داعي تسأل عنه. العميل هيشوف تأكيد قبل الكتابة في كل الحالات.\n" +
      "سقف لفئة واحدة («حط سقف 300 للترفيه») مش هنا: دي set_category_budget.",
    input_schema: {
      type: "object",
      properties: {
        monthly_limit: { type: "number" },
      },
      required: ["monthly_limit"],
    },
  },
  {
    name: "set_category_budget",
    description:
      "حط أو غيّر سقف صرف شهري لفئة واحدة: «حط سقف 300 للترفيه»، «الأكل بره ميعديش 1000». " +
      "amount صفر بيشيل السقف. رصيد الكارت كله مش هنا: دي set_monthly_limit.",
    input_schema: {
      type: "object",
      properties: {
        category: { type: "string", description: "اسم الفئة زي ما بتظهر في مصاريفه" },
        amount: { type: "number", description: "المبلغ الشهري، وصفر لشيل السقف" },
      },
      required: ["category", "amount"],
    },
  },
  {
    name: "add_inventory_item",
    description: "ضيف كمية اشتراها العميل للمخزون. لو نفس الصنف موجود عنده (حتى بإملاء أو ترتيب كلام مختلف)، الكمية بتتزوّد على صفه تلقائياً بدل صف جديد. لو العميل قال الكمية اللي فاضلة فعلاً (مش اشترى)، استخدم update_inventory_qty. لو ذكر أكتر من صنف في رسالة واحدة، نادِ الأداة دي مرة لكل صنف.",
    input_schema: {
      type: "object",
      properties: {
        item_name: { type: "string" },
        quantity: { type: "number" },
        unit: { type: "string", description: "حبة، كيلو، لتر، علبة، كيس..." },
        // كانت اختيارية (مش في required) فالموديل كان بيسيبها فاضية غالباً، فالصنف
        // كان بيتسجل category=null ويظهر في تاب "أخرى" بس — مش تاب الألبان/الخضار
        // الصح، حتى لو الاسم واضح ("جبنة"، "خيار"). enum ثابت مطابق لتابات المخزون
        // في التطبيق (InventoryScreen.kt's categoryDefs) بالظبط، عشان الموديل ميخترعش
        // كلمة تانية (زي "عام" أو "dairy") ما بتطابقش تاب حقيقي.
        category: {
          type: "string",
          enum: ["البقالة", "الخضار", "الفواكه", "اللحوم", "الألبان", "المشروبات", "العناية", "أخرى"],
          description: "صنّف الصنف لواحدة من الفئات دي بالظبط — إلزامي، حتى لو مش متأكد اختار الأقرب",
        },
        expiry_date: { type: "string", description: "YYYY-MM-DD لو العميل ذكرها" },
      },
      required: ["item_name", "quantity", "category"],
    },
  },
  {
    name: "update_inventory_qty",
    description: "عدّل كمية صنف موجود بالفعل في المخزون (بما فيها التصفير لما يخلص)، أو علّمه أساسي/على فترات بـrestock_mode.",
    input_schema: {
      type: "object",
      properties: {
        item_name: { type: "string" },
        new_qty: { type: "number" },
        fraction_left: {
          type: "number",
          description: "لما العميل يقول الفاضل كنسبة مش رقم: «فاضل نصه» = 0.5، «ربعه» = 0.25، «تلته» = 0.33، «قليل/على الآخر» = 0.2، «لسه كتير» = 0.75، «زي ما هو» = 1. زاد بيحسب الكمية من آخر شرا. مكان new_qty مش معاه. «فاضل ٣ كيلو» رقم = new_qty: 3",
        },
        restock_mode: {
          type: "string", enum: ["staple", "occasional"],
          description: "لما العميل يقول إن الصنف مش أساسي/بيجيبه كل فترة («دي مش أساسية»، «الرنجة كل شهرين») = occasional: زاد مابيعتبروش ناقص ولا بيفكّر بيه. «دي أساسية» = staple. من غير new_qty لو مفيش كمية",
        },
        reason: { type: "string", description: "سبب واضح للتعديل، ١٠ حروف على الأقل" },
      },
      required: ["item_name", "reason"],
    },
  },
  {
    name: "consume_item",
    description: "العميل قال إنه استعمل/أكل/شرب حاجة من المخزون («شربنا ٣ مية»، «خلّصنا علبة جبنة»، «فتحنا كيس رز»): زاد بيطرحها من الكمية ويتعلّم معدل البيت، ويفتكر إمتى اتفتح (opened). amount بالعدد اللي قاله (٣ مية = 3) — زاد بيحوّل للعبوة لو الصنف كرتونة فيها كذا حبة. أكلة («عملنا مكرونة بالصلصة»): نادِ الأداة لكل مكوّن موجود في المخزون بكمية تقديرية بوحدة الصنف على قد البيت، وdish = اسم الأكلة. لو العميل قال الفاضل مش المستعمل استخدم update_inventory_qty.",
    input_schema: {
      type: "object",
      properties: {
        item_name: { type: "string", description: "اسم الصنف زي ما في المخزون، أو زي ما العميل قاله" },
        amount: { type: "number", description: "الكمية اللي اتستعملت (مش اللي فاضلة)" },
        unit: { type: "string", description: "الوحدة اللي العميل قالها لو قالها: «كرتونة»، «علبة»، «زجاجة»" },
        dish: { type: "string", description: "اسم الأكلة لو الاستهلاك من طبخة" },
        opened: { type: "boolean", description: "true لو العميل فتح عبوة جديدة («فتحنا علبة لبن»، «فتحت الجبنة») — زاد بيحسب عمرها بعد الفتح. amount ساعتها 0 — العلبة المفتوحة لسه بتتعد في المخزون؛ amount أكبر من 0 بس لو قال إنه استعمل منها («فتحنا علبة لبن وشربنا نصها» = 0.5)" },
      },
      required: ["item_name", "amount"],
    },
  },
  {
    // كانت موجودة في TOOLS (مسار تيليجرام/الخلفية) بس مش هنا — العميل مقدرش يقول "امسح
    // الصنف ده" في شات التطبيق نفسه أبدًا (بند 30.10). الأداة والvalidator (rate limit ٣
    // في اللفة) كانوا شغالين فعلاً من زمان، ناقص بس التسجيل هنا.
    name: "delete_inventory_item",
    description: "احذف صنفاً من المخزون نهائياً فقط لو العميل لا يريد تتبعه بعد الآن. لو الصنف خلص استخدم update_inventory_qty واجعل الكمية صفر.",
    input_schema: { type: "object", properties: { item_name: { type: "string" } }, required: ["item_name"] },
  },
  {
    name: "add_pharmacy_item",
    description: "ضيف دواء لجدول الصيدلية بمواعيد جرعاته. الاسم لوحده كفاية: «ضيف شراب كحة لبنتي» = نادي الأداة على طول بالاسم وfor_person، ومتسألش عن الجرعة أو الكمية قبل الإضافة. **متحسبش المواعيد من الوقت الحالي** — انت مش شايف ساعة العميل ولا منطقته الزمنية. لو العميل قال عدد مرات بس (\"مرتين في اليوم\") سيب dose_times فاضية وابعت daily_dose_count، والنظام هيحط مواعيد نهارية مناسبة. مبعتش dose_times إلا لو العميل نطق ساعات بعينها، وساعتها حط times_explicit=true.",
    input_schema: {
      type: "object",
      properties: {
        name: { type: "string" },
        dosage: { type: "string", description: "التركيز والتعليمات بس (500mg، بعد الأكل). ممنوع التكرار هنا — مكانه daily_dose_count و dose_times" },
        daily_dose_count: { type: "number", description: "لازم يساوي عدد المواعيد في dose_times" },
        dose_times: { type: "string", description: "الساعات اللي العميل نطقها بنفسه بس، HH:MM مفصولة بفاصلة، ٢٤ ساعة. ممنوع 24:00 — استخدم 00:00. سيبها فاضية لو هو قال عدد مرات بس." },
        times_explicit: { type: "boolean", description: "true بس لو العميل نطق الساعات دي حرفياً في كلامه" },
        // نص حر (١٣/١١): «شريط» من الفاتورة كان بيترفض من الـenum قبل ما يوصل للمعالجة — ٥ من ٧ أدوية عند المالك.
        // zad_pharmacy_unit في الداتابيز هي القاعدة: المعروف بيتوحّد والباقي بيفضل زي ما اتكتب.
        unit: { type: "string", description: "وحدة العبوة زي ما اتقالت أو اتكتبت في الفاتورة: قرص، كبسولة، شريط، علبة، زجاجة، مل، بخاخ، نقطة، كريم، كيس، أمبول" },
        quantity: { type: "number", description: "الكمية المتاحة عنده" },
        category: { type: "string", enum: ["عام", "مسكن", "مضاد حيوي", "فيتامين", "مزمن"] },
        for_person: { type: "string", description: "لو الدوا لحد تاني غير العميل (أمه، أبوه، ابنه…) اكتب اسمه زي ما العميل قاله («ماما»، «يوسف»). فاضي = العميل نفسه. لو الشخص فرد في عيلته عنده حساب ووافق على متابعة أدويته، النظام بيسجّله في صيدليته هو والتذكير بيروحله — قول اللي رجع في النتيجة بالظبط." },
        is_recurring: { type: "boolean", description: RECURRING_HINT },
      },
      required: ["name"],
    },
  },
  {
    name: "add_shopping_item",
    description: "ضيف صنف لقائمة التسوق.",
    input_schema: {
      type: "object",
      properties: {
        item_name: { type: "string" },
        quantity: { type: "number" },
      },
      required: ["item_name", "quantity"],
    },
  },
  {
    name: "update_pharmacy_item",
    description: "عدّل كمية دواء موجود، وصف الجرعة، أو مواعيد تذكيره. استخدمها عندما يقول العميل إن الجرعة أو الموعد اتغيّر.",
    input_schema: {
      type: "object",
      properties: {
        name: { type: "string" }, dosage: { type: "string" }, remaining_quantity: { type: "number" },
        daily_dose_count: { type: "number" },
        dose_times: { type: "string", description: "HH:MM مفصولة بفاصلة — الساعات اللي العميل نطقها بس" },
        times_explicit: { type: "boolean", description: "true بس لو العميل نطق الساعات دي حرفياً" },
        is_recurring: { type: "boolean", description: RECURRING_HINT },
      }, required: ["name"],
    },
  },
  {
    name: "complete_shopping_item",
    description: "علّم صنفاً في قائمة التسوق أنه تم شراؤه، ولا تضف للمخزون تلقائياً إلا إذا طلب العميل ذلك صراحة.",
    input_schema: { type: "object", properties: { item_name: { type: "string" } }, required: ["item_name"] },
  },
  {
    name: "delete_shopping_item",
    description: "احذف صنفاً من قائمة التسوق عندما يلغي العميل الحاجة إليه.",
    input_schema: { type: "object", properties: { item_name: { type: "string" } }, required: ["item_name"] },
  },
  {
    name: "set_transaction_category",
    description: "صحّح تصنيف معاملة موجودة. استخدم تصنيف من التصنيفات الموجودة عند العميل.",
    input_schema: {
      type: "object",
      properties: {
        transaction_id: { type: "string" },
        category: { type: "string" },
      },
      required: ["transaction_id", "category"],
    },
  },
  {
    name: "set_market",
    description: "سجّل بلد العميل وعملته لما يقولهم في الكلام (مثال: \"أنا في مصر\" أو \"عملتي الجنيه\"). بعد كده متسألش عنهم تاني أبداً.",
    input_schema: {
      type: "object",
      properties: {
        currency: { type: "string", description: "كود ISO من ٣ حروف كابيتال: EGP, SAR, AED, TRY..." },
        country: { type: "string", description: "كود ISO من حرفين كابيتال: EG, SA, AE, TR..." },
      },
      required: ["currency", "country"],
    },
  },
  {
    name: "log_pharmacy_dose",
    description: "سجّل إن العميل خد جرعة من دواء موجود بالفعل في قايمته (مثال: \"خدت حبة الضغط\"). بينقّص المتبقي ويضيف الدوا لقائمة التسوق لو قرّب يخلص.",
    input_schema: {
      type: "object",
      properties: {
        name: { type: "string", description: "اسم الدواء زي ما قاله العميل" },
      },
      required: ["name"],
    },
  },
  {
    // W7 — قايمة الأدوات كانت من غير أي أداة حذف صيدلية خالص، رغم إن زرار الحذف
    // (سلة المهملات) موجود في PharmacyScreen من زمان. نفس مبدأ log_pharmacy_dose:
    // الاسم مش الـ id، لأن الـ snapshot مايدّيش الموديل أي id لأدوية الصيدلية أصلاً.
    name: "delete_pharmacy_item",
    description: "احذف دواء من قايمة الصيدلية بتاعة العميل خالص (مش نفاد كمية — حذف كامل). استخدمها لما العميل يقول \"مش محتاج الدوا ده تاني\" أو \"احذف كذا من الأدوية\".",
    input_schema: {
      type: "object",
      properties: {
        name: { type: "string", description: "اسم الدواء زي ما قاله العميل" },
      },
      required: ["name"],
    },
  },
  {
    name: "add_subscription",
    description: "ضيف اشتراك اختياري جديد (نتفليكس، شاهد، جيم، تطبيق...). لما العميل يقول \"عندي اشتراك كذا بكذا جنيه\". " +
      "**الفواتير مش هنا** (كهربا، مية، غاز، نت البيت): دي add_obligation بـkind=utility — بيت واحد للفواتير.",
    input_schema: {
      type: "object",
      properties: {
        title: { type: "string" },
        amount: { type: "number" },
        renewal_date: { type: "string", description: "YYYY-MM-DD لو العميل ذكرها" },
        category: { type: "string" },
        billing_cycle: { type: "string", enum: ["MONTHLY", "YEARLY"] },
      },
      required: ["title", "amount"],
    },
  },
  {
    name: "update_subscription",
    description: "عدّل اشتراك موجود بالفعل (المبلغ/تاريخ التجديد/تفعيل أو إيقاف). استخدم اسم الاشتراك زي ما قاله العميل.",
    input_schema: {
      type: "object",
      properties: {
        title: { type: "string", description: "اسم الاشتراك زي ما قاله العميل" },
        new_amount: { type: "number" },
        new_renewal_date: { type: "string", description: "YYYY-MM-DD" },
        is_active: { type: "boolean", description: "false لو العميل بيوقف الاشتراك من غير ما يحذفه" },
      },
      required: ["title"],
    },
  },
  {
    name: "delete_subscription",
    description: "احذف اشتراك خالص من قايمة العميل. لما يقول \"ألغيت اشتراك كذا\" أو \"احذف كذا من الاشتراكات\".",
    input_schema: {
      type: "object",
      properties: {
        title: { type: "string", description: "اسم الاشتراك زي ما قاله العميل" },
      },
      required: ["title"],
    },
  },
  {
    name: "add_debt",
    description: "ضيف دين له رصيد متبقي بينقص كل ما العميل يسدد (قرض، رصيد كارت ائتمان، تقسيط بفايدة). لو العميل قال إيجار أو فاتورة أو قسط ثابت المبلغ كل شهر من غير مفهوم \"رصيد بيقل\" (زي قسط عربية ثابت، كهرباء، مصاريف دراسية) استخدم add_obligation بدلها — دي أشهر غلطة تصنيف بين الأداتين.",
    input_schema: {
      type: "object",
      properties: {
        name: { type: "string" },
        remaining_balance: { type: "number" },
        minimum_payment: { type: "number" },
        interest_rate: { type: "number", description: "نسبة سنوية، 0 لو مفيش فايدة" },
        due_day: { type: "number", description: "يوم الاستحقاق الشهري 1-31" },
      },
      required: ["name", "remaining_balance"],
    },
  },
  {
    name: "update_debt",
    description: "عدّل دين موجود (الرصيد المتبقي بعد سداد جزء، أو الحد الأدنى الشهري). استخدم اسم الدين زي ما قاله العميل.",
    input_schema: {
      type: "object",
      properties: {
        name: { type: "string", description: "اسم الدين زي ما قاله العميل" },
        new_remaining_balance: { type: "number" },
        new_minimum_payment: { type: "number" },
      },
      required: ["name"],
    },
  },
  {
    name: "delete_debt",
    description: "احذف دين خالص من قايمة العميل — لما يقول \"خلصت سداد كذا\" أو \"احذف الدين ده\".",
    input_schema: {
      type: "object",
      properties: {
        name: { type: "string", description: "اسم الدين زي ما قاله العميل" },
      },
      required: ["name"],
    },
  },
  {
    // كان مفيش أداة إضافة مباشرة للالتزامات الثابتة خالص — الطريقة الوحيدة كانت
    // الاكتشاف التلقائي (٣ شهور من نفس المبلغ عند نفس التاجر) + confirm_obligation.
    // لو العميل قال "عندي إيجار ٣٠٠٠" أو "دفعت الكهرباء" في الشات، مفيش أداة تسجّله —
    // ده اللي كان بيخلي العقل "يخلط" بين إيجار/قسط/اشتراك/فاتورة، لأنه كان مضطر
    // يحاول يحشرها في add_subscription أو add_debt رغم إنها مش أي منهم فعلياً.
    name: "add_obligation",
    description: "ضيف التزام ثابت متكرر بمبلغ معروف: إيجار، فاتورة (كهرباء/مياه/غاز/إنترنت)، قسط ثابت المبلغ (عربية مثلاً، مش دين برصيد بينقص)، أو مصاريف دراسية. ده كمان اللي بيسجّل خطط تقسيط \"اشترِ الآن وادفع لاحقاً\" (تابي/Tabby، تمارة/Tamara، فاليو/valU) — لما العميل يقول \"اشتريت بتابي/تمارة/فاليو\" سجّلها كـ installment بقسطها الشهري، مش معاملة شراء عادية لوحدها، عشان تتحسب في \"المتاح\" ويتذكّرها العميل. مختلف عن add_debt (مفيش \"رصيد متبقي\" هنا) ومختلف عن add_subscription (ده مش اشتراك ترفيهي). لما العميل يقول \"عندي إيجار/كهرباء/قسط كذا\" أو \"دفعت فاتورة كذا\".",
    input_schema: {
      type: "object",
      properties: {
        title: { type: "string" },
        amount: { type: "number" },
        kind: {
          type: "string",
          enum: ["rent", "installment", "tuition", "utility", "other"],
          description: "rent=إيجار، installment=قسط ثابت المبلغ (يشمل تابي/تمارة/فاليو)، tuition=مصاريف دراسية، utility=فاتورة كهرباء/مياه/غاز/إنترنت، other=غير كده",
        },
        recurrence: { type: "string", enum: ["monthly", "quarterly", "yearly"], description: "افتراضي monthly لو العميل مذكرش" },
        due_day: { type: "number", description: "يوم الاستحقاق الشهري 1-31 لو العميل ذكره" },
        provider: {
          type: "string",
          enum: ["تابي", "تمارة", "فاليو"],
          description: "لو ده خطة \"اشترِ الآن وادفع لاحقاً\" حدد المزوّد بالظبط بالاسم ده — ده اللي بيخلي إشعارات البنك الجاية من نفس المزوّد تتربط تلقائيًا بالخطة دي وتقلل الأقساط الباقية. سيبه فاضي لو مش تابي/تمارة/فاليو.",
        },
        total_installments: {
          type: "number",
          description: "عدد الأقساط الكلي لخطة تابي/تمارة/فاليو لو العميل قاله (مثلاً \"4 أقساط\"). من غيره متعرفش تعرف امتى الخطة تخلص، فسيبه فاضي لو مش متأكد بدل ما تخترع رقم.",
        },
      },
      required: ["title", "amount", "kind"],
    },
  },
  {
    name: "update_obligation",
    description: "عدّل مبلغ أو يوم استحقاق التزام ثابت موجود (إيجار/فاتورة/قسط). استخدم اسم الالتزام زي ما قاله العميل.",
    input_schema: {
      type: "object",
      properties: {
        title: { type: "string", description: "اسم الالتزام زي ما قاله العميل" },
        new_amount: { type: "number" },
        new_due_day: { type: "number" },
      },
      required: ["title"],
    },
  },
  {
    name: "delete_obligation",
    description: "احذف/ألغِ التزام ثابت — لما العميل يقول \"خلص الإيجار ده\" أو \"مبقتش مطلوب مني الفاتورة دي\".",
    input_schema: {
      type: "object",
      properties: {
        title: { type: "string", description: "اسم الالتزام زي ما قاله العميل" },
      },
      required: ["title"],
    },
  },
  {
    name: "add_maintenance_item",
    description: "ضيف جهاز أو غرض للمتابعة (ضمان/صيانة دورية) — زي تكييف أو غسالة. لما العميل يذكر جهاز جديد اشتراه أو عايز يتابعه.",
    input_schema: {
      type: "object",
      properties: {
        name: { type: "string" },
        category: { type: "string" },
        warranty_expiry_date: { type: "string", description: "YYYY-MM-DD" },
        service_interval_days: { type: "number", description: "كل قد إيه محتاج صيانة دورية" },
        estimated_cost: { type: "number" },
      },
      required: ["name"],
    },
  },
  {
    name: "update_maintenance_item",
    description: "عدّل بيانات جهاز متابَع بالفعل (تاريخ آخر صيانة، تاريخ انتهاء ضمان). استخدم اسم الجهاز زي ما قاله العميل.",
    input_schema: {
      type: "object",
      properties: {
        name: { type: "string", description: "اسم الجهاز زي ما قاله العميل" },
        last_service_date: { type: "string", description: "YYYY-MM-DD" },
        warranty_expiry_date: { type: "string", description: "YYYY-MM-DD" },
      },
      required: ["name"],
    },
  },
  {
    name: "delete_maintenance_item",
    description: "احذف جهاز من متابعة الصيانة — لما العميل يقول \"بيعت الغسالة\" أو \"مش عايز أتابع الجهاز ده تاني\".",
    input_schema: {
      type: "object",
      properties: {
        name: { type: "string", description: "اسم الجهاز زي ما قاله العميل" },
      },
      required: ["name"],
    },
  },
  {
    name: "save_document",
    description:
      "سجّل أو جدّد تاريخ انتهاء مستند رسمي عشان زاد يفكّر قبل ما ينتهي: جواز سفر، بطاقة شخصية، إقامة، رخصة قيادة، " +
      "رخصة عربية، أو غيره. لما العميل يقول «جوازي بينتهي في مارس ٢٠٢٧» أو «جددت رخصتي لحد ٢٠٣٠». التاريخ بس — " +
      "**ماتطلبش ولا تسجّل رقم المستند** حتى لو قاله.",
    input_schema: {
      type: "object",
      properties: {
        kind: { type: "string", enum: [...DOCUMENT_KINDS], description: "passport جواز، national_id بطاقة، residence إقامة، driving_license رخصة قيادة، vehicle_license رخصة عربية، other غيره" },
        holder: { type: "string", description: "لمين — اسم فرد في البيت («سلمى»، «ماما»). فاضي لو بتاع العميل نفسه" },
        label: { type: "string", description: "اسم المستند لو kind = other بس (زي «كارنيه النادي»)" },
        expires_on: { type: "string", description: "تاريخ الانتهاء YYYY-MM-DD. لو قال شهر وسنة بس، اسأله اليوم" },
      },
      required: ["kind", "expires_on"],
    },
  },
  {
    name: "delete_document",
    description: "شيل مستند من متابعة المستندات — لما العميل يقول «مش محتاج تفكرني برخصة العربية، بعتها».",
    input_schema: {
      type: "object",
      properties: {
        kind: { type: "string", enum: [...DOCUMENT_KINDS] },
        holder: { type: "string", description: "لمين — فاضي لو بتاع العميل نفسه" },
        label: { type: "string", description: "اسم المستند لو kind = other" },
      },
      required: ["kind"],
    },
  },
  {
    name: "update_emergency_fund_balance",
    description: "عدّل رصيد صندوق الطوارئ المُدخل يدوياً. لما العميل يقول \"حطيت X في صندوق الطوارئ\" أو \"رصيد الطوارئ بقى كذا\".",
    input_schema: {
      type: "object",
      properties: {
        new_balance: { type: "number" },
      },
      required: ["new_balance"],
    },
  },
  {
    // مواعيد العميل غير المالية (20260914004000) — شغل/مشوار/دكتور/عيلة. زاد بتفكّره بصوتها قبلها.
    name: "add_appointment",
    description:
      "سجّل ميعاد أو مشوار أو التزام غير مالي وزاد هتفكّره بيه: «فكّريني بكرة ٥ أروح البنك»، «عندي دكتور الخميس ١١». " +
      "احسب starts_at من now_local واكتبه ISO بنفس utc_offset. " +
      "مش للفلوس (إيجار/قسط → add_obligation) ومش لتحليل مؤجل («راجعلي مصاريف الأسبوع بكرة» → schedule_task). " +
      "ميعاد دكتور (kind = medical) من غير تكلفة: بعد التسجيل اسأله سؤال واحد «الكشف بكام؟ أحجزه من المتاح» — جوابه ⇒ update_appointment بـexpected_cost.",
    input_schema: {
      type: "object",
      properties: {
        title: { type: "string", description: "الميعاد بكلام العميل مختصر: «البنك»، «دكتور الأسنان»" },
        starts_at: { type: "string", description: "ISO 8601 بالمنطقة الزمنية، مثال 2026-09-15T17:00:00+03:00" },
        kind: { type: "string", enum: ["work", "errand", "medical", "family", "personal", "other"] },
        place_label: { type: "string", description: "المكان لو العميل ذكره" },
        for_person: { type: "string", description: "لو الميعاد لحد تاني غير العميل («دكتور بابا»، «تطعيم يوسف») اكتب اسمه زي ما العميل قاله. فاضي = العميل نفسه." },
        remind_minutes_before: {
          type: "number",
          description: "يفكّره قبلها بكام دقيقة. «فكّرني الساعة ٥»/«كمان ١٠ دقايق» = 0. ميعاد محتاج تحضير (دكتور، مشوار، اجتماع) = ٣٠، ولو بعيد ٦٠. مش محدد: 0.",
        },
        recurrence: {
          type: "string",
          enum: ["once", "hourly", "daily", "weekly", "monthly"],
          description: "افتراضي once. «كل ساعة» = hourly (ومعاه starts_at أول مرة). مفيش تكرار بالدقايق — لو طلب «كل ١٠ دقايق» قوله إن أقل تكرار كل ساعة واسأله يوافق.",
        },
        expected_cost: { type: "number", description: EXPECTED_COST_HINT },
        confirm_conflict: { type: "boolean", description: "true بس بعد ما الأداة سألت عن تعارض والعميل قال يتسجل زي ما هو." },
      },
      required: ["title", "starts_at"],
    },
  },
  {
    name: "update_appointment",
    description: "عدّل ميعاد: الـid من appointments أو find_appointments. خلّص (status=done)، اتلغى (cancelled)، " +
      "اتأجل (starts_at جديد)، أو غيّر الاسم أو المكان أو التكرار أو وقت التذكير. ابعت اللي اتغير بس.",
    input_schema: {
      type: "object",
      properties: {
        appointment_id: { type: "string" },
        status: { type: "string", enum: ["upcoming", "done", "cancelled"] },
        starts_at: { type: "string", description: "الوقت الجديد ISO بالمنطقة الزمنية لو اتأجل" },
        title: { type: "string" },
        place_label: { type: "string", description: "المكان الجديد، \"\" = امسحه" },
        recurrence: { type: "string", enum: ["once", "hourly", "daily", "weekly", "monthly"] },
        remind_minutes_before: { type: "number", description: "يفكّره قبلها بكام دقيقة (0 = في وقته)" },
        expected_cost: { type: "number", nullable: true, description: EXPECTED_COST_HINT + " null = شيل الحجز." },
        confirm_conflict: { type: "boolean", description: "true بس بعد ما الأداة سألت عن تعارض والعميل قال يسيبه زي ما هو." },
      },
      required: ["appointment_id"],
    },
  },
  {
    // ٨ج.٣ — حذف حقيقي. «الغيه» = update_appointment بـcancelled (بيفضل في السجل).
    name: "delete_appointment",
    description: "امسح ميعاد أو تذكير من الجدول خالص لما العميل يقول «امسحه/شيله خالص» أو اتسجل غلط. «الغيه» بس = update_appointment بـstatus=cancelled. " +
      "الـid من appointments في الـsnapshot أو من find_appointments — لو مش متأكد أنهي ميعاد اسأله الأول.",
    input_schema: {
      type: "object",
      properties: { appointment_id: { type: "string" } },
      required: ["appointment_id"],
    },
  },
  {
    // ٨ج.٣ — قراية من zad_appointments نفسه، مش من الـsnapshot المقصوص (١٤ يوم و٣٠ صف).
    name: "find_appointments",
    description: "يقرا مواعيد العميل من الجدول: «عندي إيه بكرة/الخميس/الأسبوع الجاي؟» ⇒ from/to بأيام محلية من now_local؛ " +
      "«إمتى ميعاد الدكتور؟» أو «فين ميعاد البنك؟» ⇒ query بكلمة من اسمه. المتكرر بيظهر في كل يوم بيقع فيه. " +
      "جاوب من النتيجة بس — لو فاضية قول مفيش، وماتخترعش. وبيدّيك id لـupdate_appointment أو delete_appointment.",
    input_schema: {
      type: "object",
      properties: {
        from: { type: "string", description: "أول يوم YYYY-MM-DD بتوقيت العميل" },
        to: { type: "string", description: "آخر يوم YYYY-MM-DD (شامل). فاضي = نفس from. أقصاه ٦٢ يوم" },
        query: { type: "string", description: "كلمة من اسم الميعاد أو مكانه أو صاحبه («دكتور»، «بابا»)" },
        include_past: { type: "boolean", description: "هات اللي خلص أو اتلغى كمان («روحت الدكتور إمتى آخر مرة؟»)" },
      },
    },
  },
  {
    // ملف العميل (20260914012000).
    name: "update_customer_profile",
    description:
      "سجّل حقيقة ثابتة عن العميل نفسه أول ما يقولها، في نص الكلام ومن غير ما تسأل إذن: اسمه اللي يحب يتنادى بيه، نوعه، دوره في البيت، سنه، شغله ومواعيده، ميعاد قبضه ونظامه، مصدر دخله، عدد اللي في البيت والعيال، مدينته، اللهجة اللي عايز يتكلم بيها، اهتماماته. " +
      "أمثلة: «أنا أم لتلات عيال» ⇒ household_role=mother, kids_count=3. «بشتغل مهندس وبقبض يوم ٢٥» ⇒ occupation, pay_day=25, pay_frequency=monthly. «كلمني مصري» ⇒ dialect=EG. «كلمني حجازي» ⇒ dialect=SA, dialect_region=SA_HIJAZ؛ «سعودي عادي» ⇒ dialect_region=GENERAL. «أنا تعبانة» ⇒ gender=female. " +
      "ابعت الحقول اللي اتقالت بس. null صريح = العميل قال امسحها. متخمّنش حاجة ماتقالتش. " +
      "بعد الحفظ كمّل الكلام طبيعي وناديه بالاسم اللي قاله — متعلنش إنك سجلت ومتذكرش أسماء الحقول. " +
      "**الهزار مش بيانات:** «اسمي بيتر باركر»، اسم مشهور أو شخصية خيالية أو لقب بيهزر بيه ⇒ جاريه في الهزار بخفة دم ومتنادهاش الأداة. " +
      "الاسم والنوع لو متسجلين قبل كده مابيتغيروش غير بتأكيد صريح منه (confirm_overwrite=true).",
    input_schema: {
      type: "object",
      properties: {
        preferred_name: { type: "string" },
        gender: { type: "string", enum: ["male", "female"] },
        confirm_overwrite: { type: "boolean", description: "true بس لو العميل أكّد صراحةً إنه عايز يغيّر اسم أو نوع متسجلين قبل كده." },
        household_role: { type: "string", enum: ["father", "mother", "husband", "wife", "son", "daughter", "single", "student", "grandparent", "other"] },
        age_range: { type: "string", enum: ["under_18", "18_24", "25_34", "35_44", "45_54", "55_plus"] },
        occupation: { type: "string" },
        work_schedule: { type: "string", description: "مواعيد شغله لو قالها، مثال «من ٩ لـ٥ غير الجمعة»" },
        pay_day: { type: "number", description: "يوم القبض في الشهر ١-٣١" },
        pay_frequency: { type: "string", enum: ["monthly", "biweekly", "weekly", "daily", "irregular"] },
        income_source: { type: "string", description: "راتب، شغل حر، معاش، مشروع..." },
        household_size: { type: "number" },
        kids_count: { type: "number" },
        city: { type: "string" },
        dialect: { type: "string", enum: ["EG", "SA", "GULF", "LEVANT", "IQ", "MA", "TN", "DZ", "LY", "SD", "YE", "TR", "EN"] },
        dialect_region: {
          type: "string", enum: ["SA_HIJAZ", "SA_NAJD", "SA_EAST", "SA_SOUTH", "GENERAL"], nullable: true,
          description: "منطقة اللهجة السعودية لو قالها: حجازي (جدة/مكة/المدينة)، نجدي (الرياض/القصيم)، شرقاوي، جنوبي؛ «عادي/عام» = GENERAL. null = ارجع للمدينة.",
        },
        interests: { type: "array", items: { type: "string" } },
        notes: { type: "string", description: "حاجة مهمة عنه مش ليها خانة، مختصرة" },
        cares_for: {
          type: "array",
          items: { type: "string", enum: ["children", "parents", "spouse", "siblings", "grandparents"] },
          description: "مين في رعايته: «بصرف على أبويا وأمي» ⇒ [\"parents\"]؛ «مسؤول عن نفسي بس» ⇒ []. القائمة كلها، مش إضافة.",
        },
      },
    },
  },
  {
    // تحدي ٣٠ يوم توفير (20260914010000).
    name: "start_savings_challenge",
    description:
      "ابدأ تحدي توفير (افتراضي ٣٠ يوم) بسقف يومي: «عايز أعمل تحدي توفير»، «تحدي ٣٠ يوم»، «ساعدني أوفّر الشهر ده». " +
      "لو العميل قال رقم («مش هصرف أكتر من ١٠٠ في اليوم») حطه في daily_cap، وإلا سيبه فاضي وأنا هحسب ٨٠٪ من متوسط صرفه. " +
      "كل صباح بيتحسب امبارح، وزاد بتحتفل بصوتها في المحطات — قوله كده في ردك بعد ما يبدأ.",
    input_schema: {
      type: "object",
      properties: {
        daily_cap: { type: "number", description: "السقف اليومي لو العميل حدده" },
        length_days: { type: "number", description: "مدة التحدي بالأيام، افتراضي ٣٠" },
      },
    },
  },
  {
    name: "stop_savings_challenge",
    description: "اقفل تحدي التوفير الشغال لما العميل يطلب («بطّلت التحدي»، «وقّف التحدي»). متقفلوش من نفسك. بعد القفل قوله إن ده مش فشل وإنه يقدر يبدأ تاني وقت ما يحب.",
    input_schema: { type: "object", properties: {} },
  },
  {
    // وضع الطوارئ «مفلس باقي الشهر» (20260914009000).
    name: "set_broke_mode",
    description:
      "شغّل أو اقفل وضع الطوارئ «مفلس باقي الشهر». شغّله (active=true) فوراً لما العميل يقول «أنا مفلس»، «مفلسة»، «خلصت فلوسي»، «مفلس باقي الشهر»، «مش معايا فلوس لآخر الشهر». " +
      "لو قال المبلغ اللي معاه («معايا ٢٠٠») حطه في cash_left. اقفله (active=false) لما يقول «قبضت»، «الحمد لله الفلوس جت»، «خرّجني من وضع الطوارئ». " +
      "الوضع بيعيد حساب مصروف اليوم للأيام الباقية، وبيوقف اقتراحات الشراء، والوصفات بتبقى من المخزون بس.",
    input_schema: {
      type: "object",
      properties: {
        active: { type: "boolean" },
        cash_left: { type: "number", description: "اللي معاه فعلاً لآخر الدورة لو قاله" },
      },
      required: ["active"],
    },
  },
  {
    // تذكيرات المكان (20260914007000) — بتتقال بصوت زاد لما الموبايل يبلّغ إنه وصل نوع المحل ده.
    name: "add_place_reminder",
    description:
      "سجّل تذكير مربوط بمكان مش بوقت: «فكّريني لما أروح الصيدلية أجيب بنادول»، «أول ما أنزل السوبرماركت فكّريني بالحفاضات»، «لما أكون في المول افتكر هدية ماما». " +
      "زاد بتقوله بصوتها أول ما يوصل نوع المكان ده. لو فيه وقت محدد («بكرة الساعة ٥») يبقى add_appointment مش ده. " +
      "لو الحاجة صنف هيشتريه من السوبرماركت ومش مجرد تذكير، ضيفه كمان في قايمة الشراء لو العميل عايز.",
    input_schema: {
      type: "object",
      properties: {
        note: { type: "string", description: "هيفتكر إيه، بكلام العميل مختصر: «أجيب بنادول»" },
        place: { type: "string", enum: ["supermarket", "pharmacy", "mall", "any"], description: "نوع المكان؛ any لو قال «أي محل» أو مش واضح" },
      },
      required: ["note", "place"],
    },
  },
  {
    name: "cancel_place_reminder",
    description: "الغي تذكير مكان مفتوح من place_reminders في الـsnapshot («شيل تذكير البنادول»، «خلاص جبته»).",
    input_schema: {
      type: "object",
      properties: { reminder_id: { type: "string" } },
      required: ["reminder_id"],
    },
  },
  {
    // W8 — يخلي طلب زي "راجعلي مصاريف الأسبوع وابعتلي تقرير الساعة ٩" يتنفذ فعلاً وقت
    // ما العميل طلبه، مش وقت اللفة الحالية بس. النتيجة بتوصل كإشعار (processDueAgentTasks)
    // مش كرد شات هيختفي قبل ما يوصل وقته.
    name: "schedule_task",
    description: "أجّل تنفيذ طلب لوقت لاحق (بدل الحالا) — لما العميل يقول \"فكرني بكذا الساعة X\" أو \"راجعلي كذا بكرة الصبح\". الطلب بيتنفذ فعلياً في وقته المحدد ونتيجته بتوصل كإشعار.",
    input_schema: {
      type: "object",
      properties: {
        task_description: { type: "string", description: "وصف الطلب بالظبط زي ما هيتقال لك وقت التنفيذ (مثال: \"راجع مصاريف الأسبوع ده وقولي لو محتاج أقلل السقف\")" },
        run_at: { type: "string", description: "تاريخ ووقت التنفيذ بصيغة ISO 8601 (مثال: 2026-08-10T09:00:00Z)" },
        goal_title: { type: "string", description: "لو المهمة دي جزء من هدف حياة مسجّل، اكتب عنوانه بالظبط زي ما اتسجل — بتربط المهمة بالهدف وبتزود تقدمه لما تنجز" },
        recurrence: { type: "string", enum: ["once", "daily", "weekly", "monthly"], description: "المهام المرتبطة بهدف حياة بتحتاج recurrence=daily غالباً (مثال: سلسلة تسبيحة يومية). متسجلهاش متكررة إلا لو الجزء ده من الهدف نفسه مطلوب تكرار — once افتراضي." },
      },
      required: ["task_description", "run_at"],
    },
  },
  {
    // حلقة الأهداف — العميل يحط هدف حياة، والعقل بيفككه مهام ويتابع تقدمه
    // (agent_goals + أعمدة goal_id/recurrence على agent_tasks، migration 20260829010000).
    name: "set_life_goal",
    description:
      "سجّل هدف حياة طويل المدى العميل حدده (مثال: «وفّر 2000 قبل رمضان»، «سلسلة تسبيحة 30 يوم»). "
      + "المتابعة الأسبوعية بتتجدول لوحدها. هدف فلوس (unit = money): تقدمه بكلام العميل بـadd_goal_progress، والرد بيقولك خطوة الأسبوع. "
      + "هدف عدد (unit = count): لو ليه أجزاء فكّكه لمهام بـschedule_task واربطها بـgoal_title، وتقدمه بيتحسب من المهام المنجزة. "
      + "العميل يقدر يسألك «هدفي عامل إيه؟» وأنت تجاوب بـdone من life_goals. "
      + "action=cancel للإلغاء فقط — العميل هو اللي يحط ويعدل أهدافه بنفسه، انت بتسجل كلامه.",
    input_schema: {
      type: "object",
      properties: {
        title: { type: "string", description: "عنوان الهدف بكلام العميل نفسه" },
        metric: { type: "string", description: "إزاي بنقيس النجاح (مثال: \"500 جنيه توفير شهري\")" },
        target_value: { type: "number", description: "الرقم المستهدف لو فيه" },
        deadline_date: { type: "string", description: "تاريخ الاستحقاق YYYY-MM-DD لو العميل حدده" },
        unit: {
          type: "string", enum: ["money", "count"],
          description: "لازم مع target_value: money = مبلغ فلوس (وفّر/حوّش/احجز ٢٠٠٠) بيتحرك لما العميل يقول حط كام؛ count = عدد مرات أو أيام.",
        },
        action: { type: "string", enum: ["add", "cancel"] },
      },
      required: ["title", "action"],
    },
  },
  {
    name: "add_goal_progress",
    description:
      "ZAD_PLAN ١٠.٢(د) — العميل قال إنه حط (أو شال) فلوس لهدف مبلغ (kind = amount في life_goals): «حطيت ٥٠٠ للمصيف»، «حوشت ٢٠٠ الأسبوع ده». " +
      "amount = الرقم اللي قاله هو بالظبط (سالب لو شال منه). goal_title = عنوان الهدف من life_goals بالظبط؛ لو عنده كذا هدف ومش واضح أنهي، اسأله. " +
      "ماتسجّلش رقم هو ماقالوش، ولا صرف عادي على إنه تقدم.",
    input_schema: {
      type: "object",
      properties: {
        goal_title: { type: "string", description: "عنوان الهدف من life_goals" },
        amount: { type: "number", description: "المبلغ اللي حطه (سالب = شال منه)" },
      },
      required: ["goal_title", "amount"],
    },
  },
  {
    name: "weather_forecast",
    description:
      "الجو (Open-Meteo) لـ٣ أيام: السما والعظمى والصغرى والمطر والريح. نادِها لما يسأل عن الجو في مدينة تانية جوه بلده " +
      "(«الجو في إسكندرية بكرة؟»). جو مدينته هو موجود أصلاً في weather في الـSNAPSHOT.",
    input_schema: {
      type: "object",
      properties: { city: { type: "string", description: "المدينة اللي سأل عنها. فاضي = مدينته." } },
    },
  },
  {
    name: "store_location",
    description:
      "رابط خرايط المحل اللي زاد نبّه العميل إنه جنبه (آخر ٧ أيام). نادِها لما يطلب «هات اللوكيشن» أو «فين المحل ده؟» " +
      "وابعتله map_url زي ما رجع بالظبط. ماتسألوش هو في أنهي منطقة.",
    input_schema: {
      type: "object",
      properties: { store: { type: "string", description: "اسم المحل لو سمّاه («كارفور»). فاضي = آخر محل." } },
    },
  },
  {
    name: "home_health_score",
    description:
      "درجة صحة البيت من ١٠٠ — تجمع المالية والمخزون والصيدلية والالتزامات في رقم واحد مع أهم نقطة ضعف. "
      + "نادِها لما العميل يسأل \"إحنا عاملين إيه؟\" أو \"الوضع كويس؟\"، أو في بداية الملخص الأسبوعي.",
    input_schema: { type: "object", properties: {} },
  },
  {
    name: "propose_next_month_budget",
    description:
      "اقتراح ميزانية الشهر الجاي محسوبة من متوسط صرف آخر ٣ شهور + الالتزامات الثابتة (مش رقم من خيالك). "
      + "نادِها آخر الشهر أو لما العميل يفكر في ميزانية الشهر الجاي. دي اقتراح — العميل هو اللي يأكد.",
    input_schema: { type: "object", properties: {} },
  },
  {
    // العقل يعلّم نفسه — إجراء نجح مرتين+ بيتسجل كمهارة دائمة في zad_skills.
    name: "learn_skill",
    description:
      "سجّل إجراء اكتشفت إنه ناجح مع هذا العميل (مثال: أسلوب تذكير قصير بيرد أسرع من الطويل). "
      + "نادِها لما تلاحظ نمط نجاح متكرر — مش لأي معلومة عن العميل (دي شغلانة remember). "
      + "المهارة هتفضل معاك في كل المحادثات الجاية.",
    input_schema: {
      type: "object",
      properties: {
        skill_key: {
          type: "string",
          enum: ["reminder_style", "budget_talk", "shopping_nudge", "med_tone", "meal_suggest", "digest_style", "confirm_flow", "general_pattern"],
          description: "أقرب تصنيف للإجراء",
        },
        note: { type: "string", description: "وصف الإجراء في جملة واحدة (١٠-٢٠٠ حرف) — إجراء مش حقيقة" },
      },
      required: ["skill_key", "note"],
    },
  },
  {
    name: "forward_ledger",
    description:
      "توقّع يوم بيوم للأيام الجاية: الرصيد المتوقع كل يوم، أول يوم هيبقى فيه بالسالب، " +
      "الالتزامات والاشتراكات اللي هتتخصم في الفترة دي، والأصناف اللي هتخلص وإمتى. " +
      "نادِها لأي سؤال عن المستقبل (\"هعرف أكمّل للراتب؟\"، \"كام هيفضل معايا يوم ٢٤؟\"، " +
      "\"المية هتكفيني كام يوم؟\"). **متحسبش الأرقام دي بنفسك من الـsnapshot** — الأداة " +
      "دي بتحسبها بالظبط ومن غير أي استهلاك للكوتة. اللي في stock_unknown معناه إن معدل " +
      "استهلاكه لسه مش معروف — قول كده صراحة، متخمّنش ليه تاريخ. " +
      "**قبل شراء كبير** (العميل بيسأل «أقدر أشتري…؟» أو قال إنه ناوي يشتري حاجة بمبلغ): ابعت hypothetical_spend. " +
      "لو verdict = tight قوله بالتاريخ والالتزام اللي هيتأثر («لو اشتريتها النهارده، قسط المدرسة يوم ١٥ مش هيتغطى») " +
      "واقترح تأجيل أو مبلغ أقل — القرار قراره. لو ok قول إنه آمن بالرقم اللي هيفضل.",
    input_schema: {
      type: "object",
      properties: {
        days: { type: "number", description: "عدد الأيام للأمام. الافتراضي ٣٠، الأقصى ١٢٠." },
        hypothetical_spend: {
          type: "number",
          description: "«لو اشتريت…»: مبلغ شراء العميل بيفكر فيه (أو قاله إنه هيشتريه). الرد فيه what_if: الرصيد قبل وبعد، " +
            "أول يوم بالسالب بعده، والالتزامات اللي الرصيد كان مغطيها ومش هيغطيها (newly_uncovered). verdict: ok / tight / already_short — " +
            "محكوم لحد آخر الدورة (window_end) بس، لأن القبض بعدها والتوقّع مابيحسبوش.",
        },
        on_date: { type: "string", description: "يوم الشراء YYYY-MM-DD لو مش النهارده." },
        label: { type: "string", description: "اسم الحاجة اللي هيشتريها بكلامه (للرد بس)." },
      },
    },
  },
  {
    name: "start_family_poll",
    description:
      "افتح تصويت في شات العيلة باسم زاد لقرار عيلة (الإجازة فين، أكل الجمعة، خطة الميزانية، خروجة). " +
      "**بس لما العميل يطلبه أو يوافق صراحةً** — الرسالة بتوصل العيلة كلها. ٢–٦ اختيارات قصيرة، والتصويت بيتقفل " +
      "لوحده بعد closes_in_hours (افتراضي ٤٨) وزاد بيعلن النتيجة وهل الكبار متفقين. النتيجة رأي العيلة، مش تنفيذ: " +
      "أي فلوس بعدها بتعدي على تأكيد ولي الأمر زي أي حاجة تانية.",
    input_schema: {
      type: "object",
      properties: {
        question: { type: "string", description: "السؤال بكلام العميل" },
        options: { type: "array", items: { type: "string" }, description: "من ٢ لـ٦ اختيارات" },
        closes_in_hours: { type: "number", description: "يتقفل بعد كام ساعة (افتراضي ٤٨، أقصى ٣٣٦)" },
      },
      required: ["question", "options"],
    },
  },
  {
    name: "emergency_card",
    description:
      "كارت طوارئ لشخص في البيت (أو للعميل نفسه): رقم الإسعاف لو معروف في بلده، أدويته وجرعات آخر ٢٤ ساعة، مواعيده الطبية، " +
      "اللي زاد عارفه عنه (حساسية/حالة مزمنة)، وأفراد العيلة. نادِها **فوراً** لما العميل يقول إن حد تعبان فجأة، وقع، " +
      "اتحرق، أو أي طارئ. أول سطر في ردك: «كلّم الإسعاف» بالرقم لو رجع (ambulance) — وإلا «كلّم الإسعاف في بلدك». " +
      "بعدها الكارت باختصار. ممنوع تشخّص أو تقترح دوا أو جرعة. لو محتاج صيدلية: find_nearby_stores بـ pharmacy.",
    input_schema: {
      type: "object",
      properties: {
        for_person: { type: "string", description: "مين (ماما، عمر…) — فاضي لو العميل نفسه" },
      },
    },
  },
  {
    name: "plan_gathering",
    description:
      "خطة عزومة أو ضيوف: كميات تقديرية بالفرد (غدا/عشا أو قعدة حلو)، اللي في البيت منها، وهل في القايمة، ووضع الفلوس (المتاح، ولو " +
      "حدد ميزانية: تكفي ولا لأ). نادِها لما العميل يقول «عازم ناس» أو «جايين ضيوف الخميس». اعرض السطور باختصار، واسأل «أضيفهم " +
      "للقايمة؟» (add_gathering_to_list)، واعرض تحط ميعاد العزومة (add_appointment). **ماتخترعش إجمالي فلوس** — مفيش أسعار بوحدات. " +
      "ولو saving_agreement = true، العميل متفق يوفّر: اقترح عزومة أبسط من غير لوم.",
    input_schema: {
      type: "object",
      properties: {
        people: { type: "number", description: "كام واحد هياكل — الضيوف + أهل البيت (٢–٦٠)" },
        meal: { type: "string", enum: ["meal", "sweets"], description: "meal غدا/عشا، sweets حلو وشاي" },
        budget: { type: "number", description: "ميزانية العزومة لو العميل قالها" },
      },
      required: ["people"],
    },
  },
  {
    name: "add_gathering_to_list",
    description: "ضيف سطور خطة العزومة لقايمة التسوق مرة واحدة — **بعد ما العميل يوافق بس**. نفس people وmeal اللي اتعرضوا.",
    input_schema: {
      type: "object",
      properties: {
        people: { type: "number" },
        meal: { type: "string", enum: ["meal", "sweets"] },
        skip: { type: "array", items: { type: "string" }, description: "سطور العميل قال عنده منها (زي «رز»)" },
      },
      required: ["people"],
    },
  },
  {
    name: "set_sleep_window",
    description:
      "مواعيد نوم العميل وصحيانه، عشان زاد مايبعتش تنبيهات مش ضرورية وهو نايم (الجرعات والطوارئ مستثناة). لما يقول «بنام ١٢ " +
      "وبصحى ٦» أو «ماتبعتليش حاجة قبل ٨». اليدوي بيكسب اللي الموبايل اتعلّمه من قفل الشاشة. clear=true يرجّع للافتراضي (١١–٧).",
    input_schema: {
      type: "object",
      properties: {
        bed: { type: "string", description: "HH:MM بتوقيته — من ٢٠:٠٠ لـ٠٣:٠٠" },
        wake: { type: "string", description: "HH:MM — من ٠٤:٠٠ لـ١٢:٠٠" },
        clear: { type: "boolean" },
      },
    },
  },
  {
    name: "mark_subscription_paid",
    description:
      "العميل دفع اشتراك/فاتورة/قسط متسجّل عنده («دفعت النت»، «سددت قسط الموبايل») — نفس زرار «دفعت» في الاشتراكات: " +
      "بيسجّل الدفعة مصروف بمبلغ الاشتراك وبيقدّم التجديد دورة، وعدّاد الأقساط بينقص. **فلوس ⇒ بتستنى «أيوه» العميل.** " +
      "title زي ما قاله. مبلغ مختلف عن المسجّل؟ ابعته في amount. «دي دفعة تانية» بعد رفض التكرار ⇒ allow_duplicate=true.",
    input_schema: {
      type: "object",
      properties: {
        title: { type: "string", description: "اسم الاشتراك زي ما قاله العميل" },
        amount: { type: "number", description: "لو دفع مبلغ غير المسجّل بس" },
        allow_duplicate: { type: "boolean" },
      },
      required: ["title"],
    },
  },
  {
    name: "add_shortages_to_shopping",
    description:
      "ضيف كل نواقص البيت لقايمة التسوق مرة واحدة («ضيف النواقص كلها»، «نزّل الناقص على القايمة») — نفس زرار النواقص في «بيتي»: " +
      "الأصناف اللي خلصت فعلاً بدورة شرا البيت، من غير اللي على القايمة أصلاً ومن غير اللي على فترات. صنف واحد بعينه ⇒ add_shopping_item.",
    input_schema: { type: "object", properties: {} },
  },
  {
    name: "snooze_pharmacy_dose",
    description:
      "أجّل تذكير جرعة دوا متسجّل («أجّل البنادول ربع ساعة»، «فكّرني بالدوا بعد نص ساعة») — نفس «فكّرني بعدين». " +
      "بيأجّل الجرعة اللي لسه رنّت أو هترن (من ٣ ساعات فاتت لساعة جاية)، أو dose_time لو قال ميعاد بعينه. مش تسجيل جرعة ولا تغيير مواعيد الدوا.",
    input_schema: {
      type: "object",
      properties: {
        name: { type: "string", description: "اسم الدوا زي ما قاله" },
        minutes: { type: "number", description: "كام دقيقة (٥–٢٤٠، ١٥ لو ماقالش)" },
        dose_time: { type: "string", description: "HH:MM لو قال أنهي جرعة" },
      },
      required: ["name"],
    },
  },
  {
    name: "report_price",
    description:
      "العميل بيبلّغ عن سعر شافه بنفسه في محل («الزيت في كارفور بقى ٨٥») — نفس «ساهم بسعر»: بيدخل أسعار الجمهور بعملة حسابه. " +
      "سعر شافه بعينه بس، مش تخمين ولا سعر من النت.",
    input_schema: {
      type: "object",
      properties: {
        item: { type: "string" },
        price: { type: "number" },
        store: { type: "string" },
        city: { type: "string", description: "لو قالها، وإلا مدينته" },
      },
      required: ["item", "price"],
    },
  },
  {
    name: "clear_place_visits",
    description:
      "امسح سجل الأماكن والمحلات اللي زارها لما **يطلب صراحةً** («امسح الأماكن اللي رحتها») — نفس «مسح الزيارات» في شاشة الذاكرة. كله مرة واحدة.",
    input_schema: { type: "object", properties: {} },
  },
  {
    name: "rate_recipe",
    description:
      "رأي العميل في وصفة («الكشري اللي اقترحته ماعجبنيش»، «الوصفة دي حلوة») — نفس 👍/👎 في الوصفات: اللي ماعجبهوش مابيرجعش في الاقتراحات.",
    input_schema: {
      type: "object",
      properties: { recipe_name: { type: "string" }, liked: { type: "boolean" } },
      required: ["recipe_name", "liked"],
    },
  },
  {
    name: "dismiss_insight",
    description:
      "اقفل رؤية/تنبيه معروض عليه («مش عايز أشوف تنبيه الكهربا ده تاني») — نفس أزرار القفل على الكارت. " +
      "about = كلمة من عنوانها. reason: not_relevant (مش مهتم) / wrong_data (الرقم غلط) / timing (عرف خلاص).",
    input_schema: {
      type: "object",
      properties: {
        about: { type: "string", description: "كلمة من عنوان الرؤية" },
        reason: { type: "string", enum: ["not_relevant", "wrong_data", "timing"] },
      },
      required: ["about", "reason"],
    },
  },
  {
    name: "set_app_setting",
    description:
      "شغّل أو اقفل مفتاح من إعدادات التطبيق لما العميل يطلبه بالكلام — نفس المفتاح اللي في الإعدادات (ZAD_PLAN ١٠.٢أ). " +
      "pet_calls = نداءات زادو (الصاحب بينده عليه ويفكّره): «بطّل زادو ينده عليا» ⇒ on=false. " +
      "food_pattern = صورة الأكل في الرئيسية (اللي بيتعلمه من مشترياته): «شيل صورة الأكل» ⇒ on=false. " +
      "ماتغيّرش حاجة ماطلبهاش صراحة.",
    input_schema: {
      type: "object",
      properties: {
        setting: { type: "string", enum: ["pet_calls", "food_pattern"] },
        on: { type: "boolean" },
      },
      required: ["setting", "on"],
    },
  },
  {
    name: "delete_memory",
    description:
      "امسح ملاحظة واحدة من ذاكرة زاد عن العميل لما **يطلب صراحةً** إنك تنساها («انسى إني بحب السمك»، «امسح اللي قلتهولك عن شغلي») — " +
      "نفس «انسى» في شاشة الذاكرة. memory_id من memory في الـsnapshot بالظبط، الملاحظة اللي بيتكلم عنها. " +
      "لو المعلومة اتغيّرت بس (مش عايزك تنساها) سجّل الجديدة بـremember أو update_customer_profile بدل المسح. " +
      "ملاحظة من فرد تاني في العيلة ماتتمسحش من هنا.",
    input_schema: {
      type: "object",
      properties: { memory_id: { type: "string", description: "id الملاحظة من memory" } },
      required: ["memory_id"],
    },
  },
  {
    name: "restore_deleted",
    description:
      "رجّع حاجة اتمسحت من حاجة العميل (حركة فلوس، صنف مخزن أو قايمة، دوا، اشتراك، دين، التزام، صيانة، مستند، ميعاد، " +
      "ملاحظة، ميزانية فئة) لما **يطلب** يرجّعها («رجّعلي اللي اتمسح»، «الميعاد اتمسح بالغلط»). من غير trash_id بترجع قايمة " +
      "باللي اتمسح في آخر ٣٠ يوم كل سطر بـtrash_id؛ لو فيه أكتر من حاجة ممكن يقصدها اسأله أنهي واحدة. بالـtrash_id بترجّعها بنفس بياناتها. " +
      "ماتخترعش trash_id: لازم يكون من القايمة.",
    input_schema: {
      type: "object",
      properties: { trash_id: { type: "integer", description: "trash_id من القايمة. فاضي = اعرض القايمة." } },
    },
  },
  {
    name: "share_memory_with_family",
    description:
      "ZAD_PLAN ١٠.٢(ج) — شارك ملاحظة من ذاكرة العميل مع عيلته (عقل زاد عند باقي الأفراد يشوفها)، أو رجّعها ليه لوحده. " +
      "share = true بس لما **العميل نفسه** يوافق صراحة («أيوه شاركها»، «خلّي العيلة تعرف») — على سؤال الصبح (asked_this_morning.kind = family_share) " +
      "أو لما يطلبها هو. share = false لما يقول «خليها ليا» أو «ماتشاركهاش». memory_id = asked_this_morning.memory_id لو ده جواب السؤال، " +
      "وإلا من memory في الـsnapshot بالظبط. ملاحظة فرد تاني ماتتلمسش، وحساب الطفل مابيشاركش.",
    input_schema: {
      type: "object",
      properties: {
        memory_id: { type: "string", description: "id الملاحظة" },
        share: { type: "boolean", description: "true = شاركها مع العيلة، false = خليها خاصة" },
      },
      required: ["memory_id", "share"],
    },
  },
  {
    name: "handover_card",
    description:
      "كارت تسليم للي فاضل في البيت لما العميل يسافر أو يغيب كام يوم: جرعات الأدوية ومواعيدها (ولمين) واللي هيخلص، المواعيد، " +
      "جدول حصص الأولاد، المصروف المسموح في اليوم والمستحقات، وقايمة التسوق — للأيام الجاية. نادِها لما يقول «مسافر بكرة» أو " +
      "«جهّز لمراتي/لجوزي اللي محتاجه وأنا مش موجود». اعرضه مرتب ومختصر يتبعت زي ما هو. من بياناته هو بس — مفيش موقع حد ولا متابعة.",
    input_schema: {
      type: "object",
      properties: {
        days: { type: "number", description: "عدد أيام الغياب (١–١٤، ٣ افتراضي)" },
      },
    },
  },
  {
    name: "decision_impact",
    description:
      "أثر قرار كبير على الشهور الجاية (٦ افتراضي، ١٢ أقصى): مدرسة جديدة، عربية، رحلة، قسط جديد، شغل جديد. " +
      "بيحسب من متوسط دخل العميل وصرفه الفعلي آخر ٩٠ يوم (حتمي، صفر كوتة): الرصيد شهر بشهر من غير القرار ومعاه، " +
      "أول شهر بالسالب، كام شهر الفايض يرجّع التكلفة (payback_months)، وكام يقلل صرفه في اليوم لو الفايض بقى سالب " +
      "(daily_cut_needed). confidence = low يعني التاريخ أقل من شهرين — قولها صراحة. لو القرار بيغيّر مصروفه " +
      "الثابت، اقترح سقف جديد بأداة الميزانية والعميل يأكد. متحسبش الأرقام دي بنفسك.",
    input_schema: {
      type: "object",
      properties: {
        label: { type: "string", description: "القرار بكلام العميل (مدرسة جديدة لعمر، عربية…)" },
        one_time_cost: { type: "number", description: "تكلفة مرة واحدة (مقدم، رسوم، تمن الرحلة)" },
        monthly_cost: { type: "number", description: "تكلفة جديدة كل شهر (مصاريف المدرسة الشهرية، قسط، بنزين)" },
        monthly_income_change: { type: "number", description: "تغيير في الدخل الشهري (+ زيادة، - نقص)" },
        start_month: { type: "string", description: "شهر البداية YYYY-MM لو مش الشهر ده" },
        months: { type: "number", description: "كام شهر قدام، الافتراضي ٦ والأقصى ١٢" },
      },
    },
  },
  {
    name: "confirm_life_shift",
    description:
      "جواب العميل على سؤال «حصل تغيير في البيت؟» عن تحول في life_shift (confirmed = null): true = ده الطبيعي الجديد " +
      "(شغل جديد، عربية، حد جه يعيش معاهم…)، false = لأ، صدفة. ماتناديهاش من غير ما هو يجاوب.",
    input_schema: { type: "object", properties: { confirmed: { type: "boolean" } }, required: ["confirmed"] },
  },
  {
    name: "set_life_circumstance",
    description:
      "العميل **قال** إن البيت في ظرف: حد عيان أو طوارئ (kind = exceptional)، أو فترة امتحانات (kind = exams) — والمدة بالأيام " +
      "(افتراضي ٣، أقصى ١٤). زاد بيأجّل التذكيرات غير العاجلة؛ الجرعات والمواعيد والأمان زي ما هم. " +
      "**ماتستنتجش ظرف** من مشتريات أو من نبرة كلامه — بس لما يقوله، أو يوافق لما تسأله «أهدّي التنبيهات كام يوم؟». " +
      "في الطارئ، لو قال الظرف هيكلّف كام (مستشفى، تصليح) ابعت cost: المبلغ بيتحجز والباقي بيتوزع على الأيام، والرد فيه اليوم الجديد. " +
      "لو قال التكلفة بعد ما الظرف اتسجّل، نادِها تاني بنفس kind ومعاها cost.",
    input_schema: {
      type: "object",
      properties: {
        kind: { type: "string", enum: ["exceptional", "exams"] },
        days: { type: "number", description: "كام يوم (١–١٤)" },
        cost: { type: "number", description: "الطارئ بس: الظرف هيكلّف كام (اللي العميل قاله — ماتقدّرش من عندك)" },
      },
      required: ["kind"],
    },
  },
  {
    name: "end_life_circumstance",
    description: "العميل عايز التنبيهات ترجع عادية («رجّع التنبيهات»، «خلاص الحمد لله») — بينهي الهدوء دلوقتي.",
    input_schema: { type: "object", properties: {} },
  },
  {
    name: "household_resilience",
    description:
      "الشهور الصعبة اللي فاتت (المصاريف عدّت الدخل) والبيت رجع منها في كام شهر — من حركاته الفعلية، حتمي. " +
      "نادِها لما العميل يقلق من شهر صعب («الشهر ده تقيل»، «مش هنعدّي»، «إحنا في أزمة»). أقل من ٦ شهور تاريخ = مفيش أرقام.",
    input_schema: { type: "object", properties: {} },
  },
  {
    name: "log_decision",
    description:
      "سجّل قرار كبير **اتاخد فعلاً** («خلاص اشتريت العربية»، «قررنا ننقل عمر المدرسة الجديدة»، «مسكت الشغل الجديد») " +
      "بنفس أرقام decision_impact، عشان زاد يراجع معاه بعد شهر وبعد ٣ شهور: الحسبة طلعت صح ولا لأ. " +
      "**مش** لسؤال افتراضي («لو اشتريت…»، «أفكر في…») — ده decision_impact بس. محتاج تكلفة أو تغيير في الدخل.",
    input_schema: {
      type: "object",
      properties: {
        label: { type: "string", description: "القرار بكلام العميل (عربية، مدرسة عمر الجديدة…)" },
        one_time_cost: { type: "number", description: "تكلفة مرة واحدة (المقدم، الرسوم، التمن)" },
        monthly_cost: { type: "number", description: "تكلفة جديدة كل شهر (قسط، مصاريف المدرسة، بنزين)" },
        monthly_income_change: { type: "number", description: "تغيير في الدخل الشهري (+ زيادة، - نقص)" },
      },
      required: ["label"],
    },
  },
  {
    name: "query_family",
    description: "اقرا حالة العيلة والأولاد (عددهم، أدوارهم، أرصدتهم). نادِها لما العميل يسأل عن عيلته أو أولاده.",
    input_schema: { type: "object", properties: {} },
  },
  {
    name: "find_nearby_stores",
    description:
      "دوّر على محلات قريبة من العميل (سوبرماركت/صيدلية/مخبز...). نادِها لما تقترح إنه " +
      "يعدّي يجيب النواقص أو يشتري حاجة. لو رجّعت مفيش موقع حديث، قول للعميل إنك مش عارف " +
      "هو فين دلوقتي بدل ما تخمّن محل.",
    input_schema: {
      type: "object",
      properties: {
        tag: { type: "string", enum: ["supermarket", "pharmacy", "bakery", "convenience", "cafe", "restaurant", "mall", "park", "cinema"] },
        radius_meters: { type: "number", description: "افتراضي ٣٠٠٠" },
      },
      required: ["tag"],
    },
  },
  {
    name: "suggest_product",
    description:
      "شوف لو فيه منتج مترشّح يطابق حاجة العميل محتاجها فعلاً (صنف في قايمة التسوق أو " +
      "مخزون قرب يخلص). نادِها بس لما تكون بتتكلم عن حاجة هو محتاجها — مش عشان تعرض " +
      "منتجات. لو رجّعت فاضي، ماتقترحش أي منتج من عندك.",
    input_schema: { type: "object", properties: {} },
  },
  {
    name: "medicine_price",
    description:
      "سعر دوا في بلد العميل من بحث نت حقيقي (بالمصدر والتاريخ)، ومحفوظ ٣٠ يوم. نادِها لما يسأل «الدوا ده بكام؟» أو " +
      "قبل ما تقول إن دوا غالي أو رخيص. سعر بس: من غير بديل ولا جرعة ولا نصيحة طبية.",
    input_schema: {
      type: "object",
      properties: { name: { type: "string", description: "اسم الدوا زي ما العميل قاله أو زي ما هو في صيدليته («بنادول إكسترا»)" } },
      required: ["name"],
    },
  },
  {
    name: "check_price_online",
    description:
      "سعر حقيقي من بحث ويب فعلي (مش تخمين). نادِها قبل ما تقول للعميل إن حاجة غالية أو رخيصة. " +
      "لو رجعت status=no_results أو unclear، قول للعميل إنك مش لاقي سعر موثوق — متخترعش رقم. " +
      "الرد بيضم sources: اذكر مصدر واحد على الأقل في ردك.",
    input_schema: {
      type: "object",
      properties: {
        item_name: { type: "string" },
        store: { type: "string", description: "اختياري" },
      },
      required: ["item_name"],
    },
  },
  {
    name: "web_search",
    description:
      "بحث في الإنترنت عن أي معلومة برّه بيانات البيت (مقارنة منتجات، معلومة عامة، خبر). " +
      "بترد نتايج حقيقية بعناوينها وروابطها — استشهد بالمصدر في ردك ومتقولش معلومة مش موجودة في النتايج. " +
      "سؤال عن «آخر مرة / أحدث / الحالي» (مين كسب آخر بطولة، مين المدرب دلوقتي): ابحث دايماً — ذاكرتك قديمة — " +
      "وحط في query_en اسم الحاجة نفسها بالإنجليزي (مثلاً «FIFA Club World Cup»)؛ النتايج بترجع الأحدث الأول، " +
      "فجاوب من أحدث نتيجة وقول سنتها. ومتقولش «المصدر: …» عن حاجة ماجاتش في نتايج البحث ده.",
    input_schema: {
      type: "object",
      properties: {
        query: { type: "string", description: "سؤال البحث" },
        query_en: { type: "string", description: "نفس السؤال بالإنجليزي، لمعلومة عالمية (رياضة، علوم، أحداث، مشاهير)" },
      },
      required: ["query"],
    },
  },
  {
    name: "family_digest",
    description:
      "ملخّص أفراد العيلة: صرف كل فرد آخر ٣٠ يوم ونسبته من سقفه هو، المهام اللي خلّصها، " +
      "وسلسلة تسبيحه. نادِها لما العميل يسأل \"عيلتي عاملة إيه؟\" أو عن التزام حد بميزانيته. " +
      "بترجّع أرقام مجمّعة بس — مفيش معاملات فردية، فمتقولش إن حد اشترى حاجة بعينها.",
    input_schema: { type: "object", properties: {} },
  },
  {
    // نفس حكاية delete_inventory_item: كانت موجودة في TOOLS بس مش هنا، فالعميل مقدرش
    // ينده وساطة العيلة من شات التطبيق أصلاً رغم إن الوصف بيقول "نادِها لما العميل يشكك"
    // (بند 30.10). قراءة بس — مفيش كتابة، فمش محتاجة validator جديد.
    name: "family_mediation",
    description: "وساطة عائلية ذكية: لو اتنين في العيلة صرفوا على نفس الحاجة في نفس الفترة، اكتشف التكرار واقترح تسوية عادلة (مين يرجّع لإيه ومقدار إيه). نادِها لما العميل يشكك في ازدواج صرف أو يطلب مراجعة مشتريات العيلة المتكررة.",
    input_schema: {
      type: "object",
      properties: {
        category_hint: { type: "string", description: "الفئة المشتبه فيها (اختياري — لو فاضي نفحص كل الفئات)" },
      },
    },
  },
  {
    name: "weekly_savings_plan",
    description:
      "خطة توفير أسبوعية محسوبة من مصاريف العميل الفعلية آخر ٤ أسابيع (مش نصائح عامة). " +
      "بتحدد أكبر ٣ فئات قابلة للتقليل وتقترح مبلغ أسبوعي واقعي لكل واحدة، وبتتابع خطة الأسبوع الماضي " +
      "لو كانت موجودة (التزم بيها ولا لأ). نادِها لما العميل يطلب توفير، أو في نهاية كل أسبوع للمتابعة.",
    input_schema: {
      type: "object",
      properties: {
        follow_up: { type: "boolean", description: "true = بتابع خطة الأسبوع اللي فات (مش بعمل خطة جديدة)" },
      },
    },
  },
  {
    name: "answer_same_product",
    description:
      "سجّل جواب العميل على «دول نفس الحاجة؟» عن اسمين لصنف (لبن/حليب، مياه/ماء). same = true بس لو هو قال إنهم نفس الحاجة: " +
      "بيبقوا صنف واحد في البيت كله (المخزن والقايمة ومعدل الاستهلاك) باسم keep. same = false لو قال مختلفين: مابيتسألش تاني. " +
      "ماتناديهاش من غير ما العميل يجاوب.",
    input_schema: {
      type: "object",
      properties: {
        a: { type: "string", description: "الاسم الأول زي ما اتسأل عنه" },
        b: { type: "string", description: "الاسم التاني" },
        same: { type: "boolean", description: "اللي العميل قاله: نفس الحاجة (true) ولا مختلفين (false)" },
        keep: { type: "string", description: "الاسم اللي يحب الصنف يتسمّى بيه لو قاله (وإلا a)" },
      },
      required: ["a", "b", "same"],
    },
  },
  {
    name: "save_trusted_technician",
    description:
      "احفظ فني العميل بيثق فيه (سباك، كهربائي…) في «فنيين بثق فيهم» عشان رقمه يبان بنقرة وقت الطوارئ. " +
      "بس لما العميل يقول الاسم والرقم بنفسه — الرقم زي ما قاله بالظبط، وماتألّفش رقم أبداً.",
    input_schema: {
      type: "object",
      properties: {
        name: { type: "string", description: "اسم الفني زي ما العميل قاله («عم محمد»، «أحمد السباك»)" },
        trade: { type: "string", enum: ["plumber", "electrician", "gas", "ac", "carpenter", "locksmith", "appliances", "other"] },
        phone: { type: "string", description: "الرقم زي ما العميل قاله بالظبط" },
        notes: { type: "string", description: "ملاحظة قصيرة لو قالها («شاطر في السخانات»)" },
      },
      required: ["name", "trade", "phone"],
    },
  },
  {
    name: "remember_occasion",
    description:
      "سجّل عيد ميلاد أو ذكرى جواز — للعميل نفسه أو لحد من عيلته وصحابه — عشان زاد يفكّره الصبح قبلها بـ٣ أيام " +
      "(ويقترح يحجز مبلغ للهدية) ويهنّي يومها. لما العميل يقول تاريخ: «عيد ميلاد مراتي ١٢ مارس»، «أنا مواليد ٤ يوليو». " +
      "نفس الشخص بتاريخ تاني = تصحيح، مش مناسبة جديدة. ماتخمّنش اليوم: لو قال الشهر بس اسأله عن اليوم.",
    input_schema: {
      type: "object",
      properties: {
        occasion: { type: "string", enum: ["birthday", "anniversary"] },
        person: { type: "string", description: "صاحب المناسبة («ماما»، «يوسف»، «مراتي»). سيبه فاضي لو المناسبة بتاعة العميل نفسه." },
        month: { type: "number", description: "الشهر 1-12" },
        day: { type: "number", description: "اليوم 1-31" },
      },
      required: ["occasion", "month", "day"],
    },
  },
  {
    name: "remember",
    description: "سجّل ملاحظة دائمة عن العميل تفتكرها في المحادثات الجاية (تفضيل، ظرف، قاعدة قالها).",
    input_schema: {
      type: "object",
      properties: {
        scope: { type: "string" },
        note: { type: "string", description: "بين ١٠ و٢٠٠ حرف" },
        confidence: { type: "number", description: "رقم بين 0 و1" },
        ...REMEMBER_ABOUT_AND_UNTIL,
        share_with_family: {
          type: "boolean",
          description:
            "true بس لو العميل قال حاجة واضح إنها بتخص العيلة كلها مش هو بس (حساسية ولد، " +
            "عيد ميلاد، عادة رمضان) وقال أو أوحى إنه عايز باقي العيلة تعرفها. الافتراضي false — " +
            "ملاحظة خاصة. لو مفيش عيلة للعميل، متأثرش.",
        },
      },
      required: ["note"],
    },
  },
  {
    // شيف زاد نفسه، مش تخمين الموديل: نفس meal_suggestions اللي صفحة الشيف بتناديه.
    name: "suggest_recipes",
    description:
      "اسأل «شيف زاد» يقترح أكلات من مخزون البيت الحالي — نفس اقتراحات صفحة الشيف (بتراعي آراء العميل "
      + "في الوصفات، عدد الأسرة، المتاح في الميزانية، ووضع الطوارئ). نادِها لما العميل يسأل «أطبخ إيه؟» أو "
      + "«أعمل أكل إيه من اللي عندي؟». اعرض الوصفات اللي رجعت بس — ماتخترعش وصفة من عندك جنبها.",
    input_schema: { type: "object", properties: {} },
  },
  {
    // أمر واجهة — العقل يقدّر يفتح شاشة أو يظلّل عنصر داخل التطبيق (نمط "الإيجنت
    // يدير كل زرار"). قراءة/تنقّل بس: مفيش أي كتابة فلوس أو بيانات حساسة من هنا.
    // الأوامر بتوصل للكلاينت في رد الـ agent_turn (حقل app_commands) وبيستقبلها
    // ZadViewModel زي ما بيستقبل الرؤى.
    name: "app_command",
    description:
      "افتح شاشة معينة في التطبيق للعميل، أو جهّز فورم إضافة جاهزة، أو ظلّل عنصر بعينه على الشاشة. "
      + "استخدمها لما تقول للعميل \"هات أوريك المخزون\" أو \"افتح قائمة الشراء\" — بدل ما يقول هو فين. "
      + "screen لازم يكون من القايمة المسموحة بالظبط.",
    input_schema: {
      type: "object",
      properties: {
        screen: {
          type: "string",
          // نفس قايمة المحقّق بالظبط — كانت ١١ شاشة هنا مقابل ١٨ مسموحين، فالموديل ماكانش
          // يعرف إنه يقدر يفتح التسبيحة ولا الإشعارات ولا المواعيد.
          enum: [...APP_COMMAND_SCREENS],
        },
        action: { type: "string", enum: ["open", "add_item", "highlight"] },
        highlight_name: { type: "string", description: "اسم العنصر المطلوب تظليله لو action=highlight/add_item" },
      },
      required: ["screen", "action"],
    },
  },
  {
    name: "read_house",
    description:
      "يقرا جزء من بيانات البيت اللي مش في الملخص اللي قدامك. الأجزاء: recent_transactions (آخر ٢٠ حركة بأرقامها " +
      "ومعرّفاتها)، stock (صفوف المخزون كلها)، stock_unknown، notifications_sent (التنبيهات اللي اتبعتت)، " +
      "observations، lifestyle، behavior_profile (سلوك الصرف)، obligation_rows، obligation_detection، " +
      "cash_reconciliation، cycle_detection، self_review، debts، maintenance_due، dose_adherence، recent_outings، " +
      "upcoming، anomalies، distinct_categories، dismissal_reasons، documents (الجواز والبطاقة والرخص وانتهاؤها). " +
      "نادِها قبل أي إجابة أو تعديل محتاج الجزء ده.",
    input_schema: {
      type: "object",
      properties: { section: { type: "string", description: "اسم الجزء بالظبط من القايمة" } },
      required: ["section"],
    },
  },
  {
    name: "open_support_ticket",
    description:
      "يفتح شكوى أو طلب دعم لفريق زاد البشري ويبعته على إيميل الدعم ومعاه آخر المحادثة. استخدمها لما العميل " +
      "يشتكي من عطل، أو يطلب يكلم حد من الفريق، أو مشكلة في التطبيق مقدرتش تحلها معاه. اكتب الموضوع وملخص المشكلة بكلامه.",
    input_schema: {
      type: "object",
      properties: {
        subject: { type: "string", description: "موضوع قصير (مثال: صفحة الصيدلية فاضية)" },
        message: { type: "string", description: "المشكلة بالتفصيل بكلام العميل" },
      },
      required: ["subject", "message"],
    },
  },
  {
    name: "gold_price",
    description:
      "سعر جرام الدهب النهارده (عيار 24 و21 و18) في بلد العميل، من الأخبار المنشورة النهارده. " +
      "استخدمها لأي سؤال عن سعر الدهب قبل أي حاجة تانية، وابدأ ردك بالرقم ومصدره ووقته.",
    input_schema: { type: "object", properties: {}, required: [] },
  },
  {
    name: "fetch_current_exchange_rate",
    description:
      "سعر الصرف التقريبي بين عملتين من جدول أسعار زاد (بيتحدّث مرة في اليوم). استخدمها قبل أي " +
      "كلام عن تحويل عملات — ماتقولش رقم صرف من عندك.",
    input_schema: {
      type: "object",
      properties: {
        from_currency: { type: "string", description: "مثل: EGP, USD, SAR, EUR, GBP, TRY (3 أحرف)" },
        to_currency: { type: "string", description: "مثل: EGP, USD, SAR, EUR, GBP, TRY (3 أحرف)" },
      },
      required: ["from_currency", "to_currency"],
    },
  },
  {
    name: "area_trends",
    description:
      "ترندات سوق العميل: الأصناف اللي بيوت كتير في بلده اشترتها أو حطّتها في قايمة التسوق آخر ١٤ يوم " +
      "(افتراضياً)، بعدد البيوت واتجاهها (up/down/flat/new) مقارنة بالفترة اللي قبلها. " +
      "استخدمها لـ«الناس بتشتري إيه اليومين دول؟» أو قبل ما ترشّح حاجة يخزّنها. " +
      "الصنف مابيظهرش غير لو ٥ بيوت مختلفة على الأقل عندهم (العيلة بيت واحد) — ده حد خصوصية. " +
      "لو items فاضية قول بصراحة إن لسه مفيش بيوت كفاية في سوقه تعمل ترند، ومتخترعش واحد. " +
      "reason=no_market يعني العميل لسه ماختارش بلده. مفيش أسماء محلات ولا حد بعينه في النتيجة — متدّعيش إنك تعرف مين.",
    input_schema: {
      type: "object",
      properties: {
        days: { type: "number", description: "الفترة بالأيام. الافتراضي ١٤، من ٧ لـ٦٠." },
      },
    },
  },
  {
    name: "check_price_trend",
    description:
      "اتجاه سعر صنف من بلاغات الناس (صفحة الأسعار) بعملة العميل، آخر 30 يوم افتراضياً: آخر سعر، " +
      "المتوسط، والتغيير. استخدمها قبل نصيحة شراء. لو مفيش بلاغات قول كده — ماتخترعش سعر.",
    input_schema: {
      type: "object",
      properties: {
        item_name: {
          type: "string",
          description: "اسم الصنف زي ما العميل قاله (مثل: لبن، عيش، زيت) — البلاغات بالعربي غالباً",
        },
        days: { type: "number", description: "عدد الأيام للفحص. الافتراضي 30، الأقصى 90." },
      },
      required: ["item_name"],
    },
  },
  {
    // م٥.٥ (restockBudget.ts): بتيجي بنية بس (RESTOCK_BUDGET_INTENT) أو مع وكيل المخزن.
    name: "restock_on_budget",
    description:
      "«معايا مبلغ قليل، أجيب إيه الأول؟»: بترتب المستحق من المخزن والقايمة على المبلغ. الضروري الأول، وبعده الأهم " +
      "بالاستعجال. الأسعار من القايمة أو آخر سعر دفعه البيت بس، واللي مالوش سعر بيرجع «محتاج سعره». الأرقام من الأداة بس.",
    input_schema: {
      type: "object",
      properties: { budget: { type: "number", description: "المبلغ اللي معاه للمشتريات بعملته" } },
      required: ["budget"],
    },
  },
  {
    name: "plan_menu",
    description:
      "منيو أسبوع (أو كام يوم) على ميزانية: العميل بيدّيك الأطباق وسعر كل واحد، والأداة بتختار أحسن توليفة بالذوق " +
      "(اللي حبّوه وماحبّوهوش) من غير ما تعدّي الميزانية. ماتخترعش أطباق ولا أسعار: اسأل العميل. الأرقام من الأداة بس.",
    input_schema: {
      type: "object",
      properties: {
        budget: { type: "number", description: "ميزانية المنيو كله بعملة العميل" },
        days: { type: "number", description: "عدد الأيام (١ لـ١٤)" },
        max_repeat: { type: "number", description: "أقصى تكرار للطبق الواحد (الافتراضي ١)" },
        dishes: {
          type: "array",
          description: "الأطباق من العميل",
          items: {
            type: "object",
            properties: { name: { type: "string" }, cost: { type: "number", description: "تكلفة الطبق للبيت كله" }, tags: { type: "array", items: { type: "string" } } },
            required: ["name", "cost"],
          },
        },
      },
      required: ["budget", "days", "dishes"],
    },
  },
  {
    name: "check_medicine_reorder",
    description:
      "رصيد الأدوية بعد الجرعات المتسجلة، وكام يوم يكفي، ونقطة إعادة الطلب بأيام التوريد، وميعاد الجرعة الجاية. نادِها لما " +
      "يسأل «الدوا هيخلص امتى؟» أو «أطلب الدوا إمتى؟». lead_time_days (أيام توريد الصيدلية) من كلام العميل، مش تخمين. " +
      "الأرقام من الأداة بس.",
    input_schema: {
      type: "object",
      properties: {
        name: { type: "string", description: "اسم دواء واحد (اختياري، من غيره كل الأدوية)" },
        lead_time_days: { type: "number", description: "أيام توريد الصيدلية (افتراضي ٣)" },
        safety_days: { type: "number", description: "أيام أمان (افتراضي ٢)" },
        time_zone: { type: "string", description: "منطقة الفرد الزمنية لو غير العميل، مثلاً Africa/Cairo" },
      },
    },
  },
  {
    name: "plan_gathering_time",
    description:
      "أحسن وقت تقعد فيه العيلة كلها سوا الأسبوع الجاي (٧ أيام من النهارده): بتدّيها الأفراد ومدة اللمّة وأوقات انشغال كل واحد " +
      "(من كلام العميل: ماتخمنش مواعيد حد)، وبترجّع أحسن ٣ أوقات ومين ناقص في كل واحد. الأرقام من الأداة بس.",
    input_schema: {
      type: "object",
      properties: {
        members: { type: "array", items: { type: "string" }, description: "أسماء الأفراد (٢ لـ١٢)" },
        minutes: { type: "number", description: "مدة اللمّة بالدقايق (١٥ لـ٣٦٠)" },
        earliest: { type: "string", description: "أبكر ساعة HH:MM (افتراضي 09:00)" },
        latest: { type: "string", description: "آخر ساعة HH:MM (افتراضي 23:00)" },
        busy: {
          type: "array",
          description: "أوقات الانشغال",
          items: {
            type: "object",
            properties: {
              member: { type: "string" },
              day: { type: "number", description: "٠ = النهارده … ٦" },
              from: { type: "string", description: "HH:MM" },
              to: { type: "string", description: "HH:MM" },
            },
            required: ["member", "day", "from", "to"],
          },
        },
      },
      required: ["members", "minutes"],
    },
  },
  {
    name: "safe_daily_spend",
    description:
      "مصروف النهارده الآمن (المتاح بعد الالتزامات ÷ أيام لحد القبض) واحتمال إنه يوصل للقبض (محاكاة على صرف آخر ٢٨ يوم). " +
      "نادِها لما يسأل «أصرف كام النهارده؟» أو «هكمّل الشهر؟». من غير مدخلات: كله من ميزانيته. قبل ١٤ يوم صرف بترجّع الرقم «تقريباً» " +
      "من غير احتمال. الأرقام من الأداة بس.",
    input_schema: { type: "object", properties: {} },
  },
  {
    name: "where_to_buy",
    description:
      "فين يلاقي صنف معيّن بسعر كويس: العروض الشغالة عليه في محلات بلده، وفي أنهي محلات اتشاف في فواتير عملاء زاد في " +
      "مدينته آخر ٣ أسابيع (بالسعر لو ٣ بيوت أو أكتر بلّغوا). نادِها لما يسأل «ألاقي X فين؟» أو «أرخص مكان لـX» أو لما " +
      "صنف خلص عنده وبيسأل يجيبه منين. الأرقام من الأداة بس.",
    input_schema: {
      type: "object",
      properties: { item_name: { type: "string", description: "اسم الصنف زي ما العميل قاله، مثلاً «زيت عافية»" } },
      required: ["item_name"],
    },
  },
  {
    // ZAD_PLAN ١٠.١ الشريحة ٤د — بتيجي بنية بس (ITEM_PREFERENCE_INTENT).
    name: "set_item_preference",
    description:
      "سجّل تفضيل البيت لصنف: البراند اللي بيجيبوه (preferred_brand)، أو براند مابيجيبوهوش (rejected_brand)، أو إن الصنف " +
      "اتجاب صدفة ومش هيتجاب تاني (accidental). «بنجيب نادك مش المراعي» = نداءين.",
    input_schema: {
      type: "object",
      properties: {
        item_name: { type: "string", description: "الصنف من غير ماركة: «حليب»، «رز»، «صوص ترافل»" },
        kind: { type: "string", enum: ["preferred_brand", "rejected_brand", "accidental"] },
        brand: { type: "string", description: "البراند — لازم مع preferred_brand وrejected_brand" },
      },
      required: ["item_name", "kind"],
    },
  },
  {
    // «هاتلي عروض كيتا»، «فيه عروض إيه؟» (طلب المالك ٧/١١): العروض والأكواد المتخزنة في بلده — chatDeals.ts.
    name: "find_deals",
    description:
      "العروض وأكواد الخصم الشغالة في بلد العميل (من صفحات المحلات وفيديوهاتهم وبحثنا)، بأسعارها ولينكاتها. نادِها لما يطلب " +
      "عروض أو كود خصم، لمحل أو تطبيق («عروض كارفور»، «كود كيتا») أو لصنف («عروض على الزيت») أو من غير تحديد.",
    input_schema: {
      type: "object",
      properties: {
        store: { type: "string", description: "اسم المحل أو التطبيق لو قاله" },
        item_name: { type: "string", description: "الصنف لو قاله" },
      },
    },
  },
  {
    name: "get_nearby_deals",
    description:
      "أرخص بلاغات الناس في فئة (آخر أسبوع، بعملة العميل) مقارنة بمتوسط الفئة: المحل/المكان، " +
      "الصنف، السعر، ونسبة التوفير. مفيش مسافات — ده من بلاغات الناس مش من الخريطة.",
    input_schema: {
      type: "object",
      properties: {
        item_category: {
          type: "string",
          enum: ["bread", "milk", "eggs", "oil", "vegetables", "fruits", "general"],
          description: "الفئة العريضة — اكتشاف مجموعة سلع، مش سلعة واحدة",
        },
        savings_threshold: {
          type: "number",
          description: "اعرض فقط المتاجر اللي توفر أكتر من X% (default: 10%)",
        },
      },
      required: ["item_category"],
    },
  },
];
