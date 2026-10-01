-- =====================================================
-- تنبيه ولي الأمر لما جرعة تفوت فرد من العيلة (قرار المالك، 2026-10-01).
--
-- «ابدأ في تطوير تنبيهات الجرعات الفائتة لولي الأمر». بيشتغل بس لفرد وافق إن الشخص ده يتابع
-- أدويته (zad_family_shares, scope = medicines, granted — 20261001130000)، والاتنين لسه في
-- نفس العيلة.
--
-- لما zad_enqueue_missed_doses تكتب لحظة dose_missed / dose_missed_again للفرد نفسه
-- (ساعة لـ٣ ساعات بعد الميعاد)، الـtrigger ده بيكتب لكل متابع موافَق عليه لحظة
-- family_dose_missed. الحقائق كلها من اللحظة الأصلية (أسماء الأدوية من zad_pharmacy_items
-- زي ما هي)، والـdedupe بلحظة المصدر + المتابع، فالتنبيه مايتكررش.
--
-- التوصيل والصياغة في zad-brain (voiceMoments.ts)، زي أي لحظة: موبايل المتابع وتليجرامه.
-- ولو الفرد خد الجرعة قبل ما التنبيه يطلع، isStillRelevant بتشيله.
-- =====================================================

create or replace function public.zad_family_dose_missed_fanout()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.moment not in ('dose_missed', 'dose_missed_again') then
    return new;
  end if;

  insert into public.zad_voice_moments (user_id, moment, facts, dedupe_key)
  select s.viewer_id,
         'family_dose_missed',
         jsonb_build_object(
           'member_id', s.owner_id,
           'member_alias', coalesce(nullif(btrim(fo.alias), ''), 'فرد من العيلة'),
           'item_name', new.facts->>'item_name',
           'item_ids', coalesce(new.facts->'item_ids', '[]'::jsonb),
           'scheduled_at', new.facts->>'scheduled_at',
           'time_zone', new.facts->>'time_zone',
           'again', new.moment = 'dose_missed_again',
           'source_moment_id', new.id
         ),
         'family_dose_missed:' || new.id || ':' || s.viewer_id
    from public.zad_family_shares s
    join public.family_members fo on fo.user_id = s.owner_id and fo.family_id = s.family_id
    join public.family_members fv on fv.user_id = s.viewer_id and fv.family_id = s.family_id
   where s.owner_id = new.user_id
     and s.scope = 'medicines'
     and s.status = 'granted'
  on conflict (user_id, dedupe_key) do nothing;

  return new;
end $$;

revoke all on function public.zad_family_dose_missed_fanout() from public, anon, authenticated;

drop trigger if exists zad_family_dose_missed_fanout on public.zad_voice_moments;
create trigger zad_family_dose_missed_fanout
  after insert on public.zad_voice_moments
  for each row
  when (new.moment in ('dose_missed', 'dose_missed_again'))
  execute function public.zad_family_dose_missed_fanout();
