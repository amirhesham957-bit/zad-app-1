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
  String get paywallPlusBadge => 'الأكثر شعبية ⭐';

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
  String get paywallFamilyBadge => 'أكبر رصيد 👑';

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
      '5 محاولات بترجع كل 5 ساعات، وتسجيل المصاريف مجاني دايماً. رسالة الشات بمحاولة، مسح الفاتورة بمحاولتين، والتحليل العميق بـ3.';

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
  String get drawerNearby => 'المتاجر والأسواق القريبة';

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
      'أهلاً بيك! أنا زاد 🤖، مساعدك العائلي الذكي. أقدر أساعدك إزاي النهاردة؟\nاسألني عن الوصفات، أو راجع ثلاجتك، أو ضيف النواقص لقائمة التسوق!';

  @override
  String get chatBusy =>
      'الذكاء الاصطناعي مشغول شوية دلوقتي 🙏 جرب تاني بعد لحظات.';

  @override
  String get chatUnexpected => 'حصل خطأ غير متوقع.';

  @override
  String get chatResend => 'ماوصلتش — ابعتها تاني';

  @override
  String get chatStopVoice => 'وقّف الصوت';

  @override
  String get chatListen => 'اسمع الرد';

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
}
