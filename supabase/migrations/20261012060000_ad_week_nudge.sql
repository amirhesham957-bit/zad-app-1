-- رسالة التحويل الأسبوعية (خطة الدخل ٢٠٢٦-١٠-١١، القسم ٤): العميل اللي شاف إعلانات كتير في
-- أسبوع بيشوف مرة واحدة في الأسبوع أرقامه هو — «شفت ١٥ إعلان الأسبوع ده، حوالي ٨ دقايق» —
-- وجنبها إن الاشتراك من غير إعلانات. مش ضغط: هو شايف بنفسه إن وقته له تمن.
--
--   * بتظهر للمجاني بس، ولما يكون شاف ٥ إعلانات أو أكتر في آخر ٧ أيام.
--   * مرة في الأسبوع بالكتير (zad_ad_week_seen بتسجل إنها اتعرضت).
--   * الدقايق: إعلان المكافأة حوالي ٣٠ ثانية.

create table if not exists public.zad_ad_week_nudge (
  user_id uuid primary key references auth.users(id) on delete cascade,
  shown_at timestamptz not null default now()
);
alter table public.zad_ad_week_nudge enable row level security;
revoke all on public.zad_ad_week_nudge from anon, authenticated;

create or replace function public.zad_ad_week_status()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_user uuid := auth.uid();
  v_ads int;
  v_paid boolean;
  v_recent boolean;
begin
  if v_user is null then raise exception 'not signed in' using errcode = '42501'; end if;
  select count(*) into v_ads from public.zad_ad_grants
   where user_id = v_user and granted_at > now() - interval '7 days';
  select coalesce(e.tier <> 'free' and (e.tier_expires_at is null or e.tier_expires_at > now()), false)
    into v_paid from public.zad_entitlements e where e.user_id = v_user;
  v_recent := exists (select 1 from public.zad_ad_week_nudge n
                       where n.user_id = v_user and n.shown_at > now() - interval '7 days');
  return jsonb_build_object(
    'show', not coalesce(v_paid, false) and not v_recent and v_ads >= 5,
    'ads', v_ads,
    'minutes', ceil(v_ads * 0.5)::int
  );
end;
$$;

create or replace function public.zad_ad_week_seen()
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not signed in' using errcode = '42501'; end if;
  insert into public.zad_ad_week_nudge (user_id, shown_at) values (auth.uid(), now())
  on conflict (user_id) do update set shown_at = now();
end;
$$;

revoke execute on function public.zad_ad_week_status() from public, anon;
revoke execute on function public.zad_ad_week_seen() from public, anon;
grant execute on function public.zad_ad_week_status() to authenticated;
grant execute on function public.zad_ad_week_seen() to authenticated;
