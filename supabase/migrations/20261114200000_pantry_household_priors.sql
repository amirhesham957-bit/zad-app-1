-- خطة المخزن الواعي، الخطوة ١ (المالك ١٤/١١): «يعرف الميه والعيش بيخلصوا إمتى» من أول يوم.
--
-- المقاس ١٤/١١ على حساب المالك: ٢٩ صنف وصفر معدّل استهلاك. zad_pantry_learning مابيحسبش أيام باقية من غير
-- معدل متعلّم، والمعدل بيتعلّم بس من نزلات الكمية — ومفيش ولا نزلة. يعني الكارت «هل خلص؟» عمره ما ظهر،
-- و household_size (٢ عند المالك) متخزّن ومحدش بيقراه.
--
-- هنا: معدل مبدئي لكل صنف = استهلاك الفرد في اليوم (حسب نوعه) × عدد أفراد البيت ÷ حجم العبوة (من الاسم:
-- «500 جم»، «1.5 لتر … 6 قطع»، «500 منديل»؛ وإلا حجم معتاد). الأيام الباقية = الكمية ÷ المعدل ناقص الأيام
-- اللي عدّت من آخر قراية للصنف — الكمية المتخزنة هي آخر ما اتقال، مش النهارده.
--
-- إمتى يتستعمل: مفيش معدل متعلّم (zad_consumption) وأقل من ٣ أيام شرا مختلفة في ١٨٠ يوم. المعدل المتعلّم
-- وعادة شرا البيت نفسه (restockCycle.ts: habitCycleDays) الاتنين أدق من أي رقم عام، فبيغلبوه.
-- الأنواع اللي مش متأكدين من استهلاكها (خضار بالقطعة، لحمة في الفريزر، العناية الشخصية) مالهاش رقم — بتفضل
-- زي ما هي. الثقة 'prior' في zad_pantry_bets، فالقياس الأسبوعي (zad_pantry_bet_accuracy) بيحكم على الأرقام دي
-- لوحدها.
--
-- الكلمات تحت بيانات مطابقة مع أسامي الأصناف — ممنوع تترجم (قاعدة i18n في CLAUDE.md).

create schema if not exists private;

/** اسم الصنف أو وحدته بشكل واحد: من غير تشكيل، أ/إ/آ = ا، ة = ه، ى = ي، أرقام عربي = إنجليزي. */
create or replace function private.zad_pantry_norm(p text)
returns text
language sql
immutable
set search_path = ''
as $$
  select btrim(regexp_replace(
    translate(regexp_replace(lower(coalesce(p, '')), '[ًٌٍَُِّْـ]', '', 'g'),
              'أإآةى٠١٢٣٤٥٦٧٨٩٫', 'اااهي0123456789.'),
    '\s+', ' ', 'g'));
$$;

/**
 * كام فرد في البيت: اللي العميل قاله (zad_customer_profile.household_size)، وإلا أفراد عيلته في زاد لو اتنين
 * أو أكتر، وإلا ٣ (متوسط البيت المصري ~٤؛ ٣ عشان مانسألش بدري على بيت لوحده).
 */
create or replace function private.zad_household_people(p_user uuid)
returns int
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select p.household_size from public.zad_customer_profile p
      where p.user_id = p_user and p.household_size between 1 and 30),
    (select case when count(distinct m.user_id) >= 2 then count(distinct m.user_id)::int end
       from public.family_members m
      where m.user_id is not null
        and m.family_id in (select f.family_id from public.family_members f where f.user_id = p_user)),
    3);
$$;

/**
 * المعدل المبدئي بوحدة الصنف في اليوم (عبوات، أو كيلو/لتر، أو جرام/مل، أو أرغفة/بيض). null = نوع مالوش رقم.
 * [p_people] أفراد البيت.
 */
create or replace function private.zad_pantry_prior_daily(p_name text, p_unit text, p_people int)
returns numeric
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_name text := ' ' || private.zad_pantry_norm(p_name) || ' ';
  v_unit text := private.zad_pantry_norm(p_unit);
  v_people int := greatest(1, least(coalesce(p_people, 3), 30));
  v_kind record;
  v_size text[];
  v_count text[];
  v_pack numeric;
  v_amount numeric;
