-- زاد بيتعلم صيغ رسايل البنوك من العملاء نفسهم (ZAD_PLAN ٢.٣ و٣.١٠، قرار المالك ٢٥/١٠).
--
-- مجموعة الاختبار فيها ٦ رسايل حقيقية بس، ومفيش ولا رسالة سعودية حقيقية، ومش هنقدر نجمع ١٥٠ بإيدينا من كل
-- بنك في كل بلد. كل مرة العميل بيأكد أو يرفض اقتراح جاي من إشعار، ده حكم على صيغة الرسالة دي من البنك ده.
-- هنا الحكم ده بيتحفظ:
-- • zad_bank_template(نص، الطرف التاني) — الصيغة من غير أي رقم ({n}) ولا اسم الطرف التاني ({party})، فوق
--   الحجب اللي اتعمل قبل التخزين ([بطاقة]/[رقم]/[حساب]/[تليفون]/[بريد]، redact.ts). مفيش مبلغ ولا تاريخ ولا اسم.
-- • zad_bank_formats — صيغة لكل (بنك، صيغة)، وسوقها.
-- • zad_bank_format_votes — صوت واحد لكل عميل على كل صيغة (آخر رد يكسب). بيتمسح مع الحساب.
-- • تريجر على zad_transaction_proposals: posted/merged = «فلوس، والنوع ده»، rejected = «لأ». أي غلطة فيه
--   بتتبلع — تأكيد معاملة عمره ما يقف عشان التعلّم.
-- الاستخدام عبر العملاء (البنك ده معروف، الصيغة دي محسومة) بييجي بعدين، ومن عتبة ٣ عملاء مختلفين على نفس
-- الصيغة: صيغة ٣ ناس شافوها هي صيغة بنك، مش رسالة شخصية حد. القراءة service_role بس.

create or replace function public.zad_bank_template(p_text text, p_party text default null)
returns text
language sql
immutable
set search_path to 'public'
as $$
  with t as (
    select translate(coalesce(p_text, ''), '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹', '01234567890123456789') as s
  ), p as (
    select s,
           case when length(btrim(coalesce(p_party, ''))) >= 2
                then regexp_replace(btrim(p_party), '([.*+?^${}()|\[\]\\])', '\\\1', 'g') end as party
      from t
  ), named as (
    select case when party is null then s else regexp_replace(s, party, '{party}', 'gi') end as s from p
  ), handles as (
    -- عنوان إنستاباي (x@instapay) أو بريد = شخص، ولينك = مالوش لازمة في الصيغة.
    select regexp_replace(regexp_replace(s, 'https?://\S+', '{link}', 'gi'), '\S+@\S+', '{party}', 'g') as s from named
  )
  select left(btrim(regexp_replace(regexp_replace(s, '[0-9]+([.,٫٬/:-][0-9]+)*', '{n}', 'g'), '\s+', ' ', 'g')), 400)
    from handles;
$$;

-- البنك: اسم البنك من الاقتراح، إلا لو هو اسم حزمة (تطبيق الرسايل) — ساعتها المرسل (عنوان الإشعار «BDC»).
create or replace function public.zad_bank_sender(p_bank text, p_title text, p_package text)
returns text
language sql
immutable
set search_path to 'public'
as $$
  select left(lower(btrim(coalesce(
    case when btrim(coalesce(p_bank, '')) ~ '^[A-Za-z0-9_]+(\.[A-Za-z0-9_]+)+$' then null else nullif(btrim(p_bank), '') end,
    nullif(btrim(p_title), ''),
    p_package))), 80);
$$;

-- تطبيقات الشات مش قناة بنك: رسايل الجروبات وبوت زاد نفسه اتلقطوا من تليجرام (مقاس ٢٥/١٠) — مابيتعلمش منهم.
create or replace function public.zad_bank_learnable(p_package text, p_text text)
returns boolean
language sql
immutable
set search_path to 'public'
as $$
  select coalesce(p_package, '') !~* '(telegram|challegram|whatsapp|facebook\.orca|instagram|signal|viber|discord|slack)'
     and coalesce(p_text, '') !~* 'ZadSmartBot';
$$;

create table if not exists public.zad_bank_formats (
  id bigint generated always as identity primary key,
  sender text not null,
  template text not null,
  market text,
  first_seen timestamptz not null default now(),
  last_seen timestamptz not null default now(),
  unique (sender, template)
);

