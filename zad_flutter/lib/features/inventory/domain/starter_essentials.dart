/// The basics an empty pantry offers in one tap (ZAD_PLAN ١٠.١ slice 5).
///
/// A new account opened «بيتي» to «المخزون فارغ» and one camera button
/// (emulator, 2026-11-12): nothing to start from without a receipt in hand.
/// These are the staples nearly every home in the market keeps, ticked and
/// added together.
///
/// Every field is **data**: the name, unit and category are written to
/// `zad_inventory` as they are and matched on later (CLAUDE.md i18n rule), so
/// they stay in the market's own Arabic — «حليب» and «خبز» in the Gulf,
/// «لبن» and «عيش» in Egypt.
library;

/// One staple: what is written to the row.
typedef StarterItem = ({
  String name,
  String unit,
  String category,
  double quantity,
});

// l10n: data-begin
const List<StarterItem> _egypt = <StarterItem>[
  (name: 'رز', unit: 'كيلو', category: 'البقالة', quantity: 1),
  (name: 'سكر', unit: 'كيلو', category: 'البقالة', quantity: 1),
  (name: 'زيت', unit: 'لتر', category: 'البقالة', quantity: 1),
  (name: 'مكرونة', unit: 'كيس', category: 'البقالة', quantity: 1),
  (name: 'شاي', unit: 'علبة', category: 'المشروبات', quantity: 1),
  (name: 'لبن', unit: 'لتر', category: 'الألبان', quantity: 1),
  (name: 'جبنة', unit: 'علبة', category: 'الألبان', quantity: 1),
  (name: 'بيض', unit: 'حبة', category: 'الألبان', quantity: 10),
  (name: 'عيش', unit: 'كيس', category: 'البقالة', quantity: 1),
];

const List<StarterItem> _gulf = <StarterItem>[
  (name: 'رز', unit: 'كيلو', category: 'البقالة', quantity: 1),
  (name: 'سكر', unit: 'كيلو', category: 'البقالة', quantity: 1),
  (name: 'زيت', unit: 'لتر', category: 'البقالة', quantity: 1),
  (name: 'مكرونة', unit: 'كيس', category: 'البقالة', quantity: 1),
  (name: 'شاي', unit: 'علبة', category: 'المشروبات', quantity: 1),
  (name: 'حليب', unit: 'لتر', category: 'الألبان', quantity: 1),
  (name: 'جبن', unit: 'علبة', category: 'الألبان', quantity: 1),
  (name: 'بيض', unit: 'حبة', category: 'الألبان', quantity: 10),
  (name: 'خبز', unit: 'كيس', category: 'البقالة', quantity: 1),
  (name: 'تمر', unit: 'كيلو', category: 'البقالة', quantity: 1),
];

const Set<String> _gulfMarkets = <String>{'SA', 'AE', 'KW', 'QA', 'BH', 'OM'};
// l10n: data-end

/// The basics for an account in [country] (ISO alpha-2); Egypt's when the
/// market is not known yet.
List<StarterItem> starterEssentials(String? country) =>
    _gulfMarkets.contains(country?.trim().toUpperCase()) ? _gulf : _egypt;