begin
  -- الاستهلاك اليومي للفرد: [daily] بوحدة [measure] (g / ml / piece)، و[pack] حجم العبوة المعتاد لو الاسم ماقالش.
  select k.daily, k.measure, k.pack into v_kind
    from (values
      (1,  ' (ال)?توست ',                                      60::numeric,  'g',     500::numeric),
      (2,  ' (ال)?(عيش|خبز|رغيف|ارغفه|فينو|صامولي) ',          2.5,          'piece', 1),
      (3,  ' (ال)?(لبن|حليب) ',                                200,          'ml',    1000),
      (4,  ' (ال)?(زبادي|رايب) ',                              80,           'g',     105),
      (5,  ' (ال)?(مياه|ميه|مايه|ماء) ',                       1500,         'ml',    1500),
      (6,  ' (ال)?(بيض|بيضه|بيضات) ',                          1,            'piece', 1),
      (7,  ' (ال)?(جبن|جبنه|رومي|شيدر|موتزاريلا|فيتا) ',       30,           'g',     250),
      (8,  ' (ال)?(رز|ارز) ',                                  70,           'g',     1000),
      (9,  ' (ال)?(مكرونه|معكرونه|باستا|شعيريه) ',             40,           'g',     400),
      (10, ' (ال)?سكر ',                                       40,           'g',     1000),
      (11, ' (ال)?شاي ',                                       6,            'g',     250),
      (12, ' (ال)?(قهوه|بن|نسكافيه) ',                         8,            'g',     200),
      (13, ' (ال)?زيت ',                                       25,           'ml',    800),
      (14, ' (ال)?(سمن|زبده) ',                                10,           'g',     500),
      (15, ' (ال)?ملح ',                                       5,            'g',     1000),
      (16, ' (ال)?دقيق ',                                      40,           'g',     1000),
      (17, ' (ال)?(مسحوق|اريال|برسيل|تايد|بونكس) ',            12,           'g',     1000),
      (18, ' (ال)?مناديل ',                                    8,            'piece', 100),
      (19, ' (ال)?معجون ',                                     1.5,          'g',     100),
      (20, ' (ال)?شامبو ',                                     6,            'ml',    400)
    ) as k(ord, pattern, daily, measure, pack)
   where v_name ~ k.pattern
   order by k.ord
   limit 1;
  if not found then
    return null;
  end if;

  v_amount := v_kind.daily * v_people;

  -- الصنف بيتعد بالوزن أو الحجم نفسه.
  if v_kind.measure <> 'piece' then
    if v_unit in ('كجم', 'كيلو', 'كغ', 'kg', 'لتر', 'ليتر', 'l') then
      return round(v_amount / 1000, 4);
    elsif v_unit in ('جم', 'جرام', 'غرام', 'غم', 'g', 'gm', 'مل', 'ml') then
      return round(v_amount, 4);
    end if;
  end if;

  -- بالعبوة: حجمها من الاسم لو مكتوب.
  v_count := regexp_match(v_name,
    '([0-9]+) ?(قطعه|قطع|حبات|حبه|عبوات|عبوه|زجاجات|زجاجه|اكياس|كيس|منديل|ورقه|ارغفه|رغيف|بيضات|بيضه|x)(?![a-zء-ي])');
  if v_kind.measure = 'piece' then
    v_pack := coalesce(
      nullif(v_count[1]::numeric, 0),
      case when v_unit in ('كرتونه', 'طبق') then 30 end,
      v_kind.pack);
  else
    v_size := regexp_match(v_name,
      '([0-9]+(?:[.,][0-9]+)?) ?(كجم|كيلو|كغ|kg|جرام|غرام|جم|غم|gm|g|ليتر|لتر|l|مل|ml)(?![a-zء-ي])');
    if v_size is not null then
      v_pack := replace(v_size[1], ',', '.')::numeric
                * case when v_size[2] in ('كجم', 'كيلو', 'كغ', 'kg', 'لتر', 'ليتر', 'l') then 1000 else 1 end
                * coalesce(nullif(v_count[1]::numeric, 0), 1);
    end if;
    v_pack := coalesce(nullif(v_pack, 0), v_kind.pack);
  end if;

  return round(v_amount / v_pack, 4);
