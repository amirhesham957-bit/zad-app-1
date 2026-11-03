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
}
