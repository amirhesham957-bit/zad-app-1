// كتابة ترشيحات تيك توك وإنستجرام (zad-core-intelligence/socialPicks.ts) في zad_social_picks (طلب المالك ١٠/١١).

import { productNameKey } from "./productIdentity.ts";

const KINDS = new Set(["offer", "recipe", "idea", "restaurant", "supermarket", "delivery"]);

/** صفوف الجدول من رد القراية: الصالح بس، رابط https، ونوع معروف. نقي. */
export function socialPickRows(
  target: { country: string; store: string },
  picks: unknown,
  platform: "tiktok" | "instagram" | "youtube",
): Array<Record<string, unknown>> {
  if (!Array.isArray(picks)) return [];
  const rows: Array<Record<string, unknown>> = [];
  for (const p of picks as Array<Record<string, unknown>>) {
    const url = typeof p?.source_url === "string" ? p.source_url : "";
    const title = typeof p?.title === "string" ? p.title.trim().slice(0, 60) : "";
    if (!/^https:\/\//.test(url) || url.length > 300 || title.length < 3 || !KINDS.has(String(p.kind))) continue;
    const pct = Number(p.discount_percent);
    const likes = Number(p.likes);
    const posted = typeof p.posted_at === "string" && Number.isFinite(Date.parse(p.posted_at)) ? p.posted_at : null;
    rows.push({
      source_url: url,
      platform,
      kind: p.kind,
      country: target.country,
      store: target.store.slice(0, 60),
      store_key: productNameKey(target.store).slice(0, 80),
      title,
      summary: typeof p.summary === "string" ? p.summary.trim().slice(0, 200) : "",
      discount_percent: Number.isFinite(pct) && pct >= 1 && pct <= 90 ? Math.round(pct) : null,
      likes: Number.isFinite(likes) && likes >= 0 ? Math.round(likes) : null,
      posted_at: posted,
    });
  }
  return rows;
}
