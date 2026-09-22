/// In-app alert copy. Keep in sync with server/internal/notify/alerts.go.
class AlertCopy {
  static (String title, String body) of(
    String type, {
    required String lang,
    required String party,
    String? fallbackTitle,
    String? fallbackBody,
  }) {
    final table = lang == 'en' ? _en : _ar;
    final pair = table['$type.$party'] ?? table[type] ?? table['default']!;
    var title = pair.$1;
    var body = pair.$2;
    if (title.isEmpty) title = fallbackTitle ?? '';
    if (body.isEmpty) body = fallbackBody ?? '';
    final ref = bookingRef(fallbackBody ?? '');
    if (ref.isNotEmpty && !body.contains(ref)) body = '$body · $ref';
    return (title, body);
  }

  static String bookingRef(String body) {
    const mark = ' · ';
    final i = body.lastIndexOf(mark);
    if (i < 0) return '';
    final tail = body.substring(i + mark.length);
    return tail.startsWith('ONS-') ? tail : '';
  }
}

const _ar = <String, (String, String)>{
  'default': ('أنس', 'هناك تحديث على زيارة.'),
  'paid': ('حجز جديد', 'عميلة دفعت. راجعي تفاصيل الزيارة.'),
  'paid.client': ('مدفوع', 'تأكّد حجزكِ. ستصلكِ تفاصيل الزيارة.'),
  'paid.provider': ('حجز جديد', 'عميلة دفعت. راجعي تفاصيل الزيارة.'),
  'pending_payment.client': ('بانتظار الدفع', 'ما زال هناك مبلغ مستحق على الحجز.'),
  'pending_payment.provider': ('بانتظار الدفع', 'الحجز ما زال بانتظار دفع العميلة.'),
  'receipt_uploaded': ('إيصال إنستاباي', 'عميلة رفعت صورة تحويل إنستاباي. راجعي الإيصال وأكّدي الدفع.'),
  'on_the_way': ('في الطريق', 'المتخصصة في الطريق إليكِ.'),
  'on_the_way.client': ('في الطريق', 'المتخصصة في الطريق إليكِ.'),
  'on_the_way.provider': ('في الطريق', 'العميلة تعلم أنكِ في الطريق.'),
  'at_door': ('عند الباب', 'وصلت المتخصصة. أكّدي إن لم تؤكدي بعد.'),
  'at_door.client': ('عند الباب', 'وصلت المتخصصة. أكّدي إن لم تؤكدي بعد.'),
  'at_door.provider': ('عند الباب', 'ستؤكد العميلة وصولكِ.'),
  'in_progress': ('بدأت الزيارة', 'الزيارة جارية الآن.'),
  'in_progress.client': ('بدأت الزيارة', 'الزيارة جارية الآن.'),
  'in_progress.provider': ('بدأت الزيارة', 'أكّدت العميلة. الزيارة جارية.'),
  'completed': ('انتهت الزيارة', 'أُغلقت الزيارة.'),
  'completed.client': ('انتهت الزيارة', 'يمكنكِ تقييم المتخصصة.'),
  'completed.provider': ('انتهت الزيارة', 'أُغلقت الزيارة. تُراجع مستحقاتكِ بعد يومين.'),
  'cancelled_provider': ('إلغاء', 'ألغت المتخصصة. تتوفر بديلة في الموعد نفسه إن رغبتِ.'),
  'cancelled_provider.client': ('إلغاء', 'ألغت المتخصصة. تتوفر بديلة في الموعد نفسه إن رغبتِ.'),
  'cancelled_provider.provider': ('إلغاء', 'أُلغي الحجز من طرفكِ.'),
  'cancelled_client': ('إلغاء', 'ألغت العميلة الزيارة.'),
  'cancelled_client.client': ('إلغاء', 'أُلغي حجزكِ.'),
  'cancelled_client.provider': ('إلغاء', 'ألغت العميلة الزيارة.'),
  'dispute': ('نزاع', 'فُتح نزاع على زيارة. راجعي التفاصيل.'),
  'dispute.client': ('نزاع', 'سُجّل النزاع. ويُحتجز المبلغ حتى المراجعة.'),
  'dispute.provider': ('نزاع', 'فُتح نزاع على زيارة. راجعي التفاصيل.'),
  'disputed.client': ('نزاع', 'سُجّل النزاع. ويُحتجز المبلغ حتى المراجعة.'),
  'disputed.provider': ('نزاع', 'فُتح نزاع على زيارة. راجعي التفاصيل.'),
  'dispute_refund.client': ('استرداد', 'أُغلق النزاع. سيُعاد المبلغ إلى طريقة الدفع.'),
  'dispute_refund.provider': ('استرداد', 'أُغلق النزاع بالاسترداد. لا صرف على هذه الزيارة.'),
  'dispute_release.client': ('أُغلق', 'أُغلق النزاع وصُرف المبلغ للمتخصصة.'),
  'dispute_release.provider': ('مستحقاتك', 'أُغلق النزاع وأُفرج عن المبلغ لكِ.'),
  'dispute_split.client': ('تقسيم', 'أُغلق النزاع. جزء يُعاد وجزء للمتخصصة.'),
  'dispute_split.provider': ('تقسيم', 'أُغلق النزاع. أُفرج عن جزء من المبلغ لكِ.'),
  'refunded.client': ('استرداد', 'سيُعاد المبلغ إلى طريقة الدفع.'),
  'refunded.provider': ('استرداد', 'أُعيد الحجز. لا صرف على هذه الزيارة.'),
  'released.client': ('أُغلق', 'انتهت الزيارة وصُرف المبلغ للمتخصصة.'),
  'released.provider': ('مستحقاتك', 'أُفرج عن المبلغ لكِ.'),
  'rescheduled.client': ('تأجيل', 'تغيّر موعد الزيارة.'),
  'rescheduled.provider': ('تأجيل', 'تغيّر موعد الزيارة. راجعي الجدول.'),
  'payout': ('مستحقاتك', 'أصبح مبلغ متاحًا للسحب.'),
  'payout_held': ('إيقاف سحب', 'طلب السحب معلّق للمراجعة.'),
  'vetted': ('اكتمل التوثيق', 'رُوجع حسابكِ وأُتيح للعميلات.'),
  'rejected': ('مراجعة الهوية', 'تعذّر توثيق الحساب الآن. سنتواصل إن احتجنا شيئًا.'),
};

