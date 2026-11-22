/// What the chore sheets read from a text field (M5.2): minutes a week and a
/// comma list of chore titles, kept to the table's ranges.
library;

/// Minutes a week as typed (Arabic or Latin digits); null outside 0–2000,
/// the column's range.
int? chorePrefMinutes(String text) {
  const arabic = '٠١٢٣٤٥٦٧٨٩'; // l10n: data
  final latin = text.trim().split('').map((c) {
    final i = arabic.indexOf(c);
    return i < 0 ? c : '$i';
  }).join();
  final value = int.tryParse(latin);
  return value != null && value >= 0 && value <= 2000 ? value : null;
}

/// Chore titles from a comma list (Arabic or Latin commas), trimmed, unique,
/// at most 20 — the column's cap.
List<String> choreTitles(String text) => text
    .split(RegExp('[,،]')) // l10n: data
    .map((t) => t.trim())
    .where((t) => t.isNotEmpty)
    .toSet()
    .take(20)
    .toList();
