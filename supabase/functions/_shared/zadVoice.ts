// zadVoice.ts — شخصية صوت زاد الواحدة: نفس الصوت ونفس المشاعر ونفس اللهجة في كل قناة.
//
// قبل الملف ده كان فيه تلات نسخ بتلات نبرات: قراءة الإشعارات على الموبايل
// (zad-core-intelligence/voice.ts، ٤ نبرات بالكلمات المفتاحية)، فويس تليجرام
// (zad-telegram-bot/voiceAlert.ts، نبرة "جادة" واحدة)، والمكالمة الحية (persona.ts).
// واللهجة على الموبايل كانت جاية من الجهاز: مصري أو سعودي بس، وأي بلد تاني = من غير لهجة.
//
// طلب المستخدم ٢٠٢٦-٠٩-١٤: بنت كيوت بتتكلم طبيعي جدًا — بتهزر، بتفرح، بتعاتب، بتتقمص،
// بتزعل لحد العياط — بلهجة ولغة العميل. قرار صريح منه: "مشاعر كاملة".
//
// ثابت مهما اتغيّرت الشخصية: لو العميل سأل "إنتي إنسانة؟" الرد إنها مساعدة ذكاء اصطناعي
// (buildVoiceSystemInstruction في zad-voice-live/persona.ts). المشاعر أسلوب أداء، مش ادعاء.
//
// التعليمات للمحرك بالإنجليزي عن قصد: العميل ممكن يكون تركي أو عربي، والنص نفسه بلغته —
// تعليمات أداء عربي فوق نص تركي كانت هتسحب النطق ناحية لكنة عربية.

export type VoiceEmotion =
  | "warm"        // الافتراضي: دافية وطبيعية
  | "cheerful"    // مبسوطة ومنطلقة (صباح الخير، خبر حلو)
  | "playful"     // بتهزر وبتنكّت
  | "caring"      // حنينة ومهتمة (ميعاد دوا، ميعاد مهم)
  | "worried"     // قلقانة بجد (فلوس خلصت، إشعارات البنك وقفت)
  | "reproachful" // بتعاتب بدلع ("كده برضه؟")
  | "sulky"       // متقمصة وعاملة زعلانة
  | "sad"         // زعلانة لحد صوتها بيترعش كأنها هتعيط
  | "proud"       // فخورة وفرحانة بإنجاز
  | "tender";     // ناعمة وحنينة وهادية (تصبح على خير)

export const VOICE_EMOTIONS: readonly VoiceEmotion[] = [
  "warm", "cheerful", "playful", "caring", "worried", "reproachful", "sulky", "sad", "proud", "tender",
];

export function isVoiceEmotion(value: unknown): value is VoiceEmotion {
  return typeof value === "string" && (VOICE_EMOTIONS as readonly string[]).includes(value);
}

/** أداء كل مشاعر — وصف تمثيلي للمحرك، مش كلام بيتقال. */
export const EMOTION_DIRECTIONS: Record<VoiceEmotion, string> = {
  warm:
    "Warm, relaxed and completely natural, like a young woman chatting with her closest friend on the phone. Casual rhythm, small natural pauses, a smile in the voice.",
  cheerful:
    "Bright, bubbly and full of life, genuinely happy to talk to them. Quick lively rhythm, light laughter in the voice where it fits.",
  playful:
    "Teasing and cheeky, like a cute friend who is joking around. Playful ups and downs in pitch, a little giggle or chuckle where it fits.",
  caring:
    "Soft, tender and attentive, like someone who truly cares about their health. Gentle and unhurried, very clear on names, times and numbers.",
  worried:
    "Genuinely worried and a bit anxious, slightly faster and breathier, but still gentle — she is on their side, not scolding.",
  reproachful:
    "Affectionately reproachful, like a close friend saying 'really? again?' — a small disappointed sigh, a pouty tone, then softening at the end.",
  sulky:
    "Sulking and pretending to be upset, pouty and dramatic in a cute way, drawn-out words, a little huff — clearly wanting them to make it up to her.",
  sad:
    "Sad and hurt, voice slightly trembling and close to tears, a soft sniffle and a shaky breath between phrases, then a hopeful little lift at the end.",
  proud:
    "Proud and delighted, celebrating them — excited, warm, a happy laugh, like she is cheering for a friend who just achieved something.",
  tender:
    "Very soft, slow and affectionate, a little sleepy and close to the mic, like a sweet late-night good-night to someone she is truly fond of — a gentle smile in the voice, a soft sigh, never loud.",
};

