---
title: خريطة رحلة العميل — كل صفحة وكل زرار
date: 2026-11-11
tags:
  - zad/ui
  - zad/plan
aliases:
  - UI_JOURNEY_MAP
  - خريطة الواجهة
related:
  - "[[ZAD_PLAN]]"
  - "[[UI_OVERHAUL_STATUS]]"
  - "[[SESSION_LOG]]"
  - "[[ZAD_BRAIN_PLAN]]"
---

# خريطة رحلة العميل (١٠.٨)

> [!important] الغرض
> نقطة البداية لبند [[ZAD_PLAN]] ١٠.٨ «الواجهة صفحة صفحة وزرار زرار». اتكتبت من قراية الكود يوم ١١/١١
> (`origin/main` عند `0e3e6818`)، **مش من جهاز**. أي رقم «ضغطات» هنا محسوب من الكود؛ يتأكد على المحاكي
> قبل ما شريحة تتقفل. لو الكود والملف ده اختلفوا، الكود هو الصح.

## ١. الهيكل الحالي

### الشريط السفلي (`app/shell/zad_bottom_nav_bar.dart`)

`ZadNavDestination` فيها خمسة: `home`، `money`، `inventory`، `family`، `more`. اللي بيظهر فعلاً:

| المكان | الكبار (`_adultItems`) | وضع الأطفال (`_kidsItems`) |
|---|---|---|
| تاب ١ | الرئيسية (`home`) | الرئيسية |
| تاب ٢ | فلوسي (`money`) | عيلتي (`family`) |
| تاب ٣ | بيتي (`inventory`) | — |
| تاب ٤ | المزيد (`more`) — **مش شاشة**، بيفتح الدرج | — |
| في النص | كاميرا + مايك (`onOpenCamera` / `onOpenVoice`) | — |

يعني **عيلتي مش في شريط الكبار** رغم إن [[ZAD_BRAIN_PLAN]] قرر «أربع تابات: زاد · فلوسي · بيتي · عيلتي»
(✅ `4b98c66`). الكومنت في `ZadNavDestination.family` بيقول صراحة «Not in the adult bar: it opens from the
drawer» — القرار اتعكس بعدها من غير ما الخطة تتحدث.

### الدرج «المزيد» (`app/shell/zad_chrome.dart`)

`zadDrawerEntries` مقسومة لمجموعات (زاد، فلوسي، بيتي، عيلتي، الباقي). `focusDrawer` بيوري بس
`kDrawerAlways` (`home`، `companion`، `assistant`، `budget`، `inventory`، `family`، `notifications`،
`profile`) + اللي العميل لمسه قبل كده + الشاشة الحالية. **كل الباقي مستخبي تحت «كل المزايا»** (ZAD_PLAN ٦.٥).

| id | الاسم | بيفتح إيه | ظاهر من غير «كل المزايا»؟ |
|---|---|---|---|
| `home` | الرئيسية | تاب | ✅ |
| `companion` | رفيق زاد | `showCompanionStudio` | ✅ |
| `assistant` | عقل زاد | `showBrainFamily` (hub العقل) | ✅ |
| `appointments` | المواعيد | `showAppointmentsScreen` | ❌ |
| `places` | أماكني | `showMyPlaces` | ❌ |
| `budget` | فلوسي | تاب | ✅ |
| `subscriptions` | التزاماتي | `showSubscriptionsScreen` | ❌ |
| `premium` | الباقات | `showPaywallScreen` | ❌ |
| `inventory` | بيتي | تاب | ✅ |
| `shopping` | النواقص والتسوق | `showHouseholdSection(shopping)` | ❌ |
| `pharmacy` | الصيدلية | `showHouseholdSection(pharmacy)` | ❌ |
| `maintenance` | الصيانة | `showMaintenanceScreen` | ❌ |
| `documents` | المستندات | `showDocumentsScreen` | ❌ |
| `deals` | عروض قريبة | `showNearbyDealsScreen` (`app/zad_shell.dart` سطر ~295) | ❌ |
| `family` | عيلتي | تاب `family` | ✅ |
| `tasbiha` | السبحة | `showTasbihaScreen` | ❌ |
| `notifications` | الإشعارات | `showNotificationCenter` | ✅ |
| `profile` | حسابي | `showProfileScreen` | ✅ |

### شبكة الأقسام على الرئيسية (`features/home/presentation/sections_grid.dart`)

`zadSections` = ١٨ قسم، وأول `kSectionsCollapsed = 8` بس ظاهرين لحد ما العميل يضغط «المزيد» في الشبكة:

