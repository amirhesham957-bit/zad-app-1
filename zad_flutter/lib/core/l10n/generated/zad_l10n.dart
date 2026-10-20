import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'zad_l10n_ar.dart';
import 'zad_l10n_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of ZadL10n
/// returned by `ZadL10n.of(context)`.
///
/// Applications need to include `ZadL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/zad_l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: ZadL10n.localizationsDelegates,
///   supportedLocales: ZadL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the ZadL10n.supportedLocales
/// property.
abstract class ZadL10n {
  ZadL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static ZadL10n of(BuildContext context) {
    return Localizations.of<ZadL10n>(context, ZadL10n)!;
  }

  static const LocalizationsDelegate<ZadL10n> delegate = _ZadL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// The app's name, in the task switcher.
  ///
  /// In ar, this message translates to:
  /// **'زاد'**
  String get appTitle;

  /// Settings: the section that picks the app's language.
  ///
  /// In ar, this message translates to:
  /// **'اللغة'**
  String get settingsLanguageSection;

  /// Language choice: follow the phone's language.
  ///
  /// In ar, this message translates to:
  /// **'زي الموبايل'**
  String get languageSystem;

  /// Language choice: Arabic. Always written in Arabic.
  ///
  /// In ar, this message translates to:
  /// **'العربية'**
  String get languageArabic;

  /// Language choice: English. Always written in English.
  ///
  /// In ar, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Settings: shown under the language picker while the English translation is incomplete.
  ///
  /// In ar, this message translates to:
  /// **'الإنجليزي لسه بيتترجم — شاشات كتير هتفضل عربي لحد ما يخلص.'**
  String get languageEnglishPreview;

  /// Login: the line under the logo.
  ///
  /// In ar, this message translates to:
  /// **'تدبير ذكي لبيت هادئ'**
  String get authTagline;

  /// Login: the sign-in title, and the link back to it.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get authSignInTitle;

  /// No description provided for @authSignInSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أدخل بريدك الإلكتروني وكلمة المرور'**
  String get authSignInSubtitle;

  /// Login: the email field's label.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني'**
  String get authEmail;

  /// No description provided for @authPassword.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور'**
  String get authPassword;

  /// Tooltip on the eye icon.
  ///
  /// In ar, this message translates to:
  /// **'إظهار/إخفاء كلمة المرور'**
  String get authTogglePassword;

  /// No description provided for @authForgotPassword.
  ///
  /// In ar, this message translates to:
  /// **'نسيت كلمة المرور؟'**
  String get authForgotPassword;

  /// Login: the main button.
  ///
  /// In ar, this message translates to:
  /// **'دخول'**
  String get authSignInButton;

  /// Followed by the sign-up link; keep the trailing space.
  ///
  /// In ar, this message translates to:
  /// **'ليس لديك حساب؟ '**
  String get authNoAccount;

  /// No description provided for @authSignUpNow.
  ///
  /// In ar, this message translates to:
  /// **'سجل الآن'**
  String get authSignUpNow;

  /// No description provided for @authResetTitle.
  ///
  /// In ar, this message translates to:
  /// **'استعادة كلمة المرور'**
  String get authResetTitle;

  /// No description provided for @authResetBody.
  ///
  /// In ar, this message translates to:
  /// **'أدخل بريدك الإلكتروني. سنرسل لك رابطاً لاستعادة كلمة المرور.'**
  String get authResetBody;

  /// No description provided for @authResetSent.
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال الرابط بنجاح!'**
  String get authResetSent;

  /// No description provided for @commonClose.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق'**
  String get commonClose;

  /// No description provided for @commonSend.
  ///
  /// In ar, this message translates to:
  /// **'إرسال'**
  String get commonSend;

  /// Terms dialog: refuse.
  ///
  /// In ar, this message translates to:
  /// **'رفض'**
  String get authTermsDecline;

  /// No description provided for @authTermsAccept.
  ///
  /// In ar, this message translates to:
  /// **'موافق ومتابعة'**
  String get authTermsAccept;

  /// Sign-up: the market field.
  ///
  /// In ar, this message translates to:
  /// **'البلد'**
  String get authCountry;

