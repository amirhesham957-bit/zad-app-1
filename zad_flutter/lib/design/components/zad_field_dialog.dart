/// A dialog whose text fields own their controllers.
///
/// `showDialog` completes the moment the route is popped, but the dialog is
/// still on screen for its exit transition, its `TextField`s still attached.
/// Disposing their controllers right after the `await` — what several dialogs
/// did — kills them mid-animation: on a debug build the whole screen turns
/// red with `'_dependents.isEmpty': is not true` (seen on the kids' purchase
/// request). Here the controllers belong to a `State` that the route removes
/// only once the transition is over.
library;

import 'package:flutter/material.dart';

/// Shows [builder]'s dialog with one controller per entry of [initial],
/// each starting with that text. Read the fields inside the dialog and pop
/// the values out; the controllers are gone once it has closed.
Future<T?> showFieldDialog<T>({
  required BuildContext context,
  required List<String> initial,
  required Widget Function(
    BuildContext context,
    List<TextEditingController> fields,
  )
  builder,
}) => showDialog<T>(
  context: context,
  builder: (_) => _FieldOwner(initial: initial, builder: builder),
);

class _FieldOwner extends StatefulWidget {
  const new({required this.initial, required this.builder});

  final List<String> initial;
  final Widget Function(BuildContext, List<TextEditingController>) builder;

  @override
  State<_FieldOwner> createState() => _FieldOwnerState();
}

class _FieldOwnerState extends State<_FieldOwner> {
  late final List<TextEditingController> _fields = <TextEditingController>[
    for (final text in widget.initial) TextEditingController(text: text),
  ];

  @override
  void dispose() {
    for (final f in _fields) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _fields);
}
