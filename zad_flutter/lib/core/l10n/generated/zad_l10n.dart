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
    Locale('ar', 'SA'),
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

  /// No description provided for @authNewPasswordTitle.
  ///
  /// In ar, this message translates to:
  /// **'كلمة سر جديدة'**
  String get authNewPasswordTitle;

  /// No description provided for @authNewPasswordBody.
  ///
  /// In ar, this message translates to:
  /// **'اكتب كلمة السر الجديدة لحسابك.'**
  String get authNewPasswordBody;

  /// No description provided for @authNewPasswordSave.
  ///
  /// In ar, this message translates to:
  /// **'احفظ'**
  String get authNewPasswordSave;

  /// No description provided for @authNewPasswordDone.
  ///
  /// In ar, this message translates to:
  /// **'اتغيرت كلمة السر.'**
  String get authNewPasswordDone;

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

  /// No description provided for @adInlineLabel.
  ///
  /// In ar, this message translates to:
  /// **'إعلان'**
  String get adInlineLabel;

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
  /// **'{count, plural, =1{فيه {count} عملية لسه ما اتبعتش للسيرفر. لو خرجت دلوقتي مش هتتبعت. الأحسن تستنى لما النت يرجع.} other{فيه {count} عمليات لسه ما اتبعتش للسيرفر. لو خرجت دلوقتي مش هتتبعت. الأحسن تستنى لما النت يرجع.}}'**
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
  /// **'كل ساعتين: ٢٠ رسالة و٣ أسئلة صوتية وصورتين، وتسجيل المصاريف مجاني دايماً. التحليل العميق بـ٣ رسايل.'**
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

  /// No description provided for @navHome.
  ///
  /// In ar, this message translates to:
  /// **'الرئيسية'**
  String get navHome;

  /// No description provided for @navMoney.
  ///
  /// In ar, this message translates to:
  /// **'فلوسي'**
  String get navMoney;

  /// No description provided for @navHomeStock.
  ///
  /// In ar, this message translates to:
  /// **'بيتي'**
  String get navHomeStock;

  /// No description provided for @navMore.
  ///
  /// In ar, this message translates to:
  /// **'المزيد'**
  String get navMore;

  /// No description provided for @navFamily.
  ///
  /// In ar, this message translates to:
  /// **'العائلة'**
  String get navFamily;

  /// No description provided for @navMyFamily.
  ///
  /// In ar, this message translates to:
  /// **'عيلتي'**
  String get navMyFamily;

  /// No description provided for @navVoiceAssistant.
  ///
  /// In ar, this message translates to:
  /// **'زاد — المساعد الصوتي'**
  String get navVoiceAssistant;

  /// No description provided for @navCamera.
  ///
  /// In ar, this message translates to:
  /// **'تصوير الفواتير والمنتجات'**
  String get navCamera;

  /// No description provided for @pulseOneSaved.
  ///
  /// In ar, this message translates to:
  /// **'حاجة واحدة محفوظة'**
  String get pulseOneSaved;

  /// No description provided for @pulseTwoSaved.
  ///
  /// In ar, this message translates to:
  /// **'حاجتين محفوظين'**
  String get pulseTwoSaved;

  /// No description provided for @pulseFewSaved.
  ///
  /// In ar, this message translates to:
  /// **'{n} حاجات محفوظة'**
  String pulseFewSaved(int n);

  /// No description provided for @pulseManySaved.
  ///
  /// In ar, this message translates to:
  /// **'{n} حاجة محفوظة'**
  String pulseManySaved(int n);

  /// No description provided for @pulseOffline.
  ///
  /// In ar, this message translates to:
  /// **'مفيش نت — {what} وهتتبعت أول ما النت يرجع'**
  String pulseOffline(String what);

  /// No description provided for @pulseThinking.
  ///
  /// In ar, this message translates to:
  /// **'زاد بيفكر…'**
  String get pulseThinking;

  /// No description provided for @pulseSyncing.
  ///
  /// In ar, this message translates to:
  /// **'بنزامن…'**
  String get pulseSyncing;

  /// No description provided for @authPreparingAccount.
  ///
  /// In ar, this message translates to:
  /// **'بنجهّز حسابك…'**
  String get authPreparingAccount;

  /// No description provided for @shareTooLarge.
  ///
  /// In ar, this message translates to:
  /// **'الملف أكبر من إن زاد يقراه مرة واحدة — ابعته أصغر'**
  String get shareTooLarge;

  /// No description provided for @shareUnsupported.
  ///
  /// In ar, this message translates to:
  /// **'زاد بيقرا الكلام والصور وملفات PDF وCSV بس'**
  String get shareUnsupported;

  /// No description provided for @shareUnreadable.
  ///
  /// In ar, this message translates to:
  /// **'مقدرتش أفتح اللي اتشارك — جرّب تبعته تاني'**
  String get shareUnreadable;

  /// No description provided for @shareWhatImage.
  ///
  /// In ar, this message translates to:
  /// **'الصورة دي إيه؟'**
  String get shareWhatImage;

  /// No description provided for @shareWhatImageHint.
  ///
  /// In ar, this message translates to:
  /// **'زاد هيقراها ويوريك اللي لقاه قبل ما يسجل أي حاجة'**
  String get shareWhatImageHint;

  /// No description provided for @shareReceipt.
  ///
  /// In ar, this message translates to:
  /// **'فاتورة شرا'**
  String get shareReceipt;

  /// No description provided for @shareStatement.
  ///
  /// In ar, this message translates to:
  /// **'كشف حساب'**
  String get shareStatement;

  /// No description provided for @drawerCompanion.
  ///
  /// In ar, this message translates to:
  /// **'رفيق زاد'**
  String get drawerCompanion;

  /// No description provided for @drawerBrain.
  ///
  /// In ar, this message translates to:
  /// **'عقل زاد'**
  String get drawerBrain;

  /// No description provided for @drawerAppointments.
  ///
  /// In ar, this message translates to:
  /// **'مواعيدي'**
  String get drawerAppointments;

  /// No description provided for @drawerPlaces.
  ///
  /// In ar, this message translates to:
  /// **'أماكني'**
  String get drawerPlaces;

  /// No description provided for @drawerObligations.
  ///
  /// In ar, this message translates to:
  /// **'التزاماتي'**
  String get drawerObligations;

  /// No description provided for @drawerPlans.
  ///
  /// In ar, this message translates to:
  /// **'باقات زاد الشهرية'**
  String get drawerPlans;

  /// No description provided for @drawerShopping.
  ///
  /// In ar, this message translates to:
  /// **'قائمة التسوق'**
  String get drawerShopping;

  /// No description provided for @drawerPharmacy.
  ///
  /// In ar, this message translates to:
  /// **'صيدلية العائلة'**
  String get drawerPharmacy;

  /// No description provided for @drawerMaintenance.
  ///
  /// In ar, this message translates to:
  /// **'صيانة المنزل'**
  String get drawerMaintenance;

  /// No description provided for @drawerDocuments.
  ///
  /// In ar, this message translates to:
  /// **'مستنداتي'**
  String get drawerDocuments;

  /// No description provided for @drawerNearby.
  ///
  /// In ar, this message translates to:
  /// **'العروض والمحلات القريبة'**
  String get drawerNearby;

  /// No description provided for @drawerTips.
  ///
  /// In ar, this message translates to:
  /// **'نصايح زاد'**
  String get drawerTips;

  /// No description provided for @drawerTasbiha.
  ///
  /// In ar, this message translates to:
  /// **'تسبيحة'**
  String get drawerTasbiha;

  /// No description provided for @drawerNotifications.
  ///
  /// In ar, this message translates to:
  /// **'الإشعارات'**
  String get drawerNotifications;

  /// No description provided for @drawerAccount.
  ///
  /// In ar, this message translates to:
  /// **'حسابي'**
  String get drawerAccount;

  /// No description provided for @drawerGroupZad.
  ///
  /// In ar, this message translates to:
  /// **'زاد'**
  String get drawerGroupZad;

  /// No description provided for @drawerGroupMoney.
  ///
  /// In ar, this message translates to:
  /// **'الفلوس'**
  String get drawerGroupMoney;

  /// No description provided for @drawerGroupHome.
  ///
  /// In ar, this message translates to:
  /// **'البيت والعيلة'**
  String get drawerGroupHome;

  /// No description provided for @drawerAllFeatures.
  ///
  /// In ar, this message translates to:
  /// **'كل المزايا'**
  String get drawerAllFeatures;

  /// No description provided for @placesOrbitHome.
  ///
  /// In ar, this message translates to:
  /// **'البيت'**
  String get placesOrbitHome;

  /// No description provided for @placesOrbitCaption.
  ///
  /// In ar, this message translates to:
  /// **'الأقرب للبيت هو اللي بتروحه أكتر، مش المسافة الحقيقية.'**
  String get placesOrbitCaption;

  /// No description provided for @placesHabitVisits.
  ///
  /// In ar, this message translates to:
  /// **'{count} مرات'**
  String placesHabitVisits(int count);

  /// No description provided for @placesHabitVisitsOn.
  ///
  /// In ar, this message translates to:
  /// **'{count} مرات · غالباً {day}'**
  String placesHabitVisitsOn(int count, String day);

  /// No description provided for @placesOrbitNode.
  ///
  /// In ar, this message translates to:
  /// **'{name}، {count} مرات'**
  String placesOrbitNode(String name, int count);

  /// No description provided for @memoryGraphResetView.
  ///
  /// In ar, this message translates to:
  /// **'رجّع الشبكة مكانها'**
  String get memoryGraphResetView;

  /// No description provided for @drawerGroupMore.
  ///
  /// In ar, this message translates to:
  /// **'أكتر'**
  String get drawerGroupMore;

  /// No description provided for @drawerKidsMode.
  ///
  /// In ar, this message translates to:
  /// **'وضع الأطفال'**
  String get drawerKidsMode;

  /// No description provided for @drawerFullMode.
  ///
  /// In ar, this message translates to:
  /// **'الوضع الكامل'**
  String get drawerFullMode;

  /// No description provided for @shellOpenProfile.
  ///
  /// In ar, this message translates to:
  /// **'اضغط لعرض الملف الشخصي'**
  String get shellOpenProfile;

  /// No description provided for @shellZadUser.
  ///
  /// In ar, this message translates to:
  /// **'مستخدم زاد'**
  String get shellZadUser;

  /// No description provided for @shellHello.
  ///
  /// In ar, this message translates to:
  /// **'أهلاً بيك'**
  String get shellHello;

  /// No description provided for @shellHelloName.
  ///
  /// In ar, this message translates to:
  /// **'أهلاً يا {name}'**
  String shellHelloName(String name);

  /// The companion's name and level on the drawer card.
  ///
  /// In ar, this message translates to:
  /// **'{name} · لفل {level}'**
  String shellCompanionTag(String name, int level);

  /// No description provided for @widgetSeasonTomorrow.
  ///
  /// In ar, this message translates to:
  /// **'بكرة {name}'**
  String widgetSeasonTomorrow(String name);

  /// No description provided for @widgetSeasonTwoDays.
  ///
  /// In ar, this message translates to:
  /// **'باقي يومين على {name}'**
  String widgetSeasonTwoDays(String name);

  /// No description provided for @widgetSeasonDays.
  ///
  /// In ar, this message translates to:
  /// **'باقي {n} أيام على {name}'**
  String widgetSeasonDays(int n, String name);

  /// No description provided for @homeFxExcluded.
  ///
  /// In ar, this message translates to:
  /// **'استُبعدت {count} معاملة من الإجمالي — عملتها مالهاش سعر صرف'**
  String homeFxExcluded(int count);

  /// No description provided for @homeBankListening.
  ///
  /// In ar, this message translates to:
  /// **'بسمع رسايل البنك وحدّث رصيدك تلقائياً'**
  String get homeBankListening;

  /// No description provided for @homeBankStopped.
  ///
  /// In ar, this message translates to:
  /// **'الاستماع لرسايل البنك وقف — اضغط للإصلاح'**
  String get homeBankStopped;

  /// No description provided for @homeBirthday.
  ///
  /// In ar, this message translates to:
  /// **'كل سنة وإنت طيب! 🎂'**
  String get homeBirthday;

  /// No description provided for @homeBirthdayName.
  ///
  /// In ar, this message translates to:
  /// **'كل سنة وإنت طيب يا {who}! 🎂'**
  String homeBirthdayName(String who);

  /// No description provided for @homeBirthdayWish.
  ///
  /// In ar, this message translates to:
  /// **'زاد بيتمنالك سنة حلوة مليانة خير وراحة بال.'**
  String get homeBirthdayWish;

  /// No description provided for @homeBirthdayThanks.
  ///
  /// In ar, this message translates to:
  /// **'شكراً يا زاد 💚'**
  String get homeBirthdayThanks;

  /// No description provided for @commonHide.
  ///
  /// In ar, this message translates to:
  /// **'إخفاء'**
  String get commonHide;

  /// No description provided for @homeStoriesLabel.
  ///
  /// In ar, this message translates to:
  /// **'حكايات زاد: {name}'**
  String homeStoriesLabel(String name);

  /// No description provided for @homeStories.
  ///
  /// In ar, this message translates to:
  /// **'حكايات زاد'**
  String get homeStories;

  /// No description provided for @homeCloseDay.
  ///
  /// In ar, this message translates to:
  /// **'اقفل يومك'**
  String get homeCloseDay;

  /// No description provided for @homeCloseDayHint.
  ///
  /// In ar, this message translates to:
  /// **'عشر ثواني: صرفت حاجة كاش النهارده؟ ورفيقك يتعشى'**
  String get homeCloseDayHint;

  /// No description provided for @coverageBlind.
  ///
  /// In ar, this message translates to:
  /// **'لسه مش شايف أي مصروف الدورة دي'**
  String get coverageBlind;

  /// No description provided for @coverageBlindHint.
  ///
  /// In ar, this message translates to:
  /// **'قفّل يومك أو اربط البنك عشان أشوف'**
  String get coverageBlindHint;

  /// No description provided for @coverageFull.
  ///
  /// In ar, this message translates to:
  /// **'أنا شايف تقريباً كل مصروفك'**
  String get coverageFull;

  /// No description provided for @coverageFullHint.
  ///
  /// In ar, this message translates to:
  /// **'كمّل كده، الأرقام اللي فوق دي حقيقية'**
  String get coverageFullHint;

  /// No description provided for @coveragePartial.
  ///
  /// In ar, this message translates to:
  /// **'أنا شايف حوالي {share} من مصروفك'**
  String coveragePartial(String share);

  /// No description provided for @coveragePartialHint.
  ///
  /// In ar, this message translates to:
  /// **'قفّل يومك أو اربط البنك عشان أشوف أكتر'**
  String get coveragePartialHint;

  /// No description provided for @briefTitle.
  ///
  /// In ar, this message translates to:
  /// **'موجز زاد النهارده'**
  String get briefTitle;

  /// No description provided for @briefAllGood.
  ///
  /// In ar, this message translates to:
  /// **'كله تمام — مفيش حاجة مستعجلة النهارده.'**
  String get briefAllGood;

  /// No description provided for @briefAskZad.
  ///
  /// In ar, this message translates to:
  /// **'اسأل زاد عن أي حاجة'**
  String get briefAskZad;

  /// No description provided for @glanceStockTitle.
  ///
  /// In ar, this message translates to:
  /// **'صحة المخزون والنواقص'**
  String get glanceStockTitle;

  /// No description provided for @glanceStockSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'مراقبة التلف والاحتياج الفعلي'**
  String get glanceStockSubtitle;

  /// No description provided for @glanceOpenStock.
  ///
  /// In ar, this message translates to:
  /// **'فتح المخزون ←'**
  String get glanceOpenStock;

  /// No description provided for @glanceStockHealth.
  ///
  /// In ar, this message translates to:
  /// **'مؤشر سلامة المؤونة'**
  String get glanceStockHealth;

  /// No description provided for @glanceStockPercent.
  ///
  /// In ar, this message translates to:
  /// **'{percent}% مكتمل'**
  String glanceStockPercent(int percent);

  /// No description provided for @glanceStockEmpty.
  ///
  /// In ar, this message translates to:
  /// **'المخزن لسه فاضي'**
  String get glanceStockEmpty;

  /// No description provided for @glanceStockEmptyHint.
  ///
  /// In ar, this message translates to:
  /// **'صوّر فاتورة السوبرماركت أو ضيف أصنافك، وزاد يقولك إيه قرب يخلص قبل ما تحتاجه'**
  String get glanceStockEmptyHint;

  /// No description provided for @glanceLowCount.
  ///
  /// In ar, this message translates to:
  /// **'{count} قارب النفاد'**
  String glanceLowCount(int count);

  /// No description provided for @glanceExpired.
  ///
  /// In ar, this message translates to:
  /// **'انتهت صلاحيته'**
  String get glanceExpired;

  /// No description provided for @glanceDaysLeft.
  ///
  /// In ar, this message translates to:
  /// **'{days, plural, zero{متبقي {days} أيام} one{متبقي {days} أيام} two{متبقي {days} أيام} few{متبقي {days} أيام} other{متبقي {days} يوم}}'**
  String glanceDaysLeft(int days);

  /// No description provided for @glanceQtyLeft.
  ///
  /// In ar, this message translates to:
  /// **'متبقي {qty}'**
  String glanceQtyLeft(String qty);

  /// No description provided for @glanceRunningOut.
  ///
  /// In ar, this message translates to:
  /// **'قارب ينتهي'**
  String get glanceRunningOut;

  /// No description provided for @glanceAddToCart.
  ///
  /// In ar, this message translates to:
  /// **'أضف للسلة'**
  String get glanceAddToCart;

  /// No description provided for @glancePharmacyEmptyLabel.
  ///
  /// In ar, this message translates to:
  /// **'مفيش أدوية مسجّلة'**
  String get glancePharmacyEmptyLabel;

  /// No description provided for @glanceAdherence.
  ///
  /// In ar, this message translates to:
  /// **'الالتزام بالجرعات: {percent}% • {verdict}'**
  String glanceAdherence(int percent, String verdict);

  /// No description provided for @glanceAdherenceGood.
  ///
  /// In ar, this message translates to:
  /// **'منتظم'**
  String get glanceAdherenceGood;

  /// No description provided for @glanceAdherenceLow.
  ///
  /// In ar, this message translates to:
  /// **'محتاج انتباه'**
  String get glanceAdherenceLow;

  /// No description provided for @glanceActiveMedicines.
  ///
  /// In ar, this message translates to:
  /// **'{count} دواء نشط • لسه بنجمّع بيانات الالتزام'**
  String glanceActiveMedicines(int count);

  /// No description provided for @glancePharmacyTitle.
  ///
  /// In ar, this message translates to:
  /// **'صيدلية العائلة والجرعات'**
  String get glancePharmacyTitle;

  /// No description provided for @glanceOpenPharmacy.
  ///
  /// In ar, this message translates to:
  /// **'فتح الصيدلية ←'**
  String get glanceOpenPharmacy;

  /// No description provided for @glancePharmacyEmpty.
  ///
  /// In ar, this message translates to:
  /// **'الصيدلية فاضية'**
  String get glancePharmacyEmpty;

  /// No description provided for @glancePharmacyEmptyHint.
  ///
  /// In ar, this message translates to:
  /// **'صوّر شريط الدواء أو ضيفه يدوي، وزاد هيفكّرك بمواعيد الجرعات وينبّهك قبل ما يخلص'**
  String get glancePharmacyEmptyHint;

  /// No description provided for @glanceNextDose.
  ///
  /// In ar, this message translates to:
  /// **'الجرعة التالية'**
  String get glanceNextDose;

  /// No description provided for @glanceTookDose.
  ///
  /// In ar, this message translates to:
  /// **'خدت الجرعة'**
  String get glanceTookDose;

  /// No description provided for @glanceDosesPerDay.
  ///
  /// In ar, this message translates to:
  /// **'{count} جرعة يومياً'**
  String glanceDosesPerDay(int count);

  /// No description provided for @glanceSubsTitle.
  ///
  /// In ar, this message translates to:
  /// **'الاشتراكات الشهرية'**
  String get glanceSubsTitle;

  /// No description provided for @glanceSubsNone.
  ///
  /// In ar, this message translates to:
  /// **'مفيش اشتراكات مسجّلة'**
  String get glanceSubsNone;

  /// No description provided for @glanceSubsTotal.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي شهري: {amount}'**
  String glanceSubsTotal(String amount);

  /// No description provided for @glanceSeeAll.
  ///
  /// In ar, this message translates to:
  /// **'عرض الكل ←'**
  String get glanceSeeAll;

  /// No description provided for @glanceSubsEmpty.
  ///
  /// In ar, this message translates to:
  /// **'مفيش اشتراكات لسه'**
  String get glanceSubsEmpty;

  /// No description provided for @glanceSubsEmptyHint.
  ///
  /// In ar, this message translates to:
  /// **'ضيف اشتراكاتك الشهرية عشان زاد يحسبها في المتاح ويفكّرك بمواعيد التجديد'**
  String get glanceSubsEmptyHint;

  /// No description provided for @glanceNextRenewal.
  ///
  /// In ar, this message translates to:
  /// **'التجديد القادم: {title}'**
  String glanceNextRenewal(String title);

  /// No description provided for @glanceInstalment.
  ///
  /// In ar, this message translates to:
  /// **'القسط: {amount}'**
  String glanceInstalment(String amount);

  /// No description provided for @groceryWhatToAdd.
  ///
  /// In ar, this message translates to:
  /// **'اشتريت من {shop} بـ {amount} — ضيف إيه للمخزون؟'**
  String groceryWhatToAdd(String shop, String amount);

  /// No description provided for @groceryOtherItem.
  ///
  /// In ar, this message translates to:
  /// **'اسم منتج تاني…'**
  String get groceryOtherItem;

  /// No description provided for @commonAdd.
  ///
  /// In ar, this message translates to:
  /// **'إضافة'**
  String get commonAdd;

  /// No description provided for @groceryAdded.
  ///
  /// In ar, this message translates to:
  /// **'أضفت {count} أصناف ✅'**
  String groceryAdded(int count);

  /// No description provided for @commonDone.
  ///
  /// In ar, this message translates to:
  /// **'تم'**
  String get commonDone;

  /// No description provided for @activationTitle.
  ///
  /// In ar, this message translates to:
  /// **'جهّز زاد لبيتك'**
  String get activationTitle;

  /// No description provided for @activationSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أربع خطوات تجعل الرصيد والتنبيهات والتوقعات مفيدة من أول يوم'**
  String get activationSubtitle;

  /// No description provided for @activationProgress.
  ///
  /// In ar, this message translates to:
  /// **'{done} من {total}'**
  String activationProgress(int done, int total);

  /// No description provided for @activationBalance.
  ///
  /// In ar, this message translates to:
  /// **'ثبّت رصيد البداية'**
  String get activationBalance;

  /// No description provided for @activationBalanceHint.
  ///
  /// In ar, this message translates to:
  /// **'اكتب المبلغ الموجود الآن ليحسب زاد السحب والإيداع بدقة'**
  String get activationBalanceHint;

  /// No description provided for @activationBank.
  ///
  /// In ar, this message translates to:
  /// **'فعّل قراءة إشعارات البنك'**
  String get activationBank;

  /// No description provided for @activationBankHint.
  ///
  /// In ar, this message translates to:
  /// **'اسمح لزاد بالتقاط العمليات وعرضها للتأكيد'**
  String get activationBankHint;

  /// No description provided for @activationFirstItem.
  ///
  /// In ar, this message translates to:
  /// **'أضف أول صنف للبيت'**
  String get activationFirstItem;

  /// No description provided for @activationFirstItemHint.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ بصنف متكرر ليتعلم زاد استهلاكك'**
  String get activationFirstItemHint;

  /// No description provided for @activationGoal.
  ///
  /// In ar, this message translates to:
  /// **'حدد أول هدف لبيتك'**
  String get activationGoal;

  /// No description provided for @activationGoalHint.
  ///
  /// In ar, this message translates to:
  /// **'زاد هيتابعه معاك كل أسبوع'**
  String get activationGoalHint;

  /// No description provided for @activationAllSet.
  ///
  /// In ar, this message translates to:
  /// **'كل حاجة جاهزة! 🎉 جرب تقول لزاد \"صرفت ٥٠ بقالة\" بالصوت أو من بوت تليجرام — هيسألك تأكيد ويسجلها.'**
  String get activationAllSet;

  /// No description provided for @commonOpen.
  ///
  /// In ar, this message translates to:
  /// **'فتح'**
  String get commonOpen;

  /// No description provided for @amazonOutOfStock.
  ///
  /// In ar, this message translates to:
  /// **'خلص من مخزونك'**
  String get amazonOutOfStock;

  /// No description provided for @amazonRunningLow.
  ///
  /// In ar, this message translates to:
  /// **'قارب على النفاد'**
  String get amazonRunningLow;

  /// No description provided for @amazonOnList.
  ///
  /// In ar, this message translates to:
  /// **'في قايمة التسوق'**
  String get amazonOnList;

  /// No description provided for @amazonSuggestion.
  ///
  /// In ar, this message translates to:
  /// **'اقتراح لبيتك'**
  String get amazonSuggestion;

  /// No description provided for @amazonShop.
  ///
  /// In ar, this message translates to:
  /// **'تسوق من أمازون'**
  String get amazonShop;

  /// No description provided for @amazonApproxPrice.
  ///
  /// In ar, this message translates to:
  /// **'سعر تقريبي'**
  String get amazonApproxPrice;

  /// No description provided for @amazonUpdatedToday.
  ///
  /// In ar, this message translates to:
  /// **'اتحدث النهاردة'**
  String get amazonUpdatedToday;

  /// No description provided for @amazonPriceAge.
  ///
  /// In ar, this message translates to:
  /// **'سعر منذ {days} يوم'**
  String amazonPriceAge(int days);

  /// No description provided for @amazonName.
  ///
  /// In ar, this message translates to:
  /// **'أمازون'**
  String get amazonName;

  /// No description provided for @amazonDisclosure.
  ///
  /// In ar, this message translates to:
  /// **'رابط شراء أفلييت — عمولة لزاد بدون أي زيادة عليك'**
  String get amazonDisclosure;

  /// No description provided for @amazonOut.
  ///
  /// In ar, this message translates to:
  /// **'خلص'**
  String get amazonOut;

  /// No description provided for @amazonLow.
  ///
  /// In ar, this message translates to:
  /// **'قرب يخلص'**
  String get amazonLow;

  /// No description provided for @amazonShopEmoji.
  ///
  /// In ar, this message translates to:
  /// **'🛍️ تسوق من أمازون'**
  String get amazonShopEmoji;

  /// No description provided for @amazonNoNeeds.
  ///
  /// In ar, this message translates to:
  /// **'ضيف اللي ناقصك، أو شوف عروض النهارده'**
  String get amazonNoNeeds;

  /// No description provided for @amazonOneNeed.
  ///
  /// In ar, this message translates to:
  /// **'ناقصك {name} — اطلبه من أمازون'**
  String amazonOneNeed(String name);

  /// No description provided for @amazonManyNeeds.
  ///
  /// In ar, this message translates to:
  /// **'ناقصك {count} حاجات — اطلب كل واحدة بضغطة'**
  String amazonManyNeeds(int count);

  /// No description provided for @amazonSuggest.
  ///
  /// In ar, this message translates to:
  /// **'اقتراح'**
  String get amazonSuggest;

  /// No description provided for @amazonDeals.
  ///
  /// In ar, this message translates to:
  /// **'العروض'**
  String get amazonDeals;

  /// No description provided for @amazonOrder.
  ///
  /// In ar, this message translates to:
  /// **'🛒 اطلبه'**
  String get amazonOrder;

  /// No description provided for @homeOffline.
  ///
  /// In ar, this message translates to:
  /// **'مفيش اتصال بالإنترنت'**
  String get homeOffline;

  /// No description provided for @homeOfflineHint.
  ///
  /// In ar, this message translates to:
  /// **'بياناتك بتتحفظ محلياً وهتتزامن أول ما النت يرجع'**
  String get homeOfflineHint;

  /// No description provided for @homeTalkToZad.
  ///
  /// In ar, this message translates to:
  /// **'كلّم زاد'**
  String get homeTalkToZad;

  /// No description provided for @homeHello.
  ///
  /// In ar, this message translates to:
  /// **'أهلاً يا {name}! 👋'**
  String homeHello(String name);

  /// No description provided for @homeBrainActive.
  ///
  /// In ar, this message translates to:
  /// **'عقل زاد نشط'**
  String get homeBrainActive;

  /// No description provided for @homeScanPantry.
  ///
  /// In ar, this message translates to:
  /// **'مسح مخزون'**
  String get homeScanPantry;

  /// No description provided for @homeRecent.
  ///
  /// In ar, this message translates to:
  /// **'أحدث المعاملات'**
  String get homeRecent;

  /// No description provided for @commonSeeAll.
  ///
  /// In ar, this message translates to:
  /// **'عرض الكل'**
  String get commonSeeAll;

  /// No description provided for @homeRecentEmpty.
  ///
  /// In ar, this message translates to:
  /// **'سيتم عرض المعاملات البنكية هنا'**
  String get homeRecentEmpty;

  /// No description provided for @homeAllTransactions.
  ///
  /// In ar, this message translates to:
  /// **'السجل الكامل للمعاملات'**
  String get homeAllTransactions;

  /// No description provided for @dayToday.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get dayToday;

  /// No description provided for @dayYesterday.
  ///
  /// In ar, this message translates to:
  /// **'أمس'**
  String get dayYesterday;

  /// No description provided for @dayAgo.
  ///
  /// In ar, this message translates to:
  /// **'قبل {days} أيام'**
  String dayAgo(int days);

  /// No description provided for @homeServerDown.
  ///
  /// In ar, this message translates to:
  /// **'مقدرتش أوصل للسيرفر'**
  String get homeServerDown;

  /// No description provided for @homePreparing.
  ///
  /// In ar, this message translates to:
  /// **'بنجهّز ميزانيتك'**
  String get homePreparing;

  /// No description provided for @homeServerDownHint.
  ///
  /// In ar, this message translates to:
  /// **'هنحاول تاني لوحدنا. تقدر تسحب الشاشة لتحت دلوقتي.'**
  String get homeServerDownHint;

  /// No description provided for @homePreparingHint.
  ///
  /// In ar, this message translates to:
  /// **'ثانية واحدة وهتلاقي كل حاجة هنا.'**
  String get homePreparingHint;

  /// No description provided for @checkInFinished.
  ///
  /// In ar, this message translates to:
  /// **'هل خلص {item}؟'**
  String checkInFinished(String item);

  /// No description provided for @checkInHint.
  ///
  /// In ar, this message translates to:
  /// **'حسب معدل استهلاكك، المفروض قرب يخلص'**
  String get checkInHint;

  /// No description provided for @checkInDone.
  ///
  /// In ar, this message translates to:
  /// **'خلص'**
  String get checkInDone;

  /// No description provided for @checkInNotYet.
  ///
  /// In ar, this message translates to:
  /// **'لسه'**
  String get checkInNotYet;

  /// No description provided for @metricsSafeDaily.
  ///
  /// In ar, this message translates to:
  /// **'معدل الصرف اليومي الآمن'**
  String get metricsSafeDaily;

  /// No description provided for @metricsToMonthEnd.
  ///
  /// In ar, this message translates to:
  /// **'لحد آخر الشهر'**
  String get metricsToMonthEnd;

  /// No description provided for @metricsToPayday.
  ///
  /// In ar, this message translates to:
  /// **'لحد القبض'**
  String get metricsToPayday;

  /// No description provided for @metricsDays.
  ///
  /// In ar, this message translates to:
  /// **'{days} يوم'**
  String metricsDays(int days);

  /// No description provided for @commonNotNow.
  ///
  /// In ar, this message translates to:
  /// **'مش دلوقتي'**
  String get commonNotNow;

  /// No description provided for @quietRestoreFailed.
  ///
  /// In ar, this message translates to:
  /// **'مقدرتش أرجّع التنبيهات. جرّب تاني.'**
  String get quietRestoreFailed;

  /// No description provided for @quietRestore.
  ///
  /// In ar, this message translates to:
  /// **'رجّع التنبيهات'**
  String get quietRestore;

  /// No description provided for @metricsPaydayOn.
  ///
  /// In ar, this message translates to:
  /// **'يوم {day} {month}'**
  String metricsPaydayOn(int day, String month);

  /// No description provided for @sectionPantry.
  ///
  /// In ar, this message translates to:
  /// **'المخزون'**
  String get sectionPantry;

  /// No description provided for @sectionBudget.
  ///
  /// In ar, this message translates to:
  /// **'الميزانية'**
  String get sectionBudget;

  /// No description provided for @sectionSubscriptions.
  ///
  /// In ar, this message translates to:
  /// **'الاشتراكات'**
  String get sectionSubscriptions;

  /// No description provided for @sectionMap.
  ///
  /// In ar, this message translates to:
  /// **'خريطة زاد'**
  String get sectionMap;

  /// No description provided for @sectionStatement.
  ///
  /// In ar, this message translates to:
  /// **'استيراد كشف حساب'**
  String get sectionStatement;

  /// No description provided for @sectionPlans.
  ///
  /// In ar, this message translates to:
  /// **'باقات زاد الشهرية الذكية'**
  String get sectionPlans;

  /// No description provided for @sectionWithBadge.
  ///
  /// In ar, this message translates to:
  /// **'{name}، {count}'**
  String sectionWithBadge(String name, int count);

  /// No description provided for @sectionsFewer.
  ///
  /// In ar, this message translates to:
  /// **'أقسام أقل'**
  String get sectionsFewer;

  /// No description provided for @sectionsAll.
  ///
  /// In ar, this message translates to:
  /// **'كل الأقسام ({count})'**
  String sectionsAll(int count);

  /// No description provided for @tasbihaGarden.
  ///
  /// In ar, this message translates to:
  /// **'بستان التسبيح'**
  String get tasbihaGarden;

  /// No description provided for @tasbihaProgress.
  ///
  /// In ar, this message translates to:
  /// **'{clicks} من {target} تسبيحة'**
  String tasbihaProgress(int clicks, int target);

  /// No description provided for @travelSwitch.
  ///
  /// In ar, this message translates to:
  /// **'شكلك في {country} — أحوّل لـ {currency}؟'**
  String travelSwitch(String country, String currency);

  /// No description provided for @travelSwitchButton.
  ///
  /// In ar, this message translates to:
  /// **'تحويل'**
  String get travelSwitchButton;

  /// No description provided for @commonDismiss.
  ///
  /// In ar, this message translates to:
  /// **'تجاهل'**
  String get commonDismiss;

  /// No description provided for @recipeAskSpoil.
  ///
  /// In ar, this message translates to:
  /// **'اقترح وصفات بـ {items} قبل ما تتلف'**
  String recipeAskSpoil(String items);

  /// No description provided for @recipeAskRunOut.
  ///
  /// In ar, this message translates to:
  /// **'اقترح وصفات بـ {items} قبل ما تخلص'**
  String recipeAskRunOut(String items);

  /// Joins names in a list: «رز، زيت».
  ///
  /// In ar, this message translates to:
  /// **'، '**
  String get listSeparator;

  /// No description provided for @recipeStagnant.
  ///
  /// In ar, this message translates to:
  /// **'عندك {names} من فترة وماستخدمتهاش 🤔'**
  String recipeStagnant(String names);

  /// No description provided for @recipeRunningOut.
  ///
  /// In ar, this message translates to:
  /// **'عندك {names} هيخلص قريب 👀'**
  String recipeRunningOut(String names);

  /// No description provided for @recipeStagnantHint.
  ///
  /// In ar, this message translates to:
  /// **'وصفات تساعدك تستخدمها قبل ما تتلف'**
  String get recipeStagnantHint;

  /// No description provided for @recipeRunningOutHint.
  ///
  /// In ar, this message translates to:
  /// **'وصفات مقترحة بيه قبل ما يضيع'**
  String get recipeRunningOutHint;

  /// No description provided for @recipeOpenChat.
  ///
  /// In ar, this message translates to:
  /// **'اضغط للمزيد في شات زاد ←'**
  String get recipeOpenChat;

  /// No description provided for @profileSaveFailed.
  ///
  /// In ar, this message translates to:
  /// **'مقدرناش نحفظ الملف — جرب تاني'**
  String get profileSaveFailed;

  /// No description provided for @whoTitle.
  ///
  /// In ar, this message translates to:
  /// **'عرّفني بنفسك'**
  String get whoTitle;

  /// No description provided for @whoBody.
  ///
  /// In ar, this message translates to:
  /// **'اسمك، وتحب أكلمك بصيغة راجل ولا ست، وشغلك وميعاد قبضك — عشان أكلمك صح وأفتكرك.'**
  String get whoBody;

  /// No description provided for @whoGo.
  ///
  /// In ar, this message translates to:
  /// **'يلا نتعرّف'**
  String get whoGo;

  /// No description provided for @commonLater.
  ///
  /// In ar, this message translates to:
  /// **'لاحقاً'**
  String get commonLater;

  /// A month's name; month is m1..m12. Without date-format data, so it works anywhere.
  ///
  /// In ar, this message translates to:
  /// **'{month, select, m1{يناير} m2{فبراير} m3{مارس} m4{أبريل} m5{مايو} m6{يونيو} m7{يوليو} m8{أغسطس} m9{سبتمبر} m10{أكتوبر} m11{نوفمبر} m12{ديسمبر} other{}}'**
  String monthName(String month);

  /// No description provided for @chatVoiceUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'الصوت مش متاح دلوقتي — الرد مكتوب قدامك'**
  String get chatVoiceUnavailable;

  /// No description provided for @chatNewTooltip.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ محادثة جديدة'**
  String get chatNewTooltip;

  /// No description provided for @chatNewTitle.
  ///
  /// In ar, this message translates to:
  /// **'تبدأ محادثة جديدة؟'**
  String get chatNewTitle;

  /// No description provided for @chatNewBody.
  ///
  /// In ar, this message translates to:
  /// **'الكلام اللي فات هيتمسح من التليفون ده. اللي زاد اتعلمه عنك هيفضل زي ما هو.'**
  String get chatNewBody;

  /// No description provided for @chatClear.
  ///
  /// In ar, this message translates to:
  /// **'امسح'**
  String get chatClear;

  /// No description provided for @chatWelcome.
  ///
  /// In ar, this message translates to:
  /// **'أهلاً بيك! أنا زاد 🤖، مساعدك العائلي الذكي. أقدر أساعدك إزاي النهاردة؟\nاسألني عن الوصفات، أو راجع ثلاجتك، أو ضيف النواقص لقائمة التسوق!'**
  String get chatWelcome;

  /// No description provided for @chatBusy.
  ///
  /// In ar, this message translates to:
  /// **'الذكاء الاصطناعي مشغول شوية دلوقتي 🙏 جرب تاني بعد لحظات.'**
  String get chatBusy;

  /// No description provided for @chatUnexpected.
  ///
  /// In ar, this message translates to:
  /// **'حصل خطأ غير متوقع.'**
  String get chatUnexpected;

  /// No description provided for @chatResend.
  ///
  /// In ar, this message translates to:
  /// **'ماوصلتش — ابعتها تاني'**
  String get chatResend;

  /// No description provided for @chatStopVoice.
  ///
  /// In ar, this message translates to:
  /// **'وقّف الصوت'**
  String get chatStopVoice;

  /// No description provided for @chatListen.
  ///
  /// In ar, this message translates to:
  /// **'اسمع الرد'**
  String get chatListen;

  /// No description provided for @chatThinking.
  ///
  /// In ar, this message translates to:
  /// **'بفكر…'**
  String get chatThinking;

  /// No description provided for @refillBack.
  ///
  /// In ar, this message translates to:
  /// **'رصيدك رجع — ابعت رسالتك تاني'**
  String get refillBack;

  /// No description provided for @refillDays.
  ///
  /// In ar, this message translates to:
  /// **'رصيدك بيتجدد بعد {days} أيام'**
  String refillDays(int days);

  /// No description provided for @refillHour.
  ///
  /// In ar, this message translates to:
  /// **'ساعة'**
  String get refillHour;

  /// No description provided for @refillTwoHours.
  ///
  /// In ar, this message translates to:
  /// **'ساعتين'**
  String get refillTwoHours;

  /// No description provided for @refillFewHours.
  ///
  /// In ar, this message translates to:
  /// **'{h} ساعات'**
  String refillFewHours(int h);

  /// No description provided for @refillManyHours.
  ///
  /// In ar, this message translates to:
  /// **'{h} ساعة'**
  String refillManyHours(int h);

  /// No description provided for @refillMinutes.
  ///
  /// In ar, this message translates to:
  /// **'{m} دقيقة'**
  String refillMinutes(int m);

  /// No description provided for @refillAnd.
  ///
  /// In ar, this message translates to:
  /// **' و'**
  String get refillAnd;

  /// No description provided for @refillIn.
  ///
  /// In ar, this message translates to:
  /// **'رصيدك بيتجدد بعد {span}'**
  String refillIn(String span);

  /// No description provided for @chatSubscribeFeature.
  ///
  /// In ar, this message translates to:
  /// **'اشترك وفعّل الميزة دي'**
  String get chatSubscribeFeature;

  /// No description provided for @chatSubscribeMore.
  ///
  /// In ar, this message translates to:
  /// **'اشترك وخد محاولات أكتر'**
  String get chatSubscribeMore;

  /// No description provided for @chatNotDone.
  ///
  /// In ar, this message translates to:
  /// **'لسه ماتنفذش.'**
  String get chatNotDone;

  /// No description provided for @chatDoIt.
  ///
  /// In ar, this message translates to:
  /// **'اعملها'**
  String get chatDoIt;

  /// No description provided for @chatTranscribing.
  ///
  /// In ar, this message translates to:
  /// **'بحوّل الكلام…'**
  String get chatTranscribing;

  /// No description provided for @chatHint.
  ///
  /// In ar, this message translates to:
  /// **'اكتب لزاد…'**
  String get chatHint;

  /// No description provided for @chatSend.
  ///
  /// In ar, this message translates to:
  /// **'ابعت'**
  String get chatSend;

  /// No description provided for @voiceTooShort.
  ///
  /// In ar, this message translates to:
  /// **'مسكت الزرار بسرعة — دوس وابدأ اتكلم، وبعدين قف.'**
  String get voiceTooShort;

  /// No description provided for @voiceDenied.
  ///
  /// In ar, this message translates to:
  /// **'محتاج إذن المايك. افتح إعدادات التطبيق واسمح بالتسجيل.'**
  String get voiceDenied;

  /// No description provided for @voiceFailed.
  ///
  /// In ar, this message translates to:
  /// **'مقدرتش أحوّل الكلام. جرب تاني.'**
  String get voiceFailed;

  /// No description provided for @subscribePulseTitle.
  ///
  /// In ar, this message translates to:
  /// **'اشترك وزاد يبقى معاك على طول'**
  String get subscribePulseTitle;

  /// No description provided for @subscribePulseBody.
  ///
  /// In ar, this message translates to:
  /// **'من غير إعلانات، ومحاولات أكتر، وصوت من غير حد.'**
  String get subscribePulseBody;

  /// No description provided for @subscribePulseClose.
  ///
  /// In ar, this message translates to:
  /// **'اقفل'**
  String get subscribePulseClose;

  /// No description provided for @voiceOutToday.
  ///
  /// In ar, this message translates to:
  /// **'خلصت أسئلتك الصوتية (٣ كل ساعتين) — بترجع لوحدها، أو شاهد إعلان وخد سؤال زيادة. اكتب سؤالك، أو اشترك وكلّم زاد من غير حد.'**
  String get voiceOutToday;

  /// No description provided for @voiceRecord.
  ///
  /// In ar, this message translates to:
  /// **'سجّل صوت'**
  String get voiceRecord;

  /// No description provided for @commonCancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get commonCancel;

  /// No description provided for @voiceDone.
  ///
  /// In ar, this message translates to:
  /// **'خلصت'**
  String get voiceDone;

  /// No description provided for @chatEmergency.
  ///
  /// In ar, this message translates to:
  /// **'طوارئ في البيت؟ الـ{trade} بتاعك قدامك بنقرة.'**
  String chatEmergency(String trade);

  /// No description provided for @chatTechnicians.
  ///
  /// In ar, this message translates to:
  /// **'فنييني'**
  String get chatTechnicians;

  /// No description provided for @intChatTitle.
  ///
  /// In ar, this message translates to:
  /// **'محادثة مع زاد'**
  String get intChatTitle;

  /// No description provided for @intChatSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'اسأل عن مصاريفك، مخزونك، أو أي حاجة'**
  String get intChatSubtitle;

  /// No description provided for @intChatHide.
  ///
  /// In ar, this message translates to:
  /// **'إخفاء المحادثة'**
  String get intChatHide;

  /// No description provided for @intChatOpen.
  ///
  /// In ar, this message translates to:
  /// **'افتح المحادثة'**
  String get intChatOpen;

  /// No description provided for @intPromptRecipe.
  ///
  /// In ar, this message translates to:
  /// **'اقترح وصفة من الثلاجة'**
  String get intPromptRecipe;

  /// No description provided for @intPromptSpending.
  ///
  /// In ar, this message translates to:
  /// **'حلل مصاريفي هذا الشهر'**
  String get intPromptSpending;

  /// No description provided for @intPromptShopping.
  ///
  /// In ar, this message translates to:
  /// **'ما الذي ينقصني للتسوق؟'**
  String get intPromptShopping;

  /// No description provided for @intPromptSave.
  ///
  /// In ar, this message translates to:
  /// **'كيف أوفر أكثر هذا الشهر؟'**
  String get intPromptSave;

  /// No description provided for @intPromptSubs.
  ///
  /// In ar, this message translates to:
  /// **'اكتشف اشتراكاتي'**
  String get intPromptSubs;

  /// No description provided for @intPromptHealthy.
  ///
  /// In ar, this message translates to:
  /// **'وجبة صحية سريعة'**
  String get intPromptHealthy;

  /// No description provided for @intChatClear.
  ///
  /// In ar, this message translates to:
  /// **'مسح المحادثة'**
  String get intChatClear;

  /// No description provided for @intChatClearBody.
  ///
  /// In ar, this message translates to:
  /// **'هنمسح كل رسائل المحادثة مع عقل زاد. البيانات المالية والمخزون مش هتتأثر.'**
  String get intChatClearBody;

  /// No description provided for @intChatEmpty.
  ///
  /// In ar, this message translates to:
  /// **'اسأل زاد عن أي شيء'**
  String get intChatEmpty;

  /// No description provided for @intChatInputHint.
  ///
  /// In ar, this message translates to:
  /// **'اسأل زاد عن ثلاجتك أو ميزانيتك...'**
  String get intChatInputHint;

  /// No description provided for @intChatListen.
  ///
  /// In ar, this message translates to:
  /// **'استمع'**
  String get intChatListen;

  /// No description provided for @intChatMemoryUsed.
  ///
  /// In ar, this message translates to:
  /// **'اتبنى على {count} حاجة زاد فاكرها عنك'**
  String intChatMemoryUsed(int count);

  /// No description provided for @meshThinking.
  ///
  /// In ar, this message translates to:
  /// **'الشبكة العصبية بتشتغل...'**
  String get meshThinking;

  /// No description provided for @meshFinance.
  ///
  /// In ar, this message translates to:
  /// **'وكيل المال متصل'**
  String get meshFinance;

  /// No description provided for @meshPantry.
  ///
  /// In ar, this message translates to:
  /// **'وكيل المطبخ والمخزون متصل'**
  String get meshPantry;

  /// No description provided for @meshPharmacy.
  ///
  /// In ar, this message translates to:
  /// **'وكيل الصيدلية متصل'**
  String get meshPharmacy;

  /// No description provided for @meshFamily.
  ///
  /// In ar, this message translates to:
  /// **'وكيل العائلة متصل'**
  String get meshFamily;

  /// No description provided for @meshDefault.
  ///
  /// In ar, this message translates to:
  /// **'شبكة وكلاء زاد'**
  String get meshDefault;

  /// No description provided for @voiceChipSpending.
  ///
  /// In ar, this message translates to:
  /// **'حلل مصاريفي'**
  String get voiceChipSpending;

  /// No description provided for @voiceChipMeal.
  ///
  /// In ar, this message translates to:
  /// **'اقترح وجبة'**
  String get voiceChipMeal;

  /// No description provided for @voiceChipLeft.
  ///
  /// In ar, this message translates to:
  /// **'كام فاضل في الميزانية؟'**
  String get voiceChipLeft;

  /// No description provided for @voiceChipCoffee.
  ///
  /// In ar, this message translates to:
  /// **'صرفت 50 على القهوة'**
  String get voiceChipCoffee;

  /// No description provided for @voiceSheetDenied.
  ///
  /// In ar, this message translates to:
  /// **'امنح التطبيق إذن استخدام الميكروفون'**
  String get voiceSheetDenied;

  /// No description provided for @voiceSheetFailed.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ في التعرف على الصوت'**
  String get voiceSheetFailed;

  /// No description provided for @voiceSheetOutToday.
  ///
  /// In ar, this message translates to:
  /// **'خلصت أسئلتك الصوتية — ٣ كل ساعتين، وبترجع لوحدها'**
  String get voiceSheetOutToday;

  /// No description provided for @voiceSheetTooShort.
  ///
  /// In ar, this message translates to:
  /// **'لم أسمع كلامًا واضحًا، حاول مرة أخرى'**
  String get voiceSheetTooShort;

  /// No description provided for @voiceSheetBrainDown.
  ///
  /// In ar, this message translates to:
  /// **'ماقدرتش أوصل لعقل زاد دلوقتي'**
  String get voiceSheetBrainDown;

  /// No description provided for @voiceSpeaking.
  ///
  /// In ar, this message translates to:
  /// **'زاد بيتكلم…'**
  String get voiceSpeaking;

  /// No description provided for @voiceWriting.
  ///
  /// In ar, this message translates to:
  /// **'بكتب كلامك…'**
  String get voiceWriting;

  /// No description provided for @voiceThinking.
  ///
  /// In ar, this message translates to:
  /// **'بيفكر…'**
  String get voiceThinking;

  /// No description provided for @voicePreparing.
  ///
  /// In ar, this message translates to:
  /// **'بيجهز صوته…'**
  String get voicePreparing;

  /// No description provided for @voiceTitle.
  ///
  /// In ar, this message translates to:
  /// **'مساعد زاد الصوتي'**
  String get voiceTitle;

  /// No description provided for @voiceErrorRetry.
  ///
  /// In ar, this message translates to:
  /// **'⚠️ {error}\nاضغط المايك وجرّب تاني'**
  String voiceErrorRetry(String error);

  /// No description provided for @voiceInterruptHint.
  ///
  /// In ar, this message translates to:
  /// **'زاد بيتكلم… اتكلم في أي وقت تقاطعه'**
  String get voiceInterruptHint;

  /// No description provided for @voiceWorking.
  ///
  /// In ar, this message translates to:
  /// **'يفكر عقل زاد وينفذ طلبك…'**
  String get voiceWorking;

  /// No description provided for @voiceListening.
  ///
  /// In ar, this message translates to:
  /// **'زاد سامعك — اتكلم براحتك'**
  String get voiceListening;

  /// No description provided for @voiceTapMic.
  ///
  /// In ar, this message translates to:
  /// **'اضغط المايك وكلّم زاد 🎙️'**
  String get voiceTapMic;

  /// No description provided for @voiceHoldToTalk.
  ///
  /// In ar, this message translates to:
  /// **'دوس مع الاستمرار واتكلم'**
  String get voiceHoldToTalk;

  /// No description provided for @voiceReleaseToReply.
  ///
  /// In ar, this message translates to:
  /// **'بسمعك… سيب عشان أرد'**
  String get voiceReleaseToReply;

  /// No description provided for @voicePressToInterrupt.
  ///
  /// In ar, this message translates to:
  /// **'دوس واتكلم عشان تقاطعني'**
  String get voicePressToInterrupt;

  /// No description provided for @voiceOrPick.
  ///
  /// In ar, this message translates to:
  /// **'أو اختار سؤال جاهز:'**
  String get voiceOrPick;

  /// No description provided for @budgetSuggest.
  ///
  /// In ar, this message translates to:
  /// **'زاد يقترح تعديل ميزانيتك إلى {amount} بناءً على متوسط آخر شهرين'**
  String budgetSuggest(String amount);

  /// No description provided for @commonApply.
  ///
  /// In ar, this message translates to:
  /// **'تطبيق'**
  String get commonApply;

  /// No description provided for @txFilterAll.
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get txFilterAll;

  /// No description provided for @txFilterExpenses.
  ///
  /// In ar, this message translates to:
  /// **'المصروفات'**
  String get txFilterExpenses;

  /// No description provided for @txFilterIncome.
  ///
  /// In ar, this message translates to:
  /// **'الدخل'**
  String get txFilterIncome;

  /// No description provided for @txFilterBank.
  ///
  /// In ar, this message translates to:
  /// **'البنك'**
  String get txFilterBank;

  /// No description provided for @budgetThisMonth.
  ///
  /// In ar, this message translates to:
  /// **'هذا الشهر'**
  String get budgetThisMonth;

  /// No description provided for @budgetNoTransactions.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد معاملات بعد.'**
  String get budgetNoTransactions;

  /// No description provided for @budgetNoTransactionsHint.
  ///
  /// In ar, this message translates to:
  /// **'أضف معاملة أو اربط البنك لتتبع مصاريفك تلقائياً'**
  String get budgetNoTransactionsHint;

  /// No description provided for @txEdit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل المعاملة'**
  String get txEdit;

  /// No description provided for @txDelete.
  ///
  /// In ar, this message translates to:
  /// **'مسح المعاملة'**
  String get txDelete;

  /// No description provided for @financesTitle.
  ///
  /// In ar, this message translates to:
  /// **'الميزانية والالتزامات'**
  String get financesTitle;

  /// No description provided for @financesTabMoves.
  ///
  /// In ar, this message translates to:
  /// **'الحركات والميزانية'**
  String get financesTabMoves;

  /// No description provided for @financesAddTx.
  ///
  /// In ar, this message translates to:
  /// **'معاملة'**
  String get financesAddTx;

  /// No description provided for @financesCategoryBudgets.
  ///
  /// In ar, this message translates to:
  /// **'ميزانيات الفئات'**
  String get financesCategoryBudgets;

  /// No description provided for @financesSetCategory.
  ///
  /// In ar, this message translates to:
  /// **'تحديد فئة'**
  String get financesSetCategory;

  /// No description provided for @financesNoCategories.
  ///
  /// In ar, this message translates to:
  /// **'لسه ما حددتش ميزانية لأي فئة. اضغط \"تحديد فئة\" عشان زاد يتابعلك كل فئة لوحدها.'**
  String get financesNoCategories;

  /// No description provided for @financesAvailable.
  ///
  /// In ar, this message translates to:
  /// **'متاح'**
  String get financesAvailable;

  /// No description provided for @financesEditBalance.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الرصيد'**
  String get financesEditBalance;

  /// No description provided for @financesNoBudget.
  ///
  /// In ar, this message translates to:
  /// **'لسه محددتش ميزانيتك'**
  String get financesNoBudget;

  /// No description provided for @financesRemainingCommitted.
  ///
  /// In ar, this message translates to:
  /// **'متبقي {remaining} · محجوز {committed}'**
  String financesRemainingCommitted(String remaining, String committed);

  /// No description provided for @financesNoLimit.
  ///
  /// In ar, this message translates to:
  /// **'{amount} — بدون حد'**
  String financesNoLimit(String amount);

  /// No description provided for @financesSmartAnalysis.
  ///
  /// In ar, this message translates to:
  /// **'تحليل ذكي'**
  String get financesSmartAnalysis;

  /// No description provided for @financesSetCategoryBudget.
  ///
  /// In ar, this message translates to:
  /// **'تحديد ميزانية فئة'**
  String get financesSetCategoryBudget;

  /// No description provided for @financesEditCategoryBudget.
  ///
  /// In ar, this message translates to:
  /// **'تعديل ميزانية {category}'**
  String financesEditCategoryBudget(String category);

  /// No description provided for @financesCategory.
  ///
  /// In ar, this message translates to:
  /// **'الفئة'**
  String get financesCategory;

  /// No description provided for @financesMonthlyBudget.
  ///
  /// In ar, this message translates to:
  /// **'الميزانية الشهرية'**
  String get financesMonthlyBudget;

  /// No description provided for @commonSave.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get commonSave;

  /// No description provided for @financesInsightTitle.
  ///
  /// In ar, this message translates to:
  /// **'تحليل ذكي: {category}'**
  String financesInsightTitle(String category);

  /// No description provided for @financesAnalysing.
  ///
  /// In ar, this message translates to:
  /// **'جاري التحليل...'**
  String get financesAnalysing;

  /// No description provided for @financesInsightEmpty.
  ///
  /// In ar, this message translates to:
  /// **'مفيش بيانات كافية لتحليل الفئة دي حالياً.'**
  String get financesInsightEmpty;

  /// No description provided for @financesPredictedNext.
  ///
  /// In ar, this message translates to:
  /// **'المتوقع الشهر القادم: {amount}'**
  String financesPredictedNext(String amount);

  /// No description provided for @gateTitle.
  ///
  /// In ar, this message translates to:
  /// **'قبل ما نبدأ، معاك كام الشهر ده؟'**
  String get gateTitle;

  /// No description provided for @gateBody.
  ///
  /// In ar, this message translates to:
  /// **'زاد ما بيخترعش أرقام. من الرقم ده بنحسب «المتاح» و«المتبقي» كل يوم، وتقدر تعدّله في أي وقت.'**
  String get gateBody;

  /// No description provided for @gateMarket.
  ///
  /// In ar, this message translates to:
  /// **'البلد والعملة'**
  String get gateMarket;

  /// No description provided for @commonChange.
  ///
  /// In ar, this message translates to:
  /// **'تغيير'**
  String get commonChange;

  /// No description provided for @gateCeiling.
  ///
  /// In ar, this message translates to:
  /// **'رصيدك للشهر ده'**
  String get gateCeiling;

  /// No description provided for @gateStart.
  ///
  /// In ar, this message translates to:
  /// **'يلا نبدأ'**
  String get gateStart;

  /// No description provided for @budgetOver.
  ///
  /// In ar, this message translates to:
  /// **'تجاوزت الميزانية! حاول تقليل المصاريف'**
  String get budgetOver;

  /// No description provided for @budgetNear.
  ///
  /// In ar, this message translates to:
  /// **'وصلت لـ {pct}% من ميزانيتك. كن حذراً'**
  String budgetNear(int pct);

  /// No description provided for @budgetFine.
  ///
  /// In ar, this message translates to:
  /// **'صرفت {pct}% من ميزانيتك. أداء جيد'**
  String budgetFine(int pct);

  /// No description provided for @budgetGreat.
  ///
  /// In ar, this message translates to:
  /// **'رائع! أنت في المسار الصحيح. صرفت {pct}% فقط'**
  String budgetGreat(int pct);

  /// No description provided for @trendUp.
  ///
  /// In ar, this message translates to:
  /// **'في ازدياد'**
  String get trendUp;

  /// No description provided for @trendDown.
  ///
  /// In ar, this message translates to:
  /// **'في انخفاض'**
  String get trendDown;

  /// No description provided for @trendFlat.
  ///
  /// In ar, this message translates to:
  /// **'مستقر'**
  String get trendFlat;

  /// No description provided for @eventToday.
  ///
  /// In ar, this message translates to:
  /// **'زوّدناه عشان «{title}» النهارده'**
  String eventToday(String title);

  /// No description provided for @eventAhead.
  ///
  /// In ar, this message translates to:
  /// **'شايلين حاجة لـ«{title}» {when}'**
  String eventAhead(String title, String when);

  /// No description provided for @eventTomorrow.
  ///
  /// In ar, this message translates to:
  /// **'بكرة'**
  String get eventTomorrow;

  /// No description provided for @eventOnDay.
  ///
  /// In ar, this message translates to:
  /// **'يوم {day}'**
  String eventOnDay(String day);

  /// A weekday; day is d1 (Monday) .. d7 (Sunday), DateTime.weekday.
  ///
  /// In ar, this message translates to:
  /// **'{day, select, d1{الاتنين} d2{التلات} d3{الأربع} d4{الخميس} d5{الجمعة} d6{السبت} d7{الحد} other{}}'**
  String weekdayName(String day);

  /// No description provided for @eventOuting.
  ///
  /// In ar, this message translates to:
  /// **'مشوار'**
  String get eventOuting;

  /// No description provided for @txNoTitle.
  ///
  /// In ar, this message translates to:
  /// **'بدون وصف'**
  String get txNoTitle;

  /// No description provided for @txAddExpense.
  ///
  /// In ar, this message translates to:
  /// **'إضافة مصروف'**
  String get txAddExpense;

  /// No description provided for @txAddIncome.
  ///
  /// In ar, this message translates to:
  /// **'إضافة دخل/راتب'**
  String get txAddIncome;

  /// No description provided for @txKindExpense.
  ///
  /// In ar, this message translates to:
  /// **'خصم (مصروف)'**
  String get txKindExpense;

  /// No description provided for @txKindIncome.
  ///
  /// In ar, this message translates to:
  /// **'إيداع (راتب)'**
  String get txKindIncome;

  /// No description provided for @txDescriptionExample.
  ///
  /// In ar, this message translates to:
  /// **'الوصف (مثال: راتب، إيجار)'**
  String get txDescriptionExample;

  /// No description provided for @txAmount.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ'**
  String get txAmount;

  /// No description provided for @txDebit.
  ///
  /// In ar, this message translates to:
  /// **'خصم المبلغ'**
  String get txDebit;

  /// No description provided for @txCredit.
  ///
  /// In ar, this message translates to:
  /// **'إضافة المبلغ'**
  String get txCredit;

  /// No description provided for @commonDelete.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get commonDelete;

  /// No description provided for @txDeleteConfirm.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت متأكد من حذف معاملة \"{title}\"؟'**
  String txDeleteConfirm(String title);

  /// No description provided for @txDescription.
  ///
  /// In ar, this message translates to:
  /// **'الوصف'**
  String get txDescription;

  /// No description provided for @txForPerson.
  ///
  /// In ar, this message translates to:
  /// **'لمين؟ (سيبها فاضية لو ليك أو للبيت كله)'**
  String get txForPerson;

  /// No description provided for @txForPersonHint.
  ///
  /// In ar, this message translates to:
  /// **'ماما، بابا، يوسف…'**
  String get txForPersonHint;

  /// No description provided for @txForPersonTag.
  ///
  /// In ar, this message translates to:
  /// **'لـ{person}'**
  String txForPersonTag(String person);

  /// No description provided for @habitTrialTitle.
  ///
  /// In ar, this message translates to:
  /// **'🧪 تجربة الأسبوعين'**
  String get habitTrialTitle;

  /// No description provided for @habitTrialTry.
  ///
  /// In ar, this message translates to:
  /// **'✅ نجرب أسبوعين'**
  String get habitTrialTry;

  /// No description provided for @habitTrialNo.
  ///
  /// In ar, this message translates to:
  /// **'🙅 لأ شكراً'**
  String get habitTrialNo;

  /// No description provided for @habitTrialKeep.
  ///
  /// In ar, this message translates to:
  /// **'✅ ثبّتها'**
  String get habitTrialKeep;

  /// No description provided for @habitTrialDrop.
  ///
  /// In ar, this message translates to:
  /// **'❌ بطّلها'**
  String get habitTrialDrop;

  /// No description provided for @habitTrialStarted.
  ///
  /// In ar, this message translates to:
  /// **'يلا بينا ✅ التجربة بدأت النهارده لمدة أسبوعين، وبعدها هقولك النتيجة بالأرقام.'**
  String get habitTrialStarted;

  /// No description provided for @habitTrialDeclined.
  ///
  /// In ar, this message translates to:
  /// **'تمام، مش هقترحها تاني الفترة دي.'**
  String get habitTrialDeclined;

  /// No description provided for @habitTrialKept.
  ///
  /// In ar, this message translates to:
  /// **'تمام ✅ ثبّتناها — هفتكرها وأبني عليها.'**
  String get habitTrialKept;

  /// No description provided for @habitTrialDropped.
  ///
  /// In ar, this message translates to:
  /// **'تمام، بطّلناها. شكراً إنك جرّبت.'**
  String get habitTrialDropped;

  /// No description provided for @habitTrialAlready.
  ///
  /// In ar, this message translates to:
  /// **'تمام، ردك اتسجّل قبل كده.'**
  String get habitTrialAlready;

  /// No description provided for @habitTrialGone.
  ///
  /// In ar, this message translates to:
  /// **'التجربة دي مابقتش موجودة.'**
  String get habitTrialGone;

  /// No description provided for @habitTrialFailed.
  ///
  /// In ar, this message translates to:
  /// **'معلش، ماقدرتش أسجّل ردك دلوقتي — جرّب تاني بعد شوية.'**
  String get habitTrialFailed;

  /// No description provided for @learningTitle.
  ///
  /// In ar, this message translates to:
  /// **'🧠 اتعلمت إن'**
  String get learningTitle;

  /// No description provided for @learningRight.
  ///
  /// In ar, this message translates to:
  /// **'✅ صح'**
  String get learningRight;

  /// No description provided for @learningWrong.
  ///
  /// In ar, this message translates to:
  /// **'❌ مش صح'**
  String get learningWrong;

  /// Button on an offer notification: opens the offer's own post or video
  ///
  /// In ar, this message translates to:
  /// **'🔗 افتح العرض'**
  String get openOfferSource;

  /// No description provided for @learningKept.
  ///
  /// In ar, this message translates to:
  /// **'تمام ✅ هفتكرها.'**
  String get learningKept;

  /// No description provided for @learningCorrected.
  ///
  /// In ar, this message translates to:
  /// **'تمام، شكراً إنك صحّحتني — مش هقولها تاني.'**
  String get learningCorrected;

  /// No description provided for @learningAlready.
  ///
  /// In ar, this message translates to:
  /// **'تمام، ردك اتسجّل قبل كده.'**
  String get learningAlready;

  /// No description provided for @learningGone.
  ///
  /// In ar, this message translates to:
  /// **'الملاحظة دي مابقتش موجودة.'**
  String get learningGone;

  /// No description provided for @learningFailed.
  ///
  /// In ar, this message translates to:
  /// **'معلش، ماقدرتش أسجّل ردك دلوقتي — جرّب تاني بعد شوية.'**
  String get learningFailed;

  /// No description provided for @txType.
  ///
  /// In ar, this message translates to:
  /// **'النوع'**
  String get txType;

  /// No description provided for @txExpense.
  ///
  /// In ar, this message translates to:
  /// **'مصروف'**
  String get txExpense;

  /// No description provided for @txIncome.
  ///
  /// In ar, this message translates to:
  /// **'دخل'**
  String get txIncome;

  /// No description provided for @quickCash.
  ///
  /// In ar, this message translates to:
  /// **'مصروف كاش'**
  String get quickCash;

  /// No description provided for @quickExpense.
  ///
  /// In ar, this message translates to:
  /// **'مصروف سريع'**
  String get quickExpense;

  /// No description provided for @quickSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'سجّل مصروفك في ثوانٍ'**
  String get quickSubtitle;

  /// No description provided for @quickName.
  ///
  /// In ar, this message translates to:
  /// **'الاسم'**
  String get quickName;

  /// No description provided for @quickNameHint.
  ///
  /// In ar, this message translates to:
  /// **'مثال: حلاقة، بقالة'**
  String get quickNameHint;

  /// No description provided for @quickCategory.
  ///
  /// In ar, this message translates to:
  /// **'التصنيف'**
  String get quickCategory;

  /// No description provided for @txScanReceipt.
  ///
  /// In ar, this message translates to:
  /// **'صوّر فاتورة'**
  String get txScanReceipt;

  /// No description provided for @txLog.
  ///
  /// In ar, this message translates to:
  /// **'سجّل عملية'**
  String get txLog;

  /// No description provided for @txTitle.
  ///
  /// In ar, this message translates to:
  /// **'المعاملات'**
  String get txTitle;

  /// No description provided for @txNoneHere.
  ///
  /// In ar, this message translates to:
  /// **'مفيش معاملات هنا'**
  String get txNoneHere;

  /// No description provided for @txTryFilter.
  ///
  /// In ar, this message translates to:
  /// **'جرّب فلتر تاني.'**
  String get txTryFilter;

  /// No description provided for @commonEdit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get commonEdit;

  /// No description provided for @walletCash.
  ///
  /// In ar, this message translates to:
  /// **'كاش'**
  String get walletCash;

  /// No description provided for @walletCard.
  ///
  /// In ar, this message translates to:
  /// **'بطاقة'**
  String get walletCard;

  /// No description provided for @walletBank.
  ///
  /// In ar, this message translates to:
  /// **'بنك'**
  String get walletBank;

  /// No description provided for @txPendingOne.
  ///
  /// In ar, this message translates to:
  /// **'لسه محفوظة'**
  String get txPendingOne;

  /// No description provided for @txPendingCount.
  ///
  /// In ar, this message translates to:
  /// **'{count} لسه محفوظة'**
  String txPendingCount(int count);

  /// No description provided for @txLoadFailed.
  ///
  /// In ar, this message translates to:
  /// **'مقدرتش أجيب المعاملات'**
  String get txLoadFailed;

  /// No description provided for @txNonePeriod.
  ///
  /// In ar, this message translates to:
  /// **'مفيش معاملات الفترة دي'**
  String get txNonePeriod;

  /// No description provided for @txPullToRetry.
  ///
  /// In ar, this message translates to:
  /// **'اسحب الشاشة لتحت عشان نحاول تاني.'**
  String get txPullToRetry;

  /// No description provided for @txNoneHint.
  ///
  /// In ar, this message translates to:
  /// **'أول ما تسجّل مصروف — أو توصلك رسالة من البنك — هتلاقيها هنا.'**
  String get txNoneHint;

  /// DateFormat pattern for a day's heading.
  ///
  /// In ar, this message translates to:
  /// **'EEEE، d MMMM'**
  String get dateDayHeader;

  /// No description provided for @cycleYearly.
  ///
  /// In ar, this message translates to:
  /// **'سنوي'**
  String get cycleYearly;

  /// No description provided for @cycleWeekly.
  ///
  /// In ar, this message translates to:
  /// **'أسبوعي'**
  String get cycleWeekly;

  /// No description provided for @cycleMonthly.
  ///
  /// In ar, this message translates to:
  /// **'شهري'**
  String get cycleMonthly;

  /// No description provided for @subsTabAll.
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get subsTabAll;

  /// No description provided for @subsTabSubs.
  ///
  /// In ar, this message translates to:
  /// **'اشتراكات'**
  String get subsTabSubs;

  /// No description provided for @subsTabBills.
  ///
  /// In ar, this message translates to:
  /// **'فواتير'**
  String get subsTabBills;

  /// No description provided for @subsTabInstalments.
  ///
  /// In ar, this message translates to:
  /// **'أقساط'**
  String get subsTabInstalments;

  /// No description provided for @subsTabLoans.
  ///
  /// In ar, this message translates to:
  /// **'قروض'**
  String get subsTabLoans;

  /// No description provided for @subsNone.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد اشتراكات'**
  String get subsNone;

  /// No description provided for @subsNoneInTab.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد عناصر في هذا التصنيف'**
  String get subsNoneInTab;

  /// No description provided for @subsActive.
  ///
  /// In ar, this message translates to:
  /// **'النشطة'**
  String get subsActive;

  /// No description provided for @subsMonthlyTotal.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي الاشتراكات الشهرية'**
  String get subsMonthlyTotal;

  /// No description provided for @subsActiveCount.
  ///
  /// In ar, this message translates to:
  /// **'اشتراكات نشطة'**
  String get subsActiveCount;

  /// No description provided for @subsDetected.
  ///
  /// In ar, this message translates to:
  /// **'{count} اشتراك مكتشف تلقائياً'**
  String subsDetected(int count);

  /// No description provided for @subsClearAll.
  ///
  /// In ar, this message translates to:
  /// **'مسح الكل'**
  String get subsClearAll;

  /// No description provided for @subsBnpl.
  ///
  /// In ar, this message translates to:
  /// **'اشتري دلوقتي وادفع بعدين'**
  String get subsBnpl;

  /// No description provided for @subsLoans.
  ///
  /// In ar, this message translates to:
  /// **'أقساط وقروض وإيجار'**
  String get subsLoans;

  /// No description provided for @subsPaid.
  ///
  /// In ar, this message translates to:
  /// **'تم تسجيل سداد {title} وترحيل الموعد للشهر القادم بنجاح'**
  String subsPaid(String title);

  /// No description provided for @subsFixed.
  ///
  /// In ar, this message translates to:
  /// **'التزامات ثابتة'**
  String get subsFixed;

  /// No description provided for @subsTitle.
  ///
  /// In ar, this message translates to:
  /// **'الاشتراكات والفواتير'**
  String get subsTitle;

  /// No description provided for @subsBnplTag.
  ///
  /// In ar, this message translates to:
  /// **'اشتري وادفع بعدين · {name}'**
  String subsBnplTag(String name);

  /// No description provided for @subsRenewsToday.
  ///
  /// In ar, this message translates to:
  /// **'يُجدد اليوم'**
  String get subsRenewsToday;

  /// No description provided for @subsExpiredAgo.
  ///
  /// In ar, this message translates to:
  /// **'منتهي منذ {days} يوم'**
  String subsExpiredAgo(int days);

  /// No description provided for @subsRenewsIn.
  ///
  /// In ar, this message translates to:
  /// **'يُجدد بعد {days} يوم'**
  String subsRenewsIn(int days);

  /// No description provided for @subsPerYear.
  ///
  /// In ar, this message translates to:
  /// **'≈ {amount}/سنة'**
  String subsPerYear(String amount);

  /// No description provided for @subsPaidMark.
  ///
  /// In ar, this message translates to:
  /// **'تم الدفع ✓'**
  String get subsPaidMark;

  /// No description provided for @subsToggleAuto.
  ///
  /// In ar, this message translates to:
  /// **'تفعيل/إيقاف الخصم التلقائي'**
  String get subsToggleAuto;

  /// No description provided for @subsDisable.
  ///
  /// In ar, this message translates to:
  /// **'تعطيل'**
  String get subsDisable;

  /// No description provided for @subsEnable.
  ///
  /// In ar, this message translates to:
  /// **'تفعيل'**
  String get subsEnable;

  /// No description provided for @subsAdd.
  ///
  /// In ar, this message translates to:
  /// **'إضافة اشتراك جديد'**
  String get subsAdd;

  /// No description provided for @subsEdit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الاشتراك'**
  String get subsEdit;

  /// No description provided for @commonConfirm.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد'**
  String get commonConfirm;

  /// No description provided for @subsSuggested.
  ///
  /// In ar, this message translates to:
  /// **'الخدمات والاشتراكات المقترحة:'**
  String get subsSuggested;

  /// No description provided for @subsKind.
  ///
  /// In ar, this message translates to:
  /// **'تصنيف الالتزام:'**
  String get subsKind;

  /// No description provided for @subsKindSub.
  ///
  /// In ar, this message translates to:
  /// **'اشتراك شهري'**
  String get subsKindSub;

  /// No description provided for @subsKindInstalment.
  ///
  /// In ar, this message translates to:
  /// **'قسط'**
  String get subsKindInstalment;

  /// No description provided for @subsKindBill.
  ///
  /// In ar, this message translates to:
  /// **'فاتورة'**
  String get subsKindBill;

  /// No description provided for @subsKindRent.
  ///
  /// In ar, this message translates to:
  /// **'التزام'**
  String get subsKindRent;

  /// No description provided for @subsTotalAmount.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي المبلغ'**
  String get subsTotalAmount;

  /// No description provided for @subsRemaining.
  ///
  /// In ar, this message translates to:
  /// **'الأقساط المتبقية'**
  String get subsRemaining;

  /// No description provided for @subsNameHint.
  ///
  /// In ar, this message translates to:
  /// **'اسم الاشتراك (مثال: Netflix)'**
  String get subsNameHint;

  /// No description provided for @subsAmount.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ ({symbol})'**
  String subsAmount(String symbol);

  /// No description provided for @subsProvider.
  ///
  /// In ar, this message translates to:
  /// **'مزود الخدمة'**
  String get subsProvider;

  /// No description provided for @subsRenewalDate.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ التجديد (YYYY-MM-DD)'**
  String get subsRenewalDate;

  /// No description provided for @commonPickDate.
  ///
  /// In ar, this message translates to:
  /// **'اختر التاريخ'**
  String get commonPickDate;

  /// No description provided for @subsCycle.
  ///
  /// In ar, this message translates to:
  /// **'دورة الفوترة'**
  String get subsCycle;

  /// No description provided for @subsSuggestedCategory.
  ///
  /// In ar, this message translates to:
  /// **'الفئة المقترحة: {category}'**
  String subsSuggestedCategory(String category);

  /// No description provided for @oblKindRent.
  ///
  /// In ar, this message translates to:
  /// **'إيجار'**
  String get oblKindRent;

  /// No description provided for @oblKindInstallment.
  ///
  /// In ar, this message translates to:
  /// **'قسط'**
  String get oblKindInstallment;

  /// No description provided for @oblKindDebt.
  ///
  /// In ar, this message translates to:
  /// **'دين'**
  String get oblKindDebt;

  /// No description provided for @oblKindTuition.
  ///
  /// In ar, this message translates to:
  /// **'مصاريف دراسية'**
  String get oblKindTuition;

  /// No description provided for @oblKindUtility.
  ///
  /// In ar, this message translates to:
  /// **'فاتورة مرافق'**
  String get oblKindUtility;

  /// No description provided for @oblKindOther.
  ///
  /// In ar, this message translates to:
  /// **'أخرى'**
  String get oblKindOther;

  /// No description provided for @recurMonthly.
  ///
  /// In ar, this message translates to:
  /// **'شهري'**
  String get recurMonthly;

  /// No description provided for @recurQuarterly.
  ///
  /// In ar, this message translates to:
  /// **'ربع سنوي'**
  String get recurQuarterly;

  /// No description provided for @recurYearly.
  ///
  /// In ar, this message translates to:
  /// **'سنوي'**
  String get recurYearly;

  /// No description provided for @recurOnce.
  ///
  /// In ar, this message translates to:
  /// **'مرة واحدة'**
  String get recurOnce;

  /// No description provided for @oblStatusPaid.
  ///
  /// In ar, this message translates to:
  /// **'مدفوع'**
  String get oblStatusPaid;

  /// No description provided for @oblStatusPending.
  ///
  /// In ar, this message translates to:
  /// **'مستحق'**
  String get oblStatusPending;

  /// No description provided for @oblStatusScheduled.
  ///
  /// In ar, this message translates to:
  /// **'مجدول'**
  String get oblStatusScheduled;

  /// No description provided for @oblInDays.
  ///
  /// In ar, this message translates to:
  /// **'بعد {days} يوم'**
  String oblInDays(int days);

  /// No description provided for @oblTotal.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي الالتزامات'**
  String get oblTotal;

  /// No description provided for @oblAdd.
  ///
  /// In ar, this message translates to:
  /// **'إضافة التزام'**
  String get oblAdd;

  /// No description provided for @oblNone.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد التزامات'**
  String get oblNone;

  /// No description provided for @oblNoneHint.
  ///
  /// In ar, this message translates to:
  /// **'الأقساط والفواتير الثابتة هتظهر هنا أول ما تتسجل'**
  String get oblNoneHint;

  /// No description provided for @oblDeleteConfirm.
  ///
  /// In ar, this message translates to:
  /// **'حذف «{title}» من قائمة الالتزامات؟'**
  String oblDeleteConfirm(String title);

  /// No description provided for @oblAddNew.
  ///
  /// In ar, this message translates to:
  /// **'إضافة التزام جديد'**
  String get oblAddNew;

  /// No description provided for @oblEdit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الالتزام'**
  String get oblEdit;

  /// No description provided for @oblNameHint.
  ///
  /// In ar, this message translates to:
  /// **'اسم الالتزام (إيجار، كهرباء...)'**
  String get oblNameHint;

  /// No description provided for @oblAmountIn.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ ({currency})'**
  String oblAmountIn(String currency);

  /// No description provided for @oblDueDay.
  ///
  /// In ar, this message translates to:
  /// **'يوم الاستحقاق الشهري (1-31)'**
  String get oblDueDay;

  /// No description provided for @oblDayRange.
  ///
  /// In ar, this message translates to:
  /// **'من 1 لـ 31'**
  String get oblDayRange;

  /// No description provided for @oblRecurrence.
  ///
  /// In ar, this message translates to:
  /// **'التكرار'**
  String get oblRecurrence;

  /// No description provided for @debtSaveFailed.
  ///
  /// In ar, this message translates to:
  /// **'ماتسجلش — اتأكد من النت.'**
  String get debtSaveFailed;

  /// No description provided for @debtPaymentOn.
  ///
  /// In ar, this message translates to:
  /// **'دفعة على {name}'**
  String debtPaymentOn(String name);

  /// No description provided for @debtRemaining.
  ///
  /// In ar, this message translates to:
  /// **'المتبقي: {amount}'**
  String debtRemaining(String amount);

  /// No description provided for @debtPaidAmount.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ المدفوع'**
  String get debtPaidAmount;

  /// No description provided for @debtDelete.
  ///
  /// In ar, this message translates to:
  /// **'حذف الدين'**
  String get debtDelete;

  /// No description provided for @debtDeleteConfirm.
  ///
  /// In ar, this message translates to:
  /// **'حذف «{name}» من قائمة الديون؟'**
  String debtDeleteConfirm(String name);

  /// No description provided for @debtPlanner.
  ///
  /// In ar, this message translates to:
  /// **'مخطط سداد الديون'**
  String get debtPlanner;

  /// No description provided for @debtAdd.
  ///
  /// In ar, this message translates to:
  /// **'إضافة دين'**
  String get debtAdd;

  /// No description provided for @debtPickStrategy.
  ///
  /// In ar, this message translates to:
  /// **'اختر استراتيجية السداد المناسبة لك'**
  String get debtPickStrategy;

  /// No description provided for @debtNone.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد ديون مسجلة'**
  String get debtNone;

  /// No description provided for @debtNoneHint.
  ///
  /// In ar, this message translates to:
  /// **'أضف ديونك لنساعدك في التخطيط للسداد'**
  String get debtNoneHint;

  /// No description provided for @debtSnowball.
  ///
  /// In ar, this message translates to:
  /// **'كرة الثلج (الأصغر أولاً)'**
  String get debtSnowball;

  /// No description provided for @debtAvalanche.
  ///
  /// In ar, this message translates to:
  /// **'الانهيار الجليدي (الأعلى فائدة أولاً)'**
  String get debtAvalanche;

  /// No description provided for @debtMonths.
  ///
  /// In ar, this message translates to:
  /// **'{months} شهر'**
  String debtMonths(int months);

  /// No description provided for @debtLogPayment.
  ///
  /// In ar, this message translates to:
  /// **'سجّل دفعة'**
  String get debtLogPayment;

  /// No description provided for @debtMonthsToPayoff.
  ///
  /// In ar, this message translates to:
  /// **'{months} شهر للسداد الكامل'**
  String debtMonthsToPayoff(int months);

  /// No description provided for @debtTotalInterest.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي الفوائد: {amount}'**
  String debtTotalInterest(String amount);

  /// No description provided for @debtAnalysing.
  ///
  /// In ar, this message translates to:
  /// **'زاد يقوم بالتحليل...'**
  String get debtAnalysing;

  /// No description provided for @debtExplain.
  ///
  /// In ar, this message translates to:
  /// **'اشرح بالذكاء الاصطناعي'**
  String get debtExplain;

  /// No description provided for @debtName.
  ///
  /// In ar, this message translates to:
  /// **'اسم الدين'**
  String get debtName;

  /// No description provided for @debtLeft.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ المتبقي'**
  String get debtLeft;

  /// No description provided for @debtRate.
  ///
  /// In ar, this message translates to:
  /// **'معدل الفائدة السنوي %'**
  String get debtRate;

  /// No description provided for @debtMinimum.
  ///
  /// In ar, this message translates to:
  /// **'الحد الأدنى للدفعة الشهرية'**
  String get debtMinimum;

  /// No description provided for @dealDiscount.
  ///
  /// In ar, this message translates to:
  /// **'خصم {pct}%'**
  String dealDiscount(String pct);

  /// No description provided for @dealAt.
  ///
  /// In ar, this message translates to:
  /// **'{price} عند {store}'**
  String dealAt(String price, String store);

  /// No description provided for @dealCached.
  ///
  /// In ar, this message translates to:
  /// **'البحث مشغول دلوقتي — دي آخر عروض لقيناها{when}'**
  String dealCached(String when);

  /// No description provided for @dealTitle.
  ///
  /// In ar, this message translates to:
  /// **'العروض المتاحة لنواقصك 🏷️'**
  String get dealTitle;

  /// No description provided for @dealLive.
  ///
  /// In ar, this message translates to:
  /// **'نتيجة بحث حي'**
  String get dealLive;

  /// No description provided for @dealSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'عروض حقيقية على الأصناف الناقصة عندك'**
  String get dealSubtitle;

  /// No description provided for @dealTapRefresh.
  ///
  /// In ar, this message translates to:
  /// **'اضغط لتحديث النتائج من الإنترنت'**
  String get dealTapRefresh;

  /// No description provided for @dealSearching.
  ///
  /// In ar, this message translates to:
  /// **'يبحث في الإنترنت...'**
  String get dealSearching;

  /// No description provided for @dealFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر البحث الآن — جرّب تحدّث تاني بعد شوية'**
  String get dealFailed;

  /// No description provided for @dealFailedHint.
  ///
  /// In ar, this message translates to:
  /// **'خدمة البحث مشغولة دلوقتي. دوس تحديث تاني بعد شوية — ولو اتكررت شوف النت.'**
  String get dealFailedHint;

  /// No description provided for @dealNone.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد نتائج بحث محددة متوفرة حالياً'**
  String get dealNone;

  /// No description provided for @dealRefresh.
  ///
  /// In ar, this message translates to:
  /// **'تحديث من النت 🔄'**
  String get dealRefresh;

  /// No description provided for @goalTitle.
  ///
  /// In ar, this message translates to:
  /// **'إيه أهم هدف لبيتك دلوقتي؟'**
  String get goalTitle;

  /// No description provided for @goalBody.
  ///
  /// In ar, this message translates to:
  /// **'اختار واحد — زاد هيتابعه معاك كل أسبوع لمدة ٣ شهور، وتقدر تلغيه في أي وقت.'**
  String get goalBody;

  /// No description provided for @goalSave.
  ///
  /// In ar, this message translates to:
  /// **'أوفّر مبلغ كل شهر'**
  String get goalSave;

  /// No description provided for @goalSaveHint.
  ///
  /// In ar, this message translates to:
  /// **'حدد المبلغ، وزاد يتابع صرفك عشان توصله'**
  String get goalSaveHint;

  /// No description provided for @goalMonthly.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ الشهري'**
  String get goalMonthly;

  /// No description provided for @goalBudget.
  ///
  /// In ar, this message translates to:
  /// **'ألتزم بميزانية الشهر'**
  String get goalBudget;

  /// No description provided for @goalBudgetHint.
  ///
  /// In ar, this message translates to:
  /// **'زاد ينبهك قبل ما الصرف يسبق الميزانية'**
  String get goalBudgetHint;

  /// No description provided for @goalDebts.
  ///
  /// In ar, this message translates to:
  /// **'أسدد ديوني'**
  String get goalDebts;

  /// No description provided for @goalDebtsHint.
  ///
  /// In ar, this message translates to:
  /// **'زاد يتابع معاك المتبقي وأقرب قسط'**
  String get goalDebtsHint;

  /// No description provided for @goalWaste.
  ///
  /// In ar, this message translates to:
  /// **'أقلل هدر المطبخ'**
  String get goalWaste;

  /// No description provided for @goalWasteHint.
  ///
  /// In ar, this message translates to:
  /// **'زاد يفكرك بالأصناف قبل ما تبوظ'**
  String get goalWasteHint;

  /// No description provided for @goalOwn.
  ///
  /// In ar, this message translates to:
  /// **'هدف تاني بكلامي'**
  String get goalOwn;

  /// No description provided for @goalOwnHint.
  ///
  /// In ar, this message translates to:
  /// **'اكتبه زي ما بتقوله'**
  String get goalOwnHint;

  /// No description provided for @goalWrite.
  ///
  /// In ar, this message translates to:
  /// **'اكتب هدفك'**
  String get goalWrite;

  /// No description provided for @goalTooMany.
  ///
  /// In ar, this message translates to:
  /// **'عندك ٥ أهداف شغالة — خلّص واحد أو ألغيه الأول'**
  String get goalTooMany;

  /// No description provided for @goalSaveFailed.
  ///
  /// In ar, this message translates to:
  /// **'معرفتش أسجل الهدف — جرّب تاني'**
  String get goalSaveFailed;

  /// No description provided for @goalStart.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ الهدف'**
  String get goalStart;

  /// Brain health: the section listing messages the guards held this week.
  ///
  /// In ar, this message translates to:
  /// **'اللي سكتّ عنه وليه'**
  String get heldTitle;

  /// Brain health: no message was held this week.
  ///
  /// In ar, this message translates to:
  /// **'الأسبوع ده ماسكتّش عن أي حاجة — كل اللي كان يستاهل يتقال اتقال.'**
  String get heldNone;

  /// Brain health: the held-messages read failed.
  ///
  /// In ar, this message translates to:
  /// **'مش قادر أقرا اللي سكتّ عنه دلوقتي.'**
  String get heldFailed;

  /// Brain health: the held-messages read is in flight.
  ///
  /// In ar, this message translates to:
  /// **'بقرا…'**
  String get heldLoading;

  /// Brain health: under the held list, how to ask the brain about it.
  ///
  /// In ar, this message translates to:
  /// **'تقدر تسألني «إيه اللي ماقولتليش عليه؟» في الشات وأقولك بالتفصيل.'**
  String get heldAskHint;

  /// Brain health: how many times a guard held the same message.
  ///
  /// In ar, this message translates to:
  /// **'{count} مرات'**
  String heldTimes(int count);

  /// Held message: it was never sent.
  ///
  /// In ar, this message translates to:
  /// **'ماقولتهاش'**
  String get heldActionDropped;

  /// Held message: it waits for its slot.
  ///
  /// In ar, this message translates to:
  /// **'لسه مستنية'**
  String get heldActionWaiting;

  /// Held message: held, then sent later.
  ///
  /// In ar, this message translates to:
  /// **'أجّلتها'**
  String get heldActionPostponed;

  /// Guard: the customer muted this kind.
  ///
  /// In ar, this message translates to:
  /// **'إنت قلتلي أبطّل النوع ده لفترة'**
  String get heldReasonMuted;

  /// Guard (ZAD_PLAN 3.6): this home ignores this kind, so Zad sends it at most once a week.
  ///
  /// In ar, this message translates to:
  /// **'لاحظت إنك مابتتعاملش مع النوع ده غالباً، فبقلّل منه'**
  String get heldReasonLearnedQuiet;

  /// Guard: inside the sleep window.
  ///
  /// In ar, this message translates to:
  /// **'كان وقت نومك'**
  String get heldReasonQuietHours;

  /// Guard: waiting for the customer's reply hour.
  ///
  /// In ar, this message translates to:
  /// **'استنيت الساعة اللي بترد فيها عادة'**
  String get heldReasonReplyHour;

  /// Guard: too soon after the last message.
  ///
  /// In ar, this message translates to:
  /// **'كان لسه واصلك حاجة من شوية'**
  String get heldReasonPacing;

  /// Guard: the daily cap.
  ///
  /// In ar, this message translates to:
  /// **'وصلت لعدد الرسايل بتاع اليوم'**
  String get heldReasonDailyCap;

  /// Guard: a busy day.
  ///
  /// In ar, this message translates to:
  /// **'يومك كان مليان مواعيد'**
  String get heldReasonBusyDay;

  /// Guard: a hard time (travel, illness, a loss).
  ///
  /// In ar, this message translates to:
  /// **'كنت مراعي ظرفك'**
  String get heldReasonCircumstance;

  /// Guard: a duplicate.
  ///
  /// In ar, this message translates to:
  /// **'كنت قلتهالك قبلها بشوية'**
  String get heldReasonDuplicate;

  /// Guard: past its shelf life.
  ///
  /// In ar, this message translates to:
  /// **'كلامها قدم قبل ما ألاقي وقت مناسب'**
  String get heldReasonExpired;

  /// Guard: no longer relevant.
  ///
  /// In ar, this message translates to:
  /// **'مابقتش تفرق (اتعملت أو اتغيرت)'**
  String get heldReasonNotRelevant;

  /// Guard: nothing new.
  ///
  /// In ar, this message translates to:
  /// **'ماكانش فيه جديد يتقال'**
  String get heldReasonNothingNew;

  /// Guard: a reason this build has no words for.
  ///
  /// In ar, this message translates to:
  /// **'سبب تاني'**
  String get heldReasonOther;

  /// Held voice moment: good night.
  ///
  /// In ar, this message translates to:
  /// **'تصبح على خير'**
  String get heldKindGoodNight;

  /// Held voice moment: close your day.
  ///
  /// In ar, this message translates to:
  /// **'«اقفل يومك»'**
  String get heldKindCloseDay;

  /// Held voice moment: good morning.
  ///
  /// In ar, this message translates to:
  /// **'صباح الخير'**
  String get heldKindMorning;

  /// Held voice moment: the weekly money story.
  ///
  /// In ar, this message translates to:
  /// **'حكاية فلوس الأسبوع'**
  String get heldKindWeeklyStory;

  /// Held voice moment: the newcomer question.
  ///
  /// In ar, this message translates to:
  /// **'سؤال التعارف'**
  String get heldKindNewcomer;

  /// Held voice moment: the salary question.
  ///
  /// In ar, this message translates to:
  /// **'«ده المرتب؟»'**
  String get heldKindSalary;

  /// Held voice moment of another kind.
  ///
  /// In ar, this message translates to:
  /// **'رسالة صوتية'**
  String get heldKindVoice;

  /// Held task: the weekly home digest.
  ///
  /// In ar, this message translates to:
  /// **'ملخص البيت'**
  String get heldKindDigest;

  /// Held task: the spending forecast.
  ///
  /// In ar, this message translates to:
  /// **'توقّع مصروف الأسبوع'**
  String get heldKindForecast;

  /// Held task: spending ahead.
  ///
  /// In ar, this message translates to:
  /// **'الصرف أسرع من الميزانية'**
  String get heldKindSpendingAhead;

  /// Held task: a bill reminder.
  ///
  /// In ar, this message translates to:
  /// **'تذكير فاتورة'**
  String get heldKindBill;

  /// Held task: a warranty reminder.
  ///
  /// In ar, this message translates to:
  /// **'ضمان قرب ينتهي'**
  String get heldKindWarranty;

  /// Held task: a goal review.
  ///
  /// In ar, this message translates to:
  /// **'متابعة هدفك'**
  String get heldKindGoal;

  /// Held task: a habit and the budget.
  ///
  /// In ar, this message translates to:
  /// **'عادة بتتكرر'**
  String get heldKindHabit;

  /// Held task: predicted shortage.
  ///
  /// In ar, this message translates to:
  /// **'حاجات هتخلص قريب'**
  String get heldKindShortage;

  /// Held task: restock link.
  ///
  /// In ar, this message translates to:
  /// **'حاجة ضرورية خلصت'**
  String get heldKindRestock;

  /// Held task: the companion's call.
  ///
  /// In ar, this message translates to:
  /// **'نداء رفيقك'**
  String get heldKindPet;

  /// Held task of another kind.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظة من زاد'**
  String get heldKindNote;

  /// Hint under a price report's city field, from the account's market (ZAD_PLAN 3.13).
  ///
  /// In ar, this message translates to:
  /// **'مثل: القاهرة، الجيزة'**
  String get exampleCityEg;

  /// Hint under a price report's city field, from the account's market (ZAD_PLAN 3.13).
  ///
  /// In ar, this message translates to:
  /// **'مثل: الرياض، جدة'**
  String get exampleCitySa;

  /// Hint under a price report's city field, from the account's market (ZAD_PLAN 3.13).
  ///
  /// In ar, this message translates to:
  /// **'مثل: اسم مدينتك'**
  String get exampleCityOther;

  /// Hint under a price report's store field, from the account's market (ZAD_PLAN 3.13).
  ///
  /// In ar, this message translates to:
  /// **'مثل: كارفور، سبينيز'**
  String get exampleStoreEg;

  /// Hint under a price report's store field, from the account's market (ZAD_PLAN 3.13).
  ///
  /// In ar, this message translates to:
  /// **'مثل: بنده، العثيم'**
  String get exampleStoreSa;

  /// Hint under a price report's store field, from the account's market (ZAD_PLAN 3.13).
  ///
  /// In ar, this message translates to:
  /// **'مثل: اسم السوبر ماركت'**
  String get exampleStoreOther;

  /// Receipt scanner: paid from the bank account, named as the account's market names it (ZAD_PLAN 3.13).
  ///
  /// In ar, this message translates to:
  /// **'محفظة / إنستاباي'**
  String get walletBankEg;

  /// Receipt scanner: paid from the bank account, named as the account's market names it (ZAD_PLAN 3.13).
  ///
  /// In ar, this message translates to:
  /// **'محفظة / STC Pay'**
  String get walletBankSa;

  /// Receipt scanner: paid from the bank account, named as the account's market names it (ZAD_PLAN 3.13).
  ///
  /// In ar, this message translates to:
  /// **'محفظة / تحويل'**
  String get walletBankOther;

  /// Battery card: asks Android for the battery-optimisation exemption so the bank reading keeps running (ZAD_PLAN 2.1).
  ///
  /// In ar, this message translates to:
  /// **'خلّي زاد شغال دايماً'**
  String get keepAliveAllow;

  /// Title of the automation diagnostics screen and its settings row.
  ///
  /// In ar, this message translates to:
  /// **'تشخيص الأتمتة'**
  String get diagTitle;

  /// Settings row subtitle.
  ///
  /// In ar, this message translates to:
  /// **'إشعارات البنك ورسايل زاد — واقفة فين بالظبط'**
  String get diagMenuSubtitle;

  /// Button that reads the diagnosis again.
  ///
  /// In ar, this message translates to:
  /// **'حدّث التشخيص'**
  String get diagRefresh;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'اللي وصل السيرفر من إشعارات البنك'**
  String get diagBankTitle;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'آخر ١٤ يوم: كل إشعار الموبايل بعته، وزاد عمل بيه إيه وليه.'**
  String get diagBankNote;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'ماقدرتش أقرا من السيرفر'**
  String get diagReadFailedTitle;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'اتأكد من النت واسحب لتحت عشان تحدّث.'**
  String get diagReadFailedBody;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'مفيش إشعار وصل السيرفر'**
  String get diagBankEmptyTitle;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'لو دفعت بالكارت الأيام دي، العطل على الموبايل — شوف القسم اللي فوق.'**
  String get diagBankEmptyBody;

  /// A row whose notification had no title.
  ///
  /// In ar, this message translates to:
  /// **'إشعار'**
  String get diagNotification;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'واقفة عند أول خطوة: صلاحية قراءة الإشعارات مقفولة. فعّلها من القسم اللي فوق.'**
  String get diagBankNoAccess;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'الصلاحية شغالة بس خدمة القراءة عمرها ما اتوصلت. اقفل الصلاحية وافتحها تاني.'**
  String get diagBankNotBound;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'خدمة القراءة ماشافتش ولا إشعار من يومين — أندرويد وقّفها. اقفل الصلاحية وافتحها، وشيل زاد من توفير البطارية.'**
  String get diagBankSilent;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'فيه إشعارات اتقرت على الموبايل ولسه مااتبعتتش للسيرفر. افتح النت وسيب زاد مفتوح دقيقة.'**
  String get diagBankStuck;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'الموبايل شغال بس مفيش إشعار بنك وصل السيرفر. لو دفعت بالكارت، يبقى البنك بيبعت الرسالة من تطبيق مش متابَع — ابعتلنا اسمه.'**
  String get diagBankNothing;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'الإشعارات وصلت السيرفر بس كلها اتشالت — السبب جنب كل واحدة تحت.'**
  String get diagBankSetAside;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'فيه حركات مستنية تأكيدك. أكّدها من الإشعار أو من الرئيسية عشان تتسجل.'**
  String get diagBankWaiting;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'السلسلة شغالة: الإشعارات بتوصل وبتتسجل.'**
  String get diagBankOk;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'رسايل زاد اللي بيبدأها'**
  String get diagProTitle;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'صباح الخير، الجرعات، المواعيد، «اقفل يومك» — وصلت ولا لأ وليه.'**
  String get diagProNote;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'تليجرام'**
  String get diagTelegram;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'إشعارات التطبيق'**
  String get diagPush;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'مش عارف'**
  String get diagUnknown;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'مربوط'**
  String get diagLinked;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'مش مربوط'**
  String get diagNotLinked;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'الموبايل مش متسجّل لاستقبال إشعارات زاد'**
  String get diagPushOff;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'زاد مابدأش أي رسالة آخر ١٤ يوم'**
  String get diagProEmptyTitle;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'أول تحية صباح بتوصل الصبح الجاي لو فيه طريق يوصلك.'**
  String get diagProEmptyBody;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'زاد مش لاقي طريق يوصلك: لا تليجرام مربوط ولا الموبايل متسجّل للإشعارات. اربط تليجرام من الإعدادات، أو افتح التطبيق واسمح بالإشعارات.'**
  String get diagProNoChannel;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'السيرفر مابعتش حاجة آخر ١٤ يوم. ده مش طبيعي — ابعتلنا لقطة الشاشة دي.'**
  String get diagProNothing;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'أغلب الرسايل فشلت — السبب جنب كل واحدة تحت.'**
  String get diagProFailing;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'السلسلة شغالة: زاد بيبدأ وبيوصلك.'**
  String get diagProOk;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'صباح الخير'**
  String get diagMomentMorning;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'تصبح على خير'**
  String get diagMomentNight;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'اقفل يومك'**
  String get diagMomentCloseDay;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'ميعاد جرعة'**
  String get diagMomentDoseDue;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'جرعة فاتت'**
  String get diagMomentDoseMissed;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'تذكير جرعة'**
  String get diagMomentDoseNudge;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'ميعاد قريب'**
  String get diagMomentAppointment;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'ملخص الأسبوع'**
  String get diagMomentWeekly;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'حكاية الشهر'**
  String get diagMomentMonthly;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'اتسجلت مصروف'**
  String get diagIngestRecorded;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'مستنية تأكيدك («أكّد الحركة»)'**
  String get diagIngestWaiting;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'العقل شافها إعلان أو عرض، مش فلوس اتحركت'**
  String get diagIngestPromo;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'كود تحقق أو تنبيه أمان'**
  String get diagIngestOtp;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'حالة طلب أو توصيل'**
  String get diagIngestOrder;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'رسالة شخصية'**
  String get diagIngestPersonal;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'مالهاش علاقة بالفلوس'**
  String get diagIngestNonFinancial;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'العقل ماردّش وقتها والمصدر مش معروف'**
  String get diagIngestUnavailable;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'رسالة معلومات (رصيد أو تنبيه)'**
  String get diagIngestInfo;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'عملية فشلت أو لسه معلّقة'**
  String get diagIngestFailedTxn;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'نفس العملية وصلت من مكان تاني واتدمجت'**
  String get diagIngestMerged;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'خطأ في السيرفر — هتتجرب تاني'**
  String get diagIngestServerError;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'وصلت ولسه بتتراجع'**
  String get diagIngestReviewing;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'مفيش طريق يوصلك: لا تليجرام ولا إشعارات التطبيق'**
  String get diagMomentNoChannel;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'اتأجلت أو اتشالت (هدوء أو سقف اليوم)'**
  String get diagMomentSkipped;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'وصلت'**
  String get diagMomentSent;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'مستنية ميعادها'**
  String get diagMomentPending;

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'الموبايل متسجّل ({count})'**
  String diagPushOn(int count);

  /// Automation diagnostics screen.
  ///
  /// In ar, this message translates to:
  /// **'اتصنفت {kind}'**
  String diagIngestKind(String kind);

  /// Intro: the line under the brand.
  ///
  /// In ar, this message translates to:
  /// **'تدبير ذكي لبيت هادئ'**
  String get introTagline;

  /// Intro card 1 title.
  ///
  /// In ar, this message translates to:
  /// **'إدارة المخزون'**
  String get introPantryTitle;

  /// Intro card 1 body.
  ///
  /// In ar, this message translates to:
  /// **'تتبع كل ما في مطبخك وبيتك بذكاء'**
  String get introPantryBody;

  /// Intro card 2 title.
  ///
  /// In ar, this message translates to:
  /// **'العائلة كلها'**
  String get introFamilyTitle;

  /// Intro card 2 body.
  ///
  /// In ar, this message translates to:
  /// **'شارك الميزانية والمهام مع عائلتك'**
  String get introFamilyBody;

  /// Intro card 3 title.
  ///
  /// In ar, this message translates to:
  /// **'مساعد ذكي'**
  String get introAssistantTitle;

  /// Intro card 3 body.
  ///
  /// In ar, this message translates to:
  /// **'ذكاء اصطناعي يتنبأ باحتياجاتك ويتعلم منك'**
  String get introAssistantBody;

  /// Intro card 4 title.
  ///
  /// In ar, this message translates to:
  /// **'الميزانية بذكاء'**
  String get introBudgetTitle;

  /// Intro card 4 body.
  ///
  /// In ar, this message translates to:
  /// **'حلل إنفاقك ووفّر أكثر باقتراحات ذكية'**
  String get introBudgetBody;

  /// Intro: next card.
  ///
  /// In ar, this message translates to:
  /// **'التالي'**
  String get introNext;

  /// Intro: last card's button.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ مع زاد'**
  String get introStart;

  /// Intro: skip the cards.
  ///
  /// In ar, this message translates to:
  /// **'تخطي'**
  String get introSkip;

  /// Intro: go to sign-up.
  ///
  /// In ar, this message translates to:
  /// **'ليس لديك حساب؟ أنشئ حساباً جديداً'**
  String get introSignUp;

  /// Intro: the logo, for TalkBack.
  ///
  /// In ar, this message translates to:
  /// **'شعار زاد'**
  String get introLogoLabel;

  /// Ad button: this ad is one step of three; step in Arabic digits.
  ///
  /// In ar, this message translates to:
  /// **'شاهد إعلان — {step} من ٣'**
  String adWatchStep(String step);

  /// Under the ad button: the third ad opens the attempt.
  ///
  /// In ar, this message translates to:
  /// **'الإعلان ده بيكمّل التلاتة ويفتح {attempts}'**
  String adThirdOpens(String attempts);

  /// Under the ad button: progress toward the attempt.
  ///
  /// In ar, this message translates to:
  /// **'كل ٣ إعلانات = {attempts} — شفت {seen} من ٣'**
  String adThreeForOne(String attempts, String seen);

  /// No description provided for @appointmentGuardTitle.
  ///
  /// In ar, this message translates to:
  /// **'قبل ما أسجّله:'**
  String get appointmentGuardTitle;

  /// No description provided for @appointmentGuardAsk.
  ///
  /// In ar, this message translates to:
  /// **'تسجّله كده ولا تغيّر الوقت؟'**
  String get appointmentGuardAsk;

  /// No description provided for @appointmentGuardKeep.
  ///
  /// In ar, this message translates to:
  /// **'احفظه برضه'**
  String get appointmentGuardKeep;

  /// No description provided for @qtyLeftLittle.
  ///
  /// In ar, this message translates to:
  /// **'فاضل قليل'**
  String get qtyLeftLittle;

  /// No description provided for @qtyLeftHalf.
  ///
  /// In ar, this message translates to:
  /// **'فاضل نصه'**
  String get qtyLeftHalf;

  /// No description provided for @qtyLeftMost.
  ///
  /// In ar, this message translates to:
  /// **'فاضل كتير'**
  String get qtyLeftMost;

  /// No description provided for @scanLineToPharmacy.
  ///
  /// In ar, this message translates to:
  /// **'للصيدلية 💊'**
  String get scanLineToPharmacy;

  /// No description provided for @scanPantryWithMedicines.
  ///
  /// In ar, this message translates to:
  /// **'اللي موجود هتزيد كميته، واللي في قايمة المشتريات هيتشال منها، والأدوية هتروح الصيدلية.'**
  String get scanPantryWithMedicines;

  /// No description provided for @dealsTitle.
  ///
  /// In ar, this message translates to:
  /// **'العروض والمحلات القريبة'**
  String get dealsTitle;

  /// No description provided for @dealsTabDeals.
  ///
  /// In ar, this message translates to:
  /// **'العروض'**
  String get dealsTabDeals;

  /// No description provided for @dealsTabNearby.
  ///
  /// In ar, this message translates to:
  /// **'المحلات القريبة'**
  String get dealsTabNearby;

  /// No description provided for @dealsEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'مفيش عروض لسه'**
  String get dealsEmptyTitle;

  /// No description provided for @dealsEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'زاد بيدوّر كل أسبوع في صفحات المحلات وتطبيقات التوصيل وفواتير البيوت. أول ما يلاقي حاجة هتظهر هنا.'**
  String get dealsEmptyBody;

  /// No description provided for @dealsFailedTitle.
  ///
  /// In ar, this message translates to:
  /// **'ماقدرناش نجيب العروض'**
  String get dealsFailedTitle;

  /// No description provided for @dealsFailedBody.
  ///
  /// In ar, this message translates to:
  /// **'اتأكد من النت واسحب لتحت عشان تجرب تاني.'**
  String get dealsFailedBody;

  /// No description provided for @dealsCodesHeader.
  ///
  /// In ar, this message translates to:
  /// **'أكواد خصم'**
  String get dealsCodesHeader;

  /// No description provided for @dealsStoresHeader.
  ///
  /// In ar, this message translates to:
  /// **'عروض المحلات'**
  String get dealsStoresHeader;

  /// No description provided for @dealsFootnote.
  ///
  /// In ar, this message translates to:
  /// **'العروض من مصادرها ومتعلَّم عليها بتاريخها — ممكن يكون العرض خلص. زرار أمازون بيفتح بحث في متجر بلدك، وزاد بياخد عمولة صغيرة منه.'**
  String get dealsFootnote;

  /// No description provided for @dealsOnAmazon.
  ///
  /// In ar, this message translates to:
  /// **'على أمازون'**
  String get dealsOnAmazon;

  /// No description provided for @dealsCopied.
  ///
  /// In ar, this message translates to:
  /// **'اتنسخ {code}'**
  String dealsCopied(String code);

  /// No description provided for @dealsCodeTitle.
  ///
  /// In ar, this message translates to:
  /// **'{store} — خصم {off}'**
  String dealsCodeTitle(String store, String off);

  /// No description provided for @dealsPercent.
  ///
  /// In ar, this message translates to:
  /// **'{n}٪'**
  String dealsPercent(String n);

  /// No description provided for @dealsPrice.
  ///
  /// In ar, this message translates to:
  /// **'{store} · {price} {currency}'**
  String dealsPrice(String store, String price, String currency);

  /// No description provided for @dealsWasPrice.
  ///
  /// In ar, this message translates to:
  /// **'بدل {price}'**
  String dealsWasPrice(String price);

  /// No description provided for @dealsMinOrder.
  ///
  /// In ar, this message translates to:
  /// **'على طلب {amount} أو أكتر'**
  String dealsMinOrder(String amount);

  /// No description provided for @dealsUntil.
  ///
  /// In ar, this message translates to:
  /// **'لحد {date}'**
  String dealsUntil(String date);

  /// No description provided for @dealsSourceVideo.
  ///
  /// In ar, this message translates to:
  /// **'فيديو المحل'**
  String get dealsSourceVideo;

  /// No description provided for @dealsSourcePost.
  ///
  /// In ar, this message translates to:
  /// **'بوست المحل'**
  String get dealsSourcePost;

  /// No description provided for @dealsSourcePage.
  ///
  /// In ar, this message translates to:
  /// **'صفحة المحل'**
  String get dealsSourcePage;

  /// No description provided for @dealsSourceFlyer.
  ///
  /// In ar, this message translates to:
  /// **'نشرة المحل'**
  String get dealsSourceFlyer;

  /// No description provided for @dealsSourceReceipts.
  ///
  /// In ar, this message translates to:
  /// **'فواتير بيوت حواليك'**
  String get dealsSourceReceipts;

  /// No description provided for @dealsSourcePartner.
  ///
  /// In ar, this message translates to:
  /// **'رابط شراكة'**
  String get dealsSourcePartner;

  /// No description provided for @dealsSourceOther.
  ///
  /// In ar, this message translates to:
  /// **'المصدر'**
  String get dealsSourceOther;

  /// No description provided for @homeDealsTitle.
  ///
  /// In ar, this message translates to:
  /// **'عروض على نواقصك'**
  String get homeDealsTitle;

  /// No description provided for @recipesWeekGroup.
  ///
  /// In ar, this message translates to:
  /// **'خطة الأسبوع'**
  String get recipesWeekGroup;

  /// No description provided for @recipesWeekAction.
  ///
  /// In ar, this message translates to:
  /// **'خطة الأسبوع'**
  String get recipesWeekAction;

  /// No description provided for @recipesAddToPantry.
  ///
  /// In ar, this message translates to:
  /// **'ضيف للمخزن'**
  String get recipesAddToPantry;

  /// No description provided for @recipesWeekDay.
  ///
  /// In ar, this message translates to:
  /// **'اليوم {day}'**
  String recipesWeekDay(int day);

  /// No description provided for @recipesOnDeal.
  ///
  /// In ar, this message translates to:
  /// **'عليه عرض دلوقتي'**
  String get recipesOnDeal;

  /// No description provided for @recipesFromCreator.
  ///
  /// In ar, this message translates to:
  /// **'من فيديو @{handle}'**
  String recipesFromCreator(String handle);

  /// No description provided for @recipesTrendingGroup.
  ///
  /// In ar, this message translates to:
  /// **'ترند دلوقتي'**
  String get recipesTrendingGroup;

  /// No description provided for @homeDealsSeeAll.
  ///
  /// In ar, this message translates to:
  /// **'كل العروض'**
  String get homeDealsSeeAll;

  /// No description provided for @homeDealsSearching.
  ///
  /// In ar, this message translates to:
  /// **'بندوّرلك على عروض في محلاتك — اضغط تشوف اللي لقيناه'**
  String get homeDealsSearching;

  /// No description provided for @sheinShop.
  ///
  /// In ar, this message translates to:
  /// **'تسوّق على SHEIN'**
  String get sheinShop;

  /// No description provided for @sheinDisclosure.
  ///
  /// In ar, this message translates to:
  /// **'زاد بياخد عمولة من SHEIN على المشتريات من الروابط دي، من غير ما السعر يزيد عليك.'**
  String get sheinDisclosure;

  /// No description provided for @homeNearbyTitle.
  ///
  /// In ar, this message translates to:
  /// **'ماركتات وصيدليات جنبك'**
  String get homeNearbyTitle;

  /// No description provided for @homeNearbySeeAll.
  ///
  /// In ar, this message translates to:
  /// **'أماكني'**
  String get homeNearbySeeAll;

  /// No description provided for @homeNearbyFind.
  ///
  /// In ar, this message translates to:
  /// **'اعرف الماركتات والصيدليات اللي جنبك — اضغط وحدّد مكانك'**
  String get homeNearbyFind;

  /// No description provided for @homeDealsOrderOnAmazon.
  ///
  /// In ar, this message translates to:
  /// **'اطلبه من أمازون، يوصلك بسرعة'**
  String get homeDealsOrderOnAmazon;

  /// No description provided for @amazonAssociatesDisclosure.
  ///
  /// In ar, this message translates to:
  /// **'بصفتنا شريك في Amazon Associates، زاد بياخد عمولة من المشتريات المؤهلة — من غير أي زيادة عليك.'**
  String get amazonAssociatesDisclosure;

  /// No description provided for @homeDealsWhyNeed.
  ///
  /// In ar, this message translates to:
  /// **'ناقص عندك'**
  String get homeDealsWhyNeed;

  /// No description provided for @homeDealsWhyFavorite.
  ///
  /// In ar, this message translates to:
  /// **'من محلك'**
  String get homeDealsWhyFavorite;

  /// No description provided for @homeDealsWhyFire.
  ///
  /// In ar, this message translates to:
  /// **'خصم كبير'**
  String get homeDealsWhyFire;

  /// No description provided for @homeDealsWhyWant.
  ///
  /// In ar, this message translates to:
  /// **'بتدوّر عليه'**
  String get homeDealsWhyWant;

  /// No description provided for @homeDealsWhySeason.
  ///
  /// In ar, this message translates to:
  /// **'قبل الموسم'**
  String get homeDealsWhySeason;

  /// No description provided for @homeDealsWhyTop.
  ///
  /// In ar, this message translates to:
  /// **'من أقوى الخصومات'**
  String get homeDealsWhyTop;

  /// No description provided for @homeDealsCode.
  ///
  /// In ar, this message translates to:
  /// **'كود {code}'**
  String homeDealsCode(String code);

  /// No description provided for @bankTestLifeEvent.
  ///
  /// In ar, this message translates to:
  /// **'ميعاد أو حدث'**
  String get bankTestLifeEvent;

  /// No description provided for @outOfAttemptsTitle.
  ///
  /// In ar, this message translates to:
  /// **'محاولاتك خلصت'**
  String get outOfAttemptsTitle;

  /// No description provided for @lowAttemptsTitle.
  ///
  /// In ar, this message translates to:
  /// **'محاولاتك قربت تخلص'**
  String get lowAttemptsTitle;

  /// No description provided for @outOfAttemptsBody.
  ///
  /// In ar, this message translates to:
  /// **'شاهد إعلان وخد ٥ رسايل، أو اشترك وارتاح.'**
  String get outOfAttemptsBody;

  /// No description provided for @outOfAttemptsPlans.
  ///
  /// In ar, this message translates to:
  /// **'شوف الباقات'**
  String get outOfAttemptsPlans;

  /// No description provided for @patternTitle.
  ///
  /// In ar, this message translates to:
  /// **'نمط استهلاكك'**
  String get patternTitle;

  /// No description provided for @patternMenuSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'محلاتك، ومواعيد شراك، ودورة كل صنف'**
  String get patternMenuSubtitle;

  /// No description provided for @patternLearningTitle.
  ///
  /// In ar, this message translates to:
  /// **'لسه بتعلّم'**
  String get patternLearningTitle;

  /// No description provided for @patternLearningMessage.
  ///
  /// In ar, this message translates to:
  /// **'زاد بيحسب نمطك كل ليلة من فواتيرك ومصروفك. صوّر فاتورة أو سجّل مصروف وارجع بكرة.'**
  String get patternLearningMessage;

  /// No description provided for @patternReadFailed.
  ///
  /// In ar, this message translates to:
  /// **'مقدرتش أقرا نمطك دلوقتي. اسحب لتحت وجرّب تاني.'**
  String get patternReadFailed;

  /// No description provided for @patternWeekly.
  ///
  /// In ar, this message translates to:
  /// **'متوسط صرفك في الأسبوع'**
  String get patternWeekly;

  /// No description provided for @patternStores.
  ///
  /// In ar, this message translates to:
  /// **'محلاتك'**
  String get patternStores;

  /// No description provided for @patternStoreLine.
  ///
  /// In ar, this message translates to:
  /// **'{visits} زيارة · {share}٪ من صرفك فيهم'**
  String patternStoreLine(String visits, String share);

  /// No description provided for @patternWhen.
  ///
  /// In ar, this message translates to:
  /// **'إمتى بتشتري'**
  String get patternWhen;

  /// No description provided for @patternWhenLine.
  ///
  /// In ar, this message translates to:
  /// **'غالباً يوم {day} {part}'**
  String patternWhenLine(String day, String part);

  /// No description provided for @patternEvery.
  ///
  /// In ar, this message translates to:
  /// **'مشوار شرا كل {days} أيام تقريباً'**
  String patternEvery(String days);

  /// No description provided for @patternWhenUnknown.
  ///
  /// In ar, this message translates to:
  /// **'محتاج ٤ مشاوير شرا على الأقل عشان أعرف إمتى بتشتري'**
  String get patternWhenUnknown;

  /// No description provided for @patternPartMorning.
  ///
  /// In ar, this message translates to:
  /// **'الصبح'**
  String get patternPartMorning;

  /// No description provided for @patternPartNoon.
  ///
  /// In ar, this message translates to:
  /// **'الضهر'**
  String get patternPartNoon;

  /// No description provided for @patternPartEvening.
  ///
  /// In ar, this message translates to:
  /// **'المسا'**
  String get patternPartEvening;

  /// No description provided for @patternPartNight.
  ///
  /// In ar, this message translates to:
  /// **'بالليل'**
  String get patternPartNight;

  /// No description provided for @patternItems.
  ///
  /// In ar, this message translates to:
  /// **'دورة كل صنف'**
  String get patternItems;

  /// No description provided for @patternItemsHint.
  ///
  /// In ar, this message translates to:
  /// **'دوس على صنف عشان تقول لزاد بتشتريه كل قد إيه'**
  String get patternItemsHint;

  /// No description provided for @patternItemEvery.
  ///
  /// In ar, this message translates to:
  /// **'كل {days} يوم'**
  String patternItemEvery(String days);

  /// No description provided for @patternSourceCustomer.
  ///
  /// In ar, this message translates to:
  /// **'انت اللي حددتها'**
  String get patternSourceCustomer;

  /// No description provided for @patternSourceLearned.
  ///
  /// In ar, this message translates to:
  /// **'من مرات شراك'**
  String get patternSourceLearned;

  /// No description provided for @patternSourceEstimate.
  ///
  /// In ar, this message translates to:
  /// **'تقدير مبدئي'**
  String get patternSourceEstimate;

  /// No description provided for @patternDueNow.
  ///
  /// In ar, this message translates to:
  /// **'وقت شراه'**
  String get patternDueNow;

  /// No description provided for @patternDueIn.
  ///
  /// In ar, this message translates to:
  /// **'الشرا الجاي بعد {days} يوم'**
  String patternDueIn(String days);

  /// No description provided for @patternEditTitle.
  ///
  /// In ar, this message translates to:
  /// **'بتشتري {item} كل قد إيه؟'**
  String patternEditTitle(String item);

  /// No description provided for @patternEditField.
  ///
  /// In ar, this message translates to:
  /// **'عدد الأيام'**
  String get patternEditField;

  /// No description provided for @patternEditInvalid.
  ///
  /// In ar, this message translates to:
  /// **'اكتب رقم من ١ لـ٣٦٥'**
  String get patternEditInvalid;

  /// No description provided for @patternEditSave.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get patternEditSave;

  /// No description provided for @patternEditReset.
  ///
  /// In ar, this message translates to:
  /// **'خلّي زاد يحكم'**
  String get patternEditReset;

  /// No description provided for @patternEditNotInPantry.
  ///
  /// In ar, this message translates to:
  /// **'الصنف ده مش في مخزنك دلوقتي'**
  String get patternEditNotInPantry;

  /// No description provided for @patternEditSaved.
  ///
  /// In ar, this message translates to:
  /// **'اتحفظ — زاد هيحسب {item} على كده'**
  String patternEditSaved(String item);

  /// No description provided for @homeBankOffBanner.
  ///
  /// In ar, this message translates to:
  /// **'⚠️ قراءة رسائل البنك متوقفة.. اضغط هنا لإعادة تفعيلها لتحديث رصيدك ومصاريفك تلقائياً'**
  String get homeBankOffBanner;

  /// No description provided for @homeBankStalledHint.
  ///
  /// In ar, this message translates to:
  /// **'لو هي مفعّلة: اطفيها وشغّلها تاني من الصفحة اللي هتفتح.'**
  String get homeBankStalledHint;

  /// No description provided for @homeLocationOffBanner.
  ///
  /// In ar, this message translates to:
  /// **'📍 موقعك غير مفعّل.. فعّل اللوكيشن عشان زاد يربط عروض السوبرماركت والمحلات القريبة منك ويقوم بمهامه صح'**
  String get homeLocationOffBanner;

  /// No description provided for @homeLocationLater.
  ///
  /// In ar, this message translates to:
  /// **'مش دلوقتي'**
  String get homeLocationLater;

  /// No description provided for @channelCardTitle.
  ///
  /// In ar, this message translates to:
  /// **'مفيش طريقة أوصلك بيها'**
  String get channelCardTitle;

  /// No description provided for @channelCardBody.
  ///
  /// In ar, this message translates to:
  /// **'الإشعارات مقفولة وتليجرام مش مربوط، فمواعيد الدوا والفواتير وتنبيه الميزانية مش هتوصلك. واحدة منهم كفاية.'**
  String get channelCardBody;

  /// No description provided for @channelCardNotifications.
  ///
  /// In ar, this message translates to:
  /// **'فعّل الإشعارات'**
  String get channelCardNotifications;

  /// No description provided for @channelCardTelegram.
  ///
  /// In ar, this message translates to:
  /// **'اربط تليجرام'**
  String get channelCardTelegram;

  /// No description provided for @briefWhy.
  ///
  /// In ar, this message translates to:
  /// **'ليه؟'**
  String get briefWhy;

  /// No description provided for @briefWhyDose.
  ///
  /// In ar, this message translates to:
  /// **'من جدول {name}: جرعة الساعة {time}، ومفيش تسجيل إنها اتاخدت.'**
  String briefWhyDose(String name, String time);

  /// No description provided for @briefWhyMissed.
  ///
  /// In ar, this message translates to:
  /// **'جرعات النهارده اللي عدّى ميعادها ومااتسجلتش: {count}.'**
  String briefWhyMissed(String count);

  /// No description provided for @briefWhyOverspent.
  ///
  /// In ar, this message translates to:
  /// **'المتاح للدورة دي تحت الصفر: رصيد أول الدورة ناقص اللي اتصرف والالتزامات الثابتة.'**
  String get briefWhyOverspent;

  /// No description provided for @briefWhyRenewal.
  ///
  /// In ar, this message translates to:
  /// **'«{name}» متسجل في اشتراكاتك، وده ميعاد تجديده الجاي.'**
  String briefWhyRenewal(String name);

  /// No description provided for @briefWhyShortage.
  ///
  /// In ar, this message translates to:
  /// **'{name}: فاضل {left}، وده الحد اللي بيبقى عنده ناقص ({threshold}).'**
  String briefWhyShortage(String name, String left, String threshold);

  /// No description provided for @briefWhyRunningOut.
  ///
  /// In ar, this message translates to:
  /// **'{name}: فاضل {left}، وبتستهلك حوالي {perDay} في اليوم.'**
  String briefWhyRunningOut(String name, String left, String perDay);

  /// No description provided for @briefWhyRunningOutApprox.
  ///
  /// In ar, this message translates to:
  /// **'{name}: فاضل {left}، واستهلاكك لسه بيتقاس — حوالي {perDay} في اليوم، فده تقدير.'**
  String briefWhyRunningOutApprox(String name, String left, String perDay);

  /// No description provided for @briefWhyFamily.
  ///
  /// In ar, this message translates to:
  /// **'حد في شات العيلة قال إنها ناقصة، وزاد لقطها وهو بيراجع الشات.'**
  String get briefWhyFamily;

  /// No description provided for @briefMedicineLow.
  ///
  /// In ar, this message translates to:
  /// **'{name} هيخلص بعد {days} يوم'**
  String briefMedicineLow(String name, String days);

  /// No description provided for @briefMedicineLowDetail.
  ///
  /// In ar, this message translates to:
  /// **'اطلب علبة جديدة قبل ما يخلص'**
  String get briefMedicineLowDetail;

  /// No description provided for @briefBudgetDanger.
  ///
  /// In ar, this message translates to:
  /// **'الميزانية في خطر: باقي {daily} في اليوم لـ{days} يوم'**
  String briefBudgetDanger(String daily, String days);

  /// No description provided for @briefBudgetDangerDetail.
  ///
  /// In ar, this message translates to:
  /// **'شوف فلوسي — لسه فيه وقت تلحق'**
  String get briefBudgetDangerDetail;

  /// No description provided for @briefSeasonRamadan.
  ///
  /// In ar, this message translates to:
  /// **'رمضان بعد {days} يوم'**
  String briefSeasonRamadan(String days);

  /// No description provided for @briefSeasonHijjah.
  ///
  /// In ar, this message translates to:
  /// **'العشر من ذي الحجة بعد {days} يوم'**
  String briefSeasonHijjah(String days);

  /// No description provided for @briefSeasonDetail.
  ///
  /// In ar, this message translates to:
  /// **'جهّز الأساسيات قبل ما الأسعار تعلى'**
  String get briefSeasonDetail;

  /// No description provided for @briefWhyMedicineLow.
  ///
  /// In ar, this message translates to:
  /// **'{name}: الحبوب اللي فاضلة ÷ الجرعات في اليوم = {days} يوم.'**
  String briefWhyMedicineLow(String name, String days);

  /// No description provided for @briefWhyBudgetDanger.
  ///
  /// In ar, this message translates to:
  /// **'المتاح {available} على {days} يوم = {daily} في اليوم، ومعدل صرفك لحد دلوقتي بيقول إنه مش هيكفي.'**
  String briefWhyBudgetDanger(String available, String days, String daily);

  /// No description provided for @briefWhySeason.
  ///
  /// In ar, this message translates to:
  /// **'من تقويم أم القرى بتوقيت بلدك — والأسعار بتعلى قبل الموسم.'**
  String get briefWhySeason;

  /// No description provided for @accountRestoreTitle.
  ///
  /// In ar, this message translates to:
  /// **'حسابك مجدول للحذف'**
  String get accountRestoreTitle;

  /// No description provided for @accountRestoreBody.
  ///
  /// In ar, this message translates to:
  /// **'طلبت حذف حسابك، وهيتمسح هو وكل بياناته نهائياً بعد {days} يوم. تحب ترجّعه؟'**
  String accountRestoreBody(int days);

  /// No description provided for @accountRestoreLeave.
  ///
  /// In ar, this message translates to:
  /// **'خروج'**
  String get accountRestoreLeave;

  /// No description provided for @accountRestoreYes.
  ///
  /// In ar, this message translates to:
  /// **'رجّع حسابي'**
  String get accountRestoreYes;

  /// No description provided for @accountRestoreFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذر استرجاع الحساب دلوقتي. افتح التطبيق تاني وجرّب.'**
  String get accountRestoreFailed;

  /// No description provided for @settingsCompanionSection.
  ///
  /// In ar, this message translates to:
  /// **'رفيقك'**
  String get settingsCompanionSection;

  /// No description provided for @settingsFoodPatternTitle.
  ///
  /// In ar, this message translates to:
  /// **'صورة أكل البيت'**
  String get settingsFoodPatternTitle;

  /// No description provided for @settingsFoodPatternBody.
  ///
  /// In ar, this message translates to:
  /// **'مرة في الشهر بالكتير، زاد يوصف أكل البيت من المشتريات المتسجلة ويقترح إضافات. وصف مشتريات مش نصيحة طبية.'**
  String get settingsFoodPatternBody;

  /// No description provided for @commuteTitle.
  ///
  /// In ar, this message translates to:
  /// **'أتعلم مواعيد نزولك ورجوعك'**
  String get commuteTitle;

  /// No description provided for @commuteBody.
  ///
  /// In ar, this message translates to:
  /// **'اختياري. مواعيد بس، من غير أماكن ولا مشاوير.'**
  String get commuteBody;

  /// No description provided for @commuteConsentTitle.
  ///
  /// In ar, this message translates to:
  /// **'زاد يتعلم مواعيد يومك؟'**
  String get commuteConsentTitle;

  /// No description provided for @commuteConsentBody.
  ///
  /// In ar, this message translates to:
  /// **'زاد هيحسب إمتى بتنزل من البيت وبترجع، من خروجك ورجوعك للبيت. عشان يظبط تنبيهاتك على يومك ويكلمك في الوقت المناسب.\n\nبيتحسب على موبايلك، وللسيرفر بيروح ملخص المواعيد والأيام بس، من غير أي إحداثيات أو أماكن شغل أو خط سير. محدش من العيلة بيشوفه. ولو قفلت المفتاح، بيتمسح من الموبايل والسيرفر.'**
  String get commuteConsentBody;

  /// No description provided for @commuteConsentAgree.
  ///
  /// In ar, this message translates to:
  /// **'موافق'**
  String get commuteConsentAgree;

  /// No description provided for @commuteConsentDecline.
  ///
  /// In ar, this message translates to:
  /// **'لأ، مش دلوقتي'**
  String get commuteConsentDecline;

  /// No description provided for @settingsPetCallsTitle.
  ///
  /// In ar, this message translates to:
  /// **'نداءات زادو'**
  String get settingsPetCallsTitle;

  /// No description provided for @settingsPetCallsBody.
  ///
  /// In ar, this message translates to:
  /// **'زادو بيبعتلك لما يجوع أو يعطش، على تليجرام والإشعارات. قفلها مش بيوقف تحية الصبح ولا العروض.'**
  String get settingsPetCallsBody;

  /// No description provided for @homeWidgetSubs.
  ///
  /// In ar, this message translates to:
  /// **'اشتراكات'**
  String get homeWidgetSubs;

  /// No description provided for @homeWidgetSubsEmpty.
  ///
  /// In ar, this message translates to:
  /// **'ضيف اشتراك'**
  String get homeWidgetSubsEmpty;

  /// No description provided for @homeWidgetSubsToday.
  ///
  /// In ar, this message translates to:
  /// **'النهارده'**
  String get homeWidgetSubsToday;

  /// No description provided for @homeWidgetSubsTomorrow.
  ///
  /// In ar, this message translates to:
  /// **'بكرة'**
  String get homeWidgetSubsTomorrow;

  /// No description provided for @homeWidgetSubsInDays.
  ///
  /// In ar, this message translates to:
  /// **'بعد {days} يوم'**
  String homeWidgetSubsInDays(Object days);

  /// No description provided for @homeWidgetPantry.
  ///
  /// In ar, this message translates to:
  /// **'المخزون'**
  String get homeWidgetPantry;

  /// No description provided for @homeWidgetPantryShort.
  ///
  /// In ar, this message translates to:
  /// **'{count} ناقص'**
  String homeWidgetPantryShort(Object count);

  /// No description provided for @homeWidgetPantryFine.
  ///
  /// In ar, this message translates to:
  /// **'كله تمام'**
  String get homeWidgetPantryFine;

  /// No description provided for @homeWidgetPantryCount.
  ///
  /// In ar, this message translates to:
  /// **'{count} صنف'**
  String homeWidgetPantryCount(Object count);

  /// No description provided for @homeWidgetPantryEmpty.
  ///
  /// In ar, this message translates to:
  /// **'ضيف أصناف'**
  String get homeWidgetPantryEmpty;

  /// No description provided for @homeWidgetPharmacy.
  ///
  /// In ar, this message translates to:
  /// **'الصيدلية'**
  String get homeWidgetPharmacy;

  /// No description provided for @homeWidgetPharmacyNone.
  ///
  /// In ar, this message translates to:
  /// **'مفيش جرعات'**
  String get homeWidgetPharmacyNone;

  /// No description provided for @homeWidgetPharmacyActive.
  ///
  /// In ar, this message translates to:
  /// **'{count} دوا'**
  String homeWidgetPharmacyActive(Object count);

  /// No description provided for @homeWidgetPharmacyEmpty.
  ///
  /// In ar, this message translates to:
  /// **'ضيف دوا'**
  String get homeWidgetPharmacyEmpty;

  /// No description provided for @homeWidgetShortages.
  ///
  /// In ar, this message translates to:
  /// **'النواقص'**
  String get homeWidgetShortages;

  /// No description provided for @homeWidgetShortagesCount.
  ///
  /// In ar, this message translates to:
  /// **'{count} تتجاب'**
  String homeWidgetShortagesCount(int count);

  /// No description provided for @homeWidgetShortagesEmpty.
  ///
  /// In ar, this message translates to:
  /// **'مفيش نواقص'**
  String get homeWidgetShortagesEmpty;

  /// No description provided for @placesTabMine.
  ///
  /// In ar, this message translates to:
  /// **'أماكني'**
  String get placesTabMine;

  /// No description provided for @placesOutingsTurnOn.
  ///
  /// In ar, this message translates to:
  /// **'فعّل تسجيل خروجاتي'**
  String get placesOutingsTurnOn;

  /// No description provided for @placesOutingsWaiting.
  ///
  /// In ar, this message translates to:
  /// **'شغال. أول ما تخرج وترجع البيت، خروجتك هتظهر هنا.'**
  String get placesOutingsWaiting;

  /// No description provided for @familyHeaderTitle.
  ///
  /// In ar, this message translates to:
  /// **'عيلتي'**
  String get familyHeaderTitle;

  /// No description provided for @shellLanguageShort.
  ///
  /// In ar, this message translates to:
  /// **'EN'**
  String get shellLanguageShort;

  /// No description provided for @chefHomeTapHint.
  ///
  /// In ar, this message translates to:
  /// **'اضغط وأنا أقترحلك طبق من اللي عندك في المخزون.'**
  String get chefHomeTapHint;

  /// No description provided for @chefFullRecipe.
  ///
  /// In ar, this message translates to:
  /// **'الشرح الكامل وأسرار الشيف'**
  String get chefFullRecipe;

  /// No description provided for @chefSecrets.
  ///
  /// In ar, this message translates to:
  /// **'🤫 أسرار الشيف'**
  String get chefSecrets;

  /// No description provided for @chefSourceLink.
  ///
  /// In ar, this message translates to:
  /// **'شوف الوصفة في مصدرها'**
  String get chefSourceLink;

  /// No description provided for @chefSourceHandle.
  ///
  /// In ar, this message translates to:
  /// **'شوف الوصفة عند @{handle}'**
  String chefSourceHandle(Object handle);

  /// No description provided for @chefAsk.
  ///
  /// In ar, this message translates to:
  /// **'اسأل الشيف عن الوصفة دي'**
  String get chefAsk;

  /// No description provided for @chefAskPrefill.
  ///
  /// In ar, this message translates to:
  /// **'يا شيف، في وصفة {name}: '**
  String chefAskPrefill(Object name);

  /// No description provided for @familyTitleOf.
  ///
  /// In ar, this message translates to:
  /// **'عيلة {name}'**
  String familyTitleOf(Object name);

  /// No description provided for @familyMembersCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{فرد واحد} =2{فردين} few{{count} أفراد} other{{count} فرد}}'**
  String familyMembersCount(num count);

  /// No description provided for @familyActionInvite.
  ///
  /// In ar, this message translates to:
  /// **'دعوة'**
  String get familyActionInvite;

  /// No description provided for @familyActionShare.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة'**
  String get familyActionShare;

  /// No description provided for @familyActionSos.
  ///
  /// In ar, this message translates to:
  /// **'طوارئ'**
  String get familyActionSos;

  /// No description provided for @familyChatTools.
  ///
  /// In ar, this message translates to:
  /// **'أدوات الشات'**
  String get familyChatTools;

  /// No description provided for @familyChatQuickReplies.
  ///
  /// In ar, this message translates to:
  /// **'ردود سريعة'**
  String get familyChatQuickReplies;

  /// No description provided for @familyChatRequest.
  ///
  /// In ar, this message translates to:
  /// **'طلب مصروف'**
  String get familyChatRequest;

  /// No description provided for @familyChatPoll.
  ///
  /// In ar, this message translates to:
  /// **'تصويت'**
  String get familyChatPoll;

  /// No description provided for @familyChatTask.
  ///
  /// In ar, this message translates to:
  /// **'مهمة جديدة'**
  String get familyChatTask;

  /// No description provided for @familyChatGrocery.
  ///
  /// In ar, this message translates to:
  /// **'طلب بقالة'**
  String get familyChatGrocery;

  /// No description provided for @familyChatSos.
  ///
  /// In ar, this message translates to:
  /// **'نداء طوارئ'**
  String get familyChatSos;

  /// No description provided for @pulseTitle.
  ///
  /// In ar, this message translates to:
  /// **'نبض فلوسك'**
  String get pulseTitle;

  /// No description provided for @pulseLastDays.
  ///
  /// In ar, this message translates to:
  /// **'{days, plural, few{آخر {days} أيام} other{آخر {days} يوم}}'**
  String pulseLastDays(num days);

  /// No description provided for @pulseLess.
  ///
  /// In ar, this message translates to:
  /// **'أقل {pct}٪ من الفترة اللي قبلها'**
  String pulseLess(Object pct);

  /// No description provided for @pulseMore.
  ///
  /// In ar, this message translates to:
  /// **'أكتر {pct}٪ من الفترة اللي قبلها'**
  String pulseMore(Object pct);

  /// No description provided for @pulseDaily.
  ///
  /// In ar, this message translates to:
  /// **'متوسط اليوم'**
  String get pulseDaily;

  /// No description provided for @pulsePeak.
  ///
  /// In ar, this message translates to:
  /// **'أعلى يوم'**
  String get pulsePeak;

  /// No description provided for @pulseTop.
  ///
  /// In ar, this message translates to:
  /// **'أكبر بند'**
  String get pulseTop;

  /// No description provided for @pulseAskPrompt.
  ///
  /// In ar, this message translates to:
  /// **'حلل صرفي على {category}'**
  String pulseAskPrompt(Object category);

  /// No description provided for @brainReportWaits.
  ///
  /// In ar, this message translates to:
  /// **'سجل 3 مصاريف وتقرير زاد الكامل يجهز'**
  String get brainReportWaits;

  /// No description provided for @profileLanguageSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'عربي أو English، بضغطة واحدة'**
  String get profileLanguageSubtitle;

  /// No description provided for @profileCompanionTitle.
  ///
  /// In ar, this message translates to:
  /// **'رفيق زاد'**
  String get profileCompanionTitle;

  /// No description provided for @profileCompanionSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'زادو، هدومه وألعابه ولفله'**
  String get profileCompanionSubtitle;

  /// No description provided for @profilePremiumTitle.
  ///
  /// In ar, this message translates to:
  /// **'زاد بريميوم'**
  String get profilePremiumTitle;

  /// No description provided for @profilePremiumSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'اشتراكك ومميزاتك ورصيدك'**
  String get profilePremiumSubtitle;

  /// No description provided for @tourOpen.
  ///
  /// In ar, this message translates to:
  /// **'جولة في زاد'**
  String get tourOpen;

  /// No description provided for @profileTourSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'لفّة سريعة على كل حتة في التطبيق'**
  String get profileTourSubtitle;

  /// No description provided for @tourNext.
  ///
  /// In ar, this message translates to:
  /// **'التالي'**
  String get tourNext;

  /// No description provided for @tourSkip.
  ///
  /// In ar, this message translates to:
  /// **'تخطي'**
  String get tourSkip;

  /// No description provided for @tourDone.
  ///
  /// In ar, this message translates to:
  /// **'يلا نبدأ'**
  String get tourDone;

  /// No description provided for @tourStepOf.
  ///
  /// In ar, this message translates to:
  /// **'{step} من {total}'**
  String tourStepOf(Object step, Object total);

  /// No description provided for @tourWelcomeTitle.
  ///
  /// In ar, this message translates to:
  /// **'أهلاً بيك في زاد'**
  String get tourWelcomeTitle;

  /// No description provided for @tourWelcomeBody.
  ///
  /// In ar, this message translates to:
  /// **'في نص دقيقة هنوريك كل حاجة فين.'**
  String get tourWelcomeBody;

  /// No description provided for @tourHomeTitle.
  ///
  /// In ar, this message translates to:
  /// **'الرئيسية'**
  String get tourHomeTitle;

  /// No description provided for @tourHomeBody.
  ///
  /// In ar, this message translates to:
  /// **'فلوسك المتاحة، وأهم اللي محتاج يتعمل النهارده.'**
  String get tourHomeBody;

  /// No description provided for @tourMoneyTitle.
  ///
  /// In ar, this message translates to:
  /// **'فلوسي'**
  String get tourMoneyTitle;

  /// No description provided for @tourMoneyBody.
  ///
  /// In ar, this message translates to:
  /// **'ميزانيتك ومصاريفك والتزاماتك الشهرية.'**
  String get tourMoneyBody;

  /// No description provided for @tourMicTitle.
  ///
  /// In ar, this message translates to:
  /// **'كلّم زاد'**
  String get tourMicTitle;

  /// No description provided for @tourMicBody.
  ///
  /// In ar, this message translates to:
  /// **'قول «سجل ٥٠ جنيه قهوة» أو اسأل أي سؤال، وزاد يرد عليك.'**
  String get tourMicBody;

  /// No description provided for @tourCameraTitle.
  ///
  /// In ar, this message translates to:
  /// **'صوّر الفاتورة'**
  String get tourCameraTitle;

  /// No description provided for @tourCameraBody.
  ///
  /// In ar, this message translates to:
  /// **'صوّر إيصال، وزاد يسجله في مصاريفك ويضيف الحاجات للمخزن.'**
  String get tourCameraBody;

  /// No description provided for @tourHouseTitle.
  ///
  /// In ar, this message translates to:
  /// **'بيتي'**
  String get tourHouseTitle;

  /// No description provided for @tourHouseBody.
  ///
  /// In ar, this message translates to:
  /// **'المخزن والنواقص والصيدلية ووصفات الشيف.'**
  String get tourHouseBody;

  /// No description provided for @tourMoreTitle.
  ///
  /// In ar, this message translates to:
  /// **'المزيد'**
  String get tourMoreTitle;

  /// No description provided for @tourMoreBody.
  ///
  /// In ar, this message translates to:
  /// **'العيلة وعقل زاد وحسابك وكل المزايا.'**
  String get tourMoreBody;

  /// No description provided for @tourBellTitle.
  ///
  /// In ar, this message translates to:
  /// **'الإشعارات'**
  String get tourBellTitle;

  /// No description provided for @tourBellBody.
  ///
  /// In ar, this message translates to:
  /// **'كل تنبيهات زاد وتذكيراته في مكان واحد.'**
  String get tourBellBody;

  /// No description provided for @shoppingBasketEmpty.
  ///
  /// In ar, this message translates to:
  /// **'السلة فاضية — ضيف اللي ناقصك'**
  String get shoppingBasketEmpty;

  /// Ad button: what one ad gives.
  ///
  /// In ar, this message translates to:
  /// **'شاهد إعلان وخد {reward}'**
  String adWatchFor(String reward);

  /// Under the ad button before the first ad of the day.
  ///
  /// In ar, this message translates to:
  /// **'الإعلان التاني بيزوّد سؤال صوتي، والتالت صورة كمان'**
  String get adLadderFirst;

  /// Under the ad button after the first ad.
  ///
  /// In ar, this message translates to:
  /// **'الإعلان التالت بيدّي صورة كمان'**
  String get adLadderSecond;

  /// Under the ad button from the third ad on.
  ///
  /// In ar, this message translates to:
  /// **'كل إعلان بعد كده = {messages}'**
  String adLadderAfter(String messages);

  /// Ad reward piece: one voice question.
  ///
  /// In ar, this message translates to:
  /// **'سؤال صوتي'**
  String get rewardVoiceOne;

  /// Ad reward piece: several voice questions; n in Arabic digits.
  ///
  /// In ar, this message translates to:
  /// **'{n} أسئلة صوتية'**
  String rewardVoiceMany(String n);

  /// Ad reward piece: one image.
  ///
  /// In ar, this message translates to:
  /// **'صورة'**
  String get rewardImageOne;

  /// Ad reward piece: several images.
  ///
  /// In ar, this message translates to:
  /// **'{n} صور'**
  String rewardImageMany(String n);

  /// Count of chat messages: one.
  ///
  /// In ar, this message translates to:
  /// **'رسالة'**
  String get messagesOne;

  /// Count of chat messages: two.
  ///
  /// In ar, this message translates to:
  /// **'رسالتين'**
  String get messagesTwo;

  /// Count of chat messages: 3 to 10.
  ///
  /// In ar, this message translates to:
  /// **'{n} رسايل'**
  String messagesFew(String n);

  /// Count of chat messages: 11 and up.
  ///
  /// In ar, this message translates to:
  /// **'{n} رسالة'**
  String messagesMany(String n);

  /// Quota sheet row: chat messages.
  ///
  /// In ar, this message translates to:
  /// **'رسايل'**
  String get quotaKindMessages;

  /// Quota sheet row: voice questions.
  ///
  /// In ar, this message translates to:
  /// **'أسئلة صوتية'**
  String get quotaKindVoice;

  /// Quota sheet row: images.
  ///
  /// In ar, this message translates to:
  /// **'صور'**
  String get quotaKindImages;

  /// Quota sheet: what is left of a cycle.
  ///
  /// In ar, this message translates to:
  /// **'{left} من {total}'**
  String quotaOfTotal(String left, String total);

  /// Quota sheet: a scan costs one image.
  ///
  /// In ar, this message translates to:
  /// **'صورة من رصيد الصور'**
  String get quotaScanFromImages;

  /// Live price strip: loading.
  ///
  /// In ar, this message translates to:
  /// **'جاري جلب الأسعار...'**
  String get tickerLoading;

  /// Live price strip: fetch failed, tap to retry.
  ///
  /// In ar, this message translates to:
  /// **'تعذر جلب الأسعار الحية الآن — جرب تاني'**
  String get tickerError;

  /// Live price strip: nothing yet, tap to refresh.
  ///
  /// In ar, this message translates to:
  /// **'لسه مفيش أسعار حية لبلدك — اضغط للتحديث'**
  String get tickerEmpty;

  /// Live price strip: refresh icon (screen reader).
  ///
  /// In ar, this message translates to:
  /// **'تحديث الأسعار'**
  String get tickerRefresh;

  /// Live price strip: button to report a price.
  ///
  /// In ar, this message translates to:
  /// **'ساهم بسعر'**
  String get tickerContribute;

  /// Household screen title.
  ///
  /// In ar, this message translates to:
  /// **'البيت'**
  String get householdTitle;

  /// Household screen: prices button.
  ///
  /// In ar, this message translates to:
  /// **'الأسعار'**
  String get householdPrices;

  /// Household screen: family button.
  ///
  /// In ar, this message translates to:
  /// **'العيلة'**
  String get householdFamily;

  /// Household tab: pantry.
  ///
  /// In ar, this message translates to:
  /// **'المخزن'**
  String get householdPantry;

  /// Household tab: missing items and shopping.
  ///
  /// In ar, this message translates to:
  /// **'نواقص وتسوق'**
  String get householdShopping;

  /// Household tab: pharmacy.
  ///
  /// In ar, this message translates to:
  /// **'الصيدلية'**
  String get householdPharmacy;

  /// Household tab: recipes.
  ///
  /// In ar, this message translates to:
  /// **'وصفات'**
  String get householdRecipes;

  /// Notification center title.
  ///
  /// In ar, this message translates to:
  /// **'الإشعارات'**
  String get notifTitle;

  /// Notification center: unread count.
  ///
  /// In ar, this message translates to:
  /// **'{count} غير مقروء'**
  String notifUnread(int count);

  /// Notification center: speak button.
  ///
  /// In ar, this message translates to:
  /// **'قراءة التنبيهات صوتيًا'**
  String get notifReadAloud;

  /// Notification center: empty title.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد إشعارات حالياً.'**
  String get notifEmptyTitle;

  /// Notification center: empty guidance.
  ///
  /// In ar, this message translates to:
  /// **'هنعلمك أول ما يحصل حاجة تستاهل انتباهك'**
  String get notifEmptyBody;

  /// Notification center section: pending bank transactions.
  ///
  /// In ar, this message translates to:
  /// **'عمليات بنكية بانتظارك'**
  String get notifBankSection;

  /// Notification center section: local insights.
  ///
  /// In ar, this message translates to:
  /// **'تنبيهات ذكاء زاد'**
  String get notifInsightsSection;

  /// Notification center section: brain alerts.
  ///
  /// In ar, this message translates to:
  /// **'تنبيهات عقل زاد'**
  String get notifBrainSection;

  /// Notification center section: app notifications.
  ///
  /// In ar, this message translates to:
  /// **'إشعارات التطبيق'**
  String get notifAppSection;

  /// Insight dismiss reason: not important.
  ///
  /// In ar, this message translates to:
  /// **'مش مهم'**
  String get notifNotImportant;

  /// Insight dismiss reason: wrong number.
  ///
  /// In ar, this message translates to:
  /// **'الرقم غلط'**
  String get notifWrongNumber;

  /// Insight dismiss reason: already known.
  ///
  /// In ar, this message translates to:
  /// **'عرفت خلاص'**
  String get notifAlreadyKnew;

  /// Notification: button to open a product on Amazon.
  ///
  /// In ar, this message translates to:
  /// **'🛒 {name} على أمازون'**
  String notifOnAmazon(String name);

  /// Home bell tooltip.
  ///
  /// In ar, this message translates to:
  /// **'التنبيهات'**
  String get notifBell;

  /// Home bell tooltip with unread count.
  ///
  /// In ar, this message translates to:
  /// **'التنبيهات — {count} مش مقروء'**
  String notifBellUnread(int count);

  /// Shopping: smart fill failed.
  ///
  /// In ar, this message translates to:
  /// **'مقدرتش أوصل لزاد دلوقتي. جرّب تاني.'**
  String get shopNoReach;

  /// Shopping: quick-add field hint.
  ///
  /// In ar, this message translates to:
  /// **'محتاج تشتري إيه؟'**
  String get shopAddHint;

  /// Shopping: quick-add button.
  ///
  /// In ar, this message translates to:
  /// **'ضيف'**
  String get shopAddTooltip;

  /// Shopping: open the add sheet / its title.
  ///
  /// In ar, this message translates to:
  /// **'إضافة منتج للقائمة'**
  String get shopAddProduct;

  /// Shopping: ask Zad to fill the list.
  ///
  /// In ar, this message translates to:
  /// **'تعبئة ذكية'**
  String get shopSmartFill;

  /// Shopping: share the list on WhatsApp.
  ///
  /// In ar, this message translates to:
  /// **'واتساب'**
  String get shopWhatsApp;

  /// Shopping priority: high.
  ///
  /// In ar, this message translates to:
  /// **'حرج'**
  String get shopPriorityHigh;

  /// Shopping priority: medium.
  ///
  /// In ar, this message translates to:
  /// **'متوسط'**
  String get shopPriorityMedium;

  /// Shopping priority: low.
  ///
  /// In ar, this message translates to:
  /// **'منخفض'**
  String get shopPriorityLow;

  /// Shopping: empty title.
  ///
  /// In ar, this message translates to:
  /// **'قائمة التسوق فارغة'**
  String get shopEmptyTitle;

  /// Shopping: empty guidance.
  ///
  /// In ar, this message translates to:
  /// **'زاد سيضيف النواقص تلقائياً!'**
  String get shopEmptyBody;

  /// Shopping: filter has no rows.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد عناصر بهذا التصنيف'**
  String get shopFilterEmptyTitle;

  /// Shopping: filter empty guidance.
  ///
  /// In ar, this message translates to:
  /// **'جرّب أولوية تانية.'**
  String get shopFilterEmptyBody;

  /// Shopping: bought section header.
  ///
  /// In ar, this message translates to:
  /// **'اتشترى'**
  String get shopBought;

  /// Shopping budget header title.
  ///
  /// In ar, this message translates to:
  /// **'سلة زاد الذكية'**
  String get shopBasketTitle;

  /// Shopping budget header: only some lines priced.
  ///
  /// In ar, this message translates to:
  /// **'تقدير لـ {priced} من {lines} صنف — «تعبئة ذكية» تقدّر الباقي'**
  String shopBasketPartial(int priced, int lines);

  /// Shopping budget header: no budget known.
  ///
  /// In ar, this message translates to:
  /// **'الميزانية المتبقية: —'**
  String get shopBudgetLeftUnknown;

  /// Shopping budget header: budget left.
  ///
  /// In ar, this message translates to:
  /// **'الميزانية المتبقية: {amount}'**
  String shopBudgetLeft(String amount);

  /// Shopping budget header: share of budget.
  ///
  /// In ar, this message translates to:
  /// **'{pct}% من الميزانية'**
  String shopBudgetPct(int pct);

  /// Shopping budget header: over budget.
  ///
  /// In ar, this message translates to:
  /// **'هذه القائمة تتجاوز الميزانية المتبقية!'**
  String get shopOverBudget;

  /// Shopping: suggestions title.
  ///
  /// In ar, this message translates to:
  /// **'قد تحتاج أيضاً'**
  String get shopMayNeed;

  /// Shopping: add a suggestion.
  ///
  /// In ar, this message translates to:
  /// **'إضافة للقائمة'**
  String get shopAddToList;

  /// Shopping line: pantry stock is low.
  ///
  /// In ar, this message translates to:
  /// **'في البيت {qty} بس'**
  String shopStockLow(String qty);

  /// Shopping line: pantry has enough.
  ///
  /// In ar, this message translates to:
  /// **'في البيت {qty} — مش ناقص'**
  String shopStockEnough(String qty);

  /// Shopping line: predicted days left.
  ///
  /// In ar, this message translates to:
  /// **'ينفد بعد {days} أيام'**
  String shopRunsOutIn(int days);

  /// Shopping: snackbar after ticking a line.
  ///
  /// In ar, this message translates to:
  /// **'تم شراء {name}'**
  String shopBoughtItem(String name);

  /// Shopping: confirm removing a family of lines.
  ///
  /// In ar, this message translates to:
  /// **'تشيل {name} من القائمة؟'**
  String shopRemoveGroupTitle(String name);

  /// Shopping: confirm body.
  ///
  /// In ar, this message translates to:
  /// **'هيتشالوا {count} سطور مع بعض.'**
  String shopRemoveGroupBody(int count);

  /// Shopping: confirm removing the group.
  ///
  /// In ar, this message translates to:
  /// **'شيلهم'**
  String get shopRemoveThem;

  /// Shopping: a family of lines.
  ///
  /// In ar, this message translates to:
  /// **'{name} · {count} أنواع'**
  String shopGroupKinds(String name, int count);

  /// Shopping: collapse a family.
  ///
  /// In ar, this message translates to:
  /// **'اخفي الأنواع'**
  String get shopHideKinds;

  /// Shopping: expand a family.
  ///
  /// In ar, this message translates to:
  /// **'وريني الأنواع'**
  String get shopShowKinds;

  /// Shopping add sheet: name field.
  ///
  /// In ar, this message translates to:
  /// **'اسم المنتج'**
  String get shopFieldName;

  /// Shopping add sheet: quantity field.
  ///
  /// In ar, this message translates to:
  /// **'الكمية'**
  String get shopFieldQty;

  /// Shopping add sheet: price field.
  ///
  /// In ar, this message translates to:
  /// **'السعر التقديري'**
  String get shopFieldPrice;

  /// Shopping add sheet: store field.
  ///
  /// In ar, this message translates to:
  /// **'المتجر (اختياري)'**
  String get shopFieldStore;

  /// Pantry: empty title.
  ///
  /// In ar, this message translates to:
  /// **'المخزون فارغ'**
  String get pantryEmptyTitle;

  /// Pantry: empty guidance.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ بإضافة منتجات لتنظم مخزون منزلك'**
  String get pantryEmptyBody;

  /// Pantry: scan button on the empty state.
  ///
  /// In ar, this message translates to:
  /// **'تصوير'**
  String get pantryScan;

  /// Pantry: search found nothing.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد نتائج'**
  String get pantrySearchEmptyTitle;

  /// Pantry: search empty guidance.
  ///
  /// In ar, this message translates to:
  /// **'جرّب البحث بكلمة مختلفة'**
  String get pantrySearchEmptyBody;

  /// Pantry: scan FAB.
  ///
  /// In ar, this message translates to:
  /// **'تصوير المخزون'**
  String get pantryScanTooltip;

  /// Pantry: manual add FAB.
  ///
  /// In ar, this message translates to:
  /// **'إضافة يدوية'**
  String get pantryAddManual;

  /// Pantry: low-stock banner.
  ///
  /// In ar, this message translates to:
  /// **'نواقص المخزون ({count})'**
  String pantryLowBanner(int count);

  /// Pantry: low-stock banner suffix.
  ///
  /// In ar, this message translates to:
  /// **' (غير محدد)'**
  String get pantryUnspecified;

  /// Pantry: move a low item to the shopping list.
  ///
  /// In ar, this message translates to:
  /// **'نزّلها في التسوق'**
  String get pantryToShopping;

  /// Pantry: expiring section title.
  ///
  /// In ar, this message translates to:
  /// **'ينتهي قريباً'**
  String get pantryExpiringSoon;

  /// Pantry: ask for a recipe from expiring items.
  ///
  /// In ar, this message translates to:
  /// **'اقتراح وصفة'**
  String get pantrySuggestRecipe;

  /// Pantry: item past its date.
  ///
  /// In ar, this message translates to:
  /// **'منتهي الصلاحية'**
  String get pantryExpired;

  /// Pantry: days until expiry.
  ///
  /// In ar, this message translates to:
  /// **'باقي {days} يوم'**
  String pantryDaysLeft(String days);

  /// Pantry: low-stock tag.
  ///
  /// In ar, this message translates to:
  /// **'منخفض'**
  String get pantryLow;

  /// Pantry: short expired tag.
  ///
  /// In ar, this message translates to:
  /// **'منتهي'**
  String get pantryExpiredShort;

  /// Pantry: days tag.
  ///
  /// In ar, this message translates to:
  /// **'{days} يوم'**
  String pantryDays(int days);

  /// Pantry: decrement.
  ///
  /// In ar, this message translates to:
  /// **'استهلاك واحدة'**
  String get pantryUseOne;

  /// Pantry: increment.
  ///
  /// In ar, this message translates to:
  /// **'زيادة واحدة'**
  String get pantryAddOne;

  /// Pantry: edit an item.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الصنف'**
  String get pantryEditItem;

  /// Pantry: out-of-stock tag.
  ///
  /// In ar, this message translates to:
  /// **'خلص'**
  String get pantryOut;

  /// Pantry: kinds in a family.
  ///
  /// In ar, this message translates to:
  /// **'{count} أنواع'**
  String pantryKinds(int count);

  /// Pantry: expand a family.
  ///
  /// In ar, this message translates to:
  /// **'اعرض الأنواع'**
  String get pantryShowKinds;

  /// Pantry family: decrement.
  ///
  /// In ar, this message translates to:
  /// **'استهلكت واحدة'**
  String get pantryUsedOne;

  /// Pantry family: increment.
  ///
  /// In ar, this message translates to:
  /// **'زوّد واحدة'**
  String get pantryIncreaseOne;

  /// Pantry shortage card: quantity.
  ///
  /// In ar, this message translates to:
  /// **'الكمية: {qty}'**
  String pantryQty(String qty);

  /// Pantry shortage card: added to shopping.
  ///
  /// In ar, this message translates to:
  /// **'أُضيفت'**
  String get pantryAdded;

  /// Pantry add dialog title.
  ///
  /// In ar, this message translates to:
  /// **'إضافة منتج جديد'**
  String get pantryAddTitle;

  /// Pantry add dialog: close.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق'**
  String get pantryClose;

  /// Pantry add dialog: name hint.
  ///
  /// In ar, this message translates to:
  /// **'مثلاً: حليب'**
  String get pantryNameHint;

  /// Pantry dialogs: unit field.
  ///
  /// In ar, this message translates to:
  /// **'الوحدة'**
  String get pantryUnit;

  /// Pantry add dialog: category field.
  ///
  /// In ar, this message translates to:
  /// **'القسم'**
  String get pantryCategory;

  /// Pantry add dialog: expiry field.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الصلاحية (اختياري)'**
  String get pantryExpiryField;

  /// Pantry edit: occasional purchase switch.
  ///
  /// In ar, this message translates to:
  /// **'بشتريها على فترات'**
  String get pantryOccasional;

  /// Pantry edit: occasional switch explained.
  ///
  /// In ar, this message translates to:
  /// **'مش هتتحسب ناقصة لما تخلص، ومش هفكّرك بيها'**
  String get pantryOccasionalBody;

  /// Pantry add/edit: the expiry field when no date is set; tapping opens the calendar.
  ///
  /// In ar, this message translates to:
  /// **'اختار التاريخ'**
  String get pantryExpiryPick;

  /// Pantry add: the guessed expiry from the item kind, shown as an estimate, never as a fact.
  ///
  /// In ar, this message translates to:
  /// **'تقديري: {date}'**
  String pantryExpiryEstimate(String date);

  /// Pantry add: under the estimate — it is saved unless changed.
  ///
  /// In ar, this message translates to:
  /// **'لو سبته كده هحفظ التاريخ التقديري، غيّره لو عارف التاريخ الحقيقي'**
  String get pantryExpiryEstimateNote;

  /// Pantry add/edit: quick chip, expires in three days.
  ///
  /// In ar, this message translates to:
  /// **'٣ أيام'**
  String get pantryExpiryIn3Days;

  /// Pantry add/edit: quick chip, expires in a week.
  ///
  /// In ar, this message translates to:
  /// **'أسبوع'**
  String get pantryExpiryInWeek;

  /// Pantry add/edit: quick chip, expires in a month.
  ///
  /// In ar, this message translates to:
  /// **'شهر'**
  String get pantryExpiryInMonth;

  /// Pantry add/edit: tooltip of the × that removes the expiry date.
  ///
  /// In ar, this message translates to:
  /// **'امسح التاريخ'**
  String get pantryExpiryClear;

  /// Notification center: spoken when there is nothing new.
  ///
  /// In ar, this message translates to:
  /// **'مفيش تنبيهات جديدة'**
  String get notifNoneNew;

  /// Introduce-yourself screen: title.
  ///
  /// In ar, this message translates to:
  /// **'عرّفني بيك'**
  String get introTitle;

  /// Introduce-yourself: lead line.
  ///
  /// In ar, this message translates to:
  /// **'خمس أسئلة وسؤال اختياري، عشان أكلمك صح وآخد بالي من اللي في رعايتك.'**
  String get introLead;

  /// Introduce-yourself: name question.
  ///
  /// In ar, this message translates to:
  /// **'أناديك بإيه؟'**
  String get introNameQuestion;

  /// Introduce-yourself: name hint.
  ///
  /// In ar, this message translates to:
  /// **'اسمك أو اسم الدلع'**
  String get introNameHint;

  /// Introduce-yourself: gender question.
  ///
  /// In ar, this message translates to:
  /// **'أكلمك بصيغة إيه؟'**
  String get introGenderQuestion;

  /// Gender chip.
  ///
  /// In ar, this message translates to:
  /// **'راجل'**
  String get introGenderMale;

  /// Gender chip.
  ///
  /// In ar, this message translates to:
  /// **'ست'**
  String get introGenderFemale;

  /// Introduce-yourself: role question.
  ///
  /// In ar, this message translates to:
  /// **'إنت مين في البيت؟'**
  String get introRoleQuestion;

  /// Role chip (stored as father).
  ///
  /// In ar, this message translates to:
  /// **'أب'**
  String get introRoleFather;

  /// Role chip (stored as mother).
  ///
  /// In ar, this message translates to:
  /// **'أم'**
  String get introRoleMother;

  /// Role chip.
  ///
  /// In ar, this message translates to:
  /// **'زوج'**
  String get introRoleHusband;

  /// Role chip.
  ///
  /// In ar, this message translates to:
  /// **'زوجة'**
  String get introRoleWife;

  /// Role chip.
  ///
  /// In ar, this message translates to:
  /// **'ابن'**
  String get introRoleSon;

  /// Role chip.
  ///
  /// In ar, this message translates to:
  /// **'بنت'**
  String get introRoleDaughter;

  /// Role chip (stored as single).
  ///
  /// In ar, this message translates to:
  /// **'عايش لوحدي'**
  String get introRoleSingle;

  /// Role chip.
  ///
  /// In ar, this message translates to:
  /// **'طالب'**
  String get introRoleStudent;

  /// Role chip.
  ///
  /// In ar, this message translates to:
  /// **'جد/جدة'**
  String get introRoleGrandparent;

  /// Role chip (stored as other).
  ///
  /// In ar, this message translates to:
  /// **'غير كده'**
  String get introRoleOther;

  /// Introduce-yourself: cares-for question.
  ///
  /// In ar, this message translates to:
  /// **'مين في رعايتك؟'**
  String get introCaresQuestion;

  /// Cares-for hint.
  ///
  /// In ar, this message translates to:
  /// **'اختار كل اللي ينطبق.'**
  String get introCaresHint;

  /// Cares-for chip (stored as children).
  ///
  /// In ar, this message translates to:
  /// **'أولادي'**
  String get introCaresChildren;

  /// Cares-for chip.
  ///
  /// In ar, this message translates to:
  /// **'أبويا أو أمي'**
  String get introCaresParents;

  /// Cares-for chip.
  ///
  /// In ar, this message translates to:
  /// **'زوجي أو زوجتي'**
  String get introCaresSpouse;

  /// Cares-for chip.
  ///
  /// In ar, this message translates to:
  /// **'إخواتي'**
  String get introCaresSiblings;

  /// Cares-for chip.
  ///
  /// In ar, this message translates to:
  /// **'جدي أو جدتي'**
  String get introCaresGrandparents;

  /// Cares-for: the empty answer.
  ///
  /// In ar, this message translates to:
  /// **'محدش — مسؤول عن نفسي بس'**
  String get introCaresNobody;

  /// Introduce-yourself: household size (zad_customer_profile.household_size).
  ///
  /// In ar, this message translates to:
  /// **'كام واحد عايش في البيت؟'**
  String get introHouseholdQuestion;

  /// Household size hint.
  ///
  /// In ar, this message translates to:
  /// **'معاك إنت. عشان أحسب استهلاك البيت صح.'**
  String get introHouseholdHint;

  /// Household size chip: seven and up (stored as 7).
  ///
  /// In ar, this message translates to:
  /// **'7 أو أكتر'**
  String get introHouseholdMany;

  /// Introduce-yourself: pay day.
  ///
  /// In ar, this message translates to:
  /// **'بتقبض يوم كام في الشهر؟'**
  String get introPayDayQuestion;

  /// Pay day hint.
  ///
  /// In ar, this message translates to:
  /// **'اختياري — عشان أحسب شهرك من يوم القبض.'**
  String get introPayDayHint;

  /// Pay day: no answer.
  ///
  /// In ar, this message translates to:
  /// **'مش ثابت / مش عايز أقول'**
  String get introPayDayNone;

  /// Pay day option.
  ///
  /// In ar, this message translates to:
  /// **'يوم {day}'**
  String introPayDay(int day);

  /// Introduce-yourself: save button.
  ///
  /// In ar, this message translates to:
  /// **'يلا بينا'**
  String get introSave;

  /// Introduce-yourself: save failed.
  ///
  /// In ar, this message translates to:
  /// **'مقدرتش أحفظ — اتأكد من النت وجرّب تاني.'**
  String get introSaveFailed;

  /// First-steps screen title.
  ///
  /// In ar, this message translates to:
  /// **'أول خطوة'**
  String get firstStepsTitle;

  /// First steps: lead.
  ///
  /// In ar, this message translates to:
  /// **'تلات خطوات في دقيقتين، وزاد يبدأ يشتغل معاك من النهارده.'**
  String get firstStepsLead;

  /// First steps: step 1.
  ///
  /// In ar, this message translates to:
  /// **'سجّل أول مصروف'**
  String get firstStepsSpendTitle;

  /// First steps: step 1 body.
  ///
  /// In ar, this message translates to:
  /// **'أي حاجة صرفتها النهارده — قهوة، مواصلات، عيش. من هنا زاد بيبدأ يفهم شهرك.'**
  String get firstStepsSpendBody;

  /// First steps: step 1 done.
  ///
  /// In ar, this message translates to:
  /// **'اتسجل ✓'**
  String get firstStepsSpendDone;

  /// First steps: step 1 button.
  ///
  /// In ar, this message translates to:
  /// **'سجّل مصروف'**
  String get firstStepsSpendAction;

  /// First steps: step 2.
  ///
  /// In ar, this message translates to:
  /// **'فعّل الإشعارات'**
  String get firstStepsAlertsTitle;

  /// First steps: step 2 body.
  ///
  /// In ar, this message translates to:
  /// **'عشان أقولك لما الميزانية تقرب تخلص، وتوصلك مواعيد الدوا والفواتير في وقتها.'**
  String get firstStepsAlertsBody;

  /// First steps: step 2 done.
  ///
  /// In ar, this message translates to:
  /// **'متفعّلة ✓'**
  String get firstStepsAlertsDone;

  /// First steps: step 2 button.
  ///
  /// In ar, this message translates to:
  /// **'فعّل'**
  String get firstStepsAlertsAction;

  /// First steps: step 3.
  ///
  /// In ar, this message translates to:
  /// **'اربط بوت تليجرام'**
  String get firstStepsTelegramTitle;

  /// First steps: step 3 body.
  ///
  /// In ar, this message translates to:
  /// **'من غيره التذكيرات وسؤال «اقفل يومك» مش هتوصلك وانت برّه التطبيق.'**
  String get firstStepsTelegramBody;

  /// First steps: all done.
  ///
  /// In ar, this message translates to:
  /// **'يلا على زاد'**
  String get firstStepsGo;

  /// First steps: skip.
  ///
  /// In ar, this message translates to:
  /// **'كمّل بعدين — افتح زاد'**
  String get firstStepsLater;

  /// Companion lines, one per row: hungry.
  ///
  /// In ar, this message translates to:
  /// **'بطني بتصوصو… تأكّلني؟ 🍎\nجعان أوي 🥺 حاجة صغيرة بس\nشامم ريحة أكل؟ لأ ده أنا اللي جعان 😅'**
  String get petLinesHungry;

  /// Companion lines: thirsty.
  ///
  /// In ar, this message translates to:
  /// **'عطشان… شوية مية؟ 💧\nريقي ناشف 🥵 اسقيني\nكوباية مية واحدة وأبقى زي الفل 💧'**
  String get petLinesThirsty;

  /// Companion lines: sleepy.
  ///
  /// In ar, this message translates to:
  /// **'نعسان… 😴 تصبح على خير\nهاااه 🥱 نكمّل بكرة؟\nعيني بتقفل لوحدها… 💤'**
  String get petLinesSleepy;

  /// Companion lines: sad.
  ///
  /// In ar, this message translates to:
  /// **'وحشتني… ونسيت أكلي وميتي 🥺\n{name} زعلان شوية… تعالى نقعد سوا 💔'**
  String petLinesSad(String name);

  /// Companion lines: happy.
  ///
  /// In ar, this message translates to:
  /// **'أنا مبسوط معاك 💚\nشكراً إنك فاكرني 🥰\nإنت أحلى صاحب 🤗'**
  String get petLinesHappy;

  /// Companion lines: idle, logged today.
  ///
  /// In ar, this message translates to:
  /// **'يومك عامل إيه؟ ✨\nأنا هنا لو احتجتني 💚\nسجّلت النهارده — برافو عليك 👏'**
  String get petLinesIdleLogged;

  /// Companion lines: idle, nothing logged.
  ///
  /// In ar, this message translates to:
  /// **'سجّلت مصروفاتك النهارده؟ 📝\nمصروف واحد بس وأفرح بيك 🌱'**
  String get petLinesIdleNotLogged;

  /// Companion lines: after a meal.
  ///
  /// In ar, this message translates to:
  /// **'يمّ يمّ! 😋\nتسلم إيدك 🍎\nأحلى أكلة 🤤'**
  String get petLinesFed;

  /// Companion lines: fed while full.
  ///
  /// In ar, this message translates to:
  /// **'شبعان خلاص 🤭\nمش قادر آكل تاني 😅'**
  String get petLinesFull;

  /// Companion lines: after a drink.
  ///
  /// In ar, this message translates to:
  /// **'آآه انتعشت! 💧\nكده أحسن بكتير 😌'**
  String get petLinesWatered;

  /// Companion lines: watered while not thirsty.
  ///
  /// In ar, this message translates to:
  /// **'مش عايز مية دلوقتي 🙈\nشربت كفاية 😄'**
  String get petLinesNotThirsty;

  /// Companion lines: after a pat.
  ///
  /// In ar, this message translates to:
  /// **'هيهي بتزغزغني 🤭\nكمان! كمان! 🥰\nبحبك 💚'**
  String get petLinesPetted;
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
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'ar':
      {
        switch (locale.countryCode) {
          case 'SA':
            return ZadL10nArSa();
        }
        break;
      }
  }

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
