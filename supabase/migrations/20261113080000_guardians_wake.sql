-- ZAD_PLAN ١٠.٦ «الحراس نايمين» — اتقاس على الحي ١٣/١١ وده اللي كان واقف فعلاً.
--
-- ١) ترشيح «investigate» عمره ما اتعمل. zad_propose_guardians بيدوّر على كسر في الدورة ٣ أيام
--    (alert_date > النهارده − ٣ = النهارده وامبارح وأول امبارح)، وبيتنده من guardian-outcomes-daily
--    الساعة ٠٥:٠٣ UTC، بينما zad_loop_guard بيكتب صف النهارده الساعة ٠٥:١٣. فوقت الترشيح بيلاقي
--    صفين بالكتير ⇒ الشرط «≥ ٣» مستحيل. على الحي: كسر كل يوم من ٣١/١٠ لـ١٣/١١ وصفر ترشيح.
--    التست القديم كان بيحط صف النهارده بنفسه، فماكانش بيشوف المشكلة.
--    الإصلاح: آخر ٣ أيام **كاملة** (النهارده − ٣ … النهارده − ١)، فمابيفرقش الكرون بيجري إمتى.
--
-- ٢) حارس الدورة بيصرخ على حاجة سليمة. «مهام واقفة» = أي pending اتعملت من أكتر من ٢٤ ساعة، من غير
--    ما يبص على scheduled_for. مراجعة الأهداف الأسبوعية (goal_review، ١٠.٢د) بتتعمل pending وميعادها
--    بعد أسبوع ⇒ «مهام واقفة ٢» كل يوم من أسبوعين، والاتنين ميعادهم ١٤ و١٧/١١. إنذار كاذب يومي
--    بيعلّم الأدمن يتجاهل الحارس — ولو (١) اتصلح لوحده كان هيطلّع ترشيح investigate كاذب.
--    الإصلاح: الواقفة = pending وميعادها (scheduled_for، ولو فاضي created_at) فات من أكتر من ٢٤ ساعة.
--
-- ٣) الترشيح المفتوح بيفضل بأرقام يوم ما اتعمل. «سكّت pet_call» اتعمل ٤/١١ بدليل ٢٦ رسالة و٤٪، والحقيقة
--    ١٣/١١ ١٥٧ رسالة و٧٪ رد و٣٪ اتعمل بيها حاجة. الأدمن بيقرر على رقم قديم. الإصلاح: كل ليلة الترشيح
--    المفتوح (proposed بس — المتقرر مايتلمسش) بياخد أرقام آخر ٣٠ يوم.
--
-- اللي اتقاس وطلع سكوته صح (مفيش تعديل): bill_reminder (صفر اشتراكات وصفر التزامات في الداتابيز كلها)،
-- warranty_reminder (جهاز صيانة واحد من غير تاريخ ضمان)، med_followup (الدوا المتكرر الوحيد remaining=0)،
-- habit_budget (١١ مصروف في ٣٠ يوم، مفيش تاجر ٨ أيام)، predicted_shortage (معدل استهلاك واحد معروف)،
-- spend_forecast (الأسبوع مغطّى أو مفيش رصيد). uncategorized_spend طلّع كارت النهارده ٠٥:٠٧.

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

  -- واقفة = ميعادها فات بيوم ولسه pending. مهمة مجدولة لبعدين (goal_review الأسبوعية) مش واقفة.
  select count(*) into v_stuck
    from public.agent_tasks t
   where t.status = 'pending'
     and coalesce(t.scheduled_for, t.created_at) < p_now - interval '24 hours';

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

create or replace function public.zad_propose_guardians(p_now timestamptz default now())
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_new int := 0;
  v_n int;
  v_lines text;
  v_today date := (p_now at time zone 'UTC')::date;
