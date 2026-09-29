/**
 * إشعار شات العيلة — رسالة أو استغاثة توصل والتطبيق مقفول.
 *
 * تطبيق كوتلن كان عنده خدمة في الخلفية (ChatNotificationService) بتسمع الشات وتطلع إشعار،
 * واستغاثة (SOS) بقناة لوحدها. نسخة فلاتر كانت بتقرا الشات بس وهي مفتوحة على شاشة العيلة،
 * يعني «الرجاء الانتباه، حالة طوارئ!» من ابنك كانت ممكن ماتوصلش خالص. دلوقتي تريجر على
 * chat_messages بينادي zad-brain (family_message_push) وده بيبعت FCM لكل فرد غير اللي كتب.
 *
 * النص هنا بس — صافي عشان يتختبر.
 */

/** رسايل زاد نفسه في الشات (رد على «@زاد»، تكليف مهمة) — اللي سأل شايفها أصلاً. */
export const ZAD_SENDER_ID = "zad_ai";

export function familyPushText(m: {
  message_type?: string | null;
  message?: string | null;
  metadata?: string | null;
  sender_id?: string | null;
  alias: string;
}): { title: string; body: string } | null {
  if (m.sender_id === ZAD_SENDER_ID) return null;
  const text = (m.message ?? "").replace(/\s+/g, " ").trim();
  if (!text) return null;
  const body = text.length > 160 ? `${text.slice(0, 157)}…` : text;
  const who = m.alias.trim() || "حد من العيلة";
  switch (m.message_type) {
    case "SOS":
      return { title: `🚨 استغاثة من ${who}`, body };
    case "PURCHASE_REQUEST": {
      let allowance = false;
      try {
        allowance = JSON.parse(m.metadata ?? "{}")?.kind === "allowance";
      } catch { /* a request without readable metadata is a purchase */ }
      return { title: allowance ? `${who} طالب مصروف` : `${who} عايز يشتري حاجة`, body };
    }
    case "POLL":
      return { title: `${who} عمل تصويت في العيلة`, body };
    default:
      return { title: `${who} في شات العيلة`, body };
  }
}
