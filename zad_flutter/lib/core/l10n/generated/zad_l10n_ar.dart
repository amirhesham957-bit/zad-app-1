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
  String get subscribePulseTitle => 'اشترك وزاد يبقى معاك على طول';

  @override
  String get subscribePulseBody =>
      'من غير إعلانات، ومحاولات أكتر، وصوت من غير حد.';

  @override
  String get subscribePulseClose => 'اقفل';

  @override
  String get voiceOutToday =>
      'خلصت أسئلتك الصوتية النهارده (٣ في اليوم) — بترجع بكرة. اكتب سؤالك، أو اشترك وكلّم زاد من غير حد.';

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
      'خلصت أسئلتك الصوتية النهارده — ٣ في اليوم، وبترجع بكرة';

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
  String get gateTitle => 'قبل ما نبدأ، حدد سقفك الشهري';

  @override
  String get gateBody =>
      'زاد ما بيخترعش أرقام. من غير السقف مفيش \"متبقي\" ولا \"متاح\" — وكل رقم هتشوفه هيبقى تخمين.';

  @override
  String get gateMarket => 'البلد والعملة';

  @override
  String get commonChange => 'تغيير';

  @override
  String get gateCeiling => 'سقف الصرف الشهري';

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
  String get subsPaidMark => 'تم الدفع ✓';

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
  String get agentToolLogTransaction => 'تسجيل معاملة';

  @override
  String get agentToolUpdateTransaction => 'تعديل معاملة';

  @override
  String get agentToolDeleteTransaction => 'حذف معاملة';

  @override
  String get agentToolSetTransactionCategory => 'تصنيف معاملة';

  @override
  String get agentToolMergeDuplicateExpense => 'دمج معاملة مكررة';

  @override
  String get agentToolReconcileCashBalance => 'تسوية الكاش';

  @override
  String get agentToolParseNotificationPayload => 'قراءة رسالة بنك';

  @override
  String get agentToolSetMonthlyLimit => 'تعديل سقف الميزانية';

  @override
  String get agentToolConfirmCycleStart => 'تأكيد دورة الراتب';

  @override
  String get agentToolSetMarket => 'تعديل البلد والعملة';

  @override
  String get agentToolAddObligation => 'تسجيل التزام';

  @override
  String get agentToolConfirmObligation => 'تأكيد التزام';

  @override
  String get agentToolUpdateObligation => 'تعديل التزام';

  @override
  String get agentToolDeleteObligation => 'حذف التزام';

  @override
  String get agentToolAddSubscription => 'إضافة اشتراك';

  @override
  String get agentToolUpdateSubscription => 'تعديل اشتراك';

  @override
  String get agentToolDeleteSubscription => 'حذف اشتراك';

  @override
  String get agentToolAddDebt => 'تسجيل دين';

  @override
  String get agentToolUpdateDebt => 'تعديل دين';

  @override
  String get agentToolDeleteDebt => 'حذف دين';

  @override
  String get agentToolAddInventoryItem => 'إضافة صنف للمخزون';

  @override
  String get agentToolUpdateInventoryQty => 'تعديل كمية مخزون';

  @override
  String get agentToolDeleteInventoryItem => 'حذف صنف من المخزون';

  @override
  String get agentToolAddShoppingItem => 'إضافة لقايمة المشتريات';

  @override
  String get agentToolCompleteShoppingItem => 'شطب من قايمة المشتريات';

  @override
  String get agentToolDeleteShoppingItem => 'حذف من قايمة المشتريات';

  @override
  String get agentToolAddPharmacyItem => 'إضافة دواء';

  @override
  String get agentToolUpdatePharmacyItem => 'تعديل دواء';

  @override
  String get agentToolDeletePharmacyItem => 'حذف دواء';

  @override
  String get agentToolLogPharmacyDose => 'تسجيل جرعة دواء';

  @override
  String get agentToolAddMaintenanceItem => 'إضافة جهاز للصيانة';

  @override
  String get agentToolUpdateMaintenanceItem => 'تعديل جهاز';

  @override
  String get agentToolDeleteMaintenanceItem => 'حذف جهاز';

  @override
  String get agentToolSaveDocument => 'تسجيل مستند';

  @override
  String get agentToolDeleteDocument => 'شيل مستند';

  @override
  String get agentToolAddGatheringToList => 'سطور عزومة للقايمة';

  @override
  String get agentToolAddAppointment => 'إضافة ميعاد';

  @override
  String get agentToolUpdateAppointment => 'تعديل ميعاد';

  @override
  String get agentToolAddPlaceReminder => 'تذكير عند مكان';

  @override
  String get agentToolCancelPlaceReminder => 'إلغاء تذكير مكان';

  @override
  String get agentToolScheduleTask => 'جدولة تذكير';

  @override
  String get agentToolRemember => 'حفظ ملاحظة عنك';

  @override
  String get agentToolLinkMemory => 'ربط ملاحظات';

  @override
  String get agentToolUpdateCustomerProfile => 'تحديث ملفك';

  @override
  String get agentToolSetLifeGoal => 'هدف جديد';

  @override
  String get agentToolSetBrokeMode => 'وضع التقشف';

  @override
  String get agentToolStartSavingsChallenge => 'بدء تحدي توفير';

  @override
  String get agentToolStopSavingsChallenge => 'إيقاف تحدي توفير';

  @override
  String get agentToolUpdateEmergencyFundBalance => 'تحديث صندوق الطوارئ';

  @override
  String get agentToolAllocateIncome => 'توزيع الدخل';

  @override
  String get agentToolSetSleepWindow => 'مواعيد نومك';

  @override
  String get agentToolLearnSkill => 'تعلّم مهارة';

  @override
  String get agentToolSaveTrustedTechnician => 'حفظ صنايعي';

  @override
  String get agentToolOpenSupportTicket => 'فتح طلب دعم';

  @override
  String get agentToolAnswerSameProduct => 'مطابقة منتج';

  @override
  String get agentToolOther => 'تعديل من زاد';

  @override
  String get agentSourceAppChat => 'شات التطبيق';

  @override
  String get agentSourceTelegram => 'تليجرام';

  @override
  String get agentSourceVoice => 'رسالة صوتية';

  @override
  String get agentSourceConfirm => 'بتأكيد منك';

  @override
  String get agentSourceDaily => 'مراجعة يومية';

  @override
  String get agentSourceEvent => 'حدث تلقائي';

  @override
  String get agentSourceOther => 'زاد';

  @override
  String get undoFailureNewerActionExists =>
      'فيه تعديل أحدث على نفس الحاجة — ارجع فيه هو الأول';

  @override
  String get undoFailureAlreadyUndone => 'ده اترجع فيه قبل كده';

  @override
  String get undoFailureNeverApplied =>
      'ده ماتنفذش أصلاً، فمفيش حاجة ترجع فيها';

  @override
  String get undoFailureNotUndoable => 'ده مينفعش يترجع فيه';

  @override
  String get undoFailureTargetMissing => 'الحاجة دي اتمسحت أو مش موجودة دلوقتي';

  @override
  String get undoFailureNotAllowed => 'فيه مشكلة في الدخول — اطلع وادخل تاني';

  @override
  String get undoFailureOffline => 'مفيش اتصال دلوقتي — جرب لما النت يرجع';

  @override
  String get undoFailureUnknown => 'معرفتش أرجع فيه، جرب تاني';

  @override
  String actionLogUndoAsk(String tool) {
    return 'ترجع في «$tool»؟';
  }

  @override
  String get actionLogUndoWarning =>
      'زاد هيرجّع الحاجة دي زي ما كانت قبل التعديل. مش هتقدر ترجع في الرجوع ده بعدين.';

  @override
  String get actionLogWait => 'استنى';

  @override
  String get actionLogUndo => 'ارجع فيه';

  @override
  String actionLogUndone(String tool) {
    return 'رجعت في «$tool»';
  }

  @override
  String get actionLogTitle => 'سجل تعديلات زاد';

  @override
  String get actionLogLoadFailed => 'مقدرتش أجيب السجل';

  @override
  String get actionLogEmptyTitle => 'لسه مفيش تعديلات';

  @override
  String get actionLogPullRetry => 'اسحب لتحت نجرب تاني.';

  @override
  String get actionLogEmptyBody =>
      'أي حاجة زاد يسجّلها أو يعدّلها لك هتظهر هنا.';

  @override
  String get actionLogApplied => 'اتنفذ';

  @override
  String get actionLogUndoneStatus => 'اترجع فيه';

  @override
  String get actionLogRejected => 'اترفض';

  @override
  String get mutationFieldAmount => 'المبلغ';

  @override
  String get mutationFieldQuantity => 'الكمية';

  @override
  String get mutationFieldRemainingQuantity => 'الكمية المتبقية';

  @override
  String get mutationFieldRemainingBalance => 'المتبقي';

  @override
  String get mutationFieldPrice => 'السعر';

  @override
  String get mutationFieldUnit => 'الوحدة';

  @override
  String get mutationFieldCategory => 'الفئة';

  @override
  String get mutationFieldKind => 'النوع';

  @override
  String get mutationFieldStatus => 'الحالة';

  @override
  String get mutationFieldStartsAt => 'الميعاد';

  @override
  String get mutationFieldTaskDescription => 'التذكير';

  @override
  String get mutationFieldRecurrence => 'التكرار';

  @override
  String get mutationFieldDosage => 'الجرعة';

  @override
  String get mutationFieldDoseTimes => 'مواعيد الجرعات';

  @override
  String get mutationFieldDailyDoseCount => 'جرعات اليوم';

  @override
  String get mutationFieldExpiryDate => 'الصلاحية';

  @override
  String get mutationFieldRenewalDate => 'التجديد';

  @override
  String get mutationFieldDueDay => 'يوم الاستحقاق';

  @override
  String get mutationFieldBillingCycle => 'الدورة';

  @override
  String get mutationFieldIsActive => 'شغّال';

  @override
  String get mutationFieldForPerson => 'لمين';

  @override
  String get mutationFieldPlace => 'المكان';

  @override
  String get mutationFieldNote => 'ملاحظة';

  @override
  String get mutationFieldNotes => 'ملاحظات';

  @override
  String get mutationFieldExpectedCost => 'التكلفة المتوقعة';

  @override
  String get mutationFieldCurrency => 'العملة';

  @override
  String get mutationFieldCountry => 'البلد';

  @override
  String get mutationFieldPayDay => 'يوم القبض';

  @override
  String get mutationFieldBed => 'النوم';

  @override
  String get mutationFieldWake => 'الصحيان';

  @override
  String get mutationFieldDailyCap => 'سقف اليوم';

  @override
  String get mutationFieldLengthDays => 'المدة بالأيام';

  @override
  String get mutationFieldTrade => 'الصنعة';

  @override
  String get mutationFieldMetric => 'المقياس';

  @override
  String get mutationStatusUpcoming => 'جاي';

  @override
  String get mutationStatusDone => 'خلص';

  @override
  String get mutationStatusCancelled => 'اتلغى';

  @override
  String get mutationStatusActive => 'شغّال';

  @override
  String get mutationStatusAbandoned => 'اتوقف';

  @override
  String get mutationEdited => 'اتعدّل';

  @override
  String get mutationRemoved => 'اتشال';

  @override
  String mutationFieldChange(String field, String before, String after) {
    return '$field: $before ← $after';
  }

  @override
  String mutationValueChange(String before, String after) {
    return '$before ← $after';
  }

  @override
  String mutationMore(String shown, int count) {
    return '$shown • و$count كمان';
  }

  @override
  String get mutationYes => 'أيوه';

  @override
  String get mutationNo => 'لأ';

  @override
  String mutationItems(int count) {
    return '$count عناصر';
  }

  @override
  String get mutationListSeparator => '، ';

  @override
  String get whyChangedTitle => 'آخر التغييرات';

  @override
  String get whyChangedSubtitle =>
      'تعديلات زاد الآلية على بياناتك — إيه اتغيّر، وإمتى';

  @override
  String get whyChangedEmpty => 'مفيش تعديلات آلية مسجلة لسه';

  @override
  String get whyChangedNow => 'الآن';

  @override
  String whyChangedMinutesAgo(int minutes) {
    return 'منذ $minutes د';
  }

  @override
  String whyChangedHoursAgo(int hours) {
    return 'منذ $hours س';
  }

  @override
  String whyChangedDaysAgo(int days) {
    return 'منذ $days يوم';
  }

  @override
  String get memoryForgetAsk => 'تنسى الملاحظة دي؟';

  @override
  String get memoryForgetBody => 'زاد مش هيفتكرها تاني في أي رد جاي.';

  @override
  String get memoryForgetYes => 'انساها';

  @override
  String get memoryForgotten => 'اتنسيت';

  @override
  String get memoryClearOutingsAsk => 'تمسح خروجاتك؟';

  @override
  String get memoryClearYes => 'امسحها';

  @override
  String get memoryOutingsCleared => 'اتمسحت خروجاتك';

  @override
  String get memorySaved => 'اتحفظ';

  @override
  String get memoryTitle => 'زاد عارف عني إيه';

  @override
  String get memoryStaleBanner =>
      'مقدرتش أجيب آخر نسخة — اللي قدامك آخر حاجة اتحفظت هنا.';

  @override
  String get memoryNotesHeading => 'اللي زاد فاكره عنك';

  @override
  String get memoryEmptyTitle => 'لسه مفيش ذكريات';

  @override
  String get memoryProfileTitle => 'إنت مين عند زاد';

  @override
  String get memoryProfileSubtitle => 'زاد بيكلمك على أساس ده — عدّله براحتك';

  @override
  String get memoryEdit => 'تعديل';

  @override
  String get memoryLineName => 'بتحب أناديك';

  @override
  String get memoryLineGender => 'النوع';

  @override
  String get memoryLineRole => 'دورك في البيت';

  @override
  String get memoryLineAge => 'العمر';

  @override
  String get memoryLineJob => 'شغلك';

  @override
  String get memoryLinePay => 'القبض';

  @override
  String get memoryLineHousehold => 'البيت';

  @override
  String get memoryLineCity => 'المدينة';

  @override
  String get memoryLineDialect => 'اللهجة';

  @override
  String get memoryDialectDefault => 'زي بلدك وكلامك';

  @override
  String get memoryLineVoice => 'صوت زاد';

  @override
  String get memoryHabitsTitle => 'عاداتك وتحركاتك';

  @override
  String get memoryHabitsSubtitle =>
      'من صرفك وخروجاتك — من غير أماكن ولا إحداثيات';

  @override
  String get memoryHabitsEmpty =>
      'لسه بيتعلم عاداتك — سجّل مصاريفك وهتبان هنا.';

  @override
  String get memoryHabitWeekly => 'متوسط صرفك في الأسبوع';

  @override
  String get memoryHabitTopCategories => 'أكتر حاجات بتصرف عليها';

  @override
  String get memoryHabitBusiestDay => 'أكتر يوم بتصرف فيه';

  @override
  String get memoryHabitSubscriptions => 'اشتراكاتك في الشهر';

  @override
  String get memoryHabitOutings => 'خروجاتك آخر ٣٠ يوم';

  @override
  String get memoryHabitPerOuting => 'متوسط صرف الخروجة';

  @override
  String get memoryHabitTopPlaces => 'أكتر أماكن بتروحها';

  @override
  String get memoryClearOutingsBody =>
      'هنمسح كل الخروجات المتسجلة (أوقات وصرف ومحلات). المصاريف نفسها مش هتتمسح.';

  @override
  String get memoryEmptyBody =>
      'زاد هيتعلم عنك تدريجيًا من كلامك واستخدامك للتطبيق.';

  @override
  String get memoryUnknown => 'لسه مش عارفاه';

  @override
  String memoryHouseholdSize(int count) {
    return '$count أفراد';
  }

  @override
  String memoryKidsCount(int count) {
    return '$count عيال';
  }

  @override
  String memoryPayDay(int day) {
    return 'يوم $day';
  }

  @override
  String memoryOutingsCount(int count) {
    return '$count خروجة';
  }

  @override
  String get memoryClearOutings => 'امسح خروجاتي';

  @override
  String memoryConfirmedTimes(int count) {
    return 'اتأكدت $count مرة';
  }

  @override
  String memoryAbout(String names) {
    return 'عن: $names';
  }

  @override
  String get memoryForgetThis => 'انسى دي';

  @override
  String memoryUntil(String date) {
    return 'لحد $date';
  }

  @override
  String get brainHealthTitle => 'صحة عقل زاد';

  @override
  String get brainHealthRefresh => 'حدّث';

  @override
  String get brainHealthCannotSeeTitle => 'مش شايف العقل دلوقتي';

  @override
  String get brainHealthRetry => 'جرب تاني';

  @override
  String get brainHealthActivity => 'النشاط';

  @override
  String get brainHealthLastProactive => 'آخر تنبيه استباقي';

  @override
  String get brainHealthRuns7d => 'تشغيلات آخر ٧ أيام';

  @override
  String get brainHealthRunsFailed => 'منها فشلت';

  @override
  String get brainHealthInsights7d => 'رؤى آخر ٧ أيام';

  @override
  String get brainHealthInsightsUnseen => 'رؤى لسه مشوفتهاش';

  @override
  String get brainHealthLastFailure => 'نوع آخر عطل';

  @override
  String get brainHealthFailureBusy => 'المزوّد مشغول';

  @override
  String get brainHealthFailureConfig => 'مشكلة إعداد';

  @override
  String get brainHealthFailureOther => 'غير معروف';

  @override
  String get brainHealthTasks => 'المهام والطابور';

  @override
  String get brainHealthTasksStuck => 'مهام واقفة أو متأخرة';

  @override
  String get brainHealthTasksPending => 'مهام مستنية دورها';

  @override
  String get brainHealthTasksFailed7d => 'مهام فشلت آخر ٧ أيام';

  @override
  String get brainHealthNotRetried => 'طلبات ماتعادتش';

  @override
  String get brainHealthChatUse => 'استخدام الشات';

  @override
  String get brainHealthRequests => 'الطلبات';

  @override
  String get brainHealthTokens => 'حجم الردود';

  @override
  String get brainHealthLearning => 'التعلّم';

  @override
  String get brainHealthGoals => 'أهداف زاد شغال عليها';

  @override
  String get brainHealthDrift => 'تصرفات غير متوقعة من زاد آخر ٧ أيام';

  @override
  String get brainHealthHealthy => 'العقل شغال تمام';

  @override
  String get brainHealthQuiet => 'فيه حاجة تستاهل نظرة';

  @override
  String get brainHealthStalled => 'العقل واقف ومحتاج تدخّل';

  @override
  String get brainHealthAllClear =>
      'مفيش أي مشكلة مرصودة. زاد بيشتغل في الخلفية وبيسجّل كل خطوة.';

  @override
  String brainHealthDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count يوم',
      few: '$count أيام',
      two: 'يومين',
      one: 'يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String brainHealthHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ساعة',
      few: '$count ساعات',
      two: 'ساعتين',
      one: 'ساعة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get brainHealthNever => 'ولا مرة';

  @override
  String get brainHealthJustNow => 'دلوقتي';

  @override
  String get brainHealthReasonNoProactiveYet =>
      'زاد لسه بيتعرف عليك، وهيبدأ يبعتلك تنبيهات استباقية بعد شوية استخدام';

  @override
  String brainHealthReasonProactiveSilent(String duration) {
    return 'زاد بطّل يبعت تنبيهات استباقية من $duration';
  }

  @override
  String brainHealthReasonTasksBackedUp(int count) {
    return 'عدد المهام الواقفة أو المتأخرة: $count';
  }

  @override
  String brainHealthReasonRunsFailing(int failed, int total) {
    return 'عدد التشغيلات الفاشلة: $failed من $total';
  }

  @override
  String brainHealthReasonTasksFailed(int count) {
    return 'عدد المهام اللي فشلت: $count';
  }

  @override
  String brainHealthReasonNotRetried(int count) {
    return 'عدد الطلبات اللي ماتعادتش: $count';
  }

  @override
  String brainHealthReasonQuotaNear(int percent) {
    return 'استخدام الشات قرب من الحد اليومي ($percent%) — ممكن الردود تقف لحد بكرة';
  }

  @override
  String get brainHealthCannotSee =>
      'معرفتش أقرا حالة العقل دلوقتي. ده مش معناه إن كل حاجة تمام — معناه إني مش شايف.';

  @override
  String brainHealthOf(int used, int limit) {
    return '$used من $limit';
  }

  @override
  String get brainHealthQuotaNote =>
      'الرصيد ده بتاع ردود الشات بس، وبيتصفّر كل يوم بتوقيت جرينتش — مالوش علاقة بشغل زاد في الخلفية';

  @override
  String get staffTitle => 'فريق زاد';

  @override
  String get brainHubStaffSubtitle =>
      'اللي الموظفين لاحظوه في جولة الصبح على بيتك وفلوسك وعيلتك';

  @override
  String get brainHubMemorySubtitle =>
      'اللي زاد فاكره عنك وبيكلمك على أساسه — صحّحه أو خلّيه ينساه';

  @override
  String get brainGraphTitle => 'شبكة زاد';

  @override
  String get brainMapTitle => 'خريطة زاد';

  @override
  String get brainHubMapSubtitle =>
      'إزاي ميزانيتك واشتراكاتك وبيتك متصلين ببعض';

  @override
  String get brainHubLogSubtitle =>
      'كل حاجة زاد سجّلها أو عدّلها لك، وترجع فيها لو غلط';

  @override
  String get brainHubHealthSubtitle =>
      'زاد شغال في الخلفية ولا واقف — ولو واقف، ليه';

  @override
  String get brainHubTitle => 'عقل زاد';

  @override
  String get brainHubGraphSubtitle =>
      'الناس والأماكن والحاجات اللي زاد عارفها ومترابطة إزاي — وصدّرها لأوبسيديان';

  @override
  String get staffRolePantry => 'أمين المخزن';

  @override
  String get staffRolePharmacy => 'الممرضة';

  @override
  String get staffRoleFinance => 'المحاسب';

  @override
  String get staffRoleFamily => 'سكرتير العيلة';

  @override
  String get staffRoleHome => 'مسؤول البيت';

  @override
  String get staffRoleResearch => 'الباحث';

  @override
  String get staffRoleCoach => 'مدرّب الإعداد';

  @override
  String get staffIntro =>
      'كل صبح الفريق بيلف على بيتك: المخزن، الصيدلية، الفلوس، العيلة، والإعدادات — ويبلّغ زاد باللي محتاج انتباه.';

  @override
  String get staffEmptyTitle => 'الفريق مالقاش حاجة تستاهل';

  @override
  String get staffEmptyBody =>
      'الجولة الجاية الصبح — لو لقوا حاجة هتلاقيها هنا.';

  @override
  String get staffLoadFailed => 'مقدرتش أجيب ملاحظات الفريق';

  @override
  String get profileSheetPayDay => 'بتقبض يوم كام في الشهر؟';

  @override
  String get profileSheetPayFrequency => 'بتقبض كل قد إيه';

  @override
  String get profileSheetHouseholdSize => 'عدد اللي في البيت';

  @override
  String get profileSheetKids => 'عدد العيال';

  @override
  String get profileSheetSave => 'احفظ';

  @override
  String get entityPerson => 'شخص';

  @override
  String get entityPlace => 'مكان';

  @override
  String get entityItem => 'صنف';

  @override
  String get entityOrg => 'جهة';

  @override
  String get entityPeople => 'الناس';

  @override
  String get entityPlaces => 'الأماكن';

  @override
  String get entityItems => 'الأصناف';

  @override
  String get entityOrgs => 'الجهات';

  @override
  String graphNotesCount(int count) {
    return '$count ملاحظة';
  }

  @override
  String graphNoNotesAbout(String name) {
    return 'لسه مفيش ملاحظات عن $name.';
  }

  @override
  String graphSemantics(int count) {
    return 'شبكة فيها $count — القايمة تحتها فيها نفس الحاجات';
  }

  @override
  String get graphExportFailed => 'مقدرتش أجهّز الملفات. جرّب تاني.';

  @override
  String get graphShareSubject => 'شبكة زاد — أوبسيديان';

  @override
  String get graphShareTitle => 'صدّر شبكة زاد';

  @override
  String get graphExport => 'صدّر لأوبسيديان';

  @override
  String get graphEmptyTitle => 'لسه مفيش شبكة';

  @override
  String get graphLoadFailed => 'مقدرتش أجيب الشبكة';

  @override
  String get graphCheckNet => 'اتأكد من النت وجرّب تاني.';

  @override
  String get graphEmptyBody =>
      'كل ما تكلّم زاد عن ناسك وأماكنك وحاجاتك، هيظهروا هنا ويترابطوا ببعض.';

  @override
  String get graphRetry => 'جرّب تاني';

  @override
  String mapPerMonth(String amount) {
    return '$amount/شهر';
  }

  @override
  String mapLeft(String amount) {
    return 'فاضل $amount';
  }

  @override
  String get mapDomainBudget => 'الميزانية';

  @override
  String get mapDomainObligations => 'الالتزامات';

  @override
  String get mapDomainSubscriptions => 'الاشتراكات والأقساط';

  @override
  String get mapDomainDebts => 'الديون';

  @override
  String get mapDomainPantry => 'المخزون';

  @override
  String get mapDomainShopping => 'قائمة التسوق';

  @override
  String get mapDomainPharmacy => 'صيدلية العيلة';

  @override
  String get mapDomainMaintenance => 'الصيانة';

  @override
  String mapAskAbout(String label) {
    return 'وضّحلي أكتر عن $label';
  }

  @override
  String mapNodeCount(int count) {
    return '$count عنصر متصل';
  }

  @override
  String get mapLegendComputed => 'علاقة محسوبة فعليًا';

  @override
  String get mapLegendNotYet => 'لسه برا الحساب';

  @override
  String get mapLegendLive => 'فيه رؤية حية من زاد الآن';

  @override
  String get mapZoomIn => 'تكبير';

  @override
  String get mapZoomOut => 'تصغير';

  @override
  String get mapReset => 'إعادة ضبط';

  @override
  String get mapReserved => 'محجوز';

  @override
  String get mapAvailable => 'متاح';

  @override
  String get mapAskZad => 'اسأل زاد';

  @override
  String get mapNothingHere => 'لا يوجد عناصر هنا حالياً';

  @override
  String get mapOpenScreen => 'فتح الشاشة';

  @override
  String get brainFamilySavingsPots => 'صناديق التجميع';

  @override
  String get brainFamilyAchievements => 'الإنجازات والرتب';

  @override
  String get brainFamilyTasbiha => 'تسبيحة';

  @override
  String get brainFamilyFamily => 'العائلة';

  @override
  String get reportDaySaturday => 'السبت';

  @override
  String get reportDaySunday => 'الأحد';

  @override
  String get reportDayMonday => 'الاثنين';

  @override
  String get reportDayTuesday => 'الثلاثاء';

  @override
  String get reportDayWednesday => 'الأربعاء';

  @override
  String get reportDayThursday => 'الخميس';

  @override
  String get reportDayFriday => 'الجمعة';

  @override
  String get reportHealthExcellent => 'ممتاز 🌟';

  @override
  String get reportHealthGood => 'جيد 👍';

  @override
  String get reportHealthWatch => 'يحتاج انتباه ⚠️';

  @override
  String get reportDanger => 'خطر 🚨';

  @override
  String reportTopSpend(String category, String amount) {
    return 'أعلى إنفاقك هذا الشهر: $category ($amount)';
  }

  @override
  String reportOverBudget(String category, String amount) {
    return '⛔ تجاوزت ميزانية $category بـ$amount';
  }

  @override
  String reportSubsCost(String monthly, String yearly) {
    return 'اشتراكاتك النشطة تكلفك $monthly شهرياً ($yearly سنوياً)';
  }

  @override
  String reportSubsShare(int percent, String title, String amount) {
    return '💡 اشتراكاتك $percent% من ميزانيتك — راجع $title ($amount) لو مش مستخدمه';
  }

  @override
  String reportStreams(int count, String amount) {
    return '📺 عندك $count خدمات بث — إلغاء واحدة يوفر لك $amount شهرياً';
  }

  @override
  String reportRunningOut(String name, int days) {
    return '🛒 $name متوقع يخلص خلال $days يوم';
  }

  @override
  String reportRunway(String perDay, int days) {
    return 'بمعدل إنفاقك الحالي ($perDay/يوم)، الرصيد يكفي $days يوم';
  }

  @override
  String get reportPowerUnknown => 'غير محدد';

  @override
  String get reportPowerStrong => 'قوي 💪';

  @override
  String get reportPowerBalanced => 'متوازن ⚖️';

  @override
  String get reportPowerWeak => 'ضعيف ⚠️';

  @override
  String get reportDayUnknown => 'غير معروف';

  @override
  String reportTooFast(String current, String safe) {
    return '⚡ معدل صرفك اليومي ($current) أعلى من الآمن ($safe) — خفف شوية';
  }

  @override
  String reportSpentLess(int percent, String amount) {
    return '🎉 صرفت $percent% أقل من نفس الفترة الشهر الماضي — وفرت $amount!';
  }

  @override
  String reportSpentMore(int percent) {
    return '📈 صرفك زاد $percent% عن نفس الفترة الشهر الماضي';
  }

  @override
  String reportImpulse(int count) {
    return '🛍️ $count مشتريات اندفاعية آخر 30 يوم (أكبر من ضعف متوسطك)';
  }

  @override
  String get reportExportUnknown => 'لسه غير محدد';

  @override
  String reportExportTitle(String month) {
    return '📊 تقرير زاد المالي — $month';
  }

  @override
  String reportExportHealth(int score, String label) {
    return 'الصحة المالية: $score/100 ($label)';
  }

  @override
  String reportExportPower(String status, String safe) {
    return 'قوة الصرف: $status — الآمن يومياً: $safe';
  }

  @override
  String get reportExportNumbers => '💰 الأرقام:';

  @override
  String reportExportBudget(String amount) {
    return '• الميزانية: $amount';
  }

  @override
  String reportExportSpent(String amount) {
    return '• المصروف: $amount';
  }

  @override
  String reportExportIncome(String amount) {
    return '• الدخل: $amount';
  }

  @override
  String reportExportLeft(String amount) {
    return '• المتبقي: $amount';
  }

  @override
  String reportExportSubs(String amount) {
    return '• الاشتراكات: $amount/شهر';
  }

  @override
  String get reportExportCompare => '📅 مقارنة بالشهر الماضي (نفس الفترة):';

  @override
  String reportExportCompareLine(String now, String before, String delta) {
    return '• هذا الشهر: $now | الماضي: $before ($delta%)';
  }

  @override
  String get reportExportByCategory => '🗂️ حسب الفئة:';

  @override
  String reportExportOfBudget(String budget, int percent) {
    return ' من $budget ($percent%)';
  }

  @override
  String get reportExportTopMerchants => '🏪 أعلى الجهات:';

  @override
  String get reportExportBehaviour => '🧠 سلوكك المالي:';

  @override
  String reportExportTopDay(String day) {
    return '• أكثر يوم صرف: $day';
  }

  @override
  String reportExportWeekend(int percent) {
    return '• صرف الويكند: $percent% من الإجمالي';
  }

  @override
  String reportExportAvgTxn(String amount) {
    return '• متوسط المعاملة: $amount';
  }

  @override
  String reportExportImpulse(int count) {
    return '• مشتريات اندفاعية (30 يوم): $count';
  }

  @override
  String get reportExportNotes => '💡 ملاحظات زاد:';

  @override
  String get reportExportFooter => '— تقرير من تطبيق زاد 🥕';

  @override
  String get reportScreenTitle => 'تقرير زاد الشهري';

  @override
  String get reportShareFamily => 'شارك مع العيلة';

  @override
  String get reportHealthHeading => 'الصحة المالية';

  @override
  String get reportButton => 'التقرير الشهري';

  @override
  String get reportShareSubject => 'تقرير زاد المالي';

  @override
  String get reportShareTitle => 'مشاركة تقرير زاد';

  @override
  String get intelPromptAnalyse => 'حلل مصاريفي 📊';

  @override
  String get intelPromptForecast => 'توقع مصاريف الشهر القادم 🔮';

  @override
  String get intelPromptLunch => 'اقترح وجبة للغداء 🍲';

  @override
  String get intelPromptSafe => 'هل وضعي المالي آمن؟ 💰';

  @override
  String intelSosFrom(String name) {
    return 'نداء طوارئ من $name!';
  }

  @override
  String get intelNeedThreeBody =>
      'يحتاج عقل زاد إلى 3 مصاريف على الأقل لتحليل سلوكك المالي بدقة وتوليد تقارير الصمود المالي.';

  @override
  String intelLoggedOfThree(int count) {
    return 'تم تسجيل $count من 3 مصاريف';
  }

  @override
  String get intelReportSubtitle =>
      'تحليل فوري دقيق لجميع حركاتك ومصروفاتك عبر نماذج الذكاء الاصطناعي';

  @override
  String get intelReportWorking =>
      'جاري تحليل الحركات وتوليد التقرير بالذكاء الاصطناعي...';

  @override
  String intelCoverageDays(int days) {
    return '$days يوم تغطية';
  }

  @override
  String intelTargetDays(int days) {
    return 'الهدف: $days يوم';
  }

  @override
  String intelSaveToReach(String amount) {
    return 'وفّر $amount شهرياً للوصول للهدف';
  }

  @override
  String intelTopCategory(String category, int percent) {
    return '💡 أعلى استهلاك في فئة [$category] بنسبة $percent% من إجمالي مصروفاتك';
  }

  @override
  String get intelHeroTitle => 'عقل زاد الذكي';

  @override
  String get intelHeroBusy => 'زاد يحلل بياناتك الآن 🧠✨';

  @override
  String get intelHeroReady =>
      'متصل ومستعد لمساعدتك في إدارتك المالية والمنزلية ⚡';

  @override
  String get intelNoAnswer => 'زاد مقدرش يرد دلوقتي — جرّب تاني.';

  @override
  String get intelAnalysing => 'زاد يقوم بالتحليل...';

  @override
  String get intelExplain => 'اشرح بالذكاء الاصطناعي';

  @override
  String get intelNeedThreeTitle => 'سجل أول 3 مصاريف لتفعيل عقل زاد التحليلي';

  @override
  String get intelTalkNow => 'تحدث مع زاد الآن 💬';

  @override
  String get intelReportTitle => 'توليد تقرير الذكاء الاصطناعي الشامل';

  @override
  String get intelSharePdf => 'مشاركة التقرير PDF';

  @override
  String get intelSaveFailed =>
      'تعذر حفظ التغييرات — تحقق من الاتصال وحاول مرة أخرى';

  @override
  String get intelRetry => 'إعادة المحاولة';

  @override
  String get intelRefreshReport => 'تحديث التقرير 🔄';

  @override
  String get intelUpdateBalance => 'تحديث الرصيد';

  @override
  String get intelFundBalance => 'رصيد صندوق الطوارئ';

  @override
  String get intelCancel => 'إلغاء';

  @override
  String get intelSave => 'حفظ';

  @override
  String get intelStatusCritical => 'حرج';

  @override
  String get intelStatusLow => 'منخفض';

  @override
  String get intelStatusHealthy => 'صحي';

  @override
  String get intelStressTitle => 'اختبار الصمود المالي';

  @override
  String get intelStressQuestion => 'كم يوماً تستطيع الصمود لو توقف دخلك؟';

  @override
  String get intelAvailableNoFund =>
      'رصيدك المتاح حالياً (لسه محددتش صندوق طوارئ)';

  @override
  String get intelDailyAverage => 'متوسط الصرف اليومي';

  @override
  String get intelDistributionTitle => 'توزيع المصروفات والملاحظات السلوكية';

  @override
  String get intelDistributionSubtitle =>
      'تحليل نسب الصرف على الفئات والملاحظات السلوكية الذكية';

  @override
  String dossierIssued(String date) {
    return 'تاريخ الإصدار: $date';
  }

  @override
  String get dossierSafeDailyUnknown =>
      '• معدل الصرف اليومي الآمن: محتاج ميزانية ورصيد محدّدين عشان يتحسب.';

  @override
  String dossierSafeDaily(String amount) {
    return '• معدل الصرف اليومي الآمن الموصى به: $amount/يوم.';
  }

  @override
  String dossierSpentCycle(String amount) {
    return '• إجمالي الصرف الفعلي للدورة الحالية: $amount.';
  }

  @override
  String dossierFamilyMembers(int count) {
    return '• عقل العائلة المشترك: $count أفراد متصلين ومزامنين لحظياً.';
  }

  @override
  String dossierLowStock(int count) {
    return '• أصناف قاربت على النفاد في المخزون: $count صنف.';
  }

  @override
  String dossierAdherence(int percent) {
    return '• الالتزام الدوائي هذا الأسبوع: $percent%.';
  }

  @override
  String get dossierAdherenceUnknown =>
      '• الالتزام الدوائي: لسه مفيش جرعات كفاية مسجّلة لحساب نسبة.';

  @override
  String get dossierShareHeading => '📄 تقرير عقل زاد:';

  @override
  String dossierShareSpent(String amount) {
    return '• إجمالي الصرف: $amount';
  }

  @override
  String dossierShareAdherence(int percent) {
    return '• الالتزام الدوائي: $percent%';
  }

  @override
  String get dossierTitle => 'التقرير الاستراتيجي الشامل لعقل زاد';

  @override
  String get dossierSection1 => '1. التنبؤات والتدفق المالي للشهر القادم';

  @override
  String get dossierSection2 => '2. كفاءة إدارة المنزل والعائلة';

  @override
  String get dossierShareTitle => 'مشاركة تقرير عقل زاد';

  @override
  String get dossierShare => '📤 مشاركة التقرير';

  @override
  String get dossierClose => 'إغلاق التقرير';

  @override
  String get weekdaySat => 'السبت';

  @override
  String get weekdaySun => 'الأحد';

  @override
  String get weekdayMon => 'الاتنين';

  @override
  String get weekdayTue => 'التلات';

  @override
  String get weekdayWed => 'الأربع';

  @override
  String get weekdayThu => 'الخميس';

  @override
  String get weekdayFri => 'الجمعة';

  @override
  String behaviourNew(String name, String amount) {
    return '$name: جديد الشهر ده ($amount)';
  }

  @override
  String behaviourUp(String name, int percent, String before, String after) {
    return '$name: زادت $percent٪ ($before ← $after)';
  }

  @override
  String behaviourDown(String name, int percent, String before, String after) {
    return '$name: قلّت $percent٪ ($before ← $after)';
  }

  @override
  String behaviourPeakDay(String day, String amount) {
    return 'أكتر يوم بتصرف فيه: $day — متوسط $amount';
  }

  @override
  String behaviourPlaceLine(String amount, int count) {
    return '$amount · $count مرة';
  }

  @override
  String get behaviourTitle => 'سلوكك في الصرف';

  @override
  String get behaviourTopPlaces => 'أكتر أماكن بتصرف فيها';

  @override
  String get behaviourChanges => 'اتغيّر إيه عن الشهر اللي فات';

  @override
  String get chartsTwoWeeks => 'صرفك آخر أسبوعين';

  @override
  String chartsTotals(String total, String daily) {
    return 'الإجمالي $total · متوسط اليوم $daily';
  }

  @override
  String get chartsWhere => 'صرفك راح فين (آخر شهر)';

  @override
  String get reportsRowFailed => 'مقدرتش أجهّز التقرير دلوقتي';

  @override
  String get reportsRowMonthly => 'تصدير التقرير الشهري';

  @override
  String get reportsRowStrategic => 'التقرير الاستراتيجي';

  @override
  String get familyTitle => 'العيلة';

  @override
  String get familyLoadingTitle => 'بنشوف عيلتك';

  @override
  String get familyLoadingMessage => 'أول مرة محتاجة نت. اسحب لتحت لو طوّلت.';

  @override
  String get familyRetry => 'جرّب تاني';

  @override
  String get familyWelcomeTitle => 'أهلاً بك في عائلة زاد';

  @override
  String get familyWelcomeBody =>
      'يمكنك إنشاء عائلة جديدة لتكون أنت المدير، أو الانضمام لعائلة موجودة عبر كود الدعوة.';

  @override
  String get familyCreateAsAdmin => 'إنشاء عائلة جديدة كمدير (Admin)';

  @override
  String get familyJoin => 'الانضمام للعائلة';

  @override
  String get familyOr => 'أو';

  @override
  String get familyAliasLabel => 'اسمك في العيلة (اختياري)';

  @override
  String get familyAliasHint => 'مثال: الابن أحمد';

  @override
  String get familyInviteCodeLabel => 'كود الدعوة';

  @override
  String get familyInviteCodeHint => 'مثال: ZAD-1234';

  @override
  String get familyTabChat => 'الشات';

  @override
  String get familyTabTasks => 'المهام';

  @override
  String get familyTabMembers => 'الأعضاء';

  @override
  String get familyTabGroceries => 'البقالة';

  @override
  String get familyTabKids => 'الأبناء';

  @override
  String get familyTabGoals => 'الأهداف';

  @override
  String familyHeaderTitle(String code) {
    return 'عائلة $code';
  }

  @override
  String familyMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count أفراد',
    );
    return '$_temp0';
  }

  @override
  String get familySosTooltip => 'الرجاء الانتباه، حالة طوارئ!';

  @override
  String get familyInviteNew => 'دعوة أفراد جدد';

  @override
  String get familyShareInvite => 'مشاركة الدعوة';

  @override
  String familyShareInviteText(String code, String link) {
    return '🌱 دعوة للانضمام إلى عائلتي على تطبيق زاد\n\n📲 اضغط على الرابط التالي للانضمام فوراً وفتح التطبيق:\nhttps://zad.app/invite?code=$code\n\n🔑 كود الدعوة المباشر:\n$code\n\n🔗 رابط التطبيق المباشر:\n$link';
  }

  @override
  String get familySosConfirmTitle => 'تأكيد نداء الطوارئ';

  @override
  String get familySosConfirmBody =>
      'هيتبعت تنبيه فوري لكل أفراد العائلة إنك محتاج مساعدة. متأكد؟';

  @override
  String get familySosSend => 'أرسل النداء';

  @override
  String familyInviteShareText(String code, String link) {
    return 'انضم إلى عائلتي في تطبيق زاد!\nكود الدعوة: $code\nأو افتح الرابط: $link';
  }

  @override
  String familyInviteShareQr(String link) {
    return 'انضم إلى عائلتي في تطبيق زاد! امسح الرمز: $link';
  }

  @override
  String familyInviteShareLink(String link) {
    return 'انضم إلى عائلتي في تطبيق زاد!\nرابط الدعوة: $link';
  }

  @override
  String familyInviteShareCode(String code) {
    return 'انضم إلى عائلتي في تطبيق زاد!\nكود الدعوة: $code';
  }

  @override
  String get familyInviteMethodLink => 'رابط';

  @override
  String get familyInviteMethodCode => 'كود';

  @override
  String get familyInviteMethodWhatsapp => 'واتساب';

  @override
  String get familyInviteScanToJoin => 'مسح الرمز للانضمام:';

  @override
  String get familyInviteLinkLabel => 'رابط الدعوة:';

  @override
  String get familyCopy => 'انسخ';

  @override
  String get familyInviteCodeColon => 'كود الدعوة:';

  @override
  String get familyInviteShareWhatsapp => 'شارك عبر واتساب:';

  @override
  String get familyInviteAllApps => 'جميع التطبيقات';

  @override
  String get familyShare => 'مشاركة';

  @override
  String get familyPasteInvite => 'الصق رابط أو كود الدعوة';

  @override
  String get familyAddTaskTitle => 'إضافة مهمة جديدة';

  @override
  String get familyTaskNameLabel => 'اسم المهمة';

  @override
  String get familyTaskNameHint => 'مثال: ترتيب الغرفة';

  @override
  String get familyReward => 'المكافأة';

  @override
  String familyRewardIn(String currency) {
    return 'المكافأة ($currency)';
  }

  @override
  String get familyAssignee => 'المكلف بالمهمة:';

  @override
  String get familyDueDateOptional => 'تاريخ التسليم (اختياري)';

  @override
  String get familyQuickGroceryTitle => 'نزّلها في التسوق';

  @override
  String get familyQuickGroceryHint => 'مثلاً: حليب';

  @override
  String get familyMoneyRequestTitle => 'طلب مصروف أو مشتريات';

  @override
  String get familyMoneyRequestWhat => 'ماذا تريد أن تشتري؟';

  @override
  String get familyMoneyRequestAmount => 'المبلغ المطلوب';

  @override
  String familyMoneyRequestAmountIn(String currency) {
    return 'المبلغ المطلوب ($currency)';
  }

  @override
  String get familyMoneyRequestSend => 'إرسال الطلب';

  @override
  String get familySpendLimitTitle => 'حد الإنفاق';

  @override
  String familySpendLimitBody(String name) {
    return 'حدد أقصى مبلغ يقدر $name يصرفه يومياً/أسبوعياً. اتركه فارغاً لإلغاء الحد.';
  }

  @override
  String familyDailyLimitIn(String currency) {
    return 'الحد اليومي ($currency)';
  }

  @override
  String familyWeeklyLimitIn(String currency) {
    return 'الحد الأسبوعي ($currency)';
  }

  @override
  String get familyPollClosesTomorrow => 'بكرة';

  @override
  String get familyPollClosesTwoDays => 'بعد يومين';

  @override
  String get familyPollClosesWeek => 'بعد أسبوع';

  @override
  String get familyPollClosesByHand => 'أنا أقفله';

  @override
  String get familyPollTitle => 'تصويت عائلي';

  @override
  String get familyPollQuestion => 'السؤال';

  @override
  String familyPollOption(int n) {
    return 'خيار $n';
  }

  @override
  String get familyPollAddOption => '+ إضافة خيار';

  @override
  String get familyPollClosesWhen => 'يتقفل إمتى؟';

  @override
  String get familyPollSend => 'إرسال التصويت';

  @override
  String get familyTasksHeading => 'المهام العائلية';

  @override
  String familyTasksDoneOf(int done, int total) {
    return '$done/$total منجزة';
  }

  @override
  String get familyFilterAll => 'الكل';

  @override
  String get familyFilterPending => 'قادمة';

  @override
  String get familyFilterDone => 'منجزة';

  @override
  String get familyNoTasksTitle => 'لا توجد مهام';

  @override
  String get familyNoTasksMessage => 'ضيف مهمة عشان أفراد العائلة يشاركوا فيها';

  @override
  String get familyMembersHeading => 'أفراد العائلة';

  @override
  String get familyMembersHint => 'اضغط على أي عضو لتفاصيل إنجازاته';

  @override
  String get familyReport => 'تقرير العيلة';

  @override
  String get familyDeleteAndRecreate => 'حذف العائلة وإعادة الإنشاء';

  @override
  String get familyLeave => 'مغادرة العائلة';

  @override
  String get familyDeleteForeverTitle => 'حذف العائلة نهائياً';

  @override
  String get familyLeaveConfirmTitle => 'تأكيد المغادرة';

  @override
  String get familyDeleteForeverBody =>
      'إنت آخر فرد في العائلة دي. حذفها هيمسح الشات والمهام وكل البيانات نهائياً ومينفعش ترجعها، وتقدر تنشئ عائلة جديدة بعد كده.';

  @override
  String get familyLeaveConfirmBody =>
      'هتفقد الوصول لشات العائلة والمهام والأرصدة المشتركة. متأكد إنك عايز تغادر العائلة؟';

  @override
  String get familyDeleteForever => 'حذف نهائي';

  @override
  String get familyLeaveShort => 'مغادرة';

  @override
  String familyTasksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مهام',
    );
    return '$_temp0';
  }

  @override
  String familyTasbihaCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تسبيحة',
    );
    return '$_temp0';
  }

  @override
  String get familySavingsGoal => 'هدف التوفير';

  @override
  String get familyRoleAdminShort => 'مدير';

  @override
  String get familyRoleChild => 'ابن/ابنة';

  @override
  String get familyRoleAdminLong => 'مدير العائلة';

  @override
  String get familyRoleMember => 'عضو';

  @override
  String get familyBalance => 'الرصيد';

  @override
  String get familyGoal => 'الهدف';

  @override
  String get familyTrees => 'الأشجار';

  @override
  String familyDoneTasksTitle(int count) {
    return 'المهام المنجزة ($count)';
  }

  @override
  String get familyNoDoneTasks => 'لا توجد مهام منجزة بعد';

  @override
  String familyUpcomingTasksTitle(int count) {
    return 'المهام القادمة ($count)';
  }

  @override
  String get familyNoUpcomingTasks => 'لا توجد مهام قادمة';

  @override
  String familyTreesTitle(int count) {
    return 'أشجار التسبيحة ($count)';
  }

  @override
  String get familyDaily => 'اليومي';

  @override
  String get familyWeekly => 'الأسبوعي';

  @override
  String get familyRoleInFamily => 'الدور في العيلة';

  @override
  String familyRemoveMemberTitle(String name) {
    return 'تشيل $name من العيلة؟';
  }

  @override
  String get familyRemoveMemberShort => 'شيله';

  @override
  String get familyRemoveMember => 'شيله من العيلة';

  @override
  String familyRewardAmount(String amount) {
    return 'مكافأة: $amount';
  }

  @override
  String get familyNoLimit => 'بدون حد';

  @override
  String get familyGroceriesHeading => 'البقالة المشتركة';

  @override
  String get familyGroceriesHint =>
      'قائمة المشتريات التي تمت إضافتها من قبل أفراد العائلة أو اقترحها زاد.';

  @override
  String get familyNoGroceriesTitle => 'لا توجد طلبات بقالة حالياً.';

  @override
  String get familyNoGroceriesMessage =>
      'اكتب في الشات \"أضف حليب\" أو دوس + فوق.';

  @override
  String get familyKidsHeading => 'مصاريف الأبناء';

  @override
  String get familyKidsHint => 'نظرة عامة على أرصدة وطلبات الأبناء';

  @override
  String get familyNoKidsTitle => 'لا يوجد أبناء مسجلين بعد';

  @override
  String get familyNoKidsMessage => 'من تاب الأعضاء خلّي أي فرد \"طفل\".';

  @override
  String get familyPauseTitle => 'وقفة تفكير ٢٤ ساعة';

  @override
  String get familyPauseBody =>
      'طلب الشرا مايتوافقش عليه قبل يوم من ما اتبعت. الرفض في أي وقت، وطلب المصروف مش متأثر.';

  @override
  String familyAllowanceFor(String name) {
    return 'مصروف لـ$name';
  }

  @override
  String familyAmountIn(String currency) {
    return 'المبلغ ($currency)';
  }

  @override
  String get familyAllowanceHelper => 'بيتضاف لرصيده على طول';

  @override
  String get familyTransfer => 'حوّل';

  @override
  String familyBalanceIs(String amount) {
    return 'الرصيد: $amount';
  }

  @override
  String familyGoalIs(String amount) {
    return 'الهدف: $amount';
  }

  @override
  String familyKidTasksDoneOf(int done, int total) {
    return '$done/$total مهام';
  }

  @override
  String get familySendAllowance => 'حوّل مصروف';

  @override
  String get familyMonthlySpending => 'المصروف الشهري';

  @override
  String familyPendingRequests(int count) {
    return 'الطلبات المعلقة ($count)';
  }

  @override
  String get familyApprove => 'موافقة';

  @override
  String get familyReject => 'رفض';

  @override
  String get familyBudgetRewardsHeading => 'الميزانية والمكافآت';

  @override
  String get familySavingsGoalTitle => 'هدف الادخار العائلي';

  @override
  String get familyNoSavingsGoal => 'لسه مفيش هدف ادخار للشهر ده';

  @override
  String get familySuggestGoal => 'اقترح هدف بالذكاء الاصطناعي';

  @override
  String get familyNoKidsStatsTitle => 'لا يوجد أبناء مضافين لعرض إحصائياتهم.';

  @override
  String get familyKidsBalanceStats => 'إحصائيات أرصدة الأبناء';

  @override
  String get familyTotalRewardsPaid => 'إجمالي المكافآت المدفوعة';

  @override
  String familyGoalSuggestionBody(String amount, int days) {
    return 'الهدف: $amount خلال $days يوم';
  }

  @override
  String get familyApproveGoal => 'اعتماد الهدف';

  @override
  String get familyChatEmptyTitle => 'لا توجد رسائل بعد';

  @override
  String get familyChatEmptyMessage => 'ابدأ المحادثة بإرسال أول رسالة لعائلتك';

  @override
  String get familyChatAddTasks => 'أضف مهام';

  @override
  String get familyChatAskGroceries => 'اطلب بقالة';

  @override
  String get familyChatAskZad => 'استشر @Zad';

  @override
  String get familyZadName => 'زاد';

  @override
  String get familyVoiceMessage => 'رسالة صوتية';

  @override
  String get familyUnpin => 'إلغاء التثبيت';

  @override
  String get familyPin => 'تثبيت';

  @override
  String get familyReact => 'تفاعل';

  @override
  String familySosFrom(String name) {
    return 'نداء طوارئ من $name!';
  }

  @override
  String familyPurchaseRequestFrom(String name) {
    return 'طلب شراء من $name';
  }

  @override
  String get familyApproveAndDeduct => 'موافقة وخصم';

  @override
  String get familyApproved => 'تمت الموافقة';

  @override
  String get familyRejected => 'مرفوض';

  @override
  String familyPollFrom(String name) {
    return 'تصويت من $name';
  }

  @override
  String familyPollTimeCloses(String time, String when) {
    return '$time · بيقفل $when';
  }

  @override
  String get familyPollClose => 'اقفل التصويت';

  @override
  String get familyPollClosedNoVotes => 'اتقفل من غير أصوات';

  @override
  String get familyPollClosedTie => 'اتقفل بتعادل — القرار لكم';

  @override
  String familyPollAdultsAgreed(String option) {
    return 'الكبار كلهم اتفقوا على «$option» ✅';
  }

  @override
  String familyPollMajority(String option) {
    return 'الأغلبية اختارت «$option»';
  }

  @override
  String get familyClosesWithinHour => 'خلال ساعة';

  @override
  String familyClosesInHours(int hours) {
    return 'بعد $hours ساعة';
  }

  @override
  String get familyClosesTomorrow => 'بكرة';

  @override
  String familyClosesInDays(int days) {
    return 'بعد $days أيام';
  }

  @override
  String get familyQuickReplies => 'ردود سريعة';

  @override
  String get familySosShort => 'نداء طوارئ';

  @override
  String get familyAskMoney => 'طلب مصروف';

  @override
  String get familyPollShort => 'تصويت';

  @override
  String get familyChatHint => 'اكتب رسالة أو @Zad...';

  @override
  String get familySend => 'إرسال';

  @override
  String get familySomeoneInFamily => 'حد من العيلة';

  @override
  String familyLocationDisclosure(String asker) {
    return 'زاد هيعرف لما تدخل أو تخرج من الأماكن اللي $asker يحددها (زي المدرسة) — حتى والتطبيق مقفول — ويقوله لو خرجت في المواعيد اللي حددها. مش هيتبعت مكانك طول الوقت ولا خط سيرك. هيفضل فيه إشعار ظاهر طول ما المشاركة شغالة، وتقدر توقفها من «عيلتي» في أي وقت. في الخطوة الجاية اختار «السماح طول الوقت».';
  }

  @override
  String get familyServerUnreachable => 'مقدرتش أوصل للسيرفر. جرّب تاني.';

  @override
  String get familyShareComingGoingTitle => 'مشاركة دخولك وخروجك';

  @override
  String get familyNotNow => 'مش دلوقتي';

  @override
  String get familyAgreeContinue => 'موافق، كمّل';

  @override
  String get familyAcceptedNeedAlways =>
      'وافقت، بس محتاج «السماح طول الوقت» للموقع عشان يشتغل والتطبيق مقفول.';

  @override
  String get familyAcceptedZones => 'وافقت — هيشتغل على الأماكن اللي هيحددها.';

  @override
  String get familyAcceptedOffline => 'وافقت. هكمّل لما النت يرجع.';

  @override
  String get familyFollowRequests => 'طلبات متابعة';

  @override
  String get familyFollowRequestsHint =>
      'محدش بيشوف حاجة غير بموافقتك، وتقدر تلغي في أي وقت.';

  @override
  String get familyDeclinedFollow => 'تمام، مش هيشوفها.';

  @override
  String get familyNo => 'لأ';

  @override
  String familyAcceptedScope(String scope) {
    return 'وافقت — يقدر يتابع $scope.';
  }

  @override
  String get familyAgree => 'وافق';

  @override
  String get familyWhoFollowsYou => 'مين بيتابعك';

  @override
  String get familyFollowStopped => 'اتلغت المتابعة.';

  @override
  String get familyFollowRequestSent => 'اتبعت الطلب — هيظهرلك لما يوافق.';

  @override
  String get familyFollowRequestFailed => 'مقدرتش أبعت الطلب. جرّب تاني.';

  @override
  String get familyFollowing => 'المتابعة';

  @override
  String get familyFollowLoadFailed => 'مقدرتش أجيب المتابعة دلوقتي.';

  @override
  String get familyFollowLoading => 'بجيب اللي متشارك…';

  @override
  String familyScopeStatus(String scope, String status) {
    return '$scope: $status';
  }

  @override
  String get familyShareNotAsked => 'مش متطلبة';

  @override
  String get familySharePending => 'مستني موافقته';

  @override
  String get familyShareGranted => 'وافق ✅';

  @override
  String get familyShareDeclined => 'رفض';

  @override
  String get familyShareRevoked => 'اتلغت';

  @override
  String get familyAskToFollow => 'اطلب متابعة';

  @override
  String get familyWhatToFollow => 'عايز تتابع إيه؟';

  @override
  String get familyWhatToFollowHint =>
      'هيوصله طلب ويختار هو. مفيش حاجة هتبان قبل موافقته.';

  @override
  String get familySendRequest => 'ابعت الطلب';

  @override
  String get familyDoseMissed => '❌ فاتت';

  @override
  String get familyDoseDue => '⏰ وقتها';

  @override
  String familyDoseNoTimes(String name) {
    return '$name: من غير مواعيد';
  }

  @override
  String get familyMedicinesToday => 'الأدوية النهارده';

  @override
  String get familyNoMedicines => 'مفيش أدوية متسجلة.';

  @override
  String get familySpendingLast30 => 'المصروف آخر ٣٠ يوم';

  @override
  String get familyTasksAndAppointments => 'المهام والمواعيد';

  @override
  String get familyNoOpenTasks => 'مفيش مهام مفتوحة';

  @override
  String familyOpenTasksStill(int count) {
    return '$count مهام لسه مفتوحة';
  }

  @override
  String get familyReportLoading => 'بجيب…';

  @override
  String familyReportMissedSuffix(int count) {
    return ' — $count فاتت';
  }

  @override
  String get familyReportNoDosesToday => 'مفيش جرعات النهارده';

  @override
  String familyReportDoses(int taken, int total, String late) {
    return 'جرعات: $taken من $total$late';
  }

  @override
  String familyReportSpent30(String amount) {
    return 'صرف ٣٠ يوم: $amount';
  }

  @override
  String familyReportOpenTasks(int count) {
    return '$count مهام مفتوحة';
  }

  @override
  String familyZoneInside(String place) {
    return 'جوه $place';
  }

  @override
  String familyZoneLeft(String place) {
    return 'خرج من $place';
  }

  @override
  String familyZoneUnknown(String place) {
    return '$place: لسه';
  }

  @override
  String get familyReportNothingShared => 'لسه ماوافقش على أي متابعة';

  @override
  String familyReportNotShared(String scopes) {
    return 'مش متشارك: $scopes';
  }

  @override
  String get familyListSeparator => '، ';

  @override
  String get familyReportHint =>
      'اللي كل فرد وافق يشاركه بس — والباقي بيبان بعد موافقته.';

  @override
  String get familyReportNoMembers =>
      'لسه محدش انضم للعيلة. ابعت كود الدعوة من «عيلتي».';

  @override
  String get familyMemberFallback => 'فرد من العيلة';

  @override
  String familyWeekday(String day) {
    String _temp0 = intl.Intl.selectLogic(day, {
      'd0': 'الأحد',
      'd1': 'الاتنين',
      'd2': 'التلات',
      'd3': 'الأربع',
      'd4': 'الخميس',
      'd5': 'الجمعة',
      'd6': 'السبت',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get familyZoneNoMoves => 'لسه مفيش دخول ولا خروج';

  @override
  String familyZoneInsideSince(String day, String time) {
    return 'جوه من $day$time';
  }

  @override
  String familyZoneLeftAt(String day, String time) {
    return 'خرج $day$time';
  }

  @override
  String familyZoneSaved(String place) {
    return 'اتحفظ «$place» — هيوصله إشعار بيه.';
  }

  @override
  String get familyZoneSaveFailed => 'مقدرتش أحفظ النطاق. جرّب تاني.';

  @override
  String familyZoneRemoved(String place) {
    return 'اتشال «$place».';
  }

  @override
  String get familyZoneRemoveFailed => 'مقدرتش أشيله. جرّب تاني.';

  @override
  String get familyPlaces => 'الأماكن';

  @override
  String get familyNoZones =>
      'لسه مفيش نطاقات. وانت في المدرسة نفسها، دوس «ضيف نطاق».';

  @override
  String get familyRemoveZone => 'شيل النطاق';

  @override
  String get familyAddZone => 'ضيف نطاق';

  @override
  String get familyZoneSchool => 'مدرسة';

  @override
  String get familyZoneClub => 'نادي';

  @override
  String get familyZoneHome => 'البيت';

  @override
  String get familyZoneOther => 'مكان تاني';

  @override
  String get familyLocationFailed =>
      'مقدرتش أعرف مكانك. شغّل الموقع وجرّب تاني.';

  @override
  String get familyNewZone => 'نطاق جديد';

  @override
  String get familyNewZoneHint =>
      'هيوصلك تنبيه لو خرج منه في الأيام والساعات دي. برّاها بيتسجل من غير تنبيه.';

  @override
  String get familyZoneNameLabel => 'اسمه';

  @override
  String get familyZoneNameHint => 'مدرسة النيل';

  @override
  String get familyUseMyLocation => 'استخدم المكان اللي أنا فيه دلوقتي';

  @override
  String get familyLocationSet => 'اتحدد المكان ✓ — دوس تاني لو اتحركت';

  @override
  String get familyBeThere => 'لازم تكون في المكان نفسه وانت بتحدده.';

  @override
  String get familyZoneRadius => 'قد إيه حواليه';

  @override
  String familyMeters(int meters) {
    return '$meters م';
  }

  @override
  String get familyAlertDays => 'أيام التنبيه';

  @override
  String get familyAlertHours => 'ساعات التنبيه';

  @override
  String familyFromTime(String time) {
    return 'من $time';
  }

  @override
  String familyToTime(String time) {
    return 'لحد $time';
  }

  @override
  String get familyHoursOrder => 'ساعة البداية لازم تبقى قبل النهاية.';

  @override
  String get familySaveZone => 'احفظ النطاق';

  @override
  String get familyChatReadingDisclosure =>
      'زاد هيقرا رسايلك انت بس في شات العيلة — مش رسايل حد تاني ماوافقش — عشان يفهم طلبات البيت زي «محتاجين عيش» ويرد لو حد من العيلة سأله عن اللي اتقال. الرسايل بتتبعت لموديل ذكاء اصطناعي (Google Gemini) عشان تتفهم. العيلة كلها هتشوف إنك موافق، وتقدر توقف في أي وقت من هنا.';

  @override
  String get familyChatReadingTitle => 'زاد يقرا رسايلك؟';

  @override
  String get familyAgreeShort => 'موافق';

  @override
  String get familyChatReadingOn => 'تمام — زاد هيقرا رسايلك.';

  @override
  String get familyChatReadingOff => 'وقفت — زاد مش هيقرا رسايلك.';

  @override
  String get familyChatReadingNone => 'زاد مش بيقرا رسايل الشات';

  @override
  String familyChatReadingWho(String names) {
    return 'زاد بيقرا رسايل: $names';
  }

  @override
  String get familyChatReadingStopMine => 'وقّف لرسايلي';

  @override
  String get familyChatReadingAllowMine => 'خلّيه يقرا رسايلي';

  @override
  String get profileTitle => 'حسابي';

  @override
  String get profileSectionBrain => 'عقل زاد';

  @override
  String get profileMemoryTitle => 'زاد عارف عني إيه';

  @override
  String get profileMemorySubtitle =>
      'زاد بيتعلم من صرفك ومخزونك عشان يساعدك — شوف اللي اتعلمه وامسح أي حاجة';

  @override
  String get profileActionLogTitle => 'سجل تعديلات زاد';

  @override
  String get profileActionLogSubtitle => 'كل حاجة زاد سجّلها أو عدّلها لك';

  @override
  String get profileAlertsTitle => 'تنبيهات المساعد الذكي';

  @override
  String get profileAlertsSubtitle => 'التحكم في التنبيهات الذكية';

  @override
  String get profileNewGoalTitle => 'هدف حياة جديد';

  @override
  String get profileNewGoalSubtitle => 'خلّي زاد يتابع معاك هدف توفير أو عادة';

  @override
  String get profileSectionMeFamily => 'أنا وعيلتي';

  @override
  String get profileEditTitle => 'تعديل الملف الشخصي';

  @override
  String get profileEditSubtitle => 'الاسم أو اللقب';

  @override
  String get profileFamilyManageTitle => 'إدارة العائلة';

  @override
  String get profileFamilyManageSubtitle => 'الأعضاء والصلاحيات';

  @override
  String get profileRegionalTitle => 'الإعدادات الإقليمية';

  @override
  String get profileRegionalSubtitle => 'البلد والعملة';

  @override
  String get profileSectionMoney => 'فلوسي';

  @override
  String get profileBudgetPaymentTitle => 'الميزانية وطرق الدفع';

  @override
  String get profileBudgetPaymentSubtitle => 'الميزانية الشهرية والربط البنكي';

  @override
  String get profileStatementTitle => 'استيراد كشف حساب';

  @override
  String get profileStatementSubtitle => 'استورد كشف حساب CSV من البنك';

  @override
  String get profileSectionMyZad => 'زاد بتاعي';

  @override
  String get profileAchievementsTitle => 'الإنجازات والرتب';

  @override
  String get profileAchievementsSubtitle =>
      'نقاطك وإنجازاتك من المساهمة بالأسعار';

  @override
  String get profileSectionHelp => 'المساعدة';

  @override
  String get profileSupportTitle => 'الدعم الفني';

  @override
  String get profileSupportSubtitle => 'شكوى أو مشكلة؟ كلّم فريق الدعم';

  @override
  String get profileTermsTitle => 'الشروط والأحكام';

  @override
  String get profileTermsSubtitle => 'سياسة الاستخدام والخصوصية';

  @override
  String get profileSectionAccount => 'الحساب';

  @override
  String get profileDeleteAccountTitle => 'حذف الحساب';

  @override
  String get profileDeleteAccountSubtitle => 'حذف الحساب نهائياً';

  @override
  String get profileSignOut => 'تسجيل الخروج';

  @override
  String get profileDeleteAccountBody =>
      'هل أنت متأكد من حذف حسابك نهائياً؟ لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get profileDeleteAccountConfirm => 'نعم، احذف الحساب';

  @override
  String get profileDeleteAccountFailed =>
      'تعذر حذف الحساب. تحقق من الاتصال وحاول مرة أخرى.';

  @override
  String get profileSaved => 'تم حفظ التغييرات';

  @override
  String get profileSaveFailedRetry =>
      'تعذر حفظ التغييرات — تحقق من الاتصال وحاول مرة أخرى';

  @override
  String get profileEditName => 'تعديل الاسم';

  @override
  String get profileName => 'الاسم';

  @override
  String get profileGoalName => 'اسم الهدف';

  @override
  String get profileGoalMetricEgypt => 'إزاي بنقيسه؟ (مثال: 500 جنيه شهرياً)';

  @override
  String get profileGoalMetricOther => 'إزاي بنقيسه؟ (مثال: 500 ريال شهرياً)';

  @override
  String get profileGoalDeadline => 'الاستحقاق (اختياري)';

  @override
  String get profileGoalDeadlineHint => 'مثال: 2026-12-31';

  @override
  String get profileSaveShort => 'احفظ';

  @override
  String get profileEmail => 'البريد الإلكتروني';

  @override
  String get profileAliasLabel => 'الاسم / اللقب';

  @override
  String get profileAliasHint => 'مثال: الأب';

  @override
  String get profileSaveChanges => 'حفظ التغييرات';

  @override
  String get profileCountry => 'البلد';

  @override
  String get profileCurrency => 'العملة';

  @override
  String get profileCurrencyAuto =>
      'العملة بتتحدد تلقائياً حسب البلد المختار فوق';

  @override
  String profileChangeCountryTitle(String country) {
    return 'تغيّر البلد لـ $country؟';
  }

  @override
  String profileCurrencyWillBe(String symbol, String code) {
    return 'العملة هتبقى $symbol ($code).';
  }

  @override
  String profileLimitConverts(
    String from,
    String fromSymbol,
    String to,
    String toSymbol,
  ) {
    return 'سقفك الشهري هيتحوّل من $from $fromSymbol إلى $to $toSymbol، وميزانيات الفئات كمان.';
  }

  @override
  String get profileChange => 'غيّر';

  @override
  String get profileNoRate =>
      'مش عارف سعر التحويل، فسقفك الشهري هيفضل بنفس الرقم — راجعه بعد التغيير.';

  @override
  String get profileKidsRelockTitle => 'إعادة قفل وضع الأطفال';

  @override
  String get profileKidsRelockSubtitle => 'يرجع الجهاز لوضع الأطفال';

  @override
  String get profileKidsModeTitle => 'تبديل لوضع الأطفال';

  @override
  String get profileKidsModeSubtitle =>
      'لما تدي الجهاز لطفلك مؤقتاً — الخروج محتاج PIN';

  @override
  String get profileNoFamily => 'أنت لست منضماً لأي عائلة حالياً.';

  @override
  String get profileFamilyInviteCode => 'كود دعوة العائلة';

  @override
  String get profileFamilyMembers => 'أفراد العائلة';

  @override
  String get profileRoleAdmin => 'مدير العائلة';

  @override
  String get profileRoleChild => 'ابن/ابنة';

  @override
  String get profileRoleMember => 'عضو';

  @override
  String get profileKickFailed => 'فشل طرد العضو، يرجى المحاولة لاحقاً.';

  @override
  String get profileRoleChangeFailed =>
      'فشل تغيير الصلاحية، يرجى المحاولة لاحقاً.';

  @override
  String get profileMakeAdmin => 'ترقية لمدير (Admin)';

  @override
  String get profileMakeMember => 'إرجاع لعضو (Member)';

  @override
  String get profileMakeChild => 'تعيين كابن/ابنة';

  @override
  String get profileKick => 'طرد العضو';

  @override
  String get profilePaymentBudgetTitle => 'طرق الدفع والميزانية';

  @override
  String get profileCurrentMonthlyBudget => 'الميزانية الشهرية الحالية';

  @override
  String get profileDiagNoPermission =>
      '❌ الصلاحية مش ممنوحة — فعّلها من إعدادات الوصول للإشعارات';

  @override
  String get profileDiagNotBound => '❌ السيرفس مش مربوط — اضغط زر إعادة الربط';

  @override
  String get profileDiagNoNotifications =>
      '❌ السيرفس مربوط بس مش بيوصلوش إشعارات — جرب requestRebind';

  @override
  String get profileDiagWaitingTest =>
      '⏳ مستني وصول الإشعار التجريبي للمستمع...';

  @override
  String get profileDiagAllWorking => '✅ الرصد شغال بالكامل';

  @override
  String get profileDiagListenerWorking => '✅ المستمع مسكه والفلترة شغالة';

  @override
  String get profileDiagUnknown => '❓ حالة غير معروفة — جرب تاني';

  @override
  String profileParseOk(String amount, String kind) {
    return 'نجح التحليل ✓\nالمبلغ: $amount\nالتاجر: —\nالنوع: $kind';
  }

  @override
  String get profileParseCompleted => 'عملية مكتملة';

  @override
  String get profileParsePending => 'معلّقة';

  @override
  String get profileParseInfo => 'معلومة';

  @override
  String get profileParseServer => 'تتأكد على السيرفر';

  @override
  String get profileParseFailed =>
      'فشل التحليل — الرسالة العينة معملهاش parser';

  @override
  String get profileTest => 'اختبار';

  @override
  String get profileOk => 'تمام';

  @override
  String get profileBankReading => 'قراءة إشعارات البنك';

  @override
  String get profileBankReadingHint =>
      'الحالة الحقيقية للصلاحيات — لو الصلاحية متسحوبة من إعدادات النظام، هتلاقيها هنا فوراً';

  @override
  String get profileEnable => 'تفعيل';

  @override
  String get profileReaderConnection => 'اتصال خدمة القراءة';

  @override
  String get profileRetry => 'إعادة المحاولة';

  @override
  String profileLastConnected(String time) {
    return 'آخر اتصال فعلي: $time';
  }

  @override
  String get profileNeverConnected =>
      'الخدمة لم تتصل بعد، حتى لو كانت الصلاحية مفعلة';

  @override
  String get profileNotificationsArriving => 'وصول إشعارات للجهاز';

  @override
  String profileLastNotification(String time) {
    return 'آخر إشعار وصل للخدمة: $time';
  }

  @override
  String get profileNoNotificationYet => 'لم يصل أي إشعار للخدمة بعد';

  @override
  String profileLastParsed(int minutes) {
    return 'آخر عملية اتقرأت: قبل $minutes دقيقة';
  }

  @override
  String get profileNothingParsed => 'لسه ما اتقرتش أي عملية';

  @override
  String get profileSendTestNotification =>
      'اختبار — اختبار زاد — عملية تجريبية';

  @override
  String get profileRejectedTitle => 'آخر الرسائل اللي اترفضت';

  @override
  String get profileRejectedHint =>
      'لو بنك أو محفظة معينة مش بتتسجل، هتلاقي السبب هنا (OTP، رسالة معلّقة، أو نص محصلش فهمه).';

  @override
  String profileStatusOn(String label) {
    return '$label: شغالة ✓';
  }

  @override
  String profileStatusOff(String label) {
    return '$label: مش شغالة';
  }

  @override
  String get profileVoiceAlertsTitle => '🔔 النطق الصوتي للإشعارات والجرعات';

  @override
  String get profileVoiceAlertsDesc =>
      'زاد تقول تذكير الدوا والمواعيد بصوتها لما التطبيق مفتوح، ولما يكون مقفول الإشعار بيبقى عليه «اسمع زاد».';

  @override
  String get profileLowStockTitle => 'تنبيهات نقص المخزون';

  @override
  String get profileLowStockDesc => 'يرسل إشعاراً عند اقتراب نفاذ منتج أساسي';

  @override
  String get profileBudgetOverrunTitle => 'تنبيهات تخطي الميزانية';

  @override
  String get profileBudgetOverrunDesc =>
      'تحذير مبكر عند صرف جزء كبير من الميزانية';

  @override
  String get profileTasbihTitle => 'تذكير التسبيح';

  @override
  String get profileTasbihDesc =>
      'تذكير لطيف الساعة 5 عصراً لو لسه ما سبّحتش النهاردة';

  @override
  String get profileCompanionNapTitle => 'رفيق زاد يناديني لو غبت';

  @override
  String get profileCompanionNapDesc =>
      'إشعار واحد لو غبت يومين، وواحد كمان بعد يومين — مش أكتر من مرة في اليوم، ومش بالليل';

  @override
  String get profileCompanionCareTitle => 'رفيق زاد يفكّرني بأكله ومَيّته';

  @override
  String get profileCompanionCareDesc =>
      'إشعار واحد لما يجوع أو يعطش، بيتأجّل كل ما تأكّله أو تسقيه — ومش بالليل';

  @override
  String get profileLearnSleepTitle => 'زاد يتعلّم مواعيد نومي';

  @override
  String get profileLearnSleepDesc =>
      'من أوقات قفل وفتح الشاشة بالليل، عشان مايبعتش تنبيهات وإنت نايم. ساعة النوم وساعة الصحيان بس اللي بتتحفظ — مش اللحظات نفسها. الجرعات والطوارئ زي ما هي.';

  @override
  String get profileNotificationSound => 'صوت الإشعارات';

  @override
  String get profileNotificationSoundHint =>
      'اختار من أي صوت إشعار مثبّت على جهازك بدل الصوت الافتراضي';

  @override
  String get profileDefaultSound => 'الصوت الافتراضي';

  @override
  String get supportFallback =>
      'مش قادر أرد دلوقتي. جرّب تاني كمان شوية، ولو المشكلة مستمرة افتح «سجل الأعطال» من الشاشة دي وابعته لنا — فيه اللي نحتاجه عشان نصلحها.';

  @override
  String get supportFaqBank =>
      'عشان زاد يقرا رسايل البنك: من الرئيسية دوس «فعّل قراءة إشعارات البنك» وامشي على الخطوات. لو المفتاح رمادي أو ظهرت «إعداد مقيَّد»: افتح «معلومات التطبيق» ← ⋮ فوق ← «السماح بالإعدادات المقيدة»، وارجع فعّل الإذن. وعلى شاومي وأوبو خلي البطارية «بدون قيود» عشان مايقفش.';

  @override
  String get supportFaqAllowance =>
      'من «العائلة» ← «مصاريف الأبناء» تلاقي كل طفل ورصيده. «حوّل مصروف» بيزوّد رصيده على طول. والطفل يقدر يطلب «مصروف» (بيتضاف لو وافقت) أو «أشتري حاجة» (بيتخصم لو وافقت ورصيده يكفي).';

  @override
  String get supportFaqReceipt =>
      'صوّر الفاتورة من زرار الكاميرا. زاد بيقرا المبلغ والأصناف وتاريخ الفاتورة، وبيسجلها على يومها. راجع المبلغ والفئة قبل الحفظ، وتقدر تضيف الأصناف للمخزن في نفس الخطوة.';

  @override
  String get supportFaqCountry =>
      'البلد والعملة بيتحددوا وقت التسجيل. لو محتاج تغيّرهم: «حسابي» ← «الإعدادات» ← السوق. التوقيت ومواعيد التذكير بيمشوا على بلد الحساب.';

  @override
  String get supportFaqVoice =>
      'دوس على المايك في الشات واتكلم، وزاد بيرد بصوت. لو الرد اتأخر أو ماجاش صوت، اتأكد من النت وجرّب تاني — والرد المكتوب بيفضل ظاهر في الشات.';

  @override
  String get supportFaqAppointments =>
      'المواعيد من «مواعيدي» ← «ميعاد جديد»، أو قول لزاد في الشات «فكرني بميعاد الدكتور يوم الخميس الساعة ٥». الأدوية من «صيدلية العائلة»، وتقدر تحدد الدوا لمين في العيلة.';

  @override
  String get supportFaqFamily =>
      'من «العائلة» اعمل عيلة جديدة وابعت الكود لأهلك، أو دوس «انضم» واكتب الكود اللي وصلك. المسؤول بس هو اللي يقدر يغيّر الأدوار والمكافآت.';

  @override
  String get supportFaqPassword =>
      'من شاشة الدخول دوس «نسيت كلمة المرور» واكتب إيميلك، هيوصلك لينك تغيّرها منه.';

  @override
  String get supportFaqDeleteAccount =>
      'حذف الحساب من «حسابي» ← «حذف الحساب». ده بيمسح بياناتك كلها نهائياً ومايترجعش.';

  @override
  String get supportWelcome =>
      'أهلاً! أنا مساعد أسئلة استخدام تطبيق زاد — أقدر أساعدك تفهم أي ميزة أو تحل مشكلة تقنية. لو سؤالك عن بياناتك الشخصية (مصاريفك، رصيدك، اشتراكاتك)، الأفضل تسأل شات \"عقل زاد\" لأنه هو بس اللي شايف حسابك الفعلي.';

  @override
  String get supportContactTeam => 'كلّم فريق الدعم';

  @override
  String get supportContactHint =>
      'اكتب المشكلة أو الشكوى، وهيوصل لفريق الدعم على طول ويردوا عليك على إيميلك.';

  @override
  String get supportSubject => 'الموضوع';

  @override
  String get supportSubjectHint => 'مثال: صفحة الصيدلية فاضية';

  @override
  String get supportDetails => 'التفاصيل';

  @override
  String get supportAttachLog => 'أرفق سجل الأعطال (يساعدنا نصلحها أسرع)';

  @override
  String get supportSend => 'إرسال';

  @override
  String get supportSentByEmail =>
      'وصلت رسالتك لفريق الدعم ✅ — هيردوا عليك على إيميلك في أقرب وقت.';

  @override
  String get supportMailOpened =>
      'فتحنالك الإيميل — دوس إرسال وهتوصل لفريق الدعم';

  @override
  String supportWriteTo(String email) {
    return 'ابعت لنا على $email';
  }

  @override
  String get supportCrashLog => 'سجل الأعطال';

  @override
  String get supportShareLog => 'مشاركة السجل';

  @override
  String get supportShare => '📤 مشاركة';

  @override
  String get supportClear => '🗑️ مسح';

  @override
  String get supportClose => 'إغلاق';

  @override
  String get supportTitle => 'مساعدة استخدام التطبيق';

  @override
  String get supportSubtitle => 'أسئلة عامة — مش وصل لحسابك الشخصي';

  @override
  String get supportComplaintBanner => 'عندك شكوى أو مشكلة؟ كلّم فريق الدعم';

  @override
  String get supportInputHint => 'اكتب رسالتك هنا...';

  @override
  String get supportTyping => 'جاري الكتابة...';

  @override
  String get supportTermsTitle => 'الشروط والأحكام';

  @override
  String get supportTermsHeading => 'شروط الاستخدام واتفاقية المستخدم';

  @override
  String get supportTermsIntro =>
      'آخر تحديث: يوليو 2026\n\nمن فضلك اقرأ شروط الاستخدام دي بعناية قبل ما تستخدم تطبيق زاد.';

  @override
  String get supportTerms1Title => '١. الموافقة على الشروط';

  @override
  String get supportTerms1Body =>
      'بإنشائك حساب أو استخدامك لتطبيق زاد، فإنك توافق على هذه الشروط. لو مش موافق، من فضلك متستخدمش التطبيق.';

  @override
  String get supportTerms2Title => '٢. طبيعة الخدمة — إحنا أداة، مش جهة مسؤولة';

  @override
  String get supportTerms2Body =>
      'زاد هو أداة تنظيمية ومساعدة شخصية فقط. إحنا بنوفر برنامج بيساعدك تتابع وتنظم وتعرض بياناتك المالية والمنزلية الخاصة بيك. إحنا مش بندير فلوسك، ولا بناخد قرارات نيابةً عنك، ولا بنحتفظ بأموالك، ولا بنعالج مدفوعات، ولا بنعمل كمؤسسة مالية أو مستشار مالي أو أمين استئماني من أي نوع.\n\nكل ميزة في التطبيق — بما فيها إدارة الميزانية، تتبع المصاريف، مسح الفواتير، متابعة المخزون، تتبع الاشتراكات، اكتشاف المعاملات عن طريق الإشعارات، وأي رؤية \"ذكية\" أو \"مبنية على الذكاء الاصطناعي\" — موجودة فقط عشان تساعدك تنظم معلومات إنت أصلاً عندك أو بتنتجها. إحنا مش بنتحقق من دقة المعلومات دي ولا بنضمنها ولا بنتحمل مسؤوليتها، ولا مسؤولية أي إجراء تتخذه بناءً عليها.\n\nإنت، وإنت بس، المسؤول عن:\n- كل قرار مالي بتاخده؛\n- التأكد من دقة أي بيانات معروضة أو محسوبة أو مكتشَفة أو مقترحة من التطبيق؛\n- نتائج اعتمادك على أي ميزة آلية، بما فيها الرؤى أو التوقعات المولّدة بالذكاء الاصطناعي أو الاكتشاف عن طريق الإشعارات؛\n- كل النتائج المتعلقة بميزانيتك أو إنفاقك أو مدخراتك أو إدارة منزلك، سواء كانت معلومات التطبيق دقيقة أو لأ.\n\nإحنا مش بنتحمل أي مسؤولية أو التزام من أي نوع عن نتائج استخدامك للتطبيق. استخدامك لزاد مش بينشئ أي علاقة استشارية أو التزام أمانة أو ضمان لأي نتيجة بينك وبيننا. التطبيق متاح كأداة تنظيمية وتسهيلية بحتة — مسؤولية إزاي بتستخدم المعلومات اللي بيعرضها بالكامل عليك.';

  @override
  String get supportTerms3Title => '٣. الخصوصية والبيانات';

  @override
  String get supportTerms3Body =>
      'بنحترم خصوصيتك. بياناتك مخزنة بشكل آمن. إحنا مش بنبيع بياناتك المالية الشخصية لأي طرف تالت.';

  @override
  String get supportTerms4Title =>
      '٤. ميزات الذكاء الاصطناعي من أطراف خارجية — مساعدة فقط، مش مرجعية';

  @override
  String get supportTerms4Body =>
      'بعض الميزات (مسح الفواتير، توقعات الإنفاق، اكتشاف الاشتراكات، الرؤى السلوكية، اقتراحات الوجبات، الإدخال الصوتي) بتستخدم خدمات ذكاء اصطناعي من أطراف خارجية لمعالجة البيانات وتوليد الاقتراحات. المخرجات دي متاحة كتسهيل فقط، وميتعاملش معاها أبدًا كأنها دقيقة أو كاملة أو موثّقة أو مرجعية. المحتوى المولّد بالذكاء الاصطناعي ممكن يكون غلط أو قديم أو مش مناسب لحالتك.\n\nإحنا مش مالكين ولا متحكمين في نماذج الذكاء الاصطناعي المستخدمة. إحنا مش مسؤولين عن أي حاجة الذكاء الاصطناعي يولدها أو يقترحها أو يتوقعها أو يفشل يكتشفها. لازم تتأكد بنفسك من أي رقم أو تصنيف أو توصية قبل ما تتصرف بناءً عليها. اعتمادك على أي مخرج من الذكاء الاصطناعي كتوجيه مالي بيكون بالكامل على مسؤوليتك الخاصة.';

  @override
  String get supportTerms5Title => '٥. مشاركة العائلة';

  @override
  String get supportTerms5Body =>
      'لو دعيت أفراد من عائلتك، إنت المسؤول عن وصولهم لبيانات منزلك.';

  @override
  String get supportTerms6Title => '٦. السلوك الممنوع';

  @override
  String get supportTerms6Body =>
      'ممنوع تعمل هندسة عكسية أو اختراق أو تستخدم زاد في أي نشاط غير قانوني.';

  @override
  String get supportTerms7Title =>
      '٧. إحنا بنوفر الأداة — وإنت المسؤول عن النتيجة';

  @override
  String get supportTerms7Body =>
      'إحنا مش بنضمن ولا بنتحمل مسؤولية دقة أي رصيد أو فئة مصروف أو حالة اشتراك أو مستوى مخزون أو تنبيه نقص أو توقع ميزانية معروض في التطبيق. وإحنا مش بنضمن إن الاكتشاف التلقائي للمعاملات هيلتقط كل معاملة، ولا إنه هيكون صح دايمًا لما يلتقطها.\n\nباستخدامك لزاد، إنت مقر بإن:\n- إحنا أداة تنظيم معلومات سلبية، مش طرف فاعل في قراراتك المالية؛\n- أي خسارة مالية أو دفعة فاتت أو إسراف في الإنفاق أو تلف مخزون أو خلاف عائلي أو أي نتيجة سلبية تانية ناتجة عن استخدامك أو اعتمادك على التطبيق هي مسؤوليتك وحدك؛\n- إحنا مش هنتحمل أي مسؤولية، مالية أو غيرها، عن النتايج دي، لأقصى حد يسمح بيه القانون.';

  @override
  String get profileLabelGenderFemale => 'أنثى';

  @override
  String get profileLabelGenderMale => 'ذكر';

  @override
  String get profileLabelZadvoiceBoy => 'صوت ولد';

  @override
  String get profileLabelZadvoiceGirl => 'صوت بنت';

  @override
  String get profileLabelRoleFather => 'أب';

  @override
  String get profileLabelRoleMother => 'أم';

  @override
  String get profileLabelRoleHusband => 'زوج';

  @override
  String get profileLabelRoleWife => 'زوجة';

  @override
  String get profileLabelRoleSon => 'ابن';

  @override
  String get profileLabelRoleDaughter => 'بنت';

  @override
  String get profileLabelRoleSingle => 'عايش لوحدي';

  @override
  String get profileLabelRoleStudent => 'طالب';

  @override
  String get profileLabelRoleGrandparent => 'جد/جدة';

  @override
  String get profileLabelRoleDefault => 'غير كده';

  @override
  String get profileLabelAgeUnder18 => 'أقل من ١٨';

  @override
  String get profileLabelAge1824 => '١٨–٢٤';

  @override
  String get profileLabelAge2534 => '٢٥–٣٤';

  @override
  String get profileLabelAge3544 => '٣٥–٤٤';

  @override
  String get profileLabelAge4554 => '٤٥–٥٤';

  @override
  String get profileLabelAgeDefault => '٥٥ وأكبر';

  @override
  String get profileLabelFrequencyWeekly => 'أسبوعي';

  @override
  String get profileLabelFrequencyBiweekly => 'كل أسبوعين';

  @override
  String get profileLabelFrequencyDaily => 'يومي';

  @override
  String get profileLabelFrequencyIrregular => 'مش ثابت';

  @override
  String get profileLabelFrequencyDefault => 'شهري';

  @override
  String get profileLabelCaresforChildren => 'أولادي';

  @override
  String get profileLabelCaresforParents => 'أبويا أو أمي';

  @override
  String get profileLabelCaresforSpouse => 'زوجي أو زوجتي';

  @override
  String get profileLabelCaresforSiblings => 'إخواتي';

  @override
  String get profileLabelCaresforGrandparents => 'جدي أو جدتي';

  @override
  String get profileLabelDialectSa => 'سعودي';

  @override
  String get profileLabelDialectGulf => 'خليجي';

  @override
  String get profileLabelDialectLevant => 'شامي';

  @override
  String get profileLabelDialectIq => 'عراقي';

  @override
  String get profileLabelDialectMa => 'مغربي';

  @override
  String get profileLabelDialectTn => 'تونسي';

  @override
  String get profileLabelDialectDz => 'جزائري';

  @override
  String get profileLabelDialectLy => 'ليبي';

  @override
  String get profileLabelDialectSd => 'سوداني';

  @override
  String get profileLabelDialectYe => 'يمني';

  @override
  String get profileLabelDialectDefault => 'مصري';

  @override
  String get memoryWriteNotSaved => 'مقدرتش أحفظ ده، جرب تاني';

  @override
  String quietBannerExams(String until) {
    return 'فترة امتحانات — زاد مهدّي التنبيهات لحد $until';
  }

  @override
  String quietBannerOther(String until) {
    return 'زاد مهدّي التنبيهات لحد $until — الجرعات والمواعيد زي ما هي';
  }

  @override
  String get memoryScopeGeneral => 'عنك';

  @override
  String get memoryScopeSpending => 'صرفك';

  @override
  String get memoryScopeCycle => 'دورة القبض';

  @override
  String get memoryScopeWeekly => 'ملخص الأسبوع';

  @override
  String get memoryScopeDataQuality => 'دقة البيانات';

  @override
  String get memoryScopeDismissal => 'تنبيه رفضته';

  @override
  String get memoryScopeOther => 'ملاحظة';

  @override
  String get monthJan => 'يناير';

  @override
  String get monthFeb => 'فبراير';

  @override
  String get monthMar => 'مارس';

  @override
  String get monthApr => 'أبريل';

  @override
  String get monthMay => 'مايو';

  @override
  String get monthJun => 'يونيو';

  @override
  String get monthJul => 'يوليو';

  @override
  String get monthAug => 'أغسطس';

  @override
  String get monthSep => 'سبتمبر';

  @override
  String get monthOct => 'أكتوبر';

  @override
  String get monthNov => 'نوفمبر';

  @override
  String get monthDec => 'ديسمبر';

  @override
  String get briefTookIt => 'خدتها';

  @override
  String get briefAddThem => 'ضيفهم';

  @override
  String get occasionNewYearTitle => 'سنة جديدة سعيدة! 🎉';

  @override
  String occasionNewYearQuestion(String dialect, int year) {
    String _temp0 = intl.Intl.selectLogic(dialect, {
      'gulf': 'تبي زاد يجهّز لك خطة أهدافك المالية لسنة $year بضغطة وحدة؟',
      'other': 'حابب زاد يجهّزلك خطة أهدافك المالية لسنة $year بنقرة واحدة؟',
    });
    return '$_temp0';
  }

  @override
  String get occasionNewYearActionLabel => 'جهّزها';

  @override
  String occasionNewYearPrompt(int year) {
    return 'جهّزلي خطة أهداف مالية لسنة $year من أرقامي ومصاريفي الفعلية، واقترح عليا الأهداف أأكدها أنا.';
  }

  @override
  String get occasionRamadanTitle => 'رمضان كريم 🌙';

  @override
  String occasionRamadanQuestion(String dialect) {
    String _temp0 = intl.Intl.selectLogic(dialect, {
      'gulf': 'أجهّز لك قائمة مقاضي رمضان من الناقص في البيت؟',
      'other': 'أجهّزلك قايمة مشتريات رمضان من اللي ناقص في البيت؟',
    });
    return '$_temp0';
  }

  @override
  String get occasionRamadanActionLabel => 'جهّز القايمة';

  @override
  String get occasionRamadanPrompt =>
      'جهّزلي قايمة مشتريات رمضان من اللي ناقص في البيت فعلاً، وضيفها لقايمة التسوق في حدود الميزانية.';

  @override
  String get occasionEidFitrTitle => 'عيد فطر سعيد! 🎈';

  @override
  String occasionEidFitrQuestion(String dialect) {
    String _temp0 = intl.Intl.selectLogic(dialect, {
      'gulf': 'أسوي لك ميزانية العيد (عيدية ولبس وعزايم) من المتاح؟',
      'other': 'أعملك ميزانية للعيد (عيدية ولبس وعزومات) من المتاح؟',
    });
    return '$_temp0';
  }

  @override
  String get occasionEidFitrActionLabel => 'اعملها';

  @override
  String get occasionEidFitrPrompt =>
      'اعملي ميزانية لعيد الفطر: عيدية ولبس وعزومات، من المتاح عندي من غير ما تعدّي الميزانية.';

  @override
  String get occasionEidAdhaTitle => 'عيد أضحى مبارك! 🐑';

  @override
  String occasionEidAdhaQuestion(String dialect) {
    String _temp0 = intl.Intl.selectLogic(dialect, {
      'gulf': 'أسوي لك ميزانية العيد من المتاح؟',
      'other': 'أعملك ميزانية للعيد من المتاح؟',
    });
    return '$_temp0';
  }

  @override
  String get occasionEidAdhaActionLabel => 'اعملها';

  @override
  String get occasionEidAdhaPrompt =>
      'اعملي ميزانية لعيد الأضحى من المتاح عندي — العيدية والعزومات، والأضحية لو بنضحّي.';

  @override
  String get occasionHijriTitle => 'سنة هجرية سعيدة 🌙';

  @override
  String occasionHijriQuestion(String dialect) {
    String _temp0 = intl.Intl.selectLogic(dialect, {
      'gulf': 'نراجع أهدافك ونشوف وين وصلت؟',
      'other': 'نراجع أهدافك ونشوف ماشية إزاي؟',
    });
    return '$_temp0';
  }

  @override
  String get occasionHijriActionLabel => 'راجعها';

  @override
  String get occasionHijriPrompt =>
      'راجع أهدافي وقولّي كل هدف ماشي إزاي، واقترح خطوة صغيرة للمتأخر.';

  @override
  String get occasionMothersDayTitle => 'كل سنة وكل أم بخير 💐';

  @override
  String occasionMothersDayQuestion(String dialect) {
    String _temp0 = intl.Intl.selectLogic(dialect, {
      'gulf': 'تبي أقترح لك هدية لعيد الأم في حدود الميزانية؟',
      'other': 'تحب أقترح عليك هدية لعيد الأم جوه الميزانية؟',
    });
    return '$_temp0';
  }

  @override
  String get occasionMothersDayActionLabel => 'اقترح';

  @override
  String get occasionMothersDayPrompt =>
      'اقترح عليا هدية لعيد الأم جوه الميزانية.';

  @override
  String get occasionAnnivTodayTitle => 'كل سنة وإنتو طيبين 💍';

  @override
  String occasionAnnivTodayQuestion(String dialect) {
    String _temp0 = intl.Intl.selectLogic(dialect, {
      'gulf': 'تبي أقترح لكم طلعة الليلة في حدود الميزانية؟',
      'other': 'أقترحلكم خروجة الليلة في حدود الميزانية؟',
    });
    return '$_temp0';
  }

  @override
  String get occasionAnnivTodayActionLabel => 'اقترح';

  @override
  String get occasionAnnivTodayPrompt =>
      'النهارده ذكرى جوازنا — اقترحلي خروجة الليلة في حدود ميزانيتي.';

  @override
  String get occasionAnnivSoonTitle => 'ذكرى جوازكم بعد ٣ أيام 💍';

  @override
  String occasionAnnivSoonQuestion(String dialect) {
    String _temp0 = intl.Intl.selectLogic(dialect, {
      'gulf': 'تبي أقترح لك هدية أو طلعة في حدود الميزانية؟',
      'other': 'أقترحلك هدية أو خروجة في حدود الميزانية؟',
    });
    return '$_temp0';
  }

  @override
  String get occasionAnnivSoonActionLabel => 'اقترح';

  @override
  String occasionAnnivSoonPrompt(String date) {
    return 'ذكرى جوازنا يوم $date. اقترحلي هدية أو خروجة في حدود ميزانيتي.';
  }

  @override
  String occasionPersonTodayTitle(String what) {
    return 'النهارده $what 🎂';
  }

  @override
  String occasionPersonTodayQuestion(String dialect) {
    String _temp0 = intl.Intl.selectLogic(dialect, {
      'gulf': 'أكتب لك رسالة تهنئة ترسلها؟',
      'other': 'أكتبلك رسالة تهنئة حلوة تبعتها؟',
    });
    return '$_temp0';
  }

  @override
  String get occasionPersonTodayActionLabel => 'اكتبها';

  @override
  String occasionPersonTodayPrompt(String what) {
    return 'النهارده $what — اكتبلي رسالة تهنئة قصيرة ودافية أبعتها.';
  }

  @override
  String occasionPersonSoonTitle(String what) {
    return '$what بعد ٣ أيام 🎁';
  }

  @override
  String occasionPersonSoonQuestion(String dialect) {
    String _temp0 = intl.Intl.selectLogic(dialect, {
      'gulf': 'تبي أقترح لك هدية في حدود الميزانية وأحجز مبلغها؟',
      'other': 'أقترحلك هدية في حدود الميزانية وأحجز مبلغها؟',
    });
    return '$_temp0';
  }

  @override
  String get occasionPersonSoonActionLabel => 'اقترح هدية';

  @override
  String occasionPersonSoonPrompt(String what, String date) {
    return '$what يوم $date. اقترحلي فكرتين هدية في حدود ميزانيتي، ولو وافقت احجز مبلغها كهدف لحد يومها.';
  }

  @override
  String occasionBirthdayOf(String name) {
    return 'عيد ميلاد $name';
  }

  @override
  String occasionAnniversaryOf(String name) {
    return 'ذكرى جواز $name';
  }

  @override
  String get briefToday => 'النهارده';

  @override
  String get briefTomorrow => 'بكرة';

  @override
  String get briefDayAfter => 'بعد بكرة';

  @override
  String briefInDays(int days) {
    return 'بعد $days أيام';
  }

  @override
  String briefDoseDue(String name) {
    return 'وقت جرعة $name';
  }

  @override
  String briefDoseDueDetail(String time) {
    return 'ميعادها $time — دوس «خدتها» لما تاخدها';
  }

  @override
  String briefDosesMissed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count جرعات فاتوا',
      one: 'جرعة فاتت',
    );
    return '$_temp0';
  }

  @override
  String get briefDosesMissedDetail => 'افتح الصيدلية وسجّل اللي اتاخد';

  @override
  String briefOverspent(String amount) {
    return 'صرفت أكتر من المتاح بـ$amount';
  }

  @override
  String get briefOverspentDetail => 'شوف فلوسي — زاد يقدر يقترح تقلل منين';

  @override
  String briefInstalment(String name, String when) {
    return 'قسط $name $when';
  }

  @override
  String briefAndMore(int count) {
    return ' و$count كمان';
  }

  @override
  String briefShort(String items) {
    return 'ناقصك $items';
  }

  @override
  String get briefShortDetail => 'افتح بيتي وضيفهم لقايمة التسوق';

  @override
  String briefAboutWhen(String item, String when) {
    return '$item حوالي $when';
  }

  @override
  String briefRunningOut(String items) {
    return 'هيخلص قريب: $items';
  }

  @override
  String get briefRunningOutEstimate =>
      'تقدير من استهلاكك لحد دلوقتي — ضيفهم لقايمة التسوق؟';

  @override
  String get briefRunningOutRate => 'من معدل استهلاكك — ضيفهم لقايمة التسوق؟';

  @override
  String briefFamilyChat(String items) {
    return 'من شات العيلة: $items';
  }

  @override
  String get briefFamilySaid => 'اتقال إنهم ناقصين — ضيفهم لقايمة التسوق؟';

  @override
  String briefFamilyWhoSaid(String names, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'قالوا',
      one: 'قال',
    );
    return '$names $_temp0 إنهم ناقصين — ضيفهم لقايمة التسوق؟';
  }

  @override
  String get briefAnd => ' و';

  @override
  String get familyRoleLabelAdmin => 'مسؤول';

  @override
  String get familyRoleLabelMember => 'فرد';

  @override
  String get familyRoleLabelChild => 'طفل';

  @override
  String get familyFailureInvalidCode =>
      'الكود ده مش صح. خده تاني من صاحب العيلة.';

  @override
  String get familyFailureTooManyAttempts =>
      'جربت أكواد كتير. استنى ساعة وجرّب تاني.';

  @override
  String get familyFailureAlreadyInFamily =>
      'إنت بالفعل في عيلة. اخرج منها الأول.';

  @override
  String get familyFailureLastAdmin =>
      'إنت آخر مسؤول. خلّي حد تاني مسؤول الأول.';

  @override
  String get familyFailureNotAllowed => 'ده للمسؤول بس.';

  @override
  String get familyFailureOffline => 'محتاج نت عشان ده.';

  @override
  String get familyFailureUnknown => 'حصلت مشكلة. جرّب تاني.';

  @override
  String get familyScopeMedicines => 'الأدوية';

  @override
  String get familyScopeSpending => 'المصروف';

  @override
  String get familyScopeTasks => 'المهام والمواعيد';

  @override
  String get familyScopeLocation => 'الأماكن (المدرسة…)';

  @override
  String familyShareAskLocation(String name) {
    return '$name عايز يعرف لما تدخل أو تخرج من أماكن هو يحددها (زي المدرسة)';
  }

  @override
  String familyShareAsk(String name, String what) {
    return '$name عايز يتابع $what';
  }

  @override
  String get familyNoticeLoadFailed =>
      'مقدرتش أجيب بيانات العيلة. اسحب لتحت نجرب تاني.';

  @override
  String get familyNoticeNotSent => 'الرسالة ماتبعتتش — اتأكد من النت.';

  @override
  String get familyNoticeCoolingAdmin => 'وقفة التفكير للمسؤول بس.';

  @override
  String get familyNoticeCoolingFailed =>
      'مقدرتش أغيّر وقفة التفكير. جرّب تاني.';

  @override
  String get familyNoticeServer => 'مقدرتش أوصل للسيرفر. جرّب تاني.';

  @override
  String get familyNoticeAllowanceAdmin => 'تحويل المصروف للمسؤول بس.';

  @override
  String get familyNoticeAmountPositive => 'اكتب مبلغ أكبر من صفر.';

  @override
  String get familyNoticeAllowanceFailed => 'مقدرتش أحوّل المصروف. جرّب تاني.';

  @override
  String get familyNoticeDecisionAdmin => 'القرار ده للمسؤول بس.';

  @override
  String get familyNoticeDecisionFailed => 'مقدرتش أسجّل القرار. جرّب تاني.';

  @override
  String get familyNoticePollClosed => 'التصويت اتقفل خلاص.';

  @override
  String get familyNoticeVoteFailed => 'صوتك ماتسجلش. جرّب تاني.';

  @override
  String get familyNoticePollCloseWho =>
      'اللي فتح التصويت أو المسؤول بس يقدر يقفله.';

  @override
  String get familyNoticePollCloseFailed => 'مقدرتش أقفل التصويت. جرّب تاني.';

  @override
  String get familyNoticeEditNotSaved => 'التعديل ماتحفظش.';

  @override
  String get familyNoticeRewardAdmin => 'المكافأة يحددها المسؤول بس.';

  @override
  String get familyNoticeChoreFailed => 'المهمة ماتضافتش. جرّب تاني.';

  @override
  String get familyNoticeReopenAdmin => 'إلغاء إنجاز المهمة للمسؤول بس.';

  @override
  String get familyNoticeNotYours => 'دي مهمة حد تاني.';

  @override
  String get familyNoticeChoreUpdateFailed => 'مقدرتش أحدّث المهمة.';

  @override
  String get familyNoticeItemFailed => 'الصنف ماتضافش. جرّب تاني.';

  @override
  String get familyNoticeLimitsAdmin => 'حدود الصرف يحطها المسؤول بس.';

  @override
  String get familyNoticeLimitsFailed => 'الحدود ماتحفظتش. جرّب تاني.';

  @override
  String get familyNoticeGoalSuggestFailed =>
      'زاد ماقدرش يقترح هدف دلوقتي. جرّب تاني.';

  @override
  String get familyNoticeGoalFailed => 'الهدف ماتحفظش. جرّب تاني.';

  @override
  String get familyNoticeBalanceShort =>
      'رصيده مايكفيش الطلب ده — حوّله مصروف الأول من «حوّل مصروف»، وبعدين وافق.';

  @override
  String familyNoticeChoreDone(String amount) {
    return 'عمل رائع! 🌟 اتضاف $amount للرصيد.';
  }

  @override
  String get familyCoolingWaiting =>
      'وقفة التفكير شغالة: الطلب لسه ماكملش ٢٤ ساعة — أو ارفضه دلوقتي لو مش مقتنع.';

  @override
  String get familyCoolingWithinHour =>
      'وقفة التفكير: تقدر توافق خلال ساعة — أو ارفضه دلوقتي لو مش مقتنع.';

  @override
  String familyCoolingAfterHours(int hours) {
    return 'وقفة التفكير: تقدر توافق بعد $hours ساعة — أو ارفضه دلوقتي لو مش مقتنع.';
  }

  @override
  String attemptsCount(num count, String digits) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$digits محاولة',
      few: '$digits محاولات',
      two: 'محاولتين',
      one: 'محاولة واحدة',
      zero: 'ولا محاولة',
    );
    return '$_temp0';
  }

  @override
  String attemptsPlanName(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'starter': 'الأساسية',
      'plus': 'بلس',
      'pro': 'العيلة',
      'other': 'المجانية',
    });
    return '$_temp0';
  }

  @override
  String attemptsRefillPlan(String plan) {
    return 'باقتك $plan';
  }

  @override
  String attemptsRefillPlanOn(String plan, String day, String month) {
    return 'باقتك $plan — بتتجدد يوم $day $month';
  }

  @override
  String get attemptsRefillFull => 'رصيدك كامل';

  @override
  String get attemptsRefillNow => 'رصيدك بيرجع دلوقتي';

  @override
  String attemptsRefillAt(String count, String clock) {
    return 'بيرجع $count الساعة $clock';
  }

  @override
  String attemptsRefillTomorrowAt(String count, String clock) {
    return 'بيرجع $count بكرة الساعة $clock';
  }

  @override
  String get attemptsClockAm => 'ص';

  @override
  String get attemptsClockPm => 'م';

  @override
  String attemptsChipSemantics(String attempts) {
    return 'رصيدك $attempts';
  }

  @override
  String get attemptsSheetTitle => 'طاقة زاد';

  @override
  String attemptsSheetBalance(String attempts) {
    return 'معاك $attempts';
  }

  @override
  String get attemptsCostLog => 'تسجيل مصروف أو دخل';

  @override
  String get attemptsCostFree => 'مجاني';

  @override
  String get attemptsCostChat => 'رسالة شات';

  @override
  String get attemptsCostScan => 'مسح فاتورة أو صورة';

  @override
  String get attemptsCostBrain => 'تحليل عميق أو خطة';

  @override
  String get attemptsSubscribeNoAds => 'اشترك من غير إعلانات';

  @override
  String get attemptsSeePlans => 'شوف الباقات';

  @override
  String get refusalNoAttemptsTitle => 'رصيد المحاولات مايكفيش';

  @override
  String get refusalSlowDownTitle => 'استنى شوية';

  @override
  String adWeekTitle(int count) {
    return 'شفت $count إعلان الأسبوع ده';
  }

  @override
  String adWeekBody(int minutes) {
    return 'يعني حوالي $minutes دقيقة من وقتك. الاشتراك من غير إعلانات خالص، ومعاه محاولات أكتر.';
  }

  @override
  String get adsCappedToday => 'خلصت إعلانات النهارده';

  @override
  String get adNextInAMinute => 'الإعلان الجاي بعد دقيقة';

  @override
  String adWatchFor(String attempts) {
    return 'شاهد إعلان وخد $attempts';
  }

  @override
  String adOpensBox(String bonus) {
    return 'الإعلان ده بيفتح الصندوق: +$bonus زيادة';
  }

  @override
  String adBoxProgress(String done) {
    return 'كل تالت إعلان بيفتح صندوق — $done من ٣';
  }

  @override
  String get adRewardOnTheWay => 'المكافأة في الطريق لرصيدك…';

  @override
  String get adClosedEarly => 'الإعلان اتقفل قبل المكافأة.';

  @override
  String get adNoneNow => 'مفيش إعلان دلوقتي. جرّب كمان شوية.';

  @override
  String companionPersonaTrait(String id) {
    String _temp0 = intl.Intl.selectLogic(id, {
      'basbous': 'حنين وبيحب الحلو والتوفير',
      'fella': 'رقيقة وبتهدّي البيت',
      'felfool': 'نشيط وبيحب التحديات',
      'mishmish': 'منفوش ودافي، بيحب القعدة في البيت',
      'toota': 'شقية وفنانة، بترسم الخطط',
      'fanoos': 'بيظهر في رمضان',
      'maamoul': 'بيظهر في العيد',
      'other': 'هادي وبيحب البيت المترتب',
    });
    return '$_temp0';
  }

  @override
  String companionPersonaLine(String id) {
    String _temp0 = intl.Intl.selectLogic(id, {
      'basbous': 'وفّرنا النهارده؟ يبقى نستاهل حتة بسبوسة.',
      'fella': 'البيت ريحته فل لما كل حاجة متسجلة في مكانها.',
      'felfool': 'يلا يا بطل! تحدي الأسبوع: نوفّر ١٠٠ ونكسب.',
      'mishmish': 'التلاجة مليانة والبيت دافي؟ يبقى أنا مبسوط.',
      'toota': 'تعالى نرسم خطة الشهر سوا.',
      'fanoos': 'رمضان كريم! جهزت لك قائمة السحور.',
      'maamoul': 'عيدكم مبارك! العيدية اتسجلت؟',
      'other': 'أهلاً! أنا زادو، معاك في أي حاجة تخص البيت.',
    });
    return '$_temp0';
  }

  @override
  String companionStageLabel(String stage) {
    String _temp0 = intl.Intl.selectLogic(stage, {
      'seed': 'بذرة',
      'sprout': 'بُرعم',
      'little': 'صغيّر',
      'sage': 'حكيم',
      'other': 'رفيق',
    });
    return '$_temp0';
  }

  @override
  String companionStageDescription(String stage) {
    String _temp0 = intl.Intl.selectLogic(stage, {
      'seed': 'لسه في قشرته، وعينيه كبيرة.',
      'sprout': 'خرج من القشرة وطلع له إيدين.',
      'little': 'طلع له رجلين، وبقى يلبس كل حاجة.',
      'sage': 'هالة دهب ونجوم بتلف حواليه.',
      'other': 'هالة نور حواليه، وبيرقص لما تفرح.',
    });
    return '$_temp0';
  }

  @override
  String companionOutfitLabel(String outfit) {
    String _temp0 = intl.Intl.selectLogic(outfit, {
      'sunglasses': 'نضارة شمس',
      'winterHat': 'طاقية شتوي',
      'chefHat': 'طاقية الشيف',
      'shemagh': 'شماغ',
      'gradCap': 'طاقية التخرج',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String companionBackgroundLabel(String bg) {
    String _temp0 = intl.Intl.selectLogic(bg, {
      'night': 'بالليل',
      'garden': 'الجنينة',
      'kitchen': 'المطبخ',
      'stars': 'سما النجوم',
      'shilla': 'الشلة',
      'other': 'الصبح',
    });
    return '$_temp0';
  }

  @override
  String offerOpensAtLevel(int level) {
    return 'يتفتح عند لفل $level';
  }

  @override
  String offerOpensFriends(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'يتفتح لما $count صحاب يسجّلوا',
      one: 'يتفتح لما صاحب يسجّل',
    );
    return '$_temp0';
  }

  @override
  String get offerPlusGift => 'هدية مع اشتراك بلس';

  @override
  String get offerRamadanOnly => 'في رمضان بس';

  @override
  String get offerEidOnly => 'في العيد بس';

  @override
  String petPokedMany(int count) {
    return 'خلاص! $count مرة؟ هشتكيك لزاد 😂';
  }

  @override
  String petPokedLots(String i, int count) {
    String _temp0 = intl.Intl.selectLogic(i, {
      'i0': 'إنت بتعدّ ولا إيه؟ دي $count مرة 😵‍💫',
      'other': 'الشاشة هتتعب مني ومنك 😅 $count دوسة!',
    });
    return '$_temp0';
  }

  @override
  String petPokedSome(String i, String name) {
    String _temp0 = intl.Intl.selectLogic(i, {
      'i0': 'بتدغدغني! 🤭 كفاية…',
      'i1': 'أنا مش زرار على فكرة 😤',
      'other': '$name اتزغلل من كتر الدوس 😵',
    });
    return '$_temp0';
  }

  @override
  String petBackDay(String i) {
    String _temp0 = intl.Intl.selectLogic(i, {
      'i0': 'بقالك يوم كامل مش هنا! فكرتك نسيتني 🥺',
      'other': 'يوم بحاله؟ كنت قاعد أعدّ البلاط 🥲',
    });
    return '$_temp0';
  }

  @override
  String petBackHours(String i, int hours) {
    String _temp0 = intl.Intl.selectLogic(i, {
      'i0': 'غبت $hours ساعة… مش إنك وحشتني ولا حاجة 😌',
      'other': 'رجعت! $hours ساعة وأنا باصص على الباب 👀',
    });
    return '$_temp0';
  }

  @override
  String petClockNight(String i, int hour) {
    String _temp0 = intl.Intl.selectLogic(i, {
      'i0': 'الساعة $hour بالليل! بتعمل إيه صاحي؟ 👀',
      'other': 'إحنا الاتنين صاحيين الساعة $hour… سرّنا 🤫',
    });
    return '$_temp0';
  }

  @override
  String petClockDawn(String i) {
    String _temp0 = intl.Intl.selectLogic(i, {
      'i0': 'صاحي بدري… ولا لسه مانمتش؟ 🌅',
      'other': 'الفجر لسه طالع وإنت هنا؟ برافو 🌄',
    });
    return '$_temp0';
  }

  @override
  String petPaywall(String i, String name) {
    String _temp0 = intl.Intl.selectLogic(i, {
      'i0': 'أنا شايفك بتبص على الأسعار 👀 خد وقتك',
      'i1': 'مش هضغط عليك… بس $name هيفرح أوي 🥹',
      'other': 'متقلقش، أنا معاك في الحالتين 💚',
    });
    return '$_temp0';
  }

  @override
  String petDreamTalked(String what) {
    return 'حلمت بالليل إن «$what» قعد يحكيلي عن امبارح… وفهمت إنك كنت محتاجه 🌙';
  }

  @override
  String petDreamMarket(String what) {
    return 'حلمت إني ماشي في سوق كبير، وكل محل اسمه «$what» 😄 امبارح كان يومه';
  }

  @override
  String petDreamChased(String what) {
    return 'حلمت بالليل إن «$what» بيجري ورايا 😱🌙';
  }

  @override
  String petDreamPlayed(String what) {
    return 'حلمت إني بلعب مع «$what» 🤭 هو كان أكبر حاجة امبارح';
  }

  @override
  String petWeekGoalGrown(int days) {
    return '$days أيام من ٧ الأسبوع ده… ده بيت بيعرف طريقه 💚';
  }

  @override
  String petWeekGoalYoung(int days) {
    return '$days أيام الأسبوع ده! أنا كبرت من الفرحة 🎉';
  }

  @override
  String petWeekSomeGrown(int days) {
    return 'سجّلنا $days أيام الأسبوع ده. خطوة خطوة بنوصل 🌱';
  }

  @override
  String petWeekSomeYoung(int days) {
    return '$days أيام سجّلناهم سوا! نكمّل؟ 🥰';
  }

  @override
  String get petWeekNoneGrown => 'أسبوع جديد، صفحة بيضا. أنا هنا لما تحب 💚';

  @override
  String get petWeekNoneYoung => 'أسبوع جديد! نلعب لعبة «سجّل مصروف»؟ 🌱';

  @override
  String petMoodHungry(String i) {
    String _temp0 = intl.Intl.selectLogic(i, {
      'i0': 'بطني بتصوصو… تأكّلني؟ 🍎',
      'i1': 'جعان أوي 🥺 حاجة صغيرة بس',
      'other': 'شامم ريحة أكل؟ لأ ده أنا اللي جعان 😅',
    });
    return '$_temp0';
  }

  @override
  String petMoodThirsty(String i) {
    String _temp0 = intl.Intl.selectLogic(i, {
      'i0': 'عطشان… شوية مية؟ 💧',
      'i1': 'ريقي ناشف 🥵 اسقيني',
      'other': 'كوباية مية واحدة وأبقى زي الفل 💧',
    });
    return '$_temp0';
  }

  @override
  String petMoodSleepy(String i) {
    String _temp0 = intl.Intl.selectLogic(i, {
      'i0': 'نعسان… 😴 تصبح على خير',
      'i1': 'هاااه 🥱 نكمّل بكرة؟',
      'other': 'عيني بتقفل لوحدها… 💤',
    });
    return '$_temp0';
  }

  @override
  String petMoodSad(String i, String name) {
    String _temp0 = intl.Intl.selectLogic(i, {
      'i0': 'وحشتني… ونسيت أكلي وميتي 🥺',
      'other': '$name زعلان شوية… تعالى نقعد سوا 💔',
    });
    return '$_temp0';
  }

  @override
  String petMoodHappy(String i) {
    String _temp0 = intl.Intl.selectLogic(i, {
      'i0': 'أنا مبسوط معاك 💚',
      'i1': 'شكراً إنك فاكرني 🥰',
      'other': 'إنت أحلى صاحب 🤗',
    });
    return '$_temp0';
  }

  @override
  String petMoodLogged(String i) {
    String _temp0 = intl.Intl.selectLogic(i, {
      'i0': 'يومك عامل إيه؟ ✨',
      'i1': 'أنا هنا لو احتجتني 💚',
      'other': 'سجّلت النهارده — برافو عليك 👏',
    });
    return '$_temp0';
  }

  @override
  String petMoodNudge(String i) {
    String _temp0 = intl.Intl.selectLogic(i, {
      'i0': 'سجّلت مصروفاتك النهارده؟ 📝',
      'other': 'مصروف واحد بس وأفرح بيك 🌱',
    });
    return '$_temp0';
  }

  @override
  String petFed(String i) {
    String _temp0 = intl.Intl.selectLogic(i, {
      'i0': 'يمّ يمّ! 😋',
      'i1': 'تسلم إيدك 🍎',
      'other': 'أحلى أكلة 🤤',
    });
    return '$_temp0';
  }

  @override
  String petFull(String i) {
    String _temp0 = intl.Intl.selectLogic(i, {
      'i0': 'شبعان خلاص 🤭',
      'other': 'مش قادر آكل تاني 😅',
    });
    return '$_temp0';
  }

  @override
  String petWatered(String i) {
    String _temp0 = intl.Intl.selectLogic(i, {
      'i0': 'آآه انتعشت! 💧',
      'other': 'كده أحسن بكتير 😌',
    });
    return '$_temp0';
  }

  @override
  String petWaterFull(String i) {
    String _temp0 = intl.Intl.selectLogic(i, {
      'i0': 'مش عايز مية دلوقتي 🙈',
      'other': 'شربت كفاية 😄',
    });
    return '$_temp0';
  }

  @override
  String petPetted(String i) {
    String _temp0 = intl.Intl.selectLogic(i, {
      'i0': 'هيهي بتزغزغني 🤭',
      'i1': 'كمان! كمان! 🥰',
      'other': 'بحبك 💚',
    });
    return '$_temp0';
  }

  @override
  String priceSourceLabel(String source) {
    String _temp0 = intl.Intl.selectLogic(source, {
      'yours': 'انت دفعت',
      'other': 'متوسط الناس في مدينتك',
    });
    return '$_temp0';
  }

  @override
  String get petMomentMissedYou => 'وحشتني! 💚';

  @override
  String petMomentWasSleeping(String name) {
    return '$name كان نايم مستنيك…';
  }

  @override
  String petMomentGift(int seeds) {
    return 'جبت لك $seeds 🌱 هدية رجوعك. يلا نكمّل سوا!';
  }

  @override
  String get petMomentKeepGoing => 'يلا نكمّل سوا!';

  @override
  String petMomentAwayDays(int days) {
    return 'بقالك $days أيام مش هنا، فنام تحت البطانية. دوس عليه يصحى.';
  }

  @override
  String get petMomentTapToWake => 'دوس عليه يصحى.';

  @override
  String get petMomentLetsGo => 'يلا بينا';

  @override
  String get petMomentWake => 'صحّيه 👋';

  @override
  String petMomentGrew(String name, String stage) {
    return '$name كبر! بقى $stage ✨';
  }

  @override
  String petMomentChanging(String name) {
    return '$name بيتحوّل…';
  }

  @override
  String petMomentLevel(int level) {
    return 'لفل $level! 🎉';
  }

  @override
  String get petMomentSomething => 'استنى… فيه حاجة بتحصل!';

  @override
  String petMomentLevelBody(String name) {
    return 'كل حاجة سجّلتها كبّرت $name.';
  }

  @override
  String get petMomentWow => 'يا سلام!';

  @override
  String get petLoggedFull => 'اتسجّل ✓ بس أنا شبعان خلاص 🤭';

  @override
  String get petLoggedYum => 'اتسجّل ✓ يمّ يمّ! 😋';

  @override
  String petOrbSemantics(String name, String mood) {
    return '$name — $mood. اضغط علشان تأكّله وتسقيه';
  }

  @override
  String petCareStreak(int days) {
    return '🔥 $days يوم رعاية';
  }

  @override
  String petPamper(String name) {
    return 'دلّع $name';
  }

  @override
  String get petMeterFull => 'الشبع';

  @override
  String get petMeterWater => 'الريّ';

  @override
  String get petMeterHappy => 'السعادة';

  @override
  String petTapToPamper(String name) {
    return 'اضغط على $name علشان تدلّعه';
  }

  @override
  String get petFeedButton => '🍎 أكّله';

  @override
  String get petWaterButton => '💧 اسقيه';

  @override
  String petPlayedScore(int score) {
    return 'لعبنا وجبت $score! 🏆';
  }

  @override
  String get petPlayButton => '⚽ العب معاه';

  @override
  String petGuessedRight(int right) {
    return 'خمّنت $right صح! 💰';
  }

  @override
  String get petGuessTitle => '💰 خمّن السعر';

  @override
  String petMemoryDone(int moves) {
    return 'خلصنا الذاكرة في $moves محاولات! 🧠';
  }

  @override
  String get petMemoryTitle => '🧠 ذاكرة الأسعار';

  @override
  String get petStudioButton => '👗 استوديو الرفيق';

  @override
  String petBallVerdict(String tier, String name) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'none': '$name مستني تلعب معاه تاني 🥺',
      'some': 'حلو! $name اتبسط 😊',
      'lots': 'برافو! $name طاير من الفرحة 🤩',
      'other': 'أسطورة! $name مش مصدّق 🏆',
    });
    return '$_temp0';
  }

  @override
  String petBallTitle(String name) {
    return 'العب مع $name';
  }

  @override
  String petBallScore(int score) {
    return 'النقط: $score';
  }

  @override
  String get petBallHint => 'اصطاد الكورة قبل ما تهرب!';

  @override
  String get petGameAgain => '🔁 تاني';

  @override
  String get petGameDone => 'خلصت';

  @override
  String get petGamesNoPrices => 'لسه مفيش أسعار كفاية';

  @override
  String petGamesNoPricesBody(String name) {
    return 'سجّل كام مصروف أو بلّغ عن سعر في «أسعار الناس»، و$name هيلعب معاك بيها.';
  }

  @override
  String petGuessVerdict(String tier, String name) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'all': 'كلهم صح! $name مش مصدّق 🏆',
      'half': 'برافو! عينك على الأسعار 🤩',
      'some': 'مش وحش! $name اتبسط 😊',
      'other': 'الأسعار غلبتنا المرة دي 😅 تاني؟',
    });
    return '$_temp0';
  }

  @override
  String petGuessScore(int right, int total) {
    return '$right من $total';
  }

  @override
  String petGuessProgress(int at, int total, int right) {
    return 'سؤال $at من $total · صح $right';
  }

  @override
  String petGuessQuestion(String item) {
    return 'بكام «$item»؟';
  }

  @override
  String get petGuessResult => 'النتيجة';

  @override
  String get petGuessNext => 'اللي بعده';

  @override
  String petMemoryVerdict(String tier, String name, int moves) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'iron': 'ذاكرة حديد! $name مبهور 🏆',
      'good': 'برافو! خلصتها في $moves محاولات 🤩',
      'other': 'خلصناها في $moves محاولات، $name اتبسط 😊',
    });
    return '$_temp0';
  }

  @override
  String petMemoryHint(int moves) {
    return 'وصّل كل حاجة بسعرها · محاولات $moves';
  }

  @override
  String petMeterPercent(int percent) {
    return '$percent٪';
  }

  @override
  String documentKindLabel(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'passport': 'جواز السفر',
      'nationalId': 'البطاقة الشخصية',
      'residence': 'الإقامة',
      'drivingLicense': 'رخصة القيادة',
      'vehicleLicense': 'رخصة العربية',
      'other': 'مستند تاني',
    });
    return '$_temp0';
  }

  @override
  String reminderPetThirstyTitle(String name) {
    return '💧 $name عطشان';
  }

  @override
  String reminderPetHungryTitle(String name) {
    return '🍎 $name جعان';
  }

  @override
  String get reminderPetThirstyBody =>
      'كوباية مية واحدة ويرجع يلعب — تعالى اسقيه';

  @override
  String get reminderPetHungryBody => 'مستنيك تأكّله… وحشته 🥺';

  @override
  String reminderPetCallTitle(String i, String name) {
    String _temp0 = intl.Intl.selectLogic(i, {
      'i0': '🥺 $name لسه مستنيك',
      'i1': '🍎 $name بيسأل عليك',
      'i2': '😢 $name زعلان',
      'i3': '💔 $name وحشته أوي',
      'i4': '😭 $name تعبان من الجوع',
      'other': '🌧️ $name قاعد لوحده',
    });
    return '$_temp0';
  }

  @override
  String reminderPetCallBody(String i) {
    String _temp0 = intl.Intl.selectLogic(i, {
      'i0': 'بطنه بتصوصو من الصبح… لقمة واحدة بس؟',
      'i1': 'قاعد جنب الطبق فاضي — تعالى أكّله وأسقيه',
      'i2': 'بقاله يوم من غير أكل… شكله اتبهدل ومستنيك',
      'i3': 'مش راضي يلعب من غيرك — دقيقة واحدة ترجّعه مبسوط',
      'i4': 'يومين من غير أكل ولا مية… هو لسه مستنيك',
      'other': 'كل يوم بيبص على الباب — تعالى طمّنه',
    });
    return '$_temp0';
  }

  @override
  String reminderNapTitle(String name) {
    return '😴 $name نام مستنيك';
  }

  @override
  String get reminderNapBody =>
      'بقالك يومين مش هنا — ارجع صحّيه، ومعاه بذور هدية رجوعك 🌱';

  @override
  String reminderNapAgainTitle(String name) {
    return '$name لسه نايم…';
  }

  @override
  String get reminderNapAgainBody =>
      'سجّل مصروف واحد بس وهيصحى فرحان، والسلسلة تبدأ من جديد 🔥';

  @override
  String get reminderChannelDoses => 'زاد — مواعيد الأدوية';

  @override
  String get reminderChannelTasbih => 'زاد — تذكير التسبيح';

  @override
  String get reminderChannelCompanion => 'رفيق زاد';

  @override
  String get reminderChannelSeasons => 'زاد — المناسبات القادمة';

  @override
  String get reminderChannelDocuments => 'زاد — المستندات قبل ما تنتهي';

  @override
  String get reminderDoseTaken => 'أخدتها ✅';

  @override
  String get reminderDoseSnooze => 'أجّل';

  @override
  String get reminderDoseTitle => 'موعد الدواء';

  @override
  String reminderDoseBody(String name) {
    return 'حان موعد جرعة $name';
  }

  @override
  String get reminderTasbihTitle => '🌱 وقت التسبيح';

  @override
  String get reminderTasbihBody => 'شجرتك مستنياك — سبّح شوية ونمّيها';

  @override
  String reminderSeasonName(String slug) {
    String _temp0 = intl.Intl.selectLogic(slug, {
      'ramadan': 'رمضان',
      'eid_al_fitr': 'عيد الفطر',
      'eid_al_adha': 'عيد الأضحى',
      'back_to_school': 'العودة للمدارس',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String reminderSeasonTitle(String name) {
    return '📅 $name قريباً';
  }

  @override
  String reminderSeasonBody(String name) {
    return 'استعد لمصاريف $name — ابدأ التوفير الآن';
  }

  @override
  String reminderDocumentWho(String document, String holder) {
    return '$document بتاع $holder';
  }

  @override
  String reminderDocumentToday(String document) {
    return '🪪 $document بينتهي النهارده';
  }

  @override
  String reminderDocumentInDays(String document, int days) {
    return '🪪 $document بينتهي بعد $days يوم';
  }

  @override
  String get reminderDocumentPassport =>
      'دول كتير بتطلب الجواز صالح ٦ شهور للسفر — لو فيه سفر، جدّده بدري.';

  @override
  String reminderDocumentLastDay(String date) {
    return 'آخر يوم $date — ابدأ التجديد بدري.';
  }

  @override
  String marketCountryName(String country) {
    String _temp0 = intl.Intl.selectLogic(country, {
      'SA': 'السعودية',
      'EG': 'مصر',
      'AE': 'الإمارات',
      'KW': 'الكويت',
      'QA': 'قطر',
      'BH': 'البحرين',
      'OM': 'عُمان',
      'JO': 'الأردن',
      'LB': 'لبنان',
      'IQ': 'العراق',
      'SY': 'سوريا',
      'YE': 'اليمن',
      'PS': 'فلسطين',
      'LY': 'ليبيا',
      'SD': 'السودان',
      'MA': 'المغرب',
      'TN': 'تونس',
      'DZ': 'الجزائر',
      'TR': 'تركيا',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get marketSearchHint => 'دوّر على بلدك أو عملتك';

  @override
  String orbMood(String mood) {
    String _temp0 = intl.Intl.selectLogic(mood, {
      'listening': 'زاد: بيسمع',
      'focused': 'زاد: بيفكر',
      'speaking': 'زاد: بيتكلم',
      'happy': 'زاد: مبسوط',
      'alert': 'زاد: تنبيه',
      'celebrating': 'زاد: بيحتفل',
      'sad': 'زاد: زعلان',
      'hungry': 'زاد: جعان',
      'thirsty': 'زاد: عطشان',
      'sleepy': 'زاد: نعسان',
      'other': 'زاد: هادئ',
    });
    return '$_temp0';
  }

  @override
  String orbAccessoryLabel(String accessory) {
    String _temp0 = intl.Intl.selectLogic(accessory, {
      'bow': 'فيونكة',
      'glasses': 'نضارة',
      'flower': 'وردة',
      'crown': 'تاج',
      'other': 'من غير',
    });
    return '$_temp0';
  }

  @override
  String orbPetAsleep(String name) {
    return '$name نايم';
  }

  @override
  String orbPetMood(String name, String mood) {
    return '$name: $mood';
  }
}