١ المخزن (تاب بيتي) · ٢ النواقص · ٣ المواعيد · ٤ أماكني · ٥ عيلتي · ٦ الميزانية (تاب فلوسي) ·
٧ الاشتراكات · ٨ الصيدلية ‖ (مستخبيين) ٩ السبحة · ١٠ الصيانة · ١١ المستندات · ١٢ رفيق زاد · ١٣ عقل زاد ·
١٤ خريطة المعرفة · ١٥ الإشعارات · ١٦ كشف الحساب · ١٧ الباقات · ١٨ حسابي.

الدرج نفسه فيه كمان `_MoreSheet` بيعرض `zadSections` ناقص `inventory` و`assistant`.

### بيتي (`features/household/presentation/household_screen.dart`)

تاب واحد بأربع تابات جواه: **المخزن · نواقص وتسوق · الصيدلية · وصفات**، وفوق زرار الأسعار
(`showPricesScreen`). يعني الشيف **تاب رابع جوه بيتي**، مش قسم لوحده.

### الشاشات وعمقها (ضغطات من فتح التطبيق، أقصر طريق)

| الشاشة | الملف | أقصر طريق | ضغطات | قايمة؟ |
|---|---|---|---|---|
| الرئيسية | `features/home/presentation/home_screen.dart` | — | ٠ | لا (بلوكات) |
| فلوسي | `features/budget/…` (تاب) | الشريط | ١ | أيوه |
| المخزن | `household_screen` تاب المخزن | الشريط ← بيتي | ١ | أيوه |
| النواقص | `household_screen` تاب نواقص | بيتي ← تاب | ٢ (أو ١ من الشبكة) | أيوه |
| الصيدلية | `household_screen` تاب الصيدلية | بيتي ← تاب، أو مربع الجرعة في `HomeGlanceWidgets` | ١–٢ | أيوه |
| الوصفات (الشيف) | `features/recipes/presentation/recipes_view.dart` | بيتي ← تاب وصفات، أو `HomeChefSection` تحت الرئيسية | ٢ | أيوه |
| الاشتراكات | `features/subscriptions/…` | مربع في `HomeGlanceWidgets` أو الشبكة | ١ | أيوه |
| العروض | `features/nearby/presentation/deals_view.dart` | «كل العروض» في `HomeDealsCarousel` (بيظهر بس لو فيه عروض) أو الدرج ← كل المزايا ← عروض قريبة | ١ لو الكاروسيل ظاهر، وإلا ٣ | أيوه |
| عيلتي | `features/family/presentation/family_screen.dart` | الشبكة (مربع ٥) أو الدرج | ٢ | أيوه (تابات) |
| عقل زاد (hub) | `features/brain_family/presentation/brain_family_screen.dart` | الدرج ← عقل زاد، أو زرار في الشات | ٢ | لا |
| الشات | `features/chat/presentation/chat_screen.dart` | `ShellTab.chat` من الوكيل/الإشعار، أو من الـhub | ٢–٣ | أيوه |
| الذاكرة / سجل الأفعال / صحة العقل / الإنجازات / ادخار العيلة | `brain_family_screen` وجواه | الدرج ← عقل زاد ← زرار | ٣ | أيوه |
| خريطة المعرفة | `showKnowledgeMap` | الشبكة (مستخبي) ← «المزيد» ← المربع | ٣ | لا |
| الأسعار | `showPricesScreen` | بيتي ← أيقونة فوق | ٢ | أيوه |
| المواعيد / أماكني | `showAppointmentsScreen` / `showMyPlaces` | الشبكة | ١ | أيوه |
| الصيانة / المستندات / السبحة | — | الشبكة ← «المزيد» ← المربع | ٢ | أيوه |
| كشف الحساب | `showStatementImportScreen` | الشبكة ← «المزيد»، أو حسابي | ٢–٣ | — |
| فنيين موثوقين | `showTrustedTechnicians` | **من الشات بس** (كارت الطوارئ) | — | أيوه |
| الذكاء (`showIntelligenceScreen`) | — | **من مركز الإشعارات أو أمر الوكيل بس** | ٢+ | — |

## ٢. الرئيسية زي ما هي (من فوق لتحت)

`HomeScreen` = `ListView` واحد، بالترتيب ده بالظبط:

