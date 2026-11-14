-- خطة المخزن الواعي، الخطوة ٣ (المالك ١٤/١١): «يعرف إن الزيت/اللبن اتفتح».
--
-- المقاس ١٤/١١: مفيش أي حالة فتح في المخزون. اللبن المفتوح من ٥ أيام كان بيتحسب زي اللي في الكرتونة.
--
-- • opened_at: إمتى اتفتح (consume_item بـopened، «فتحنا علبة لبن»). بيتمسح لوحده لما الكمية توصل صفر.
-- • opened_life_days: يفضل كويس كام يوم بعد الفتح، حسب نوعه — بيتحسب في التريجر من private.zad_pantry_opened_life،
--   فالعقل والبوت بيقروا العمود ومحدش بيكرر القايمة. null = نوع مابيبوظش بسرعة بعد الفتح (رز، زيت، سكر).
-- • zad_pantry_learning: الأيام الباقية = الأقل بين المعدل (المتعلّم أو المبدئي) وبين اللي فاضل من عمره بعد الفتح،
--   والثقة 'opened' لما الفتح هو اللي بيحكم.
-- الكلمات تحت بيانات مطابقة مع أسامي الأصناف — ممنوع تترجم (قاعدة i18n في CLAUDE.md).

alter table public.zad_inventory
  add column if not exists opened_at timestamptz,
  add column if not exists opened_life_days int check (opened_life_days is null or opened_life_days between 1 and 365);

/** يفضل كويس كام يوم بعد الفتح (في التلاجة). null = مالوش عمر قصير بعد الفتح. */
create or replace function private.zad_pantry_opened_life(p_name text)
returns int
language sql
immutable
set search_path = ''
as $$
  select k.days
    from (values
      (1, ' (ال)?(زبادي|رايب|قشطه|كريمه|كريم شانتيه) ', 3),
      (2, ' (ال)?(لبن|حليب) ', 4),
      (3, ' (ال)?(لانشون|بسطرمه|مرتديلا|تركي مدخن|سلامي) ', 4),
      (4, ' (ال)?(عصير|جوس) ', 5),
      (5, ' (ال)?(لبنه|جبنه قريش|قريش|ريكوتا) ', 5),
      (6, ' (ال)?(جبن|جبنه|رومي|شيدر|موتزاريلا|فيتا|اسطنبولي|براميلي) ', 7),
      (7, ' (ال)?(صلصه|معجون طماطم) ', 7),
      (8, ' (ال)?(توست|خبز توست) ', 5)
    ) as k(ord, pattern, days)
   where (' ' || private.zad_pantry_norm(p_name) || ' ') ~ k.pattern
   order by k.ord
   limit 1;
$$;

revoke all on function private.zad_pantry_opened_life(text) from public, anon, authenticated;

/** الفتح بيتمسح لما الصنف يخلص؛ وعمره بعد الفتح بيتحسب من اسمه. */
create or replace function private.zad_inventory_opened()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if coalesce(new.quantity, 0) <= 0 then
    new.opened_at := null;
  end if;
  new.opened_life_days := case when new.opened_at is null then null
                               else private.zad_pantry_opened_life(new.item_name) end;
  return new;
end;
$$;

revoke all on function private.zad_inventory_opened() from public, anon, authenticated;

drop trigger if exists zad_inventory_opened on public.zad_inventory;
create trigger zad_inventory_opened
  before insert or update of quantity, opened_at, item_name on public.zad_inventory
  for each row execute function private.zad_inventory_opened();

/** الأيام الباقية من عمر الصنف بعد فتحه، أو null. */
create or replace function private.zad_pantry_opened_left(p_opened_at timestamptz, p_life int)
returns numeric
language sql
stable
set search_path = ''
as $$
  select case when p_opened_at is null or p_life is null then null
              else greatest(0, round(p_life - extract(epoch from now() - p_opened_at)::numeric / 86400, 1)) end;
$$;

revoke all on function private.zad_pantry_opened_left(timestamptz, int) from public, anon, authenticated;

alter table public.zad_pantry_bets drop constraint if exists zad_pantry_bets_confidence_check;
alter table public.zad_pantry_bets add constraint zad_pantry_bets_confidence_check
  check (confidence in ('known', 'approximate', 'prior', 'opened', 'cycle', 'unasked'));

/** مخزن البيت بعين السيرفر (20261114200000) + عمر الصنف بعد فتحه. */
create or replace function public.zad_pantry_learning()
returns table (
  item_id uuid,
  item_name text,
  days_left numeric,
  confidence text,
  stagnant boolean,
  ask boolean
)
language plpgsql
volatile
security definer
set search_path = public
as $$
#variable_conflict use_column
declare
  v_me uuid := auth.uid();
  v_today date;
