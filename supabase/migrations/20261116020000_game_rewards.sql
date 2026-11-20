-- بذور الألعاب، من السيرفر وبسقف يومي (واجهة العوالم الجديدة، ٢٠٢٦-١١-١٦).
--
-- نفس عملة بذور الرفيق (zad_companion.seeds) ونفس الدفتر (zad_companion_ledger): السطر الواحد فريد على
-- (user, source, ref)، فالمنح مايتكررش، والسقف اليومي مجموع على الدفتر. العميل مابيقولش «اديني ١٠ بذور»؛
-- بيقول لعبة ونتيجة، والسيرفر هو اللي بيحسب:
--   • قايمة اللعب المسموحة، ولكل لعبة قسمة ثابتة وحد أقصى للجولة الواحدة.
--   • سقف يومي على كل الألعاب (٦٠ بذرة) وسقف جولات لكل لعبة (١٠ في اليوم)، بتوقيت سوق الحساب.
--   • المضاعفة بإعلان: p_doubled مابتضاعفش إلا لو فيه إيصال إعلان مكافأة (zad_ad_ssv_receipts) للمنادي
--     عمره أقل من ١٠ دقايق ومااتستخدمش في مضاعفة قبل كده. الاستخدام بيتسجل في الدفتر نفسه (مصدر
--     'game_double'، المرجع = transaction_id)، فالفريد على الدفتر هو حارس إعادة الاستخدام. المضاعفة
--     بتتحسب على السقف اليومي برضه.
-- النتيجة نفسها بتجي من العميل ومش قابلة للتحقق، فالسقف هو اللي بيحمي الاقتصاد: أقصى كسب في اليوم ٦٠ بذرة
-- مهما كانت النتيجة المبعوتة. (إيصال الإعلان ممكن يكون هو نفسه اللي اتصرف على محاولات ذكاء — مفيش علامة
-- «استُهلك» على الإيصال في المخطط، فالمضاعفة بتسجل استخدامها لحسابها بس.)

alter table public.zad_companion_ledger drop constraint if exists zad_companion_ledger_source_check;
alter table public.zad_companion_ledger add constraint zad_companion_ledger_source_check check (source in
  ('log', 'scan', 'pantry', 'streak', 'family', 'level', 'streak_milestone', 'missions',
   'invite', 'welcome', 'buy', 'purchase', 'challenge', 'close_day', 'game', 'game_double'));

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

  v_base := least(v_max, p_score / v_divisor);
  select coalesce(sum(seeds), 0) into v_used from public.zad_companion_ledger
   where user_id = v_user and day = v_day and source in ('game', 'game_double');
  select count(*) into v_rounds from public.zad_companion_ledger
   where user_id = v_user and day = v_day and source = 'game' and ref like p_game || ':%';

  if v_base > 0 and v_rounds < c_round_cap and v_used < c_daily_cap then
    v_granted := least(v_base, c_daily_cap - v_used);
    perform public.zad_companion_seed(v_user, 'game', p_game || ':' || gen_random_uuid()::text, v_granted);

    if coalesce(p_doubled, false) then
      select r.transaction_id into v_tx from public.zad_ad_ssv_receipts r
       where r.user_id = v_user and r.created_at > now() - interval '10 minutes'
         and not exists (select 1 from public.zad_companion_ledger l
                          where l.user_id = v_user and l.source = 'game_double' and l.ref = r.transaction_id)
       order by r.created_at desc limit 1;
      v_extra := least(v_granted, c_daily_cap - (v_used + v_granted));
      if v_tx is not null and v_extra > 0 then
        v_doubled := public.zad_companion_seed(v_user, 'game_double', v_tx, v_extra);
        if not v_doubled then v_extra := 0; end if;
      else
        v_extra := 0;
      end if;
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
