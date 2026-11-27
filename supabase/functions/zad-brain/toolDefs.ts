import type { ToolDef } from "./callModel.ts";
import { REMEMBER_ABOUT_AND_UNTIL } from "./toolSchemas.ts";

export const TOOLS: ToolDef[] = [
  {
    name: "forward_ledger",
    description:
      "توقّع يوم بيوم للأيام الجاية (SQL حتمي، مش تقدير، وبصفر كوتة): الرصيد المتوقع كل " +
      "يوم، أول يوم هيبقى فيه بالسالب، الالتزامات والاشتراكات اللي هتتخصم، والأصناف اللي " +
      "هتخلص وإمتى. **نادِها قبل أي رؤية عن المستقبل** — تحذير زي \"هتبقى ناقص\" أو " +
      "\"المية هتخلص\" لازم يكون رقمه من هنا مش من حسابك على الـsnapshot. اللي في " +
      "stock_unknown معدل استهلاكه لسه مش معروف — متخمّنش ليه تاريخ. stockouts بـconfidence=approximate " +
      "محسوبة من دورة شرا واحدة: قول التاريخ بـ«تقريباً» أو «على حسب آخر مرة»، مش كأنه أكيد.",
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
    name: "emit_insight",
    description: "سجّل رؤية أو تنبيه للعميل — يظهر في الصفحة الرئيسية أو الجرس أو بالصوت.",
    input_schema: {
      type: "object",
      properties: {
        kind: { type: "string", enum: ["insight", "alert"] },
        surface: { type: "string", enum: ["home_card", "bell", "voice"] },
        priority: { type: "string", enum: ["normal", "critical"] },
        title: { type: "string", description: "أقصى ٤٠ حرف" },
        body: { type: "string", description: "لازم يحتوي رقم محدد" },
        dedupe_key: { type: "string", description: "حروف صغيرة وأرقام و_ فقط" },
        about_item: { type: "string" },
        valid_until: {
          type: "string",
          description: "YYYY-MM-DD: آخر يوم الكارت ده صحيح فيه. لازم لأي كارت عن يوم معين (تجديد، قسط، ميعاد، «بكرة»، «النهارده») = اليوم ده نفسه؛ بعده الكارت بيختفي لوحده. سيبه فاضي للرؤية العامة.",
        },
      },
      required: ["title", "body", "dedupe_key"],
    },
  },
  {
    name: "ask_user",
    description: "اسأل العميل سؤال محدد له إجابة قابلة للتنفيذ (رقم/نعم-لا/صورة).",
    input_schema: {
      type: "object",
      properties: {
        title: { type: "string" },
        body: { type: "string" },
        dedupe_key: { type: "string" },
        answer_type: { type: "string", enum: ["number", "yes_no", "camera"] },
        about_item: { type: "string", description: "لازم يكون من stock_unknown في الـ snapshot" },
        surface: { type: "string", enum: ["home_card", "bell", "voice"] },
      },
      required: ["title", "body", "dedupe_key", "answer_type"],
    },
  },
  {
    "name": "family_mediation",
    "description": "وساطة عائلية ذكية: لو اتنين في العيلة صرفوا على نفس الحاجة في نفس الفترة، اكتشف التكرار واقترح تسوية عادلة (مين يرجّع لإيه ومقدار إيه). نادِها لما العميل يشكك في ازدواج صرف أو يطلب مراجعة مشتريات العيلة المتكررة.",
    "input_schema": {
      "type": "object",
      "properties": {
        "category_hint": { "type": "string", "description": "الفئة المشتبه فيها (اختياري — لو فاضي نفحص كل الفئات)" }
      }
    }
  },
  {
    name: "what_i_held_back",
    description:
      "اللي سكتّ عنه وليه (ZAD_PLAN ٣.٥): الرسايل اللي الحراس أجّلوها أو شالوها آخر [days] يوم (الكتم، النوم، " +
      "المسافة، سقف اليوم، ساعة الرد، التكرار، الكلام اللي قدم). نادِها لما العميل يسأل «إيه اللي ماقولتليش عليه؟» " +
      "أو «ليه مابعتليش…؟». قول النتيجة زي ما هي بلهجته، ومتألّفش رسالة ماتسجلتش.",
    input_schema: {
      type: "object",
      properties: { days: { type: "number", description: "كام يوم لورا (١–٣٠)، الافتراضي ٧" } },
    },
  },
  {
    name: "monthly_review",
    description:
      "جلسة مراجعة شهرية — ٥ دقايق صوتية آخر كل شهر. بيسأل العميل ٣ أسئلة ذكية عن قراراته المالية " +
      "(أكبر قرار، أكبر ندم، هدف الشهر الجاي)، وبيبني منها 'شخصية مالية' بتتحدث كل شهر " +
      "(مثلاً: منفق عاطفي، موفر حذر، مخاطر محسوبة). نادِها آخر ٥ أيام من الشهر أو لما العميل يطلب مراجعة.",
    input_schema: {
      type: "object",
      properties: {
        answers: {
          type: "object",
          description: "إجابات العميل على الأسئلة الثلاثة (لو متاحة) — أول نداء سيبه فاضي عشان ترجع الأسئلة",
          properties: {
            biggest_decision: { type: "string" },
            biggest_regret: { type: "string" },
            next_month_goal: { type: "string" },
          },
        },
      },
    },
  },
  {
    name: "salary_plan",
    description:
      "وضع الراتب وصل: أول ما يتسجل دخل كبير (راتب)، احسب خطة الشهر في ٣ نقاط: " +
      "١- الالتزامات الثابتة اللي جاية، ٢- المعدل اليومي الآمن بعد حجزها (نادِ safe_daily_spend وقول رقمها زي ما رجع — ماتحسبوش بنفسك)، ٣- أعلى فئة صرف لازم ينتبه لها. " +
      "نادِها تلقائياً لما تشوف معاملة income كبيرة (أكبر من متوسط الدخل) أو لما العميل يقول الراتب وصل.",
    input_schema: {
      type: "object",
      properties: {
        transaction_id: { type: "string", description: "معرف معاملة الراتب (لو متاح)" },
      },
    },
  },
  {
    name: "suggest_challenge",
    description:
      "اقترح تحدي توفير أسبوعي شخصي مبني على أكبر فئة صرف قابلة للتقليل (من بيانات العميل الحقيقية). " +
      "التحدي بيتخزن ويتتابع تلقائياً. نادِها لما العميل يقول عوز تحدي أو بعد خطة التوفير عشان يتحول لتحدي عملي.",
    input_schema: {
      type: "object",
      properties: {
        category: { type: "string", description: "الفئة المستهدفة (مثلاً: مطاعم، مشروبات)" },
        reduction_percent: { type: "number", description: "نسبة الخفض المقترحة (١٥-٤٠). افتراضي ٢٠" },
      },
      required: ["category"],
    },
  },
  {
    name: "remember",
    description: "سجّل درس/ملاحظة دائمة عن العميل لتستخدمها الجلسات الجاية.",
    input_schema: {
      type: "object",
      properties: {
        replaces_note_id: {
          type: "string",
          description:
            "استخدمها **بس** بعد ما remember ترجّعلك تعارض وتسأل العميل ويرد. حط فيها الـid " +
            "اللي رجع في رسالة التعارض. من غيرها الملاحظة المتناقضة مش هتتخزن.",
        },
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
    name: "link_memory",
    description:
      "اربط ملاحظتين موجودين في memory ببعض لما تلاحظ علاقة حقيقية بينهم. " +
      "استخدم الـid بتاع كل ملاحظة زي ما هو في memory. " +
      "leads_to = الأولى بتؤدي للتانية، co_occurs = بيحصلوا مع بعض، " +
      "explains = الأولى بتفسّر التانية، contradicts = بيناقضوا بعض. " +
      "اربط بس لما تكون العلاقة ظاهرة في البيانات، مش تخمين.",
    input_schema: {
      type: "object",
      properties: {
        from_id: { type: "string", description: "id ملاحظة من memory" },
        to_id: { type: "string", description: "id ملاحظة تانية من memory" },
        relation: { type: "string", enum: ["leads_to", "co_occurs", "explains", "contradicts"] },
        strength: { type: "number", description: "رقم بين 0 و1" },
      },
      required: ["from_id", "to_id", "relation"],
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
    name: "update_inventory_qty",
    description: "عدّل كمية صنف في المخزون — لازم سبب واضح. أو علّمه أساسي/على فترات بـrestock_mode.",
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
        reason: { type: "string", description: "على الأقل ١٠ حروف" },
      },
      required: ["item_name", "reason"],
    },
  },
  {
    name: "delete_inventory_item",
    description: "احذف صنفاً من المخزون نهائياً فقط لو العميل لا يريد تتبعه بعد الآن. لو الصنف خلص استخدم update_inventory_qty واجعل الكمية صفر.",
    input_schema: { type: "object", properties: { item_name: { type: "string" } }, required: ["item_name"] },
  },
  {
    name: "set_transaction_category",
    description: "صحّح تصنيف معاملة موجودة.",
    input_schema: {
      type: "object",
      properties: {
        transaction_id: { type: "string" },
        category: { type: "string", description: "لازم يكون من distinct_categories في الـ snapshot" },
        reason: { type: "string" },
      },
      required: ["transaction_id", "category", "reason"],
    },
  },
  {
    name: "suggest_budget_change",
    description: "اقترح تعديل الميزانية — لا يغيّرها مباشرة، العميل يأكد.",
    input_schema: {
      type: "object",
      properties: {
        new_budget: { type: "number" },
        reason: { type: "string" },
      },
      required: ["new_budget", "reason"],
    },
  },
  {
    name: "merge_duplicate_expense",
    description: "ادمج معاملتين مكررتين — يمسح drop_id ويحتفظ بـ keep_id.",
    input_schema: {
      type: "object",
      properties: {
        keep_id: { type: "string" },
        drop_id: { type: "string" },
      },
      required: ["keep_id", "drop_id"],
    },
  },
  {
    name: "reconcile_cash_balance",
    description: "بعد ما العميل يرد على سؤال تسوية الكاش الأسبوعي برقم، نادِ الأداة دي بالرقم اللي قاله — بتظبط الرصيد المحسوب من غير تفاصيل.",
    input_schema: {
      type: "object",
      properties: {
        reported_amount: { type: "number", description: "الرقم اللي العميل قاله — تقريبي، مفيش تفصيل مطلوب" },
      },
      required: ["reported_amount"],
    },
  },
  {
    name: "confirm_cycle_start",
    description: "بعد ما العميل يأكد بـ(أيوة) على سؤال دورة الراتب (cycle_start_confirm) — سجّل يوم بداية الدورة عشان كل حساب مالي يعتمد عليه بدل الشهر التقويمي.",
    input_schema: {
      type: "object",
      properties: {
        cycle_start_day: { type: "number", description: "لازم يكون بالظبط cycle_detection.suggested_day من الـ snapshot" },
      },
      required: ["cycle_start_day"],
    },
  },
  {
    name: "confirm_obligation",
    description: "بعد ما العميل يأكد بـ(أيوة) على سؤال التزام ثابت (obligation_detection) — سجّل الالتزام (إيجار/قسط/دين...) عشان يتحسب في رقم \"متاح\". لو obligation_detection.provider مضبوط (تابي/تمارة/فاليو) اسأل العميل كام قسط في الخطة قبل ما تنادي الأداة دي وابعت الرقم في total_installments — من غيره مش هينفع نربط دفعات الشهور الجاية بالخطة دي أوتوماتيك.",
    input_schema: {
      type: "object",
      properties: {
        kind: { type: "string", enum: ["rent", "installment", "debt", "tuition", "utility", "other"], description: "صنّف الالتزام حسب اسم التاجر ونص السؤال" },
        total_installments: { type: "number", description: "عدد أقساط خطة تابي/تمارة/فاليو لو العميل قاله. سيبها فاضية لو مش متأكد — متخترعش رقم." },
      },
      required: ["kind"],
    },
  },
];
