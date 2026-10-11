-- هوية المنتج — الاسم الواحد للبيت (الموجة ٦، الشريحة ١، ٢٠٢٦-١٠-١١).
--
-- فحص ما قبل الإطلاق: المية متسجلة خمس أصناف («مياه إيلانو»، «مياه نستله بيور لايف»، «عبوة مياه»،
-- «إزازة ماء»، «صافي مياه معدنية 1.5 لتر») واللبن صنفين («لبن»، «حليب»). كل اسم بيبدأ عداد
-- استهلاكه من الأول، فمن ١٣ صنف في zad_consumption واحد بس معدله معروف، و«هيخلص إمتى؟» عمره
-- ما اشتغل.
--
-- قرار المالك (٢٠٢٦-١٠-١١): **العقل يسأل العميل مرة** «دول نفس الحاجة؟»، ومايدمجش لوحده —
-- الدمج الغلط («لبن رايب» مع «لبن») أصعب في الرجوع من سؤال زيادة.
--
-- هنا الأساس، من غير ما حاجة تتدمج لسه:
--   zad_product_pairs — إجابات البيت: زوج مفاتيح (zad_inventory_name_key) و«same» باسم
--     المحتفظ بيه، أو «different» عشان مايتسألش تاني. للبيت (user_id + family_id زي المخزن).
--     الكتابة من الدوال بس (الشريحة الجاية)؛ العميل وعيلته بيقروا.
--   private.zad_product_canonical_for(user, name) — الاسم اللي البيت اختاره، أو الاسم زي ما هو.
--     بتمشي في السلسلة (أ=ب، ب=ج) لحد ٣ خطوات.
--   تريجر BEFORE INSERT/UPDATE على المخزن والقايمة والملاحظات: أي اسم جديد بيتكتب بالاسم المختار
--     — التطبيق والعقل وتليجرام وSQL مرة واحدة، من غير ما كل كاتب يتعلّم لوحده.
--   zad_record_observation بتعيد حساب الاستهلاك بالاسم المختار (الملاحظة نفسها اتكتبت بيه).
--
-- لما مفيش ولا إجابة في البيت (النهارده كله) التريجر بيرجّع الاسم زي ما هو: السلوك من غير تغيير.

create schema if not exists private;

-- التحذير الوحيد من get_advisors على دالة المفتاح: search_path متغير. مافيهاش جداول.
alter function public.zad_inventory_name_key(text) set search_path = pg_catalog;

create table if not exists public.zad_product_pairs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  family_id uuid references public.family_groups(id) on delete set null,
  a_key text not null,
  b_key text not null,
  verdict text not null check (verdict in ('same', 'different')),
  canonical_name text,
  created_at timestamptz not null default now(),
  check (a_key < b_key),
  check (a_key <> '' and b_key <> ''),
  check ((verdict = 'same') = (canonical_name is not null and btrim(canonical_name) <> '')),
  check (canonical_name is null or char_length(canonical_name) <= 80)
);

create unique index if not exists zad_product_pairs_household_pair
  on public.zad_product_pairs ((coalesce(family_id, user_id)), a_key, b_key);
create index if not exists zad_product_pairs_user on public.zad_product_pairs (user_id);
create index if not exists zad_product_pairs_family on public.zad_product_pairs (family_id) where family_id is not null;

alter table public.zad_product_pairs enable row level security;
drop policy if exists zad_product_pairs_select on public.zad_product_pairs;
create policy zad_product_pairs_select on public.zad_product_pairs for select
  using ((select auth.uid()) = user_id
         or (family_id is not null and family_id in (select public.get_my_family_ids())));
grant select on public.zad_product_pairs to authenticated;
grant all on public.zad_product_pairs to service_role;

create or replace function private.zad_product_canonical_for(p_user uuid, p_name text)
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_name text := btrim(regexp_replace(coalesce(p_name, ''), '\s+', ' ', 'g'));
  v_family uuid;
  v_key text;
  v_next text;
  v_changed boolean := false;
