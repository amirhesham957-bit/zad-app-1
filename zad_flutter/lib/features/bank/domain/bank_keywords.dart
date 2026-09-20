/// ⚠️ بيانات مطابقة، مش نصوص واجهة.
///
/// كل نص في الملف ده بيتطابق مع **نص إشعار البنك الوارد**. ترجمته أو "تحسينه"
/// بيخلي الپارسر يبطل يقرا المعاملات — والعطل ده **مابيبانش في البناء ولا في
/// اللينت ولا في أي تست**: البيلد بيعدّي أخضر، والمشكلة بتبان لما رسالة بنك
/// حقيقية تقف عن القراءة عند عميل حقيقي. (قاعدة i18n في CLAUDE.md.)
///
/// منقولة حرفياً من `app/src/main/java/com/example/data/SaBankParser.kt`. أي
/// تعديل هناك لازم ينزل هنا في نفس الكومِت، والعكس —
/// `bank_notification_test.dart` بيقفل الاتنين على نفس المتجهات.
library;

/// رموز التحقق — مش معاملات.
const List<String> kOtpKeywords = <String>[
  'رمز التحقق',
  'رمز تحقق',
  'كود التحقق',
  'الرمز السري',
  'رمز الدخول',
  'رمز التفعيل',
  'كود التفعيل',
  'كلمة المرور',
  'لا تشارك',
  'لا تشاركه',
  'otp',
  'verification code',
  'one-time',
  'one time password',
  'do not share',
  'password',
  'الرقم السري المؤقت',
  'doğrulama kodu',
  'tek kullanımlık şifre',
  'kimseyle paylaşmayın',
];

/// عملية اتفشلت أو اترفضت.
const List<String> kDeclinedKeywords = <String>[
  'فشل',
  'فشلت',
  'رفض',
  'مرفوضة',
  'مرفوض',
  'لم تتم',
  'لم تنجح',
  'غير ناجحة',
  'تعذر',
  'رصيد غير كاف',
  'insufficient',
  'declined',
  'failed',
  'unsuccessful',
  'rejected',
  'تم الإلغاء',
  'ملغاة',
  'başarısız',
  'reddedildi',
  'yetersiz bakiye',
  'işlem gerçekleşmedi',
];

/// خصم لسه ماحصلش — بشرط توفر رصيد لاحقاً.
///
/// المثال الحقيقي اللي سبّب العطل: رسالة Vodafone "لا يوجد رصيد كافي لتجديد
/// خدمة DSL... سيتم تجديد الخدمة تلقائياً في حالة وجود رصيد كافي" — مفيهاش أي
/// كلمة من [kDeclinedKeywords]، فعدّت فحص الضجيج وانسجلت كمعاملة فعلية بـ530.1
/// رغم إن الرسالة بتقول صراحة إن الخصم مشروط وماحصلش.
const List<String> kPendingKeywords = <String>[
  'لا يوجد رصيد كافي',
  'لا يوجد رصيد كافٍ',
  'رصيد غير كافي',
  'رصيد غير كافٍ',
  'عدم كفاية الرصيد',
  'insufficient balance',
  'insufficient funds',
  'not enough balance',
  'bakiye yetersiz',
];

/// صيغة الشرط المستقبلي — بتتفحص **كزوج** مع [kConditionOnBalanceMarkers] مش
/// لوحدها، عشان مانمنعش رسايل شرعية فيها "سيتم" (تأكيد إيداع مثلاً).
const List<String> kConditionalFutureMarkers = <String>[
  'سيتم',
  'will be',
  'will only',
];

/// الشرط نفسه: معلّق على رصيد لسه مش متوفر.
const List<String> kConditionOnBalanceMarkers = <String>[
  'في حالة وجود رصيد',
  'عند توفر',
  'عند توفّر',
  'لو توفر',
  'لو توفّر',
  'متى ما توفر',
  'if sufficient balance',
  'once balance',
  'if funds become available',
];

/// بطاقة/خدمة منتهية.
const List<String> kExpiredKeywords = <String>[
  'انتهت صلاحية',
  'انتهت صلاحيتها',
  'منتهية الصلاحية',
  'بطاقة منتهية',
  'expired',
  'has expired',
  'card expired',
  'süresi doldu',
  'kartın süresi dolmuş',
];

