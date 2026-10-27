import 'package:flutter/material.dart';

/// A text field for an output name. It shows the custom [value] or, without one, the
/// [defaultName], so the default can be edited instead of retyped. It reports when editing
/// ends (Enter or focus loss), so a name becomes one undo step instead of one per
/// keystroke; text equal to the default, or blank, reports '' (no custom name). Follows
/// [value] when it changes from outside (undo).
class NameField extends StatefulWidget {
  const NameField({
    super.key,
    required this.value,
    required this.defaultName,
    required this.onCommit,
    this.label,
    this.error,
  });

  final String? value;
  final String defaultName;
  final String? label;
  final String? error;
  final ValueChanged<String> onCommit;

  @override
  State<NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<NameField> {
  late final _controller = TextEditingController(text: _shown);
  final _focus = FocusNode();

  String get _shown => widget.value ?? widget.defaultName;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(NameField old) {
    super.didUpdateWidget(old);
    final v = _shown;
    if (!_focus.hasFocus && _controller.text != v) _controller.text = v;
  }

  void _commit() {
    final text = _controller.text;
    final custom = text.trim().isEmpty || text == widget.defaultName ? null : text;
    if (custom != widget.value) widget.onCommit(custom ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _controller,
        focusNode: _focus,
        decoration: InputDecoration(
          isDense: true,
          hintText: widget.defaultName,
          labelText: widget.label,
          errorText: widget.error,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (_) => _commit(),
      );
}
