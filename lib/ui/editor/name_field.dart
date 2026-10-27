import 'package:flutter/material.dart';

/// A text field that reports its value when editing ends (Enter or focus loss), so a
/// name becomes one undo step instead of one per keystroke. Follows [value] when it
/// changes from outside (undo).
class NameField extends StatefulWidget {
  const NameField({super.key, required this.value, required this.hint, required this.onCommit, this.label, this.error});

  final String? value;
  final String hint;
  final String? label;
  final String? error;
  final ValueChanged<String> onCommit;

  @override
  State<NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<NameField> {
  late final _controller = TextEditingController(text: widget.value ?? '');
  final _focus = FocusNode();

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
    final v = widget.value ?? '';
    if (!_focus.hasFocus && _controller.text != v) _controller.text = v;
  }

  void _commit() {
    if (_controller.text != (widget.value ?? '')) widget.onCommit(_controller.text);
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
          hintText: widget.hint,
          labelText: widget.label,
          errorText: widget.error,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (_) => _commit(),
      );
}