/// إعلانات.
const List<String> kPromoKeywords = <String>[
  'عرض خاص',
  'عروض',
  'خصم يصل',
  'استمتع',
  'اشترك الآن',
  'حمل التطبيق',
  'سارع',
  'لفترة محدودة',
  'كاش باك يصل',
  '% off',
  'promo',
  'offer ends',
  'özel teklif',
  'kampanya',
  'şimdi abone ol',
  'uygulamayı indir',
];

/// عبارات بتقول إن الإشعار بيتكلم عن فلوس — بتتطابق **كجزء من النص** عن قصد:
/// الأفعال والأسماء العربية بتاخد بادئات ولواحق ("الخصم"، "خصمها").
///
/// "pos" و"card" اتستبعدوا عن قصد: المطابقة بلا حدود كلمات، و"pos" بتطابق
/// "post" و"possible"، و"card" واسعة جداً بالإنجليزي.
const List<String> kMoneyPhrases = <String>[
  'خصم',
  'شراء',
  'دفع',
  'تم الدفع',
  'رصيد',
  'إيداع',
  'تحويل',
  'مبلغ',
  'بطاقة',
  'مشتريات',
  'سحب',
  'راتب',
  'مرتب',
  'مدين',
  'دائن',
  'قسط',
  'فاتورة',
  'اشتراك',
  'تم الخصم',
  'خصم دوري',
  'تجديد تلقائي',
  'التزام شهري',
  'قسط شهري',
  'سداد',
  'تم السداد',
  'استحقاق',
  'مستحق',
  'دفعة',
  'أقساط',
  'تجديد اشتراك',
  'إشعار خصم',
  'auto debit',
  'recurring',
  'إيجار',
  'قسط إيجار',
  'تم التحويل من',
  'أمر خصم',
  'فاتورة كهربا',
  'فاتورة مياه',
  'فاتورة نت',
  'فاتورة الجوال',
  'الكهرباء',
  'المياه',
  'الاتصالات',
  'الإنترنت',
  'محفظة',
  'تم استلام',
  'تم إرسال',
  'تم تحويل',
  'عملية',
  'معاملة',
  'طلبك',
  'استرجاع',
  'استرداد',
  'كاش باك',
  'نقاط',
  'تم الشراء',
  'pay',
  'paid',
  'purchase',
  'amount',
  'debit',
  'credit',
  'transfer',
  'balance',
  'deposit',
  'withdraw',
  'refund',
  'cashback',
  'receipt',
  'transaction',
  'charged',
  'order total',
  'salary',
  'ödeme',
  'harcama',
  'bakiye',
  'kartınızdan',
  'fatura',
  'maaş',
  'iade',
  'havale',
  'işlem',
  'paiement',
  'achat',
  'solde',
  'virement',
  'retrait',
  'carte bancaire',
  'montant',
  'débit',
  'crédit',
];

/// أكواد ورموز العملات — بتتطابق **بحدود كلمات**، مش كجزء من كلمة.
///
/// مقاس على ٧٬٧٣٣ نص واجهة بالخمس لغات: تسعة كانوا بيتطابقوا جوه كلمات عادية —
/// TL في "Currently"، MAD في "Ramadan"، ILS في "Details"، TRY في "Country"،
/// و"رس" في "رسائل"/"أرسل". سبعة منهم كانوا بيعدّوا **البوابتين** فيرجّعوا مبلغ
/// من نص مش مالي خالص. وأخطرهم "وصلتك 3 رسائل جديدة" اللي كان بيتقري معاملة بـ3
/// — ودي مش حالة متخيّلة، ده نص إشعار تطبيق المراسلة، وهو القناة البنكية
/// الأساسية (CLAUDE.md، قسم الإشعارات البنكية).
const List<String> kCurrencyTokens = <String>[
  'ر.س',
  'رس',
  'ريال',
  'SAR',
  'TL',
  '₺',
  'TRY',
  'eft',
  'EGP',
  'ج.م',
  'جنيه',
  'AED',
  'د.إ',
  'KWD',
  'د.ك',
  'QAR',
  'ر.ق',
  'BHD',
  'د.ب',
  'OMR',
  'ر.ع',
  'JOD',
  'د.أ',
  'LBP',
  'ل.ل',
  'IQD',
  'د.ع',
  'SYP',
  'ل.س',
  'YER',
  'ر.ي',
  'ILS',
  '₪',
  'LYD',
  'د.ل',
  'SDG',
  'ج.س',
  'MAD',
  'د.م',
  'TND',
  'د.ت',
  'DZD',
  'د.ج',
  'دينار',
  'درهم',
  'USD',
  r'$',
  'EUR',
  '€',
  'GBP',
  '£',
  'دولار',
  'يورو',
];

