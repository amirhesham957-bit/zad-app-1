// مقياس الخصوصية (م٨.٦): صفر رسالة لفرد فيها محتوى فرد تاني ما وافقش يشاركه.
// consent[memberId] === true فقط لو الفرد وافق يشارك محتواه. أي حد مش موجود في الخريطة يُعامَل كغير موافق (fail closed).
// محتوى الفرد نفسه مش تسريب. دالة نقية: مافيش I/O.

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
