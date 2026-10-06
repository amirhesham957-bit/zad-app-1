-- =====================================================
-- ذروة المناسبة وموسم الشهر (طلب المالك 2026-10-05: «مستويات الشدة والربط بين المناسبات المتقاربة»).
--
-- ١. peak_md: يوم الذروة جوه نافذة الحملة (٦ أكتوبر جوه ٤–٧، ٣١ أكتوبر جوه ٢٥–٣١). التطبيق
--    بيحسب الشدة منه (campaignIntensity في campaign.dart): يوم الذروة = peak، قبلها أو بعدها بيومين
--    = medium، الباقي = low — وبيكثّف الجسيمات على قدها. null = الشدة من طول النافذة (٣ أيام أو أقل
--    = peak كلها، أطول = medium).
-- ٢. autumn: موسم الشهر كله لكل البلاد (١–٣١ أكتوبر) بأولوية -10، فأي مناسبة تانية بتكسبه في
--    أيامها (٦ أكتوبر لمصر بأولوية 10، الهالوين بـ0) وهو بيملا الباقي بشدة واطية. من غير event_name
--    = من غير عدّاد تنازلي — موسم مش يوم.
-- =====================================================

alter table public.app_campaigns
  add column if not exists peak_md text
    check (peak_md is null or peak_md ~ '^(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$');

comment on column public.app_campaigns.peak_md is
  'يوم الذروة جوه النافذة، MM-DD. التطبيق بيحسب الشدة منه (low/medium/peak). null = من طول النافذة.';

-- الصفوف اللي اتعدّلت من اللوحة مابتتلمسش (peak_md is null بس).
update public.app_campaigns c
set peak_md = p.peak
from (values
  ('egypt_october_6', '10-06'),
  ('egypt_july_23', '07-23'),
  ('saudi_national_day', '09-23'),
  ('saudi_founding_day', '02-22'),
  ('uae_union_day', '12-02'),
  ('halloween', '10-31'),
  ('new_year', '01-01'),
  ('white_friday', '11-27')
) as p(key, peak)
where c.event_key = p.key and c.peak_md is null;

insert into public.app_campaigns
  (event_key, target_country, dialect, from_md, to_md, season_slug, theme_primary, theme_secondary,
   badge, particles, banner_title, banner_body, cta_text, cta_prompt, priority)
values
  ('autumn', null, null, '10-01', '10-31', null, '#7C2D12', '#854D0E', '🍂', 'sparkle',
   'خريف هادي لميزانيتك 🍂',
   'الجو بيتغيّر ومعاه مصاريف البيت — زاد يجهّزك لمصاريف الشتا من دلوقتي.',
   'جهّزني للشتا',
   'إيه المصاريف اللي جاية مع الشتا (لبس، تدفئة، مدارس) وأجنّب لها قد إيه كل شهر من دلوقتي؟', -10),
  ('autumn', null, 'GULF', '10-01', '10-31', null, '#7C2D12', '#854D0E', '🍂', 'sparkle',
   'موسم هادي لميزانيتك 🍂',
   'الموسم يتغيّر ومعه مصاريف البيت — زاد يجهّزك للي جاي من الحين.',
   'جهّزني للي جاي',
   'إيش المصاريف اللي جاية الأشهر الجاية (سفر، مدارس، شتا) وكم أجنّب لها كل شهر من الحين؟', -10)
on conflict (event_key, coalesce(target_country, '*'), coalesce(dialect, '*')) do nothing;