/// رمز مكتوب بشكل مميز — كود ISO أو اختصار محلي بيحسم العملة فوراً.
const Map<String, String> kUnambiguousCurrencyTokens = <String, String>{
  'sar': 'SAR',
  'sr': 'SAR',
  'ر.س': 'SAR',
  'رس': 'SAR',
  'egp': 'EGP',
  'ج.م': 'EGP',
  'جم': 'EGP',
  'try': 'TRY',
  'tl': 'TRY',
  '₺': 'TRY',
  'aed': 'AED',
  'د.إ': 'AED',
  'kwd': 'KWD',
  'د.ك': 'KWD',
  'qar': 'QAR',
  'ر.ق': 'QAR',
  'bhd': 'BHD',
  'د.ب': 'BHD',
  'omr': 'OMR',
  'ر.ع': 'OMR',
  'jod': 'JOD',
  'د.أ': 'JOD',
  'lbp': 'LBP',
  'ل.ل': 'LBP',
  'iqd': 'IQD',
  'د.ع': 'IQD',
  'syp': 'SYP',
  'ل.س': 'SYP',
  'yer': 'YER',
  'ر.ي': 'YER',
  'ils': 'ILS',
  'nis': 'ILS',
  '₪': 'ILS',
  'lyd': 'LYD',
  'د.ل': 'LYD',
  'sdg': 'SDG',
  'ج.س': 'SDG',
  'mad': 'MAD',
  'د.م': 'MAD',
  'tnd': 'TND',
  'د.ت': 'TND',
  'dzd': 'DZD',
  'د.ج': 'DZD',
  'usd': 'USD',
  r'$': 'USD',
  'دولار': 'USD',
  'eur': 'EUR',
  '€': 'EUR',
  'يورو': 'EUR',
  'gbp': 'GBP',
  '£': 'GBP',
};

/// كلمة عامية مشتركة بين أكتر من بلد. بترجع عملة بس لو بتطابق عملة السوق
/// المختار حالياً — أبداً مش تخمين عبر حدود دولة، نفس مبدأ الپارسر الأساسي
/// "الرفض أفضل من التخمين".
const Map<String, Set<String>> kAmbiguousCurrencyFamilies =
    <String, Set<String>>{
      'ريال': <String>{'SAR', 'QAR', 'YER'},
      'دينار': <String>{'KWD', 'BHD', 'JOD', 'IQD', 'LYD', 'TND', 'DZD'},
      'درهم': <String>{'AED', 'MAD'},
      'جنيه': <String>{'EGP', 'SDG'},
      'ليرة': <String>{'LBP', 'SYP', 'TRY'},
    };

/// الأرقام العربية-الهندية ← لاتينية، والفاصلة العشرية العربية ← نقطة.
///
/// مطابقة حرفياً لـ`arabicIndicDigits` في كوتلن: الأرقام الفارسية (۰-۹) **مش**
/// موجودة هناك، فمش موجودة هنا. إضافتها في طرف واحد بس معناها إن الطرفين بيقروا
/// نفس الرسالة بشكل مختلف.
const Map<String, String> kArabicIndicDigits = <String, String>{
  '٠': '0',
  '١': '1',
  '٢': '2',
  '٣': '3',
  '٤': '4',
  '٥': '5',
  '٦': '6',
  '٧': '7',
  '٨': '8',
  '٩': '9',
  '٫': '.',
};
