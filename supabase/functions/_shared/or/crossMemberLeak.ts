// مقياس الخصوصية (م٨.٦): صفر رسالة لفرد فيها محتوى فرد تاني ما وافقش يشاركه.
// consent[memberId] === true فقط لو الفرد وافق يشارك محتواه. أي حد مش موجود في الخريطة يُعامَل كغير موافق (fail closed).
// محتوى الفرد نفسه مش تسريب. دالة نقية: مافيش I/O.
// ومن P2.5: isMatrixLeak وfindMatrixLeaks (آخر الملف) بيقروا مصفوفة الرؤية (visibilityMatrix.ts) بدل خريطة موافقة مسطحة.

import { canSee, type Consent, type Domain, type Person, type Subject } from "./visibilityMatrix.ts";

export interface OutgoingMessage {
  toMemberId: string;
  text: string;
  sourceMemberIds: readonly string[];
}

export type ConsentMap = Readonly<Record<string, boolean | undefined>>;

/** True لو الرسالة فيها محتوى فرد تاني (غير المستلم) ما وافقش يشاركه. */
export function isCrossMemberLeak(message: OutgoingMessage, consent: ConsentMap): boolean {
  return message.sourceMemberIds.some(
    (source) => source !== message.toMemberId && consent[source] !== true,
  );
}

/** الرسايل المتسرّبة. المقياس = طول المصفوفة الناتجة، والمستهدف 0. */
export function findCrossMemberLeaks(
  messages: readonly OutgoingMessage[],
  consent: ConsentMap,
): OutgoingMessage[] {
  return messages.filter((message) => isCrossMemberLeak(message, consent));
}

export interface MatrixSource {
  subject: Subject;
  domain: Domain;
}

export interface MatrixMessage {
  to: Person;
  text: string;
  sources: readonly MatrixSource[];
  /** موافقات كل صاحب بيانات (بمعرّفه). الناقص = غير موافق. */
  consentBy?: Readonly<Record<string, Consent>>;
}

/** تسريب = أي مصدر المستلم مش مسموح له يشوفه حسب المصفوفة (القاصر مصفوفته أضيق: مهامه وأهدافه بس). */
export function isMatrixLeak(message: MatrixMessage): boolean {
  return message.sources.some((s) => !canSee(message.to, s.subject, s.domain, message.consentBy?.[s.subject.id] ?? {}));
}

export function findMatrixLeaks(messages: readonly MatrixMessage[]): MatrixMessage[] {
  return messages.filter(isMatrixLeak);
}
