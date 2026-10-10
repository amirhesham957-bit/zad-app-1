// العقل يشوف الحملة اللي على الرئيسية وذوق الوصفات (campaigns.ts، §١١ح). الصفوف شكلها زي الحي (٢٠٢٦-١٠-١٠).
import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { campaignAndTasteRules, campaignWindowOn, type CampaignRow, pickHomeCampaign, recipeTaste } from "./campaigns.ts";
import { buildChatSystemPrompt } from "./index.ts";

let n = 0;
const row = (over: Partial<CampaignRow>): CampaignRow => ({
  id: `c${String(++n).padStart(2, "0")}`, event_key: "x", banner_title: "عنوان", banner_body: "نص", cta_text: "يلا", priority: 0,
  is_active: true, ...over,
});
const ROWS: CampaignRow[] = [
  row({ event_key: "autumn", from_md: "10-01", to_md: "10-31", priority: -10, banner_title: "خريف هادي لميزانيتك 🍂" }),
  row({ event_key: "autumn", dialect: "GULF", from_md: "10-01", to_md: "10-31", priority: -10, banner_title: "موسم هادي لميزانيتك 🍂" }),
  row({ event_key: "egypt_october_6", target_country: "EG", from_md: "10-04", to_md: "10-07", priority: 10, banner_title: "٦ أكتوبر" }),
  row({ event_key: "halloween", from_md: "10-25", to_md: "10-31", priority: 0, banner_title: "متخليش مصاريف البيت تخوّفك 🎃" }),
  row({ event_key: "new_year", from_md: "12-28", to_md: "01-03", priority: 0, banner_title: "سنة جديدة" }),
  row({ event_key: "ramadan", season_slug: "ramadan", priority: 20, banner_title: "رمضان كريم 🌙", event_name: "رمضان" }),
];
const SEASONS = [{ slug: "ramadan", start_date: "2027-02-08", end_date: "2027-03-09" }];

Deno.test("home campaign: the same pick as the app, for this country and dialect, today", () => {
  assertEquals(pickHomeCampaign(ROWS, SEASONS, "2026-10-10", "EG")?.title, "خريف هادي لميزانيتك 🍂");
  // السعودي ياخد نسخة الخليج (اللهجة الجارة) قبل العامة.
  assertEquals(pickHomeCampaign(ROWS, SEASONS, "2026-10-10", "SA")?.title, "موسم هادي لميزانيتك 🍂");
  // لهجة في الملف تغلب لهجة البلد.
  assertEquals(pickHomeCampaign(ROWS, SEASONS, "2026-10-10", "SA", "EG")?.title, "خريف هادي لميزانيتك 🍂");
  // أعلى أولوية: ٦ أكتوبر لمصر بس.
  assertEquals(pickHomeCampaign(ROWS, SEASONS, "2026-10-05", "EG")?.event, "egypt_october_6");
  assertEquals(pickHomeCampaign(ROWS, SEASONS, "2026-10-05", "SA")?.event, "autumn");
  assertEquals(pickHomeCampaign(ROWS, SEASONS, "2026-10-26", "EG")?.event, "halloween");
  // شباك بيلف السنة: ٢ يناير جزء من حملة بدأت ٢٨ ديسمبر اللي فات.
  assertEquals(pickHomeCampaign(ROWS, SEASONS, "2027-01-02", "EG")?.until, "2027-01-03");
  assertEquals(pickHomeCampaign(ROWS, SEASONS, "2027-01-04", "EG"), null);
  // موسم هجري من الشبابيك.
  const ramadan = pickHomeCampaign(ROWS, SEASONS, "2027-02-20", "EG");
  assertEquals([ramadan?.event, ramadan?.name, ramadan?.until], ["ramadan", "رمضان", "2027-03-09"]);
});

Deno.test("home campaign: ties, inactive rows and malformed windows behave as on the phone", () => {
  const a = row({ id: "b-later", from_md: "10-01", to_md: "10-31", banner_title: "B" });
  const b = row({ id: "a-first", from_md: "10-01", to_md: "10-31", banner_title: "A" });
  assertEquals(pickHomeCampaign([a, b], [], "2026-10-10", "EG")?.title, "A");
  // للبلد ده بالذات تغلب العامة بنفس الأولوية.
  const mine = row({ target_country: "EG", from_md: "10-01", to_md: "10-31", banner_title: "مصر" });
  assertEquals(pickHomeCampaign([b, mine], [], "2026-10-10", "EG")?.title, "مصر");
  assertEquals(pickHomeCampaign([row({ is_active: false, from_md: "10-01", to_md: "10-31" })], [], "2026-10-10", "EG"), null);
  // تاريخ وموسم مع بعض، أو ولا واحد = التطبيق بيرميه.
  assertEquals(campaignWindowOn(row({ from_md: "10-01", to_md: "10-31", season_slug: "ramadan" }), "2026-10-10", SEASONS), null);
  assertEquals(campaignWindowOn(row({}), "2026-10-10", SEASONS), null);
  // لهجة تانية خالص مش للعميل ده.
  assertEquals(pickHomeCampaign([row({ dialect: "MA", from_md: "10-01", to_md: "10-31" })], [], "2026-10-10", "EG"), null);
});

Deno.test("recipe taste: the latest likes and dislikes, each once", () => {
  assertEquals(recipeTaste([]), null);
  assertEquals(recipeTaste([
    { recipe_name: "كشري", liked: true }, { recipe_name: "ملوخية", liked: false },
    { recipe_name: "كشري", liked: true }, { recipe_name: " ", liked: true }, { recipe_name: "x", liked: null },
  ]), { liked: ["كشري"], disliked: ["ملوخية"] });
});

Deno.test("prompt: the campaign on screen and the taste, only when there are any", () => {
  assertEquals(campaignAndTasteRules({}), "");
  const prompt = buildChatSystemPrompt({
    home_campaign: { event: "autumn", name: null, title: "خريف هادي لميزانيتك 🍂", body: "x", cta: null, until: "2026-10-31" },
    recipe_taste: { liked: ["كشري"], disliked: ["ملوخية"] },
  });
  assertStringIncludes(prompt, "«خريف هادي لميزانيتك 🍂» لحد 2026-10-31");
  assertStringIncludes(prompt, "ماتناقضهاش");
  assertStringIncludes(prompt, "ماتقترحش أي حاجة في disliked");
  assert(!buildChatSystemPrompt({}).includes("home_campaign"));
});
