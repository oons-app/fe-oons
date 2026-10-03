/// What `GET /me/referral` returns: her invite code, how it is going and the
/// coupons she has earned.
class ReferralReward {
  const ReferralReward({required this.code, required this.percent, required this.maxDiscount, required this.status, this.expiresAt});
  final String code;
  final int percent;

  /// Piastres; 0 = no cap.
  final int maxDiscount;

  /// `available` · `used` · `expired`.
  final String status;
  final DateTime? expiresAt;

  bool get available => status == 'available';

  factory ReferralReward.fromJson(Map j) => ReferralReward(
        code: '${j['code'] ?? ''}',
        percent: (j['percent'] as num?)?.toInt() ?? 0,
        maxDiscount: (j['maxDiscount'] as num?)?.toInt() ?? 0,
        status: '${j['status'] ?? 'available'}',
        expiresAt: DateTime.tryParse('${j['expiresAt'] ?? ''}')?.toLocal(),
      );
}

class ReferralInfo {
  const ReferralInfo({
    required this.enabled,
    required this.code,
    required this.percent,
    required this.maxDiscount,
    required this.validDays,
    required this.invited,
    required this.completed,
    required this.rewards,
    required this.usedCode,
    required this.canApplyCode,
  });

  final bool enabled;
  final String code;
  final int percent;
  final int maxDiscount;
  final int validDays;
  final int invited;
  final int completed;
  final List<ReferralReward> rewards;

  /// She already entered someone's code.
  final bool usedCode;

  /// She is new (no booking yet) and has not used a code: show the entry field.
  final bool canApplyCode;

  factory ReferralInfo.fromJson(Map j) => ReferralInfo(
        enabled: j['enabled'] != false,
        code: '${j['code'] ?? ''}',
        percent: (j['percent'] as num?)?.toInt() ?? 50,
        maxDiscount: (j['maxDiscount'] as num?)?.toInt() ?? 0,
        validDays: (j['validDays'] as num?)?.toInt() ?? 90,
        invited: (j['invited'] as num?)?.toInt() ?? 0,
        completed: (j['completed'] as num?)?.toInt() ?? 0,
        rewards: [
          for (final r in (j['rewards'] as List? ?? const []))
            if (r is Map) ReferralReward.fromJson(r),
        ],
        usedCode: j['usedCode'] == true,
        canApplyCode: j['canApplyCode'] == true,
      );
}
