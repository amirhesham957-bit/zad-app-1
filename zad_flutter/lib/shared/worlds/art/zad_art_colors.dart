/// The colours the art kit repeats, once. One-off colours stay in the
/// drawing they belong to (they are part of that picture, not of the app).
library;

import 'package:flutter/painting.dart';

/// Art palette tokens.
abstract final class ZadArtColors {
  /// #374151.
  static const Color slate = Color(0xFF374151);

  /// #F5B93A.
  static const Color amber = Color(0xFFF5B93A);

  /// #C68216.
  static const Color ochre = Color(0xFFC68216);

  /// #8A5A2B.
  static const Color brown = Color(0xFF8A5A2B);

  /// #45BF68.
  static const Color leaf = Color(0xFF45BF68);

  /// #E5473C.
  static const Color tomato = Color(0xFFE5473C);

  /// #6EE7B7.
  static const Color mint = Color(0xFF6EE7B7);

  /// #F2C27B.
  static const Color crust = Color(0xFFF2C27B);

  /// #0F9B76.
  static const Color emerald = Color(0xFF0F9B76);

  /// #7CB7FF.
  static const Color sky = Color(0xFF7CB7FF);

  /// #2F7BD8.
  static const Color blue = Color(0xFF2F7BD8);

  /// #E3DED4.
  static const Color plate = Color(0xFFE3DED4);

  /// #C2416B.
  static const Color berry = Color(0xFFC2416B);

  /// #5A8FD0.
  static const Color steel = Color(0xFF5A8FD0);

  /// #1F1F14.
  static const Color ink = Color(0xFF1F1F14);

  /// #E2CBA8.
  static const Color shell = Color(0xFFE2CBA8);

  /// #F28AAE.
  static const Color pink = Color(0xFFF28AAE);

  /// #1B3B6B.
  static const Color navy = Color(0xFF1B3B6B);

  /// #CFE3D8.
  static const Color sage = Color(0xFFCFE3D8);

  /// #1B4332.
  static const Color forest = Color(0xFF1B4332);

  /// #FFF4DE.
  static const Color cream = Color(0xFFFFF4DE);

  /// #F2416B.
  static const Color rose = Color(0xFFF2416B);

  /// #3CA06E.
  static const Color herb = Color(0xFF3CA06E);

  /// #B9762F.
  static const Color wood = Color(0xFFB9762F);

  /// #C9B8FF.
  static const Color lilac = Color(0xFFC9B8FF);

  /// #9AA0A6.
  static const Color grey = Color(0xFF9AA0A6);

  /// #E2B866.
  static const Color sand = Color(0xFFE2B866);

  /// #F5D46A.
  static const Color butter = Color(0xFFF5D46A);

  /// #0B6B4E.
  static const Color pine = Color(0xFF0B6B4E);

  /// #E8B4A6.
  static const Color blush = Color(0xFFE8B4A6);

  /// Token name (as written `{name}` in a drawing) to colour.
  static const Map<String, Color> named = <String, Color>{
    'slate': slate,
    'amber': amber,
    'ochre': ochre,
    'brown': brown,
    'leaf': leaf,
    'tomato': tomato,
    'mint': mint,
    'crust': crust,
    'emerald': emerald,
    'sky': sky,
    'blue': blue,
    'plate': plate,
    'berry': berry,
    'steel': steel,
    'ink': ink,
    'shell': shell,
    'pink': pink,
    'navy': navy,
    'sage': sage,
    'forest': forest,
    'cream': cream,
    'rose': rose,
    'herb': herb,
    'wood': wood,
    'lilac': lilac,
    'grey': grey,
    'sand': sand,
    'butter': butter,
    'pine': pine,
    'blush': blush,
  };
}
