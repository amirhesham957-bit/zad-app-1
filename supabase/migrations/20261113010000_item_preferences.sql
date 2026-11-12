-- ZAD_PLAN ١٠.١ الشريحة ٤ (د): تفضيلات البيت لكل صنف — البراند اللي بنجيبه، البراند اللي مابنجيبهوش، واللي اتجاب صدفة.
--
-- المقاس ١٢/١١: مفيش مكان للبراند المفضل أو «اتجاب صدفة ومش هجيبه». العقل كان بيحفظ البراند كملاحظة حرة في
-- zad_memory (سكوب brand_preference) وعروض الصبح بتقراها — وعلى الحي **صفر** ملاحظات بالسكوب ده. وملاحظة حرة
-- مابتتطابقش بصنف، ومفيش فيها «مرفوض» ولا «صدفة».
--
-- ده جدول مسطّح (صنف × نوع × براند)، مش جراف معرفة (EPIC_1_4 رفض الجراف؛ ZAD_LIVING_BRAIN الكيانات في
-- zad_memory) — الكود بيطابق عليه بالمفتاح زي ما بيطابق صفوف المخزن.
--   • preferred_brand: براند واحد لكل صنف في البيت؛ التسجيل بيشيل أي «مفضل» تاني لنفس الصنف وأي «مرفوض» لنفس البراند.
--   • rejected_brand: براند مابنجيبهوش (أكتر من واحد لكل صنف)؛ بيشيل «مفضل» بنفس البراند.
--   • accidental: الصنف اتجاب مرة صدفة ومش هيتجاب تاني ⇒ صفوفه في مخزن البيت بتتعلّم «على فترات» (restock_mode =
--     occasional): مابتدخلش النواقص ولا قايمة الشرا ولا سؤال «هل خلص؟».
-- الصف بيشيل family_id ساعة الكتابة، والبيت كله بيقراه. الكتابة من الدوال بس.

create table if not exists public.zad_item_preferences (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  family_id uuid,
  item_name text not null check (char_length(btrim(item_name)) between 1 and 80),
  item_key text not null check (char_length(item_key) between 1 and 80),
  kind text not null check (kind in ('preferred_brand', 'rejected_brand', 'accidental')),
  brand text check (brand is null or char_length(btrim(brand)) between 1 and 60),
  created_at timestamptz not null default now(),
  constraint zad_item_preferences_brand_kind check ((kind = 'accidental') = (brand is null))
);

create unique index if not exists zad_item_preferences_one
  on public.zad_item_preferences (user_id, item_key, kind, lower(coalesce(brand, '')));
create index if not exists zad_item_preferences_family on public.zad_item_preferences (family_id) where family_id is not null;

alter table public.zad_item_preferences enable row level security;
revoke all on table public.zad_item_preferences from anon, authenticated;
grant select on table public.zad_item_preferences to authenticated;
grant all on table public.zad_item_preferences to service_role;

drop policy if exists zad_item_preferences_home_reads on public.zad_item_preferences;
create policy zad_item_preferences_home_reads on public.zad_item_preferences for select to authenticated
  using (user_id = (select auth.uid())
         or (family_id is not null and family_id in (select public.get_my_family_ids())));

comment on table public.zad_item_preferences is
  'ZAD_PLAN 10.1 slice 4d — per item: the brand the home buys, brands it does not, and items bought once by accident. Written through zad_set_item_preference / zad_clear_item_preference only.';

/**
 * يسجّل تفضيل. [p_user] للسيرفر (العقل بـservice role)؛ من التطبيق بيبقى null أو نفس المستخدم.
 * بيرجّع {ok, id} أو {ok:false, reason}.
 */
