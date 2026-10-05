-- أجواء المناسبات: بانر وألوان وبادج لكل مناسبة، حسب البلد واللهجة (طلب المالك ٢٠٢٦-١٠-٠٤).
--
-- الجدول بيتعدّل من اللوحة من غير APK جديد. التطبيق بيقرا الصفوف الشغالة كلها (عددهم قليل)،
-- بيخزّنها، ويختار الحملة بنفسه بتاريخ النهارده بتوقيت سوق الحساب — كده البانر يطلع أوفلاين،
-- ويبدأ في يومه حتى من غير شبكة. مفيش موديل في الطريق خالص.
--
-- قرارات المالك في نفس اليوم:
--  * زرار البانر بيبعت أمر للعقل (cta_prompt) — مش اشتراك. Play Billing مش شغال على الـAPK
--    المتسطّب (قرار ٢٠٢٦-٠٩-٢١: مفيش Play Console)، فدعوة البريميوم والخصم مستنيين Play.
--    عشان كده مفيش عمود خصم: الخصم لما ييجي يتقري من Play نفسه، مش من رقم مكتوب بإيد هنا
--    (رقم في البانر مختلف عن اللي العميل بيدفعه = تسعير مضلِّل).
--  * الهالوين وراس السنة لكل البلاد.
--
-- النافذة نوعين بالظبط (القيد app_campaigns_one_window):
--  * from_md / to_md: تاريخ ميلادي بيتكرر كل سنة، 'MM-DD'، وممكن يلف على السنة (12-28 → 01-03).
--  * season_slug: موسم هجري، شبابيكه في seasonal_event_windows (المواسم العامة، family_id null).
--    التواريخ الهجرية مابتتكتبش بإيد هنا؛ لما السنة مالهاش شباك هناك، الحملة مابتطلعش.
--
-- اللهجة بنفس أكواد zad_customer_profile.dialect. null = النسخة الافتراضية لأي لهجة.
-- الألوان لازم تبقى غامقة كفاية للكلام الأبيض؛ التطبيق بيرجع للون زاد العادي لو مش كده.

create table if not exists public.app_campaigns (
  id uuid primary key default gen_random_uuid(),
  event_key text not null check (event_key ~ '^[a-z0-9_]{2,40}$'),
  target_country text check (target_country is null or target_country ~ '^[A-Z]{2}$'),
  dialect text check (dialect is null or dialect in
    ('EG', 'SA', 'GULF', 'LEVANT', 'IQ', 'MA', 'TN', 'DZ', 'LY', 'SD', 'YE', 'TR', 'EN')),
  from_md text check (from_md is null or from_md ~ '^(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$'),
  to_md text check (to_md is null or to_md ~ '^(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$'),
  season_slug text check (season_slug is null or season_slug in
    ('ramadan', 'eid_al_fitr', 'eid_al_adha', 'back_to_school')),
  theme_primary text not null check (theme_primary ~ '^#[0-9A-Fa-f]{6}$'),
  theme_secondary text not null check (theme_secondary ~ '^#[0-9A-Fa-f]{6}$'),
  badge text not null default '' check (char_length(badge) <= 16),
  lottie_badge_url text check (lottie_badge_url is null or lottie_badge_url ~ '^https://'),
  particles text not null default 'none' check (particles in ('none', 'snow', 'confetti', 'sparkle')),
  banner_title text not null check (char_length(banner_title) between 1 and 80),
  banner_body text not null check (char_length(banner_body) between 1 and 240),
  cta_text text not null check (char_length(cta_text) between 1 and 40),
  cta_prompt text not null check (char_length(cta_prompt) between 1 and 400),
  priority int not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint app_campaigns_one_window check (
    (from_md is not null and to_md is not null and season_slug is null)
    or (from_md is null and to_md is null and season_slug is not null)
  )
);

-- نسخة واحدة لكل مناسبة × بلد × لهجة، عشان الاختيار مايبقاش عشوائي بين نسختين.
create unique index if not exists app_campaigns_one_variant
  on public.app_campaigns (event_key, coalesce(target_country, '*'), coalesce(dialect, '*'));

alter table public.app_campaigns enable row level security;

-- القراءة: أي حد مسجّل دخول، الحملات الشغالة بس (المسودات مستخبية). الكتابة: مفيش سياسة،
-- يعني service-role واللوحة بس.
drop policy if exists app_campaigns_read on public.app_campaigns;
create policy app_campaigns_read on public.app_campaigns
  for select to authenticated using (is_active);

comment on table public.app_campaigns is
  'أجواء المناسبات: بانر وألوان وبادج، حسب البلد واللهجة. الكتابة من اللوحة بس. الزرار أمر للعقل (cta_prompt).';

-- البذرة. on conflict do nothing: اللي اتعدّل من اللوحة مايرجعش لأصله لو الميجريشن اتعادت.
insert into public.app_campaigns
  (event_key, target_country, dialect, from_md, to_md, season_slug, theme_primary, theme_secondary,
   badge, particles, banner_title, banner_body, cta_text, cta_prompt, priority)
