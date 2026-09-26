---
title: جرد تطابق الواجهة — كوتلن مقابل فلاتر
date: 2026-09-26
tags:
  - zad/flutter-migration
  - audit/ui-parity
aliases:
  - UI parity audit
  - جرد الواجهة
---

# جرد تطابق الواجهة: كوتلن ← فلاتر

فلاتر لازم يكون بديل مطابق لكوتلن (drop-in replacement): نفس الواجهة فوق نفس الباك إند.
الملف ده بيجرد كل حاجة ظاهرة للمستخدم في كوتلن وملهاش مقابل في فلاتر: الشاشات والكروت
والأزرار والنصوص والألوان والأيقونات والحركة. حالة الشغل العامة في [[FLUTTER_MIGRATION]].

> [!abstract] الخلاصة
> - فلاتر **غطّى أغلب الشاشات** بس **أعاد كتابتها** بدل ما ينسخها: صياغة جديدة للنصوص، وترتيب
>   مختلف، ومجموعة أيقونات مختلفة، ومن غير وضع داكن.
> - من **1,621** نص ظاهر في كود كوتلن الشغّال فعلاً، فيه **518 (32%)** ملهمش أي أثر في فلاتر.
>   بعضهم ميزة ناقصة بالكامل، والباقي ميزة موجودة بكلام تاني.
> - **186 لون** من ألوان كوتلن مش موجودين في فلاتر، وأغلبهم عيلة الوضع الداكن كلها.
> - **211 أيقونة Material** مستخدمة في كوتلن (679 مرة). فلاتر بيرسم بـ **Lucide**، يعني ولا أيقونة
>   فيهم مطابقة شكلاً.
> - **14 أنيميشن Lottie وصوت `zad_alert.wav`** مش موجودين في فلاتر.

## المنهج وحدوده

- **النصوص:** اتسحب كل `R.string.*` وكل نص عربي مكتوب مباشرة في `Text/label/title/contentDescription`
  من `app/src/main/java/**/ui/**`. اتترجم المفتاح لقيمته من `res/values/strings.xml`، وبعدها اتدوّر
  على أطول جزء ثابت من النص جوه كل ملفات `zad_flutter/lib` (بما فيها الملفات اللي لسه متعدلة ومش
  متكومتة). التطبيع شال التشكيل ووحّد أ/إ/آ وى/ي وة/ه.
- **الكود الميت اتشال:** 62 دالة `@Composable` في كوتلن ماحدش بينادي عليها، زي `PredictionCard`
  و`EventsRadarCard` و`OutingSuggestionCard` و`QuickDeductDialog` و`CashCard` و`ZadPremiumPromoCard`
  و27 كارت ميت في `ZadIntelligenceScreen`. نصوصهم مش محسوبة، لأن نسخها هيضيف لفلاتر حاجات
  المستخدم عمره ما شافها في كوتلن.
- **الحدود:** النص اللي "مش موجود" ممكن يكون الميزة موجودة بكلام تاني، وده برضه عدم تطابق بالمعيار
  المطلوب. وممكن كمان يكون كارت كوتلن ظاهر بشرط نادر. الفحص ده **مابيقيسش الأبعاد والمسافات
  بالـ dp**: ده محتاج مقارنة كل شاشة جنب نظيرتها.

## 1. تغييرات على مستوى التطبيق كله

| البند | كوتلن | فلاتر | الأثر |
|---|---|---|---|
| الوضع الداكن | `ZadTheme(darkTheme = isSystemInDarkTheme())` + `ZadDarkColorScheme` + `ZadExtendedColorsDark` | مفيش `darkTheme` ولا `ThemeMode` | لو الموبايل على الداكن، كوتلن داكن وفلاتر فاتح |
| الأيقونات | Material Icons: ‏211 أيقونة، 679 استخدام | Lucide: ‏391 استخدام لـ`ZadIcons` + 40 لـ`LucideIcons` مباشرة | ولا أيقونة مطابقة شكلاً |
| Lottie | 14 ملف في `res/raw` (confetti، success_check، scan_receipt، empty_box، onboarding…) | مفيش مكتبة ولا ملفات | الحركة محذوفة أو مرسومة يدوي |
| صوت التنبيه | `R.raw.zad_alert` | مش موجود | |
| الخطوط | Cairo + Inter variable | Cairo + Inter variable | ✅ مطابق |

### الألوان الناقصة من `ui/theme/Color.kt`، بالاسم وعدد مرات الاستخدام

- **الداكن (مستخدمة):** `ZadForestEmeraldDark` (6)، `ZadEmeraldOnDark` (7)، `ZadOnAccentDark` (4)،
  `ZadIosBackgroundDark`، `ZadIosSurfaceDark`، `ZadIosSurfaceVariantDark`، `ZadIosOutlineDark`،
  `ZadNeutralOnDark`، `ZadNeutralMutedOnDark`، و`*ContainerOnDark` للزمردي والمسطردة والطوبي.
- **درجات الهوية:** `ZadEmeraldContainer` ‎#E8F0EC، `ZadMustardDark` ‎#A5680E،
  `ZadMustardContainer` ‎#FBF4E7، `ZadTerracottaDark` ‎#B84218، `ZadTerracottaLight` ‎#EA764B،
  `ZadTerracottaContainer` ‎#FDF0EA.
- **الفئات:** `catTransport*`، `catDaily*`، `catEntertain*`، `catHealth*`، الخلفية والأيقونة لكل واحدة.
- **البراندات (أيقونات الاشتراكات):** Netflix ‎#E50914، Shahid ‎#00A651، Spotify ‎#1DB954،
  YouTube ‎#FF0000، Tabby ‎#29E7CD، Tamara ‎#FF7043، Water، Internet، Rent، و**Telegram ‎#229ED9
  (13 استخدام)**.
- **شيت الصوت:** `ZadVoiceDarkSheetBg`، `ZadVoiceTextSoft`، `ZadVoiceTextMint`، `ZadVoiceAlertAmber`،
  `ZadVoiceDanger*`.
- **Sci-Fi (خريطة المعرفة / عقل زاد):** 14 لون `ZadSciFi*`، كل واحد مستخدم مرة.
- **مش لازم تتنقل (0 استخدام في كوتلن):** `kidsBackground`، `kidsSurface`، `ZadHeartRed`،
  `ZadOrb*` (5)، `ZadShortcut*Glow` (3).
