import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/features/client/client_chrome.dart';
import 'package:oons/l10n/copy.dart';

void openLegal(BuildContext context, String id) => context.push('/legal/$id');

/// Auth footer with tappable Terms and Privacy links.
class LegalFooter extends StatelessWidget {
  const LegalFooter({super.key, required this.lang});

  final String lang;

  @override
  Widget build(BuildContext context) {
    final a = Copy.of(lang)['auth'] as Map;
    final style = const TextStyle(fontSize: 11, height: 1.5, color: Client.muted);
    final link = TextStyle(fontSize: 11, height: 1.5, color: Client.plum, fontWeight: FontWeight.w700, decoration: TextDecoration.underline, decorationColor: Client.plum);
    return RichText(
      text: TextSpan(
        style: style,
        children: [
          TextSpan(text: '${a['legalPrefix']}'),
          TextSpan(text: '${a['termsLink']}', style: link, recognizer: TapGestureRecognizer()..onTap = () => openLegal(context, 'terms')),
          TextSpan(text: '${a['legalAnd']}'),
          TextSpan(text: '${a['privacyLink']}', style: link, recognizer: TapGestureRecognizer()..onTap = () => openLegal(context, 'privacy')),
          TextSpan(text: '${a['legalSuffix']}'),
        ],
      ),
    );
  }
}

/// Checkbox row with optional link to the related legal document.
class LegalConsentRow extends StatelessWidget {
  const LegalConsentRow({
    super.key,
    required this.lang,
    required this.value,
    required this.onChanged,
    required this.label,
    this.docId,
  });

  final String lang;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;
  final String? docId;

  @override
  Widget build(BuildContext context) {
    final read = (Copy.of(lang)['auth'] as Map)['readDoc'];
    return InkWell(
      onTap: () => onChanged(!value),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              border: Border.all(color: Client.ink, width: Client.rule),
              color: value ? Client.plum : Colors.transparent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 14, height: 1.4, color: Client.ink)),
                if (docId != null)
                  GestureDetector(
                    onTap: () => openLegal(context, docId!),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '$read',
                        style: const TextStyle(fontSize: 12, color: Client.plum, fontWeight: FontWeight.w700, decoration: TextDecoration.underline, decorationColor: Client.plum),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