1. `QuietModeBanner` — لو وضع الهدوء شغال.
2. `OccasionCardSlot` — كارت المناسبة.
3. `BirthdayCelebration` — يوم الميلاد بس.
4. `TravelBannerSlot` — لو العميل مسافر.
5. `GroceryPurchasePromptHost` — «اشتريت من …؟ ضيف إيه للمخزن» (بيطلع حوار؛ اتشاف على المحاكي ١١/١١).
6. `HomeOfflineBanner` — من غير نت.
7. `PermissionBanners` — الموقع/الإشعارات (على المحاكي: «موقعك غير مفعّل» واخد ٣ سطور).
8. `ZadSlots.liveMarketTickerSlot()` — شريط الأسعار الحية + «ساهم بسعر» (فاضي = سطر «لسه مفيش أسعار»).
9. `HomeCompanionHeader` — التحية + الصوت + الكاميرا.
10. `_Budget` — كارت الفلوس (فاضي = `ZadEmptyState`).
11. `CampaignBannerSlot` — بانر الحملة.
12. صف: `_TourButton` + `CampaignStoriesStrip`.
13. `FxExcludedNotice`.
14. `HomeGlanceWidgets` — **٣ مربعات: الاشتراك الجاي، الناقص من المخزن، الجرعة الجاية** (ده أقرب حاجة للاختصارات اللي المالك طالبها، وموجود فعلاً).
15. `ZadSlots.homeDealsCarousel()` = `HomeDealsCarousel` — «عروض على نواقصك»، **قايمة رأسي** لحد ٤ كروت (قرار المالك ٦/١١: «قايمة مش شريط جانبي»)، و**مابيظهرش خالص لو مفيش عروض**.
16. `SectionsGrid` — ٨ مربعات + «المزيد».
17. `CloseDayCard`.
18. `ZadSlots.homeTelegramBlocks()`.
19. `OutOfAttemptsCard` · `SubscribePulseCard` · `AdWeekCard` — الكوتة والاشتراك والإعلانات.
20. `HomeAmazonStrip` — منتجات أمازون.
21. `DailyBriefCard` — موجز العقل اليومي.
22. `ZadSlots.homeProposalsSection()` — اقتراحات البنك.
23. `brokeModeSlot` · `savingsChallengeSlot`.
24. `HomeActivationSlot` · `WhoAreYouCard` · `InventoryCheckInSlot`.
25. `TasbihaHomeSlot`.
26. `ZadSlots.homeChefSection()` = `HomeChefSection` — الشيف.
27. `BankListeningPill`.
28. `stuckNotificationsSlot` · `HomeRecentTransactions`.
29. `homeInsightsSection` · `AiAlertBannerSlot` · `UrgentRecipeSlot`.

**٢٩ بلوك في عمود واحد.** الموجز اليومي (المفروض «الرئيسية = موجز العقل» حسب [[ZAD_BRAIN_PLAN]]) رقم ٢١،
والشيف ٢٦، واقتراحات البنك ٢٢ — كلهم تحت أكتر من ٦ شاشات سكرول على موبايل عادي.

## ٣. المدفون

1. **العروض:** شاشة `deals_view` مالهاش مدخل ثابت غير الدرج ← «كل المزايا» ← «عروض قريبة» (٣ ضغطات). الكاروسيل اللي على الرئيسية بيختفي لما مفيش عروض، فساعتها مفيش أي طريق ظاهر ليها.
2. **الشيف/الوصفات:** تاب رابع جوه بيتي، و`HomeChefSection` رقم ٢٦ في الرئيسية. ومفيش قسم في الشبكة ولا الدرج اسمه «الشيف».
3. **عيلتي:** مش في الشريط (عكس قرار [[ZAD_BRAIN_PLAN]])، مربع ٥ في الشبكة.
4. **عقل زاد (الذاكرة، سجل الأفعال، صحة العقل، خريطة المعرفة):** ٣ ضغطات، وخريطة المعرفة مستخبية تحت «المزيد» في الشبكة.
5. **فنيين موثوقين والذكاء (`showIntelligenceScreen`):** مالهمش مدخل غير الشات/الإشعارات/أوامر الوكيل.
6. **الاشتراكات:** ظاهرة كمربع في `HomeGlanceWidgets` (كويس)، بس في الدرج مستخبية تحت «كل المزايا» واسمها هناك «التزاماتي» مش «الاشتراكات».
7. **الصيدلية والنواقص:** مربع الجرعة والناقص في `HomeGlanceWidgets` بيوصلوا بضغطة — مش مدفونين على الرئيسية، بس في الدرج مستخبيين.

## ٤. الاقتراح (طلبات المالك ١١/١١)

### الرئيسية الجديدة (من فوق لتحت)

