/// The full English legal text behind the Arabic summary, one tap away. The
/// text is `kTermsFullText`, word for word.
library;

import 'package:flutter/material.dart';
import 'package:zad/core/design/tokens/zad_colors.dart';
import 'package:zad/core/design/tokens/zad_typography.dart';
import 'package:zad/core/l10n/l10n.dart';
import 'package:zad/features/auth/presentation/terms_content.dart';

/// «النص القانوني الكامل (بالإنجليزي)», collapsed until asked for.
class LegalTextExpansion extends StatelessWidget {
  /// Creates the expansion.
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: Text(
          context.l10n.consentLegalToggle,
          style: ZadType.bodyMedium.copyWith(
            color: ZadColors.forestEmerald,
            fontWeight: FontWeight.w800,
          ),
        ),
        children: <Widget>[
          Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                kTermsFullText,
                style: ZadType.bodySmall.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 18 / 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