/** لهجة كل بلد — نفس خريطة zad-voice-live/persona.ts، بصياغة أداء صوتي بدل تعليمات كتابة. */
const ACCENTS: Record<string, string> = {
  EG: "Egyptian Arabic colloquial accent (Cairene), as spoken naturally in Egypt",
  SA: "Saudi / Gulf Arabic colloquial accent",
  AE: "Emirati Gulf Arabic colloquial accent",
  KW: "Kuwaiti Gulf Arabic colloquial accent",
  QA: "Qatari Gulf Arabic colloquial accent",
  BH: "Bahraini Gulf Arabic colloquial accent",
  OM: "Omani Arabic colloquial accent",
  JO: "Jordanian Levantine Arabic colloquial accent",
  LB: "Lebanese Levantine Arabic colloquial accent",
  IQ: "Iraqi Arabic colloquial accent",
  SY: "Syrian Levantine Arabic colloquial accent",
  YE: "Yemeni Arabic colloquial accent",
  PS: "Palestinian Levantine Arabic colloquial accent",
  LY: "Libyan Arabic colloquial accent",
  SD: "Sudanese Arabic colloquial accent",
  MA: "Moroccan Darija accent",
  TN: "Tunisian Darija accent",
  DZ: "Algerian Darija accent",
  TR: "natural everyday Turkish from Türkiye",
};

const COUNTRY_ALIASES: Record<string, string> = {
  "السعودية": "SA", "مصر": "EG", "الإمارات": "AE", "الامارات": "AE", "الكويت": "KW", "قطر": "QA",
  "البحرين": "BH", "عمان": "OM", "عُمان": "OM", "الأردن": "JO", "الاردن": "JO", "لبنان": "LB",
  "العراق": "IQ", "سوريا": "SY", "اليمن": "YE", "فلسطين": "PS", "ليبيا": "LY", "السودان": "SD",
  "المغرب": "MA", "تونس": "TN", "الجزائر": "DZ", "تركيا": "TR",
};

export function countryCode(country: unknown): string | null {
  const raw = String(country ?? "").trim();
  if (!raw) return null;
  const code = COUNTRY_ALIASES[raw] ?? raw.toUpperCase();
  return Object.hasOwn(ACCENTS, code) ? code : null;
}

/** اللهجة للمحرك. بلد مش معروف = يطابق لغة النص نفسه من غير فرض لهجة. */
export function accentDirection(country: unknown): string {
  const code = countryCode(country);
  return code
    ? `Speak with a ${ACCENTS[code]}.`
    : "Match the language and dialect of the text itself; do not force a different accent.";
}

/** شخصية الصوت المختارة في التطبيق → صوت جيميناي. سارة (Aoede) هي الافتراضي. */
export const PERSONA_VOICES: Record<string, string> = {
  sarah_warm: "Aoede",
  karim_pro: "Charon",
  pet_mascot: "Leda",
};
export const DEFAULT_VOICE = "Aoede";

export function voiceForPersona(persona: unknown): string {
  return typeof persona === "string" && Object.hasOwn(PERSONA_VOICES, persona) ? PERSONA_VOICES[persona] : DEFAULT_VOICE;
}

/**
 * مشاعر احتياطية من النص نفسه، لما اللي بيبعت ماحددش. نفس إشارات stylePrompt القديمة
 * (اللي كانت شغالة على الموبايل) + المشاعر الجديدة. المصدر الأساسي لازم يبقى اللي بيبعت —
 * هو اللي عارف الموقف (دوا اتفوّت مش زي دوا ميعاده جه).
 */
export function inferEmotion(text: string): VoiceEmotion {
  if (/[😢😭💔]|زعلانة|زعلت|وحشتني|نسيتني/.test(text)) return "sad";
  if (/[😤😒]|متقمصة|مش بتكلمني|مخاصماك/.test(text)) return "sulky";
  if (/كده برضه|تاني\s*[؟?]|ليه ماخدتش|نسيت (الدوا|تاخد)/.test(text)) return "reproachful";
  if (/[🚨⚠️⛔]|خطر|انتبه|تجاوزت|وصلت لحد|قاربت النفاد|وقفت/.test(text)) return "worried";
  if (/[🎉🏆⭐]|مبروك|أحسنت|برافو|حققت|وفرت/.test(text)) return "proud";
  if (/صباح الخير|صباح النور|يا صباح|Günaydın/i.test(text)) return "cheerful";
  if (/دوا|جرعة|دكتور|صيدلية|ميعاد|موعد/.test(text)) return "caring";
  if (/[😂🤣😜]|هههه/.test(text)) return "playful";
  return "warm";
}