1. **البانرات المؤقتة في مكان واحد:** `QuietModeBanner`، `TravelBannerSlot`، `HomeOfflineBanner`، `PermissionBanners` يتجمعوا في slot واحد يعرض **واحد بس** (الأهم) — بدل ما يتكوموا فوق الفلوس.
2. `HomeCompanionHeader` (التحية + الصوت + الكاميرا).
3. `_Budget` (الفلوس).
4. **صف الاختصارات السريعة:** توسيع `HomeGlanceWidgets` من ٣ لـ٤ مربعات بنفس الشكل: **المخزن** (`showHouseholdSection(pantry)`)، **النواقص** (`showHouseholdSection(shopping)`)، **الصيدلية** (`showHouseholdSection(pharmacy)`)، **الاشتراكات** (`showSubscriptionsScreen`). كل مربع يفضل يعرض رقمه (الناقص، الجرعة الجاية، الاشتراك الجاي) ومستهدف ≥ ٤٤dp. ده **إعادة استخدام** للموجود، مش ويدجت جديد.
5. **بار العروض الأفقي:** `HomeDealsCarousel` يتعرض كشريط أفقي من نفس الكروت (`_DealCard`)، و«كل العروض» آخر الشريط، و**مايختفيش لما مفيش عروض**: يعرض كارت فاضي حقيقي (`ZadEmptyState`-style صغير) فيه «كل العروض». ⚠️ ده عكس قرار المالك ٦/١١ («قايمة مش شريط جانبي») — طلب ١١/١١ أحدث، بس يتأكد منه قبل التنفيذ.
6. `DailyBriefCard` (موجز العقل) — يطلع من رقم ٢١ لهنا.
7. `ZadSlots.homeProposalsSection()` — اقتراحات البنك (فلوس مستنية موافقة).
8. `HomeChefSection` — الشيف يطلع من ٢٦ لهنا.
9. `SectionsGrid` — زي ما هو (٨ + المزيد).
10. الباقي زي ترتيبه (الحملات، تليجرام، الكوتة، أمازون، السبحة، آخر الحركات، الرؤى).

`OccasionCardSlot` + `CampaignBannerSlot` + `CampaignStoriesStrip` + `_TourButton`: يتجمعوا في صف واحد تحت الفلوس
(UI_OVERHAUL_STATUS «Left to do» بيقول نفس الكلام: «Home stacks the location banner, an empty live-prices bar,
«ساهم بسعر», the tour row, the greeting and the occasion banner above the money»).

### الشريط والدرج

- **الشريط:** يرجع لقرار [[ZAD_BRAIN_PLAN]]: الرئيسية · فلوسي · بيتي · عيلتي، و«المزيد» يبقى أيقونة الدرج في الهيدر (موجودة أصلاً: `onOpenDrawer` في `zad_chrome.dart`). ده **قرار محتاج المالك** لأن التاب الرابع دلوقتي «المزيد».
- **بيتي:** التابات الأربعة زي ما هي، والشيف يفضل تاب، بس يتضاف مربع «الشيف» في `zadSections` (أول ٨) عشان يبان.
- **الدرج:** `deals` و`subscriptions` و`pharmacy` و`shopping` يتضافوا لـ`kDrawerAlways` — المالك قالهم بالاسم.

### قواعد لازم تتحترم (CLAUDE.md «Mobile UI/UX rules»)