end;
$$;

/**
 * الأيام الباقية بالمعدل المبدئي، لكل صنف في بيت [p_user] (أصنافه وأصناف عيلته) مالوش معدل متعلّم ولا عادة شرا.
 * [held] = حد في البيت قال «لسه» عليه في آخر ٣ أيام (مايتسألش، نفس قاعدة zad_pantry_learning).
 */
create or replace function private.zad_pantry_prior_days(p_user uuid)
returns table (item_id uuid, item_name text, days_left numeric, daily numeric, people int, held boolean)
language sql
stable
security definer
set search_path = public
as $$
  with fam as (
    select f.family_id from public.family_members f where f.user_id = p_user
  ),
  home as (
    select p_user as uid
    union
    select m.user_id from public.family_members m where m.family_id in (select family_id from fam) and m.user_id is not null
  ),
  ppl as (select private.zad_household_people(p_user) as n),
  inv as (
    select i.id, i.item_name, i.quantity, i.created_at,
           private.zad_product_canonical_for(p_user, i.item_name) as canon,
           private.zad_pantry_prior_daily(i.item_name, i.unit, (select n from ppl)) as daily
      from public.zad_inventory i
     where (i.user_id = p_user or (i.family_id is not null and i.family_id in (select family_id from fam)))
       and i.quantity > 0
       and i.restock_mode is distinct from 'occasional'
     limit 400
  ),
  learned as (
    select inv.id
      from inv
      join public.zad_consumption c
        on c.user_id in (select uid from home) and c.item_name in (inv.canon, inv.item_name) and c.avg_daily_qty > 0
     group by inv.id
  ),
  seen as (
    select inv.id,
           max(o.observed_at) as last_at,
           count(distinct (o.observed_at at time zone 'UTC')::date)
             filter (where o.source in ('purchase', 'camera_ocr', 'chat_add')
                       and o.observed_at > now() - interval '180 days') as bought_days
      from inv
      join public.zad_inventory_observations o
        on o.user_id in (select uid from home) and o.item_name in (inv.canon, inv.item_name)
     where inv.daily > 0
     group by inv.id
  )
  select inv.id, inv.item_name,
         greatest(0, round(inv.quantity / inv.daily
                           - extract(epoch from now() - coalesce(greatest(s.last_at, inv.created_at), now()))::numeric / 86400, 1)),
         inv.daily,
         (select n from ppl),
         exists (
           select 1 from public.zad_pantry_bets b
            where b.user_id in (select uid from home) and b.item_id = inv.id
              and b.answer = 'still_have' and b.answered_at > now() - interval '3 days')
    from inv
    left join seen s on s.id = inv.id
   where inv.daily > 0
     and coalesce(s.bought_days, 0) < 3
     and not exists (select 1 from learned l where l.id = inv.id);
$$;

revoke all on function private.zad_pantry_norm(text) from public, anon, authenticated;
revoke all on function private.zad_household_people(uuid) from public, anon, authenticated;
revoke all on function private.zad_pantry_prior_daily(text, text, int) from public, anon, authenticated;
revoke all on function private.zad_pantry_prior_days(uuid) from public, anon, authenticated;

/** البوت (service role): الأيام الباقية بالمعدل المبدئي لأصناف العميل ده — نفس اللي الموبايل بيشوفه. */
create or replace function public.zad_pantry_prior_days_for(p_user uuid)
returns table (item_name text, days_left numeric, held boolean)
language sql
stable
security definer
set search_path = public
as $$
  select p.item_name, p.days_left, p.held from private.zad_pantry_prior_days(p_user) p;
$$;

revoke all on function public.zad_pantry_prior_days_for(uuid) from public, anon, authenticated;
grant execute on function public.zad_pantry_prior_days_for(uuid) to service_role;

