-- تحديات العيلة الموسمية وأوسمتها (طلب المالك ٢٠٢٦-١٠-٠٤): تحدي مربوط بمناسبة («تحدي رمضان 🌙»)،
-- واللي يخلّصه ياخد وسام المناسبة، ويبان في شاشة الأولاد.
--
-- season_key = event_key بتاع الحملة في app_campaigns (من غير FK: الحملة ممكن تتشال من اللوحة
-- والوسام يفضل). badge = الإيموجي بتاع الوسام وقت ما التحدي اتعمل.
--
-- الوسام بيتحسب من financial_challenge_progress.is_completed، واللي بيكتبه zad_contribute_to_challenge
-- بس — فمفيش طريق لوسام من غير ما التحدي يتعمل فعلاً.
--
-- **مفيش أوسمة للمشتركين بس.** المالك طلب «هويات احتفالية نادرة حصرية لمشتركي بريميوم»، واترفض:
-- سياسة Google Play Families بتمنع تشجيع الأطفال على الشراء، ومفيش Play أصلاً.

alter table public.family_financial_challenges
  add column if not exists season_key text
    check (season_key is null or season_key ~ '^[a-z0-9_]{2,40}$'),
  add column if not exists badge text
    check (badge is null or char_length(badge) between 1 and 16);

comment on column public.family_financial_challenges.season_key is
  'المناسبة اللي التحدي مربوط بيها (event_key في app_campaigns)؛ null = تحدي عادي.';
comment on column public.family_financial_challenges.badge is
  'وسام اللي يخلّص التحدي (إيموجي). بيتحسب من progress.is_completed.';

-- نفس الـguard بتاع 20260921150000، والعمودين الجداد اتضافوا للي مايتغيّرش غير من الأدمن:
-- طفل يغيّر وسام تحدي شغال = يغيّر الجايزة.
create or replace function public.zad_family_challenges_guard()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or public.zad_family_ledger_open() then return new; end if;
  if coalesce(new.reward_amount, 0) < 0 or coalesce(new.target_amount, 0) < 0 then
    raise exception 'negative_amount' using errcode = '22023';
  end if;
  if public.zad_is_family_admin(new.family_id) then return new; end if;

  if tg_op = 'INSERT' then
    if coalesce(new.reward_amount, 0) <> 0 then
      raise exception 'only_admins_set_rewards' using errcode = '42501';
    end if;
    return new;
  end if;

  -- Lowering the target or reopening the window is winning without saving.
  if new.family_id is distinct from old.family_id
     or new.reward_amount is distinct from old.reward_amount
     or new.target_amount is distinct from old.target_amount
     or new.start_date is distinct from old.start_date
     or new.end_date is distinct from old.end_date
     or new.is_active is distinct from old.is_active
     or new.season_key is distinct from old.season_key
     or new.badge is distinct from old.badge then
    raise exception 'only_admins_change_challenges' using errcode = '42501';
  end if;
  return new;
end;
$$;
