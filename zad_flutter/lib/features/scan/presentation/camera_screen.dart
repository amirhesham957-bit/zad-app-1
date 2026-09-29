/// Kotlin's `CameraScreen` (`ui/screens/CameraScreen.kt`): «الماسح الذكي» —
/// photograph the pantry, a receipt or a medicine box, read it, review it in
/// a dialog, and only then write anything.
///
/// The reads are the same edge actions Kotlin calls (`analyze_inventory_image`,
/// `analyze_receipt`, `analyze_medicine_image`); the writes go through this
/// client's intake ([CameraActions]). Kotlin's personal Gemini key dialog is
/// left out by the owner's decision; its settings button opened nothing.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:lottie/lottie.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:zad/app/shell/zad_chrome.dart';
import 'package:zad/data/providers.dart';
import 'package:zad/design/tokens/zad_extended_colors.dart';
import 'package:zad/features/inventory/domain/receipt_intake.dart';
import 'package:zad/features/market/domain/market.dart';
import 'package:zad/features/scan/application/camera_actions.dart';
import 'package:zad/features/scan/application/scan_controller.dart';
import 'package:zad/features/scan/data/receipt_scanner.dart';
import 'package:zad/features/scan/data/vision_scanner.dart';
import 'package:zad/features/scan/domain/scanned_receipt.dart';

/// What the screen scans.
enum CameraMode {
  /// The pantry.
  inventory,

  /// A receipt.
  receipt,

  /// A medicine box.
  pharmacy,
}

/// Opens the screen on [mode] — Kotlin's `camera/{mode}` route.
Future<void> showCameraScreen(BuildContext context, CameraMode mode) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => CameraScreen(initialMode: mode)),
    );

/// Kotlin's `showCameraSheet = true`: the camera sheet's choice, then the
/// screen on that mode.
Future<void> openZadCamera(BuildContext context) async {
  final choice = await showZadCameraSheet(context);
  if (!context.mounted || choice == null) return;
  await showCameraScreen(
    context,
    choice == ZadCameraChoice.receipt
        ? CameraMode.receipt
        : CameraMode.inventory,
  );
}

const List<(ReceiptType, String)> _receiptTypes = <(ReceiptType, String)>[
  (ReceiptType.pharmacy, 'صيدلية'),
  (ReceiptType.grocery, 'سوبرماركت'),
  (ReceiptType.general, 'مصاريف عامة'),
];

const List<String> _units = <String>[
  'قطعة',
  'كجم',
  'لتر',
  'حبة',
  'علبة',
  'كرتون',
  'زجاجة',
  'كيس',
];

const List<String> _manualCategories = <String>[
  'خضار',
  'فواكه',
  'ألبان',
  'لحوم',
  'بقالة',
  'مشروبات',
  'منظفات',
  'معلبات',
  'عام',
];