- كمان: 49 لون مكتوب مباشرة في `ZadExtendedColors.kt` (أغلبه الـ Dark palette)، و9 ألوان
  `ZadSectionAccent.kt`، و5 في `ZadV2.kt` (`gray400`، `danger`، `info`، `violet`، ‎#EC4899).

## 2. الرئيسية (HomeScreen)

ترتيب كوتلن الفعلي، وجنب كل بلوك حالته في فلاتر:

1. شريط أوفلاين ✅
2. هيدر الأورب ✅
3. `LifeGoalPickerSheet`: شيت «إيه أهم هدف لبيتك دلوقتي؟» بـ5 أهداف جاهزة ❌ **ناقص كله**
4. `BrokeModeBanner` + `BrokeModeDialog` ✅ (`modes_cards`)
5. `SavingsChallengeCard` ✅
6. `HomeActivationCard`: «جهّز زاد لبيتك»، 4 خطوات بعلامات صح ❌ **ناقص**
7. `WhoAreYouCard`: «عرّفني بنفسك» ❌ **ناقص من الرئيسية**
8. `LocationAlertsCard`: تنبيهات لما تكون قريب من متجر ❌ (مرتبط بقرار الـ geofence)
9. `InventoryCheckInCard`: «هل خلص X؟» ❌ **ناقص**
10. `LiveMarketTicker`: شريط أسعار السوق + «ساهم بسعر» ❌ **ناقص**
11. `ZadWalletHeroCard` ✅ (`ZadBalanceCard`). الضغط عليه في كوتلن بيفتح `WhyChangedSheet` «آخر
    التغييرات»، وفي فلاتر بيفتح سجل الأفعال: **سلوك مختلف**
12. `ZadMinimalMetricsDuo` ✅
13. تنبيه «استُبعدت N معاملة من الإجمالي — عملتها مالهاش سعر صرف» ❌
14. `BankListeningPill` ⚠️ فلاتر حاطط مكانه `BankAccessCard` **قبل** شبكة الأقسام، وده شكل ومكان مختلفين
15. `ZadSectionsGrid` ✅
16. `TelegramLinkBanner` + `ZadTelegramCommunityCard` ❌ **ناقصين**
17. `ZadFoodShortagesGlanceCard` ✅، ونص الحالة الفاضية مختلف
18. `ZadPharmacyGlanceCard` ✅، ونص الحالة الفاضية مختلف
19. `WeekWithZadCard`: «أسبوعي مع زاد» + «شارك أسبوعك» ❌ **ناقص**
20. `TasbihaHomeWidget` ❌ **ناقص من رئيسية الكبار** (موجود بس في رئيسية الأطفال)
21. `ZadSubscriptionsGlanceCard` ✅، ونص «ضيف اشتراكاتك…» و«القسط:» مختلفين
22. `SmartChefSection`: «شيف زاد (اقتراحات ذكية)» + نصوص المخزون الفاضي أو الخلصان ❌ **ناقص**
23. `TransactionProposalCard` ✅، ناقص فيه سؤال التكرار («نفس المعاملة / عملية أخرى»)
    و«الاتجاه غير صحيح؟» و«لن يتغير الرصيد قبل قرارك»
24. كروت الرؤى + `ZadQuestionCard` ✅ (زرار «أيوة» مكتوب بكلام تاني)
25. `PremiumTransactionsRow` ✅، ناقص فيه «السجل الكامل للمعاملات» (ديالوج كل المعاملات)
26. صف ترشيحات أمازون + `ZadAmazonSearchChip` ❌ **ناقص من رئيسية الكبار**
27. `AiAlertBanner` ❌
28. `UrgentRecipeCard` ❌ (مستبعد عن قصد: نداء LLM تلقائي)
29. شيت/برومبت تليجرام (`TelegramBotSheet`، `TelegramLinkPrompt`) ❌
30. `BudgetEditSheet` بنصوص «اكتب رصيدك الحالي…» و«الرقم ده كلمتك الأخيرة…» ⚠️ فلاتر عنده
    `monthly_limit_sheet` بكلام تاني

## 3. شاشات فيها ميزة ناقصة بالكامل

| كوتلن | الناقص | نصوص ناقصة |
|---|---|---|
| `TelegramBinding.kt` | ربط تليجرام كله: توليد كود، نسخه، «افتح البوت واربط تلقائياً»، الحالة، فك الربط، شاشة الإقناع بمزاياها الخمسة، البانر، مجتمع زاد | 27/28 |
| `LifeGoalPickerSheet.kt` | شيت الأهداف كله | 17/17 |
| `HomeActivationCard.kt` | كارت التفعيل | 11/12 |
| `WeekWithZadCard.kt` | كارت مشاركة الأسبوع | 7/7 |
| `ZadVoiceBottomSheet.kt` | شيت المساعد الصوتي: «دوس مع الاستمرار واتكلم»، حالات بيتصل/بيفكر/بيتكلم، إعدادات شخصية الصوت، الأسئلة الجاهزة | 22/25 |
| `LiveMarketTicker.kt` | الشريط | 5/5 |
| `WhyChangedSheet.kt` | «آخر التغييرات» | 3/3 |
| `PendingSubscriptionsCard.kt` | «زاد لاحظ اشتراك محتمل» + تأكيد / مش اشتراك | 3/3 |
| `GroceryPurchasePromptDialog.kt` | «اشتريت من X بـ Y — ضيف إيه للمخزون؟» | 3/4 |
| `InventoryCheckInCard.kt` | «هل خلص X؟» | 2/4 |
| `ZadBezierSpendChart.kt` | منحنى «نبض الإنفاق»، آخر 7 أيام | 3/3 |
| `TravelBanner.kt` | «شكلك في X — أحوّل لـ Y؟» | 1/3 |
| `ZadAgentOverlay.kt` | فقاعة «زاد بيكتب...» + «فتح الشات الكامل» | 2/6 |
| `AdEnergyBatteryCard.kt` | بطارية الإعلانات (مرتبطة بقرار AdMob) | 5/5 |
| `SignUpScreen.kt` | شاشة تسجيل مستقلة + **موافقة على الشروط وسياسة الخصوصية** + «تم التسجيل بنجاح» | 12/17 |
| `ProfileSubScreens.kt` | إدارة أعضاء العيلة (ترقية لمدير، إرجاع لعضو، تعيين كابن، طرد)، «طرق الدفع والميزانية»، نبرة صوت المساعد، مفاتيح تنبيهات نقص المخزون وتخطي الميزانية، **صوت الإشعارات**، **تشخيص قراءة إشعارات البنك** (آخر اتصال، آخر إشعار، اختبار تحليل، الرسائل المرفوضة) | 37/61 |
| `NotificationCenterScreen.kt` | أقسام «تنبيهات ذكاء زاد / عقل زاد / إشعارات التطبيق»، عداد «غير مقروء»، زرار «قراءة التنبيهات صوتيًا» | 8/9 |
| `PharmacyScreen.kt` | «أدوية العيلة» (قائمة الأسرة كلها)، «أخذ الجرعة»، «إعادة طلب»، «تعديل الكمية»، إضافة ذكية بالكلام، تلميح المنبهات الدقيقة | 13/69 |
| `InventoryScreen.kt` | «تصوير المخزون»، «إضافة يدوية»، «نواقص المخزون (N)»، «اشتريه من أمازون»، وصفة للأصناف اللي قربت تخلص | 10/39 |
| `SubscriptionsScreen.kt` | ملخص «إجمالي الاشتراكات الشهرية» و«اشتراكات نشطة»، **قائمة الخدمات المقترحة (presets)**، «تم الدفع ✓»، مفتاح الخصم التلقائي، حقول الأقساط (الإجمالي والمتبقي)، «يُجدد اليوم / بعد N يوم» | 26/96 |
| `CameraScreen.kt` | الشاشة معمولة في فلاتر كشيتات بكلام تاني. ناقص: ديالوج تأكيد المخزون المستخرج بـ +/-، اختيار «نوع الفاتورة»، «إضافة منتج آخر»، «حقن في المخزون»، إدخال مفتاح Gemini | 44/60 |
| `PriceReportingScreen.kt` | متعمولة بتصميم تاني. ناقص: «لوحة الأسعار»، «مساهماتك»، «أكثر المشاركين 🏆»، حقل المنطقة، «أرخص سعر حواليك» بنفس الشكل | 23/29 |
| `ZadIntelligenceScreen.kt` | كارت «محادثة مع زاد» والأسئلة الجاهزة الستة جوه الشاشة، مسح المحادثة، «استمع»، «تصدير التقرير الشهري»، تقرير شبكة العائلة (الأبناء، مقاضي العيلة، ملاحظات لرب الأسرة)، «التوزيع حسب الفئة» | 45/84 |
| `ZadHomeGlanceCards.kt` | التقرير الاستراتيجي المطبوع بقسميه + مشاركة وإغلاق، و«العقل الثاني… ثلاثي الأبعاد» | 18/35 |
| `LoginScreen.kt` | موجودة بكلام تاني بالكامل | 8/16 |
| `AmazonAffiliateWidget.kt` | ودجت «ترشيحات الشراء من أمازون» + الإفصاح + التفعيل | 6/8 |

## 4. استبعادات متاخدة بقرار قبل كده (محتاجة تأكيد مع مبدأ «100%»)

> [!warning] الاستبعادات دي بتتعارض مع «انسخ 100% من غير حذف»
> كل واحد فيها اتشال بقرار موثّق. لو المطابقة الكاملة هي القاعدة، كل بند محتاج قرار جديد:
> - مكالمة الصوت الحية (`zad-voice-live`): **اتلغت نهائياً** (CLAUDE.md). ده جزء من `ZadVoiceBottomSheet`.
> - AdMob وPlay Billing: واجهة بس في فلاتر، لأن الإصدار بيتنزّل على الموبايل مباشرة من غير Play.
> - نداءات LLM تلقائية عند فتح الشاشة (`detectSubscriptions`، `UrgentRecipeCard`، الوصفات الاحتياطية
>   الثابتة): ممنوعة بقاعدة CLAUDE.md.
> - geofence الموقع في الخلفية: فلاتر مابيعلنش إذن الموقع في الخلفية.
> - لصق مفتاح Gemini في الكاميرا: مسار اختياري ومش شغال في كوتلن نفسه.
> - TTS وتنبيهات صوتية وتحية الصحيان: مش متنقلين (FLUTTER_MIGRATION §6).

## 5. ترتيب الشغل المقترح

1. **الوضع الداكن + الألوان**: أساس. أي شاشة تتنسخ قبله هتحتاج لمسة تانية.
2. **قرار الأيقونات**: Material زي كوتلن، ولا Lucide يفضل. ده بيأثر على كل شاشة.
3. **الرئيسية بترتيب كوتلن بالظبط** (القسم 2)، وبعدها الشيتات والكروت الناقصة كلها (القسم 3).
4. **تليجرام** والبروفايل الفرعي (إدارة العيلة، التنبيهات، تشخيص البنك).
5. الشاشات اللي اتعملت بكلام تاني (الكاميرا، الأسعار، الدخول والتسجيل، الاشتراكات، الصيدلية، المخزون):
   مقارنة كل شاشة سطر بسطر، ونقل النصوص حرفياً من `strings.xml`.
6. Lottie + `zad_alert.wav`.

## ملحق: كل نص ناقص، مرتب حسب الملف

القايمة دي فيها كل نص ظاهر في كود كوتلن الشغّال وماتلقاش في فلاتر. كل بند هو المفتاح في
`strings.xml` (أو «نص مباشر» لو مكتوب جوه الكود) وقيمته العربية. علّم على البند لما يتنقل.

### ZadIntelligenceScreen.kt — 45 من 84

- [ ] `ad_loading_retry_toast` — جاري تحميل الإعلان... ثواني وجرب تاني 🎬
- [ ] `ad_failed_toast` — الإعلان غير متاح حالياً، حاول بعد قليل
- [ ] `ai_intel_empty_desc` — يحتاج عقل زاد إلى 3 مصاريف على الأقل لتحليل سلوكك المالي بدقة وتوليد تقارير الصمود المالي.
- [ ] `ai_chat_card_title` — محادثة مع زاد
- [ ] `ai_chat_card_subtitle` — اسأل عن مصاريفك، مخزونك، أو أي حاجة
- [ ] `collapse_chat_action` — إخفاء المحادثة
- [ ] `open_chat_action` — افتح المحادثة
- [ ] `quick_prompt_recipe` — اقترح وصفة من الثلاجة
- [ ] `quick_prompt_analyze_spending` — حلل مصاريفي هذا الشهر
- [ ] `quick_prompt_shopping_missing` — ما الذي ينقصني للتسوق؟
- [ ] `quick_prompt_save_more` — كيف أوفر أكثر هذا الشهر؟
- [ ] `quick_prompt_subscriptions` — اكتشف اشتراكاتي
- [ ] `quick_prompt_healthy_meal` — وجبة صحية سريعة
- [ ] `clear_chat_title` — مسح المحادثة
- [ ] `clear_chat_confirm` — هنمسح كل رسائل المحادثة مع عقل زاد. البيانات المالية والمخزون مش هتتأثر.
- [ ] `clear_chat_action` — مسح المحادثة
- [ ] `voice_unavailable_toast` — الصوت البشري غير متاح حالياً — حاول تاني
- [ ] `ask_zad_hint_short` — اسأل زاد عن أي شيء
- [ ] `ask_zad_placeholder` — اسأل زاد عن ثلاجتك أو ميزانيتك...
- [ ] `listen_action` — استمع
- [ ] `chat_memory_hint_label` — اتبنى على %1$d حاجة زاد فاكرها عنك
- [ ] `export_monthly_report` — تصدير التقرير الشهري
- [ ] `ai_intel_generate_report_desc` — تحليل فوري دقيق لجميع حركاتك ومصروفاتك عبر نماذج الذكاء الاصطناعي
- [ ] `ai_intel_generating_report` — جاري تحليل الحركات وتوليد التقرير بالذكاء الاصطناعي...
- [ ] `auto_zadintelligence_36332` — تقرير شبكة العائلة العصبية
- [ ] `auto_zadintelligence_96391` — تحليل الذكاء الاصطناعي المشترك لأفراد الأسرة
- [ ] `auto_zadintelligence_23852` — لم تنضم لعائلة بعد في زاد
- [ ] `auto_zadintelligence_85865` — أضف أفراد أسرتك (الزوجة، الأبناء) لربط شبكاتهم العصبية وتبادل الرؤى وتدبير المنزل معاً.
- [ ] `auto_zadintelligence_82314` — إنشاء / انضمام لعائلة
- [ ] `auto_zadintelligence_1763` — 🎯 رادار الأبناء والمهام والمصروف
- [ ] `auto_zadintelligence_65857` — لا يوجد أبناء مضافين حالياً. يمكنك إضافة حسابات الأبناء لمتابعة مهامهم ومصروفهم بأمان.
- [ ] `family_child_task_summary` — أنجز %1$d من %2$d مهام · رصيد المصروف: %3$s %4$s
- [ ] `auto_zadintelligence_65720` — 🛒 تدبير مقاضي واحتياجات البيت المشتركة
- [ ] `auto_zadintelligence_22228` — لا توجد نواقص معلقة في قائمة مقاضي العائلة المشتركة ✅
- [ ] `family_pending_groceries` — نواقص العائلة المطلوبة: %1$s
- [ ] `auto_zadintelligence_53103` — 💡 ملاحظات عقل زاد لرب الأسرة
- [ ] `auto_zadintelligence_40342` — أضف مهام وقائمة مشتريات عائلية ليبدأ زاد بملاحظات حقيقية على بياناتكم.
- [ ] `category_breakdown_title` — التوزيع حسب الفئة
- [ ] `brain_gate_title` — Unlock Zad Brain
- [ ] `brain_gate_subtitle` — Watch a few short ads to unlock the smart brain — predictions, reports and chat for 24 hours. Or subscribe for unlimited access.
- [ ] `brain_gate_loading` — Loading ad…
- [ ] `brain_gate_watch_ad` — ▶ Watch ad to unlock
- [ ] `brain_gate_bypass` — تخطي ومتابعة للتقارير مباشرة ⚡
- [ ] `brain_gate_subscribe` — Or subscribe to Zad Premium
- [ ] نص مباشر — ملاحظة من عقل زاد

### CameraScreen.kt — 44 من 60

- [ ] `cam_hint_initial` — التقط صورة للثلاجة أو أكياس البقالة أو الفاتورة وسيستخرجها الذكاء الاصطناعي!
- [ ] `cam_analyzing_ai` — جاري تحليل الصورة بالذكاء الاصطناعي...
- [ ] `cam_medicine_extracted` — تم التعرف على: %1$s
- [ ] `medicine_scan_error` — تعذر قراءة العلبة بدقة، يرجى المحاولة بزاوية أوضح
- [ ] `cam_items_extracted` — تم استخراج %1$d منتج! راجعها وأكّد
- [ ] `cam_no_items_found` — لم يتعرف AI على منتجات واضحة. جرب تصوير أقرب أو بإضاءة أفضل، أو أضفها يدوياً
- [ ] `cam_receipt_extracted` — تم استخراج فاتورة %1$s! راجعها وأكّد
- [ ] `cam_receipt_unreadable` — لم نتمكن من قراءة الفاتورة، يرجى المحاولة بصورة أوضح
- [ ] `cam_analysis_error` — حدث خطأ أثناء التحليل. جرب مرة أخرى
- [ ] `cam_cannot_open_camera` — تعذر فتح الكاميرا. ثبّت تطبيق كاميرا أو استخدم الإدخال اليدوي
- [ ] `cam_permission_needed` — نحتاج صلاحية الكاميرا للمسح. يمكنك الإضافة يدوياً
- [ ] `cam_permission_blocked` — صلاحية الكاميرا ممنوعة نهائياً — افتح الإعدادات وفعّلها عشان تقدر تصوّر
- [ ] `cam_items_added_manual` — تمت إضافة %1$d منتجات يدوياً!
- [ ] `cam_ai_setup_title` — إعداد الذكاء الاصطناعي (Gemini API)
- [ ] `auto_camera_14259` — أدخل مفتاح Gemini الخاص بك لتفعيل تحليل الصور (يمكن إدخال أكثر من مفتاح مفصولة بفاصلة):
- [ ] `cam_api_key_label` — API Key
- [ ] `cam_smart_scanner` — الماسح الذكي
- [ ] `cd_captured_image` — الصورة الملتقطة
- [ ] `auto_camera_36966` — التقط صورة للمخزون أو الفاتورة
- [ ] `auto_camera_21409` — سيقوم AI باستخراج المنتجات تلقائياً
- [ ] `cam_scan_medicine` — مسح علبة دواء
- [ ] `cam_scan_receipt` — مسح الفاتورة
- [ ] `cam_add_products_manually` — إضافة منتجات يدوياً
- [ ] `cam_injected` — تم الحقن: %1$s
- [ ] `cam_injecting` — جاري حقن %1$d منتجات في المخزون...
- [ ] `cam_inject_into_stock` — حقن في المخزون
- [ ] `cam_add_cancelled` — تم إلغاء الإضافة
- [ ] `cam_confirm_stock` — تأكيد المخزون المستخرج
- [ ] `auto_camera_11386` — تم استخراج المنتجات التالية. يمكنك مراجعتها قبل الحفظ:
- [ ] `cam_save_to_pharmacy` — حفظ في الصيدلية
- [ ] `cam_ok` — حسناً
- [ ] `cam_receipt_read_failed_title` — تعذّرت قراءة الفاتورة
- [ ] `cam_receipt_read_failed_body` — لم نتمكن من قراءة الفاتورة، يرجى المحاولة بصورة أوضح
- [ ] `cam_receipt_to_pharmacy` — تم تسجيل فاتورة %1$s (%2$s) في الصيدلية!
- [ ] `cam_receipt_and_stock` — تم تسجيل فاتورة %1$s (%2$s) وتحديث المخزون!
- [ ] `cam_receipt_and_items` — تم تسجيل فاتورة %1$s بقيمة %2$s والمنتجات في المخزون!
- [ ] `cam_save_receipt` — تسجيل الفاتورة
- [ ] `cam_receipt_cancelled` — تم إلغاء الفاتورة
- [ ] `cam_confirm_receipt` — تأكيد الفاتورة المستخرجة
- [ ] `auto_camera_97981` — راجع المنتجات قبل التسجيل في المصروفات والمخزون:
- [ ] `cam_receipt_type_hint` — نوع الفاتورة (زاد صنّفها تلقائياً، وتقدر تغيّرها):
- [ ] `cd_decrease_qty` — إنقاص الكمية
- [ ] `cd_increase_qty` — زيادة الكمية
- [ ] `cam_add_another_product` — إضافة منتج آخر

### ProfileSubScreens.kt — 37 من 61

- [ ] `family_invite_code_label` — كود دعوة العائلة
- [ ] `promote_to_admin` — ترقية لمدير (Admin)
- [ ] `demote_to_member` — إرجاع لعضو (Member)
- [ ] `set_as_child` — تعيين كابن/ابنة
- [ ] `kick_member` — طرد العضو
- [ ] `not_in_family_yet` — أنت لست منضماً لأي عائلة حالياً.
- [ ] `payment_and_budget_title` — طرق الدفع والميزانية
- [ ] `current_monthly_budget` — الميزانية الشهرية الحالية
- [ ] `auto_profilesubscreens_45124` — نبرة صوت المساعد الصوتي
- [ ] `low_inventory_alerts` — تنبيهات نقص المخزون
- [ ] `low_inventory_alerts_desc` — يرسل إشعاراً عند اقتراب نفاذ منتج أساسي
- [ ] `budget_overrun_alerts` — تنبيهات تخطي الميزانية
- [ ] `budget_overrun_alerts_desc` — تحذير مبكر عند صرف جزء كبير من الميزانية
- [ ] `tasbih_reminder_alert_desc` — تذكير لطيف الساعة 5 عصراً لو لسه ما سبّحتش النهاردة
- [ ] `notification_sound_title` — صوت الإشعارات
- [ ] `notification_sound_desc` — اختار من أي صوت إشعار مثبّت على جهازك بدل الصوت الافتراضي
- [ ] `notification_sound_default` — الصوت الافتراضي
- [ ] `bank_reading_status_title` — قراءة إشعارات البنك
- [ ] `bank_reading_status_desc` — الحالة الحقيقية للصلاحيات — لو الصلاحية متسحوبة من إعدادات النظام، هتلاقيها هنا فوراً
- [ ] `notification_reading_status_label` — قراءة إشعارات البنك
- [ ] `bank_listener_connected_label` — اتصال خدمة القراءة
- [ ] `bank_last_connected_format` — آخر اتصال فعلي: %1$s
- [ ] `bank_listener_never_connected` — الخدمة لم تتصل بعد، حتى لو كانت الصلاحية مفعلة
- [ ] `bank_notification_seen_label` — وصول إشعارات للجهاز
- [ ] `bank_last_seen_format` — آخر إشعار وصل للخدمة: %1$s
- [ ] `bank_notification_never_seen` — لم يصل أي إشعار للخدمة بعد
- [ ] `last_parsed_at_format` — آخر عملية اتقرأت: قبل %d دقيقة
- [ ] `last_parsed_never` — لسه ما اتقرتش أي عملية
- [ ] `test_parse_success` — نجح التحليل ✓
- [ ] `test_parse_merchant` — التاجر
- [ ] `test_parse_failed` — فشل التحليل — الرسالة العينة معملهاش parser
- [ ] `test_notification_title` — اختبار زاد — عملية تجريبية
- [ ] `test_notification_body` — تم خصم 123.45 جنيه من حسابك — اختبار رصد
- [ ] `bank_sync_rejected_title` — آخر الرسائل اللي اترفضت
- [ ] `bank_sync_rejected_hint` — لو بنك أو محفظة معينة مش بتتسجل، هتلاقي السبب هنا (OTP، رسالة معلّقة، أو نص محصلش فهمه).
- [ ] `status_on` — شغالة ✓
- [ ] `status_off` — مش شغالة

### TelegramBinding.kt — 27 من 28

- [ ] `telegram_code_copied_toast` — تم نسخ الكود
- [ ] `telegram_no_app_toast` — مفيش تطبيق تليجرام أو متصفح على الجهاز
- [ ] `telegram_link_title` — ربط تليجرام
- [ ] `telegram_link_subtitle` — شوف رصيدك ومعاملاتك من بوت زاد
- [ ] `telegram_status_linked` — مربوط بتليجرام
- [ ] `telegram_status_not_linked` — مش مربوط
- [ ] `telegram_already_linked` — حسابك مربوط بتليجرام بالفعل ✅
- [ ] `telegram_unlink_action` — فصل الربط
- [ ] `telegram_code_failed` — معرفناش نولّد كود — جرب تاني
- [ ] `telegram_new_code_action` — كود جديد
- [ ] `telegram_bot_handle_label` — بوت زاد على تليجرام
- [ ] `telegram_open_bot_action` — افتح البوت واربط تلقائياً
- [ ] `telegram_manual_hint` — مش اشتغل الزرار؟ ابعت للبوت: /start ‏%1$s
- [ ] `telegram_code_expiry_note` — الكود صالح ١٠ دقايق بس — دوس عليه عشان تنسخه
- [ ] `telegram_prompt_title` — خلّي زاد يكلمك على تيليجرام
- [ ] `telegram_prompt_subtitle` — اربط حسابك مرة واحدة، وزاد يوصلك بالمهم حتى لو التطبيق مقفول.
- [ ] `telegram_prompt_benefit_confirm` — يأكد معاك أي حركة بنكية قبل ما تتحسب من رصيدك
- [ ] `telegram_prompt_benefit_alerts` — ينبهك بالنواقص والفواتير اللي قربت
- [ ] `telegram_prompt_benefit_forecast` — يبعتلك ملخص البيت وتوقع الصرف
- [ ] `telegram_prompt_benefit_log` — تسجل مصروفك برسالة واحدة
- [ ] `telegram_prompt_benefit_voice` — ينبهك بفويس بصوت زاد للحاجات المهمة: دوا اتفوّت، ميعاد قرّب، ميزانية في خطر
- [ ] `telegram_prompt_without_link` — ⚠️ من غير الربط مش هتوصلك التقارير ولا التنبيهات الصوتية برّه التطبيق — تجربة زاد بتبقى ناقصة.
- [ ] `telegram_banner_title` — اربط تليجرام عشان زاد توصلك
- [ ] `telegram_banner_body` — التقارير وتأكيد حركات البنك وفويسات زاد (صباح الخير، الدوا، المواعيد) كلها بتوصل على تليجرام. من غير الربط مش هتوصلك.
- [ ] `telegram_banner_link` — اربط دلوقتي
- [ ] `telegram_community_title` — مجتمع زاد على تليجرام
- [ ] `telegram_community_subtitle` — انضم لقناتنا لتحديثات الأسعار والذكاء الاصطناعي

### SubscriptionsScreen.kt — 26 من 96

- [ ] `total_monthly_subscriptions` — إجمالي الاشتراكات الشهرية
- [ ] `active_subs_count_label` — اشتراكات نشطة
- [ ] `ai_detecting_subscriptions` — زاد يبحث عن اشتراكاتك من المعاملات المالية...
- [ ] `subscriptions_auto_detected_count` — %1$d اشتراك مكتشف تلقائياً
- [ ] `subscriptions_clear_all` — مسح الكل
- [ ] `no_subscriptions_any` — لا توجد اشتراكات
- [ ] `no_items_in_category` — لا توجد عناصر في هذا التصنيف
- [ ] `sub_paid_success` — تم تسجيل سداد %s وترحيل الموعد للشهر القادم بنجاح
- [ ] `renews_today` — يُجدد اليوم
- [ ] `renews_in_days` — يُجدد بعد %1$d يوم
- [ ] `sub_mark_as_paid` — تم الدفع ✓
- [ ] `auto_deduct_toggle_action` — تفعيل/إيقاف الخصم التلقائي
- [ ] `disable` — تعطيل
- [ ] `edit_subscription_dialog_title` — تعديل الاشتراك
- [ ] `add_subscription_dialog_title` — إضافة اشتراك جديد
- [ ] `subscriptions_presets_title` — الخدمات والاشتراكات المقترحة:
- [ ] `subscription_obligation_type_title` — تصنيف الالتزام:
- [ ] `installment_total_label` — إجمالي المبلغ
- [ ] `installment_remaining_label` — الأقساط المتبقية
- [ ] `subscription_name_hint` — اسم الاشتراك (مثال: Netflix)
- [ ] `service_provider_hint` — مزود الخدمة
- [ ] `renewal_date_hint` — تاريخ التجديد (YYYY-MM-DD)
- [ ] `pick_date_action` — اختر التاريخ
- [ ] `billing_cycle_label` — دورة الفوترة
- [ ] `subs_suggested_category` — الفئة المقترحة: %1$s
- [ ] `live_search_error_state_hint` — البحث الحي ما ردّش في الوقت. دوس تحديث تاني — وشوف النت لو الحالة اتكررت.

### HomeScreen.kt — 25 من 81

- [ ] `fx_excluded_notice` — استُبعدت %1$d معاملة من الإجمالي — عملتها مالهاش سعر صرف
- [ ] `zad_smart_insight_title` — رؤية زاد الذكي ✨
- [ ] `shop_from_amazon` — تسوق من أمازون
- [ ] `recent_transactions_full_log` — السجل الكامل للمعاملات
- [ ] `budget_save_hint` — اكتب رصيدك الحالي وزاد يمشي عليه: كل دخل بيزوّده وكل مصروف بينقّصه.
- [ ] `manual_balance_hint` — الرقم ده كلمتك الأخيرة — لو زاد حسب غلط، صحّحه من هنا وهو هيمشي عليه.
- [ ] `items_stagnant_hint` — عندك %1$s من فترة وماستخدمتهاش 🤔
- [ ] `items_expiring_soon_hint` — عندك %1$s هيخلص قريب 👀
- [ ] `suggested_recipes_use_it_up` — وصفات تساعدك تستخدمها قبل ما تتلف
- [ ] `suggested_recipes_before_expiry` — وصفات مقترحة بيه قبل ما يضيع
- [ ] `tap_for_more_in_chat` — اضغط للمزيد في شات زاد ←
- [ ] `chef_card_all_depleted_hint` — مخزونك كله خلص — نزّل النواقص في التسوق وأنا أقترحلك أكل.
- [ ] `chef_card_empty_hint` — ضيف أصناف لمخزونك عشان شيف زاد يقترح لك طبق اليوم.
- [ ] `zad_agent` — وكيل زاد
- [ ] `expiring_soon_stat_label` — منتهٍ قريباً
- [ ] `agent_summary_empty` — الملخص مش جاهز لسه — زاد محتاج شوية بيانات أو النت فصل.
- [ ] `no_description_fallback` — بدون وصف
- [ ] `add_expense_title` — إضافة مصروف
- [ ] `add_income_title` — إضافة دخل/راتب
- [ ] `expense_deduction` — خصم (مصروف)
- [ ] `income_deposit` — إيداع (راتب)
- [ ] `description_hint` — الوصف (مثال: راتب، إيجار)
- [ ] `category_hint` — التصنيف (سوبرماركت، فواتير...)
- [ ] `deduct_amount` — خصم المبلغ
- [ ] `add_amount` — إضافة المبلغ

### PriceReportingScreen.kt — 23 من 29

- [ ] `price_report_submit_title` — سجّل السعر
- [ ] `price_report_subtitle` — ساهم في تحديث أسعار السوق الحية. بيانات العائلة تساعد تنبؤات أفضل.
- [ ] `price_report_item_label` — اسم السلعة
- [ ] `price_report_item_hint` — مثل: خبز، لبن، بيض
- [ ] `price_report_price_hint` — مثل: 15.50
- [ ] `price_report_region_label` — المنطقة
- [ ] `price_report_region_hint` — مثل: القاهرة، الجيزة
- [ ] `price_report_store_label` — اسم المتجر (اختياري)
- [ ] `price_report_store_hint` — مثل: كارفور، سبينيز
- [ ] `price_report_send` — أرسل السعر
- [ ] `price_board_title` — لوحة الأسعار
- [ ] `price_board_your_contributions` — مساهماتك
- [ ] `price_report_new` — سجّل سعر جديد
- [ ] `price_top_contributors` — أكثر المشاركين 🏆
- [ ] `price_board_empty_title` — لسه مفيش مساهمات
- [ ] `price_board_empty_subtitle` — سجّل أول سعر شفته في السوق — مساهمتك بتظهر هنا وبتساعد جيرانك يلاقوا أرخص مكان.
- [ ] `price_report_first` — سجّل أول سعر
- [ ] `cheapest_title` — أرخص سعر حواليك
- [ ] `cheapest_subtitle` — من بلاغات مجتمع زاد آخر ١٤ يوم — مش أسعار رسمية
- [ ] `cheapest_city_label` — المدينة أو المنطقة (اختياري)
- [ ] `cheapest_failed` — مقدرناش نجيب الأسعار دلوقتي
- [ ] `cheapest_empty_title` — لسه مفيش بلاغات هنا
- [ ] `cheapest_empty_subtitle` — كن أول واحد يبلّغ عن سعر — جيرانك هيشكروك

### ZadViewModel.kt — 23 من 31

- [ ] `zad_welcome_message` — Welcome! I'm Zad 🤖, your smart family assistant. How can I help you today? You can ask me about recipes, check your fridge, or add missing i…
- [ ] `zad_undo_inventory` — ↩️ Undone — your inventory is back to how it was.
- [ ] `zad_cancel_reply` — Okay, cancelled.
- [ ] `zad_inventory_added` — 📦 Added to inventory: %1$s
- [ ] `zad_pharmacy_added` — ✅ Done, added %1$s to your medicine schedule%2$s.
- [ ] `zad_agent_fallback_notice` — ⚠️ My action engine is unavailable right now — this is a general reply from your saved data only, and nothing was executed. If you asked to …
- [ ] `zad_ai_busy` — AI is a bit busy right now 🙏 try again in a moment.
- [ ] `zad_unexpected_error` — An unexpected error occurred.
- [ ] `outbox_stuck_title` — إشعار ما وصلش لزاد
- [ ] `outbox_stuck_body_with_amount` — وصل إشعار بمبلغ %1$s (%2$s) بس ما قدرناش نوصّله. أسجّله؟
- [ ] `outbox_stuck_body_no_amount` — وصل إشعار (%1$s) وما قدرناش نقرا مبلغ منه. راجعه وضيفه يدوي لو معاملة.
- [ ] `manual_balance_correction_title` — تصحيح رصيد يدوي
- [ ] نص مباشر — ⚠️ تنبيه الميزانية — $pct%
- [ ] نص مباشر — 🔔 تجديد ${sub.title} قريب!
- [ ] نص مباشر — 📦 مخزون منخفض
- [ ] نص مباشر — ${target.name} (تعبئة)
- [ ] نص مباشر — اشتراك غير مستغل: ${sub.title}
- [ ] نص مباشر — تكلفة اشتراك عالية: ${sub.title}
- [ ] نص مباشر — ميزانية $cat على وشك النفاد
- [ ] نص مباشر — ⚠️ إنفاق غير مألوف هذا الأسبوع
- [ ] نص مباشر — ${outOfStock.size} صنف خلص
- [ ] نص مباشر — عديت السقف الشهري
- [ ] نص مباشر — الشاشة الرئيسية

### ZadVoiceBottomSheet.kt — 22 من 25

- [ ] `voice_suggestion_budget` — كام فاضل في الميزانية؟
- [ ] `voice_suggestion_spend` — صرفت 50 على القهوة
- [ ] `voice_header_connecting` — بيتّصل…
- [ ] `voice_header_speaking` — زاد بيتكلم…
- [ ] `voice_header_thinking` — بيفكر…
- [ ] `voice_header_live` — عقل زاد • مباشر
- [ ] `voice_sheet_title` — مساعد زاد الصوتي
- [ ] `voice_settings_title` — إعدادات الصوت
- [ ] `voice_status_error_retry` — ⚠️ %1$s اضغط المايك وجرّب تاني
- [ ] `voice_status_connecting` — بيتّصل بزاد…
- [ ] `voice_status_live_speaking` — زاد بيتكلم… اتكلم في أي وقت تقاطعه
- [ ] `voice_status_thinking` — يفكر عقل زاد وينفذ طلبك…
- [ ] `voice_status_live_listening` — زاد سامعك — اتكلم براحتك
- [ ] `voice_status_tap_to_start` — اضغط المايك وكلّم زاد 🎙️
- [ ] `voice_fallback_note` — المكالمة المباشرة مش متاحة دلوقتي، فبكلّمك بالطريقة العادية بنفس الصوت
- [ ] `voice_retry_live` — جرّب المكالمة المباشرة تاني
- [ ] `voice_hold_to_talk` — دوس مع الاستمرار واتكلم
- [ ] `voice_release_to_send` — بسمعك… سيب عشان أرد
- [ ] `voice_hold_to_interrupt` — دوس واتكلم عشان تقاطعني
- [ ] `voice_chips_label` — أو اختار سؤال جاهز:
- [ ] `voice_settings_persona` — شخصية الصوت
- [ ] `voice_settings_info_body` — نفس الصوت اللي بتختاره هنا بيرد عليك في المكالمة وبيقرا الإشعارات. وتقدر تقاطع زاد وهو بيتكلم في أي وقت.

### ZadHomeGlanceCards.kt — 18 من 35

- [ ] `glance_inventory_empty_sub` — صوّر فاتورة السوبرماركت أو ضيف أصنافك، وزاد يقولك إيه قرب يخلص قبل ما تحتاجه
- [ ] `report_section_forecast` — 1. التنبؤات والتدفق المالي للشهر القادم
- [ ] `report_section_household` — 2. كفاءة إدارة المنزل والعائلة
- [ ] `report_share` — 📤 مشاركة التقرير
- [ ] `report_close` — إغلاق التقرير
- [ ] نص مباشر — ${(healthRatio * 100).toInt()}% مكتمل
- [ ] نص مباشر — متبقي ${item.daysLeft} أيام
- [ ] نص مباشر — ضيف اشتراكاتك الشهرية عشان زاد يحسبها في المتاح ويفكّرك بمواعيد التجديد
- [ ] نص مباشر — القسط: ${com.example.data.CurrencyFormatter.format(context, nextCommitment.amount)}
- [ ] نص مباشر — صوّر شريط الدواء أو ضيفه يدوي، وزاد هيفكّرك بمواعيد الجرعات وينبّهك قبل ما يخلص
- [ ] نص مباشر — العقل الثاني: نظام تشغيل فكري ثلاثي الأبعاد
- [ ] نص مباشر — 📄 التقرير المطبوع
- [ ] نص مباشر — 🌐 اسحب للتدوير 3D • باعد أصابعك للتقريب والإبعاد
- [ ] نص مباشر — التقرير الاستراتيجي الشامل لعقل زاد
- [ ] نص مباشر — تاريخ الإصدار: $currentDate
- [ ] نص مباشر — • إجمالي الصرف الفعلي للدورة الحالية: ${com.example.data.CurrencyFormatter.format(context, totalSpent)}.\n
- [ ] نص مباشر — • عقل العائلة المشترك: $familyMembersCount أفراد متصلين ومزامنين لحظياً.\n
- [ ] نص مباشر — 📄 تقرير عقل زاد:\n

### LifeGoalPickerSheet.kt — 17 من 17

- [ ] `life_goal_sheet_title` — إيه أهم هدف لبيتك دلوقتي؟
- [ ] `life_goal_sheet_subtitle` — اختار واحد — زاد هيتابعه معاك كل أسبوع لمدة ٣ شهور، وتقدر تلغيه في أي وقت.
- [ ] `life_goal_preset_save_title` — أوفّر مبلغ كل شهر
- [ ] `life_goal_preset_save_desc` — حدد المبلغ، وزاد يتابع صرفك عشان توصله
- [ ] `life_goal_amount_label` — المبلغ الشهري
- [ ] `life_goal_preset_budget_title` — ألتزم بميزانية الشهر
- [ ] `life_goal_preset_budget_desc` — زاد ينبهك قبل ما الصرف يسبق الميزانية
- [ ] `life_goal_preset_debts_title` — أسدد ديوني
- [ ] `life_goal_preset_debts_desc` — زاد يتابع معاك المتبقي وأقرب قسط
- [ ] `life_goal_preset_waste_title` — أقلل هدر المطبخ
- [ ] `life_goal_preset_waste_desc` — زاد يفكرك بالأصناف قبل ما تبوظ
- [ ] `life_goal_preset_custom_title` — هدف تاني بكلامي
- [ ] `life_goal_preset_custom_desc` — اكتبه زي ما بتقوله
- [ ] `life_goal_custom_label` — اكتب هدفك
- [ ] `life_goal_error_too_many` — عندك ٥ أهداف شغالة — خلّص واحد أو ألغيه الأول
- [ ] `life_goal_error_generic` — معرفتش أسجل الهدف — جرّب تاني
- [ ] `life_goal_save` — ابدأ الهدف

### PharmacyScreen.kt — 13 من 69

- [ ] `family_pharmacy_action` — أدوية العيلة
- [ ] `exact_alarm_permission_hint` — فعّل "المنبهات الدقيقة" من الإعدادات عشان تنبيهات مواعيد الدواء تشتغل بدقة
- [ ] `pharm_take_dose` — أخذ الجرعة
- [ ] `pharm_reorder` — إعادة طلب
- [ ] `pharm_edit_quantity` — تعديل الكمية
- [ ] `medicine_scan_success` — تم استخراج بيانات الدواء بنجاح
- [ ] `medicine_scan_error` — تعذر قراءة العلبة بدقة، يرجى المحاولة بزاوية أوضح
- [ ] `medicine_scanning_ai` — جاري قراءة علبة الدواء بالذكاء الاصطناعي...
- [ ] `scan_medicine_box_action` — مسح العبوة بالكاميرا
- [ ] `category_hint` — التصنيف (سوبرماركت، فواتير...)
- [ ] `smart_pharmacy_add_dialog_hint` — قول اسم الدواء والجرعة ومواعيدها بشكل عادي، وزاد هيضبطها ويضيفها.
- [ ] `family_pharmacy_empty_title` — لسه مفيش أدوية مسجّلة
- [ ] `family_pharmacy_empty_subtitle` — أي دوا يسجّله أي فرد في العيلة هيظهر هنا

### FamilyScreen.kt — 12 من 142

- [ ] `family_intro_hint` — يمكنك إنشاء عائلة جديدة لتكون أنت المدير، أو الانضمام لعائلة موجودة عبر كود الدعوة.
- [ ] `tap_to_open` — أو اضغط:
- [ ] `shared_grocery_list_hint` — قائمة المشتريات التي تمت إضافتها من قبل أفراد العائلة أو اقترحها زاد.
- [ ] `approved_emoji` — تمت الموافقة ✅
- [ ] `rejected_emoji` — تم الرفض ❌
- [ ] `leave_family_confirm_body` — هتفقد الوصول لشات العائلة والمهام والأرصدة المشتركة. متأكد إنك عايز تغادر العائلة؟
- [ ] `delete_family_confirm_body` — إنت آخر فرد في العائلة دي. حذفها هيمسح الشات والمهام وكل البيانات نهائياً ومينفعش ترجعها، وتقدر تنشئ عائلة جديدة بعد كده.
- [ ] `spend_limits_hint` — حدد أقصى مبلغ يقدر %1$s يصرفه يومياً/أسبوعياً. اتركه فارغاً لإلغاء الحد.
- [ ] `join_family_scan_message` — انضم إلى عائلتي في تطبيق زاد! امسح الرمز: zad://invite?code=%1$s
- [ ] `join_family_link_message` — انضم إلى عائلتي في تطبيق زاد! رابط الدعوة: zad://invite?code=%1$s
- [ ] `join_family_code_message` — انضم إلى عائلتي في تطبيق زاد! كود الدعوة: %1$s
- [ ] `family_typing_many` — %1$s يكتبون...

### SignUpScreen.kt — 12 من 17

- [ ] `auth_signup_action` — إنشاء حساب
- [ ] `auth_signup_subtitle` — أدخل بياناتك للمتابعة
- [ ] `auth_username_label` — اسم المستخدم
- [ ] `auth_username_hint` — محمد أحمد
- [ ] `auth_email_placeholder` — your.email@gmail.com
- [ ] `auth_toggle_password_visibility` — إظهار/إخفاء كلمة المرور
- [ ] `auth_terms_agree_prefix` — أوافق على
- [ ] `auth_terms_link` — الشروط وسياسة الخصوصية
- [ ] `auth_signup_done_title` — تم التسجيل بنجاح
- [ ] `auth_signup_done_body` — تم التسجيل بنجاح! جاري التوجيه...
- [ ] `auth_have_account` — لديك حساب بالفعل؟
- [ ] `auth_terms_agree_action` — موافق ومتابعة

### HomeActivationCard.kt — 11 من 12

- [ ] `home_activation_title` — جهّز زاد لبيتك
- [ ] `activation_done_hint` — كل حاجة جاهزة! 🎉 جرب تقول لزاد "صرفت ٥٠ بقالة" بالصوت أو من بوت تليجرام — هيسألك تأكيد ويسجلها.
- [ ] `home_activation_subtitle` — أربع خطوات تجعل الرصيد والتنبيهات والتوقعات مفيدة من أول يوم
- [ ] `home_activation_balance_title` — ثبّت رصيد البداية
- [ ] `home_activation_balance_desc` — اكتب المبلغ الموجود الآن ليحسب زاد السحب والإيداع بدقة
- [ ] `home_activation_bank_title` — فعّل قراءة إشعارات البنك
- [ ] `home_activation_bank_desc` — اسمح لزاد بالتقاط العمليات وعرضها للتأكيد
- [ ] `home_activation_inventory_title` — أضف أول صنف للبيت
- [ ] `home_activation_inventory_desc` — ابدأ بصنف متكرر ليتعلم زاد استهلاكك
- [ ] `home_activation_goal_title` — حدد أول هدف لبيتك
- [ ] `home_activation_goal_desc` — زاد هيتابعه معاك كل أسبوع

### InventoryScreen.kt — 10 من 39

- [ ] `suggest_recipe_for_expiring_prompt` — اقترح لي وصفة سريعة تستخدم هذه المكونات التي تنتهي قريباً:
- [ ] `amazon_buy_this` — اشتريه من أمازون
- [ ] `photograph_inventory` — تصوير المخزون
- [ ] `add_manually` — إضافة يدوية
- [ ] `inventory_shortages_count` — نواقص المخزون (%1$d)
- [ ] `estimated_cost_unknown` — غير محدد
- [ ] `inventory_empty` — المخزون فارغ
- [ ] `inventory_empty_hint` — ابدأ بإضافة منتجات لتنظم مخزون منزلك
- [ ] `added_to_list_label` — أُضيفت
- [ ] `add_new_product` — إضافة منتج جديد

### ZadSubscriptionPaywallScreen.kt — 10 من 15

- [ ] `paywall_current_plan` — أنت مشترك حالياً في باقة: %1$s
- [ ] `paywall_price_loading` — جاري تحميل السعر…
- [ ] `ad_loading_retry_toast` — جاري تحميل الإعلان... ثواني وجرب تاني 🎬
- [ ] `ad_failed_toast` — الإعلان غير متاح حالياً، حاول بعد قليل
- [ ] `ad_loading_text` — جاري التحميل...
- [ ] نص مباشر — تجربة فورية بلا إعلانات، ذكاء اصطناعي فوري، ومزامنة عائلية ذكية عبر متجر Google Play الرسمي.
- [ ] نص مباشر — جميع المزايا مفعلة ونشطة في حسابك
- [ ] نص مباشر — اشترك في ${selectedPlan.titleAr} عبر Google Play
- [ ] نص مباشر — يتم الدفع وتجديد الاشتراك الشهري بأمان عبر حساب Google Play الخاص بك، مع إمكانية الإلغاء في أي وقت من متجر التطبيقات.
- [ ] نص مباشر — شاهد 3 إعلانات للحصول على 5 رسائل ذكاء اصطناعي وجلسة نشطة لمدة 12 ساعة.

### TransactionProposalCard.kt — 9 من 18

- [ ] `bank_proposal_needs_classification` — حدد الاتجاه
- [ ] `bank_proposal_amount` — %1$.2f %2$s
- [ ] `bank_proposal_review_note` — لن يتغير الرصيد قبل قرارك.
- [ ] `bank_proposal_failed` — تعذر تنفيذ القرار. حاول مرة أخرى.
- [ ] `bank_proposal_processing` — جارٍ تنفيذ القرار…
- [ ] `bank_proposal_duplicate_question` — توجد عملية أخرى بنفس المبلغ في نفس الوقت تقريبًا. هل هذه نفس المعاملة؟
- [ ] `bank_proposal_duplicate_same` — نفس المعاملة
- [ ] `bank_proposal_duplicate_separate` — عملية أخرى
- [ ] `bank_proposal_correct_direction` — الاتجاه غير صحيح؟

### NotificationCenterScreen.kt — 8 من 9

- [ ] `notif_none_new_spoken` — مفيش تنبيهات جديدة
- [ ] `notif_unread_count` — %1$d غير مقروء
- [ ] `notif_read_aloud_cd` — قراءة التنبيهات صوتيًا
- [ ] `no_notifications_yet` — لا توجد إشعارات حالياً.
- [ ] `notif_empty_subtitle` — هنعلمك أول ما يحصل حاجة تستاهل انتباهك
- [ ] `notif_section_intelligence` — تنبيهات ذكاء زاد
- [ ] `notif_section_brain` — تنبيهات عقل زاد
- [ ] `app_notifications_title` — إشعارات التطبيق

### ProfileScreen.kt — 8 من 64

- [ ] `behavior_consent_explanation` — زاد يحلل بيانات صرفك واستهلاكك (المعاملات، المخزون، الاشتراكات) لتقديم:  • تنبؤات مخصصة للمصاريف • ترشيحات ذكية للمنتجات • تحليل أسبوعي للسل…
- [ ] `regional_settings_subtitle` — اللغة، البلد، والعملة
- [ ] `new_life_goal_title` — New life goal
- [ ] `new_life_goal_subtitle` — Let Zad track a saving or habit goal for you
- [ ] `new_life_goal_name` — Goal name
- [ ] `new_life_goal_metric` — How do we measure it? (e.g. 500 SAR/month)
- [ ] `new_life_goal_deadline` — Deadline (optional)
- [ ] `new_life_goal_deadline_hint` — e.g. 2026-12-31

### LoginScreen.kt — 8 من 16

- [ ] `auth_login_subtitle` — أدخل بريدك الإلكتروني وكلمة المرور
- [ ] `auth_toggle_password_visibility` — إظهار/إخفاء كلمة المرور
- [ ] `auth_forgot_password` — نسيت كلمة المرور؟
- [ ] `auth_no_account` — ليس لديك حساب؟
- [ ] `auth_register_now` — سجل الآن
- [ ] `auth_reset_title` — استعادة كلمة المرور
- [ ] `auth_reset_body` — أدخل بريدك الإلكتروني. سنرسل لك رابطاً لاستعادة كلمة المرور.
- [ ] `auth_reset_sent` — تم إرسال الرابط بنجاح!

### WeekWithZadCard.kt — 7 من 7

- [ ] `week_share_title` — أسبوعي مع زاد
- [ ] `week_share_action` — شارك أسبوعك
- [ ] `week_share_first_week` — أول أسبوع مع زاد
- [ ] `week_share_less` — صرفت أقل بـ %1$d٪ من الأسبوع اللي فات
- [ ] `week_share_more` — صرفت أكتر بـ %1$d٪ من الأسبوع اللي فات
- [ ] `week_share_same` — نفس صرف الأسبوع اللي فات بالظبط
- [ ] `week_share_top_category` — أكتر حاجة صرفت عليها: %1$s

### ZadKnowledgeMapScreen.kt — 6 من 27

- [ ] `knowledge_map_legend_live` — فيه رؤية حية من زاد الآن
- [ ] `knowledge_map_domain_empty` — لا يوجد عناصر هنا حالياً
- [ ] `knowledge_map_open_screen` — فتح الشاشة
- [ ] نص مباشر — تكبير
- [ ] نص مباشر — تصغير
- [ ] نص مباشر — إعادة ضبط

### AmazonAffiliateWidget.kt — 6 من 8

- [ ] `amazon_affiliate_disclosure` — رابط شراء أفلييت — عمولة لزاد بدون أي زيادة عليك
- [ ] `amazon_search_direct` — دوّر على المنتج مباشرة في أمازون
- [ ] `amazon_search_action` — ابحث في أمازون
- [ ] `amazon_picks_widget_title` — ترشيحات الشراء من أمازون
- [ ] `amazon_picks_disclosure` — زاد بيقترح عليك منتجات من أمازون تناسب احتياجاتك. قد نحصل على عمولة من المشتريات.
- [ ] `amazon_picks_enable` — تفعيل الترشيحات

### AdEnergyBatteryCard.kt — 5 من 5

- [ ] `ad_energy_title` — بطارية شحن الذكاء الاصطناعي
- [ ] `ad_energy_refill_hint` — يتجدد رصيدك التلقائي كل 5 ساعات، أو شاهد %1$d إعلانات للشحن الفوري (+5 رسائل).
- [ ] `ad_loading_text` — جاري التحميل...
- [ ] `ad_watch_action` — مشاهدة فيديو (%1$d/%2$d)
- [ ] `upgrade_action` — ترقية ⭐

### LiveMarketTicker.kt — 5 من 5

- [ ] `market_approx_prices` — أسعار استرشادية تقريبية — اضغط للتحديث الحي
- [ ] `market_ticker_contribute` — ساهم بسعر
- [ ] `auto_comp_livemarketticker_80931` — جاري جلب الأسعار...
- [ ] `auto_comp_livemarketticker_69159` — تعذر جلب الأسعار الحية الآن — جرب تاني
- [ ] نص مباشر — تحديث الأسعار

### BudgetScreen.kt — 5 من 69

- [ ] `challenge_stop_body` — السلسلة هتقف والأيام اللي كسبتها هتفضل محسوبة. تقدر تبدأ تاني وقت ما تحب.
- [ ] `budget_suggestion_text` — زاد يقترح تعديل ميزانيتك إلى %1$s بناءً على متوسط آخر شهرين
- [ ] `no_category_budgets_hint` — لسه ما حددتش ميزانية لأي فئة. اضغط "تحديد فئة" عشان زاد يتابعلك كل فئة لوحدها.
- [ ] `no_transactions_bank_hint` — أضف معاملة أو اربط البنك لتتبع مصاريفك تلقائياً
- [ ] `tx_delete_cd` — مسح المعاملة

### ChefRecipeCards.kt — 4 من 7

- [ ] `chef_badge_from_inventory` — ✓ مكتملة من مخزونك
- [ ] `chef_recipe_dislike_action` — معجبتنيش
- [ ] `auto_comp_chefrecipecards_34776` — ضيفهم لقائمة التسوق
- [ ] `auto_comp_chefrecipecards_23405` — اضغط للخطوات

### CustomerProfileSection.kt — 4 من 5

- [ ] `profile_save_failed` — مقدرناش نحفظ الملف — جرب تاني
- [ ] `who_are_you_title` — عرّفني بنفسك
- [ ] `who_are_you_body` — اسمك، وتحب أكلمك بصيغة راجل ولا ست، وشغلك وميعاد قبضك — عشان أكلمك صح وأفتكرك.
- [ ] `who_are_you_cta` — يلا نتعرّف

### LocationAlertsCard.kt — 4 من 7

- [ ] `location_alerts_toggle_label` — تنبيهات ذكية وأنت قريب من متجر
- [ ] `location_alerts_enabled_hint` — مفعّلة — هتوصلك تنبيهات لما تكون قريب من متجر
- [ ] `location_alerts_toggle_hint` — زاد يفكّرك بنواقصك من المؤن أو الدواء لما تكون قريب من سوبرماركت أو صيدلية، ويتعلّم مكان بيتك (بيفضل على موبايلك بس) عشان لما ترجع يقولك صرف…
- [ ] `location_alerts_settings_hint` — أندرويد ما بيسمحش بطلب إذن الموقع في الخلفية من داخل التطبيق — اختر «السماح طوال الوقت» من الإعدادات.

### AppointmentsScreen.kt — 4 من 46

- [ ] `appointments_empty_subtitle` — سجّل ميعاد أو مشوار، أو قولها لزاد بصوتك — وهي هتفكّرك قبلها.
- [ ] `appointments_voice_hint_example` — «فكّريني بكرة الساعة ٥ أروح البنك» — وهتفكّرك بصوتها قبلها
- [ ] `place_reminders_hint` — قول لزاد «فكّريني لما أروح الصيدلية أجيب بنادول» — هتقولهالك بصوتها أول ما توصل.
- [ ] `place_reminders_location_off` — تنبيهات الموقع مقفولة — التذكيرات دي مش هتشتغل غير لما تفعّلها من الإعدادات.

### ZadMemoryScreen.kt — 4 من 14

- [ ] `profile_save_failed` — مقدرناش نحفظ الملف — جرب تاني
- [ ] `zad_memory_delete_failed_snackbar` — معرفتش أنساها، جرب تاني
- [ ] `habits_clear_body` — هنمسح كل الخروجات المتسجلة (أوقات وصرف ومحلات). المصاريف نفسها مش هتتمسح.
- [ ] `zad_memory_delete_action` — تنسيها

### GroceryPurchasePromptDialog.kt — 3 من 4

- [ ] `grocery_purchase_prompt_title` — اشتريت من %1$s بـ %2$s — ضيف إيه للمخزون؟
- [ ] `grocery_purchase_new_item_hint` — اسم منتج تاني…
- [ ] `grocery_purchase_added_count` — أضفت %1$d أصناف ✅

### PendingSubscriptionsCard.kt — 3 من 3

- [ ] `detected_subscription_title` — زاد لاحظ اشتراك محتمل
- [ ] `detected_subscription_confirm` — تأكيد الإضافة
- [ ] `detected_subscription_dismiss` — مش اشتراك

### PremiumHomeComponents.kt — 3 من 10

- [ ] `current_balance_label` — رصيدك دلوقتي
- [ ] `chef_card_empty_hint` — ضيف أصناف لمخزونك عشان شيف زاد يقترح لك طبق اليوم.
- [ ] `zad_chef_suggestions` — شيف زاد (اقتراحات ذكية)

### WhyChangedSheet.kt — 3 من 3

- [ ] `auto_comp_whychangedsheet_38518` — آخر التغييرات
- [ ] `auto_comp_whychangedsheet_19473` — تعديلات زاد الآلية على بياناتك — إيه اتغيّر، وإمتى
- [ ] `auto_comp_whychangedsheet_94891` — مفيش تعديلات آلية مسجلة لسه

### ZadBezierSpendChart.kt — 3 من 3

- [ ] نص مباشر — منحنى نبض الإنفاق التحليلي
- [ ] نص مباشر — إجمالي الأسبوع: ${CurrencyFormatter.format(context, totalWeekly)}
- [ ] نص مباشر — آخر 7 أيام 📈

### NearbyDealsScreenFull.kt — 3 من 6

- [ ] `nearby_deals_disclaimer` — مسافات حقيقية من خرائط OpenStreetMap المجتمعية — قد لا تكون كاملة. هذه الشاشة تعرض قرب المتاجر ونواقص مخزونك، وليست أسعاراً أو عروضاً لحظية.
- [ ] `loading` — Loading…
- [ ] `no_stores_found` — No stores found nearby — check location permission.

### ShoppingListScreen.kt — 3 من 28

- [ ] `auto_shoppinglist_76247` — اقتراح: بديل من أمازون
- [ ] `affiliate_clicks_recorded` — زاد سجّل %1$d نقرة على ترشيحات أمازون
- [ ] `affiliate_withdraw_consent` — إيقاف الترشيحات

### OnboardingScreen.kt — 3 من 7

- [ ] `auth_logo_content_description` — شعار زاد
- [ ] `cta_enter` — ابدأ مع زاد
- [ ] `auto_onboarding_21316` — ليس لديك حساب؟ أنشئ حساباً جديداً

### FamilyViewModel.kt — 3 من 5

- [ ] نص مباشر — 🚨 نداء طوارئ من ${curr.myMemberInfo.alias}
- [ ] نص مباشر — موافق! ✅
- [ ] نص مباشر — مهمة جديدة 📋

### AgentProposalsCard.kt — 2 من 4

- [ ] `agent_proposal_title_single` — زاد مستني تأكيدك
- [ ] `agent_proposal_title_plural` — زاد مستني تأكيدك على دول

### HabitsCard.kt — 2 من 12

- [ ] `habits_subtitle` — اللي زاد اتعلمته من صرفك وخروجاتك — من غير أماكن ولا إحداثيات
- [ ] `habits_empty` — لسه بتتعلم عاداتك — سجّل مصاريفك وفعّل تنبيهات الموقع وهتبان هنا

### InventoryCheckInCard.kt — 2 من 4

- [ ] `inventory_checkin_question` — هل خلص %1$s؟
- [ ] `inventory_checkin_hint` — حسب معدل استهلاكك، المفروض قرب يخلص

### ZadAgentOverlay.kt — 2 من 6

- [ ] `auto_comp_zadagentoverlay_90994` — زاد بيكتب...
- [ ] نص مباشر — فتح الشات الكامل

### BrainHealthScreen.kt — 2 من 31

- [ ] `brain_health_error_message` — معرفتش أقرا حالة العقل دلوقتي. ده مش معناه إن كل حاجة تمام — معناه إني مش شايف.
- [ ] `brain_health_quota_note` — الرصيد ده بتاع ردود الشات بس، وبيتصفّر كل يوم بتوقيت جرينتش — مالوش علاقة بشغل زاد في الخلفية

### NearbyDealsScreen.kt — 2 من 2

- [ ] `refill_needed_reminder_hint` — دواء قرب يخلص: %1$s
- [ ] `low_stock_reminder_hint` — ينقصك: %1$s

### StatementImportScreen.kt — 2 من 17

- [ ] `statement_import_intro` — اختر ملف CSV من كشف حسابك — هتحدد بنفسك أي عمود هو التاريخ والمبلغ قبل الاستيراد، ومفيش حاجة بتتسجل غير بعد ما تراجعها.
- [ ] `statement_no_rows_subtitle` — الملف اتقرا لكن مفيهوش صفوف أقدر أستوردها — اتأكد إنه كشف حساب وإن صيغته CSV أو PDF مقروء.

### MarketSelectionScreen.kt — 2 من 4

- [ ] `auto_marketselection_32367` — وين موطنك؟
- [ ] `auto_marketselection_17720` — زاد بيتكلم بلهجتك وبيحسب مصروفك بعملة بلدك

### BrokeModeCards.kt — 1 من 13

- [ ] `broke_mode_dialog_body` — فاضل %1$d يوم. اكتب اللي معاك فعلاً، أو سيبه فاضي وأحسب من رصيدك.

### CustomerProfileCard.kt — 1 من 57

- [ ] `profile_card_subtitle` — زاد بتعرف ده عنك وبتكلمك على أساسه — عدّله براحتك

### OrbAccessoryPicker.kt — 1 من 12

- [ ] `orb_picker_next` — فاضل %1$d من عيلتك ينضموا وتفتح «%2$s»

### TravelBanner.kt — 1 من 3

- [ ] `travel_banner_message` — شكلك في %1$s — أحوّل لـ %2$s؟

### ZadCategoryGridPicker.kt — 1 من 8

- [ ] نص مباشر — طعام ومؤن

### ZadShare.kt — 1 من 1

- [ ] `orb_invite_message` — 🌱 تعالى انضم لعيلتنا على زاد — بنظبط البيت والفلوس سوا  ادخل من هنا: %1$s أو اكتب الكود: %2$s

### ZadShell.kt — 1 من 27

- [ ] `kids_mode_full_mode` — الوضع الكامل 🔒

### AgentActionLogScreen.kt — 1 من 4

- [ ] `agent_action_log_empty_subtitle` — أي حاجة زاد يسجّلها أو يعدّلها هتظهر هنا

### BudgetGateScreen.kt — 1 من 7

- [ ] `budget_gate_body` — زاد ما بيخترعش أرقام. من غير السقف مفيش "متبقي" ولا "متاح" — وكل رقم هتشوفه هيبقى تخمين.

### MaintenanceScreen.kt — 1 من 21

- [ ] `category_hint` — التصنيف (سوبرماركت، فواتير...)

### PantryShoppingScreen.kt — 1 من 5

- [ ] `contribute_price_action` — ساهم بسعر

### TermsOfServiceScreen.kt — 1 من 10

- [ ] `auto_termsofservice_95498` — آخر تحديث: يوليو 2026  من فضلك اقرأ شروط الاستخدام دي بعناية قبل ما تستخدم تطبيق زاد.

### ZadQuestionCard.kt — 1 من 3

- [ ] `answer_yes` — أيوة
