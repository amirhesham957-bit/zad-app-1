/// The terms, as a bottom sheet: seven plain points and the way to the whole
/// text, instead of a wall of English in a dialog. The legal text itself is
/// `terms_content.dart`, still there word for word behind the last expansion.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_spacing.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/auth/presentation/legal_text_expansion.dart';
import 'package:zad/features/auth/presentation/terms_content.dart';
import 'package:zad/shared/companion/domain/companion_catalog.dart';
import 'package:zad/shared/orb/domain/orb_occasion.dart';
import 'package:zad/shared/orb/presentation/companion_orb.dart';

/// Opens a web page; false when it could not be opened.
typedef UrlOpener = Future<bool> Function(Uri url);

Future<bool> _inAppBrowser(Uri url) =>
    launchUrl(url, mode: LaunchMode.inAppBrowserView);

/// Asks for the customer's agreement: true to accept, false to decline, null
/// when the sheet was dismissed. [openUrl] is how the two policy links open
/// (the in-app browser unless a test hands another).
Future<bool?> showConsentSheet(BuildContext context, {UrlOpener? openUrl}) =>
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      builder: (_) => _ConsentSheet(openUrl: openUrl ?? _inAppBrowser),
    );

class _Point {
  const new(this.icon, this.ink, this.tint, this.lead, this.body);

  final IconData icon;
  final Color ink;
  final Color tint;
  final String lead;
  final String body;
}

class _ConsentSheet extends StatelessWidget {
  const new({required this.openUrl});

  final UrlOpener openUrl;

  Future<void> _open(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await openUrl(Uri.parse(url));
    } on Object {
      opened = false;
    }
    if (opened) return;
    messenger.showSnackBar(SnackBar(content: SelectableText(url)));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final points = <_Point>[
      _Point(
        Icons.notes,
        const Color(0xFF1B4332),
        const Color(0xFFE6F4EC),
        l.consentPoint1Lead,
        l.consentPoint1Body,
      ),
      _Point(
        Icons.lock_outline,
        const Color(0xFF8A5A0B),
        const Color(0xFFFFF4DE),
        l.consentPoint2Lead,
        l.consentPoint2Body,
      ),
      _Point(
        Icons.shield_outlined,
        const Color(0xFF1B4332),
        const Color(0xFFE6F4EC),
        l.consentPoint3Lead,
        l.consentPoint3Body,
      ),
      _Point(
        Icons.auto_awesome,
        const Color(0xFF5B3FB8),
        const Color(0xFFEEE9FB),
        l.consentPoint4Lead,
        l.consentPoint4Body,
      ),
      _Point(
        Icons.desktop_windows_outlined,
        const Color(0xFFA4361A),
        const Color(0xFFFDECE8),
        l.consentPoint5Lead,
        l.consentPoint5Body,
      ),
      _Point(
        Icons.file_download_outlined,
        const Color(0xFF1B4332),
        const Color(0xFFE6F4EC),
        l.consentPoint6Lead,
        l.consentPoint6Body,
      ),
      _Point(
        Icons.person_outline,
        const Color(0xFF374151),
        const Color(0xFFF1F2EE),
        l.consentPoint7Lead,
        l.consentPoint7Body,
      ),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            ZadSpacing.lg + 2,
            0,
            ZadSpacing.lg + 2,
            ZadSpacing.sm,
          ),
          child: Row(
            children: <Widget>[
              const CompanionOrb(
                // The intro's Zado, not the classic ball (see auth_hero.dart).
                look: CompanionLook(),
                occasion: OrbOccasion.none,
                size: 72,
                animated: false,
              ),
              const SizedBox(width: ZadSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l.consentTitle,
                      style: ZadType.titleLarge.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      l.consentVersionLine(
                        // The reader's digits and month («٢٫٢ · نوفمبر ٢٠٢٦»),
                        // not «2.2 · November 2026» inside Arabic (emulator,
                        // 2026-11-15).
                        l.consentTermsVersion,
                        l.consentTermsUpdated,
                      ),
                      style: ZadType.labelMedium.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(
              horizontal: ZadSpacing.lg + 2,
              vertical: ZadSpacing.xs,
            ),
            children: <Widget>[
              for (final p in points) ...<Widget>[
                _PointRow(point: p),
                const SizedBox(height: ZadSpacing.md - 2),
              ],
              const LegalTextExpansion(),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: ZadSpacing.lg + 2),
          child: Wrap(
            spacing: ZadSpacing.md,
            children: <Widget>[
              for (final (label, url) in <(String, String)>[
                (l.consentPrivacyLink, kPrivacyPolicyUrl),
                (l.consentTermsLink, kTermsUrl),
              ])
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                  onPressed: () => unawaited(_open(context, url)),
                  child: Text(
                    label,
                    style: ZadType.bodyMedium.copyWith(
                      color: ZadColors.forestEmerald,
                      fontWeight: FontWeight.w800,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            ZadSpacing.lg + 2,
            ZadSpacing.sm,
            ZadSpacing.lg + 2,
            ZadSpacing.lg,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: ZadColors.canvasBottom,
                      foregroundColor: scheme.onSurfaceVariant,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ZadRadii.card),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(
                      l.authTermsDecline,
                      style: ZadType.titleSmall.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: ZadSpacing.md - 2),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: ZadColors.forestEmerald,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ZadRadii.card),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(
                      l.authTermsAccept,
                      style: ZadType.titleSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PointRow extends StatelessWidget {
  const new({required this.point});

  final _Point point;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: point.tint,
            borderRadius: BorderRadius.circular(ZadRadii.chip),
          ),
          child: Icon(point.icon, size: 20, color: point.ink),
        ),
        const SizedBox(width: ZadSpacing.md - 2),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: '${point.lead} ',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(text: point.body.trim()),
              ],
            ),
            style: ZadType.bodyMedium.copyWith(
              color: const Color(0xFF374151),
              height: 1.65,
            ),
          ),
        ),
      ],
    );
  }
}
