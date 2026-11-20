-- إنجازات زاد: كاتب على السيرفر (الجداول والأنماط من user_achievements في 20260831140000).
--
-- الجدول كان له سياسة قراءة لصاحبه وسياسة insert بـ`with check (true)` اسمها "server write" — وده
-- كان بيسمح لأي حساب مسجّل يكتب إنجاز لنفسه (أو لغيره) من العميل. السيرفر (service_role) بيتخطى RLS
-- أصلاً فالسياسة ماكانتش لازمة. هنا بتتشال، والصلاحيات بتتسحب، والكتابة الوحيدة من
-- zad_grant_achievement، دالة داخلية مش متاحة للعميل، بتتنادى من التريجرز ومن zad_game_reward.
--
-- الكتالوج ثابت هنا (مش من العميل). كل منح idempotent على (user_id, achievement_id).
-- قاعدة الرحمة زي الرفيق: كل تريجر بيبلع أخطاءه — إنجاز مكسور مايفشلش مصروف.
--
--   first_receipt     أول فاتورة اتصورت            (zad_transactions.source_type = 'receipt')
--   first_transaction أول معاملة
--   streak_7          سلسلة ٧ أيام                 (zad_companion.streak — السلسلة موجودة على السيرفر)
--   tasbih_tree       أول شجرة تسبيح ٩٩ ضغطة        (family_tasbiha.total_clicks)
--   saved_1000        ١٠٠٠ متوفرة في هدف            (agent_goals.current_value)
--   zado_run_300      ٣٠٠ في زادو ران               (zad_game_reward)
-- saved_1000 مقروءة من هدف يقدر العميل يعدّله، فهي شارة تشجيع مش دليل — مفيش بذور عليها.

drop policy if exists "user_achievements_server_write" on public.user_achievements;
revoke insert, update, delete on public.user_achievements from anon, authenticated;
revoke all on public.user_achievements from anon;
grant select on public.user_achievements to authenticated;

create unique index if not exists idx_user_achievements_unique
  on public.user_achievements (user_id, achievement_id);

create or replace function public.zad_grant_achievement(p_user uuid, p_achievement text)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_points int;
  v_id bigint;
begin
  if p_user is null then return false; end if;
  v_points := case p_achievement
    when 'first_receipt' then 20
    when 'first_transaction' then 10
    when 'streak_7' then 100
    when 'tasbih_tree' then 30
    when 'saved_1000' then 100
    when 'zado_run_300' then 50
    else null end;
  if v_points is null then return false; end if;  -- خارج الكتالوج: مفيش حاجة بتتكتب
  insert into public.user_achievements (user_id, achievement_id, points_earned)
  values (p_user, p_achievement, v_points)
  on conflict (user_id, achievement_id) do nothing
  returning id into v_id;
  return v_id is not null;
end;
$$;

revoke all on function public.zad_grant_achievement(uuid, text) from public, anon, authenticated;
grant execute on function public.zad_grant_achievement(uuid, text) to service_role;

-- ── التريجرز ─────────────────────────────────────────────────────────────────

create or replace function public.zad_achievements_on_transaction()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  begin
    if new.user_id is not null then
      perform public.zad_grant_achievement(new.user_id, 'first_transaction');
      if new.source_type = 'receipt' then
        perform public.zad_grant_achievement(new.user_id, 'first_receipt');
      end if;
    end if;
  exception when others then
    raise warning 'zad_achievements_on_transaction: % (%)', sqlerrm, sqlstate;
  end;
  return null;
end;
$$;

create or replace function public.zad_achievements_on_streak()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  begin
    if new.streak >= 7 then
      perform public.zad_grant_achievement(new.user_id, 'streak_7');
    end if;
  exception when others then
    raise warning 'zad_achievements_on_streak: % (%)', sqlerrm, sqlstate;
  end;
  return null;
end;
$$;

create or replace function public.zad_achievements_on_tasbiha()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_who uuid;
begin
  begin
    if coalesce(new.total_clicks, 0) >= 99 then
      -- شجرة شخصية: صاحبها. شجرة عيلة: اللي ضغط فعلاً (مش كل العيلة).
      v_who := case when new.family_id is null then new.user_id else coalesce(auth.uid(), new.user_id) end;
      perform public.zad_grant_achievement(v_who, 'tasbih_tree');
    end if;
  exception when others then
    raise warning 'zad_achievements_on_tasbiha: % (%)', sqlerrm, sqlstate;
  end;
  return null;
end;
$$;

create or replace function public.zad_achievements_on_goal()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  begin
    if coalesce(new.current_value, 0) >= 1000 then
      perform public.zad_grant_achievement(new.user_id, 'saved_1000');
    end if;
  exception when others then
    raise warning 'zad_achievements_on_goal: % (%)', sqlerrm, sqlstate;
  end;
  return null;
end;
$$;

revoke all on function public.zad_achievements_on_transaction() from public, anon, authenticated;
revoke all on function public.zad_achievements_on_streak() from public, anon, authenticated;
revoke all on function public.zad_achievements_on_tasbiha() from public, anon, authenticated;
revoke all on function public.zad_achievements_on_goal() from public, anon, authenticated;

drop trigger if exists zad_achievements on public.zad_transactions;
create trigger zad_achievements after insert on public.zad_transactions
  for each row execute function public.zad_achievements_on_transaction();

drop trigger if exists zad_achievements on public.zad_companion;
create trigger zad_achievements after update of streak on public.zad_companion
  for each row when (new.streak >= 7) execute function public.zad_achievements_on_streak();

drop trigger if exists zad_achievements on public.family_tasbiha;
create trigger zad_achievements after insert or update of total_clicks on public.family_tasbiha
  for each row when (new.total_clicks >= 99) execute function public.zad_achievements_on_tasbiha();

drop trigger if exists zad_achievements on public.agent_goals;
create trigger zad_achievements after insert or update of current_value on public.agent_goals
  for each row when (new.current_value >= 1000) execute function public.zad_achievements_on_goal();