begin
  -- الترشيح المفتوح ياخد أرقام النهارده، عشان الأدمن يقرر على الحقيقة مش على يوم ما اتعمل.
  update public.zad_guardian_proposals p
     set why = format('«%s» اتبعت %s مرة آخر ٣٠ يوم والناس ردت على %s٪ بس — أسكّته عند الكل؟', s.kind, s.delivered, s.reply_pct),
         evidence = p.evidence || jsonb_build_object(
           'delivered', s.delivered, 'replied', s.replied, 'reply_pct', s.reply_pct, 'refreshed_at', p_now)
    from public.zad_guardian_scorecard(30) s
   where p.kind = 'pause_kind' and p.status = 'proposed' and p.subject = s.kind;

  -- pause_kind
  insert into public.zad_guardian_proposals (kind, subject, why, evidence)
  select 'pause_kind', s.kind,
         format('«%s» اتبعت %s مرة آخر ٣٠ يوم والناس ردت على %s٪ بس — أسكّته عند الكل؟', s.kind, s.delivered, s.reply_pct),
         jsonb_build_object('delivered', s.delivered, 'replied', s.replied, 'reply_pct', s.reply_pct)
    from public.zad_guardian_scorecard(30) s
   where s.delivered >= 20 and s.reply_pct < 10
     and s.kind not in ('med_followup', 'bill_reminder')
     and not exists (select 1 from public.zad_guardian_proposals p
                      where p.kind = 'pause_kind' and p.subject = s.kind and p.status in ('proposed', 'approved'))
  on conflict do nothing;
  get diagnostics v_n = row_count;
  v_new := v_new + v_n;

  -- investigate: كسر في الدورة آخر ٣ أيام كاملة. صف النهارده بيتكتب بعد الترشيح (loop-guard-daily ٠٥:١٣)،
  -- فمابيدخلش في العد.
  if (select count(*) from public.zad_brain_health_alerts a
       where a.kind = 'loop_break' and a.bad_runs > 0
         and a.alert_date >= v_today - 3 and a.alert_date < v_today) >= 3
     and not exists (select 1 from public.zad_guardian_proposals p
                      where p.kind = 'investigate' and p.subject = 'loop_break'
                        and (p.status = 'proposed' or p.proposed_at > p_now - interval '7 days')) then
    insert into public.zad_guardian_proposals (kind, subject, why, evidence)
    select 'investigate', 'loop_break',
           'حارس الدورة لقى كسر ٣ أيام ورا بعض — حاجة في الدورة رجعت تتكسر: ' || coalesce(a.top_error, ''),
           jsonb_build_object('last', a.top_error, 'date', a.alert_date)
      from public.zad_brain_health_alerts a
     where a.kind = 'loop_break' and a.alert_date < v_today order by a.alert_date desc limit 1
    on conflict do nothing;
    get diagnostics v_n = row_count;
    v_new := v_new + v_n;
  end if;

  if v_new > 0 then
    select string_agg(format('#%s — %s', p.id, p.why), E'\n' order by p.id) into v_lines
      from public.zad_guardian_proposals p
     where p.status = 'proposed' and p.proposed_at > p_now - interval '1 minute';
    begin
      perform public.zad_notify_admin('🛡️ حراس مرشّحين',
        coalesce(v_lines, '') || E'\n\nالموافقة: zad_guardian_proposal_decide(رقم، true) من الداشبورد.');
    exception when others then
      raise warning 'zad_propose_guardians: admin alert failed: %', sqlerrm;
    end;
  end if;
  return v_new;
end;
$$;

-- create or replace بيحافظ على الصلاحيات، بس نكتبها صريحة: السيرفر بس (زي 20261011220000 و20261011240000).
revoke all on function public.zad_loop_guard(timestamptz) from public, anon, authenticated;
grant execute on function public.zad_loop_guard(timestamptz) to service_role;
revoke all on function public.zad_propose_guardians(timestamptz) from public, anon, authenticated;
grant execute on function public.zad_propose_guardians(timestamptz) to service_role;
