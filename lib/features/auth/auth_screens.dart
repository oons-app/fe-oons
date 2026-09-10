import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:oons/app/web_host.dart';
import 'package:oons/core/analytics.dart';
import 'package:oons/core/locale.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/core/widgets.dart';
import 'package:oons/data/repo.dart';
import 'package:oons/features/auth/lab_api_tile.dart';
import 'package:oons/features/client/client_chrome.dart';
import 'package:oons/features/legal/legal_widgets.dart';
import 'package:oons/l10n/copy.dart';
import 'package:oons/l10n/errors.dart';

String afterAuthPath(String role) {
  final box = Hive.box('prefs');
  final pending = box.get('pending_path') as String?;
  if (pending != null && pending.isNotEmpty) {
    box.delete('pending_path');
    return pending;
  }
  return role == 'provider' ? '/pro/jobs' : '/home';
}

/// Phone + OTP for the in-progress registration (URL query can be lost on web).
({String phone, String code}) pendingRegistration(String fallbackPhone, String fallbackCode) {
  final box = Hive.box('prefs');
  final phone = fallbackPhone.trim().isNotEmpty ? fallbackPhone.trim() : '${box.get('pending_reg_phone') ?? ''}';
  final code = fallbackCode.trim().isNotEmpty ? fallbackCode.trim() : '${box.get('pending_reg_code') ?? ''}';
  return (phone: phone, code: code);
}

void clearPendingRegistration() {
  final box = Hive.box('prefs');
  box.delete('pending_reg_phone');
  box.delete('pending_reg_code');
  box.delete('pending_reg_role');
}

String normalizeEgPhone(String raw) {
  // Accept Arabic-Indic (٠-٩) and Eastern Arabic-Indic (۰-۹) from local keyboards.
  final ascii = raw.replaceAllMapped(RegExp(r'[\u0660-\u0669\u06F0-\u06F9]'), (m) {
    final c = m.group(0)!.codeUnitAt(0);
    final zero = c >= 0x06F0 ? 0x06F0 : 0x0660;
    return String.fromCharCode(0x30 + (c - zero));
  });
  var d = ascii.replaceAll(RegExp(r'\D'), '');
  if (d.startsWith('00')) d = d.substring(2);
  // +20 / 20 country code (with or without a following trunk 0).
  if (d.startsWith('20') && d.length >= 12) d = d.substring(2);
  d = d.replaceFirst(RegExp(r'^0+'), '');
  if (d.isEmpty) return '';
  // National form without trunk zero is 10 digits (1XXXXXXXXX); stored as 01XXXXXXXXX.
  return '0$d';
}

bool isValidEgPhone(String digits) {
  final n = normalizeEgPhone(digits);
  return RegExp(r'^01[0125][0-9]{8}$').hasMatch(n);
}

/// Display next to +20 without a second leading zero.
String egPhoneNational(String storedOrRaw) {
  final n = normalizeEgPhone(storedOrRaw);
  if (n.startsWith('0') && n.length > 1) return n.substring(1);
  return n;
}

