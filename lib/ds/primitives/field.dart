import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/ds/tokens.dart';

/// Labelled text field: label above, white box, 1px ink border (2px plum when
/// focused). [mono] is for numbers; [ltr] keeps phones, URLs and handles
/// readable inside an Arabic screen.
class DsField extends StatelessWidget {
  const DsField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.keyboardType,
    this.mono = false,
    this.ltr = false,
    this.maxLines = 1,
    this.onChanged,
    this.suffix,
    this.enabled = true,
    this.inputFormatters,
    this.helper,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final TextInputType? keyboardType;
  final bool mono;
  final bool ltr;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final String? suffix;
  final bool enabled;
  final List<TextInputFormatter>? inputFormatters;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder b(Color c, double w) => OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: c, width: w));
    final field = TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChanged,
      inputFormatters: inputFormatters,
      textDirection: ltr ? TextDirection.ltr : null,
      style: mono ? TextStyle(fontFamily: T.mono, fontSize: 15, fontWeight: FontWeight.w500, color: Ds.ink) : const TextStyle(fontSize: 15, color: Ds.ink),
      cursorColor: Ds.plum,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: enabled ? Ds.white : Ds.surface,
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 14, color: Ds.textFaint),
        suffixText: suffix,
        suffixStyle: DsText.meta,
        contentPadding: const EdgeInsets.symmetric(horizontal: Ds.s3, vertical: 14),
        enabledBorder: b(Ds.ink, Ds.rule),
        disabledBorder: b(Ds.divider, Ds.rule),
        focusedBorder: b(Ds.plum, 2),
        border: b(Ds.ink, Ds.rule),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(label, style: DsText.meta.copyWith(fontWeight: FontWeight.w600))),
        field,
        if (helper != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(helper!, style: DsText.hint)),
      ],
    );
  }
}
