-- إيقاع النوم (ZAD_LIVING_BRAIN.md الشريحة ٧ = ٣٧ في §١٠، قرار المالك ٢٠٢٦-١٠-٠٣).
--
-- «أوقات الخمول وقفل الشاشة هي المصدر الأساسي (من غير ما تزعج)، وHealth Connect اختياري، وتحديد يدوي في الملف الشخصي».
-- الموبايل بيحسب نافذة النوم من لحظات قفل/فتح الشاشة (`sleep_window.dart`) وبيبعت **النتيجة بس**: ساعة النوم وساعة الصحيان
-- وعدد الليالي — مفيش لحظات ولا خط زمني. العميل يقدر يحددها بنفسه من الشات (`set_sleep_window`)، واليدوي بيكسب:
-- التعلّم مابيكتبش فوقه.
--
-- السيرفر بيستخدمها لساعات الهدوء (zad-brain/shared.ts quietWindowOf) بدل ١١–٧ الثابتة: المهام الاستباقية ولحظات الصوت
-- بتستنى صحيانه هو. الحدود: النوم من ٨ بالليل لـ٣ الفجر، والصحيان من ٤ لـ١٢ الضهر — برّه كده (شغل ليلي، موبايل سايب) مش
-- بيتخزن، والهدوء الافتراضي يفضل.
-- رقم الإصدار مش على ساعة مدوّرة عن قصد (تصادمين ٢٠٢٦-١٠-٠٥).

alter table public.zad_users
  add column if not exists sleep_bed time,
  add column if not exists sleep_wake time,
  add column if not exists sleep_nights smallint,
  add column if not exists sleep_source text,
  add column if not exists sleep_updated_at timestamptz;

alter table public.zad_users drop constraint if exists zad_users_sleep_source_check;
alter table public.zad_users add constraint zad_users_sleep_source_check
  check (sleep_source is null or sleep_source in ('learned', 'manual'));

-- p_source: 'learned' (الموبايل) أو 'manual' (العميل) أو 'clear' (يمسح) أو 'clear_learned' (العميل قفل التعلّم من قفل الشاشة:
-- يمسح المتعلّم بس، واليدوي يفضل). المتعلّم مابيكتبش فوق اليدوي.
create or replace function public.zad_set_sleep_window(p_bed time, p_wake time, p_nights int, p_source text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_current text;
begin
  if v_uid is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if p_source = 'clear_learned' then
    update public.zad_users
      set sleep_bed = null, sleep_wake = null, sleep_nights = null, sleep_source = null, sleep_updated_at = now()
      where id = v_uid and sleep_source = 'learned';
    return jsonb_build_object('ok', true, 'cleared', found);
  end if;
  if p_source = 'clear' then
    update public.zad_users
      set sleep_bed = null, sleep_wake = null, sleep_nights = null, sleep_source = null, sleep_updated_at = now()
      where id = v_uid;
    return jsonb_build_object('ok', true, 'cleared', true);
  end if;
  if p_source is null or p_source not in ('learned', 'manual') or p_bed is null or p_wake is null then
    return jsonb_build_object('ok', false, 'reason', 'invalid_input');
  end if;
  if not (p_bed >= time '20:00' or p_bed <= time '03:00') or p_wake not between time '04:00' and time '12:00' then
    return jsonb_build_object('ok', false, 'reason', 'out_of_range');
  end if;
  select sleep_source into v_current from public.zad_users where id = v_uid;
  if p_source = 'learned' and v_current = 'manual' then
    return jsonb_build_object('ok', true, 'kept', 'manual');
  end if;
  update public.zad_users
    set sleep_bed = p_bed, sleep_wake = p_wake,
        sleep_nights = case when p_source = 'learned' then least(greatest(coalesce(p_nights, 0), 0), 31) end,
        sleep_source = p_source, sleep_updated_at = now()
    where id = v_uid;
  return jsonb_build_object('ok', true, 'source', p_source);
end;
$$;

revoke all on function public.zad_set_sleep_window(time, time, int, text) from public, anon;
grant execute on function public.zad_set_sleep_window(time, time, int, text) to authenticated;
