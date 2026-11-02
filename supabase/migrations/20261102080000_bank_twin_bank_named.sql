-- صف البنك اللي تاجره اسم البنك نفسه = مالوش تاجر (تكملة 20261102070000، نفس اليوم).
--
-- بلاغ المالك ٢/١١: الـ3500 يوم ١/١١ كانت تحويل إنستاباي للإيجار، مش etisalat — «etisalat» توقيع شبكة
-- الموبايل في آخر رسالة بنك القاهرة، والموديل خده تاجر (اتصلّح في notificationGate.ts carrierSignOff). من غير
-- طرف، الاقتراح بياخد اسم البنك تاجر («BDC»)، فـ20261102070000 كانت هترفض الدمج مع «إيجار شقة 3500».
-- دلوقتي: تاجر = اسم البنك أو عنوان الصف = زي مالوش تاجر.

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
          or t.merchant_name ~ '^[a-z][a-z0-9_]*(\.[a-z0-9_]+)+$'
          or lower(btrim(t.merchant_name)) = lower(btrim(coalesce(t.bank_name, '')))
          or lower(btrim(t.merchant_name)) = lower(btrim(coalesce(t.title, ''))));
$$;

revoke all on function public.zad_bank_twin_service(uuid, numeric) from public, anon, authenticated;
grant execute on function public.zad_bank_twin_service(uuid, numeric) to service_role;
