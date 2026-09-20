import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:oons/core/format.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/core/widgets.dart';
import 'package:oons/features/client/client_chrome.dart';

class PayManualPanel extends StatelessWidget {
  const PayManualPanel({
    super.key,
    required this.lang,
    required this.bf,
    required this.amountPiastres,
    required this.number,
    required this.preview,
    required this.busy,
    required this.submitted,
    required this.onPick,
    required this.onSubmit,
  });

  final String lang;
  final Map<String, String> bf;
  final int amountPiastres;
  final String number;
  final Uint8List? preview;
  final bool busy;
  final bool submitted;
  final VoidCallback onPick;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text(bf['manualTitle'] ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.3)),
        const SizedBox(height: 8),
        Text(bf['manualBody'] ?? '', style: const TextStyle(fontSize: 14, height: 1.45, color: Client.body)),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(border: Border.all(color: Client.ink, width: Client.rule), color: Client.card),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(bf['manualNumber'] ?? '', style: const TextStyle(fontSize: 12, color: Client.muted, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Ltr(
                child: Text(
                  number,
                  style: const TextStyle(fontFamily: T.mono, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 0.6),
                ),
              ),
              const SizedBox(height: 12),
              ClientGhostButton(
                label: bf['manualCopy'] ?? '',
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: number));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(bf['manualCopied'] ?? '')));
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          money(amountPiastres, lang),
          style: const TextStyle(fontFamily: T.mono, fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        if (submitted)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            color: Client.warnTint,
            child: Text(bf['manualWaiting'] ?? '', style: const TextStyle(fontSize: 14, height: 1.45, fontWeight: FontWeight.w700)),
          )
        else ...[
          if (preview != null) ...[
            Container(
              height: 180,
              decoration: BoxDecoration(border: Border.all(color: Client.ink, width: Client.rule)),
              clipBehavior: Clip.hardEdge,
              child: Image.memory(preview!, fit: BoxFit.cover, width: double.infinity),
            ),
            const SizedBox(height: 10),
          ],
          ClientGhostButton(
            label: preview == null ? (bf['manualUpload'] ?? '') : (bf['manualChange'] ?? ''),
            onTap: busy ? null : onPick,
          ),
          const SizedBox(height: 10),
          ClientPrimaryButton(
            label: bf['manualSubmit'] ?? '',
            enabled: !busy && preview != null,
            onTap: busy ? null : onSubmit,
          ),
        ],
      ],
    );
  }
}

Future<XFile?> pickPayReceipt() {
  return ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 2000);
}
