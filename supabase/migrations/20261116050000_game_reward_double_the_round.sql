-- المضاعفة مابقتش جولة جديدة (٢٠٢٦-١١-١٦). قبل كده p_doubled=true كانت بتحسب جولة كاملة جديدة + الإضافة، والعميل
-- بينادي الدالة مرتين (مرة عند نهاية الجولة، ومرة عند «ضاعف البذور») = ٣ أضعاف وجولتين على السقف.
-- دلوقتي المضاعفة بتدوّر على آخر جولة للمنادي في نفس اللعبة (عمرها < ١٠ دقايق)، ومرة واحدة بس للجولة
-- (حارس: مفيش سطر game_double للمنادي بتاريخ >= تاريخ الجولة)، وإيصال إعلان جديد زي الأول. بتمنح مثل بذور
-- الجولة (محدودة بالسقف اليومي) من غير ما تزوّد عدّاد الجولات. من غير جولة مؤهلة أو إيصال: صفر، والإيصال
-- مايتصرفش. الرد: granted = الإضافة، base = 0.

create or replace function public.zad_game_reward(p_game text, p_score int, p_doubled boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  c_daily_cap constant int := 60;
  c_round_cap constant int := 10;
  v_user uuid := auth.uid();
  v_divisor int;
  v_max int;
  v_day date;
  v_base int;
  v_used int;
  v_rounds int;
  v_granted int := 0;
  v_extra int := 0;
  v_doubled boolean := false;
  v_tx text;
  v_remaining int;
  v_round_at timestamptz;
  v_round_seeds int;
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;

  select d, m into v_divisor, v_max from (values
    ('ball', 10, 8), ('zado_run', 50, 10), ('zado_sort', 5, 8), ('star_catch', 5, 8), ('tasbih_garden', 33, 6)
  ) as g(game, d, m) where g.game = p_game;
  if v_divisor is null then
    raise exception 'unknown_game' using errcode = '22023';
  end if;
  if p_score is null or p_score < 0 or p_score > 1000000 then
    raise exception 'bad_score' using errcode = '22023';
  end if;

  -- طلبين متوازيين لنفس الحساب مايعدّوش السقف: واحد ورا التاني.
  perform pg_advisory_xact_lock(hashtextextended('zad_game_reward:' || v_user::text, 0));

  perform public.zad_companion_ensure(v_user);
  v_day := public.zad_companion_today(v_user);

  -- إنجاز زادو ران: على النتيجة، مش على البذور (الشارة ماليهاش بذور).
  if p_game = 'zado_run' and p_score >= 300 then
    perform public.zad_grant_achievement(v_user, 'zado_run_300');
  end if;

  select coalesce(sum(seeds), 0) into v_used from public.zad_companion_ledger
   where user_id = v_user and day = v_day and source in ('game', 'game_double');

  if coalesce(p_doubled, false) then
    -- المضاعفة عمرها ما بتفتح جولة: بتضاعف آخر جولة للمنادي في نفس اللعبة (عمرها أقل من ١٠ دقايق)،
    -- ومرة واحدة بس للجولة الواحدة.
    select l.created_at, l.seeds into v_round_at, v_round_seeds from public.zad_companion_ledger l
     where l.user_id = v_user and l.source = 'game' and l.ref like p_game || ':%'
       and l.created_at > now() - interval '10 minutes'
     order by l.created_at desc, l.id desc limit 1;
    if v_round_at is not null
       and not exists (select 1 from public.zad_companion_ledger d
                        where d.user_id = v_user and d.source = 'game_double' and d.created_at >= v_round_at) then
      select r.transaction_id into v_tx from public.zad_ad_ssv_receipts r
       where r.user_id = v_user and r.created_at > now() - interval '10 minutes'
         and not exists (select 1 from public.zad_companion_ledger l
                          where l.user_id = v_user and l.source = 'game_double' and l.ref = r.transaction_id)
       order by r.created_at desc limit 1;
      v_extra := least(v_round_seeds, c_daily_cap - v_used);
      if v_tx is not null and v_extra > 0 then
        v_doubled := public.zad_companion_seed(v_user, 'game_double', v_tx, v_extra);
        if not v_doubled then v_extra := 0; end if;
      else
        v_extra := 0;
      end if;
    end if;
  else
    v_base := least(v_max, p_score / v_divisor);
    select count(*) into v_rounds from public.zad_companion_ledger
     where user_id = v_user and day = v_day and source = 'game' and ref like p_game || ':%';
    if v_base > 0 and v_rounds < c_round_cap and v_used < c_daily_cap then
      v_granted := least(v_base, c_daily_cap - v_used);
      perform public.zad_companion_seed(v_user, 'game', p_game || ':' || gen_random_uuid()::text, v_granted);
    end if;
  end if;

  v_remaining := greatest(c_daily_cap - (v_used + v_granted + v_extra), 0);
  return jsonb_build_object(
    'granted', v_granted + v_extra,
    'base', v_granted,
    'doubled', v_doubled,
    'remaining_today', v_remaining,
    'daily_cap', c_daily_cap
  );
end;
$$;

revoke all on function public.zad_game_reward(text, int, boolean) from public, anon;
grant execute on function public.zad_game_reward(text, int, boolean) to authenticated, service_role;
