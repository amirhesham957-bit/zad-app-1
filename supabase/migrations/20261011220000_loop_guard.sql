-- حارس الدورة وحارس القناة (الموجة ٧، ٢٠٢٦-١٠-١١).
--
-- فحص ما قبل الإطلاق لقى كسور في الدورة ماكانش حد هيشوفها: price_index صفر صف لأن الفواتير مابتبلّغش،
-- وأسطر في القايمة مفتوحة بعد ما الحاجة اتشترت، و١٩ رسالة صبح ومسا في أسبوع اتصاغت ومالقتش قناة. الموجة ٥
-- قفلت اللي اتلاقى؛ الحارس ده بيقول لو حاجة منهم رجعت — قبل ما العميل يلاحظ.
--
-- zad_loop_guard() — كل يوم (الكرون تحت)، SQL بس، صفر نداءات موديل. بيعدّ:
--   receipt_without_prices — فاتورة باسم محل (source_type = receipt) آخر ٧ أيام، صاحبها عنده عملة، ومفيش ولا
--     بلاغ سعر منه بنفس اسم المحل بعد تاريخ الفاتورة بيوم. (تاريخ الفاتورة هو المطبوع، مش وقت التصوير.)
--   bought_not_ticked — سطر مفتوح في قايمة البيت، وحد في البيت اشترى نفس الصنف (ملاحظة شرا/كاميرا/شات)
--     بعد ما السطر اتضاف، آخر ٤٨ ساعة.
--   composed_then_wasted — لحظة اتصاغت (نداء موديل) ومالقتش قناة توصل منها، آخر ٢٤ ساعة.
--   stuck_tasks — مهام استباقية لسه pending بعد ٢٤ ساعة.
-- النتيجة صف واحد في اليوم في zad_brain_health_alerts (kind = loop_break)، وتنبيه لشات الأدمن مرة في اليوم
-- لو فيه أي كسر (zad_notify_admin — شات الأدمن بس، مش شات عميل).
--
-- حارس القناة جوه نفس اللفة: حساب مالوش توكن موبايل ولا تليجرام مربوط، وتحية اتمسكت عنه آخر ٣ أيام لأنه
-- مالوش قناة ⇒ إشعار جوه التطبيق (مركز الإشعارات) مرة في الأسبوع بالكتير: «فعّل الإشعارات أو اربط تليجرام».
-- ده الطريق الوحيد اللي يوصله — هيشوفه أول ما يفتح التطبيق.

create or replace function public.zad_loop_guard(p_now timestamptz default now())
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_receipts int;
  v_unticked int;
  v_wasted int;
  v_stuck int;
  v_nudged int;
  v_total int;
  v_first boolean;
  v_summary text;
begin
  select count(*) into v_receipts
    from public.zad_transactions t
    join public.zad_users u on u.id = t.user_id
   where t.source_type = 'receipt'
     and nullif(btrim(t.merchant_name), '') is not null
     and t.created_at > p_now - interval '7 days'
     and nullif(btrim(u.currency), '') is not null
     and not exists (
       select 1 from public.price_index p
        where p.user_id = t.user_id and p.source = 'crowdsource'
          and lower(btrim(coalesce(p.store_name, ''))) = lower(btrim(t.merchant_name))
          and p."timestamp" > t.created_at - interval '1 day'
     );

  select count(distinct s.id) into v_unticked
    from public.zad_shopping_list s
    join public.zad_inventory_observations o
      on public.zad_inventory_name_key(o.item_name) = public.zad_inventory_name_key(s.item_name)
     and (o.user_id = s.user_id
          or (s.family_id is not null and o.user_id in
                (select m.user_id from public.family_members m where m.family_id = s.family_id)))
   where not coalesce(s.is_purchased, false)
     and o.source in ('purchase', 'camera_ocr', 'chat_add')
     and o.observed_at > s.created_at
     and o.observed_at > p_now - interval '48 hours';

  select count(*) into v_wasted
    from public.zad_voice_moments v
   where v.status = 'failed' and v.error = 'no channel delivered'
     and v.created_at > p_now - interval '24 hours';

  select count(*) into v_stuck
    from public.agent_tasks t
   where t.status = 'pending' and t.created_at < p_now - interval '24 hours';

  -- حارس القناة.
  with silent as (
    select distinct v.user_id
      from public.zad_voice_moments v
     where v.error like 'no channel%'
       and v.created_at > p_now - interval '3 days'
       and not exists (select 1 from public.zad_fcm_tokens f where f.user_id = v.user_id)
       and not exists (select 1 from public.telegram_bindings b where b.user_id = v.user_id and b.bound_at is not null)
       and not exists (
         select 1 from public.app_notifications n
          where n.user_id = v.user_id and n.title = 'زاد مش قادر يوصلك'
            and n.created_at > p_now - interval '7 days')
       and exists (select 1 from auth.users a where a.id = v.user_id)
  ), ins as (
    insert into public.app_notifications (user_id, title, message, is_read)
    select user_id, 'زاد مش قادر يوصلك',
           'كان عندي ليك تحية الصبح وتذكيرات، ومالقتش طريق أوصلك بيه. فعّل الإشعارات من إعدادات الموبايل، '
             || 'أو اربط تليجرام من «ملفي»، وأنا هوصلك في وقتك.',
           false
      from silent
    returning 1
  )
  select count(*) into v_nudged from ins;

  v_total := v_receipts + v_unticked + v_wasted + v_stuck;
  v_summary := format('فواتير من غير أسعار %s · مشترى ولسه في القايمة %s · رسايل اتصاغت ومالقتش قناة %s · مهام واقفة %s',
                      v_receipts, v_unticked, v_wasted, v_stuck);

  insert into public.zad_brain_health_alerts (alert_date, kind, total_runs, bad_runs, bad_pct, top_error)
  values ((p_now at time zone 'UTC')::date, 'loop_break', 4, v_total, 0, left(v_summary, 200))
  on conflict (alert_date, kind) do update
    set bad_runs = excluded.bad_runs, top_error = excluded.top_error
  returning (xmax = 0) into v_first;

  if v_total > 0 and v_first then
    begin
      perform public.zad_notify_admin('🔗 حارس الدورة', v_summary);
    exception when others then
      raise warning 'zad_loop_guard: admin alert failed: %', sqlerrm;
    end;
  end if;

  return jsonb_build_object(
    'receipt_without_prices', v_receipts, 'bought_not_ticked', v_unticked,
    'composed_then_wasted', v_wasted, 'stuck_tasks', v_stuck, 'channel_nudges', v_nudged);
end;
$$;

revoke all on function public.zad_loop_guard(timestamptz) from public, anon, authenticated;
grant execute on function public.zad_loop_guard(timestamptz) to service_role;

-- كل يوم ٥:١٣ بتوقيت جرينتش (بعد التحليل اليومي ٤:٥٣). من غير pg_cron (قاعدة تجربة) بيتخطى.
do $cron$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule('loop-guard-daily') where exists (select 1 from cron.job where jobname = 'loop-guard-daily');
    perform cron.schedule('loop-guard-daily', '13 5 * * *', 'select public.zad_loop_guard()');
  end if;
end
$cron$;
