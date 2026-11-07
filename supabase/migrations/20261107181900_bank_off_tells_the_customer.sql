-- قراءة البنك وقفت ⇒ العميل يعرف على طول، مش بعد ٣ أيام (طلب المالك ٧/١١: «والبوت يبعتلهم»).
--
-- قبل كده: `listener_gap_alert` بيطلع بس لو العميل سجّل حركتين بإيده في ٣ أيام والرصد صفر — يعني اللي بيعتمد على
-- القراية التلقائية (المفروض الكل) عمره ما بيتنبّه. الموبايل نفسه بيقول بالظبط إمتى القراية وقفت: `bank.off`
-- (الصلاحية اتشالت) و`bank.stalled` (الخدمة ساكتة ١٢ ساعة — kListenerStallAfter بعد ٧/١١) في zad_product_events
-- لما التطبيق يتفتح (مرة كل ١٢ ساعة لكل حالة بالكتير).
--
-- التريجر بيحوّل الحدث ده لمهمة `listener_gap_alert` (نفس النوع: صوت «قلقان» وعنوان «زاد لاحظ إن إشعارات البنك وقفت»
-- والمعالج اللي بيوصّلها تليجرام/التطبيق). واحدة في اليوم بالكتير (فهرس idx_agent_tasks_proactive_dedup)، وأي
-- خطأ هنا مايوقعش تسجيل الحدث نفسه. الكلام من غير أي حاجة من رسايل العميل.

create or replace function public.zad_bank_off_tells()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.user_id is null or new.name not in ('bank.off', 'bank.stalled') then
    return new;
  end if;
  begin
    insert into public.agent_tasks (user_id, kind, task_description, scheduled_for)
    values (
      new.user_id,
      'listener_gap_alert',
      case new.name
        when 'bank.off' then
          $t$[مهم: قراءة رسايل البنك وقفت] صلاحية «الوصول للإشعارات» بتاعة زاد اتشالت من الموبايل، فمصاريفك ورصيدك مش بيتحدّثوا لوحدهم.

الحل في دقيقة: افتح زاد ← البانر الأصفر فوق في الرئيسية ← فعّل زاد في الصفحة اللي هتفتح.
على شاومي: كمان الإعدادات ← التطبيقات ← زاد ← التشغيل التلقائي ✅ وتوفير البطارية «بلا قيود».$t$
        else
          $t$[مهم: قراءة رسايل البنك وقفت] زاد ماسمعش ولا إشعار من موبايلك من أكتر من ١٢ ساعة — الغالب إن الموبايل قفل زاد في الخلفية عشان البطارية، فأي دفعة دلوقتي مش هتتسجل.

الحل: افتح زاد ← البانر الأصفر فوق في الرئيسية ← اطفي زاد وشغّله تاني في الصفحة اللي هتفتح.
على شاومي: الإعدادات ← التطبيقات ← زاد ← التشغيل التلقائي ✅ وتوفير البطارية «بلا قيود»، وثبّت زاد في التطبيقات الأخيرة 🔒.$t$
      end,
      now()
    );
  exception when unique_violation then
    null; -- اتبعتت النهارده خلاص
  when others then
    raise warning 'zad_bank_off_tells: %', sqlerrm;
  end;
  return new;
end;
$$;

revoke all on function public.zad_bank_off_tells() from public, anon, authenticated;

drop trigger if exists zad_bank_off_tells on public.zad_product_events;
create trigger zad_bank_off_tells
  after insert on public.zad_product_events
  for each row
  when (new.name in ('bank.off', 'bank.stalled'))
  execute function public.zad_bank_off_tells();
