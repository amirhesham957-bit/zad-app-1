// رابط إنستجرام في رد الشات بيفضل بس لو احنا اللي جايبينه (videoLinks.ts، بلاغ المالك ١٠/١١: «مفيش لينكات من إنستا»).
// «جايبينه» = متخزن برابطه في جدول من جداول المصادر: العروض، الأكواد، أو ترشيحات السوشيال.

import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";

const TABLES = ["zad_social_picks", "zad_deals", "zad_deal_codes"] as const;

/** الرابط بالشرطة اللي في الآخر ومن غيرها: Graph API بيرجّعه بشرطة، والموديل ساعات بيشيلها. نقي. */
export function linkForms(url: string): string[] {
  const bare = url.trim().replace(/\/+$/, "");
  return [bare, `${bare}/`];
}

export function knownLinkCheck(sb: SupabaseClient): (url: string) => Promise<boolean> {
  return async (url) => {
    const forms = linkForms(url);
    for (const table of TABLES) {
      const { data, error } = await sb.from(table).select("source_url").in("source_url", forms).limit(1);
      if (!error && (data?.length ?? 0) > 0) return true;
    }
    return false;
  };
}