begin
  if v_name = '' or p_user is null then
    return p_name;
  end if;
  select m.family_id into v_family from public.family_members m where m.user_id = p_user limit 1;
  if not exists (
    select 1 from public.zad_product_pairs pp
     where pp.verdict = 'same'
       and (pp.user_id = p_user or (v_family is not null and pp.family_id = v_family))
  ) then
    return p_name;
  end if;

  for i in 1..3 loop
    v_key := public.zad_inventory_name_key(v_name);
    v_next := null;
    select pp.canonical_name into v_next
      from public.zad_product_pairs pp
     where pp.verdict = 'same'
       and (pp.user_id = p_user or (v_family is not null and pp.family_id = v_family))
       and (pp.a_key = v_key or pp.b_key = v_key)
       and public.zad_inventory_name_key(pp.canonical_name) <> v_key
     order by pp.created_at desc
     limit 1;
    exit when v_next is null;
    v_name := v_next;
    v_changed := true;
  end loop;

  return case when v_changed then v_name else p_name end;
end;
$$;

revoke all on function private.zad_product_canonical_for(uuid, text) from public, anon, authenticated;

-- للتطبيق والعقل: نفس الحاجة للعميل نفسه بس.
create or replace function public.zad_product_canonical(p_user uuid, p_name text)
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is not null and auth.uid() <> p_user then
    raise exception 'not_authorized' using errcode = '42501';
  end if;
  return private.zad_product_canonical_for(p_user, p_name);
end;
$$;

revoke all on function public.zad_product_canonical(uuid, text) from public, anon;
grant execute on function public.zad_product_canonical(uuid, text) to authenticated, service_role;

create or replace function private.zad_product_canonical_name_trg()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'UPDATE' and new.item_name is not distinct from old.item_name then
    return new;
  end if;
  new.item_name := private.zad_product_canonical_for(new.user_id, new.item_name);
  return new;
end;
$$;

revoke all on function private.zad_product_canonical_name_trg() from public, anon, authenticated;

drop trigger if exists zad_product_canonical_name on public.zad_inventory;
create trigger zad_product_canonical_name before insert or update of item_name on public.zad_inventory
  for each row execute function private.zad_product_canonical_name_trg();
drop trigger if exists zad_product_canonical_name on public.zad_shopping_list;
create trigger zad_product_canonical_name before insert or update of item_name on public.zad_shopping_list
  for each row execute function private.zad_product_canonical_name_trg();
drop trigger if exists zad_product_canonical_name on public.zad_inventory_observations;
create trigger zad_product_canonical_name before insert or update of item_name on public.zad_inventory_observations
  for each row execute function private.zad_product_canonical_name_trg();

-- الملاحظة بتتكتب بالاسم المختار (التريجر)، فإعادة الحساب لازم تبقى بيه هي كمان. على النص الحي:
-- الجملة بكلماتها بأي مسافات، مرة واحدة بالظبط، وإلا المايجريشن بتقف.
do $migrate$
declare
  v_def text;
  v_pat text;
  v_hits int;
begin
  select pg_get_functiondef('public.zad_record_observation(uuid, text, numeric, text)'::regprocedure) into v_def;
  v_pat := regexp_replace('return public.zad_recompute_consumption(p_user, p_item);', '([.*+?^${}()|\[\]\\])', '\\\1', 'g');
  v_pat := regexp_replace(v_pat, ' ', '\\s+', 'g');
  v_hits := regexp_count(v_def, v_pat);
  if v_hits <> 1 then
    raise exception 'product identity: zad_record_observation has % recompute calls, expected 1', v_hits;
  end if;
  execute regexp_replace(v_def, v_pat,
    'return public.zad_recompute_consumption(p_user, private.zad_product_canonical_for(p_user, p_item));');
end
$migrate$;
