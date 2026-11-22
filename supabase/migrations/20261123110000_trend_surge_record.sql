-- م٦.٣: تسجيل قفزات الترند اليومية (مجمّعة بس) + كرون يومي بينده zad-trend-surge.
-- الجدول والكاتب مجهولين بقصد (نفس سابقة zad_restock_observe): الصف = (يوم، صنف، عدد بيوت، عدد إشارات، المعتاد، z).
-- مفيش user_id ولا member_id، فمش بيعدي من zad_commit_intent (الباب بيسجّل صاحب الحدث في zad_events، والقفزة المجمّعة
-- مالهاش صاحب). service_role بس. حد الخصوصية ٥ بيوت متفحوص هنا تاني (check + رفض في الكاتب).
-- الهايب لوحده مش سبب ترشيح: مفيش عمود بيقول «اشتري»، والجدول للعرض والتحليل بس.

create table if not exists public.zad_trend_surges (
  day date not null,
  item_key text not null check (length(item_key) between 2 and 120),
  houses integer not null check (houses >= 5),
  signal_count integer not null check (signal_count >= 0),
  baseline numeric not null check (baseline >= 0),
  z numeric not null,
  primary key (day, item_key)
);
alter table public.zad_trend_surges enable row level security;
revoke all on public.zad_trend_surges from public, anon, authenticated;

create or replace function public.zad_trend_surge_record(p_day date, p_rows jsonb) returns integer
language plpgsql security definer set search_path = public as $$
declare
  r jsonb;
  n integer := 0;
begin
  if p_day is null then raise exception 'bad_day'; end if;
  if p_rows is null or jsonb_typeof(p_rows) <> 'array' then raise exception 'bad_rows'; end if;
  for r in select * from jsonb_array_elements(p_rows) loop
    if coalesce((r ->> 'houses')::integer, 0) < 5 then continue; end if;
    insert into public.zad_trend_surges (day, item_key, houses, signal_count, baseline, z)
    values (p_day, lower(btrim(r ->> 'item')), (r ->> 'houses')::integer, (r ->> 'count')::integer,
            (r ->> 'baseline')::numeric, round((r ->> 'z')::numeric, 3))
    on conflict (day, item_key) do update
      set houses = excluded.houses, signal_count = excluded.signal_count, baseline = excluded.baseline, z = excluded.z;
    n := n + 1;
  end loop;
  delete from public.zad_trend_surges where day < p_day - 90;
  return n;
end;
$$;
revoke all on function public.zad_trend_surge_record(date, jsonb) from public, anon, authenticated;
grant execute on function public.zad_trend_surge_record(date, jsonb) to service_role;