begin
  if v_me is null then
    raise exception 'not_authenticated';
  end if;

  select (now() at time zone coalesce(public.zad_market_timezone(u.country), 'Africa/Cairo'))::date
    into v_today
    from public.zad_users u where u.id = v_me;
  v_today := coalesce(v_today, (now() at time zone 'Africa/Cairo')::date);

  return query
  with home as (
    select v_me as uid
    union
    select m.user_id from public.family_members m
     where m.family_id in (select public.get_my_family_ids()) and m.user_id is not null
  ),
  inv as (
    select i.id, i.item_name, i.quantity, i.restock_mode, i.created_at,
           private.zad_pantry_opened_left(i.opened_at, i.opened_life_days) as opened_left,
           private.zad_product_canonical_for(v_me, i.item_name) as canon
      from public.zad_inventory i
     where i.user_id = v_me
        or (i.family_id is not null and i.family_id in (select public.get_my_family_ids()))
     limit 400
  ),
  rate as (
    select inv.id,
           max(c.avg_daily_qty) filter (where c.avg_daily_qty > 0) as avg_daily_qty,
           bool_or(c.rate_known and c.avg_daily_qty > 0) as known
      from inv
      join public.zad_consumption c
        on c.user_id in (select uid from home) and c.item_name in (inv.canon, inv.item_name)
     group by inv.id
  ),
  prior as (
    select p.item_id, p.days_left from private.zad_pantry_prior_days(v_me) p
  ),
  obs as (
    select o.item_name, o.observed_at,
           o.qty < lag(o.qty) over (partition by o.user_id, o.item_name order by o.observed_at, o.created_at, o.id) as dropped
      from public.zad_inventory_observations o
     where o.user_id in (select uid from home)
  ),
  activity as (
    select inv.id, max(obs.observed_at) as last_at, coalesce(bool_or(obs.dropped), false) as used
      from inv join obs on obs.item_name in (inv.canon, inv.item_name)
     group by inv.id
  ),
  rated as (
    select inv.id, inv.item_name, inv.quantity, inv.restock_mode, inv.created_at, inv.opened_left,
           case when r.avg_daily_qty > 0 then round((inv.quantity / r.avg_daily_qty::numeric), 1)
                else p.days_left end as by_rate,
           case when r.avg_daily_qty > 0 then case when r.known then 'known' else 'approximate' end
                when p.days_left is not null then 'prior' end as rate_confidence,
           a.last_at, coalesce(a.used, false) as used
      from inv
      left join rate r on r.id = inv.id
      left join prior p on p.item_id = inv.id
      left join activity a on a.id = inv.id
  ),
  judged as (
    select r.*,
           case when r.opened_left is not null and (r.by_rate is null or r.opened_left < r.by_rate) then r.opened_left
                else r.by_rate end as days_left,
           case when r.opened_left is not null and (r.by_rate is null or r.opened_left < r.by_rate) then 'opened'
                else r.rate_confidence end as confidence
      from rated r
  ),
  out as (
    select j.id, j.item_name, j.days_left, j.confidence,
           (j.quantity > 0
             and coalesce(j.last_at, j.created_at, now()) < now() - interval '30 days'
             and not j.used) as stagnant,
           (j.quantity > 0
             and j.restock_mode is distinct from 'occasional'
             and j.days_left is not null and j.days_left <= 2
             and not exists (
               select 1 from public.zad_pantry_bets b
                where b.user_id in (select uid from home) and b.item_id = j.id
                  and ((b.answer = 'still_have' and b.answered_at > now() - interval '3 days')
                       or (b.asked_on = v_today and b.answer is not null))
             )) as ask
      from judged j
  ),
  -- رهان للي هيتسأل فعلاً بس: الموبايل بيعرض أقرب اتنين (20261114200000).
  bets as (
    insert into public.zad_pantry_bets (user_id, item_id, item_name, asked_on, predicted_days_left, confidence)
    select v_me, o.id, o.item_name, v_today, o.days_left, o.confidence
      from out o where o.ask
     order by o.days_left asc nulls last, o.item_name
     limit 2
    on conflict on constraint zad_pantry_bets_one_a_day do nothing
    returning 1
  )
  select o.id, o.item_name, o.days_left, o.confidence, o.stagnant, o.ask
    from out o
   order by o.ask desc, o.days_left asc nulls last, o.item_name;
end;
$$;

revoke all on function public.zad_pantry_learning() from public, anon;
grant execute on function public.zad_pantry_learning() to authenticated, service_role;
