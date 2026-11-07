-- «لسه موجودين بعد أسبوع 0» من ١٦ (أول قراية حية ٧/١١) كان مضلل: أغلب الـ١٦ اتسجلوا من أقل من أسبوع، فمستحيل
-- يكون عدّى عليهم أسبوع. المقام بقى اللي عدّى عليهم أسبوع بس.

create or replace function public.zad_founder_dropoff(p_now timestamptz default now())
returns text
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  c_probe constant uuid := 'a11ce000-0000-4000-8000-00000000a11a';
  v_screens text;
  v_last text;
  v_gone int;
  v_d1 int; v_d7 int; v_new14 int; v_week_old int;
begin
  select coalesce(string_agg(name || ' ' || n, '، ' order by n desc, name), 'مفيش')
    into v_screens
    from (select name, count(distinct user_id) as n from zad_product_events
           where user_id <> c_probe and at >= p_now - interval '7 days'
             and (name like 'tab.%' or name like 'section.%')
           group by name order by n desc, name limit 10) s;

  with last_seen as (
    select distinct on (user_id) user_id, name, at
      from zad_product_events
     where user_id <> c_probe and at >= p_now - interval '30 days'
     order by user_id, at desc
  ), gone as (select * from last_seen where at < p_now - interval '7 days')
  select (select count(*) from gone),
         coalesce((select string_agg(name || ' ' || n, '، ' order by n desc, name)
                     from (select name, count(*) as n from gone group by name order by n desc, name limit 6) g), '—')
    into v_gone, v_last;

  -- رجوع الجداد: اتسجلوا من ٢–١٤ يوم؛ رجعوا تاني يوم؟ رجعوا بعد أسبوع؟
  select count(*),
         count(*) filter (where exists (select 1 from zad_product_events e where e.user_id = u.id
                                         and e.at >= u.created_at + interval '1 day' and e.at < u.created_at + interval '2 days')),
         count(*) filter (where exists (select 1 from zad_product_events e where e.user_id = u.id
                                         and e.at >= u.created_at + interval '7 days')),
         count(*) filter (where u.created_at <= p_now - interval '7 days')
    into v_new14, v_d1, v_d7, v_week_old
    from zad_users u
   where u.id <> c_probe and u.created_at >= p_now - interval '14 days' and u.created_at < p_now - interval '2 days';

  return '🖥️ الشاشات (عدد الناس الأسبوع ده): ' || v_screens || '.' || E'\n\n' ||
         '🚪 فين بيقفوا: ' || v_gone || ' مافتحوش من أسبوع؛ آخر حاجة عملوها: ' || v_last || '.' || E'\n\n' ||
         '↩️ الجداد (آخر أسبوعين، ' || v_new14 || '): رجعوا تاني يوم ' || v_d1 || '، ولسه موجودين بعد أسبوع ' || v_d7 || ' من ' || v_week_old || ' عدّى عليهم أسبوع.';
end;
$$;
revoke all on function public.zad_founder_dropoff(timestamptz) from public, anon, authenticated;
