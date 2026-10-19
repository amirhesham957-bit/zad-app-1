-- ZAD_PLAN ٥.٥: حالة الرفيق على السيرفر. يتشغّل بعد scratch_scaffold.sql والمايجريشن
-- 20261020090000_companion_care.sql على قاعدة فاضية.

\set ON_ERROR_STOP on

insert into auth.users (id) values
  ('00000000-0000-4000-8000-0000000000c1'), ('00000000-0000-4000-8000-0000000000c2');

set role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000c1","role":"authenticated"}', false);

do $$
declare r jsonb;
begin
  -- موبايل جديد بيقرا الأول: مفيش صف = null، ومافيش حاجة اتكتبت.
  r := zad_companion_care_sync(null);
  if r is not null then raise exception 'read before any row should be null, got %', r; end if;

  -- الموبايل ١ بيبعت حالته (أكل من ساعتين، وسلسلة ٦).
  r := zad_companion_care_sync(jsonb_build_object('fed_at', now() - interval '2 hours',
    'watered_at', now() - interval '3 hours', 'last_care_at', now() - interval '2 hours',
    'care_day', '2026-10-19', 'fed_day', '2026-10-19', 'care_streak', 6));
  if (r ->> 'care_streak')::int <> 6 then raise exception 'first write lost the streak: %', r; end if;

  -- الموبايل ٢ بحالة أقدم (مولود بعد إعادة تسطيب): مايرجّعش الأكلة لورا ولا يمسح السلسلة.
  r := zad_companion_care_sync(jsonb_build_object('fed_at', now() - interval '12 hours',
    'watered_at', now() - interval '1 hour', 'last_care_at', now() - interval '12 hours', 'care_streak', 0));
  if (r ->> 'fed_at')::timestamptz <> date_trunc('microseconds', now() - interval '2 hours') then
    raise exception 'older meal won: %', r; end if;
  if (r ->> 'watered_at')::timestamptz <> now() - interval '1 hour' then raise exception 'newer drink lost: %', r; end if;
  if (r ->> 'care_streak')::int <> 6 then raise exception 'older care reset the streak: %', r; end if;

  -- اهتمام أحدث بياخد السلسلة.
  r := zad_companion_care_sync(jsonb_build_object('fed_at', now() - interval '10 minutes',
    'watered_at', now() - interval '10 minutes', 'last_care_at', now() - interval '10 minutes',
    'care_day', '2026-10-20', 'care_streak', 7));
  if (r ->> 'care_streak')::int <> 7 or r ->> 'care_day' <> '2026-10-20' then raise exception 'newer care lost: %', r; end if;

  -- ساعة موبايل في المستقبل بتتقص.
  r := zad_companion_care_sync(jsonb_build_object('fed_at', now() + interval '3 days',
    'watered_at', now() - interval '1 hour', 'last_care_at', now() + interval '3 days', 'care_streak', 7));
  if (r ->> 'fed_at')::timestamptz > now() + interval '6 minutes' then raise exception 'future meal stored: %', r; end if;

  -- طبطبة ماحصلتش تفضل null (least() بيتجاهل null — كانت بتبقى «دلوقتي»).
  if r ->> 'petted_at' is not null then raise exception 'a pat that never happened was stored: %', r; end if;

  -- من غير أكلة: مرفوض.
  begin
    perform zad_companion_care_sync('{"watered_at":"2026-10-19T08:00:00Z"}');
    raise exception 'a care without fed_at passed';
  exception when sqlstate '22023' then null;
  end;

  -- القراية بترجّع نفس الصف.
  if zad_companion_care_sync(null) <> r then raise exception 'read differs from last write'; end if;
end $$;

-- حساب تاني مايشوفش صف الأول.
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000000c2","role":"authenticated"}', false);
do $$ begin
  if zad_companion_care_sync(null) is not null then raise exception 'another account read the pet'; end if;
end $$;

-- والجدول مقفول على القراية المباشرة.
do $$ begin
  begin
    perform 1 from zad_companion_care;
    raise exception 'authenticated read the table directly';
  exception when insufficient_privilege then null;
  end;
end $$;

-- من غير حساب: مرفوض.
select set_config('request.jwt.claims', '{"role":"anon"}', false);
do $$ begin
  begin
    perform zad_companion_care_sync(null);
    raise exception 'unsigned call passed';
  exception when sqlstate '28000' then null;
  end;
end $$;

reset role;
select 'companion_care_test: ok';
