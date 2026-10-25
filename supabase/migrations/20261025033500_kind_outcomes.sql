-- يتعلم من النتيجة (ZAD_PLAN ٣.٦): لكل بيت ولكل نوع مبادرة — اتبعت كام، اترد كام، اتعمل بيه كام.
--
-- zad_guardian_outcomes بيتحكم فيه كل يوم على كل مبادرة اتبعتت (20261011230000، 20261019100000)، بس
-- الحكم كان بيروح للوحة الحقيقة متجمّع على الكل (zad_guardian_scorecard) — ولا بيت واحد كان بيتعلم منه.
-- zad_kind_outcomes بيرجّعه لبيت واحد، وzad-brain (outcomeLearning.ts) بيهدّي النوع اللي البيت ده
-- بيتجاهله ويقدّم اللي بيتعامل معاه. «اتعمل بيه» = فعل خلال ساعتين من غير رفض صريح.
-- zad_my_kind_outcomes = نفس الحاجة للعميل نفسه. رقم الإصدار مش على ساعة مدوّرة عن قصد.

create or replace function public.zad_kind_outcomes(p_user uuid, p_days int default 60)
returns table (kind text, sent int, replied int, acted int, dismissed int, last_at timestamptz)
language sql
stable
security definer
set search_path to 'public'
as $$
  select o.kind,
         count(*)::int,
         count(*) filter (where o.replied_within_day)::int,
         count(*) filter (where coalesce(o.acted_within_2h, false) and not coalesce(o.dismissed, false))::int,
         count(*) filter (where coalesce(o.dismissed, false))::int,
         max(o.delivered_at)
    from public.zad_guardian_outcomes o
   where o.user_id = p_user
     and o.kind is not null
     and o.delivered_at > now() - make_interval(days => greatest(least(coalesce(p_days, 60), 365), 1))
   group by o.kind
   order by count(*) desc;
$$;

revoke all on function public.zad_kind_outcomes(uuid, int) from public, anon, authenticated;
grant execute on function public.zad_kind_outcomes(uuid, int) to service_role;

create or replace function public.zad_my_kind_outcomes(p_days int default 60)
returns table (kind text, sent int, replied int, acted int, dismissed int, last_at timestamptz)
language sql
stable
security definer
set search_path to 'public'
as $$
  select * from public.zad_kind_outcomes(auth.uid(), p_days) where auth.uid() is not null;
$$;

revoke all on function public.zad_my_kind_outcomes(int) from public, anon;
grant execute on function public.zad_my_kind_outcomes(int) to authenticated;
