-- التسجيل بالكلام مابيندمجش في حركة بنك ليها تاجر (تصحيح 20261102060000، نفس اليوم).
--
-- اتقاس بعد النشر على حساب المالك: الـ3500 من البنك يوم ١/١١ كان تاجرها «etisalat» (zad_transaction_proposals
-- merchant_name)، و«إيجار شقة 3500» من تليجرام دفعة تانية — تحية آخر اليوم كانت قايلاهم الاتنين. القاعدة اللي
-- اتنشرت الصبح كانت هتدمجهم. صورة الفاتورة غير كده: مبلغ بالقرش + أصناف + نفس اليوم (124.54 «FAWRY*ATARH
-- ALHSN» = «فتح الله العطار») — باب الشرا بيفضل يدمج زي ما هو.
--
-- zad_bank_twin_service (log_transaction من غير أصناف) بقت ترجّع صف البنك بس لو مالوش تاجر، أو تاجره اسم
-- باكدج تطبيق الرسايل (com.google.android.apps.messaging — الإشعار بيكتبه كده، 20261011281730).

create or replace function public.zad_bank_twin_service(p_user uuid, p_amount numeric)
returns uuid
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select t.id
    from public.zad_transactions t
   where t.id = private.zad_bank_twin(p_user, round(p_amount, 2), now())
     and (nullif(btrim(coalesce(t.merchant_name, '')), '') is null
          or t.merchant_name ~ '^[a-z][a-z0-9_]*(\.[a-z0-9_]+)+$');
$$;

revoke all on function public.zad_bank_twin_service(uuid, numeric) from public, anon, authenticated;
grant execute on function public.zad_bank_twin_service(uuid, numeric) to service_role;