- كل مربع/زرار ≥ ٤٤dp؛ الأفعال الأساسية في التلت اللي تحت (الكاميرا والمايك في الشريط موجودين).
- `ZadSpacing` / `ZadType` / `ZadColors` / `ZadRadii` بس؛ مفيش `fontSize` ولا hex في المكونات المشتركة.
- كل قايمة ليها `ZadEmptyState` حقيقي — ده بالذات ناقص في بار العروض لما يبقى فاضي.
- `test/app/shell_walkthrough_test.dart` لازم يعدّي بعد أي تغيير في الشل أو الرئيسية.
- الإعلانات (#485) عمرها ما تقع جوه بلوك أو جنب زرار.

## ٥. الشيف (١٠.٩) — الوصفات بتقف فين

المقاس على الحي ١١/١١: `zad_social_recipes` فيه ٣١ تيك توك + ٢٧ يوتيوب + **صفر إنستجرام**.

**الطريق في الكود:**

1. **الجمع:** `zad-brain/socialRecipesRun.ts` بيكتب في `zad_social_recipes` (تيك توك للحسابات والمواضيع، يوتيوب للمواضيع، إنستجرام للحسابات `RECIPE_ACCOUNTS` بس). إنستجرام بيتجرب بس مابيطلّعش صفوف — يتقاس ليه (غالباً البحث مابيرجعش بوستات وصفات بالحسابات دي).
2. **القراية الوحيدة:** `zad-core-intelligence/index.ts` (~سطر ٢٢٩٧) جوه أكشن `meal_suggestions`. بيقرا آخر ١٢٠ يوم لبلد العميل، وبعدين `pickSocialRecipes` (`zad-core-intelligence/chefInputs.ts`) **بيرمي أي وصفة مكوّناتها مش في المخزن أو قايمة الشرا أو العروض** (`score > 0`)، وبياخد ٤ بس. بعدها بتدخل البرومبت كبلوك `=== وصفات متداولة ===`، والرابط بيرجع بس **لو الموديل كتب رقم المصدر** (`recipeSource`).
3. **التطبيق:** `features/recipes/data/recipes_remote.dart` بينادي `meal_suggestions` **لما العميل يدوس بس** (قاعدة «never on open»). `Recipe.sourceUrl` / `sourceHandle` موجودين و`recipes_view.dart` (سطر ~٤٧٠) و`recipe_detail_screen.dart` (سطر ~٢٦٥) بيعرضوا الرابط لو موجود.
4. **البوت:** `zad-brain/chef.ts` (أداة `suggest_recipes`) بينادي نفس `meal_suggestions`، بس **بيكتب سطور الوصفات من غير `source_url`** — يعني حتى لو الوصفة جاية من تيك توك، الرابط بيقع في البوت.

**يعني الوصفات بتقف عند:** (أ) فلتر `pickSocialRecipes` على عميل مخزنه فاضي ⇒ صفر وصفة؛ (ب) الموديل لازم يختارها ويكتب رقمها؛ (ج) البوت بيشيل الرابط؛ (د) مفيش أي مكان يعرض «الترند» نفسه كقايمة (`Recipe.trending` موجود في الموديل وفيه `recipesTrendingGroup` في الـARB، بس بيتملي بس من رد الموديل).

**الناقص بالظبط:**
- أكشن قراية من غير موديل (زي `home_deals`) يرجّع آخر وصفات `zad_social_recipes` لبلد العميل بروابطها، ويتعرض كقسم «ترند دلوقتي» في `RecipesView` وفي `HomeChefSection` — من غير ما يستنى ضغطة ومن غير كوتة ذكاء.
- `pickSocialRecipes`: لو المخزن فاضي، يرجّع الأحدث بدل صفر.
- `zad-brain/chef.ts`: يضيف `source_url` لكل سطر في رد البوت (رابط تيك توك/يوتيوب بيتفتح على طول).
- إنستجرام: قياس ليه `socialRecipesRun` بيرجع صفر صفوف منه.

## ٦. خطة التنفيذ (شريحة = PR)

1. **الاختصارات الأربعة:** `features/home/presentation/home_glance_widgets.dart` (مربع رابع + المخزن والنواقص)، اختبار في `test/features/home/`. على الجهاز: ٤ مربعات، كل واحد بيفتح شاشته بضغطة.
2. **بار العروض الأفقي + حالته الفاضية:** `features/nearby/presentation/home_deals_carousel.dart` (بعد تأكيد المالك على عكس قرار ٦/١١). على الجهاز: الشريط ظاهر بعروض ومن غيرها، و«كل العروض» بتفتح `deals_view`.
3. **ترتيب الرئيسية + slot البانرات:** `features/home/presentation/home_screen.dart` (+ slot جديد يختار بانر واحد). على الجهاز: الفلوس في أول شاشة من غير سكرول.
4. **الشيف ظاهر:** مربع «الشيف» في `zadSections` + الدرج (`kDrawerAlways`: `deals`، `subscriptions`، `pharmacy`، `shopping`). `shell_walkthrough_test` لازم يعدّي.
5. **وصفات الترند بروابطها (سيرفر):** أكشن قراية في `zad-core-intelligence` أو `zad-brain` + `chefInputs.ts` (fallback للأحدث) + `zad-brain/chef.ts` (الرابط في البوت)، باختبارات `deno test`. على الجهاز: قسم «ترند دلوقتي» فيه وصفات تيك توك/يوتيوب بتفتح.
6. **الشريط بأربع تابات (لو المالك وافق):** `app/shell/zad_bottom_nav_bar.dart` + `app/zad_shell.dart`. على الجهاز: عيلتي ضغطة واحدة.
7. **عقل زاد أقرب:** مدخل للـhub من `DailyBriefCard`، وخريطة المعرفة جوه الـhub بس.
