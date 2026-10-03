-- =====================================================
-- التأمل الليلي بالموديل (docs/agent/ZAD_LIVING_BRAIN.md، الشريحة ٤ — قرار المالك 2026-10-03).
--
-- zad-brain/consolidation.ts بيراجع محادثات اليوم مرة في الليلة ويطلّع حقايق بكياناتها وزمنها.
-- الملف ده هو البوابة والعلامة:
--   - zad_memory_consolidation_due: لفات العميل من آخر مراجعة (٢٤ ساعة بالكتير، ٤٠ لفة)، بس لو
--     قال ≥ p_min_user_turns رسالة فيهم. غير كده فاضية = العقل مابينادي الموديل خالص (الكوتة).
--   - zad_users.memory_consolidated_at: لحد فين اتراجع، عشان نفس الكلام مايتراجعش مرتين لو الكرون
--     اتنده تاني في نفس الليلة.
-- =====================================================

alter table public.zad_users
  add column if not exists memory_consolidated_at timestamptz;

comment on column public.zad_users.memory_consolidated_at is
  'آخر لفة في zad_chat_turns راجعها التأمل الليلي بالموديل (ZAD_LIVING_BRAIN.md الشريحة ٤). null = لسه.';

create or replace function public.zad_memory_consolidation_due(p_user uuid, p_min_user_turns integer default 3)
returns jsonb language sql stable security definer set search_path = public as $$
  with since as (
    select greatest(
      coalesce((select memory_consolidated_at from public.zad_users where id = p_user), '-infinity'::timestamptz),
      now() - interval '24 hours'
    ) as t
  ),
  turns as (
    select role, left(text, 600) as text, created_at
      from public.zad_chat_turns
     where user_id = p_user and created_at > (select t from since)
     order by created_at desc
     limit 40
  )
  select case
    when (select count(*) from turns where role = 'user') < greatest(1, coalesce(p_min_user_turns, 3)) then '[]'::jsonb
    else (select jsonb_agg(jsonb_build_object('role', role, 'text', text, 'at', created_at) order by created_at) from turns)
  end;
$$;
revoke all on function public.zad_memory_consolidation_due(uuid, integer) from public, anon, authenticated;
grant execute on function public.zad_memory_consolidation_due(uuid, integer) to service_role;

create or replace function public.zad_memory_mark_consolidated(p_user uuid, p_at timestamptz)
returns void language sql security definer set search_path = public as $$
  update public.zad_users
     set memory_consolidated_at = greatest(coalesce(memory_consolidated_at, '-infinity'::timestamptz), p_at)
   where id = p_user and p_at is not null and p_at <= now() + interval '1 minute';
$$;
revoke all on function public.zad_memory_mark_consolidated(uuid, timestamptz) from public, anon, authenticated;
grant execute on function public.zad_memory_mark_consolidated(uuid, timestamptz) to service_role;
