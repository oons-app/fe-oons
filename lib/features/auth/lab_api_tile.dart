import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/data/api.dart';
import 'package:oons/features/client/client_chrome.dart';

/// Debug / profile only. Lets a physical phone point at the Mac LAN API.
class LabApiTile extends StatefulWidget {
  const LabApiTile({super.key});

  @override
  State<LabApiTile> createState() => _LabApiTileState();
}

class _LabApiTileState extends State<LabApiTile> {
  late final TextEditingController _ctrl;
  String? _err;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: apiHost());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      await setLabApiBase(_ctrl.text);
      setState(() {
        _err = null;
        _ctrl.text = apiHost();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('API: ${apiHost()}')),
        );
      }
    } catch (_) {
      setState(() => _err = 'Use the lab API host, e.g. 47.91.41.120:8088');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!allowLabApiOverride) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kProfileMode
                ? 'Lab API (this profile build can open from the Home Screen)'
                : 'Lab API (debug cannot open from the Home Screen on iOS — use profile)',
            style: const TextStyle(fontSize: 12, height: 1.4, color: Client.body),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _ctrl,
            autocorrect: false,
            keyboardType: TextInputType.url,
            style: const TextStyle(fontSize: 14, fontFamily: T.mono, color: Client.ink),
            decoration: InputDecoration(
              hintText: '47.91.41.120:8088',
              filled: true,
              fillColor: Client.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: Client.ink, width: Client.rule),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: Client.ink, width: Client.rule),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          if (_err != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_err!, style: const TextStyle(color: T.danger, fontSize: 12)),
            ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: _save,
              child: const Text('Save API host'),
            ),
          ),
        ],
      ),
    );
  }
}
