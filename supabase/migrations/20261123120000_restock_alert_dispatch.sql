-- م٦.٢: إرسال يومي لتنبيه «محتاجه وقريب» (_shared/or/restockAlert.ts). الدالة هنا بتقرا بس: مين محتاج إيه، وفين تقريباً.
-- القرار والإرسال في zad-restock-alerts (إيدج فانكشن بتتندّه من الكرون). مفيش كتابة في أي جدول من الـ١٦ اللي ورا الباب.
-- خصوصية: الموقع بيتقرّب لرقمين عشريين (≈ ١ كم) هنا قبل ما يوصل للكود، والدالة مابترجّعش أي حاجة عن مين اشترى أو أبلغ.
-- zad_restock_alert_log: اللي اتبعت بس (مستخدم + صنف + وقت) — سقف اليوم ومنع تكرار نفس الصنف ٣ أيام. service_role بس.

create table if not exists public.zad_restock_alert_log (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  item_key text not null check (length(item_key) between 1 and 60),
  sent_at timestamptz not null default now()
);
create index if not exists zad_restock_alert_log_user on public.zad_restock_alert_log (user_id, sent_at desc);
alter table public.zad_restock_alert_log enable row level security;
revoke all on public.zad_restock_alert_log from public, anon, authenticated;

create or replace function public.zad_restock_alert_candidates(p_limit integer default 500)
returns table (
  user_id uuid,
  country text,
  tz text,
  lat numeric,
  lng numeric,
  sleep_bed text,
  sleep_wake text,
  muted boolean,
  broke boolean,
  sent_today integer,
  needed text[]
)
language plpgsql stable security definer set search_path = public as $$
begin
  return query
  select u.id,
         upper(u.country),
         public.zad_market_timezone(u.country),
         round(u.last_lat::numeric, 2),
         round(u.last_lon::numeric, 2),
         u.sleep_bed::text,
         u.sleep_wake::text,
         exists (select 1 from public.zad_memory m
                  where m.user_id = u.id and m.subject_kind = 'restock_alert' and m.suppress_until > now()),
         exists (select 1 from public.zad_broke_mode b
                  where b.user_id = u.id and b.ended_at is null and b.ends_at > now()),
         (select count(*)::int from public.zad_restock_alert_log l
           where l.user_id = u.id and l.sent_at > now() - interval '20 hours'),
         n.items
    from public.zad_users u
    cross join lateral (
      select coalesce(array_agg(x.name order by x.name), '{}') as items
        from (
          select distinct left(btrim(i.item_name), 60) as name
            from public.zad_inventory i
           where i.user_id = u.id and i.item_name is not null and btrim(i.item_name) <> ''
             and i.quantity <= greatest(coalesce(i.low_stock_threshold, 0), 0)
          union
          select distinct left(btrim(s.item_name), 60)
            from public.zad_shopping_list s
           where s.user_id = u.id and not coalesce(s.is_purchased, false) and btrim(s.item_name) <> ''
        ) x
       where not exists (select 1 from public.zad_restock_alert_log l
                          where l.user_id = u.id and l.item_key = lower(x.name)
                            and l.sent_at > now() - interval '3 days')
    ) n
   where u.country is not null
     and u.last_lat is not null and u.last_lon is not null
     and u.last_location_at > now() - interval '14 days'
     and cardinality(n.items) > 0
   order by u.id
   limit least(greatest(coalesce(p_limit, 500), 1), 2000);
end;
$$;
revoke all on function public.zad_restock_alert_candidates(integer) from public, anon, authenticated;
grant execute on function public.zad_restock_alert_candidates(integer) to service_role;

-- كرون يومي ١٥:٠٠ UTC (عصر/مغرب في سوق زاد). السر في الـVault باسم zad_restock_alert_cron_secret ولازم يساوي
-- سر الإيدج ZAD_RESTOCK_ALERT_CRON_SECRET (خطوة يدوية للمالك). لحد ما يتظبط الدالة بترفض ٤٠١ (بتفشل مقفولة).
do $do$
begin
  if to_regnamespace('cron') is not null then
    perform cron.unschedule(jobid) from cron.job where jobname = 'zad-restock-alerts-daily';
    perform cron.schedule(
      'zad-restock-alerts-daily',
      '0 15 * * *',
      $cron$
      select net.http_post(
        url := 'https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/zad-restock-alerts',
        headers := jsonb_build_object(
          'X-Restock-Alert-Cron-Secret', public.zad_cron_secret('zad_restock_alert_cron_secret'),
          'Content-Type', 'application/json'
        ),
        body := '{}'::jsonb,
        timeout_milliseconds := 55000
      );
      $cron$
    );
  end if;
end
$do$;
