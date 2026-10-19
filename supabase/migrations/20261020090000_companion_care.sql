-- ZAD_PLAN ٥.٥ — حالة الرفيق على السيرفر (٢٠٢٦-١٠-٢٠).
--
-- الجوع والعطش والسلسلة كانوا متخزنين على الموبايل بس (`pet_care_controller.dart`): البوت مايعرفش إن
-- زادو جعان، وتليجرام مايقدرش يقول «زادو مستنيك»، والسلسلة بتضيع لو العميل غيّر موبايله. هنا نفس
-- الأوقات بس — مش XP ولا بذور (دول بتوع السيرفر من الأول ومابيتحسبوش من هنا، ZAD_COMPANION.md).
--
-- موبايلين على نفس الحساب: الدمج مابيرجعش لورا. آخر أكلة وآخر شربة وآخر طبطبة = الأحدث من الاتنين،
-- والسلسلة وأيامها من اللي اهتم بيه آخر مرة. الموبايل بيبعت حالته بعد كل أكلة وكل فتحة، وبياخد الصف
-- اللي راجع (السيرفر بيكسب)، فمفيش outbox: الحالة كلها في كل نداء، والنداء اللي ماوصلش بيتعاد في الفتحة الجاية.

create table if not exists public.zad_companion_care (
  user_id uuid primary key references auth.users (id) on delete cascade,
  fed_at timestamptz not null,
  watered_at timestamptz not null,
  petted_at timestamptz,
  last_care_at timestamptz,
  fed_day text check (fed_day ~ '^\d{4}-\d{2}-\d{2}$'),
  watered_day text check (watered_day ~ '^\d{4}-\d{2}-\d{2}$'),
  care_day text check (care_day ~ '^\d{4}-\d{2}-\d{2}$'),
  care_streak int not null default 0 check (care_streak between 0 and 3650),
  updated_at timestamptz not null default now()
);

alter table public.zad_companion_care enable row level security;
-- مفيش سياسة: الكتابة والقراية من الدالة تحت بس (أو service_role للبوت).
revoke all on public.zad_companion_care from anon, authenticated;
grant all on public.zad_companion_care to service_role;

create or replace function public.zad_companion_care_json(c public.zad_companion_care)
returns jsonb
language sql
immutable
as $$
  select jsonb_build_object(
    'fed_at', c.fed_at, 'watered_at', c.watered_at, 'petted_at', c.petted_at,
    'last_care_at', c.last_care_at, 'fed_day', c.fed_day, 'watered_day', c.watered_day,
    'care_day', c.care_day, 'care_streak', c.care_streak
  );
$$;

revoke all on function public.zad_companion_care_json(public.zad_companion_care) from public, anon, authenticated;

-- [p_care] null = «اقرا بس»: موبايل لسه شايف الرفيق لأول مرة مايبعتش أوقات المولود بتاعه قبل ما يعرف
-- إن مفيش صف — وإلا المولود («جعان شوية») كان هيمسح أكلة حقيقية من موبايل تاني. يرجّع null لو مفيش صف.
create or replace function public.zad_companion_care_sync(p_care jsonb default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_now timestamptz := now() + interval '5 minutes';
  v_fed timestamptz;
  v_watered timestamptz;
  v_petted timestamptz;
  v_last timestamptz;
  v_row public.zad_companion_care;
begin
  if v_user is null then
    raise exception 'not signed in' using errcode = '28000';
  end if;

  if p_care is null or jsonb_typeof(p_care) <> 'object' then
    select * into v_row from zad_companion_care where user_id = v_user;
    return case when found then zad_companion_care_json(v_row) end;
  end if;

  -- ساعة الموبايل مش مرجع: وقت في المستقبل بيتقص لدلوقتي، عشان رفيق «شبعان لبكرة» مايتخزنش.
  v_fed := (p_care ->> 'fed_at')::timestamptz;
  v_watered := (p_care ->> 'watered_at')::timestamptz;
  v_petted := (p_care ->> 'petted_at')::timestamptz;
  v_last := (p_care ->> 'last_care_at')::timestamptz;
  if v_fed is null or v_watered is null then
    raise exception 'fed_at and watered_at are required' using errcode = '22023';
  end if;
  -- least() بيتجاهل null، فالقص بعد الفحص ولكل قيمة موجودة بس (طبطبة ماحصلتش تفضل null).
  v_fed := least(v_fed, v_now);
  v_watered := least(v_watered, v_now);
  v_petted := case when v_petted is not null then least(v_petted, v_now) end;
  v_last := case when v_last is not null then least(v_last, v_now) end;

  insert into zad_companion_care as c (
    user_id, fed_at, watered_at, petted_at, last_care_at, fed_day, watered_day, care_day, care_streak, updated_at)
  values (
    v_user, v_fed, v_watered, v_petted, v_last,
    nullif(p_care ->> 'fed_day', ''), nullif(p_care ->> 'watered_day', ''), nullif(p_care ->> 'care_day', ''),
    greatest(0, least(3650, coalesce((p_care ->> 'care_streak')::int, 0))), now())
  on conflict (user_id) do update set
    fed_at = greatest(c.fed_at, excluded.fed_at),
    watered_at = greatest(c.watered_at, excluded.watered_at),
    petted_at = greatest(c.petted_at, excluded.petted_at),
    last_care_at = greatest(c.last_care_at, excluded.last_care_at),
    -- السلسلة من آخر واحد اهتم بيه (التعادل للجديد).
    fed_day = case when coalesce(excluded.last_care_at, '-infinity') >= coalesce(c.last_care_at, '-infinity')
                   then excluded.fed_day else c.fed_day end,
    watered_day = case when coalesce(excluded.last_care_at, '-infinity') >= coalesce(c.last_care_at, '-infinity')
                       then excluded.watered_day else c.watered_day end,
    care_day = case when coalesce(excluded.last_care_at, '-infinity') >= coalesce(c.last_care_at, '-infinity')
                    then excluded.care_day else c.care_day end,
    care_streak = case when coalesce(excluded.last_care_at, '-infinity') >= coalesce(c.last_care_at, '-infinity')
                       then excluded.care_streak else c.care_streak end,
    updated_at = now()
  returning * into v_row;

  return zad_companion_care_json(v_row);
end;
$$;

revoke all on function public.zad_companion_care_sync(jsonb) from public, anon;
grant execute on function public.zad_companion_care_sync(jsonb) to authenticated;
