// مشاركة الرحلة مع العيلة (م٧.٦): العيلة بتشوف بس اللي المسافر وافق يشاركه.
// وده معناه: الحالة + اسم المدينة بس. مافيش إحداثيات (lat/lng) أبداً، ومافيش تتبع.
// أي حقل تاني في المدخل بيتشال، حتى لو جه بالغلط.
// دالة نقية: مافيش I/O.

export interface TripShareInput {
  consented: boolean;
  status?: string;
  city?: string;
  lat?: number;
  lng?: number;
  [k: string]: unknown;
}

export interface FamilyView {
  status: string;
  city: string;
}

/** لو المسافر ماوافقش ⇒ null (مافيش أي بيانات تتبعت للعيلة).
 * لو وافق ⇒ بس الحالة والمدينة، وغياب أي واحدة بيرجع "" مش undefined. */
export function familyView(i: TripShareInput): FamilyView | null {
  if (!i.consented) return null;
  return {
    status: i.status ?? "",
    city: i.city ?? "",
  };
}
