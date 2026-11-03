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
  /// **'المتاجر والأسواق القريبة'**
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
  /// **'خلصت أسئلتك الصوتية النهارده (٣ في اليوم) — بترجع بكرة. اكتب سؤالك، أو اشترك وكلّم زاد من غير حد.'**
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
  /// **'خلصت أسئلتك الصوتية النهارده — ٣ في اليوم، وبترجع بكرة'**
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
  /// **'قبل ما نبدأ، حدد سقفك الشهري'**
  String get gateTitle;

  /// No description provided for @gateBody.
  ///
  /// In ar, this message translates to:
  /// **'زاد ما بيخترعش أرقام. من غير السقف مفيش \"متبقي\" ولا \"متاح\" — وكل رقم هتشوفه هيبقى تخمين.'**
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
  /// **'سقف الصرف الشهري'**
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

  /// Action log: what Zad did, for the tool log_transaction.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل معاملة'**
  String get agentToolLogTransaction;

  /// Action log: what Zad did, for the tool update_transaction.
  ///
  /// In ar, this message translates to:
  /// **'تعديل معاملة'**
  String get agentToolUpdateTransaction;

  /// Action log: what Zad did, for the tool delete_transaction.
  ///
  /// In ar, this message translates to:
  /// **'حذف معاملة'**
  String get agentToolDeleteTransaction;

  /// Action log: what Zad did, for the tool set_transaction_category.
  ///
  /// In ar, this message translates to:
  /// **'تصنيف معاملة'**
  String get agentToolSetTransactionCategory;

  /// Action log: what Zad did, for the tool merge_duplicate_expense.
  ///
  /// In ar, this message translates to:
  /// **'دمج معاملة مكررة'**
  String get agentToolMergeDuplicateExpense;

  /// Action log: what Zad did, for the tool reconcile_cash_balance.
  ///
  /// In ar, this message translates to:
  /// **'تسوية الكاش'**
  String get agentToolReconcileCashBalance;

  /// Action log: what Zad did, for the tool parse_notification_payload.
  ///
  /// In ar, this message translates to:
  /// **'قراءة رسالة بنك'**
  String get agentToolParseNotificationPayload;

  /// Action log: what Zad did, for the tool set_monthly_limit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل سقف الميزانية'**
  String get agentToolSetMonthlyLimit;

  /// Action log: what Zad did, for the tool confirm_cycle_start.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد دورة الراتب'**
  String get agentToolConfirmCycleStart;

  /// Action log: what Zad did, for the tool set_market.
  ///
  /// In ar, this message translates to:
  /// **'تعديل البلد والعملة'**
  String get agentToolSetMarket;

  /// Action log: what Zad did, for the tool add_obligation.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل التزام'**
  String get agentToolAddObligation;

  /// Action log: what Zad did, for the tool confirm_obligation.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد التزام'**
  String get agentToolConfirmObligation;

  /// Action log: what Zad did, for the tool update_obligation.
  ///
  /// In ar, this message translates to:
  /// **'تعديل التزام'**
  String get agentToolUpdateObligation;

  /// Action log: what Zad did, for the tool delete_obligation.
  ///
  /// In ar, this message translates to:
  /// **'حذف التزام'**
  String get agentToolDeleteObligation;

  /// Action log: what Zad did, for the tool add_subscription.
  ///
  /// In ar, this message translates to:
  /// **'إضافة اشتراك'**
  String get agentToolAddSubscription;

  /// Action log: what Zad did, for the tool update_subscription.
  ///
  /// In ar, this message translates to:
  /// **'تعديل اشتراك'**
  String get agentToolUpdateSubscription;

  /// Action log: what Zad did, for the tool delete_subscription.
  ///
  /// In ar, this message translates to:
  /// **'حذف اشتراك'**
  String get agentToolDeleteSubscription;

  /// Action log: what Zad did, for the tool add_debt.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل دين'**
  String get agentToolAddDebt;

  /// Action log: what Zad did, for the tool update_debt.
  ///
  /// In ar, this message translates to:
  /// **'تعديل دين'**
  String get agentToolUpdateDebt;

  /// Action log: what Zad did, for the tool delete_debt.
  ///
  /// In ar, this message translates to:
  /// **'حذف دين'**
  String get agentToolDeleteDebt;

  /// Action log: what Zad did, for the tool add_inventory_item.
  ///
  /// In ar, this message translates to:
  /// **'إضافة صنف للمخزون'**
  String get agentToolAddInventoryItem;

  /// Action log: what Zad did, for the tool update_inventory_qty.
  ///
  /// In ar, this message translates to:
  /// **'تعديل كمية مخزون'**
  String get agentToolUpdateInventoryQty;

  /// Action log: what Zad did, for the tool delete_inventory_item.
  ///
  /// In ar, this message translates to:
  /// **'حذف صنف من المخزون'**
  String get agentToolDeleteInventoryItem;

  /// Action log: what Zad did, for the tool add_shopping_item.
  ///
  /// In ar, this message translates to:
  /// **'إضافة لقايمة المشتريات'**
  String get agentToolAddShoppingItem;

  /// Action log: what Zad did, for the tool complete_shopping_item.
  ///
  /// In ar, this message translates to:
  /// **'شطب من قايمة المشتريات'**
  String get agentToolCompleteShoppingItem;

  /// Action log: what Zad did, for the tool delete_shopping_item.
  ///
  /// In ar, this message translates to:
  /// **'حذف من قايمة المشتريات'**
  String get agentToolDeleteShoppingItem;

  /// Action log: what Zad did, for the tool add_pharmacy_item.
  ///
  /// In ar, this message translates to:
  /// **'إضافة دواء'**
  String get agentToolAddPharmacyItem;

  /// Action log: what Zad did, for the tool update_pharmacy_item.
  ///
  /// In ar, this message translates to:
  /// **'تعديل دواء'**
  String get agentToolUpdatePharmacyItem;

  /// Action log: what Zad did, for the tool delete_pharmacy_item.
  ///
  /// In ar, this message translates to:
  /// **'حذف دواء'**
  String get agentToolDeletePharmacyItem;

  /// Action log: what Zad did, for the tool log_pharmacy_dose.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل جرعة دواء'**
  String get agentToolLogPharmacyDose;

  /// Action log: what Zad did, for the tool add_maintenance_item.
  ///
  /// In ar, this message translates to:
  /// **'إضافة جهاز للصيانة'**
  String get agentToolAddMaintenanceItem;

  /// Action log: what Zad did, for the tool update_maintenance_item.
  ///
  /// In ar, this message translates to:
  /// **'تعديل جهاز'**
  String get agentToolUpdateMaintenanceItem;

  /// Action log: what Zad did, for the tool delete_maintenance_item.
  ///
  /// In ar, this message translates to:
  /// **'حذف جهاز'**
  String get agentToolDeleteMaintenanceItem;

  /// Action log: what Zad did, for the tool save_document.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل مستند'**
  String get agentToolSaveDocument;

  /// Action log: what Zad did, for the tool delete_document.
  ///
  /// In ar, this message translates to:
  /// **'شيل مستند'**
  String get agentToolDeleteDocument;

  /// Action log: what Zad did, for the tool add_gathering_to_list.
  ///
  /// In ar, this message translates to:
  /// **'سطور عزومة للقايمة'**
  String get agentToolAddGatheringToList;

  /// Action log: what Zad did, for the tool add_appointment.
  ///
  /// In ar, this message translates to:
  /// **'إضافة ميعاد'**
  String get agentToolAddAppointment;

  /// Action log: what Zad did, for the tool update_appointment.
  ///
  /// In ar, this message translates to:
  /// **'تعديل ميعاد'**
  String get agentToolUpdateAppointment;

  /// Action log: what Zad did, for the tool add_place_reminder.
  ///
  /// In ar, this message translates to:
  /// **'تذكير عند مكان'**
  String get agentToolAddPlaceReminder;

  /// Action log: what Zad did, for the tool cancel_place_reminder.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء تذكير مكان'**
  String get agentToolCancelPlaceReminder;

  /// Action log: what Zad did, for the tool schedule_task.
  ///
  /// In ar, this message translates to:
  /// **'جدولة تذكير'**
  String get agentToolScheduleTask;

  /// Action log: what Zad did, for the tool remember.
  ///
  /// In ar, this message translates to:
  /// **'حفظ ملاحظة عنك'**
  String get agentToolRemember;

  /// Action log: what Zad did, for the tool link_memory.
  ///
  /// In ar, this message translates to:
  /// **'ربط ملاحظات'**
  String get agentToolLinkMemory;

  /// Action log: what Zad did, for the tool update_customer_profile.
  ///
  /// In ar, this message translates to:
  /// **'تحديث ملفك'**
  String get agentToolUpdateCustomerProfile;

  /// Action log: what Zad did, for the tool set_life_goal.
  ///
  /// In ar, this message translates to:
  /// **'هدف جديد'**
  String get agentToolSetLifeGoal;

  /// Action log: what Zad did, for the tool set_broke_mode.
  ///
  /// In ar, this message translates to:
  /// **'وضع التقشف'**
  String get agentToolSetBrokeMode;

  /// Action log: what Zad did, for the tool start_savings_challenge.
  ///
  /// In ar, this message translates to:
  /// **'بدء تحدي توفير'**
  String get agentToolStartSavingsChallenge;

  /// Action log: what Zad did, for the tool stop_savings_challenge.
  ///
  /// In ar, this message translates to:
  /// **'إيقاف تحدي توفير'**
  String get agentToolStopSavingsChallenge;

  /// Action log: what Zad did, for the tool update_emergency_fund_balance.
  ///
  /// In ar, this message translates to:
  /// **'تحديث صندوق الطوارئ'**
  String get agentToolUpdateEmergencyFundBalance;

  /// Action log: what Zad did, for the tool allocate_income.
  ///
  /// In ar, this message translates to:
  /// **'توزيع الدخل'**
  String get agentToolAllocateIncome;

  /// Action log: what Zad did, for the tool set_sleep_window.
  ///
  /// In ar, this message translates to:
  /// **'مواعيد نومك'**
  String get agentToolSetSleepWindow;

  /// Action log: what Zad did, for the tool learn_skill.
  ///
  /// In ar, this message translates to:
  /// **'تعلّم مهارة'**
  String get agentToolLearnSkill;

  /// Action log: what Zad did, for the tool save_trusted_technician.
  ///
  /// In ar, this message translates to:
  /// **'حفظ صنايعي'**
  String get agentToolSaveTrustedTechnician;

  /// Action log: what Zad did, for the tool open_support_ticket.
  ///
  /// In ar, this message translates to:
  /// **'فتح طلب دعم'**
  String get agentToolOpenSupportTicket;

  /// Action log: what Zad did, for the tool answer_same_product.
  ///
  /// In ar, this message translates to:
  /// **'مطابقة منتج'**
  String get agentToolAnswerSameProduct;

  /// Action log: a tool with no label of its own.
  ///
  /// In ar, this message translates to:
  /// **'تعديل من زاد'**
  String get agentToolOther;

  /// Action log: which door the turn came in by (app_chat).
  ///
  /// In ar, this message translates to:
  /// **'شات التطبيق'**
  String get agentSourceAppChat;

  /// Action log: which door the turn came in by (telegram).
  ///
  /// In ar, this message translates to:
  /// **'تليجرام'**
  String get agentSourceTelegram;

  /// Action log: which door the turn came in by (voice).
  ///
  /// In ar, this message translates to:
  /// **'رسالة صوتية'**
  String get agentSourceVoice;

  /// Action log: which door the turn came in by (confirm).
  ///
  /// In ar, this message translates to:
  /// **'بتأكيد منك'**
  String get agentSourceConfirm;

  /// Action log: which door the turn came in by (daily).
  ///
  /// In ar, this message translates to:
  /// **'مراجعة يومية'**
  String get agentSourceDaily;

  /// Action log: which door the turn came in by (event).
  ///
  /// In ar, this message translates to:
  /// **'حدث تلقائي'**
  String get agentSourceEvent;

  /// Action log: an unknown source.
  ///
  /// In ar, this message translates to:
  /// **'زاد'**
  String get agentSourceOther;

  /// Action log: why an undo did not happen.
  ///
  /// In ar, this message translates to:
  /// **'فيه تعديل أحدث على نفس الحاجة — ارجع فيه هو الأول'**
  String get undoFailureNewerActionExists;

  /// Action log: why an undo did not happen.
  ///
  /// In ar, this message translates to:
  /// **'ده اترجع فيه قبل كده'**
  String get undoFailureAlreadyUndone;

  /// Action log: why an undo did not happen.
  ///
  /// In ar, this message translates to:
  /// **'ده ماتنفذش أصلاً، فمفيش حاجة ترجع فيها'**
  String get undoFailureNeverApplied;

  /// Action log: why an undo did not happen.
  ///
  /// In ar, this message translates to:
  /// **'ده مينفعش يترجع فيه'**
  String get undoFailureNotUndoable;

  /// Action log: why an undo did not happen.
  ///
  /// In ar, this message translates to:
  /// **'الحاجة دي اتمسحت أو مش موجودة دلوقتي'**
  String get undoFailureTargetMissing;

  /// Action log: why an undo did not happen.
  ///
  /// In ar, this message translates to:
  /// **'فيه مشكلة في الدخول — اطلع وادخل تاني'**
  String get undoFailureNotAllowed;

  /// Action log: why an undo did not happen.
  ///
  /// In ar, this message translates to:
  /// **'مفيش اتصال دلوقتي — جرب لما النت يرجع'**
  String get undoFailureOffline;

  /// Action log: why an undo did not happen.
  ///
  /// In ar, this message translates to:
  /// **'معرفتش أرجع فيه، جرب تاني'**
  String get undoFailureUnknown;

  /// Action log: confirm dialog title before an undo.
  ///
  /// In ar, this message translates to:
  /// **'ترجع في «{tool}»؟'**
  String actionLogUndoAsk(String tool);

  /// Action log: confirm dialog body before an undo.
  ///
  /// In ar, this message translates to:
  /// **'زاد هيرجّع الحاجة دي زي ما كانت قبل التعديل. مش هتقدر ترجع في الرجوع ده بعدين.'**
  String get actionLogUndoWarning;

  /// Action log: cancel the undo.
  ///
  /// In ar, this message translates to:
  /// **'استنى'**
  String get actionLogWait;

  /// Action log: the undo button and confirm.
  ///
  /// In ar, this message translates to:
  /// **'ارجع فيه'**
  String get actionLogUndo;

  /// Action log: snackbar after an undo.
  ///
  /// In ar, this message translates to:
  /// **'رجعت في «{tool}»'**
  String actionLogUndone(String tool);

  /// Action log: screen title.
  ///
  /// In ar, this message translates to:
  /// **'سجل تعديلات زاد'**
  String get actionLogTitle;

  /// Action log: empty state when loading failed.
  ///
  /// In ar, this message translates to:
  /// **'مقدرتش أجيب السجل'**
  String get actionLogLoadFailed;

  /// Action log: empty state title.
  ///
  /// In ar, this message translates to:
  /// **'لسه مفيش تعديلات'**
  String get actionLogEmptyTitle;

  /// Action log: empty state after a failure.
  ///
  /// In ar, this message translates to:
  /// **'اسحب لتحت نجرب تاني.'**
  String get actionLogPullRetry;

  /// Action log: empty state guidance.
  ///
  /// In ar, this message translates to:
  /// **'أي حاجة زاد يسجّلها أو يعدّلها لك هتظهر هنا.'**
  String get actionLogEmptyBody;

  /// Action log: status chip, the action ran.
  ///
  /// In ar, this message translates to:
  /// **'اتنفذ'**
  String get actionLogApplied;

  /// Action log: status chip, the action was taken back.
  ///
  /// In ar, this message translates to:
  /// **'اترجع فيه'**
  String get actionLogUndoneStatus;

  /// Action log: status chip, the action was refused.
  ///
  /// In ar, this message translates to:
  /// **'اترفض'**
  String get actionLogRejected;

  /// Why-changed sheet: the name of a changed field (amount).
  ///
  /// In ar, this message translates to:
  /// **'المبلغ'**
  String get mutationFieldAmount;

  /// Why-changed sheet: the name of a changed field (quantity).
  ///
  /// In ar, this message translates to:
  /// **'الكمية'**
  String get mutationFieldQuantity;

  /// Why-changed sheet: the name of a changed field (remaining_quantity).
  ///
  /// In ar, this message translates to:
  /// **'الكمية المتبقية'**
  String get mutationFieldRemainingQuantity;

  /// Why-changed sheet: the name of a changed field (remaining_balance).
  ///
  /// In ar, this message translates to:
  /// **'المتبقي'**
  String get mutationFieldRemainingBalance;

  /// Why-changed sheet: the name of a changed field (price).
  ///
  /// In ar, this message translates to:
  /// **'السعر'**
  String get mutationFieldPrice;

  /// Why-changed sheet: the name of a changed field (unit).
  ///
  /// In ar, this message translates to:
  /// **'الوحدة'**
  String get mutationFieldUnit;

  /// Why-changed sheet: the name of a changed field (category).
  ///
  /// In ar, this message translates to:
  /// **'الفئة'**
  String get mutationFieldCategory;

  /// Why-changed sheet: the name of a changed field (kind).
  ///
  /// In ar, this message translates to:
  /// **'النوع'**
  String get mutationFieldKind;

  /// Why-changed sheet: the name of a changed field (status).
  ///
  /// In ar, this message translates to:
  /// **'الحالة'**
  String get mutationFieldStatus;

  /// Why-changed sheet: the name of a changed field (starts_at).
  ///
  /// In ar, this message translates to:
  /// **'الميعاد'**
  String get mutationFieldStartsAt;

  /// Why-changed sheet: the name of a changed field (task_description).
  ///
  /// In ar, this message translates to:
  /// **'التذكير'**
  String get mutationFieldTaskDescription;

  /// Why-changed sheet: the name of a changed field (recurrence).
  ///
  /// In ar, this message translates to:
  /// **'التكرار'**
  String get mutationFieldRecurrence;

  /// Why-changed sheet: the name of a changed field (dosage).
  ///
  /// In ar, this message translates to:
  /// **'الجرعة'**
  String get mutationFieldDosage;

  /// Why-changed sheet: the name of a changed field (dose_times).
  ///
  /// In ar, this message translates to:
  /// **'مواعيد الجرعات'**
  String get mutationFieldDoseTimes;

  /// Why-changed sheet: the name of a changed field (daily_dose_count).
  ///
  /// In ar, this message translates to:
  /// **'جرعات اليوم'**
  String get mutationFieldDailyDoseCount;

  /// Why-changed sheet: the name of a changed field (expiry_date).
  ///
  /// In ar, this message translates to:
  /// **'الصلاحية'**
  String get mutationFieldExpiryDate;

  /// Why-changed sheet: the name of a changed field (renewal_date).
  ///
  /// In ar, this message translates to:
  /// **'التجديد'**
  String get mutationFieldRenewalDate;

  /// Why-changed sheet: the name of a changed field (due_day).
  ///
  /// In ar, this message translates to:
  /// **'يوم الاستحقاق'**
  String get mutationFieldDueDay;

  /// Why-changed sheet: the name of a changed field (billing_cycle).
  ///
  /// In ar, this message translates to:
  /// **'الدورة'**
  String get mutationFieldBillingCycle;

  /// Why-changed sheet: the name of a changed field (is_active).
  ///
  /// In ar, this message translates to:
  /// **'شغّال'**
  String get mutationFieldIsActive;

  /// Why-changed sheet: the name of a changed field (for_person).
  ///
  /// In ar, this message translates to:
  /// **'لمين'**
  String get mutationFieldForPerson;

  /// Why-changed sheet: the name of a changed field (place).
  ///
  /// In ar, this message translates to:
  /// **'المكان'**
  String get mutationFieldPlace;

  /// Why-changed sheet: the name of a changed field (note).
  ///
  /// In ar, this message translates to:
  /// **'ملاحظة'**
  String get mutationFieldNote;

  /// Why-changed sheet: the name of a changed field (notes).
  ///
  /// In ar, this message translates to:
  /// **'ملاحظات'**
  String get mutationFieldNotes;

  /// Why-changed sheet: the name of a changed field (expected_cost).
  ///
  /// In ar, this message translates to:
  /// **'التكلفة المتوقعة'**
  String get mutationFieldExpectedCost;

  /// Why-changed sheet: the name of a changed field (currency).
  ///
  /// In ar, this message translates to:
  /// **'العملة'**
  String get mutationFieldCurrency;

  /// Why-changed sheet: the name of a changed field (country).
  ///
  /// In ar, this message translates to:
  /// **'البلد'**
  String get mutationFieldCountry;

  /// Why-changed sheet: the name of a changed field (pay_day).
  ///
  /// In ar, this message translates to:
  /// **'يوم القبض'**
  String get mutationFieldPayDay;

  /// Why-changed sheet: the name of a changed field (bed).
  ///
  /// In ar, this message translates to:
  /// **'النوم'**
  String get mutationFieldBed;

  /// Why-changed sheet: the name of a changed field (wake).
  ///
  /// In ar, this message translates to:
  /// **'الصحيان'**
  String get mutationFieldWake;

  /// Why-changed sheet: the name of a changed field (daily_cap).
  ///
  /// In ar, this message translates to:
  /// **'سقف اليوم'**
  String get mutationFieldDailyCap;

  /// Why-changed sheet: the name of a changed field (length_days).
  ///
  /// In ar, this message translates to:
  /// **'المدة بالأيام'**
  String get mutationFieldLengthDays;

  /// Why-changed sheet: the name of a changed field (trade).
  ///
  /// In ar, this message translates to:
  /// **'الصنعة'**
  String get mutationFieldTrade;

  /// Why-changed sheet: the name of a changed field (metric).
  ///
  /// In ar, this message translates to:
  /// **'المقياس'**
  String get mutationFieldMetric;

  /// Why-changed sheet: a status value (upcoming).
  ///
  /// In ar, this message translates to:
  /// **'جاي'**
  String get mutationStatusUpcoming;

  /// Why-changed sheet: a status value (done).
  ///
  /// In ar, this message translates to:
  /// **'خلص'**
  String get mutationStatusDone;

  /// Why-changed sheet: a status value (cancelled).
  ///
  /// In ar, this message translates to:
  /// **'اتلغى'**
  String get mutationStatusCancelled;

  /// Why-changed sheet: a status value (active).
  ///
  /// In ar, this message translates to:
  /// **'شغّال'**
  String get mutationStatusActive;

  /// Why-changed sheet: a status value (abandoned).
  ///
  /// In ar, this message translates to:
  /// **'اتوقف'**
  String get mutationStatusAbandoned;

  /// Why-changed sheet: a row changed but no shown field did.
  ///
  /// In ar, this message translates to:
  /// **'اتعدّل'**
  String get mutationEdited;

  /// Why-changed sheet: a row was removed.
  ///
  /// In ar, this message translates to:
  /// **'اتشال'**
  String get mutationRemoved;

  /// Why-changed sheet: one field before and after. The arrow points from old to new in reading order.
  ///
  /// In ar, this message translates to:
  /// **'{field}: {before} ← {after}'**
  String mutationFieldChange(String field, String before, String after);

  /// Why-changed sheet: a value before and after.
  ///
  /// In ar, this message translates to:
  /// **'{before} ← {after}'**
  String mutationValueChange(String before, String after);

  /// Why-changed sheet: the first fields, and how many more were left out.
  ///
  /// In ar, this message translates to:
  /// **'{shown} • و{count} كمان'**
  String mutationMore(String shown, int count);

  /// Why-changed sheet: a true value.
  ///
  /// In ar, this message translates to:
  /// **'أيوه'**
  String get mutationYes;

  /// Why-changed sheet: a false value.
  ///
  /// In ar, this message translates to:
  /// **'لأ'**
  String get mutationNo;

  /// Why-changed sheet: a list of values, counted.
  ///
  /// In ar, this message translates to:
  /// **'{count} عناصر'**
  String mutationItems(int count);

  /// Why-changed sheet: what joins a list of values.
  ///
  /// In ar, this message translates to:
  /// **'، '**
  String get mutationListSeparator;

  /// Why-changed sheet: title.
  ///
  /// In ar, this message translates to:
  /// **'آخر التغييرات'**
  String get whyChangedTitle;

  /// Why-changed sheet: subtitle.
  ///
  /// In ar, this message translates to:
  /// **'تعديلات زاد الآلية على بياناتك — إيه اتغيّر، وإمتى'**
  String get whyChangedSubtitle;

  /// Why-changed sheet: nothing to show.
  ///
  /// In ar, this message translates to:
  /// **'مفيش تعديلات آلية مسجلة لسه'**
  String get whyChangedEmpty;

  /// Why-changed sheet: less than a minute ago.
  ///
  /// In ar, this message translates to:
  /// **'الآن'**
  String get whyChangedNow;

  /// Why-changed sheet: minutes ago.
  ///
  /// In ar, this message translates to:
  /// **'منذ {minutes} د'**
  String whyChangedMinutesAgo(int minutes);

  /// Why-changed sheet: hours ago.
  ///
  /// In ar, this message translates to:
  /// **'منذ {hours} س'**
  String whyChangedHoursAgo(int hours);

  /// Why-changed sheet: days ago.
  ///
  /// In ar, this message translates to:
  /// **'منذ {days} يوم'**
  String whyChangedDaysAgo(int days);

  /// Memory: confirm before forgetting a note.
  ///
  /// In ar, this message translates to:
  /// **'تنسى الملاحظة دي؟'**
  String get memoryForgetAsk;

  /// Memory: what forgetting a note means.
  ///
  /// In ar, this message translates to:
  /// **'زاد مش هيفتكرها تاني في أي رد جاي.'**
  String get memoryForgetBody;

  /// Memory: confirm forgetting.
  ///
  /// In ar, this message translates to:
  /// **'انساها'**
  String get memoryForgetYes;

  /// Memory: snackbar after forgetting a note.
  ///
  /// In ar, this message translates to:
  /// **'اتنسيت'**
  String get memoryForgotten;

  /// Memory: confirm before clearing outings.
  ///
  /// In ar, this message translates to:
  /// **'تمسح خروجاتك؟'**
  String get memoryClearOutingsAsk;

  /// Memory: confirm clearing outings.
  ///
  /// In ar, this message translates to:
  /// **'امسحها'**
  String get memoryClearYes;

  /// Memory: snackbar after clearing outings.
  ///
  /// In ar, this message translates to:
  /// **'اتمسحت خروجاتك'**
  String get memoryOutingsCleared;

  /// Memory: snackbar after saving the profile.
  ///
  /// In ar, this message translates to:
  /// **'اتحفظ'**
  String get memorySaved;

  /// Memory: screen title.
  ///
  /// In ar, this message translates to:
  /// **'زاد عارف عني إيه'**
  String get memoryTitle;

  /// Memory: banner when the refresh failed.
  ///
  /// In ar, this message translates to:
  /// **'مقدرتش أجيب آخر نسخة — اللي قدامك آخر حاجة اتحفظت هنا.'**
  String get memoryStaleBanner;

  /// Memory: heading over the notes.
  ///
  /// In ar, this message translates to:
  /// **'اللي زاد فاكره عنك'**
  String get memoryNotesHeading;

  /// Memory: empty state title.
  ///
  /// In ar, this message translates to:
  /// **'لسه مفيش ذكريات'**
  String get memoryEmptyTitle;

  /// Memory: the profile card title.
  ///
  /// In ar, this message translates to:
  /// **'إنت مين عند زاد'**
  String get memoryProfileTitle;

  /// Memory: the profile card subtitle.
  ///
  /// In ar, this message translates to:
  /// **'زاد بيكلمك على أساس ده — عدّله براحتك'**
  String get memoryProfileSubtitle;

  /// Memory: edit the profile.
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get memoryEdit;

  /// Memory profile line: preferred name.
  ///
  /// In ar, this message translates to:
  /// **'بتحب أناديك'**
  String get memoryLineName;

  /// Memory profile line: gender.
  ///
  /// In ar, this message translates to:
  /// **'النوع'**
  String get memoryLineGender;

  /// Memory profile line: household role.
  ///
  /// In ar, this message translates to:
  /// **'دورك في البيت'**
  String get memoryLineRole;

  /// Memory profile line: age range.
  ///
  /// In ar, this message translates to:
  /// **'العمر'**
  String get memoryLineAge;

  /// Memory profile line: occupation.
  ///
  /// In ar, this message translates to:
  /// **'شغلك'**
  String get memoryLineJob;

  /// Memory profile line: pay day and frequency.
  ///
  /// In ar, this message translates to:
  /// **'القبض'**
  String get memoryLinePay;

  /// Memory profile line: household size and kids.
  ///
  /// In ar, this message translates to:
  /// **'البيت'**
  String get memoryLineHousehold;

  /// Memory profile line: city.
  ///
  /// In ar, this message translates to:
  /// **'المدينة'**
  String get memoryLineCity;

  /// Memory profile line: dialect.
  ///
  /// In ar, this message translates to:
  /// **'اللهجة'**
  String get memoryLineDialect;

  /// Memory profile line: dialect not chosen.
  ///
  /// In ar, this message translates to:
  /// **'زي بلدك وكلامك'**
  String get memoryDialectDefault;

  /// Memory profile line: the voice Zad speaks in.
  ///
  /// In ar, this message translates to:
  /// **'صوت زاد'**
  String get memoryLineVoice;

  /// Memory: the habits card title.
  ///
  /// In ar, this message translates to:
  /// **'عاداتك وتحركاتك'**
  String get memoryHabitsTitle;

  /// Memory: the habits card subtitle.
  ///
  /// In ar, this message translates to:
  /// **'من صرفك وخروجاتك — من غير أماكن ولا إحداثيات'**
  String get memoryHabitsSubtitle;

  /// Memory: no habits yet.
  ///
  /// In ar, this message translates to:
  /// **'لسه بيتعلم عاداتك — سجّل مصاريفك وهتبان هنا.'**
  String get memoryHabitsEmpty;

  /// Memory habit line.
  ///
  /// In ar, this message translates to:
  /// **'متوسط صرفك في الأسبوع'**
  String get memoryHabitWeekly;

  /// Memory habit line.
  ///
  /// In ar, this message translates to:
  /// **'أكتر حاجات بتصرف عليها'**
  String get memoryHabitTopCategories;

  /// Memory habit line.
  ///
  /// In ar, this message translates to:
  /// **'أكتر يوم بتصرف فيه'**
  String get memoryHabitBusiestDay;

  /// Memory habit line.
  ///
  /// In ar, this message translates to:
  /// **'اشتراكاتك في الشهر'**
  String get memoryHabitSubscriptions;

  /// Memory habit line.
  ///
  /// In ar, this message translates to:
  /// **'خروجاتك آخر ٣٠ يوم'**
  String get memoryHabitOutings;

  /// Memory habit line.
  ///
  /// In ar, this message translates to:
  /// **'متوسط صرف الخروجة'**
  String get memoryHabitPerOuting;

  /// Memory habit line.
  ///
  /// In ar, this message translates to:
  /// **'أكتر أماكن بتروحها'**
  String get memoryHabitTopPlaces;

  /// Memory: what clearing outings does.
  ///
  /// In ar, this message translates to:
  /// **'هنمسح كل الخروجات المتسجلة (أوقات وصرف ومحلات). المصاريف نفسها مش هتتمسح.'**
  String get memoryClearOutingsBody;

  /// Memory: empty state guidance.
  ///
  /// In ar, this message translates to:
  /// **'زاد هيتعلم عنك تدريجيًا من كلامك واستخدامك للتطبيق.'**
  String get memoryEmptyBody;

  /// Memory profile line: a field Zad doesn't know yet.
  ///
  /// In ar, this message translates to:
  /// **'لسه مش عارفاه'**
  String get memoryUnknown;

  /// Memory profile line: household size.
  ///
  /// In ar, this message translates to:
  /// **'{count} أفراد'**
  String memoryHouseholdSize(int count);

  /// Memory profile line: number of kids.
  ///
  /// In ar, this message translates to:
  /// **'{count} عيال'**
  String memoryKidsCount(int count);

  /// Memory profile line: the day of the month pay comes.
  ///
  /// In ar, this message translates to:
  /// **'يوم {day}'**
  String memoryPayDay(int day);

  /// Memory habit line: outings counted.
  ///
  /// In ar, this message translates to:
  /// **'{count} خروجة'**
  String memoryOutingsCount(int count);

  /// Memory: the button that clears outings.
  ///
  /// In ar, this message translates to:
  /// **'امسح خروجاتي'**
  String get memoryClearOutings;

  /// Memory note: how many times it was confirmed.
  ///
  /// In ar, this message translates to:
  /// **'اتأكدت {count} مرة'**
  String memoryConfirmedTimes(int count);

  /// Memory note: who or what it is about.
  ///
  /// In ar, this message translates to:
  /// **'عن: {names}'**
  String memoryAbout(String names);

  /// Memory note: the forget button's tooltip.
  ///
  /// In ar, this message translates to:
  /// **'انسى دي'**
  String get memoryForgetThis;

  /// Memory note: the last day a temporary note holds.
  ///
  /// In ar, this message translates to:
  /// **'لحد {date}'**
  String memoryUntil(String date);

  /// Brain health: screen title.
  ///
  /// In ar, this message translates to:
  /// **'صحة عقل زاد'**
  String get brainHealthTitle;

  /// Brain health: refresh button tooltip.
  ///
  /// In ar, this message translates to:
  /// **'حدّث'**
  String get brainHealthRefresh;

  /// Brain health: empty state when the read failed.
  ///
  /// In ar, this message translates to:
  /// **'مش شايف العقل دلوقتي'**
  String get brainHealthCannotSeeTitle;

  /// Brain health: retry.
  ///
  /// In ar, this message translates to:
  /// **'جرب تاني'**
  String get brainHealthRetry;

  /// Brain health: section title.
  ///
  /// In ar, this message translates to:
  /// **'النشاط'**
  String get brainHealthActivity;

  /// Brain health metric.
  ///
  /// In ar, this message translates to:
  /// **'آخر تنبيه استباقي'**
  String get brainHealthLastProactive;

  /// Brain health metric.
  ///
  /// In ar, this message translates to:
  /// **'تشغيلات آخر ٧ أيام'**
  String get brainHealthRuns7d;

  /// Brain health metric.
  ///
  /// In ar, this message translates to:
  /// **'منها فشلت'**
  String get brainHealthRunsFailed;

  /// Brain health metric.
  ///
  /// In ar, this message translates to:
  /// **'رؤى آخر ٧ أيام'**
  String get brainHealthInsights7d;

  /// Brain health metric.
  ///
  /// In ar, this message translates to:
  /// **'رؤى لسه مشوفتهاش'**
  String get brainHealthInsightsUnseen;

  /// Brain health metric.
  ///
  /// In ar, this message translates to:
  /// **'نوع آخر عطل'**
  String get brainHealthLastFailure;

  /// Brain health: failure kind.
  ///
  /// In ar, this message translates to:
  /// **'المزوّد مشغول'**
  String get brainHealthFailureBusy;

  /// Brain health: failure kind.
  ///
  /// In ar, this message translates to:
  /// **'مشكلة إعداد'**
  String get brainHealthFailureConfig;

  /// Brain health: failure kind.
  ///
  /// In ar, this message translates to:
  /// **'غير معروف'**
  String get brainHealthFailureOther;

  /// Brain health: section title.
  ///
  /// In ar, this message translates to:
  /// **'المهام والطابور'**
  String get brainHealthTasks;

  /// Brain health metric.
  ///
  /// In ar, this message translates to:
  /// **'مهام واقفة أو متأخرة'**
  String get brainHealthTasksStuck;

  /// Brain health metric.
  ///
  /// In ar, this message translates to:
  /// **'مهام مستنية دورها'**
  String get brainHealthTasksPending;

  /// Brain health metric.
  ///
  /// In ar, this message translates to:
  /// **'مهام فشلت آخر ٧ أيام'**
  String get brainHealthTasksFailed7d;

  /// Brain health metric.
  ///
  /// In ar, this message translates to:
  /// **'طلبات ماتعادتش'**
  String get brainHealthNotRetried;

  /// Brain health: section title.
  ///
  /// In ar, this message translates to:
  /// **'استخدام الشات'**
  String get brainHealthChatUse;

  /// Brain health metric.
  ///
  /// In ar, this message translates to:
  /// **'الطلبات'**
  String get brainHealthRequests;

  /// Brain health metric: tokens used today.
  ///
  /// In ar, this message translates to:
  /// **'حجم الردود'**
  String get brainHealthTokens;

  /// Brain health: section title.
  ///
  /// In ar, this message translates to:
  /// **'التعلّم'**
  String get brainHealthLearning;

  /// Brain health metric.
  ///
  /// In ar, this message translates to:
  /// **'أهداف زاد شغال عليها'**
  String get brainHealthGoals;

  /// Brain health metric.
  ///
  /// In ar, this message translates to:
  /// **'تصرفات غير متوقعة من زاد آخر ٧ أيام'**
  String get brainHealthDrift;

  /// Brain health: status banner.
  ///
  /// In ar, this message translates to:
  /// **'العقل شغال تمام'**
  String get brainHealthHealthy;

  /// Brain health: status banner.
  ///
  /// In ar, this message translates to:
  /// **'فيه حاجة تستاهل نظرة'**
  String get brainHealthQuiet;

  /// Brain health: status banner.
  ///
  /// In ar, this message translates to:
  /// **'العقل واقف ومحتاج تدخّل'**
  String get brainHealthStalled;

  /// Brain health: no reasons.
  ///
  /// In ar, this message translates to:
  /// **'مفيش أي مشكلة مرصودة. زاد بيشتغل في الخلفية وبيسجّل كل خطوة.'**
  String get brainHealthAllClear;

  /// Brain health: a number of days.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{يوم واحد} =2{يومين} few{{count} أيام} other{{count} يوم}}'**
  String brainHealthDays(int count);

  /// Brain health: a number of hours.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{ساعة واحدة} =2{ساعتين} few{{count} ساعات} other{{count} ساعة}}'**
  String brainHealthHours(int count);

  /// Brain health: no proactive message ever.
  ///
  /// In ar, this message translates to:
  /// **'ولا مرة'**
  String get brainHealthNever;

  /// Brain health: less than an hour ago.
  ///
  /// In ar, this message translates to:
  /// **'دلوقتي'**
  String get brainHealthJustNow;

  /// Brain health reason.
  ///
  /// In ar, this message translates to:
  /// **'زاد لسه بيتعرف عليك، وهيبدأ يبعتلك تنبيهات استباقية بعد شوية استخدام'**
  String get brainHealthReasonNoProactiveYet;

  /// Brain health reason.
  ///
  /// In ar, this message translates to:
  /// **'زاد بطّل يبعت تنبيهات استباقية من {duration}'**
  String brainHealthReasonProactiveSilent(String duration);

  /// Brain health reason.
  ///
  /// In ar, this message translates to:
  /// **'عدد المهام الواقفة أو المتأخرة: {count}'**
  String brainHealthReasonTasksBackedUp(int count);

  /// Brain health reason.
  ///
  /// In ar, this message translates to:
  /// **'عدد التشغيلات الفاشلة: {failed} من {total}'**
  String brainHealthReasonRunsFailing(int failed, int total);

  /// Brain health reason.
  ///
  /// In ar, this message translates to:
  /// **'عدد المهام اللي فشلت: {count}'**
  String brainHealthReasonTasksFailed(int count);

  /// Brain health reason.
  ///
  /// In ar, this message translates to:
  /// **'عدد الطلبات اللي ماتعادتش: {count}'**
  String brainHealthReasonNotRetried(int count);

  /// Brain health reason.
  ///
  /// In ar, this message translates to:
  /// **'استخدام الشات قرب من الحد اليومي ({percent}%) — ممكن الردود تقف لحد بكرة'**
  String brainHealthReasonQuotaNear(int percent);

  /// Brain health: the read failed.
  ///
  /// In ar, this message translates to:
  /// **'معرفتش أقرا حالة العقل دلوقتي. ده مش معناه إن كل حاجة تمام — معناه إني مش شايف.'**
  String get brainHealthCannotSee;

  /// Brain health: used of the daily limit.
  ///
  /// In ar, this message translates to:
  /// **'{used} من {limit}'**
  String brainHealthOf(int used, int limit);

  /// Brain health: what the chat quota covers.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد ده بتاع ردود الشات بس، وبيتصفّر كل يوم بتوقيت جرينتش — مالوش علاقة بشغل زاد في الخلفية'**
  String get brainHealthQuotaNote;

  /// The staff screen and its entry in the brain hub.
  ///
  /// In ar, this message translates to:
  /// **'فريق زاد'**
  String get staffTitle;

  /// Brain hub entry subtitle.
  ///
  /// In ar, this message translates to:
  /// **'اللي الموظفين لاحظوه في جولة الصبح على بيتك وفلوسك وعيلتك'**
  String get brainHubStaffSubtitle;

  /// Brain hub entry subtitle.
  ///
  /// In ar, this message translates to:
  /// **'اللي زاد فاكره عنك وبيكلمك على أساسه — صحّحه أو خلّيه ينساه'**
  String get brainHubMemorySubtitle;

  /// The memory graph screen and its entry in the brain hub.
  ///
  /// In ar, this message translates to:
  /// **'شبكة زاد'**
  String get brainGraphTitle;

  /// The knowledge map screen and its entry in the brain hub.
  ///
  /// In ar, this message translates to:
  /// **'خريطة زاد'**
  String get brainMapTitle;

  /// Brain hub entry subtitle.
  ///
  /// In ar, this message translates to:
  /// **'إزاي ميزانيتك واشتراكاتك وبيتك متصلين ببعض'**
  String get brainHubMapSubtitle;

  /// Brain hub entry subtitle.
  ///
  /// In ar, this message translates to:
  /// **'كل حاجة زاد سجّلها أو عدّلها لك، وترجع فيها لو غلط'**
  String get brainHubLogSubtitle;

  /// Brain hub entry subtitle.
  ///
  /// In ar, this message translates to:
  /// **'زاد شغال في الخلفية ولا واقف — ولو واقف، ليه'**
  String get brainHubHealthSubtitle;

  /// Brain hub screen title.
  ///
  /// In ar, this message translates to:
  /// **'عقل زاد'**
  String get brainHubTitle;

  /// Brain hub entry subtitle.
  ///
  /// In ar, this message translates to:
  /// **'الناس والأماكن والحاجات اللي زاد عارفها ومترابطة إزاي — وصدّرها لأوبسيديان'**
  String get brainHubGraphSubtitle;

  /// Staff screen: who wrote a note (pantry).
  ///
  /// In ar, this message translates to:
  /// **'أمين المخزن'**
  String get staffRolePantry;

  /// Staff screen: who wrote a note (pharmacy).
  ///
  /// In ar, this message translates to:
  /// **'الممرضة'**
  String get staffRolePharmacy;

  /// Staff screen: who wrote a note (finance).
  ///
  /// In ar, this message translates to:
  /// **'المحاسب'**
  String get staffRoleFinance;

  /// Staff screen: who wrote a note (family).
  ///
  /// In ar, this message translates to:
  /// **'سكرتير العيلة'**
  String get staffRoleFamily;

  /// Staff screen: who wrote a note (home).
  ///
  /// In ar, this message translates to:
  /// **'مسؤول البيت'**
  String get staffRoleHome;

  /// Staff screen: who wrote a note (research).
  ///
  /// In ar, this message translates to:
  /// **'الباحث'**
  String get staffRoleResearch;

  /// Staff screen: a note from the setup coach.
  ///
  /// In ar, this message translates to:
  /// **'مدرّب الإعداد'**
  String get staffRoleCoach;

  /// Staff screen: what the team does.
  ///
  /// In ar, this message translates to:
  /// **'كل صبح الفريق بيلف على بيتك: المخزن، الصيدلية، الفلوس، العيلة، والإعدادات — ويبلّغ زاد باللي محتاج انتباه.'**
  String get staffIntro;

  /// Staff screen: empty state title.
  ///
  /// In ar, this message translates to:
  /// **'الفريق مالقاش حاجة تستاهل'**
  String get staffEmptyTitle;

  /// Staff screen: empty state guidance.
  ///
  /// In ar, this message translates to:
  /// **'الجولة الجاية الصبح — لو لقوا حاجة هتلاقيها هنا.'**
  String get staffEmptyBody;

  /// Staff screen: load failed.
  ///
  /// In ar, this message translates to:
  /// **'مقدرتش أجيب ملاحظات الفريق'**
  String get staffLoadFailed;

  /// Profile sheet: pay day field.
  ///
  /// In ar, this message translates to:
  /// **'بتقبض يوم كام في الشهر؟'**
  String get profileSheetPayDay;

  /// Profile sheet: pay frequency choice.
  ///
  /// In ar, this message translates to:
  /// **'بتقبض كل قد إيه'**
  String get profileSheetPayFrequency;

  /// Profile sheet: household size field.
  ///
  /// In ar, this message translates to:
  /// **'عدد اللي في البيت'**
  String get profileSheetHouseholdSize;

  /// Profile sheet: kids count field.
  ///
  /// In ar, this message translates to:
  /// **'عدد العيال'**
  String get profileSheetKids;

  /// Profile sheet: save button.
  ///
  /// In ar, this message translates to:
  /// **'احفظ'**
  String get profileSheetSave;

  /// Memory graph: an entity kind.
  ///
  /// In ar, this message translates to:
  /// **'شخص'**
  String get entityPerson;

  /// Memory graph: an entity kind.
  ///
  /// In ar, this message translates to:
  /// **'مكان'**
  String get entityPlace;

  /// Memory graph: an entity kind.
  ///
  /// In ar, this message translates to:
  /// **'صنف'**
  String get entityItem;

  /// Memory graph: an entity kind.
  ///
  /// In ar, this message translates to:
  /// **'جهة'**
  String get entityOrg;

  /// Memory graph legend: entity kind, plural.
  ///
  /// In ar, this message translates to:
  /// **'الناس'**
  String get entityPeople;

  /// Memory graph legend: entity kind, plural.
  ///
  /// In ar, this message translates to:
  /// **'الأماكن'**
  String get entityPlaces;

  /// Memory graph legend: entity kind, plural.
  ///
  /// In ar, this message translates to:
  /// **'الأصناف'**
  String get entityItems;

  /// Memory graph legend: entity kind, plural.
  ///
  /// In ar, this message translates to:
  /// **'الجهات'**
  String get entityOrgs;

  /// Memory graph: notes about an entity.
  ///
  /// In ar, this message translates to:
  /// **'{count} ملاحظة'**
  String graphNotesCount(int count);

  /// Memory graph: an entity with no notes.
  ///
  /// In ar, this message translates to:
  /// **'لسه مفيش ملاحظات عن {name}.'**
  String graphNoNotesAbout(String name);

  /// Memory graph: screen-reader label of the drawing.
  ///
  /// In ar, this message translates to:
  /// **'شبكة فيها {count} — القايمة تحتها فيها نفس الحاجات'**
  String graphSemantics(int count);

  /// Memory graph: export failed.
  ///
  /// In ar, this message translates to:
  /// **'مقدرتش أجهّز الملفات. جرّب تاني.'**
  String get graphExportFailed;

  /// Memory graph: share sheet subject for the vault.
  ///
  /// In ar, this message translates to:
  /// **'شبكة زاد — أوبسيديان'**
  String get graphShareSubject;

  /// Memory graph: share sheet title.
  ///
  /// In ar, this message translates to:
  /// **'صدّر شبكة زاد'**
  String get graphShareTitle;

  /// Memory graph: export button tooltip.
  ///
  /// In ar, this message translates to:
  /// **'صدّر لأوبسيديان'**
  String get graphExport;

  /// Memory graph: empty state title.
  ///
  /// In ar, this message translates to:
  /// **'لسه مفيش شبكة'**
  String get graphEmptyTitle;

  /// Memory graph: load failed.
  ///
  /// In ar, this message translates to:
  /// **'مقدرتش أجيب الشبكة'**
  String get graphLoadFailed;

  /// Memory graph: load failed guidance.
  ///
  /// In ar, this message translates to:
  /// **'اتأكد من النت وجرّب تاني.'**
  String get graphCheckNet;

  /// Memory graph: empty state guidance.
  ///
  /// In ar, this message translates to:
  /// **'كل ما تكلّم زاد عن ناسك وأماكنك وحاجاتك، هيظهروا هنا ويترابطوا ببعض.'**
  String get graphEmptyBody;

  /// Memory graph: retry after a failed load.
  ///
  /// In ar, this message translates to:
  /// **'جرّب تاني'**
  String get graphRetry;

  /// Knowledge map: a subscription per month.
  ///
  /// In ar, this message translates to:
  /// **'{amount}/شهر'**
  String mapPerMonth(String amount);

  /// Knowledge map: what is left of a debt or a medicine.
  ///
  /// In ar, this message translates to:
  /// **'فاضل {amount}'**
  String mapLeft(String amount);

  /// Knowledge map: the budget area.
  ///
  /// In ar, this message translates to:
  /// **'الميزانية'**
  String get mapDomainBudget;

  /// Knowledge map: the obligations area.
  ///
  /// In ar, this message translates to:
  /// **'الالتزامات'**
  String get mapDomainObligations;

  /// Knowledge map: the subscriptions area.
  ///
  /// In ar, this message translates to:
  /// **'الاشتراكات والأقساط'**
  String get mapDomainSubscriptions;

  /// Knowledge map: the debts area.
  ///
  /// In ar, this message translates to:
  /// **'الديون'**
  String get mapDomainDebts;

  /// Knowledge map: the pantry area.
  ///
  /// In ar, this message translates to:
  /// **'المخزون'**
  String get mapDomainPantry;

  /// Knowledge map: the shopping area.
  ///
  /// In ar, this message translates to:
  /// **'قائمة التسوق'**
  String get mapDomainShopping;

  /// Knowledge map: the pharmacy area.
  ///
  /// In ar, this message translates to:
  /// **'صيدلية العيلة'**
  String get mapDomainPharmacy;

  /// Knowledge map: the maintenance area.
  ///
  /// In ar, this message translates to:
  /// **'الصيانة'**
  String get mapDomainMaintenance;

  /// Knowledge map: the question put in the chat box, which the customer sends.
  ///
  /// In ar, this message translates to:
  /// **'وضّحلي أكتر عن {label}'**
  String mapAskAbout(String label);

  /// Knowledge map: how many nodes are on it.
  ///
  /// In ar, this message translates to:
  /// **'{count} عنصر متصل'**
  String mapNodeCount(int count);

  /// Knowledge map legend: a solid line.
  ///
  /// In ar, this message translates to:
  /// **'علاقة محسوبة فعليًا'**
  String get mapLegendComputed;

  /// Knowledge map legend: a dashed line.
  ///
  /// In ar, this message translates to:
  /// **'لسه برا الحساب'**
  String get mapLegendNotYet;

  /// Knowledge map legend: a highlighted area.
  ///
  /// In ar, this message translates to:
  /// **'فيه رؤية حية من زاد الآن'**
  String get mapLegendLive;

  /// Knowledge map: control.
  ///
  /// In ar, this message translates to:
  /// **'تكبير'**
  String get mapZoomIn;

  /// Knowledge map: control.
  ///
  /// In ar, this message translates to:
  /// **'تصغير'**
  String get mapZoomOut;

  /// Knowledge map: control.
  ///
  /// In ar, this message translates to:
  /// **'إعادة ضبط'**
  String get mapReset;

  /// Knowledge map budget card: money already committed.
  ///
  /// In ar, this message translates to:
  /// **'محجوز'**
  String get mapReserved;

  /// Knowledge map budget card: money available.
  ///
  /// In ar, this message translates to:
  /// **'متاح'**
  String get mapAvailable;

  /// Knowledge map: ask Zad about an area.
  ///
  /// In ar, this message translates to:
  /// **'اسأل زاد'**
  String get mapAskZad;

  /// Knowledge map: an empty area.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد عناصر هنا حالياً'**
  String get mapNothingHere;

  /// Knowledge map: open the area's own screen.
  ///
  /// In ar, this message translates to:
  /// **'فتح الشاشة'**
  String get mapOpenScreen;

  /// Brain & family tab: opens the family savings pots.
  ///
  /// In ar, this message translates to:
  /// **'صناديق التجميع'**
  String get brainFamilySavingsPots;

  /// Brain & family tab: opens achievements.
  ///
  /// In ar, this message translates to:
  /// **'الإنجازات والرتب'**
  String get brainFamilyAchievements;

  /// Brain & family tab: opens the tasbiha tree.
  ///
  /// In ar, this message translates to:
  /// **'تسبيحة'**
  String get brainFamilyTasbiha;

  /// Brain & family tab: the family side.
  ///
  /// In ar, this message translates to:
  /// **'العائلة'**
  String get brainFamilyFamily;

  /// Monthly report: a weekday.
  ///
  /// In ar, this message translates to:
  /// **'السبت'**
  String get reportDaySaturday;

  /// Monthly report: a weekday.
  ///
  /// In ar, this message translates to:
  /// **'الأحد'**
  String get reportDaySunday;

  /// Monthly report: a weekday.
  ///
  /// In ar, this message translates to:
  /// **'الاثنين'**
  String get reportDayMonday;

  /// Monthly report: a weekday.
  ///
  /// In ar, this message translates to:
  /// **'الثلاثاء'**
  String get reportDayTuesday;

  /// Monthly report: a weekday.
  ///
  /// In ar, this message translates to:
  /// **'الأربعاء'**
  String get reportDayWednesday;

  /// Monthly report: a weekday.
  ///
  /// In ar, this message translates to:
  /// **'الخميس'**
  String get reportDayThursday;

  /// Monthly report: a weekday.
  ///
  /// In ar, this message translates to:
  /// **'الجمعة'**
  String get reportDayFriday;

  /// Monthly report: health label.
  ///
  /// In ar, this message translates to:
  /// **'ممتاز 🌟'**
  String get reportHealthExcellent;

  /// Monthly report: health label.
  ///
  /// In ar, this message translates to:
  /// **'جيد 👍'**
  String get reportHealthGood;

  /// Monthly report: health label.
  ///
  /// In ar, this message translates to:
  /// **'يحتاج انتباه ⚠️'**
  String get reportHealthWatch;

  /// Monthly report: health or spending-power label.
  ///
  /// In ar, this message translates to:
  /// **'خطر 🚨'**
  String get reportDanger;

  /// Monthly report insight.
  ///
  /// In ar, this message translates to:
  /// **'أعلى إنفاقك هذا الشهر: {category} ({amount})'**
  String reportTopSpend(String category, String amount);

  /// Monthly report insight.
  ///
  /// In ar, this message translates to:
  /// **'⛔ تجاوزت ميزانية {category} بـ{amount}'**
  String reportOverBudget(String category, String amount);

  /// Monthly report insight.
  ///
  /// In ar, this message translates to:
  /// **'اشتراكاتك النشطة تكلفك {monthly} شهرياً ({yearly} سنوياً)'**
  String reportSubsCost(String monthly, String yearly);

  /// Monthly report insight.
  ///
  /// In ar, this message translates to:
  /// **'💡 اشتراكاتك {percent}% من ميزانيتك — راجع {title} ({amount}) لو مش مستخدمه'**
  String reportSubsShare(int percent, String title, String amount);

  /// Monthly report insight.
  ///
  /// In ar, this message translates to:
  /// **'📺 عندك {count} خدمات بث — إلغاء واحدة يوفر لك {amount} شهرياً'**
  String reportStreams(int count, String amount);

  /// Monthly report insight.
  ///
  /// In ar, this message translates to:
  /// **'🛒 {name} متوقع يخلص خلال {days} يوم'**
  String reportRunningOut(String name, int days);

  /// Monthly report insight.
  ///
  /// In ar, this message translates to:
  /// **'بمعدل إنفاقك الحالي ({perDay}/يوم)، الرصيد يكفي {days} يوم'**
  String reportRunway(String perDay, int days);

  /// Monthly report: spending power with no budget.
  ///
  /// In ar, this message translates to:
  /// **'غير محدد'**
  String get reportPowerUnknown;

  /// Monthly report: spending power.
  ///
  /// In ar, this message translates to:
  /// **'قوي 💪'**
  String get reportPowerStrong;

  /// Monthly report: spending power.
  ///
  /// In ar, this message translates to:
  /// **'متوازن ⚖️'**
  String get reportPowerBalanced;

  /// Monthly report: spending power.
  ///
  /// In ar, this message translates to:
  /// **'ضعيف ⚠️'**
  String get reportPowerWeak;

  /// Monthly report: no top spending day.
  ///
  /// In ar, this message translates to:
  /// **'غير معروف'**
  String get reportDayUnknown;

  /// Monthly report insight.
  ///
  /// In ar, this message translates to:
  /// **'⚡ معدل صرفك اليومي ({current}) أعلى من الآمن ({safe}) — خفف شوية'**
  String reportTooFast(String current, String safe);

  /// Monthly report insight.
  ///
  /// In ar, this message translates to:
  /// **'🎉 صرفت {percent}% أقل من نفس الفترة الشهر الماضي — وفرت {amount}!'**
  String reportSpentLess(int percent, String amount);

  /// Monthly report insight.
  ///
  /// In ar, this message translates to:
  /// **'📈 صرفك زاد {percent}% عن نفس الفترة الشهر الماضي'**
  String reportSpentMore(int percent);

  /// Monthly report insight.
  ///
  /// In ar, this message translates to:
  /// **'🛍️ {count} مشتريات اندفاعية آخر 30 يوم (أكبر من ضعف متوسطك)'**
  String reportImpulse(int count);

  /// Report export: a figure not known yet.
  ///
  /// In ar, this message translates to:
  /// **'لسه غير محدد'**
  String get reportExportUnknown;

  /// Monthly report: the shared text export.
  ///
  /// In ar, this message translates to:
  /// **'📊 تقرير زاد المالي — {month}'**
  String reportExportTitle(String month);

  /// Monthly report: the shared text export.
  ///
  /// In ar, this message translates to:
  /// **'الصحة المالية: {score}/100 ({label})'**
  String reportExportHealth(int score, String label);

  /// Monthly report: the shared text export.
  ///
  /// In ar, this message translates to:
  /// **'قوة الصرف: {status} — الآمن يومياً: {safe}'**
  String reportExportPower(String status, String safe);

  /// Monthly report: the shared text export.
  ///
  /// In ar, this message translates to:
  /// **'💰 الأرقام:'**
  String get reportExportNumbers;

  /// Monthly report: the shared text export.
  ///
  /// In ar, this message translates to:
  /// **'• الميزانية: {amount}'**
  String reportExportBudget(String amount);

  /// Monthly report: the shared text export.
  ///
  /// In ar, this message translates to:
  /// **'• المصروف: {amount}'**
  String reportExportSpent(String amount);

  /// Monthly report: the shared text export.
  ///
  /// In ar, this message translates to:
  /// **'• الدخل: {amount}'**
  String reportExportIncome(String amount);

  /// Monthly report: the shared text export.
  ///
  /// In ar, this message translates to:
  /// **'• المتبقي: {amount}'**
  String reportExportLeft(String amount);

  /// Monthly report: the shared text export.
  ///
  /// In ar, this message translates to:
  /// **'• الاشتراكات: {amount}/شهر'**
  String reportExportSubs(String amount);

  /// Monthly report: the shared text export.
  ///
  /// In ar, this message translates to:
  /// **'📅 مقارنة بالشهر الماضي (نفس الفترة):'**
  String get reportExportCompare;

  /// Monthly report: the shared text export.
  ///
  /// In ar, this message translates to:
  /// **'• هذا الشهر: {now} | الماضي: {before} ({delta}%)'**
  String reportExportCompareLine(String now, String before, String delta);

  /// Monthly report: the shared text export.
  ///
  /// In ar, this message translates to:
  /// **'🗂️ حسب الفئة:'**
  String get reportExportByCategory;

  /// Monthly report: the shared text export.
  ///
  /// In ar, this message translates to:
  /// **' من {budget} ({percent}%)'**
  String reportExportOfBudget(String budget, int percent);

  /// Monthly report: the shared text export.
  ///
  /// In ar, this message translates to:
  /// **'🏪 أعلى الجهات:'**
  String get reportExportTopMerchants;

  /// Monthly report: the shared text export.
  ///
  /// In ar, this message translates to:
  /// **'🧠 سلوكك المالي:'**
  String get reportExportBehaviour;

  /// Monthly report: the shared text export.
  ///
  /// In ar, this message translates to:
  /// **'• أكثر يوم صرف: {day}'**
  String reportExportTopDay(String day);

  /// Monthly report: the shared text export.
  ///
  /// In ar, this message translates to:
  /// **'• صرف الويكند: {percent}% من الإجمالي'**
  String reportExportWeekend(int percent);

  /// Monthly report: the shared text export.
  ///
  /// In ar, this message translates to:
  /// **'• متوسط المعاملة: {amount}'**
  String reportExportAvgTxn(String amount);

  /// Monthly report: the shared text export.
  ///
  /// In ar, this message translates to:
  /// **'• مشتريات اندفاعية (30 يوم): {count}'**
  String reportExportImpulse(int count);

  /// Monthly report: the shared text export.
  ///
  /// In ar, this message translates to:
  /// **'💡 ملاحظات زاد:'**
  String get reportExportNotes;

  /// Monthly report: the shared text export.
  ///
  /// In ar, this message translates to:
  /// **'— تقرير من تطبيق زاد 🥕'**
  String get reportExportFooter;

  /// Monthly report screen title.
  ///
  /// In ar, this message translates to:
  /// **'تقرير زاد الشهري'**
  String get reportScreenTitle;

  /// Monthly report: share the PDF.
  ///
  /// In ar, this message translates to:
  /// **'شارك مع العيلة'**
  String get reportShareFamily;

  /// Monthly report: the score card heading.
  ///
  /// In ar, this message translates to:
  /// **'الصحة المالية'**
  String get reportHealthHeading;

  /// The button that opens the monthly report.
  ///
  /// In ar, this message translates to:
  /// **'التقرير الشهري'**
  String get reportButton;

  /// Monthly report PDF: share subject (the PDF is Arabic).
  ///
  /// In ar, this message translates to:
  /// **'تقرير زاد المالي'**
  String get reportShareSubject;

  /// Monthly report PDF: share sheet title (the PDF is Arabic).
  ///
  /// In ar, this message translates to:
  /// **'مشاركة تقرير زاد'**
  String get reportShareTitle;

  /// Intelligence: a quick question the customer sends to the chat.
  ///
  /// In ar, this message translates to:
  /// **'حلل مصاريفي 📊'**
  String get intelPromptAnalyse;

  /// Intelligence: a quick question the customer sends to the chat.
  ///
  /// In ar, this message translates to:
  /// **'توقع مصاريف الشهر القادم 🔮'**
  String get intelPromptForecast;

  /// Intelligence: a quick question the customer sends to the chat.
  ///
  /// In ar, this message translates to:
  /// **'اقترح وجبة للغداء 🍲'**
  String get intelPromptLunch;

  /// Intelligence: a quick question the customer sends to the chat.
  ///
  /// In ar, this message translates to:
  /// **'هل وضعي المالي آمن؟ 💰'**
  String get intelPromptSafe;

  /// Intelligence: a family SOS banner.
  ///
  /// In ar, this message translates to:
  /// **'نداء طوارئ من {name}!'**
  String intelSosFrom(String name);

  /// Intelligence: why it needs three expenses.
  ///
  /// In ar, this message translates to:
  /// **'يحتاج عقل زاد إلى 3 مصاريف على الأقل لتحليل سلوكك المالي بدقة وتوليد تقارير الصمود المالي.'**
  String get intelNeedThreeBody;

  /// Intelligence: progress toward three expenses.
  ///
  /// In ar, this message translates to:
  /// **'تم تسجيل {count} من 3 مصاريف'**
  String intelLoggedOfThree(int count);

  /// Intelligence: the AI report card subtitle.
  ///
  /// In ar, this message translates to:
  /// **'تحليل فوري دقيق لجميع حركاتك ومصروفاتك عبر نماذج الذكاء الاصطناعي'**
  String get intelReportSubtitle;

  /// Intelligence: the AI report is being built.
  ///
  /// In ar, this message translates to:
  /// **'جاري تحليل الحركات وتوليد التقرير بالذكاء الاصطناعي...'**
  String get intelReportWorking;

  /// Intelligence: days the savings would last.
  ///
  /// In ar, this message translates to:
  /// **'{days} يوم تغطية'**
  String intelCoverageDays(int days);

  /// Intelligence: the coverage goal.
  ///
  /// In ar, this message translates to:
  /// **'الهدف: {days} يوم'**
  String intelTargetDays(int days);

  /// Intelligence: suggested monthly saving.
  ///
  /// In ar, this message translates to:
  /// **'وفّر {amount} شهرياً للوصول للهدف'**
  String intelSaveToReach(String amount);

  /// Intelligence: the top spending category.
  ///
  /// In ar, this message translates to:
  /// **'💡 أعلى استهلاك في فئة [{category}] بنسبة {percent}% من إجمالي مصروفاتك'**
  String intelTopCategory(String category, int percent);

  /// Intelligence: hero title.
  ///
  /// In ar, this message translates to:
  /// **'عقل زاد الذكي'**
  String get intelHeroTitle;

  /// Intelligence: hero while thinking.
  ///
  /// In ar, this message translates to:
  /// **'زاد يحلل بياناتك الآن 🧠✨'**
  String get intelHeroBusy;

  /// Intelligence: hero when idle.
  ///
  /// In ar, this message translates to:
  /// **'متصل ومستعد لمساعدتك في إدارتك المالية والمنزلية ⚡'**
  String get intelHeroReady;

  /// Intelligence: the explanation failed.
  ///
  /// In ar, this message translates to:
  /// **'زاد مقدرش يرد دلوقتي — جرّب تاني.'**
  String get intelNoAnswer;

  /// Intelligence: explanation in progress.
  ///
  /// In ar, this message translates to:
  /// **'زاد يقوم بالتحليل...'**
  String get intelAnalysing;

  /// Intelligence: ask the model to explain a card.
  ///
  /// In ar, this message translates to:
  /// **'اشرح بالذكاء الاصطناعي'**
  String get intelExplain;

  /// Intelligence: not enough data yet.
  ///
  /// In ar, this message translates to:
  /// **'سجل أول 3 مصاريف لتفعيل عقل زاد التحليلي'**
  String get intelNeedThreeTitle;

  /// Intelligence: open the chat.
  ///
  /// In ar, this message translates to:
  /// **'تحدث مع زاد الآن 💬'**
  String get intelTalkNow;

  /// Intelligence: the AI report card title and button.
  ///
  /// In ar, this message translates to:
  /// **'توليد تقرير الذكاء الاصطناعي الشامل'**
  String get intelReportTitle;

  /// Intelligence: share tooltip.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة التقرير PDF'**
  String get intelSharePdf;

  /// Intelligence: the report failed.
  ///
  /// In ar, this message translates to:
  /// **'تعذر حفظ التغييرات — تحقق من الاتصال وحاول مرة أخرى'**
  String get intelSaveFailed;

  /// Intelligence: retry.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get intelRetry;

  /// Intelligence: rebuild the report.
  ///
  /// In ar, this message translates to:
  /// **'تحديث التقرير 🔄'**
  String get intelRefreshReport;

  /// Intelligence: emergency fund balance dialog title and button.
  ///
  /// In ar, this message translates to:
  /// **'تحديث الرصيد'**
  String get intelUpdateBalance;

  /// Intelligence: emergency fund field and label.
  ///
  /// In ar, this message translates to:
  /// **'رصيد صندوق الطوارئ'**
  String get intelFundBalance;

  /// Intelligence: cancel the dialog.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get intelCancel;

  /// Intelligence: save the dialog.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get intelSave;

  /// Intelligence: resilience status.
  ///
  /// In ar, this message translates to:
  /// **'حرج'**
  String get intelStatusCritical;

  /// Intelligence: resilience status.
  ///
  /// In ar, this message translates to:
  /// **'منخفض'**
  String get intelStatusLow;

  /// Intelligence: resilience status.
  ///
  /// In ar, this message translates to:
  /// **'صحي'**
  String get intelStatusHealthy;

  /// Intelligence: the stress test card title.
  ///
  /// In ar, this message translates to:
  /// **'اختبار الصمود المالي'**
  String get intelStressTitle;

  /// Intelligence: the stress test question.
  ///
  /// In ar, this message translates to:
  /// **'كم يوماً تستطيع الصمود لو توقف دخلك؟'**
  String get intelStressQuestion;

  /// Intelligence: the savings used when there is no fund.
  ///
  /// In ar, this message translates to:
  /// **'رصيدك المتاح حالياً (لسه محددتش صندوق طوارئ)'**
  String get intelAvailableNoFund;

  /// Intelligence: stress test figure.
  ///
  /// In ar, this message translates to:
  /// **'متوسط الصرف اليومي'**
  String get intelDailyAverage;

  /// Intelligence: distribution card title.
  ///
  /// In ar, this message translates to:
  /// **'توزيع المصروفات والملاحظات السلوكية'**
  String get intelDistributionTitle;

  /// Intelligence: distribution card subtitle.
  ///
  /// In ar, this message translates to:
  /// **'تحليل نسب الصرف على الفئات والملاحظات السلوكية الذكية'**
  String get intelDistributionSubtitle;

  /// Strategic report: issue date.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الإصدار: {date}'**
  String dossierIssued(String date);

  /// Strategic report line.
  ///
  /// In ar, this message translates to:
  /// **'• معدل الصرف اليومي الآمن: محتاج ميزانية ورصيد محدّدين عشان يتحسب.'**
  String get dossierSafeDailyUnknown;

  /// Strategic report line.
  ///
  /// In ar, this message translates to:
  /// **'• معدل الصرف اليومي الآمن الموصى به: {amount}/يوم.'**
  String dossierSafeDaily(String amount);

  /// Strategic report line.
  ///
  /// In ar, this message translates to:
  /// **'• إجمالي الصرف الفعلي للدورة الحالية: {amount}.'**
  String dossierSpentCycle(String amount);

  /// Strategic report line.
  ///
  /// In ar, this message translates to:
  /// **'• عقل العائلة المشترك: {count} أفراد متصلين ومزامنين لحظياً.'**
  String dossierFamilyMembers(int count);

  /// Strategic report line.
  ///
  /// In ar, this message translates to:
  /// **'• أصناف قاربت على النفاد في المخزون: {count} صنف.'**
  String dossierLowStock(int count);

  /// Strategic report line.
  ///
  /// In ar, this message translates to:
  /// **'• الالتزام الدوائي هذا الأسبوع: {percent}%.'**
  String dossierAdherence(int percent);

  /// Strategic report line.
  ///
  /// In ar, this message translates to:
  /// **'• الالتزام الدوائي: لسه مفيش جرعات كفاية مسجّلة لحساب نسبة.'**
  String get dossierAdherenceUnknown;

  /// Strategic report: shared text heading.
  ///
  /// In ar, this message translates to:
  /// **'📄 تقرير عقل زاد:'**
  String get dossierShareHeading;

  /// Strategic report: shared text.
  ///
  /// In ar, this message translates to:
  /// **'• إجمالي الصرف: {amount}'**
  String dossierShareSpent(String amount);

  /// Strategic report: shared text.
  ///
  /// In ar, this message translates to:
  /// **'• الالتزام الدوائي: {percent}%'**
  String dossierShareAdherence(int percent);

  /// Strategic report: title.
  ///
  /// In ar, this message translates to:
  /// **'التقرير الاستراتيجي الشامل لعقل زاد'**
  String get dossierTitle;

  /// Strategic report: section title.
  ///
  /// In ar, this message translates to:
  /// **'1. التنبؤات والتدفق المالي للشهر القادم'**
  String get dossierSection1;

  /// Strategic report: section title.
  ///
  /// In ar, this message translates to:
  /// **'2. كفاءة إدارة المنزل والعائلة'**
  String get dossierSection2;

  /// Strategic report: share sheet title.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة تقرير عقل زاد'**
  String get dossierShareTitle;

  /// Strategic report: share button.
  ///
  /// In ar, this message translates to:
  /// **'📤 مشاركة التقرير'**
  String get dossierShare;

  /// Strategic report: close button.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق التقرير'**
  String get dossierClose;

  /// Spending charts: a weekday, short.
  ///
  /// In ar, this message translates to:
  /// **'السبت'**
  String get weekdaySat;

  /// Spending charts: a weekday, short.
  ///
  /// In ar, this message translates to:
  /// **'الأحد'**
  String get weekdaySun;

  /// Spending charts: a weekday, short.
  ///
  /// In ar, this message translates to:
  /// **'الاتنين'**
  String get weekdayMon;

  /// Spending charts: a weekday, short.
  ///
  /// In ar, this message translates to:
  /// **'التلات'**
  String get weekdayTue;

  /// Spending charts: a weekday, short.
  ///
  /// In ar, this message translates to:
  /// **'الأربع'**
  String get weekdayWed;

  /// Spending charts: a weekday, short.
  ///
  /// In ar, this message translates to:
  /// **'الخميس'**
  String get weekdayThu;

  /// Spending charts: a weekday, short.
  ///
  /// In ar, this message translates to:
  /// **'الجمعة'**
  String get weekdayFri;

  /// Spending habits: a category that is new this month.
  ///
  /// In ar, this message translates to:
  /// **'{name}: جديد الشهر ده ({amount})'**
  String behaviourNew(String name, String amount);

  /// Spending habits: a category that grew. Old to new in reading order.
  ///
  /// In ar, this message translates to:
  /// **'{name}: زادت {percent}٪ ({before} ← {after})'**
  String behaviourUp(String name, int percent, String before, String after);

  /// Spending habits: a category that shrank. Old to new in reading order.
  ///
  /// In ar, this message translates to:
  /// **'{name}: قلّت {percent}٪ ({before} ← {after})'**
  String behaviourDown(String name, int percent, String before, String after);

  /// Spending habits: the busiest weekday.
  ///
  /// In ar, this message translates to:
  /// **'أكتر يوم بتصرف فيه: {day} — متوسط {amount}'**
  String behaviourPeakDay(String day, String amount);

  /// Spending habits: a place, total and visits.
  ///
  /// In ar, this message translates to:
  /// **'{amount} · {count} مرة'**
  String behaviourPlaceLine(String amount, int count);

  /// Spending habits: card title.
  ///
  /// In ar, this message translates to:
  /// **'سلوكك في الصرف'**
  String get behaviourTitle;

  /// Spending habits: places heading.
  ///
  /// In ar, this message translates to:
  /// **'أكتر أماكن بتصرف فيها'**
  String get behaviourTopPlaces;

  /// Spending habits: changes heading.
  ///
  /// In ar, this message translates to:
  /// **'اتغيّر إيه عن الشهر اللي فات'**
  String get behaviourChanges;

  /// Spending charts: title.
  ///
  /// In ar, this message translates to:
  /// **'صرفك آخر أسبوعين'**
  String get chartsTwoWeeks;

  /// Spending charts: totals line.
  ///
  /// In ar, this message translates to:
  /// **'الإجمالي {total} · متوسط اليوم {daily}'**
  String chartsTotals(String total, String daily);

  /// Spending charts: title.
  ///
  /// In ar, this message translates to:
  /// **'صرفك راح فين (آخر شهر)'**
  String get chartsWhere;

  /// Home reports row: building the report failed.
  ///
  /// In ar, this message translates to:
  /// **'مقدرتش أجهّز التقرير دلوقتي'**
  String get reportsRowFailed;

  /// Home reports row: button.
  ///
  /// In ar, this message translates to:
  /// **'تصدير التقرير الشهري'**
  String get reportsRowMonthly;

  /// Home reports row: button.
  ///
  /// In ar, this message translates to:
  /// **'التقرير الاستراتيجي'**
  String get reportsRowStrategic;

  /// No description provided for @familyTitle.
  ///
  /// In ar, this message translates to:
  /// **'العيلة'**
  String get familyTitle;

  /// No description provided for @familyLoadingTitle.
  ///
  /// In ar, this message translates to:
  /// **'بنشوف عيلتك'**
  String get familyLoadingTitle;

  /// No description provided for @familyLoadingMessage.
  ///
  /// In ar, this message translates to:
  /// **'أول مرة محتاجة نت. اسحب لتحت لو طوّلت.'**
  String get familyLoadingMessage;

  /// No description provided for @familyRetry.
  ///
  /// In ar, this message translates to:
  /// **'جرّب تاني'**
  String get familyRetry;

  /// No description provided for @familyWelcomeTitle.
  ///
  /// In ar, this message translates to:
  /// **'أهلاً بك في عائلة زاد'**
  String get familyWelcomeTitle;

  /// No description provided for @familyWelcomeBody.
  ///
  /// In ar, this message translates to:
  /// **'يمكنك إنشاء عائلة جديدة لتكون أنت المدير، أو الانضمام لعائلة موجودة عبر كود الدعوة.'**
  String get familyWelcomeBody;

  /// No description provided for @familyCreateAsAdmin.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء عائلة جديدة كمدير (Admin)'**
  String get familyCreateAsAdmin;

  /// No description provided for @familyJoin.
  ///
  /// In ar, this message translates to:
  /// **'الانضمام للعائلة'**
  String get familyJoin;

  /// No description provided for @familyOr.
  ///
  /// In ar, this message translates to:
  /// **'أو'**
  String get familyOr;

  /// No description provided for @familyAliasLabel.
  ///
  /// In ar, this message translates to:
  /// **'اسمك في العيلة (اختياري)'**
  String get familyAliasLabel;

  /// No description provided for @familyAliasHint.
  ///
  /// In ar, this message translates to:
  /// **'مثال: الابن أحمد'**
  String get familyAliasHint;

  /// No description provided for @familyInviteCodeLabel.
  ///
  /// In ar, this message translates to:
  /// **'كود الدعوة'**
  String get familyInviteCodeLabel;

  /// No description provided for @familyInviteCodeHint.
  ///
  /// In ar, this message translates to:
  /// **'مثال: ZAD-1234'**
  String get familyInviteCodeHint;

  /// No description provided for @familyTabChat.
  ///
  /// In ar, this message translates to:
  /// **'الشات'**
  String get familyTabChat;

  /// No description provided for @familyTabTasks.
  ///
  /// In ar, this message translates to:
  /// **'المهام'**
  String get familyTabTasks;

  /// No description provided for @familyTabMembers.
  ///
  /// In ar, this message translates to:
  /// **'الأعضاء'**
  String get familyTabMembers;

  /// No description provided for @familyTabGroceries.
  ///
  /// In ar, this message translates to:
  /// **'البقالة'**
  String get familyTabGroceries;

  /// No description provided for @familyTabKids.
  ///
  /// In ar, this message translates to:
  /// **'الأبناء'**
  String get familyTabKids;

  /// No description provided for @familyTabGoals.
  ///
  /// In ar, this message translates to:
  /// **'الأهداف'**
  String get familyTabGoals;

  /// Family header: the family's invite code is its name.
  ///
  /// In ar, this message translates to:
  /// **'عائلة {code}'**
  String familyHeaderTitle(String code);

  /// No description provided for @familyMemberCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, other{{count} أفراد}}'**
  String familyMemberCount(int count);

  /// No description provided for @familySosTooltip.
  ///
  /// In ar, this message translates to:
  /// **'الرجاء الانتباه، حالة طوارئ!'**
  String get familySosTooltip;

  /// No description provided for @familyInviteNew.
  ///
  /// In ar, this message translates to:
  /// **'دعوة أفراد جدد'**
  String get familyInviteNew;

  /// No description provided for @familyShareInvite.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة الدعوة'**
  String get familyShareInvite;

  /// Shared to another app from the family header.
  ///
  /// In ar, this message translates to:
  /// **'🌱 دعوة للانضمام إلى عائلتي على تطبيق زاد\n\n📲 اضغط على الرابط التالي للانضمام فوراً وفتح التطبيق:\nhttps://zad.app/invite?code={code}\n\n🔑 كود الدعوة المباشر:\n{code}\n\n🔗 رابط التطبيق المباشر:\n{link}'**
  String familyShareInviteText(String code, String link);

  /// No description provided for @familySosConfirmTitle.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد نداء الطوارئ'**
  String get familySosConfirmTitle;

  /// No description provided for @familySosConfirmBody.
  ///
  /// In ar, this message translates to:
  /// **'هيتبعت تنبيه فوري لكل أفراد العائلة إنك محتاج مساعدة. متأكد؟'**
  String get familySosConfirmBody;

  /// No description provided for @familySosSend.
  ///
  /// In ar, this message translates to:
  /// **'أرسل النداء'**
  String get familySosSend;

  /// No description provided for @familyInviteShareText.
  ///
  /// In ar, this message translates to:
  /// **'انضم إلى عائلتي في تطبيق زاد!\nكود الدعوة: {code}\nأو افتح الرابط: {link}'**
  String familyInviteShareText(String code, String link);

  /// No description provided for @familyInviteShareQr.
  ///
  /// In ar, this message translates to:
  /// **'انضم إلى عائلتي في تطبيق زاد! امسح الرمز: {link}'**
  String familyInviteShareQr(String link);

  /// No description provided for @familyInviteShareLink.
  ///
  /// In ar, this message translates to:
  /// **'انضم إلى عائلتي في تطبيق زاد!\nرابط الدعوة: {link}'**
  String familyInviteShareLink(String link);

  /// No description provided for @familyInviteShareCode.
  ///
  /// In ar, this message translates to:
  /// **'انضم إلى عائلتي في تطبيق زاد!\nكود الدعوة: {code}'**
  String familyInviteShareCode(String code);

  /// No description provided for @familyInviteMethodLink.
  ///
  /// In ar, this message translates to:
  /// **'رابط'**
  String get familyInviteMethodLink;

  /// No description provided for @familyInviteMethodCode.
  ///
  /// In ar, this message translates to:
  /// **'كود'**
  String get familyInviteMethodCode;

  /// No description provided for @familyInviteMethodWhatsapp.
  ///
  /// In ar, this message translates to:
  /// **'واتساب'**
  String get familyInviteMethodWhatsapp;

  /// No description provided for @familyInviteScanToJoin.
  ///
  /// In ar, this message translates to:
  /// **'مسح الرمز للانضمام:'**
  String get familyInviteScanToJoin;

  /// No description provided for @familyInviteLinkLabel.
  ///
  /// In ar, this message translates to:
  /// **'رابط الدعوة:'**
  String get familyInviteLinkLabel;

  /// No description provided for @familyCopy.
  ///
  /// In ar, this message translates to:
  /// **'انسخ'**
  String get familyCopy;

  /// No description provided for @familyInviteCodeColon.
  ///
  /// In ar, this message translates to:
  /// **'كود الدعوة:'**
  String get familyInviteCodeColon;

  /// No description provided for @familyInviteShareWhatsapp.
  ///
  /// In ar, this message translates to:
  /// **'شارك عبر واتساب:'**
  String get familyInviteShareWhatsapp;

  /// No description provided for @familyInviteAllApps.
  ///
  /// In ar, this message translates to:
  /// **'جميع التطبيقات'**
  String get familyInviteAllApps;

  /// No description provided for @familyShare.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة'**
  String get familyShare;

  /// No description provided for @familyPasteInvite.
  ///
  /// In ar, this message translates to:
  /// **'الصق رابط أو كود الدعوة'**
  String get familyPasteInvite;

  /// No description provided for @familyAddTaskTitle.
  ///
  /// In ar, this message translates to:
  /// **'إضافة مهمة جديدة'**
  String get familyAddTaskTitle;

  /// No description provided for @familyTaskNameLabel.
  ///
  /// In ar, this message translates to:
  /// **'اسم المهمة'**
  String get familyTaskNameLabel;

  /// No description provided for @familyTaskNameHint.
  ///
  /// In ar, this message translates to:
  /// **'مثال: ترتيب الغرفة'**
  String get familyTaskNameHint;

  /// No description provided for @familyReward.
  ///
  /// In ar, this message translates to:
  /// **'المكافأة'**
  String get familyReward;

  /// No description provided for @familyRewardIn.
  ///
  /// In ar, this message translates to:
  /// **'المكافأة ({currency})'**
  String familyRewardIn(String currency);

  /// No description provided for @familyAssignee.
  ///
  /// In ar, this message translates to:
  /// **'المكلف بالمهمة:'**
  String get familyAssignee;

  /// No description provided for @familyDueDateOptional.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ التسليم (اختياري)'**
  String get familyDueDateOptional;

  /// No description provided for @familyQuickGroceryTitle.
  ///
  /// In ar, this message translates to:
  /// **'نزّلها في التسوق'**
  String get familyQuickGroceryTitle;

  /// No description provided for @familyQuickGroceryHint.
  ///
  /// In ar, this message translates to:
  /// **'مثلاً: حليب'**
  String get familyQuickGroceryHint;

  /// No description provided for @familyMoneyRequestTitle.
  ///
  /// In ar, this message translates to:
  /// **'طلب مصروف أو مشتريات'**
  String get familyMoneyRequestTitle;

  /// No description provided for @familyMoneyRequestWhat.
  ///
  /// In ar, this message translates to:
  /// **'ماذا تريد أن تشتري؟'**
  String get familyMoneyRequestWhat;

  /// No description provided for @familyMoneyRequestAmount.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ المطلوب'**
  String get familyMoneyRequestAmount;

  /// No description provided for @familyMoneyRequestAmountIn.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ المطلوب ({currency})'**
  String familyMoneyRequestAmountIn(String currency);

  /// No description provided for @familyMoneyRequestSend.
  ///
  /// In ar, this message translates to:
  /// **'إرسال الطلب'**
  String get familyMoneyRequestSend;

  /// No description provided for @familySpendLimitTitle.
  ///
  /// In ar, this message translates to:
  /// **'حد الإنفاق'**
  String get familySpendLimitTitle;

  /// No description provided for @familySpendLimitBody.
  ///
  /// In ar, this message translates to:
  /// **'حدد أقصى مبلغ يقدر {name} يصرفه يومياً/أسبوعياً. اتركه فارغاً لإلغاء الحد.'**
  String familySpendLimitBody(String name);

  /// No description provided for @familyDailyLimitIn.
  ///
  /// In ar, this message translates to:
  /// **'الحد اليومي ({currency})'**
  String familyDailyLimitIn(String currency);

  /// No description provided for @familyWeeklyLimitIn.
  ///
  /// In ar, this message translates to:
  /// **'الحد الأسبوعي ({currency})'**
  String familyWeeklyLimitIn(String currency);

  /// No description provided for @familyPollClosesTomorrow.
  ///
  /// In ar, this message translates to:
  /// **'بكرة'**
  String get familyPollClosesTomorrow;

  /// No description provided for @familyPollClosesTwoDays.
  ///
  /// In ar, this message translates to:
  /// **'بعد يومين'**
  String get familyPollClosesTwoDays;

  /// No description provided for @familyPollClosesWeek.
  ///
  /// In ar, this message translates to:
  /// **'بعد أسبوع'**
  String get familyPollClosesWeek;

  /// No description provided for @familyPollClosesByHand.
  ///
  /// In ar, this message translates to:
  /// **'أنا أقفله'**
  String get familyPollClosesByHand;

  /// No description provided for @familyPollTitle.
  ///
  /// In ar, this message translates to:
  /// **'تصويت عائلي'**
  String get familyPollTitle;

  /// No description provided for @familyPollQuestion.
  ///
  /// In ar, this message translates to:
  /// **'السؤال'**
  String get familyPollQuestion;

  /// No description provided for @familyPollOption.
  ///
  /// In ar, this message translates to:
  /// **'خيار {n}'**
  String familyPollOption(int n);

  /// No description provided for @familyPollAddOption.
  ///
  /// In ar, this message translates to:
  /// **'+ إضافة خيار'**
  String get familyPollAddOption;

  /// No description provided for @familyPollClosesWhen.
  ///
  /// In ar, this message translates to:
  /// **'يتقفل إمتى؟'**
  String get familyPollClosesWhen;

  /// No description provided for @familyPollSend.
  ///
  /// In ar, this message translates to:
  /// **'إرسال التصويت'**
  String get familyPollSend;

  /// No description provided for @familyTasksHeading.
  ///
  /// In ar, this message translates to:
  /// **'المهام العائلية'**
  String get familyTasksHeading;

  /// No description provided for @familyTasksDoneOf.
  ///
  /// In ar, this message translates to:
  /// **'{done}/{total} منجزة'**
  String familyTasksDoneOf(int done, int total);

  /// No description provided for @familyFilterAll.
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get familyFilterAll;

  /// No description provided for @familyFilterPending.
  ///
  /// In ar, this message translates to:
  /// **'قادمة'**
  String get familyFilterPending;

  /// No description provided for @familyFilterDone.
  ///
  /// In ar, this message translates to:
  /// **'منجزة'**
  String get familyFilterDone;

  /// No description provided for @familyNoTasksTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مهام'**
  String get familyNoTasksTitle;

  /// No description provided for @familyNoTasksMessage.
  ///
  /// In ar, this message translates to:
  /// **'ضيف مهمة عشان أفراد العائلة يشاركوا فيها'**
  String get familyNoTasksMessage;

  /// No description provided for @familyMembersHeading.
  ///
  /// In ar, this message translates to:
  /// **'أفراد العائلة'**
  String get familyMembersHeading;

  /// No description provided for @familyMembersHint.
  ///
  /// In ar, this message translates to:
  /// **'اضغط على أي عضو لتفاصيل إنجازاته'**
  String get familyMembersHint;

  /// No description provided for @familyReport.
  ///
  /// In ar, this message translates to:
  /// **'تقرير العيلة'**
  String get familyReport;

  /// No description provided for @familyDeleteAndRecreate.
  ///
  /// In ar, this message translates to:
  /// **'حذف العائلة وإعادة الإنشاء'**
  String get familyDeleteAndRecreate;

  /// No description provided for @familyLeave.
  ///
  /// In ar, this message translates to:
  /// **'مغادرة العائلة'**
  String get familyLeave;

  /// No description provided for @familyDeleteForeverTitle.
  ///
  /// In ar, this message translates to:
  /// **'حذف العائلة نهائياً'**
  String get familyDeleteForeverTitle;

  /// No description provided for @familyLeaveConfirmTitle.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد المغادرة'**
  String get familyLeaveConfirmTitle;

  /// No description provided for @familyDeleteForeverBody.
  ///
  /// In ar, this message translates to:
  /// **'إنت آخر فرد في العائلة دي. حذفها هيمسح الشات والمهام وكل البيانات نهائياً ومينفعش ترجعها، وتقدر تنشئ عائلة جديدة بعد كده.'**
  String get familyDeleteForeverBody;

  /// No description provided for @familyLeaveConfirmBody.
  ///
  /// In ar, this message translates to:
  /// **'هتفقد الوصول لشات العائلة والمهام والأرصدة المشتركة. متأكد إنك عايز تغادر العائلة؟'**
  String get familyLeaveConfirmBody;

  /// No description provided for @familyDeleteForever.
  ///
  /// In ar, this message translates to:
  /// **'حذف نهائي'**
  String get familyDeleteForever;

  /// No description provided for @familyLeaveShort.
  ///
  /// In ar, this message translates to:
  /// **'مغادرة'**
  String get familyLeaveShort;

  /// No description provided for @familyTasksCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, other{{count} مهام}}'**
  String familyTasksCount(int count);

  /// No description provided for @familyTasbihaCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, other{{count} تسبيحة}}'**
  String familyTasbihaCount(int count);

  /// No description provided for @familySavingsGoal.
  ///
  /// In ar, this message translates to:
  /// **'هدف التوفير'**
  String get familySavingsGoal;

  /// No description provided for @familyRoleAdminShort.
  ///
  /// In ar, this message translates to:
  /// **'مدير'**
  String get familyRoleAdminShort;

  /// No description provided for @familyRoleChild.
  ///
  /// In ar, this message translates to:
  /// **'ابن/ابنة'**
  String get familyRoleChild;

  /// No description provided for @familyRoleAdminLong.
  ///
  /// In ar, this message translates to:
  /// **'مدير العائلة'**
  String get familyRoleAdminLong;

  /// No description provided for @familyRoleMember.
  ///
  /// In ar, this message translates to:
  /// **'عضو'**
  String get familyRoleMember;

  /// No description provided for @familyBalance.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد'**
  String get familyBalance;

  /// No description provided for @familyGoal.
  ///
  /// In ar, this message translates to:
  /// **'الهدف'**
  String get familyGoal;

  /// No description provided for @familyTrees.
  ///
  /// In ar, this message translates to:
  /// **'الأشجار'**
  String get familyTrees;

  /// No description provided for @familyDoneTasksTitle.
  ///
  /// In ar, this message translates to:
  /// **'المهام المنجزة ({count})'**
  String familyDoneTasksTitle(int count);

  /// No description provided for @familyNoDoneTasks.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مهام منجزة بعد'**
  String get familyNoDoneTasks;

  /// No description provided for @familyUpcomingTasksTitle.
  ///
  /// In ar, this message translates to:
  /// **'المهام القادمة ({count})'**
  String familyUpcomingTasksTitle(int count);

  /// No description provided for @familyNoUpcomingTasks.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مهام قادمة'**
  String get familyNoUpcomingTasks;

  /// No description provided for @familyTreesTitle.
  ///
  /// In ar, this message translates to:
  /// **'أشجار التسبيحة ({count})'**
  String familyTreesTitle(int count);

  /// No description provided for @familyDaily.
  ///
  /// In ar, this message translates to:
  /// **'اليومي'**
  String get familyDaily;

  /// No description provided for @familyWeekly.
  ///
  /// In ar, this message translates to:
  /// **'الأسبوعي'**
  String get familyWeekly;

  /// No description provided for @familyRoleInFamily.
  ///
  /// In ar, this message translates to:
  /// **'الدور في العيلة'**
  String get familyRoleInFamily;

  /// No description provided for @familyRemoveMemberTitle.
  ///
  /// In ar, this message translates to:
  /// **'تشيل {name} من العيلة؟'**
  String familyRemoveMemberTitle(String name);

  /// No description provided for @familyRemoveMemberShort.
  ///
  /// In ar, this message translates to:
  /// **'شيله'**
  String get familyRemoveMemberShort;

  /// No description provided for @familyRemoveMember.
  ///
  /// In ar, this message translates to:
  /// **'شيله من العيلة'**
  String get familyRemoveMember;

  /// No description provided for @familyRewardAmount.
  ///
  /// In ar, this message translates to:
  /// **'مكافأة: {amount}'**
  String familyRewardAmount(String amount);

  /// No description provided for @familyNoLimit.
  ///
  /// In ar, this message translates to:
  /// **'بدون حد'**
  String get familyNoLimit;

  /// No description provided for @familyGroceriesHeading.
  ///
  /// In ar, this message translates to:
  /// **'البقالة المشتركة'**
  String get familyGroceriesHeading;

  /// No description provided for @familyGroceriesHint.
  ///
  /// In ar, this message translates to:
  /// **'قائمة المشتريات التي تمت إضافتها من قبل أفراد العائلة أو اقترحها زاد.'**
  String get familyGroceriesHint;

  /// No description provided for @familyNoGroceriesTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد طلبات بقالة حالياً.'**
  String get familyNoGroceriesTitle;

  /// No description provided for @familyNoGroceriesMessage.
  ///
  /// In ar, this message translates to:
  /// **'اكتب في الشات \"أضف حليب\" أو دوس + فوق.'**
  String get familyNoGroceriesMessage;

  /// No description provided for @familyKidsHeading.
  ///
  /// In ar, this message translates to:
  /// **'مصاريف الأبناء'**
  String get familyKidsHeading;

  /// No description provided for @familyKidsHint.
  ///
  /// In ar, this message translates to:
  /// **'نظرة عامة على أرصدة وطلبات الأبناء'**
  String get familyKidsHint;

  /// No description provided for @familyNoKidsTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد أبناء مسجلين بعد'**
  String get familyNoKidsTitle;

  /// No description provided for @familyNoKidsMessage.
  ///
  /// In ar, this message translates to:
  /// **'من تاب الأعضاء خلّي أي فرد \"طفل\".'**
  String get familyNoKidsMessage;

  /// No description provided for @familyPauseTitle.
  ///
  /// In ar, this message translates to:
  /// **'وقفة تفكير ٢٤ ساعة'**
  String get familyPauseTitle;

  /// No description provided for @familyPauseBody.
  ///
  /// In ar, this message translates to:
  /// **'طلب الشرا مايتوافقش عليه قبل يوم من ما اتبعت. الرفض في أي وقت، وطلب المصروف مش متأثر.'**
  String get familyPauseBody;

  /// No description provided for @familyAllowanceFor.
  ///
  /// In ar, this message translates to:
  /// **'مصروف لـ{name}'**
  String familyAllowanceFor(String name);

  /// No description provided for @familyAmountIn.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ ({currency})'**
  String familyAmountIn(String currency);

  /// No description provided for @familyAllowanceHelper.
  ///
  /// In ar, this message translates to:
  /// **'بيتضاف لرصيده على طول'**
  String get familyAllowanceHelper;

  /// No description provided for @familyTransfer.
  ///
  /// In ar, this message translates to:
  /// **'حوّل'**
  String get familyTransfer;

  /// No description provided for @familyBalanceIs.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد: {amount}'**
  String familyBalanceIs(String amount);

  /// No description provided for @familyGoalIs.
  ///
  /// In ar, this message translates to:
  /// **'الهدف: {amount}'**
  String familyGoalIs(String amount);

  /// No description provided for @familyKidTasksDoneOf.
  ///
  /// In ar, this message translates to:
  /// **'{done}/{total} مهام'**
  String familyKidTasksDoneOf(int done, int total);

  /// No description provided for @familySendAllowance.
  ///
  /// In ar, this message translates to:
  /// **'حوّل مصروف'**
  String get familySendAllowance;

  /// No description provided for @familyMonthlySpending.
  ///
  /// In ar, this message translates to:
  /// **'المصروف الشهري'**
  String get familyMonthlySpending;

  /// No description provided for @familyPendingRequests.
  ///
  /// In ar, this message translates to:
  /// **'الطلبات المعلقة ({count})'**
  String familyPendingRequests(int count);

  /// No description provided for @familyApprove.
  ///
  /// In ar, this message translates to:
  /// **'موافقة'**
  String get familyApprove;

  /// No description provided for @familyReject.
  ///
  /// In ar, this message translates to:
  /// **'رفض'**
  String get familyReject;

  /// No description provided for @familyBudgetRewardsHeading.
  ///
  /// In ar, this message translates to:
  /// **'الميزانية والمكافآت'**
  String get familyBudgetRewardsHeading;

  /// No description provided for @familySavingsGoalTitle.
  ///
  /// In ar, this message translates to:
  /// **'هدف الادخار العائلي'**
  String get familySavingsGoalTitle;

  /// No description provided for @familyNoSavingsGoal.
  ///
  /// In ar, this message translates to:
  /// **'لسه مفيش هدف ادخار للشهر ده'**
  String get familyNoSavingsGoal;

  /// No description provided for @familySuggestGoal.
  ///
  /// In ar, this message translates to:
  /// **'اقترح هدف بالذكاء الاصطناعي'**
  String get familySuggestGoal;

  /// No description provided for @familyNoKidsStatsTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد أبناء مضافين لعرض إحصائياتهم.'**
  String get familyNoKidsStatsTitle;

  /// No description provided for @familyKidsBalanceStats.
  ///
  /// In ar, this message translates to:
  /// **'إحصائيات أرصدة الأبناء'**
  String get familyKidsBalanceStats;

  /// No description provided for @familyTotalRewardsPaid.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي المكافآت المدفوعة'**
  String get familyTotalRewardsPaid;

  /// No description provided for @familyGoalSuggestionBody.
  ///
  /// In ar, this message translates to:
  /// **'الهدف: {amount} خلال {days} يوم'**
  String familyGoalSuggestionBody(String amount, int days);

  /// No description provided for @familyApproveGoal.
  ///
  /// In ar, this message translates to:
  /// **'اعتماد الهدف'**
  String get familyApproveGoal;

  /// No description provided for @familyChatEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد رسائل بعد'**
  String get familyChatEmptyTitle;

  /// No description provided for @familyChatEmptyMessage.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ المحادثة بإرسال أول رسالة لعائلتك'**
  String get familyChatEmptyMessage;

  /// No description provided for @familyChatAddTasks.
  ///
  /// In ar, this message translates to:
  /// **'أضف مهام'**
  String get familyChatAddTasks;

  /// No description provided for @familyChatAskGroceries.
  ///
  /// In ar, this message translates to:
  /// **'اطلب بقالة'**
  String get familyChatAskGroceries;

  /// No description provided for @familyChatAskZad.
  ///
  /// In ar, this message translates to:
  /// **'استشر @Zad'**
  String get familyChatAskZad;

  /// Zad's name over a poll it sent.
  ///
  /// In ar, this message translates to:
  /// **'زاد'**
  String get familyZadName;

  /// No description provided for @familyVoiceMessage.
  ///
  /// In ar, this message translates to:
  /// **'رسالة صوتية'**
  String get familyVoiceMessage;

  /// No description provided for @familyUnpin.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء التثبيت'**
  String get familyUnpin;

  /// No description provided for @familyPin.
  ///
  /// In ar, this message translates to:
  /// **'تثبيت'**
  String get familyPin;

  /// No description provided for @familyReact.
  ///
  /// In ar, this message translates to:
  /// **'تفاعل'**
  String get familyReact;

  /// No description provided for @familySosFrom.
  ///
  /// In ar, this message translates to:
  /// **'نداء طوارئ من {name}!'**
  String familySosFrom(String name);

  /// No description provided for @familyPurchaseRequestFrom.
  ///
  /// In ar, this message translates to:
  /// **'طلب شراء من {name}'**
  String familyPurchaseRequestFrom(String name);

  /// No description provided for @familyApproveAndDeduct.
  ///
  /// In ar, this message translates to:
  /// **'موافقة وخصم'**
  String get familyApproveAndDeduct;

  /// No description provided for @familyApproved.
  ///
  /// In ar, this message translates to:
  /// **'تمت الموافقة'**
  String get familyApproved;

  /// No description provided for @familyRejected.
  ///
  /// In ar, this message translates to:
  /// **'مرفوض'**
  String get familyRejected;

  /// No description provided for @familyPollFrom.
  ///
  /// In ar, this message translates to:
  /// **'تصويت من {name}'**
  String familyPollFrom(String name);

  /// No description provided for @familyPollTimeCloses.
  ///
  /// In ar, this message translates to:
  /// **'{time} · بيقفل {when}'**
  String familyPollTimeCloses(String time, String when);

  /// No description provided for @familyPollClose.
  ///
  /// In ar, this message translates to:
  /// **'اقفل التصويت'**
  String get familyPollClose;

  /// No description provided for @familyPollClosedNoVotes.
  ///
  /// In ar, this message translates to:
  /// **'اتقفل من غير أصوات'**
  String get familyPollClosedNoVotes;

  /// No description provided for @familyPollClosedTie.
  ///
  /// In ar, this message translates to:
  /// **'اتقفل بتعادل — القرار لكم'**
  String get familyPollClosedTie;

  /// No description provided for @familyPollAdultsAgreed.
  ///
  /// In ar, this message translates to:
  /// **'الكبار كلهم اتفقوا على «{option}» ✅'**
  String familyPollAdultsAgreed(String option);

  /// No description provided for @familyPollMajority.
  ///
  /// In ar, this message translates to:
  /// **'الأغلبية اختارت «{option}»'**
  String familyPollMajority(String option);

  /// No description provided for @familyClosesWithinHour.
  ///
  /// In ar, this message translates to:
  /// **'خلال ساعة'**
  String get familyClosesWithinHour;

  /// No description provided for @familyClosesInHours.
  ///
  /// In ar, this message translates to:
  /// **'بعد {hours} ساعة'**
  String familyClosesInHours(int hours);

  /// No description provided for @familyClosesTomorrow.
  ///
  /// In ar, this message translates to:
  /// **'بكرة'**
  String get familyClosesTomorrow;

  /// No description provided for @familyClosesInDays.
  ///
  /// In ar, this message translates to:
  /// **'بعد {days} أيام'**
  String familyClosesInDays(int days);

  /// No description provided for @familyQuickReplies.
  ///
  /// In ar, this message translates to:
  /// **'ردود سريعة'**
  String get familyQuickReplies;

  /// No description provided for @familySosShort.
  ///
  /// In ar, this message translates to:
  /// **'نداء طوارئ'**
  String get familySosShort;

  /// No description provided for @familyAskMoney.
  ///
  /// In ar, this message translates to:
  /// **'طلب مصروف'**
  String get familyAskMoney;

  /// No description provided for @familyPollShort.
  ///
  /// In ar, this message translates to:
  /// **'تصويت'**
  String get familyPollShort;

  /// No description provided for @familyChatHint.
  ///
  /// In ar, this message translates to:
  /// **'اكتب رسالة أو @Zad...'**
  String get familyChatHint;

  /// No description provided for @familySend.
  ///
  /// In ar, this message translates to:
  /// **'إرسال'**
  String get familySend;

  /// No description provided for @familySomeoneInFamily.
  ///
  /// In ar, this message translates to:
  /// **'حد من العيلة'**
  String get familySomeoneInFamily;

  /// Google Play's prominent disclosure for background location, read by the child before agreeing.
  ///
  /// In ar, this message translates to:
  /// **'زاد هيعرف لما تدخل أو تخرج من الأماكن اللي {asker} يحددها (زي المدرسة) — حتى والتطبيق مقفول — ويقوله لو خرجت في المواعيد اللي حددها. مش هيتبعت مكانك طول الوقت ولا خط سيرك. هيفضل فيه إشعار ظاهر طول ما المشاركة شغالة، وتقدر توقفها من «عيلتي» في أي وقت. في الخطوة الجاية اختار «السماح طول الوقت».'**
  String familyLocationDisclosure(String asker);

  /// No description provided for @familyServerUnreachable.
  ///
  /// In ar, this message translates to:
  /// **'مقدرتش أوصل للسيرفر. جرّب تاني.'**
  String get familyServerUnreachable;

  /// No description provided for @familyShareComingGoingTitle.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة دخولك وخروجك'**
  String get familyShareComingGoingTitle;

  /// No description provided for @familyNotNow.
  ///
  /// In ar, this message translates to:
  /// **'مش دلوقتي'**
  String get familyNotNow;

  /// No description provided for @familyAgreeContinue.
  ///
  /// In ar, this message translates to:
  /// **'موافق، كمّل'**
  String get familyAgreeContinue;

  /// No description provided for @familyAcceptedNeedAlways.
  ///
  /// In ar, this message translates to:
  /// **'وافقت، بس محتاج «السماح طول الوقت» للموقع عشان يشتغل والتطبيق مقفول.'**
  String get familyAcceptedNeedAlways;

  /// No description provided for @familyAcceptedZones.
  ///
  /// In ar, this message translates to:
  /// **'وافقت — هيشتغل على الأماكن اللي هيحددها.'**
  String get familyAcceptedZones;

  /// No description provided for @familyAcceptedOffline.
  ///
  /// In ar, this message translates to:
  /// **'وافقت. هكمّل لما النت يرجع.'**
  String get familyAcceptedOffline;

  /// No description provided for @familyFollowRequests.
  ///
  /// In ar, this message translates to:
  /// **'طلبات متابعة'**
  String get familyFollowRequests;

  /// No description provided for @familyFollowRequestsHint.
  ///
  /// In ar, this message translates to:
  /// **'محدش بيشوف حاجة غير بموافقتك، وتقدر تلغي في أي وقت.'**
  String get familyFollowRequestsHint;

  /// No description provided for @familyDeclinedFollow.
  ///
  /// In ar, this message translates to:
  /// **'تمام، مش هيشوفها.'**
  String get familyDeclinedFollow;

  /// No description provided for @familyNo.
  ///
  /// In ar, this message translates to:
  /// **'لأ'**
  String get familyNo;

  /// No description provided for @familyAcceptedScope.
  ///
  /// In ar, this message translates to:
  /// **'وافقت — يقدر يتابع {scope}.'**
  String familyAcceptedScope(String scope);

  /// No description provided for @familyAgree.
  ///
  /// In ar, this message translates to:
  /// **'وافق'**
  String get familyAgree;

  /// No description provided for @familyWhoFollowsYou.
  ///
  /// In ar, this message translates to:
  /// **'مين بيتابعك'**
  String get familyWhoFollowsYou;

  /// No description provided for @familyFollowStopped.
  ///
  /// In ar, this message translates to:
  /// **'اتلغت المتابعة.'**
  String get familyFollowStopped;

  /// No description provided for @familyFollowRequestSent.
  ///
  /// In ar, this message translates to:
  /// **'اتبعت الطلب — هيظهرلك لما يوافق.'**
  String get familyFollowRequestSent;

  /// No description provided for @familyFollowRequestFailed.
  ///
  /// In ar, this message translates to:
  /// **'مقدرتش أبعت الطلب. جرّب تاني.'**
  String get familyFollowRequestFailed;

  /// No description provided for @familyFollowing.
  ///
  /// In ar, this message translates to:
  /// **'المتابعة'**
  String get familyFollowing;

  /// No description provided for @familyFollowLoadFailed.
  ///
  /// In ar, this message translates to:
  /// **'مقدرتش أجيب المتابعة دلوقتي.'**
  String get familyFollowLoadFailed;

  /// No description provided for @familyFollowLoading.
  ///
  /// In ar, this message translates to:
  /// **'بجيب اللي متشارك…'**
  String get familyFollowLoading;

  /// No description provided for @familyScopeStatus.
  ///
  /// In ar, this message translates to:
  /// **'{scope}: {status}'**
  String familyScopeStatus(String scope, String status);

  /// No description provided for @familyShareNotAsked.
  ///
  /// In ar, this message translates to:
  /// **'مش متطلبة'**
  String get familyShareNotAsked;

  /// No description provided for @familySharePending.
  ///
  /// In ar, this message translates to:
  /// **'مستني موافقته'**
  String get familySharePending;

  /// No description provided for @familyShareGranted.
  ///
  /// In ar, this message translates to:
  /// **'وافق ✅'**
  String get familyShareGranted;

  /// No description provided for @familyShareDeclined.
  ///
  /// In ar, this message translates to:
  /// **'رفض'**
  String get familyShareDeclined;

  /// No description provided for @familyShareRevoked.
  ///
  /// In ar, this message translates to:
  /// **'اتلغت'**
  String get familyShareRevoked;

  /// No description provided for @familyAskToFollow.
  ///
  /// In ar, this message translates to:
  /// **'اطلب متابعة'**
  String get familyAskToFollow;

  /// No description provided for @familyWhatToFollow.
  ///
  /// In ar, this message translates to:
  /// **'عايز تتابع إيه؟'**
  String get familyWhatToFollow;

  /// No description provided for @familyWhatToFollowHint.
  ///
  /// In ar, this message translates to:
  /// **'هيوصله طلب ويختار هو. مفيش حاجة هتبان قبل موافقته.'**
  String get familyWhatToFollowHint;

  /// No description provided for @familySendRequest.
  ///
  /// In ar, this message translates to:
  /// **'ابعت الطلب'**
  String get familySendRequest;

  /// No description provided for @familyDoseMissed.
  ///
  /// In ar, this message translates to:
  /// **'❌ فاتت'**
  String get familyDoseMissed;

  /// No description provided for @familyDoseDue.
  ///
  /// In ar, this message translates to:
  /// **'⏰ وقتها'**
  String get familyDoseDue;

  /// No description provided for @familyDoseNoTimes.
  ///
  /// In ar, this message translates to:
  /// **'{name}: من غير مواعيد'**
  String familyDoseNoTimes(String name);

  /// No description provided for @familyMedicinesToday.
  ///
  /// In ar, this message translates to:
  /// **'الأدوية النهارده'**
  String get familyMedicinesToday;

  /// No description provided for @familyNoMedicines.
  ///
  /// In ar, this message translates to:
  /// **'مفيش أدوية متسجلة.'**
  String get familyNoMedicines;

  /// No description provided for @familySpendingLast30.
  ///
  /// In ar, this message translates to:
  /// **'المصروف آخر ٣٠ يوم'**
  String get familySpendingLast30;

  /// No description provided for @familyTasksAndAppointments.
  ///
  /// In ar, this message translates to:
  /// **'المهام والمواعيد'**
  String get familyTasksAndAppointments;

  /// No description provided for @familyNoOpenTasks.
  ///
  /// In ar, this message translates to:
  /// **'مفيش مهام مفتوحة'**
  String get familyNoOpenTasks;

  /// No description provided for @familyOpenTasksStill.
  ///
  /// In ar, this message translates to:
  /// **'{count} مهام لسه مفتوحة'**
  String familyOpenTasksStill(int count);

  /// No description provided for @familyReportLoading.
  ///
  /// In ar, this message translates to:
  /// **'بجيب…'**
  String get familyReportLoading;

  /// No description provided for @familyReportMissedSuffix.
  ///
  /// In ar, this message translates to:
  /// **' — {count} فاتت'**
  String familyReportMissedSuffix(int count);

  /// No description provided for @familyReportNoDosesToday.
  ///
  /// In ar, this message translates to:
  /// **'مفيش جرعات النهارده'**
  String get familyReportNoDosesToday;

  /// No description provided for @familyReportDoses.
  ///
  /// In ar, this message translates to:
  /// **'جرعات: {taken} من {total}{late}'**
  String familyReportDoses(int taken, int total, String late);

  /// No description provided for @familyReportSpent30.
  ///
  /// In ar, this message translates to:
  /// **'صرف ٣٠ يوم: {amount}'**
  String familyReportSpent30(String amount);

  /// No description provided for @familyReportOpenTasks.
  ///
  /// In ar, this message translates to:
  /// **'{count} مهام مفتوحة'**
  String familyReportOpenTasks(int count);

  /// No description provided for @familyZoneInside.
  ///
  /// In ar, this message translates to:
  /// **'جوه {place}'**
  String familyZoneInside(String place);

  /// No description provided for @familyZoneLeft.
  ///
  /// In ar, this message translates to:
  /// **'خرج من {place}'**
  String familyZoneLeft(String place);

  /// No description provided for @familyZoneUnknown.
  ///
  /// In ar, this message translates to:
  /// **'{place}: لسه'**
  String familyZoneUnknown(String place);

  /// No description provided for @familyReportNothingShared.
  ///
  /// In ar, this message translates to:
  /// **'لسه ماوافقش على أي متابعة'**
  String get familyReportNothingShared;

  /// No description provided for @familyReportNotShared.
  ///
  /// In ar, this message translates to:
  /// **'مش متشارك: {scopes}'**
  String familyReportNotShared(String scopes);

  /// Joins names or items in one line.
  ///
  /// In ar, this message translates to:
  /// **'، '**
  String get familyListSeparator;

  /// No description provided for @familyReportHint.
  ///
  /// In ar, this message translates to:
  /// **'اللي كل فرد وافق يشاركه بس — والباقي بيبان بعد موافقته.'**
  String get familyReportHint;

  /// No description provided for @familyReportNoMembers.
  ///
  /// In ar, this message translates to:
  /// **'لسه محدش انضم للعيلة. ابعت كود الدعوة من «عيلتي».'**
  String get familyReportNoMembers;

  /// No description provided for @familyMemberFallback.
  ///
  /// In ar, this message translates to:
  /// **'فرد من العيلة'**
  String get familyMemberFallback;

  /// Weekday by d + its number, Sunday = d0.
  ///
  /// In ar, this message translates to:
  /// **'{day, select, d0{الأحد} d1{الاتنين} d2{التلات} d3{الأربع} d4{الخميس} d5{الجمعة} d6{السبت} other{}}'**
  String familyWeekday(String day);

  /// No description provided for @familyZoneNoMoves.
  ///
  /// In ar, this message translates to:
  /// **'لسه مفيش دخول ولا خروج'**
  String get familyZoneNoMoves;

  /// No description provided for @familyZoneInsideSince.
  ///
  /// In ar, this message translates to:
  /// **'جوه من {day}{time}'**
  String familyZoneInsideSince(String day, String time);

  /// No description provided for @familyZoneLeftAt.
  ///
  /// In ar, this message translates to:
  /// **'خرج {day}{time}'**
  String familyZoneLeftAt(String day, String time);

  /// No description provided for @familyZoneSaved.
  ///
  /// In ar, this message translates to:
  /// **'اتحفظ «{place}» — هيوصله إشعار بيه.'**
  String familyZoneSaved(String place);

  /// No description provided for @familyZoneSaveFailed.
  ///
  /// In ar, this message translates to:
  /// **'مقدرتش أحفظ النطاق. جرّب تاني.'**
  String get familyZoneSaveFailed;

  /// No description provided for @familyZoneRemoved.
  ///
  /// In ar, this message translates to:
  /// **'اتشال «{place}».'**
  String familyZoneRemoved(String place);

  /// No description provided for @familyZoneRemoveFailed.
  ///
  /// In ar, this message translates to:
  /// **'مقدرتش أشيله. جرّب تاني.'**
  String get familyZoneRemoveFailed;

  /// No description provided for @familyPlaces.
  ///
  /// In ar, this message translates to:
  /// **'الأماكن'**
  String get familyPlaces;

  /// No description provided for @familyNoZones.
  ///
  /// In ar, this message translates to:
  /// **'لسه مفيش نطاقات. وانت في المدرسة نفسها، دوس «ضيف نطاق».'**
  String get familyNoZones;

  /// No description provided for @familyRemoveZone.
  ///
  /// In ar, this message translates to:
  /// **'شيل النطاق'**
  String get familyRemoveZone;

  /// No description provided for @familyAddZone.
  ///
  /// In ar, this message translates to:
  /// **'ضيف نطاق'**
  String get familyAddZone;

  /// No description provided for @familyZoneSchool.
  ///
  /// In ar, this message translates to:
  /// **'مدرسة'**
  String get familyZoneSchool;

  /// No description provided for @familyZoneClub.
  ///
  /// In ar, this message translates to:
  /// **'نادي'**
  String get familyZoneClub;

  /// No description provided for @familyZoneHome.
  ///
  /// In ar, this message translates to:
  /// **'البيت'**
  String get familyZoneHome;

  /// No description provided for @familyZoneOther.
  ///
  /// In ar, this message translates to:
  /// **'مكان تاني'**
  String get familyZoneOther;

  /// No description provided for @familyLocationFailed.
  ///
  /// In ar, this message translates to:
  /// **'مقدرتش أعرف مكانك. شغّل الموقع وجرّب تاني.'**
  String get familyLocationFailed;

  /// No description provided for @familyNewZone.
  ///
  /// In ar, this message translates to:
  /// **'نطاق جديد'**
  String get familyNewZone;

  /// No description provided for @familyNewZoneHint.
  ///
  /// In ar, this message translates to:
  /// **'هيوصلك تنبيه لو خرج منه في الأيام والساعات دي. برّاها بيتسجل من غير تنبيه.'**
  String get familyNewZoneHint;

  /// No description provided for @familyZoneNameLabel.
  ///
  /// In ar, this message translates to:
  /// **'اسمه'**
  String get familyZoneNameLabel;

  /// No description provided for @familyZoneNameHint.
  ///
  /// In ar, this message translates to:
  /// **'مدرسة النيل'**
  String get familyZoneNameHint;

  /// No description provided for @familyUseMyLocation.
  ///
  /// In ar, this message translates to:
  /// **'استخدم المكان اللي أنا فيه دلوقتي'**
  String get familyUseMyLocation;

  /// No description provided for @familyLocationSet.
  ///
  /// In ar, this message translates to:
  /// **'اتحدد المكان ✓ — دوس تاني لو اتحركت'**
  String get familyLocationSet;

  /// No description provided for @familyBeThere.
  ///
  /// In ar, this message translates to:
  /// **'لازم تكون في المكان نفسه وانت بتحدده.'**
  String get familyBeThere;

  /// No description provided for @familyZoneRadius.
  ///
  /// In ar, this message translates to:
  /// **'قد إيه حواليه'**
  String get familyZoneRadius;

  /// No description provided for @familyMeters.
  ///
  /// In ar, this message translates to:
  /// **'{meters} م'**
  String familyMeters(int meters);

  /// No description provided for @familyAlertDays.
  ///
  /// In ar, this message translates to:
  /// **'أيام التنبيه'**
  String get familyAlertDays;

  /// No description provided for @familyAlertHours.
  ///
  /// In ar, this message translates to:
  /// **'ساعات التنبيه'**
  String get familyAlertHours;

  /// No description provided for @familyFromTime.
  ///
  /// In ar, this message translates to:
  /// **'من {time}'**
  String familyFromTime(String time);

  /// No description provided for @familyToTime.
  ///
  /// In ar, this message translates to:
  /// **'لحد {time}'**
  String familyToTime(String time);

  /// No description provided for @familyHoursOrder.
  ///
  /// In ar, this message translates to:
  /// **'ساعة البداية لازم تبقى قبل النهاية.'**
  String get familyHoursOrder;

  /// No description provided for @familySaveZone.
  ///
  /// In ar, this message translates to:
  /// **'احفظ النطاق'**
  String get familySaveZone;

  /// Disclosure before Zad reads the writer's family-chat messages.
  ///
  /// In ar, this message translates to:
  /// **'زاد هيقرا رسايلك انت بس في شات العيلة — مش رسايل حد تاني ماوافقش — عشان يفهم طلبات البيت زي «محتاجين عيش» ويرد لو حد من العيلة سأله عن اللي اتقال. الرسايل بتتبعت لموديل ذكاء اصطناعي (Google Gemini) عشان تتفهم. العيلة كلها هتشوف إنك موافق، وتقدر توقف في أي وقت من هنا.'**
  String get familyChatReadingDisclosure;

  /// No description provided for @familyChatReadingTitle.
  ///
  /// In ar, this message translates to:
  /// **'زاد يقرا رسايلك؟'**
  String get familyChatReadingTitle;

  /// No description provided for @familyAgreeShort.
  ///
  /// In ar, this message translates to:
  /// **'موافق'**
  String get familyAgreeShort;

  /// No description provided for @familyChatReadingOn.
  ///
  /// In ar, this message translates to:
  /// **'تمام — زاد هيقرا رسايلك.'**
  String get familyChatReadingOn;

  /// No description provided for @familyChatReadingOff.
  ///
  /// In ar, this message translates to:
  /// **'وقفت — زاد مش هيقرا رسايلك.'**
  String get familyChatReadingOff;

  /// No description provided for @familyChatReadingNone.
  ///
  /// In ar, this message translates to:
  /// **'زاد مش بيقرا رسايل الشات'**
  String get familyChatReadingNone;

  /// No description provided for @familyChatReadingWho.
  ///
  /// In ar, this message translates to:
  /// **'زاد بيقرا رسايل: {names}'**
  String familyChatReadingWho(String names);

  /// No description provided for @familyChatReadingStopMine.
  ///
  /// In ar, this message translates to:
  /// **'وقّف لرسايلي'**
  String get familyChatReadingStopMine;

  /// No description provided for @familyChatReadingAllowMine.
  ///
  /// In ar, this message translates to:
  /// **'خلّيه يقرا رسايلي'**
  String get familyChatReadingAllowMine;

  /// No description provided for @profileTitle.
  ///
  /// In ar, this message translates to:
  /// **'حسابي'**
  String get profileTitle;

  /// No description provided for @profileSectionBrain.
  ///
  /// In ar, this message translates to:
  /// **'عقل زاد'**
  String get profileSectionBrain;

  /// No description provided for @profileMemoryTitle.
  ///
  /// In ar, this message translates to:
  /// **'زاد عارف عني إيه'**
  String get profileMemoryTitle;

  /// No description provided for @profileMemorySubtitle.
  ///
  /// In ar, this message translates to:
  /// **'زاد بيتعلم من صرفك ومخزونك عشان يساعدك — شوف اللي اتعلمه وامسح أي حاجة'**
  String get profileMemorySubtitle;

  /// No description provided for @profileActionLogTitle.
  ///
  /// In ar, this message translates to:
  /// **'سجل تعديلات زاد'**
  String get profileActionLogTitle;

  /// No description provided for @profileActionLogSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'كل حاجة زاد سجّلها أو عدّلها لك'**
  String get profileActionLogSubtitle;

  /// No description provided for @profileAlertsTitle.
  ///
  /// In ar, this message translates to:
  /// **'تنبيهات المساعد الذكي'**
  String get profileAlertsTitle;

  /// No description provided for @profileAlertsSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'التحكم في التنبيهات الذكية'**
  String get profileAlertsSubtitle;

  /// No description provided for @profileNewGoalTitle.
  ///
  /// In ar, this message translates to:
  /// **'هدف حياة جديد'**
  String get profileNewGoalTitle;

  /// No description provided for @profileNewGoalSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'خلّي زاد يتابع معاك هدف توفير أو عادة'**
  String get profileNewGoalSubtitle;

  /// No description provided for @profileSectionMeFamily.
  ///
  /// In ar, this message translates to:
  /// **'أنا وعيلتي'**
  String get profileSectionMeFamily;

  /// No description provided for @profileEditTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الملف الشخصي'**
  String get profileEditTitle;

  /// No description provided for @profileEditSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'الاسم أو اللقب'**
  String get profileEditSubtitle;

  /// No description provided for @profileFamilyManageTitle.
  ///
  /// In ar, this message translates to:
  /// **'إدارة العائلة'**
  String get profileFamilyManageTitle;

  /// No description provided for @profileFamilyManageSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'الأعضاء والصلاحيات'**
  String get profileFamilyManageSubtitle;

  /// No description provided for @profileRegionalTitle.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات الإقليمية'**
  String get profileRegionalTitle;

  /// No description provided for @profileRegionalSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'البلد والعملة'**
  String get profileRegionalSubtitle;

  /// No description provided for @profileSectionMoney.
  ///
  /// In ar, this message translates to:
  /// **'فلوسي'**
  String get profileSectionMoney;

  /// No description provided for @profileBudgetPaymentTitle.
  ///
  /// In ar, this message translates to:
  /// **'الميزانية وطرق الدفع'**
  String get profileBudgetPaymentTitle;

  /// No description provided for @profileBudgetPaymentSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'الميزانية الشهرية والربط البنكي'**
  String get profileBudgetPaymentSubtitle;

  /// No description provided for @profileStatementTitle.
  ///
  /// In ar, this message translates to:
  /// **'استيراد كشف حساب'**
  String get profileStatementTitle;

  /// No description provided for @profileStatementSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'استورد كشف حساب CSV من البنك'**
  String get profileStatementSubtitle;

  /// No description provided for @profileSectionMyZad.
  ///
  /// In ar, this message translates to:
  /// **'زاد بتاعي'**
  String get profileSectionMyZad;

  /// No description provided for @profileAchievementsTitle.
  ///
  /// In ar, this message translates to:
  /// **'الإنجازات والرتب'**
  String get profileAchievementsTitle;

  /// No description provided for @profileAchievementsSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'نقاطك وإنجازاتك من المساهمة بالأسعار'**
  String get profileAchievementsSubtitle;

  /// No description provided for @profileSectionHelp.
  ///
  /// In ar, this message translates to:
  /// **'المساعدة'**
  String get profileSectionHelp;

  /// No description provided for @profileSupportTitle.
  ///
  /// In ar, this message translates to:
  /// **'الدعم الفني'**
  String get profileSupportTitle;

  /// No description provided for @profileSupportSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'شكوى أو مشكلة؟ كلّم فريق الدعم'**
  String get profileSupportSubtitle;

  /// No description provided for @profileTermsTitle.
  ///
  /// In ar, this message translates to:
  /// **'الشروط والأحكام'**
  String get profileTermsTitle;

  /// No description provided for @profileTermsSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'سياسة الاستخدام والخصوصية'**
  String get profileTermsSubtitle;

  /// No description provided for @profileSectionAccount.
  ///
  /// In ar, this message translates to:
  /// **'الحساب'**
  String get profileSectionAccount;

  /// No description provided for @profileDeleteAccountTitle.
  ///
  /// In ar, this message translates to:
  /// **'حذف الحساب'**
  String get profileDeleteAccountTitle;

  /// No description provided for @profileDeleteAccountSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'حذف الحساب نهائياً'**
  String get profileDeleteAccountSubtitle;

  /// No description provided for @profileSignOut.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get profileSignOut;

  /// No description provided for @profileDeleteAccountBody.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت متأكد من حذف حسابك نهائياً؟ لا يمكن التراجع عن هذا الإجراء.'**
  String get profileDeleteAccountBody;

  /// No description provided for @profileDeleteAccountConfirm.
  ///
  /// In ar, this message translates to:
  /// **'نعم، احذف الحساب'**
  String get profileDeleteAccountConfirm;

  /// No description provided for @profileDeleteAccountFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذر حذف الحساب. تحقق من الاتصال وحاول مرة أخرى.'**
  String get profileDeleteAccountFailed;

  /// No description provided for @profileSaved.
  ///
  /// In ar, this message translates to:
  /// **'تم حفظ التغييرات'**
  String get profileSaved;

  /// No description provided for @profileSaveFailedRetry.
  ///
  /// In ar, this message translates to:
  /// **'تعذر حفظ التغييرات — تحقق من الاتصال وحاول مرة أخرى'**
  String get profileSaveFailedRetry;

  /// No description provided for @profileEditName.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الاسم'**
  String get profileEditName;

  /// No description provided for @profileName.
  ///
  /// In ar, this message translates to:
  /// **'الاسم'**
  String get profileName;

  /// No description provided for @profileGoalName.
  ///
  /// In ar, this message translates to:
  /// **'اسم الهدف'**
  String get profileGoalName;

  /// No description provided for @profileGoalMetricEgypt.
  ///
  /// In ar, this message translates to:
  /// **'إزاي بنقيسه؟ (مثال: 500 جنيه شهرياً)'**
  String get profileGoalMetricEgypt;

  /// No description provided for @profileGoalMetricOther.
  ///
  /// In ar, this message translates to:
  /// **'إزاي بنقيسه؟ (مثال: 500 ريال شهرياً)'**
  String get profileGoalMetricOther;

  /// No description provided for @profileGoalDeadline.
  ///
  /// In ar, this message translates to:
  /// **'الاستحقاق (اختياري)'**
  String get profileGoalDeadline;

  /// No description provided for @profileGoalDeadlineHint.
  ///
  /// In ar, this message translates to:
  /// **'مثال: 2026-12-31'**
  String get profileGoalDeadlineHint;

  /// No description provided for @profileSaveShort.
  ///
  /// In ar, this message translates to:
  /// **'احفظ'**
  String get profileSaveShort;

  /// No description provided for @profileEmail.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني'**
  String get profileEmail;

  /// No description provided for @profileAliasLabel.
  ///
  /// In ar, this message translates to:
  /// **'الاسم / اللقب'**
  String get profileAliasLabel;

  /// No description provided for @profileAliasHint.
  ///
  /// In ar, this message translates to:
  /// **'مثال: الأب'**
  String get profileAliasHint;

  /// No description provided for @profileSaveChanges.
  ///
  /// In ar, this message translates to:
  /// **'حفظ التغييرات'**
  String get profileSaveChanges;

  /// No description provided for @profileCountry.
  ///
  /// In ar, this message translates to:
  /// **'البلد'**
  String get profileCountry;

  /// No description provided for @profileCurrency.
  ///
  /// In ar, this message translates to:
  /// **'العملة'**
  String get profileCurrency;

  /// No description provided for @profileCurrencyAuto.
  ///
  /// In ar, this message translates to:
  /// **'العملة بتتحدد تلقائياً حسب البلد المختار فوق'**
  String get profileCurrencyAuto;

  /// No description provided for @profileChangeCountryTitle.
  ///
  /// In ar, this message translates to:
  /// **'تغيّر البلد لـ {country}؟'**
  String profileChangeCountryTitle(String country);

  /// No description provided for @profileCurrencyWillBe.
  ///
  /// In ar, this message translates to:
  /// **'العملة هتبقى {symbol} ({code}).'**
  String profileCurrencyWillBe(String symbol, String code);

  /// No description provided for @profileLimitConverts.
  ///
  /// In ar, this message translates to:
  /// **'سقفك الشهري هيتحوّل من {from} {fromSymbol} إلى {to} {toSymbol}، وميزانيات الفئات كمان.'**
  String profileLimitConverts(
    String from,
    String fromSymbol,
    String to,
    String toSymbol,
  );

  /// No description provided for @profileChange.
  ///
  /// In ar, this message translates to:
  /// **'غيّر'**
  String get profileChange;

  /// No description provided for @profileNoRate.
  ///
  /// In ar, this message translates to:
  /// **'مش عارف سعر التحويل، فسقفك الشهري هيفضل بنفس الرقم — راجعه بعد التغيير.'**
  String get profileNoRate;

  /// No description provided for @profileKidsRelockTitle.
  ///
  /// In ar, this message translates to:
  /// **'إعادة قفل وضع الأطفال'**
  String get profileKidsRelockTitle;

  /// No description provided for @profileKidsRelockSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'يرجع الجهاز لوضع الأطفال'**
  String get profileKidsRelockSubtitle;

  /// No description provided for @profileKidsModeTitle.
  ///
  /// In ar, this message translates to:
  /// **'تبديل لوضع الأطفال'**
  String get profileKidsModeTitle;

  /// No description provided for @profileKidsModeSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'لما تدي الجهاز لطفلك مؤقتاً — الخروج محتاج PIN'**
  String get profileKidsModeSubtitle;

  /// No description provided for @profileNoFamily.
  ///
  /// In ar, this message translates to:
  /// **'أنت لست منضماً لأي عائلة حالياً.'**
  String get profileNoFamily;

  /// No description provided for @profileFamilyInviteCode.
  ///
  /// In ar, this message translates to:
  /// **'كود دعوة العائلة'**
  String get profileFamilyInviteCode;

  /// No description provided for @profileFamilyMembers.
  ///
  /// In ar, this message translates to:
  /// **'أفراد العائلة'**
  String get profileFamilyMembers;

  /// No description provided for @profileRoleAdmin.
  ///
  /// In ar, this message translates to:
  /// **'مدير العائلة'**
  String get profileRoleAdmin;

  /// No description provided for @profileRoleChild.
  ///
  /// In ar, this message translates to:
  /// **'ابن/ابنة'**
  String get profileRoleChild;

  /// No description provided for @profileRoleMember.
  ///
  /// In ar, this message translates to:
  /// **'عضو'**
  String get profileRoleMember;

  /// No description provided for @profileKickFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل طرد العضو، يرجى المحاولة لاحقاً.'**
  String get profileKickFailed;

  /// No description provided for @profileRoleChangeFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل تغيير الصلاحية، يرجى المحاولة لاحقاً.'**
  String get profileRoleChangeFailed;

  /// No description provided for @profileMakeAdmin.
  ///
  /// In ar, this message translates to:
  /// **'ترقية لمدير (Admin)'**
  String get profileMakeAdmin;

  /// No description provided for @profileMakeMember.
  ///
  /// In ar, this message translates to:
  /// **'إرجاع لعضو (Member)'**
  String get profileMakeMember;

  /// No description provided for @profileMakeChild.
  ///
  /// In ar, this message translates to:
  /// **'تعيين كابن/ابنة'**
  String get profileMakeChild;

  /// No description provided for @profileKick.
  ///
  /// In ar, this message translates to:
  /// **'طرد العضو'**
  String get profileKick;

  /// No description provided for @profilePaymentBudgetTitle.
  ///
  /// In ar, this message translates to:
  /// **'طرق الدفع والميزانية'**
  String get profilePaymentBudgetTitle;

  /// No description provided for @profileCurrentMonthlyBudget.
  ///
  /// In ar, this message translates to:
  /// **'الميزانية الشهرية الحالية'**
  String get profileCurrentMonthlyBudget;

  /// No description provided for @profileDiagNoPermission.
  ///
  /// In ar, this message translates to:
  /// **'❌ الصلاحية مش ممنوحة — فعّلها من إعدادات الوصول للإشعارات'**
  String get profileDiagNoPermission;

  /// No description provided for @profileDiagNotBound.
  ///
  /// In ar, this message translates to:
  /// **'❌ السيرفس مش مربوط — اضغط زر إعادة الربط'**
  String get profileDiagNotBound;

  /// No description provided for @profileDiagNoNotifications.
  ///
  /// In ar, this message translates to:
  /// **'❌ السيرفس مربوط بس مش بيوصلوش إشعارات — جرب requestRebind'**
  String get profileDiagNoNotifications;

  /// No description provided for @profileDiagWaitingTest.
  ///
  /// In ar, this message translates to:
  /// **'⏳ مستني وصول الإشعار التجريبي للمستمع...'**
  String get profileDiagWaitingTest;

  /// No description provided for @profileDiagAllWorking.
  ///
  /// In ar, this message translates to:
  /// **'✅ الرصد شغال بالكامل'**
  String get profileDiagAllWorking;

  /// No description provided for @profileDiagListenerWorking.
  ///
  /// In ar, this message translates to:
  /// **'✅ المستمع مسكه والفلترة شغالة'**
  String get profileDiagListenerWorking;

  /// No description provided for @profileDiagUnknown.
  ///
  /// In ar, this message translates to:
  /// **'❓ حالة غير معروفة — جرب تاني'**
  String get profileDiagUnknown;

  /// No description provided for @profileParseOk.
  ///
  /// In ar, this message translates to:
  /// **'نجح التحليل ✓\nالمبلغ: {amount}\nالتاجر: —\nالنوع: {kind}'**
  String profileParseOk(String amount, String kind);

  /// No description provided for @profileParseCompleted.
  ///
  /// In ar, this message translates to:
  /// **'عملية مكتملة'**
  String get profileParseCompleted;

  /// No description provided for @profileParsePending.
  ///
  /// In ar, this message translates to:
  /// **'معلّقة'**
  String get profileParsePending;

  /// No description provided for @profileParseInfo.
  ///
  /// In ar, this message translates to:
  /// **'معلومة'**
  String get profileParseInfo;

  /// No description provided for @profileParseServer.
  ///
  /// In ar, this message translates to:
  /// **'تتأكد على السيرفر'**
  String get profileParseServer;

  /// No description provided for @profileParseFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل التحليل — الرسالة العينة معملهاش parser'**
  String get profileParseFailed;

  /// No description provided for @profileTest.
  ///
  /// In ar, this message translates to:
  /// **'اختبار'**
  String get profileTest;

  /// No description provided for @profileOk.
  ///
  /// In ar, this message translates to:
  /// **'تمام'**
  String get profileOk;

  /// No description provided for @profileBankReading.
  ///
  /// In ar, this message translates to:
  /// **'قراءة إشعارات البنك'**
  String get profileBankReading;

  /// No description provided for @profileBankReadingHint.
  ///
  /// In ar, this message translates to:
  /// **'الحالة الحقيقية للصلاحيات — لو الصلاحية متسحوبة من إعدادات النظام، هتلاقيها هنا فوراً'**
  String get profileBankReadingHint;

  /// No description provided for @profileEnable.
  ///
  /// In ar, this message translates to:
  /// **'تفعيل'**
  String get profileEnable;

  /// No description provided for @profileReaderConnection.
  ///
  /// In ar, this message translates to:
  /// **'اتصال خدمة القراءة'**
  String get profileReaderConnection;

  /// No description provided for @profileRetry.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get profileRetry;

  /// No description provided for @profileLastConnected.
  ///
  /// In ar, this message translates to:
  /// **'آخر اتصال فعلي: {time}'**
  String profileLastConnected(String time);

  /// No description provided for @profileNeverConnected.
  ///
  /// In ar, this message translates to:
  /// **'الخدمة لم تتصل بعد، حتى لو كانت الصلاحية مفعلة'**
  String get profileNeverConnected;

  /// No description provided for @profileNotificationsArriving.
  ///
  /// In ar, this message translates to:
  /// **'وصول إشعارات للجهاز'**
  String get profileNotificationsArriving;

  /// No description provided for @profileLastNotification.
  ///
  /// In ar, this message translates to:
  /// **'آخر إشعار وصل للخدمة: {time}'**
  String profileLastNotification(String time);

  /// No description provided for @profileNoNotificationYet.
  ///
  /// In ar, this message translates to:
  /// **'لم يصل أي إشعار للخدمة بعد'**
  String get profileNoNotificationYet;

  /// No description provided for @profileLastParsed.
  ///
  /// In ar, this message translates to:
  /// **'آخر عملية اتقرأت: قبل {minutes} دقيقة'**
  String profileLastParsed(int minutes);

  /// No description provided for @profileNothingParsed.
  ///
  /// In ar, this message translates to:
  /// **'لسه ما اتقرتش أي عملية'**
  String get profileNothingParsed;

  /// No description provided for @profileSendTestNotification.
  ///
  /// In ar, this message translates to:
  /// **'اختبار — اختبار زاد — عملية تجريبية'**
  String get profileSendTestNotification;

  /// No description provided for @profileRejectedTitle.
  ///
  /// In ar, this message translates to:
  /// **'آخر الرسائل اللي اترفضت'**
  String get profileRejectedTitle;

  /// No description provided for @profileRejectedHint.
  ///
  /// In ar, this message translates to:
  /// **'لو بنك أو محفظة معينة مش بتتسجل، هتلاقي السبب هنا (OTP، رسالة معلّقة، أو نص محصلش فهمه).'**
  String get profileRejectedHint;

  /// No description provided for @profileStatusOn.
  ///
  /// In ar, this message translates to:
  /// **'{label}: شغالة ✓'**
  String profileStatusOn(String label);

  /// No description provided for @profileStatusOff.
  ///
  /// In ar, this message translates to:
  /// **'{label}: مش شغالة'**
  String profileStatusOff(String label);

  /// No description provided for @profileVoiceAlertsTitle.
  ///
  /// In ar, this message translates to:
  /// **'🔔 النطق الصوتي للإشعارات والجرعات'**
  String get profileVoiceAlertsTitle;

  /// No description provided for @profileVoiceAlertsDesc.
  ///
  /// In ar, this message translates to:
  /// **'زاد تقول تذكير الدوا والمواعيد بصوتها لما التطبيق مفتوح، ولما يكون مقفول الإشعار بيبقى عليه «اسمع زاد».'**
  String get profileVoiceAlertsDesc;

  /// No description provided for @profileLowStockTitle.
  ///
  /// In ar, this message translates to:
  /// **'تنبيهات نقص المخزون'**
  String get profileLowStockTitle;

  /// No description provided for @profileLowStockDesc.
  ///
  /// In ar, this message translates to:
  /// **'يرسل إشعاراً عند اقتراب نفاذ منتج أساسي'**
  String get profileLowStockDesc;

  /// No description provided for @profileBudgetOverrunTitle.
  ///
  /// In ar, this message translates to:
  /// **'تنبيهات تخطي الميزانية'**
  String get profileBudgetOverrunTitle;

  /// No description provided for @profileBudgetOverrunDesc.
  ///
  /// In ar, this message translates to:
  /// **'تحذير مبكر عند صرف جزء كبير من الميزانية'**
  String get profileBudgetOverrunDesc;

  /// No description provided for @profileTasbihTitle.
  ///
  /// In ar, this message translates to:
  /// **'تذكير التسبيح'**
  String get profileTasbihTitle;

  /// No description provided for @profileTasbihDesc.
  ///
  /// In ar, this message translates to:
  /// **'تذكير لطيف الساعة 5 عصراً لو لسه ما سبّحتش النهاردة'**
  String get profileTasbihDesc;

  /// No description provided for @profileCompanionNapTitle.
  ///
  /// In ar, this message translates to:
  /// **'رفيق زاد يناديني لو غبت'**
  String get profileCompanionNapTitle;

  /// No description provided for @profileCompanionNapDesc.
  ///
  /// In ar, this message translates to:
  /// **'إشعار واحد لو غبت يومين، وواحد كمان بعد يومين — مش أكتر من مرة في اليوم، ومش بالليل'**
  String get profileCompanionNapDesc;

  /// No description provided for @profileCompanionCareTitle.
  ///
  /// In ar, this message translates to:
  /// **'رفيق زاد يفكّرني بأكله ومَيّته'**
  String get profileCompanionCareTitle;

  /// No description provided for @profileCompanionCareDesc.
  ///
  /// In ar, this message translates to:
  /// **'إشعار واحد لما يجوع أو يعطش، بيتأجّل كل ما تأكّله أو تسقيه — ومش بالليل'**
  String get profileCompanionCareDesc;

  /// No description provided for @profileLearnSleepTitle.
  ///
  /// In ar, this message translates to:
  /// **'زاد يتعلّم مواعيد نومي'**
  String get profileLearnSleepTitle;

  /// No description provided for @profileLearnSleepDesc.
  ///
  /// In ar, this message translates to:
  /// **'من أوقات قفل وفتح الشاشة بالليل، عشان مايبعتش تنبيهات وإنت نايم. ساعة النوم وساعة الصحيان بس اللي بتتحفظ — مش اللحظات نفسها. الجرعات والطوارئ زي ما هي.'**
  String get profileLearnSleepDesc;

  /// No description provided for @profileNotificationSound.
  ///
  /// In ar, this message translates to:
  /// **'صوت الإشعارات'**
  String get profileNotificationSound;

  /// No description provided for @profileNotificationSoundHint.
  ///
  /// In ar, this message translates to:
  /// **'اختار من أي صوت إشعار مثبّت على جهازك بدل الصوت الافتراضي'**
  String get profileNotificationSoundHint;

  /// No description provided for @profileDefaultSound.
  ///
  /// In ar, this message translates to:
  /// **'الصوت الافتراضي'**
  String get profileDefaultSound;

  /// No description provided for @supportFallback.
  ///
  /// In ar, this message translates to:
  /// **'مش قادر أرد دلوقتي. جرّب تاني كمان شوية، ولو المشكلة مستمرة افتح «سجل الأعطال» من الشاشة دي وابعته لنا — فيه اللي نحتاجه عشان نصلحها.'**
  String get supportFallback;

  /// No description provided for @supportFaqBank.
  ///
  /// In ar, this message translates to:
  /// **'عشان زاد يقرا رسايل البنك: من الرئيسية دوس «فعّل قراءة إشعارات البنك» وامشي على الخطوات. لو المفتاح رمادي أو ظهرت «إعداد مقيَّد»: افتح «معلومات التطبيق» ← ⋮ فوق ← «السماح بالإعدادات المقيدة»، وارجع فعّل الإذن. وعلى شاومي وأوبو خلي البطارية «بدون قيود» عشان مايقفش.'**
  String get supportFaqBank;

  /// No description provided for @supportFaqAllowance.
  ///
  /// In ar, this message translates to:
  /// **'من «العائلة» ← «مصاريف الأبناء» تلاقي كل طفل ورصيده. «حوّل مصروف» بيزوّد رصيده على طول. والطفل يقدر يطلب «مصروف» (بيتضاف لو وافقت) أو «أشتري حاجة» (بيتخصم لو وافقت ورصيده يكفي).'**
  String get supportFaqAllowance;

  /// No description provided for @supportFaqReceipt.
  ///
  /// In ar, this message translates to:
  /// **'صوّر الفاتورة من زرار الكاميرا. زاد بيقرا المبلغ والأصناف وتاريخ الفاتورة، وبيسجلها على يومها. راجع المبلغ والفئة قبل الحفظ، وتقدر تضيف الأصناف للمخزن في نفس الخطوة.'**
  String get supportFaqReceipt;

  /// No description provided for @supportFaqCountry.
  ///
  /// In ar, this message translates to:
  /// **'البلد والعملة بيتحددوا وقت التسجيل. لو محتاج تغيّرهم: «حسابي» ← «الإعدادات» ← السوق. التوقيت ومواعيد التذكير بيمشوا على بلد الحساب.'**
  String get supportFaqCountry;

  /// No description provided for @supportFaqVoice.
  ///
  /// In ar, this message translates to:
  /// **'دوس على المايك في الشات واتكلم، وزاد بيرد بصوت. لو الرد اتأخر أو ماجاش صوت، اتأكد من النت وجرّب تاني — والرد المكتوب بيفضل ظاهر في الشات.'**
  String get supportFaqVoice;

  /// No description provided for @supportFaqAppointments.
  ///
  /// In ar, this message translates to:
  /// **'المواعيد من «مواعيدي» ← «ميعاد جديد»، أو قول لزاد في الشات «فكرني بميعاد الدكتور يوم الخميس الساعة ٥». الأدوية من «صيدلية العائلة»، وتقدر تحدد الدوا لمين في العيلة.'**
  String get supportFaqAppointments;

  /// No description provided for @supportFaqFamily.
  ///
  /// In ar, this message translates to:
  /// **'من «العائلة» اعمل عيلة جديدة وابعت الكود لأهلك، أو دوس «انضم» واكتب الكود اللي وصلك. المسؤول بس هو اللي يقدر يغيّر الأدوار والمكافآت.'**
  String get supportFaqFamily;

  /// No description provided for @supportFaqPassword.
  ///
  /// In ar, this message translates to:
  /// **'من شاشة الدخول دوس «نسيت كلمة المرور» واكتب إيميلك، هيوصلك لينك تغيّرها منه.'**
  String get supportFaqPassword;

  /// No description provided for @supportFaqDeleteAccount.
  ///
  /// In ar, this message translates to:
  /// **'حذف الحساب من «حسابي» ← «حذف الحساب». ده بيمسح بياناتك كلها نهائياً ومايترجعش.'**
  String get supportFaqDeleteAccount;

  /// No description provided for @supportWelcome.
  ///
  /// In ar, this message translates to:
  /// **'أهلاً! أنا مساعد أسئلة استخدام تطبيق زاد — أقدر أساعدك تفهم أي ميزة أو تحل مشكلة تقنية. لو سؤالك عن بياناتك الشخصية (مصاريفك، رصيدك، اشتراكاتك)، الأفضل تسأل شات \"عقل زاد\" لأنه هو بس اللي شايف حسابك الفعلي.'**
  String get supportWelcome;

  /// No description provided for @supportContactTeam.
  ///
  /// In ar, this message translates to:
  /// **'كلّم فريق الدعم'**
  String get supportContactTeam;

  /// No description provided for @supportContactHint.
  ///
  /// In ar, this message translates to:
  /// **'اكتب المشكلة أو الشكوى، وهيوصل لفريق الدعم على طول ويردوا عليك على إيميلك.'**
  String get supportContactHint;

  /// No description provided for @supportSubject.
  ///
  /// In ar, this message translates to:
  /// **'الموضوع'**
  String get supportSubject;

  /// No description provided for @supportSubjectHint.
  ///
  /// In ar, this message translates to:
  /// **'مثال: صفحة الصيدلية فاضية'**
  String get supportSubjectHint;

  /// No description provided for @supportDetails.
  ///
  /// In ar, this message translates to:
  /// **'التفاصيل'**
  String get supportDetails;

  /// No description provided for @supportAttachLog.
  ///
  /// In ar, this message translates to:
  /// **'أرفق سجل الأعطال (يساعدنا نصلحها أسرع)'**
  String get supportAttachLog;

  /// No description provided for @supportSend.
  ///
  /// In ar, this message translates to:
  /// **'إرسال'**
  String get supportSend;

  /// No description provided for @supportSentByEmail.
  ///
  /// In ar, this message translates to:
  /// **'وصلت رسالتك لفريق الدعم ✅ — هيردوا عليك على إيميلك في أقرب وقت.'**
  String get supportSentByEmail;

  /// No description provided for @supportMailOpened.
  ///
  /// In ar, this message translates to:
  /// **'فتحنالك الإيميل — دوس إرسال وهتوصل لفريق الدعم'**
  String get supportMailOpened;

  /// No description provided for @supportWriteTo.
  ///
  /// In ar, this message translates to:
  /// **'ابعت لنا على {email}'**
  String supportWriteTo(String email);

  /// No description provided for @supportCrashLog.
  ///
  /// In ar, this message translates to:
  /// **'سجل الأعطال'**
  String get supportCrashLog;

  /// No description provided for @supportShareLog.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة السجل'**
  String get supportShareLog;

  /// No description provided for @supportShare.
  ///
  /// In ar, this message translates to:
  /// **'📤 مشاركة'**
  String get supportShare;

  /// No description provided for @supportClear.
  ///
  /// In ar, this message translates to:
  /// **'🗑️ مسح'**
  String get supportClear;

  /// No description provided for @supportClose.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق'**
  String get supportClose;

  /// No description provided for @supportTitle.
  ///
  /// In ar, this message translates to:
  /// **'مساعدة استخدام التطبيق'**
  String get supportTitle;

  /// No description provided for @supportSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أسئلة عامة — مش وصل لحسابك الشخصي'**
  String get supportSubtitle;

  /// No description provided for @supportComplaintBanner.
  ///
  /// In ar, this message translates to:
  /// **'عندك شكوى أو مشكلة؟ كلّم فريق الدعم'**
  String get supportComplaintBanner;

  /// No description provided for @supportInputHint.
  ///
  /// In ar, this message translates to:
  /// **'اكتب رسالتك هنا...'**
  String get supportInputHint;

  /// No description provided for @supportTyping.
  ///
  /// In ar, this message translates to:
  /// **'جاري الكتابة...'**
  String get supportTyping;

  /// No description provided for @supportTermsTitle.
  ///
  /// In ar, this message translates to:
  /// **'الشروط والأحكام'**
  String get supportTermsTitle;

  /// No description provided for @supportTermsHeading.
  ///
  /// In ar, this message translates to:
  /// **'شروط الاستخدام واتفاقية المستخدم'**
  String get supportTermsHeading;

  /// No description provided for @supportTermsIntro.
  ///
  /// In ar, this message translates to:
  /// **'آخر تحديث: يوليو 2026\n\nمن فضلك اقرأ شروط الاستخدام دي بعناية قبل ما تستخدم تطبيق زاد.'**
  String get supportTermsIntro;

  /// No description provided for @supportTerms1Title.
  ///
  /// In ar, this message translates to:
  /// **'١. الموافقة على الشروط'**
  String get supportTerms1Title;

  /// No description provided for @supportTerms1Body.
  ///
  /// In ar, this message translates to:
  /// **'بإنشائك حساب أو استخدامك لتطبيق زاد، فإنك توافق على هذه الشروط. لو مش موافق، من فضلك متستخدمش التطبيق.'**
  String get supportTerms1Body;

  /// No description provided for @supportTerms2Title.
  ///
  /// In ar, this message translates to:
  /// **'٢. طبيعة الخدمة — إحنا أداة، مش جهة مسؤولة'**
  String get supportTerms2Title;

  /// No description provided for @supportTerms2Body.
  ///
  /// In ar, this message translates to:
  /// **'زاد هو أداة تنظيمية ومساعدة شخصية فقط. إحنا بنوفر برنامج بيساعدك تتابع وتنظم وتعرض بياناتك المالية والمنزلية الخاصة بيك. إحنا مش بندير فلوسك، ولا بناخد قرارات نيابةً عنك، ولا بنحتفظ بأموالك، ولا بنعالج مدفوعات، ولا بنعمل كمؤسسة مالية أو مستشار مالي أو أمين استئماني من أي نوع.\n\nكل ميزة في التطبيق — بما فيها إدارة الميزانية، تتبع المصاريف، مسح الفواتير، متابعة المخزون، تتبع الاشتراكات، اكتشاف المعاملات عن طريق الإشعارات، وأي رؤية \"ذكية\" أو \"مبنية على الذكاء الاصطناعي\" — موجودة فقط عشان تساعدك تنظم معلومات إنت أصلاً عندك أو بتنتجها. إحنا مش بنتحقق من دقة المعلومات دي ولا بنضمنها ولا بنتحمل مسؤوليتها، ولا مسؤولية أي إجراء تتخذه بناءً عليها.\n\nإنت، وإنت بس، المسؤول عن:\n- كل قرار مالي بتاخده؛\n- التأكد من دقة أي بيانات معروضة أو محسوبة أو مكتشَفة أو مقترحة من التطبيق؛\n- نتائج اعتمادك على أي ميزة آلية، بما فيها الرؤى أو التوقعات المولّدة بالذكاء الاصطناعي أو الاكتشاف عن طريق الإشعارات؛\n- كل النتائج المتعلقة بميزانيتك أو إنفاقك أو مدخراتك أو إدارة منزلك، سواء كانت معلومات التطبيق دقيقة أو لأ.\n\nإحنا مش بنتحمل أي مسؤولية أو التزام من أي نوع عن نتائج استخدامك للتطبيق. استخدامك لزاد مش بينشئ أي علاقة استشارية أو التزام أمانة أو ضمان لأي نتيجة بينك وبيننا. التطبيق متاح كأداة تنظيمية وتسهيلية بحتة — مسؤولية إزاي بتستخدم المعلومات اللي بيعرضها بالكامل عليك.'**
  String get supportTerms2Body;

  /// No description provided for @supportTerms3Title.
  ///
  /// In ar, this message translates to:
  /// **'٣. الخصوصية والبيانات'**
  String get supportTerms3Title;

  /// No description provided for @supportTerms3Body.
  ///
  /// In ar, this message translates to:
  /// **'بنحترم خصوصيتك. بياناتك مخزنة بشكل آمن. إحنا مش بنبيع بياناتك المالية الشخصية لأي طرف تالت.'**
  String get supportTerms3Body;

  /// No description provided for @supportTerms4Title.
  ///
  /// In ar, this message translates to:
  /// **'٤. ميزات الذكاء الاصطناعي من أطراف خارجية — مساعدة فقط، مش مرجعية'**
  String get supportTerms4Title;

  /// No description provided for @supportTerms4Body.
  ///
  /// In ar, this message translates to:
  /// **'بعض الميزات (مسح الفواتير، توقعات الإنفاق، اكتشاف الاشتراكات، الرؤى السلوكية، اقتراحات الوجبات، الإدخال الصوتي) بتستخدم خدمات ذكاء اصطناعي من أطراف خارجية لمعالجة البيانات وتوليد الاقتراحات. المخرجات دي متاحة كتسهيل فقط، وميتعاملش معاها أبدًا كأنها دقيقة أو كاملة أو موثّقة أو مرجعية. المحتوى المولّد بالذكاء الاصطناعي ممكن يكون غلط أو قديم أو مش مناسب لحالتك.\n\nإحنا مش مالكين ولا متحكمين في نماذج الذكاء الاصطناعي المستخدمة. إحنا مش مسؤولين عن أي حاجة الذكاء الاصطناعي يولدها أو يقترحها أو يتوقعها أو يفشل يكتشفها. لازم تتأكد بنفسك من أي رقم أو تصنيف أو توصية قبل ما تتصرف بناءً عليها. اعتمادك على أي مخرج من الذكاء الاصطناعي كتوجيه مالي بيكون بالكامل على مسؤوليتك الخاصة.'**
  String get supportTerms4Body;

  /// No description provided for @supportTerms5Title.
  ///
  /// In ar, this message translates to:
  /// **'٥. مشاركة العائلة'**
  String get supportTerms5Title;

  /// No description provided for @supportTerms5Body.
  ///
  /// In ar, this message translates to:
  /// **'لو دعيت أفراد من عائلتك، إنت المسؤول عن وصولهم لبيانات منزلك.'**
  String get supportTerms5Body;

  /// No description provided for @supportTerms6Title.
  ///
  /// In ar, this message translates to:
  /// **'٦. السلوك الممنوع'**
  String get supportTerms6Title;

  /// No description provided for @supportTerms6Body.
  ///
  /// In ar, this message translates to:
  /// **'ممنوع تعمل هندسة عكسية أو اختراق أو تستخدم زاد في أي نشاط غير قانوني.'**
  String get supportTerms6Body;

  /// No description provided for @supportTerms7Title.
  ///
  /// In ar, this message translates to:
  /// **'٧. إحنا بنوفر الأداة — وإنت المسؤول عن النتيجة'**
  String get supportTerms7Title;

  /// No description provided for @supportTerms7Body.
  ///
  /// In ar, this message translates to:
  /// **'إحنا مش بنضمن ولا بنتحمل مسؤولية دقة أي رصيد أو فئة مصروف أو حالة اشتراك أو مستوى مخزون أو تنبيه نقص أو توقع ميزانية معروض في التطبيق. وإحنا مش بنضمن إن الاكتشاف التلقائي للمعاملات هيلتقط كل معاملة، ولا إنه هيكون صح دايمًا لما يلتقطها.\n\nباستخدامك لزاد، إنت مقر بإن:\n- إحنا أداة تنظيم معلومات سلبية، مش طرف فاعل في قراراتك المالية؛\n- أي خسارة مالية أو دفعة فاتت أو إسراف في الإنفاق أو تلف مخزون أو خلاف عائلي أو أي نتيجة سلبية تانية ناتجة عن استخدامك أو اعتمادك على التطبيق هي مسؤوليتك وحدك؛\n- إحنا مش هنتحمل أي مسؤولية، مالية أو غيرها، عن النتايج دي، لأقصى حد يسمح بيه القانون.'**
  String get supportTerms7Body;
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
