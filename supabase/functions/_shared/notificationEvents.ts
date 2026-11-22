// م٦.٤: تصنيف واستخراج أحداث الإشعارات (حجز دكتور ← appointment، طيران ← trip، أبشر/خدمة حكومية ← document_due).
// دالة صافية: بتاخد نص الإشعار وبترجّع حقول منظّمة بس (title ثابت من عندنا، date، time، place). النص الخام مابيرجعش
// ولا بيتكتب في أي مكان. اللي بيندّه هو اللي بيتأكد إن مفتاح المستخدم لنوعه شغّال قبل ما يندّه أصلاً.

export type NotificationEventKind = "appointment" | "trip" | "document_due";
export const NOTIFICATION_EVENT_KINDS: readonly NotificationEventKind[] = ["appointment", "trip", "document_due"];

export interface NotificationEventFields {
  /** عنوان ثابت من عندنا (مش من النص). */
  title: string;
  /** YYYY-MM-DD أو null. */
  date: string | null;
  /** HH:MM (٢٤ ساعة) أو null. */
  time: string | null;
  /** اسم مكان قصير (عيادة/مستشفى/وجهة) أو null. */
  place: string | null;
}
export interface NotificationEvent {
  kind: NotificationEventKind;
  fields: NotificationEventFields;
}

const AR_DIGITS = "٠١٢٣٤٥٦٧٨٩";
const FA_DIGITS = "۰۱۲۳۴۵۶۷۸۹";
function latinDigits(s: string): string {
  return s.replace(/[٠-٩۰-۹]/g, (d) => String(AR_DIGITS.includes(d) ? AR_DIGITS.indexOf(d) : FA_DIGITS.indexOf(d)));
}

// رسالة فلوس/OTP مش حدث حياة، حتى لو فيها كلمة «حجز».
const MONEY_OR_OTP = /(رمز\s*(?:التحقق|الدخول)|otp|verification code|تم\s*(?:خصم|إيداع|تحويل)|debited|credited|purchase of|رصيدك)/i;

const BOOKING = /(حجز|حجزك|موعدك|موعد|تأكيد|appointment|booking|booked|confirmed|scheduled)/i;
const MEDICAL = /(دكتور|دكتورة|د\.|عيادة|مستشفى|طبيب|صحتي|clinic|hospital|doctor|\bdr\.?\s|seha|mawid)/i;

const FLIGHT = /(رحلة|رحلتك|طيران|الخطوط|flight|airline|airways|saudia|flynas|flyadeal|egyptair|air arabia|nesma|riyadh air)/i;
const TRIP_BOOKING = /(حجز|تأكيد|تذكرة|بطاقة صعود|الإقلاع|boarding|e-?ticket|confirmed|itinerary|departs?|departure|check-?in)/i;

const GOV = /(أبشر|ابشر|absher|المرور|الجوازات|جوازات|الأحوال المدنية|السجل المدني|مقيم|توكلنا|passport|iqama)/i;
const DOC = /(إقامة|اقامة|هوية|رخصة|استمارة|جواز|بطاقة الرقم القومي|iqama|license|licence|passport|id card|registration)/i;
const DUE = /(تنتهي|ينتهي|انتهاء|انتهت|تجديد|مستحق|مستحقة|سداد|متأخر|expires?|expiry|expiring|renew|due|overdue)/i;

function docTitle(t: string): string {
  if (/(إقامة|اقامة|iqama)/i.test(t)) return "تجديد الإقامة";
  if (/(رخصة|license|licence)/i.test(t)) return "تجديد الرخصة";
  if (/(استمارة|registration)/i.test(t)) return "تجديد الاستمارة";
  if (/(جواز|passport)/i.test(t)) return "تجديد الجواز";
  if (/(هوية|الرقم القومي|id card)/i.test(t)) return "تجديد الهوية";
  return "خدمة حكومية مستحقة";
}

