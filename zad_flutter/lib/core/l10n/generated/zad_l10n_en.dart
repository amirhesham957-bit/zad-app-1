// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'zad_l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class ZadL10nEn extends ZadL10n {
  ZadL10nEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Zad';

  @override
  String get settingsLanguageSection => 'Language';

  @override
  String get languageSystem => 'Same as phone';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageEnglishPreview =>
      'English is still being translated — many screens stay in Arabic until it is done.';

  @override
  String get authTagline => 'Smart running for a calm home';

  @override
  String get authSignInTitle => 'Sign in';

  @override
  String get authSignInSubtitle => 'Enter your email and password';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Password';

  @override
  String get authTogglePassword => 'Show or hide password';

  @override
  String get authForgotPassword => 'Forgot your password?';

  @override
  String get authSignInButton => 'Sign in';

  @override
  String get authNoAccount => 'Don\'t have an account? ';

  @override
  String get authSignUpNow => 'Sign up now';

  @override
  String get authResetTitle => 'Reset password';

  @override
  String get authResetBody =>
      'Enter your email. We\'ll send you a link to reset your password.';

  @override
  String get authResetSent => 'Link sent!';

  @override
  String get commonClose => 'Close';

  @override
  String get commonSend => 'Send';

  @override
  String get authTermsDecline => 'Decline';

  @override
  String get authTermsAccept => 'Agree and continue';

  @override
  String get authCountry => 'Country';

  @override
  String get authPickCountry => 'Choose your country';

  @override
  String get authSignUpTitle => 'Create account';

  @override
  String get authSignUpSubtitle => 'Enter your details to continue';

  @override
  String get authName => 'Your name';

  @override
  String get authNameHint => 'Sara Ahmed';

  @override
  String get authAgreeTo => 'I agree to ';

  @override
  String get authTermsLink => 'the terms and privacy policy';

  @override
  String get authSignUpDone => 'You\'re signed up! Taking you in…';

  @override
  String get authHaveAccount => 'Already have an account? ';

  @override
  String get authSignOut => 'Sign out';

  @override
  String get authSignOutTitle => 'Sign out?';

  @override
  String get authSignOutBody =>
      'You\'ll need to sign in again to reach your accounts.';

  @override
  String get commonWait => 'Wait';

  @override
  String get authSignOutConfirm => 'Sign out';

  @override
  String get authErrorInvalidCredentials => 'The email or password is wrong.';

  @override
  String get authErrorEmailTaken =>
      'This email already has an account. Try signing in with it, or reset the password.';

  @override
  String get authErrorWeakPassword =>
      'The password is too short — use at least 6 characters.';

  @override
  String get authErrorInvalidEmail => 'This email doesn\'t look right.';

  @override
  String get authErrorEmailNotConfirmed =>
      'You still need to confirm your email. Check your inbox for the link we sent.';

  @override
  String get authErrorRateLimited =>
      'Too many tries in a short time. Wait a little and try again.';

  @override
  String get authErrorSignupDisabled => 'Sign-up is closed right now.';

  @override
  String get authErrorUserBanned => 'This account is suspended.';

  @override
  String get authErrorOffline =>
      'No internet connection — signing in needs one.';

  @override
  String get authErrorServer =>
      'The service isn\'t answering right now. Try again in a bit.';

  @override
  String get authErrorUnknown => 'Something unexpected went wrong. Try again.';

  @override
  String authSignOutPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count changes haven\'t reached the server yet. If you sign out now they won\'t be sent. Better to wait until you\'re back online.',
      one: 'One change hasn\'t reached the server yet. If you sign out now it won\'t be sent. Better to wait until you\'re back online.',
    );
    return '$_temp0';
  }

  @override
  String get paywallBasicTitle => 'Basic';

  @override
  String get paywallBasicBadge => 'Best value';

  @override
  String get paywallBasicPerkNoAds => 'No ads at all';

  @override
  String get paywallBasicPerkAttempts =>
      '300 attempts a month (about 10 a day)';

  @override
  String get paywallBasicPerkPriority =>
      'Your place is kept at busy times, and Zad remembers your conversations longer';

  @override
  String get paywallBasicPerkTelegram =>
      'Photos and voice notes in the Telegram bot';

  @override
  String get paywallPlusTitle => 'Plus';

  @override
  String get paywallPlusBadge => 'Most popular ⭐';

  @override
  String get paywallAllBasicPerks => 'Everything in Basic';

  @override
  String get paywallPlusPerkAttempts =>
      '1,000 attempts a month (about 33 a day)';

  @override
  String get paywallPlusPerkDaily =>
      'Enough for receipt scans and a deep analysis every day';

  @override
  String get paywallFamilyTitle => 'Family';

  @override
  String get paywallFamilyBadge => 'Biggest allowance 👑';

  @override
  String get paywallFamilyPerkAttempts =>
      '2,500 attempts a month (about 83 a day)';

  @override
  String get paywallFamilyPerkHeavy => 'For whoever leans on Zad most at home';

  @override
  String get paywallNoPlayTitle => 'Google Play isn\'t available';

  @override
  String get paywallNoPlayBody =>
      'Subscriptions go through Google Play. If Zad was installed from a file rather than the store, install it from Google Play and subscribe here.';

  @override
  String get paywallNotOnPlayTitle => 'This plan isn\'t in the store yet';

  @override
  String get paywallNotOnPlayBody =>
      'This plan isn\'t live on Google Play yet. Try again soon.';

  @override
  String get paywallFailedTitle => 'We couldn\'t open Google Play';

  @override
  String get paywallFailedBody =>
      'Something went wrong opening the payment. Check your connection and try again.';

  @override
  String get commonOk => 'OK';

  @override
  String get paywallTitle => 'Zad Premium (Zad VIP)';

  @override
  String get paywallHeadline => 'Choose the Zad plan that fits your family';

  @override
  String get paywallSubhead =>
      'No ads, more attempts, a place kept at busy times — paid through the official Google Play store.';

  @override
  String get paywallSafePayment => 'Safe, secure payment';

  @override
  String get paywallBillingNote =>
      'Payment and monthly renewal go securely through your Google Play account, and you can cancel any time from the store.';

  @override
  String get paywallStayFree => 'Or stay on the free plan';

  @override
  String get paywallFreeTerms =>
      '5 attempts that come back every 5 hours, and logging expenses is always free. A chat message costs 1 attempt, a receipt scan 2, a deep analysis 3.';

  @override
  String get paywallFromPlay => 'From Google Play';

  @override
  String get paywallAutoRenew => 'Monthly, renews automatically';

  @override
  String paywallSubscribeTo(String plan) {
    return 'Subscribe to $plan on Google Play';
  }

  @override
  String paywallAttemptsPerMonth(int count) {
    return '$count attempts a month';
  }

  @override
  String paywallPricePerMonth(String price) {
    return '$price a month';
  }

  @override
  String get navHome => 'Home';

  @override
  String get navMoney => 'My money';

  @override
  String get navHomeStock => 'My home';

  @override
  String get navMore => 'More';

  @override
  String get navFamily => 'Family';

  @override
  String get navMyFamily => 'My family';

  @override
  String get navVoiceAssistant => 'Zad — voice assistant';

  @override
  String get navCamera => 'Photograph receipts and products';

  @override
  String get pulseOneSaved => 'one thing saved';

  @override
  String get pulseTwoSaved => 'two things saved';

  @override
  String pulseFewSaved(int n) {
    return '$n things saved';
  }

  @override
  String pulseManySaved(int n) {
    return '$n things saved';
  }

  @override
  String pulseOffline(String what) {
    return 'No internet — $what, sent as soon as you\'re back online';
  }

  @override
  String get pulseThinking => 'Zad is thinking…';

  @override
  String get pulseSyncing => 'Syncing…';

  @override
  String get authPreparingAccount => 'Getting your account ready…';

  @override
  String get shareTooLarge =>
      'The file is too big for Zad to read in one go — send a smaller one';

  @override
  String get shareUnsupported =>
      'Zad reads text, pictures, PDF and CSV files only';

  @override
  String get shareUnreadable =>
      'I couldn\'t open what was shared — try sending it again';

  @override
  String get shareWhatImage => 'What is this picture?';

  @override
  String get shareWhatImageHint =>
      'Zad will read it and show you what it found before saving anything';

  @override
  String get shareReceipt => 'A shopping receipt';

  @override
  String get shareStatement => 'A bank statement';

  @override
  String get drawerCompanion => 'Zad companion';

  @override
  String get drawerBrain => 'Zad\'s brain';

  @override
  String get drawerAppointments => 'My appointments';

  @override
  String get drawerPlaces => 'My places';

  @override
  String get drawerObligations => 'My commitments';

  @override
  String get drawerPlans => 'Zad\'s monthly plans';

  @override
  String get drawerShopping => 'Shopping list';

  @override
  String get drawerPharmacy => 'Family pharmacy';

  @override
  String get drawerMaintenance => 'Home maintenance';

  @override
  String get drawerDocuments => 'My documents';

  @override
  String get drawerNearby => 'Shops and markets nearby';

  @override
  String get drawerTips => 'Zad\'s tips';

  @override
  String get drawerTasbiha => 'Tasbiha';

  @override
  String get drawerNotifications => 'Notifications';

  @override
  String get drawerAccount => 'My account';

  @override
  String get drawerGroupZad => 'Zad';

  @override
  String get drawerGroupMoney => 'Money';

  @override
  String get drawerGroupHome => 'Home and family';

  @override
  String get drawerGroupMore => 'More';

  @override
  String get drawerKidsMode => 'Kids mode';

  @override
  String get drawerFullMode => 'Full mode';

  @override
  String get shellOpenProfile => 'Tap to see your profile';

  @override
  String get shellZadUser => 'Zad user';

  @override
  String get shellHello => 'Welcome';

  @override
  String shellHelloName(String name) {
    return 'Hello, $name';
  }

  @override
  String shellCompanionTag(String name, int level) {
    return '$name · level $level';
  }

  @override
  String widgetSeasonTomorrow(String name) {
    return '$name is tomorrow';
  }

  @override
  String widgetSeasonTwoDays(String name) {
    return 'Two days to $name';
  }

  @override
  String widgetSeasonDays(int n, String name) {
    return '$n days to $name';
  }

  @override
  String homeFxExcluded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count transactions left out of the total — their currency has no exchange rate',
      one: 'One transaction left out of the total — its currency has no exchange rate',
    );
    return '$_temp0';
  }

  @override
  String get homeBankListening =>
      'Listening to bank messages and updating your balance';

  @override
  String get homeBankStopped =>
      'Listening to bank messages stopped — tap to fix';

  @override
  String get homeBirthday => 'Happy birthday! 🎂';

  @override
  String homeBirthdayName(String who) {
    return 'Happy birthday, $who! 🎂';
  }

  @override
  String get homeBirthdayWish =>
      'Zad wishes you a lovely year full of good things and peace of mind.';

  @override
  String get homeBirthdayThanks => 'Thank you, Zad 💚';

  @override
  String get commonHide => 'Hide';

  @override
  String homeStoriesLabel(String name) {
    return 'Zad\'s stories: $name';
  }

  @override
  String get homeStories => 'Zad\'s stories';

  @override
  String get homeCloseDay => 'Close your day';

  @override
  String get homeCloseDayHint =>
      'Ten seconds: did you pay cash for anything today? And your companion gets dinner';

  @override
  String get coverageBlind => 'I can\'t see any spending this cycle yet';

  @override
  String get coverageBlindHint =>
      'Close your day or link your bank so I can see';

  @override
  String get coverageFull => 'I can see nearly all your spending';

  @override
  String get coverageFullHint => 'Keep it up — the numbers above are real';

  @override
  String coveragePartial(String share) {
    return 'I can see about $share of your spending';
  }

  @override
  String get coveragePartialHint =>
      'Close your day or link your bank so I can see more';

  @override
  String get briefTitle => 'Zad\'s brief for today';

  @override
  String get briefAllGood => 'All good — nothing urgent today.';

  @override
  String get briefAskZad => 'Ask Zad anything';

  @override
  String get glanceStockTitle => 'Stock health and shortages';

  @override
  String get glanceStockSubtitle =>
      'Watching spoilage and what you really need';

  @override
  String get glanceOpenStock => 'Open the pantry →';

  @override
  String get glanceStockHealth => 'Pantry health';

  @override
  String glanceStockPercent(int percent) {
    return '$percent% stocked';
  }

  @override
  String get glanceStockEmpty => 'The pantry is empty';

  @override
  String get glanceStockEmptyHint =>
      'Photograph a supermarket receipt or add your items, and Zad tells you what\'s running out before you need it';

  @override
  String glanceLowCount(int count) {
    return '$count running low';
  }

  @override
  String get glanceExpired => 'Expired';

  @override
  String glanceDaysLeft(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days left',
      one: '1 day left',
    );
    return '$_temp0';
  }

  @override
  String glanceQtyLeft(String qty) {
    return '$qty left';
  }

  @override
  String get glanceRunningOut => 'Running out';

  @override
  String get glanceAddToCart => 'Add to the list';

  @override
  String get glancePharmacyEmptyLabel => 'No medicines yet';

  @override
  String glanceAdherence(int percent, String verdict) {
    return 'Doses taken: $percent% • $verdict';
  }

  @override
  String get glanceAdherenceGood => 'on track';

  @override
  String get glanceAdherenceLow => 'needs attention';

  @override
  String glanceActiveMedicines(int count) {
    return '$count active medicines • still gathering how doses go';
  }

  @override
  String get glancePharmacyTitle => 'Family pharmacy and doses';

  @override
  String get glanceOpenPharmacy => 'Open the pharmacy →';

  @override
  String get glancePharmacyEmpty => 'The pharmacy is empty';

  @override
  String get glancePharmacyEmptyHint =>
      'Photograph a medicine strip or add it by hand, and Zad reminds you of doses and warns you before it runs out';

  @override
  String get glanceNextDose => 'Next dose';

  @override
  String get glanceTookDose => 'I took it';

  @override
  String glanceDosesPerDay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count doses a day',
      one: '1 dose a day',
    );
    return '$_temp0';
  }

  @override
  String get glanceSubsTitle => 'Monthly subscriptions';

  @override
  String get glanceSubsNone => 'No subscriptions yet';

  @override
  String glanceSubsTotal(String amount) {
    return 'Monthly total: $amount';
  }

  @override
  String get glanceSeeAll => 'See all →';

  @override
  String get glanceSubsEmpty => 'No subscriptions yet';

  @override
  String get glanceSubsEmptyHint =>
      'Add your monthly subscriptions so Zad counts them in what\'s available and reminds you of renewals';

  @override
  String glanceNextRenewal(String title) {
    return 'Next renewal: $title';
  }

  @override
  String glanceInstalment(String amount) {
    return 'Payment: $amount';
  }

  @override
  String groceryWhatToAdd(String shop, String amount) {
    return 'You bought from $shop for $amount — what goes in the pantry?';
  }

  @override
  String get groceryOtherItem => 'Another item\'s name…';

  @override
  String get commonAdd => 'Add';

  @override
  String groceryAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Added $count items ✅',
      one: 'Added 1 item ✅',
    );
    return '$_temp0';
  }

  @override
  String get commonDone => 'Done';

  @override
  String get activationTitle => 'Set Zad up for your home';

  @override
  String get activationSubtitle =>
      'Four steps that make the balance, alerts and forecasts useful from day one';

  @override
  String activationProgress(int done, int total) {
    return '$done of $total';
  }

  @override
  String get activationBalance => 'Set your starting balance';

  @override
  String get activationBalanceHint =>
      'Enter what you have now so Zad tracks money in and out accurately';

  @override
  String get activationBank => 'Turn on bank notification reading';

  @override
  String get activationBankHint =>
      'Let Zad pick up transactions and show them for you to confirm';

  @override
  String get activationFirstItem => 'Add your first home item';

  @override
  String get activationFirstItemHint =>
      'Start with something you buy often so Zad learns how fast you use it';

  @override
  String get activationGoal => 'Set your home\'s first goal';

  @override
  String get activationGoalHint => 'Zad follows it with you every week';

  @override
  String get activationAllSet =>
      'All set! 🎉 Try telling Zad \"spent 50 on groceries\" by voice or in the Telegram bot — it asks you to confirm and records it.';

  @override
  String get commonOpen => 'Open';

  @override
  String get amazonOutOfStock => 'Out of your pantry';

  @override
  String get amazonRunningLow => 'Running low';

  @override
  String get amazonOnList => 'On your shopping list';

  @override
  String get amazonSuggestion => 'A suggestion for your home';

  @override
  String get amazonShop => 'Shop on Amazon';

  @override
  String get amazonApproxPrice => 'Approximate price';

  @override
  String get amazonUpdatedToday => 'Updated today';

  @override
  String amazonPriceAge(int days) {
    return 'Price from $days days ago';
  }

  @override
  String get amazonName => 'Amazon';

  @override
  String get amazonDisclosure =>
      'Affiliate link — Zad earns a commission at no extra cost to you';

  @override
  String get amazonOut => 'Ran out';

  @override
  String get amazonLow => 'Running low';

  @override
  String get amazonShopEmoji => '🛍️ Shop on Amazon';

  @override
  String get amazonNoNeeds => 'Add what you\'re missing, or see today\'s deals';

  @override
  String amazonOneNeed(String name) {
    return 'You\'re out of $name — order it from Amazon';
  }

  @override
  String amazonManyNeeds(int count) {
    return 'You\'re missing $count things — order each with a tap';
  }

  @override
  String get amazonSuggest => 'Suggestion';

  @override
  String get amazonDeals => 'Deals';

  @override
  String get amazonOrder => '🛒 Order it';

  @override
  String get homeOffline => 'No internet connection';

  @override
  String get homeOfflineHint =>
      'Your data is saved on the phone and syncs as soon as you\'re back online';

  @override
  String get homeTalkToZad => 'Talk to Zad';

  @override
  String homeHello(String name) {
    return 'Hello, $name! 👋';
  }

  @override
  String get homeBrainActive => 'Zad\'s brain is on';

  @override
  String get homeScanPantry => 'Scan the pantry';

  @override
  String get homeRecent => 'Recent transactions';

  @override
  String get commonSeeAll => 'See all';

  @override
  String get homeRecentEmpty => 'Your bank transactions will show here';

  @override
  String get homeAllTransactions => 'All transactions';

  @override
  String get dayToday => 'Today';

  @override
  String get dayYesterday => 'Yesterday';

  @override
  String dayAgo(int days) {
    return '$days days ago';
  }

  @override
  String get homeServerDown => 'I couldn\'t reach the server';

  @override
  String get homePreparing => 'Getting your budget ready';

  @override
  String get homeServerDownHint =>
      'We\'ll try again on our own. You can pull the screen down now.';

  @override
  String get homePreparingHint => 'One second and everything will be here.';

  @override
  String checkInFinished(String item) {
    return 'Is the $item finished?';
  }

  @override
  String get checkInHint => 'By how fast you use it, it should be nearly gone';

  @override
  String get checkInDone => 'Finished';

  @override
  String get checkInNotYet => 'Not yet';

  @override
  String get metricsSafeDaily => 'Safe daily spend';

  @override
  String get metricsToMonthEnd => 'To the end of the month';

  @override
  String get metricsToPayday => 'To payday';

  @override
  String metricsDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get commonNotNow => 'Not now';

  @override
  String get quietRestoreFailed =>
      'I couldn\'t bring the alerts back. Try again.';

  @override
  String get quietRestore => 'Bring the alerts back';

  @override
  String metricsPaydayOn(int day, String month) {
    return '$month $day';
  }

  @override
  String get sectionPantry => 'Pantry';

  @override
  String get sectionBudget => 'Budget';

  @override
  String get sectionSubscriptions => 'Subscriptions';

  @override
  String get sectionMap => 'Zad\'s map';

  @override
  String get sectionStatement => 'Import a statement';

  @override
  String get sectionPlans => 'Zad\'s smart monthly plans';

  @override
  String sectionWithBadge(String name, int count) {
    return '$name, $count';
  }

  @override
  String get sectionsFewer => 'Fewer sections';

  @override
  String sectionsAll(int count) {
    return 'All sections ($count)';
  }

  @override
  String get tasbihaGarden => 'The tasbih garden';

  @override
  String tasbihaProgress(int clicks, int target) {
    return '$clicks of $target tasbih';
  }

  @override
  String travelSwitch(String country, String currency) {
    return 'Looks like you\'re in $country — switch to $currency?';
  }

  @override
  String get travelSwitchButton => 'Switch';

  @override
  String get commonDismiss => 'Dismiss';

  @override
  String recipeAskSpoil(String items) {
    return 'Suggest recipes with $items before they spoil';
  }

  @override
  String recipeAskRunOut(String items) {
    return 'Suggest recipes with $items before they run out';
  }

  @override
  String get listSeparator => ', ';

  @override
  String recipeStagnant(String names) {
    return 'You\'ve had $names a while and haven\'t used it 🤔';
  }

  @override
  String recipeRunningOut(String names) {
    return 'Your $names will run out soon 👀';
  }

  @override
  String get recipeStagnantHint => 'Recipes to use it before it spoils';

  @override
  String get recipeRunningOutHint => 'Recipes with it before it goes to waste';

  @override
  String get recipeOpenChat => 'Tap for more in Zad\'s chat →';

  @override
  String get profileSaveFailed => 'We couldn\'t save your profile — try again';

  @override
  String get whoTitle => 'Introduce yourself';

  @override
  String get whoBody =>
      'Your name, how you\'d like to be addressed, your work and payday — so I talk to you right and remember you.';

  @override
  String get whoGo => 'Let\'s get acquainted';

  @override
  String get commonLater => 'Later';

  @override
  String monthName(String month) {
    String _temp0 = intl.Intl.selectLogic(month, {
      'm1': 'January',
      'm2': 'February',
      'm3': 'March',
      'm4': 'April',
      'm5': 'May',
      'm6': 'June',
      'm7': 'July',
      'm8': 'August',
      'm9': 'September',
      'm10': 'October',
      'm11': 'November',
      'm12': 'December',
      'other': '',
    });
    return '$_temp0';
  }
}