alter table public.zad_pantry_bets drop constraint if exists zad_pantry_bets_confidence_check;
alter table public.zad_pantry_bets add constraint zad_pantry_bets_confidence_check
  check (confidence in ('known', 'approximate', 'prior', 'cycle', 'unasked'));

/** مخزن البيت بعين السيرفر (20261112230000) + المعدل المبدئي لما مفيش معدل متعلّم. */
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
  judged as (
    select inv.id, inv.item_name, inv.quantity, inv.restock_mode, inv.created_at,
           case when r.avg_daily_qty > 0 then round((inv.quantity / r.avg_daily_qty::numeric), 1)
                else p.days_left end as days_left,
           case when r.avg_daily_qty > 0 then case when r.known then 'known' else 'approximate' end
                when p.days_left is not null then 'prior' end as confidence,
           a.last_at, coalesce(a.used, false) as used
      from inv
      left join rate r on r.id = inv.id
      left join prior p on p.item_id = inv.id
      left join activity a on a.id = inv.id
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
  -- رهان للي هيتسأل فعلاً بس: الموبايل بيعرض أقرب اتنين (الكارت = الأول، الإشعار = أول اتنين). من غير السقف ده
  -- المعدل المبدئي كان هيفتح رهان كل يوم لكل صنف قديم عدّى وقته، ويغرّق القياس بـ«اتجاهل».
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

/** سؤال البوت رهان (20261113000000) — ولو سأل بالمعدل المبدئي، الرهان بيتقال 'prior' بأيامه. */
create or replace function private.zad_pantry_bet_from_prompt()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item record;
  v_rate double precision;
  v_known boolean;
  v_prior numeric;
  v_today date;
begin
  if tg_op = 'INSERT' then
    select i.id, i.item_name, i.quantity into v_item
      from public.zad_inventory i
     where i.user_id = new.user_id and i.item_name = new.item_name
     order by i.created_at desc nulls last
     limit 1;
    if not found then
      return new;
    end if;

    select max(c.avg_daily_qty) filter (where c.avg_daily_qty > 0), bool_or(c.rate_known and c.avg_daily_qty > 0)
      into v_rate, v_known
      from public.zad_consumption c
     where c.user_id = new.user_id
       and c.item_name in (v_item.item_name, private.zad_product_canonical_for(new.user_id, v_item.item_name));

    if not coalesce(v_rate > 0, false) then
      select p.days_left into v_prior from private.zad_pantry_prior_days(new.user_id) p where p.item_id = v_item.id;
    end if;

    select (new.sent_at at time zone coalesce(public.zad_market_timezone(u.country), 'Africa/Cairo'))::date
      into v_today from public.zad_users u where u.id = new.user_id;

    insert into public.zad_pantry_bets
      (user_id, item_id, item_name, asked_on, asked_at, predicted_days_left, confidence, channel, prompt_id)
    values
      (new.user_id, v_item.id, v_item.item_name,
       coalesce(v_today, (new.sent_at at time zone 'Africa/Cairo')::date), new.sent_at,
       case when v_rate > 0 then round(greatest(coalesce(new.quantity_at_prompt, v_item.quantity), 0) / v_rate::numeric, 1)
            else v_prior end,
       case when v_rate > 0 then case when v_known then 'known' else 'approximate' end
            when v_prior is not null then 'prior'
            else 'cycle' end,
       'telegram', new.id)
    on conflict on constraint zad_pantry_bets_one_a_day
      do update set prompt_id = coalesce(public.zad_pantry_bets.prompt_id, excluded.prompt_id);
    return new;
  end if;

  if new.status in ('answered_yes', 'answered_no') and old.status is distinct from new.status then
    update public.zad_pantry_bets b
       set answer = case
                      when new.status = 'answered_no' or new.answer_fraction = 0 then 'finished'
                      when new.answer_fraction is not null and new.answer_fraction <= 0.25 then 'low'
                      else 'still_have'
                    end,
           answered_at = coalesce(new.answered_at, now())
     where b.prompt_id = new.id and b.answer is null;
  end if;
  return new;
end;
$$;

revoke all on function private.zad_pantry_bet_from_prompt() from public, anon, authenticated;