  /// No description provided for @authPickCountry.
  ///
  /// In ar, this message translates to:
  /// **'اختار بلدك'**
  String get authPickCountry;

  /// Sign-up: the title and the main button.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء حساب'**
  String get authSignUpTitle;

  /// No description provided for @authSignUpSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أدخل بياناتك للمتابعة'**
  String get authSignUpSubtitle;

  /// No description provided for @authName.
  ///
  /// In ar, this message translates to:
  /// **'اسم المستخدم'**
  String get authName;

  /// An example name in the name field.
  ///
  /// In ar, this message translates to:
  /// **'محمد أحمد'**
  String get authNameHint;

  /// Followed by the terms link; keep the trailing space.
  ///
  /// In ar, this message translates to:
  /// **'أوافق على '**
  String get authAgreeTo;

  /// No description provided for @authTermsLink.
  ///
  /// In ar, this message translates to:
  /// **'الشروط وسياسة الخصوصية'**
  String get authTermsLink;

  /// No description provided for @authSignUpDone.
  ///
  /// In ar, this message translates to:
  /// **'تم التسجيل بنجاح! جاري التوجيه...'**
  String get authSignUpDone;

  /// Followed by the sign-in link; keep the trailing space.
  ///
  /// In ar, this message translates to:
  /// **'لديك حساب بالفعل؟ '**
  String get authHaveAccount;

  /// No description provided for @authSignOut.
  ///
  /// In ar, this message translates to:
  /// **'اخرج من الحساب'**
  String get authSignOut;

  /// No description provided for @authSignOutTitle.
  ///
  /// In ar, this message translates to:
  /// **'تخرج من الحساب؟'**
  String get authSignOutTitle;

  /// No description provided for @authSignOutBody.
  ///
  /// In ar, this message translates to:
  /// **'هنحتاج تدخل تاني عشان توصل لحساباتك.'**
  String get authSignOutBody;

  /// No description provided for @commonWait.
  ///
  /// In ar, this message translates to:
  /// **'استنى'**
  String get commonWait;

  /// Sign-out dialog: the confirming button.
  ///
  /// In ar, this message translates to:
  /// **'اخرج'**
  String get authSignOutConfirm;

  /// No description provided for @authErrorInvalidCredentials.
  ///
  /// In ar, this message translates to:
  /// **'الإيميل أو كلمة السر مش مظبوطة.'**
  String get authErrorInvalidCredentials;

  /// No description provided for @authErrorEmailTaken.
  ///
  /// In ar, this message translates to:
  /// **'الإيميل ده مسجّل قبل كده. جرّب تدخل بيه، أو غيّر كلمة السر.'**
  String get authErrorEmailTaken;

  /// No description provided for @authErrorWeakPassword.
  ///
  /// In ar, this message translates to:
  /// **'كلمة السر قصيرة — خليها ٦ حروف على الأقل.'**
  String get authErrorWeakPassword;

  /// No description provided for @authErrorInvalidEmail.
  ///
  /// In ar, this message translates to:
  /// **'الإيميل ده شكله مش مظبوط.'**
  String get authErrorInvalidEmail;

  /// No description provided for @authErrorEmailNotConfirmed.
  ///
  /// In ar, this message translates to:
  /// **'لسه محتاج تأكّد الإيميل. بصّ في رسايلك على اللينك اللي بعتناه.'**
  String get authErrorEmailNotConfirmed;

  /// No description provided for @authErrorRateLimited.
  ///
  /// In ar, this message translates to:
  /// **'جرّبت مرات كتير في وقت قصير. استنى شوية وحاول تاني.'**
  String get authErrorRateLimited;

  /// No description provided for @authErrorSignupDisabled.
  ///
  /// In ar, this message translates to:
  /// **'التسجيل مقفول دلوقتي.'**
  String get authErrorSignupDisabled;

  /// No description provided for @authErrorUserBanned.
  ///
  /// In ar, this message translates to:
  /// **'الحساب ده موقوف.'**
  String get authErrorUserBanned;

  /// No description provided for @authErrorOffline.
  ///
  /// In ar, this message translates to:
  /// **'مفيش اتصال بالنت — الدخول محتاج نت.'**
  String get authErrorOffline;

