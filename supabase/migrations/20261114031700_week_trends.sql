-- «هبات الأسبوع» (طلب المالك ١٤/١١): الأكلة أو المنتج اللي مكسّر تيك توك في بلد العميل، برابط الفيديو.
--
-- من غير كشط ولا متصفح خفي (قرار المالك ١٤/١١): zad-brain trends_week_run ⇐ zad-core-intelligence week_trends
-- (بحث ويب عادي ⇐ جيميناي بيختار من النتايج برقمها) ⇐ oEmbed الرسمي بيأكد إن الفيديو عام ⇐ zad_social_picks بنوع 'trend'.
--
--   • zad_social_picks.kind بيقبل 'trend'.
--   • zad_week_trends(p_limit): القراية للعميل المسجّل، لبلده هو بس (zad_users.country، والفاضي = مصر). الجدول نفسه
--     لسه مقفول على السيرفر؛ الدالة بترجع الأعمدة اللي تتعرض بس.
--   • كرون trends-week الاتنين والخميس — نداء بحث واحد ونداء جيميناي واحد لكل بلد فيه عميل.
-- رقم الإصدار مش على ساعة مدوّرة عن قصد.

alter table public.zad_social_picks drop constraint if exists zad_social_picks_kind_check;
alter table public.zad_social_picks add constraint zad_social_picks_kind_check
  check (kind in ('offer', 'recipe', 'idea', 'restaurant', 'supermarket', 'delivery', 'trend'));

create index if not exists zad_social_picks_kind_idx on public.zad_social_picks (country, kind, found_at desc);

create or replace function public.zad_week_trends(p_limit int default 20)
returns table (
  source_url text,
  platform text,
  kind text,
  store text,
  title text,
  summary text,
  discount_percent int,
  posted_at timestamptz,
  found_at timestamptz
)
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
declare
  uid uuid := auth.uid();
  cc text;
begin
  if uid is null then
    raise exception 'not signed in' using errcode = '42501';
  end if;

  select upper(u.country) into cc from public.zad_users u where u.id = uid;
  cc := coalesce(nullif(cc, ''), 'EG');

  -- الهبات الأول، وبعدها باقي ترشيحات السوشيال (وصفة، مطعم، عرض) — الأحدث الأول في كل نوع.
  return query
    select p.source_url, p.platform, p.kind, p.store, p.title, p.summary, p.discount_percent, p.posted_at, p.found_at
      from public.zad_social_picks p
     where p.country = cc
       and p.expires_at > now()
     order by (p.kind = 'trend') desc, p.found_at desc
     limit least(greatest(coalesce(p_limit, 20), 1), 50);
end;
$function$;

revoke all on function public.zad_week_trends(int) from public, anon;
grant execute on function public.zad_week_trends(int) to authenticated, service_role;

select cron.unschedule('trends-week') where exists (select 1 from cron.job where jobname = 'trends-week');
select cron.schedule('trends-week', '17 9 * * 1,4', $cron$
    select net.http_post(
        url := 'https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/zad-brain',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'ZAD-PROACTIVE-CRON-SECRET', public.zad_cron_secret('zad_proactive_cron_secret')
        ),
        body := '{"action":"trends_week_run"}'::jsonb,
        timeout_milliseconds := 150000
      ) as request_id;
    $cron$);