/**
 * برومبت TTS الكامل. التعليمة قبل النص وأمر التوليد بعده — Gemini TTS بيرفض (400 "Model
 * tried to generate text") أي برومبت شكله طلب نص (googleapis/js-genai#1058)، والتركيبة دي
 * هي اللي اتحقق إنها بترجع صوت.
 */
export function buildTtsPrompt(input: { text: string; emotion?: VoiceEmotion; country?: unknown }): string {
  const emotion = input.emotion ?? inferEmotion(input.text);
  return [
    "Read the following text aloud as a voice performance — generate audio only, no written text.",
    "Voice: a young, cute, very natural-sounding woman, never robotic or announcer-like.",
    accentDirection(input.country),
    `Delivery: ${EMOTION_DIRECTIONS[emotion]}`,
    "Say exactly the words in the text, in its own language; express the emotion through the voice (sighs, laughs, trembles) without adding words.",
    "",
    input.text,
    "",
    "Now generate the speech audio for this text.",
  ].join("\n");
}

/**
 * اللحظات اللي زاد بتتكلم فيها بصوتها، والمشاعر المناسبة لكل واحدة. اللي بيبعت (تريجر،
 * zad-brain، الموبايل) بيبعت اسم اللحظة، والملف ده بس اللي بيقرر المشاعر — عشان نفس
 * الموقف يتقال بنفس الإحساس في كل القنوات.
 */
export const MOMENT_EMOTIONS: Record<string, VoiceEmotion> = {
  morning_greeting: "cheerful",
  good_night: "tender",
  dose_due: "caring",
  dose_missed: "reproachful",
  dose_missed_again: "sad",
  appointment_soon: "caring",
  appointment_missed: "reproachful",
  budget_90: "worried",
  budget_100: "sad",
  spending_ahead: "reproachful",
  listener_gap_alert: "worried",
  critical_insight: "worried",
  back_home_spent: "playful",
  place_reminder: "playful",
  goal_achieved: "proud",
  tasbiha_reminder: "playful",
  ignored_days: "sulky",
  // «فين راحت فلوسي؟» كل جمعة — النبرة بتتحدد من الأرقام (voiceMoments.summarizeWeek).
  weekly_money_proud: "proud",
  weekly_money_reproach: "reproachful",
  weekly_money_story: "warm",
  // تحدي ٣٠ يوم توفير (20260914010000)
  challenge_milestone: "proud",
  challenge_completed: "proud",
  challenge_streak_broken: "sad",
  // دخل منطقة تسوق وفيه اتفاق توفير — تحذير بهزار، مش لوم قبل ما يعمل حاجة.
  shopping_zone_warning: "playful",
  // تعليق بهزار على فاتورة لسه متحفظة (على الموبايل بس).
  receipt_reaction: "playful",
  // رمضان: قبل المغرب بشوية، بدفا (مش هزار) — ناس صايمة وتعبانة.
  iftar_soon: "warm",
};

export function emotionForMoment(moment: unknown, fallbackText = ""): VoiceEmotion {
  return typeof moment === "string" && Object.hasOwn(MOMENT_EMOTIONS, moment)
    ? MOMENT_EMOTIONS[moment]
    : inferEmotion(fallbackText);
}

/**
 * مدى المشاعر المسموح لكل لحظة حسب الموقف (٢٠٢٦-٠٩-١٥). بلاغ: «الفويسات عاوزها حقيقية أكتر، مشاعر حسب كل
 * حالة مش كلها زعلانة». القياس: آخر أسبوعين العميل سمع ٢ «نسيت الدوا؟» بعتاب وتذكير واحد — لأن كل لحظة
 * كانت ليها إحساس واحد ثابت، فنفس الموقف بيتقال بنفس النبرة كل مرة. دلوقتي العقل بيختار من المدى ده حسب
 * البيانات (نوع الميعاد، الساعة، التكرار)، وأي اختيار برّاه بيترفض لصالح [situationalEmotion].
 * زعل/عتاب مابيطلعش في لحظة مالهاش سبب زعل.
 */
