-- الفواتير في بيت واحد (ZAD_LIVING_BRAIN.md §١١ هـ، قرار المالك ٢٠٢٦-١٠-٠٥: «تنظيف جداول الفواتير المزدوجة»).
--
-- المقاس على الحي: فاتورة الكهربا في `zad_subscriptions` (type=utility، category=فواتير) وفاتورة المية في `zad_obligations`
-- (kind=utility). شاشة «التزاماتي» بتعرض الاتنين جنب بعض، وحساب «الملتزم بيه» في الميزانية بيجمع الجدولين — فنفس الفاتورة لو
-- اتسجلت مرة من شاشة الاشتراكات ومرة من العقل (add_obligation) **بتتحسب مرتين**. والتذكير والبوت ليهم مسارين مختلفين لنفس الحاجة.
--
-- البيت الواحد = `zad_obligations` (kind=utility): فيه يوم الاستحقاق والتكرار والمزوّد، و`zad_obligation_next_due`، و«دفتر الأيام»
-- والميزانية بيقروه، والعقل بيكتبه. الاشتراكات للخدمات الاختيارية (نتفليكس، شاهد).
--
--   ١. نقل مرة واحدة: كل اشتراك شغال هو فاتورة (type utility/bill أو فئته القياسية «الفواتير») بمبلغ وتكرار شهري/سنوي ⇒ التزام
--      utility بنفس الاسم والمبلغ ويوم الاستحقاق، **إلا لو فيه التزام شغال بنفس الاسم** (ده اللي كان هيتحسب مرتين). الاشتراك
--      بيتقفل (is_active=false) مش بيتمسح — التاريخ يفضل.
--   ٢. تريجر: أي كاتب (نسخة قديمة من التطبيق، البوت، أي مسار) يضيف فاتورة في الاشتراكات ⇒ نفس النقل فوراً. النسخة الجديدة من
--      التطبيق بتكتب الفاتورة التزام من الأول.
--   الأسبوعي والمبلغ صفر بيفضلوا زي ما هم: الالتزامات مافيهاش أسبوعي، ومبلغها لازم > ٠.
-- رقم الإصدار بعد كل اللي على الحي ومش على ساعة مدوّرة.

create or replace function public.zad_subscription_is_bill(p_type text, p_category text)
returns boolean language sql immutable set search_path = public as $$
  select coalesce(lower(btrim(p_type)) in ('utility', 'bill'), false)
      or coalesce(public.zad_canonical_category(p_category) = 'الفواتير', false)
$$;

create or replace function public.zad_subscription_to_obligation(p_sub public.zad_subscriptions)
returns boolean language plpgsql security definer set search_path = public as $$
begin
  if not coalesce(p_sub.is_active, false) or coalesce(p_sub.amount, 0) <= 0
     or upper(coalesce(p_sub.billing_cycle, 'MONTHLY')) not in ('MONTHLY', 'YEARLY', 'ANNUAL')
     or not public.zad_subscription_is_bill(p_sub.type, p_sub.category) then
    return false;
  end if;
  if not exists (
    select 1 from public.zad_obligations o
    where o.user_id = p_sub.user_id and coalesce(o.active, false)
      and lower(btrim(o.title)) = lower(btrim(p_sub.title))
  ) then
    insert into public.zad_obligations (user_id, title, amount, kind, recurrence, due_day, provider, confirmed, active, auto_detected)
    values (
      p_sub.user_id, btrim(p_sub.title), p_sub.amount, 'utility',
      case when upper(coalesce(p_sub.billing_cycle, 'MONTHLY')) in ('YEARLY', 'ANNUAL') then 'yearly' else 'monthly' end,
      -- الاشتراكات مافيهاش قيد على اليوم والالتزامات فيها (١..٣١): يوم برّه المدى يبقى «من غير ميعاد» مش خطأ يوقف النقل.
      (select d from (select coalesce(p_sub.due_day, extract(day from public.zad_try_date(p_sub.renewal_date))::int) as d) x
        where d between 1 and 31),
      nullif(btrim(coalesce(p_sub.provider, '')), ''),
      true, true, false
    );
  end if;
  update public.zad_subscriptions set is_active = false where id = p_sub.id;
  return true;
end;
$$;

revoke all on function public.zad_subscription_to_obligation(public.zad_subscriptions) from public, anon, authenticated;

create or replace function public.zad_subscriptions_bills_to_obligations()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform public.zad_subscription_to_obligation(new);
  return null;
end;
$$;

revoke all on function public.zad_subscriptions_bills_to_obligations() from public, anon, authenticated;

drop trigger if exists zad_subscriptions_bills_to_obligations on public.zad_subscriptions;
create trigger zad_subscriptions_bills_to_obligations
  after insert on public.zad_subscriptions
  for each row execute function public.zad_subscriptions_bills_to_obligations();

-- الموجود: مرة واحدة.
select public.zad_subscription_to_obligation(s) from public.zad_subscriptions s
 where coalesce(s.is_active, false) and public.zad_subscription_is_bill(s.type, s.category);