create or replace function public.zad_set_item_preference(
  p_item text, p_kind text, p_brand text default null, p_user uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := coalesce(auth.uid(), p_user);
  v_item text := btrim(regexp_replace(coalesce(p_item, ''), '\s+', ' ', 'g'));
  v_brand text := nullif(btrim(regexp_replace(coalesce(p_brand, ''), '\s+', ' ', 'g')), '');
  v_key text;
  v_family uuid;
  v_id uuid;
  v_marked int := 0;
begin
  if v_user is null then
    raise exception 'not_authenticated';
  end if;
  if auth.uid() is not null and p_user is not null and p_user <> auth.uid() then
    raise exception 'not_authorized';
  end if;
  if p_kind is null or p_kind not in ('preferred_brand', 'rejected_brand', 'accidental') then
    return jsonb_build_object('ok', false, 'reason', 'bad_kind');
  end if;
  if char_length(v_item) not between 1 and 80 then
    return jsonb_build_object('ok', false, 'reason', 'bad_item');
  end if;
  if p_kind = 'accidental' then
    v_brand := null;
  elsif v_brand is null or char_length(v_brand) > 60 then
    return jsonb_build_object('ok', false, 'reason', 'brand_needed');
  end if;

  v_key := public.zad_inventory_name_key(v_item);
  if v_key = '' then
    return jsonb_build_object('ok', false, 'reason', 'bad_item');
  end if;
  select m.family_id into v_family from public.family_members m where m.user_id = v_user limit 1;

  -- واحد بيلغي التاني: مفضل واحد لكل صنف، ونفس البراند مايبقاش مفضل ومرفوض.
  if p_kind = 'preferred_brand' then
    delete from public.zad_item_preferences p
     where p.item_key = v_key
       and (p.user_id = v_user or (v_family is not null and p.family_id = v_family))
       and (p.kind = 'preferred_brand' or (p.kind = 'rejected_brand' and lower(p.brand) = lower(v_brand)));
  elsif p_kind = 'rejected_brand' then
    delete from public.zad_item_preferences p
     where p.item_key = v_key and p.kind = 'preferred_brand' and lower(p.brand) = lower(v_brand)
       and (p.user_id = v_user or (v_family is not null and p.family_id = v_family));
  end if;

  insert into public.zad_item_preferences (user_id, family_id, item_name, item_key, kind, brand)
  values (v_user, v_family, v_item, v_key, p_kind, v_brand)
  on conflict (user_id, item_key, kind, lower(coalesce(brand, '')))
    do update set item_name = excluded.item_name, family_id = excluded.family_id, created_at = now()
  returning id into v_id;

  if p_kind = 'accidental' then
    update public.zad_inventory i set restock_mode = 'occasional'
     where public.zad_inventory_name_key(i.item_name) = v_key
       and (i.user_id = v_user or (v_family is not null and i.family_id = v_family))
       and i.restock_mode is distinct from 'occasional';
    get diagnostics v_marked = row_count;
  end if;

  return jsonb_build_object('ok', true, 'id', v_id, 'marked_occasional', v_marked);
end;
$$;

revoke all on function public.zad_set_item_preference(text, text, text, uuid) from public, anon;
grant execute on function public.zad_set_item_preference(text, text, text, uuid) to authenticated, service_role;

/** يشيل تفضيل كتبه المستخدم ده (أو أي فرد في بيته). «صدفة» اللي اتشالت مابترجّعش restock_mode — ده قرار العميل لوحده. */
create or replace function public.zad_clear_item_preference(p_id uuid, p_user uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := coalesce(auth.uid(), p_user);
  v_family uuid;
  v_n int;
begin
  if v_user is null then
    raise exception 'not_authenticated';
  end if;
  if auth.uid() is not null and p_user is not null and p_user <> auth.uid() then
    raise exception 'not_authorized';
  end if;
  select m.family_id into v_family from public.family_members m where m.user_id = v_user limit 1;
  delete from public.zad_item_preferences p
   where p.id = p_id
     and (p.user_id = v_user or (v_family is not null and p.family_id = v_family));
  get diagnostics v_n = row_count;
  return jsonb_build_object('ok', v_n > 0);
end;
$$;

revoke all on function public.zad_clear_item_preference(uuid, uuid) from public, anon;
grant execute on function public.zad_clear_item_preference(uuid, uuid) to authenticated, service_role;
