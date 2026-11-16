// Why: generated data, split at spaces so lines stay short.
// ignore_for_file: missing_whitespace_between_adjacent_strings
/// Product drawings, SVG body in the 64x64 box.
/// Generated from the owner-approved art kit (docs/agent/previews/
/// all_pages_2026_11_15/art.js); `{name}` is a ZadArtColors token.
library;

import 'package:zad/shared/worlds/art/zad_art_kinds.dart';

/// The product drawings by kind.
const Map<ZadProductArt, String> zadProductSvg = <ZadProductArt, String>{
  ZadProductArt.milk:
      '<defs>'
      '<linearGradient id="g1" x1="0" y1="0" x2="1" y2="1">'
      '<stop offset="0%" stop-color="#FFFFFF"/>'
      '<stop offset="100%" stop-color="#DDE7EF"/>'
      '</linearGradient>'
      '</defs>'
      '<ellipse cx="32" cy="60" rx="18" ry="3" fill="#000" opacity=".1"/>'
      '<path d="M20 18 L26 8 H38 L44 18 V56 a3 3 0 0 1 -3 3 H23 a3 3 0 0 '
      '1 -3 -3Z" fill="url(#g1)" stroke="#C9D6E2"/>'
      '<path d="M20 30 H44 V44 H20Z" fill="{blue}"/>'
      '<path d="M26 8 H38 L36 4 H28Z" fill="{blue}"/>'
      '<text x="32" y="41" text-anchor="middle" font-size="8" '
      'font-weight="900" fill="#fff" font-family="Cairo">حليب</text>'
      '<rect x="23" y="20" width="3" height="30" rx="1.5" fill="#fff" '
      'opacity=".45"/>',
  ZadProductArt.rice:
      '<defs>'
      '<linearGradient id="g1" x1="0" y1="0" x2="1" y2="1">'
      '<stop offset="0%" stop-color="#FFF6DD"/>'
      '<stop offset="100%" stop-color="#EBD39A"/>'
      '</linearGradient>'
      '</defs>'
      '<ellipse cx="32" cy="60" rx="18" ry="3" fill="#000" opacity=".1"/>'
      '<path d="M16 16 Q32 10 48 16 L50 54 Q32 60 14 54Z" '
      'fill="url(#g1)" stroke="#D8BD7A"/>'
      '<path d="M16 16 Q32 22 48 16" fill="none" stroke="{ochre}" '
      'stroke-width="2.5"/>'
      '<rect x="21" y="28" width="22" height="14" rx="4" fill="{ochre}"/>'
      '<text x="32" y="38" text-anchor="middle" font-size="7.5" '
      'font-weight="900" fill="#fff" font-family="Cairo">بسمتي</text>'
      '<ellipse cx="22" cy="49" rx="1.6" ry="3" fill="#fff" '
      'transform="rotate(0 22 49)"/>'
      '<ellipse cx="27" cy="49" rx="1.6" ry="3" fill="#fff" '
      'transform="rotate(25 27 49)"/>'
      '<ellipse cx="32" cy="49" rx="1.6" ry="3" fill="#fff" '
      'transform="rotate(50 32 49)"/>'
      '<ellipse cx="37" cy="49" rx="1.6" ry="3" fill="#fff" '
      'transform="rotate(75 37 49)"/>'
      '<ellipse cx="42" cy="49" rx="1.6" ry="3" fill="#fff" '
      'transform="rotate(100 42 49)"/>',
  ZadProductArt.eggs:
      '<ellipse cx="32" cy="60" rx="18" ry="3" fill="#000" opacity=".1"/>'
      '<rect x="10" y="34" width="44" height="20" rx="6" fill="#D8C3A2"/>'
      '<ellipse cx="18" cy="32" rx="6" ry="8" fill="#F1DCC0" '
      'stroke="{shell}"/>'
      '<ellipse cx="28" cy="30" rx="6" ry="8" fill="#FFF3E2" '
      'stroke="{shell}"/>'
      '<ellipse cx="38" cy="32" rx="6" ry="8" fill="#F1DCC0" '
      'stroke="{shell}"/>'
      '<ellipse cx="48" cy="30" rx="6" ry="8" fill="#FFF3E2" '
      'stroke="{shell}"/>'
      '<path d="M10 42 H54" stroke="#C5AE8B" stroke-width="1.5"/>',
  ZadProductArt.tomato:
      '<ellipse cx="32" cy="60" rx="18" ry="3" fill="#000" opacity=".1"/>'
      '<circle cx="32" cy="38" r="18" fill="{tomato}"/>'
      '<ellipse cx="25" cy="31" rx="5" ry="3" fill="#fff" opacity=".4"/>'
      '<path d="M32 20 l-6 -4 4 5 -8 1 8 2 -2 6 4 -5 4 5 -2 -6 8 -2 -8 '
      '-1 4 -5Z" fill="{herb}"/>',
  ZadProductArt.bread:
      '<defs>'
      '<linearGradient id="g1" x1="0" y1="0" x2="1" y2="1">'
      '<stop offset="0%" stop-color="{crust}"/>'
      '<stop offset="100%" stop-color="{wood}"/>'
      '</linearGradient>'
      '</defs>'
      '<ellipse cx="32" cy="60" rx="18" ry="3" fill="#000" opacity=".1"/>'
      '<path d="M10 40 Q10 22 32 22 Q54 22 54 40 V52 H10Z" '
      'fill="url(#g1)"/>'
      '<path d="M20 28 q4 6 0 12" stroke="{brown}" stroke-width="2" '
      'fill="none" stroke-linecap="round"/>'
      '<path d="M30 28 q4 6 0 12" stroke="{brown}" stroke-width="2" '
      'fill="none" stroke-linecap="round"/>'
      '<path d="M40 28 q4 6 0 12" stroke="{brown}" stroke-width="2" '
      'fill="none" stroke-linecap="round"/>'
      '<ellipse cx="22" cy="28" rx="6" ry="2.5" fill="#fff" '
      'opacity=".35"/>',
  ZadProductArt.coffee:
      '<ellipse cx="32" cy="60" rx="18" ry="3" fill="#000" opacity=".1"/>'
      '<path d="M16 24 H44 L41 54 a4 4 0 0 1 -4 3 H23 a4 4 0 0 1 -4 -3Z" '
      'fill="#fff" stroke="{plate}"/>'
      '<path d="M17 32 H43 L42 42 H18Z" fill="#A0522D"/>'
      '<rect x="14" y="18" width="32" height="7" rx="3" fill="#5B3416"/>'
      '<path d="M26 12 q-3 -4 0 -8 M33 12 q-3 -4 0 -8" stroke="#C9CFC9" '
      'stroke-width="2" fill="none" stroke-linecap="round"/>',
  ZadProductArt.oil:
      '<defs>'
      '<linearGradient id="g1" x1="0" y1="0" x2="1" y2="1">'
      '<stop offset="0%" stop-color="#E8D36A"/>'
      '<stop offset="100%" stop-color="#B39B1F"/>'
      '</linearGradient>'
      '</defs>'
      '<ellipse cx="32" cy="60" rx="18" ry="3" fill="#000" opacity=".1"/>'
      '<rect x="27" y="4" width="10" height="8" rx="2" fill="{herb}"/>'
      '<path d="M26 12 H38 L42 22 V54 a4 4 0 0 1 -4 4 H26 a4 4 0 0 1 -4 '
      '-4 V22Z" fill="url(#g1)" opacity=".92"/>'
      '<rect x="24" y="30" width="16" height="14" rx="3" fill="#fff"/>'
      '<circle cx="32" cy="37" r="4" fill="{herb}"/>'
      '<rect x="25" y="24" width="3" height="26" rx="1.5" fill="#fff" '
      'opacity=".45"/>',
  ZadProductArt.detergent:
      '<defs>'
      '<linearGradient id="g1" x1="0" y1="0" x2="1" y2="1">'
      '<stop offset="0%" stop-color="{sky}"/>'
      '<stop offset="100%" stop-color="#2F6BC0"/>'
      '</linearGradient>'
      '</defs>'
      '<ellipse cx="32" cy="60" rx="18" ry="3" fill="#000" opacity=".1"/>'
      '<path d="M18 14 H40 L46 22 V54 a4 4 0 0 1 -4 4 H20 a4 4 0 0 1 -4 '
      '-4 V22Z" fill="url(#g1)"/>'
      '<rect x="22" y="8" width="12" height="7" rx="2" fill="{amber}"/>'
      '<circle cx="31" cy="38" r="9" fill="#fff"/>'
      '<circle cx="31" cy="38" r="5" fill="{mint}"/>'
      '<rect x="19" y="22" width="3" height="26" rx="1.5" fill="#fff" '
      'opacity=".45"/>'
      '<path d="M40 16 a8 8 0 0 1 6 12" stroke="#2F6BC0" '
      'stroke-width="3" fill="none"/>',
  ZadProductArt.tissue:
      '<ellipse cx="32" cy="60" rx="18" ry="3" fill="#000" opacity=".1"/>'
      '<rect x="10" y="28" width="44" height="26" rx="5" fill="{pink}"/>'
      '<ellipse cx="32" cy="30" rx="10" ry="3" fill="{berry}"/>'
      '<path d="M26 30 Q28 14 34 18 Q40 22 38 30" fill="#fff" '
      'stroke="#E7E7E7"/>'
      '<path d="M14 46 H50" stroke="#fff" stroke-width="2" opacity=".6"/>',
  ZadProductArt.shampoo:
      '<defs>'
      '<linearGradient id="g1" x1="0" y1="0" x2="1" y2="1">'
      '<stop offset="0%" stop-color="{lilac}"/>'
      '<stop offset="100%" stop-color="#7B62D6"/>'
      '</linearGradient>'
      '</defs>'
      '<ellipse cx="32" cy="60" rx="18" ry="3" fill="#000" opacity=".1"/>'
      '<rect x="26" y="6" width="12" height="10" rx="3" fill="#4A3F94"/>'
      '<rect x="20" y="16" width="24" height="42" rx="9" '
      'fill="url(#g1)"/>'
      '<rect x="24" y="30" width="16" height="12" rx="3" fill="#fff" '
      'opacity=".9"/>'
      '<rect x="23" y="20" width="3" height="30" rx="1.5" fill="#fff" '
      'opacity=".45"/>',
  ZadProductArt.chickpeas:
      '<ellipse cx="32" cy="60" rx="18" ry="3" fill="#000" opacity=".1"/>'
      '<rect x="18" y="14" width="28" height="42" rx="6" fill="#D9A441"/>'
      '<rect x="18" y="14" width="28" height="7" rx="3" fill="{grey}"/>'
      '<rect x="18" y="49" width="28" height="7" rx="3" fill="{grey}"/>'
      '<circle cx="32" cy="35" r="9" fill="#FFF3D6"/>'
      '<circle cx="29" cy="33" r="2.4" fill="{sand}"/>'
      '<circle cx="34" cy="33" r="2.4" fill="{sand}"/>'
      '<circle cx="31" cy="38" r="2.4" fill="{sand}"/>',
  ZadProductArt.vinegar:
      '<ellipse cx="32" cy="60" rx="18" ry="3" fill="#000" opacity=".1"/>'
      '<rect x="28" y="4" width="8" height="10" rx="2" fill="{tomato}"/>'
      '<path d="M27 14 H37 V22 Q44 26 44 34 V54 a4 4 0 0 1 -4 4 H24 a4 4 '
      '0 0 1 -4 -4 V34 Q20 26 27 22Z" fill="#EAF6FB" stroke="#BFD9E5"/>'
      '<rect x="22" y="36" width="20" height="10" rx="3" '
      'fill="{emerald}"/>'
      '<rect x="23" y="30" width="3" height="20" rx="1.5" fill="#fff" '
      'opacity=".45"/>',
  ZadProductArt.medicine:
      '<ellipse cx="32" cy="60" rx="18" ry="3" fill="#000" opacity=".1"/>'
      '<rect x="12" y="20" width="40" height="34" rx="6" fill="#fff" '
      'stroke="#D9D3F5"/>'
      '<rect x="12" y="20" width="40" height="10" rx="5" fill="#6B5FC7"/>'
      '<rect x="28" y="34" width="8" height="16" rx="2" fill="#D95726"/>'
      '<rect x="24" y="38" width="16" height="8" rx="2" fill="#D95726"/>',
  ZadProductArt.blender:
      '<defs>'
      '<linearGradient id="g1" x1="0" y1="0" x2="1" y2="1">'
      '<stop offset="0%" stop-color="#E6F4FF"/>'
      '<stop offset="100%" stop-color="#A9CDEB"/>'
      '</linearGradient>'
      '</defs>'
      '<ellipse cx="32" cy="60" rx="18" ry="3" fill="#000" opacity=".1"/>'
      '<path d="M20 10 H44 L40 40 H24Z" fill="url(#g1)" '
      'stroke="#8FB8D9"/>'
      '<rect x="18" y="6" width="28" height="6" rx="3" fill="{slate}"/>'
      '<rect x="20" y="40" width="24" height="16" rx="5" fill="{slate}"/>'
      '<circle cx="32" cy="48" r="3" fill="{mint}"/>'
      '<rect x="23" y="14" width="3" height="20" rx="1.5" fill="#fff" '
      'opacity=".45"/>',
  ZadProductArt.airfryer:
      '<ellipse cx="32" cy="60" rx="18" ry="3" fill="#000" opacity=".1"/>'
      '<rect x="12" y="12" width="40" height="44" rx="14" '
      'fill="#1F2A2E"/>'
      '<rect x="18" y="32" width="28" height="18" rx="6" fill="#2E3B40"/>'
      '<rect x="26" y="40" width="12" height="4" rx="2" fill="{mint}"/>'
      '<circle cx="32" cy="22" r="5" fill="{amber}"/>'
      '<ellipse cx="22" cy="18" rx="5" ry="2" fill="#fff" opacity=".25"/>',
  ZadProductArt.koshari:
      '<ellipse cx="32" cy="60" rx="18" ry="3" fill="#000" opacity=".1"/>'
      '<ellipse cx="32" cy="44" rx="26" ry="10" fill="#fff" '
      'stroke="{plate}"/>'
      '<path d="M10 42 Q32 18 54 42Z" fill="{ochre}"/>'
      '<path d="M14 40 Q32 24 50 40" fill="{tomato}" opacity=".85"/>'
      '<circle cx="24" cy="32" r="2.6" fill="{brown}"/>'
      '<circle cx="32" cy="28" r="2.6" fill="{brown}"/>'
      '<circle cx="40" cy="32" r="2.6" fill="{brown}"/>'
      '<circle cx="28" cy="36" r="2.6" fill="{brown}"/>'
      '<circle cx="37" cy="36" r="2.6" fill="{brown}"/>'
      '<path d="M22 30 q4 -4 8 0 q4 -4 8 0" stroke="{crust}" '
      'stroke-width="2.5" fill="none"/>',
  ZadProductArt.chicken:
      '<ellipse cx="32" cy="60" rx="18" ry="3" fill="#000" opacity=".1"/>'
      '<ellipse cx="32" cy="46" rx="26" ry="9" fill="#fff" '
      'stroke="{plate}"/>'
      '<path d="M18 40 c-4 -14 12 -24 22 -16 c8 6 6 16 -2 18Z" '
      'fill="#D9853B"/>'
      '<ellipse cx="28" cy="30" rx="6" ry="3" fill="#fff" opacity=".35"/>'
      '<rect x="38" y="38" width="12" height="5" rx="2.5" '
      'fill="{crust}"/>'
      '<circle cx="46" cy="44" r="4" fill="{butter}"/>'
      '<circle cx="16" cy="44" r="4" fill="{butter}"/>',
  ZadProductArt.fish:
      '<ellipse cx="32" cy="60" rx="18" ry="3" fill="#000" opacity=".1"/>'
      '<ellipse cx="32" cy="46" rx="26" ry="9" fill="#fff" '
      'stroke="{plate}"/>'
      '<path d="M12 36 Q30 20 46 36 Q30 50 12 36Z" fill="{sky}"/>'
      '<path d="M46 36 L56 28 V44Z" fill="{steel}"/>'
      '<circle cx="20" cy="34" r="2.5" fill="{ink}"/>'
      '<path d="M26 30 v12" stroke="{steel}" stroke-width="2"/>'
      '<path d="M32 30 v12" stroke="{steel}" stroke-width="2"/>'
      '<path d="M38 30 v12" stroke="{steel}" stroke-width="2"/>'
      '<circle cx="50" cy="48" r="3" fill="{butter}"/>',
  ZadProductArt.salad:
      '<ellipse cx="32" cy="60" rx="18" ry="3" fill="#000" opacity=".1"/>'
      '<path d="M8 34 H56 a24 18 0 0 1 -48 0Z" fill="#fff" '
      'stroke="{plate}"/>'
      '<circle cx="20" cy="32" r="7" fill="{leaf}"/>'
      '<circle cx="32" cy="28" r="8" fill="#8BC34A"/>'
      '<circle cx="44" cy="32" r="7" fill="{leaf}"/>'
      '<circle cx="26" cy="34" r="4" fill="{tomato}"/>'
      '<circle cx="40" cy="30" r="3.5" fill="#F2B91E"/>',
  ZadProductArt.pasta:
      '<ellipse cx="32" cy="60" rx="18" ry="3" fill="#000" opacity=".1"/>'
      '<ellipse cx="32" cy="44" rx="26" ry="10" fill="#fff" '
      'stroke="{plate}"/>'
      '<path d="M14 40 q4 -10 8 0 q4 10 8 0" stroke="{crust}" '
      'stroke-width="3" fill="none"/>'
      '<path d="M21 40 q4 -10 8 0 q4 10 8 0" stroke="{crust}" '
      'stroke-width="3" fill="none"/>'
      '<path d="M28 40 q4 -10 8 0 q4 10 8 0" stroke="{crust}" '
      'stroke-width="3" fill="none"/>'
      '<path d="M35 40 q4 -10 8 0 q4 10 8 0" stroke="{crust}" '
      'stroke-width="3" fill="none"/>'
      '<path d="M42 40 q4 -10 8 0 q4 10 8 0" stroke="{crust}" '
      'stroke-width="3" fill="none"/>'
      '<circle cx="32" cy="34" r="8" fill="{tomato}"/>'
      '<circle cx="29" cy="31" r="2" fill="#fff" opacity=".5"/>',
  ZadProductArt.ball:
      '<circle cx="32" cy="32" r="24" fill="#fff" stroke="{ink}" '
      'stroke-width="2"/>'
      '<path d="M32 18 l10 7 -4 12 h-12 l-4 -12z" fill="{ink}"/>'
      '<path d="M32 8 v10 M42 25 l12 -4 M38 37 l8 10 M26 37 l-8 10 M22 '
      '25 l-12 -4" stroke="{ink}" stroke-width="2"/>',
  ZadProductArt.box:
      '<ellipse cx="32" cy="60" rx="18" ry="3" fill="#000" opacity=".1"/>'
      '<rect x="10" y="22" width="44" height="34" rx="5" fill="{tint}"/>'
      '<rect x="8" y="14" width="48" height="12" rx="4" fill="{tint}"/>'
      '<rect x="8" y="14" width="48" height="12" rx="4" fill="#000" '
      'opacity=".12"/>'
      '<rect x="27" y="14" width="10" height="12" rx="2" fill="#fff" '
      'opacity=".5"/>'
      '<rect x="14" y="30" width="3" height="20" rx="1.5" fill="#fff" '
      'opacity=".45"/>',
};
