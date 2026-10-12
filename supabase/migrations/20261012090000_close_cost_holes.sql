-- ── ثلاث ثغرات تكلفة في السيرفر (فحص ما قبل الإطلاق ٢٠٢٦-١٠-١٢، الخطوة الأولى) ─────────────
--
-- ١. zad_set_tier كانت بترجّع رصيد الشهر كامل في **كل** نداء. verify-purchase بيناديها كل ما
--    التطبيق يبعت توكن صحيح — نفس التوكن مرة واتنين وعشرة — فمشترك الأساسية كان ياخد ٣٠٠ محاولة
--    جديدة مع كل نداء. دلوقتي الرصيد بيتجدد بس لما فيه فلوس جديدة فعلاً:
--      * باقة أعلى من الحالية (شراء جديد أو ترقية)،
--      * أو نفس الباقة بتاريخ انتهاء أبعد من المتخزّن (تجديد من جوجل)،
--      * أو النزول للمجاني من باقة مدفوعة.
--    نفس التوكن بنفس التاريخ = تحديث صامت من غير رصيد. وباقة أقل والأعلى لسه شغالة (اشتراكين
--    متوازيين) = الأعلى بتفضل، و'applied': false عشان verify-purchase مايكتبش توكن الأقل فوقها.
--    وكمان: النزول للمجاني كان بيحط دورة شهر، فالعميل مايتجددلوش رصيد ٣٠ يوم. دلوقتي ٥ ساعات زي
--    zad_entitlement_refresh.
--
-- ٢. zad-core-intelligence (المسح والصوت) ماكانتش بتخصم ولا بتعدّ. الفنكشن بقت بتنادي
--    zad_entitlement_consume للمسح (محاولتين) وللصوت (سعره من zad_tiers.voice_monthly، مجاني
--    دلوقتي بقرار المالك ٢٠٢٦-٠٩-١٤)، وده اللي بيلزمها هنا:
--      * zad_entitlement_refund: مسح رجع فاضي (صورة مش مقروءة، الموديل ماردّش) بيرجّع اللي اتخصم.
--      * zad_rate_take: حد في الدقيقة وفي اليوم لكل عميل ولكل نوع، عشان سكريبت واحد مايخلّصش
--        مفاتيح Gemini المشتركة على كل الناس.
--
-- ٣. zad_ad_reward_grant و zad_media_pass_grant كانوا مفتوحين لأي مستخدم مسجّل (authenticated)،
--    فأي حد يقدر يناديهم من غير ما يشوف إعلان: ٧٥ محاولة في اليوم + ٢٤ ساعة مسح وصوت ببلاش.
--    المنحة دلوقتي من admob-ssv بس (service_role)، بعد ما توقيع جوجل يتأكد. التطبيق مابيناديهمش
--    (مفيش google_mobile_ads لسه)، فمفيش حاجة شغالة بتقع.

