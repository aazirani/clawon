import 'package:flutter/material.dart';
import '../../utils/text_direction.dart';

/// A TextField that automatically adjusts text alignment based on content.
///
/// Uses [detectTextDirection] to determine if text should be displayed
/// right-to-left or left-to-right based on the first strong directional
/// character in the text content.
class RtlTextField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final TextStyle? style;
  final InputDecoration? decoration;
  final int? maxLines;
  final int? minLines;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool readOnly;
  final bool autofocus;
  final String? obscuringCharacter;
  final Key? textFieldKey;

  const RtlTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.style,
    this.decoration,
    this.maxLines,
    this.minLines,
    this.textInputAction,
    this.onSubmitted,
    this.enabled = true,
    this.obscureText = false,
    this.keyboardType,
    this.maxLength,
    this.onChanged,
    this.onTap,
    this.readOnly = false,
    this.autofocus = false,
    this.obscuringCharacter,
    this.textFieldKey,
  });

  @override
  State<RtlTextField> createState() => _RtlTextFieldState();
}

class _RtlTextFieldState extends State<RtlTextField> {
  TextDirection _textDirection = TextDirection.ltr;

  @override
  void initState() {
    super.initState();
    _updateTextDirection();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(RtlTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
      _updateTextDirection();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    _updateTextDirection();
  }

  void _updateTextDirection() {
    final newDirection = detectTextDirection(widget.controller.text);
    if (newDirection != _textDirection) {
      setState(() {
        _textDirection = newDirection;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: widget.textFieldKey,
      controller: widget.controller,
      focusNode: widget.focusNode,
      style: widget.style,
      decoration: widget.decoration,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      textInputAction: widget.textInputAction,
      onSubmitted: widget.onSubmitted,
      enabled: widget.enabled,
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
      maxLength: widget.maxLength,
      onChanged: widget.onChanged,
      onTap: widget.onTap,
      readOnly: widget.readOnly,
      autofocus: widget.autofocus,
      obscuringCharacter: widget.obscuringCharacter ?? '•',
      // RTL-specific properties
      textAlign: _textDirection.isRTL ? TextAlign.right : TextAlign.left,
      textDirection: _textDirection,
    );
  }
}
