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
  String get drawerNearby => 'Deals and shops nearby';

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
  String get memoryGraphResetView => 'Put the graph back';

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
      'That\'s today\'s voice questions (6 a day) — they\'re back tomorrow. Type your question, or subscribe to talk to Zad without a limit.';

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
      'That\'s today\'s voice questions — 6 a day, back tomorrow';

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
  String get openOfferSource => '🔗 Open the offer';

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
  String get scanLineToPharmacy => 'To pharmacy 💊';

  @override
  String get scanPantryWithMedicines =>
      'What you have goes up, what\'s on the shopping list comes off it, and medicines go to the pharmacy.';

  @override
  String get dealsTitle => 'Deals and shops nearby';

  @override
  String get dealsTabDeals => 'Deals';

  @override
  String get dealsTabNearby => 'Shops nearby';

  @override
  String get dealsEmptyTitle => 'No deals yet';

  @override
  String get dealsEmptyBody =>
      'Zad searches store pages, delivery apps and households\' receipts every week. Anything it finds shows up here.';

  @override
  String get dealsFailedTitle => 'Couldn\'t load the deals';

  @override
  String get dealsFailedBody =>
      'Check your connection and pull down to try again.';

  @override
  String get dealsCodesHeader => 'Discount codes';

  @override
  String get dealsStoresHeader => 'Store deals';

  @override
  String get dealsFootnote =>
      'Deals come from their sources with their dates — a deal may have ended. The Amazon button opens a search in your country\'s store, and Zad earns a small commission from it.';

  @override
  String get dealsOnAmazon => 'On Amazon';

  @override
  String dealsCopied(String code) {
    return 'Copied $code';
  }

  @override
  String dealsCodeTitle(String store, String off) {
    return '$store — $off off';
  }

  @override
  String dealsPercent(String n) {
    return '$n%';
  }

  @override
  String dealsPrice(String store, String price, String currency) {
    return '$store · $price $currency';
  }

  @override
  String dealsWasPrice(String price) {
    return 'instead of $price';
  }

  @override
  String dealsMinOrder(String amount) {
    return 'on orders of $amount or more';
  }

  @override
  String dealsUntil(String date) {
    return 'until $date';
  }

  @override
  String get dealsSourceVideo => 'Store\'s video';

  @override
  String get dealsSourcePost => 'Store\'s post';

  @override
  String get dealsSourcePage => 'Store\'s page';

  @override
  String get dealsSourceFlyer => 'Store\'s flyer';

  @override
  String get dealsSourceReceipts => 'Receipts from homes near you';

  @override
  String get dealsSourcePartner => 'Partner link';

  @override
  String get dealsSourceOther => 'Source';

  @override
  String get homeDealsTitle => 'Deals on what you\'re out of';

  @override
  String get recipesWeekGroup => 'This week\'s plan';

  @override
  String get recipesWeekAction => 'Week plan';

  @override
  String recipesWeekDay(int day) {
    return 'Day $day';
  }

  @override
  String get recipesOnDeal => 'On offer now';

  @override
  String recipesFromCreator(String handle) {
    return 'From @$handle\'s video';
  }

  @override
  String get recipesTrendingGroup => 'Trending now';

  @override
  String get homeDealsSeeAll => 'All deals';

  @override
  String get homeDealsWhyNeed => 'You\'re out';

  @override
  String get homeDealsWhyFavorite => 'Your store';

  @override
  String get homeDealsWhyFire => 'Big discount';

  @override
  String get homeDealsWhyWant => 'You asked about it';

  @override
  String get homeDealsWhySeason => 'Ahead of the season';

  @override
  String get homeDealsWhyTop => 'Top discount';

  @override
  String homeDealsCode(String code) {
    return 'Code $code';
  }

  @override
  String get bankTestLifeEvent => 'An appointment or event';

  @override
  String get outOfAttemptsTitle => 'You\'re out of attempts';

  @override
  String get lowAttemptsTitle => 'You\'re almost out of attempts';

  @override
  String get outOfAttemptsBody =>
      'Watch 3 ads to get an attempt, or subscribe.';

  @override
  String get outOfAttemptsPlans => 'See the plans';

  @override
  String get patternTitle => 'Your shopping pattern';

  @override
  String get patternMenuSubtitle =>
      'Your stores, when you shop, and each item\'s cycle';

  @override
  String get patternLearningTitle => 'Still learning';

  @override
  String get patternLearningMessage =>
      'Zad works out your pattern every night from your receipts and spending. Scan a receipt or log a purchase and check back tomorrow.';

  @override
  String get patternReadFailed =>
      'Couldn\'t read your pattern right now. Pull down to try again.';

  @override
  String get patternWeekly => 'Your average weekly spending';

  @override
  String get patternStores => 'Your stores';

  @override
  String patternStoreLine(String visits, String share) {
    return '$visits visits · $share% of your store spending';
  }

  @override
  String get patternWhen => 'When you shop';

  @override
  String patternWhenLine(String day, String part) {
    return 'Usually on $day, $part';
  }

  @override
  String patternEvery(String days) {
    return 'A shopping trip about every $days days';
  }

  @override
  String get patternWhenUnknown =>
      'I need at least 4 shopping trips to know when you shop';

  @override
  String get patternPartMorning => 'in the morning';

  @override
  String get patternPartNoon => 'at midday';

  @override
  String get patternPartEvening => 'in the evening';

  @override
  String get patternPartNight => 'at night';

  @override
  String get patternItems => 'Each item\'s cycle';

  @override
  String get patternItemsHint => 'Tap an item to tell Zad how often you buy it';

  @override
  String patternItemEvery(String days) {
    return 'Every $days days';
  }

  @override
  String get patternSourceCustomer => 'Set by you';

  @override
  String get patternSourceLearned => 'From your purchases';

  @override
  String get patternSourceEstimate => 'First estimate';

  @override
  String get patternDueNow => 'Time to buy';

  @override
  String patternDueIn(String days) {
    return 'Next purchase in $days days';
  }

  @override
  String patternEditTitle(String item) {
    return 'How often do you buy $item?';
  }

  @override
  String get patternEditField => 'Days';

  @override
  String get patternEditInvalid => 'Enter a number from 1 to 365';

  @override
  String get patternEditSave => 'Save';

  @override
  String get patternEditReset => 'Let Zad decide';

  @override
  String get patternEditNotInPantry =>
      'This item isn\'t in your pantry right now';

  @override
  String patternEditSaved(String item) {
    return 'Saved — Zad will plan $item by that';
  }

  @override
  String get homeBankOffBanner =>
      '⚠️ Bank message reading has stopped. Tap here to turn it back on so your balance and spending update by themselves.';

  @override
  String get homeBankStalledHint =>
      'If it is already on: switch it off and on again on the screen that opens.';

  @override
  String get homeLocationOffBanner =>
      '📍 Your location is off. Turn it on so Zad can match supermarket deals and nearby shops and do its job properly.';

  @override
  String get homeLocationLater => 'Not now';

  @override
  String get channelCardTitle => 'Zad has no way to reach you';

  @override
  String get channelCardBody =>
      'Notifications are off and Telegram isn\'t linked, so medicine times, bills and budget alerts won\'t reach you. Either one is enough.';

  @override
  String get channelCardNotifications => 'Turn on notifications';

  @override
  String get channelCardTelegram => 'Link Telegram';

  @override
  String get briefWhy => 'Why?';

  @override
  String briefWhyDose(String name, String time) {
    return 'From $name\'s schedule: the $time dose, with nothing recorded yet.';
  }

  @override
  String briefWhyMissed(String count) {
    return 'Today\'s doses past their time with nothing recorded: $count.';
  }

  @override
  String get briefWhyOverspent =>
      'This period\'s available money is below zero: the opening balance minus what was spent and the fixed commitments.';

  @override
  String briefWhyRenewal(String name) {
    return '«$name» is in your subscriptions, and this is its next renewal.';
  }

  @override
  String briefWhyShortage(String name, String left, String threshold) {
    return '$name: $left left, which is where it counts as low ($threshold).';
  }

  @override
  String briefWhyRunningOut(String name, String left, String perDay) {
    return '$name: $left left, and you use about $perDay a day.';
  }

  @override
  String briefWhyRunningOutApprox(String name, String left, String perDay) {
    return '$name: $left left; your usage is still being measured — about $perDay a day, so this is an estimate.';
  }

  @override
  String get briefWhyFamily =>
      'Someone in the family chat said it\'s needed, and Zad picked it up reviewing the chat.';

  @override
  String briefMedicineLow(String name, String days) {
    return '$name runs out in $days days';
  }

  @override
  String get briefMedicineLowDetail => 'Get a new box before it runs out';

  @override
  String briefBudgetDanger(String daily, String days) {
    return 'Budget at risk: $daily a day left for $days days';
  }

  @override
  String get briefBudgetDangerDetail =>
      'Open money — there\'s still time to catch up';

  @override
  String briefSeasonRamadan(String days) {
    return 'Ramadan in $days days';
  }

  @override
  String briefSeasonHijjah(String days) {
    return 'The first ten days of Dhul Hijjah in $days days';
  }

  @override
  String get briefSeasonDetail => 'Get the basics in before prices go up';

  @override
  String briefWhyMedicineLow(String name, String days) {
    return '$name: pills left ÷ doses a day = $days days.';
  }

  @override
  String briefWhyBudgetDanger(String available, String days, String daily) {
    return '$available available over $days days = $daily a day, and your spending so far says it won\'t last.';
  }

  @override
  String get briefWhySeason =>
      'From the Umm al-Qura calendar in your country\'s time — prices rise before the season.';

  @override
  String get accountRestoreTitle => 'Your account is scheduled for deletion';

  @override
  String accountRestoreBody(int days) {
    return 'You asked to delete your account. It and all its data will be erased in $days days. Restore it?';
  }

  @override
  String get accountRestoreLeave => 'Sign out';

  @override
  String get accountRestoreYes => 'Restore my account';

  @override
  String get accountRestoreFailed =>
      'Couldn\'t restore the account right now. Reopen the app and try again.';

  @override
  String get settingsCompanionSection => 'Your companion';

  @override
  String get settingsFoodPatternTitle => 'Your home\'s food picture';

  @override
  String get settingsFoodPatternBody =>
      'At most once a month, Zad describes your home\'s food from recorded purchases and suggests additions. A description of purchases, not medical advice.';

  @override
  String get commuteTitle => 'Learn when I leave and come back';

  @override
  String get commuteBody => 'Optional. Times only, no places or routes.';

  @override
  String get commuteConsentTitle => 'Let Zad learn your daily times?';

  @override
  String get commuteConsentBody =>
      'Zad works out when you usually leave home and return, from your leaving and coming home, so it can fit reminders to your day and reach you at the right time.\n\nThis is worked out on your phone. Only a summary of times and weekdays goes to the server: no coordinates, workplace or route. Nobody in your family sees it. Turning this off erases it from your phone and the server.';

  @override
  String get commuteConsentAgree => 'I agree';

  @override
  String get commuteConsentDecline => 'Not now';

  @override
  String get settingsPetCallsTitle => 'Zado\'s calls';

  @override
  String get settingsPetCallsBody =>
      'Zado messages you when it\'s hungry or thirsty, on Telegram and by notification. Turning this off doesn\'t stop the morning greeting or the deals.';
}