values
  -- عالمي
  ('halloween', null, null, '10-25', '10-31', null, '#4C1D95', '#9A3412', '🎃', 'sparkle',
   'متخليش مصاريف البيت تخوّفك 🎃',
   'في الهالوين، زاد يطلّعلك المصاريف اللي بتاكل ميزانيتك من غير ما تحس.',
   'اكشفلي المصاريف المخيفة',
   'طلّعلي أكتر ٣ مصاريف بتاكل ميزانيتي الشهر ده من غير ما أحس، وقولي أوفّر منهم إزاي.', 0),
  ('halloween', null, 'GULF', '10-25', '10-31', null, '#4C1D95', '#9A3412', '🎃', 'sparkle',
   'لا تخلي مصاريف البيت تخوفك 🎃',
   'بمناسبة الهالوين، زاد يطلع لك المصاريف اللي تاكل ميزانيتك وانت ما تدري.',
   'طلّع لي المصاريف المخيفة',
   'طلع لي أكثر ٣ مصاريف تاكل ميزانيتي هالشهر وأنا ما أدري، وقول لي كيف أوفر منها.', 0),
  ('white_friday', null, null, '11-20', '11-30', null, '#111827', '#854D0E', '🛍️', 'sparkle',
   'الوايت فرايداي وصل 🛍️',
   'قبل ما العروض تلخبطك، خلّي زاد يحطلك سقف للصرف ويقولك إيه اللي ناقص فعلاً.',
   'جهّزلي ميزانية العروض',
   'الوايت فرايداي بدأ. حطلي سقف صرف للعروض من الميزانية المتاحة، وقولي إيه اللي ناقص في البيت فعلاً عشان مشتريش حاجات ملهاش لازمة.', 0),
  ('white_friday', null, 'GULF', '11-20', '11-30', null, '#111827', '#854D0E', '🛍️', 'sparkle',
   'موسم الخصومات وصل 🛍️',
   'خل زاد يحدد لك سقف للتسوق ويحميك من الهدر قبل لا تغريك العروض.',
   'حدد لي سقف التسوق',
   'موسم الوايت فرايداي بدأ. حدد لي سقف صرف للعروض من الميزانية المتاحة، وقول لي وش الناقص في البيت فعلاً عشان ما أشتري شي ما أحتاجه.', 0),
  ('new_year', null, null, '12-28', '01-03', null, '#1E1B4B', '#854D0E', '🎆', 'snow',
   'سنة جديدة، بداية جديدة 🎆',
   'ابدأ السنة الجديدة بخطة: زاد يرتّبلك أهداف فلوس العيلة للسنة كلها.',
   'جهّزلي خطة السنة',
   'السنة الجديدة داخلة. جهّزلي خطة أهداف مالية للعيلة للسنة الجاية: ادخار، مصاريف كبيرة متوقعة، وحد شهري واقعي.', 0),
  ('new_year', null, 'GULF', '12-28', '01-03', null, '#1E1B4B', '#854D0E', '🎆', 'snow',
   'سنة جديدة وبداية جديدة 🎆',
   'ابدأ السنة بخطة: زاد يرتب لك أهداف فلوس العائلة للسنة كاملة.',
   'جهز لي خطة السنة',
   'السنة الجديدة على الأبواب. جهز لي خطة أهداف مالية للعائلة للسنة الجاية: ادخار، مصاريف كبيرة متوقعة، وحد شهري واقعي.', 0),
  -- وطني
  ('saudi_national_day', 'SA', null, '09-20', '09-24', null, '#006C35', '#0B3D2E', '🇸🇦', 'confetti',
   'دمت يا وطن العطاء 🇸🇦',
   'بمناسبة اليوم الوطني، خل زاد يرتب لك مصاريف الإجازة والطلعات بدون ما تتعب.',
   'رتب لي مصاريف الإجازة',
   'اليوم الوطني والإجازة جاية. رتب لي ميزانية للطلعات والعروض في الإجازة من المتاح عندي بدون ما أتجاوز.', 10),
  ('saudi_founding_day', 'SA', null, '02-20', '02-23', null, '#006C35', '#0B3D2E', '🇸🇦', 'confetti',
   'يوم بدينا 🇸🇦',
   'في يوم التأسيس، زاد يجهز لك ميزانية الطلعات والعزايم بدون هدر.',
   'جهز لي ميزانية الطلعات',
   'يوم التأسيس وإجازته. جهز لي ميزانية للطلعات والعزايم من المتاح عندي بدون هدر.', 10),
  ('uae_union_day', 'AE', null, '11-30', '12-03', null, '#00732F', '#7F1D1D', '🇦🇪', 'confetti',
   'كل عام والإمارات بخير 🇦🇪',
   'بمناسبة عيد الاتحاد، خل زاد يرتب لك مصاريف الإجازة والطلعات بدون ما تتعدى الميزانية.',
   'رتب لي مصاريف الإجازة',
   'إجازة عيد الاتحاد. رتب لي ميزانية للطلعات والعروض من المتاح عندي بدون ما أتعدى.', 10),
  ('egypt_october_6', 'EG', null, '10-04', '10-07', null, '#991B1B', '#111827', '🇪🇬', 'confetti',
   '٦ أكتوبر.. كل سنة ومصر منتصرة 🇪🇬',
   'الإجازة جاية؟ خلّي زاد يقترحلك خروجة حلوة للعيلة على قد الميزانية.',
   'اقترحلي خروجة على قدّي',
   'إجازة ٦ أكتوبر. اقترحلي خروجة حلوة للعيلة على قد الميزانية المتاحة.', 10),
  ('egypt_july_23', 'EG', null, '07-21', '07-24', null, '#991B1B', '#111827', '🇪🇬', 'confetti',
   '٢٣ يوليو.. كل سنة ومصر بخير 🇪🇬',
   'الإجازة جاية؟ خلّي زاد يقترحلك خروجة حلوة للعيلة على قد الميزانية.',
   'اقترحلي خروجة على قدّي',
   'إجازة ٢٣ يوليو. اقترحلي خروجة حلوة للعيلة على قد الميزانية المتاحة.', 10),
  -- ديني (الشبابيك من seasonal_event_windows)
  ('ramadan', null, null, null, null, 'ramadan', '#172554', '#854D0E', '🌙', 'sparkle',
   'رمضان كريم 🌙',
   'زاد يجهّزلك ميزانية رمضان: الياميش والعزومات وزكاة الفطر، من غير ما الشهر يفلت منك.',
   'جهّزلي ميزانية رمضان',
   'رمضان بدأ. جهّزلي ميزانية رمضان من المتاح: الياميش، العزومات، وزكاة الفطر، وقولي أحسب حسابي في إيه.', 20),
  ('ramadan', null, 'GULF', null, null, 'ramadan', '#172554', '#854D0E', '🌙', 'sparkle',
   'رمضان كريم 🌙',
   'زاد يجهز لك ميزانية رمضان: المقاضي والعزايم وزكاة الفطر، بدون ما يفلت منك الشهر.',
   'جهز لي ميزانية رمضان',
   'رمضان بدأ. جهز لي ميزانية رمضان من المتاح: المقاضي، العزايم، وزكاة الفطر، وقول لي وش أحسب حسابه.', 20),
  ('eid_al_fitr', null, null, null, null, 'eid_al_fitr', '#0F766E', '#6D28D9', '🎉', 'confetti',
   'عيد فطر سعيد 🎉',
   'كل سنة وإنت طيب! زاد يرتّبلك العيدية والخروجات من غير ما تقلق.',
   'رتّبلي مصاريف العيد',
   'العيد جه. رتّبلي العيدية والخروجات والعزومات من المتاح عندي.', 20),
  ('eid_al_fitr', null, 'GULF', null, null, 'eid_al_fitr', '#0F766E', '#6D28D9', '🎉', 'confetti',
   'عيدكم مبارك 🎉',
   'كل عام وأنتم بخير! زاد يرتب لك العيادي والطلعات بدون هم.',
   'رتب لي مصاريف العيد',
   'العيد وصل. رتب لي العيادي والطلعات والعزايم من المتاح عندي.', 20),
  ('eid_al_adha', null, null, null, null, 'eid_al_adha', '#065F46', '#92400E', '🐑', 'confetti',
   'عيد أضحى مبارك 🐑',
   'زاد يحسبلك الأضحية والعزومات ويقولك تخزّن اللحمة إزاي صح.',
   'رتّبلي مصاريف العيد',
   'عيد الأضحى. رتّبلي مصاريف الأضحية والعزومات من المتاح، وقولي أخزّن اللحمة إزاي.', 20),
  ('eid_al_adha', null, 'GULF', null, null, 'eid_al_adha', '#065F46', '#92400E', '🐑', 'confetti',
   'عيدكم مبارك 🐑',
   'زاد يحسب لك الأضحية والعزايم ويقول لك كيف تخزن اللحم صح.',
   'رتب لي مصاريف العيد',
   'عيد الأضحى. رتب لي مصاريف الأضحية والعزايم من المتاح، وقول لي كيف أخزن اللحم.', 20),
  ('back_to_school', null, null, null, null, 'back_to_school', '#1E40AF', '#115E59', '🎒', 'sparkle',
   'رجوع المدارس 🎒',
   'زاد يعملّك قايمة تجهيزات المدرسة ويوزّعها على الميزانية.',
   'اعملّي قايمة المدارس',
   'المدارس راجعة. اعملّي قايمة تجهيزات المدرسة للأولاد ووزّعها على الميزانية المتاحة.', 5),
  ('back_to_school', null, 'GULF', null, null, 'back_to_school', '#1E40AF', '#115E59', '🎒', 'sparkle',
   'العودة للمدارس 🎒',
   'زاد يسوي لك قائمة تجهيزات المدرسة ويوزعها على الميزانية.',
   'سو لي قائمة المدارس',
   'المدارس راجعة. سو لي قائمة تجهيزات المدرسة للعيال ووزعها على الميزانية المتاحة.', 5)
on conflict (event_key, coalesce(target_country, '*'), coalesce(dialect, '*')) do nothing;