/// The screen.
class CameraScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const new({this.initialMode = CameraMode.inventory, super.key});

  /// Preselected by the camera sheet's two buttons, or the pharmacy.
  final CameraMode initialMode;

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  late CameraMode _mode = widget.initialMode;
  Uint8List? _image;
  String _status =
      'التقط صورة للثلاجة أو أكياس البقالة أو الفاتورة وسيستخرجها الذكاء '
      'الاصطناعي!';
  bool _analyzing = false;
  bool _flash = false;
  bool _permanentlyDenied = false;

  String _money(double v) {
    final country = ref.read(settingsRepositoryProvider).cached()?.country;
    final symbol = marketFor(country)?.currencySymbol ?? '';
    final n = NumberFormat('#,##0.##', 'en').format(v);
    return symbol.isEmpty ? n : '$n $symbol';
  }

  void _say(String s) {
    if (mounted) setState(() => _status = s);
  }

  Future<void> _shoot(CameraMode mode) async {
    setState(() => _mode = mode);
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (!status.isGranted) {
      final blocked = status.isPermanentlyDenied;
      setState(() {
        _permanentlyDenied = blocked;
        _status = blocked
            ? 'صلاحية الكاميرا ممنوعة نهائياً — افتح الإعدادات وفعّلها عشان '
                  'تقدر تصوّر'
            : 'نحتاج صلاحية الكاميرا للمسح. يمكنك الإضافة يدوياً';
      });
      return;
    }
    _permanentlyDenied = false;
    Uint8List? bytes;
    try {
      bytes = await ref
          .read(receiptCameraProvider)
          .capture(ReceiptImageSource.camera);
    } on Object {
      _say('تعذر فتح الكاميرا. ثبّت تطبيق كاميرا أو استخدم الإدخال اليدوي');
      return;
    }
    if (bytes == null || !mounted) return;
    setState(() {
      _image = bytes;
      _flash = true;
      _analyzing = true;
      _status = 'جاري تحليل الصورة بالذكاء الاصطناعي...';
    });
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _flash = false);
    });
    await _analyze(bytes);
    if (mounted) setState(() => _analyzing = false);
  }

  Future<void> _analyze(Uint8List bytes) async {
    final userId = ref.read(signedInUserIdProvider)() ?? '';
    try {
      switch (_mode) {
        case CameraMode.pharmacy:
          final med = await ref
              .read(visionScannerProvider)
              .medicine(userId: userId, image: bytes);
          if (med != null && med.name.trim().isNotEmpty) {
            unawaited(HapticFeedback.mediumImpact());
            _say('تم التعرف على: ${med.name}');
            if (mounted) unawaited(_confirmMedicine(med));
          } else {
            _say('تعذر قراءة العلبة بدقة، يرجى المحاولة بزاوية أوضح');
          }
        case CameraMode.inventory:
          final items = await ref
              .read(visionScannerProvider)
              .pantry(userId: userId, image: bytes);
          if (items.isNotEmpty) {
            unawaited(HapticFeedback.mediumImpact());
            _say('تم استخراج ${items.length} منتج! راجعها وأكّد');
            if (mounted) unawaited(_confirmPantry(items));
          } else {
            _say(
              'لم يتعرف AI على منتجات واضحة. جرب تصوير أقرب أو بإضاءة أفضل، '
              'أو أضفها يدوياً',
            );
          }
        case CameraMode.receipt:
          final receipt = await ref
              .read(receiptScannerProvider)
              .scan(userId: userId, image: bytes);
          // A silent "0" save is worse than an error.
          if (receipt.total > 0 || receipt.items.isNotEmpty) {
            unawaited(HapticFeedback.mediumImpact());
            _say('تم استخراج فاتورة ${receipt.storeName}! راجعها وأكّد');
            if (mounted) unawaited(_confirmReceipt(receipt));
          } else {
            _say('لم نتمكن من قراءة الفاتورة، يرجى المحاولة بصورة أوضح');
            if (mounted) unawaited(_receiptError());
          }
      }
    } on Object {
      _say('حدث خطأ أثناء التحليل. جرب مرة أخرى');
    }
  }

  Future<void> _confirmPantry(List<ScannedPantryItem> parsed) async {
    final kept = await showDialog<List<ScannedPantryItem>>(
      context: context,
      builder: (_) => _PantryConfirmDialog(items: parsed),
    );
    if (!mounted) return;
    if (kept == null) {
      _say('تم إلغاء الإضافة');
      return;
    }
    setState(() {
      _image = null;
      _status = 'جاري حقن ${kept.length} منتجات في المخزون...';
    });
    final summary = await ref.read(cameraActionsProvider.notifier).injectPantry(
      <IntakeLine>[
        for (final i in kept)
          IntakeLine(
            name: i.name,
            quantity: i.quantity < 1 ? 1 : i.quantity,
            unit: i.unit,
            category: i.category,
          ),
      ],
    );
    _say('تم الحقن: $summary');
  }

  Future<void> _confirmMedicine(ScannedMedicine med) async {
    final save = await showDialog<bool>(
      context: context,
      builder: (_) => _MedicineConfirmDialog(med: med),
    );
    if (!mounted) return;
    if (save != true) {
      _say('تم إلغاء الإضافة');
      return;
    }
    await ref.read(cameraActionsProvider.notifier).addMedicine(med);
    if (!mounted) return;
    setState(() => _image = null);
    _say('تم التعرف على: ${med.name}');
  }

  Future<void> _receiptError() => showDialog<void>(
    context: context,
    builder: (c) {
      final scheme = Theme.of(c).colorScheme;
      return AlertDialog(
        icon: Icon(Icons.error_outline, color: scheme.error),
        title: const Text(
          'تعذّرت قراءة الفاتورة',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'لم نتمكن من قراءة الفاتورة، يرجى المحاولة بصورة أوضح',
        ),
        actions: <Widget>[
          FilledButton(
            onPressed: () {
              Navigator.of(c).pop();
              setState(() => _image = null);
            },
            child: const Text('حسناً'),
          ),
        ],
      );
    },
  );

  Future<void> _confirmReceipt(ScannedReceipt parsed) async {
    final receipt = await showDialog<ScannedReceipt>(
      context: context,
      builder: (_) => _ReceiptConfirmDialog(receipt: parsed, money: _money),
    );
    if (!mounted) return;
    if (receipt == null) {
      _say('تم إلغاء الفاتورة');
      return;
    }
    setState(() => _image = null);
    final actions = ref.read(cameraActionsProvider.notifier);
    final total = _money(receipt.total);
    if (receipt.type == ReceiptType.pharmacy) {
      await actions.savePharmacyReceipt(receipt);
      _say('تم تسجيل فاتورة ${receipt.storeName} ($total) في الصيدلية!');
    } else if (isHouseholdReceipt(receipt)) {
      _say('تم تسجيل فاتورة ${receipt.storeName} ($total) وتحديث المخزون!');
      final summary = await actions.saveHouseholdReceipt(receipt);
      _say('فاتورة ${receipt.storeName}: $summary');
    } else {
      _say(
        'تم تسجيل فاتورة ${receipt.storeName} بقيمة $total والمنتجات في '
        'المخزون!',
      );
      final summary = await actions.saveReceipt(receipt);
      _say('فاتورة ${receipt.storeName} ($total): $summary');
    }
  }

  Future<void> _manual() async {
    final items = await showDialog<List<IntakeLine>>(
      context: context,
      builder: (_) => const _ManualInventoryDialog(),
    );
    if (items == null || items.isEmpty || !mounted) return;
    await ref.read(cameraActionsProvider.notifier).injectPantry(items);
    _say('تمت إضافة ${items.length} منتجات يدوياً!');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final pharmacy =
        _mode == CameraMode.pharmacy ||
        widget.initialMode == CameraMode.pharmacy;
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );

    return Stack(
      children: <Widget>[
        Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: bg,
            title: const Text(
              '  الماسح الذكي',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            actions: <Widget>[
              IconButton(
                tooltip: 'Settings',
                onPressed: () {},
                icon: Icon(Icons.settings, color: scheme.primary),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    height: 300,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          scheme.surfaceContainerHighest,
                          scheme.surfaceContainerLow,
                        ],
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        if (_image != null)
                          Image.memory(
                            _image!,
                            fit: BoxFit.contain,
                            semanticLabel: 'الصورة الملتقطة',
                          )
                        else
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Icon(
                                Icons.camera_alt,
                                size: 72,
                                color: scheme.onSurfaceVariant.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'التقط صورة للمخزون أو الفاتورة',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'سيقوم AI باستخراج المنتجات تلقائياً',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        if (_analyzing)
                          ColoredBox(
                            color: Colors.black.withValues(alpha: 0.4),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Lottie.asset(
                                  'assets/lottie/lottie_scan_receipt.json',
                                  width: 96,
                                  height: 96,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'جاري التحليل...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: <Widget>[
                    if (pharmacy)
                      Expanded(
                        child: SizedBox(
                          height: 60,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(shape: buttonShape),
                            onPressed: _analyzing
                                ? null
                                : () => _shoot(CameraMode.pharmacy),
                            icon: const Icon(Icons.medication, size: 22),
                            label: const Text(
                              '   مسح علبة دواء',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      )
                    else ...<Widget>[
                      Expanded(
                        child: SizedBox(
                          height: 60,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(shape: buttonShape),
                            onPressed: _analyzing
                                ? null
                                : () => _shoot(CameraMode.inventory),
                            icon: const Icon(Icons.camera_alt, size: 22),
                            label: const Text(
                              '   مسح المخزون',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 60,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(shape: buttonShape),
                            onPressed: _analyzing
                                ? null
                                : () => _shoot(CameraMode.receipt),
                            icon: const Icon(Icons.receipt, size: 22),
                            label: const Text(
                              '   مسح الفاتورة',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.onSurface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _manual,
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text(
                      '   إضافة منتجات يدوياً',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _status.isEmpty
                      ? const SizedBox.shrink()
                      : Container(
                          key: ValueKey<String>(_status),
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: <Widget>[
                              Text(
                                _status,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: scheme.onSurface),
                              ),
                              // The way out of the dead end: a refused
                              // permission never shows the system dialog again.
                              if (_permanentlyDenied) ...<Widget>[
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () async {
                                    await openAppSettings();
                                    final s = await Permission.camera.status;
                                    if (mounted) {
                                      setState(
                                        () => _permanentlyDenied = !s.isGranted,
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.settings, size: 18),
                                  label: const Text(
                                    'افتح إعدادات التطبيق',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        // The capture flash: Lottie's shutter, the moment the photo lands.
        IgnorePointer(
          child: AnimatedOpacity(
            opacity: _flash ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: _flash
                ? Lottie.asset(
                    'assets/lottie/lottie_camera_capture.json',
                    repeat: false,
                    fit: BoxFit.contain,
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

class _PantryConfirmDialog extends StatefulWidget {
  const new({required this.items});

  final List<ScannedPantryItem> items;

  @override
  State<_PantryConfirmDialog> createState() => _PantryConfirmDialogState();
}

class _PantryConfirmDialogState extends State<_PantryConfirmDialog> {
  late final List<ScannedPantryItem> _list = <ScannedPantryItem>[
    ...widget.items,
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      icon: const Text('  ', style: TextStyle(fontSize: 24)),
      title: const Text(
        'تأكيد المخزون المستخرج',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'تم استخراج المنتجات التالية. يمكنك مراجعتها قبل الحفظ:',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: <Widget>[
                    for (final item in _list) ...<Widget>[
                      _ItemTile(
                        title: item.name,
                        subtitle:
                            '${item.quantity} ${item.unit}  •  '
                            '${item.category ?? ''}',
                        onDelete: () => setState(() => _list.remove(item)),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: scheme.primary),
          onPressed: () => Navigator.of(context).pop(_list),
          icon: const Icon(Icons.check, size: 18),
          label: const Text('   حقن في المخزون'),
        ),
      ],
    );
  }
}

class _ItemTile extends StatelessWidget {
  const new({
    required this.title,
    required this.subtitle,
    required this.onDelete,
    this.trailing = const <Widget>[],
  });

  final String title;
  final String subtitle;
  final VoidCallback onDelete;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.inventory_2, size: 20, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          ...trailing,
          IconButton(
            tooltip: 'حذف',
            onPressed: onDelete,
            icon: Icon(Icons.delete, color: scheme.error),
          ),
        ],
      ),
    );
  }
}

class _MedicineConfirmDialog extends StatelessWidget {
  const new({required this.med});

  final ScannedMedicine med;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final expiry = med.expiryDate;
    return AlertDialog(
      icon: Icon(Icons.medication, size: 28, color: scheme.primary),
      title: Text(
        'مسح علبة دواء',
        style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            med.name,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (med.activeIngredient?.trim().isNotEmpty ?? false) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              med.activeIngredient!,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '${med.quantity} ${med.unit}  •  ${med.category}',
            style: text.bodySmall,
          ),
          if (med.dosage?.trim().isNotEmpty ?? false) ...<Widget>[
            const SizedBox(height: 8),
            Text(med.dosage!, style: text.bodySmall),
          ],
          if (expiry != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'تاريخ الانتهاء: ${expiry.year.toString().padLeft(4, '0')}-'
              '${expiry.month.toString().padLeft(2, '0')}-'
              '${expiry.day.toString().padLeft(2, '0')}',
              style: text.labelSmall?.copyWith(
                color: context.zadExt.textTertiary,
              ),
            ),
          ],
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('إلغاء'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.check, size: 18),
          label: const Text('   حفظ في الصيدلية'),
        ),
      ],
    );
  }
}

class _ReceiptConfirmDialog extends StatefulWidget {
  const new({required this.receipt, required this.money});

  final ScannedReceipt receipt;
  final String Function(double) money;

  @override
  State<_ReceiptConfirmDialog> createState() => _ReceiptConfirmDialogState();
}

class _ReceiptConfirmDialogState extends State<_ReceiptConfirmDialog> {
  late ReceiptType _type = widget.receipt.type;
  late final List<ScannedReceiptItem> _items = <ScannedReceiptItem>[
    ...widget.receipt.items,
  ];

  ScannedReceiptItem _withQty(ScannedReceiptItem i, double q) =>
      ScannedReceiptItem(
        name: i.name,
        price: i.price,
        quantity: q,
        unit: i.unit,
        category: i.category,
      );

  @override
  Widget build(BuildContext context) {
    final r = widget.receipt;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return AlertDialog(
      icon: const Icon(Icons.receipt),
      title: const Text(
        'تأكيد الفاتورة المستخرجة',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '${r.storeName}  •  ${widget.money(r.total)}',
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'راجع المنتجات قبل التسجيل في المصروفات والمخزون:',
              style: text.bodySmall,
            ),
            const SizedBox(height: 12),
            Text(
              'نوع الفاتورة (زاد صنّفها تلقائياً، وتقدر تغيّرها):',
              style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: <Widget>[
                for (final (value, label) in _receiptTypes)
                  FilterChip(
                    selected: _type == value,
                    onSelected: (_) => setState(() => _type = value),
                    label: Text(label, style: text.labelSmall),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: <Widget>[
                    for (var idx = 0; idx < _items.length; idx++) ...<Widget>[
                      _ItemTile(
                        title: _items[idx].name,
                        subtitle:
                            '${_items[idx].unit}  •  '
                            '${widget.money(_items[idx].price)}',
                        onDelete: () => setState(() => _items.removeAt(idx)),
                        trailing: <Widget>[
                          SizedBox.square(
                            dimension: 32,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              tooltip: 'إنقاص الكمية',
                              onPressed: () => setState(() {
                                final q = _items[idx].quantity - 1;
                                _items[idx] = _withQty(
                                  _items[idx],
                                  q < 1 ? 1 : q,
                                );
                              }),
                              icon: const Icon(Icons.remove, size: 18),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              '${_items[idx].quantity.toInt()}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox.square(
                            dimension: 32,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              tooltip: 'زيادة الكمية',
                              onPressed: () => setState(() {
                                _items[idx] = _withQty(
                                  _items[idx],
                                  _items[idx].quantity + 1,
                                );
                              }),
                              icon: const Icon(Icons.add, size: 18),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton.icon(
          onPressed: () =>
              Navigator.of(context).pop(r.copyWith(type: _type, items: _items)),
          icon: const Icon(Icons.check, size: 18),
          label: const Text('   تسجيل الفاتورة'),
        ),
      ],
    );
  }
}

class _ManualRow {
  String name = '';
  int quantity = 1;
  String unit = 'قطعة';
  String category = 'عام';
}

class _ManualInventoryDialog extends StatefulWidget {
  const new();

  @override
  State<_ManualInventoryDialog> createState() => _ManualInventoryDialogState();
}

class _ManualInventoryDialogState extends State<_ManualInventoryDialog> {
  final List<_ManualRow> _rows = <_ManualRow>[_ManualRow()];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final valid = _rows.where((r) => r.name.trim().isNotEmpty).toList();
    return AlertDialog(
      icon: const Text('  ', style: TextStyle(fontSize: 24)),
      title: const Text(
        'إضافة منتجات يدوياً',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: <Widget>[
                    for (var idx = 0; idx < _rows.length; idx++) ...<Widget>[
                      _row(idx, scheme),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _rows.add(_ManualRow())),
              icon: const Icon(Icons.add),
              label: const Text('   إضافة منتج آخر'),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton.icon(
          onPressed: valid.isEmpty
              ? null
              : () => Navigator.of(context).pop(<IntakeLine>[
                  for (final r in valid)
                    IntakeLine(
                      name: r.name.trim(),
                      quantity: r.quantity < 1 ? 1 : r.quantity,
                      unit: r.unit,
                      category: r.category,
                    ),
                ]),
          icon: const Icon(Icons.check, size: 18),
          label: Text('حفظ (${valid.length})'),
        ),
      ],
    );
  }

  Widget _row(int idx, ColorScheme scheme) {
    final row = _rows[idx];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              SizedBox(
                width: 24,
                child: Text(
                  '${idx + 1}.',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: TextFormField(
                  initialValue: row.name,
                  decoration: const InputDecoration(
                    labelText: 'اسم المنتج',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => row.name = v),
                ),
              ),
              if (_rows.length > 1)
                IconButton(
                  tooltip: 'حذف',
                  onPressed: () => setState(() => _rows.removeAt(idx)),
                  icon: Icon(Icons.close, color: scheme.error),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              SizedBox(
                width: 80,
                child: TextFormField(
                  initialValue: '${row.quantity}',
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'الكمية',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => row.quantity = int.tryParse(v) ?? 0,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                child: DropdownButtonFormField<String>(
                  initialValue: row.unit,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'الوحدة',
                    border: OutlineInputBorder(),
                  ),
                  items: <DropdownMenuItem<String>>[
                    for (final u in _units)
                      DropdownMenuItem<String>(value: u, child: Text(u)),
                  ],
                  onChanged: (u) => row.unit = u ?? row.unit,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: row.category,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'التصنيف',
                    border: OutlineInputBorder(),
                  ),
                  items: <DropdownMenuItem<String>>[
                    for (final c in _manualCategories)
                      DropdownMenuItem<String>(value: c, child: Text(c)),
                  ],
                  onChanged: (c) => row.category = c ?? row.category,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
