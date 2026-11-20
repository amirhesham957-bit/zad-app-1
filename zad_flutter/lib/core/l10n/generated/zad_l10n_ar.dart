// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'zad_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class ZadL10nAr extends ZadL10n {
  ZadL10nAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'زاد';

  @override
  String get settingsLanguageSection => 'اللغة';

  @override
  String get languageSystem => 'زي الموبايل';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageEnglishPreview =>
      'الإنجليزي لسه بيتترجم — شاشات كتير هتفضل عربي لحد ما يخلص.';

  @override
  String get authTagline => 'تدبير ذكي لبيت هادئ';

  @override
  String get authSignInTitle => 'تسجيل الدخول';

  @override
  String get authSignInSubtitle => 'أدخل بريدك الإلكتروني وكلمة المرور';

  @override
  String get authEmail => 'البريد الإلكتروني';

  @override
  String get authPassword => 'كلمة المرور';

  @override
  String get authTogglePassword => 'إظهار/إخفاء كلمة المرور';

  @override
  String get authForgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get authSignInButton => 'دخول';

  @override
  String get authNoAccount => 'ليس لديك حساب؟ ';

  @override
  String get authSignUpNow => 'سجل الآن';

  @override
  String get authResetTitle => 'استعادة كلمة المرور';

  @override
  String get authResetBody =>
      'أدخل بريدك الإلكتروني. سنرسل لك رابطاً لاستعادة كلمة المرور.';

  @override
  String get authResetSent => 'تم إرسال الرابط بنجاح!';

  @override
  String get authNewPasswordTitle => 'كلمة سر جديدة';

  @override
  String get authNewPasswordBody => 'اكتب كلمة السر الجديدة لحسابك.';

  @override
  String get authNewPasswordSave => 'احفظ';

  @override
  String get authNewPasswordDone => 'اتغيرت كلمة السر.';

  @override
  String get commonClose => 'إغلاق';

  @override
  String get commonSend => 'إرسال';

  @override
  String get authTermsDecline => 'رفض';

  @override
  String get authTermsAccept => 'موافق ومتابعة';

  @override
  String get authCountry => 'البلد';

  @override
  String get authPickCountry => 'اختار بلدك';

  @override
  String get authSignUpTitle => 'إنشاء حساب';

  @override
  String get authSignUpSubtitle => 'أدخل بياناتك للمتابعة';

  @override
  String get authName => 'اسم المستخدم';

  @override
  String get authNameHint => 'محمد أحمد';

  @override
  String get authAgreeTo => 'أوافق على ';

  @override
  String get authTermsLink => 'الشروط وسياسة الخصوصية';

  @override
  String get authSignUpDone => 'تم التسجيل بنجاح! جاري التوجيه...';

  @override
  String get authHaveAccount => 'لديك حساب بالفعل؟ ';

  @override
  String get authSignOut => 'اخرج من الحساب';

  @override
  String get authSignOutTitle => 'تخرج من الحساب؟';

  @override
  String get authSignOutBody => 'هنحتاج تدخل تاني عشان توصل لحساباتك.';

  @override
  String get commonWait => 'استنى';

  @override
  String get adInlineLabel => 'إعلان';

  @override
  String get authSignOutConfirm => 'اخرج';

  @override
  String get authErrorInvalidCredentials => 'الإيميل أو كلمة السر مش مظبوطة.';

  @override
  String get authErrorEmailTaken =>
      'الإيميل ده مسجّل قبل كده. جرّب تدخل بيه، أو غيّر كلمة السر.';

  @override
  String get authErrorWeakPassword =>
      'كلمة السر قصيرة — خليها ٦ حروف على الأقل.';

  @override
  String get authErrorInvalidEmail => 'الإيميل ده شكله مش مظبوط.';

  @override
  String get authErrorEmailNotConfirmed =>
      'لسه محتاج تأكّد الإيميل. بصّ في رسايلك على اللينك اللي بعتناه.';

  @override
  String get authErrorRateLimited =>
      'جرّبت مرات كتير في وقت قصير. استنى شوية وحاول تاني.';

  @override
  String get authErrorSignupDisabled => 'التسجيل مقفول دلوقتي.';

  @override
  String get authErrorUserBanned => 'الحساب ده موقوف.';

  @override
  String get authErrorOffline => 'مفيش اتصال بالنت — الدخول محتاج نت.';

  @override
  String get authErrorServer => 'الخدمة مش بتردّ دلوقتي. حاول تاني بعد شوية.';

  @override
  String get authErrorUnknown => 'حصل خطأ مش متوقع. حاول تاني.';

  @override
  String authSignOutPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'فيه $count عمليات لسه ما اتبعتش للسيرفر. لو خرجت دلوقتي مش هتتبعت. الأحسن تستنى لما النت يرجع.',
      one:
          'فيه $count عملية لسه ما اتبعتش للسيرفر. لو خرجت دلوقتي مش هتتبعت. الأحسن تستنى لما النت يرجع.',
    );
    return '$_temp0';
  }

  @override
  String get paywallBasicTitle => 'الأساسية (Basic)';

  @override
  String get paywallBasicBadge => 'الأكثر اقتصاداً';

  @override
  String get paywallBasicPerkNoAds => 'من غير إعلانات خالص';

  @override
  String get paywallBasicPerkAttempts =>
      '300 محاولة في الشهر (حوالي 10 في اليوم)';

  @override
  String get paywallBasicPerkPriority =>
      'مكانك محجوز وقت الزحمة، وزاد بيفتكر كلامكم أطول';

  @override
  String get paywallBasicPerkTelegram => 'صور وفويس في بوت تليجرام';

  @override
  String get paywallPlusTitle => 'المتقدمة (Plus)';

  @override
  String get paywallPlusBadge => 'الأكثر شعبية';

  @override
  String get paywallAllBasicPerks => 'كل مزايا الأساسية';

  @override
  String get paywallPlusPerkAttempts =>
      '1000 محاولة في الشهر (حوالي 33 في اليوم)';

  @override
  String get paywallPlusPerkDaily => 'تكفي مسح فواتير وتحليل عميق كل يوم';

  @override
  String get paywallFamilyTitle => 'العيلة (Family)';

  @override
  String get paywallFamilyBadge => 'أكبر رصيد';

  @override
  String get paywallFamilyPerkAttempts =>
      '2500 محاولة في الشهر (حوالي 83 في اليوم)';

  @override
  String get paywallFamilyPerkHeavy => 'لأكتر حد بيعتمد على زاد في البيت';

  @override
  String get paywallNoPlayTitle => 'Google Play مش متاح';

  @override
  String get paywallNoPlayBody =>
      'الاشتراك بيتم من Google Play. لو زاد متثبت من ملف مش من المتجر، نزّله من Google Play وبعدين اشترك من هنا.';

  @override
  String get paywallNotOnPlayTitle => 'الباقة لسه مش على المتجر';

  @override
  String get paywallNotOnPlayBody =>
      'الباقة دي لسه ماتفعّلتش على Google Play. جرّب تاني قريب.';

  @override
  String get paywallFailedTitle => 'مقدرناش نفتح Google Play';

  @override
  String get paywallFailedBody =>
      'حصلت مشكلة وإحنا بنفتح الدفع. اتأكد من النت وجرّب تاني.';

  @override
  String get commonOk => 'تمام';

  @override
  String get paywallTitle => 'اشتراكات زاد بريميوم (Zad VIP)';

  @override
  String get paywallHeadline => 'اختر خطة زاد المناسبة لعائلتك';

  @override
  String get paywallSubhead =>
      'من غير إعلانات، برصيد محاولات أكبر، ومكان محجوز وقت الزحمة — والدفع عبر متجر Google Play الرسمي.';

  @override
  String get paywallSafePayment => 'دفع آمن ومحمي';

  @override
  String get paywallBillingNote =>
      'يتم الدفع وتجديد الاشتراك الشهري بأمان عبر حساب Google Play الخاص بك، مع إمكانية الإلغاء في أي وقت من متجر التطبيقات.';

  @override
  String get paywallStayFree => 'أو كمّل على المجاني';

  @override
  String get paywallFreeTerms =>
      'كل ساعتين: ٢٠ رسالة و٣ أسئلة صوتية وصورتين، وتسجيل المصاريف مجاني دايماً. التحليل العميق بـ٣ رسايل.';

  @override
  String get paywallFromPlay => 'من Google Play';

  @override
  String get paywallAutoRenew => 'اشتراك شهري تجديد تلقائي';

  @override
  String paywallSubscribeTo(String plan) {
    return 'اشترك في $plan عبر Google Play';
  }

  @override
  String paywallAttemptsPerMonth(int count) {
    return '$count محاولة في الشهر';
  }

  @override
  String paywallPricePerMonth(String price) {
    return '$price في الشهر';
  }

  @override
  String paywallStatePlan(String plan) {
    return 'خطتك دلوقتي: $plan';
  }

  @override
  String get paywallStateInvite => 'اختار الباقة اللي تناسب بيتك';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navMoney => 'فلوسي';

  @override
  String get navHomeStock => 'بيتي';

  @override
  String get navMore => 'المزيد';

  @override
  String get navFamily => 'العائلة';

  @override
  String get navMyFamily => 'عيلتي';

  @override
  String get navVoiceAssistant => 'زاد — المساعد الصوتي';

  @override
  String get navCamera => 'تصوير الفواتير والمنتجات';

  @override
  String get pulseOneSaved => 'حاجة واحدة محفوظة';

  @override
  String get pulseTwoSaved => 'حاجتين محفوظين';

  @override
  String pulseFewSaved(int n) {
    return '$n حاجات محفوظة';
  }

  @override
  String pulseManySaved(int n) {
    return '$n حاجة محفوظة';
  }

  @override
  String pulseOffline(String what) {
    return 'مفيش نت — $what وهتتبعت أول ما النت يرجع';
  }

  @override
  String get pulseThinking => 'زاد بيفكر…';

  @override
  String get pulseSyncing => 'بنزامن…';

  @override
  String get authPreparingAccount => 'بنجهّز حسابك…';

  @override
  String get shareTooLarge =>
      'الملف أكبر من إن زاد يقراه مرة واحدة — ابعته أصغر';

  @override
  String get shareUnsupported => 'زاد بيقرا الكلام والصور وملفات PDF وCSV بس';

  @override
  String get shareUnreadable => 'مقدرتش أفتح اللي اتشارك — جرّب تبعته تاني';

  @override
  String get shareWhatImage => 'الصورة دي إيه؟';

  @override
  String get shareWhatImageHint =>
      'زاد هيقراها ويوريك اللي لقاه قبل ما يسجل أي حاجة';

  @override
  String get shareReceipt => 'فاتورة شرا';

  @override
  String get shareStatement => 'كشف حساب';

  @override
  String get drawerCompanion => 'رفيق زاد';

  @override
  String get drawerBrain => 'عقل زاد';

  @override
  String get drawerAppointments => 'مواعيدي';

  @override
  String get drawerPlaces => 'أماكني';

  @override
  String get drawerObligations => 'التزاماتي';

  @override
  String get drawerPlans => 'باقات زاد الشهرية';

  @override
  String get drawerShopping => 'قائمة التسوق';

  @override
  String get drawerPharmacy => 'صيدلية العائلة';

  @override
  String get drawerMaintenance => 'صيانة المنزل';

  @override
  String get drawerDocuments => 'مستنداتي';

  @override
  String get drawerNearby => 'العروض والمحلات القريبة';

  @override
  String get drawerTips => 'نصايح زاد';

  @override
  String get drawerTasbiha => 'تسبيحة';

  @override
  String get drawerNotifications => 'الإشعارات';

  @override
  String get drawerAccount => 'حسابي';

  @override
  String get drawerGroupZad => 'زاد';

  @override
  String get drawerGroupMoney => 'الفلوس';

  @override
  String get drawerGroupHome => 'البيت والعيلة';

  @override
  String get drawerAllFeatures => 'كل المزايا';

  @override
  String get placesOrbitHome => 'البيت';

  @override
  String get placesOrbitCaption =>
      'الأقرب للبيت هو اللي بتروحه أكتر، مش المسافة الحقيقية.';

  @override
  String placesHabitVisits(int count) {
    return '$count مرات';
  }

  @override
  String placesHabitVisitsOn(int count, String day) {
    return '$count مرات · غالباً $day';
  }

  @override
  String placesOrbitNode(String name, int count) {
    return '$name، $count مرات';
  }

  @override
  String get memoryGraphResetView => 'رجّع الشبكة مكانها';

  @override
  String get drawerGroupMore => 'أكتر';

  @override
  String get drawerKidsMode => 'وضع الأطفال';

  @override
  String get drawerFullMode => 'الوضع الكامل';

  @override
  String get shellOpenProfile => 'اضغط لعرض الملف الشخصي';

  @override
  String get shellZadUser => 'مستخدم زاد';

  @override
  String get shellHello => 'أهلاً بيك';

  @override
  String shellHelloName(String name) {
    return 'أهلاً يا $name';
  }

  @override
  String shellCompanionTag(String name, int level) {
    return '$name · لفل $level';
  }

  @override
  String widgetSeasonTomorrow(String name) {
    return 'بكرة $name';
  }

  @override
  String widgetSeasonTwoDays(String name) {
    return 'باقي يومين على $name';
  }

  @override
  String widgetSeasonDays(int n, String name) {
    return 'باقي $n أيام على $name';
  }

  @override
  String homeFxExcluded(int count) {
    return 'استُبعدت $count معاملة من الإجمالي — عملتها مالهاش سعر صرف';
  }

  @override
  String get homeBankListening => 'بسمع رسايل البنك وحدّث رصيدك تلقائياً';

  @override
  String get homeBankStopped => 'الاستماع لرسايل البنك وقف — اضغط للإصلاح';

  @override
  String get homeBirthday => 'كل سنة وإنت طيب! 🎂';

  @override
  String homeBirthdayName(String who) {
    return 'كل سنة وإنت طيب يا $who! 🎂';
  }

  @override
  String get homeBirthdayWish => 'زاد بيتمنالك سنة حلوة مليانة خير وراحة بال.';

  @override
  String get homeBirthdayThanks => 'شكراً يا زاد 💚';

  @override
  String get commonHide => 'إخفاء';

  @override
  String homeStoriesLabel(String name) {
    return 'حكايات زاد: $name';
  }

  @override
  String get homeStories => 'حكايات زاد';

  @override
  String get homeCloseDay => 'اقفل يومك';

  @override
  String get homeCloseDayHint =>
      'عشر ثواني: صرفت حاجة كاش النهارده؟ ورفيقك يتعشى';

  @override
  String get coverageBlind => 'لسه مش شايف أي مصروف الدورة دي';

  @override
  String get coverageBlindHint => 'قفّل يومك أو اربط البنك عشان أشوف';

  @override
  String get coverageFull => 'أنا شايف تقريباً كل مصروفك';

  @override
  String get coverageFullHint => 'كمّل كده، الأرقام اللي فوق دي حقيقية';

  @override
  String coveragePartial(String share) {
    return 'أنا شايف حوالي $share من مصروفك';
  }

  @override
  String get coveragePartialHint => 'قفّل يومك أو اربط البنك عشان أشوف أكتر';

  @override
  String get briefTitle => 'موجز زاد النهارده';

  @override
  String get briefAllGood => 'كله تمام — مفيش حاجة مستعجلة النهارده.';

  @override
  String get briefAskZad => 'اسأل زاد عن أي حاجة';

  @override
  String get glanceStockTitle => 'صحة المخزون والنواقص';

  @override
  String get glanceStockSubtitle => 'مراقبة التلف والاحتياج الفعلي';

  @override
  String get glanceOpenStock => 'فتح المخزون ←';

  @override
  String get glanceStockHealth => 'مؤشر سلامة المؤونة';

  @override
  String glanceStockPercent(int percent) {
    return '$percent% مكتمل';
  }

  @override
  String get glanceStockEmpty => 'المخزن لسه فاضي';

  @override
  String get glanceStockEmptyHint =>
      'صوّر فاتورة السوبرماركت أو ضيف أصنافك، وزاد يقولك إيه قرب يخلص قبل ما تحتاجه';

  @override
  String glanceLowCount(int count) {
    return '$count قارب النفاد';
  }

  @override
  String get glanceExpired => 'انتهت صلاحيته';

  @override
  String glanceDaysLeft(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'متبقي $days يوم',
      few: 'متبقي $days أيام',
      two: 'متبقي $days أيام',
      one: 'متبقي $days أيام',
      zero: 'متبقي $days أيام',
    );
    return '$_temp0';
  }

  @override
  String glanceQtyLeft(String qty) {
    return 'متبقي $qty';
  }

  @override
  String get glanceRunningOut => 'قارب ينتهي';

  @override
  String get glanceAddToCart => 'أضف للسلة';

  @override
  String get glancePharmacyEmptyLabel => 'مفيش أدوية مسجّلة';

  @override
  String glanceAdherence(int percent, String verdict) {
    return 'الالتزام بالجرعات: $percent% • $verdict';
  }

  @override
  String get glanceAdherenceGood => 'منتظم';

  @override
  String get glanceAdherenceLow => 'محتاج انتباه';

  @override
  String glanceActiveMedicines(int count) {
    return '$count دواء نشط • لسه بنجمّع بيانات الالتزام';
  }

  @override
  String get glancePharmacyTitle => 'صيدلية العائلة والجرعات';

  @override
  String get glanceOpenPharmacy => 'فتح الصيدلية ←';

  @override
  String get glancePharmacyEmpty => 'الصيدلية فاضية';

  @override
  String get glancePharmacyEmptyHint =>
      'صوّر شريط الدواء أو ضيفه يدوي، وزاد هيفكّرك بمواعيد الجرعات وينبّهك قبل ما يخلص';

  @override
  String get glanceNextDose => 'الجرعة التالية';

  @override
  String get glanceTookDose => 'خدت الجرعة';

  @override
  String glanceDosesPerDay(int count) {
    return '$count جرعة يومياً';
  }

  @override
  String get glanceSubsTitle => 'الاشتراكات الشهرية';

  @override
  String get glanceSubsNone => 'مفيش اشتراكات مسجّلة';

  @override
  String glanceSubsTotal(String amount) {
    return 'إجمالي شهري: $amount';
  }

  @override
  String get glanceSeeAll => 'عرض الكل ←';

  @override
  String get glanceSubsEmpty => 'مفيش اشتراكات لسه';

  @override
  String get glanceSubsEmptyHint =>
      'ضيف اشتراكاتك الشهرية عشان زاد يحسبها في المتاح ويفكّرك بمواعيد التجديد';

  @override
  String glanceNextRenewal(String title) {
    return 'التجديد القادم: $title';
  }

  @override
  String glanceInstalment(String amount) {
    return 'القسط: $amount';
  }

  @override
  String groceryWhatToAdd(String shop, String amount) {
    return 'اشتريت من $shop بـ $amount — ضيف إيه للمخزون؟';
  }

  @override
  String get groceryOtherItem => 'اسم منتج تاني…';

  @override
  String get commonAdd => 'إضافة';

  @override
  String groceryAdded(int count) {
    return 'أضفت $count أصناف ✅';
  }

  @override
  String get commonDone => 'تم';

  @override
  String get activationTitle => 'جهّز زاد لبيتك';

  @override
  String get activationSubtitle =>
      'أربع خطوات تجعل الرصيد والتنبيهات والتوقعات مفيدة من أول يوم';

  @override
  String activationProgress(int done, int total) {
    return '$done من $total';
  }

  @override
  String get activationBalance => 'ثبّت رصيد البداية';

  @override
  String get activationBalanceHint =>
      'اكتب المبلغ الموجود الآن ليحسب زاد السحب والإيداع بدقة';

  @override
  String get activationBank => 'فعّل قراءة إشعارات البنك';

  @override
  String get activationBankHint => 'اسمح لزاد بالتقاط العمليات وعرضها للتأكيد';

  @override
  String get activationFirstItem => 'أضف أول صنف للبيت';

  @override
  String get activationFirstItemHint => 'ابدأ بصنف متكرر ليتعلم زاد استهلاكك';

  @override
  String get activationGoal => 'حدد أول هدف لبيتك';

  @override
  String get activationGoalHint => 'زاد هيتابعه معاك كل أسبوع';

  @override
  String get activationAllSet =>
      'كل حاجة جاهزة! 🎉 جرب تقول لزاد \"صرفت ٥٠ بقالة\" بالصوت أو من بوت تليجرام — هيسألك تأكيد ويسجلها.';

  @override
  String get commonOpen => 'فتح';

  @override
  String get amazonOutOfStock => 'خلص من مخزونك';

  @override
  String get amazonRunningLow => 'قارب على النفاد';

  @override
  String get amazonOnList => 'في قايمة التسوق';

  @override
  String get amazonSuggestion => 'اقتراح لبيتك';

  @override
  String get amazonShop => 'تسوق من أمازون';

  @override
  String get amazonApproxPrice => 'سعر تقريبي';

  @override
  String get amazonUpdatedToday => 'اتحدث النهاردة';

  @override
  String amazonPriceAge(int days) {
    return 'سعر منذ $days يوم';
  }

  @override
  String get amazonName => 'أمازون';

  @override
  String get amazonDisclosure =>
      'رابط شراء أفلييت — عمولة لزاد بدون أي زيادة عليك';

  @override
  String get amazonOut => 'خلص';

  @override
  String get amazonLow => 'قرب يخلص';

  @override
  String get amazonShopEmoji => '🛍️ تسوق من أمازون';

  @override
  String get amazonNoNeeds => 'ضيف اللي ناقصك، أو شوف عروض النهارده';

  @override
  String amazonOneNeed(String name) {
    return 'ناقصك $name — اطلبه من أمازون';
  }

  @override
  String amazonManyNeeds(int count) {
    return 'ناقصك $count حاجات — اطلب كل واحدة بضغطة';
  }

  @override
  String get amazonSuggest => 'اقتراح';

  @override
  String get amazonDeals => 'العروض';

  @override
  String get amazonOrder => '🛒 اطلبه';

  @override
  String get homeOffline => 'مفيش اتصال بالإنترنت';

  @override
  String get homeOfflineHint =>
      'بياناتك بتتحفظ محلياً وهتتزامن أول ما النت يرجع';

  @override
  String get homeTalkToZad => 'كلّم زاد';

  @override
  String homeHello(String name) {
    return 'أهلاً يا $name! 👋';
  }

  @override
  String get homeBrainActive => 'عقل زاد نشط';

  @override
  String get homeScanPantry => 'مسح مخزون';

  @override
  String get homeRecent => 'أحدث المعاملات';

  @override
  String get commonSeeAll => 'عرض الكل';

  @override
  String get homeRecentEmpty => 'سيتم عرض المعاملات البنكية هنا';

  @override
  String get homeAllTransactions => 'السجل الكامل للمعاملات';

  @override
  String get dayToday => 'اليوم';

  @override
  String get dayYesterday => 'أمس';

  @override
  String dayAgo(int days) {
    return 'قبل $days أيام';
  }

  @override
  String get homeServerDown => 'مقدرتش أوصل للسيرفر';

  @override
  String get homePreparing => 'بنجهّز ميزانيتك';

  @override
  String get homeServerDownHint =>
      'هنحاول تاني لوحدنا. تقدر تسحب الشاشة لتحت دلوقتي.';

  @override
  String get homePreparingHint => 'ثانية واحدة وهتلاقي كل حاجة هنا.';

  @override
  String checkInFinished(String item) {
    return 'هل خلص $item؟';
  }

  @override
  String get checkInHint => 'حسب معدل استهلاكك، المفروض قرب يخلص';

  @override
  String get checkInDone => 'خلص';

  @override
  String get checkInNotYet => 'لسه';

  @override
  String get metricsSafeDaily => 'معدل الصرف اليومي الآمن';

  @override
  String get metricsToMonthEnd => 'لحد آخر الشهر';

  @override
  String get metricsToPayday => 'لحد القبض';

  @override
  String metricsDays(int days) {
    return '$days يوم';
  }

  @override
  String get commonNotNow => 'مش دلوقتي';

  @override
  String get quietRestoreFailed => 'مقدرتش أرجّع التنبيهات. جرّب تاني.';

  @override
  String get quietRestore => 'رجّع التنبيهات';

  @override
  String metricsPaydayOn(int day, String month) {
    return 'يوم $day $month';
  }

  @override
  String get sectionPantry => 'المخزون';

  @override
  String get sectionBudget => 'الميزانية';

  @override
  String get sectionSubscriptions => 'الاشتراكات';

  @override
  String get sectionMap => 'خريطة زاد';

  @override
  String get sectionStatement => 'استيراد كشف حساب';

  @override
  String get sectionPlans => 'باقات زاد الشهرية الذكية';

  @override
  String sectionWithBadge(String name, int count) {
    return '$name، $count';
  }

  @override
  String get sectionsFewer => 'أقسام أقل';

  @override
  String sectionsAll(int count) {
    return 'كل الأقسام ($count)';
  }

  @override
  String get tasbihaGarden => 'بستان التسبيح';

  @override
  String tasbihaProgress(int clicks, int target) {
    return '$clicks من $target تسبيحة';
  }

  @override
  String travelSwitch(String country, String currency) {
    return 'شكلك في $country — أحوّل لـ $currency؟';
  }

  @override
  String get travelSwitchButton => 'تحويل';

  @override
  String get commonDismiss => 'تجاهل';

  @override
  String recipeAskSpoil(String items) {
    return 'اقترح وصفات بـ $items قبل ما تتلف';
  }

  @override
  String recipeAskRunOut(String items) {
    return 'اقترح وصفات بـ $items قبل ما تخلص';
  }

  @override
  String get listSeparator => '، ';

  @override
  String recipeStagnant(String names) {
    return 'عندك $names من فترة وماستخدمتهاش 🤔';
  }

  @override
  String recipeRunningOut(String names) {
    return 'عندك $names هيخلص قريب 👀';
  }

  @override
  String get recipeStagnantHint => 'وصفات تساعدك تستخدمها قبل ما تتلف';

  @override
  String get recipeRunningOutHint => 'وصفات مقترحة بيه قبل ما يضيع';

  @override
  String get recipeOpenChat => 'اضغط للمزيد في شات زاد ←';

  @override
  String get profileSaveFailed => 'مقدرناش نحفظ الملف — جرب تاني';

  @override
  String get whoTitle => 'عرّفني بنفسك';

  @override
  String get whoBody =>
      'اسمك، وتحب أكلمك بصيغة راجل ولا ست، وشغلك وميعاد قبضك — عشان أكلمك صح وأفتكرك.';

  @override
  String get whoGo => 'يلا نتعرّف';

  @override
  String get commonLater => 'لاحقاً';

  @override
  String monthName(String month) {
    String _temp0 = intl.Intl.selectLogic(month, {
      'm1': 'يناير',
      'm2': 'فبراير',
      'm3': 'مارس',
      'm4': 'أبريل',
      'm5': 'مايو',
      'm6': 'يونيو',
      'm7': 'يوليو',
      'm8': 'أغسطس',
      'm9': 'سبتمبر',
      'm10': 'أكتوبر',
      'm11': 'نوفمبر',
      'm12': 'ديسمبر',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get chatVoiceUnavailable => 'الصوت مش متاح دلوقتي — الرد مكتوب قدامك';

  @override
  String get chatNewTooltip => 'ابدأ محادثة جديدة';

  @override
  String get chatNewTitle => 'تبدأ محادثة جديدة؟';

  @override
  String get chatNewBody =>
      'الكلام اللي فات هيتمسح من التليفون ده. اللي زاد اتعلمه عنك هيفضل زي ما هو.';

  @override
  String get chatClear => 'امسح';

  @override
  String get chatWelcome =>
      'أهلاً بيك! أنا زاد، مساعدك العائلي الذكي. أقدر أساعدك إزاي النهاردة؟\nاسألني عن الوصفات، أو راجع ثلاجتك، أو ضيف النواقص لقائمة التسوق!';

  @override
  String get chatBusy =>
      'الذكاء الاصطناعي مشغول شوية دلوقتي جرب تاني بعد لحظات.';

  @override
  String get chatUnexpected => 'حصل خطأ غير متوقع.';

  @override
  String get chatResend => 'ماوصلتش — ابعتها تاني';

  @override
  String get chatStopVoice => 'وقّف الصوت';

  @override
  String get chatListen => 'اسمع الرد';

  @override
  String get chatReport => 'بلّغ عن الرد';

  @override
  String get chatReportTitle => 'إيه المشكلة في الرد ده؟';

  @override
  String get chatReportOffensive => 'مسيء أو غير لائق';

  @override
  String get chatReportWrong => 'معلومة غلط أو مضللة';

  @override
  String get chatReportHarmful => 'نصيحة ممكن تأذي';

  @override
  String get chatReportOther => 'حاجة تانية';

  @override
  String get chatReportSent => 'وصل بلاغك، شكراً. هنراجع الرد ده.';

  @override
  String get chatReportFailed => 'البلاغ ماوصلش — جرّب تاني';

  @override
  String get chatWorldEyebrow => 'اسأل أي حاجة';

  @override
  String get chatStateThinking => 'بيفكّر…';

  @override
  String get chatStateListening => 'بيسمعك…';

  @override
  String get chatStateSpeaking => 'بيتكلم…';

  @override
  String get chatStateEmpty => 'أنا سامعك';

  @override
  String chatStateCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count رسالة',
      few: '$count رسايل',
      two: 'رسالتين',
      one: 'رسالة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get chatThinking => 'بفكر…';

  @override
  String get refillBack => 'رصيدك رجع — ابعت رسالتك تاني';

  @override
  String refillDays(int days) {
    return 'رصيدك بيتجدد بعد $days أيام';
  }

  @override
  String get refillHour => 'ساعة';

  @override
  String get refillTwoHours => 'ساعتين';

  @override
  String refillFewHours(int h) {
    return '$h ساعات';
  }

  @override
  String refillManyHours(int h) {
    return '$h ساعة';
  }

  @override
  String refillMinutes(int m) {
    return '$m دقيقة';
  }

  @override
  String get refillAnd => ' و';

  @override
  String refillIn(String span) {
    return 'رصيدك بيتجدد بعد $span';
  }

  @override
  String get chatSubscribeFeature => 'اشترك وفعّل الميزة دي';

  @override
  String get chatSubscribeMore => 'اشترك وخد محاولات أكتر';

  @override
  String get chatNotDone => 'لسه ماتنفذش.';

  @override
  String get chatDoIt => 'اعملها';

  @override
  String get chatTranscribing => 'بحوّل الكلام…';

  @override
  String get chatHint => 'اكتب لزاد…';

  @override
  String get chatSend => 'ابعت';

  @override
  String get voiceTooShort => 'مسكت الزرار بسرعة — دوس وابدأ اتكلم، وبعدين قف.';

  @override
  String get voiceDenied =>
      'محتاج إذن المايك. افتح إعدادات التطبيق واسمح بالتسجيل.';

  @override
  String get voiceFailed => 'مقدرتش أحوّل الكلام. جرب تاني.';

  @override
  String get subscribePulseTitle => 'اشترك وزاد يبقى معاك على طول';

  @override
  String get subscribePulseBody =>
      'من غير إعلانات، ومحاولات أكتر، وصوت من غير حد.';

  @override
  String get subscribePulseClose => 'اقفل';

  @override
  String get voiceOutToday =>
      'خلصت أسئلتك الصوتية (٣ كل ساعتين) — بترجع لوحدها، أو شاهد إعلان وخد سؤال زيادة. اكتب سؤالك، أو اشترك وكلّم زاد من غير حد.';

  @override
  String get voiceRecord => 'سجّل صوت';

  @override
  String get commonCancel => 'إلغاء';

  @override
  String get voiceDone => 'خلصت';

  @override
  String chatEmergency(String trade) {
    return 'طوارئ في البيت؟ الـ$trade بتاعك قدامك بنقرة.';
  }

  @override
  String get chatTechnicians => 'فنييني';

  @override
  String get intChatTitle => 'محادثة مع زاد';

  @override
  String get intChatSubtitle => 'اسأل عن مصاريفك، مخزونك، أو أي حاجة';

  @override
  String get intChatHide => 'إخفاء المحادثة';

  @override
  String get intChatOpen => 'افتح المحادثة';

  @override
  String get intPromptRecipe => 'اقترح وصفة من الثلاجة';

  @override
  String get intPromptSpending => 'حلل مصاريفي هذا الشهر';

  @override
  String get intPromptShopping => 'ما الذي ينقصني للتسوق؟';

  @override
  String get intPromptSave => 'كيف أوفر أكثر هذا الشهر؟';

  @override
  String get intPromptSubs => 'اكتشف اشتراكاتي';

  @override
  String get intPromptHealthy => 'وجبة صحية سريعة';

  @override
  String get intChatClear => 'مسح المحادثة';

  @override
  String get intChatClearBody =>
      'هنمسح كل رسائل المحادثة مع عقل زاد. البيانات المالية والمخزون مش هتتأثر.';

  @override
  String get intChatEmpty => 'اسأل زاد عن أي شيء';

  @override
  String get intChatInputHint => 'اسأل زاد عن ثلاجتك أو ميزانيتك...';

  @override
  String get intChatListen => 'استمع';

  @override
  String intChatMemoryUsed(int count) {
    return 'اتبنى على $count حاجة زاد فاكرها عنك';
  }

  @override
  String get meshThinking => 'الشبكة العصبية بتشتغل...';

  @override
  String get meshFinance => 'وكيل المال متصل';

  @override
  String get meshPantry => 'وكيل المطبخ والمخزون متصل';

  @override
  String get meshPharmacy => 'وكيل الصيدلية متصل';

  @override
  String get meshFamily => 'وكيل العائلة متصل';

  @override
  String get meshDefault => 'شبكة وكلاء زاد';

  @override
  String get voiceChipSpending => 'حلل مصاريفي';

  @override
  String get voiceChipMeal => 'اقترح وجبة';

  @override
  String get voiceChipLeft => 'كام فاضل في الميزانية؟';

  @override
  String get voiceChipCoffee => 'صرفت 50 على القهوة';

  @override
  String get voiceSheetDenied => 'امنح التطبيق إذن استخدام الميكروفون';

  @override
  String get voiceSheetFailed => 'حدث خطأ في التعرف على الصوت';

  @override
  String get voiceSheetOutToday =>
      'خلصت أسئلتك الصوتية — ٣ كل ساعتين، وبترجع لوحدها';

  @override
  String get voiceSheetTooShort => 'لم أسمع كلامًا واضحًا، حاول مرة أخرى';

  @override
  String get voiceSheetBrainDown => 'ماقدرتش أوصل لعقل زاد دلوقتي';

  @override
  String get voiceSpeaking => 'زاد بيتكلم…';

  @override
  String get voiceWriting => 'بكتب كلامك…';

  @override
  String get voiceThinking => 'بيفكر…';

  @override
  String get voicePreparing => 'بيجهز صوته…';

  @override
  String get voiceTitle => 'مساعد زاد الصوتي';

  @override
  String voiceErrorRetry(String error) {
    return '⚠️ $error\nاضغط المايك وجرّب تاني';
  }

  @override
  String get voiceInterruptHint => 'زاد بيتكلم… اتكلم في أي وقت تقاطعه';

  @override
  String get voiceWorking => 'يفكر عقل زاد وينفذ طلبك…';

  @override
  String get voiceListening => 'زاد سامعك — اتكلم براحتك';

  @override
  String get voiceTapMic => 'اضغط المايك وكلّم زاد 🎙️';

  @override
  String get voiceHoldToTalk => 'دوس مع الاستمرار واتكلم';

  @override
  String get voiceReleaseToReply => 'بسمعك… سيب عشان أرد';

  @override
  String get voicePressToInterrupt => 'دوس واتكلم عشان تقاطعني';

  @override
  String get voiceOrPick => 'أو اختار سؤال جاهز:';

  @override
  String budgetSuggest(String amount) {
    return 'زاد يقترح تعديل ميزانيتك إلى $amount بناءً على متوسط آخر شهرين';
  }

  @override
  String get commonApply => 'تطبيق';

  @override
  String get txFilterAll => 'الكل';

  @override
  String get txFilterExpenses => 'المصروفات';

  @override
  String get txFilterIncome => 'الدخل';

  @override
  String get txFilterBank => 'البنك';

  @override
  String get budgetThisMonth => 'هذا الشهر';

  @override
  String get budgetNoTransactions => 'لا توجد معاملات بعد.';

  @override
  String get budgetNoTransactionsHint =>
      'أضف معاملة أو اربط البنك لتتبع مصاريفك تلقائياً';

  @override
  String get txEdit => 'تعديل المعاملة';

  @override
  String get txDelete => 'مسح المعاملة';

  @override
  String get financesTitle => 'الميزانية والالتزامات';

  @override
  String get financesTabMoves => 'الحركات والميزانية';

  @override
  String get financesAddTx => 'معاملة';

  @override
  String get financesCategoryBudgets => 'ميزانيات الفئات';

  @override
  String get financesSetCategory => 'تحديد فئة';

  @override
  String get financesNoCategories =>
      'لسه ما حددتش ميزانية لأي فئة. اضغط \"تحديد فئة\" عشان زاد يتابعلك كل فئة لوحدها.';

  @override
  String get financesAvailable => 'متاح';

  @override
  String get financesEditBalance => 'تعديل الرصيد';

  @override
  String get financesNoBudget => 'لسه محددتش ميزانيتك';

  @override
  String financesRemainingCommitted(String remaining, String committed) {
    return 'متبقي $remaining · محجوز $committed';
  }

  @override
  String financesNoLimit(String amount) {
    return '$amount — بدون حد';
  }

  @override
  String get financesSmartAnalysis => 'تحليل ذكي';

  @override
  String get financesSetCategoryBudget => 'تحديد ميزانية فئة';

  @override
  String financesEditCategoryBudget(String category) {
    return 'تعديل ميزانية $category';
  }

  @override
  String get financesCategory => 'الفئة';

  @override
  String get financesMonthlyBudget => 'الميزانية الشهرية';

  @override
  String get commonSave => 'حفظ';

  @override
  String financesInsightTitle(String category) {
    return 'تحليل ذكي: $category';
  }

  @override
  String get financesAnalysing => 'جاري التحليل...';

  @override
  String get financesInsightEmpty =>
      'مفيش بيانات كافية لتحليل الفئة دي حالياً.';

  @override
  String financesPredictedNext(String amount) {
    return 'المتوقع الشهر القادم: $amount';
  }

  @override
  String get gateTitle => 'قبل ما نبدأ، معاك كام الشهر ده؟';

  @override
  String get gateBody =>
      'زاد ما بيخترعش أرقام. من الرقم ده بنحسب «المتاح» و«المتبقي» كل يوم، وتقدر تعدّله في أي وقت.';

  @override
  String get gateMarket => 'البلد والعملة';

  @override
  String get commonChange => 'تغيير';

  @override
  String get gateCeiling => 'رصيدك للشهر ده';

  @override
  String get gateStart => 'يلا نبدأ';

  @override
  String get budgetOver => 'تجاوزت الميزانية! حاول تقليل المصاريف';

  @override
  String budgetNear(int pct) {
    return 'وصلت لـ $pct% من ميزانيتك. كن حذراً';
  }

  @override
  String budgetFine(int pct) {
    return 'صرفت $pct% من ميزانيتك. أداء جيد';
  }

  @override
  String budgetGreat(int pct) {
    return 'رائع! أنت في المسار الصحيح. صرفت $pct% فقط';
  }

  @override
  String get trendUp => 'في ازدياد';

  @override
  String get trendDown => 'في انخفاض';

  @override
  String get trendFlat => 'مستقر';

  @override
  String eventToday(String title) {
    return 'زوّدناه عشان «$title» النهارده';
  }

  @override
  String eventAhead(String title, String when) {
    return 'شايلين حاجة لـ«$title» $when';
  }

  @override
  String get eventTomorrow => 'بكرة';

  @override
  String eventOnDay(String day) {
    return 'يوم $day';
  }

  @override
  String weekdayName(String day) {
    String _temp0 = intl.Intl.selectLogic(day, {
      'd1': 'الاتنين',
      'd2': 'التلات',
      'd3': 'الأربع',
      'd4': 'الخميس',
      'd5': 'الجمعة',
      'd6': 'السبت',
      'd7': 'الحد',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get eventOuting => 'مشوار';

  @override
  String get txNoTitle => 'بدون وصف';

  @override
  String get txAddExpense => 'إضافة مصروف';

  @override
  String get txAddIncome => 'إضافة دخل/راتب';

  @override
  String get txKindExpense => 'خصم (مصروف)';

  @override
  String get txKindIncome => 'إيداع (راتب)';

  @override
  String get txDescriptionExample => 'الوصف (مثال: راتب، إيجار)';

  @override
  String get txAmount => 'المبلغ';

  @override
  String get txDebit => 'خصم المبلغ';

  @override
  String get txCredit => 'إضافة المبلغ';

  @override
  String get commonDelete => 'حذف';

  @override
  String txDeleteConfirm(String title) {
    return 'هل أنت متأكد من حذف معاملة \"$title\"؟';
  }

  @override
  String get txDescription => 'الوصف';

  @override
  String get txForPerson => 'لمين؟ (سيبها فاضية لو ليك أو للبيت كله)';

  @override
  String get txForPersonHint => 'ماما، بابا، يوسف…';

  @override
  String txForPersonTag(String person) {
    return 'لـ$person';
  }

  @override
  String get habitTrialTitle => '🧪 تجربة الأسبوعين';

  @override
  String get habitTrialTry => '✅ نجرب أسبوعين';

  @override
  String get habitTrialNo => '🙅 لأ شكراً';

  @override
  String get habitTrialKeep => '✅ ثبّتها';

  @override
  String get habitTrialDrop => '❌ بطّلها';

  @override
  String get habitTrialStarted =>
      'يلا بينا ✅ التجربة بدأت النهارده لمدة أسبوعين، وبعدها هقولك النتيجة بالأرقام.';

  @override
  String get habitTrialDeclined => 'تمام، مش هقترحها تاني الفترة دي.';

  @override
  String get habitTrialKept => 'تمام ✅ ثبّتناها — هفتكرها وأبني عليها.';

  @override
  String get habitTrialDropped => 'تمام، بطّلناها. شكراً إنك جرّبت.';

  @override
  String get habitTrialAlready => 'تمام، ردك اتسجّل قبل كده.';

  @override
  String get habitTrialGone => 'التجربة دي مابقتش موجودة.';

  @override
  String get habitTrialFailed =>
      'معلش، ماقدرتش أسجّل ردك دلوقتي — جرّب تاني بعد شوية.';

  @override
  String get learningTitle => '🧠 اتعلمت إن';

  @override
  String get learningRight => '✅ صح';

  @override
  String get learningWrong => '❌ مش صح';

  @override
  String get openOfferSource => '🔗 افتح العرض';

  @override
  String get learningKept => 'تمام ✅ هفتكرها.';

  @override
  String get learningCorrected => 'تمام، شكراً إنك صحّحتني — مش هقولها تاني.';

  @override
  String get learningAlready => 'تمام، ردك اتسجّل قبل كده.';

  @override
  String get learningGone => 'الملاحظة دي مابقتش موجودة.';

  @override
  String get learningFailed =>
      'معلش، ماقدرتش أسجّل ردك دلوقتي — جرّب تاني بعد شوية.';

  @override
  String get txType => 'النوع';

  @override
  String get txExpense => 'مصروف';

  @override
  String get txIncome => 'دخل';

  @override
  String get quickCash => 'مصروف كاش';

  @override
  String get quickExpense => 'مصروف سريع';

  @override
  String get quickSubtitle => 'سجّل مصروفك في ثوانٍ';

  @override
  String get quickName => 'الاسم';

  @override
  String get quickNameHint => 'مثال: حلاقة، بقالة';

  @override
  String get quickCategory => 'التصنيف';

  @override
  String get txScanReceipt => 'صوّر فاتورة';

  @override
  String get txLog => 'سجّل عملية';

  @override
  String get txTitle => 'المعاملات';

  @override
  String get txNoneHere => 'مفيش معاملات هنا';

  @override
  String get txTryFilter => 'جرّب فلتر تاني.';

  @override
  String get commonEdit => 'تعديل';

  @override
  String get walletCash => 'كاش';

  @override
  String get walletCard => 'بطاقة';

  @override
  String get walletBank => 'بنك';

  @override
  String get txPendingOne => 'لسه محفوظة';

  @override
  String txPendingCount(int count) {
    return '$count لسه محفوظة';
  }

  @override
  String get txLoadFailed => 'مقدرتش أجيب المعاملات';

  @override
  String get txNonePeriod => 'مفيش معاملات الفترة دي';

  @override
  String get txPullToRetry => 'اسحب الشاشة لتحت عشان نحاول تاني.';

  @override
  String get txNoneHint =>
      'أول ما تسجّل مصروف — أو توصلك رسالة من البنك — هتلاقيها هنا.';

  @override
  String get dateDayHeader => 'EEEE، d MMMM';

  @override
  String get cycleYearly => 'سنوي';

  @override
  String get cycleWeekly => 'أسبوعي';

  @override
  String get cycleMonthly => 'شهري';

  @override
  String get subsTabAll => 'الكل';

  @override
  String get subsTabSubs => 'اشتراكات';

  @override
  String get subsTabBills => 'فواتير';

  @override
  String get subsTabInstalments => 'أقساط';

  @override
  String get subsTabLoans => 'قروض';

  @override
  String get subsNone => 'لا توجد اشتراكات';

  @override
  String get subsNoneInTab => 'لا توجد عناصر في هذا التصنيف';

  @override
  String get subsActive => 'النشطة';

  @override
  String get subsMonthlyTotal => 'إجمالي الاشتراكات الشهرية';

  @override
  String get subsActiveCount => 'اشتراكات نشطة';

  @override
  String subsDetected(int count) {
    return '$count اشتراك مكتشف تلقائياً';
  }

  @override
  String get subsClearAll => 'مسح الكل';

  @override
  String get subsBnpl => 'اشتري دلوقتي وادفع بعدين';

  @override
  String get subsLoans => 'أقساط وقروض وإيجار';

  @override
  String subsPaid(String title) {
    return 'تم تسجيل سداد $title وترحيل الموعد للشهر القادم بنجاح';
  }

  @override
  String get subsFixed => 'التزامات ثابتة';

  @override
  String get subsTitle => 'الاشتراكات والفواتير';

  @override
  String get subsWorldNone => 'مفيش اشتراكات لسه';

  @override
  String subsWorldTotal(String amount) {
    return '$amount في الشهر';
  }

  @override
  String subsWorldNextToday(String amount, String title) {
    return '$amount في الشهر · $title بيجدد النهارده';
  }

  @override
  String subsWorldNext(String amount, String title, int days) {
    return '$amount في الشهر · $title بعد $days يوم';
  }

  @override
  String get subsEmptyHint => 'اضغط «إضافة» وزاد يحسب لك التجديد الجاي.';

  @override
  String subsBnplTag(String name) {
    return 'اشتري وادفع بعدين · $name';
  }

  @override
  String get subsRenewsToday => 'يُجدد اليوم';

  @override
  String subsExpiredAgo(int days) {
    return 'منتهي منذ $days يوم';
  }

  @override
  String subsRenewsIn(int days) {
    return 'يُجدد بعد $days يوم';
  }

  @override
  String subsPerYear(String amount) {
    return '≈ $amount/سنة';
  }

  @override
  String get subsPaidMark => 'تم الدفع';

  @override
  String get subsToggleAuto => 'تفعيل/إيقاف الخصم التلقائي';

  @override
  String get subsDisable => 'تعطيل';

  @override
  String get subsEnable => 'تفعيل';

  @override
  String get subsAdd => 'إضافة اشتراك جديد';

  @override
  String get subsEdit => 'تعديل الاشتراك';

  @override
  String get commonConfirm => 'تأكيد';

  @override
  String get subsSuggested => 'الخدمات والاشتراكات المقترحة:';

  @override
  String get subsKind => 'تصنيف الالتزام:';

  @override
  String get subsKindSub => 'اشتراك شهري';

  @override
  String get subsKindInstalment => 'قسط';

  @override
  String get subsKindBill => 'فاتورة';

  @override
  String get subsKindRent => 'التزام';

  @override
  String get subsTotalAmount => 'إجمالي المبلغ';

  @override
  String get subsRemaining => 'الأقساط المتبقية';

  @override
  String get subsNameHint => 'اسم الاشتراك (مثال: Netflix)';

  @override
  String subsAmount(String symbol) {
    return 'المبلغ ($symbol)';
  }

  @override
  String get subsProvider => 'مزود الخدمة';

  @override
  String get subsRenewalDate => 'تاريخ التجديد (YYYY-MM-DD)';

  @override
  String get commonPickDate => 'اختر التاريخ';

  @override
  String get subsCycle => 'دورة الفوترة';

  @override
  String subsSuggestedCategory(String category) {
    return 'الفئة المقترحة: $category';
  }

  @override
  String get oblKindRent => 'إيجار';

  @override
  String get oblKindInstallment => 'قسط';

  @override
  String get oblKindDebt => 'دين';

  @override
  String get oblKindTuition => 'مصاريف دراسية';

  @override
  String get oblKindUtility => 'فاتورة مرافق';

  @override
  String get oblKindOther => 'أخرى';

  @override
  String get recurMonthly => 'شهري';

  @override
  String get recurQuarterly => 'ربع سنوي';

  @override
  String get recurYearly => 'سنوي';

  @override
  String get recurOnce => 'مرة واحدة';

  @override
  String get oblStatusPaid => 'مدفوع';

  @override
  String get oblStatusPending => 'مستحق';

  @override
  String get oblStatusScheduled => 'مجدول';

  @override
  String oblInDays(int days) {
    return 'بعد $days يوم';
  }

  @override
  String get oblTotal => 'إجمالي الالتزامات';

  @override
  String get oblAdd => 'إضافة التزام';

  @override
  String get oblNone => 'لا توجد التزامات';

  @override
  String get oblNoneHint => 'الأقساط والفواتير الثابتة هتظهر هنا أول ما تتسجل';

  @override
  String oblDeleteConfirm(String title) {
    return 'حذف «$title» من قائمة الالتزامات؟';
  }

  @override
  String get oblAddNew => 'إضافة التزام جديد';

  @override
  String get oblEdit => 'تعديل الالتزام';

  @override
  String get oblNameHint => 'اسم الالتزام (إيجار، كهرباء...)';

  @override
  String oblAmountIn(String currency) {
    return 'المبلغ ($currency)';
  }

  @override
  String get oblDueDay => 'يوم الاستحقاق الشهري (1-31)';

  @override
  String get oblDayRange => 'من 1 لـ 31';

  @override
  String get oblRecurrence => 'التكرار';

  @override
  String get debtSaveFailed => 'ماتسجلش — اتأكد من النت.';

  @override
  String debtPaymentOn(String name) {
    return 'دفعة على $name';
  }

  @override
  String debtRemaining(String amount) {
    return 'المتبقي: $amount';
  }

  @override
  String get debtPaidAmount => 'المبلغ المدفوع';

  @override
  String get debtDelete => 'حذف الدين';

  @override
  String debtDeleteConfirm(String name) {
    return 'حذف «$name» من قائمة الديون؟';
  }

  @override
  String get debtPlanner => 'مخطط سداد الديون';

  @override
  String get debtAdd => 'إضافة دين';

  @override
  String get debtPickStrategy => 'اختر استراتيجية السداد المناسبة لك';

  @override
  String get debtNone => 'لا توجد ديون مسجلة';

  @override
  String get debtNoneHint => 'أضف ديونك لنساعدك في التخطيط للسداد';

  @override
  String get debtSnowball => 'كرة الثلج (الأصغر أولاً)';

  @override
  String get debtAvalanche => 'الانهيار الجليدي (الأعلى فائدة أولاً)';

  @override
  String debtMonths(int months) {
    return '$months شهر';
  }

  @override
  String get debtLogPayment => 'سجّل دفعة';

  @override
  String debtMonthsToPayoff(int months) {
    return '$months شهر للسداد الكامل';
  }

  @override
  String debtTotalInterest(String amount) {
    return 'إجمالي الفوائد: $amount';
  }

  @override
  String get debtAnalysing => 'زاد يقوم بالتحليل...';

  @override
  String get debtExplain => 'اشرح بالذكاء الاصطناعي';

  @override
  String get debtName => 'اسم الدين';

  @override
  String get debtLeft => 'المبلغ المتبقي';

  @override
  String get debtRate => 'معدل الفائدة السنوي %';

  @override
  String get debtMinimum => 'الحد الأدنى للدفعة الشهرية';

  @override
  String dealDiscount(String pct) {
    return 'خصم $pct%';
  }

  @override
  String dealAt(String price, String store) {
    return '$price عند $store';
  }

  @override
  String dealCached(String when) {
    return 'البحث مشغول دلوقتي — دي آخر عروض لقيناها$when';
  }

  @override
  String get dealTitle => 'العروض المتاحة لنواقصك 🏷️';

  @override
  String get dealLive => 'نتيجة بحث حي';

  @override
  String get dealSubtitle => 'عروض حقيقية على الأصناف الناقصة عندك';

  @override
  String get dealTapRefresh => 'اضغط لتحديث النتائج من الإنترنت';

  @override
  String get dealSearching => 'يبحث في الإنترنت...';

  @override
  String get dealFailed => 'تعذّر البحث الآن — جرّب تحدّث تاني بعد شوية';

  @override
  String get dealFailedHint =>
      'خدمة البحث مشغولة دلوقتي. دوس تحديث تاني بعد شوية — ولو اتكررت شوف النت.';

  @override
  String get dealNone => 'لا توجد نتائج بحث محددة متوفرة حالياً';

  @override
  String get dealRefresh => 'تحديث من النت 🔄';

  @override
  String get goalTitle => 'إيه أهم هدف لبيتك دلوقتي؟';

  @override
  String get goalBody =>
      'اختار واحد — زاد هيتابعه معاك كل أسبوع لمدة ٣ شهور، وتقدر تلغيه في أي وقت.';

  @override
  String get goalSave => 'أوفّر مبلغ كل شهر';

  @override
  String get goalSaveHint => 'حدد المبلغ، وزاد يتابع صرفك عشان توصله';

  @override
  String get goalMonthly => 'المبلغ الشهري';

  @override
  String get goalBudget => 'ألتزم بميزانية الشهر';

  @override
  String get goalBudgetHint => 'زاد ينبهك قبل ما الصرف يسبق الميزانية';

  @override
  String get goalDebts => 'أسدد ديوني';

  @override
  String get goalDebtsHint => 'زاد يتابع معاك المتبقي وأقرب قسط';

  @override
  String get goalWaste => 'أقلل هدر المطبخ';

  @override
  String get goalWasteHint => 'زاد يفكرك بالأصناف قبل ما تبوظ';

  @override
  String get goalOwn => 'هدف تاني بكلامي';

  @override
  String get goalOwnHint => 'اكتبه زي ما بتقوله';

  @override
  String get goalWrite => 'اكتب هدفك';

  @override
  String get goalTooMany => 'عندك ٥ أهداف شغالة — خلّص واحد أو ألغيه الأول';

  @override
  String get goalSaveFailed => 'معرفتش أسجل الهدف — جرّب تاني';

  @override
  String get goalStart => 'ابدأ الهدف';

  @override
  String get heldTitle => 'اللي سكتّ عنه وليه';

  @override
  String get heldNone =>
      'الأسبوع ده ماسكتّش عن أي حاجة — كل اللي كان يستاهل يتقال اتقال.';

  @override
  String get heldFailed => 'مش قادر أقرا اللي سكتّ عنه دلوقتي.';

  @override
  String get heldLoading => 'بقرا…';

  @override
  String get heldAskHint =>
      'تقدر تسألني «إيه اللي ماقولتليش عليه؟» في الشات وأقولك بالتفصيل.';

  @override
  String heldTimes(int count) {
    return '$count مرات';
  }

  @override
  String get heldActionDropped => 'ماقولتهاش';

  @override
  String get heldActionWaiting => 'لسه مستنية';

  @override
  String get heldActionPostponed => 'أجّلتها';

  @override
  String get heldReasonMuted => 'إنت قلتلي أبطّل النوع ده لفترة';

  @override
  String get heldReasonLearnedQuiet =>
      'لاحظت إنك مابتتعاملش مع النوع ده غالباً، فبقلّل منه';

  @override
  String get heldReasonQuietHours => 'كان وقت نومك';

  @override
  String get heldReasonReplyHour => 'استنيت الساعة اللي بترد فيها عادة';

  @override
  String get heldReasonPacing => 'كان لسه واصلك حاجة من شوية';

  @override
  String get heldReasonDailyCap => 'وصلت لعدد الرسايل بتاع اليوم';

  @override
  String get heldReasonBusyDay => 'يومك كان مليان مواعيد';

  @override
  String get heldReasonCircumstance => 'كنت مراعي ظرفك';

  @override
  String get heldReasonDuplicate => 'كنت قلتهالك قبلها بشوية';

  @override
  String get heldReasonExpired => 'كلامها قدم قبل ما ألاقي وقت مناسب';

  @override
  String get heldReasonNotRelevant => 'مابقتش تفرق (اتعملت أو اتغيرت)';

  @override
  String get heldReasonNothingNew => 'ماكانش فيه جديد يتقال';

  @override
  String get heldReasonOther => 'سبب تاني';

  @override
  String get heldKindGoodNight => 'تصبح على خير';

  @override
  String get heldKindCloseDay => '«اقفل يومك»';

  @override
  String get heldKindMorning => 'صباح الخير';

  @override
  String get heldKindWeeklyStory => 'حكاية فلوس الأسبوع';

  @override
  String get heldKindNewcomer => 'سؤال التعارف';

  @override
  String get heldKindSalary => '«ده المرتب؟»';

  @override
  String get heldKindVoice => 'رسالة صوتية';

  @override
  String get heldKindDigest => 'ملخص البيت';

  @override
  String get heldKindForecast => 'توقّع مصروف الأسبوع';

  @override
  String get heldKindSpendingAhead => 'الصرف أسرع من الميزانية';

  @override
  String get heldKindBill => 'تذكير فاتورة';

  @override
  String get heldKindWarranty => 'ضمان قرب ينتهي';

  @override
  String get heldKindGoal => 'متابعة هدفك';

  @override
  String get heldKindHabit => 'عادة بتتكرر';

  @override
  String get heldKindShortage => 'حاجات هتخلص قريب';

  @override
  String get heldKindRestock => 'حاجة ضرورية خلصت';

  @override
  String get heldKindPet => 'نداء رفيقك';

  @override
  String get heldKindNote => 'ملاحظة من زاد';

  @override
  String get exampleCityEg => 'مثل: القاهرة، الجيزة';

  @override
  String get exampleCitySa => 'مثل: الرياض، جدة';

  @override
  String get exampleCityOther => 'مثل: اسم مدينتك';

  @override
  String get exampleStoreEg => 'مثل: كارفور، سبينيز';

  @override
  String get exampleStoreSa => 'مثل: بنده، العثيم';

  @override
  String get exampleStoreOther => 'مثل: اسم السوبر ماركت';

  @override
  String get walletBankEg => 'محفظة / إنستاباي';

  @override
  String get walletBankSa => 'محفظة / STC Pay';

  @override
  String get walletBankOther => 'محفظة / تحويل';

  @override
  String get keepAliveAllow => 'خلّي زاد شغال دايماً';

  @override
  String get diagTitle => 'تشخيص الأتمتة';

  @override
  String get diagMenuSubtitle => 'إشعارات البنك ورسايل زاد — واقفة فين بالظبط';

  @override
  String get diagRefresh => 'حدّث التشخيص';

  @override
  String get diagBankTitle => 'اللي وصل السيرفر من إشعارات البنك';

  @override
  String get diagBankNote =>
      'آخر ١٤ يوم: كل إشعار الموبايل بعته، وزاد عمل بيه إيه وليه.';

  @override
  String get diagReadFailedTitle => 'ماقدرتش أقرا من السيرفر';

  @override
  String get diagReadFailedBody => 'اتأكد من النت واسحب لتحت عشان تحدّث.';

  @override
  String get diagBankEmptyTitle => 'مفيش إشعار وصل السيرفر';

  @override
  String get diagBankEmptyBody =>
      'لو دفعت بالكارت الأيام دي، العطل على الموبايل — شوف القسم اللي فوق.';

  @override
  String get diagNotification => 'إشعار';

  @override
  String get diagBankNoAccess =>
      'واقفة عند أول خطوة: صلاحية قراءة الإشعارات مقفولة. فعّلها من القسم اللي فوق.';

  @override
  String get diagBankNotBound =>
      'الصلاحية شغالة بس خدمة القراءة عمرها ما اتوصلت. اقفل الصلاحية وافتحها تاني.';

  @override
  String get diagBankSilent =>
      'خدمة القراءة ماشافتش ولا إشعار من يومين — أندرويد وقّفها. اقفل الصلاحية وافتحها، وشيل زاد من توفير البطارية.';

  @override
  String get diagBankStuck =>
      'فيه إشعارات اتقرت على الموبايل ولسه مااتبعتتش للسيرفر. افتح النت وسيب زاد مفتوح دقيقة.';

  @override
  String get diagBankNothing =>
      'الموبايل شغال بس مفيش إشعار بنك وصل السيرفر. لو دفعت بالكارت، يبقى البنك بيبعت الرسالة من تطبيق مش متابَع — ابعتلنا اسمه.';

  @override
  String get diagBankSetAside =>
      'الإشعارات وصلت السيرفر بس كلها اتشالت — السبب جنب كل واحدة تحت.';

  @override
  String get diagBankWaiting =>
      'فيه حركات مستنية تأكيدك. أكّدها من الإشعار أو من الرئيسية عشان تتسجل.';

  @override
  String get diagBankOk => 'السلسلة شغالة: الإشعارات بتوصل وبتتسجل.';

  @override
  String get diagProTitle => 'رسايل زاد اللي بيبدأها';

  @override
  String get diagProNote =>
      'صباح الخير، الجرعات، المواعيد، «اقفل يومك» — وصلت ولا لأ وليه.';

  @override
  String get diagTelegram => 'تليجرام';

  @override
  String get diagPush => 'إشعارات التطبيق';

  @override
  String get diagUnknown => 'مش عارف';

  @override
  String get diagLinked => 'مربوط';

  @override
  String get diagNotLinked => 'مش مربوط';

  @override
  String get diagPushOff => 'الموبايل مش متسجّل لاستقبال إشعارات زاد';

  @override
  String get diagProEmptyTitle => 'زاد مابدأش أي رسالة آخر ١٤ يوم';

  @override
  String get diagProEmptyBody =>
      'أول تحية صباح بتوصل الصبح الجاي لو فيه طريق يوصلك.';

  @override
  String get diagProNoChannel =>
      'زاد مش لاقي طريق يوصلك: لا تليجرام مربوط ولا الموبايل متسجّل للإشعارات. اربط تليجرام من الإعدادات، أو افتح التطبيق واسمح بالإشعارات.';

  @override
  String get diagProNothing =>
      'السيرفر مابعتش حاجة آخر ١٤ يوم. ده مش طبيعي — ابعتلنا لقطة الشاشة دي.';

  @override
  String get diagProFailing => 'أغلب الرسايل فشلت — السبب جنب كل واحدة تحت.';

  @override
  String get diagProOk => 'السلسلة شغالة: زاد بيبدأ وبيوصلك.';

  @override
  String get diagMomentMorning => 'صباح الخير';

  @override
  String get diagMomentNight => 'تصبح على خير';

  @override
  String get diagMomentCloseDay => 'اقفل يومك';

  @override
  String get diagMomentDoseDue => 'ميعاد جرعة';

  @override
  String get diagMomentDoseMissed => 'جرعة فاتت';

  @override
  String get diagMomentDoseNudge => 'تذكير جرعة';

  @override
  String get diagMomentAppointment => 'ميعاد قريب';

  @override
  String get diagMomentWeekly => 'ملخص الأسبوع';

  @override
  String get diagMomentMonthly => 'حكاية الشهر';

  @override
  String get diagIngestRecorded => 'اتسجلت مصروف';

  @override
  String get diagIngestWaiting => 'مستنية تأكيدك («أكّد الحركة»)';

  @override
  String get diagIngestPromo => 'العقل شافها إعلان أو عرض، مش فلوس اتحركت';

  @override
  String get diagIngestOtp => 'كود تحقق أو تنبيه أمان';

  @override
  String get diagIngestOrder => 'حالة طلب أو توصيل';

  @override
  String get diagIngestPersonal => 'رسالة شخصية';

  @override
  String get diagIngestNonFinancial => 'مالهاش علاقة بالفلوس';

  @override
  String get diagIngestUnavailable => 'العقل ماردّش وقتها والمصدر مش معروف';

  @override
  String get diagIngestInfo => 'رسالة معلومات (رصيد أو تنبيه)';

  @override
  String get diagIngestFailedTxn => 'عملية فشلت أو لسه معلّقة';

  @override
  String get diagIngestMerged => 'نفس العملية وصلت من مكان تاني واتدمجت';

  @override
  String get diagIngestServerError => 'خطأ في السيرفر — هتتجرب تاني';

  @override
  String get diagIngestReviewing => 'وصلت ولسه بتتراجع';

  @override
  String get diagMomentNoChannel =>
      'مفيش طريق يوصلك: لا تليجرام ولا إشعارات التطبيق';

  @override
  String get diagMomentSkipped => 'اتأجلت أو اتشالت (هدوء أو سقف اليوم)';

  @override
  String get diagMomentSent => 'وصلت';

  @override
  String get diagMomentPending => 'مستنية ميعادها';

  @override
  String diagPushOn(int count) {
    return 'الموبايل متسجّل ($count)';
  }

  @override
  String diagIngestKind(String kind) {
    return 'اتصنفت $kind';
  }

  @override
  String get introTagline => 'تدبير ذكي لبيت هادئ';

  @override
  String get introPantryTitle => 'إدارة المخزون';

  @override
  String get introPantryBody => 'تتبع كل ما في مطبخك وبيتك بذكاء';

  @override
  String get introFamilyTitle => 'العائلة كلها';

  @override
  String get introFamilyBody => 'شارك الميزانية والمهام مع عائلتك';

  @override
  String get introAssistantTitle => 'مساعد ذكي';

  @override
  String get introAssistantBody => 'ذكاء اصطناعي يتنبأ باحتياجاتك ويتعلم منك';

  @override
  String get introBudgetTitle => 'الميزانية بذكاء';

  @override
  String get introBudgetBody => 'حلل إنفاقك ووفّر أكثر باقتراحات ذكية';

  @override
  String get introNext => 'التالي';

  @override
  String get introStart => 'ابدأ مع زاد';

  @override
  String get introSkip => 'تخطي';

  @override
  String get introSignUp => 'ليس لديك حساب؟ أنشئ حساباً جديداً';

  @override
  String get introLogoLabel => 'شعار زاد';

  @override
  String adWatchStep(String step) {
    return 'شاهد إعلان — $step من ٣';
  }

  @override
  String adThirdOpens(String attempts) {
    return 'الإعلان ده بيكمّل التلاتة ويفتح $attempts';
  }

  @override
  String adThreeForOne(String attempts, String seen) {
    return 'كل ٣ إعلانات = $attempts — شفت $seen من ٣';
  }

  @override
  String get appointmentGuardTitle => 'قبل ما أسجّله:';

  @override
  String get appointmentGuardAsk => 'تسجّله كده ولا تغيّر الوقت؟';

  @override
  String get appointmentGuardKeep => 'احفظه برضه';

  @override
  String get qtyLeftLittle => 'فاضل قليل';

  @override
  String get qtyLeftHalf => 'فاضل نصه';

  @override
  String get qtyLeftMost => 'فاضل كتير';

  @override
  String get scanLineToPharmacy => 'للصيدلية 💊';

  @override
  String get scanPantryWithMedicines =>
      'اللي موجود هتزيد كميته، واللي في قايمة المشتريات هيتشال منها، والأدوية هتروح الصيدلية.';

  @override
  String get dealsTitle => 'العروض والمحلات القريبة';

  @override
  String get dealsTabDeals => 'العروض';

  @override
  String get dealsTabNearby => 'المحلات القريبة';

  @override
  String get dealsEmptyTitle => 'مفيش عروض لسه';

  @override
  String get dealsEmptyBody =>
      'زاد بيدوّر كل أسبوع في صفحات المحلات وتطبيقات التوصيل وفواتير البيوت. أول ما يلاقي حاجة هتظهر هنا.';

  @override
  String get dealsFailedTitle => 'ماقدرناش نجيب العروض';

  @override
  String get dealsFailedBody => 'اتأكد من النت واسحب لتحت عشان تجرب تاني.';

  @override
  String get dealsCodesHeader => 'أكواد خصم';

  @override
  String get dealsStoresHeader => 'عروض المحلات';

  @override
  String get dealsFootnote =>
      'العروض من مصادرها ومتعلَّم عليها بتاريخها — ممكن يكون العرض خلص. زرار أمازون بيفتح بحث في متجر بلدك، وزاد بياخد عمولة صغيرة منه.';

  @override
  String get dealsOnAmazon => 'على أمازون';

  @override
  String dealsCopied(String code) {
    return 'اتنسخ $code';
  }

  @override
  String dealsCodeTitle(String store, String off) {
    return '$store — خصم $off';
  }

  @override
  String dealsPercent(String n) {
    return '$n٪';
  }

  @override
  String dealsPrice(String store, String price, String currency) {
    return '$store · $price $currency';
  }

  @override
  String dealsWasPrice(String price) {
    return 'بدل $price';
  }

  @override
  String dealsMinOrder(String amount) {
    return 'على طلب $amount أو أكتر';
  }

  @override
  String dealsUntil(String date) {
    return 'لحد $date';
  }

  @override
  String get dealsSourceVideo => 'فيديو المحل';

  @override
  String get dealsSourcePost => 'بوست المحل';

  @override
  String get dealsSourcePage => 'صفحة المحل';

  @override
  String get dealsSourceFlyer => 'نشرة المحل';

  @override
  String get dealsSourceReceipts => 'فواتير بيوت حواليك';

  @override
  String get dealsSourcePartner => 'رابط شراكة';

  @override
  String get dealsSourceOther => 'المصدر';

  @override
  String get homeDealsTitle => 'عروض على نواقصك';

  @override
  String get recipesWeekGroup => 'خطة الأسبوع';

  @override
  String get recipesWeekAction => 'خطة الأسبوع';

  @override
  String get recipesAddToPantry => 'ضيف للمخزن';

  @override
  String recipesWeekDay(int day) {
    return 'اليوم $day';
  }

  @override
  String get recipesChefSecret => 'سر الشيف';

  @override
  String get recipesOnDeal => 'عليه عرض دلوقتي';

  @override
  String recipesFromCreator(String handle) {
    return 'من فيديو @$handle';
  }

  @override
  String get recipesTrendingGroup => 'ترند دلوقتي';

  @override
  String chefWorldState(int total, int ready) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total وصفة',
      few: '$total وصفات',
      two: 'وصفتين',
      one: 'وصفة واحدة',
    );
    return '$_temp0 · $ready منها مكتملة';
  }

  @override
  String get chefStateEmpty => 'المخزن فاضي — ضيف أكلك وأنا أقترح';

  @override
  String get chefStateReady => 'جاهزة أقترحلك أكلة من مخزنك';

  @override
  String get chefStateThinking => 'بفكر في أكلة من مخزنك…';

  @override
  String get chefError => 'مقدرتش أوصل لشيف زاد. جرّب تاني بعد شوية.';

  @override
  String get chefStale => 'مخزنك اتغيّر من آخر اقتراحات — اطلب جديدة لو حابب.';

  @override
  String get chefReadyTitle => 'شيف زاد جاهزة';

  @override
  String get chefReadyBody =>
      'دوس «وصفات من مخزني» وهتقولك تطبخ إيه من اللي عندك، واللي ناقصه حاجة بسيطة.';

  @override
  String get chefEmptyTitle => 'المخزن فاضي';

  @override
  String get chefEmptyBody =>
      'ضيف اللي عندك في المخزن، وشيف زاد تقترح أكلات منه.';

  @override
  String get chefAskCta => 'وصفات من مخزني';

  @override
  String get chefAsking => 'شيف زاد بتفكر…';

  @override
  String get chefAskAgain => 'اقتراحات جديدة';

  @override
  String get chefGroupPantry => 'من مخزونك';

  @override
  String get chefGroupMore => 'وجبات تانية';

  @override
  String get chefComplete => 'مكتملة';

  @override
  String chefMissingCount(int count) {
    return 'ناقصك $count';
  }

  @override
  String chefMinutes(int count) {
    return '$count دقيقة';
  }

  @override
  String get chefHaveHeading => 'من عندك';

  @override
  String get chefMissingHeading => 'ناقصك';

  @override
  String get chefMethodHeading => 'الطريقة';

  @override
  String get chefStepByStep => 'الوصفة كاملة خطوة بخطوة';

  @override
  String chefAddMissing(int count) {
    return 'ضيف الناقص لقايمة التسوق ($count)';
  }

  @override
  String get chefAddedOne => 'ضفت صنف لقايمة التسوق.';

  @override
  String chefAddedMany(int count) {
    return 'ضفت $count أصناف لقايمة التسوق.';
  }

  @override
  String get chefNothingToAdd => 'الناقص كله في قايمة التسوق أو المخزن.';

  @override
  String get chefRatePrompt => 'عجبتك؟ شيف زاد بتفتكر.';

  @override
  String get chefLike => 'عجبتني';

  @override
  String get chefDislike => 'مش لذوقي';

  @override
  String get chefDetailIngredients => 'المقادير';

  @override
  String get chefDetailSteps => 'طريقة التحضير';

  @override
  String get chefDetailAddToShopping => 'إضافة الناقص للتسوق';

  @override
  String get chefDetailClose => 'إغلاق';

  @override
  String get chefDetailRetry => 'إعادة المحاولة';

  @override
  String get chefDetailLoading => 'شيف زاد يجهز لك الوصفة…';

  @override
  String get chefDetailEmpty => 'شيف زاد مارجّعش الوصفة دي — جرب تاني';

  @override
  String get chefDetailSlow => 'شيف زاد اتأخر في الرد — جرب تاني';

  @override
  String get chefDetailFailed => 'عذراً، حدث خطأ أثناء تحميل الوصفة';

  @override
  String get chefHomeTitle => 'شيف زاد (اقتراحات ذكية)';

  @override
  String get chefHomeAllDepleted =>
      'مخزونك كله خلص — نزّل النواقص في التسوق وأنا أقترحلك أكل.';

  @override
  String get chefHomePantryEmpty =>
      'ضيف أصناف لمخزونك عشان شيف زاد يقترح لك طبق اليوم.';

  @override
  String get chefHomeComplete => 'مكتملة من مخزونك';

  @override
  String chefHomeMinutes(int count) {
    return '$count د';
  }

  @override
  String chefHomeMissingList(String items) {
    return 'ناقصك: $items';
  }

  @override
  String get chefHomeAddMissing => 'ضيفهم لقائمة التسوق';

  @override
  String get chefHomeTapSteps => 'اضغط للخطوات';

  @override
  String get homeDealsSeeAll => 'كل العروض';

  @override
  String get homeDealsSearching =>
      'بندوّرلك على عروض في محلاتك — اضغط تشوف اللي لقيناه';

  @override
  String get sheinShop => 'تسوّق على SHEIN';

  @override
  String get sheinDisclosure =>
      'زاد بياخد عمولة من SHEIN على المشتريات من الروابط دي، من غير ما السعر يزيد عليك.';

  @override
  String get homeNearbyTitle => 'ماركتات وصيدليات جنبك';

  @override
  String get homeNearbySeeAll => 'أماكني';

  @override
  String get homeNearbyFind =>
      'اعرف الماركتات والصيدليات اللي جنبك — اضغط وحدّد مكانك';

  @override
  String get homeDealsOrderOnAmazon => 'اطلبه من أمازون، يوصلك بسرعة';

  @override
  String get amazonAssociatesDisclosure =>
      'بصفتنا شريك في Amazon Associates، زاد بياخد عمولة من المشتريات المؤهلة — من غير أي زيادة عليك.';

  @override
  String get homeDealsWhyNeed => 'ناقص عندك';

  @override
  String get homeDealsWhyFavorite => 'من محلك';

  @override
  String get homeDealsWhyFire => 'خصم كبير';

  @override
  String get homeDealsWhyWant => 'بتدوّر عليه';

  @override
  String get homeDealsWhySeason => 'قبل الموسم';

  @override
  String get homeDealsWhyTop => 'من أقوى الخصومات';

  @override
  String homeDealsCode(String code) {
    return 'كود $code';
  }

  @override
  String get bankTestLifeEvent => 'ميعاد أو حدث';

  @override
  String get outOfAttemptsTitle => 'محاولاتك خلصت';

  @override
  String get lowAttemptsTitle => 'محاولاتك قربت تخلص';

  @override
  String get outOfAttemptsBody => 'شاهد إعلان وخد ٥ رسايل، أو اشترك وارتاح.';

  @override
  String get outOfAttemptsPlans => 'شوف الباقات';

  @override
  String get patternTitle => 'نمط استهلاكك';

  @override
  String get patternMenuSubtitle => 'محلاتك، ومواعيد شراك، ودورة كل صنف';

  @override
  String get patternLearningTitle => 'لسه بتعلّم';

  @override
  String get patternLearningMessage =>
      'زاد بيحسب نمطك كل ليلة من فواتيرك ومصروفك. صوّر فاتورة أو سجّل مصروف وارجع بكرة.';

  @override
  String get patternReadFailed =>
      'مقدرتش أقرا نمطك دلوقتي. اسحب لتحت وجرّب تاني.';

  @override
  String get patternWeekly => 'متوسط صرفك في الأسبوع';

  @override
  String get patternStores => 'محلاتك';

  @override
  String patternStoreLine(String visits, String share) {
    return '$visits زيارة · $share٪ من صرفك فيهم';
  }

  @override
  String get patternWhen => 'إمتى بتشتري';

  @override
  String patternWhenLine(String day, String part) {
    return 'غالباً يوم $day $part';
  }

  @override
  String patternEvery(String days) {
    return 'مشوار شرا كل $days أيام تقريباً';
  }

  @override
  String get patternWhenUnknown =>
      'محتاج ٤ مشاوير شرا على الأقل عشان أعرف إمتى بتشتري';

  @override
  String get patternPartMorning => 'الصبح';

  @override
  String get patternPartNoon => 'الضهر';

  @override
  String get patternPartEvening => 'المسا';

  @override
  String get patternPartNight => 'بالليل';

  @override
  String get patternItems => 'دورة كل صنف';

  @override
  String get patternItemsHint => 'دوس على صنف عشان تقول لزاد بتشتريه كل قد إيه';

  @override
  String patternItemEvery(String days) {
    return 'كل $days يوم';
  }

  @override
  String get patternSourceCustomer => 'انت اللي حددتها';

  @override
  String get patternSourceLearned => 'من مرات شراك';

  @override
  String get patternSourceEstimate => 'تقدير مبدئي';

  @override
  String get patternDueNow => 'وقت شراه';

  @override
  String patternDueIn(String days) {
    return 'الشرا الجاي بعد $days يوم';
  }

  @override
  String patternEditTitle(String item) {
    return 'بتشتري $item كل قد إيه؟';
  }

  @override
  String get patternEditField => 'عدد الأيام';

  @override
  String get patternEditInvalid => 'اكتب رقم من ١ لـ٣٦٥';

  @override
  String get patternEditSave => 'حفظ';

  @override
  String get patternEditReset => 'خلّي زاد يحكم';

  @override
  String get patternEditNotInPantry => 'الصنف ده مش في مخزنك دلوقتي';

  @override
  String patternEditSaved(String item) {
    return 'اتحفظ — زاد هيحسب $item على كده';
  }

  @override
  String get homeBankOffBanner =>
      '⚠️ قراءة رسائل البنك متوقفة.. اضغط هنا لإعادة تفعيلها لتحديث رصيدك ومصاريفك تلقائياً';

  @override
  String get homeBankStalledHint =>
      'لو هي مفعّلة: اطفيها وشغّلها تاني من الصفحة اللي هتفتح.';

  @override
  String get homeLocationOffBanner =>
      '📍 موقعك غير مفعّل.. فعّل اللوكيشن عشان زاد يربط عروض السوبرماركت والمحلات القريبة منك ويقوم بمهامه صح';

  @override
  String get homeLocationLater => 'مش دلوقتي';

  @override
  String get channelCardTitle => 'مفيش طريقة أوصلك بيها';

  @override
  String get channelCardBody =>
      'الإشعارات مقفولة وتليجرام مش مربوط، فمواعيد الدوا والفواتير وتنبيه الميزانية مش هتوصلك. واحدة منهم كفاية.';

  @override
  String get channelCardNotifications => 'فعّل الإشعارات';

  @override
  String get channelCardTelegram => 'اربط تليجرام';

  @override
  String get briefWhy => 'ليه؟';

  @override
  String briefWhyDose(String name, String time) {
    return 'من جدول $name: جرعة الساعة $time، ومفيش تسجيل إنها اتاخدت.';
  }

  @override
  String briefWhyMissed(String count) {
    return 'جرعات النهارده اللي عدّى ميعادها ومااتسجلتش: $count.';
  }

  @override
  String get briefWhyOverspent =>
      'المتاح للدورة دي تحت الصفر: رصيد أول الدورة ناقص اللي اتصرف والالتزامات الثابتة.';

  @override
  String briefWhyRenewal(String name) {
    return '«$name» متسجل في اشتراكاتك، وده ميعاد تجديده الجاي.';
  }

  @override
  String briefWhyShortage(String name, String left, String threshold) {
    return '$name: فاضل $left، وده الحد اللي بيبقى عنده ناقص ($threshold).';
  }

  @override
  String briefWhyRunningOut(String name, String left, String perDay) {
    return '$name: فاضل $left، وبتستهلك حوالي $perDay في اليوم.';
  }

  @override
  String briefWhyRunningOutApprox(String name, String left, String perDay) {
    return '$name: فاضل $left، واستهلاكك لسه بيتقاس — حوالي $perDay في اليوم، فده تقدير.';
  }

  @override
  String get briefWhyFamily =>
      'حد في شات العيلة قال إنها ناقصة، وزاد لقطها وهو بيراجع الشات.';

  @override
  String briefMedicineLow(String name, String days) {
    return '$name هيخلص بعد $days يوم';
  }

  @override
  String get briefMedicineLowDetail => 'اطلب علبة جديدة قبل ما يخلص';

  @override
  String briefBudgetDanger(String daily, String days) {
    return 'الميزانية في خطر: باقي $daily في اليوم لـ$days يوم';
  }

  @override
  String get briefBudgetDangerDetail => 'شوف فلوسي — لسه فيه وقت تلحق';

  @override
  String briefSeasonRamadan(String days) {
    return 'رمضان بعد $days يوم';
  }

  @override
  String briefSeasonHijjah(String days) {
    return 'العشر من ذي الحجة بعد $days يوم';
  }

  @override
  String get briefSeasonDetail => 'جهّز الأساسيات قبل ما الأسعار تعلى';

  @override
  String briefWhyMedicineLow(String name, String days) {
    return '$name: الحبوب اللي فاضلة ÷ الجرعات في اليوم = $days يوم.';
  }

  @override
  String briefWhyBudgetDanger(String available, String days, String daily) {
    return 'المتاح $available على $days يوم = $daily في اليوم، ومعدل صرفك لحد دلوقتي بيقول إنه مش هيكفي.';
  }

  @override
  String get briefWhySeason =>
      'من تقويم أم القرى بتوقيت بلدك — والأسعار بتعلى قبل الموسم.';

  @override
  String get accountRestoreTitle => 'حسابك مجدول للحذف';

  @override
  String accountRestoreBody(int days) {
    return 'طلبت حذف حسابك، وهيتمسح هو وكل بياناته نهائياً بعد $days يوم. تحب ترجّعه؟';
  }

  @override
  String get accountRestoreLeave => 'خروج';

  @override
  String get accountRestoreYes => 'رجّع حسابي';

  @override
  String get accountRestoreFailed =>
      'تعذر استرجاع الحساب دلوقتي. افتح التطبيق تاني وجرّب.';

  @override
  String get settingsCompanionSection => 'رفيقك';

  @override
  String get settingsFoodPatternTitle => 'صورة أكل البيت';

  @override
  String get settingsFoodPatternBody =>
      'مرة في الشهر بالكتير، زاد يوصف أكل البيت من المشتريات المتسجلة ويقترح إضافات. وصف مشتريات مش نصيحة طبية.';

  @override
  String get commuteTitle => 'أتعلم مواعيد نزولك ورجوعك';

  @override
  String get commuteBody => 'اختياري. مواعيد بس، من غير أماكن ولا مشاوير.';

  @override
  String get commuteConsentTitle => 'زاد يتعلم مواعيد يومك؟';

  @override
  String get commuteConsentBody =>
      'زاد هيحسب إمتى بتنزل من البيت وبترجع، من خروجك ورجوعك للبيت. عشان يظبط تنبيهاتك على يومك ويكلمك في الوقت المناسب.\n\nبيتحسب على موبايلك، وللسيرفر بيروح ملخص المواعيد والأيام بس، من غير أي إحداثيات أو أماكن شغل أو خط سير. محدش من العيلة بيشوفه. ولو قفلت المفتاح، بيتمسح من الموبايل والسيرفر.';

  @override
  String get commuteConsentAgree => 'موافق';

  @override
  String get commuteConsentDecline => 'لأ، مش دلوقتي';

  @override
  String get settingsPetCallsTitle => 'نداءات زادو';

  @override
  String get settingsPetCallsBody =>
      'زادو بيبعتلك لما يجوع أو يعطش، على تليجرام والإشعارات. قفلها مش بيوقف تحية الصبح ولا العروض.';

  @override
  String get homeWidgetSubs => 'اشتراكات';

  @override
  String get homeWidgetSubsEmpty => 'ضيف اشتراك';

  @override
  String get homeWidgetSubsToday => 'النهارده';

  @override
  String get homeWidgetSubsTomorrow => 'بكرة';

  @override
  String homeWidgetSubsInDays(Object days) {
    return 'بعد $days يوم';
  }

  @override
  String get homeWidgetPantry => 'المخزون';

  @override
  String homeWidgetPantryShort(Object count) {
    return '$count ناقص';
  }

  @override
  String get homeWidgetPantryFine => 'كله تمام';

  @override
  String homeWidgetPantryCount(Object count) {
    return '$count صنف';
  }

  @override
  String get homeWidgetPantryEmpty => 'ضيف أصناف';

  @override
  String get homeWidgetPharmacy => 'الصيدلية';

  @override
  String get homeWidgetPharmacyNone => 'مفيش جرعات';

  @override
  String homeWidgetPharmacyActive(Object count) {
    return '$count دوا';
  }

  @override
  String get homeWidgetPharmacyEmpty => 'ضيف دوا';

  @override
  String get homeWidgetShortages => 'النواقص';

  @override
  String homeWidgetShortagesCount(int count) {
    return '$count تتجاب';
  }

  @override
  String get homeWidgetShortagesEmpty => 'مفيش نواقص';

  @override
  String get placesTabMine => 'أماكني';

  @override
  String get placesOutingsTurnOn => 'فعّل تسجيل خروجاتي';

  @override
  String get placesOutingsWaiting =>
      'شغال. أول ما تخرج وترجع البيت، خروجتك هتظهر هنا.';

  @override
  String get familyHeaderTitle => 'عيلتي';

  @override
  String get shellLanguageShort => 'EN';

  @override
  String get chefHomeTapHint =>
      'اضغط وأنا أقترحلك طبق من اللي عندك في المخزون.';

  @override
  String get chefFullRecipe => 'الشرح الكامل وأسرار الشيف';

  @override
  String get chefSecrets => 'أسرار الشيف';

  @override
  String get chefSourceLink => 'شوف الوصفة في مصدرها';

  @override
  String chefSourceHandle(Object handle) {
    return 'شوف الوصفة عند @$handle';
  }

  @override
  String get chefAsk => 'اسأل الشيف عن الوصفة دي';

  @override
  String chefAskPrefill(Object name) {
    return 'يا شيف، في وصفة $name: ';
  }

  @override
  String familyTitleOf(Object name) {
    return 'عيلة $name';
  }

  @override
  String familyMembersCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فرد',
      few: '$count أفراد',
      two: 'فردين',
      one: 'فرد واحد',
    );
    return '$_temp0';
  }

  @override
  String get familyActionInvite => 'دعوة';

  @override
  String get familyActionShare => 'مشاركة';

  @override
  String get familyActionSos => 'طوارئ';

  @override
  String get familyChatTools => 'أدوات الشات';

  @override
  String get familyChatQuickReplies => 'ردود سريعة';

  @override
  String get familyChatRequest => 'طلب مصروف';

  @override
  String get familyChatPoll => 'تصويت';

  @override
  String get familyChatTask => 'مهمة جديدة';

  @override
  String get familyChatGrocery => 'طلب بقالة';

  @override
  String get familyChatSos => 'نداء طوارئ';

  @override
  String get pulseTitle => 'نبض فلوسك';

  @override
  String pulseLastDays(num days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'آخر $days يوم',
      few: 'آخر $days أيام',
    );
    return '$_temp0';
  }

  @override
  String pulseLess(Object pct) {
    return 'أقل $pct٪ من الفترة اللي قبلها';
  }

  @override
  String pulseMore(Object pct) {
    return 'أكتر $pct٪ من الفترة اللي قبلها';
  }

  @override
  String get pulseDaily => 'متوسط اليوم';

  @override
  String get pulsePeak => 'أعلى يوم';

  @override
  String get pulseTop => 'أكبر بند';

  @override
  String pulseAskPrompt(Object category) {
    return 'حلل صرفي على $category';
  }

  @override
  String get brainReportWaits => 'سجل 3 مصاريف وتقرير زاد الكامل يجهز';

  @override
  String get profileLanguageSubtitle => 'عربي أو English، بضغطة واحدة';

  @override
  String get profileCompanionTitle => 'رفيق زاد';

  @override
  String get profileCompanionSubtitle => 'زادو، هدومه وألعابه ولفله';

  @override
  String get profilePremiumTitle => 'زاد بريميوم';

  @override
  String get profilePremiumSubtitle => 'اشتراكك ومميزاتك ورصيدك';

  @override
  String get tourOpen => 'جولة في زاد';

  @override
  String get profileTourSubtitle => 'لفّة سريعة على كل حتة في التطبيق';

  @override
  String get tourNext => 'التالي';

  @override
  String get tourSkip => 'تخطي';

  @override
  String get tourDone => 'يلا نبدأ';

  @override
  String tourStepOf(Object step, Object total) {
    return '$step من $total';
  }

  @override
  String get tourWelcomeTitle => 'أهلاً بيك في زاد';

  @override
  String get tourWelcomeBody => 'في نص دقيقة هنوريك كل حاجة فين.';

  @override
  String get tourHomeTitle => 'الرئيسية';

  @override
  String get tourHomeBody => 'فلوسك المتاحة، وأهم اللي محتاج يتعمل النهارده.';

  @override
  String get tourMoneyTitle => 'فلوسي';

  @override
  String get tourMoneyBody => 'ميزانيتك ومصاريفك والتزاماتك الشهرية.';

  @override
  String get tourMicTitle => 'كلّم زاد';

  @override
  String get tourMicBody =>
      'قول «سجل ٥٠ جنيه قهوة» أو اسأل أي سؤال، وزاد يرد عليك.';

  @override
  String get tourCameraTitle => 'صوّر الفاتورة';

  @override
  String get tourCameraBody =>
      'صوّر إيصال، وزاد يسجله في مصاريفك ويضيف الحاجات للمخزن.';

  @override
  String get tourHouseTitle => 'بيتي';

  @override
  String get tourHouseBody => 'المخزن والنواقص والصيدلية ووصفات الشيف.';

  @override
  String get tourMoreTitle => 'المزيد';

  @override
  String get tourMoreBody => 'العيلة وعقل زاد وحسابك وكل المزايا.';

  @override
  String get tourBellTitle => 'الإشعارات';

  @override
  String get tourBellBody => 'كل تنبيهات زاد وتذكيراته في مكان واحد.';

  @override
  String get shoppingBasketEmpty => 'السلة فاضية — ضيف اللي ناقصك';

  @override
  String adWatchFor(String reward) {
    return 'شاهد إعلان وخد $reward';
  }

  @override
  String get adLadderFirst =>
      'الإعلان التاني بيزوّد سؤال صوتي، والتالت صورة كمان';

  @override
  String get adLadderSecond => 'الإعلان التالت بيدّي صورة كمان';

  @override
  String adLadderAfter(String messages) {
    return 'كل إعلان بعد كده = $messages';
  }

  @override
  String get rewardVoiceOne => 'سؤال صوتي';

  @override
  String rewardVoiceMany(String n) {
    return '$n أسئلة صوتية';
  }

  @override
  String get rewardImageOne => 'صورة';

  @override
  String rewardImageMany(String n) {
    return '$n صور';
  }

  @override
  String get messagesOne => 'رسالة';

  @override
  String get messagesTwo => 'رسالتين';

  @override
  String messagesFew(String n) {
    return '$n رسايل';
  }

  @override
  String messagesMany(String n) {
    return '$n رسالة';
  }

  @override
  String get quotaKindMessages => 'رسايل';

  @override
  String get quotaKindVoice => 'أسئلة صوتية';

  @override
  String get quotaKindImages => 'صور';

  @override
  String quotaOfTotal(String left, String total) {
    return '$left من $total';
  }

  @override
  String get quotaScanFromImages => 'صورة من رصيد الصور';

  @override
  String get tickerLoading => 'جاري جلب الأسعار...';

  @override
  String get tickerError => 'تعذر جلب الأسعار الحية الآن — جرب تاني';

  @override
  String get tickerEmpty => 'لسه مفيش أسعار حية لبلدك — اضغط للتحديث';

  @override
  String get tickerRefresh => 'تحديث الأسعار';

  @override
  String get tickerContribute => 'ساهم بسعر';

  @override
  String get householdTitle => 'البيت';

  @override
  String get householdPrices => 'الأسعار';

  @override
  String get householdFamily => 'العيلة';

  @override
  String get householdPantry => 'المخزن';

  @override
  String get householdShopping => 'نواقص وتسوق';

  @override
  String get householdPharmacy => 'الصيدلية';

  @override
  String get householdRecipes => 'وصفات';

  @override
  String get notifTitle => 'الإشعارات';

  @override
  String notifUnread(int count) {
    return '$count غير مقروء';
  }

  @override
  String get notifReadAloud => 'قراءة التنبيهات صوتيًا';

  @override
  String get notifEmptyTitle => 'لا توجد إشعارات حالياً.';

  @override
  String get notifEmptyBody => 'هنعلمك أول ما يحصل حاجة تستاهل انتباهك';

  @override
  String get notifBankSection => 'عمليات بنكية بانتظارك';

  @override
  String get notifInsightsSection => 'تنبيهات ذكاء زاد';

  @override
  String get notifBrainSection => 'تنبيهات عقل زاد';

  @override
  String get notifAppSection => 'إشعارات التطبيق';

  @override
  String get notifNotImportant => 'مش مهم';

  @override
  String get notifWrongNumber => 'الرقم غلط';

  @override
  String get notifAlreadyKnew => 'عرفت خلاص';

  @override
  String notifOnAmazon(String name) {
    return '🛒 $name على أمازون';
  }

  @override
  String get notifBell => 'التنبيهات';

  @override
  String notifBellUnread(int count) {
    return 'التنبيهات — $count مش مقروء';
  }

  @override
  String get shopNoReach => 'مقدرتش أوصل لزاد دلوقتي. جرّب تاني.';

  @override
  String get shopAddHint => 'محتاج تشتري إيه؟';

  @override
  String get shopAddTooltip => 'ضيف';

  @override
  String get shopAddProduct => 'إضافة منتج للقائمة';

  @override
  String get shopSmartFill => 'تعبئة ذكية';

  @override
  String get shopWhatsApp => 'واتساب';

  @override
  String get shopPriorityHigh => 'حرج';

  @override
  String get shopPriorityMedium => 'متوسط';

  @override
  String get shopPriorityLow => 'منخفض';

  @override
  String get shopEmptyTitle => 'قائمة التسوق فارغة';

  @override
  String get shopEmptyBody => 'زاد سيضيف النواقص تلقائياً!';

  @override
  String get shopFilterEmptyTitle => 'لا توجد عناصر بهذا التصنيف';

  @override
  String get shopFilterEmptyBody => 'جرّب أولوية تانية.';

  @override
  String get shopBought => 'اتشترى';

  @override
  String get shopBasketTitle => 'سلة زاد الذكية';

  @override
  String shopBasketPartial(int priced, int lines) {
    return 'تقدير لـ $priced من $lines صنف — «تعبئة ذكية» تقدّر الباقي';
  }

  @override
  String get shopBudgetLeftUnknown => 'الميزانية المتبقية: —';

  @override
  String shopBudgetLeft(String amount) {
    return 'الميزانية المتبقية: $amount';
  }

  @override
  String shopBudgetPct(int pct) {
    return '$pct% من الميزانية';
  }

  @override
  String get shopOverBudget => 'هذه القائمة تتجاوز الميزانية المتبقية!';

  @override
  String get shopMayNeed => 'قد تحتاج أيضاً';

  @override
  String get shopAddToList => 'إضافة للقائمة';

  @override
  String shopStockLow(String qty) {
    return 'في البيت $qty بس';
  }

  @override
  String shopStockEnough(String qty) {
    return 'في البيت $qty — مش ناقص';
  }

  @override
  String shopRunsOutIn(int days) {
    return 'ينفد بعد $days أيام';
  }

  @override
  String shopBoughtItem(String name) {
    return 'تم شراء $name';
  }

  @override
  String shopRemoveGroupTitle(String name) {
    return 'تشيل $name من القائمة؟';
  }

  @override
  String shopRemoveGroupBody(int count) {
    return 'هيتشالوا $count سطور مع بعض.';
  }

  @override
  String get shopRemoveThem => 'شيلهم';

  @override
  String shopGroupKinds(String name, int count) {
    return '$name · $count أنواع';
  }

  @override
  String get shopHideKinds => 'اخفي الأنواع';

  @override
  String get shopShowKinds => 'وريني الأنواع';

  @override
  String get shopFieldName => 'اسم المنتج';

  @override
  String get shopFieldQty => 'الكمية';

  @override
  String get shopFieldPrice => 'السعر التقديري';

  @override
  String get shopFieldStore => 'المتجر (اختياري)';

  @override
  String get pantryEmptyTitle => 'المخزون فارغ';

  @override
  String get pantryEmptyBody => 'ابدأ بإضافة منتجات لتنظم مخزون منزلك';

  @override
  String get pantryScan => 'تصوير';

  @override
  String get pantrySearchEmptyTitle => 'لا توجد نتائج';

  @override
  String get pantrySearchEmptyBody => 'جرّب البحث بكلمة مختلفة';

  @override
  String get pantryScanTooltip => 'تصوير المخزون';

  @override
  String get pantryAddManual => 'إضافة يدوية';

  @override
  String pantryLowBanner(int count) {
    return 'نواقص المخزون ($count)';
  }

  @override
  String get pantryUnspecified => ' (غير محدد)';

  @override
  String get pantryToShopping => 'نزّلها في التسوق';

  @override
  String get pantryExpiringSoon => 'ينتهي قريباً';

  @override
  String get pantrySuggestRecipe => 'اقتراح وصفة';

  @override
  String get pantryExpired => 'منتهي الصلاحية';

  @override
  String pantryDaysLeft(String days) {
    return 'باقي $days يوم';
  }

  @override
  String get pantryLow => 'منخفض';

  @override
  String get pantryExpiredShort => 'منتهي';

  @override
  String pantryDays(int days) {
    return '$days يوم';
  }

  @override
  String get pantryUseOne => 'استهلاك واحدة';

  @override
  String get pantryAddOne => 'زيادة واحدة';

  @override
  String get pantryEditItem => 'تعديل الصنف';

  @override
  String get pantryOut => 'خلص';

  @override
  String pantryKinds(int count) {
    return '$count أنواع';
  }

  @override
  String get pantryShowKinds => 'اعرض الأنواع';

  @override
  String get pantryUsedOne => 'استهلكت واحدة';

  @override
  String get pantryIncreaseOne => 'زوّد واحدة';

  @override
  String pantryQty(String qty) {
    return 'الكمية: $qty';
  }

  @override
  String get pantryAdded => 'أُضيفت';

  @override
  String get pantryAddTitle => 'إضافة منتج جديد';

  @override
  String get pantryClose => 'إغلاق';

  @override
  String get pantryNameHint => 'مثلاً: حليب';

  @override
  String get pantryUnit => 'الوحدة';

  @override
  String get pantryCategory => 'القسم';

  @override
  String get pantryExpiryField => 'تاريخ الصلاحية (اختياري)';

  @override
  String get pantryOccasional => 'بشتريها على فترات';

  @override
  String get pantryOccasionalBody =>
      'مش هتتحسب ناقصة لما تخلص، ومش هفكّرك بيها';

  @override
  String get pantryExpiryPick => 'اختار التاريخ';

  @override
  String pantryExpiryEstimate(String date) {
    return 'تقديري: $date';
  }

  @override
  String get pantryExpiryEstimateNote =>
      'لو سبته كده هحفظ التاريخ التقديري، غيّره لو عارف التاريخ الحقيقي';

  @override
  String get pantryExpiryIn3Days => '٣ أيام';

  @override
  String get pantryExpiryInWeek => 'أسبوع';

  @override
  String get pantryExpiryInMonth => 'شهر';

  @override
  String get pantryExpiryClear => 'امسح التاريخ';

  @override
  String get notifNoneNew => 'مفيش تنبيهات جديدة';

  @override
  String get pantryFinish => 'خلص';

  @override
  String pantryFinishedSnack(String name) {
    return '$name خلص';
  }

  @override
  String get pantryUndo => 'تراجع';

  @override
  String get pantryDeleteItem => 'حذف الصنف';

  @override
  String get pantryStarterTitle => 'ضيف أساسيات بيتك بلمسة';

  @override
  String get pantryStarterBody =>
      'علّم على اللي عندك دلوقتي، وزاد يتابعه ويقولك قبل ما يخلص.';

  @override
  String pantryStarterAdd(int count) {
    return 'ضيف $count';
  }

  @override
  String get pantryStarterReceipt => 'أو صوّر فاتورة الشرا';

  @override
  String get introTitle => 'عرّفني بيك';

  @override
  String get introLead =>
      'خمس أسئلة وسؤال اختياري، عشان أكلمك صح وآخد بالي من اللي في رعايتك.';

  @override
  String get introNameQuestion => 'أناديك بإيه؟';

  @override
  String get introNameHint => 'اسمك أو اسم الدلع';

  @override
  String get introGenderQuestion => 'أكلمك بصيغة إيه؟';

  @override
  String get introGenderMale => 'راجل';

  @override
  String get introGenderFemale => 'ست';

  @override
  String get introRoleQuestion => 'إنت مين في البيت؟';

  @override
  String get introRoleFather => 'أب';

  @override
  String get introRoleMother => 'أم';

  @override
  String get introRoleHusband => 'زوج';

  @override
  String get introRoleWife => 'زوجة';

  @override
  String get introRoleSon => 'ابن';

  @override
  String get introRoleDaughter => 'بنت';

  @override
  String get introRoleSingle => 'عايش لوحدي';

  @override
  String get introRoleStudent => 'طالب';

  @override
  String get introRoleGrandparent => 'جد/جدة';

  @override
  String get introRoleOther => 'غير كده';

  @override
  String get introCaresQuestion => 'مين في رعايتك؟';

  @override
  String get introCaresHint => 'اختار كل اللي ينطبق.';

  @override
  String get introCaresChildren => 'أولادي';

  @override
  String get introCaresParents => 'أبويا أو أمي';

  @override
  String get introCaresSpouse => 'زوجي أو زوجتي';

  @override
  String get introCaresSiblings => 'إخواتي';

  @override
  String get introCaresGrandparents => 'جدي أو جدتي';

  @override
  String get introCaresNobody => 'محدش — مسؤول عن نفسي بس';

  @override
  String get introHouseholdQuestion => 'كام واحد عايش في البيت؟';

  @override
  String get introHouseholdHint => 'معاك إنت. عشان أحسب استهلاك البيت صح.';

  @override
  String get introHouseholdMany => '7 أو أكتر';

  @override
  String get introPayDayQuestion => 'بتقبض يوم كام في الشهر؟';

  @override
  String get introPayDayHint => 'اختياري — عشان أحسب شهرك من يوم القبض.';

  @override
  String get introPayDayNone => 'مش ثابت / مش عايز أقول';

  @override
  String introPayDay(int day) {
    return 'يوم $day';
  }

  @override
  String get introSave => 'يلا بينا';

  @override
  String get introSaveFailed => 'مقدرتش أحفظ — اتأكد من النت وجرّب تاني.';

  @override
  String get firstStepsTitle => 'أول خطوة';

  @override
  String get firstStepsLead =>
      'تلات خطوات في دقيقتين، وزاد يبدأ يشتغل معاك من النهارده.';

  @override
  String get firstStepsSpendTitle => 'سجّل أول مصروف';

  @override
  String get firstStepsSpendBody =>
      'أي حاجة صرفتها النهارده — قهوة، مواصلات، عيش. من هنا زاد بيبدأ يفهم شهرك.';

  @override
  String get firstStepsSpendDone => 'اتسجل ✓';

  @override
  String get firstStepsSpendAction => 'سجّل مصروف';

  @override
  String get firstStepsAlertsTitle => 'فعّل الإشعارات';

  @override
  String get firstStepsAlertsBody =>
      'عشان أقولك لما الميزانية تقرب تخلص، وتوصلك مواعيد الدوا والفواتير في وقتها.';

  @override
  String get firstStepsAlertsDone => 'متفعّلة ✓';

  @override
  String get firstStepsAlertsAction => 'فعّل';

  @override
  String get firstStepsTelegramTitle => 'اربط بوت تليجرام';

  @override
  String get firstStepsTelegramBody =>
      'من غيره التذكيرات وسؤال «اقفل يومك» مش هتوصلك وانت برّه التطبيق.';

  @override
  String get firstStepsGo => 'يلا على زاد';

  @override
  String get firstStepsLater => 'كمّل بعدين — افتح زاد';

  @override
  String get petLinesHungry =>
      'بطني بتصوصو… تأكّلني؟ 🍎\nجعان أوي 🥺 حاجة صغيرة بس\nشامم ريحة أكل؟ لأ ده أنا اللي جعان 😅';

  @override
  String get petLinesThirsty =>
      'عطشان… شوية مية؟ 💧\nريقي ناشف 🥵 اسقيني\nكوباية مية واحدة وأبقى زي الفل 💧';

  @override
  String get petLinesSleepy =>
      'نعسان… 😴 تصبح على خير\nهاااه 🥱 نكمّل بكرة؟\nعيني بتقفل لوحدها… 💤';

  @override
  String petLinesSad(String name) {
    return 'وحشتني… ونسيت أكلي وميتي 🥺\n$name زعلان شوية… تعالى نقعد سوا 💔';
  }

  @override
  String get petLinesHappy =>
      'أنا مبسوط معاك 💚\nشكراً إنك فاكرني 🥰\nإنت أحلى صاحب 🤗';

  @override
  String get petLinesIdleLogged =>
      'يومك عامل إيه؟ ✨\nأنا هنا لو احتجتني 💚\nسجّلت النهارده — برافو عليك 👏';

  @override
  String get petLinesIdleNotLogged =>
      'سجّلت مصروفاتك النهارده؟ 📝\nمصروف واحد بس وأفرح بيك 🌱';

  @override
  String get petLinesFed => 'يمّ يمّ! 😋\nتسلم إيدك 🍎\nأحلى أكلة 🤤';

  @override
  String get petLinesFull => 'شبعان خلاص 🤭\nمش قادر آكل تاني 😅';

  @override
  String get petLinesWatered => 'آآه انتعشت! 💧\nكده أحسن بكتير 😌';

  @override
  String get petLinesNotThirsty => 'مش عايز مية دلوقتي 🙈\nشربت كفاية 😄';

  @override
  String get petLinesPetted => 'هيهي بتزغزغني 🤭\nكمان! كمان! 🥰\nبحبك 💚';

  @override
  String get cookDone => 'طبختها';

  @override
  String get cookSheetTitle => 'اخصم اللي استخدمته من البيت';

  @override
  String get cookSheetHint =>
      'دي الكميات اللي أتوقعها — عدّلها لو استخدمت أكتر أو أقل.';

  @override
  String cookConfirm(int count) {
    return 'اخصم $count';
  }

  @override
  String get cookNothing => 'مالقيتش مكونات الوصفة دي في بيتك.';

  @override
  String cookDoneSnack(int count) {
    return 'خصمت $count من البيت ✅';
  }

  @override
  String get cookLess => 'أقل';

  @override
  String get cookMore => 'أكتر';

  @override
  String get profileRegionTitle => 'منطقتك';

  @override
  String get profileRegionHijazi => 'حجازي';

  @override
  String get profileRegionNajdi => 'نجدي';

  @override
  String get profileRegionEast => 'شرقي';

  @override
  String get profileRegionSouth => 'جنوبي';

  @override
  String get profileRegionGeneral => 'عام';

  @override
  String get pantryCatAll => 'الكل';

  @override
  String get pantryCatGrocery => 'البقالة';

  @override
  String get pantryCatVegetables => 'الخضار';

  @override
  String get pantryCatFruit => 'الفواكه';

  @override
  String get pantryCatMeat => 'اللحوم';

  @override
  String get pantryCatDairy => 'الألبان';

  @override
  String get pantryCatDrinks => 'المشروبات';

  @override
  String get pantryCatCare => 'العناية';

  @override
  String get pantryCatOther => 'أخرى';

  @override
  String get pantryUnitPiece => 'حبة';

  @override
  String get pantryUnitKilo => 'كجم';

  @override
  String get pantryUnitGram => 'جرام';

  @override
  String get pantryUnitLitre => 'لتر';

  @override
  String get pantryUnitCan => 'علبة';

  @override
  String get pantryUnitBag => 'كيس';

  @override
  String get pantryUnitBottle => 'قرشة';

  @override
  String get pantryUnitCrate => 'صندوق';

  @override
  String get shopShareHeader => 'قائمة تسوق زاد:';

  @override
  String shopShareTotal(String total, String currency) {
    return 'الإجمالي: $total $currency';
  }

  @override
  String shopShareEstimate(int priced, int all) {
    return '(تقدير لـ $priced من $all صنف)';
  }

  @override
  String get agentToolSetAppSetting => 'تغيير إعداد';

  @override
  String get agentToolDeleteMemory => 'نسيان ملاحظة';

  @override
  String get agentToolMarkSubscriptionPaid => 'دفع اشتراك';

  @override
  String get agentToolAddShortages => 'النواقص للقايمة';

  @override
  String get agentToolSnoozeDose => 'تأجيل جرعة';

  @override
  String get agentToolReportPrice => 'بلاغ سعر';

  @override
  String get agentToolClearPlaceVisits => 'مسح الأماكن';

  @override
  String get agentToolRateRecipe => 'رأيك في وصفة';

  @override
  String get agentToolDismissInsight => 'قفل تنبيه';

  @override
  String get rewardsCardTitle => 'مكافآت زاد';

  @override
  String get rewardsCardBody =>
      'شوف إعلان وخد رسايل زيادة، أو اشترك وارتاح من الإعلانات.';

  @override
  String get rewardsSubscribe => 'اشترك في زاد بريميوم';

  @override
  String get rewardsTelegram => 'بوت زاد على تليجرام';

  @override
  String get profileTelegramSubtitle => 'اربط حسابك وخلّي التذكيرات توصلك';

  @override
  String get profileExportTitle => 'تصدير بياناتي';

  @override
  String get profileExportSubtitle => 'نسخة من كل اللي زاد عارفه عنك';

  @override
  String get profileExportFailed => 'معرفناش نجهز الملف، جرّب تاني';

  @override
  String get profileExportSubject => 'بياناتي من زاد';

  @override
  String get homeCareTitle => 'اشتراكاتك وأدويتك';

  @override
  String get homeCareRenewsToday => 'بيتجدد النهارده';

  @override
  String get homeCareRenewsTomorrow => 'بيتجدد بكرة';

  @override
  String homeCareRenewsInDays(Object days) {
    return 'بيتجدد بعد $days يوم';
  }

  @override
  String homeCareDoseAt(Object time) {
    return 'الجرعة $time';
  }

  @override
  String get homeCareDoseNow => 'جرعتها دلوقتي';

  @override
  String get introSayPantry => 'التلاجة دي بتاعتي!';

  @override
  String get introSayFamily => 'البيت كله في إيد واحدة';

  @override
  String get introSayAssistant => 'بتعلّم منك كل يوم';

  @override
  String get introSayBudget => 'ونوفّر سوا';

  @override
  String get authZadoWatching => 'زادو بيبص على اللي بتكتبه… إلا كلمة السر.';

  @override
  String get authZadoNotLooking => 'مش باصص، والله';

  @override
  String authZadoHello(String name) {
    return 'أهلاً يا $name!';
  }

  @override
  String get consentTitle => 'قبل ما نبدأ، ده اتفاقنا';

  @override
  String consentVersionLine(String terms, String updated) {
    return 'الشروط $terms وسياسة الخصوصية ٤٫٠ · $updated';
  }

  @override
  String get consentPoint1Lead => 'بنحفظ اللي بتدخّله بس.';

  @override
  String get consentPoint1Body =>
      'حسابك وفلوسك ومخزونك وأدويتك ومواعيدك ورسايل العيلة، عشان زاد يساعدك بيهم.';

  @override
  String get consentPoint2Lead => 'كل إذن بموافقتك.';

  @override
  String get consentPoint2Body =>
      'إشعارات البنك والموقع والكاميرا والمايك، كل واحد بيتطلب لما تستخدم الميزة، وتقدر تقفله في أي وقت.';

  @override
  String get consentPoint3Lead => 'مابنبيعش بياناتك لحد.';

  @override
  String get consentPoint3Body =>
      'ومابنقراش كلمات سر البنك ولا أرقام الكروت ولا أكواد OTP.';

  @override
  String get consentPoint4Lead => 'الذكاء الاصطناعي بيساعد، وممكن يغلط.';

  @override
  String get consentPoint4Body =>
      'راجع الأرقام قبل أي قرار؛ زاد مش بنك ولا مستشار مالي.';

  @override
  String get consentPoint5Lead => 'الخطة المجانية فيها إعلانات';

  @override
  String get consentPoint5Body =>
      ' من Google. حسابات الأطفال مفيهاش إعلانات خالص.';

  @override
  String get consentPoint6Lead => 'بياناتك ملكك.';

  @override
  String get consentPoint6Body =>
      'تصدّرها في أي وقت، أو تمسح حسابك، والمسح بيتم بعد ١٤ يوم تقدر ترجع فيهم.';

  @override
  String get consentPoint7Lead => 'زاد للكبار من ١٨ سنة.';

  @override
  String get consentPoint7Body => 'الأطفال بيدخلوا كأفراد في عيلة وليّ أمرهم.';

  @override
  String get consentLegalToggle => 'النص القانوني الكامل (بالإنجليزي)';

  @override
  String get consentPrivacyLink => 'سياسة الخصوصية';

  @override
  String get consentTermsLink => 'شروط الاستخدام';

  @override
  String get consentTermsVersion => '٢٫٢';

  @override
  String get consentTermsUpdated => 'نوفمبر ٢٠٢٦';

  @override
  String get worldLabelBrain => 'عقل زاد';

  @override
  String get worldLabelChef => 'شيف زاد';

  @override
  String get worldLabelInv => 'المخزون';

  @override
  String get worldLabelShop => 'التسوق';

  @override
  String get worldLabelTx => 'المعاملات';

  @override
  String get worldLabelBudget => 'الميزانية';

  @override
  String get worldLabelStmt => 'كشف الحساب';

  @override
  String get worldLabelSubs => 'الاشتراكات';

  @override
  String get worldLabelPh => 'الصيدلية';

  @override
  String get worldLabelAppt => 'المواعيد';

  @override
  String get worldLabelMaint => 'الصيانة';

  @override
  String get worldLabelDocs => 'المستندات';

  @override
  String get worldLabelPlaces => 'أماكني';

  @override
  String get worldLabelComp => 'رفيق زاد';

  @override
  String get worldLabelChat => 'الشات';

  @override
  String get worldLabelNotif => 'الإشعارات';

  @override
  String get worldLabelProfile => 'حسابي';

  @override
  String get worldLabelPrem => 'بريميوم';

  @override
  String get worldLabelTas => 'بستان التسبيح';

  @override
  String get worldLabelGames => 'ألعاب زادو';

  @override
  String get worldLabelPrices => 'أسعار النهارده';

  @override
  String get worldLabelOffers => 'عروضي';

  @override
  String get worldLabelAch => 'إنجازاتي';

  @override
  String get worldLinksTitle => 'متصلة بـ';

  @override
  String get worldLinksHint => 'اللي بيحصل هنا بيأثر في:';

  @override
  String get worldBack => 'رجوع';

  @override
  String pantryWorldEyebrow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count صنف',
      few: '$count أصناف',
      two: 'صنفين',
      one: 'صنف واحد',
      zero: 'لسه مفيش أصناف',
    );
    return '$_temp0';
  }

  @override
  String pantryWorldState(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count حاجة قربت تخلص',
      few: '$count حاجات قربت تخلص',
      two: 'حاجتين قربوا يخلصوا',
      one: 'حاجة واحدة قربت تخلص',
      zero: 'مفيش حاجة قربت تخلص',
    );
    return '$_temp0';
  }

  @override
  String pantryLegendLow(int count) {
    return '$count قربت تخلص';
  }

  @override
  String pantryLegendExpiring(int count) {
    return '$count هتبوظ قريب';
  }

  @override
  String pantryLegendOk(int count) {
    return '$count تمام';
  }

  @override
  String get brainWorldState => 'متصل ويتعلم';

  @override
  String brainWorldEyebrow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عنصر متصل',
      zero: 'لسه مفيش عناصر',
    );
    return '$_temp0';
  }

  @override
  String get brainFilterAll => 'الكل';

  @override
  String get brainFilterLabel => 'فلتر المجالات';

  @override
  String get brainNetworkEmptyTitle => 'زاد لسه بيتعلم عنك';

  @override
  String get brainNetworkEmptyMessage =>
      'سجّل مصاريفك أو ضيف مخزون وأدوية، وهتلاقي الشبكة بتكبر هنا.';

  @override
  String get brainCardsTitle => 'جوه عقل زاد';

  @override
  String get brainCardStaffTitle => 'فريق زاد';

  @override
  String get brainCardStaffBody =>
      'اللي الموظفين لاحظوه في جولة الصبح على بيتك وفلوسك وعيلتك';

  @override
  String get brainCardMemoryTitle => 'زاد عارف عني إيه';

  @override
  String get brainCardMemoryBody =>
      'اللي زاد فاكره عنك وبيكلمك على أساسه — صحّحه أو خلّيه ينساه';

  @override
  String get brainCardGraphTitle => 'شبكة زاد';

  @override
  String get brainCardGraphBody =>
      'الناس والأماكن والحاجات اللي زاد عارفها ومترابطة إزاي — وصدّرها لأوبسيديان';

  @override
  String get brainCardMapTitle => 'خريطة زاد';

  @override
  String get brainCardMapBody =>
      'إزاي ميزانيتك واشتراكاتك وبيتك متصلين ببعض — بملء الشاشة';

  @override
  String get brainCardLogTitle => 'سجل تعديلات زاد';

  @override
  String get brainCardLogBody =>
      'كل حاجة زاد سجّلها أو عدّلها لك، وترجع فيها لو غلط';

  @override
  String get brainCardHealthTitle => 'صحة عقل زاد';

  @override
  String get brainCardHealthBody =>
      'زاد شغال في الخلفية ولا واقف — ولو واقف، ليه';

  @override
  String brainTelemetryLinks(int active, int total) {
    return 'الروابط: $active/$total';
  }

  @override
  String get brainTelemetryDecisions => 'قرارات النهارده';

  @override
  String get brainTelemetryGauge => 'مؤشر الثبات';

  @override
  String get brainTelemetryStable => 'مستقر';

  @override
  String get brainTelemetryAlert => 'تنبيه';

  @override
  String get zadStatusTitle => 'حالة زاد';

  @override
  String get zadStatusAllGood => 'زاد شغال وبيتابع';

  @override
  String get zadStatusNeedsFix => 'في حاجة واقفة ومحتاجة منك خطوة';

  @override
  String zadStatusAllButOne(String what) {
    return 'كله شغال ما عدا: $what';
  }

  @override
  String get zadStatusWorking => 'شغال';

  @override
  String get zadStatusStopped => 'واقف';

  @override
  String get zadStatusMaybe => 'ممكن يقف';

  @override
  String get zadStatusBank => 'قراءة رسائل البنك';

  @override
  String get zadStatusBankOk => 'زاد بيقرا رسائل البنك ويسجّلها.';

  @override
  String get zadStatusBankOff =>
      'قراءة رسائل البنك متوقفة. شغّلها عشان رصيدك ومصاريفك تتحدّث لوحدها.';

  @override
  String get zadStatusBankStalled =>
      'الخدمة مابقتش بتشوف إشعارات من فترة. لو هي مفعّلة: اطفيها وشغّلها تاني من الصفحة اللي هتفتح.';

  @override
  String get zadStatusBankSilent =>
      'مفعّلة، بس لسه ماجاتش ولا رسالة. لو مستني رسالة من البنك ومجتش: اطفيها وشغّلها تاني.';

  @override
  String get zadStatusNotifications => 'الإشعارات';

  @override
  String get zadStatusNotificationsOk =>
      'تنبيهات الجرعات والفواتير والميزانية بتوصلك.';

  @override
  String get zadStatusNotificationsOff =>
      'الإشعارات مقفولة، فتنبيهات الجرعات والفواتير مش هتوصلك.';

  @override
  String get zadStatusLocation => 'الموقع';

  @override
  String get zadStatusLocationOk =>
      'الموقع شغال، والعروض والمحلات القريبة بتتحسب من مكانك.';

  @override
  String get zadStatusLocationServiceOff =>
      'الموقع مقفول في الموبايل، فالقراءات مش هتبقى من مكانك الحقيقي.';

  @override
  String get zadStatusLocationDenied =>
      'زاد مش مسموحله يعرف مكانك، فالعروض والمحلات القريبة مش هتشتغل.';

  @override
  String get zadStatusBackground => 'الموقع طول الوقت';

  @override
  String get zadStatusBackgroundOk =>
      'تنبيهات الطريق شغالة حتى والتطبيق مقفول.';

  @override
  String get zadStatusBackgroundOff =>
      'من غير «طول الوقت» تنبيهات الطريق مش هتشتغل والتطبيق مقفول.';

  @override
  String get zadStatusBattery => 'توفير البطارية';

  @override
  String get zadStatusBatteryOk => 'الموبايل مش بيقيّد زاد في الخلفية.';

  @override
  String get zadStatusBatteryWarn =>
      'الموبايل ممكن يوقف زاد في الخلفية. اختار «بدون قيود» عشان القراءة ماتقطعش.';

  @override
  String get zadStatusFixOpenSettings => 'افتح الإعدادات';

  @override
  String get zadStatusFixAllow => 'اسمح';

  @override
  String get zadStatusFixLocationOn => 'شغّل الموقع';

  @override
  String get zadStatusFixBattery => 'فكّ القيود';

  @override
  String get gamesHubButton => 'ألعاب زادو';

  @override
  String get gamesHubTitle => 'ألعاب زادو';

  @override
  String get gamesBackTooltip => 'رجوع';

  @override
  String get gamesHubIntro => 'العب، كمّل السلسلة، اكسب بذور';

  @override
  String gamesHubToday(int target, String game) {
    return 'تحدي النهارده: $target نقطة في «$game»';
  }

  @override
  String gamesHubWeekly(int days, int goal) {
    return 'صندوق الأسبوع: $days من $goal أيام ورا بعض';
  }

  @override
  String gamesHubStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count أيام ورا بعض',
      one: 'يوم واحد',
      zero: 'ابدأ سلسلتك النهارده',
    );
    return '$_temp0';
  }

  @override
  String gamesHubBest(int score) {
    return 'أحسن نتيجة: $score';
  }

  @override
  String get gamesHubNotPlayed => 'لسه ما لعبتش';

  @override
  String get gamesHubPlay => 'العب';

  @override
  String get gamesHubChallengeDone => 'تحدي النهارده خلص';

  @override
  String get gameNameBall => 'اصطاد الكورة';

  @override
  String get gameNameRun => 'نطّة زادو';

  @override
  String get gameNameSort => 'زادو بيرتّب';

  @override
  String get gameNameStar => 'اصطاد النجوم';

  @override
  String get gameBlurbBall => 'كورة بتهرب، اصطادها بسرعة وكوّن كومبو';

  @override
  String get gameBlurbRun => 'انط فوق الصناديق وخد البذور والسرعة بتزيد';

  @override
  String get gameBlurbSort => 'ادمج البذور المتشابهة، ولغز جديد كل يوم';

  @override
  String get gameBlurbStar => 'حرّك زادو وامسك النجوم قبل ما تقع';

  @override
  String gameBest(int score) {
    return 'أحسن نتيجة: $score';
  }

  @override
  String get gameNewBest => 'رقم قياسي جديد!';

  @override
  String get gameEndTitle => 'خلصت الجولة';

  @override
  String gameEndScore(int score) {
    return '$score نقطة';
  }

  @override
  String gameChallenge(int target) {
    return 'تحدي النهارده: اوصل $target نقطة';
  }

  @override
  String gameChallengeProgress(int done, int target) {
    return '$done من $target';
  }

  @override
  String get gameChallengeDone => 'خلصت التحدي النهارده، برافو!';

  @override
  String gameSeedsGranted(int count) {
    return '+$count بذور';
  }

  @override
  String gameSeedsLeft(int count) {
    return 'باقي $count بذور النهارده';
  }

  @override
  String get gameSeedsCapped => 'وصلت للحد اليومي للبذور';

  @override
  String get gameDouble => 'ضاعف البذور';

  @override
  String get gameDoubleHint => 'بإعلان قصير';

  @override
  String get gameContinue => 'كمّل من مكانك';

  @override
  String get gameContinueHint => 'بإعلان قصير، مرة واحدة في الجولة';

  @override
  String get gameAdUnavailable => 'مفيش إعلان متاح دلوقتي';

  @override
  String get gameAgain => 'جولة تانية';

  @override
  String get gameDone => 'خلصت';

  @override
  String get gamePaused => 'اللعبة واقفة';

  @override
  String get gameResume => 'كمّل';

  @override
  String gameScoreSemantics(int score) {
    return 'النقط $score';
  }

  @override
  String gameCombo(int n) {
    return 'كومبو ×$n';
  }

  @override
  String gameLevel(int n) {
    return 'مستوى $n';
  }

  @override
  String gameLives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count محاولات',
      one: 'محاولة واحدة',
      zero: 'مفيش محاولات',
    );
    return '$_temp0';
  }

  @override
  String runGameTitle(String name) {
    return 'نطّة $name';
  }

  @override
  String runGameHint(String name) {
    return 'المس الشاشة عشان $name ينط';
  }

  @override
  String runGameHit(String name) {
    return '$name خبط!';
  }

  @override
  String runGameSeedsSemantics(int count) {
    return 'بذور $count';
  }

  @override
  String get sortGameTitle => 'زادو بيرتّب';

  @override
  String get sortGameHint =>
      'اسحب في أي اتجاه أو استخدم الأسهم، وادمج البذور المتشابهة';

  @override
  String get sortGameDaily => 'لغز النهارده';

  @override
  String get sortGameStuck => 'مفيش حركات تانية';

  @override
  String get sortGameLeft => 'يسار';

  @override
  String get sortGameRight => 'يمين';

  @override
  String get sortGameUp => 'فوق';

  @override
  String get sortGameDown => 'تحت';

  @override
  String sortGameTile(int value) {
    return 'بذرة بمستوى $value';
  }

  @override
  String get starGameTitle => 'اصطاد النجوم';

  @override
  String starGameHint(String name) {
    return 'اسحب $name يمين وشمال عشان يمسك النجوم';
  }

  @override
  String get starGameOver => 'النجوم خلصت منك';

  @override
  String shopWorldEyebrow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count حاجة ناقصة',
      few: '$count حاجات ناقصة',
      two: 'حاجتين ناقصين',
      one: 'حاجة واحدة ناقصة',
      zero: 'مفيش حاجة ناقصة',
    );
    return '$_temp0';
  }

  @override
  String shopWorldStores(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'من $count محل',
      few: 'من $count محلات',
      two: 'من محلين',
      one: 'من محل واحد',
    );
    return '$_temp0';
  }

  @override
  String get shopWorldAnyStore => 'من أي محل';

  @override
  String get shopWorldDone => 'القايمة فاضية';

  @override
  String get shopGroupAnyStore => 'أي محل';

  @override
  String shopPantryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'في المخزن $count صنف',
      few: 'في المخزن $count أصناف',
      two: 'في المخزن صنفين',
      one: 'في المخزن صنف واحد',
      zero: 'المخزن فاضي',
    );
    return '$_temp0';
  }

  @override
  String apptWorldToday(String weekday) {
    return 'النهارده $weekday';
  }

  @override
  String apptWorldNext(String title, String when) {
    return '$title $when';
  }

  @override
  String get apptWorldNone => 'مفيش مواعيد جاية';

  @override
  String get apptNextLabel => 'الميعاد الجاي';

  @override
  String get apptInNow => 'دلوقتي';

  @override
  String apptInMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'بعد $count دقيقة',
      few: 'بعد $count دقايق',
      two: 'بعد دقيقتين',
      one: 'بعد دقيقة',
    );
    return '$_temp0';
  }

  @override
  String apptInHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'بعد $count ساعة',
      few: 'بعد $count ساعات',
      two: 'بعد ساعتين',
      one: 'بعد ساعة',
    );
    return '$_temp0';
  }

  @override
  String apptInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'بعد $count يوم',
      few: 'بعد $count أيام',
      two: 'بعد يومين',
      one: 'بعد يوم',
    );
    return '$_temp0';
  }

  @override
  String phEyebrowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count دواء',
      few: '$count أدوية',
      two: 'دواءين',
      one: 'دوا واحد',
    );
    return '$_temp0';
  }

  @override
  String get phFamilyEyebrow => 'صيدلية العيلة';

  @override
  String phMemberState(String name) {
    return 'جدول $name';
  }

  @override
  String get phNoDosesToday => 'مفيش جرعات النهارده';

  @override
  String phDoseDueNow(String name) {
    return 'جرعة $name وقتها دلوقتي';
  }

  @override
  String phNextDose(String when) {
    return 'الجرعة الجاية $when';
  }

  @override
  String phDoseMissedLine(String name) {
    return 'فاتتك جرعة $name';
  }

  @override
  String get phDosesDone => 'خلصت جرعات النهارده';

  @override
  String get phPeriodMorning => 'الصبح';

  @override
  String get phPeriodNoon => 'الضهر';

  @override
  String get phPeriodAfternoon => 'العصر';

  @override
  String get phPeriodNight => 'بالليل';

  @override
  String phClockWords(String hour, String minutes, String period) {
    return '$hour$minutes $period';
  }

  @override
  String get phDoseTaken => 'اتاخدت';

  @override
  String get phDoseDue => 'وقتها دلوقتي';

  @override
  String get phDoseMissed => 'فاتت';

  @override
  String get phDoseUpcoming => 'جاية';

  @override
  String get phDoseSnoozed => 'اتأجلت شوية';

  @override
  String get phDosePassed => 'الميعاد عدّى';

  @override
  String get phSnooze => 'بعدين';

  @override
  String get phTake => 'خدته';

  @override
  String get phTakeFor => 'خدها';

  @override
  String phForPerson(String name) {
    return 'لـ$name';
  }

  @override
  String get phCourseDone => 'الكورس خلص';

  @override
  String phExpiredAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'منتهي من $count يوم',
      few: 'منتهي من $count أيام',
      two: 'منتهي من يومين',
      one: 'منتهي من يوم',
    );
    return '$_temp0';
  }

  @override
  String phExpiresIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تنتهي خلال $count يوم',
      few: 'تنتهي خلال $count أيام',
      two: 'تنتهي خلال يومين',
      one: 'تنتهي خلال يوم',
    );
    return '$_temp0';
  }

  @override
  String phRemaining(int count, String unit) {
    return 'متبقي $count $unit';
  }

  @override
  String phSupplyDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'يكفي $count يوم',
      few: 'يكفي $count أيام',
      two: 'يكفي يومين',
      one: 'يكفي يوم',
      zero: 'يكفي أقل من يوم',
    );
    return '$_temp0';
  }

  @override
  String get phDelete => 'حذف';

  @override
  String get phBadDoseTime => 'وقت جرعة مش مفهوم — عدّله';

  @override
  String get phNoSchedule => 'مالوش مواعيد — مش هفكّرك بيه';

  @override
  String get phSetTimes => 'حدد مواعيده';

  @override
  String get phConfirmQtyBadge => 'الكمية محتاجة تأكيد';

  @override
  String get phTakeDose => 'تناول جرعة';

  @override
  String get phRefill => 'تجديد الطلب';

  @override
  String get phToShopping => 'ضيفه للتسوق';

  @override
  String get phHowMuchLeft => 'فاضل قد إيه فعلاً؟';

  @override
  String phAddedToShopping(String name) {
    return 'ضفت $name لقايمة التسوق';
  }

  @override
  String get phDosesToday => 'جرعات النهارده';

  @override
  String get phNoDosesLeft => 'مفيش جرعات فاضلة النهارده.';

  @override
  String get phNoTimesYet =>
      'ولا دوا ليه مواعيد لسه — حدد مواعيد أي دوا تحت عشان أفكّرك بيه.';

  @override
  String get phLoadFailed => 'مقدرتش أجيب الأدوية';

  @override
  String get phEmptyTitle => 'لا توجد أدوية مسجلة بعد';

  @override
  String get phPullRetry => 'اسحب لتحت نجرب تاني.';

  @override
  String get phEmptyGuide =>
      'ضيفه بالزرار، أو صوّر العلبة، أو قول لزاد: \"باخد كونكور قرص الصبح وبالليل\" وهو يسجّله بمواعيده.';

  @override
  String get phMedicines => 'الأدوية';

  @override
  String phTimesTitle(String name) {
    return 'مواعيد $name';
  }

  @override
  String get phTimesHint => 'هفكّرك في كل ميعاد، وتقدر تسجّل الجرعة بضغطة.';

  @override
  String get phSaveTimes => 'احفظ المواعيد';

  @override
  String get phAdherence => 'الالتزام بالجرعات';

  @override
  String get phAdherenceWaiting => 'في انتظار أول جرعة';

  @override
  String get phCountTotal => 'إجمالي الأدوية';

  @override
  String get phCountExpiring => 'قرب الانتهاء';

  @override
  String get phCountLow => 'مخزون منخفض';

  @override
  String phExpiredBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count دواء منتهي الصلاحية — تخلص منه بأمان',
      few: '$count أدوية منتهية الصلاحية — تخلص منها بأمان',
      two: 'دواءين منتهيين الصلاحية — تخلص منهم بأمان',
      one: 'دواء منتهي الصلاحية — تخلص منه بأمان',
    );
    return '$_temp0';
  }

  @override
  String get phExpiringHeading => 'قرب الانتهاء — تخلص منها بأمان';

  @override
  String get phCostSpending => 'صرف الصحة الشهر ده';

  @override
  String get phCostBoxes => 'أسعار علب الأدوية';

  @override
  String get phTabMe => 'أنا';

  @override
  String get phTabMember => 'عضو';

  @override
  String get phMemberFallback => 'العضو';

  @override
  String phHeadNote(String name) {
    return 'إنت رب الأسرة — بتشوف جدول $name وتعدّل فيه وتعلّم الجرعة لو ساعدته';
  }

  @override
  String phReadOnlyNote(String name) {
    return 'جدول $name للمتابعة بس — رب الأسرة هو اللي يعدّل';
  }

  @override
  String phAddFor(String name) {
    return 'دوا لـ$name';
  }

  @override
  String phMemberLoadFailed(String name) {
    return 'مقدرتش أجيب أدوية $name';
  }

  @override
  String get phMemberEmptyTitle => 'لسه مفيش أدوية تقدر تشوفها';

  @override
  String get phMemberEmptyGuide =>
      'أدوية كل فرد بتظهر هنا بعد ما يوافق — اطلب المتابعة من صفحته في «عيلتي»';

  @override
  String phMemberDoses(String name) {
    return 'جرعات $name النهارده';
  }

  @override
  String get phEdit => 'تعديل';

  @override
  String phEditTitle(String name) {
    return 'تعديل $name';
  }

  @override
  String get phPhoto => 'صوّر الدوا';

  @override
  String get phAdd => 'إضافة';

  @override
  String get phScanUnclear =>
      'تعذر قراءة العلبة بدقة، يرجى المحاولة بزاوية أوضح';

  @override
  String get phScanOk => 'تم استخراج بيانات الدواء بنجاح';

  @override
  String get phScanReading => 'جاري قراءة علبة الدواء بالذكاء الاصطناعي...';

  @override
  String get phScanBtn => 'مسح العبوة بالكاميرا';

  @override
  String get phAddTitle => 'إضافة دواء';

  @override
  String get phReviewTitle => 'راجع الدواء';

  @override
  String get phReadFromBox =>
      'قريت ده من العلبة — عدّل أي حاجة غلط قبل ما تحفظ.';

  @override
  String get phFieldName => 'اسم الدواء';

  @override
  String get phFieldForWhom => 'لمين؟ (سيبها فاضية لو ليك)';

  @override
  String get phHintPeople => 'ماما، بابا، يوسف…';

  @override
  String get phFieldDosageNote => 'الجرعة (مثال: بعد الأكل)';

  @override
  String get phFieldTimesOptional => 'مواعيد الجرعة (اختياري)';

  @override
  String phTimesSuggested(String times) {
    return 'لسه مفيش مواعيد مضافة — مقترح: $times';
  }

  @override
  String get phFieldAmount => 'المبلغ';

  @override
  String phFieldAmountCur(String currency) {
    return 'المبلغ ($currency)';
  }

  @override
  String get phMoreDetails => 'تفاصيل إضافية (اختياري)';

  @override
  String get phSave => 'حفظ';

  @override
  String get phCancel => 'إلغاء';

  @override
  String get phConfirm => 'تأكيد';

  @override
  String get phPickTime => 'اختر ميعاد الجرعة';

  @override
  String get phAddTime => 'إضافة ميعاد';

  @override
  String get phPickExpiry => 'تاريخ الانتهاء — اضغط لاختيار التاريخ';

  @override
  String get phFieldQty => 'الكمية المتبقية';

  @override
  String get phFieldUnit => 'الوحدة';

  @override
  String get phFieldDailyCount => 'جرعات اليوم';

  @override
  String phFieldPerDose(String unit) {
    return 'الجرعة الواحدة كام $unit؟';
  }

  @override
  String get phPresetMorning => 'صباحاً';

  @override
  String get phPresetNoon => 'ظهراً';

  @override
  String get phPresetEvening => 'مساءً';

  @override
  String get phPresetBed => 'قبل النوم';

  @override
  String get phFieldIngredient => 'المادة الفعالة';

  @override
  String get phFieldDosageFreq => 'الجرعة (مثال: قرص كل 8 ساعات)';

  @override
  String get phChronic => 'دواء مزمن / روشتة متجددة شهرياً';

  @override
  String get phForFamilyMember => 'لمين في العائلة';

  @override
  String get phNone => 'بدون';

  @override
  String phDeleteBody(String name) {
    return 'حذف «$name» من الصيدلية؟';
  }

  @override
  String phQtyCurrent(String name, int count, String unit) {
    return '$name — الكمية الحالية المسجلة: $count $unit';
  }

  @override
  String get phPerDoseHelp =>
      'من غير الرقم ده مقدرش أحسب المخزون هيكفي كام يوم';

  @override
  String phRefillTitle(String name) {
    return 'تجديد طلب $name';
  }

  @override
  String phAddedQty(String unit) {
    return 'الكمية المضافة ($unit)';
  }

  @override
  String get phPrice => 'السعر';

  @override
  String get phExpiryDate => 'تاريخ الانتهاء';

  @override
  String get phAlarmHint =>
      'فعّل \"المنبهات الدقيقة\" من الإعدادات عشان تنبيهات مواعيد الدواء تشتغل بدقة';

  @override
  String get phErrNotHead => 'بس رب الأسرة يقدر يعدّل أدوية حد من العيلة.';

  @override
  String get phErrOffline =>
      'مفيش نت دلوقتي — ما اتحفظش حاجة. جرّب تاني لما يرجع.';

  @override
  String get phErrNotFound =>
      'الدوا ده مش موجود عند العضو دلوقتي — حدّث الصفحة.';

  @override
  String get phErrDuplicate => 'العضو عنده دوا بنفس الاسم ده.';

  @override
  String get phErrRejected => 'السيرفر رفض الحفظ. جرّب تاني.';

  @override
  String get tasEyebrow => 'ورد كل ٣٣ · شجرة كل ٩٩';

  @override
  String tasStateLine(int count, int flowers) {
    return '$count تسبيحة · $flowers وردة';
  }

  @override
  String get tasStateEmpty => 'ابدأ أول تسبيحة والورد هيفتّح';

  @override
  String get tasTabMine => 'بستاني';

  @override
  String get tasTabFamily => 'أشجار العيلة';

  @override
  String get tasTabChallenges => 'التحديات';

  @override
  String get tasStage1 => 'بذرة';

  @override
  String get tasStage2 => 'بذرة نبتت';

  @override
  String get tasStage3 => 'شتلة';

  @override
  String get tasStage4 => 'شجرة';

  @override
  String get tasStage5 => 'شجرة مثمرة';

  @override
  String get tasStatLevel => 'المرحلة';

  @override
  String tasStatLevelValue(int level) {
    return '$level/5';
  }

  @override
  String get tasStatTotal => 'إجمالي التسبيح';

  @override
  String get tasStatStreak => 'السلسلة';

  @override
  String get tasStatFlowers => 'الورد';

  @override
  String get tasStatSession => 'في الجلسة دي';

  @override
  String tasNext(int score, int next) {
    return '$score / $next للمرحلة التالية';
  }

  @override
  String get tasComplete => 'اكتملت!';

  @override
  String tasStreakDays(int days) {
    return '$days يوم ورا بعض';
  }

  @override
  String get tasTapLabel => 'سبّح';

  @override
  String get tasReset => 'تصفير';

  @override
  String get tasCycle => 'الدورة';

  @override
  String get tasLevelUp => 'مبروك! شجرتك كبرت!';

  @override
  String get tasBloom => 'وردة جديدة فتّحت!';

  @override
  String tasSeedsGranted(int seeds) {
    return '+$seeds بذور';
  }

  @override
  String tasMyTrees(int count) {
    return 'أشجاري ($count)';
  }

  @override
  String get tasNewTree => 'شجرة جديدة';

  @override
  String get tasNoTreeTitle => 'لسه مفيش شجرة';

  @override
  String get tasNoTreeMsg => 'ازرع أول شجرة وابدأ التسبيح.';

  @override
  String get tasTreeNameLabel => 'اسم الشجرة';

  @override
  String get tasRenameTitle => 'تسمية الشجرة';

  @override
  String get tasNewTreeHint => 'أضف شجرة جديدة لبستانك!';

  @override
  String get tasTreeNameExample => 'مثال: شجرة التفاح';

  @override
  String get tasCancel => 'إلغاء';

  @override
  String get tasSave => 'حفظ';

  @override
  String get tasAdd => 'إضافة';

  @override
  String get tasLeaderboard => 'لوحة المتصدرين';

  @override
  String get tasShare => 'شارك الترتيب';

  @override
  String get tasNoTreesTitle => 'لا توجد أشجار بعد';

  @override
  String get tasNoTreesMsg => 'أول ما حد من العيلة يسبّح، شجرته هتظهر هنا.';

  @override
  String tasMemberTrees(int trees, int mature) {
    return '$trees أشجار | $mature مثمرة';
  }

  @override
  String get tasUnit => 'تسبيحة';

  @override
  String get tasChallengesTitle => 'التحديات العائلية';

  @override
  String get tasChallengesTagline => 'تحدَ أفراد عائلتك في التسبيحة!';

  @override
  String get tasNewChallenge => 'تحدي جديد';

  @override
  String get tasNoChallengesTitle => 'لا توجد تحديات حالياً';

  @override
  String get tasNoChallengesAdmin => 'اضغط + وابدأ أول تحدي للعيلة.';

  @override
  String get tasNoChallengesMember => 'اطلب من المدير إنشاء تحدي جديد!';

  @override
  String get tasOngoing => 'مستمر';

  @override
  String get tasChallengeTitleLabel => 'عنوان التحدي';

  @override
  String get tasChallengeDescLabel => 'الوصف (اختياري)';

  @override
  String get tasChallengeTargetLabel => 'الهدف (عدد التسبيحات)';

  @override
  String get tasNightSky => 'ليل البستان';

  @override
  String get tasDaySky => 'نهار البستان';

  @override
  String txWorldEyebrow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count معاملة',
      few: '$count معاملات',
      two: 'معاملتين',
      one: 'معاملة واحدة',
      zero: 'لسه مفيش معاملات',
    );
    return '$_temp0';
  }

  @override
  String txWorldState(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count اتسجلوا لوحدهم النهارده',
      few: '$count اتسجلوا لوحدهم النهارده',
      two: 'اتنين اتسجلوا لوحدهم النهارده',
      one: 'واحدة اتسجلت لوحدها النهارده',
      zero: 'لسه مفيش حاجة اتسجلت لوحدها النهارده',
    );
    return '$_temp0';
  }

  @override
  String get txSourceBank => 'رسالة من البنك';

  @override
  String txSourceBankNamed(String bank) {
    return '$bank · رسالة';
  }

  @override
  String get txSourceReceipt => 'فاتورة اتصورت';

  @override
  String get txSourceVoice => 'قولتها بصوتك';

  @override
  String get txSourceStatement => 'من كشف الحساب';

  @override
  String get txSourcePharmacy => 'تعبئة الصيدلية';

  @override
  String get txSourceManual => 'كتبتها بإيدك';

  @override
  String budgetWorldUntil(int day) {
    return 'لحد يوم $day';
  }

  @override
  String budgetWorldDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'فاضل $count يوم',
      few: 'فاضل $count أيام',
      two: 'فاضل يومين',
      one: 'فاضل يوم واحد',
      zero: 'آخر يوم',
    );
    return '$_temp0';
  }

  @override
  String budgetWorldState(String amount, String perDay) {
    return 'متاح $amount · $perDay في اليوم';
  }

  @override
  String budgetWorldAvailable(String amount) {
    return 'متاح $amount';
  }

  @override
  String statementWorldStateLess(int pct) {
    return 'صرفت $pct٪ أقل من نفس الفترة الشهر اللي فات';
  }

  @override
  String statementWorldStateMore(int pct) {
    return 'صرفت $pct٪ أكتر من نفس الفترة الشهر اللي فات';
  }

  @override
  String get statementWorldStateSame => 'صرفك زي الشهر اللي فات';

  @override
  String get statementWorldStateNone => 'استورد كشفك وشوف فلوسك رايحة فين';

  @override
  String get statementWorldBreakdownTitle => 'فلوسك داخلة منين وخارجة فين';

  @override
  String get statementWorldIn => 'الدخل';

  @override
  String get statementWorldEmptyTitle => 'مفيش حركات الشهر ده لسه';

  @override
  String get statementWorldEmptyBody =>
      'استورد كشفك أو سجّل معاملة، وهتلاقي هنا الدخل والمصروف حسب الفئة.';

  @override
  String get statementPickBody =>
      'اختار كشف حسابك: PDF من تطبيق البنك، أو صورة، أو ملف CSV. زاد بيقرا الحركات ويراجعها على رصيد الكشف، ومفيش حاجة بتتسجل غير بعد ما تراجعها.';

  @override
  String get statementReading => 'بقرا الكشف… الكشف الطويل بياخد دقيقة';

  @override
  String get statementPickButton => 'اختيار الكشف';

  @override
  String get statementMapIntro =>
      'حدد أي عمود من الملف يمثل كل بيانة — الملف مختلف من بنك لبنك';

  @override
  String get statementMapDate => 'عمود التاريخ';

  @override
  String get statementMapTitle => 'عمود الوصف/العنوان';

  @override
  String get statementMapAmount => 'عمود المبلغ';

  @override
  String get statementMapCategory => 'عمود التصنيف (اختياري)';

  @override
  String get statementMapInvert =>
      'اعكس إشارة المبلغ (لو السالب هنا معناه دخل مش مصروف)';

  @override
  String get statementMapContinue => 'متابعة للمراجعة';

  @override
  String get statementMapNone => 'بدون';

  @override
  String statementMapColumnN(int n) {
    return 'عمود $n';
  }

  @override
  String statementPreviewCount(int rows, int checked) {
    return '$rows صف — $checked محدد للاستيراد';
  }

  @override
  String get statementPreviewEmptyTitle => 'ما لقيتش أي معاملة في الملف';

  @override
  String get statementPreviewEmptyBody =>
      'الملف اتقرا لكن مفيهوش صفوف أقدر أستوردها — اتأكد إنه كشف حساب وإن صيغته CSV أو PDF مقروء.';

  @override
  String get statementRowUnreadable =>
      'تعذّرت قراءة التاريخ أو المبلغ في هذا الصف';

  @override
  String get statementRowBalance =>
      'الرصيد في الكشف مش متطابق مع الصف ده — راجع المبلغ';

  @override
  String get statementCheckBalanced => 'الأرقام متطابقة مع رصيد الكشف';

  @override
  String get statementCheckMismatch =>
      'في أرقام مش متطابقة مع رصيد الكشف — الصفوف دي مش متعلّمة، راجعها';

  @override
  String get statementCheckUnknown =>
      'الكشف مفيهوش رصيد أراجع عليه — راجع كل صف قبل الاستيراد';

  @override
  String statementDropped(String text, int n) {
    return '$text. وفي $n صف ماقدرتش أقراه.';
  }

  @override
  String placesWorldEyebrow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count خروجة',
      few: '$count خروجات',
      two: 'خروجتين',
      one: 'خروجة واحدة',
      zero: 'لسه مفيش خروجات',
    );
    return '$_temp0';
  }

  @override
  String placesWorldState(int count, String alerts) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مكان',
      few: '$count أماكن',
      two: 'مكانين',
      one: 'مكان واحد',
      zero: 'مفيش أماكن',
    );
    String _temp1 = intl.Intl.selectLogic(alerts, {
      'on': 'تنبيهات الشارع شغالة',
      'other': 'تنبيهات الشارع مقفولة',
    });
    return '$_temp0 · $_temp1';
  }

  @override
  String docsEyebrowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مستند',
      few: '$count مستندات',
      two: 'مستندين',
      one: 'مستند واحد',
    );
    return '$_temp0';
  }

  @override
  String get docsStateEmpty => 'الدرج فاضي — ضيف أول مستند';

  @override
  String docsStateNearest(String name, String status) {
    return 'الأقرب: $name — $status';
  }

  @override
  String get docsPrivacy =>
      'زاد بيحفظ نوع المستند وتاريخ انتهائه بس — من غير رقم ولا صورة — ويفكّرك قبلها.';

  @override
  String get docsDueOne => 'مستند واحد محتاج تجديد قريب';

  @override
  String docsDueMany(int count) {
    return '$count مستندات محتاجة تجديد قريب';
  }

  @override
  String get docsEmptyTitle => 'مفيش مستندات متسجلة';

  @override
  String get docsEmptyMessage =>
      'ضيف الجواز أو البطاقة أو الرخصة بتاريخ انتهائها، وزاد يفكّرك قبلها بوقت كفاية للتجديد. أو قول لزاد في الشات: «جوازي بينتهي ١٥ مارس ٢٠٢٧».';

  @override
  String get docsAdd => 'إضافة مستند';

  @override
  String get docsDelete => 'حذف';

  @override
  String docsExpires(String date) {
    return 'بينتهي $date';
  }

  @override
  String get docsSaveFailedEdit =>
      'ماتحفظش — يمكن فيه مستند بنفس النوع والاسم، أو النت مقطوع.';

  @override
  String get docsSaveFailedAdd => 'ماتحفظش — اتأكد من النت.';

  @override
  String get docsDeleteFailed => 'ماتشالش — اتأكد من النت.';

  @override
  String maintEyebrowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count جهاز',
      few: '$count أجهزة',
      two: 'جهازين',
      one: 'جهاز واحد',
    );
    return '$_temp0';
  }

  @override
  String get maintStateNone => 'مفيش جهاز متسجل لسه';

  @override
  String get maintStateNoSchedule => 'سجّل دورة الصيانة وزاد يفكّرك';

  @override
  String maintStateNext(String name, String status) {
    return 'الجاي: $name — $status';
  }

  @override
  String maintStateOverdue(String name, int days) {
    return '$name متأخر $days يوم';
  }

  @override
  String maintServiceOverdue(int days) {
    return 'متأخر $days يوم';
  }

  @override
  String maintServiceIn(int days) {
    return 'الصيانة خلال $days يوم';
  }

  @override
  String get maintServiceSoon => 'صيانة قريبة';

  @override
  String get maintWarrantyEnded => 'الضمان منتهي';

  @override
  String maintWarrantyIn(int days) {
    return 'الضمان ينتهي خلال $days يوم';
  }

  @override
  String get maintStatDevices => 'الأجهزة';

  @override
  String get maintStatSoon => 'صيانة قريبة';

  @override
  String get maintStatWarranty => 'ضمان قارب';

  @override
  String maintOverdueBanner(int count) {
    return '$count جهاز متأخر عن موعد الصيانة';
  }

  @override
  String get maintEmptyTitle => 'لا توجد أجهزة مسجلة بعد';

  @override
  String get maintEmptyMessage =>
      'سجّل التكييف أو السخان أو العربية، وزاد يفكّرك بميعاد صيانتها وضمانها.';

  @override
  String get maintAdd => 'إضافة جهاز';

  @override
  String get maintServicedToday => 'تمت الصيانة اليوم';

  @override
  String get maintDelete => 'حذف';

  @override
  String get maintTechnicians => 'فنيين بثق فيهم';

  @override
  String get maintTechniciansHint => 'اتصل أو ابعت واتساب لفني اتجرّبته';

  @override
  String get maintAddFailed => 'ماتسجلش الجهاز — اتأكد من النت.';

  @override
  String get notifMarkAllRead => 'علّم الكل مقروء';

  @override
  String get notifAllRead => 'كله مقروء';

  @override
  String achWorldState(int done, int total) {
    return '$done من $total إنجاز';
  }

  @override
  String achLevel(int level) {
    return 'المستوى $level';
  }

  @override
  String achLevelPoints(int points, int next) {
    return '$points من $next نقطة';
  }

  @override
  String get achOnTrack => 'أنت على الطريق الصحيح!';

  @override
  String get achContributions => 'المساهمات';

  @override
  String get achStreak => 'التسلسل';

  @override
  String get achShelf => 'الإنجازات';

  @override
  String get achNext => 'الإنجاز التالي';

  @override
  String get achLocked => 'مقفول';

  @override
  String get achLoadFailed => 'مش قادرين نجيب الإنجازات دلوقتي';

  @override
  String get achLoadFailedHint => 'اتأكد من النت وجرّب تاني';

  @override
  String get achRetry => 'جرّب تاني';

  @override
  String get pricesEyebrow => 'لوحة الأسعار';

  @override
  String get pricesWorldNeutral => 'أسعار السوق من بلاغات الناس';

  @override
  String get pricesWorldFlat => 'الأسعار ثابتة النهارده';

  @override
  String pricesWorldUp(String name) {
    return '$name طالع';
  }

  @override
  String pricesWorldDown(String name) {
    return '$name نازل';
  }

  @override
  String pricesWorldUpDown(String up, String down) {
    return '$up طالع، $down نازل';
  }

  @override
  String get pricesMine => 'مساهماتك';

  @override
  String get pricesReportNew => 'سجّل سعر جديد';

  @override
  String get pricesCheapestTitle => 'أرخص سعر حواليك';

  @override
  String get pricesCheapestNote =>
      'من بلاغات مجتمع زاد آخر ١٤ يوم — مش أسعار رسمية';

  @override
  String get pricesCityLabel => 'المدينة أو المنطقة (اختياري)';

  @override
  String get pricesSearch => 'دوّر';

  @override
  String get pricesFetchFailed => 'مقدرناش نجيب الأسعار دلوقتي';

  @override
  String get pricesFetchFailedHint => 'اتأكد من النت وجرّب تاني';

  @override
  String get pricesRetry => 'جرّب تاني';

  @override
  String get pricesNoReportsTitle => 'لسه مفيش بلاغات هنا';

  @override
  String get pricesNoReportsHint => 'كن أول واحد يبلّغ عن سعر — جيرانك هيشكروك';

  @override
  String get pricesFirstReport => 'سجّل أول سعر';

  @override
  String pricesRowMeta(String where, int count) {
    return '$where · $count بلاغ';
  }

  @override
  String get pricesTrendsTitle => 'ترندات سوقك';

  @override
  String pricesTrendsNote(int days) {
    return 'اللي بيوت كتير في بلدك اشترته أو حطّته في قايمة التسوق آخر $days يوم — من غير أسماء ولا محلات';
  }

  @override
  String get pricesTrendsNoMarket => 'اختار بلدك الأول';

  @override
  String get pricesTrendsNoMarketHint => 'الترندات بتتحسب لكل بلد لوحده.';

  @override
  String get pricesTrendsEmpty => 'لسه مفيش ترند في سوقك';

  @override
  String pricesTrendsEmptyHint(int homes) {
    return 'الصنف بيظهر هنا لما $homes بيوت مختلفة على الأقل يشتروه أو يحطّوه في قايمتهم — عشان محدش يتعرف من مشترياته. كل فاتورة بتصوّرها بتقرّب اليوم ده.';
  }

  @override
  String get pricesTrendUp => 'بيزيد';

  @override
  String get pricesTrendDown => 'بيقل';

  @override
  String get pricesTrendFlat => 'ثابت';

  @override
  String get pricesTrendFresh => 'جديد';

  @override
  String pricesHomes(int n) {
    return '$n بيوت';
  }

  @override
  String get pricesTopTitle => 'أكثر المشاركين';

  @override
  String get pricesTopNone => 'لسه مفيش مساهمات';

  @override
  String get pricesTopNoneHint =>
      'سجّل أول سعر شفته في السوق — مساهمتك بتظهر هنا وبتساعد جيرانك يلاقوا أرخص مكان.';

  @override
  String pricesContributor(int rank) {
    return 'المساهم $rank';
  }

  @override
  String pricesContribCount(int n) {
    return '$n مساهمات';
  }

  @override
  String get profileGroupMe => 'أنا وزاد';

  @override
  String get profileGroupAccount => 'الحساب والعيلة';

  @override
  String get profileGroupMoney => 'الفلوس';

  @override
  String get profileGroupPlan => 'رفيق زاد والاشتراك';

  @override
  String get profilePlanFree => 'المجانية';

  @override
  String get profilePlanBasic => 'الأساسية';

  @override
  String get profilePlanPlus => 'المتقدمة';

  @override
  String get profilePlanUltra => 'العيلة';

  @override
  String get profileSettingsTitle => 'الإعدادات';

  @override
  String get profileSettingsSubtitle => 'السقف، الأصوات، الإعلانات والخصوصية';

  @override
  String get settingsWorldTitle => 'الإعدادات';

  @override
  String get settingsGroupMoney => 'الفلوس';

  @override
  String get settingsGroupCompanion => 'رفيق زاد';

  @override
  String get settingsGroupSounds => 'الأصوات واللغة';

  @override
  String get settingsGroupPrivacy => 'الإعلانات والخصوصية';

  @override
  String get settingsGroupAccount => 'الحساب';

  @override
  String get settingsAdsTitle => 'الإعلانات';

  @override
  String get settingsAdsBody => 'مخصّصة ليك؟ تقدر تغيّر اختيارك في أي وقت';

  @override
  String get settingsAdsUnavailable => 'مفيش اختيارات خصوصية متاحة دلوقتي';

  @override
  String get settingsTermsTitle => 'الشروط والأحكام';

  @override
  String get settingsTermsBody => 'سياسة الاستخدام والخصوصية';

  @override
  String get worldLabelHome => 'الرئيسية';

  @override
  String homeGreetDawn(String name) {
    return 'صباح الخير يا $name';
  }

  @override
  String homeGreetMorning(String name) {
    return 'أهلاً يا $name';
  }

  @override
  String homeGreetNoon(String name) {
    return 'نهارك سعيد يا $name';
  }

  @override
  String homeGreetEvening(String name) {
    return 'مساء الخير يا $name';
  }

  @override
  String homeGreetNight(String name) {
    return 'ليلة هادية يا $name';
  }

  @override
  String homeStateMoney(String amount, String currency, String days) {
    return 'متاح $amount $currency · $days';
  }

  @override
  String get homeStateIdle => 'بيتك كله قدامك';

  @override
  String get homeWorldsTitle => 'عوالمك';

  @override
  String get homeWorldsHint => 'كل جزء من بيتك في مكانه';

  @override
  String get homeTodayTitle => 'النهارده في بيتك';

  @override
  String get homeTodayEmpty => 'مفيش نواقص ولا جرعات ولا تجديدات قريبة';

  @override
  String get homeTodayEmptyHint =>
      'اليوم هادي. أي حاجة تحتاج انتباهك هتظهر هنا.';

  @override
  String get homeTodayShortTitle => 'نواقص بتتجاب';

  @override
  String homeTodayShortSub(String name, int count) {
    return '$count صنف · أولهم $name';
  }
}