  /// No description provided for @authErrorServer.
  ///
  /// In ar, this message translates to:
  /// **'الخدمة مش بتردّ دلوقتي. حاول تاني بعد شوية.'**
  String get authErrorServer;

  /// No description provided for @authErrorUnknown.
  ///
  /// In ar, this message translates to:
  /// **'حصل خطأ مش متوقع. حاول تاني.'**
  String get authErrorUnknown;

  /// Sign-out dialog when writes are still waiting to be sent.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{فيه عملية واحدة لسه ما اتبعتش للسيرفر. لو خرجت دلوقتي مش هتتبعت. الأحسن تستنى لما النت يرجع.} other{فيه {count} عمليات لسه ما اتبعتش للسيرفر. لو خرجت دلوقتي مش هتتبعت. الأحسن تستنى لما النت يرجع.}}'**
  String authSignOutPending(int count);

  /// No description provided for @paywallBasicTitle.
  ///
  /// In ar, this message translates to:
  /// **'الأساسية (Basic)'**
  String get paywallBasicTitle;

  /// No description provided for @paywallBasicBadge.
  ///
  /// In ar, this message translates to:
  /// **'الأكثر اقتصاداً'**
  String get paywallBasicBadge;

  /// No description provided for @paywallBasicPerkNoAds.
  ///
  /// In ar, this message translates to:
  /// **'من غير إعلانات خالص'**
  String get paywallBasicPerkNoAds;

  /// No description provided for @paywallBasicPerkAttempts.
  ///
  /// In ar, this message translates to:
  /// **'300 محاولة في الشهر (حوالي 10 في اليوم)'**
  String get paywallBasicPerkAttempts;

  /// No description provided for @paywallBasicPerkPriority.
  ///
  /// In ar, this message translates to:
  /// **'مكانك محجوز وقت الزحمة، وزاد بيفتكر كلامكم أطول'**
  String get paywallBasicPerkPriority;

  /// No description provided for @paywallBasicPerkTelegram.
  ///
  /// In ar, this message translates to:
  /// **'صور وفويس في بوت تليجرام'**
  String get paywallBasicPerkTelegram;

  /// No description provided for @paywallPlusTitle.
  ///
  /// In ar, this message translates to:
  /// **'المتقدمة (Plus)'**
  String get paywallPlusTitle;

  /// No description provided for @paywallPlusBadge.
  ///
  /// In ar, this message translates to:
  /// **'الأكثر شعبية ⭐'**
  String get paywallPlusBadge;

  /// No description provided for @paywallAllBasicPerks.
  ///
  /// In ar, this message translates to:
  /// **'كل مزايا الأساسية'**
  String get paywallAllBasicPerks;

  /// No description provided for @paywallPlusPerkAttempts.
  ///
  /// In ar, this message translates to:
  /// **'1000 محاولة في الشهر (حوالي 33 في اليوم)'**
  String get paywallPlusPerkAttempts;

  /// No description provided for @paywallPlusPerkDaily.
  ///
  /// In ar, this message translates to:
  /// **'تكفي مسح فواتير وتحليل عميق كل يوم'**
  String get paywallPlusPerkDaily;

  /// No description provided for @paywallFamilyTitle.
  ///
  /// In ar, this message translates to:
  /// **'العيلة (Family)'**
  String get paywallFamilyTitle;

  /// No description provided for @paywallFamilyBadge.
  ///
  /// In ar, this message translates to:
  /// **'أكبر رصيد 👑'**
  String get paywallFamilyBadge;

  /// No description provided for @paywallFamilyPerkAttempts.
  ///
  /// In ar, this message translates to:
  /// **'2500 محاولة في الشهر (حوالي 83 في اليوم)'**
  String get paywallFamilyPerkAttempts;

  /// No description provided for @paywallFamilyPerkHeavy.
  ///
  /// In ar, this message translates to:
  /// **'لأكتر حد بيعتمد على زاد في البيت'**
  String get paywallFamilyPerkHeavy;

  /// No description provided for @paywallNoPlayTitle.
  ///
  /// In ar, this message translates to:
  /// **'Google Play مش متاح'**
  String get paywallNoPlayTitle;

  /// No description provided for @paywallNoPlayBody.
  ///
  /// In ar, this message translates to:
  /// **'الاشتراك بيتم من Google Play. لو زاد متثبت من ملف مش من المتجر، نزّله من Google Play وبعدين اشترك من هنا.'**
  String get paywallNoPlayBody;