-- ── ١. zad_set_tier ───────────────────────────────────────────────────────────────────────────
create or replace function public.zad_set_tier(p_user uuid, p_tier text, p_expires timestamptz default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  e public.zad_entitlements;
  t public.zad_tiers;
  t_old public.zad_tiers;
  v_fresh boolean;
begin
  select * into t from public.zad_tiers where tier = p_tier;
  if not found then return jsonb_build_object('ok', false, 'reason', 'unknown_tier'); end if;

  -- refresh بينزّل الباقة المنتهية للمجاني ويقفل الصف للترانزاكشن دي.
  e := public.zad_entitlement_refresh(p_user);
  select * into t_old from public.zad_tiers where tier = e.tier;

  if p_tier = 'free' then
    if e.tier = 'free' then
      return jsonb_build_object('ok', true, 'applied', false, 'tier', e.tier, 'cycle_reset_at', e.cycle_reset_at);
    end if;
    v_fresh := true;
  elsif t.sort_order < coalesce(t_old.sort_order, 0) then
    -- اشتراك أقل والأعلى لسه شغال: الأعلى يفضل لحد ما ينتهي أو جوجل تسحبه.
    return jsonb_build_object('ok', true, 'applied', false, 'reason', 'higher_plan_active',
                              'tier', e.tier, 'cycle_reset_at', e.cycle_reset_at);
  elsif t.sort_order > coalesce(t_old.sort_order, 0) then
    v_fresh := true;
  else
    -- نفس الباقة: رصيد جديد بس لو جوجل مدّت الانتهاء (فترة جديدة اتدفعت).
    v_fresh := p_expires is not null
      and p_expires > coalesce(e.tier_expires_at, '-infinity'::timestamptz);
  end if;

  if v_fresh then
    update public.zad_entitlements set
      tier = p_tier,
      tier_expires_at = p_expires,
      brain_left = greatest(t.brain_monthly, 0),
      scan_left  = greatest(t.scan_monthly, 0),
      chat_left  = greatest(t.chat_monthly, 0),
      voice_left = greatest(t.voice_monthly, 0),
      -- نفس دورة zad_entitlement_refresh: المجاني كل ٥ ساعات، المدفوع كل شهر.
      cycle_reset_at = now() + case when p_tier = 'free' then interval '5 hours' else interval '1 month' end,
      updated_at = now()
    where user_id = p_user returning * into e;
  else
    update public.zad_entitlements set
      tier_expires_at = coalesce(p_expires, tier_expires_at),
      updated_at = now()
    where user_id = p_user returning * into e;
  end if;

  return jsonb_build_object('ok', true, 'applied', true, 'refilled', v_fresh,
                            'tier', e.tier, 'cycle_reset_at', e.cycle_reset_at);
end;
$$;

revoke execute on function public.zad_set_tier(uuid, text, timestamptz) from public, anon, authenticated;
grant execute on function public.zad_set_tier(uuid, text, timestamptz) to service_role;

-- ── ٢أ. إرجاع خصم مسح رجع فاضي ─────────────────────────────────────────────────────────────────
-- بيتنادى بس لما zad_entitlement_consume رجّعت reason = 'quota' (يعني اتخصم فعلاً) — مش بعد
-- media_pass ولا unlimited. zad-core-intelligence هي اللي بتقرر؛ هنا الجمع بس.
create or replace function public.zad_entitlement_refund(p_user uuid, p_kind text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_kind = 'voice' then
    update public.zad_entitlements set voice_left = voice_left + 1, updated_at = now() where user_id = p_user;
  elsif p_kind in ('chat', 'scan', 'brain') then
    update public.zad_entitlements
       set chat_left = chat_left + public.zad_attempt_cost(p_kind), updated_at = now()
     where user_id = p_user;
  end if;
end;
$$;

revoke execute on function public.zad_entitlement_refund(uuid, text) from public, anon, authenticated;
grant execute on function public.zad_entitlement_refund(uuid, text) to service_role;

-- ── ٢ب. حد لكل عميل ولكل نوع (zad-core-intelligence) ─────────────────────────────────────────
create table if not exists public.zad_rate_gate (
  user_id uuid not null references auth.users(id) on delete cascade,
  bucket text not null,
  minute_start timestamptz not null default now(),
  minute_count int not null default 0,
  day date not null default (now() at time zone 'utc')::date,
  day_count int not null default 0,
  primary key (user_id, bucket)
);
alter table public.zad_rate_gate enable row level security;
revoke all on public.zad_rate_gate from anon, authenticated;

-- نداء واحد زيادة لـ p_user في p_bucket، أو رفض: 'minute' لو عدّى p_per_minute في الدقيقة دي،
-- 'day' لو عدّى p_per_day في اليوم (UTC). النداء المرفوض مابيتحسبش.
create or replace function public.zad_rate_take(p_user uuid, p_bucket text, p_per_minute int, p_per_day int)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  g public.zad_rate_gate;
  v_today date := (now() at time zone 'utc')::date;
  v_minute_open boolean;
begin
  insert into public.zad_rate_gate (user_id, bucket) values (p_user, p_bucket)
  on conflict (user_id, bucket) do nothing;
  select * into g from public.zad_rate_gate where user_id = p_user and bucket = p_bucket for update;

  v_minute_open := g.minute_start > now() - interval '1 minute';
  if g.day = v_today and g.day_count >= greatest(p_per_day, 1) then
    return jsonb_build_object('ok', false, 'reason', 'day');
  end if;
  if v_minute_open and g.minute_count >= greatest(p_per_minute, 1) then
    return jsonb_build_object('ok', false, 'reason', 'minute');
  end if;

  update public.zad_rate_gate set
    minute_start = case when v_minute_open then minute_start else now() end,
    minute_count = case when v_minute_open then minute_count + 1 else 1 end,
    day = v_today,
    day_count = case when g.day = v_today then day_count + 1 else 1 end
  where user_id = p_user and bucket = p_bucket;
  return jsonb_build_object('ok', true);
end;
$$;

revoke execute on function public.zad_rate_take(uuid, text, int, int) from public, anon, authenticated;
grant execute on function public.zad_rate_take(uuid, text, int, int) to service_role;

-- ── ٣. منح الإعلانات من admob-ssv بس ─────────────────────────────────────────────────────────
-- create or replace بيحتفظ بالصلاحيات، فأي ترحيل بعد كده بيعيد تعريف الدالتين مش هيرجّع الفتح —
-- إلا لو كتب grant صريح لـ authenticated، وده اللي ممنوع.
revoke execute on function public.zad_ad_reward_grant(uuid) from public, anon, authenticated;
grant execute on function public.zad_ad_reward_grant(uuid) to service_role;
revoke execute on function public.zad_media_pass_grant(uuid) from public, anon, authenticated;
grant execute on function public.zad_media_pass_grant(uuid) to service_role;