const _en = <String, (String, String)>{
  'default': ('Oons', "There's an update on a visit."),
  'paid': ('New booking', 'A client paid. Open the visit.'),
  'paid.client': ('Paid', 'Your booking is confirmed.'),
  'paid.provider': ('New booking', 'A client paid. Open the visit.'),
  'pending_payment.client': ('Waiting for payment', 'This booking is still unpaid.'),
  'pending_payment.provider': ('Waiting for payment', 'The client has not paid yet.'),
  'receipt_uploaded': ('InstaPay receipt', 'A client uploaded an InstaPay transfer screenshot. Review it and confirm payment.'),
  'on_the_way': ('On the way', 'Your professional is on the way.'),
  'on_the_way.client': ('On the way', 'Your professional is on the way.'),
  'on_the_way.provider': ('On the way', 'She knows you are on the way.'),
  'at_door': ('At the door', "She has arrived. Confirm if you haven't."),
  'at_door.client': ('At the door', "She has arrived. Confirm if you haven't."),
  'at_door.provider': ('At the door', 'Waiting for her to confirm you arrived.'),
  'in_progress': ('Visit started', 'The visit is running now.'),
  'in_progress.client': ('Visit started', 'The visit is running now.'),
  'in_progress.provider': ('Visit started', 'She confirmed. The visit is running.'),
  'completed': ('Visit ended', 'The visit is closed.'),
  'completed.client': ('Visit ended', 'You can rate her now.'),
  'completed.provider': ('Visit ended', 'The visit is closed. Earnings review after the hold.'),
  'cancelled_provider': ('Cancelled', 'She cancelled. We can find a replacement at the same time.'),
  'cancelled_provider.client': ('Cancelled', 'She cancelled. We can find a replacement at the same time.'),
  'cancelled_provider.provider': ('Cancelled', 'This booking was cancelled on your side.'),
  'cancelled_client': ('Cancelled', 'The client cancelled the visit.'),
  'cancelled_client.client': ('Cancelled', 'Your booking was cancelled.'),
  'cancelled_client.provider': ('Cancelled', 'The client cancelled the visit.'),
  'dispute': ('Dispute', 'A visit is under review. Open the details.'),
  'dispute.client': ('Dispute', 'The money stays held until we review.'),
  'dispute.provider': ('Dispute', 'A visit is under review. Open the details.'),
  'disputed.client': ('Dispute', 'The money stays held until we review.'),
  'disputed.provider': ('Dispute', 'A visit is under review. Open the details.'),
  'dispute_refund.client': ('Refund', 'The dispute is closed. The amount goes back to how you paid.'),
  'dispute_refund.provider': ('Refund', 'The dispute closed with a refund. No payout on this visit.'),
  'dispute_release.client': ('Closed', 'The dispute closed and she was paid.'),
  'dispute_release.provider': ('Your money', 'The dispute closed and the amount was released to you.'),
  'dispute_split.client': ('Split', 'The dispute closed. Part refunded, part paid to her.'),
  'dispute_split.provider': ('Split', 'The dispute closed. Part of the amount was released to you.'),
  'refunded.client': ('Refund', 'The amount goes back to how you paid.'),
  'refunded.provider': ('Refund', 'This booking was refunded. No payout.'),
  'released.client': ('Closed', 'The visit closed and the amount was released.'),
  'released.provider': ('Your money', 'The amount was released to you.'),
  'rescheduled.client': ('Rescheduled', 'The visit time changed.'),
  'rescheduled.provider': ('Rescheduled', 'The visit time changed. Check your list.'),
  'payout': ('Your money', 'An amount is available to withdraw.'),
  'payout_held': ('Payout held', 'This withdrawal is paused for review.'),
  'vetted': ('Verified', 'Your profile is live for clients.'),
  'rejected': ('ID review', 'We could not verify the account yet. We will reach you if we need anything.'),
};