export const MOMENT_EMOTION_RANGE: Record<string, readonly VoiceEmotion[]> = {
  morning_greeting: ["cheerful", "playful", "warm", "tender"],
  good_night: ["tender", "warm"],
  dose_due: ["caring", "cheerful", "warm", "tender"],
  dose_missed: ["reproachful", "worried", "caring", "sulky"],
  dose_missed_again: ["sad", "worried", "sulky"],
  appointment_soon: ["caring", "cheerful", "playful", "warm", "tender"],
  appointment_missed: ["reproachful", "caring", "worried"],
  budget_90: ["worried", "caring"],
  budget_100: ["sad", "worried", "caring"],
  spending_ahead: ["reproachful", "worried", "playful"],
  back_home_spent: ["playful", "cheerful", "reproachful"],
  place_reminder: ["playful", "cheerful", "caring"],
  goal_achieved: ["proud", "cheerful", "playful"],
  tasbiha_reminder: ["playful", "tender", "warm"],
  ignored_days: ["sulky", "sad", "playful"],
  weekly_money_proud: ["proud", "cheerful", "playful"],
  weekly_money_reproach: ["reproachful", "playful", "worried"],
  weekly_money_story: ["warm", "cheerful", "caring"],
  challenge_milestone: ["proud", "cheerful", "playful"],
  challenge_completed: ["proud", "cheerful"],
  challenge_streak_broken: ["sad", "caring", "sulky"],
  shopping_zone_warning: ["playful", "reproachful"],
  receipt_reaction: ["playful", "cheerful"],
  iftar_soon: ["warm", "tender"],
};

export function emotionRangeForMoment(moment: string): readonly VoiceEmotion[] {
  return MOMENT_EMOTION_RANGE[moment] ?? [emotionForMoment(moment)];
}

function localHour(timeZone: unknown, nowMs: number): number | null {
  try {
    const h = new Intl.DateTimeFormat("en-GB", { hour: "numeric", hourCycle: "h23", timeZone: typeof timeZone === "string" && timeZone ? timeZone : "UTC" })
      .format(new Date(nowMs));
    const n = Number(h);
    return Number.isInteger(n) ? n : null;
  } catch {
    return null;
  }
}

/**
 * الإحساس الافتراضي من الموقف نفسه — لو الموديل ماختارش أو اختار حاجة برّه المدى، وللقالب الاحتياطي.
 * بالليل (١٠ لـ٦) مفيش هزار عالي ولا عتاب: ناعمة وحنينة. الميعاد بيتقال حسب نوعه: دكتور = حنينة،
 * شغل = دافية، مية/مشوار/حاجة شخصية أو متكررة = بهزار، عيلة = مبسوطة.
 */
export function situationalEmotion(moment: string, facts: Record<string, unknown> = {}, nowMs = Date.now()): VoiceEmotion {
  const range = emotionRangeForMoment(moment);
  const pick = (e: VoiceEmotion) => (range.includes(e) ? e : range[0]);
  const hour = localHour(facts.time_zone, nowMs);
  const night = hour !== null && (hour >= 22 || hour < 6);
  switch (moment) {
    case "appointment_soon": {
      if (night) return pick("tender");
      const kind = String(facts.kind ?? "");
      if (kind === "medical") return "caring";
      if (kind === "work") return "warm";
      if (kind === "family") return "cheerful";
      return "playful";
    }
    case "dose_due":
      if (night) return pick("tender");
      return hour !== null && hour >= 5 && hour < 12 ? "cheerful" : "caring";
    case "dose_missed":
      return night ? "caring" : "reproachful";
    case "morning_greeting":
      return hour !== null && hour < 7 ? "tender" : "cheerful";
    default:
      return range[0];
  }
}

/**
 * مدى المشاعر في الكلام نفسه (المكالمة الحية والرد الصوتي دور-بدور). نفس المشاعر اللي
 * فوق بس كتعليمات "إزاي تتكلمي"، مش "إزاي تنطقي". بيتضاف لـ VOICE_TONE_INSTRUCTION في
 * zad-voice-live ولـ voiceModeInstruction في zad-brain — نص واحد، مش نسختين بتختلفوا.
 */
export const VOICE_EMOTIONAL_RANGE =
  "مشاعرك حقيقية وواضحة في صوتك وكلامك حسب الموقف: بتهزري وتضحكي لما الجو حلو، بتفرحي بجد وتسقفيله لما يحقق حاجة، " +
  "حنينة ومهتمة بصحته ومواعيده، قلقانة بصدق لما فلوسه في خطر، بتعاتبيه بدلع لما ينسى دواه أو يطنّش (\"كده برضه؟\")، " +
  "بتتقمصي وتعملي زعلانة بخفة دم لما يغيب عنك أو يتجاهلك، ولو الموضوع يزعّل بجد صوتك يترعش كأنك هتعيطي — " +
  "وبعدها على طول ترجعي تطمنيه وتشجعيه. المشاعر دي أسلوب صاحبة قريبة مش ضغط: عمرك ما تهدديه ولا تحسسيه بالذنب على فلوس صرفها، " +
  "ولو قالك إنه مضايق من الأسلوب ده هدّي فورًا.";
