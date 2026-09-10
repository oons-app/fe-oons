import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:oons/admin/theme.dart';

String ymd(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String ymdShort(DateTime d, String lang) {
  return DateFormat('d MMM', lang == 'ar' ? 'ar' : 'en').format(d);
}

Map<String, dynamic> dateQuery(DateTime? from, DateTime? to) => {
  if (from != null) 'from': ymd(from),
  if (to != null) 'to': ymd(to),
};

class FilterWrap extends StatelessWidget {
  const FilterWrap({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: children),
        ],
      ),
    );
  }
}

class SearchField extends StatelessWidget {
  const SearchField({super.key, required this.controller, required this.hint, required this.onSubmit, this.width = 220});
  final TextEditingController controller;
  final String hint;
  final VoidCallback? onSubmit;
  final double width;

  @override
  Widget build(BuildContext context) {
    final avail = MediaQuery.sizeOf(context).width - 32;
    final w = avail > 0 && width > avail ? avail : width;
    return SizedBox(
      width: w,
      child: TextField(
        controller: controller,
        enabled: onSubmit != null,
        onSubmitted: onSubmit == null ? null : (_) => onSubmit!(),
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class DateBtn extends StatelessWidget {
  const DateBtn({super.key, required this.label, required this.value, required this.lang, required this.onChanged});
  final String label;
  final DateTime? value;
  final String lang;
  final ValueChanged<DateTime?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final text = value == null ? label : '$label ${ymdShort(value!, lang)}';
    return Opacity(
      opacity: onChanged == null ? 0.45 : 1,
      child: Material(
        color: value == null ? T.surface : T.plumTint,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onChanged == null
              ? null
              : () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: value ?? DateTime.now(),
                    firstDate: DateTime(2024, 1, 1),
                    lastDate: DateTime.now().add(const Duration(days: 400)),
                  );
                  if (picked != null) onChanged!(dayOnly(picked));
                },
          onLongPress: onChanged == null || value == null ? null : () => onChanged!(null),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: value == null ? T.lineStrong : T.plum),
            ),
            child: Text(text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: value == null ? T.body : T.plumInk)),
          ),
        ),
      ),
    );
  }
}

class FilterDrop<V> extends StatelessWidget {
  const FilterDrop({super.key, required this.value, required this.items, required this.onChanged});
  final V value;
  final List<DropdownMenuItem<V>> items;
  final ValueChanged<V?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<V>(
      value: value,
      items: items,
      onChanged: onChanged,
      underline: Container(height: 1, color: T.line),
    );
  }
}

class FilterApply extends StatelessWidget {
  const FilterApply({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: Material(
        color: T.action,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(label, style: const TextStyle(color: T.white, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ),
      ),
    );
  }
}

class FilterClear extends StatelessWidget {
  const FilterClear({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(onPressed: onTap, child: Text(label, style: const TextStyle(color: T.muted, fontWeight: FontWeight.w600)));
  }
}

class LabeledField extends StatelessWidget {
  const LabeledField({super.key, required this.label, required this.controller, required this.onSubmit, this.width = 180, this.forceLtr = false});
  final String label;
  final TextEditingController controller;
  final VoidCallback onSubmit;
  final double width;
  final bool forceLtr;

  @override
  Widget build(BuildContext context) {
    final avail = MediaQuery.sizeOf(context).width - 32;
    final w = avail > 0 && width > avail ? avail : width;
    final field = TextField(
      controller: controller,
      onSubmitted: (_) => onSubmit(),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: const OutlineInputBorder(),
      ),
    );
    return SizedBox(
      width: w,
      child: forceLtr ? Directionality(textDirection: TextDirection.ltr, child: field) : field,
    );
  }
}

class LabeledDrop<V> extends StatelessWidget {
  const LabeledDrop({super.key, required this.label, required this.value, required this.items, required this.onChanged});
  final String label;
  final V value;
  final List<DropdownMenuItem<V>> items;
  final ValueChanged<V?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: T.muted, fontWeight: FontWeight.w600)),
        FilterDrop<V>(value: value, items: items, onChanged: onChanged),
      ],
    );
  }
}