/// Keeps the +20 field as national digits only (1XXXXXXXXX), max 10.
/// Pasting 01… / +20… / 20… is normalized so users don't hit a false "invalid" error.
class _EgPhoneInputFormatter extends TextInputFormatter {
  const _EgPhoneInputFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue _, TextEditingValue n) {
    final ascii = n.text.replaceAllMapped(
      RegExp(r'[\u0660-\u0669\u06F0-\u06F9]'),
      (m) {
        final c = m.group(0)!.codeUnitAt(0);
        final zero = c >= 0x06F0 ? 0x06F0 : 0x0660;
        return String.fromCharCode(0x30 + (c - zero));
      },
    );
    var d = ascii.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('00')) d = d.substring(2);
    if (d.startsWith('20') && d.length >= 12) d = d.substring(2);
    d = d.replaceFirst(RegExp(r'^0+'), '');
    if (d.length > 10) d = d.substring(0, 10);
    final offset = d.length;
    return TextEditingValue(
      text: d,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

class OnboardScreen extends ConsumerWidget {
  const OnboardScreen({super.key, required this.index});
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = langOf(ref);
    final t = Copy.of(lang);
    final trust = t['trustScreen'] as Map;
    final bullets = (trust['bullets'] as List).cast<String>();
    return Scaffold(
      backgroundColor: Client.bg,
      body: Column(
        children: [
          ClientAuthHeader(onLang: () => ref.read(localeProvider.notifier).toggle()),
          Expanded(
            child: SafeArea(
              top: false,
              child: ClientTrustScreenBody(
                title: '${trust['title']}',
                body: '${trust['body']}',
                bullets: bullets,
                cta: '${trust['cta']}',
                skip: '${t['skip']}',
                onCta: () {
                  Hive.box('prefs').put('onboarded', true);
                  context.go('/auth');
                },
                onSkip: () {
                  Hive.box('prefs').put('onboarded', true);
                  context.go('/auth');
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final ctrl = TextEditingController();
  bool busy = false;
  String? err;
  String role = 'client';

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = langOf(ref);
    final t = Copy.of(lang);
    final a = t['auth'] as Map;
    final phoneErr = err != null;
    final clientOnly = isCustomerOnlyAuthHost();
    final effectiveRole = clientOnly ? 'client' : role;
    return Scaffold(
      backgroundColor: Client.bg,
      body: Column(
        children: [
          ClientAuthHeader(onLang: () => ref.read(localeProvider.notifier).toggle()),
          Expanded(
            child: SafeArea(
              top: false,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    lang == 'ar' ? 'أهلاً. خدمة البيت بمتخصصات متأكدين منهم.' : 'Welcome. In-home care from vetted women.',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.15, color: Client.ink),
                  ),
                  const SizedBox(height: 12),
                  Text('${a['sub']}', style: const TextStyle(fontSize: 15, height: 1.55, color: Client.body)),
                  if (!clientOnly) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _roleChip(lang == 'ar' ? 'عميلة' : 'Client', 'client'),
                        const SizedBox(width: 8),
                        _roleChip(lang == 'ar' ? 'متخصصة' : 'Professional', 'provider'),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  ClientFieldLabel('${a['label']}', required: true),
                  const SizedBox(height: 8),
                  Ltr(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: phoneErr ? T.danger : Client.ink, width: Client.rule),
                        color: Client.card,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            alignment: Alignment.center,
                            constraints: const BoxConstraints(minHeight: 52),
                            decoration: BoxDecoration(
                              color: Client.sand,
                              border: Border(right: BorderSide(color: phoneErr ? T.danger : Client.ink, width: Client.rule)),
                            ),
                            child: const Text('+20', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Client.ink)),
                          ),
                          Expanded(
                            child: TextField(
                              controller: ctrl,
                              keyboardType: TextInputType.phone,
                              inputFormatters: const [_EgPhoneInputFormatter()],
                              onChanged: (_) {
                                if (err != null) setState(() => err = null);
                              },
                              style: const TextStyle(fontSize: 17, letterSpacing: 0.6, color: Client.ink),
                              decoration: const InputDecoration(
                                hintText: '1117198333',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      lang == 'ar'
                          ? 'اكتبي الرقم من غير صفر الأول — التطبيق بيحط +٢٠ لوحده.'
                          : 'Skip the leading 0 — the app already adds +20.',
                      style: const TextStyle(fontSize: 12, height: 1.35, color: Client.body),
                    ),
                  ),
                  if (err != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(err!, style: const TextStyle(color: T.danger, fontSize: 13, height: 1.4)),
                    ),
                  const SizedBox(height: 16),
                  ClientPrimaryButton(
                    label: '${a['send']}',
                    enabled: !busy,
                    onTap: () async {
                      final digits = normalizeEgPhone(ctrl.text);
                      if (digits.isEmpty) {
                        setState(() => err = '${a['phoneRequired']}');
                        return;
                      }
                      if (!isValidEgPhone(digits)) {
                        setState(() => err = '${a['phoneInvalid']}');
                        return;
                      }
                      setState(() {
                        busy = true;
                        err = null;
                      });
                      try {
                        final demo = await ref.read(sessionProvider.notifier).requestOtp(digits, role: effectiveRole);
                        unawaited(AppAnalytics.otpSent(role: effectiveRole));
                        if (effectiveRole == 'client') {
                          unawaited(AppAnalytics.clientRegistrationStarted(source: 'auth'));
                        } else {
                          unawaited(AppAnalytics.providerRegistrationStarted());
                        }
                        if (mounted) {
                          context.go('/otp?phone=${Uri.encodeComponent(digits)}&role=$effectiveRole&demo=${demo ? 1 : 0}');
                        }
                      } catch (e) {
                        setState(() => err = friendlyError(e, lang));
                      } finally {
                        if (mounted) setState(() => busy = false);
                      }
                    },
                  ),
                  const SizedBox(height: 28),
                  ...(a['assur'] as List).map((x) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('✓', style: TextStyle(fontFamily: T.mono, fontSize: 14, color: Client.olive, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 10),
                            Expanded(child: Text('$x', style: const TextStyle(fontSize: 13, height: 1.45, color: Client.body))),
                          ],
                        ),
                      )),
                  const SizedBox(height: 12),
                  const LabApiTile(),
                  LegalFooter(lang: lang),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleChip(String label, String id) {
    final on = role == id;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => role = id),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? Client.plum : Client.card,
            border: Border.all(color: Client.ink, width: Client.rule),
          ),
          child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: on ? Client.bg : Client.ink)),
        ),
      ),
    );
  }
}

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.phone, this.role = 'client', this.demo = false});
  final String phone;
  final String role;
  final bool demo;
  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  String code = '';
  bool busy = false;
  String? err;
  int cooldown = 60;
  Timer? tick;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    tick?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    tick?.cancel();
    setState(() => cooldown = 60);
    tick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (cooldown <= 1) {
        t.cancel();
        setState(() => cooldown = 0);
      } else {
        setState(() => cooldown--);
      }
    });
  }

  void _digit(String d) {
    if (code.length >= 4) return;
    setState(() {
      code += d;
      err = null;
    });
    if (code.length == 4) _verify();
  }

  void _backspace() {
    if (code.isEmpty) return;
    setState(() => code = code.substring(0, code.length - 1));
  }

  Future<void> _verify() async {
    if (busy) return;
    final lang = langOf(ref);
    final a = Copy.of(lang)['auth'] as Map;
    if (code.isEmpty) {
      setState(() => err = '${a['otpRequired']}');
      return;
    }
    if (code.length != 4) {
      setState(() => err = '${a['otpIncomplete']}');
      return;
    }
    setState(() => busy = true);
    try {
      await ref.read(sessionProvider.notifier).verify(widget.phone, code, role: widget.role);
      unawaited(AppAnalytics.otpVerificationAttempted(role: widget.role, success: true));
      tapSuccess();
      if (mounted) context.go(afterAuthPath(widget.role));
    } on NeedsRegister {
      unawaited(AppAnalytics.otpVerificationAttempted(role: widget.role, success: true, needsRegister: true));
      if (widget.role == 'client') {
        unawaited(AppAnalytics.clientRegistrationStarted(source: 'otp'));
      } else {
        unawaited(AppAnalytics.providerRegistrationStarted());
      }
      final box = Hive.box('prefs');
      await box.put('pending_reg_phone', widget.phone);
      await box.put('pending_reg_code', code);
      await box.put('pending_reg_role', widget.role);
      if (mounted) {
        final q = 'phone=${Uri.encodeComponent(widget.phone)}&code=${Uri.encodeComponent(code)}';
        context.go(widget.role == 'provider' ? '/pro/register?$q' : '/register?$q');
      }
    } catch (e) {
      unawaited(AppAnalytics.otpVerificationAttempted(role: widget.role, success: false));
      setState(() {
        err = friendlyError(e, lang);
        code = '';
      });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = langOf(ref);
    final t = Copy.of(lang);
    final o = t['otp'] as Map;
    return Scaffold(
      backgroundColor: Client.bg,
      body: Column(
        children: [
          ClientAuthHeader(onLang: () => ref.read(localeProvider.notifier).toggle()),
          Expanded(
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: constraints.maxHeight - 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextButton(
                                  onPressed: () => context.go('/auth'),
                                  child: Text(lang == 'ar' ? '← رجوع' : '← Back', style: const TextStyle(fontSize: 13, color: Client.muted)),
                                ),
                                const SizedBox(height: 4),
                                Text('${o['title']}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Client.ink)),
                                const SizedBox(height: 10),
                                Text(
                                  lang == 'ar' ? 'لو فعّلنا الرسائل، الكود بيوصل SMS. في التجربة المحلية الكود بيتسجل على السيرفر فقط.' : 'When SMS is live, the code arrives by text. On a local server it is issued by the API only.',
                                  style: const TextStyle(fontSize: 15, height: 1.45, color: Client.body),
                                ),
                                const SizedBox(height: 8),
                                Ltr(child: Text('+20 ${egPhoneNational(widget.phone)}', style: const TextStyle(fontFamily: T.mono, fontSize: 13, color: Client.plum))),
                                const SizedBox(height: 20),
                                ClientOtpBoxes(code: code, error: err != null),
                                if (err != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: Text(err!, style: const TextStyle(color: T.danger, fontSize: 13)),
                                  ),
                                const SizedBox(height: 20),
                                ClientNumpad(onDigit: _digit, onBackspace: _backspace, compact: true),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                    child: ClientPrimaryButton(
                      label: '${o['verify']}',
                      enabled: !busy,
                      onTap: _verify,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextButton(
                      onPressed: cooldown > 0 || busy
                          ? null
                          : () async {
                              try {
                                await ref.read(sessionProvider.notifier).requestOtp(widget.phone, role: widget.role);
                                unawaited(AppAnalytics.otpSent(role: widget.role, resend: true));
                                _startCooldown();
                              } catch (e) {
                                setState(() => err = friendlyError(e, lang));
                              }
                            },
                      child: Text(
                        cooldown > 0 ? '${o['resendIn']} 0:${cooldown.toString().padLeft(2, '0')}' : '${o['resendNow']}',
                        style: TextStyle(fontSize: 13, color: cooldown > 0 ? Client.muted2 : Client.plum),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ClientRegisterScreen extends ConsumerStatefulWidget {
  const ClientRegisterScreen({super.key, required this.phone, required this.code});
  final String phone;
  final String code;
  @override
  ConsumerState<ClientRegisterScreen> createState() => _ClientRegisterScreenState();
}

class _ClientRegisterScreenState extends ConsumerState<ClientRegisterScreen> {
  final first = TextEditingController();
  final last = TextEditingController();
  bool busy = false;
  bool eligibility = false;
  bool terms = false;
  bool privacy = false;
  String? err;
  String? firstErr;
  String? lastErr;
  final Set<String> _consentViewed = {};
  late final String _phone;
  late final String _code;

  @override
  void initState() {
    super.initState();
    final pending = pendingRegistration(widget.phone, widget.code);
    _phone = pending.phone;
    _code = pending.code;
    if (_phone.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/auth');
      });
    }
    unawaited(AppAnalytics.clientRegistrationStarted(source: 'register'));
    for (final t in ['eligibility', 'terms', 'privacy']) {
      unawaited(AppAnalytics.consentScreenViewed(consentType: t));
      _consentViewed.add(t);
    }
  }

  void _markConsent(String type, bool value) {
    setState(() {
      if (type == 'eligibility') eligibility = value;
      if (type == 'terms') terms = value;
      if (type == 'privacy') privacy = value;
    });
    if (value && !_consentViewed.contains('${type}_accepted')) {
      _consentViewed.add('${type}_accepted');
      unawaited(AppAnalytics.consentScreenViewed(consentType: '${type}_accepted'));
    }
  }

  @override
  void dispose() {
    first.dispose();
    last.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = langOf(ref);
    final a = Copy.of(lang)['auth'] as Map;
    final p = Copy.of(lang)['pro'] as Map;
    return Scaffold(
      backgroundColor: Client.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('${a['regTitle']}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Client.ink)),
            const SizedBox(height: 10),
            Text('${a['regSub']}', style: const TextStyle(fontSize: 15, height: 1.5, color: Client.body)),
            const SizedBox(height: 24),
            ClientFieldLabel('${p['first']}', required: true),
            const SizedBox(height: 8),
            ClientTextField(
              controller: first,
              errorText: firstErr,
              onChanged: (_) {
                if (firstErr != null) setState(() => firstErr = null);
              },
            ),
            const SizedBox(height: 16),
            ClientFieldLabel('${p['last']}', required: true),
            const SizedBox(height: 8),
            ClientTextField(
              controller: last,
              errorText: lastErr,
              onChanged: (_) {
                if (lastErr != null) setState(() => lastErr = null);
              },
            ),
            const SizedBox(height: 24),
            ClientKicker('${a['eligTitle']}'),
            const SizedBox(height: 8),
            Text('${a['eligBody']}', style: const TextStyle(fontSize: 13, height: 1.45, color: Client.muted)),
            const SizedBox(height: 12),
            LegalConsentRow(
              lang: lang,
              value: eligibility,
              onChanged: (v) => _markConsent('eligibility', v),
              label: '${a['eligAccept']}',
            ),
            const SizedBox(height: 12),
            LegalConsentRow(
              lang: lang,
              value: terms,
              onChanged: (v) => _markConsent('terms', v),
              label: '${a['termsAccept']}',
              docId: 'terms',
            ),
            const SizedBox(height: 12),
            LegalConsentRow(
              lang: lang,
              value: privacy,
              onChanged: (v) => _markConsent('privacy', v),
              label: '${a['privacyAccept']}',
              docId: 'privacy',
            ),
            if (err != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text(err!, style: const TextStyle(color: T.danger))),
            const SizedBox(height: 24),
            ClientPrimaryButton(
              label: '${a['regCta']}',
              enabled: !busy,
              onTap: () async {
                final fEmpty = first.text.trim().isEmpty;
                final lEmpty = last.text.trim().isEmpty;
                if (fEmpty || lEmpty) {
                  setState(() {
                    firstErr = fEmpty ? '${a['firstRequired']}' : null;
                    lastErr = lEmpty ? '${a['lastRequired']}' : null;
                    err = '${a['nameRequired']}';
                  });
                  return;
                }
                if (!eligibility || !terms || !privacy) {
                  setState(() => err = '${a['consentRequired']}');
                  return;
                }
                setState(() {
                  busy = true;
                  err = null;
                  firstErr = null;
                  lastErr = null;
                });
                try {
                  await ref.read(sessionProvider.notifier).registerClient(
                        phone: _phone,
                        code: _code,
                        firstName: first.text.trim(),
                        lastName: last.text.trim(),
                        eligibilityConsent: true,
                        termsConsent: true,
                        privacyConsent: true,
                      );
                  clearPendingRegistration();
                  tapSuccess();
                  if (mounted) context.go(afterAuthPath('client'));
                } catch (e) {
                  setState(() => err = friendlyError(e, lang));
                } finally {
                  if (mounted) setState(() => busy = false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
