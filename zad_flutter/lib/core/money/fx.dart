/// Currency conversion for one job: carrying the customer's limits across
/// when they change country. Kotlin's `CurrencyExchange` seed, rate for rate —
/// the value is how many US dollars one unit of the currency is worth.
///
/// Offline seed, not a source of truth; good enough to keep a monthly limit
/// meaning the same money after a move, and never used to value a
/// transaction.
library;

const Map<String, double> _usdPerUnit = <String, double>{
  'USD': 1,
  'SAR': 0.26666667,
  'EGP': 0.019649473,
  'AED': 0.27229408,
  'KWD': 3.2440358,
  'QAR': 0.27472527,
  'BHD': 2.6595745,
  'OMR': 2.6008005,
  'JOD': 1.4104372,
  'LBP': 0.000011173184,
  'IQD': 0.00076265172,
  'SYP': 0.0082173756,
  'YER': 0.0042207236,
  'ILS': 0.33198305,
  'LYD': 0.15757978,
  'SDG': 0.0021796741,
  'MAD': 0.10692106,
  'TND': 0.34380353,
  'DZD': 0.007507284,
  'TRY': 0.020635439,
};

/// [amount] in [from] as [to], or null when either currency is unknown —
/// never a silent 1:1, which would treat a Syrian pound as a dollar.
double? convertCurrency(double amount, String from, String to) {
  final f = from.trim().toUpperCase();
  final t = to.trim().toUpperCase();
  if (f == t) return amount;
  final a = _usdPerUnit[f];
  final b = _usdPerUnit[t];
  if (a == null || b == null || a <= 0 || b <= 0) return null;
  return amount * (a / b);
}
