-- تحدي ٣٠ يوم توفير (٢٠٢٦-٠٩-١٤).
--
-- العميل بيحدد سقف يومي (أو زاد تقترحه)، وكل يوم صرفه تحت السقف = يوم كسبه وسلسلته بتكبر.
-- زاد بتشجعه بصوتها في المحطات (٣/٧/١٤/٢١ يوم ورا بعض)، وتحتفل لما يخلّص، وتزعل بلطف
-- لو سلسلة ٣ أيام أو أكتر اتقطعت. التحدي كمان «اتفاق توفير» — لما يدخل منطقة تسوق وهو
-- شغال، زاد بتفكّره (store_arrival → shopping_zone_warning).
--
-- التقييم على السيرفر بس (zad_evaluate_savings_challenges، كل ٥ دقايق في كرون اللحظات):
-- الساعة ٩ الصبح بتوقيت العميل بيتحسب امبارح (وأي يوم فات ماتحسبش لو الكرون وقف). العميل
-- مايقدرش يعدّل العدادات بنفسه — صلاحية التعديل على الحالة بس (يسيب التحدي).

create table if not exists public.zad_savings_challenges (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  started_on date not null,
  length_days int not null default 30 check (length_days between 7 and 90),
  daily_cap numeric(14, 2) not null check (daily_cap >= 0),
  currency text check (currency is null or char_length(currency) <= 10),
  status text not null default 'active' check (status in ('active', 'completed', 'abandoned')),
  days_won int not null default 0,
  days_lost int not null default 0,
  streak int not null default 0,
  best_streak int not null default 0,
  last_evaluated_on date,
  source text not null default 'app' check (source in ('app', 'voice', 'chat', 'telegram')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists zad_savings_challenges_one_active
  on public.zad_savings_challenges (user_id) where status = 'active';

alter table public.zad_savings_challenges enable row level security;

drop policy if exists "savings challenges: owner reads" on public.zad_savings_challenges;
create policy "savings challenges: owner reads" on public.zad_savings_challenges
  for select using (auth.uid() = user_id);
drop policy if exists "savings challenges: owner inserts" on public.zad_savings_challenges;
create policy "savings challenges: owner inserts" on public.zad_savings_challenges
  for insert with check (auth.uid() = user_id and days_won = 0 and days_lost = 0 and streak = 0 and best_streak = 0 and last_evaluated_on is null);
drop policy if exists "savings challenges: owner updates status" on public.zad_savings_challenges;
create policy "savings challenges: owner updates status" on public.zad_savings_challenges
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "savings challenges: owner deletes" on public.zad_savings_challenges;
create policy "savings challenges: owner deletes" on public.zad_savings_challenges
  for delete using (auth.uid() = user_id);

-- العدادات بيكتبها التقييم بس: العميل يعدّل الحالة (يسيب التحدي) ووقت التعديل، مش سلسلته.
revoke update on public.zad_savings_challenges from authenticated;
grant update (status, updated_at) on public.zad_savings_challenges to authenticated;

create or replace function public.zad_evaluate_savings_challenges()
returns int
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  c record;
  v_tz text;
  v_local_date date;
  v_local_hour int;
  v_day date;
  v_spent numeric;
  v_won boolean;
  v_prev_streak int;
  v_streak int;
  v_best int;
  v_won_days int;
  v_lost_days int;
  v_day_index int;
  v_moment text;
  v_evaluated int := 0;
begin
  for c in
    select s.*, u.country
    from public.zad_savings_challenges s
    join public.zad_users u on u.id = s.user_id
    where s.status = 'active'
  loop
    v_tz := public.zad_market_timezone(c.country);
    v_local_date := (now() at time zone v_tz)::date;
    v_local_hour := extract(hour from now() at time zone v_tz)::int;
    continue when v_local_hour < 9;

    v_streak := c.streak;
    v_best := c.best_streak;
    v_won_days := c.days_won;
    v_lost_days := c.days_lost;
    v_moment := null;
    v_day := coalesce(c.last_evaluated_on + 1, c.started_on);

    -- لحد امبارح، ومش بعد آخر يوم في التحدي. ٩٠ لفة كحد أقصى (طول التحدي).
    while v_day < v_local_date and v_day < c.started_on + c.length_days loop
      select coalesce(sum(abs(t.amount)), 0) into v_spent
      from public.zad_transactions t
      where t.user_id = c.user_id
        and t.txn_kind = 'expense'
        and coalesce(t.counts_toward_budget, true)
        and t.created_at >= (v_day::timestamp at time zone v_tz)
        and t.created_at < ((v_day + 1)::timestamp at time zone v_tz);

      v_won := v_spent <= c.daily_cap;
      v_prev_streak := v_streak;
      if v_won then
        v_streak := v_streak + 1;
        v_won_days := v_won_days + 1;
        v_best := greatest(v_best, v_streak);
      else
        v_streak := 0;
        v_lost_days := v_lost_days + 1;
      end if;
      v_day_index := v_day - c.started_on + 1;

      -- لحظة واحدة بس، عن آخر يوم اتحسب — لو الكرون كان واقف أيام مانغرقوش برسايل قديمة.
      v_moment := case
        when v_day_index >= c.length_days then 'challenge_completed'
        when v_won and v_streak in (3, 7, 14, 21) then 'challenge_milestone'
        when not v_won and v_prev_streak >= 3 then 'challenge_streak_broken'
        else null
      end;
      v_day := v_day + 1;
    end loop;

    continue when v_day = coalesce(c.last_evaluated_on + 1, c.started_on);

    update public.zad_savings_challenges
    set streak = v_streak,
        best_streak = v_best,
        days_won = v_won_days,
        days_lost = v_lost_days,
        last_evaluated_on = v_day - 1,
        status = case when (v_day - c.started_on) >= c.length_days then 'completed' else status end,
        updated_at = now()
    where id = c.id;
    v_evaluated := v_evaluated + 1;

    if v_moment is not null then
      insert into public.zad_voice_moments (user_id, moment, facts, dedupe_key)
      values (
        c.user_id, v_moment,
        jsonb_build_object(
          'challenge_id', c.id, 'day', v_day - c.started_on, 'length_days', c.length_days,
          'streak', v_streak, 'broken_streak', v_prev_streak, 'best_streak', v_best,
          'days_won', v_won_days, 'daily_cap', c.daily_cap, 'yesterday_spent', v_spent,
          'currency', c.currency, 'time_zone', v_tz
        ),
        'challenge:' || c.id || ':' || (v_day - 1)
      )
      on conflict (user_id, dedupe_key) do nothing;
    end if;
  end loop;
  return v_evaluated;
end;
$function$;

revoke all on function public.zad_evaluate_savings_challenges() from public;
revoke all on function public.zad_evaluate_savings_challenges() from anon;
revoke all on function public.zad_evaluate_savings_challenges() from authenticated;

select cron.unschedule('voice-moments-processor')
where exists (select 1 from cron.job where jobname = 'voice-moments-processor');

select cron.schedule(
  'voice-moments-processor',
  '*/5 * * * *',
  $$
  select public.zad_enqueue_missed_doses();
  select public.zad_enqueue_appointment_moments();
  select public.zad_enqueue_morning_fallback();
  select public.zad_enqueue_weekly_money_story();
  select public.zad_evaluate_savings_challenges();
  select net.http_post(
      url := 'https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/zad-brain',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'ZAD-PROACTIVE-CRON-SECRET', public.zad_cron_secret('zad_proactive_cron_secret')
      ),
      body := '{"action":"process_voice_moments"}'::jsonb,
      timeout_milliseconds := 55000
    ) as request_id
  where exists (
    select 1 from public.zad_voice_moments
    where status = 'pending' and created_at > now() - interval '6 hours'
  );
  $$
);