/// The translations for Arabic, as used in Saudi Arabia (`ar_SA`).
class ZadL10nArSa extends ZadL10nAr {
  ZadL10nArSa() : super('ar_SA');

  @override
  String get languageEnglishPreview =>
      'الإنجليزي للحين ينترجم — شاشات كثير بتظل عربي لين يخلص.';

  @override
  String get authSignOutBody => 'بنحتاجك تدخل مرة ثانية عشان توصل لحساباتك.';

  @override
  String get commonWait => 'لحظة';

  @override
  String get authErrorInvalidCredentials => 'الإيميل أو كلمة السر مو صحيحة.';

  @override
  String get authErrorEmailTaken =>
      'الإيميل هذا مسجّل من قبل. جرّب تدخل فيه، أو غيّر كلمة السر.';

  @override
  String get authErrorInvalidEmail => 'الإيميل هذا شكله مو صحيح.';

  @override
  String get authErrorEmailNotConfirmed =>
      'للحين تحتاج تأكّد الإيميل. شوف رسائلك على الرابط اللي أرسلناه.';

  @override
  String get authErrorRateLimited =>
      'جرّبت مرات كثير في وقت قصير. انتظر شوي وحاول مرة ثانية.';

  @override
  String get authErrorSignupDisabled => 'التسجيل مقفل الحين.';

