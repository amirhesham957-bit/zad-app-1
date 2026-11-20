/// What the brain map's areas look like: one colour and one drawn icon per
/// area. The sci-fi palette is this map's own (the same exception CLAUDE.md
/// makes for Kids Mode).
library;

import 'package:flutter/painting.dart';
import 'package:zad/core/design/tokens/zad_palette.dart';
import 'package:zad/features/brain/domain/knowledge_map.dart';
import 'package:zad/shared/worlds/art/art.dart';

/// Money and plain health.
const Color kMapEmerald = ZadPalette.sciFiNeonGreen;

/// The budget and what feeds it.
const Color kMapCyan = ZadPalette.sciFiCyanElectric;

/// Things that want a look.
const Color kMapAmber = ZadPalette.sciFiAmber;

/// An area's colour.
Color mapDomainColor(MapDomain d) => switch (d.key) {
  MapDomainKey.budget || MapDomainKey.subscriptions => kMapCyan,
  MapDomainKey.obligations ||
  MapDomainKey.debts ||
  MapDomainKey.maintenance => kMapAmber,
  MapDomainKey.pharmacy when d.needsAttention => kMapAmber,
  _ => kMapEmerald,
};

/// The drawing inside an area's node.
ZadIconArt mapDomainArt(MapDomainKey key) => switch (key) {
  MapDomainKey.budget => ZadIconArt.chart,
  MapDomainKey.obligations => ZadIconArt.calendar,
  MapDomainKey.subscriptions => ZadIconArt.repeat,
  MapDomainKey.debts => ZadIconArt.receipt,
  MapDomainKey.pantry => ZadIconArt.pantry,
  MapDomainKey.shopping => ZadIconArt.cart,
  MapDomainKey.pharmacy => ZadIconArt.pill,
  MapDomainKey.maintenance => ZadIconArt.wrench,
};
