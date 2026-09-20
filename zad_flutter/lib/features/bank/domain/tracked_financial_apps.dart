/// Which packages are named financial apps.
///
/// ⚠️ This list is **not** the bank channel's coverage, and treating it as one
/// is the mistake this comment exists to prevent.
///
/// Measured over the whole of `zad_notification_ingest_events`: every recorded
/// bank transaction on this project arrived from a package that is **not** in
/// this list — all of them from `com.google.android.apps.messaging`, the
/// messaging app, which will never be in it. That follows from dropping
/// RECEIVE_SMS for Play Store compliance: bank text stopped being an SMS
/// broadcast and became a notification from whichever app displays it.
///
/// So membership here does one narrow thing: it lets a message with no
/// readable amount through the gate anyway, on the grounds that a named bank
/// saying something unrecognised is worth the server's attention. Everything
/// else — anything with an amount, anything that failed or is pending — goes
/// up regardless of the package.
///
/// **Never tighten filtering on untracked packages without re-measuring
/// first.** A third suppression rule was proposed on this evidence and
/// rejected. The numbers and the re-measurement query are in
/// `docs/agent/BANK_NOTIFICATION_CHANNEL.md`.
library;

/// Named banking and wallet apps whose unreadable messages still reach the
/// server.
const Set<String> kTrackedFinancialApps = <String>{
  // Saudi
  'com.alrajhibank.activity',
  'sa.alinma.mobile',
  'com.ncb.alahlimobile',
  'sa.com.riyadbank.mobile',
  'com.bankalbilad.mobile',
  'sa.com.sabb.sabbmobile',
  'com.stcpay.stcpay',
  // Egypt
  'com.cib.egypt',
  'com.nbe.mobilebanking',
  'com.banquemisr.mobile',
  'com.vodafone.vodafonecash',
  'com.fawry.myfawry',
  'com.instapay.ipn',
  // Gulf
  'com.emiratesnbd.mobilebanking',
  'ae.mashreq.mashreqmobile',
  'com.nbk.mobile',
  'qa.qnb.mobile',
  // Turkey
  'com.garanti.cepsubesi',
  'com.ziraat.ziraatmobil',
  'com.pozitron.iscep',
  // Cards and global wallets
  'com.paypal.android.p2pmobile',
  'com.wise.android',
};

/// Whether [packageName] is a named financial app.
bool isTrackedFinancialApp(String packageName) =>
    kTrackedFinancialApps.contains(packageName);
