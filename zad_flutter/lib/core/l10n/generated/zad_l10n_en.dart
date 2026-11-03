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
  String get authNewPasswordTitle => 'New password';

  @override
  String get authNewPasswordBody => 'Type the new password for your account.';

  @override
  String get authNewPasswordSave => 'Save';

  @override
  String get authNewPasswordDone => 'Your password was changed.';

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

  @override
  String get chatVoiceUnavailable =>
      'Voice isn\'t available right now — the reply is written in front of you';

  @override
  String get chatNewTooltip => 'Start a new conversation';

  @override
  String get chatNewTitle => 'Start a new conversation?';

  @override
  String get chatNewBody =>
      'The conversation so far is cleared from this phone. What Zad has learned about you stays as it is.';

  @override
  String get chatClear => 'Clear';

  @override
  String get chatWelcome =>
      'Welcome! I\'m Zad 🤖, your smart family assistant. How can I help you today?\nAsk me about recipes, check your fridge, or add what\'s missing to the shopping list!';

  @override
  String get chatBusy =>
      'The AI is a bit busy right now 🙏 Try again in a moment.';

  @override
  String get chatUnexpected => 'Something unexpected went wrong.';

  @override
  String get chatResend => 'Didn\'t arrive — send it again';

  @override
  String get chatStopVoice => 'Stop the voice';

  @override
  String get chatListen => 'Hear the reply';

  @override
  String get chatThinking => 'Thinking…';

  @override
  String get refillBack => 'Your attempts are back — send your message again';

  @override
  String refillDays(int days) {
    return 'Your attempts refill in $days days';
  }

  @override
  String get refillHour => 'an hour';

  @override
  String get refillTwoHours => 'two hours';

  @override
  String refillFewHours(int h) {
    return '$h hours';
  }

  @override
  String refillManyHours(int h) {
    return '$h hours';
  }

  @override
  String refillMinutes(int m) {
    return '$m minutes';
  }

  @override
  String get refillAnd => ' and ';

  @override
  String refillIn(String span) {
    return 'Your attempts refill in $span';
  }

  @override
  String get chatSubscribeFeature => 'Subscribe to turn this on';

  @override
  String get chatSubscribeMore => 'Subscribe for more attempts';

  @override
  String get chatNotDone => 'Not done yet.';

  @override
  String get chatDoIt => 'Do it';

  @override
  String get chatTranscribing => 'Turning speech into text…';

  @override
  String get chatHint => 'Write to Zad…';

  @override
  String get chatSend => 'Send';

  @override
  String get voiceTooShort =>
      'That was a quick tap — press, start talking, then stop.';

  @override
  String get voiceDenied =>
      'I need microphone permission. Open the app\'s settings and allow recording.';

  @override
  String get voiceFailed => 'I couldn\'t turn the speech into text. Try again.';

  @override
  String get subscribePulseTitle => 'Subscribe and keep Zad with you';

  @override
  String get subscribePulseBody =>
      'No ads, more attempts, and voice without a limit.';

  @override
  String get subscribePulseClose => 'Close';

  @override
  String get voiceOutToday =>
      'That\'s today\'s voice questions (3 a day) — they\'re back tomorrow. Type your question, or subscribe to talk to Zad without a limit.';

  @override
  String get voiceRecord => 'Record voice';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get voiceDone => 'Done';

  @override
  String chatEmergency(String trade) {
    return 'An emergency at home? Your $trade is one tap away.';
  }

  @override
  String get chatTechnicians => 'My technicians';

  @override
  String get intChatTitle => 'Chat with Zad';

  @override
  String get intChatSubtitle =>
      'Ask about your spending, your pantry, or anything';

  @override
  String get intChatHide => 'Hide the chat';

  @override
  String get intChatOpen => 'Open the chat';

  @override
  String get intPromptRecipe => 'Suggest a recipe from the fridge';

  @override
  String get intPromptSpending => 'Analyse my spending this month';

  @override
  String get intPromptShopping => 'What am I missing for shopping?';

  @override
  String get intPromptSave => 'How can I save more this month?';

  @override
  String get intPromptSubs => 'Find my subscriptions';

  @override
  String get intPromptHealthy => 'A quick healthy meal';

  @override
  String get intChatClear => 'Clear the chat';

  @override
  String get intChatClearBody =>
      'We\'ll clear every message in the chat with Zad\'s brain. Your money data and pantry aren\'t affected.';

  @override
  String get intChatEmpty => 'Ask Zad anything';

  @override
  String get intChatInputHint => 'Ask Zad about your fridge or your budget...';

  @override
  String get intChatListen => 'Listen';

  @override
  String intChatMemoryUsed(int count) {
    return 'Built on $count things Zad remembers about you';
  }

  @override
  String get meshThinking => 'The neural network is working...';

  @override
  String get meshFinance => 'Money agent connected';

  @override
  String get meshPantry => 'Kitchen and pantry agent connected';

  @override
  String get meshPharmacy => 'Pharmacy agent connected';

  @override
  String get meshFamily => 'Family agent connected';

  @override
  String get meshDefault => 'Zad\'s agent network';

  @override
  String get voiceChipSpending => 'Analyse my spending';

  @override
  String get voiceChipMeal => 'Suggest a meal';

  @override
  String get voiceChipLeft => 'How much is left in the budget?';

  @override
  String get voiceChipCoffee => 'I spent 50 on coffee';

  @override
  String get voiceSheetDenied =>
      'Give the app permission to use the microphone';

  @override
  String get voiceSheetFailed => 'Something went wrong recognising your voice';

  @override
  String get voiceSheetOutToday =>
      'That\'s today\'s voice questions — 3 a day, back tomorrow';

  @override
  String get voiceSheetTooShort => 'I didn\'t hear anything clear — try again';

  @override
  String get voiceSheetBrainDown => 'I couldn\'t reach Zad\'s brain right now';

  @override
  String get voiceSpeaking => 'Zad is speaking…';

  @override
  String get voiceWriting => 'Writing down what you said…';

  @override
  String get voiceThinking => 'Thinking…';

  @override
  String get voicePreparing => 'Getting the voice ready…';

  @override
  String get voiceTitle => 'Zad\'s voice assistant';

  @override
  String voiceErrorRetry(String error) {
    return '⚠️ $error\nTap the mic and try again';
  }

  @override
  String get voiceInterruptHint =>
      'Zad is speaking… talk any time to interrupt';

  @override
  String get voiceWorking =>
      'Zad\'s brain is thinking and doing what you asked…';

  @override
  String get voiceListening => 'Zad is listening — take your time';

  @override
  String get voiceTapMic => 'Tap the mic and talk to Zad 🎙️';

  @override
  String get voiceHoldToTalk => 'Press and hold to talk';

  @override
  String get voiceReleaseToReply => 'I\'m listening… let go so I can answer';

  @override
  String get voicePressToInterrupt => 'Press and talk to interrupt me';

  @override
  String get voiceOrPick => 'Or pick a ready question:';

  @override
  String budgetSuggest(String amount) {
    return 'Zad suggests changing your budget to $amount, based on the last two months\' average';
  }

  @override
  String get commonApply => 'Apply';

  @override
  String get txFilterAll => 'All';

  @override
  String get txFilterExpenses => 'Expenses';

  @override
  String get txFilterIncome => 'Income';

  @override
  String get txFilterBank => 'Bank';

  @override
  String get budgetThisMonth => 'This month';

  @override
  String get budgetNoTransactions => 'No transactions yet.';

  @override
  String get budgetNoTransactionsHint =>
      'Add a transaction or link your bank to track spending automatically';

  @override
  String get txEdit => 'Edit transaction';

  @override
  String get txDelete => 'Delete transaction';

  @override
  String get financesTitle => 'Budget and commitments';

  @override
  String get financesTabMoves => 'Movements and budget';

  @override
  String get financesAddTx => 'Transaction';

  @override
  String get financesCategoryBudgets => 'Category budgets';

  @override
  String get financesSetCategory => 'Set a category';

  @override
  String get financesNoCategories =>
      'You haven\'t set a budget for any category yet. Tap \"Set a category\" so Zad follows each one on its own.';

  @override
  String get financesAvailable => 'Available';

  @override
  String get financesEditBalance => 'Edit balance';

  @override
  String get financesNoBudget => 'You haven\'t set your budget yet';

  @override
  String financesRemainingCommitted(String remaining, String committed) {
    return '$remaining left · $committed committed';
  }

  @override
  String financesNoLimit(String amount) {
    return '$amount — no limit';
  }

  @override
  String get financesSmartAnalysis => 'Smart analysis';

  @override
  String get financesSetCategoryBudget => 'Set a category budget';

  @override
  String financesEditCategoryBudget(String category) {
    return 'Edit the $category budget';
  }

  @override
  String get financesCategory => 'Category';

  @override
  String get financesMonthlyBudget => 'Monthly budget';

  @override
  String get commonSave => 'Save';

  @override
  String financesInsightTitle(String category) {
    return 'Smart analysis: $category';
  }

  @override
  String get financesAnalysing => 'Analysing...';

  @override
  String get financesInsightEmpty =>
      'Not enough data to analyse this category yet.';

  @override
  String financesPredictedNext(String amount) {
    return 'Expected next month: $amount';
  }

  @override
  String get gateTitle => 'Before we start, set your monthly ceiling';

  @override
  String get gateBody =>
      'Zad doesn\'t make numbers up. Without a ceiling there\'s no \"left\" or \"available\" — every figure would be a guess.';

  @override
  String get gateMarket => 'Country and currency';

  @override
  String get commonChange => 'Change';

  @override
  String get gateCeiling => 'Monthly spending ceiling';

  @override
  String get gateStart => 'Let\'s start';

  @override
  String get budgetOver => 'Over budget! Try to cut back';

  @override
  String budgetNear(int pct) {
    return 'You\'ve reached $pct% of your budget. Be careful';
  }

  @override
  String budgetFine(int pct) {
    return 'You\'ve spent $pct% of your budget. Doing well';
  }

  @override
  String budgetGreat(int pct) {
    return 'Great! You\'re on track — only $pct% spent';
  }

  @override
  String get trendUp => 'Rising';

  @override
  String get trendDown => 'Falling';

  @override
  String get trendFlat => 'Steady';

  @override
  String eventToday(String title) {
    return 'Raised for «$title» today';
  }

  @override
  String eventAhead(String title, String when) {
    return 'Keeping some aside for «$title» $when';
  }

  @override
  String get eventTomorrow => 'tomorrow';

  @override
  String eventOnDay(String day) {
    return 'on $day';
  }

  @override
  String weekdayName(String day) {
    String _temp0 = intl.Intl.selectLogic(day, {
      'd1': 'Monday',
      'd2': 'Tuesday',
      'd3': 'Wednesday',
      'd4': 'Thursday',
      'd5': 'Friday',
      'd6': 'Saturday',
      'd7': 'Sunday',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get eventOuting => 'an outing';

  @override
  String get txNoTitle => 'No description';

  @override
  String get txAddExpense => 'Add an expense';

  @override
  String get txAddIncome => 'Add income or salary';

  @override
  String get txKindExpense => 'Debit (expense)';

  @override
  String get txKindIncome => 'Credit (salary)';

  @override
  String get txDescriptionExample => 'Description (e.g. salary, rent)';

  @override
  String get txAmount => 'Amount';

  @override
  String get txDebit => 'Deduct the amount';

  @override
  String get txCredit => 'Add the amount';

  @override
  String get commonDelete => 'Delete';

  @override
  String txDeleteConfirm(String title) {
    return 'Are you sure you want to delete \"$title\"?';
  }

  @override
  String get txDescription => 'Description';

  @override
  String get txForPerson =>
      'For whom? (leave empty if for you or the whole house)';

  @override
  String get txForPersonHint => 'Mum, Dad, Youssef…';

  @override
  String txForPersonTag(String person) {
    return 'for $person';
  }

  @override
  String get habitTrialTitle => '🧪 Two-week trial';

  @override
  String get habitTrialTry => '✅ Try for two weeks';

  @override
  String get habitTrialNo => '🙅 No thanks';

  @override
  String get habitTrialKeep => '✅ Keep it';

  @override
  String get habitTrialDrop => '❌ Drop it';

  @override
  String get habitTrialStarted =>
      'Let\'s go ✅ The trial starts today for two weeks, then I\'ll tell you how it went in numbers.';

  @override
  String get habitTrialDeclined => 'OK, I won\'t suggest it again for a while.';

  @override
  String get habitTrialKept =>
      'Done ✅ It\'s kept — I\'ll remember it and build on it.';

  @override
  String get habitTrialDropped => 'OK, dropped. Thanks for trying.';

  @override
  String get habitTrialAlready => 'OK, your answer was already recorded.';

  @override
  String get habitTrialGone => 'That trial no longer exists.';

  @override
  String get habitTrialFailed =>
      'Sorry, I couldn\'t record your answer right now — try again in a bit.';

  @override
  String get learningTitle => '🧠 I\'ve learned';

  @override
  String get learningRight => '✅ Right';

  @override
  String get learningWrong => '❌ Not right';

  @override
  String get learningKept => 'Got it ✅ I\'ll remember that.';

  @override
  String get learningCorrected =>
      'OK, thanks for correcting me — I won\'t say it again.';

  @override
  String get learningAlready => 'OK, your answer was already recorded.';

  @override
  String get learningGone => 'That note no longer exists.';

  @override
  String get learningFailed =>
      'Sorry, I couldn\'t record your answer right now — try again in a bit.';

  @override
  String get txType => 'Type';

  @override
  String get txExpense => 'Expense';

  @override
  String get txIncome => 'Income';

  @override
  String get quickCash => 'Cash expense';

  @override
  String get quickExpense => 'Quick expense';

  @override
  String get quickSubtitle => 'Log your expense in seconds';

  @override
  String get quickName => 'Name';

  @override
  String get quickNameHint => 'e.g. haircut, groceries';

  @override
  String get quickCategory => 'Category';

  @override
  String get txScanReceipt => 'Photograph a receipt';

  @override
  String get txLog => 'Log a transaction';

  @override
  String get txTitle => 'Transactions';

  @override
  String get txNoneHere => 'No transactions here';

  @override
  String get txTryFilter => 'Try another filter.';

  @override
  String get commonEdit => 'Edit';

  @override
  String get walletCash => 'Cash';

  @override
  String get walletCard => 'Card';

  @override
  String get walletBank => 'Bank';

  @override
  String get txPendingOne => 'Still saved here';

  @override
  String txPendingCount(int count) {
    return '$count still saved here';
  }

  @override
  String get txLoadFailed => 'I couldn\'t load the transactions';

  @override
  String get txNonePeriod => 'No transactions this period';

  @override
  String get txPullToRetry => 'Pull the screen down to try again.';

  @override
  String get txNoneHint =>
      'As soon as you log an expense — or a bank message arrives — you\'ll find it here.';

  @override
  String get dateDayHeader => 'EEEE, d MMMM';

  @override
  String get cycleYearly => 'Yearly';

  @override
  String get cycleWeekly => 'Weekly';

  @override
  String get cycleMonthly => 'Monthly';

  @override
  String get subsTabAll => 'All';

  @override
  String get subsTabSubs => 'Subscriptions';

  @override
  String get subsTabBills => 'Bills';

  @override
  String get subsTabInstalments => 'Instalments';

  @override
  String get subsTabLoans => 'Loans';

  @override
  String get subsNone => 'No subscriptions';

  @override
  String get subsNoneInTab => 'Nothing in this category';

  @override
  String get subsActive => 'Active';

  @override
  String get subsMonthlyTotal => 'Monthly subscriptions total';

  @override
  String get subsActiveCount => 'Active subscriptions';

  @override
  String subsDetected(int count) {
    return '$count found automatically';
  }

  @override
  String get subsClearAll => 'Clear all';

  @override
  String get subsBnpl => 'Buy now, pay later';

  @override
  String get subsLoans => 'Instalments, loans and rent';

  @override
  String subsPaid(String title) {
    return 'Recorded the payment for $title and moved the date to next month';
  }

  @override
  String get subsFixed => 'Fixed commitments';

  @override
  String get subsTitle => 'Subscriptions and bills';

  @override
  String subsBnplTag(String name) {
    return 'Buy now pay later · $name';
  }

  @override
  String get subsRenewsToday => 'Renews today';

  @override
  String subsExpiredAgo(int days) {
    return 'Ended $days days ago';
  }

  @override
  String subsRenewsIn(int days) {
    return 'Renews in $days days';
  }

  @override
  String subsPerYear(String amount) {
    return '≈ $amount/year';
  }

  @override
  String get subsPaidMark => 'Paid ✓';

  @override
  String get subsToggleAuto => 'Turn auto-debit on or off';

  @override
  String get subsDisable => 'Disable';

  @override
  String get subsEnable => 'Enable';

  @override
  String get subsAdd => 'Add a new subscription';

  @override
  String get subsEdit => 'Edit subscription';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get subsSuggested => 'Suggested services and subscriptions:';

  @override
  String get subsKind => 'Kind of commitment:';

  @override
  String get subsKindSub => 'Monthly subscription';

  @override
  String get subsKindInstalment => 'Instalment';

  @override
  String get subsKindBill => 'Bill';

  @override
  String get subsKindRent => 'Commitment';

  @override
  String get subsTotalAmount => 'Total amount';

  @override
  String get subsRemaining => 'Instalments left';

  @override
  String get subsNameHint => 'Subscription name (e.g. Netflix)';

  @override
  String subsAmount(String symbol) {
    return 'Amount ($symbol)';
  }

  @override
  String get subsProvider => 'Provider';

  @override
  String get subsRenewalDate => 'Renewal date (YYYY-MM-DD)';

  @override
  String get commonPickDate => 'Pick a date';

  @override
  String get subsCycle => 'Billing cycle';

  @override
  String subsSuggestedCategory(String category) {
    return 'Suggested category: $category';
  }

  @override
  String get oblKindRent => 'Rent';

  @override
  String get oblKindInstallment => 'Instalment';

  @override
  String get oblKindDebt => 'Debt';

  @override
  String get oblKindTuition => 'School fees';

  @override
  String get oblKindUtility => 'Utility bill';

  @override
  String get oblKindOther => 'Other';

  @override
  String get recurMonthly => 'Monthly';

  @override
  String get recurQuarterly => 'Quarterly';

  @override
  String get recurYearly => 'Yearly';

  @override
  String get recurOnce => 'Once';

  @override
  String get oblStatusPaid => 'Paid';

  @override
  String get oblStatusPending => 'Due';

  @override
  String get oblStatusScheduled => 'Scheduled';

  @override
  String oblInDays(int days) {
    return 'In $days days';
  }

  @override
  String get oblTotal => 'Total commitments';

  @override
  String get oblAdd => 'Add a commitment';

  @override
  String get oblNone => 'No commitments';

  @override
  String get oblNoneHint =>
      'Fixed instalments and bills show here as soon as they\'re recorded';

  @override
  String oblDeleteConfirm(String title) {
    return 'Remove «$title» from your commitments?';
  }

  @override
  String get oblAddNew => 'Add a new commitment';

  @override
  String get oblEdit => 'Edit commitment';

  @override
  String get oblNameHint => 'Commitment name (rent, electricity...)';

  @override
  String oblAmountIn(String currency) {
    return 'Amount ($currency)';
  }

  @override
  String get oblDueDay => 'Monthly due day (1-31)';

  @override
  String get oblDayRange => 'From 1 to 31';

  @override
  String get oblRecurrence => 'Repeats';

  @override
  String get debtSaveFailed => 'Not saved — check your connection.';

  @override
  String debtPaymentOn(String name) {
    return 'A payment on $name';
  }

  @override
  String debtRemaining(String amount) {
    return 'Left: $amount';
  }

  @override
  String get debtPaidAmount => 'Amount paid';

  @override
  String get debtDelete => 'Delete the debt';

  @override
  String debtDeleteConfirm(String name) {
    return 'Remove «$name» from your debts?';
  }

  @override
  String get debtPlanner => 'Debt payoff planner';

  @override
  String get debtAdd => 'Add a debt';

  @override
  String get debtPickStrategy => 'Pick the payoff strategy that suits you';

  @override
  String get debtNone => 'No debts recorded';

  @override
  String get debtNoneHint =>
      'Add your debts and we\'ll help you plan the payoff';

  @override
  String get debtSnowball => 'Snowball (smallest first)';

  @override
  String get debtAvalanche => 'Avalanche (highest interest first)';

  @override
  String debtMonths(int months) {
    return '$months months';
  }

  @override
  String get debtLogPayment => 'Log a payment';

  @override
  String debtMonthsToPayoff(int months) {
    return '$months months to pay it all';
  }

  @override
  String debtTotalInterest(String amount) {
    return 'Total interest: $amount';
  }

  @override
  String get debtAnalysing => 'Zad is analysing...';

  @override
  String get debtExplain => 'Explain with AI';

  @override
  String get debtName => 'Debt name';

  @override
  String get debtLeft => 'Amount left';

  @override
  String get debtRate => 'Annual interest rate %';

  @override
  String get debtMinimum => 'Minimum monthly payment';

  @override
  String dealDiscount(String pct) {
    return '$pct% off';
  }

  @override
  String dealAt(String price, String store) {
    return '$price at $store';
  }

  @override
  String dealCached(String when) {
    return 'Search is busy right now — these are the last deals we found$when';
  }

  @override
  String get dealTitle => 'Deals on what you\'re missing 🏷️';

  @override
  String get dealLive => 'Live search result';

  @override
  String get dealSubtitle => 'Real deals on the items you\'re short of';

  @override
  String get dealTapRefresh => 'Tap to refresh the results from the web';

  @override
  String get dealSearching => 'Searching the web...';

  @override
  String get dealFailed =>
      'Couldn\'t search right now — try refreshing in a bit';

  @override
  String get dealFailedHint =>
      'The search service is busy. Tap refresh again in a bit — and if it keeps happening, check your connection.';

  @override
  String get dealNone => 'No specific results right now';

  @override
  String get dealRefresh => 'Refresh from the web 🔄';

  @override
  String get goalTitle => 'What\'s your home\'s most important goal right now?';

  @override
  String get goalBody =>
      'Pick one — Zad follows it with you every week for 3 months, and you can cancel any time.';

  @override
  String get goalSave => 'Save an amount every month';

  @override
  String get goalSaveHint =>
      'Set the amount, and Zad watches your spending so you reach it';

  @override
  String get goalMonthly => 'Monthly amount';

  @override
  String get goalBudget => 'Stay within the month\'s budget';

  @override
  String get goalBudgetHint =>
      'Zad warns you before spending outruns the budget';

  @override
  String get goalDebts => 'Pay off my debts';

  @override
  String get goalDebtsHint =>
      'Zad follows what\'s left and the next instalment with you';

  @override
  String get goalWaste => 'Waste less food';

  @override
  String get goalWasteHint => 'Zad reminds you of items before they spoil';

  @override
  String get goalOwn => 'Another goal, in my words';

  @override
  String get goalOwnHint => 'Write it the way you\'d say it';

  @override
  String get goalWrite => 'Write your goal';

  @override
  String get goalTooMany =>
      'You have 5 goals running — finish or cancel one first';

  @override
  String get goalSaveFailed => 'I couldn\'t save the goal — try again';

  @override
  String get goalStart => 'Start the goal';

  @override
  String get heldTitle => 'What I held back, and why';

  @override
  String get heldNone =>
      'Nothing held back this week — everything worth saying was said.';

  @override
  String get heldFailed => 'I can\'t read what I held back right now.';

  @override
  String get heldLoading => 'Reading…';

  @override
  String get heldAskHint =>
      'You can ask me «what didn\'t you tell me?» in the chat for the details.';

  @override
  String heldTimes(int count) {
    return '$count times';
  }

  @override
  String get heldActionDropped => 'not sent';

  @override
  String get heldActionWaiting => 'still waiting';

  @override
  String get heldActionPostponed => 'sent later';

  @override
  String get heldReasonMuted => 'you asked me to stop this kind for a while';

  @override
  String get heldReasonLearnedQuiet =>
      'I noticed you rarely act on this kind, so I send it less';

  @override
  String get heldReasonQuietHours => 'it was your sleeping time';

  @override
  String get heldReasonReplyHour =>
      'I waited for the hour you usually reply in';

  @override
  String get heldReasonPacing => 'something had just reached you';

  @override
  String get heldReasonDailyCap => 'the day\'s messages were used up';

  @override
  String get heldReasonBusyDay => 'your day was full of appointments';

  @override
  String get heldReasonCircumstance => 'I was giving you space';

  @override
  String get heldReasonDuplicate => 'I had said it a little before';

  @override
  String get heldReasonExpired => 'it went stale before a good moment came';

  @override
  String get heldReasonNotRelevant => 'it no longer mattered (done or changed)';

  @override
  String get heldReasonNothingNew => 'there was nothing new to say';

  @override
  String get heldReasonOther => 'another reason';

  @override
  String get heldKindGoodNight => 'Good night';

  @override
  String get heldKindCloseDay => '«Close your day»';

  @override
  String get heldKindMorning => 'Good morning';

  @override
  String get heldKindWeeklyStory => 'The week\'s money story';

  @override
  String get heldKindNewcomer => 'The getting-to-know-you question';

  @override
  String get heldKindSalary => '«Is this the salary?»';

  @override
  String get heldKindVoice => 'A voice message';

  @override
  String get heldKindDigest => 'The home digest';

  @override
  String get heldKindForecast => 'The week\'s spending forecast';

  @override
  String get heldKindSpendingAhead => 'Spending ahead of the budget';

  @override
  String get heldKindBill => 'A bill reminder';

  @override
  String get heldKindWarranty => 'A warranty about to end';

  @override
  String get heldKindGoal => 'Your goal follow-up';

  @override
  String get heldKindHabit => 'A repeating habit';

  @override
  String get heldKindShortage => 'Things running out soon';

  @override
  String get heldKindRestock => 'An essential ran out';

  @override
  String get heldKindPet => 'Your companion\'s call';

  @override
  String get heldKindNote => 'A note from Zad';

  @override
  String get exampleCityEg => 'e.g. Cairo, Giza';

  @override
  String get exampleCitySa => 'e.g. Riyadh, Jeddah';

  @override
  String get exampleCityOther => 'e.g. your city';

  @override
  String get exampleStoreEg => 'e.g. Carrefour, Spinneys';

  @override
  String get exampleStoreSa => 'e.g. Panda, Othaim';

  @override
  String get exampleStoreOther => 'e.g. the supermarket\'s name';

  @override
  String get walletBankEg => 'Wallet / InstaPay';

  @override
  String get walletBankSa => 'Wallet / STC Pay';

  @override
  String get walletBankOther => 'Wallet / transfer';

  @override
  String get keepAliveAllow => 'Keep Zad running';

  @override
  String get diagTitle => 'Automation check';

  @override
  String get diagMenuSubtitle =>
      'Bank notifications and Zad\'s messages — where exactly they stop';

  @override
  String get diagRefresh => 'Refresh';

  @override
  String get diagBankTitle => 'What reached the server from bank notifications';

  @override
  String get diagBankNote =>
      'The last 14 days: every notification the phone sent, and what Zad did with it and why.';

  @override
  String get diagReadFailedTitle => 'Couldn\'t read from the server';

  @override
  String get diagReadFailedBody =>
      'Check your connection and pull down to refresh.';

  @override
  String get diagBankEmptyTitle => 'No notification reached the server';

  @override
  String get diagBankEmptyBody =>
      'If you paid by card lately, the break is on the phone — see the section above.';

  @override
  String get diagNotification => 'Notification';

  @override
  String get diagBankNoAccess =>
      'Stopped at the first step: notification access is off. Turn it on in the section above.';

  @override
  String get diagBankNotBound =>
      'Access is on but the reading service never connected. Turn access off and on again.';

  @override
  String get diagBankSilent =>
      'The reading service has seen nothing for two days — Android stopped it. Turn access off and on, and take Zad out of battery saving.';

  @override
  String get diagBankStuck =>
      'Some notifications were read on the phone but not sent yet. Go online and keep Zad open for a minute.';

  @override
  String get diagBankNothing =>
      'The phone is working but no bank notification reached the server. If you paid by card, your bank sends from an app we don\'t follow — tell us its name.';

  @override
  String get diagBankSetAside =>
      'Notifications reached the server but all were set aside — the reason is next to each one below.';

  @override
  String get diagBankWaiting =>
      'Some transactions are waiting for you. Confirm them from the notification or the home screen so they are recorded.';

  @override
  String get diagBankOk => 'Working: notifications arrive and are recorded.';

  @override
  String get diagProTitle => 'Messages Zad starts';

  @override
  String get diagProNote =>
      'Good morning, doses, appointments, «close your day» — whether they arrived and why.';

  @override
  String get diagTelegram => 'Telegram';

  @override
  String get diagPush => 'App notifications';

  @override
  String get diagUnknown => 'Unknown';

  @override
  String get diagLinked => 'Linked';

  @override
  String get diagNotLinked => 'Not linked';

  @override
  String get diagPushOff =>
      'This phone is not registered for Zad\'s notifications';

  @override
  String get diagProEmptyTitle => 'Zad started no message in the last 14 days';

  @override
  String get diagProEmptyBody =>
      'The first good-morning arrives next morning if there is a way to reach you.';

  @override
  String get diagProNoChannel =>
      'Zad has no way to reach you: no Telegram linked and this phone isn\'t registered for notifications. Link Telegram in settings, or open the app and allow notifications.';

  @override
  String get diagProNothing =>
      'The server sent nothing in 14 days. That isn\'t normal — send us a screenshot of this.';

  @override
  String get diagProFailing =>
      'Most messages failed — the reason is next to each one below.';

  @override
  String get diagProOk => 'Working: Zad starts messages and they reach you.';

  @override
  String get diagMomentMorning => 'Good morning';

  @override
  String get diagMomentNight => 'Good night';

  @override
  String get diagMomentCloseDay => 'Close your day';

  @override
  String get diagMomentDoseDue => 'Dose time';

  @override
  String get diagMomentDoseMissed => 'Missed dose';

  @override
  String get diagMomentDoseNudge => 'Dose reminder';

  @override
  String get diagMomentAppointment => 'Appointment soon';

  @override
  String get diagMomentWeekly => 'Weekly summary';

  @override
  String get diagMomentMonthly => 'Monthly story';

  @override
  String get diagIngestRecorded => 'Recorded as an expense';

  @override
  String get diagIngestWaiting => 'Waiting for you to confirm';

  @override
  String get diagIngestPromo => 'Judged an advert, not money moving';

  @override
  String get diagIngestOtp => 'A verification code or security alert';

  @override
  String get diagIngestOrder => 'An order or delivery status';

  @override
  String get diagIngestPersonal => 'A personal message';

  @override
  String get diagIngestNonFinancial => 'Not about money';

  @override
  String get diagIngestUnavailable =>
      'The brain didn\'t answer and the sender is unknown';

  @override
  String get diagIngestInfo => 'An information message (balance or alert)';

  @override
  String get diagIngestFailedTxn => 'A failed or pending transaction';

  @override
  String get diagIngestMerged =>
      'The same transaction arrived elsewhere and was merged';

  @override
  String get diagIngestServerError => 'A server error — it will be retried';

  @override
  String get diagIngestReviewing => 'Arrived, still being reviewed';

  @override
  String get diagMomentNoChannel =>
      'No way to reach you: no Telegram and no app notifications';

  @override
  String get diagMomentSkipped =>
      'Postponed or dropped (quiet hours or the daily cap)';

  @override
  String get diagMomentSent => 'Delivered';

  @override
  String get diagMomentPending => 'Waiting for its time';

  @override
  String diagPushOn(int count) {
    return 'This phone is registered ($count)';
  }

  @override
  String diagIngestKind(String kind) {
    return 'Classified as $kind';
  }

  @override
  String get introTagline => 'Smart care for a calm home';

  @override
  String get introPantryTitle => 'Your pantry';

  @override
  String get introPantryBody =>
      'Keep track of everything in your kitchen and home';

  @override
  String get introFamilyTitle => 'The whole family';

  @override
  String get introFamilyBody => 'Share the budget and chores with your family';

  @override
  String get introAssistantTitle => 'A smart assistant';

  @override
  String get introAssistantBody =>
      'AI that sees what you need and learns from you';

  @override
  String get introBudgetTitle => 'A smarter budget';

  @override
  String get introBudgetBody => 'See where your money goes and save more';

  @override
  String get introNext => 'Next';

  @override
  String get introStart => 'Start with Zad';

  @override
  String get introSkip => 'Skip';

  @override
  String get introSignUp => 'No account? Create one';

  @override
  String get introLogoLabel => 'Zad logo';

  @override
  String adWatchStep(String step) {
    return 'Watch an ad — $step of 3';
  }

  @override
  String adThirdOpens(String attempts) {
    return 'This ad completes three and opens $attempts';
  }

  @override
  String adThreeForOne(String attempts, String seen) {
    return 'Every 3 ads = $attempts — $seen of 3 watched';
  }

  @override
  String get appointmentGuardTitle => 'Before I save it:';

  @override
  String get appointmentGuardAsk => 'Save it like this, or change the time?';

  @override
  String get appointmentGuardKeep => 'Save anyway';

  @override
  String get qtyLeftLittle => 'A little left';

  @override
  String get qtyLeftHalf => 'About half left';

  @override
  String get qtyLeftMost => 'Most of it left';

  @override
  String get agentToolLogTransaction => 'Logged a transaction';

  @override
  String get agentToolUpdateTransaction => 'Edited a transaction';

  @override
  String get agentToolDeleteTransaction => 'Deleted a transaction';

  @override
  String get agentToolSetTransactionCategory => 'Categorised a transaction';

  @override
  String get agentToolMergeDuplicateExpense => 'Merged a duplicate expense';

  @override
  String get agentToolReconcileCashBalance => 'Settled the cash balance';

  @override
  String get agentToolParseNotificationPayload => 'Read a bank message';

  @override
  String get agentToolSetMonthlyLimit => 'Changed the budget limit';

  @override
  String get agentToolConfirmCycleStart => 'Confirmed the pay cycle';

  @override
  String get agentToolSetMarket => 'Changed country and currency';

  @override
  String get agentToolAddObligation => 'Added a commitment';

  @override
  String get agentToolConfirmObligation => 'Confirmed a commitment';

  @override
  String get agentToolUpdateObligation => 'Edited a commitment';

  @override
  String get agentToolDeleteObligation => 'Deleted a commitment';

  @override
  String get agentToolAddSubscription => 'Added a subscription';

  @override
  String get agentToolUpdateSubscription => 'Edited a subscription';

  @override
  String get agentToolDeleteSubscription => 'Deleted a subscription';

  @override
  String get agentToolAddDebt => 'Added a debt';

  @override
  String get agentToolUpdateDebt => 'Edited a debt';

  @override
  String get agentToolDeleteDebt => 'Deleted a debt';

  @override
  String get agentToolAddInventoryItem => 'Added an item to the pantry';

  @override
  String get agentToolUpdateInventoryQty => 'Changed a pantry quantity';

  @override
  String get agentToolDeleteInventoryItem => 'Removed an item from the pantry';

  @override
  String get agentToolAddShoppingItem => 'Added to the shopping list';

  @override
  String get agentToolCompleteShoppingItem => 'Ticked off the shopping list';

  @override
  String get agentToolDeleteShoppingItem => 'Removed from the shopping list';

  @override
  String get agentToolAddPharmacyItem => 'Added a medicine';

  @override
  String get agentToolUpdatePharmacyItem => 'Edited a medicine';

  @override
  String get agentToolDeletePharmacyItem => 'Removed a medicine';

  @override
  String get agentToolLogPharmacyDose => 'Logged a dose';

  @override
  String get agentToolAddMaintenanceItem => 'Added an appliance to maintenance';

  @override
  String get agentToolUpdateMaintenanceItem => 'Edited an appliance';

  @override
  String get agentToolDeleteMaintenanceItem => 'Removed an appliance';

  @override
  String get agentToolSaveDocument => 'Saved a document';

  @override
  String get agentToolDeleteDocument => 'Removed a document';

  @override
  String get agentToolAddGatheringToList =>
      'Added a gathering\'s items to the list';

  @override
  String get agentToolAddAppointment => 'Added an appointment';

  @override
  String get agentToolUpdateAppointment => 'Edited an appointment';

  @override
  String get agentToolAddPlaceReminder => 'Set a place reminder';

  @override
  String get agentToolCancelPlaceReminder => 'Cancelled a place reminder';

  @override
  String get agentToolScheduleTask => 'Scheduled a reminder';

  @override
  String get agentToolRemember => 'Saved a note about you';

  @override
  String get agentToolLinkMemory => 'Linked notes';

  @override
  String get agentToolUpdateCustomerProfile => 'Updated your profile';

  @override
  String get agentToolSetLifeGoal => 'New goal';

  @override
  String get agentToolSetBrokeMode => 'Tight-month mode';

  @override
  String get agentToolStartSavingsChallenge => 'Started a savings challenge';

  @override
  String get agentToolStopSavingsChallenge => 'Stopped a savings challenge';

  @override
  String get agentToolUpdateEmergencyFundBalance =>
      'Updated the emergency fund';

  @override
  String get agentToolAllocateIncome => 'Allocated income';

  @override
  String get agentToolSetSleepWindow => 'Your sleep hours';

  @override
  String get agentToolLearnSkill => 'Learned a skill';

  @override
  String get agentToolSaveTrustedTechnician => 'Saved a technician';

  @override
  String get agentToolOpenSupportTicket => 'Opened a support request';

  @override
  String get agentToolAnswerSameProduct => 'Matched a product';

  @override
  String get agentToolOther => 'A change by Zad';

  @override
  String get agentSourceAppChat => 'App chat';

  @override
  String get agentSourceTelegram => 'Telegram';

  @override
  String get agentSourceVoice => 'Voice message';

  @override
  String get agentSourceConfirm => 'Confirmed by you';

  @override
  String get agentSourceDaily => 'Daily review';

  @override
  String get agentSourceEvent => 'Automatic event';

  @override
  String get agentSourceOther => 'Zad';

  @override
  String get undoFailureNewerActionExists =>
      'There\'s a newer change to the same thing — undo that one first';

  @override
  String get undoFailureAlreadyUndone => 'This was already undone';

  @override
  String get undoFailureNeverApplied =>
      'This never went through, so there\'s nothing to undo';

  @override
  String get undoFailureNotUndoable => 'This can\'t be undone';

  @override
  String get undoFailureTargetMissing =>
      'That\'s been deleted or isn\'t there any more';

  @override
  String get undoFailureNotAllowed =>
      'There\'s a sign-in problem — sign out and back in';

  @override
  String get undoFailureOffline =>
      'No connection right now — try when you\'re back online';

  @override
  String get undoFailureUnknown => 'I couldn\'t undo it, try again';

  @override
  String actionLogUndoAsk(String tool) {
    return 'Undo “$tool”?';
  }

  @override
  String get actionLogUndoWarning =>
      'Zad will put this back the way it was before the change. You won\'t be able to undo this later.';

  @override
  String get actionLogWait => 'Wait';

  @override
  String get actionLogUndo => 'Undo';

  @override
  String actionLogUndone(String tool) {
    return 'Undid “$tool”';
  }

  @override
  String get actionLogTitle => 'Zad\'s change log';

  @override
  String get actionLogLoadFailed => 'Couldn\'t load the log';

  @override
  String get actionLogEmptyTitle => 'No changes yet';

  @override
  String get actionLogPullRetry => 'Pull down to try again.';

  @override
  String get actionLogEmptyBody =>
      'Anything Zad logs or changes for you will show up here.';

  @override
  String get actionLogApplied => 'Done';

  @override
  String get actionLogUndoneStatus => 'Undone';

  @override
  String get actionLogRejected => 'Refused';

  @override
  String get mutationFieldAmount => 'Amount';

  @override
  String get mutationFieldQuantity => 'Quantity';

  @override
  String get mutationFieldRemainingQuantity => 'Quantity left';

  @override
  String get mutationFieldRemainingBalance => 'Remaining';

  @override
  String get mutationFieldPrice => 'Price';

  @override
  String get mutationFieldUnit => 'Unit';

  @override
  String get mutationFieldCategory => 'Category';

  @override
  String get mutationFieldKind => 'Type';

  @override
  String get mutationFieldStatus => 'Status';

  @override
  String get mutationFieldStartsAt => 'Time';

  @override
  String get mutationFieldTaskDescription => 'Reminder';

  @override
  String get mutationFieldRecurrence => 'Repeats';

  @override
  String get mutationFieldDosage => 'Dose';

  @override
  String get mutationFieldDoseTimes => 'Dose times';

  @override
  String get mutationFieldDailyDoseCount => 'Doses a day';

  @override
  String get mutationFieldExpiryDate => 'Expiry';

  @override
  String get mutationFieldRenewalDate => 'Renewal';

  @override
  String get mutationFieldDueDay => 'Due day';

  @override
  String get mutationFieldBillingCycle => 'Cycle';

  @override
  String get mutationFieldIsActive => 'Active';

  @override
  String get mutationFieldForPerson => 'For whom';

  @override
  String get mutationFieldPlace => 'Place';

  @override
  String get mutationFieldNote => 'Note';

  @override
  String get mutationFieldNotes => 'Notes';

  @override
  String get mutationFieldExpectedCost => 'Expected cost';

  @override
  String get mutationFieldCurrency => 'Currency';

  @override
  String get mutationFieldCountry => 'Country';

  @override
  String get mutationFieldPayDay => 'Payday';

  @override
  String get mutationFieldBed => 'Bedtime';

  @override
  String get mutationFieldWake => 'Wake-up';

  @override
  String get mutationFieldDailyCap => 'Daily cap';

  @override
  String get mutationFieldLengthDays => 'Length in days';

  @override
  String get mutationFieldTrade => 'Trade';

  @override
  String get mutationFieldMetric => 'Measure';

  @override
  String get mutationStatusUpcoming => 'Upcoming';

  @override
  String get mutationStatusDone => 'Done';

  @override
  String get mutationStatusCancelled => 'Cancelled';

  @override
  String get mutationStatusActive => 'Active';

  @override
  String get mutationStatusAbandoned => 'Stopped';

  @override
  String get mutationEdited => 'Edited';

  @override
  String get mutationRemoved => 'Removed';

  @override
  String mutationFieldChange(String field, String before, String after) {
    return '$field: $before → $after';
  }

  @override
  String mutationValueChange(String before, String after) {
    return '$before → $after';
  }

  @override
  String mutationMore(String shown, int count) {
    return '$shown • and $count more';
  }

  @override
  String get mutationYes => 'Yes';

  @override
  String get mutationNo => 'No';

  @override
  String mutationItems(int count) {
    return '$count items';
  }

  @override
  String get mutationListSeparator => ', ';

  @override
  String get whyChangedTitle => 'Latest changes';

  @override
  String get whyChangedSubtitle =>
      'Zad\'s automatic edits to your data — what changed, and when';

  @override
  String get whyChangedEmpty => 'No automatic edits recorded yet';

  @override
  String get whyChangedNow => 'Now';

  @override
  String whyChangedMinutesAgo(int minutes) {
    return '$minutes min ago';
  }

  @override
  String whyChangedHoursAgo(int hours) {
    return '$hours h ago';
  }

  @override
  String whyChangedDaysAgo(int days) {
    return '$days d ago';
  }

  @override
  String get memoryForgetAsk => 'Forget this note?';

  @override
  String get memoryForgetBody =>
      'Zad won\'t bring it up again in any future reply.';

  @override
  String get memoryForgetYes => 'Forget it';

  @override
  String get memoryForgotten => 'Forgotten';

  @override
  String get memoryClearOutingsAsk => 'Clear your outings?';

  @override
  String get memoryClearYes => 'Clear them';

  @override
  String get memoryOutingsCleared => 'Your outings were cleared';

  @override
  String get memorySaved => 'Saved';

  @override
  String get memoryTitle => 'What Zad knows about me';

  @override
  String get memoryStaleBanner =>
      'Couldn\'t fetch the latest — this is what was last saved here.';

  @override
  String get memoryNotesHeading => 'What Zad remembers about you';

  @override
  String get memoryEmptyTitle => 'No memories yet';

  @override
  String get memoryProfileTitle => 'Who you are to Zad';

  @override
  String get memoryProfileSubtitle =>
      'Zad talks to you based on this — edit it whenever you like';

  @override
  String get memoryEdit => 'Edit';

  @override
  String get memoryLineName => 'What I call you';

  @override
  String get memoryLineGender => 'Gender';

  @override
  String get memoryLineRole => 'Your role at home';

  @override
  String get memoryLineAge => 'Age';

  @override
  String get memoryLineJob => 'Your work';

  @override
  String get memoryLinePay => 'Payday';

  @override
  String get memoryLineHousehold => 'Household';

  @override
  String get memoryLineCity => 'City';

  @override
  String get memoryLineDialect => 'Dialect';

  @override
  String get memoryDialectDefault => 'Like your country and how you talk';

  @override
  String get memoryLineVoice => 'Zad\'s voice';

  @override
  String get memoryHabitsTitle => 'Your habits and outings';

  @override
  String get memoryHabitsSubtitle =>
      'From your spending and outings — no places or coordinates';

  @override
  String get memoryHabitsEmpty =>
      'Still learning your habits — log your spending and they\'ll show up here.';

  @override
  String get memoryHabitWeekly => 'Average weekly spending';

  @override
  String get memoryHabitTopCategories => 'What you spend most on';

  @override
  String get memoryHabitBusiestDay => 'Your biggest spending day';

  @override
  String get memoryHabitSubscriptions => 'Subscriptions a month';

  @override
  String get memoryHabitOutings => 'Outings, last 30 days';

  @override
  String get memoryHabitPerOuting => 'Average spend per outing';

  @override
  String get memoryHabitTopPlaces => 'Places you go most';

  @override
  String get memoryClearOutingsBody =>
      'We\'ll clear every recorded outing (times, spending and places). The expenses themselves stay.';

  @override
  String get memoryEmptyBody =>
      'Zad will learn about you bit by bit from what you say and how you use the app.';

  @override
  String get memoryUnknown => 'Don\'t know yet';

  @override
  String memoryHouseholdSize(int count) {
    return '$count people';
  }

  @override
  String memoryKidsCount(int count) {
    return '$count kids';
  }

  @override
  String memoryPayDay(int day) {
    return 'Day $day';
  }

  @override
  String memoryOutingsCount(int count) {
    return '$count outings';
  }

  @override
  String get memoryClearOutings => 'Clear my outings';

  @override
  String memoryConfirmedTimes(int count) {
    return 'Confirmed $count times';
  }

  @override
  String memoryAbout(String names) {
    return 'About: $names';
  }

  @override
  String get memoryForgetThis => 'Forget this';

  @override
  String memoryUntil(String date) {
    return 'Until $date';
  }

  @override
  String get brainHealthTitle => 'Zad\'s brain health';

  @override
  String get brainHealthRefresh => 'Refresh';

  @override
  String get brainHealthCannotSeeTitle => 'Can\'t see the brain right now';

  @override
  String get brainHealthRetry => 'Try again';

  @override
  String get brainHealthActivity => 'Activity';

  @override
  String get brainHealthLastProactive => 'Last proactive alert';

  @override
  String get brainHealthRuns7d => 'Runs, last 7 days';

  @override
  String get brainHealthRunsFailed => 'Of which failed';

  @override
  String get brainHealthInsights7d => 'Insights, last 7 days';

  @override
  String get brainHealthInsightsUnseen => 'Insights you haven\'t seen';

  @override
  String get brainHealthLastFailure => 'Last failure type';

  @override
  String get brainHealthFailureBusy => 'Provider busy';

  @override
  String get brainHealthFailureConfig => 'Setup problem';

  @override
  String get brainHealthFailureOther => 'Unknown';

  @override
  String get brainHealthTasks => 'Tasks and queue';

  @override
  String get brainHealthTasksStuck => 'Stuck or late tasks';

  @override
  String get brainHealthTasksPending => 'Tasks waiting their turn';

  @override
  String get brainHealthTasksFailed7d => 'Failed tasks, last 7 days';

  @override
  String get brainHealthNotRetried => 'Requests not retried';

  @override
  String get brainHealthChatUse => 'Chat use';

  @override
  String get brainHealthRequests => 'Requests';

  @override
  String get brainHealthTokens => 'Reply size';

  @override
  String get brainHealthLearning => 'Learning';

  @override
  String get brainHealthGoals => 'Goals Zad is working on';

  @override
  String get brainHealthDrift => 'Unexpected actions by Zad, last 7 days';

  @override
  String get brainHealthHealthy => 'The brain is working fine';

  @override
  String get brainHealthQuiet => 'Something\'s worth a look';

  @override
  String get brainHealthStalled => 'The brain has stopped and needs attention';

  @override
  String get brainHealthAllClear =>
      'No problems spotted. Zad works in the background and logs every step.';

  @override
  String brainHealthDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String brainHealthHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '1 hour',
    );
    return '$_temp0';
  }

  @override
  String get brainHealthNever => 'Never';

  @override
  String get brainHealthJustNow => 'Just now';

  @override
  String get brainHealthReasonNoProactiveYet =>
      'Zad is still getting to know you, and will start sending proactive alerts after a little use';

  @override
  String brainHealthReasonProactiveSilent(String duration) {
    return 'Zad hasn\'t sent a proactive alert for $duration';
  }

  @override
  String brainHealthReasonTasksBackedUp(int count) {
    return 'Stuck or late tasks: $count';
  }

  @override
  String brainHealthReasonRunsFailing(int failed, int total) {
    return 'Failed runs: $failed of $total';
  }

  @override
  String brainHealthReasonTasksFailed(int count) {
    return 'Failed tasks: $count';
  }

  @override
  String brainHealthReasonNotRetried(int count) {
    return 'Requests not retried: $count';
  }

  @override
  String brainHealthReasonQuotaNear(int percent) {
    return 'Chat use is close to the daily limit ($percent%) — replies may stop until tomorrow';
  }

  @override
  String get brainHealthCannotSee =>
      'I couldn\'t read the brain\'s state right now. That doesn\'t mean everything\'s fine — it means I can\'t see.';

  @override
  String brainHealthOf(int used, int limit) {
    return '$used of $limit';
  }

  @override
  String get brainHealthQuotaNote =>
      'This allowance is for chat replies only and resets every day at midnight GMT — it has nothing to do with Zad\'s background work';

  @override
  String get staffTitle => 'Zad\'s team';

  @override
  String get brainHubStaffSubtitle =>
      'What the team noticed on the morning round of your home, money and family';

  @override
  String get brainHubMemorySubtitle =>
      'What Zad remembers about you and talks to you by — correct it or have it forget';

  @override
  String get brainGraphTitle => 'Zad\'s network';

  @override
  String get brainMapTitle => 'Zad\'s map';

  @override
  String get brainHubMapSubtitle =>
      'How your budget, subscriptions and home connect';

  @override
  String get brainHubLogSubtitle =>
      'Everything Zad logged or changed for you, with an undo if it was wrong';

  @override
  String get brainHubHealthSubtitle =>
      'Is Zad working in the background or stuck — and if stuck, why';

  @override
  String get brainHubTitle => 'Zad\'s brain';

  @override
  String get brainHubGraphSubtitle =>
      'The people, places and things Zad knows and how they connect — and export it to Obsidian';

  @override
  String get staffRolePantry => 'Pantry keeper';

  @override
  String get staffRolePharmacy => 'The nurse';

  @override
  String get staffRoleFinance => 'The accountant';

  @override
  String get staffRoleFamily => 'Family secretary';

  @override
  String get staffRoleHome => 'Home manager';

  @override
  String get staffRoleResearch => 'The researcher';

  @override
  String get staffRoleCoach => 'Setup coach';

  @override
  String get staffIntro =>
      'Every morning the team does a round of your home: pantry, pharmacy, money, family and settings — and tells Zad what needs attention.';

  @override
  String get staffEmptyTitle => 'The team found nothing worth flagging';

  @override
  String get staffEmptyBody =>
      'The next round is in the morning — anything they find will show up here.';

  @override
  String get staffLoadFailed => 'Couldn\'t load the team\'s notes';

  @override
  String get profileSheetPayDay => 'What day of the month do you get paid?';

  @override
  String get profileSheetPayFrequency => 'How often you get paid';

  @override
  String get profileSheetHouseholdSize => 'People at home';

  @override
  String get profileSheetKids => 'Number of kids';

  @override
  String get profileSheetSave => 'Save';

  @override
  String get entityPerson => 'Person';

  @override
  String get entityPlace => 'Place';

  @override
  String get entityItem => 'Item';

  @override
  String get entityOrg => 'Organisation';

  @override
  String get entityPeople => 'People';

  @override
  String get entityPlaces => 'Places';

  @override
  String get entityItems => 'Items';

  @override
  String get entityOrgs => 'Organisations';

  @override
  String graphNotesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes',
      one: '1 note',
    );
    return '$_temp0';
  }

  @override
  String graphNoNotesAbout(String name) {
    return 'No notes about $name yet.';
  }

  @override
  String graphSemantics(int count) {
    return 'A network of $count — the list below has the same things';
  }

  @override
  String get graphExportFailed => 'Couldn\'t prepare the files. Try again.';

  @override
  String get graphShareSubject => 'Zad\'s network — Obsidian';

  @override
  String get graphShareTitle => 'Export Zad\'s network';

  @override
  String get graphExport => 'Export to Obsidian';

  @override
  String get graphEmptyTitle => 'No network yet';

  @override
  String get graphLoadFailed => 'Couldn\'t load the network';

  @override
  String get graphCheckNet => 'Check your connection and try again.';

  @override
  String get graphEmptyBody =>
      'Whenever you tell Zad about your people, places and things, they show up here, connected.';

  @override
  String get graphRetry => 'Try again';

  @override
  String mapPerMonth(String amount) {
    return '$amount/month';
  }

  @override
  String mapLeft(String amount) {
    return '$amount left';
  }

  @override
  String get mapDomainBudget => 'Budget';

  @override
  String get mapDomainObligations => 'Commitments';

  @override
  String get mapDomainSubscriptions => 'Subscriptions and instalments';

  @override
  String get mapDomainDebts => 'Debts';

  @override
  String get mapDomainPantry => 'Pantry';

  @override
  String get mapDomainShopping => 'Shopping list';

  @override
  String get mapDomainPharmacy => 'Family pharmacy';

  @override
  String get mapDomainMaintenance => 'Maintenance';

  @override
  String mapAskAbout(String label) {
    return 'Tell me more about $label';
  }

  @override
  String mapNodeCount(int count) {
    return '$count connected items';
  }

  @override
  String get mapLegendComputed => 'A link actually computed';

  @override
  String get mapLegendNotYet => 'Not counted yet';

  @override
  String get mapLegendLive => 'Zad has a live insight here now';

  @override
  String get mapZoomIn => 'Zoom in';

  @override
  String get mapZoomOut => 'Zoom out';

  @override
  String get mapReset => 'Reset';

  @override
  String get mapReserved => 'Reserved';

  @override
  String get mapAvailable => 'Available';

  @override
  String get mapAskZad => 'Ask Zad';

  @override
  String get mapNothingHere => 'Nothing here right now';

  @override
  String get mapOpenScreen => 'Open the screen';

  @override
  String get brainFamilySavingsPots => 'Savings pots';

  @override
  String get brainFamilyAchievements => 'Achievements and ranks';

  @override
  String get brainFamilyTasbiha => 'Tasbiha';

  @override
  String get brainFamilyFamily => 'Family';

  @override
  String get reportDaySaturday => 'Saturday';

  @override
  String get reportDaySunday => 'Sunday';

  @override
  String get reportDayMonday => 'Monday';

  @override
  String get reportDayTuesday => 'Tuesday';

  @override
  String get reportDayWednesday => 'Wednesday';

  @override
  String get reportDayThursday => 'Thursday';

  @override
  String get reportDayFriday => 'Friday';

  @override
  String get reportHealthExcellent => 'Excellent 🌟';

  @override
  String get reportHealthGood => 'Good 👍';

  @override
  String get reportHealthWatch => 'Needs attention ⚠️';

  @override
  String get reportDanger => 'Danger 🚨';

  @override
  String reportTopSpend(String category, String amount) {
    return 'Your biggest spend this month: $category ($amount)';
  }

  @override
  String reportOverBudget(String category, String amount) {
    return '⛔ You went over the $category budget by $amount';
  }

  @override
  String reportSubsCost(String monthly, String yearly) {
    return 'Your active subscriptions cost you $monthly a month ($yearly a year)';
  }

  @override
  String reportSubsShare(int percent, String title, String amount) {
    return '💡 Subscriptions are $percent% of your budget — check $title ($amount) if you don\'t use it';
  }

  @override
  String reportStreams(int count, String amount) {
    return '📺 You have $count streaming services — cancelling one saves you $amount a month';
  }

  @override
  String reportRunningOut(String name, int days) {
    return '🛒 $name is expected to run out within $days days';
  }

  @override
  String reportRunway(String perDay, int days) {
    return 'At your current pace ($perDay/day), the balance lasts $days days';
  }

  @override
  String get reportPowerUnknown => 'Not set';

  @override
  String get reportPowerStrong => 'Strong 💪';

  @override
  String get reportPowerBalanced => 'Balanced ⚖️';

  @override
  String get reportPowerWeak => 'Weak ⚠️';

  @override
  String get reportDayUnknown => 'Unknown';

  @override
  String reportTooFast(String current, String safe) {
    return '⚡ Your daily spending ($current) is above the safe pace ($safe) — ease off a bit';
  }

  @override
  String reportSpentLess(int percent, String amount) {
    return '🎉 You spent $percent% less than the same point last month — you saved $amount!';
  }

  @override
  String reportSpentMore(int percent) {
    return '📈 Your spending is up $percent% on the same point last month';
  }

  @override
  String reportImpulse(int count) {
    return '🛍️ $count impulse buys in the last 30 days (more than twice your average)';
  }

  @override
  String get reportExportUnknown => 'Not set yet';

  @override
  String reportExportTitle(String month) {
    return '📊 Zad money report — $month';
  }

  @override
  String reportExportHealth(int score, String label) {
    return 'Financial health: $score/100 ($label)';
  }

  @override
  String reportExportPower(String status, String safe) {
    return 'Spending power: $status — safe per day: $safe';
  }

  @override
  String get reportExportNumbers => '💰 The numbers:';

  @override
  String reportExportBudget(String amount) {
    return '• Budget: $amount';
  }

  @override
  String reportExportSpent(String amount) {
    return '• Spent: $amount';
  }

  @override
  String reportExportIncome(String amount) {
    return '• Income: $amount';
  }

  @override
  String reportExportLeft(String amount) {
    return '• Left: $amount';
  }

  @override
  String reportExportSubs(String amount) {
    return '• Subscriptions: $amount/month';
  }

  @override
  String get reportExportCompare => '📅 Compared with last month (same point):';

  @override
  String reportExportCompareLine(String now, String before, String delta) {
    return '• This month: $now | last: $before ($delta%)';
  }

  @override
  String get reportExportByCategory => '🗂️ By category:';

  @override
  String reportExportOfBudget(String budget, int percent) {
    return ' of $budget ($percent%)';
  }

  @override
  String get reportExportTopMerchants => '🏪 Top places:';

  @override
  String get reportExportBehaviour => '🧠 Your money habits:';

  @override
  String reportExportTopDay(String day) {
    return '• Top spending day: $day';
  }

  @override
  String reportExportWeekend(int percent) {
    return '• Weekend spending: $percent% of the total';
  }

  @override
  String reportExportAvgTxn(String amount) {
    return '• Average transaction: $amount';
  }

  @override
  String reportExportImpulse(int count) {
    return '• Impulse buys (30 days): $count';
  }

  @override
  String get reportExportNotes => '💡 Zad\'s notes:';

  @override
  String get reportExportFooter => '— A report from the Zad app 🥕';

  @override
  String get reportScreenTitle => 'Zad\'s monthly report';

  @override
  String get reportShareFamily => 'Share with the family';

  @override
  String get reportHealthHeading => 'Financial health';

  @override
  String get reportButton => 'Monthly report';

  @override
  String get reportShareSubject => 'Zad money report';

  @override
  String get reportShareTitle => 'Share Zad report';

  @override
  String get intelPromptAnalyse => 'Analyse my spending 📊';

  @override
  String get intelPromptForecast => 'Forecast next month\'s spending 🔮';

  @override
  String get intelPromptLunch => 'Suggest a lunch 🍲';

  @override
  String get intelPromptSafe => 'Am I financially safe? 💰';

  @override
  String intelSosFrom(String name) {
    return 'Emergency call from $name!';
  }

  @override
  String get intelNeedThreeBody =>
      'Zad\'s brain needs at least 3 expenses to analyse your spending properly and build resilience reports.';

  @override
  String intelLoggedOfThree(int count) {
    return '$count of 3 expenses logged';
  }

  @override
  String get intelReportSubtitle =>
      'An instant, detailed analysis of all your transactions and spending by AI models';

  @override
  String get intelReportWorking =>
      'Analysing transactions and building the AI report...';

  @override
  String intelCoverageDays(int days) {
    return '$days days covered';
  }

  @override
  String intelTargetDays(int days) {
    return 'Goal: $days days';
  }

  @override
  String intelSaveToReach(String amount) {
    return 'Save $amount a month to reach the goal';
  }

  @override
  String intelTopCategory(String category, int percent) {
    return '💡 Your biggest category is [$category] at $percent% of your spending';
  }

  @override
  String get intelHeroTitle => 'Zad\'s smart brain';

  @override
  String get intelHeroBusy => 'Zad is analysing your data now 🧠✨';

  @override
  String get intelHeroReady =>
      'Connected and ready to help with your money and home ⚡';

  @override
  String get intelNoAnswer => 'Zad couldn\'t answer right now — try again.';

  @override
  String get intelAnalysing => 'Zad is analysing...';

  @override
  String get intelExplain => 'Explain with AI';

  @override
  String get intelNeedThreeTitle =>
      'Log your first 3 expenses to switch on Zad\'s analysis';

  @override
  String get intelTalkNow => 'Talk to Zad now 💬';

  @override
  String get intelReportTitle => 'Build the full AI report';

  @override
  String get intelSharePdf => 'Share the report as PDF';

  @override
  String get intelSaveFailed =>
      'Couldn\'t save the changes — check your connection and try again';

  @override
  String get intelRetry => 'Retry';

  @override
  String get intelRefreshReport => 'Refresh the report 🔄';

  @override
  String get intelUpdateBalance => 'Update the balance';

  @override
  String get intelFundBalance => 'Emergency fund balance';

  @override
  String get intelCancel => 'Cancel';

  @override
  String get intelSave => 'Save';

  @override
  String get intelStatusCritical => 'Critical';

  @override
  String get intelStatusLow => 'Low';

  @override
  String get intelStatusHealthy => 'Healthy';

  @override
  String get intelStressTitle => 'Financial resilience test';

  @override
  String get intelStressQuestion =>
      'How many days could you last if your income stopped?';

  @override
  String get intelAvailableNoFund =>
      'Your available balance (no emergency fund set yet)';

  @override
  String get intelDailyAverage => 'Average daily spending';

  @override
  String get intelDistributionTitle => 'Spending breakdown and habits';

  @override
  String get intelDistributionSubtitle =>
      'How your spending splits across categories, with smart habit notes';

  @override
  String dossierIssued(String date) {
    return 'Issued: $date';
  }

  @override
  String get dossierSafeDailyUnknown =>
      '• Safe daily spending: needs a set budget and balance to work out.';

  @override
  String dossierSafeDaily(String amount) {
    return '• Recommended safe daily spending: $amount/day.';
  }

  @override
  String dossierSpentCycle(String amount) {
    return '• Total actually spent this cycle: $amount.';
  }

  @override
  String dossierFamilyMembers(int count) {
    return '• The family\'s shared brain: $count members connected and synced live.';
  }

  @override
  String dossierLowStock(int count) {
    return '• Pantry items running low: $count.';
  }

  @override
  String dossierAdherence(int percent) {
    return '• Medicine adherence this week: $percent%.';
  }

  @override
  String get dossierAdherenceUnknown =>
      '• Medicine adherence: not enough doses logged yet to work out a rate.';

  @override
  String get dossierShareHeading => '📄 Zad\'s brain report:';

  @override
  String dossierShareSpent(String amount) {
    return '• Total spent: $amount';
  }

  @override
  String dossierShareAdherence(int percent) {
    return '• Medicine adherence: $percent%';
  }

  @override
  String get dossierTitle => 'Zad\'s full strategic report';

  @override
  String get dossierSection1 => '1. Next month\'s forecasts and cash flow';

  @override
  String get dossierSection2 => '2. How well the home and family are run';

  @override
  String get dossierShareTitle => 'Share Zad\'s brain report';

  @override
  String get dossierShare => '📤 Share the report';

  @override
  String get dossierClose => 'Close the report';

  @override
  String get weekdaySat => 'Sat';

  @override
  String get weekdaySun => 'Sun';

  @override
  String get weekdayMon => 'Mon';

  @override
  String get weekdayTue => 'Tue';

  @override
  String get weekdayWed => 'Wed';

  @override
  String get weekdayThu => 'Thu';

  @override
  String get weekdayFri => 'Fri';

  @override
  String behaviourNew(String name, String amount) {
    return '$name: new this month ($amount)';
  }

  @override
  String behaviourUp(String name, int percent, String before, String after) {
    return '$name: up $percent% ($before → $after)';
  }

  @override
  String behaviourDown(String name, int percent, String before, String after) {
    return '$name: down $percent% ($before → $after)';
  }

  @override
  String behaviourPeakDay(String day, String amount) {
    return 'Your biggest spending day: $day — average $amount';
  }

  @override
  String behaviourPlaceLine(String amount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count times',
      one: 'once',
    );
    return '$amount · $_temp0';
  }

  @override
  String get behaviourTitle => 'Your spending habits';

  @override
  String get behaviourTopPlaces => 'Where you spend most';

  @override
  String get behaviourChanges => 'What changed since last month';

  @override
  String get chartsTwoWeeks => 'Your spending, last two weeks';

  @override
  String chartsTotals(String total, String daily) {
    return 'Total $total · daily average $daily';
  }

  @override
  String get chartsWhere => 'Where your money went (last month)';

  @override
  String get reportsRowFailed => 'Couldn\'t prepare the report right now';

  @override
  String get reportsRowMonthly => 'Export the monthly report';

  @override
  String get reportsRowStrategic => 'The strategic report';

  @override
  String get familyTitle => 'Family';

  @override
  String get familyLoadingTitle => 'Finding your family';

  @override
  String get familyLoadingMessage =>
      'The first time needs internet. Pull down if it takes a while.';

  @override
  String get familyRetry => 'Try again';

  @override
  String get familyWelcomeTitle => 'Welcome to Zad Family';

  @override
  String get familyWelcomeBody =>
      'Start a new family and run it yourself, or join one you already have with its invite code.';

  @override
  String get familyCreateAsAdmin => 'Start a new family as admin';

  @override
  String get familyJoin => 'Join a family';

  @override
  String get familyOr => 'or';

  @override
  String get familyAliasLabel => 'Your name in the family (optional)';

  @override
  String get familyAliasHint => 'e.g. Ahmed (son)';

  @override
  String get familyInviteCodeLabel => 'Invite code';

  @override
  String get familyInviteCodeHint => 'e.g. ZAD-1234';

  @override
  String get familyTabChat => 'Chat';

  @override
  String get familyTabTasks => 'Tasks';

  @override
  String get familyTabMembers => 'Members';

  @override
  String get familyTabGroceries => 'Groceries';

  @override
  String get familyTabKids => 'Kids';

  @override
  String get familyTabGoals => 'Goals';

  @override
  String familyHeaderTitle(String code) {
    return 'Family $code';
  }

  @override
  String familyMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return '$_temp0';
  }

  @override
  String get familySosTooltip => 'Emergency — alert everyone!';

  @override
  String get familyInviteNew => 'Invite new members';

  @override
  String get familyShareInvite => 'Share invite';

  @override
  String familyShareInviteText(String code, String link) {
    return '🌱 Join my family on Zad\n\n📲 Tap this link to join right away and open the app:\nhttps://zad.app/invite?code=$code\n\n🔑 Invite code:\n$code\n\n🔗 Direct app link:\n$link';
  }

  @override
  String get familySosConfirmTitle => 'Send an emergency alert?';

  @override
  String get familySosConfirmBody =>
      'Everyone in the family gets an instant alert that you need help. Are you sure?';

  @override
  String get familySosSend => 'Send alert';

  @override
  String familyInviteShareText(String code, String link) {
    return 'Join my family on Zad!\nInvite code: $code\nOr open the link: $link';
  }

  @override
  String familyInviteShareQr(String link) {
    return 'Join my family on Zad! Scan the code: $link';
  }

  @override
  String familyInviteShareLink(String link) {
    return 'Join my family on Zad!\nInvite link: $link';
  }

  @override
  String familyInviteShareCode(String code) {
    return 'Join my family on Zad!\nInvite code: $code';
  }

  @override
  String get familyInviteMethodLink => 'Link';

  @override
  String get familyInviteMethodCode => 'Code';

  @override
  String get familyInviteMethodWhatsapp => 'WhatsApp';

  @override
  String get familyInviteScanToJoin => 'Scan to join:';

  @override
  String get familyInviteLinkLabel => 'Invite link:';

  @override
  String get familyCopy => 'Copy';

  @override
  String get familyInviteCodeColon => 'Invite code:';

  @override
  String get familyInviteShareWhatsapp => 'Share on WhatsApp:';

  @override
  String get familyInviteAllApps => 'All apps';

  @override
  String get familyShare => 'Share';

  @override
  String get familyPasteInvite => 'Paste the invite link or code';

  @override
  String get familyAddTaskTitle => 'New task';

  @override
  String get familyTaskNameLabel => 'Task';

  @override
  String get familyTaskNameHint => 'e.g. Tidy the room';

  @override
  String get familyReward => 'Reward';

  @override
  String familyRewardIn(String currency) {
    return 'Reward ($currency)';
  }

  @override
  String get familyAssignee => 'Who does it:';

  @override
  String get familyDueDateOptional => 'Due date (optional)';

  @override
  String get familyQuickGroceryTitle => 'Add to the shopping list';

  @override
  String get familyQuickGroceryHint => 'e.g. Milk';

  @override
  String get familyMoneyRequestTitle => 'Ask for money or a purchase';

  @override
  String get familyMoneyRequestWhat => 'What do you want to buy?';

  @override
  String get familyMoneyRequestAmount => 'Amount';

  @override
  String familyMoneyRequestAmountIn(String currency) {
    return 'Amount ($currency)';
  }

  @override
  String get familyMoneyRequestSend => 'Send request';

  @override
  String get familySpendLimitTitle => 'Spending limit';

  @override
  String familySpendLimitBody(String name) {
    return 'Set the most $name can spend a day or a week. Leave it empty for no limit.';
  }

  @override
  String familyDailyLimitIn(String currency) {
    return 'Daily limit ($currency)';
  }

  @override
  String familyWeeklyLimitIn(String currency) {
    return 'Weekly limit ($currency)';
  }

  @override
  String get familyPollClosesTomorrow => 'Tomorrow';

  @override
  String get familyPollClosesTwoDays => 'In 2 days';

  @override
  String get familyPollClosesWeek => 'In a week';

  @override
  String get familyPollClosesByHand => 'I\'ll close it';

  @override
  String get familyPollTitle => 'Family poll';

  @override
  String get familyPollQuestion => 'Question';

  @override
  String familyPollOption(int n) {
    return 'Option $n';
  }

  @override
  String get familyPollAddOption => '+ Add option';

  @override
  String get familyPollClosesWhen => 'Closes when?';

  @override
  String get familyPollSend => 'Send poll';

  @override
  String get familyTasksHeading => 'Family tasks';

  @override
  String familyTasksDoneOf(int done, int total) {
    return '$done/$total done';
  }

  @override
  String get familyFilterAll => 'All';

  @override
  String get familyFilterPending => 'Upcoming';

  @override
  String get familyFilterDone => 'Done';

  @override
  String get familyNoTasksTitle => 'No tasks yet';

  @override
  String get familyNoTasksMessage => 'Add a task so the family can pitch in';

  @override
  String get familyMembersHeading => 'Family members';

  @override
  String get familyMembersHint => 'Tap anyone to see what they\'ve done';

  @override
  String get familyReport => 'Family report';

  @override
  String get familyDeleteAndRecreate => 'Delete the family and start over';

  @override
  String get familyLeave => 'Leave the family';

  @override
  String get familyDeleteForeverTitle => 'Delete the family for good';

  @override
  String get familyLeaveConfirmTitle => 'Leave the family?';

  @override
  String get familyDeleteForeverBody =>
      'You\'re the last one in this family. Deleting it wipes the chat, the tasks and all its data for good — there\'s no getting it back. You can start a new family afterwards.';

  @override
  String get familyLeaveConfirmBody =>
      'You\'ll lose the family chat, the tasks and the shared balances. Are you sure you want to leave?';

  @override
  String get familyDeleteForever => 'Delete for good';

  @override
  String get familyLeaveShort => 'Leave';

  @override
  String familyTasksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks',
      one: '1 task',
    );
    return '$_temp0';
  }

  @override
  String familyTasbihaCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasbihs',
      one: '1 tasbih',
    );
    return '$_temp0';
  }

  @override
  String get familySavingsGoal => 'Savings goal';

  @override
  String get familyRoleAdminShort => 'Admin';

  @override
  String get familyRoleChild => 'Child';

  @override
  String get familyRoleAdminLong => 'Family admin';

  @override
  String get familyRoleMember => 'Member';

  @override
  String get familyBalance => 'Balance';

  @override
  String get familyGoal => 'Goal';

  @override
  String get familyTrees => 'Trees';

  @override
  String familyDoneTasksTitle(int count) {
    return 'Done ($count)';
  }

  @override
  String get familyNoDoneTasks => 'Nothing done yet';

  @override
  String familyUpcomingTasksTitle(int count) {
    return 'Upcoming ($count)';
  }

  @override
  String get familyNoUpcomingTasks => 'Nothing coming up';

  @override
  String familyTreesTitle(int count) {
    return 'Tasbih trees ($count)';
  }

  @override
  String get familyDaily => 'Daily';

  @override
  String get familyWeekly => 'Weekly';

  @override
  String get familyRoleInFamily => 'Role in the family';

  @override
  String familyRemoveMemberTitle(String name) {
    return 'Remove $name from the family?';
  }

  @override
  String get familyRemoveMemberShort => 'Remove';

  @override
  String get familyRemoveMember => 'Remove from the family';

  @override
  String familyRewardAmount(String amount) {
    return 'Reward: $amount';
  }

  @override
  String get familyNoLimit => 'No limit';

  @override
  String get familyGroceriesHeading => 'Shared groceries';

  @override
  String get familyGroceriesHint =>
      'What the family added to the shopping list, or Zad suggested.';

  @override
  String get familyNoGroceriesTitle => 'Nothing on the grocery list.';

  @override
  String get familyNoGroceriesMessage =>
      'Type \"add milk\" in the chat, or tap + above.';

  @override
  String get familyKidsHeading => 'Kids\' spending';

  @override
  String get familyKidsHint => 'Your kids\' balances and requests at a glance';

  @override
  String get familyNoKidsTitle => 'No kids added yet';

  @override
  String get familyNoKidsMessage =>
      'In the Members tab, set anyone as a \"child\".';

  @override
  String get familyPauseTitle => '24-hour think-it-over';

  @override
  String get familyPauseBody =>
      'A purchase request can\'t be approved until a day after it was sent. You can still say no anytime, and allowance requests aren\'t affected.';

  @override
  String familyAllowanceFor(String name) {
    return 'Allowance for $name';
  }

  @override
  String familyAmountIn(String currency) {
    return 'Amount ($currency)';
  }

  @override
  String get familyAllowanceHelper => 'Goes straight into their balance';

  @override
  String get familyTransfer => 'Send';

  @override
  String familyBalanceIs(String amount) {
    return 'Balance: $amount';
  }

  @override
  String familyGoalIs(String amount) {
    return 'Goal: $amount';
  }

  @override
  String familyKidTasksDoneOf(int done, int total) {
    return '$done/$total tasks';
  }

  @override
  String get familySendAllowance => 'Send allowance';

  @override
  String get familyMonthlySpending => 'Monthly spending';

  @override
  String familyPendingRequests(int count) {
    return 'Waiting for you ($count)';
  }

  @override
  String get familyApprove => 'Approve';

  @override
  String get familyReject => 'Decline';

  @override
  String get familyBudgetRewardsHeading => 'Budget and rewards';

  @override
  String get familySavingsGoalTitle => 'Family savings goal';

  @override
  String get familyNoSavingsGoal => 'No savings goal for this month yet';

  @override
  String get familySuggestGoal => 'Suggest a goal with AI';

  @override
  String get familyNoKidsStatsTitle => 'No kids added to show stats for.';

  @override
  String get familyKidsBalanceStats => 'Kids\' balances';

  @override
  String get familyTotalRewardsPaid => 'Total rewards paid';

  @override
  String familyGoalSuggestionBody(String amount, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Goal: $amount in $days days',
      one: 'Goal: $amount in 1 day',
    );
    return '$_temp0';
  }

  @override
  String get familyApproveGoal => 'Set this goal';

  @override
  String get familyChatEmptyTitle => 'No messages yet';

  @override
  String get familyChatEmptyMessage =>
      'Say hi — send your family the first message';

  @override
  String get familyChatAddTasks => 'Add tasks';

  @override
  String get familyChatAskGroceries => 'Ask for groceries';

  @override
  String get familyChatAskZad => 'Ask @Zad';

  @override
  String get familyZadName => 'Zad';

  @override
  String get familyVoiceMessage => 'Voice message';

  @override
  String get familyUnpin => 'Unpin';

  @override
  String get familyPin => 'Pin';

  @override
  String get familyReact => 'React';

  @override
  String familySosFrom(String name) {
    return 'Emergency alert from $name!';
  }

  @override
  String familyPurchaseRequestFrom(String name) {
    return 'Purchase request from $name';
  }

  @override
  String get familyApproveAndDeduct => 'Approve and deduct';

  @override
  String get familyApproved => 'Approved';

  @override
  String get familyRejected => 'Declined';

  @override
  String familyPollFrom(String name) {
    return 'Poll from $name';
  }

  @override
  String familyPollTimeCloses(String time, String when) {
    return '$time · closes $when';
  }

  @override
  String get familyPollClose => 'Close poll';

  @override
  String get familyPollClosedNoVotes => 'Closed with no votes';

  @override
  String get familyPollClosedTie => 'Closed on a tie — it\'s your call';

  @override
  String familyPollAdultsAgreed(String option) {
    return 'All the grown-ups agreed on “$option” ✅';
  }

  @override
  String familyPollMajority(String option) {
    return 'Most picked “$option”';
  }

  @override
  String get familyClosesWithinHour => 'within the hour';

  @override
  String familyClosesInHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'in $hours hours',
      one: 'in 1 hour',
    );
    return '$_temp0';
  }

  @override
  String get familyClosesTomorrow => 'tomorrow';

  @override
  String familyClosesInDays(int days) {
    return 'in $days days';
  }

  @override
  String get familyQuickReplies => 'Quick replies';

  @override
  String get familySosShort => 'Emergency alert';

  @override
  String get familyAskMoney => 'Ask for money';

  @override
  String get familyPollShort => 'Poll';

  @override
  String get familyChatHint => 'Write a message or @Zad...';

  @override
  String get familySend => 'Send';

  @override
  String get familySomeoneInFamily => 'someone in the family';

  @override
  String familyLocationDisclosure(String asker) {
    return 'Zad will know when you arrive at or leave the places $asker sets (like school) — even with the app closed — and tell them if you leave during the hours they chose. Your location isn\'t sent all the time, and neither is your route. A notification stays visible the whole time sharing is on, and you can stop it from “My family” anytime. On the next step, choose “Allow all the time”.';
  }

  @override
  String get familyServerUnreachable =>
      'Couldn\'t reach the server. Try again.';

  @override
  String get familyShareComingGoingTitle =>
      'Share your arrivals and departures';

  @override
  String get familyNotNow => 'Not now';

  @override
  String get familyAgreeContinue => 'OK, continue';

  @override
  String get familyAcceptedNeedAlways =>
      'You agreed, but location needs “Allow all the time” to work with the app closed.';

  @override
  String get familyAcceptedZones =>
      'You agreed — it\'ll work on the places they set.';

  @override
  String get familyAcceptedOffline =>
      'You agreed. I\'ll finish when the internet\'s back.';

  @override
  String get familyFollowRequests => 'Follow requests';

  @override
  String get familyFollowRequestsHint =>
      'Nobody sees anything without your yes, and you can stop anytime.';

  @override
  String get familyDeclinedFollow => 'OK, they won\'t see it.';

  @override
  String get familyNo => 'No';

  @override
  String familyAcceptedScope(String scope) {
    return 'Done — they can follow: $scope.';
  }

  @override
  String get familyAgree => 'Agree';

  @override
  String get familyWhoFollowsYou => 'Who follows you';

  @override
  String get familyFollowStopped => 'Following stopped.';

  @override
  String get familyFollowRequestSent =>
      'Request sent — you\'ll see it once they agree.';

  @override
  String get familyFollowRequestFailed =>
      'Couldn\'t send the request. Try again.';

  @override
  String get familyFollowing => 'Following';

  @override
  String get familyFollowLoadFailed =>
      'Couldn\'t load what\'s shared right now.';

  @override
  String get familyFollowLoading => 'Loading what\'s shared…';

  @override
  String familyScopeStatus(String scope, String status) {
    return '$scope: $status';
  }

  @override
  String get familyShareNotAsked => 'not asked';

  @override
  String get familySharePending => 'waiting for their yes';

  @override
  String get familyShareGranted => 'agreed ✅';

  @override
  String get familyShareDeclined => 'declined';

  @override
  String get familyShareRevoked => 'stopped';

  @override
  String get familyAskToFollow => 'Ask to follow';

  @override
  String get familyWhatToFollow => 'What do you want to follow?';

  @override
  String get familyWhatToFollowHint =>
      'They get a request and choose. Nothing shows before they say yes.';

  @override
  String get familySendRequest => 'Send request';

  @override
  String get familyDoseMissed => '❌ missed';

  @override
  String get familyDoseDue => '⏰ due now';

  @override
  String familyDoseNoTimes(String name) {
    return '$name: no set times';
  }

  @override
  String get familyMedicinesToday => 'Medicines today';

  @override
  String get familyNoMedicines => 'No medicines saved.';

  @override
  String get familySpendingLast30 => 'Spending, last 30 days';

  @override
  String get familyTasksAndAppointments => 'Tasks and appointments';

  @override
  String get familyNoOpenTasks => 'No open tasks';

  @override
  String familyOpenTasksStill(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks still open',
      one: '1 task still open',
    );
    return '$_temp0';
  }

  @override
  String get familyReportLoading => 'Loading…';

  @override
  String familyReportMissedSuffix(int count) {
    return ' — $count missed';
  }

  @override
  String get familyReportNoDosesToday => 'No doses today';

  @override
  String familyReportDoses(int taken, int total, String late) {
    return 'Doses: $taken of $total$late';
  }

  @override
  String familyReportSpent30(String amount) {
    return 'Spent in 30 days: $amount';
  }

  @override
  String familyReportOpenTasks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count open tasks',
      one: '1 open task',
    );
    return '$_temp0';
  }

  @override
  String familyZoneInside(String place) {
    return 'at $place';
  }

  @override
  String familyZoneLeft(String place) {
    return 'left $place';
  }

  @override
  String familyZoneUnknown(String place) {
    return '$place: nothing yet';
  }

  @override
  String get familyReportNothingShared =>
      'Hasn\'t agreed to share anything yet';

  @override
  String familyReportNotShared(String scopes) {
    return 'Not shared: $scopes';
  }

  @override
  String get familyListSeparator => ', ';

  @override
  String get familyReportHint =>
      'Only what each person agreed to share — the rest shows once they say yes.';

  @override
  String get familyReportNoMembers =>
      'Nobody has joined yet. Send the invite code from “My family”.';

  @override
  String get familyMemberFallback => 'Family member';

  @override
  String familyWeekday(String day) {
    String _temp0 = intl.Intl.selectLogic(day, {
      'd0': 'Sun',
      'd1': 'Mon',
      'd2': 'Tue',
      'd3': 'Wed',
      'd4': 'Thu',
      'd5': 'Fri',
      'd6': 'Sat',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get familyZoneNoMoves => 'No arrivals or departures yet';

  @override
  String familyZoneInsideSince(String day, String time) {
    return 'In since $day$time';
  }

  @override
  String familyZoneLeftAt(String day, String time) {
    return 'Left $day$time';
  }

  @override
  String familyZoneSaved(String place) {
    return 'Saved “$place” — they\'ll get a notification about it.';
  }

  @override
  String get familyZoneSaveFailed => 'Couldn\'t save the place. Try again.';

  @override
  String familyZoneRemoved(String place) {
    return 'Removed “$place”.';
  }

  @override
  String get familyZoneRemoveFailed => 'Couldn\'t remove it. Try again.';

  @override
  String get familyPlaces => 'Places';

  @override
  String get familyNoZones =>
      'No places yet. While you\'re at the school itself, tap “Add a place”.';

  @override
  String get familyRemoveZone => 'Remove place';

  @override
  String get familyAddZone => 'Add a place';

  @override
  String get familyZoneSchool => 'School';

  @override
  String get familyZoneClub => 'Club';

  @override
  String get familyZoneHome => 'Home';

  @override
  String get familyZoneOther => 'Somewhere else';

  @override
  String get familyLocationFailed =>
      'Couldn\'t find where you are. Turn on location and try again.';

  @override
  String get familyNewZone => 'New place';

  @override
  String get familyNewZoneHint =>
      'You get an alert if they leave it on these days and hours. Outside them it\'s logged without an alert.';

  @override
  String get familyZoneNameLabel => 'Name';

  @override
  String get familyZoneNameHint => 'Nile School';

  @override
  String get familyUseMyLocation => 'Use where I am right now';

  @override
  String get familyLocationSet => 'Place set ✓ — tap again if you moved';

  @override
  String get familyBeThere => 'You need to be at the place itself to set it.';

  @override
  String get familyZoneRadius => 'How far around it';

  @override
  String familyMeters(int meters) {
    return '$meters m';
  }

  @override
  String get familyAlertDays => 'Alert days';

  @override
  String get familyAlertHours => 'Alert hours';

  @override
  String familyFromTime(String time) {
    return 'From $time';
  }

  @override
  String familyToTime(String time) {
    return 'Until $time';
  }

  @override
  String get familyHoursOrder => 'The start has to be before the end.';

  @override
  String get familySaveZone => 'Save place';

  @override
  String get familyChatReadingDisclosure =>
      'Zad will read only your own messages in the family chat — never anyone else\'s who hasn\'t agreed — to pick up household requests like “we need bread” and answer if someone in the family asks about what was said. The messages are sent to an AI model (Google Gemini) to be understood. The whole family will see that you agreed, and you can stop anytime from here.';

  @override
  String get familyChatReadingTitle => 'Let Zad read your messages?';

  @override
  String get familyAgreeShort => 'I agree';

  @override
  String get familyChatReadingOn => 'Done — Zad will read your messages.';

  @override
  String get familyChatReadingOff => 'Stopped — Zad won\'t read your messages.';

  @override
  String get familyChatReadingNone => 'Zad isn\'t reading the chat';

  @override
  String familyChatReadingWho(String names) {
    return 'Zad reads messages from: $names';
  }

  @override
  String get familyChatReadingStopMine => 'Stop for mine';

  @override
  String get familyChatReadingAllowMine => 'Let it read mine';

  @override
  String get profileTitle => 'My account';

  @override
  String get profileSectionBrain => 'Zad\'s brain';

  @override
  String get profileMemoryTitle => 'What Zad knows about me';

  @override
  String get profileMemorySubtitle =>
      'Zad learns from your spending and pantry to help you — see what it learnt and delete anything';

  @override
  String get profileActionLogTitle => 'Zad\'s change log';

  @override
  String get profileActionLogSubtitle =>
      'Everything Zad saved or changed for you';

  @override
  String get profileAlertsTitle => 'Smart assistant alerts';

  @override
  String get profileAlertsSubtitle => 'Choose which smart alerts you get';

  @override
  String get profileNewGoalTitle => 'New life goal';

  @override
  String get profileNewGoalSubtitle =>
      'Let Zad keep you on track with a savings goal or a habit';

  @override
  String get profileSectionMeFamily => 'Me and my family';

  @override
  String get profileEditTitle => 'Edit profile';

  @override
  String get profileEditSubtitle => 'Your name or nickname';

  @override
  String get profileFamilyManageTitle => 'Manage family';

  @override
  String get profileFamilyManageSubtitle => 'Members and roles';

  @override
  String get profileRegionalTitle => 'Region';

  @override
  String get profileRegionalSubtitle => 'Country and currency';

  @override
  String get profileSectionMoney => 'My money';

  @override
  String get profileBudgetPaymentTitle => 'Budget and payment';

  @override
  String get profileBudgetPaymentSubtitle => 'Monthly budget and bank link';

  @override
  String get profileStatementTitle => 'Import a statement';

  @override
  String get profileStatementSubtitle =>
      'Import a CSV statement from your bank';

  @override
  String get profileSectionMyZad => 'My Zad';

  @override
  String get profileAchievementsTitle => 'Achievements and ranks';

  @override
  String get profileAchievementsSubtitle =>
      'Points and badges for sharing prices';

  @override
  String get profileSectionHelp => 'Help';

  @override
  String get profileSupportTitle => 'Support';

  @override
  String get profileSupportSubtitle =>
      'A complaint or a problem? Talk to the support team';

  @override
  String get profileTermsTitle => 'Terms and conditions';

  @override
  String get profileTermsSubtitle => 'Terms of use and privacy';

  @override
  String get profileSectionAccount => 'Account';

  @override
  String get profileDeleteAccountTitle => 'Delete account';

  @override
  String get profileDeleteAccountSubtitle => 'Delete your account for good';

  @override
  String get profileSignOut => 'Sign out';

  @override
  String get profileDeleteAccountBody =>
      'Are you sure you want to delete your account for good? This can\'t be undone.';

  @override
  String get profileDeleteAccountConfirm => 'Yes, delete my account';

  @override
  String get profileDeleteAccountFailed =>
      'Couldn\'t delete the account. Check your connection and try again.';

  @override
  String get profileSaved => 'Changes saved';

  @override
  String get profileSaveFailedRetry =>
      'Couldn\'t save the changes — check your connection and try again';

  @override
  String get profileEditName => 'Edit name';

  @override
  String get profileName => 'Name';

  @override
  String get profileGoalName => 'Goal';

  @override
  String get profileGoalMetricEgypt =>
      'How do we measure it? (e.g. 500 EGP a month)';

  @override
  String get profileGoalMetricOther =>
      'How do we measure it? (e.g. 500 SAR a month)';

  @override
  String get profileGoalDeadline => 'Deadline (optional)';

  @override
  String get profileGoalDeadlineHint => 'e.g. 2026-12-31';

  @override
  String get profileSaveShort => 'Save';

  @override
  String get profileEmail => 'Email';

  @override
  String get profileAliasLabel => 'Name / nickname';

  @override
  String get profileAliasHint => 'e.g. Dad';

  @override
  String get profileSaveChanges => 'Save changes';

  @override
  String get profileCountry => 'Country';

  @override
  String get profileCurrency => 'Currency';

  @override
  String get profileCurrencyAuto =>
      'The currency follows the country you pick above';

  @override
  String profileChangeCountryTitle(String country) {
    return 'Change the country to $country?';
  }

  @override
  String profileCurrencyWillBe(String symbol, String code) {
    return 'The currency will be $symbol ($code).';
  }

  @override
  String profileLimitConverts(
    String from,
    String fromSymbol,
    String to,
    String toSymbol,
  ) {
    return 'Your monthly cap changes from $from $fromSymbol to $to $toSymbol, and so do your category budgets.';
  }

  @override
  String get profileChange => 'Change';

  @override
  String get profileNoRate =>
      'I don\'t know the exchange rate, so your monthly cap keeps the same number — check it after the change.';

  @override
  String get profileKidsRelockTitle => 'Lock kids mode again';

  @override
  String get profileKidsRelockSubtitle => 'Puts the phone back in kids mode';

  @override
  String get profileKidsModeTitle => 'Switch to kids mode';

  @override
  String get profileKidsModeSubtitle =>
      'When you hand the phone to your child for a bit — leaving needs the PIN';

  @override
  String get profileNoFamily => 'You\'re not in a family yet.';

  @override
  String get profileFamilyInviteCode => 'Family invite code';

  @override
  String get profileFamilyMembers => 'Family members';

  @override
  String get profileRoleAdmin => 'Family admin';

  @override
  String get profileRoleChild => 'Child';

  @override
  String get profileRoleMember => 'Member';

  @override
  String get profileKickFailed =>
      'Couldn\'t remove the member. Please try again later.';

  @override
  String get profileRoleChangeFailed =>
      'Couldn\'t change the role. Please try again later.';

  @override
  String get profileMakeAdmin => 'Make admin';

  @override
  String get profileMakeMember => 'Make member';

  @override
  String get profileMakeChild => 'Set as child';

  @override
  String get profileKick => 'Remove member';

  @override
  String get profilePaymentBudgetTitle => 'Payment and budget';

  @override
  String get profileCurrentMonthlyBudget => 'Current monthly budget';

  @override
  String get profileDiagNoPermission =>
      '❌ Permission not granted — turn it on in notification access settings';

  @override
  String get profileDiagNotBound =>
      '❌ The service isn\'t connected — tap retry';

  @override
  String get profileDiagNoNotifications =>
      '❌ The service is connected but gets no notifications — try requestRebind';

  @override
  String get profileDiagWaitingTest =>
      '⏳ Waiting for the test notification to reach the listener...';

  @override
  String get profileDiagAllWorking => '✅ Bank reading works end to end';

  @override
  String get profileDiagListenerWorking =>
      '✅ The listener caught it and filtering works';

  @override
  String get profileDiagUnknown => '❓ Unknown state — try again';

  @override
  String profileParseOk(String amount, String kind) {
    return 'Parsed ✓\nAmount: $amount\nMerchant: —\nType: $kind';
  }

  @override
  String get profileParseCompleted => 'Completed transaction';

  @override
  String get profileParsePending => 'Pending';

  @override
  String get profileParseInfo => 'Information';

  @override
  String get profileParseServer => 'Checked on the server';

  @override
  String get profileParseFailed =>
      'Parsing failed — no parser matched the sample message';

  @override
  String get profileTest => 'Test';

  @override
  String get profileOk => 'OK';

  @override
  String get profileBankReading => 'Reading bank notifications';

  @override
  String get profileBankReadingHint =>
      'The real state of the permissions — if one was revoked in system settings, you\'ll see it here right away';

  @override
  String get profileEnable => 'Turn on';

  @override
  String get profileReaderConnection => 'Reading service connection';

  @override
  String get profileRetry => 'Retry';

  @override
  String profileLastConnected(String time) {
    return 'Last connected: $time';
  }

  @override
  String get profileNeverConnected =>
      'The service hasn\'t connected yet, even if the permission is on';

  @override
  String get profileNotificationsArriving => 'Notifications reaching the phone';

  @override
  String profileLastNotification(String time) {
    return 'Last notification seen: $time';
  }

  @override
  String get profileNoNotificationYet =>
      'No notification has reached the service yet';

  @override
  String profileLastParsed(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Last transaction read: $minutes minutes ago',
      one: 'Last transaction read: 1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String get profileNothingParsed => 'No transaction read yet';

  @override
  String get profileSendTestNotification => 'Test — send a sample transaction';

  @override
  String get profileRejectedTitle => 'Recently rejected messages';

  @override
  String get profileRejectedHint =>
      'If a bank or wallet isn\'t being recorded, the reason is here (an OTP, a pending message, or text that wasn\'t understood).';

  @override
  String profileStatusOn(String label) {
    return '$label: on ✓';
  }

  @override
  String profileStatusOff(String label) {
    return '$label: off';
  }

  @override
  String get profileVoiceAlertsTitle => '🔔 Spoken alerts and doses';

  @override
  String get profileVoiceAlertsDesc =>
      'Zad reads medicine and appointment reminders aloud while the app is open; when it\'s closed, the notification has a “Listen to Zad” button.';

  @override
  String get profileLowStockTitle => 'Low-stock alerts';

  @override
  String get profileLowStockDesc =>
      'A notification when a staple is about to run out';

  @override
  String get profileBudgetOverrunTitle => 'Budget alerts';

  @override
  String get profileBudgetOverrunDesc =>
      'An early heads-up when much of the budget is spent';

  @override
  String get profileTasbihTitle => 'Tasbih reminder';

  @override
  String get profileTasbihDesc =>
      'A gentle reminder at 5 pm if you haven\'t done your tasbih today';

  @override
  String get profileCompanionNapTitle =>
      'Zad\'s companion calls me if I\'m away';

  @override
  String get profileCompanionNapDesc =>
      'One notification after two days away, and one more two days later — never more than once a day, and never at night';

  @override
  String get profileCompanionCareTitle =>
      'Zad\'s companion reminds me to feed it';

  @override
  String get profileCompanionCareDesc =>
      'One notification when it\'s hungry or thirsty, pushed back each time you feed or water it — and never at night';

  @override
  String get profileLearnSleepTitle => 'Zad learns my sleep hours';

  @override
  String get profileLearnSleepDesc =>
      'From when the screen locks and unlocks at night, so alerts don\'t come while you sleep. Only your bedtime and wake-up hour are saved — not the moments themselves. Doses and emergencies still come as usual.';

  @override
  String get profileNotificationSound => 'Notification sound';

  @override
  String get profileNotificationSoundHint =>
      'Pick any notification sound on your phone instead of the default';

  @override
  String get profileDefaultSound => 'Default sound';

  @override
  String get supportFallback =>
      'I can\'t answer right now. Try again in a little while, and if it keeps happening, open the “Crash log” on this screen and send it to us — it has what we need to fix it.';

  @override
  String get supportFaqBank =>
      'To let Zad read your bank messages: on Home, tap “Turn on bank notification reading” and follow the steps. If the switch is grey or you see “Restricted setting”: open “App info” → ⋮ at the top → “Allow restricted settings”, then come back and turn the permission on. On Xiaomi and Oppo, set the battery to “No restrictions” so it doesn\'t stop.';

  @override
  String get supportFaqAllowance =>
      'In “Family” → “Kids\' spending” you\'ll find each child and their balance. “Send allowance” adds to it straight away. A child can ask for an “allowance” (added if you approve) or to “buy something” (deducted if you approve and the balance covers it).';

  @override
  String get supportFaqReceipt =>
      'Snap the receipt with the camera button. Zad reads the total, the items and the receipt\'s date, and logs it on that day. Check the amount and the category before saving — you can add the items to the pantry in the same step.';

  @override
  String get supportFaqCountry =>
      'Your country and currency are set when you sign up. To change them: “My account” → “Region”. Times and reminders follow the account\'s country.';

  @override
  String get supportFaqVoice =>
      'Tap the mic in the chat and talk — Zad answers out loud. If the answer is slow or there\'s no sound, check your internet and try again; the written reply stays in the chat.';

  @override
  String get supportFaqAppointments =>
      'Add appointments from “My appointments” → “New appointment”, or tell Zad in the chat “remind me of the doctor on Thursday at 5”. Medicines live in “Family pharmacy”, where you can say who in the family each one is for.';

  @override
  String get supportFaqFamily =>
      'In “Family”, start a new family and send the code to your people, or tap “Join” and enter the code you got. Only the admin can change roles and rewards.';

  @override
  String get supportFaqPassword =>
      'On the sign-in screen, tap “Forgot password” and enter your email — you\'ll get a link to change it.';

  @override
  String get supportFaqDeleteAccount =>
      'Delete your account from “My account” → “Delete account”. It erases all your data for good, with no way back.';

  @override
  String get supportWelcome =>
      'Hi! I\'m Zad\'s help assistant — I can explain any feature or sort out a technical problem. If your question is about your own data (spending, balance, subscriptions), ask the \"Zad\'s brain\" chat instead: it\'s the only one that sees your actual account.';

  @override
  String get supportContactTeam => 'Contact support';

  @override
  String get supportContactHint =>
      'Describe the problem or complaint — it goes straight to the support team, and they\'ll reply by email.';

  @override
  String get supportSubject => 'Subject';

  @override
  String get supportSubjectHint => 'e.g. The pharmacy page is empty';

  @override
  String get supportDetails => 'Details';

  @override
  String get supportAttachLog =>
      'Attach the crash log (helps us fix it faster)';

  @override
  String get supportSend => 'Send';

  @override
  String get supportSentByEmail =>
      'Your message reached the support team ✅ — they\'ll reply by email as soon as they can.';

  @override
  String get supportMailOpened =>
      'Your email app is open — tap send and it reaches the support team';

  @override
  String supportWriteTo(String email) {
    return 'Write to us at $email';
  }

  @override
  String get supportCrashLog => 'Crash log';

  @override
  String get supportShareLog => 'Share log';

  @override
  String get supportShare => '📤 Share';

  @override
  String get supportClear => '🗑️ Clear';

  @override
  String get supportClose => 'Close';

  @override
  String get supportTitle => 'App help';

  @override
  String get supportSubtitle => 'General questions — no access to your account';

  @override
  String get supportComplaintBanner =>
      'A complaint or a problem? Contact support';

  @override
  String get supportInputHint => 'Type your message...';

  @override
  String get supportTyping => 'Typing...';

  @override
  String get supportTermsTitle => 'Terms and conditions';

  @override
  String get supportTermsHeading => 'Terms of Use and User Agreement';

  @override
  String get supportTermsIntro =>
      'Last updated: July 2026\n\nPlease read these terms of use carefully before using Zad.';

  @override
  String get supportTerms1Title => '1. Accepting the terms';

  @override
  String get supportTerms1Body =>
      'By creating an account or using Zad, you agree to these terms. If you don\'t agree, please don\'t use the app.';

  @override
  String get supportTerms2Title =>
      '2. What the service is — a tool, not a responsible party';

  @override
  String get supportTerms2Body =>
      'Zad is an organising and personal-assistance tool only. We provide software that helps you track, organise and view your own financial and household data. We do not manage your money, make decisions on your behalf, hold your funds, process payments, or act as a financial institution, financial adviser or fiduciary of any kind.\n\nEvery feature in the app — including budgeting, expense tracking, receipt scanning, pantry tracking, subscription tracking, transaction detection from notifications, and any \"smart\" or \"AI-based\" insight — exists only to help you organise information you already have or produce. We do not verify, guarantee or take responsibility for the accuracy of that information, or for any action you take based on it.\n\nYou, and only you, are responsible for:\n- every financial decision you make;\n- checking the accuracy of any data the app shows, calculates, detects or suggests;\n- the results of relying on any automated feature, including AI-generated insights or forecasts and detection from notifications;\n- every outcome relating to your budget, spending, savings or household management, whether or not the app\'s information is accurate.\n\nWe accept no responsibility or liability of any kind for the results of your use of the app. Using Zad does not create any advisory relationship, fiduciary duty or guarantee of any outcome between you and us. The app is offered purely as an organising and convenience tool — how you use the information it shows is entirely your responsibility.';

  @override
  String get supportTerms3Title => '3. Privacy and data';

  @override
  String get supportTerms3Body =>
      'We respect your privacy. Your data is stored securely. We do not sell your personal financial data to any third party.';

  @override
  String get supportTerms4Title =>
      '4. Third-party AI features — assistance only, not authoritative';

  @override
  String get supportTerms4Body =>
      'Some features (receipt scanning, spending forecasts, subscription detection, behavioural insights, meal suggestions, voice input) use third-party AI services to process data and generate suggestions. These outputs are offered as a convenience only and must never be treated as accurate, complete, verified or authoritative. AI-generated content may be wrong, out of date or unsuitable for your situation.\n\nWe do not own or control the AI models used. We are not responsible for anything the AI generates, suggests, predicts or fails to detect. You must check any number, category or recommendation yourself before acting on it. Relying on any AI output as financial guidance is entirely at your own risk.';

  @override
  String get supportTerms5Title => '5. Family sharing';

  @override
  String get supportTerms5Body =>
      'If you invite family members, you are responsible for their access to your household\'s data.';

  @override
  String get supportTerms6Title => '6. Prohibited conduct';

  @override
  String get supportTerms6Body =>
      'You may not reverse-engineer or hack Zad, or use it for any unlawful activity.';

  @override
  String get supportTerms7Title =>
      '7. We provide the tool — you are responsible for the outcome';

  @override
  String get supportTerms7Body =>
      'We do not guarantee, and take no responsibility for, the accuracy of any balance, expense category, subscription status, stock level, low-stock alert or budget forecast shown in the app. Nor do we guarantee that automatic transaction detection will catch every transaction, or that it will always be right when it does.\n\nBy using Zad, you acknowledge that:\n- we are a passive information-organising tool, not an active party to your financial decisions;\n- any financial loss, missed payment, overspending, spoiled stock, family disagreement or other negative outcome arising from your use of or reliance on the app is your responsibility alone;\n- we will accept no liability, financial or otherwise, for those outcomes, to the fullest extent permitted by law.';

  @override
  String get profileLabelGenderFemale => 'Female';

  @override
  String get profileLabelGenderMale => 'Male';

  @override
  String get profileLabelZadvoiceBoy => 'A boy\'s voice';

  @override
  String get profileLabelZadvoiceGirl => 'A girl\'s voice';

  @override
  String get profileLabelRoleFather => 'Father';

  @override
  String get profileLabelRoleMother => 'Mother';

  @override
  String get profileLabelRoleHusband => 'Husband';

  @override
  String get profileLabelRoleWife => 'Wife';

  @override
  String get profileLabelRoleSon => 'Son';

  @override
  String get profileLabelRoleDaughter => 'Daughter';

  @override
  String get profileLabelRoleSingle => 'Living alone';

  @override
  String get profileLabelRoleStudent => 'Student';

  @override
  String get profileLabelRoleGrandparent => 'Grandparent';

  @override
  String get profileLabelRoleDefault => 'Something else';

  @override
  String get profileLabelAgeUnder18 => 'Under 18';

  @override
  String get profileLabelAge1824 => '18–24';

  @override
  String get profileLabelAge2534 => '25–34';

  @override
  String get profileLabelAge3544 => '35–44';

  @override
  String get profileLabelAge4554 => '45–54';

  @override
  String get profileLabelAgeDefault => '55 and over';

  @override
  String get profileLabelFrequencyWeekly => 'Weekly';

  @override
  String get profileLabelFrequencyBiweekly => 'Every two weeks';

  @override
  String get profileLabelFrequencyDaily => 'Daily';

  @override
  String get profileLabelFrequencyIrregular => 'Irregular';

  @override
  String get profileLabelFrequencyDefault => 'Monthly';

  @override
  String get profileLabelCaresforChildren => 'My children';

  @override
  String get profileLabelCaresforParents => 'My father or mother';

  @override
  String get profileLabelCaresforSpouse => 'My husband or wife';

  @override
  String get profileLabelCaresforSiblings => 'My siblings';

  @override
  String get profileLabelCaresforGrandparents => 'My grandparents';

  @override
  String get profileLabelDialectSa => 'Saudi';

  @override
  String get profileLabelDialectGulf => 'Gulf';

  @override
  String get profileLabelDialectLevant => 'Levantine';

  @override
  String get profileLabelDialectIq => 'Iraqi';

  @override
  String get profileLabelDialectMa => 'Moroccan';

  @override
  String get profileLabelDialectTn => 'Tunisian';

  @override
  String get profileLabelDialectDz => 'Algerian';

  @override
  String get profileLabelDialectLy => 'Libyan';

  @override
  String get profileLabelDialectSd => 'Sudanese';

  @override
  String get profileLabelDialectYe => 'Yemeni';

  @override
  String get profileLabelDialectDefault => 'Egyptian';

  @override
  String get memoryWriteNotSaved => 'I couldn\'t save that, try again';

  @override
  String quietBannerExams(String until) {
    return 'Exam season — Zad has quietened alerts until $until';
  }

  @override
  String quietBannerOther(String until) {
    return 'Zad has quietened alerts until $until — doses and appointments still come';
  }

  @override
  String get memoryScopeGeneral => 'About you';

  @override
  String get memoryScopeSpending => 'Your spending';

  @override
  String get memoryScopeCycle => 'Pay cycle';

  @override
  String get memoryScopeWeekly => 'Week summary';

  @override
  String get memoryScopeDataQuality => 'Data accuracy';

  @override
  String get memoryScopeDismissal => 'An alert you turned down';

  @override
  String get memoryScopeOther => 'Note';

  @override
  String get monthJan => 'January';

  @override
  String get monthFeb => 'February';

  @override
  String get monthMar => 'March';

  @override
  String get monthApr => 'April';

  @override
  String get monthMay => 'May';

  @override
  String get monthJun => 'June';

  @override
  String get monthJul => 'July';

  @override
  String get monthAug => 'August';

  @override
  String get monthSep => 'September';

  @override
  String get monthOct => 'October';

  @override
  String get monthNov => 'November';

  @override
  String get monthDec => 'December';

  @override
  String get briefTookIt => 'Took it';

  @override
  String get briefAddThem => 'Add them';

  @override
  String get occasionNewYearTitle => 'Happy New Year! 🎉';

  @override
  String occasionNewYearQuestion(String dialect, int year) {
    return 'Want Zad to set up your money goals plan for $year in one tap?';
  }

  @override
  String get occasionNewYearActionLabel => 'Set it up';

  @override
  String occasionNewYearPrompt(int year) {
    return 'Make me a money goals plan for $year from my real numbers and spending, and suggest the goals for me to confirm.';
  }

  @override
  String get occasionRamadanTitle => 'Ramadan Kareem 🌙';

  @override
  String occasionRamadanQuestion(String dialect) {
    return 'Shall I make your Ramadan shopping list from what\'s missing at home?';
  }

  @override
  String get occasionRamadanActionLabel => 'Make the list';

  @override
  String get occasionRamadanPrompt =>
      'Make me a Ramadan shopping list from what\'s actually missing at home, and add it to the shopping list within the budget.';

  @override
  String get occasionEidFitrTitle => 'Happy Eid al-Fitr! 🎈';

  @override
  String occasionEidFitrQuestion(String dialect) {
    return 'Shall I set an Eid budget (eidiya, clothes, gatherings) from what you have available?';
  }

  @override
  String get occasionEidFitrActionLabel => 'Do it';

  @override
  String get occasionEidFitrPrompt =>
      'Make me an Eid al-Fitr budget: eidiya, clothes and gatherings, from what I have available without going over the budget.';

  @override
  String get occasionEidAdhaTitle => 'Eid al-Adha Mubarak! 🐑';

  @override
  String occasionEidAdhaQuestion(String dialect) {
    return 'Shall I set an Eid budget from what you have available?';
  }

  @override
  String get occasionEidAdhaActionLabel => 'Do it';

  @override
  String get occasionEidAdhaPrompt =>
      'Make me an Eid al-Adha budget from what I have available — eidiya and gatherings, and the sacrifice if we do one.';

  @override
  String get occasionHijriTitle => 'Happy Hijri New Year 🌙';

  @override
  String occasionHijriQuestion(String dialect) {
    return 'Shall we review your goals and see how they\'re going?';
  }

  @override
  String get occasionHijriActionLabel => 'Review them';

  @override
  String get occasionHijriPrompt =>
      'Review my goals, tell me how each one is going, and suggest a small step for the ones behind.';

  @override
  String get occasionMothersDayTitle => 'Happy Mother\'s Day 💐';

  @override
  String occasionMothersDayQuestion(String dialect) {
    return 'Want me to suggest a Mother\'s Day gift within the budget?';
  }

  @override
  String get occasionMothersDayActionLabel => 'Suggest';

  @override
  String get occasionMothersDayPrompt =>
      'Suggest a Mother\'s Day gift for me within the budget.';

  @override
  String get occasionAnnivTodayTitle => 'Happy anniversary 💍';

  @override
  String occasionAnnivTodayQuestion(String dialect) {
    return 'Shall I suggest an outing tonight within the budget?';
  }

  @override
  String get occasionAnnivTodayActionLabel => 'Suggest';

  @override
  String get occasionAnnivTodayPrompt =>
      'Today is our wedding anniversary — suggest an outing tonight within my budget.';

  @override
  String get occasionAnnivSoonTitle => 'Your anniversary is in 3 days 💍';

  @override
  String occasionAnnivSoonQuestion(String dialect) {
    return 'Shall I suggest a gift or an outing within the budget?';
  }

  @override
  String get occasionAnnivSoonActionLabel => 'Suggest';

  @override
  String occasionAnnivSoonPrompt(String date) {
    return 'Our wedding anniversary is on $date. Suggest a gift or an outing within my budget.';
  }

  @override
  String occasionPersonTodayTitle(String what) {
    return 'Today is $what 🎂';
  }

  @override
  String occasionPersonTodayQuestion(String dialect) {
    return 'Shall I write a congratulations message for you to send?';
  }

  @override
  String get occasionPersonTodayActionLabel => 'Write it';

  @override
  String occasionPersonTodayPrompt(String what) {
    return 'Today is $what — write me a short, warm congratulations message to send.';
  }

  @override
  String occasionPersonSoonTitle(String what) {
    return '$what is in 3 days 🎁';
  }

  @override
  String occasionPersonSoonQuestion(String dialect) {
    return 'Shall I suggest a gift within the budget and set aside its amount?';
  }

  @override
  String get occasionPersonSoonActionLabel => 'Suggest a gift';

  @override
  String occasionPersonSoonPrompt(String what, String date) {
    return '$what is on $date. Suggest two gift ideas within my budget, and if I agree, set the amount aside as a goal until the day.';
  }

  @override
  String occasionBirthdayOf(String name) {
    return '$name\'s birthday';
  }

  @override
  String occasionAnniversaryOf(String name) {
    return '$name\'s wedding anniversary';
  }

  @override
  String get briefToday => 'today';

  @override
  String get briefTomorrow => 'tomorrow';

  @override
  String get briefDayAfter => 'the day after tomorrow';

  @override
  String briefInDays(int days) {
    return 'in $days days';
  }

  @override
  String briefDoseDue(String name) {
    return 'Time for $name';
  }

  @override
  String briefDoseDueDetail(String time) {
    return 'Due at $time — tap “Took it” when you take it';
  }

  @override
  String briefDosesMissed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count doses were missed',
      one: 'A dose was missed',
    );
    return '$_temp0';
  }

  @override
  String get briefDosesMissedDetail =>
      'Open the pharmacy and log what was taken';

  @override
  String briefOverspent(String amount) {
    return 'You spent $amount more than available';
  }

  @override
  String get briefOverspentDetail =>
      'See My money — Zad can suggest where to cut';

  @override
  String briefInstalment(String name, String when) {
    return '$name instalment $when';
  }

  @override
  String briefAndMore(int count) {
    return ' and $count more';
  }

  @override
  String briefShort(String items) {
    return 'You\'re out of $items';
  }

  @override
  String get briefShortDetail =>
      'Open My home and add them to the shopping list';

  @override
  String briefAboutWhen(String item, String when) {
    return '$item around $when';
  }

  @override
  String briefRunningOut(String items) {
    return 'Running out soon: $items';
  }

  @override
  String get briefRunningOutEstimate =>
      'An estimate from your use so far — add them to the shopping list?';

  @override
  String get briefRunningOutRate =>
      'From your usage rate — add them to the shopping list?';

  @override
  String briefFamilyChat(String items) {
    return 'From the family chat: $items';
  }

  @override
  String get briefFamilySaid =>
      'Someone said they\'re out — add them to the shopping list?';

  @override
  String briefFamilyWhoSaid(String names, int count) {
    return '$names said they\'re out — add them to the shopping list?';
  }

  @override
  String get briefAnd => ' and ';

  @override
  String get familyRoleLabelAdmin => 'Admin';

  @override
  String get familyRoleLabelMember => 'Member';

  @override
  String get familyRoleLabelChild => 'Child';

  @override
  String get familyFailureInvalidCode =>
      'That code isn\'t right. Get it again from the family\'s owner.';

  @override
  String get familyFailureTooManyAttempts =>
      'You\'ve tried too many codes. Wait an hour and try again.';

  @override
  String get familyFailureAlreadyInFamily =>
      'You\'re already in a family. Leave it first.';

  @override
  String get familyFailureLastAdmin =>
      'You\'re the last admin. Make someone else an admin first.';

  @override
  String get familyFailureNotAllowed => 'Only an admin can do this.';

  @override
  String get familyFailureOffline => 'This needs an internet connection.';

  @override
  String get familyFailureUnknown => 'Something went wrong. Try again.';

  @override
  String get familyScopeMedicines => 'Medicines';

  @override
  String get familyScopeSpending => 'Spending';

  @override
  String get familyScopeTasks => 'Tasks and appointments';

  @override
  String get familyScopeLocation => 'Places (school…)';

  @override
  String familyShareAskLocation(String name) {
    return '$name wants to know when you arrive at or leave places they set (like school)';
  }

  @override
  String familyShareAsk(String name, String what) {
    return '$name wants to follow your $what';
  }

  @override
  String get familyNoticeLoadFailed =>
      'Couldn\'t load the family\'s data. Pull down to try again.';

  @override
  String get familyNoticeNotSent =>
      'The message wasn\'t sent — check your connection.';

  @override
  String get familyNoticeCoolingAdmin =>
      'Only an admin can change the thinking pause.';

  @override
  String get familyNoticeCoolingFailed =>
      'Couldn\'t change the thinking pause. Try again.';

  @override
  String get familyNoticeServer => 'Couldn\'t reach the server. Try again.';

  @override
  String get familyNoticeAllowanceAdmin =>
      'Only an admin can send pocket money.';

  @override
  String get familyNoticeAmountPositive => 'Enter an amount above zero.';

  @override
  String get familyNoticeAllowanceFailed =>
      'Couldn\'t send the pocket money. Try again.';

  @override
  String get familyNoticeDecisionAdmin => 'Only an admin can decide this.';

  @override
  String get familyNoticeDecisionFailed =>
      'Couldn\'t save the decision. Try again.';

  @override
  String get familyNoticePollClosed => 'The poll is already closed.';

  @override
  String get familyNoticeVoteFailed => 'Your vote wasn\'t saved. Try again.';

  @override
  String get familyNoticePollCloseWho =>
      'Only whoever opened the poll or an admin can close it.';

  @override
  String get familyNoticePollCloseFailed =>
      'Couldn\'t close the poll. Try again.';

  @override
  String get familyNoticeEditNotSaved => 'The change wasn\'t saved.';

  @override
  String get familyNoticeRewardAdmin => 'Only an admin sets the reward.';

  @override
  String get familyNoticeChoreFailed => 'The task wasn\'t added. Try again.';

  @override
  String get familyNoticeReopenAdmin =>
      'Only an admin can undo a finished task.';

  @override
  String get familyNoticeNotYours => 'That\'s someone else\'s task.';

  @override
  String get familyNoticeChoreUpdateFailed => 'Couldn\'t update the task.';

  @override
  String get familyNoticeItemFailed => 'The item wasn\'t added. Try again.';

  @override
  String get familyNoticeLimitsAdmin => 'Only an admin sets spending limits.';

  @override
  String get familyNoticeLimitsFailed =>
      'The limits weren\'t saved. Try again.';

  @override
  String get familyNoticeGoalSuggestFailed =>
      'Zad couldn\'t suggest a goal right now. Try again.';

  @override
  String get familyNoticeGoalFailed => 'The goal wasn\'t saved. Try again.';

  @override
  String get familyNoticeBalanceShort =>
      'Their balance doesn\'t cover this request — send pocket money first with “Send pocket money”, then approve.';

  @override
  String familyNoticeChoreDone(String amount) {
    return 'Great work! 🌟 $amount added to the balance.';
  }

  @override
  String get familyCoolingWaiting =>
      'The thinking pause is on: the request isn\'t 24 hours old yet — or turn it down now if you\'re not convinced.';

  @override
  String get familyCoolingWithinHour =>
      'Thinking pause: you can approve within an hour — or turn it down now if you\'re not convinced.';

  @override
  String familyCoolingAfterHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours hours',
      one: '1 hour',
    );
    return 'Thinking pause: you can approve in $_temp0 — or turn it down now if you\'re not convinced.';
  }

  @override
  String attemptsCount(num count, String digits) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$digits attempts',
      one: '1 attempt',
      zero: 'no attempts',
    );
    return '$_temp0';
  }

  @override
  String attemptsPlanName(String tier) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'starter': 'Basic',
      'plus': 'Plus',
      'pro': 'Family',
      'other': 'Free',
    });
    return '$_temp0';
  }

  @override
  String attemptsRefillPlan(String plan) {
    return 'Your $plan plan';
  }

  @override
  String attemptsRefillPlanOn(String plan, String day, String month) {
    return 'Your $plan plan — renews on $month $day';
  }

  @override
  String get attemptsRefillFull => 'Your balance is full';

  @override
  String get attemptsRefillNow => 'Your balance is coming back now';

  @override
  String attemptsRefillAt(String count, String clock) {
    return '$count come back at $clock';
  }

  @override
  String attemptsRefillTomorrowAt(String count, String clock) {
    return '$count come back tomorrow at $clock';
  }

  @override
  String get attemptsClockAm => 'AM';

  @override
  String get attemptsClockPm => 'PM';

  @override
  String attemptsChipSemantics(String attempts) {
    return 'Your balance: $attempts';
  }

  @override
  String get attemptsSheetTitle => 'Zad\'s energy';

  @override
  String attemptsSheetBalance(String attempts) {
    return 'You have $attempts';
  }

  @override
  String get attemptsCostLog => 'Logging an expense or income';

  @override
  String get attemptsCostFree => 'Free';

  @override
  String get attemptsCostChat => 'A chat message';

  @override
  String get attemptsCostScan => 'Scanning a receipt or photo';

  @override
  String get attemptsCostBrain => 'A deep analysis or plan';

  @override
  String get attemptsSubscribeNoAds => 'Subscribe, no ads';

  @override
  String get attemptsSeePlans => 'See the plans';

  @override
  String get refusalNoAttemptsTitle => 'Not enough attempts';

  @override
  String get refusalSlowDownTitle => 'Wait a little';

  @override
  String adWeekTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You watched $count ads this week',
      one: 'You watched 1 ad this week',
    );
    return '$_temp0';
  }

  @override
  String adWeekBody(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '1 minute',
    );
    return 'That\'s about $_temp0 of your time. A plan has no ads at all, and more attempts.';
  }

  @override
  String get adsCappedToday => 'No more ads today';

  @override
  String get adNextInAMinute => 'Next ad in a minute';

  @override
  String adWatchFor(String attempts) {
    return 'Watch an ad, get $attempts';
  }

  @override
  String adOpensBox(String bonus) {
    return 'This ad opens the box: +$bonus extra';
  }

  @override
  String adBoxProgress(String done) {
    return 'Every third ad opens a box — $done of 3';
  }

  @override
  String get adRewardOnTheWay => 'Your reward is on its way to your balance…';

  @override
  String get adClosedEarly => 'The ad closed before the reward.';

  @override
  String get adNoneNow => 'No ad right now. Try again in a little while.';

  @override
  String companionPersonaTrait(String id) {
    String _temp0 = intl.Intl.selectLogic(id, {
      'basbous': 'Kind, loves sweets and saving',
      'fella': 'Gentle, calms the house',
      'felfool': 'Lively, loves a challenge',
      'mishmish': 'Fluffy and warm, loves staying in',
      'toota': 'Cheeky and artistic, draws the plans',
      'fanoos': 'Comes out in Ramadan',
      'maamoul': 'Comes out at Eid',
      'other': 'Calm, loves a tidy home',
    });
    return '$_temp0';
  }

  @override
  String companionPersonaLine(String id) {
    String _temp0 = intl.Intl.selectLogic(id, {
      'basbous': 'Saved today? Then we\'ve earned a piece of basbousa.',
      'fella':
          'The house smells of jasmine when everything\'s logged in its place.',
      'felfool': 'Come on, champ! This week\'s challenge: save 100 and win.',
      'mishmish': 'Full fridge and a warm house? Then I\'m happy.',
      'toota': 'Come, let\'s draw this month\'s plan together.',
      'fanoos': 'Ramadan Kareem! I\'ve got your suhoor list ready.',
      'maamoul': 'Eid Mubarak! Did the Eid money get logged?',
      'other': 'Hi! I\'m Zado, here for anything about the house.',
    });
    return '$_temp0';
  }

  @override
  String companionStageLabel(String stage) {
    String _temp0 = intl.Intl.selectLogic(stage, {
      'seed': 'Seed',
      'sprout': 'Sprout',
      'little': 'Little one',
      'sage': 'Sage',
      'other': 'Companion',
    });
    return '$_temp0';
  }

  @override
  String companionStageDescription(String stage) {
    String _temp0 = intl.Intl.selectLogic(stage, {
      'seed': 'Still in its shell, with big eyes.',
      'sprout': 'Out of its shell, with two little hands.',
      'little': 'It has feet now, and can wear everything.',
      'sage': 'A gold halo, with stars circling it.',
      'other': 'A soft light around it, and it dances when you\'re happy.',
    });
    return '$_temp0';
  }

  @override
  String companionOutfitLabel(String outfit) {
    String _temp0 = intl.Intl.selectLogic(outfit, {
      'sunglasses': 'Sunglasses',
      'winterHat': 'Winter hat',
      'chefHat': 'Chef\'s hat',
      'shemagh': 'Shemagh',
      'gradCap': 'Graduation cap',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String companionBackgroundLabel(String bg) {
    String _temp0 = intl.Intl.selectLogic(bg, {
      'night': 'Night',
      'garden': 'The garden',
      'kitchen': 'The kitchen',
      'stars': 'Starry sky',
      'shilla': 'The gang',
      'other': 'Morning',
    });
    return '$_temp0';
  }

  @override
  String offerOpensAtLevel(int level) {
    return 'Opens at level $level';
  }

  @override
  String offerOpensFriends(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Opens when $count friends sign up',
      one: 'Opens when a friend signs up',
    );
    return '$_temp0';
  }

  @override
  String get offerPlusGift => 'A gift with the Plus plan';

  @override
  String get offerRamadanOnly => 'Ramadan only';

  @override
  String get offerEidOnly => 'Eid only';

  @override
  String petPokedMany(int count) {
    return 'Enough! $count times? I\'m telling Zad on you 😂';
  }

  @override
  String petPokedLots(String i, int count) {
    String _temp0 = intl.Intl.selectLogic(i, {
      'i0': 'Are you counting or what? That\'s $count times 😵‍💫',
      'other': 'The screen\'s getting tired of us 😅 $count taps!',
    });
    return '$_temp0';
  }

  @override
  String petPokedSome(String i, String name) {
    String _temp0 = intl.Intl.selectLogic(i, {
      'i0': 'That tickles! 🤭 Stop…',
      'i1': 'I\'m not a button, you know 😤',
      'other': '$name is seeing stars from all the tapping 😵',
    });
    return '$_temp0';
  }

  @override
  String petBackDay(String i) {
    String _temp0 = intl.Intl.selectLogic(i, {
      'i0': 'A whole day away! I thought you forgot me 🥺',
      'other': 'A full day? I sat here counting floor tiles 🥲',
    });
    return '$_temp0';
  }

  @override
  String petBackHours(String i, int hours) {
    String _temp0 = intl.Intl.selectLogic(i, {
      'i0': 'Gone $hours hours… not that I missed you or anything 😌',
      'other': 'You\'re back! $hours hours of me staring at the door 👀',
    });
    return '$_temp0';
  }

  @override
  String petClockNight(String i, int hour) {
    String _temp0 = intl.Intl.selectLogic(i, {
      'i0': 'It\'s $hour at night! What are you doing up? 👀',
      'other': 'Both of us awake at $hour… our secret 🤫',
    });
    return '$_temp0';
  }

  @override
  String petClockDawn(String i) {
    String _temp0 = intl.Intl.selectLogic(i, {
      'i0': 'Up early… or still not asleep? 🌅',
      'other': 'Dawn\'s barely here and so are you? Bravo 🌄',
    });
    return '$_temp0';
  }

  @override
  String petPaywall(String i, String name) {
    String _temp0 = intl.Intl.selectLogic(i, {
      'i0': 'I see you looking at the prices 👀 Take your time',
      'i1': 'No pressure… but $name would be so happy 🥹',
      'other': 'Don\'t worry, I\'m with you either way 💚',
    });
    return '$_temp0';
  }

  @override
  String petDreamTalked(String what) {
    return 'Last night I dreamt “$what” told me all about yesterday… and I got that you needed it 🌙';
  }

  @override
  String petDreamMarket(String what) {
    return 'I dreamt I walked through a big market and every shop was called “$what” 😄 Yesterday was its day';
  }

  @override
  String petDreamChased(String what) {
    return 'Last night I dreamt “$what” was chasing me 😱🌙';
  }

  @override
  String petDreamPlayed(String what) {
    return 'I dreamt I was playing with “$what” 🤭 It was the biggest thing yesterday';
  }

  @override
  String petWeekGoalGrown(int days) {
    return '$days days out of 7 this week… this house knows its way 💚';
  }

  @override
  String petWeekGoalYoung(int days) {
    return '$days days this week! I grew from sheer joy 🎉';
  }

  @override
  String petWeekSomeGrown(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'We logged $days days this week. Step by step we get there 🌱',
      one: 'We logged 1 day this week. Step by step we get there 🌱',
    );
    return '$_temp0';
  }

  @override
  String petWeekSomeYoung(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days logged together! Keep going? 🥰',
      one: '1 day logged together! Keep going? 🥰',
    );
    return '$_temp0';
  }

  @override
  String get petWeekNoneGrown =>
      'A new week, a blank page. I\'m here whenever you like 💚';

  @override
  String get petWeekNoneYoung =>
      'A new week! Want to play “log an expense”? 🌱';

  @override
  String petMoodHungry(String i) {
    String _temp0 = intl.Intl.selectLogic(i, {
      'i0': 'My tummy\'s rumbling… feed me? 🍎',
      'i1': 'So hungry 🥺 just a little something',
      'other': 'Smell food? Nope, that\'s just me being hungry 😅',
    });
    return '$_temp0';
  }

  @override
  String petMoodThirsty(String i) {
    String _temp0 = intl.Intl.selectLogic(i, {
      'i0': 'Thirsty… a little water? 💧',
      'i1': 'My mouth\'s so dry 🥵 water me',
      'other': 'One glass of water and I\'ll be perfect 💧',
    });
    return '$_temp0';
  }

  @override
  String petMoodSleepy(String i) {
    String _temp0 = intl.Intl.selectLogic(i, {
      'i0': 'Sleepy… 😴 good night',
      'i1': 'Yaaawn 🥱 continue tomorrow?',
      'other': 'My eyes are closing on their own… 💤',
    });
    return '$_temp0';
  }

  @override
  String petMoodSad(String i, String name) {
    String _temp0 = intl.Intl.selectLogic(i, {
      'i0': 'I missed you… and you forgot my food and water 🥺',
      'other': '$name is a bit sad… come sit with me 💔',
    });
    return '$_temp0';
  }

  @override
  String petMoodHappy(String i) {
    String _temp0 = intl.Intl.selectLogic(i, {
      'i0': 'I\'m happy with you 💚',
      'i1': 'Thanks for remembering me 🥰',
      'other': 'You\'re the best friend 🤗',
    });
    return '$_temp0';
  }

  @override
  String petMoodLogged(String i) {
    String _temp0 = intl.Intl.selectLogic(i, {
      'i0': 'How\'s your day going? ✨',
      'i1': 'I\'m here if you need me 💚',
      'other': 'You logged today — well done 👏',
    });
    return '$_temp0';
  }

  @override
  String petMoodNudge(String i) {
    String _temp0 = intl.Intl.selectLogic(i, {
      'i0': 'Logged your expenses today? 📝',
      'other': 'Just one expense and I\'ll be so proud 🌱',
    });
    return '$_temp0';
  }

  @override
  String petFed(String i) {
    String _temp0 = intl.Intl.selectLogic(i, {
      'i0': 'Yum yum! 😋',
      'i1': 'Thank you 🍎',
      'other': 'Best meal ever 🤤',
    });
    return '$_temp0';
  }

  @override
  String petFull(String i) {
    String _temp0 = intl.Intl.selectLogic(i, {
      'i0': 'I\'m full 🤭',
      'other': 'Can\'t eat another bite 😅',
    });
    return '$_temp0';
  }

  @override
  String petWatered(String i) {
    String _temp0 = intl.Intl.selectLogic(i, {
      'i0': 'Aah, refreshing! 💧',
      'other': 'Much better now 😌',
    });
    return '$_temp0';
  }

  @override
  String petWaterFull(String i) {
    String _temp0 = intl.Intl.selectLogic(i, {
      'i0': 'I don\'t want water right now 🙈',
      'other': 'I\'ve had enough to drink 😄',
    });
    return '$_temp0';
  }

  @override
  String petPetted(String i) {
    String _temp0 = intl.Intl.selectLogic(i, {
      'i0': 'Hehe, that tickles 🤭',
      'i1': 'More! More! 🥰',
      'other': 'Love you 💚',
    });
    return '$_temp0';
  }

  @override
  String priceSourceLabel(String source) {
    String _temp0 = intl.Intl.selectLogic(source, {
      'yours': 'You paid',
      'other': 'Average in your city',
    });
    return '$_temp0';
  }

  @override
  String get petMomentMissedYou => 'I missed you! 💚';

  @override
  String petMomentWasSleeping(String name) {
    return '$name was asleep, waiting for you…';
  }

  @override
  String petMomentGift(int seeds) {
    return 'I brought you $seeds 🌱 as a welcome-back gift. Let\'s keep going together!';
  }

  @override
  String get petMomentKeepGoing => 'Let\'s keep going together!';

  @override
  String petMomentAwayDays(int days) {
    return 'You\'ve been away $days days, so it fell asleep under the blanket. Tap it to wake it up.';
  }

  @override
  String get petMomentTapToWake => 'Tap it to wake it up.';

  @override
  String get petMomentLetsGo => 'Let\'s go';

  @override
  String get petMomentWake => 'Wake it 👋';

  @override
  String petMomentGrew(String name, String stage) {
    return '$name grew! Now a $stage ✨';
  }

  @override
  String petMomentChanging(String name) {
    return '$name is changing…';
  }

  @override
  String petMomentLevel(int level) {
    return 'Level $level! 🎉';
  }

  @override
  String get petMomentSomething => 'Wait… something\'s happening!';

  @override
  String petMomentLevelBody(String name) {
    return 'Everything you logged helped $name grow.';
  }

  @override
  String get petMomentWow => 'Wow!';

  @override
  String get petLoggedFull => 'Logged ✓ but I\'m full 🤭';

  @override
  String get petLoggedYum => 'Logged ✓ yum yum! 😋';

  @override
  String petOrbSemantics(String name, String mood) {
    return '$name — $mood. Tap to feed and water it';
  }

  @override
  String petCareStreak(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '🔥 $days days of care',
      one: '🔥 1 day of care',
    );
    return '$_temp0';
  }

  @override
  String petPamper(String name) {
    return 'Pamper $name';
  }

  @override
  String get petMeterFull => 'Fullness';

  @override
  String get petMeterWater => 'Water';

  @override
  String get petMeterHappy => 'Happiness';

  @override
  String petTapToPamper(String name) {
    return 'Tap $name to pamper it';
  }

  @override
  String get petFeedButton => '🍎 Feed';

  @override
  String get petWaterButton => '💧 Water';

  @override
  String petPlayedScore(int score) {
    return 'We played and you scored $score! 🏆';
  }

  @override
  String get petPlayButton => '⚽ Play with it';

  @override
  String petGuessedRight(int right) {
    return 'You guessed $right right! 💰';
  }

  @override
  String get petGuessTitle => '💰 Guess the price';

  @override
  String petMemoryDone(int moves) {
    return 'We finished the memory game in $moves moves! 🧠';
  }

  @override
  String get petMemoryTitle => '🧠 Price memory';

  @override
  String get petStudioButton => '👗 Companion studio';

  @override
  String petBallVerdict(String tier, String name) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'none': '$name is waiting for you to play again 🥺',
      'some': 'Nice! $name had fun 😊',
      'lots': 'Bravo! $name is over the moon 🤩',
      'other': 'Legend! $name can\'t believe it 🏆',
    });
    return '$_temp0';
  }

  @override
  String petBallTitle(String name) {
    return 'Play with $name';
  }

  @override
  String petBallScore(int score) {
    return 'Score: $score';
  }

  @override
  String get petBallHint => 'Catch the ball before it gets away!';

  @override
  String get petGameAgain => '🔁 Again';

  @override
  String get petGameDone => 'Done';

  @override
  String get petGamesNoPrices => 'Not enough prices yet';

  @override
  String petGamesNoPricesBody(String name) {
    return 'Log a few expenses or report a price in “Crowd prices”, and $name will play with them.';
  }

  @override
  String petGuessVerdict(String tier, String name) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'all': 'All right! $name can\'t believe it 🏆',
      'half': 'Bravo! You\'ve got an eye for prices 🤩',
      'some': 'Not bad! $name had fun 😊',
      'other': 'The prices beat us this time 😅 Again?',
    });
    return '$_temp0';
  }

  @override
  String petGuessScore(int right, int total) {
    return '$right of $total';
  }

  @override
  String petGuessProgress(int at, int total, int right) {
    return 'Question $at of $total · $right right';
  }

  @override
  String petGuessQuestion(String item) {
    return 'How much is “$item”?';
  }

  @override
  String get petGuessResult => 'Result';

  @override
  String get petGuessNext => 'Next';

  @override
  String petMemoryVerdict(String tier, String name, int moves) {
    String _temp0 = intl.Intl.selectLogic(tier, {
      'iron': 'Memory of steel! $name is amazed 🏆',
      'good': 'Bravo! Done in $moves moves 🤩',
      'other': 'We did it in $moves moves, $name had fun 😊',
    });
    return '$_temp0';
  }

  @override
  String petMemoryHint(int moves) {
    return 'Match each item with its price · $moves moves';
  }

  @override
  String petMeterPercent(int percent) {
    return '$percent%';
  }

  @override
  String documentKindLabel(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'passport': 'Passport',
      'nationalId': 'National ID',
      'residence': 'Residence permit',
      'drivingLicense': 'Driving licence',
      'vehicleLicense': 'Vehicle licence',
      'other': 'Other document',
    });
    return '$_temp0';
  }

  @override
  String reminderPetThirstyTitle(String name) {
    return '💧 $name is thirsty';
  }

  @override
  String reminderPetHungryTitle(String name) {
    return '🍎 $name is hungry';
  }

  @override
  String get reminderPetThirstyBody =>
      'One glass of water and it\'s back to playing — come water it';

  @override
  String get reminderPetHungryBody =>
      'Waiting for you to feed it… it misses you 🥺';

  @override
  String reminderPetCallTitle(String i, String name) {
    String _temp0 = intl.Intl.selectLogic(i, {
      'i0': '🥺 $name is still waiting for you',
      'i1': '🍎 $name is asking about you',
      'i2': '😢 $name is sad',
      'i3': '💔 $name misses you so much',
      'i4': '😭 $name is weak with hunger',
      'other': '🌧️ $name is sitting all alone',
    });
    return '$_temp0';
  }

  @override
  String reminderPetCallBody(String i) {
    String _temp0 = intl.Intl.selectLogic(i, {
      'i0': 'Its tummy\'s been rumbling since morning… just one bite?',
      'i1': 'Sitting by an empty bowl — come feed and water it',
      'i2': 'A day without food… it looks a mess and it\'s waiting for you',
      'i3': 'It won\'t play without you — one minute makes it happy again',
      'i4': 'Two days without food or water… it\'s still waiting for you',
      'other': 'Every day it watches the door — come and reassure it',
    });
    return '$_temp0';
  }

  @override
  String reminderNapTitle(String name) {
    return '😴 $name fell asleep waiting for you';
  }

  @override
  String get reminderNapBody =>
      'You\'ve been away two days — come wake it up, it has welcome-back seeds for you 🌱';

  @override
  String reminderNapAgainTitle(String name) {
    return '$name is still asleep…';
  }

  @override
  String get reminderNapAgainBody =>
      'Log just one expense and it\'ll wake up happy, and the streak starts again 🔥';

  @override
  String get reminderChannelDoses => 'Zad — medicine times';

  @override
  String get reminderChannelTasbih => 'Zad — tasbih reminder';

  @override
  String get reminderChannelCompanion => 'Zad\'s companion';

  @override
  String get reminderChannelSeasons => 'Zad — upcoming occasions';

  @override
  String get reminderChannelDocuments => 'Zad — documents before they expire';

  @override
  String get reminderDoseTaken => 'Taken ✅';

  @override
  String get reminderDoseSnooze => 'Snooze';

  @override
  String get reminderDoseTitle => 'Medicine time';

  @override
  String reminderDoseBody(String name) {
    return 'Time for your dose of $name';
  }

  @override
  String get reminderTasbihTitle => '🌱 Tasbih time';

  @override
  String get reminderTasbihBody =>
      'Your tree is waiting — say some tasbih and help it grow';

  @override
  String reminderSeasonName(String slug) {
    String _temp0 = intl.Intl.selectLogic(slug, {
      'ramadan': 'Ramadan',
      'eid_al_fitr': 'Eid al-Fitr',
      'eid_al_adha': 'Eid al-Adha',
      'back_to_school': 'Back to school',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String reminderSeasonTitle(String name) {
    return '📅 $name is coming';
  }

  @override
  String reminderSeasonBody(String name) {
    return 'Get ready for $name expenses — start saving now';
  }

  @override
  String reminderDocumentWho(String document, String holder) {
    return '$holder\'s $document';
  }

  @override
  String reminderDocumentToday(String document) {
    return '🪪 $document expires today';
  }

  @override
  String reminderDocumentInDays(String document, int days) {
    return '🪪 $document expires in $days days';
  }

  @override
  String get reminderDocumentPassport =>
      'Many countries want a passport valid for 6 months to travel — if a trip is coming, renew it early.';

  @override
  String reminderDocumentLastDay(String date) {
    return 'Last day $date — start the renewal early.';
  }

  @override
  String marketCountryName(String country) {
    String _temp0 = intl.Intl.selectLogic(country, {
      'SA': 'Saudi Arabia',
      'EG': 'Egypt',
      'AE': 'UAE',
      'KW': 'Kuwait',
      'QA': 'Qatar',
      'BH': 'Bahrain',
      'OM': 'Oman',
      'JO': 'Jordan',
      'LB': 'Lebanon',
      'IQ': 'Iraq',
      'SY': 'Syria',
      'YE': 'Yemen',
      'PS': 'Palestine',
      'LY': 'Libya',
      'SD': 'Sudan',
      'MA': 'Morocco',
      'TN': 'Tunisia',
      'DZ': 'Algeria',
      'TR': 'Turkey',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get marketSearchHint => 'Search your country or currency';

  @override
  String orbMood(String mood) {
    String _temp0 = intl.Intl.selectLogic(mood, {
      'listening': 'Zad: listening',
      'focused': 'Zad: thinking',
      'speaking': 'Zad: speaking',
      'happy': 'Zad: pleased',
      'alert': 'Zad: alert',
      'celebrating': 'Zad: celebrating',
      'sad': 'Zad: sad',
      'hungry': 'Zad: hungry',
      'thirsty': 'Zad: thirsty',
      'sleepy': 'Zad: sleepy',
      'other': 'Zad: calm',
    });
    return '$_temp0';
  }

  @override
  String orbAccessoryLabel(String accessory) {
    String _temp0 = intl.Intl.selectLogic(accessory, {
      'bow': 'Bow',
      'glasses': 'Glasses',
      'flower': 'Flower',
      'crown': 'Crown',
      'other': 'None',
    });
    return '$_temp0';
  }

  @override
  String orbPetAsleep(String name) {
    return '$name is asleep';
  }

  @override
  String orbPetMood(String name, String mood) {
    return '$name: $mood';
  }

  @override
  String insightKindLabel(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'question': 'Question',
      'alert': 'Alert',
      'other': 'Info',
    });
    return '$_temp0';
  }

  @override
  String insightDismissReason(String reason) {
    String _temp0 = intl.Intl.selectLogic(reason, {
      'notRelevant': 'Not relevant to me',
      'wrongData': 'The number is wrong',
      'other': 'I already knew',
    });
    return '$_temp0';
  }

  @override
  String localInsightBudgetTitle(String category) {
    return 'Your $category budget is almost used up';
  }

  @override
  String localInsightBudgetBody(String spent, String budget, String category) {
    return 'You\'ve spent $spent of $budget on $category this month.';
  }

  @override
  String localInsightUnusedTitle(String name) {
    return 'Unused subscription: $name';
  }

  @override
  String localInsightUnusedBody(String name, String yearly) {
    return 'We haven\'t seen any activity on $name lately. Cancelling could save $yearly a year.';
  }

  @override
  String localInsightCostlyTitle(String name) {
    return 'Costly subscription: $name';
  }

  @override
  String localInsightCostlyBody(String yearly) {
    return 'This subscription costs you $yearly a year. Is it worth keeping?';
  }

  @override
  String get localInsightWelcomeTitle => 'Welcome to Zad';

  @override
  String get localInsightWelcomeBody =>
      'Add transactions or pantry items so we can analyse your data and make smart suggestions.';

  @override
  String get questionYes => 'Yes';

  @override
  String get questionNo => 'No';

  @override
  String get questionOpenCamera => 'Open the camera';

  @override
  String get questionSend => 'Send';
}
