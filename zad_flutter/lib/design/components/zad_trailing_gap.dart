/// A gap under a block that may render nothing.
///
/// Kotlin writes `if (shown) { Card(); Spacer(16.dp) }`, so a hidden card
/// takes its spacer with it. Several Flutter slots decide inside themselves
/// whether to draw anything, which leaves the caller unable to tell — this
/// adds `gap` under `child` only when the child actually has height.
library;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// [child], then [gap] — or nothing at all when [child] is empty.
class ZadTrailingGap extends SingleChildRenderObjectWidget {
  /// Adds [gap] under [child] when it draws something.
  const new({required this.gap, required Widget super.child, super.key});

  /// The space under a non-empty child.
  final double gap;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderTrailingGap(gap);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      (renderObject as _RenderTrailingGap).gap = gap;
}

class _RenderTrailingGap extends RenderProxyBox {
  new(this._gap);

  double _gap;

  double get gap => _gap;

  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final c = child;
    if (c == null) {
      size = constraints.smallest;
      return;
    }
    c.layout(
      constraints.copyWith(
        minHeight: 0,
        maxHeight: constraints.maxHeight.isFinite
            ? (constraints.maxHeight - _gap).clamp(0, double.infinity)
            : double.infinity,
      ),
      parentUsesSize: true,
    );
    final h = c.size.height;
    size = constraints.constrain(Size(c.size.width, h == 0 ? 0 : h + _gap));
  }
}