const pad = (n: number) => String(n).padStart(2, "0");
function validDay(y: number, m: number, d: number): string | null {
  if (y < 2000 || y > 2100 || m < 1 || m > 12 || d < 1 || d > 31) return null;
  const dt = new Date(Date.UTC(y, m - 1, d));
  if (dt.getUTCFullYear() !== y || dt.getUTCMonth() !== m - 1 || dt.getUTCDate() !== d) return null;
  return `${y}-${pad(m)}-${pad(d)}`;
}

/** تاريخ ميلادي بصيغة YYYY-MM-DD أو D/M/YYYY (اليوم الأول). الهجري (سنة < ٢٠٠٠) بيتسيب null. */
export function extractDate(text: string): string | null {
  const t = latinDigits(text);
  const iso = t.match(/\b(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})\b/);
  if (iso) return validDay(+iso[1], +iso[2], +iso[3]);
  const dmy = t.match(/\b(\d{1,2})[-/.](\d{1,2})[-/.](\d{4})\b/);
  if (dmy) return validDay(+dmy[3], +dmy[2], +dmy[1]);
  return null;
}

/** وقت HH:MM (٢٤ ساعة)، مع دعم ص/م وAM/PM. */
export function extractTime(text: string): string | null {
  const t = latinDigits(text);
  const m = t.match(/(?<![\d/:.-])(\d{1,2}):(\d{2})\s*(ص|م|am|pm|صباحا|صباحاً|مساء|مساءً|مساءا)?(?![\d/])/i);
  if (!m) return null;
  let h = +m[1];
  const mi = +m[2];
  if (mi > 59 || h > 23) return null;
  const mer = (m[3] ?? "").toLowerCase();
  if (mer) {
    const pm = mer === "م" || mer === "pm" || mer.startsWith("مساء");
    if (h < 1 || h > 12) return null;
    if (pm && h < 12) h += 12;
    if (!pm && h === 12) h = 0;
  }
  return `${pad(h)}:${pad(mi)}`;
}

const PLACE_STOP = /\s+(?:يوم|الساعة|الساعه|في|على|بتاريخ|at|on|departs?|departing|for|with)(?:\s.*)?$/iu;
function tidy(s: string): string | null {
  const v = s.replace(PLACE_STOP, "").replace(/[0-9٠-٩۰-۹]{3,}/g, " ").replace(/[^\p{L}\p{N} .'-]/gu, " ").replace(/\s+/g, " ").trim();
  return v.length >= 2 && v.length <= 40 ? v : null;
}

function extractPlace(kind: NotificationEventKind, text: string): string | null {
  if (kind === "appointment") {
    const m = text.match(/(?:عيادة|مستشفى|مركز|clinic|hospital|center|centre)\s+([\p{L}][\p{L}'.-]*(?:\s+[\p{L}][\p{L}'.-]*){0,2})/iu);
    return m ? tidy(m[0]) : null;
  }
  if (kind === "trip") {
    const m = text.match(/(?:إلى|الى|\bto\b)\s+([\p{L}][\p{L}'.-]*(?:\s+[\p{L}][\p{L}'.-]*)?)/iu);
    return m ? tidy(m[1]) : null;
  }
  return null;
}

/** يصنّف إشعار ويطلّع حقوله، أو null لو مش حدث من التلاتة. */
export function classifyNotificationEvent(title: string, text: string): NotificationEvent | null {
  const all = `${title}\n${text}`;
  if (MONEY_OR_OTP.test(all)) return null;
  let kind: NotificationEventKind | null = null;
  let label = "";
  if (GOV.test(all) && DOC.test(all) && DUE.test(all)) {
    kind = "document_due";
    label = docTitle(all);
  } else if (FLIGHT.test(all) && TRIP_BOOKING.test(all)) {
    kind = "trip";
    label = "رحلة طيران";
  } else if (BOOKING.test(all) && MEDICAL.test(all)) {
    kind = "appointment";
    label = "موعد دكتور";
  }
  if (!kind) return null;
  return { kind, fields: { title: label, date: extractDate(all), time: extractTime(all), place: extractPlace(kind, all) } };
}