  /// No description provided for @paywallNotOnPlayTitle.
  ///
  /// In ar, this message translates to:
  /// **'الباقة لسه مش على المتجر'**
  String get paywallNotOnPlayTitle;

  /// No description provided for @paywallNotOnPlayBody.
  ///
  /// In ar, this message translates to:
  /// **'الباقة دي لسه ماتفعّلتش على Google Play. جرّب تاني قريب.'**
  String get paywallNotOnPlayBody;

  /// No description provided for @paywallFailedTitle.
  ///
  /// In ar, this message translates to:
  /// **'مقدرناش نفتح Google Play'**
  String get paywallFailedTitle;

  /// No description provided for @paywallFailedBody.
  ///
  /// In ar, this message translates to:
  /// **'حصلت مشكلة وإحنا بنفتح الدفع. اتأكد من النت وجرّب تاني.'**
  String get paywallFailedBody;

  /// No description provided for @commonOk.
  ///
  /// In ar, this message translates to:
  /// **'تمام'**
  String get commonOk;

  /// No description provided for @paywallTitle.
  ///
  /// In ar, this message translates to:
  /// **'اشتراكات زاد بريميوم (Zad VIP)'**
  String get paywallTitle;

  /// No description provided for @paywallHeadline.
  ///
  /// In ar, this message translates to:
  /// **'اختر خطة زاد المناسبة لعائلتك'**
  String get paywallHeadline;

  /// No description provided for @paywallSubhead.
  ///
  /// In ar, this message translates to:
  /// **'من غير إعلانات، برصيد محاولات أكبر، ومكان محجوز وقت الزحمة — والدفع عبر متجر Google Play الرسمي.'**
  String get paywallSubhead;

  /// No description provided for @paywallSafePayment.
  ///
  /// In ar, this message translates to:
  /// **'دفع آمن ومحمي'**
  String get paywallSafePayment;

  /// No description provided for @paywallBillingNote.
  ///
  /// In ar, this message translates to:
  /// **'يتم الدفع وتجديد الاشتراك الشهري بأمان عبر حساب Google Play الخاص بك، مع إمكانية الإلغاء في أي وقت من متجر التطبيقات.'**
  String get paywallBillingNote;

  /// No description provided for @paywallStayFree.
  ///
  /// In ar, this message translates to:
  /// **'أو كمّل على المجاني'**
  String get paywallStayFree;

  /// No description provided for @paywallFreeTerms.
  ///
  /// In ar, this message translates to:
  /// **'5 محاولات بترجع كل 5 ساعات، وتسجيل المصاريف مجاني دايماً. رسالة الشات بمحاولة، مسح الفاتورة بمحاولتين، والتحليل العميق بـ3.'**
  String get paywallFreeTerms;

  /// No description provided for @paywallFromPlay.
  ///
  /// In ar, this message translates to:
  /// **'من Google Play'**
  String get paywallFromPlay;

  /// No description provided for @paywallAutoRenew.
  ///
  /// In ar, this message translates to:
  /// **'اشتراك شهري تجديد تلقائي'**
  String get paywallAutoRenew;

  /// The buy button.
  ///
  /// In ar, this message translates to:
  /// **'اشترك في {plan} عبر Google Play'**
  String paywallSubscribeTo(String plan);

  /// Under a plan's name.
  ///
  /// In ar, this message translates to:
  /// **'{count} محاولة في الشهر'**
  String paywallAttemptsPerMonth(int count);

  /// Play's formatted price, per month.
  ///
  /// In ar, this message translates to:
  /// **'{price} في الشهر'**
  String paywallPricePerMonth(String price);
}

class _ZadL10nDelegate extends LocalizationsDelegate<ZadL10n> {
  const _ZadL10nDelegate();

  @override
  Future<ZadL10n> load(Locale locale) {
    return SynchronousFuture<ZadL10n>(lookupZadL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_ZadL10nDelegate old) => false;
}

ZadL10n lookupZadL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return ZadL10nAr();
    case 'en':
      return ZadL10nEn();
  }

  throw FlutterError(
    'ZadL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