  @override
  String get authErrorUserBanned => 'الحساب هذا موقوف.';

  @override
  String get authErrorOffline => 'ما فيه اتصال بالنت — الدخول يحتاج نت.';

  @override
  String get authErrorServer => 'الخدمة ما ترد الحين. حاول مرة ثانية بعد شوي.';

  @override
  String get authErrorUnknown => 'صار خطأ ما توقعناه. حاول مرة ثانية.';

  @override
  String authSignOutPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'فيه $count عمليات للحين ما انرسلت للسيرفر. لو طلعت الحين ما بتنرسل. الأفضل تنتظر لين يرجع النت.',
      one:
          'فيه $count عملية للحين ما انرسلت للسيرفر. لو طلعت الحين ما بتنرسل. الأفضل تنتظر لين يرجع النت.',
    );
    return '$_temp0';
  }

  @override
  String get paywallBasicPerkNoAds => 'بدون إعلانات أبد';

  @override
  String get paywallNoPlayTitle => 'Google Play مو متاح';

  @override
  String get paywallNoPlayBody =>
      'الاشتراك يتم من Google Play. لو زاد مثبّت من ملف مو من المتجر، نزّله من Google Play وبعدها اشترك من هنا.';

  @override
  String get paywallNotOnPlayTitle => 'الباقة للحين مو على المتجر';

  @override
  String get paywallNotOnPlayBody =>
      'الباقة هذي للحين ما تفعّلت على Google Play. جرّب مرة ثانية قريب.';

  @override
  String paywallStatePlan(String plan) {
    return 'خطتك الحين: $plan';
  }

  @override
  String get paywallStateInvite => 'اختر الباقة اللي تناسب بيتك';

  @override
  String get navMyFamily => 'عائلتي';

  @override
  String get pulseOneSaved => 'شي واحد محفوظ';

  @override
  String get pulseTwoSaved => 'شيئين محفوظين';

  @override
  String pulseFewSaved(int n) {
    return '$n أشياء محفوظة';
  }

  @override
  String pulseManySaved(int n) {
    return '$n شي محفوظ';
  }

  @override
  String pulseOffline(String what) {
    return 'ما فيه نت — $what وبتنرسل أول ما يرجع النت';
  }

  @override
  String get pulseThinking => 'زاد يفكّر…';

  @override
  String get pulseSyncing => 'نزامن…';

  @override
  String get authPreparingAccount => 'نجهّز حسابك…';

  @override
  String get shareTooLarge =>
      'الملف أكبر من إن زاد يقراه مرة وحدة — أرسله أصغر';

  @override
  String get shareUnsupported => 'زاد يقرا الكلام والصور وملفات PDF وCSV بس';

  @override
  String get shareUnreadable =>
      'ما قدرت أفتح اللي انشارك — جرّب ترسله مرة ثانية';

  @override
  String get shareWhatImage => 'وش هذي الصورة؟';

  @override
  String get shareWhatImageHint =>
      'زاد بيقراها ويوريك وش لقى قبل ما يسجل أي شي';

  @override
  String get shareReceipt => 'فاتورة شراء';

  @override
  String get drawerGroupHome => 'البيت والعائلة';

  @override
  String get placesOrbitCaption =>
      'الأقرب للبيت هو اللي تروح له أكثر، مو المسافة الحقيقية.';

  @override
  String get drawerGroupMore => 'أكثر';

  @override
  String get homeBankListening => 'أتابع رسائل البنك وأحدّث رصيدك تلقائياً';

  @override
  String get homeBankStopped => 'قراءة رسائل البنك وقفت — اضغط للإصلاح';

  @override
  String get homeBirthday => 'كل عام وأنت بخير! 🎂';

  @override
  String homeBirthdayName(String who) {
    return 'كل عام وأنت بخير يا $who! 🎂';
  }

  @override
  String get homeBirthdayWish => 'زاد يتمنى لك سنة حلوة مليانة خير وراحة بال.';

  @override
  String get homeCloseDay => 'سكّر يومك';

  @override
  String get homeCloseDayHint => 'عشر ثواني: صرفت شي كاش اليوم؟ ورفيقك يتعشى';

  @override
  String get coverageBlind => 'للحين ما أشوف أي مصروف هالدورة';

  @override
  String get coverageBlindHint => 'سكّر يومك أو اربط البنك عشان أشوف';

  @override
  String get coverageFullHint => 'كمّل كذا، الأرقام اللي فوق حقيقية';

  @override
  String get coveragePartialHint => 'سكّر يومك أو اربط البنك عشان أشوف أكثر';

  @override
  String get briefTitle => 'موجز زاد اليوم';

  @override
  String get briefAllGood => 'كل شي تمام — ما فيه شي مستعجل اليوم.';

  @override
  String get briefAskZad => 'اسأل زاد عن أي شي';

  @override
  String get glanceStockEmpty => 'المخزون للحين فاضي';

  @override
  String get glanceStockEmptyHint =>
      'صوّر فاتورة السوبرماركت أو أضف أصنافك، وزاد يقولك وش قرّب يخلص قبل ما تحتاجه';

  @override
  String get glancePharmacyEmptyLabel => 'ما فيه أدوية مسجّلة';

  @override
  String glanceActiveMedicines(int count) {
    return '$count دواء نشط • للحين نجمع بيانات الالتزام';
  }

  @override
  String get glancePharmacyEmptyHint =>
      'صوّر شريط الدواء أو أضفه يدوي، وزاد بيذكّرك بمواعيد الجرعات وينبّهك قبل ما يخلص';

  @override
  String get glanceTookDose => 'أخذت الجرعة';

  @override
  String get glanceSubsNone => 'ما فيه اشتراكات مسجّلة';

  @override
  String get glanceSubsEmpty => 'ما فيه اشتراكات للحين';

  @override
  String get glanceSubsEmptyHint =>
      'أضف اشتراكاتك الشهرية عشان زاد يحسبها في المتاح ويذكّرك بمواعيد التجديد';

  @override
  String groceryWhatToAdd(String shop, String amount) {
    return 'اشتريت من $shop بـ $amount — وش أضيف للمخزون؟';
  }

  @override
  String get groceryOtherItem => 'اسم منتج ثاني…';

  @override
  String get activationGoalHint => 'زاد بيتابعه معك كل أسبوع';

  @override
  String get activationAllSet =>
      'كل شي جاهز! 🎉 جرّب تقول لزاد \"صرفت ٥٠ بقالة\" بالصوت أو من بوت تليجرام — بيطلب منك تأكيد ويسجلها.';

  @override
  String get amazonOnList => 'في قائمة التسوق';

  @override
  String get amazonUpdatedToday => 'تحدّث اليوم';

  @override
  String get amazonDisclosure =>
      'رابط شراء بالعمولة — زاد ياخذ عمولة بدون أي زيادة عليك';

  @override
  String get amazonNoNeeds => 'أضف اللي ناقصك، أو شوف عروض اليوم';

  @override
  String amazonManyNeeds(int count) {
    return 'ناقصك $count أغراض — اطلب كل واحد بضغطة';
  }

  @override
  String get homeOffline => 'ما فيه اتصال بالإنترنت';

  @override
  String get homeOfflineHint =>
      'بياناتك تنحفظ على الجوال وبتتزامن أول ما يرجع النت';

  @override
  String get homeServerDown => 'ما قدرت أوصل للسيرفر';

  @override
  String get homePreparing => 'نجهّز ميزانيتك';

  @override
  String get homeServerDownHint =>
      'بنحاول مرة ثانية من نفسنا. تقدر تسحب الشاشة لتحت الحين.';

  @override
  String get homePreparingHint => 'ثانية وحدة وبتلقى كل شي هنا.';

  @override
  String get checkInNotYet => 'للحين لا';

  @override
  String get metricsToMonthEnd => 'لين آخر الشهر';

  @override
  String get metricsToPayday => 'لين الراتب';

  @override
  String get commonNotNow => 'مو الحين';

  @override
  String get quietRestoreFailed => 'ما قدرت أرجّع التنبيهات. جرّب مرة ثانية.';

  @override
  String recipeStagnant(String names) {
    return 'عندك $names من فترة وما استخدمتها 🤔';
  }

  @override
  String recipeRunningOut(String names) {
    return 'عندك $names بيخلص قريب 👀';
  }

  @override
  String get recipeRunningOutHint => 'وصفات مقترحة فيه قبل ما يروح عليك';

  @override
  String get recipeOpenChat => 'اضغط للمزيد في محادثة زاد ←';

  @override
  String get profileSaveFailed => 'ما قدرنا نحفظ الملف — جرّب مرة ثانية';

  @override
  String get whoBody =>
      'اسمك، وتحب أكلمك بصيغة المذكّر ولا المؤنّث، وشغلك وموعد راتبك — عشان أكلمك صح وأتذكرك.';

  @override
  String get whoGo => 'يلّا نتعرّف';

  @override
  String get chatVoiceUnavailable => 'الصوت مو متاح الحين — الرد مكتوب قدامك';

  @override
  String get chatNewBody =>
      'الكلام اللي فات بينمسح من هالجوال. واللي تعلّمه زاد عنك بيظل مثل ما هو.';

  @override
  String get chatWelcome =>
      'هلا والله! أنا زاد، مساعدك العائلي الذكي. كيف أقدر أساعدك اليوم؟\nاسألني عن الوصفات، أو راجع ثلاجتك، أو أضف النواقص لقائمة التسوق!';

  @override
  String get chatBusy =>
      'الذكاء الاصطناعي مشغول شوي الحين جرّب مرة ثانية بعد لحظات.';

  @override
  String get chatResend => 'ما وصلت — أرسلها مرة ثانية';

  @override
  String get chatReportTitle => 'وش المشكلة في هذا الرد؟';

  @override
  String get chatReportHarmful => 'نصيحة ممكن تضر';

  @override
  String get chatReportOther => 'شي ثاني';

  @override
  String get chatReportSent => 'وصل بلاغك، شكراً. بنراجع هذا الرد.';

  @override
  String get chatReportFailed => 'ما وصل البلاغ — حاول مرة ثانية';

  @override
  String get chatWorldEyebrow => 'اسألني أي شيء';

  @override
  String get chatStateThinking => 'يفكّر…';

  @override
  String get chatStateListening => 'يسمعك…';

  @override
  String get chatStateSpeaking => 'يتكلم…';

  @override
  String get chatStateEmpty => 'أنا أسمعك';

  @override
  String chatStateCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count رسالة',
      few: '$count رسائل',
      two: 'رسالتان',
      one: 'رسالة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get chatThinking => 'أفكّر…';

  @override
  String get refillBack => 'رصيدك رجع — أرسل رسالتك مرة ثانية';

  @override
  String refillDays(int days) {
    return 'رصيدك يتجدد بعد $days أيام';
  }

  @override
  String refillIn(String span) {
    return 'رصيدك يتجدد بعد $span';
  }

  @override
  String get chatSubscribeFeature => 'اشترك وفعّل هالميزة';

  @override
  String get chatSubscribeMore => 'اشترك وخذ محاولات أكثر';

  @override
  String get chatNotDone => 'للحين ما تنفّذ.';

  @override
  String get chatDoIt => 'سوّها';

  @override
  String get chatTranscribing => 'أحوّل الكلام…';

  @override
  String get chatSend => 'أرسل';

  @override
  String get voiceTooShort =>
      'ضغطت الزر بسرعة — اضغط وابدأ تكلّم، وبعدين وقّف.';

  @override
  String get voiceDenied =>
      'أحتاج إذن المايك. افتح إعدادات التطبيق واسمح بالتسجيل.';

  @override
  String get voiceFailed => 'ما قدرت أحوّل الكلام. جرّب مرة ثانية.';

  @override
  String get subscribePulseTitle => 'اشترك وزاد يكون معك على طول';

  @override
  String get subscribePulseClose => 'سكّر';

  @override
  String get voiceOutToday =>
      'خلصت أسئلتك الصوتية (٣ كل ساعتين) — ترجع من نفسها، أو شاهد إعلان وخذ سؤال زيادة. اكتب سؤالك، أو اشترك وكلّم زاد بدون حد.';

  @override
  String chatEmergency(String trade) {
    return 'طوارئ في البيت؟ الـ$trade حقّك قدامك بضغطة.';
  }

  @override
  String get chatTechnicians => 'الفنيين حقّي';

  @override
  String get intChatSubtitle => 'اسأل عن مصاريفك، مخزونك، أو أي شي';

  @override
  String get intChatClearBody =>
      'بنمسح كل رسائل المحادثة مع عقل زاد. البيانات المالية والمخزون ما بتتأثر.';

  @override
  String intChatMemoryUsed(int count) {
    return 'مبني على $count شي زاد يتذكره عنك';
  }

  @override
  String get meshThinking => 'الشبكة العصبية تشتغل...';

  @override
  String get voiceSheetBrainDown => 'ما قدرت أوصل لعقل زاد الحين';

  @override
  String get financesNoCategories =>
      'للحين ما حددت ميزانية لأي فئة. اضغط \"تحديد فئة\" عشان زاد يتابع لك كل فئة لحالها.';

  @override
  String get financesNoBudget => 'للحين ما حددت ميزانيتك';

  @override
  String get financesInsightEmpty =>
      'ما فيه بيانات كافية لتحليل هالفئة حالياً.';

  @override
  String get gateTitle => 'قبل ما نبدأ، كم معك هالشهر؟';

  @override
  String get gateBody =>
      'زاد ما يخترع أرقام. من هالرقم نحسب «المتاح» و«المتبقي» كل يوم، وتقدر تعدّله في أي وقت.';

  @override
  String get gateCeiling => 'رصيدك لهالشهر';

  @override
  String get gateStart => 'يلّا نبدأ';

  @override
  String eventToday(String title) {
    return 'زوّدناه عشان «$title» اليوم';
  }

  @override
  String get txForPerson => 'لمين؟ (خلّها فاضية إذا لك أو للبيت كله)';

  @override
  String get habitTrialStarted =>
      'يلا ✅ التجربة بدأت اليوم لمدة أسبوعين، وبعدها أقولك النتيجة بالأرقام.';

  @override
  String get habitTrialDeclined => 'تمام، ما راح أقترحها مرة ثانية هالفترة.';

  @override
  String get habitTrialKept => 'تمام ✅ ثبّتناها — بتذكرها وأبني عليها.';

  @override
  String get habitTrialAlready => 'تمام، ردك انسجّل من قبل.';

  @override
  String get habitTrialGone => 'التجربة هذي ما عادت موجودة.';

  @override
  String get habitTrialFailed =>
      'المعذرة، ما قدرت أسجّل ردك الحين — جرّب مرة ثانية بعد شوي.';

  @override
  String get learningWrong => '❌ مو صح';

  @override
  String get learningKept => 'تمام ✅ بتذكرها.';

  @override
  String get learningCorrected =>
      'تمام، مشكور إنك صحّحت لي — ما راح أقولها مرة ثانية.';

  @override
  String get learningAlready => 'تمام، ردك انسجّل من قبل.';

  @override
  String get learningGone => 'الملاحظة هذي ما عادت موجودة.';

  @override
  String get learningFailed =>
      'المعذرة، ما قدرت أسجّل ردك الحين — جرّب مرة ثانية بعد شوي.';

  @override
  String get txNoneHere => 'ما فيه معاملات هنا';

  @override
  String get txTryFilter => 'جرّب فلتر ثاني.';

  @override
  String get txPendingOne => 'محفوظة للحين';

  @override
  String txPendingCount(int count) {
    return '$count محفوظة للحين';
  }

  @override
  String get txLoadFailed => 'ما قدرت أجيب المعاملات';

  @override
  String get txNonePeriod => 'ما فيه معاملات في هالفترة';

  @override
  String get txPullToRetry => 'اسحب الشاشة لتحت عشان نحاول مرة ثانية.';

  @override
  String get txNoneHint =>
      'أول ما تسجّل مصروف — أو توصلك رسالة من البنك — بتلقاها هنا.';

  @override
  String get subsBnpl => 'اشترِ الحين وادفع بعدين';

  @override
  String get subsWorldNone => 'ما فيه اشتراكات للحين';

  @override
  String subsWorldTotal(String amount) {
    return '$amount في الشهر';
  }

  @override
  String subsWorldNextToday(String amount, String title) {
    return '$amount في الشهر · $title يتجدد اليوم';
  }

  @override
  String subsWorldNext(String amount, String title, int days) {
    return '$amount في الشهر · $title بعد $days يوم';
  }

  @override
  String get subsEmptyHint => 'اضغط «إضافة» وزاد يحسب لك التجديد الجاي.';

  @override
  String get oblNoneHint => 'الأقساط والفواتير الثابتة بتطلع هنا أول ما تنسجل';

  @override
  String dealCached(String when) {
    return 'البحث مشغول الحين — هذي آخر عروض لقيناها$when';
  }

  @override
  String get dealFailed => 'تعذّر البحث الحين — جرّب تحدّث مرة ثانية بعد شوي';

  @override
  String get dealFailedHint =>
      'خدمة البحث مشغولة الحين. اضغط تحديث مرة ثانية بعد شوي — ولو تكررت شيّك على النت.';

  @override
  String get goalTitle => 'وش أهم هدف لبيتك الحين؟';

  @override
  String get goalBody =>
      'اختر واحد — زاد بيتابعه معك كل أسبوع لمدة ٣ شهور، وتقدر تلغيه في أي وقت.';

  @override
  String get heldNone =>
      'هالأسبوع ما سكتّ عن أي شي — كل اللي يستاهل ينقال انقال.';

  @override
  String get heldFailed => 'ما أقدر أقرا اللي سكتّ عنه الحين.';

  @override
  String get heldAskHint =>
      'تقدر تسألني «وش اللي ما قلته لي؟» في الشات وأقولك بالتفصيل.';

  @override
  String get heldActionWaiting => 'للحين أنتظر';

  @override
  String get heldReasonMuted => 'أنت قلت لي أوقف هالنوع فترة';

  @override
  String get heldReasonLearnedQuiet =>
      'لاحظت إنك غالباً ما تتعامل مع هالنوع، فقللت منه';

  @override
  String get heldReasonPacing => 'كان واصلك شي قبل شوي';

  @override
  String get heldReasonDailyCap => 'وصلت لعدد رسائل اليوم';

  @override
  String get heldKindSalary => '«هذا الراتب؟»';

  @override
  String get heldKindShortage => 'أشياء بتخلص قريب';

  @override
  String get diagMenuSubtitle => 'إشعارات البنك ورسائل زاد — واقفة وين بالضبط';

  @override
  String get diagBankNote =>
      'آخر ١٤ يوم: كل إشعار أرسله الجوال، ووش سوّى فيه زاد وليش.';

  @override
  String get diagBankEmptyTitle => 'ما وصل السيرفر أي إشعار';

  @override
  String get diagBankNothing =>
      'الجوال شغّال بس ما وصل السيرفر أي إشعار بنك. لو دفعت بالبطاقة، فالبنك يرسل الرسالة من تطبيق مو متابَع — أرسل لنا اسمه.';

  @override
  String get diagUnknown => 'ما أدري';

  @override
  String get diagNotLinked => 'مو مربوط';

  @override
  String get diagPushOff => 'الجوال مو مسجّل يستقبل إشعارات زاد';

  @override
  String get diagProNoChannel =>
      'زاد ما لقى طريق يوصلك: لا تليجرام مربوط ولا الجوال مسجّل للإشعارات. اربط تليجرام من الإعدادات، أو افتح التطبيق واسمح بالإشعارات.';

  @override
  String get diagProNothing =>
      'السيرفر ما أرسل شي آخر ١٤ يوم. هذا مو طبيعي — أرسل لنا لقطة الشاشة هذي.';

  @override
  String get diagIngestPromo => 'العقل شافها إعلان أو عرض، مو فلوس تحركت';

  @override
  String get diagIngestUnavailable => 'العقل ما رد وقتها والمصدر مو معروف';

  @override
  String get diagIngestFailedTxn => 'عملية فشلت أو للحين معلّقة';

  @override
  String get diagIngestServerError => 'خطأ في السيرفر — بنجربها مرة ثانية';

  @override
  String get diagMomentNoChannel =>
      'ما فيه طريق يوصلك: لا تليجرام ولا إشعارات التطبيق';

  @override
  String get diagMomentSkipped => 'تأجلت أو انشالت (هدوء أو حد اليوم)';

  @override
  String adThirdOpens(String attempts) {
    return 'هالإعلان يكمّل الثلاثة ويفتح $attempts';
  }

  @override
  String get appointmentGuardAsk => 'تسجّله كذا ولا تغيّر الوقت؟';

  @override
  String get scanPantryWithMedicines =>
      'الموجود بتزيد كميته، واللي في قائمة المشتريات بينشال منها، والأدوية بتروح للصيدلية.';

  @override
  String get dealsEmptyTitle => 'ما فيه عروض للحين';

  @override
  String get dealsEmptyBody =>
      'زاد يدوّر كل أسبوع في صفحات المحلات وتطبيقات التوصيل وفواتير البيوت. أول ما يلقى شي بيطلع هنا.';

  @override
  String dealsUntil(String date) {
    return 'لين $date';
  }

  @override
  String get recipesOnDeal => 'عليه عرض الحين';

  @override
  String get recipesTrendingGroup => 'ترند الحين';

  @override
  String get chefStateEmpty => 'المخزن فاضي — أضف أكلك وأنا أقترح';

  @override
  String get chefStateReady => 'جاهزة أقترح عليك أكلة من مخزنك';

  @override
  String get chefStateThinking => 'أفكر في أكلة من مخزنك…';

  @override
  String get chefError => 'ما قدرت أوصل لشيف زاد. جرّب مرة ثانية بعد شوي.';

  @override
  String get chefStale => 'مخزنك تغيّر من آخر اقتراحات — اطلب جديدة إذا تبغى.';

  @override
  String get chefReadyBody =>
      'اضغط «وصفات من مخزني» وتقول لك وش تطبخ من اللي عندك، واللي ناقصه شي بسيط.';

  @override
  String get chefEmptyBody =>
      'أضف اللي عندك في المخزن، وشيف زاد تقترح لك أكلات منه.';

  @override
  String get chefAsking => 'شيف زاد تفكّر…';

  @override
  String get chefGroupMore => 'وجبات ثانية';

  @override
  String get chefStepByStep => 'الوصفة كاملة خطوة خطوة';

  @override
  String chefAddMissing(int count) {
    return 'أضف الناقص لقائمة التسوق ($count)';
  }

  @override
  String get chefAddedOne => 'أضفت صنف لقائمة التسوق.';

  @override
  String chefAddedMany(int count) {
    return 'أضفت $count أصناف لقائمة التسوق.';
  }

  @override
  String get chefNothingToAdd => 'الناقص كله في قائمة التسوق أو المخزن.';

  @override
  String get chefRatePrompt => 'عجبتك؟ شيف زاد تتذكّر.';

  @override
  String get chefDislike => 'مو على ذوقي';

  @override
  String get chefDetailLoading => 'شيف زاد يجهّز لك الوصفة…';

  @override
  String get chefDetailEmpty => 'شيف زاد ما رجّع الوصفة — جرّب مرة ثانية';

  @override
  String get chefDetailSlow => 'شيف زاد تأخر في الرد — جرّب مرة ثانية';

  @override
  String get chefDetailFailed => 'عذراً، صار خطأ أثناء تحميل الوصفة';

  @override
  String get chefHomeAllDepleted =>
      'مخزونك كله خلص — نزّل النواقص في التسوق وأنا أقترح لك أكل.';

  @override
  String get chefHomePantryEmpty =>
      'أضف أصناف لمخزونك عشان شيف زاد يقترح لك طبق اليوم.';

  @override
  String get chefHomeAddMissing => 'أضفهم لقائمة التسوق';

  @override
  String get patternLearningTitle => 'للحين أتعلّم';

  @override
  String get patternReadFailed =>
      'ما قدرت أقرا نمطك الحين. اسحب لتحت وجرّب مرة ثانية.';

  @override
  String get patternWhen => 'متى تشتري';

  @override
  String get patternWhenUnknown =>
      'أحتاج ٤ مشاوير شراء على الأقل عشان أعرف متى تشتري';

  @override
  String get patternItemsHint => 'اضغط على صنف عشان تقول لزاد كل قد إيش تشتريه';

  @override
  String get patternSourceCustomer => 'أنت اللي حددتها';

  @override
  String get patternEditNotInPantry => 'الصنف هذا مو في مخزونك الحين';

  @override
  String patternEditSaved(String item) {
    return 'انحفظ — زاد بيحسب $item على كذا';
  }

  @override
  String get homeBankStalledHint =>
      'إذا كانت مفعّلة: طفّها وشغّلها مرة ثانية من الصفحة اللي بتفتح.';

  @override
  String get homeLocationOffBanner =>
      '📍 موقعك مو مفعّل.. فعّل الموقع عشان زاد يربط عروض السوبرماركت والمحلات القريبة منك ويسوّي شغله صح';

  @override
  String get homeLocationLater => 'مو الحين';

  @override
  String get channelCardTitle => 'ما فيه طريقة أوصلك فيها';

  @override
  String get channelCardBody =>
      'الإشعارات مقفلة وتليجرام مو مربوط، فمواعيد الدوا والفواتير وتنبيه الميزانية ما بتوصلك. وحدة منهم تكفي.';

  @override
  String briefWhyMissed(String count) {
    return 'جرعات اليوم اللي فات وقتها وما انسجلت: $count.';
  }

  @override
  String get briefWhyOverspent =>
      'المتاح لهالدورة تحت الصفر: رصيد أول الدورة ناقص اللي انصرف والالتزامات الثابتة.';

  @override
  String briefWhyRunningOutApprox(String name, String left, String perDay) {
    return '$name: باقي $left، واستهلاكك للحين ينقاس — تقريباً $perDay في اليوم، فهذا تقدير.';
  }

  @override
  String briefMedicineLow(String name, String days) {
    return '$name بيخلص بعد $days يوم';
  }

  @override
  String get briefBudgetDangerDetail => 'شوف فلوسي — للحين فيه وقت تلحق';

  @override
  String briefWhyBudgetDanger(String available, String days, String daily) {
    return 'المتاح $available على $days يوم = $daily في اليوم، ومعدل صرفك لين الحين يقول إنه ما بيكفي.';
  }

  @override
  String accountRestoreBody(int days) {
    return 'طلبت حذف حسابك، وبينحذف هو وكل بياناته نهائياً بعد $days يوم. تبغى ترجّعه؟';
  }

  @override
  String get accountRestoreFailed =>
      'تعذّر استرجاع الحساب الحين. افتح التطبيق مرة ثانية وجرّب.';

  @override
  String get settingsFoodPatternBody =>
      'مرة في الشهر بالكثير، زاد يوصف أكل البيت من المشتريات المسجلة ويقترح إضافات. وصف مشتريات مو نصيحة طبية.';

  @override
  String get commuteConsentBody =>
      'زاد بيحسب متى تطلع من البيت وترجع، من طلعتك ورجعتك للبيت. عشان يضبط تنبيهاتك على يومك ويكلمك في الوقت المناسب.\n\nينحسب على جوالك، وللسيرفر يروح ملخص المواعيد والأيام بس، بدون أي إحداثيات أو أماكن شغل أو خط سير. ما أحد من العائلة يشوفه. ولو قفلت المفتاح، ينمسح من الجوال والسيرفر.';

  @override
  String get commuteConsentDecline => 'لا، مو الحين';

  @override
  String get settingsPetCallsBody =>
      'زادو يرسل لك لما يجوع أو يعطش، على تليجرام والإشعارات. قفلها ما يوقف تحية الصبح ولا العروض.';

  @override
  String get homeWidgetSubsEmpty => 'أضف اشتراك';

  @override
  String get homeWidgetSubsToday => 'اليوم';

  @override
  String get homeWidgetPantryEmpty => 'أضف أصناف';

  @override
  String get homeWidgetPharmacyNone => 'ما فيه جرعات';

  @override
  String homeWidgetPharmacyActive(Object count) {
    return '$count دواء';
  }

  @override
  String get homeWidgetPharmacyEmpty => 'أضف دواء';

  @override
  String homeWidgetShortagesCount(int count) {
    return '$count تنجاب';
  }

  @override
  String get homeWidgetShortagesEmpty => 'ما فيه نواقص';

  @override
  String get placesOutingsWaiting =>
      'شغّال. أول ما تطلع وترجع البيت، طلعتك بتظهر هنا.';

  @override
  String get chefAsk => 'اسأل الشيف عن هالوصفة';

  @override
  String get tourDone => 'يلّا نبدأ';

  @override
  String get tourWelcomeBody => 'في نص دقيقة بنوريك وين كل شي.';

  @override
  String get tourHomeBody => 'فلوسك المتاحة، وأهم شي لازم يتسوّى اليوم.';

  @override
  String get tourMicBody =>
      'قل «سجّل ٥٠ ريال قهوة» أو اسأل أي سؤال، وزاد يرد عليك.';

  @override
  String get tourCameraBody =>
      'صوّر الفاتورة، وزاد يسجلها في مصاريفك ويضيف الأغراض للمخزون.';

  @override
  String get tourMoreBody => 'العائلة وعقل زاد وحسابك وكل المزايا.';

  @override
  String get shoppingBasketEmpty => 'السلة فاضية — أضف اللي ناقصك';

  @override
  String adLadderAfter(String messages) {
    return 'كل إعلان بعدها = $messages';
  }

  @override
  String get tickerError =>
      'ما قدرنا نجيب الأسعار الحية الحين — جرّب مرة ثانية';

  @override
  String get tickerEmpty => 'للحين ما فيه أسعار حية لبلدك — اضغط للتحديث';

  @override
  String get householdFamily => 'العائلة';

  @override
  String get householdPantry => 'المخزون';

  @override
  String get householdShopping => 'المقاضي';

  @override
  String get notifEmptyBody => 'بنعلمك أول ما يصير شي يستاهل انتباهك';

  @override
  String get notifNotImportant => 'مو مهم';

  @override
  String notifBellUnread(int count) {
    return 'التنبيهات — $count مو مقروءة';
  }

  @override
  String get shopNoReach => 'ما قدرت أوصل لزاد الحين. جرّب مرة ثانية.';

  @override
  String get shopAddHint => 'وش تحتاج تشتري؟';

  @override
  String get shopAddTooltip => 'أضف';

  @override
  String get shopFilterEmptyBody => 'جرّب أولوية ثانية.';

  @override
  String get shopBought => 'تم الشراء';

  @override
  String shopStockEnough(String qty) {
    return 'في البيت $qty — مو ناقص';
  }

  @override
  String shopRunsOutIn(int days) {
    return 'يخلص بعد $days أيام';
  }

  @override
  String shopBoughtItem(String name) {
    return 'اشتريت $name';
  }

  @override
  String shopRemoveGroupBody(int count) {
    return 'بنشيل $count سطور مع بعض.';
  }

  @override
  String get shopHideKinds => 'أخفِ الأنواع';

  @override
  String get shopShowKinds => 'ورني الأنواع';

  @override
  String get pantryToShopping => 'نزّلها في المقاضي';

  @override
  String get pantryIncreaseOne => 'زِد واحدة';

  @override
  String get pantryOccasional => 'أشتريها على فترات';

  @override
  String get pantryOccasionalBody =>
      'ما راح تنحسب ناقصة إذا خلصت، وما راح أذكّرك فيها';

  @override
  String get pantryExpiryPick => 'اختر التاريخ';

  @override
  String get pantryExpiryEstimateNote =>
      'إذا تركته كذا بحفظ التاريخ التقديري، غيّره إذا تعرف التاريخ الصحيح';

  @override
  String get notifNoneNew => 'ما فيه تنبيهات جديدة';

  @override
  String get pantryStarterTitle => 'أضف أساسيات بيتك بلمسة';

  @override
  String get pantryStarterBody =>
      'حدد اللي عندك الحين، وزاد يتابعه ويقولك قبل لا يخلص.';

  @override
  String pantryStarterAdd(int count) {
    return 'أضف $count';
  }

  @override
  String get pantryStarterReceipt => 'أو صوّر فاتورة المشتريات';

  @override
  String get introTitle => 'عرّفني عليك';

  @override
  String get introLead =>
      'خمسة أسئلة وسؤال اختياري، عشان أكلمك صح وأنتبه للي في رعايتك.';

  @override
  String get introNameQuestion => 'وش أناديك؟';

  @override
  String get introNameHint => 'اسمك أو اللقب اللي تحبه';

  @override
  String get introGenderQuestion => 'أكلمك بأي صيغة؟';

  @override
  String get introGenderMale => 'رجّال';

  @override
  String get introGenderFemale => 'امرأة';

  @override
  String get introRoleQuestion => 'وش دورك في البيت؟';

  @override
  String get introRoleSingle => 'ساكن لحالي';

  @override
  String get introRoleOther => 'غير كذا';

  @override
  String get introCaresHint => 'اختر كل اللي ينطبق.';

  @override
  String get introCaresChildren => 'عيالي';

  @override
  String get introCaresParents => 'أبوي أو أمي';

  @override
  String get introCaresSiblings => 'إخواني';

  @override
  String get introCaresNobody => 'ما أحد — مسؤول عن نفسي بس';

  @override
  String get introHouseholdQuestion => 'كم شخص ساكن في البيت؟';

  @override
  String get introHouseholdHint => 'معك أنت. عشان أحسب استهلاك البيت صح.';

  @override
  String get introHouseholdMany => '7 أو أكثر';

  @override
  String get introPayDayQuestion => 'متى ينزل راتبك في الشهر؟';

  @override
  String get introPayDayHint => 'اختياري — عشان أحسب شهرك من يوم الراتب.';

  @override
  String get introPayDayNone => 'مو ثابت / ما أبي أقول';

  @override
  String get introSave => 'يلّا نبدأ';

  @override
  String get introSaveFailed => 'ما قدرت أحفظ — تأكد من النت وجرّب مرة ثانية.';

  @override
  String get firstStepsLead =>
      'ثلاث خطوات في دقيقتين، وزاد يبدأ يشتغل معك من اليوم.';

  @override
  String get firstStepsSpendBody =>
      'أي شي صرفته اليوم — قهوة، مواصلات، خبز. من هنا زاد يبدأ يفهم شهرك.';

  @override
  String get firstStepsSpendDone => 'انسجل ✓';

  @override
  String get firstStepsAlertsBody =>
      'عشان أقولك إذا الميزانية قربت تخلص، وتوصلك مواعيد الدواء والفواتير في وقتها.';

  @override
  String get firstStepsAlertsDone => 'مفعّلة ✓';

  @override
  String get firstStepsTelegramBody =>
      'بدونه التذكيرات وسؤال «اقفل يومك» ما راح توصلك وأنت برّا التطبيق.';

  @override
  String get firstStepsGo => 'يلّا على زاد';

  @override
  String get petLinesHungry =>
      'بطني تقرقر… تأكّلني؟ 🍎\nجوعان مرة 🥺 شي صغير بس\nشامّ ريحة أكل؟ لا هذا أنا الجوعان 😅';

  @override
  String get petLinesThirsty =>
      'عطشان… شوي موية؟ 💧\nريقي ناشف 🥵 اسقني\nكاسة موية وحدة وأصير تمام 💧';

  @override
  String get petLinesSleepy =>
      'نعسان… 😴 تصبح على خير\nهاااه 🥱 نكمّل بكرة؟\nعيوني تسكّر لحالها… 💤';

  @override
  String petLinesSad(String name) {
    return 'اشتقت لك… ونسيت أكلي وموياتي 🥺\n$name زعلان شوي… تعال نقعد سوا 💔';
  }

  @override
  String get petLinesHappy =>
      'أنا مبسوط معك 💚\nشكراً إنك ذاكرني 🥰\nأنت أحلى صاحب 🤗';

  @override
  String get petLinesIdleLogged =>
      'وش أخبار يومك؟ ✨\nأنا هنا لو احتجتني 💚\nسجّلت اليوم — كفو عليك 👏';

  @override
  String get petLinesIdleNotLogged =>
      'سجّلت مصاريفك اليوم؟ 📝\nمصروف واحد بس وأفرح فيك 🌱';

  @override
  String get petLinesFed => 'يمّ يمّ! 😋\nتسلم يدك 🍎\nأحلى أكلة 🤤';

  @override
  String get petLinesFull => 'شبعان خلاص 🤭\nما أقدر آكل زيادة 😅';

  @override
  String get petLinesWatered => 'آآه انتعشت! 💧\nكذا أحسن بكثير 😌';

  @override
  String get petLinesNotThirsty => 'ما أبي موية الحين 🙈\nشربت كفاية 😄';

  @override
  String get petLinesPetted => 'هيهي تدغدغني 🤭\nبعد! بعد! 🥰\nأحبك 💚';

  @override
  String get cookDone => 'طبختها';

  @override
  String get cookSheetTitle => 'أخصم اللي استخدمته من البيت';

  @override
  String get cookSheetHint =>
      'هذي الكميات اللي أتوقعها — عدّلها إذا استخدمت أكثر أو أقل.';

  @override
  String cookConfirm(int count) {
    return 'أخصم $count';
  }

  @override
  String get cookNothing => 'ما لقيت مكونات هالوصفة في بيتك.';

  @override
  String cookDoneSnack(int count) {
    return 'خصمت $count من البيت ✅';
  }

  @override
  String get cookMore => 'أكثر';

  @override
  String get rewardsCardTitle => 'مكافآت زاد';

  @override
  String get rewardsCardBody =>
      'شف إعلان وخذ رسائل زيادة، أو اشترك وارتاح من الإعلانات.';

  @override
  String get rewardsSubscribe => 'اشترك في زاد بريميوم';

  @override
  String get rewardsTelegram => 'بوت زاد على تليجرام';

  @override
  String get profileTelegramSubtitle => 'اربط حسابك وخلّ التذكيرات توصلك';

  @override
  String get homeCareRenewsToday => 'يتجدد اليوم';

  @override
  String get homeCareRenewsTomorrow => 'يتجدد بكرة';

  @override
  String homeCareRenewsInDays(Object days) {
    return 'يتجدد بعد $days يوم';
  }

  @override
  String get homeCareDoseNow => 'جرعتها الحين';

  @override
  String get introSayPantry => 'الثلاجة هذي حقتي!';

  @override
  String get authZadoNotLooking => 'ما أشوف، والله';

  @override
  String get consentTitle => 'قبل ما نبدأ، هذا اتفاقنا';

  @override
  String get consentPoint3Lead => 'ما نبيع بياناتك لأحد.';

  @override
  String get consentPoint4Body =>
      'راجع الأرقام قبل أي قرار؛ زاد مو بنك ولا مستشار مالي.';

  @override
  String get worldLabelPrices => 'أسعار اليوم';

  @override
  String get worldLinksHint => 'اللي يصير هنا يأثر في:';

  @override
  String pantryWorldEyebrow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count صنف',
      few: '$count أصناف',
      two: 'صنفين',
      one: 'صنف واحد',
      zero: 'للحين ما فيه أصناف',
    );
    return '$_temp0';
  }

  @override
  String pantryWorldState(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count شي قرّب يخلص',
      few: '$count أشياء قرّبت تخلص',
      two: 'شيئين قرّبوا يخلصون',
      one: 'شي واحد قرّب يخلص',
      zero: 'ما فيه شي قرّب يخلص',
    );
    return '$_temp0';
  }

  @override
  String brainWorldEyebrow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عنصر متصل',
      zero: 'للحين ما فيه عناصر',
    );
    return '$_temp0';
  }

  @override
  String get brainNetworkEmptyTitle => 'زاد للحين يتعلم عنك';

  @override
  String get brainNetworkEmptyMessage =>
      'سجّل مصاريفك أو أضف مخزون وأدوية، وبتلقى الشبكة تكبر هنا.';

  @override
  String get brainCardStaffBody =>
      'اللي لاحظه الموظفين في جولة الصباح على بيتك وفلوسك وعيلتك';

  @override
  String get brainCardMemoryTitle => 'وش يعرف زاد عني';

  @override
  String get brainCardMemoryBody =>
      'اللي يتذكره زاد عنك ويكلمك على أساسه — صحّحه أو خله ينساه';

  @override
  String get brainCardGraphBody =>
      'الناس والأماكن والأشياء اللي يعرفها زاد وكيف تترابط — وصدّرها لأوبسيديان';

  @override
  String get brainCardMapBody =>
      'كيف ميزانيتك واشتراكاتك وبيتك مرتبطين ببعض — بملء الشاشة';

  @override
  String get brainCardLogBody =>
      'كل شي سجّله زاد أو عدّله لك، وتتراجع عنه لو غلط';

  @override
  String get brainCardHealthBody =>
      'زاد شغال في الخلفية ولا واقف — ولو واقف، ليش';

  @override
  String get brainTelemetryDecisions => 'قرارات اليوم';

  @override
  String get zadStatusTitle => 'حالة زاد';

  @override
  String get zadStatusAllGood => 'زاد شغّال ويتابع';

  @override
  String get zadStatusNeedsFix => 'فيه شي واقف ويحتاج منك خطوة';

  @override
  String zadStatusAllButOne(String what) {
    return 'كله شغّال ما عدا: $what';
  }

  @override
  String get zadStatusWorking => 'شغال';

  @override
  String get zadStatusStopped => 'واقف';

  @override
  String get zadStatusMaybe => 'ممكن يقف';

  @override
  String get zadStatusBank => 'قراءة رسائل البنك';

  @override
  String get zadStatusBankOk => 'زاد بيقرا رسائل البنك ويسجّلها.';

  @override
  String get zadStatusBankOff =>
      'قراءة رسائل البنك متوقفة. شغّلها عشان رصيدك ومصاريفك تتحدّث لحالها.';

  @override
  String get zadStatusBankStalled =>
      'الخدمة ما عادت تشوف إشعارات من فترة. إذا كانت مفعّلة: طفّها وشغّلها مرة ثانية من الصفحة اللي بتفتح.';

  @override
  String get zadStatusBankSilent =>
      'مفعّلة، بس للحين ما وصلت ولا رسالة. إذا تنتظر رسالة من البنك وما وصلت: طفّها وشغّلها مرة ثانية.';

  @override
  String get zadStatusNotifications => 'الإشعارات';

  @override
  String get zadStatusNotificationsOk =>
      'تنبيهات الجرعات والفواتير والميزانية بتوصلك.';

  @override
  String get zadStatusNotificationsOff =>
      'الإشعارات مقفولة، فتنبيهات الجرعات والفواتير ما بتوصلك.';

  @override
  String get zadStatusLocation => 'الموقع';

  @override
  String get zadStatusLocationOk =>
      'الموقع شغّال، والعروض والمحلات القريبة تنحسب من مكانك.';

  @override
  String get zadStatusLocationServiceOff =>
      'الموقع مقفول في الجوال، فالقراءات ما بتكون من مكانك الحقيقي.';

  @override
  String get zadStatusLocationDenied =>
      'زاد ما هو مسموح له يعرف مكانك، فالعروض والمحلات القريبة ما بتشتغل.';

  @override
  String get zadStatusBackground => 'الموقع طول الوقت';

  @override
  String get zadStatusBackgroundOk =>
      'تنبيهات الطريق شغالة حتى والتطبيق مقفول.';

  @override
  String get zadStatusBackgroundOff =>
      'بدون «طوال الوقت» تنبيهات الطريق ما بتشتغل والتطبيق مقفول.';

  @override
  String get zadStatusBattery => 'توفير البطارية';

  @override
  String get zadStatusBatteryOk => 'الجوال ما يقيّد زاد في الخلفية.';

  @override
  String get zadStatusBatteryWarn =>
      'الجوال ممكن يوقف زاد في الخلفية. اختر «بدون قيود» عشان القراءة ما تنقطع.';

  @override
  String get zadStatusFixOpenSettings => 'افتح الإعدادات';

  @override
  String get zadStatusFixAllow => 'اسمح';

  @override
  String get zadStatusFixLocationOn => 'شغّل الموقع';

  @override
  String get zadStatusFixBattery => 'فكّ القيود';

  @override
  String get gamesHubIntro => 'العب، كمّل السلسلة، واكسب بذور';

  @override
  String gamesHubToday(int target, String game) {
    return 'تحدي اليوم: $target نقطة في «$game»';
  }

  @override
  String gamesHubStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count أيام ورا بعض',
      one: 'يوم واحد',
      zero: 'ابدأ سلسلتك اليوم',
    );
    return '$_temp0';
  }

  @override
  String get gamesHubNotPlayed => 'ما لعبت للحين';

  @override
  String get gamesHubChallengeDone => 'تحدي اليوم خلص';

  @override
  String gameChallenge(int target) {
    return 'تحدي اليوم: وصّل $target نقطة';
  }

  @override
  String get gameChallengeDone => 'خلصت التحدي اليوم، برافو!';

  @override
  String gameSeedsLeft(int count) {
    return 'باقي $count بذور اليوم';
  }

  @override
  String get gameAdUnavailable => 'ما فيه إعلان متاح الحين';

  @override
  String gameLives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count محاولات',
      one: 'محاولة واحدة',
      zero: 'ما فيه محاولات',
    );
    return '$_temp0';
  }

  @override
  String runGameHint(String name) {
    return 'المس الشاشة عشان $name يقفز';
  }

  @override
  String get sortGameDaily => 'لغز اليوم';

  @override
  String get sortGameStuck => 'ما فيه حركات ثانية';

  @override
  String shopWorldEyebrow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count شي ناقص',
      few: '$count أشياء ناقصة',
      two: 'شيئين ناقصين',
      one: 'شي واحد ناقص',
      zero: 'ما فيه شي ناقص',
    );
    return '$_temp0';
  }

  @override
  String shopWorldStores(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'من $count محل',
      few: 'من $count محلات',
      two: 'من محلين',
      one: 'من محل واحد',
    );
    return '$_temp0';
  }

  @override
  String get shopWorldAnyStore => 'من أي محل';

  @override
  String get shopWorldDone => 'القائمة فاضية';

  @override
  String get shopGroupAnyStore => 'أي محل';

  @override
  String shopPantryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'في المخزن $count صنف',
      few: 'في المخزن $count أصناف',
      two: 'في المخزن صنفين',
      one: 'في المخزن صنف واحد',
      zero: 'المخزن فاضي',
    );
    return '$_temp0';
  }

  @override
  String apptWorldToday(String weekday) {
    return 'اليوم $weekday';
  }

  @override
  String apptWorldNext(String title, String when) {
    return '$title $when';
  }

  @override
  String get apptWorldNone => 'ما فيه مواعيد جاية';

  @override
  String get apptNextLabel => 'الموعد القادم';

  @override
  String get apptInNow => 'الحين';

  @override
  String apptInMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'بعد $count دقيقة',
      few: 'بعد $count دقائق',
      two: 'بعد دقيقتين',
      one: 'بعد دقيقة',
    );
    return '$_temp0';
  }

  @override
  String apptInHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'بعد $count ساعة',
      few: 'بعد $count ساعات',
      two: 'بعد ساعتين',
      one: 'بعد ساعة',
    );
    return '$_temp0';
  }

  @override
  String apptInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'بعد $count يوم',
      few: 'بعد $count أيام',
      two: 'بعد يومين',
      one: 'بعد يوم',
    );
    return '$_temp0';
  }

  @override
  String phEyebrowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count دواء',
      few: '$count أدوية',
      two: 'دواءين',
      one: 'دواء واحد',
    );
    return '$_temp0';
  }

  @override
  String get phFamilyEyebrow => 'صيدلية العائلة';

  @override
  String phMemberState(String name) {
    return 'جدول $name';
  }

  @override
  String get phNoDosesToday => 'ما فيه جرعات اليوم';

  @override
  String phDoseDueNow(String name) {
    return 'جرعة $name وقتها الحين';
  }

  @override
  String phNextDose(String when) {
    return 'الجرعة القادمة $when';
  }

  @override
  String phDoseMissedLine(String name) {
    return 'فاتتك جرعة $name';
  }

  @override
  String get phDosesDone => 'خلصت جرعات اليوم';

  @override
  String get phPeriodMorning => 'الصباح';

  @override
  String get phPeriodNoon => 'الظهر';

  @override
  String get phPeriodAfternoon => 'العصر';

  @override
  String get phPeriodNight => 'بالليل';

  @override
  String phClockWords(String hour, String minutes, String period) {
    return '$hour$minutes $period';
  }

  @override
  String get phDoseTaken => 'انأخذت';

  @override
  String get phDoseDue => 'وقتها الحين';

  @override
  String get phDoseMissed => 'فاتت';

  @override
  String get phDoseUpcoming => 'قادمة';

  @override
  String get phDoseSnoozed => 'تأجلت شوي';

  @override
  String get phDosePassed => 'عدّى وقتها';

  @override
  String get phSnooze => 'بعدين';

  @override
  String get phTake => 'أخذته';

  @override
  String get phTakeFor => 'أخذتها';

  @override
  String phForPerson(String name) {
    return 'لـ$name';
  }

  @override
  String get phCourseDone => 'انتهى الكورس';

  @override
  String phExpiredAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'منتهي من $count يوم',
      few: 'منتهي من $count أيام',
      two: 'منتهي من يومين',
      one: 'منتهي من يوم',
    );
    return '$_temp0';
  }

  @override
  String phExpiresIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تنتهي خلال $count يوم',
      few: 'تنتهي خلال $count أيام',
      two: 'تنتهي خلال يومين',
      one: 'تنتهي خلال يوم',
    );
    return '$_temp0';
  }

  @override
  String phRemaining(int count, String unit) {
    return 'متبقي $count $unit';
  }

  @override
  String phSupplyDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'يكفي $count يوم',
      few: 'يكفي $count أيام',
      two: 'يكفي يومين',
      one: 'يكفي يوم',
      zero: 'يكفي أقل من يوم',
    );
    return '$_temp0';
  }

  @override
  String get phDelete => 'حذف';

  @override
  String get phBadDoseTime => 'وقت جرعة غير مفهوم — عدّله';

  @override
  String get phNoSchedule => 'ما له مواعيد — ما راح أذكّرك فيه';

  @override
  String get phSetTimes => 'حدد مواعيده';

  @override
  String get phConfirmQtyBadge => 'الكمية تحتاج تأكيد';

  @override
  String get phTakeDose => 'تناول جرعة';

  @override
  String get phRefill => 'تجديد الطلب';

  @override
  String get phToShopping => 'أضفه للتسوق';

  @override
  String get phHowMuchLeft => 'كم باقي فعلاً؟';

  @override
  String phAddedToShopping(String name) {
    return 'أضفت $name لقائمة التسوق';
  }

  @override
  String get phDosesToday => 'جرعات اليوم';

  @override
  String get phNoDosesLeft => 'ما فيه جرعات باقية اليوم.';

  @override
  String get phNoTimesYet =>
      'ما فيه دواء له مواعيد للحين — حدد مواعيد أي دواء تحت عشان أذكّرك فيه.';

  @override
  String get phLoadFailed => 'ما قدرت أجيب الأدوية';

  @override
  String get phEmptyTitle => 'لا توجد أدوية مسجلة بعد';

  @override
  String get phPullRetry => 'اسحب لتحت ونجرب مرة ثانية.';

  @override
  String get phEmptyGuide =>
      'أضفه بالزر، أو صوّر العلبة، أو قل لزاد: \"آخذ كونكور قرص الصباح والليل\" وهو يسجّله بمواعيده.';

  @override
  String get phMedicines => 'الأدوية';

  @override
  String phTimesTitle(String name) {
    return 'مواعيد $name';
  }

  @override
  String get phTimesHint => 'بذكّرك في كل ميعاد، وتقدر تسجّل الجرعة بضغطة.';

  @override
  String get phSaveTimes => 'احفظ المواعيد';

  @override
  String get phAdherence => 'الالتزام بالجرعات';

  @override
  String get phAdherenceWaiting => 'في انتظار أول جرعة';

  @override
  String get phCountTotal => 'إجمالي الأدوية';

  @override
  String get phCountExpiring => 'قريبة الانتهاء';

  @override
  String get phCountLow => 'مخزون منخفض';

  @override
  String phExpiredBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count دواء منتهي الصلاحية — تخلص منه بأمان',
      few: '$count أدوية منتهية الصلاحية — تخلص منها بأمان',
      two: 'دواءين منتهيين الصلاحية — تخلص منهم بأمان',
      one: 'دواء منتهي الصلاحية — تخلص منه بأمان',
    );
    return '$_temp0';
  }

  @override
  String get phExpiringHeading => 'قريبة الانتهاء — تخلص منها بأمان';

  @override
  String get phCostSpending => 'صرف الصحة هذا الشهر';

  @override
  String get phCostBoxes => 'أسعار علب الأدوية';

  @override
  String get phTabMe => 'أنا';

  @override
  String get phTabMember => 'عضو';

  @override
  String get phMemberFallback => 'العضو';

  @override
  String phHeadNote(String name) {
    return 'أنت رب الأسرة — تشوف جدول $name وتعدّل عليه وتعلّم الجرعة لو ساعدته';
  }

  @override
  String phReadOnlyNote(String name) {
    return 'جدول $name للمتابعة فقط — رب الأسرة هو اللي يعدّل';
  }

  @override
  String phAddFor(String name) {
    return 'دواء لـ$name';
  }

  @override
  String phMemberLoadFailed(String name) {
    return 'ما قدرت أجيب أدوية $name';
  }

  @override
  String get phMemberEmptyTitle => 'للحين ما فيه أدوية تقدر تشوفها';

  @override
  String get phMemberEmptyGuide =>
      'أدوية كل فرد تظهر هنا بعد ما يوافق — اطلب المتابعة من صفحته في «عيلتي»';

  @override
  String phMemberDoses(String name) {
    return 'جرعات $name اليوم';
  }

  @override
  String get phEdit => 'تعديل';

  @override
  String phEditTitle(String name) {
    return 'تعديل $name';
  }

  @override
  String get phPhoto => 'صوّر الدواء';

  @override
  String get phAdd => 'إضافة';

  @override
  String get phScanUnclear =>
      'تعذر قراءة العلبة بدقة، يرجى المحاولة بزاوية أوضح';

  @override
  String get phScanOk => 'تم استخراج بيانات الدواء بنجاح';

  @override
  String get phScanReading => 'جاري قراءة علبة الدواء بالذكاء الاصطناعي...';

  @override
  String get phScanBtn => 'مسح العبوة بالكاميرا';

  @override
  String get phAddTitle => 'إضافة دواء';

  @override
  String get phReviewTitle => 'راجع الدواء';

  @override
  String get phReadFromBox =>
      'قرأت هذا من العلبة — عدّل أي شي غلط قبل ما تحفظ.';

  @override
  String get phFieldName => 'اسم الدواء';

  @override
  String get phFieldForWhom => 'لمن؟ (خلها فاضية لو لك)';

  @override
  String get phHintPeople => 'ماما، بابا، يوسف…';

  @override
  String get phFieldDosageNote => 'الجرعة (مثال: بعد الأكل)';

  @override
  String get phFieldTimesOptional => 'مواعيد الجرعة (اختياري)';

  @override
  String phTimesSuggested(String times) {
    return 'للحين ما فيه مواعيد مضافة — المقترح: $times';
  }

  @override
  String get phFieldAmount => 'المبلغ';

  @override
  String phFieldAmountCur(String currency) {
    return 'المبلغ ($currency)';
  }

  @override
  String get phMoreDetails => 'تفاصيل إضافية (اختياري)';

  @override
  String get phSave => 'حفظ';

  @override
  String get phCancel => 'إلغاء';

  @override
  String get phConfirm => 'تأكيد';

  @override
  String get phPickTime => 'اختر ميعاد الجرعة';

  @override
  String get phAddTime => 'إضافة ميعاد';

  @override
  String get phPickExpiry => 'تاريخ الانتهاء — اضغط لاختيار التاريخ';

  @override
  String get phFieldQty => 'الكمية المتبقية';

  @override
  String get phFieldUnit => 'الوحدة';

  @override
  String get phFieldDailyCount => 'جرعات اليوم';

  @override
  String phFieldPerDose(String unit) {
    return 'كم $unit في الجرعة الواحدة؟';
  }

  @override
  String get phPresetMorning => 'صباحاً';

  @override
  String get phPresetNoon => 'ظهراً';

  @override
  String get phPresetEvening => 'مساءً';

  @override
  String get phPresetBed => 'قبل النوم';

  @override
  String get phFieldIngredient => 'المادة الفعالة';

  @override
  String get phFieldDosageFreq => 'الجرعة (مثال: قرص كل 8 ساعات)';

  @override
  String get phChronic => 'دواء مزمن / روشتة متجددة شهرياً';

  @override
  String get phForFamilyMember => 'لمن في العائلة';

  @override
  String get phNone => 'بدون';

  @override
  String phDeleteBody(String name) {
    return 'حذف «$name» من الصيدلية؟';
  }

  @override
  String phQtyCurrent(String name, int count, String unit) {
    return '$name — الكمية الحالية المسجلة: $count $unit';
  }

  @override
  String get phPerDoseHelp =>
      'من غير هذا الرقم ما أقدر أحسب المخزون يكفي كم يوم';

  @override
  String phRefillTitle(String name) {
    return 'تجديد طلب $name';
  }

  @override
  String phAddedQty(String unit) {
    return 'الكمية المضافة ($unit)';
  }

  @override
  String get phPrice => 'السعر';

  @override
  String get phExpiryDate => 'تاريخ الانتهاء';

  @override
  String get phAlarmHint =>
      'فعّل \"المنبهات الدقيقة\" من الإعدادات عشان تشتغل تنبيهات مواعيد الدواء بدقة';

  @override
  String get phErrNotHead => 'فقط رب الأسرة يقدر يعدّل أدوية أحد من العائلة.';

  @override
  String get phErrOffline =>
      'ما فيه نت الحين — ما انحفظ شي. جرّب مرة ثانية لما يرجع.';

  @override
  String get phErrNotFound =>
      'هذا الدواء مو موجود عند العضو الحين — حدّث الصفحة.';

  @override
  String get phErrDuplicate => 'العضو عنده دواء بنفس هذا الاسم.';

  @override
  String get phErrRejected => 'السيرفر رفض الحفظ. جرّب مرة ثانية.';

  @override
  String get tasStateEmpty => 'ابدأ أول تسبيحة والورد بيتفتح';

  @override
  String get tasTabFamily => 'أشجار العائلة';

  @override
  String get tasStatSession => 'في هذي الجلسة';

  @override
  String tasStreakDays(int days) {
    return '$days يوم متتالي';
  }

  @override
  String get tasBloom => 'تفتّحت وردة جديدة!';

  @override
  String get tasNoTreeTitle => 'للحين ما فيه شجرة';

  @override
  String get tasNoTreesMsg => 'أول ما أحد من العائلة يسبّح تظهر شجرته هنا.';

  @override
  String get tasChallengesTitle => 'التحديات العائلية';

  @override
  String get tasNoChallengesAdmin => 'اضغط + وابدأ أول تحدي للعائلة.';

  @override
  String get tasNoChallengesMember => 'اطلب من المدير ينشئ تحدي جديد!';

  @override
  String txWorldEyebrow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count معاملة',
      few: '$count معاملات',
      two: 'معاملتين',
      one: 'معاملة وحدة',
      zero: 'للحين ما فيه معاملات',
    );
    return '$_temp0';
  }

  @override
  String txWorldState(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تسجّلوا بنفسهم اليوم',
      few: '$count تسجّلوا بنفسهم اليوم',
      two: 'ثنتين تسجّلوا بنفسهم اليوم',
      one: 'وحدة تسجّلت بنفسها اليوم',
      zero: 'للحين ما فيه شي تسجّل بنفسه اليوم',
    );
    return '$_temp0';
  }

  @override
  String get txSourceBank => 'رسالة من البنك';

  @override
  String txSourceBankNamed(String bank) {
    return '$bank · رسالة';
  }

  @override
  String get txSourceReceipt => 'فاتورة مصوّرة';

  @override
  String get txSourceVoice => 'قلتها بصوتك';

  @override
  String get txSourceStatement => 'من كشف الحساب';

  @override
  String get txSourcePharmacy => 'تعبئة الصيدلية';

  @override
  String get txSourceManual => 'كتبتها بيدك';

  @override
  String budgetWorldUntil(int day) {
    return 'لين يوم $day';
  }

  @override
  String budgetWorldDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'باقي $count يوم',
      few: 'باقي $count أيام',
      two: 'باقي يومين',
      one: 'باقي يوم واحد',
      zero: 'آخر يوم',
    );
    return '$_temp0';
  }

  @override
  String budgetWorldState(String amount, String perDay) {
    return 'متاح $amount · $perDay في اليوم';
  }

  @override
  String budgetWorldAvailable(String amount) {
    return 'متاح $amount';
  }

  @override
  String statementWorldStateLess(int pct) {
    return 'صرفت $pct٪ أقل من نفس الفترة الشهر اللي فات';
  }

  @override
  String statementWorldStateMore(int pct) {
    return 'صرفت $pct٪ أكثر من نفس الفترة الشهر اللي فات';
  }

  @override
  String get statementWorldStateSame => 'صرفك مثل الشهر اللي فات';

  @override
  String get statementWorldStateNone => 'استورد كشفك وشف فلوسك وين راحت';

  @override
  String get statementWorldBreakdownTitle => 'فلوسك من وين تدخل وين تطلع';

  @override
  String get statementWorldIn => 'الدخل';

  @override
  String get statementWorldEmptyTitle => 'ما فيه حركات هذا الشهر للحين';

  @override
  String get statementWorldEmptyBody =>
      'استورد كشفك أو سجّل معاملة، وتلقى هنا الدخل والمصروف حسب الفئة.';

  @override
  String get statementPickBody =>
      'اختر كشف حسابك: PDF من تطبيق البنك، أو صورة، أو ملف CSV. زاد يقرا الحركات ويراجعها على رصيد الكشف، وما يتسجل شي إلا بعد ما تراجعها.';

  @override
  String get statementReading => 'أقرا الكشف… الكشف الطويل ياخذ دقيقة';

  @override
  String get statementPickButton => 'اختيار الكشف';

  @override
  String get statementMapIntro =>
      'حدد أي عمود من الملف يمثل كل بيان — الملف يختلف من بنك لبنك';

  @override
  String get statementMapDate => 'عمود التاريخ';

  @override
  String get statementMapTitle => 'عمود الوصف/العنوان';

  @override
  String get statementMapAmount => 'عمود المبلغ';

  @override
  String get statementMapCategory => 'عمود التصنيف (اختياري)';

  @override
  String get statementMapInvert =>
      'اعكس إشارة المبلغ (لو السالب هنا يعني دخل مو مصروف)';

  @override
  String get statementMapContinue => 'متابعة للمراجعة';

  @override
  String get statementMapNone => 'بدون';

  @override
  String statementMapColumnN(int n) {
    return 'عمود $n';
  }

  @override
  String statementPreviewCount(int rows, int checked) {
    return '$rows صف — $checked محدد للاستيراد';
  }

  @override
  String get statementPreviewEmptyTitle => 'ما لقيت أي معاملة في الملف';

  @override
  String get statementPreviewEmptyBody =>
      'الملف انقرا بس ما فيه صفوف أقدر أستوردها — تأكد إنه كشف حساب وإن صيغته CSV أو PDF مقروء.';

  @override
  String get statementRowUnreadable =>
      'تعذّرت قراءة التاريخ أو المبلغ في هذا الصف';

  @override
  String get statementRowBalance =>
      'الرصيد في الكشف مو متطابق مع هذا الصف — راجع المبلغ';

  @override
  String get statementCheckBalanced => 'الأرقام متطابقة مع رصيد الكشف';

  @override
  String get statementCheckMismatch =>
      'فيه أرقام مو متطابقة مع رصيد الكشف — الصفوف هذي غير معلّمة، راجعها';

  @override
  String get statementCheckUnknown =>
      'الكشف ما فيه رصيد أراجع عليه — راجع كل صف قبل الاستيراد';

  @override
  String statementDropped(String text, int n) {
    return '$text. وفيه $n صف ما قدرت أقراه.';
  }

  @override
  String placesWorldEyebrow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count خروجة',
      few: '$count خروجات',
      two: 'خروجتين',
      one: 'خروجة وحدة',
      zero: 'ما فيه خروجات للحين',
    );
    return '$_temp0';
  }

  @override
  String placesWorldState(int count, String alerts) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مكان',
      few: '$count أماكن',
      two: 'مكانين',
      one: 'مكان واحد',
      zero: 'ما فيه أماكن',
    );
    String _temp1 = intl.Intl.selectLogic(alerts, {
      'on': 'تنبيهات الشارع شغّالة',
      'other': 'تنبيهات الشارع مقفّلة',
    });
    return '$_temp0 · $_temp1';
  }

  @override
  String get docsPrivacy =>
      'زاد يحفظ نوع المستند وتاريخ انتهائه بس — بدون رقم ولا صورة — ويذكّرك قبلها.';

  @override
  String get docsEmptyTitle => 'ما فيه مستندات مسجّلة';

  @override
  String get docsSaveFailedEdit =>
      'ما انحفظ — يمكن فيه مستند بنفس النوع والاسم، أو ما فيه نت.';

  @override
  String get docsSaveFailedAdd => 'ما انحفظ — تأكد من النت.';

  @override
  String get docsDeleteFailed => 'ما انحذف — تأكد من النت.';

  @override
  String get maintStateNone => 'ما فيه جهاز مسجّل للحين';

  @override
  String get maintEmptyTitle => 'ما فيه أجهزة مسجّلة للحين';

  @override
  String get maintEmptyMessage =>
      'سجّل المكيف أو السخان أو السيارة، وزاد يذكّرك بموعد صيانتها وضمانها.';

  @override
  String get maintTechnicians => 'فنيين أثق فيهم';

  @override
  String get maintTechniciansHint => 'اتصل أو أرسل واتساب لفني جرّبته';

  @override
  String get maintAddFailed => 'ما انسجّل الجهاز — تأكد من النت.';

  @override
  String get notifMarkAllRead => 'علّم الكل كمقروء';

  @override
  String get notifAllRead => 'الكل مقروء';

  @override
  String achWorldState(int done, int total) {
    return '$done من $total إنجاز';
  }

  @override
  String achLevel(int level) {
    return 'المستوى $level';
  }

  @override
  String achLevelPoints(int points, int next) {
    return '$points من $next نقطة';
  }

  @override
  String get achOnTrack => 'أنت على الطريق الصحيح!';

  @override
  String get achContributions => 'المساهمات';

  @override
  String get achStreak => 'التسلسل';

  @override
  String get achShelf => 'الإنجازات';

  @override
  String get achNext => 'الإنجاز التالي';

  @override
  String get achLocked => 'مقفول';

  @override
  String get achLoadFailed => 'ما قدرنا نجيب الإنجازات الحين';

  @override
  String get achLoadFailedHint => 'تأكد من الاتصال وحاول مرة ثانية';

  @override
  String get achRetry => 'حاول مرة ثانية';

  @override
  String get pricesEyebrow => 'لوحة الأسعار';

  @override
  String get pricesWorldNeutral => 'أسعار السوق من بلاغات الناس';

  @override
  String get pricesWorldFlat => 'الأسعار ثابتة اليوم';

  @override
  String pricesWorldUp(String name) {
    return '$name طالع';
  }

  @override
  String pricesWorldDown(String name) {
    return '$name نازل';
  }

  @override
  String pricesWorldUpDown(String up, String down) {
    return '$up طالع، $down نازل';
  }

  @override
  String get pricesMine => 'مساهماتك';

  @override
  String get pricesReportNew => 'سجّل سعراً جديداً';

  @override
  String get pricesCheapestTitle => 'أرخص سعر حولك';

  @override
  String get pricesCheapestNote =>
      'من بلاغات مجتمع زاد آخر ١٤ يوماً — وليست أسعاراً رسمية';

  @override
  String get pricesCityLabel => 'المدينة أو المنطقة (اختياري)';

  @override
  String get pricesSearch => 'ابحث';

  @override
  String get pricesFetchFailed => 'ما قدرنا نجيب الأسعار الحين';

  @override
  String get pricesFetchFailedHint => 'تأكد من الإنترنت وحاول مرة ثانية';

  @override
  String get pricesRetry => 'حاول مرة ثانية';

  @override
  String get pricesNoReportsTitle => 'ما فيه بلاغات هنا للحين';

  @override
  String get pricesNoReportsHint => 'كن أول من يبلّغ عن سعر — جيرانك بيشكرونك';

  @override
  String get pricesFirstReport => 'سجّل أول سعر';

  @override
  String pricesRowMeta(String where, int count) {
    return '$where · $count بلاغ';
  }

  @override
  String get pricesTrendsTitle => 'ترندات سوقك';

  @override
  String pricesTrendsNote(int days) {
    return 'ما اشترته أو أضافته بيوت كثيرة في بلدك لقائمة التسوق آخر $days يوم — بدون أسماء ولا محلات';
  }

  @override
  String get pricesTrendsNoMarket => 'اختر بلدك أولاً';

  @override
  String get pricesTrendsNoMarketHint => 'الترندات تُحسب لكل بلد على حدة.';

  @override
  String get pricesTrendsEmpty => 'ما فيه ترند في سوقك للحين';

  @override
  String pricesTrendsEmptyHint(int homes) {
    return 'يظهر الصنف هنا لما يشتريه أو يضيفه $homes بيوت مختلفة على الأقل — حتى لا يُعرف أحد من مشترياته. كل فاتورة تصوّرها تقرّب هذا اليوم.';
  }

  @override
  String get pricesTrendUp => 'يزيد';

  @override
  String get pricesTrendDown => 'يقل';

  @override
  String get pricesTrendFlat => 'ثابت';

  @override
  String get pricesTrendFresh => 'جديد';

  @override
  String pricesHomes(int n) {
    return '$n بيوت';
  }

  @override
  String get pricesTopTitle => 'أكثر المشاركين';

  @override
  String get pricesTopNone => 'ما فيه مساهمات للحين';

  @override
  String get pricesTopNoneHint =>
      'سجّل أول سعر رأيته في السوق — تظهر مساهمتك هنا وتساعد جيرانك يلقون أرخص مكان.';

  @override
  String pricesContributor(int rank) {
    return 'المساهم $rank';
  }

  @override
  String pricesContribCount(int n) {
    return '$n مساهمات';
  }

  @override
  String get settingsAdsUnavailable => 'ما فيه اختيارات خصوصية متاحة الحين';

  @override
  String get homeTodayTitle => 'اليوم في بيتك';

  @override
  String get homeTodayEmpty => 'ما فيه نواقص ولا جرعات ولا تجديدات قريبة';

  @override
  String get homeTodayEmptyHint => 'اليوم هادي. أي شي يحتاج انتباهك بيظهر هنا.';

  @override
  String get homeTodayShortTitle => 'نواقص تنشرى';
}