create table if not exists public.zad_bank_format_votes (
  format_id bigint not null references public.zad_bank_formats(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  verdict text not null check (verdict in ('money', 'not_money')),
  txn_kind text check (txn_kind in ('expense', 'income', 'transfer')),
  voted_at timestamptz not null default now(),
  primary key (format_id, user_id)
);

alter table public.zad_bank_formats enable row level security;
alter table public.zad_bank_format_votes enable row level security;
revoke all on public.zad_bank_formats, public.zad_bank_format_votes from anon, authenticated;
grant all on public.zad_bank_formats, public.zad_bank_format_votes to service_role;

create or replace function public.zad_bank_format_learn()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_event record;
  v_sender text;
  v_template text;
  v_market text;
  v_format bigint;
begin
  begin
    select package_name, title, body into v_event
      from zad_notification_ingest_events where id = new.source_event_id;
    if v_event is null or coalesce(v_event.body, '') = ''
       or not zad_bank_learnable(v_event.package_name, coalesce(v_event.title, '') || ' ' || v_event.body) then
      return new;
    end if;
    v_sender := zad_bank_sender(new.bank_name, v_event.title, v_event.package_name);
    v_template := zad_bank_template(btrim(coalesce(v_event.title, '') || ' ' || v_event.body), new.merchant_name);
    if v_sender is null or length(v_template) < 8 then
      return new;
    end if;
    select country into v_market from zad_users where id = new.user_id;

    insert into zad_bank_formats (sender, template, market)
    values (v_sender, v_template, v_market)
    on conflict (sender, template) do update set last_seen = now(), market = coalesce(zad_bank_formats.market, excluded.market)
    returning id into v_format;

    insert into zad_bank_format_votes (format_id, user_id, verdict, txn_kind)
    values (v_format, new.user_id,
            case when new.status = 'rejected' then 'not_money' else 'money' end,
            case when new.status = 'rejected' then null else new.txn_kind end)
    on conflict (format_id, user_id) do update
      set verdict = excluded.verdict, txn_kind = excluded.txn_kind, voted_at = now();
  exception when others then
    raise warning 'zad_bank_format_learn skipped: % (%)', sqlerrm, sqlstate;
  end;
  return new;
end;
$$;

revoke all on function public.zad_bank_format_learn() from public, anon, authenticated;

drop trigger if exists zad_bank_format_learn on public.zad_transaction_proposals;
create trigger zad_bank_format_learn
  after update of status on public.zad_transaction_proposals
  for each row
  when (new.source_type = 'notification_listener'
        and new.status in ('posted', 'merged', 'rejected')
        and old.status is distinct from new.status)
  execute function public.zad_bank_format_learn();

-- ما اتعلم لحد دلوقتي: لكل بنك، الصيغ وكام عميل مختلف حكم عليها وبإيه. «agreed» = ٣ عملاء أو أكتر و٩٠٪ اتفاق.
create or replace function public.zad_bank_formats_learned(p_min_users int default 3)
returns table (sender text, market text, template text, users int, money int, not_money int, top_kind text, agreed boolean)
language sql
stable
security definer
set search_path to 'public'
as $$
  select f.sender, f.market, f.template,
         count(*)::int,
         count(*) filter (where v.verdict = 'money')::int,
         count(*) filter (where v.verdict = 'not_money')::int,
         mode() within group (order by v.txn_kind),
         count(*) >= p_min_users
           and greatest(count(*) filter (where v.verdict = 'money'), count(*) filter (where v.verdict = 'not_money')) >= 0.9 * count(*)
    from zad_bank_formats f join zad_bank_format_votes v on v.format_id = f.id
   group by f.id
   order by count(*) desc, f.last_seen desc;
$$;

revoke all on function public.zad_bank_formats_learned(int) from public, anon, authenticated;
grant execute on function public.zad_bank_formats_learned(int) to service_role;

-- اللي اتحكم عليه قبل كده بيدخل كمان (المالك والحساب التجريبي النهارده).
insert into public.zad_bank_formats (sender, template, market, first_seen, last_seen)
select distinct on (s.sender, s.template) s.sender, s.template, s.market, s.at, s.at
  from (
    select public.zad_bank_sender(p.bank_name, e.title, e.package_name) as sender,
           public.zad_bank_template(btrim(coalesce(e.title, '') || ' ' || e.body), p.merchant_name) as template,
           u.country as market, p.updated_at as at
      from public.zad_transaction_proposals p
      join public.zad_notification_ingest_events e on e.id = p.source_event_id
      left join public.zad_users u on u.id = p.user_id
     where p.source_type = 'notification_listener' and p.status in ('posted', 'merged', 'rejected')
       and coalesce(e.body, '') <> ''
       and public.zad_bank_learnable(e.package_name, coalesce(e.title, '') || ' ' || e.body)
  ) s
 where s.sender is not null and length(s.template) >= 8
 order by s.sender, s.template, s.at desc
on conflict (sender, template) do nothing;

insert into public.zad_bank_format_votes (format_id, user_id, verdict, txn_kind, voted_at)
select distinct on (f.id, p.user_id) f.id, p.user_id,
       case when p.status = 'rejected' then 'not_money' else 'money' end,
       case when p.status = 'rejected' then null else p.txn_kind end,
       p.updated_at
  from public.zad_transaction_proposals p
  join public.zad_notification_ingest_events e on e.id = p.source_event_id
  join public.zad_bank_formats f
    on f.sender = public.zad_bank_sender(p.bank_name, e.title, e.package_name)
   and f.template = public.zad_bank_template(btrim(coalesce(e.title, '') || ' ' || e.body), p.merchant_name)
  join auth.users au on au.id = p.user_id
 where p.source_type = 'notification_listener' and p.status in ('posted', 'merged', 'rejected')
 order by f.id, p.user_id, p.updated_at desc
on conflict (format_id, user_id) do nothing;
